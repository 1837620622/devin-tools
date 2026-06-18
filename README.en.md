# Devin Fix Tool

![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Linux%20%7C%20Windows-blue?style=for-the-badge)
![Shell](https://img.shields.io/badge/Shell-Bash%20%7C%20PowerShell-green?style=for-the-badge)
![License](https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge)

A cross-platform troubleshooting toolkit for Devin IDE, focused on startup
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

The current guidance is based on local inspection, Devin troubleshooting
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
  `fix-devin-mac.sh`
  Includes startup cache cleanup, deep runtime cleanup, MCP diagnostics,
  terminal fixes, ID reset, AI tool cleanup, conversation archiving, and
  long-chat lag diagnosis.
- Linux:
  `fix-devin-linux.sh`
  Includes startup cache cleanup, `chrome-sandbox` repair, systemd OSC
  troubleshooting, MCP diagnostics, and ID reset.
- Windows:
  `fix-devin-win.ps1`
  Includes startup cache cleanup, execution policy repair, update and network
  checks, deep runtime cleanup, and ID reset.
- macOS system cleanup:
  `macos-safe-cleanup.sh`
  Handles risk-tiered cleanup for system caches, dev-tool caches, Devin
  runtime caches, and common app caches.

## Repository Layout

| File | Purpose |
| --- | --- |
| `fix-devin-mac.sh` | Main macOS repair script |
| `fix-devin-linux.sh` | Main Linux repair script |
| `fix-devin-win.ps1` | Main Windows repair script |
| `fix-devin-win.bat` | Windows launcher for the PowerShell version |
| `macos-safe-cleanup.sh` | macOS system and developer cache cleanup script |
| `DEVIN-CLEANING-GUIDE.md` | Guide for cleanup, lag, and device-ID modes |
| `README.md` | Chinese documentation |
| `README.en.md` | English documentation |

## Quick Start

### macOS Launch

```bash
git clone https://github.com/1837620622/devin-tools.git
cd devin
chmod +x fix-devin-mac.sh
./fix-devin-mac.sh
```

### Linux Launch

```bash
git clone https://github.com/1837620622/devin-tools.git
cd devin
chmod +x fix-devin-linux.sh
./fix-devin-linux.sh
```

### Windows Launch

```powershell
git clone https://github.com/1837620622/devin-tools.git
cd devin
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
.\fix-devin-win.ps1
```

`fix-devin-win.ps1` is stored as `UTF-8 with BOM` for compatibility with
Windows PowerShell 5.1 when Chinese text is present. `GBK` is not recommended
because it depends on the local system code page and is less reliable across
GitHub, VS Code, and cross-platform environments.

### macOS System Cleanup

```bash
git clone https://github.com/1837620622/devin-tools.git
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
[Devin cleaning guide](./DEVIN-CLEANING-GUIDE.md).

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
FORCE_RESET_ID=0 bash fix-devin-mac.sh
FORCE_RESET_ID=0 bash fix-devin-linux.sh
```

```powershell
$env:FORCE_RESET_ID="0"
.\fix-devin-win.ps1
```

Both modes keep `cascade/*.pb` conversation history. The difference is whether
device identifiers are reset after cleanup.

## Manual Cleanup Commands

### macOS

```bash
rm -rf ~/Library/Application\ Support/Devin/CachedData
rm -rf ~/Library/Application\ Support/Devin/Cache
rm -rf ~/Library/Application\ Support/Devin/GPUCache
rm -rf ~/Library/Application\ Support/Devin/Code\ Cache
rm -rf ~/Library/Application\ Support/Devin/DawnWebGPUCache
rm -rf ~/Library/Application\ Support/Devin/DawnGraphiteCache
rm -rf ~/Library/Application\ Support/Devin/CachedExtensionVSIXs
```

### Linux

```bash
rm -rf ~/.config/Devin/CachedData
rm -rf ~/.config/Devin/Cache
rm -rf ~/.config/Devin/GPUCache
rm -rf ~/.config/Devin/Code\ Cache
rm -rf ~/.config/Devin/DawnWebGPUCache
rm -rf ~/.config/Devin/DawnGraphiteCache
rm -rf ~/.config/Devin/CachedExtensionVSIXs
```

### Windows

```powershell
Remove-Item -Recurse -Force "$env:APPDATA\Devin\CachedData"
Remove-Item -Recurse -Force "$env:APPDATA\Devin\Cache"
Remove-Item -Recurse -Force "$env:APPDATA\Devin\GPUCache"
Remove-Item -Recurse -Force "$env:APPDATA\Devin\Code Cache"
Remove-Item -Recurse -Force "$env:APPDATA\Devin\DawnWebGPUCache"
Remove-Item -Recurse -Force "$env:APPDATA\Devin\DawnGraphiteCache"
Remove-Item -Recurse -Force "$env:APPDATA\Devin\CachedExtensionVSIXs"
```

## Folders To Avoid Cleaning By Default

- `IndexedDB`
- `WebStorage`
- `Local Storage`
- `Session Storage`
- `Service Worker`

These locations are closer to persistent site and session data in Electron, so
cleaning them may require signing in again for embedded Devin services.

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
4. Whether Devin logs show MCP launch errors.

### 5. Terminal session gets stuck

Common causes include heavy `zsh` themes, `Oh My Zsh`, `Powerlevel10k`, or
Linux systemd OSC terminal context tracking.

### 6. “Devin is damaged” on macOS

Make sure the app is in `/Applications`, matches your chip architecture, then
run:

```bash
xattr -c "/Applications/Devin.app/"
```

### 7. Silent crash on Linux

This often comes from broken `chrome-sandbox` permissions:

```bash
sudo chown root:root /path/to/devin/chrome-sandbox
sudo chmod 4755 /path/to/devin/chrome-sandbox
```

### 8. Chinese output is garbled on Windows

The PowerShell script is stored as `UTF-8 with BOM` and sets both input and
output encoding to UTF-8 at runtime. Reverting to `GBK` is not recommended.

## macOS System Cleanup Script

`macos-safe-cleanup.sh` is better suited for system-wide and developer-cache
cleanup. Its current behavior is:

- It cleans Devin `CachedData`, `Cache`, `GPUCache`, `Code Cache`, and
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
  Windows uses `%USERPROFILE%\.codeium\devin\cascade`.
- MCP config:
  macOS / Linux use `~/.codeium/windsurf/mcp_config.json`;
  Windows uses `%USERPROFILE%\.codeium\devin\mcp_config.json`.
- macOS runtime cache:
  `~/Library/Application Support/Devin`
- Linux runtime cache:
  `~/.config/Devin`
- Windows runtime cache:
  `%APPDATA%\Devin`

## Network Whitelist

If you are behind a firewall, VPN, proxy, or enterprise network policy, make
sure these domains are reachable:

- `*.codeium.com`
- `*.devin.com`
- `*.codeiumdata.com`

## References

- [Official Devin Troubleshooting](https://docs.devin.com/troubleshooting/devin-common-issues)
- [Devin Terminal Documentation](https://docs.devin.com/devin/terminal)
- [Devin MCP Documentation](https://docs.devin.com/devin/cascade/mcp)
- [PowerShell File Encoding Guidance](https://learn.microsoft.com/en-us/powershell/scripting/dev-cross-plat/vscode/understanding-file-encoding?view=powershell-7.5)
- [Devin cleaning guide](./DEVIN-CLEANING-GUIDE.md)

## Author

- WeChat: `1837620622` (传康Kk)
- Email: `2040168455@qq.com`
- Xianyu / Bilibili: `万能程序员`

## License

MIT
