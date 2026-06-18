# Windsurf 修复工具

![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Linux%20%7C%20Windows-blue?style=for-the-badge)
![Shell](https://img.shields.io/badge/Shell-Bash%20%7C%20PowerShell-green?style=for-the-badge)
![License](https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge)

跨平台 Windsurf IDE 故障排除工具包，重点解决启动卡顿、Shell 连接异常、
MCP 加载失败、缓存膨胀，以及 AI 工具残留垃圾文件问题。

[中文](./README.md) | [English](./README.en.md)

## 项目定位

- 优先处理不需要重新登录、也不影响已安装扩展的安全清理项。
- 针对 macOS、Linux、Windows 提供独立脚本，避免硬编码到单一系统。
- 补充 Windsurf 常见问题、PowerShell 编码说明、MCP 排查入口和系统缓存清理。
- 保留对话历史、登录态、扩展配置、MCP 配置的风险边界说明，减少误删。

## 当前验证结论

结合本地目录勘察、Windsurf 官方排障文档、Electron 存储语义和 PowerShell
官方编码文档，当前推荐的默认清理边界如下。

- 启动卡顿首选：
  `CachedData`
  当前最常见、收益最高的可再生运行时缓存，默认建议优先清理。
- 次级运行时缓存：
  `Cache`、`GPUCache`、`Code Cache`、`Dawn*Cache`、`logs`
  这组目录属于 Electron 或图形管线缓存，清理后通常会自动重建。
- 扩展安装包缓存：
  `CachedExtensionVSIXs`
  默认建议清理，不会卸载已安装扩展。
- 工作状态备份：
  `User/globalStorage/state.vscdb.backup`
  可作为谨慎清理项，一般不会影响登录，但会丢失本地状态备份。
- 登录或会话相关存储：
  `IndexedDB`、`WebStorage`、`Local Storage`、`Session Storage`、
  `Service Worker`
  默认不清理，因为更接近持久化站点数据。
- 对话历史：
  `~/.codeium/windsurf/cascade`
  默认不清理，删除后会丢失本地 Cascade 历史。
- MCP 配置：
  `~/.codeium/windsurf/mcp_config.json`
  默认不清理，仅在明确需要重置 MCP 时处理。

## 功能矩阵

- macOS：
  `fix-windsurf-mac.sh`
  包含启动缓存清理、深度运行时缓存清理、MCP 诊断、终端修复、
  ID 重置、AI 工具垃圾清理、对话归档、长对话卡顿快速诊断。
- Linux：
  `fix-windsurf-linux.sh`
  包含启动缓存清理、`chrome-sandbox` 修复、systemd OSC 上下文排查、
  MCP 诊断、ID 重置。
- Windows：
  `fix-windsurf-win.ps1`
  包含启动缓存清理、执行策略修复、网络与更新问题排查、深度运行时缓存清理、
  ID 重置。
- macOS 系统清理：
  `macos-safe-cleanup.sh`
  按风险等级清理系统缓存、开发工具缓存、Windsurf 运行时缓存和常见应用缓存。

## 仓库结构

| 文件 | 用途 |
| --- | --- |
| `fix-windsurf-mac.sh` | macOS 主修复脚本 |
| `fix-windsurf-linux.sh` | Linux 主修复脚本 |
| `fix-windsurf-win.ps1` | Windows 主修复脚本 |
| `fix-windsurf-win.bat` | Windows 批处理入口，便于直接启动 PowerShell 版本 |
| `macos-safe-cleanup.sh` | macOS 系统数据与开发工具缓存清理脚本 |
| `WINDSURF-CLEANING-GUIDE.md` | Windsurf 长对话卡顿、清理边界与设备 ID 模式说明 |
| `README.md` | 中文说明 |
| `README.en.md` | 英文说明 |

## 快速开始

### macOS 启动命令

```bash
git clone https://github.com/1837620622/devin.git
cd devin
chmod +x fix-windsurf-mac.sh
./fix-windsurf-mac.sh
```

### Linux 启动命令

```bash
git clone https://github.com/1837620622/devin.git
cd devin
chmod +x fix-windsurf-linux.sh
./fix-windsurf-linux.sh
```

### Windows 启动命令

```powershell
git clone https://github.com/1837620622/devin.git
cd devin
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
.\fix-windsurf-win.ps1
```

`fix-windsurf-win.ps1` 使用 `UTF-8 with BOM`，用于兼容 Windows
PowerShell 5.1 的中文脚本解析。默认不建议把脚本改成 `GBK`，因为那会依赖
本机区域代码页，在 GitHub、VS Code 和跨平台环境里更容易再次出现乱码。

### macOS 系统清理

```bash
git clone https://github.com/1837620622/devin.git
cd devin
chmod +x macos-safe-cleanup.sh
./macos-safe-cleanup.sh
```

## 推荐清理顺序

1. 先运行“清理启动缓存”，优先处理 `CachedData`。
2. 如果仍然卡顿，再连同 `Cache`、`GPUCache`、`Code Cache`、
   `DawnWebGPUCache`、`DawnGraphiteCache`、旧日志一起清理。
3. 如果怀疑扩展安装包缓存膨胀，再清理 `CachedExtensionVSIXs`。
4. 如果需要更激进但仍尽量保留历史和登录态，再使用“深度清理运行时缓存”。
   现在 `macOS` 的 `18` 号选项会先执行默认安全深清，然后额外询问是否继续
   清理 `IndexedDB / WebStorage / Cookies` 这一组高风险会话存储。
5. 只有在启动失败或状态异常非常严重时，才把 `cascade` 当作最后手段处理。

如果你正在专门处理“对话越来越长后变卡”的问题，建议同时阅读
[Windsurf 清理参考手册](./WINDSURF-CLEANING-GUIDE.md)。

## 运行模式

当前主脚本支持两种模式：

- 强制重置模式：
  清理后自动重置 `installation_id`、`machineid` 和 telemetry 标识。
- 保守模式：
  只做清理，不自动重置设备 ID，尽量保留当前登录态。

示例：

```bash
FORCE_RESET_ID=0 bash fix-windsurf-mac.sh
FORCE_RESET_ID=0 bash fix-windsurf-linux.sh
```

```powershell
$env:FORCE_RESET_ID="0"
.\fix-windsurf-win.ps1
```

这两种模式都不会删除 `cascade/*.pb` 对话历史；区别只在于是否额外重置设备标识。

## 手动清理命令

### macOS

```bash
rm -rf ~/Library/Application\ Support/Windsurf/CachedData
rm -rf ~/Library/Application\ Support/Windsurf/Cache
rm -rf ~/Library/Application\ Support/Windsurf/GPUCache
rm -rf ~/Library/Application\ Support/Windsurf/Code\ Cache
rm -rf ~/Library/Application\ Support/Windsurf/DawnWebGPUCache
rm -rf ~/Library/Application\ Support/Windsurf/DawnGraphiteCache
rm -rf ~/Library/Application\ Support/Windsurf/CachedExtensionVSIXs
```

### Linux

```bash
rm -rf ~/.config/Windsurf/CachedData
rm -rf ~/.config/Windsurf/Cache
rm -rf ~/.config/Windsurf/GPUCache
rm -rf ~/.config/Windsurf/Code\ Cache
rm -rf ~/.config/Windsurf/DawnWebGPUCache
rm -rf ~/.config/Windsurf/DawnGraphiteCache
rm -rf ~/.config/Windsurf/CachedExtensionVSIXs
```

### Windows

```powershell
Remove-Item -Recurse -Force "$env:APPDATA\Windsurf\CachedData"
Remove-Item -Recurse -Force "$env:APPDATA\Windsurf\Cache"
Remove-Item -Recurse -Force "$env:APPDATA\Windsurf\GPUCache"
Remove-Item -Recurse -Force "$env:APPDATA\Windsurf\Code Cache"
Remove-Item -Recurse -Force "$env:APPDATA\Windsurf\DawnWebGPUCache"
Remove-Item -Recurse -Force "$env:APPDATA\Windsurf\DawnGraphiteCache"
Remove-Item -Recurse -Force "$env:APPDATA\Windsurf\CachedExtensionVSIXs"
```

## 默认不建议清理的目录

- `IndexedDB`
- `WebStorage`
- `Local Storage`
- `Session Storage`
- `Service Worker`

这些位置更接近 Electron 持久化站点或会话数据。清理后，Windsurf 内嵌网页、
认证状态或某些服务连接可能需要重新登录。

## 常见问题

### 1. Windsurf 启动卡顿

优先处理 `CachedData`，其次处理 `Cache`、`GPUCache`、`Code Cache`、
`Dawn*Cache` 和旧日志。当前脚本已经把这组目录纳入默认安全清理范围。

### 2. Cascade 历史会不会被删

不会。默认启动缓存清理、扩展缓存清理、深度运行时缓存清理都不会删除
`~/.codeium/windsurf/cascade`。只有显式选择“清理 Cascade 缓存”才会处理。

### 3. 会不会把扩展卸载掉

不会。默认只清理 `CachedExtensionVSIXs` 这类安装包缓存，不会删除已安装扩展
本体，也不会清空用户设置。

### 4. MCP 无法自动加载

优先检查：

1. `~/.codeium/windsurf/mcp_config.json` 是否是合法 JSON。
2. Node.js、Python、`npx` 等运行时是否已安装。
3. 环境变量是否齐全。
4. Windsurf 输出日志中是否出现 MCP 启动报错。

### 5. 终端会话卡住

常见原因是复杂的 `zsh` 主题、`Oh My Zsh`、`Powerlevel10k` 或
Linux 上的 systemd OSC 终端上下文跟踪干扰。

### 6. macOS 提示 “Windsurf 已损坏”

优先确认应用位于 `/Applications`，版本与芯片架构匹配，然后执行：

```bash
xattr -c "/Applications/Windsurf.app/"
```

### 7. Linux 启动时静默崩溃

常见于 `chrome-sandbox` 权限异常，可执行：

```bash
sudo chown root:root /path/to/windsurf/chrome-sandbox
sudo chmod 4755 /path/to/windsurf/chrome-sandbox
```

### 8. Windows 中文乱码

仓库中的 PowerShell 脚本已固定为 `UTF-8 with BOM`，并在运行时设置
`InputEncoding` 和 `OutputEncoding` 为 UTF-8。默认不建议回退到 `GBK`。

## macOS 系统清理脚本说明

`macos-safe-cleanup.sh` 更适合做系统层与开发工具层的缓存减重。当前策略是：

- 默认清理 Windsurf 的 `CachedData`、`Cache`、`GPUCache`、
  `Code Cache`、`Dawn*Cache`。
- 仅展示 `WebStorage` 风险，不会默认删除。
- 会清理 `~/Library/Logs`、`~/Library/Caches`、`~/.cache` 下已确认可再生的
  隐藏缓存，例如 `codex-runtimes`、`uv`、`selenium`、
  `vscode-ripgrep`、`WebDriver Manager`。
- 额外补充清理 Chrome 的组件缓存、语音模型缓存、Shader 缓存、Crashpad 缓存。
- 额外补充清理 Choice 的 `temp`、`logs`、`crash` 目录。
- 额外补充清理 MathWorks 的 `ServiceHost/logs` 和 `MATLAB/local_cluster_jobs`。
- 会对 `/private/var/folders` 里的陈旧临时克隆、joblib memmap、
  `node-gyp-tmp`、`node-compile-cache` 做定向清理，但会跳过近期仍在活跃的目录。
- 这类 `/private` 定向临时垃圾现在默认静默自动清理，只显示条数和总量，不再刷出内部文件明细。
- 支持 Homebrew、npm、pip、Maven、Playwright、Telegram、微信等缓存清理。
- 输出分隔符已改为 ASCII，降低部分终端的乱码概率。
- 每一步都要求确认，便于只清理需要的项目。

## 重要路径

- 对话历史：
  macOS / Linux 为 `~/.codeium/windsurf/cascade`；
  Windows 为 `%USERPROFILE%\.codeium\windsurf\cascade`。
- MCP 配置：
  macOS / Linux 为 `~/.codeium/windsurf/mcp_config.json`；
  Windows 为 `%USERPROFILE%\.codeium\windsurf\mcp_config.json`。
- macOS 运行时缓存：
  `~/Library/Application Support/Windsurf`
- Linux 运行时缓存：
  `~/.config/Windsurf`
- Windows 运行时缓存：
  `%APPDATA%\Windsurf`

## 网络白名单

如果正在使用防火墙、代理、VPN 或企业网络策略，建议确认以下域名可访问：

- `*.codeium.com`
- `*.windsurf.com`
- `*.codeiumdata.com`

## 参考资料

- [Windsurf 官方排障文档](https://docs.windsurf.com/troubleshooting/windsurf-common-issues)
- [Windsurf Terminal 文档](https://docs.windsurf.com/windsurf/terminal)
- [Windsurf MCP 文档](https://docs.windsurf.com/windsurf/cascade/mcp)
- [PowerShell 文件编码说明](https://learn.microsoft.com/en-us/powershell/scripting/dev-cross-plat/vscode/understanding-file-encoding?view=powershell-7.5)
- [Windsurf 清理参考手册](./WINDSURF-CLEANING-GUIDE.md)

## 作者

- 微信：`1837620622`（传康Kk）
- 邮箱：`2040168455@qq.com`
- 咸鱼 / B 站：`万能程序员`

## License

MIT
