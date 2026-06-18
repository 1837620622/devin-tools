# Windsurf 与 macOS 清理参考手册

> 针对 **"Cascade 对话长就卡顿"** 和 **"绕过限速/刷新会话"** 两大核心诉求整理。
> 作者：传康Kk · GitHub: <https://github.com/1837620622/devin>

## 0. 运行模式（重要）

工具默认运行在 **强制重置模式**。所有清理菜单完成后会**自动重置 Windsurf 设备 ID**（installation_id / machineid / telemetry.*）。

| 模式 | 行为 | 如何启用 |
|:-:|:-|:-|
| **强制重置（默认）** | 清理完立即重置 ID，重启 Windsurf 可能需要重登 | 直接运行脚本 |
| **保守模式** | 清理不动 ID，保留登录态 | `FORCE_RESET_ID=0 bash fix-windsurf-mac.sh` |

### 为什么默认强制重置？

- **绕过限速**：重置后 Windsurf 服务端把你当成新设备，免费额度重新计算
- **刷新会话**：解决服务端缓存异常、奇怪的鉴权问题
- **防止指纹追踪**：让每次清理都是真正的"全新开始"

### 强制重置会改哪些值？

| 位置 | 字段 | 备注 |
|:-|:-|:-|
| `~/.codeium/windsurf/installation_id` | 整个 UUID | 重生成 |
| `~/Library/Application Support/Windsurf/machineid` | 整个 UUID | 重生成 |
| `.../globalStorage/storage.json` | `telemetry.devDeviceId` | 重生成 UUID |
| `.../globalStorage/storage.json` | `telemetry.macMachineId` | 重生成 32 hex |
| `.../globalStorage/storage.json` | `telemetry.machineId` | 重生成 64 hex |
| `.../globalStorage/storage.json` | `telemetry.sqmId` | 重生成大写 UUID |
| `.../globalStorage/state.vscdb` (SQLite) | `storage.serviceMachineId` | 重生成 UUID |
| **Windows 专属** | `HKLM\SOFTWARE\Microsoft\Cryptography\MachineGuid` | 重生成 UUID（需管理员） |

### 逃生通道

如果你**明确要保留登录态**，只做清理不重置，用：

```bash
# macOS
FORCE_RESET_ID=0 bash fix-windsurf-mac.sh

# Linux
FORCE_RESET_ID=0 bash fix-windsurf-linux.sh

# Windows PowerShell
$env:FORCE_RESET_ID="0"; .\fix-windsurf-win.ps1
```

## 一、卡顿根因（请按顺序排查）

| 序号 | 根因 | 表现 | 对应治理 |
|:-:|:-|:-|:-|
| 1 | **对话历史文件累计过大** | 切换对话、启动慢 | `fix-windsurf-mac.sh` 菜单 **23**（归档） |
| 2 | **`state.vscdb` 积累碎片** | 每次点击操作都变卡 | 菜单 **24** 的 VACUUM 步骤 |
| 3 | **`workspaceStorage/*/state.vscdb` 碎片** | 切换工作区慢 | 菜单 **18/24** 会自动 VACUUM |
| 4 | **Electron 内核缓存膨胀** | 首次启动慢 | 菜单 **18/20/24** |
| 5 | **IndexedDB leveldb 膨胀** | Cascade 面板响应慢 | 菜单 **18/24**（已默认清） |
| 6 | **大量 `node_modules` 被监视** | CPU 持续高 | 在 `settings.json` 里加 `files.watcherExclude` |
| 7 | **language_server 僵尸进程** | 内存 10GB+ | 菜单 **19** 监控 + 关闭重启 |
| 8 | **Zsh 主题（p10k 等）挂在终端** | 打开终端转圈 | 菜单 **9** 自动检测 |

## 二、Windsurf 数据目录详解

### 2.1 数据类型与存储路径

| 类型 | 路径 | 作用 | 能否清理 |
|:-|:-|:-|:-:|
| **对话历史** | `~/.codeium/windsurf/cascade/*.pb` | 每次 Cascade 对话的完整记录（单文件可达 27MB+） | ❌ 不能删，可**归档** |
| **用户记忆** | `~/.codeium/windsurf/memories/` | Memories 和 global_rules | ❌ 不能删 |
| **技能** | `~/.codeium/windsurf/skills/` | 已安装 Skills | ❌ 不能删 |
| **MCP 配置** | `~/.codeium/windsurf/mcp_config.json` | MCP 服务器配置 | ❌ 不能删 |
| **用户偏好** | `~/.codeium/windsurf/user_settings.pb` | Cascade 偏好 | ❌ 不能删 |
| **设备 ID** | `~/.codeium/windsurf/installation_id` | Windsurf 设备标识（与登录关联） | ❌ 不能删 |
| **AI 索引** | `~/.codeium/windsurf/implicit/`、`code_tracker/` | 代码追踪索引，可重建 | ✅ 可清 |
| **VSCode 设置** | `~/Library/Application Support/Windsurf/User/settings.json` | 个人编辑器配置 | ❌ 不能删 |
| **快捷键** | `~/Library/Application Support/Windsurf/User/keybindings.json` | 自定义快捷键 | ❌ 不能删 |
| **全局状态** | `~/Library/Application Support/Windsurf/User/globalStorage/state.vscdb` | 工作区列表、最近文件 | 🟡 只能 VACUUM，不能删 |
| **全局状态备份** | `.../globalStorage/state.vscdb.backup` | 旧版 SQLite 备份 | ✅ 可清 |
| **工作区状态** | `.../User/workspaceStorage/<hash>/state.vscdb` | 每个工作区的独立状态（打开的文件、断点等） | 🟡 只能 VACUUM，不能删 |
| **对话索引备份** | `.../User/workspaceStorage/<hash>/state.vscdb.backup` | — | ✅ 可清 |
| **机器 ID** | `~/Library/Application Support/Windsurf/machineid` | Electron 机器 ID | ❌ 不能删 |
| **登录 Cookies** | `.../Windsurf/Cookies`、`Cookies-journal` | 登录凭证 | ❌ 不能删 |
| **Local Storage** | `.../Windsurf/Local Storage/leveldb/` | 内嵌网页会话 | ❌ 不能删 |
| **WebStorage** | `.../Windsurf/WebStorage/` | 内嵌网页登录态 | ❌ 不能删 |
| **Electron Cache** | `.../Windsurf/Cache/`、`CachedData/`、`GPUCache/`、`Code Cache/`、`DawnWebGPUCache/`、`DawnGraphiteCache/` | Chromium 内核缓存 | ✅ 可清 |
| **Shared Dictionary** | `.../Windsurf/Shared Dictionary/` | 压缩字典缓存 | ✅ 可清 |
| **IndexedDB** | `.../Windsurf/IndexedDB/vscode-file_vscode-app_0.*` | **VSCode webview 的 UI 状态**（非登录！） | ✅ 可清 |
| **Service Worker** | `.../Windsurf/Service Worker/CacheStorage`、`ScriptCache` | Chromium SW 资源 | ✅ 可清 |
| **blob_storage** | `.../Windsurf/blob_storage/` | 临时 Blob 对象 | ✅ 可清 |
| **运行日志** | `.../Windsurf/logs/` | 文本日志 | ✅ 可清 |
| **崩溃报告** | `.../Windsurf/Crashpad/completed/`、`pending/` | 崩溃 dump | ✅ 可清 |
| **扩展旧包** | `.../Windsurf/CachedExtensionVSIXs/`、`CachedProfilesData/` | 扩展安装包残留 | ✅ 可清 |
| **终端快照** | `/tmp/windsurf-terminal-*.snapshot` | Cascade 终端快照 | ✅ 可清 |

### 2.2 卡顿治理优先级

```
第一优先（零风险，立即执行）：
  菜单 24：卡顿快速诊断 + 一键安全优化
    └─ VACUUM 全局/所有工作区 state.vscdb
    └─ 清 Cache/CachedData/GPUCache/Code Cache
    └─ 清 IndexedDB/Service Worker 缓存
    └─ 清 logs/Crashpad/implicit/code_tracker

第二优先（低风险，解决"启动慢"）：
  菜单 20：一键智能优化（会做第一阶段深清理，默认不动登录）

第三优先（仅当对话已累计 >200MB）：
  菜单 23：Cascade 对话归档
    └─ 把 30 天以上 或 10MB 以上的对话移动到备份目录
    └─ 可随时通过归档目录里的 restore.sh 恢复

最后手段（仅当完全无法使用）：
  菜单 1：清 Cascade 缓存（会丢对话历史！）
  菜单 17：重置 Windsurf ID（会强制重登）
```

## 三、macOS 清理边界

### 3.1 ✅ 安全可清（系统会自动重建）

| 路径 | 说明 |
|:-|:-|
| `~/Library/Caches/<app>/`（除保护列表外） | 应用缓存 |
| `~/Library/Logs/` 30 天以上 | 应用日志 |
| `~/Library/Saved Application State/` | 应用窗口位置缓存 |
| `~/Library/WebKit/*/Caches/`、`WebsiteData/` | WebKit 缓存 |
| `~/.Trash/` | 废纸篓 |
| `~/Library/Containers/com.apple.mediaanalysisd/Data/Library/Caches/` | 照片 ML 分析缓存 |
| `/private/var/folders/*/C/`（7 天以上） | 用户态临时缓存 |
| `/private/var/folders/*/T/`（7 天以上，排除 ask-continue-ports） | 临时文件 |
| `/private/var/db/diagnostics/` | Apple 统一日志 |
| `/private/var/db/uuidtext/` | 日志 UUID 文本 |
| `/private/var/log/*.log` 30 天以上 | 系统日志 |
| `~/Library/Developer/Xcode/DerivedData/` | Xcode 派生数据 |
| `~/Library/Developer/CoreSimulator/` | iOS 模拟器数据（会全部重置） |
| `$(brew --cache)` | Homebrew 下载缓存 |
| `~/.npm/_cacache/`、`~/.npm/_npx/` | npm 缓存 |
| `~/Library/Caches/pip/`、`~/.cache/uv/` | Python 包缓存 |
| `~/.m2/repository/`（小心：会重新下载所有 Maven 依赖） | Maven 仓库 |
| `~/Library/Caches/ms-playwright/` | Playwright 浏览器 |
| 下载目录下的 `node_modules/` | 可用 `npm install` 重建 |
| 项目里的 `__pycache__/` | Python 会重建 |

### 3.2 ❌ 绝对不能清（会损坏系统/iCloud/登录）

| 路径 | 后果 |
|:-|:-|
| `~/Library/Mobile Documents/` | **iCloud Drive 数据本体！** 不是缓存 |
| `~/Library/Caches/com.apple.bird` | iCloud 文件提供程序，删后要重新下载 iCloud |
| `~/Library/Caches/CloudKit` | iCloud 同步状态 |
| `~/Library/Caches/com.apple.nsurlsessiond` | 后台下载任务 |
| `~/Library/Caches/FamilyCircle` | 家人共享 |
| `~/Library/Keychains/` | **钥匙串！** 删后丢所有密码 |
| `~/Library/Cookies/` | 系统级 Cookies |
| `/System/Library/Caches/` | 系统级缓存 |
| `/private/var/db/Spotlight-V100/` | Spotlight 索引（删后重建要几小时） |
| `/var/db/receipts/` | 软件安装记录 |
| `/Library/Caches/com.apple.coresymbolicationd` | 符号表，影响崩溃日志 |
| `.Spotlight-V100`、`.fseventsd`、`.DocumentRevisions-V100`、`.TemporaryItems` | 系统隐藏目录 |

## 四、常见问题

### Q1：清理后 Windsurf 需要重新登录吗？
A：本工具的菜单 **2/3/18/20/23/24** 都不会清理登录相关目录，不会导致重新登录。只有菜单 **1**（会删对话）、**17**（重置 ID）、**18 第二阶段**（手动确认）才会影响登录。

### Q2：对话归档后怎么恢复？
A：归档目录里会自动生成 `restore.sh`，运行 `bash ~/.windsurf-conversations-archive-*/restore.sh` 即可一键恢复；或手动 `cp ~/.windsurf-conversations-archive-*/<file>.pb ~/.codeium/windsurf/cascade/`。

### Q3：VACUUM 是什么？会丢数据吗？
A：SQLite 的 `VACUUM` 命令把数据库文件中的"碎片页"（删除行留下的空洞）整理掉，重新紧凑写入。**不会丢任何数据**，只是压缩。官方有 issue 实测可从 298MB 压到 639KB（<https://github.com/microsoft/vscode/issues/235684>）。

### Q4：Cascade 对话历史为什么会让 Windsurf 卡？
A：Windsurf 启动时会扫描 `~/.codeium/windsurf/cascade/` 目录，切换对话时要读取对应 `.pb`（protobuf 序列化）。单个对话文件可达 27MB+。当目录内有 50+ 个文件、累计 300MB+ 时，切换/启动延迟会很明显。归档到外部目录后，Windsurf 只需加载保留的近期对话，体感显著变快。

### Q5：为什么要保留 Windsurf 不自动清对话？
A：Windsurf 官方没有"清对话"按钮，但社区反馈显示 Cascade 的内存/IO 压力随对话历史线性增长（<https://boostdevspeed.com/blog/windsurf-ide-10gb-ram-memory-leak-fix>）。归档是当前唯一**既保留所有对话又缓解卡顿**的方案。

## 五、推荐的维护节奏

| 频率 | 操作 | 耗时 |
|:-:|:-|:-:|
| 每天 | 无需操作 | — |
| 每周一次 | `fix-windsurf-mac.sh` 菜单 **24**（卡顿诊断 + 一键优化） | 1 分钟 |
| 每月一次 | `fix-windsurf-mac.sh` 菜单 **20**（一键智能优化） | 2 分钟 |
| 对话 >200MB 时 | 菜单 **23**（对话归档） | 1 分钟 |
| 每季度一次 | `macos-safe-cleanup.sh`（全量系统清理） | 10 分钟 |
| 需要重置账号 | 菜单 **17**（重置 ID，注意会重登） | 1 分钟 |

## 六、工具来源与引用

- Windsurf 官方故障排除：<https://docs.windsurf.com/troubleshooting/windsurf-common-issues>
- VSCode state.vscdb VACUUM issue：<https://github.com/microsoft/vscode/issues/235684>
- Windsurf 内存泄漏分析：<https://boostdevspeed.com/blog/windsurf-ide-10gb-ram-memory-leak-fix>
- macOS `/private/var/folders` 安全性：<https://apple.stackexchange.com/questions/176371>
- 社区 Cascade 卡顿讨论：<https://www.reddit.com/r/Codeium/comments/1jrjpx1>

---

**作者**：传康Kk · 微信 1837620622 · 邮箱 2040168455@qq.com
**GitHub**：<https://github.com/1837620622/devin>
