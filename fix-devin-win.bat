@echo off
chcp 65001 >nul 2>&1
title Windsurf 修复工具 - Windows

:: ============================================================================
:: Windsurf 修复工具 - Windows 批处理版本
:: 用于修复 Windsurf IDE 卡顿、Shell无法连接等常见问题
:: 使用方法: 双击运行或在命令提示符中执行
:: 作者: 传康KK
:: GitHub: https://github.com/1837620622/windsurf-fix-tool
:: ============================================================================

setlocal EnableDelayedExpansion

:: 颜色代码设置
for /F %%a in ('echo prompt $E ^| cmd') do set "ESC=%%a"
set "GREEN=%ESC%[92m"
set "RED=%ESC%[91m"
set "YELLOW=%ESC%[93m"
set "BLUE=%ESC%[94m"
set "CYAN=%ESC%[96m"
set "NC=%ESC%[0m"

:: 路径定义
set "CODEIUM_DIR=%USERPROFILE%\.codeium"
set "WINDSURF_DIR=%CODEIUM_DIR%\windsurf"
set "CASCADE_DIR=%WINDSURF_DIR%\cascade"

:: 显示标题
:header
cls
echo.
echo %CYAN%========================================%NC%
echo %CYAN%  Windsurf 修复工具 - Windows%NC%
echo %CYAN%  by 传康KK%NC%
echo %CYAN%  github.com/1837620622/windsurf-fix-tool%NC%
echo %CYAN%========================================%NC%
echo.

:: 检测系统信息
echo %BLUE%[信息]%NC% 系统: Windows
echo %BLUE%[信息]%NC% 用户目录: %USERPROFILE%
echo.

:menu
echo.
echo %CYAN%请选择修复选项:%NC%
echo.
echo   1) 清理 Cascade 缓存 (解决启动失败/卡顿)
echo   2) 清理扩展缓存
echo   3) 检查 Windsurf 进程
echo   4) 显示路径信息
echo   5) 打开 PowerShell 完整版工具（含 AI 工具清理）
echo.
echo   0) 退出
echo.
set /p choice="请输入选项 [0-5]: "

if "%choice%"=="1" goto clean_cascade
if "%choice%"=="2" goto clean_extension
if "%choice%"=="3" goto check_process
if "%choice%"=="4" goto show_paths
if "%choice%"=="5" goto run_powershell
if "%choice%"=="0" goto exit_script
goto invalid_option

:: 清理Cascade缓存
:clean_cascade
echo.
echo %YELLOW%[警告]%NC% 此操作将删除对话历史和本地设置！
echo.

if not exist "%CASCADE_DIR%" (
    echo %BLUE%[信息]%NC% Cascade 缓存目录不存在，无需清理
    goto continue
)

set /p confirm="确认删除 Cascade 缓存？[y/N]: "
if /i not "%confirm%"=="y" (
    echo %BLUE%[信息]%NC% 已取消操作
    goto continue
)

:: 检查Windsurf是否运行
tasklist /FI "IMAGENAME eq Windsurf.exe" 2>NUL | find /I "Windsurf.exe" >NUL
if not errorlevel 1 (
    echo %YELLOW%[警告]%NC% Windsurf 正在运行，请先关闭
    goto continue
)

:: 备份并删除
set "BACKUP_DIR=%USERPROFILE%\.windsurf-backup-%date:~0,4%%date:~5,2%%date:~8,2%"
if not exist "%BACKUP_DIR%" mkdir "%BACKUP_DIR%"
xcopy "%CASCADE_DIR%" "%BACKUP_DIR%\cascade\" /E /I /Q >nul 2>&1
echo %BLUE%[信息]%NC% 已备份到: %BACKUP_DIR%

rmdir /S /Q "%CASCADE_DIR%"
if errorlevel 1 (
    echo %RED%[错误]%NC% 删除失败
) else (
    echo %GREEN%[成功]%NC% Cascade 缓存已清理
)
goto continue

:: 清理扩展缓存
:clean_extension
echo.
set "CACHE_DIR=%APPDATA%\Windsurf\CachedData"
set "CACHE_DIR_LEGACY=%WINDSURF_DIR%\CachedData"
set "CACHE_VSIX_DIR=%APPDATA%\Windsurf\CachedExtensionVSIXs"
set "CACHE_VSIX_DIR_LEGACY=%WINDSURF_DIR%\CachedExtensions"

if not exist "%CACHE_DIR%" if not exist "%CACHE_DIR_LEGACY%" if not exist "%CACHE_VSIX_DIR%" if not exist "%CACHE_VSIX_DIR_LEGACY%" (
    echo %BLUE%[信息]%NC% 未找到可清理的扩展缓存目录
    goto continue
)

set /p confirm="确认清理扩展缓存？[y/N]: "
if /i not "%confirm%"=="y" (
    echo %BLUE%[信息]%NC% 已取消操作
    goto continue
)

if exist "%CACHE_DIR%" (
    rmdir /S /Q "%CACHE_DIR%"
    if not errorlevel 1 echo %GREEN%[成功]%NC% 已清理 CachedData
)
if exist "%CACHE_DIR_LEGACY%" (
    rmdir /S /Q "%CACHE_DIR_LEGACY%"
    if not errorlevel 1 echo %GREEN%[成功]%NC% 已清理旧版 CachedData
)
if exist "%CACHE_VSIX_DIR%" (
    rmdir /S /Q "%CACHE_VSIX_DIR%"
    if not errorlevel 1 echo %GREEN%[成功]%NC% 已清理 CachedExtensionVSIXs
)
if exist "%CACHE_VSIX_DIR_LEGACY%" (
    rmdir /S /Q "%CACHE_VSIX_DIR_LEGACY%"
    if not errorlevel 1 echo %GREEN%[成功]%NC% 已清理旧版 CachedExtensions
)
echo %GREEN%[成功]%NC% 扩展缓存已清理
goto continue

:: 检查进程
:check_process
echo.
echo %BLUE%[信息]%NC% 检查 Windsurf 进程...
echo.
tasklist /FI "IMAGENAME eq Windsurf.exe" 2>NUL | find /I "Windsurf.exe" >NUL
if errorlevel 1 (
    echo %GREEN%[成功]%NC% Windsurf 未运行
) else (
    echo %YELLOW%[警告]%NC% Windsurf 正在运行
    echo.
    set /p kill="是否关闭 Windsurf？[y/N]: "
    if /i "!kill!"=="y" (
        taskkill /F /IM Windsurf.exe >nul 2>&1
        echo %GREEN%[成功]%NC% Windsurf 已关闭
    )
)
goto continue

:: 显示路径信息
:show_paths
echo.
echo %CYAN%重要路径:%NC%
echo.
echo   Codeium 目录: %CODEIUM_DIR%
echo   Windsurf 目录: %WINDSURF_DIR%
echo   Cascade 缓存: %CASCADE_DIR%
echo   设置文件: %APPDATA%\Windsurf\User\settings.json
echo.
echo %CYAN%路径状态:%NC%
echo.
if exist "%CODEIUM_DIR%" (echo   Codeium 目录: %GREEN%存在%NC%) else (echo   Codeium 目录: %RED%不存在%NC%)
if exist "%CASCADE_DIR%" (echo   Cascade 缓存: %GREEN%存在%NC%) else (echo   Cascade 缓存: %RED%不存在%NC%)
goto continue

:: 运行PowerShell版本
:run_powershell
echo.
echo %BLUE%[信息]%NC% 启动 PowerShell 版本工具...
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0fix-windsurf-win.ps1"
goto continue

:invalid_option
echo.
echo %RED%[错误]%NC% 无效选项
goto continue

:continue
echo.
pause
goto header

:exit_script
echo.
echo %BLUE%[信息]%NC% 感谢使用 Windsurf 修复工具
echo.
pause
exit /b 0
