# Windsurf Fix Tool

![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Linux%20%7C%20Windows-blue?style=for-the-badge)
![Shell](https://img.shields.io/badge/Shell-Bash%20%7C%20PowerShell-green?style=for-the-badge)
![License](https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge)

A cross-platform troubleshooting toolkit for Windsurf IDE, focused on startup
lag, shell issues, MCP loading failures, oversized runtime caches, and AI tool
cleanup.

[中文](./README.md) | [English](./README.en.md)

## What This Repository Focuses On

- Safe cleanup first: fix lag without forcing sign-in again.
- Separate scripts for macOS, Linux, and Windows.
- Clear risk boundaries for chat history, login state, extensions, and MCP config.
- Practical remediation for terminal issues, MCP diagnostics, and system cache
  cleanup.

## Verified Cleanup Boundaries

The current guidance is based on local inspection, Windsurf troubleshooting
docs, Electron storage behavior, and official PowerShell encoding guidance.

- Best first target for lag:
  `CachedData`
  This is the highest-value rebuildable runtime cache.
- Secondary runtime caches:
  `Cache`, `GPUCache`, `Code Cache`, `Dawn*Cache`, and `logs`
  These are usually safe to rebuild.
- Extension package cache:
  `CachedExtensionVSIXs`
  Safe by default and does not uninstall installed extensions.
- Local backup state:
  `User/globalStorage/state.vscdb.backup`
  Usually safe, but it removes local backup state.
- Login or session related stores:
  `IndexedDB`, `WebStorage`, `Local Storage`, `Session Storage`,
  `Service Worker`
  Avoid these by default because they are closer to persistent site data.
- Cascade history:
  `~/.codeium/windsurf/cascade`
  Avoid by default because it removes local Cascade history.
- MCP config:
  `~/.codeium/windsurf/mcp_config.json`
  Reset only when MCP config itself is broken.

## Feature Matrix

- macOS:
  `fix-windsurf-mac.sh`
  Includes startup cache cleanup, deep runtime cleanup, MCP diagnostics,
  terminal fixes, ID reset, AI tool cleanup, conversation archiving, and
  long-chat lag diagnosis.
- Linux:
  `fix-windsurf-linux.sh`
  Includes startup cache cleanup, `chrome-sandbox` repair, systemd OSC
  troubleshooting, MCP diagnostics, and ID reset.
- Windows:
  `fix-windsurf-win.ps1`
  Includes startup cache cleanup, execution policy repair, update and network
  checks, deep runtime cleanup, and ID reset.
- macOS system cleanup:
  `macos-safe-cleanup.sh`
  Handles risk-tiered cleanup for system caches, dev-tool caches, Windsurf
  runtime caches, and common app caches.

## Repository Layout

| File | Purpose |
| --- | --- |
| `fix-windsurf-mac.sh` | Main macOS repair script |
| `fix-windsurf-linux.sh` | Main Linux repair script |
| `fix-windsurf-win.ps1` | Main Windows repair script |
| `fix-windsurf-win.bat` | Windows launcher for the PowerShell version |
| `macos-safe-cleanup.sh` | macOS system and developer cache cleanup script |
| `WINDSURF-CLEANING-GUIDE.md` | Guide for cleanup, lag, and device-ID modes |
| `README.md` | Chinese documentation |
| `README.en.md` | English documentation |

## Quick Start

### macOS Launch

```bash
git clone https://github.com/1837620622/devin.git
cd devin
chmod +x fix-windsurf-mac.sh
./fix-windsurf-mac.sh
```

### Linux Launch

```bash
git clone https://github.com/1837620622/devin.git
cd devin
chmod +x fix-windsurf-linux.sh
./fix-windsurf-linux.sh
```

### Windows Launch

```powershell
git clone https://github.com/1837620622/devin.git
cd devin
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
.\fix-windsurf-win.ps1
```

`fix-windsurf-win.ps1` is stored as `UTF-8 with BOM` for compatibility with
Windows PowerShell 5.1 when Chinese text is present. `GBK` is not recommended
because it depends on the local system code page and is less reliable across
GitHub, VS Code, and cross-platform environments.

### macOS System Cleanup

```bash
git clone https://github.com/1837620622/devin.git
cd devin
chmod +x macos-safe-cleanup.sh
./macos-safe-cleanup.sh
```

## Recommended Cleanup Order

1. Start with the built-in startup cache cleanup and target `CachedData` first.
2. If lag remains, also clean `Cache`, `GPUCache`, `Code Cache`,
   `DawnWebGPUCache`, `DawnGraphiteCache`, and old logs.
3. Clean `CachedExtensionVSIXs` only when extension package cache is suspected.
4. Use deep runtime cleanup when you want a stronger reset without touching chat
   history or login-related storage.
   On macOS, option `18` now performs a safe deep cleanup first, then asks
   whether to continue with risky session stores such as `IndexedDB`,
   `WebStorage`, and `Cookies`.
5. Treat `cascade` cleanup as a last resort for severe startup failures.

If you are specifically working on long-chat lag, also read the
[Windsurf cleaning guide](./WINDSURF-CLEANING-GUIDE.md).

## Runtime Modes

The main scripts now support two modes:

- Forced reset mode:
  cleanup followed by automatic reset of `installation_id`, `machineid`, and
  telemetry identifiers.
- Conservative mode:
  cleanup without automatic device-ID reset, which is better when you want to
  preserve the current login state as much as possible.

Examples:

```bash
FORCE_RESET_ID=0 bash fix-windsurf-mac.sh
FORCE_RESET_ID=0 bash fix-windsurf-linux.sh
```

```powershell
$env:FORCE_RESET_ID="0"
.\fix-windsurf-win.ps1
```

Both modes keep `cascade/*.pb` conversation history. The difference is whether
device identifiers are reset after cleanup.

## Manual Cleanup Commands

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

## Folders To Avoid Cleaning By Default

- `IndexedDB`
- `WebStorage`
- `Local Storage`
- `Session Storage`
- `Service Worker`

These locations are closer to persistent site and session data in Electron, so
cleaning them may require signing in again for embedded Windsurf services.

## Common Issues

### 1. Startup lag

Start with `CachedData`, then move to `Cache`, `GPUCache`, `Code Cache`,
`Dawn*Cache`, and old logs.

### 2. Will this delete Cascade history

No. Startup cache cleanup, extension cache cleanup, and deep runtime cleanup do
not touch `~/.codeium/windsurf/cascade`. Only the explicit Cascade cleanup
option removes it.

### 3. Will this uninstall extensions

No. The default cleanup only removes `CachedExtensionVSIXs`, which is an
installer cache, not the installed extension itself.

### 4. MCP does not auto-load

Check:

1. Whether `~/.codeium/windsurf/mcp_config.json` is valid JSON.
2. Whether Node.js, Python, and `npx` are installed.
3. Whether required environment variables are present.
4. Whether Windsurf logs show MCP launch errors.

### 5. Terminal session gets stuck

Common causes include heavy `zsh` themes, `Oh My Zsh`, `Powerlevel10k`, or
Linux systemd OSC terminal context tracking.

### 6. “Windsurf is damaged” on macOS

Make sure the app is in `/Applications`, matches your chip architecture, then
run:

```bash
xattr -c "/Applications/Windsurf.app/"
```

### 7. Silent crash on Linux

This often comes from broken `chrome-sandbox` permissions:

```bash
sudo chown root:root /path/to/windsurf/chrome-sandbox
sudo chmod 4755 /path/to/windsurf/chrome-sandbox
```

### 8. Chinese output is garbled on Windows

The PowerShell script is stored as `UTF-8 with BOM` and sets both input and
output encoding to UTF-8 at runtime. Reverting to `GBK` is not recommended.

## macOS System Cleanup Script

`macos-safe-cleanup.sh` is better suited for system-wide and developer-cache
cleanup. Its current behavior is:

- It cleans Windsurf `CachedData`, `Cache`, `GPUCache`, `Code Cache`, and
  `Dawn*Cache` by default.
- It only displays the risk of `WebStorage` and keeps it by default.
- It cleans `~/Library/Logs`, `~/Library/Caches`, and selected rebuildable
  hidden caches under `~/.cache`, such as `codex-runtimes`, `uv`, `selenium`,
  `vscode-ripgrep`, and `WebDriver Manager`.
- It also targets Chrome component caches, speech model caches, shader caches,
  and Crashpad caches.
- It also targets Choice `temp`, `logs`, and `crash` directories.
- It also targets MathWorks `ServiceHost/logs` and
  `MATLAB/local_cluster_jobs`.
- It performs targeted cleanup for stale `/private/var/folders` items such as
  temporary clones, joblib memmaps, `node-gyp-tmp`, and `node-compile-cache`,
  while skipping recent active directories.
- These targeted `/private` items are now cleaned silently by default, showing
  only the count and total size instead of printing internal file details.
- It supports cleanup for Homebrew, npm, pip, Maven, Playwright, Telegram,
  WeChat, and other large cache locations.
- Section dividers were changed to ASCII to reduce display garbling in some
  terminals.
- Every step is confirmed interactively.

## Important Paths

- Conversation history:
  macOS / Linux use `~/.codeium/windsurf/cascade`;
  Windows uses `%USERPROFILE%\.codeium\windsurf\cascade`.
- MCP config:
  macOS / Linux use `~/.codeium/windsurf/mcp_config.json`;
  Windows uses `%USERPROFILE%\.codeium\windsurf\mcp_config.json`.
- macOS runtime cache:
  `~/Library/Application Support/Windsurf`
- Linux runtime cache:
  `~/.config/Windsurf`
- Windows runtime cache:
  `%APPDATA%\Windsurf`

## Network Whitelist

If you are behind a firewall, VPN, proxy, or enterprise network policy, make
sure these domains are reachable:

- `*.codeium.com`
- `*.windsurf.com`
- `*.codeiumdata.com`

## References

- [Official Windsurf Troubleshooting](https://docs.windsurf.com/troubleshooting/windsurf-common-issues)
- [Windsurf Terminal Documentation](https://docs.windsurf.com/windsurf/terminal)
- [Windsurf MCP Documentation](https://docs.windsurf.com/windsurf/cascade/mcp)
- [PowerShell File Encoding Guidance](https://learn.microsoft.com/en-us/powershell/scripting/dev-cross-plat/vscode/understanding-file-encoding?view=powershell-7.5)
- [Windsurf cleaning guide](./WINDSURF-CLEANING-GUIDE.md)

## Author

- WeChat: `1837620622` (传康Kk)
- Email: `2040168455@qq.com`
- Xianyu / Bilibili: `万能程序员`

## License

MIT
