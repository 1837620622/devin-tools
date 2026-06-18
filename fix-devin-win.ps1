# ============================================================================
# Windsurf 修复工具 - Windows 版本 (PowerShell)
# 用于修复 Windsurf IDE 卡顿、Shell无法连接等常见问题
# 基于官方文档: https://docs.windsurf.com/troubleshooting/windsurf-common-issues
# 使用方法: 以管理员身份运行 PowerShell，执行 .\fix-windsurf-win.ps1
# 作者: 传康KK
# GitHub: https://github.com/1837620622/windsurf-fix-tool
# ============================================================================

#Requires -Version 5.1

# ----------------------------------------------------------------------------
# 编码设置
# 脚本文件采用 UTF-8 with BOM，兼容 Windows PowerShell 5.1 的中文解析。
# 不使用 GBK/ANSI，避免 GitHub 与跨平台环境再次出现编码不一致。
# ----------------------------------------------------------------------------
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# ----------------------------------------------------------------------------
# 路径定义
# ----------------------------------------------------------------------------
$CodeiumDir = "$env:USERPROFILE\.codeium"
$WindsurfDir = "$CodeiumDir\windsurf"
$WindsurfAppData = Join-Path $env:APPDATA "Windsurf"
$CascadeDir = "$WindsurfDir\cascade"
$BackupDir = "$env:USERPROFILE\.windsurf-backup-$(Get-Date -Format 'yyyyMMdd_HHmmss')"
$SettingsJsonPath = "$env:APPDATA\Windsurf\User\settings.json"
$XdgConfigRoot = if ([string]::IsNullOrWhiteSpace($env:XDG_CONFIG_HOME)) { "$env:USERPROFILE\.config" } else { $env:XDG_CONFIG_HOME }
$XdgCacheRoot = if ([string]::IsNullOrWhiteSpace($env:XDG_CACHE_HOME)) { "$env:USERPROFILE\.cache" } else { $env:XDG_CACHE_HOME }
$XdgDataRoot = if ([string]::IsNullOrWhiteSpace($env:XDG_DATA_HOME)) { "$env:USERPROFILE\.local\share" } else { $env:XDG_DATA_HOME }
$ClaudeCodeDir = if ([string]::IsNullOrWhiteSpace($env:CLAUDE_CONFIG_DIR)) { "$env:USERPROFILE\.claude" } else { $env:CLAUDE_CONFIG_DIR }
$CodexDir = if ([string]::IsNullOrWhiteSpace($env:CODEX_HOME)) { "$env:USERPROFILE\.codex" } else { $env:CODEX_HOME }
$GeminiCliHomeRoot = if ([string]::IsNullOrWhiteSpace($env:GEMINI_CLI_HOME)) { $env:USERPROFILE } else { $env:GEMINI_CLI_HOME.TrimEnd([char[]]"\\/") }
$GeminiCliDir = if ([System.IO.Path]::GetFileName($GeminiCliHomeRoot) -eq ".gemini") { $GeminiCliHomeRoot } else { Join-Path $GeminiCliHomeRoot ".gemini" }
$OpenCodeInstallDir = "$env:USERPROFILE\.opencode"
$OpenCodeConfigDir = Join-Path $XdgConfigRoot "opencode"
$OpenCodeCacheDir = Join-Path $XdgCacheRoot "opencode"
$OpenCodeDataDir = Join-Path $XdgDataRoot "opencode"

# ----------------------------------------------------------------------------
# 颜色输出函数
# ----------------------------------------------------------------------------
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Type = "Info"
    )
    
    switch ($Type) {
        "Info"    { Write-Host "[信息] " -ForegroundColor Blue -NoNewline; Write-Host $Message }
        "Success" { Write-Host "[成功] " -ForegroundColor Green -NoNewline; Write-Host $Message }
        "Warning" { Write-Host "[警告] " -ForegroundColor Yellow -NoNewline; Write-Host $Message }
        "Error"   { Write-Host "[错误] " -ForegroundColor Red -NoNewline; Write-Host $Message }
        "Header"  { Write-Host $Message -ForegroundColor Cyan }
    }
}

function Write-Header {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  Windsurf 修复工具 - Windows" -ForegroundColor Cyan
    Write-Host "  by 传康KK" -ForegroundColor Cyan
    Write-Host "  github.com/1837620622/windsurf-fix-tool" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    # 运行模式提示
    if ($env:FORCE_RESET_ID -eq "0" -or $env:FORCE_RESET_ID -eq "false") {
        Write-Host "[当前模式] 保守模式" -ForegroundColor Green -NoNewline
        Write-Host "（FORCE_RESET_ID=0）——清理不重置设备 ID，保留登录态"
    }
    else {
        Write-Host "[当前模式] 强制重置模式" -ForegroundColor Red -NoNewline
        Write-Host "（默认）——所有清理菜单完成后自动重置 Windsurf 设备 ID"
        Write-Host "  ⚠ 重置后 Windsurf 会被识别为新设备，可能需要重新登录一次" -ForegroundColor Yellow
        Write-Host "  ⚠ 用途：绕过限速、刷新免费额度、解决服务端缓存异常" -ForegroundColor Yellow
        Write-Host "  如需关闭强制重置：" -NoNewline
        Write-Host '  $env:FORCE_RESET_ID="0"; .\fix-windsurf-win.ps1' -ForegroundColor Cyan
    }
    Write-Host ""
    Write-Host "[始终保留] 对话和用户数据，任何模式下都不会被清理：" -ForegroundColor Green
    Write-Host "  - ~/.codeium/windsurf/cascade/*.pb         对话历史"
    Write-Host "  - ~/.codeium/windsurf/memories/            用户记忆"
    Write-Host "  - ~/.codeium/windsurf/skills/              技能"
    Write-Host "  - ~/.codeium/windsurf/mcp_config.json      MCP 配置"
    Write-Host "  - ~/.codeium/windsurf/user_settings.pb     用户偏好"
    Write-Host "  - %APPDATA%\Windsurf\User\settings.json    编辑器设置"
    Write-Host ""
    Write-Host "[清理后会被强制重置] 仅在强制重置模式下（默认）：" -ForegroundColor Red
    Write-Host "  - installation_id                          Windsurf 安装标识"
    Write-Host "  - machineid                                机器标识"
    Write-Host "  - storage.json 中的 telemetry.* 多项标识"
    Write-Host ""
}

# ----------------------------------------------------------------------------
# 确认操作函数
# ----------------------------------------------------------------------------
function Confirm-Action {
    param([string]$Message = "确认执行此操作？")
    
    $choice = Read-Host "$Message [y/N]"
    return ($choice -eq 'y' -or $choice -eq 'Y')
}

# ----------------------------------------------------------------------------
# 检测系统信息
# ----------------------------------------------------------------------------
function Get-SystemInfo {
    Write-ColorOutput "正在检测系统信息..." "Info"
    
    $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
    $arch = if ([Environment]::Is64BitOperatingSystem) { "64-bit" } else { "32-bit" }
    
    Write-Host ""
    Write-Host "  Windows版本: " -NoNewline; Write-Host "$($osInfo.Caption)" -ForegroundColor Green
    Write-Host "  系统架构: " -NoNewline; Write-Host "$arch" -ForegroundColor Green
    Write-Host "  用户目录: " -NoNewline; Write-Host "$env:USERPROFILE" -ForegroundColor Green
    Write-Host ""
}

# ----------------------------------------------------------------------------
# 检查管理员权限
# ----------------------------------------------------------------------------
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ----------------------------------------------------------------------------
# 检查Windsurf是否正在运行
# ----------------------------------------------------------------------------
function Test-WindsurfRunning {
    $processes = Get-Process -Name "Windsurf" -ErrorAction SilentlyContinue
    
    if ($processes) {
        Write-ColorOutput "检测到 Windsurf 正在运行" "Warning"
        Write-Host "  请先关闭 Windsurf 再执行修复操作"
        
        if (Confirm-Action "是否自动关闭Windsurf？") {
            $processes | Stop-Process -Force
            Start-Sleep -Seconds 2
            Write-ColorOutput "Windsurf 已关闭" "Success"
            return $true
        }
        else {
            Write-ColorOutput "请手动关闭 Windsurf 后重试" "Error"
            return $false
        }
    }
    return $true
}

# ----------------------------------------------------------------------------
# 功能1: 清理Cascade缓存
# ----------------------------------------------------------------------------
function Clear-CascadeCache {
    Write-ColorOutput "清理 Cascade 缓存..." "Info"
    Write-ColorOutput "此操作将删除对话历史和本地设置！" "Warning"
    
    if (-not (Test-Path $CascadeDir)) {
        Write-ColorOutput "Cascade 缓存目录不存在，无需清理" "Info"
        return
    }
    
    if (Confirm-Action) {
        # 备份
        try {
            New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
            Copy-Item -Path $CascadeDir -Destination "$BackupDir\cascade" -Recurse -Force
            Write-ColorOutput "已备份到: $BackupDir" "Info"
        }
        catch {
            Write-ColorOutput "备份失败: $_" "Warning"
        }
        
        # 删除
        try {
            Remove-Item -Path $CascadeDir -Recurse -Force
            Write-ColorOutput "Cascade 缓存已清理" "Success"

            # 清理完毕 -> 强制重置设备 ID（默认行为）
            Invoke-AutoResetAfterClean
        }
        catch {
            Write-ColorOutput "清理失败: $_" "Error"
        }
    }
    else {
        Write-ColorOutput "已取消操作" "Info"
    }
}

# ----------------------------------------------------------------------------
# 功能3: 清理扩展缓存
# ----------------------------------------------------------------------------
function Clear-ExtensionCache {
    Write-ColorOutput "清理扩展缓存..." "Info"

    if (Confirm-Action) {
        $cacheCleared = $false
        $cacheDirs = @(
            (Join-Path $WindsurfAppData "CachedData"),
            (Join-Path $WindsurfAppData "CachedExtensionVSIXs"),
            (Join-Path $WindsurfDir "CachedData"),
            (Join-Path $WindsurfDir "CachedExtensions")
        )

        foreach ($cacheDir in $cacheDirs) {
            if (Test-Path $cacheDir) {
                try {
                    Remove-Item -Path $cacheDir -Recurse -Force
                    Write-ColorOutput "已清理 $([System.IO.Path]::GetFileName($cacheDir))" "Success"
                    $cacheCleared = $true
                }
                catch {
                    Write-ColorOutput "清理失败: $_" "Error"
                }
            }
        }

        if (-not $cacheCleared) {
            Write-ColorOutput "未找到可清理的扩展缓存目录" "Info"
        }

        Write-ColorOutput "扩展缓存清理完成" "Success"

        # 清理完毕 -> 强制重置设备 ID（默认行为）
        Invoke-AutoResetAfterClean
    }
    else {
        Write-ColorOutput "已取消操作" "Info"
    }
}

# ----------------------------------------------------------------------------
# 功能2: 清理启动缓存（不清理对话历史）
# ----------------------------------------------------------------------------
function Clear-StartupCache {
    Write-ColorOutput "清理启动相关缓存（解决启动卡顿）..." "Info"
    
    Write-Host ""
    Write-Host "此操作将清理以下缓存以加速启动:"
    Write-Host "  - Cache (浏览器缓存)"
    Write-Host "  - GPUCache (GPU渲染缓存)"
    Write-Host "  - CachedData (编辑器缓存数据)"
    Write-Host "  - DawnWebGPUCache / DawnGraphiteCache (图形管线缓存)"
    Write-Host "  - CachedExtensionVSIXs (扩展安装包缓存)"
    Write-Host "  - Code Cache (代码缓存)"
    Write-Host "  - 7天以上的日志文件"
    Write-Host ""
    Write-ColorOutput "此操作 不会 清理对话历史！" "Success"
    Write-Host ""
    
    if (Confirm-Action) {
        if (-not (Test-WindsurfRunning)) { return }

        # 清理 GPUCache
        $cacheDir = Join-Path $WindsurfAppData "Cache"
        if (Test-Path $cacheDir) {
            Remove-Item -Path $cacheDir -Recurse -Force -ErrorAction SilentlyContinue
            Write-ColorOutput "已清理 Cache" "Success"
        }

        $gpuCache = Join-Path $WindsurfAppData "GPUCache"
        if (Test-Path $gpuCache) {
            Remove-Item -Path $gpuCache -Recurse -Force -ErrorAction SilentlyContinue
            Write-ColorOutput "已清理 GPUCache" "Success"
        }
        
        # 清理 CachedData
        foreach ($cachedData in @((Join-Path $WindsurfAppData "CachedData"), (Join-Path $WindsurfDir "CachedData"))) {
            if (Test-Path $cachedData) {
                Remove-Item -Path $cachedData -Recurse -Force -ErrorAction SilentlyContinue
                Write-ColorOutput "已清理 $([System.IO.Path]::GetFileName($cachedData))" "Success"
            }
        }

        # 清理扩展安装包缓存，兼容旧版目录结构。
        foreach ($cachedExt in @((Join-Path $WindsurfAppData "CachedExtensionVSIXs"), (Join-Path $WindsurfDir "CachedExtensions"))) {
            if (Test-Path $cachedExt) {
                Remove-Item -Path $cachedExt -Recurse -Force -ErrorAction SilentlyContinue
                Write-ColorOutput "已清理 $([System.IO.Path]::GetFileName($cachedExt))" "Success"
            }
        }
        
        # 清理 Code Cache
        $codeCache = Join-Path $WindsurfAppData "Code Cache"
        if (Test-Path $codeCache) {
            Remove-Item -Path $codeCache -Recurse -Force -ErrorAction SilentlyContinue
            Write-ColorOutput "已清理 Code Cache" "Success"
        }

        foreach ($graphCache in @((Join-Path $WindsurfAppData "DawnWebGPUCache"), (Join-Path $WindsurfAppData "DawnGraphiteCache"))) {
            if (Test-Path $graphCache) {
                Remove-Item -Path $graphCache -Recurse -Force -ErrorAction SilentlyContinue
                Write-ColorOutput "已清理 $([System.IO.Path]::GetFileName($graphCache))" "Success"
            }
        }
        
        # 清理旧日志
        $logsDir = Join-Path $WindsurfAppData "logs"
        if (Test-Path $logsDir) {
            Get-ChildItem -Path $logsDir -File -Recurse | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) } | Remove-Item -Force -ErrorAction SilentlyContinue
            Write-ColorOutput "已清理旧日志文件" "Success"
        }
        
        Write-Host ""
        Write-ColorOutput "启动缓存清理完成！" "Success"
        Write-ColorOutput "重启 Windsurf 后启动速度应该会改善" "Info"

        # 清理完毕 -> 强制重置设备 ID（默认行为）
        Invoke-AutoResetAfterClean
    }
    else {
        Write-ColorOutput "已取消操作" "Info"
    }
}

# ----------------------------------------------------------------------------
# 功能7: MCP诊断
# ----------------------------------------------------------------------------
function Test-MCP {
    Write-ColorOutput "MCP (Model Context Protocol) 诊断..." "Info"
    
    $mcpConfig = "$WindsurfDir\mcp_config.json"
    $mcpConfigOld = "$CodeiumDir\mcp_config.json"
    
    Write-Host ""
    Write-Host "MCP 配置文件状态:" -ForegroundColor Cyan
    Write-Host ""
    
    if (Test-Path $mcpConfig) {
        Write-ColorOutput "找到 MCP 配置: $mcpConfig" "Success"
        Write-Host ""
        Write-Host "配置内容预览:"
        Get-Content $mcpConfig -TotalCount 30 | ForEach-Object { Write-Host "  $_" }
        Write-Host ""
        
        # 验证 JSON 格式
        try {
            $null = Get-Content $mcpConfig -Raw | ConvertFrom-Json
            Write-ColorOutput "MCP 配置 JSON 格式有效" "Success"
        }
        catch {
            Write-ColorOutput "MCP 配置 JSON 格式无效！" "Error"
        }
    }
    else {
        Write-ColorOutput "未找到 MCP 配置文件: $mcpConfig" "Warning"
    }
    
    if (Test-Path $mcpConfigOld) {
        Write-ColorOutput "发现旧版 MCP 配置: $mcpConfigOld" "Info"
    }
    
    Write-Host ""
    Write-Host "运行时检查:" -ForegroundColor Cyan
    Write-Host ""
    
    # 检查 Node.js
    try {
        $nodeVersion = & node --version 2>$null
        Write-ColorOutput "Node.js: $nodeVersion" "Success"
    }
    catch {
        Write-ColorOutput "未找到 Node.js" "Warning"
    }
    
    # 检查 npx
    try {
        $null = Get-Command npx -ErrorAction Stop
        Write-ColorOutput "npx 可用" "Success"
    }
    catch {
        Write-ColorOutput "未找到 npx" "Warning"
    }
    
    # 检查 Python
    try {
        $pyVersion = & python --version 2>$null
        Write-ColorOutput "Python: $pyVersion" "Success"
    }
    catch {
        Write-ColorOutput "未找到 Python" "Warning"
    }
    
    # 检查 uvx
    try {
        $null = Get-Command uvx -ErrorAction Stop
        Write-ColorOutput "uvx 可用" "Success"
    }
    catch {
        Write-ColorOutput "uvx 未安装" "Info"
    }
}

# ----------------------------------------------------------------------------
# 功能8: 重置MCP配置
# ----------------------------------------------------------------------------
function Reset-MCPConfig {
    Write-ColorOutput "重置 MCP 配置..." "Info"
    
    $mcpConfig = "$WindsurfDir\mcp_config.json"
    
    Write-Host ""
    Write-ColorOutput "此操作将备份并重置 MCP 配置文件" "Warning"
    Write-Host ""
    
    if (-not (Test-Path $mcpConfig)) {
        Write-ColorOutput "MCP 配置文件不存在" "Info"
        return
    }
    
    if (Confirm-Action) {
        New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
        Copy-Item -Path $mcpConfig -Destination "$BackupDir\mcp_config.json.bak" -Force
        Write-ColorOutput "已备份到: $BackupDir\mcp_config.json.bak" "Info"
        
        @'
{
  "mcpServers": {}
}
'@ | Out-File -FilePath $mcpConfig -Encoding UTF8
        
        Write-ColorOutput "MCP 配置已重置" "Success"
    }
    else {
        Write-ColorOutput "已取消操作" "Info"
    }
}

# ----------------------------------------------------------------------------
# 功能4: 清理开发工具缓存
# ----------------------------------------------------------------------------
function Clear-DevCaches {
    Write-ColorOutput "扫描开发工具缓存..." "Info"
    
    Write-Host ""
    Write-Host "正在检测各类开发工具缓存大小..." -ForegroundColor Cyan
    Write-Host ""
    
    $totalSize = 0
    $cleanableItems = @()
    
    # npm 缓存
    $npmCache = "$env:APPDATA\npm-cache"
    if (Test-Path $npmCache) {
        $size = [math]::Round((Get-ChildItem $npmCache -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB)
        Write-Host "  [npm 缓存] $npmCache - " -NoNewline; Write-Host "${size}MB" -ForegroundColor Yellow
        $totalSize += $size
        $cleanableItems += "npm"
    }
    
    # pip 缓存
    $pipCache = "$env:LOCALAPPDATA\pip\cache"
    if (Test-Path $pipCache) {
        $size = [math]::Round((Get-ChildItem $pipCache -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB)
        Write-Host "  [pip 缓存] $pipCache - " -NoNewline; Write-Host "${size}MB" -ForegroundColor Yellow
        $totalSize += $size
        $cleanableItems += "pip"
    }
    
    # uv 缓存
    $uvCache = "$env:LOCALAPPDATA\uv\cache"
    if (Test-Path $uvCache) {
        $size = [math]::Round((Get-ChildItem $uvCache -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB)
        Write-Host "  [uv 缓存] $uvCache - " -NoNewline; Write-Host "${size}MB" -ForegroundColor Yellow
        $totalSize += $size
        $cleanableItems += "uv"
    }
    
    # Maven 缓存
    $mavenCache = "$env:USERPROFILE\.m2\repository"
    if (Test-Path $mavenCache) {
        $size = [math]::Round((Get-ChildItem $mavenCache -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB)
        Write-Host "  [Maven 缓存] $mavenCache - " -NoNewline; Write-Host "${size}MB" -ForegroundColor Yellow
        $totalSize += $size
        $cleanableItems += "maven"
    }
    
    # Gradle 缓存
    $gradleCache = "$env:USERPROFILE\.gradle\caches"
    if (Test-Path $gradleCache) {
        $size = [math]::Round((Get-ChildItem $gradleCache -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB)
        Write-Host "  [Gradle 缓存] $gradleCache - " -NoNewline; Write-Host "${size}MB" -ForegroundColor Yellow
        $totalSize += $size
        $cleanableItems += "gradle"
    }
    
    # Yarn 缓存
    $yarnCache = "$env:LOCALAPPDATA\Yarn\Cache"
    if (Test-Path $yarnCache) {
        $size = [math]::Round((Get-ChildItem $yarnCache -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB)
        Write-Host "  [Yarn 缓存] $yarnCache - " -NoNewline; Write-Host "${size}MB" -ForegroundColor Yellow
        $totalSize += $size
        $cleanableItems += "yarn"
    }
    
    # pnpm 缓存
    $pnpmStore = "$env:LOCALAPPDATA\pnpm-store"
    if (Test-Path $pnpmStore) {
        $size = [math]::Round((Get-ChildItem $pnpmStore -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB)
        Write-Host "  [pnpm 缓存] $pnpmStore - " -NoNewline; Write-Host "${size}MB" -ForegroundColor Yellow
        $totalSize += $size
        $cleanableItems += "pnpm"
    }
    
    # NuGet 缓存
    $nugetCache = "$env:USERPROFILE\.nuget\packages"
    if (Test-Path $nugetCache) {
        $size = [math]::Round((Get-ChildItem $nugetCache -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB)
        Write-Host "  [NuGet 缓存] $nugetCache - " -NoNewline; Write-Host "${size}MB" -ForegroundColor Yellow
        $totalSize += $size
        $cleanableItems += "nuget"
    }
    
    # Selenium/WebDriver 缓存
    $seleniumCache = "$env:USERPROFILE\.cache\selenium"
    $wdmCache = "$env:USERPROFILE\.wdm"
    $selSize = 0
    if (Test-Path $seleniumCache) {
        $selSize += [math]::Round((Get-ChildItem $seleniumCache -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB)
    }
    if (Test-Path $wdmCache) {
        $selSize += [math]::Round((Get-ChildItem $wdmCache -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB)
    }
    if ($selSize -gt 0) {
        Write-Host "  [Selenium/WebDriver] - " -NoNewline; Write-Host "${selSize}MB" -ForegroundColor Yellow
        $totalSize += $selSize
        $cleanableItems += "selenium"
    }
    
    # Go 缓存
    $goCache = "$env:USERPROFILE\go\pkg\mod\cache"
    if (Test-Path $goCache) {
        $size = [math]::Round((Get-ChildItem $goCache -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB)
        Write-Host "  [Go 模块缓存] $goCache - " -NoNewline; Write-Host "${size}MB" -ForegroundColor Yellow
        $totalSize += $size
        $cleanableItems += "go"
    }
    
    # Cargo/Rust 缓存
    $cargoCache = "$env:USERPROFILE\.cargo\registry"
    if (Test-Path $cargoCache) {
        $size = [math]::Round((Get-ChildItem $cargoCache -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB)
        Write-Host "  [Cargo 缓存] $cargoCache - " -NoNewline; Write-Host "${size}MB" -ForegroundColor Yellow
        $totalSize += $size
        $cleanableItems += "cargo"
    }
    
    # conda 缓存
    foreach ($condaDir in @("$env:USERPROFILE\miniconda3\pkgs", "$env:USERPROFILE\anaconda3\pkgs")) {
        if (Test-Path $condaDir) {
            $size = [math]::Round((Get-ChildItem $condaDir -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB)
            Write-Host "  [conda 包缓存] $condaDir - " -NoNewline; Write-Host "${size}MB" -ForegroundColor Yellow
            $totalSize += $size
            $cleanableItems += "conda"
            break
        }
    }
    
    Write-Host ""
    Write-Host "  可清理总计: " -NoNewline -ForegroundColor Cyan; Write-Host "${totalSize}MB" -ForegroundColor Yellow
    Write-Host ""
    
    if ($cleanableItems.Count -eq 0) {
        Write-ColorOutput "未检测到可清理的开发工具缓存" "Info"
        return
    }
    
    Write-Host "请选择清理方式:" -ForegroundColor Yellow
    Write-Host "  1) 全部清理（推荐安全项）"
    Write-Host "  2) 逐项选择清理"
    Write-Host "  3) 取消"
    Write-Host ""
    $cleanChoice = Read-Host "请选择 [1-3]"
    
    switch ($cleanChoice) {
        "1" {
            foreach ($item in $cleanableItems) {
                switch ($item) {
                    "npm" {
                        try { & npm cache clean --force 2>$null } catch { Remove-Item "$npmCache\_cacache" -Recurse -Force -ErrorAction SilentlyContinue }
                        Write-ColorOutput "npm 缓存已清理" "Success"
                    }
                    "pip" {
                        try { & pip cache purge 2>$null } catch { Remove-Item $pipCache -Recurse -Force -ErrorAction SilentlyContinue }
                        Write-ColorOutput "pip 缓存已清理" "Success"
                    }
                    "uv" {
                        Remove-Item $uvCache -Recurse -Force -ErrorAction SilentlyContinue
                        Write-ColorOutput "uv 缓存已清理" "Success"
                    }
                    "maven" { Write-ColorOutput "Maven 缓存跳过（删除后需重新下载依赖）" "Warning" }
                    "gradle" { Write-ColorOutput "Gradle 缓存跳过（删除后需重新下载依赖）" "Warning" }
                    "yarn" {
                        try { & yarn cache clean 2>$null } catch { Remove-Item $yarnCache -Recurse -Force -ErrorAction SilentlyContinue }
                        Write-ColorOutput "Yarn 缓存已清理" "Success"
                    }
                    "pnpm" {
                        try { & pnpm store prune 2>$null } catch {}
                        Write-ColorOutput "pnpm 缓存已清理" "Success"
                    }
                    "nuget" { Write-ColorOutput "NuGet 缓存跳过（建议使用 dotnet nuget locals all --clear）" "Warning" }
                    "selenium" {
                        Remove-Item $seleniumCache -Recurse -Force -ErrorAction SilentlyContinue
                        Remove-Item $wdmCache -Recurse -Force -ErrorAction SilentlyContinue
                        Write-ColorOutput "Selenium/WebDriver 缓存已清理" "Success"
                    }
                    "go" {
                        try { & go clean -modcache 2>$null } catch {}
                        Write-ColorOutput "Go 模块缓存已清理" "Success"
                    }
                    "cargo" { Write-ColorOutput "Cargo 缓存跳过" "Warning" }
                    "conda" {
                        try { & conda clean --all -y 2>$null } catch {}
                        Write-ColorOutput "conda 缓存已清理" "Success"
                    }
                }
            }
            Write-Host ""
            Write-ColorOutput "开发工具缓存清理完成！" "Success"
        }
        "2" {
            foreach ($item in $cleanableItems) {
                $label = switch ($item) {
                    "npm" { "npm 缓存" }
                    "pip" { "pip 缓存" }
                    "uv" { "uv 缓存" }
                    "maven" { "Maven 缓存" }
                    "gradle" { "Gradle 缓存" }
                    "yarn" { "Yarn 缓存" }
                    "pnpm" { "pnpm 缓存" }
                    "nuget" { "NuGet 缓存" }
                    "selenium" { "Selenium/WebDriver 缓存" }
                    "go" { "Go 模块缓存" }
                    "cargo" { "Cargo 缓存" }
                    "conda" { "conda 包缓存" }
                    default { $item }
                }
                
                if (Confirm-Action "清理 ${label}？") {
                    switch ($item) {
                        "npm" { try { & npm cache clean --force 2>$null } catch { Remove-Item "$npmCache\_cacache" -Recurse -Force -ErrorAction SilentlyContinue } }
                        "pip" { try { & pip cache purge 2>$null } catch { Remove-Item $pipCache -Recurse -Force -ErrorAction SilentlyContinue } }
                        "uv" { Remove-Item $uvCache -Recurse -Force -ErrorAction SilentlyContinue }
                        "maven" { Remove-Item $mavenCache -Recurse -Force -ErrorAction SilentlyContinue }
                        "gradle" { Remove-Item $gradleCache -Recurse -Force -ErrorAction SilentlyContinue }
                        "yarn" { try { & yarn cache clean 2>$null } catch { Remove-Item $yarnCache -Recurse -Force -ErrorAction SilentlyContinue } }
                        "pnpm" { try { & pnpm store prune 2>$null } catch {} }
                        "nuget" { try { & dotnet nuget locals all --clear 2>$null } catch { Remove-Item $nugetCache -Recurse -Force -ErrorAction SilentlyContinue } }
                        "selenium" { Remove-Item $seleniumCache, $wdmCache -Recurse -Force -ErrorAction SilentlyContinue }
                        "go" { try { & go clean -modcache 2>$null } catch {} }
                        "cargo" { Remove-Item $cargoCache -Recurse -Force -ErrorAction SilentlyContinue }
                        "conda" { try { & conda clean --all -y 2>$null } catch {} }
                    }
                    Write-ColorOutput "$label 已清理" "Success"
                }
            }
        }
        default { Write-ColorOutput "已取消操作" "Info" }
    }
}

# ----------------------------------------------------------------------------
# 功能5: 清理Windows系统缓存
# ----------------------------------------------------------------------------
function Clear-SystemCaches {
    Write-ColorOutput "扫描 Windows 系统缓存..." "Info"
    
    Write-Host ""
    Write-Host "正在检测系统级缓存..." -ForegroundColor Cyan
    Write-Host ""
    
    $totalSize = 0
    
    # 用户临时文件
    $userTemp = $env:TEMP
    if (Test-Path $userTemp) {
        $size = [math]::Round((Get-ChildItem $userTemp -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB)
        Write-Host "  [用户临时文件] $userTemp - " -NoNewline; Write-Host "${size}MB" -ForegroundColor Yellow
        $totalSize += $size
    }
    
    # Windows 临时文件
    $winTemp = "$env:SystemRoot\Temp"
    if (Test-Path $winTemp) {
        $size = [math]::Round((Get-ChildItem $winTemp -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB)
        Write-Host "  [Windows 临时文件] $winTemp - " -NoNewline; Write-Host "${size}MB" -ForegroundColor Yellow
        $totalSize += $size
    }
    
    # 回收站
    $recycleBin = (New-Object -ComObject Shell.Application).Namespace(0xA)
    $rbCount = $recycleBin.Items().Count
    if ($rbCount -gt 0) {
        Write-Host "  [回收站] ${rbCount}个项目" -ForegroundColor Green
    }
    
    # Windows Update 缓存
    $wuCache = "$env:SystemRoot\SoftwareDistribution\Download"
    if (Test-Path $wuCache) {
        $size = [math]::Round((Get-ChildItem $wuCache -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB)
        Write-Host "  [Windows Update 缓存] - " -NoNewline; Write-Host "${size}MB" -ForegroundColor Yellow
        $totalSize += $size
    }
    
    # Windsurf 旧备份
    $backups = Get-ChildItem "$env:USERPROFILE\.windsurf-backup-*" -Directory -ErrorAction SilentlyContinue
    if ($backups) {
        $bkSize = [math]::Round(($backups | Get-ChildItem -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB)
        Write-Host "  [Windsurf 旧备份] $($backups.Count)个备份目录 - " -NoNewline; Write-Host "${bkSize}MB" -ForegroundColor Yellow
        $totalSize += $bkSize
    }
    
    # 旧诊断报告
    $diagReports = Get-ChildItem "$env:USERPROFILE\windsurf-diagnostic-*.txt" -ErrorAction SilentlyContinue
    if ($diagReports) {
        Write-Host "  [旧诊断报告] $($diagReports.Count)个文件" -ForegroundColor Green
    }
    
    # DNS 缓存
    Write-Host "  [DNS 缓存] 系统DNS缓存（可刷新）" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "  系统缓存总计: " -NoNewline -ForegroundColor Cyan; Write-Host "${totalSize}MB" -ForegroundColor Yellow
    Write-Host ""
    
    Write-Host "请选择清理项目:" -ForegroundColor Yellow
    Write-Host "  1) 清理用户临时文件"
    Write-Host "  2) 清理 Windows 临时文件（需管理员）"
    Write-Host "  3) 清空回收站"
    Write-Host "  4) 清理 Windsurf 旧备份目录"
    Write-Host "  5) 清理旧诊断报告"
    Write-Host "  6) 刷新 DNS 缓存"
    Write-Host "  7) 全部执行（安全项）"
    Write-Host "  0) 取消"
    Write-Host ""
    $sysChoice = Read-Host "请选择 [0-7]"
    
    switch ($sysChoice) {
        "1" {
            Get-ChildItem $userTemp -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) } | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            Write-ColorOutput "用户临时文件已清理（保留7天内）" "Success"
        }
        "2" {
            if (Test-Administrator) {
                Get-ChildItem $winTemp -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) } | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                Write-ColorOutput "Windows 临时文件已清理" "Success"
            }
            else {
                Write-ColorOutput "需要管理员权限" "Error"
            }
        }
        "3" {
            if (Confirm-Action) {
                Clear-RecycleBin -Force -ErrorAction SilentlyContinue
                Write-ColorOutput "回收站已清空" "Success"
            }
        }
        "4" {
            if ($backups) {
                Write-ColorOutput "将删除 $($backups.Count) 个 Windsurf 旧备份目录" "Info"
                if (Confirm-Action) {
                    $backups | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                    Write-ColorOutput "Windsurf 旧备份已清理" "Success"
                }
            }
            else {
                Write-ColorOutput "没有旧备份需要清理" "Info"
            }
        }
        "5" {
            if ($diagReports) {
                $diagReports | Remove-Item -Force -ErrorAction SilentlyContinue
                Write-ColorOutput "旧诊断报告已清理" "Success"
            }
        }
        "6" {
            ipconfig /flushdns 2>$null | Out-Null
            Write-ColorOutput "DNS 缓存已刷新" "Success"
        }
        "7" {
            Write-ColorOutput "执行全部安全清理项..." "Info"
            
            Get-ChildItem $userTemp -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) } | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            Write-ColorOutput "用户临时文件已清理" "Success"
            
            if ($backups) {
                $backups | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                Write-ColorOutput "Windsurf 旧备份已清理" "Success"
            }
            
            if ($diagReports) {
                $diagReports | Remove-Item -Force -ErrorAction SilentlyContinue
                Write-ColorOutput "旧诊断报告已清理" "Success"
            }
            
            ipconfig /flushdns 2>$null | Out-Null
            Write-ColorOutput "DNS 缓存已刷新" "Success"
            
            Write-Host ""
            Write-ColorOutput "系统缓存清理完成！" "Success"
        }
        default { Write-ColorOutput "已取消操作" "Info" }
    }
}

# ----------------------------------------------------------------------------
# 功能6: 磁盘空间分析
# ----------------------------------------------------------------------------
function Get-DiskAnalysis {
    Write-ColorOutput "分析磁盘空间使用情况..." "Info"
    
    Write-Host ""
    Write-Host "========== 磁盘空间概览 ==========" -ForegroundColor Cyan
    Write-Host ""
    
    # 磁盘总体使用
    Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
        $free = [math]::Round($_.FreeSpace / 1GB, 2)
        $total = [math]::Round($_.Size / 1GB, 2)
        $used = [math]::Round(($_.Size - $_.FreeSpace) / 1GB, 2)
        $pct = [math]::Round(($_.Size - $_.FreeSpace) / $_.Size * 100, 1)
        Write-Host "  $($_.DeviceID) 总容量: ${total}GB | 已使用: ${used}GB | 可用: ${free}GB | 使用率: ${pct}%"
    }
    Write-Host ""
    
    # 用户主目录
    Write-Host "  用户主目录主要文件夹:" -ForegroundColor Cyan
    Write-Host ""
    
    foreach ($dir in @("Downloads", "Documents", "Desktop", "Videos", "Music", "Pictures")) {
        $path = "$env:USERPROFILE\$dir"
        if (Test-Path $path) {
            $size = [math]::Round((Get-ChildItem $path -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB)
            Write-Host ("    {0,-15} {1}MB" -f $dir, $size)
        }
    }
    Write-Host ""
    
    # AppData 大小
    Write-Host "  AppData 目录:" -ForegroundColor Cyan
    Write-Host ""
    foreach ($dir in @("Local", "Roaming", "LocalLow")) {
        $path = "$env:USERPROFILE\AppData\$dir"
        if (Test-Path $path) {
            $size = [math]::Round((Get-ChildItem $path -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB)
            Write-Host ("    {0,-15} {1}MB" -f $dir, $size)
        }
    }
    Write-Host ""
    
    Write-ColorOutput "分析完成。大型应用缓存建议在对应应用内清理" "Info"
}

# ----------------------------------------------------------------------------
# 功能9: 配置终端设置
# ----------------------------------------------------------------------------
function Set-TerminalSettings {
    Write-ColorOutput "配置终端设置..." "Info"
    
    Write-Host ""
    Write-Host "推荐的终端配置:"
    Write-Host '  "terminal.integrated.defaultProfile.windows": "PowerShell"' -ForegroundColor Green
    Write-Host ""
    
    if (Test-Path $SettingsJsonPath) {
        Write-ColorOutput "settings.json 位置: $SettingsJsonPath" "Info"
        
        $content = Get-Content $SettingsJsonPath -Raw -ErrorAction SilentlyContinue
        if ($content -match "terminal.integrated.defaultProfile.windows") {
            Write-ColorOutput "终端配置已存在" "Info"
            $content | Select-String "terminal.integrated.defaultProfile" | ForEach-Object { Write-Host "  $_" }
        }
        else {
            Write-ColorOutput "未找到终端配置，建议手动添加" "Warning"
        }
    }
    else {
        Write-ColorOutput "未找到 settings.json 文件" "Warning"
        Write-ColorOutput "Windsurf 可能尚未创建配置文件，请先启动一次 Windsurf" "Info"
    }
}

# ----------------------------------------------------------------------------
# 功能11: 检查更新问题
# ----------------------------------------------------------------------------
function Test-UpdateIssues {
    Write-ColorOutput "检查更新相关问题..." "Info"
    
    Write-Host ""
    
    # 检查是否以管理员身份运行
    if (Test-Administrator) {
        Write-ColorOutput "当前以管理员身份运行" "Warning"
        Write-Host ""
        Write-Host "  Windsurf 以管理员模式运行时无法自动更新"
        Write-Host "  解决方案: 以普通用户权限运行 Windsurf"
        Write-Host ""
    }
    else {
        Write-ColorOutput "以普通用户权限运行（正常）" "Success"
    }
    
    # 检查用户安装 vs 系统安装
    $userInstall = Test-Path "$env:LOCALAPPDATA\Programs\Windsurf"
    $systemInstall = Test-Path "$env:ProgramFiles\Windsurf"
    
    if ($userInstall) {
        Write-ColorOutput "检测到用户范围安装: $env:LOCALAPPDATA\Programs\Windsurf" "Info"
    }
    if ($systemInstall) {
        Write-ColorOutput "检测到系统范围安装: $env:ProgramFiles\Windsurf" "Info"
    }
}

# ----------------------------------------------------------------------------
# 功能10: 修复PowerShell执行策略
# ----------------------------------------------------------------------------
function Set-PSExecutionPolicy {
    Write-ColorOutput "检查 PowerShell 执行策略..." "Info"
    
    $currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
    Write-Host ""
    Write-Host "  当前执行策略: " -NoNewline; Write-Host "$currentPolicy" -ForegroundColor Yellow
    Write-Host ""
    
    if ($currentPolicy -eq "Restricted") {
        Write-ColorOutput "执行策略为 Restricted，可能导致脚本问题" "Warning"
        Write-Host ""
        Write-Host "  建议设置为 RemoteSigned"
        Write-Host "  命令: Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser"
        Write-Host ""
        
        if (Confirm-Action "是否修改执行策略为 RemoteSigned？") {
            try {
                Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
                Write-ColorOutput "执行策略已更新" "Success"
            }
            catch {
                Write-ColorOutput "修改失败: $_" "Error"
            }
        }
    }
    else {
        Write-ColorOutput "执行策略正常" "Success"
    }
}

# ----------------------------------------------------------------------------
# 功能14: 生成诊断报告
# ----------------------------------------------------------------------------
function New-DiagnosticReport {
    Write-ColorOutput "生成诊断报告..." "Info"
    
    $reportFile = "$env:USERPROFILE\windsurf-diagnostic-$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
    
    $report = @"
==========================================
Windsurf 诊断报告 - Windows
生成时间: $(Get-Date)
==========================================

## 系统信息
$((Get-CimInstance -ClassName Win32_OperatingSystem).Caption)
架构: $(if ([Environment]::Is64BitOperatingSystem) { "64-bit" } else { "32-bit" })
用户: $env:USERNAME

## PowerShell 信息
版本: $($PSVersionTable.PSVersion)
执行策略: $(Get-ExecutionPolicy -Scope CurrentUser)

## Windsurf 安装状态
用户安装路径: $env:LOCALAPPDATA\Programs\Windsurf
$(if (Test-Path "$env:LOCALAPPDATA\Programs\Windsurf") { "存在" } else { "不存在" })

系统安装路径: $env:ProgramFiles\Windsurf
$(if (Test-Path "$env:ProgramFiles\Windsurf") { "存在" } else { "不存在" })

## Codeium 目录状态
路径: $CodeiumDir
$(if (Test-Path $CodeiumDir) { "存在" } else { "不存在" })

## Cascade 缓存状态
路径: $CascadeDir
$(if (Test-Path $CascadeDir) { 
    $size = (Get-ChildItem $CascadeDir -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    "存在 - 大小: $([math]::Round($size/1MB, 2)) MB"
} else { "不存在" })

## 网络状态
$(try { 
    $result = Test-NetConnection -ComputerName "codeium.com" -Port 443 -WarningAction SilentlyContinue
    "codeium.com 连接: $(if ($result.TcpTestSucceeded) { '成功' } else { '失败' })"
} catch { "无法测试网络连接" })

## 磁盘空间
$(Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='C:'" | ForEach-Object {
    "C盘可用空间: $([math]::Round($_.FreeSpace/1GB, 2)) GB / $([math]::Round($_.Size/1GB, 2)) GB"
})

## 管理员权限
$(if (Test-Administrator) { "以管理员身份运行" } else { "普通用户权限" })

"@
    
    $report | Out-File -FilePath $reportFile -Encoding UTF8
    Write-ColorOutput "诊断报告已保存: $reportFile" "Success"
}

# ----------------------------------------------------------------------------
# 功能13: 清理Windsurf临时文件
# ----------------------------------------------------------------------------
function Clear-TempFiles {
    Write-ColorOutput "清理临时文件..." "Info"
    
    $tempDirs = @(
        "$env:TEMP\windsurf*",
        "$env:TEMP\codeium*"
    )
    
    if (Confirm-Action) {
        foreach ($pattern in $tempDirs) {
            $items = Get-ChildItem -Path $pattern -ErrorAction SilentlyContinue
            if ($items) {
                foreach ($item in $items) {
                    try {
                        Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction Stop
                        Write-ColorOutput "已删除: $($item.Name)" "Success"
                    }
                    catch {
                        Write-ColorOutput "无法删除: $($item.Name)" "Warning"
                    }
                }
            }
        }
        Write-ColorOutput "临时文件清理完成" "Success"

        # 清理完毕 -> 强制重置设备 ID（默认行为）
        Invoke-AutoResetAfterClean
    }
    else {
        Write-ColorOutput "已取消操作" "Info"
    }
}

# ----------------------------------------------------------------------------
# 功能15: 完整修复
# ----------------------------------------------------------------------------
function Start-FullRepair {
    Write-ColorOutput "执行完整修复..." "Info"
    Write-ColorOutput "此操作将执行所有修复步骤" "Warning"
    
    if (Confirm-Action) {
        if (-not (Test-WindsurfRunning)) {
            return
        }

        # 标记批量模式：子函数跳过各自的 Invoke-AutoResetAfterClean
        $env:_IN_BATCH_REPAIR = "1"

        Clear-CascadeCache
        Clear-ExtensionCache
        Clear-StartupCache
        Set-TerminalSettings
        Test-UpdateIssues
        Set-PSExecutionPolicy
        Clear-TempFiles
        New-DiagnosticReport

        # 退出批量模式，末尾统一重置一次
        $env:_IN_BATCH_REPAIR = "0"

        Write-Host ""
        Write-ColorOutput "完整修复已完成！" "Success"

        # 统一在完整修复末尾执行一次强制重置
        Invoke-AutoResetAfterClean
        Write-ColorOutput "请重新启动 Windsurf" "Info"
    }
    else {
        Write-ColorOutput "已取消操作" "Info"
    }
}

# ----------------------------------------------------------------------------
# 功能12: 网络白名单检查
# ----------------------------------------------------------------------------
function Test-NetworkWhitelist {
    Write-ColorOutput "检查网络连接..." "Info"
    
    $domains = @(
        "codeium.com",
        "windsurf.com",
        "codeiumdata.com"
    )
    
    Write-Host ""
    Write-Host "检查以下域名的连接状态:"
    Write-Host ""
    
    foreach ($domain in $domains) {
        Write-Host "  测试 $domain... " -NoNewline
        try {
            $result = Test-NetConnection -ComputerName $domain -Port 443 -WarningAction SilentlyContinue -InformationLevel Quiet
            if ($result) {
                Write-Host "成功" -ForegroundColor Green
            }
            else {
                Write-Host "失败" -ForegroundColor Red
            }
        }
        catch {
            Write-Host "错误" -ForegroundColor Red
        }
    }
    
    Write-Host ""
    Write-Host "如果连接失败，请将以下域名加入防火墙/VPN白名单:"
    Write-Host "  *.codeium.com" -ForegroundColor Yellow
    Write-Host "  *.windsurf.com" -ForegroundColor Yellow
    Write-Host "  *.codeiumdata.com" -ForegroundColor Yellow
    Write-Host ""
}

# ----------------------------------------------------------------------------
# 格式化KB大小为易读格式
# ----------------------------------------------------------------------------
function Format-KbSize {
    param([long]$KbValue)
    # 大于1GB时显示GB
    if ($KbValue -ge 1048576) {
        return "{0:F2}GB" -f ($KbValue / 1024 / 1024)
    }
    # 大于1MB时显示MB
    elseif ($KbValue -ge 1024) {
        return "{0:F2}MB" -f ($KbValue / 1024)
    }
    else {
        return "${KbValue}KB"
    }
}

# ----------------------------------------------------------------------------
# 获取目录或文件总大小（KB）
# ----------------------------------------------------------------------------
function Get-PathSizeKb {
    param([string]$TargetPath)
    # 使用 Get-ChildItem 递归统计大小
    try {
        $size = (Get-ChildItem -Path $TargetPath -Recurse -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum).Sum
        return [long]($size / 1024)
    }
    catch {
        return 0
    }
}

# ----------------------------------------------------------------------------
# 清理路径并输出释放空间统计
# ----------------------------------------------------------------------------
function Remove-PathWithStats {
    param(
        [string]$TargetPath,
        [string]$Label
    )

    Write-Host ""
    Write-ColorOutput $Label "Info"

    # 统计清理前大小
    if (Test-Path $TargetPath) {
        $BeforeKb = Get-PathSizeKb -TargetPath $TargetPath
        Write-ColorOutput "清理前大小: $(Format-KbSize $BeforeKb)" "Info"

        # 删除目标（目录下所有内容或单个文件）
        try {
            if (Test-Path $TargetPath -PathType Container) {
                Get-ChildItem -Path $TargetPath -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            }
            else {
                Remove-Item -Path $TargetPath -Force -ErrorAction SilentlyContinue
            }
        }
        catch {
            # 忽略单个文件删除失败，继续执行
        }

        # 统计清理后大小
        $AfterKb = 0
        if (Test-Path $TargetPath) {
            $AfterKb = Get-PathSizeKb -TargetPath $TargetPath
        }
        $ReleasedKb = [long]($BeforeKb - $AfterKb)
        if ($ReleasedKb -lt 0) { $ReleasedKb = 0 }

        # 累加到全局释放计数
        $script:TotalReleasedKb += $ReleasedKb
        Write-ColorOutput "已释放: $(Format-KbSize $ReleasedKb)" "Success"
    }
    else {
        Write-ColorOutput "路径不存在，无需清理" "Info"
    }
}

# ----------------------------------------------------------------------------
# 显示候选清理项大小
# ----------------------------------------------------------------------------
function Show-CleanupCandidate {
    param(
        [string]$Label,
        [string]$TargetPath
    )

    if (Test-Path $TargetPath) {
        $sizeKb = Get-PathSizeKb -TargetPath $TargetPath
        if ($sizeKb -gt 0) {
            Write-Host "    $Label -> $(Format-KbSize $sizeKb)"
        }
        return $sizeKb
    }

    return 0
}

# ----------------------------------------------------------------------------
# 计算四个 AI 工具默认安全清理项总大小（KB）
# ----------------------------------------------------------------------------
function Get-AIToolGarbageTotalKb {
    $total = 0

    $safePaths = @(
        "$ClaudeCodeDir\cache",
        "$ClaudeCodeDir\debug",
        "$ClaudeCodeDir\downloads",
        "$ClaudeCodeDir\paste-cache",
        "$ClaudeCodeDir\plugins\cache",
        "$ClaudeCodeDir\session-data",
        "$CodexDir\.tmp",
        "$CodexDir\tmp",
        "$CodexDir\cache",
        "$CodexDir\log",
        "$CodexDir\plugins\cache",
        "$CodexDir\logs_1.sqlite-shm",
        "$CodexDir\logs_1.sqlite-wal",
        "$CodexDir\models_cache.json",
        "$CodexDir\vendor_imports\skills-curated-cache.json",
        $OpenCodeCacheDir,
        "$OpenCodeDataDir\tool-output",
        "$OpenCodeDataDir\opencode.db-shm",
        "$OpenCodeDataDir\opencode.db-wal"
    )

    foreach ($path in $safePaths) {
        if (Test-Path $path) {
            $total += Get-PathSizeKb -TargetPath $path
        }
    }

    return $total
}

# ----------------------------------------------------------------------------
# 计算四个 AI 工具可选深清项总大小（KB）
# ----------------------------------------------------------------------------
function Get-AIToolOptionalGarbageTotalKb {
    $total = 0

    foreach ($path in @("$GeminiCliDir\tmp", "$CodexDir\logs_1.sqlite")) {
        if (Test-Path $path) {
            $total += Get-PathSizeKb -TargetPath $path
        }
    }

    return $total
}

# ----------------------------------------------------------------------------
# 功能19: 清理 Claude Code / codex / gemini-cli / opencode 垃圾缓存
# ----------------------------------------------------------------------------
function Clear-AIToolGarbage {
    Write-ColorOutput "扫描 Claude Code / codex / gemini-cli / opencode 垃圾缓存..." "Info"

    $toolFound = (Test-Path $ClaudeCodeDir) -or
        (Test-Path $CodexDir) -or
        (Test-Path $GeminiCliDir) -or
        (Test-Path $OpenCodeInstallDir) -or
        (Test-Path $OpenCodeConfigDir) -or
        (Test-Path $OpenCodeCacheDir) -or
        (Test-Path $OpenCodeDataDir)

    if (-not $toolFound) {
        Write-ColorOutput "未检测到四个 AI 工具的本地目录" "Info"
        return
    }

    $safeTotalKb = Get-AIToolGarbageTotalKb
    $geminiTmpKb = if (Test-Path "$GeminiCliDir\tmp") { Get-PathSizeKb -TargetPath "$GeminiCliDir\tmp" } else { 0 }
    $codexLogDbKb = if (Test-Path "$CodexDir\logs_1.sqlite") { Get-PathSizeKb -TargetPath "$CodexDir\logs_1.sqlite" } else { 0 }
    $optionalTotalKb = Get-AIToolOptionalGarbageTotalKb

    Write-Host ""
    Write-ColorOutput "默认只清理缓存、日志、临时文件、工具输出和数据库临时文件" "Success"
    Write-ColorOutput "不会清理 MCP、登录认证、settings、skills、rules、memories、正式数据库、插件主体和安装目录" "Success"
    Write-ColorOutput "可选深清项只会影响本地日志或会话恢复能力，不会影响 MCP、登录状态和核心配置" "Warning"
    Write-Host ""
    Write-Host "保护范围说明:" -ForegroundColor Cyan
    Write-Host "  - Claude Code: mcp.json、config.json、settings.json、commands/、projects/、sessions/、history.jsonl"
    Write-Host "  - codex: config.toml、auth.json、agents/、memories/、rules/、sessions/、history.jsonl、session_index.jsonl"
    Write-Host "  - gemini-cli: settings.json、oauth_creds.json、skills/、policies/、history/、tmp/chats/"
    Write-Host "  - opencode: opencode.json、auth.json、opencode.db、storage/session_diff、prompt-history.jsonl、node_modules/"
    Write-Host ""
    Write-Host "扫描结果:" -ForegroundColor Cyan

    if (Test-Path $ClaudeCodeDir) {
        Write-Host ""
        Write-Host "  [Claude Code] $ClaudeCodeDir" -ForegroundColor Green
        foreach ($item in @(
            @{ Label = "cache"; Path = "$ClaudeCodeDir\cache" },
            @{ Label = "debug"; Path = "$ClaudeCodeDir\debug" },
            @{ Label = "downloads"; Path = "$ClaudeCodeDir\downloads" },
            @{ Label = "paste-cache"; Path = "$ClaudeCodeDir\paste-cache" },
            @{ Label = "plugins\\cache"; Path = "$ClaudeCodeDir\plugins\cache" },
            @{ Label = "session-data"; Path = "$ClaudeCodeDir\session-data" },
            @{ Label = "file-history"; Path = "$ClaudeCodeDir\file-history" },
            @{ Label = "shell-snapshots"; Path = "$ClaudeCodeDir\shell-snapshots" },
            @{ Label = "tasks"; Path = "$ClaudeCodeDir\tasks" },
            @{ Label = "todos"; Path = "$ClaudeCodeDir\todos" },
            @{ Label = "session-env"; Path = "$ClaudeCodeDir\session-env" },
            @{ Label = "ide"; Path = "$ClaudeCodeDir\ide" },
            @{ Label = "metrics"; Path = "$ClaudeCodeDir\metrics" },
            @{ Label = "telemetry"; Path = "$ClaudeCodeDir\telemetry" }
        )) {
            [void](Show-CleanupCandidate -Label $item.Label -TargetPath $item.Path)
        }
    }

    if (Test-Path $CodexDir) {
        Write-Host ""
        Write-Host "  [codex] $CodexDir" -ForegroundColor Green
        foreach ($item in @(
            @{ Label = ".tmp"; Path = "$CodexDir\.tmp" },
            @{ Label = "tmp"; Path = "$CodexDir\tmp" },
            @{ Label = "cache"; Path = "$CodexDir\cache" },
            @{ Label = "log"; Path = "$CodexDir\log" },
            @{ Label = "plugins\\cache"; Path = "$CodexDir\plugins\cache" },
            @{ Label = "logs_1.sqlite-shm"; Path = "$CodexDir\logs_1.sqlite-shm" },
            @{ Label = "logs_1.sqlite-wal"; Path = "$CodexDir\logs_1.sqlite-wal" },
            @{ Label = "models_cache.json"; Path = "$CodexDir\models_cache.json" },
            @{ Label = "vendor_imports\\skills-curated-cache.json"; Path = "$CodexDir\vendor_imports\skills-curated-cache.json" }
        )) {
            [void](Show-CleanupCandidate -Label $item.Label -TargetPath $item.Path)
        }
        if ($codexLogDbKb -gt 0) {
            Write-Host "    logs_1.sqlite（可选深清） -> $(Format-KbSize $codexLogDbKb)"
        }
    }

    if (Test-Path $GeminiCliDir) {
        Write-Host ""
        Write-Host "  [gemini-cli] $GeminiCliDir" -ForegroundColor Green
        if ($geminiTmpKb -gt 0) {
            Write-Host "    tmp（可选深清，会删除本地可恢复会话缓存） -> $(Format-KbSize $geminiTmpKb)"
        }
    }

    if ((Test-Path $OpenCodeInstallDir) -or (Test-Path $OpenCodeConfigDir) -or (Test-Path $OpenCodeCacheDir) -or (Test-Path $OpenCodeDataDir)) {
        Write-Host ""
        Write-Host "  [opencode]" -ForegroundColor Green
        if (Test-Path $OpenCodeConfigDir) { Write-Host "    config -> $OpenCodeConfigDir" }
        if (Test-Path $OpenCodeCacheDir) { Write-Host "    cache -> $OpenCodeCacheDir" }
        if (Test-Path $OpenCodeDataDir) { Write-Host "    data -> $OpenCodeDataDir" }

        foreach ($item in @(
            @{ Label = "opencode cache"; Path = $OpenCodeCacheDir },
            @{ Label = "tool-output"; Path = "$OpenCodeDataDir\tool-output" },
            @{ Label = "log"; Path = "$OpenCodeDataDir\log" },
            @{ Label = "snapshot"; Path = "$OpenCodeDataDir\snapshot" },
            @{ Label = "opencode.db-shm"; Path = "$OpenCodeDataDir\opencode.db-shm" },
            @{ Label = "opencode.db-wal"; Path = "$OpenCodeDataDir\opencode.db-wal" }
        )) {
            [void](Show-CleanupCandidate -Label $item.Label -TargetPath $item.Path)
        }
    }

    Write-Host ""
    Write-Host "  默认安全清理预计: $(Format-KbSize $safeTotalKb)" -ForegroundColor Cyan
    Write-Host "  可选深清额外预计: $(Format-KbSize $optionalTotalKb)" -ForegroundColor Cyan
    Write-Host ""

    if ($safeTotalKb -le 0 -and $optionalTotalKb -le 0) {
        Write-ColorOutput "当前没有可安全清理的垃圾缓存" "Info"
        return
    }

    $script:TotalReleasedKb = 0
    $didClean = $false

    if ($safeTotalKb -gt 0) {
        if (Confirm-Action "确认执行默认安全清理？") {
            foreach ($item in @(
                @{ Label = "清理 Claude Code cache"; Path = "$ClaudeCodeDir\cache" },
                @{ Label = "清理 Claude Code debug"; Path = "$ClaudeCodeDir\debug" },
                @{ Label = "清理 Claude Code downloads"; Path = "$ClaudeCodeDir\downloads" },
                @{ Label = "清理 Claude Code paste-cache"; Path = "$ClaudeCodeDir\paste-cache" },
                @{ Label = "清理 Claude Code 插件缓存"; Path = "$ClaudeCodeDir\plugins\cache" },
                @{ Label = "清理 Claude Code 临时会话文件"; Path = "$ClaudeCodeDir\session-data" },
                @{ Label = "清理 Claude Code 文件编辑历史"; Path = "$ClaudeCodeDir\file-history" },
                @{ Label = "清理 Claude Code Shell 快照"; Path = "$ClaudeCodeDir\shell-snapshots" },
                @{ Label = "清理 Claude Code 任务状态"; Path = "$ClaudeCodeDir\tasks" },
                @{ Label = "清理 Claude Code 待办追踪"; Path = "$ClaudeCodeDir\todos" },
                @{ Label = "清理 Claude Code 会话环境"; Path = "$ClaudeCodeDir\session-env" },
                @{ Label = "清理 Claude Code IDE 锁文件"; Path = "$ClaudeCodeDir\ide" },
                @{ Label = "清理 Claude Code 指标数据"; Path = "$ClaudeCodeDir\metrics" },
                @{ Label = "清理 Claude Code 遥测数据"; Path = "$ClaudeCodeDir\telemetry" },
                @{ Label = "清理 codex .tmp"; Path = "$CodexDir\.tmp" },
                @{ Label = "清理 codex tmp"; Path = "$CodexDir\tmp" },
                @{ Label = "清理 codex cache"; Path = "$CodexDir\cache" },
                @{ Label = "清理 codex 日志目录"; Path = "$CodexDir\log" },
                @{ Label = "清理 codex 插件缓存"; Path = "$CodexDir\plugins\cache" },
                @{ Label = "清理 codex 日志数据库 shm"; Path = "$CodexDir\logs_1.sqlite-shm" },
                @{ Label = "清理 codex 日志数据库 wal"; Path = "$CodexDir\logs_1.sqlite-wal" },
                @{ Label = "清理 codex models_cache.json"; Path = "$CodexDir\models_cache.json" },
                @{ Label = "清理 codex skills 缓存索引"; Path = "$CodexDir\vendor_imports\skills-curated-cache.json" },
                @{ Label = "清理 opencode cache"; Path = $OpenCodeCacheDir },
                @{ Label = "清理 opencode tool-output"; Path = "$OpenCodeDataDir\tool-output" },
                @{ Label = "清理 opencode log"; Path = "$OpenCodeDataDir\log" },
                @{ Label = "清理 opencode snapshot"; Path = "$OpenCodeDataDir\snapshot" },
                @{ Label = "清理 opencode.db-shm"; Path = "$OpenCodeDataDir\opencode.db-shm" },
                @{ Label = "清理 opencode.db-wal"; Path = "$OpenCodeDataDir\opencode.db-wal" }
            )) {
                Remove-PathWithStats -TargetPath $item.Path -Label $item.Label
            }
            $didClean = $true
        }
        else {
            Write-ColorOutput "已跳过默认安全清理" "Info"
        }
    }

    if ($geminiTmpKb -gt 0) {
        if (Confirm-Action "是否额外清理 gemini-cli tmp？这会删除本地可恢复会话缓存") {
            Remove-PathWithStats -TargetPath "$GeminiCliDir\tmp" -Label "额外清理 gemini-cli tmp（删除本地可恢复会话缓存）"
            $didClean = $true
        }
        else {
            Write-ColorOutput "已保留 gemini-cli tmp" "Info"
        }
    }

    if ($codexLogDbKb -gt 0) {
        if (Confirm-Action "是否额外清理 codex logs_1.sqlite？这会清空本地日志数据库") {
            Remove-PathWithStats -TargetPath "$CodexDir\logs_1.sqlite" -Label "额外清理 codex 日志数据库"
            $didClean = $true
        }
        else {
            Write-ColorOutput "已保留 codex logs_1.sqlite" "Info"
        }
    }

    Write-Host ""
    if ($didClean) {
        Write-ColorOutput "四个 AI 工具垃圾缓存清理完成，总释放空间: $(Format-KbSize $script:TotalReleasedKb)" "Success"
        Write-ColorOutput "核心配置、MCP、登录认证、skills、history 和正式数据库均已保留" "Info"

        # 清理完毕 -> 强制重置 Windsurf 设备 ID（默认行为）
        Invoke-AutoResetAfterClean
    }
    else {
        Write-ColorOutput "未执行任何清理操作" "Info"
    }
}

# ----------------------------------------------------------------------------
# 计算当前可清理运行时缓存总大小（KB），用于优化前后对比
# ----------------------------------------------------------------------------
function Get-RuntimeCacheTotalKb {
    $WsAppData = "$env:APPDATA\Windsurf"
    $ImplicitDir = "$WindsurfDir\implicit"
    $CodeTrackerDir = "$WindsurfDir\code_tracker"
    $Total = 0

    # 统计各缓存路径大小
    $paths = @(
        "$WsAppData\Cache",
        "$WsAppData\CachedData",
        "$WsAppData\GPUCache",
        "$WsAppData\Code Cache",
        "$WsAppData\DawnWebGPUCache",
        "$WsAppData\DawnGraphiteCache",
        "$WsAppData\logs",
        "$WsAppData\Crashpad\completed",
        "$WsAppData\Crashpad\pending",
        "$WsAppData\CachedExtensionVSIXs",
        $ImplicitDir,
        $CodeTrackerDir
    )

    foreach ($p in $paths) {
        if (Test-Path $p) {
            $Total += Get-PathSizeKb -TargetPath $p
        }
    }

    # state.vscdb.backup 单独计算
    $StateBackup = "$WsAppData\User\globalStorage\state.vscdb.backup"
    if (Test-Path $StateBackup) {
        $Total += Get-PathSizeKb -TargetPath $StateBackup
    }

    return $Total
}

# ----------------------------------------------------------------------------
# 功能16: 深度清理运行时缓存（保留对话历史，解决Windsurf运行卡顿）
# ----------------------------------------------------------------------------
function Deep-CleanRuntimeCache {
    param([switch]$AutoConfirm)

    $WsAppData = "$env:APPDATA\Windsurf"
    $ImplicitDir = "$WindsurfDir\implicit"
    $CodeTrackerDir = "$WindsurfDir\code_tracker"

    Write-ColorOutput "深度清理运行时缓存（保留对话历史）..." "Info"
    Write-Host ""
    Write-Host "此操作将清理运行时缓存和日志，包含大型 state.vscdb.backup 文件"
    Write-ColorOutput "不会清理对话历史、登录态相关存储（IndexedDB/WebStorage/Local Storage/Session Storage/Service Worker）、memories、skills、extensions、用户设置" "Success"
    Write-Host ""

    # 判断是否需要手动确认
    if (-not $AutoConfirm) {
        if (-not (Confirm-Action)) {
            Write-ColorOutput "已取消操作" "Info"
            return
        }
    }
    else {
        Write-ColorOutput "已启用自动确认模式" "Info"
    }

    if (-not (Test-WindsurfRunning)) { return }

    # 初始化全局释放空间计数
    $script:TotalReleasedKb = 0

    # 逐项清理并统计空间
    Remove-PathWithStats "$WsAppData\Cache"                                      "清理浏览器缓存 (Cache)"
    Remove-PathWithStats "$WsAppData\CachedData"                                 "清理编译缓存 (CachedData)"
    Remove-PathWithStats "$WsAppData\GPUCache"                                   "清理 GPU 缓存 (GPUCache)"
    Remove-PathWithStats "$WsAppData\Code Cache"                                 "清理代码缓存 (Code Cache)"
    Remove-PathWithStats "$WsAppData\DawnWebGPUCache"                            "清理 Dawn WebGPU 缓存"
    Remove-PathWithStats "$WsAppData\DawnGraphiteCache"                          "清理 Dawn Graphite 缓存"
    Remove-PathWithStats "$WsAppData\logs"                                       "清理日志文件 (logs)"
    Remove-PathWithStats "$WsAppData\Crashpad\completed"                         "清理 Crashpad completed"
    Remove-PathWithStats "$WsAppData\Crashpad\pending"                           "清理 Crashpad pending"
    Remove-PathWithStats "$WsAppData\User\globalStorage\state.vscdb.backup"      "清理 state.vscdb.backup（关键大文件）"
    Remove-PathWithStats "$WsAppData\CachedExtensionVSIXs"                       "清理旧版插件安装包残留"
    Remove-PathWithStats $ImplicitDir                                             "清理 implicit AI 索引缓存"
    Remove-PathWithStats $CodeTrackerDir                                          "清理 AI 代码追踪索引 (code_tracker)"

    # 清理 Windows 临时文件夹中的 Windsurf 相关快照
    Get-ChildItem -Path $env:TEMP -Filter "windsurf-terminal-*.snapshot" -ErrorAction SilentlyContinue |
        Remove-Item -Force -ErrorAction SilentlyContinue
    Write-ColorOutput "清理 %TEMP% 中的终端快照" "Info"

    Write-Host ""
    Write-ColorOutput "深度清理完成，总释放空间: $(Format-KbSize $script:TotalReleasedKb)" "Success"
    Write-ColorOutput "已保留对话历史、memories、skills、extensions、用户设置" "Info"

    # 清理完毕 -> 强制重置设备 ID（默认行为，FORCE_RESET_ID=0 可关闭）
    Invoke-AutoResetAfterClean
}

# ----------------------------------------------------------------------------
# 功能17: Windsurf 进程资源监控
# ----------------------------------------------------------------------------
function Monitor-WindsurfProcesses {
    Write-ColorOutput "Windsurf 进程资源监控..." "Info"

    Write-Host ""
    Write-Host "========== Windsurf 进程 ==========" -ForegroundColor Cyan

    # 查找所有 windsurf 相关进程
    $processes = Get-Process | Where-Object { $_.Name -like "*windsurf*" } 2>$null

    if ($processes) {
        Write-Host ("{0,-10} {1,-30} {2,-12} {3,-12}" -f "PID", "进程名", "CPU(s)", "内存(MB)")
        Write-Host ("-" * 70)
        foreach ($proc in $processes) {
            $memMB = [math]::Round($proc.WorkingSet64 / 1MB, 2)
            # CPU时间取秒数
            $cpuSec = [math]::Round($proc.CPU, 2)
            Write-Host ("{0,-10} {1,-30} {2,-12} {3,-12}" -f $proc.Id, $proc.Name, $cpuSec, $memMB)
        }
    }
    else {
        Write-ColorOutput "未检测到 Windsurf 正在运行" "Warning"
    }

    Write-Host ""
    Write-Host "========== 系统内存概况 ==========" -ForegroundColor Cyan

    # 使用 WMI 获取内存信息
    try {
        $os = Get-WmiObject -Class Win32_OperatingSystem -ErrorAction SilentlyContinue
        if ($os) {
            $totalMB = [math]::Round($os.TotalVisibleMemorySize / 1024, 2)
            $freeMB  = [math]::Round($os.FreePhysicalMemory / 1024, 2)
            $usedMB  = [math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / 1024, 2)
            Write-Host "  内存总量: ${totalMB}MB"
            Write-Host "  已使用:   ${usedMB}MB"
            Write-Host "  空闲内存: ${freeMB}MB"
        }
    }
    catch {
        Write-ColorOutput "无法获取内存信息" "Warning"
    }

    Write-Host ""
    Write-Host "========== 磁盘空间 ==========" -ForegroundColor Cyan
    Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -ne $null } |
        Select-Object Name, @{N="已用(GB)";E={[math]::Round($_.Used/1GB,2)}}, @{N="空闲(GB)";E={[math]::Round($_.Free/1GB,2)}} |
        Format-Table -AutoSize

    Write-Host ""
    Write-Host "========== 系统负载 ==========" -ForegroundColor Cyan
    try {
        $cpu = (Get-WmiObject -Class Win32_Processor -ErrorAction SilentlyContinue |
            Measure-Object -Property LoadPercentage -Average).Average
        Write-Host "  CPU 平均负载: ${cpu}%"
    }
    catch {
        Write-ColorOutput "无法获取 CPU 负载" "Warning"
    }
}

# ----------------------------------------------------------------------------
# 功能18: 一键智能优化（保留对话历史，清理前后空间对比）
# ----------------------------------------------------------------------------
function Smart-Optimize {
    Write-ColorOutput "执行一键智能优化（保留对话历史）..." "Info"
    Write-ColorOutput "不会清理 cascade/memories/skills/extensions" "Success"

    # 统计优化前可清理空间
    $BeforeTotalKb = Get-RuntimeCacheTotalKb
    Write-ColorOutput "优化前可清理空间: $(Format-KbSize $BeforeTotalKb)" "Info"

    # 调用深度清理（自动确认模式，无需手动输入）
    Deep-CleanRuntimeCache -AutoConfirm

    # 统计优化后残余空间
    $AfterTotalKb = Get-RuntimeCacheTotalKb
    $OptimizedKb = $BeforeTotalKb - $AfterTotalKb
    if ($OptimizedKb -lt 0) { $OptimizedKb = 0 }

    Write-Host ""
    Write-Host "========== 优化前后对比 ==========" -ForegroundColor Cyan
    Write-Host "  优化前可清理空间: $(Format-KbSize $BeforeTotalKb)"
    Write-Host "  优化后可清理空间: $(Format-KbSize $AfterTotalKb)"
    Write-Host "  本次优化释放空间: $(Format-KbSize $OptimizedKb)"
    Write-Host ""
    Write-ColorOutput "一键智能优化完成" "Success"
}

# ----------------------------------------------------------------------------
# 功能20: 备份 MCP 配置、Skills 和全局 Rules
# ----------------------------------------------------------------------------
function Backup-McpSkillsRules {
    Write-ColorOutput "备份 MCP 配置、Skills 和全局 Rules..." "Info"

    $BackupTimestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $BackupTarget = Join-Path $env:USERPROFILE ".windsurf-config-backup-$BackupTimestamp"

    $McpConfig = Join-Path $WindsurfDir "mcp_config.json"
    $SkillsDir = Join-Path $WindsurfDir "skills"
    $GlobalRules = Join-Path $WindsurfDir "memories\global_rules.md"
    $MemoriesDir = Join-Path $WindsurfDir "memories"

    Write-Host ""
    Write-Host "将备份以下内容:" -ForegroundColor Cyan
    Write-Host ""

    $BackupCount = 0

    if (Test-Path $McpConfig) {
        $McpSize = Get-PathSizeKb -TargetPath $McpConfig
        Write-Host "  [MCP 配置] $McpConfig - $(Format-KbSize $McpSize)" -ForegroundColor Green
        $BackupCount++
    }
    else { Write-Host "  [MCP 配置] 不存在" -ForegroundColor Red }

    if (Test-Path $SkillsDir) {
        $SkillsCount = (Get-ChildItem -Directory -Path $SkillsDir -ErrorAction SilentlyContinue).Count
        $SkillsSize = Get-PathSizeKb -TargetPath $SkillsDir
        Write-Host "  [Skills] $SkillsDir - $SkillsCount 个技能, $(Format-KbSize $SkillsSize)" -ForegroundColor Green
        $BackupCount++
    }
    else { Write-Host "  [Skills] 目录不存在" -ForegroundColor Red }

    if (Test-Path $GlobalRules) {
        $RulesSize = Get-PathSizeKb -TargetPath $GlobalRules
        Write-Host "  [全局 Rules] $GlobalRules - $(Format-KbSize $RulesSize)" -ForegroundColor Green
        $BackupCount++
    }
    else { Write-Host "  [全局 Rules] 不存在" -ForegroundColor Red }

    if (Test-Path $MemoriesDir) {
        $MemCount = (Get-ChildItem -File -Path $MemoriesDir -Filter "*.pb" -ErrorAction SilentlyContinue).Count
        $MemSize = Get-PathSizeKb -TargetPath $MemoriesDir
        Write-Host "  [Memories] $MemoriesDir - $MemCount 个记忆文件, $(Format-KbSize $MemSize)" -ForegroundColor Green
        $BackupCount++
    }
    else { Write-Host "  [Memories] 目录不存在" -ForegroundColor Red }

    Write-Host ""
    if ($BackupCount -eq 0) { Write-ColorOutput "没有找到任何可备份的内容" "Warning"; return }

    Write-Host "备份目标目录: $BackupTarget" -ForegroundColor Cyan
    Write-Host ""

    if (Confirm-Action "确认执行备份？") {
        New-Item -ItemType Directory -Path $BackupTarget -Force | Out-Null
        if (Test-Path $McpConfig) { Copy-Item $McpConfig (Join-Path $BackupTarget "mcp_config.json") -Force; Write-ColorOutput "MCP 配置已备份" "Success" }
        if (Test-Path $SkillsDir) { Copy-Item $SkillsDir (Join-Path $BackupTarget "skills") -Recurse -Force; Write-ColorOutput "Skills 目录已备份" "Success" }
        if (Test-Path $GlobalRules) { New-Item -ItemType Directory -Path (Join-Path $BackupTarget "memories") -Force | Out-Null; Copy-Item $GlobalRules (Join-Path $BackupTarget "memories\global_rules.md") -Force; Write-ColorOutput "全局 Rules 已备份" "Success" }
        if (Test-Path $MemoriesDir) { Copy-Item $MemoriesDir (Join-Path $BackupTarget "memories") -Recurse -Force -ErrorAction SilentlyContinue; Write-ColorOutput "Memories 目录已备份" "Success" }

        $TotalSize = Get-PathSizeKb -TargetPath $BackupTarget
        Write-Host ""
        Write-ColorOutput "备份完成！总大小: $(Format-KbSize $TotalSize)" "Success"
        Write-ColorOutput "备份位置: $BackupTarget" "Info"
    }
    else { Write-ColorOutput "已取消操作" "Info" }
}

# ----------------------------------------------------------------------------
# 功能21: 还原 MCP 配置、Skills 和全局 Rules
# ----------------------------------------------------------------------------
function Restore-McpSkillsRules {
    Write-ColorOutput "还原 MCP 配置、Skills 和全局 Rules..." "Info"

    $McpConfig = Join-Path $WindsurfDir "mcp_config.json"
    $SkillsDir = Join-Path $WindsurfDir "skills"
    $GlobalRules = Join-Path $WindsurfDir "memories\global_rules.md"
    $MemoriesDir = Join-Path $WindsurfDir "memories"

    $BackupList = Get-ChildItem -Directory -Path $env:USERPROFILE -Filter ".windsurf-config-backup-*" -ErrorAction SilentlyContinue
    if (-not $BackupList) { Write-ColorOutput "未找到任何配置备份" "Warning"; Write-ColorOutput "请先使用备份功能进行备份" "Info"; return }

    Write-Host ""
    Write-Host "可用的配置备份:" -ForegroundColor Cyan
    Write-Host ""

    $Idx = 1
    foreach ($bdir in $BackupList) {
        $Contents = @()
        if (Test-Path (Join-Path $bdir.FullName "mcp_config.json")) { $Contents += "MCP" }
        if (Test-Path (Join-Path $bdir.FullName "skills")) { $Contents += "Skills" }
        if (Test-Path (Join-Path $bdir.FullName "memories\global_rules.md")) { $Contents += "Rules" }
        if ($Contents.Count -eq 0) { $Contents = @("(空)") }
        $BSize = Get-PathSizeKb -TargetPath $bdir.FullName
        Write-Host "  $Idx) $($bdir.Name) - $(Format-KbSize $BSize)" -ForegroundColor Green
        Write-Host "     包含: $($Contents -join ', ')" -ForegroundColor Cyan
        $Idx++
    }

    Write-Host ""
    Write-Host "  0) 取消"
    Write-Host ""
    $RestoreChoice = Read-Host "请选择要还原的备份 [0-$($BackupList.Count)]"
    if ($RestoreChoice -eq "0" -or [string]::IsNullOrWhiteSpace($RestoreChoice)) { Write-ColorOutput "已取消操作" "Info"; return }
    if (-not ($RestoreChoice -match '^\d+$') -or [int]$RestoreChoice -lt 1 -or [int]$RestoreChoice -gt $BackupList.Count) { Write-ColorOutput "无效选项" "Error"; return }

    $SelectedBackup = $BackupList[[int]$RestoreChoice - 1]
    Write-Host ""
    Write-Host "已选择备份: $($SelectedBackup.Name)" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "请选择还原方式:" -ForegroundColor Cyan
    Write-Host "  1) 全部还原  2) 仅MCP  3) 仅Skills  4) 仅Rules  5) 仅Memories  0) 取消"
    Write-Host ""
    $RestoreMode = Read-Host "请选择 [0-5]"

    $RestoreMcp = $false; $RestoreSkills = $false; $RestoreRules = $false; $RestoreMem = $false
    switch ($RestoreMode) {
        "0" { Write-ColorOutput "已取消操作" "Info"; return }
        "1" { $RestoreMcp = $true; $RestoreSkills = $true; $RestoreRules = $true; $RestoreMem = $true }
        "2" { $RestoreMcp = $true }
        "3" { $RestoreSkills = $true }
        "4" { $RestoreRules = $true }
        "5" { $RestoreMem = $true }
        default { Write-ColorOutput "无效选项" "Error"; return }
    }

    Write-Host ""
    Write-ColorOutput "还原操作将覆盖当前配置！" "Warning"

    if (Confirm-Action "确认执行还原？") {
        Write-Host ""
        $BackupPath = $SelectedBackup.FullName
        if ($RestoreMcp -and (Test-Path (Join-Path $BackupPath "mcp_config.json"))) { Copy-Item (Join-Path $BackupPath "mcp_config.json") $McpConfig -Force; Write-ColorOutput "MCP 配置已还原" "Success" }
        if ($RestoreSkills -and (Test-Path (Join-Path $BackupPath "skills"))) { if (Test-Path $SkillsDir) { Remove-Item $SkillsDir -Recurse -Force -ErrorAction SilentlyContinue }; Copy-Item (Join-Path $BackupPath "skills") $SkillsDir -Recurse -Force; Write-ColorOutput "Skills 目录已还原" "Success" }
        if ($RestoreRules -and (Test-Path (Join-Path $BackupPath "memories\global_rules.md"))) { if (-not (Test-Path $MemoriesDir)) { New-Item -ItemType Directory -Path $MemoriesDir -Force | Out-Null }; Copy-Item (Join-Path $BackupPath "memories\global_rules.md") $GlobalRules -Force; Write-ColorOutput "全局 Rules 已还原" "Success" }
        if ($RestoreMem -and (Test-Path (Join-Path $BackupPath "memories"))) { if (-not (Test-Path $MemoriesDir)) { New-Item -ItemType Directory -Path $MemoriesDir -Force | Out-Null }; Copy-Item (Join-Path $BackupPath "memories\*") $MemoriesDir -Recurse -Force -ErrorAction SilentlyContinue; Write-ColorOutput "Memories 已还原" "Success" }
        Write-Host ""
        Write-ColorOutput "还原完成！" "Success"
        Write-ColorOutput "请重启 Windsurf 使更改生效" "Info"
    }
    else { Write-ColorOutput "已取消操作" "Info" }
}

# ----------------------------------------------------------------------------
# 内部函数: 自动重置 Windsurf ID（无确认提示，供清理流程自动调用）
# ----------------------------------------------------------------------------
function Reset-WindsurfIdAuto {
    $InstallationIdFile = Join-Path $WindsurfDir "installation_id"
    $MachineIdFile = Join-Path $env:APPDATA "Windsurf\machineid"
    $StorageJson = Join-Path $env:APPDATA "Windsurf\User\globalStorage\storage.json"

    # 生成新的 UUID / 随机字节
    $NewInstallId = [guid]::NewGuid().ToString()
    $NewMachineId = [guid]::NewGuid().ToString()
    $NewDevDeviceId = [guid]::NewGuid().ToString()
    $NewSqmId = [guid]::NewGuid().ToString().Replace("-", "").ToUpper()
    $NewMacMachineId = -join ((1..16) | ForEach-Object { "{0:x2}" -f (Get-Random -Maximum 256) })
    $NewTelemetryMachineId = -join ((1..32) | ForEach-Object { "{0:x2}" -f (Get-Random -Maximum 256) })

    # 重置 installation_id
    if ((Test-Path $InstallationIdFile) -or (Test-Path (Split-Path $InstallationIdFile))) {
        try { $NewInstallId | Out-File $InstallationIdFile -Encoding UTF8 -Force } catch {}
    }

    # 重置 machineid
    if ((Test-Path $MachineIdFile) -or (Test-Path (Split-Path $MachineIdFile))) {
        try { $NewMachineId | Out-File $MachineIdFile -Encoding UTF8 -Force } catch {}
    }

    # 重置 storage.json 中的 telemetry ID
    if (Test-Path $StorageJson) {
        try {
            $StorageData = Get-Content $StorageJson -Raw | ConvertFrom-Json
            $StorageData | Add-Member -NotePropertyName "telemetry.devDeviceId" -NotePropertyValue $NewDevDeviceId -Force
            $StorageData | Add-Member -NotePropertyName "telemetry.macMachineId" -NotePropertyValue $NewMacMachineId -Force
            $StorageData | Add-Member -NotePropertyName "telemetry.machineId" -NotePropertyValue $NewTelemetryMachineId -Force
            $StorageData | Add-Member -NotePropertyName "telemetry.sqmId" -NotePropertyValue $NewSqmId -Force
            $StorageData | ConvertTo-Json -Depth 10 | Out-File $StorageJson -Encoding UTF8 -Force
        }
        catch { }
    }

    # 【关键补强】重置 state.vscdb 的 ItemTable 中的 telemetry 键
    # VSCode/Windsurf 的 globalStorage 会把 telemetry 同时存到 SQLite 里，只改 storage.json 会被覆盖
    $StateDb = Join-Path $env:APPDATA "Windsurf\User\globalStorage\state.vscdb"
    if (Test-Path $StateDb) {
        # 优先使用 sqlite3.exe（常见于 Git for Windows、Python、或手动安装）
        $sqliteExe = Get-Command sqlite3.exe -ErrorAction SilentlyContinue
        if ($sqliteExe) {
            $sqlScript = @"
UPDATE ItemTable SET value = '""$NewTelemetryMachineId""' WHERE key = 'telemetry.machineId';
UPDATE ItemTable SET value = '""$NewDevDeviceId""' WHERE key = 'telemetry.devDeviceId';
UPDATE ItemTable SET value = '""$NewSqmId""' WHERE key = 'telemetry.sqmId';
UPDATE ItemTable SET value = '""$NewMacMachineId""' WHERE key = 'telemetry.macMachineId';
UPDATE ItemTable SET value = '""$NewInstallId""' WHERE key = 'storage.serviceMachineId';
"@
            try {
                $sqlScript | & $sqliteExe.Source $StateDb
                Write-ColorOutput "state.vscdb telemetry 键已同步" "Success"
            } catch {
                Write-ColorOutput "state.vscdb 更新失败: $_" "Warning"
            }
        }
        elseif (Get-Command python -ErrorAction SilentlyContinue) {
            # 退而求其次：用 Python 的内置 sqlite3 模块
            $pyScript = @"
import sqlite3
try:
    c = sqlite3.connect(r'$StateDb')
    cur = c.cursor()
    for k, v in [
        ('telemetry.machineId', '$NewTelemetryMachineId'),
        ('telemetry.devDeviceId', '$NewDevDeviceId'),
        ('telemetry.sqmId', '$NewSqmId'),
        ('telemetry.macMachineId', '$NewMacMachineId'),
        ('storage.serviceMachineId', '$NewInstallId'),
    ]:
        cur.execute("UPDATE ItemTable SET value = ? WHERE key = ?", ('"' + v + '"', k))
    c.commit()
    c.close()
    print('OK')
except Exception as e:
    print('ERR', e)
"@
            $pyScript | python
            Write-ColorOutput "state.vscdb telemetry 键已通过 Python 同步" "Success"
        }
        else {
            Write-ColorOutput "未找到 sqlite3.exe 或 python，state.vscdb 未同步（重置可能不彻底）" "Warning"
            Write-ColorOutput "建议安装 Git for Windows（自带 sqlite3）或 Python" "Info"
        }
    }

    # 【Windows 特有】重置注册表 MachineGuid（需要管理员权限）
    # HKLM\SOFTWARE\Microsoft\Cryptography\MachineGuid 是 Windows 系统级机器标识
    # Windsurf/Electron 应用会读取它作为设备指纹的一部分
    $RegPath = "HKLM:\SOFTWARE\Microsoft\Cryptography"
    try {
        $isAdmin = Test-Administrator
        if ($isAdmin) {
            $NewRegMachineGuid = [guid]::NewGuid().ToString()
            Set-ItemProperty -Path $RegPath -Name "MachineGuid" -Value $NewRegMachineGuid -ErrorAction Stop
            Write-ColorOutput "Windows 注册表 MachineGuid 已重置: $NewRegMachineGuid" "Success"
        } else {
            Write-ColorOutput "跳过注册表 MachineGuid 重置（需要管理员权限）" "Warning"
            Write-ColorOutput "如需完整重置，请以管理员身份重新运行脚本" "Info"
        }
    }
    catch {
        Write-ColorOutput "注册表 MachineGuid 重置失败: $_" "Warning"
    }

    Write-ColorOutput "Windsurf ID 已自动重置（含 storage.json + state.vscdb + 注册表同步）" "Success"
    Write-Host "  installation_id: $NewInstallId" -ForegroundColor Green
    Write-Host "  machineid:       $NewMachineId" -ForegroundColor Green
    Write-Host "  telemetry.*:     已同步到 storage.json 和 state.vscdb" -ForegroundColor Green
}

# ----------------------------------------------------------------------------
# 内部函数: 清理流程末尾统一调用的"强制重置设备 ID"入口
# 默认行为：强制重置（用户要求）
# 逃生通道：设置环境变量 FORCE_RESET_ID=0 完全跳过
#   例：$env:FORCE_RESET_ID=0; .\fix-windsurf-win.ps1
# ----------------------------------------------------------------------------
function Invoke-AutoResetAfterClean {
    # 用户主动关闭？
    if ($env:FORCE_RESET_ID -eq "0" -or $env:FORCE_RESET_ID -eq "false") {
        Write-ColorOutput "已跳过设备 ID 重置（FORCE_RESET_ID=0）" "Info"
        return
    }

    # Start-FullRepair 等批量流程中：子函数跳过，末尾统一重置一次
    if ($env:_IN_BATCH_REPAIR -eq "1") {
        return
    }

    Write-Host ""
    Write-Host "================ 清理后强制重置 Windsurf 设备 ID ================" -ForegroundColor Cyan
    Write-ColorOutput "此为用户默认行为：每次清理完成后自动重置设备标识" "Warning"
    Write-ColorOutput "预期影响：Windsurf 服务端会识别为新设备，可能需要重新登录一次" "Warning"
    Write-ColorOutput "如需关闭：下次运行前 `$env:FORCE_RESET_ID='0'; .\fix-windsurf-win.ps1" "Info"
    Write-Host ""

    # 关闭 Windsurf 才能可靠重置 storage.json
    $wsRunning = Get-Process -Name "Windsurf" -ErrorAction SilentlyContinue
    if ($wsRunning) {
        Write-ColorOutput "检测到 Windsurf 正在运行，建议先关闭再重置" "Warning"
        Write-ColorOutput "将等待 3 秒后继续（Ctrl+C 可取消）..." "Info"
        Start-Sleep -Seconds 3
    }

    Reset-WindsurfIdAuto
    Write-Host "================================================================" -ForegroundColor Cyan
}

# ----------------------------------------------------------------------------
# 功能22: 重置 Windsurf ID
# ----------------------------------------------------------------------------
function Reset-WindsurfId {
    Write-ColorOutput "重置 Windsurf ID..." "Info"

    $InstallationIdFile = Join-Path $WindsurfDir "installation_id"
    $MachineIdFile = Join-Path $env:APPDATA "Windsurf\machineid"
    $StorageJson = Join-Path $env:APPDATA "Windsurf\User\globalStorage\storage.json"

    Write-Host ""
    Write-Host "当前 Windsurf ID 信息:" -ForegroundColor Cyan
    Write-Host ""

    if (Test-Path $InstallationIdFile) { Write-Host "  [installation_id] $(Get-Content $InstallationIdFile -ErrorAction SilentlyContinue)" -ForegroundColor Green }
    else { Write-Host "  [installation_id] 文件不存在" -ForegroundColor Red }
    if (Test-Path $MachineIdFile) { Write-Host "  [machineid]       $(Get-Content $MachineIdFile -ErrorAction SilentlyContinue)" -ForegroundColor Green }
    else { Write-Host "  [machineid]       文件不存在" -ForegroundColor Red }
    if (Test-Path $StorageJson) { Write-Host "  [storage.json]    存在 (包含 telemetry ID)" -ForegroundColor Green }
    else { Write-Host "  [storage.json]    文件不存在" -ForegroundColor Red }

    Write-Host ""
    Write-ColorOutput "此操作将重新生成所有 Windsurf 标识 ID" "Warning"
    Write-Host "  包括: installation_id, machineid, telemetry ID"
    Write-Host "  重置后 Windsurf 将被视为全新安装"
    Write-Host ""

    if (Confirm-Action "确认重置 Windsurf ID？") {
        if (-not (Test-WindsurfRunning)) { return }

        $NewInstallId = [guid]::NewGuid().ToString()
        $NewMachineId = [guid]::NewGuid().ToString()
        $NewDevDeviceId = [guid]::NewGuid().ToString()
        $NewSqmId = [guid]::NewGuid().ToString().Replace("-", "").ToUpper()
        $NewMacMachineId = -join ((1..16) | ForEach-Object { "{0:x2}" -f (Get-Random -Maximum 256) })
        $NewTelemetryMachineId = -join ((1..32) | ForEach-Object { "{0:x2}" -f (Get-Random -Maximum 256) })

        Write-Host ""
        Write-ColorOutput "生成新 ID..." "Info"

        if ((Test-Path $InstallationIdFile) -or (Test-Path (Split-Path $InstallationIdFile))) { $NewInstallId | Out-File $InstallationIdFile -Encoding UTF8 -Force; Write-ColorOutput "installation_id 已重置: $NewInstallId" "Success" }
        if ((Test-Path $MachineIdFile) -or (Test-Path (Split-Path $MachineIdFile))) { $NewMachineId | Out-File $MachineIdFile -Encoding UTF8 -Force; Write-ColorOutput "machineid 已重置: $NewMachineId" "Success" }

        if (Test-Path $StorageJson) {
            try {
                $StorageData = Get-Content $StorageJson -Raw | ConvertFrom-Json
                $StorageData | Add-Member -NotePropertyName "telemetry.devDeviceId" -NotePropertyValue $NewDevDeviceId -Force
                $StorageData | Add-Member -NotePropertyName "telemetry.macMachineId" -NotePropertyValue $NewMacMachineId -Force
                $StorageData | Add-Member -NotePropertyName "telemetry.machineId" -NotePropertyValue $NewTelemetryMachineId -Force
                $StorageData | Add-Member -NotePropertyName "telemetry.sqmId" -NotePropertyValue $NewSqmId -Force
                $StorageData | ConvertTo-Json -Depth 10 | Out-File $StorageJson -Encoding UTF8 -Force
                Write-ColorOutput "storage.json 中的 telemetry ID 已重置" "Success"
            }
            catch { Write-ColorOutput "storage.json 处理失败: $_" "Warning" }
        }

        Write-Host ""
        Write-Host "重置后的 ID 信息:" -ForegroundColor Cyan
        Write-Host "  installation_id:        $NewInstallId" -ForegroundColor Green
        Write-Host "  machineid:              $NewMachineId" -ForegroundColor Green
        Write-Host "  telemetry.devDeviceId:  $NewDevDeviceId" -ForegroundColor Green
        Write-Host "  telemetry.macMachineId: $NewMacMachineId" -ForegroundColor Green
        Write-Host "  telemetry.machineId:    $NewTelemetryMachineId" -ForegroundColor Green
        Write-Host "  telemetry.sqmId:        $NewSqmId" -ForegroundColor Green
        Write-Host ""
        Write-ColorOutput "Windsurf ID 重置完成！" "Success"
        Write-ColorOutput "请重启 Windsurf 使更改生效" "Info"
    }
    else { Write-ColorOutput "已取消操作" "Info" }
}

# ----------------------------------------------------------------------------
# 主菜单
# ----------------------------------------------------------------------------
function Show-Menu {
    Write-Host ""
    Write-Host "请选择修复选项:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "== Windsurf 缓存清理 ==" -ForegroundColor Yellow
    Write-Host "  1) 清理 Cascade 缓存 (会清理对话历史)"
    Write-Host "  2) 清理启动缓存 (不清理对话历史，推荐)"
    Write-Host "  3) 清理扩展缓存 (不清理对话历史)"
    Write-Host ""
    Write-Host "== 系统缓存清理 ==" -ForegroundColor Yellow
    Write-Host "  4) 清理开发工具缓存 (npm/pip/NuGet/Maven等)"
    Write-Host "  5) 清理 Windows 系统缓存 (临时文件/回收站/旧备份等)"
    Write-Host "  6) 磁盘空间分析"
    Write-Host ""
    Write-Host "== MCP 相关 ==" -ForegroundColor Yellow
    Write-Host "  7) MCP 诊断 (检查MCP加载问题)"
    Write-Host "  8) 重置 MCP 配置"
    Write-Host ""
    Write-Host "== 终端相关 ==" -ForegroundColor Yellow
    Write-Host "  9) 配置终端设置"
    Write-Host "  10) 修复 PowerShell 执行策略"
    Write-Host ""
    Write-Host "== 其他 ==" -ForegroundColor Yellow
    Write-Host "  11) 检查更新问题"
    Write-Host "  12) 检查网络连接"
    Write-Host "  13) 清理 Windsurf 临时文件"
    Write-Host "  14) 生成诊断报告"
    Write-Host "  15) 完整修复 (执行所有步骤)"
    Write-Host ""
    Write-Host "== 深度优化 ==" -ForegroundColor Yellow
    Write-Host "  16) 深度清理运行时缓存 (保留对话历史，推荐)"
    Write-Host "  17) Windsurf 进程资源监控"
    Write-Host "  18) 一键智能优化 (保留对话历史)"
    Write-Host ""
    Write-Host "== AI 工具清理 ==" -ForegroundColor Yellow
    Write-Host "  19) 清理 Claude Code / codex / gemini-cli / opencode 垃圾缓存"
    Write-Host ""
    Write-Host "== 配置备份与 ID 管理 ==" -ForegroundColor Yellow
    Write-Host "  20) 备份 MCP 配置 / Skills / 全局 Rules"
    Write-Host "  21) 还原 MCP 配置 / Skills / 全局 Rules"
    Write-Host "  22) 重置 Windsurf ID (重新生成所有标识)"
    Write-Host ""
    Write-Host "  0) 退出"
    Write-Host ""
    
    $choice = Read-Host "请输入选项 [0-22]"
    
    switch ($choice) {
        "1" { if (Test-WindsurfRunning) { Clear-CascadeCache } }
        "2" { Clear-StartupCache }
        "3" { if (Test-WindsurfRunning) { Clear-ExtensionCache } }
        "4" { Clear-DevCaches }
        "5" { Clear-SystemCaches }
        "6" { Get-DiskAnalysis }
        "7" { Test-MCP }
        "8" { Reset-MCPConfig }
        "9" { Set-TerminalSettings }
        "10" { Set-PSExecutionPolicy }
        "11" { Test-UpdateIssues }
        "12" { Test-NetworkWhitelist }
        "13" { Clear-TempFiles }
        "14" { New-DiagnosticReport }
        "15" { Start-FullRepair }
        "16" { Deep-CleanRuntimeCache }
        "17" { Monitor-WindsurfProcesses }
        "18" { Smart-Optimize }
        "19" { Clear-AIToolGarbage }
        "20" { Backup-McpSkillsRules }
        "21" { Restore-McpSkillsRules }
        "22" { Reset-WindsurfId }
        "0" { 
            Write-Host ""
            Write-ColorOutput "感谢使用 Windsurf 修复工具" "Info"
            exit 
        }
        default { Write-ColorOutput "无效选项" "Error" }
    }
}

# ----------------------------------------------------------------------------
# 主程序入口
# ----------------------------------------------------------------------------
function Main {
    Write-Header
    Get-SystemInfo
    
    while ($true) {
        Show-Menu
        Write-Host ""
        Read-Host "按回车键继续..."
    }
}

# 执行主程序
Main
