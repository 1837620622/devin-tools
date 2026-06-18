#!/bin/bash
# 统一 UTF-8 终端环境，针对 macOS 设为 en_US.UTF-8 以彻底解决乱码问题。
if [ "$(uname)" = "Darwin" ]; then
    export LANG="en_US.UTF-8"
    export LC_ALL="en_US.UTF-8"
else
    export LANG="${LANG:-C.UTF-8}"
    export LC_ALL="${LC_ALL:-C.UTF-8}"
fi

# ============================================================================
# macOS 系统数据安全清理脚本
# 针对你的系统定制，只清理可安全删除的缓存和临时文件
# 不会清理：应用程序、用户文档、聊天记录、邮件、配置文件
# 作者: 传康KK
# GitHub: https://github.com/1837620622/devin-tools
# ============================================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
SECTION_BAR="--------------------------------------------"

# 统计变量
TOTAL_FREED=0
DRY_RUN=0
ASSUME_YES=0
ASSUME_NO=0
SAFE_AUTO=0
CODEX_DIR="${CODEX_HOME:-$HOME/.codex}"

# ----------------------------------------------------------------------------
# 运行模式参数
# ----------------------------------------------------------------------------
for arg in "$@"; do
    case "$arg" in
        --dry-run)
            DRY_RUN=1
            ;;
        --scan-only)
            DRY_RUN=1
            ASSUME_NO=1
            ;;
        --yes)
            ASSUME_YES=1
            ;;
        --safe-auto)
            SAFE_AUTO=1
            ;;
        --help|-h)
            echo "用法: $0 [--dry-run] [--scan-only] [--safe-auto] [--yes]"
            echo "  --dry-run    演练模式：显示将清理的项目，但不删除"
            echo "  --scan-only  只扫描不清理：自动回答否"
            echo "  --safe-auto  保守自动清理：只自动确认明确可重建的应用缓存/日志，跳过系统、网络、开发仓库和身份数据"
            echo "  --yes        自动确认所有普通提示，危险项仍需要环境变量显式允许"
            exit 0
            ;;
    esac
done

# ----------------------------------------------------------------------------
# 工具函数
# ----------------------------------------------------------------------------
print_info()    { echo -e "${BLUE}[信息]${NC} $1"; }
print_success() { echo -e "${GREEN}[完成]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[警告]${NC} $1"; }

# 获取目录大小（字节）
get_size_bytes() {
    if [ -d "$1" ] || [ -f "$1" ]; then
        du -sk "$1" 2>/dev/null | awk '{print $1 * 1024}'
    else
        echo 0
    fi
}

# 格式化大小显示
format_size() {
    local bytes=$1
    if [ "$bytes" -ge 1073741824 ]; then
        echo "$(echo "scale=1; $bytes / 1073741824" | bc)GB"
    elif [ "$bytes" -ge 1048576 ]; then
        echo "$(echo "scale=1; $bytes / 1048576" | bc)MB"
    elif [ "$bytes" -ge 1024 ]; then
        echo "$(echo "scale=0; $bytes / 1024" | bc)KB"
    else
        echo "${bytes}B"
    fi
}

# 确认操作（直接回车即默认为 Yes）
confirm() {
    local prompt="${1//？/?}"
    if [ "$ASSUME_NO" -eq 1 ] 2>/dev/null; then
        printf "%b%s [Y/n]: n%b\n" "${YELLOW}" "$prompt" "${NC}"
        return 1
    fi
    if [ "$SAFE_AUTO" -eq 1 ] 2>/dev/null; then
            case "$prompt" in
                *"WPS Office 缓存"*|*"Telegram 缓存"*|*"Telegram 临时目录和日志"*|*"Telegram 临时目录、日志和媒体缓存"*|*"QQ 可重建缓存"*|*"Google Chrome 缓存"*|*"Chrome 缓存"*|*"Choice 临时与日志缓存"*|*"Claude Code 纯缓存"*|*"Gemini CLI 缓存"*|*"OpenCode 浏览器缓存"*|*"Codex 日志"*|*"清理所有 __pycache__"*|*"WebKit Caches"*|*"这些可重建缓存"*|*"废纸篓"*|*"Devin 缓存"*|*"腾讯会议"*|*"Photos 缩略图"*|*"iMessage 缓存"*|*"uv/tools"*|*"诊断报告"*|*"Codeium/Devin AI"*|*"先退出"*)
                printf "%b%s [Y/n]: y (safe-auto)%b\n" "${YELLOW}" "$prompt" "${NC}"
                return 0
                ;;
            *)
                printf "%b%s [Y/n]: n (safe-auto)%b\n" "${YELLOW}" "$prompt" "${NC}"
                return 1
                ;;
        esac
    fi
    if [ "$ASSUME_YES" -eq 1 ] 2>/dev/null; then
        printf "%b%s [Y/n]: y%b\n" "${YELLOW}" "$prompt" "${NC}"
        return 0
    fi
    printf "%b%s [Y/n]: %b" "${YELLOW}" "$prompt" "${NC}"
    read -r choice
    case "$choice" in
        ""|[yY]|[yY][eE][sS]|[yY][eE] ) return 0;;
        * ) return 1;;
    esac
}

# 静默清理目录内容（保留目录本身，用于大类合并清理）
silent_clean_dir() {
    local dir="$1"
    local desc="$2"
    if [ -d "$dir" ]; then
        if is_protected_path "$dir"; then
            print_warning "  已保护，跳过：$dir"
            return 0
        fi
        if path_has_open_files "$dir"; then
            print_warning "  正在被应用使用，跳过：$dir"
            return 0
        fi
        local before=$(get_size_bytes "$dir")
        if [ "$before" -gt 0 ]; then
            echo -e "  ${CYAN}$desc${NC}: $(format_size $before)"
            if [ "$DRY_RUN" -eq 1 ] 2>/dev/null; then
                print_info "  演练模式：不删除"
                return 0
            fi
            find "$dir" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null
            local after=$(get_size_bytes "$dir")
            local freed=$((before - after))
            [ "$freed" -lt 0 ] && freed=0
            TOTAL_FREED=$((TOTAL_FREED + freed))
            print_success "  已清理 $(format_size $freed)"
        fi
    fi
}

# 静默删除整个目录（用于大类合并清理）
silent_remove_dir() {
    local dir="$1"
    local desc="$2"
    if [ -d "$dir" ]; then
        if is_protected_path "$dir"; then
            print_warning "  已保护，跳过：$dir"
            return 0
        fi
        if path_has_open_files "$dir"; then
            print_warning "  正在被应用使用，跳过：$dir"
            return 0
        fi
        local before=$(get_size_bytes "$dir")
        if [ "$before" -gt 0 ]; then
            echo -e "  ${CYAN}$desc${NC}: $(format_size $before)"
            if [ "$DRY_RUN" -eq 1 ] 2>/dev/null; then
                print_info "  演练模式：不删除"
                return 0
            fi
            rm -rf "$dir" 2>/dev/null
            local after=0
            [ -e "$dir" ] && after=$(get_size_bytes "$dir")
            local freed=$((before - after))
            [ "$freed" -lt 0 ] && freed=0
            TOTAL_FREED=$((TOTAL_FREED + freed))
            print_success "  已清理 $(format_size $freed)"
        fi
    fi
}

# 安全删除目录内容（保留目录本身）
safe_clean_dir() {
    local dir="$1"
    local desc="$2"
    if [ -d "$dir" ]; then
        local size=$(get_size_bytes "$dir")
        if [ "$size" -gt 0 ]; then
            echo -e "  ${CYAN}$desc${NC}: $(format_size $size)"
            if confirm "  清理此项？"; then
                silent_clean_dir "$dir" "$desc"
            else
                print_info "  已跳过"
            fi
        fi
    fi
}

# 安全删除整个目录
safe_remove_dir() {
    local dir="$1"
    local desc="$2"
    if [ -d "$dir" ]; then
        local size=$(get_size_bytes "$dir")
        if [ "$size" -gt 0 ]; then
            echo -e "  ${CYAN}$desc${NC}: $(format_size $size)"
            if confirm "  清理此项？"; then
                silent_remove_dir "$dir" "$desc"
            else
                print_info "  已跳过"
            fi
        fi
    fi
}

# 优雅终止应用进程（先 AppleScript 退出，再 SIGTERM，最后 SIGKILL）
# 避免清理运行中应用的缓存导致数据库损坏。只在用户确认后才调用。
kill_app_process() {
    local app_name="$1"
    local bundle_id="$2"
    if [ "$DRY_RUN" -eq 1 ] 2>/dev/null; then
        print_info "  演练模式：不终止 $app_name"
        return 0
    fi
    # 先尝试 AppleScript 优雅退出
    osascript -e "tell application id \"$bundle_id\" to quit" 2>/dev/null
    sleep 2
    # 检查是否还在运行
    if pgrep -f "$bundle_id" >/dev/null 2>&1; then
        pkill -15 -f "$bundle_id" 2>/dev/null
        sleep 2
    fi
    # 仍运行则强制杀
    if pgrep -f "$bundle_id" >/dev/null 2>&1; then
        pkill -9 -f "$bundle_id" 2>/dev/null
        sleep 1
    fi
    if pgrep -f "$bundle_id" >/dev/null 2>&1; then
        print_warning "  $app_name 仍在运行，可能需要手动退出"
        return 1
    else
        print_success "  $app_name 已退出"
        return 0
    fi
}

# 判断路径是否属于绝对保护区。保护区只允许提示，不允许脚本删除。
is_protected_path() {
    local target="$1"
    case "$target" in
        # Apple 账户、钥匙串、iCloud、系统网络配置与证书，任何清理步骤均不得触碰。
        "$HOME/Library/Keychains"*|"/Library/Keychains"*|"/System/Library/Keychains"*) return 0 ;;
        "$HOME/Library/Mobile Documents"*|"$HOME/Library/Caches/com.apple.bird"*|"$HOME/Library/Caches/CloudKit"*|"$HOME/Library/Caches/com.apple.nsurlsessiond"*) return 0 ;;
        "/Library/Preferences/SystemConfiguration"*|"/Library/Network"*|"$HOME/Library/Preferences/com.apple.networkextension"*|"$HOME/Library/Group Containers/group.com.apple.networkextension"*) return 0 ;;

        # 代理、VPN、TUN、防火墙和网络扩展：用户明确要求不动 Clash/VPN，本脚本只做硬保护。
        "$HOME/Library/Application Support/io.github.clash-verge-rev.clash-verge-rev"*|"$HOME/Library/Caches/io.github.clash-verge-rev.clash-verge-rev"*) return 0 ;;
        "$HOME/Library/Application Support/Clash"*|"$HOME/Library/Application Support/clash"*|"$HOME/Library/Application Support/mihomo"*|"$HOME/Library/Caches/Clash"*|"$HOME/Library/Caches/clash"*|"$HOME/Library/Caches/mihomo"*) return 0 ;;
        "$HOME/Library/Application Support/ClashX"*|"$HOME/Library/Preferences/com.west2online.ClashX"*|"$HOME/Library/Preferences/com.cfwapp.clashx"*) return 0 ;;
        "$HOME/.ShadowsocksX-NG"*|"$HOME/.config/clash"*|"$HOME/.config/mihomo"*|"$HOME/.config/tailscale"*) return 0 ;;
        "$HOME/Library/Group Containers/group.com.liguangming.Shadowrocket"*|"$HOME/Library/Group Containers/group.io.norselabs.dvpn"*|"$HOME/Library/Group Containers/group.com.fish.stream"*|"$HOME/Library/Group Containers/group.com.moonlight.app"*) return 0 ;;
        "$HOME/Library/Application Support/Tailscale"*|"$HOME/Library/Containers/io.tailscale.ipn.macos"*|"$HOME/Library/Caches/io.tailscale.ipn.macos"*) return 0 ;;
        "$HOME/Library/Application Support/Little Snitch"*|"$HOME/Library/Preferences/at.obdev.LittleSnitch"*|"/Library/Application Support/Objective Development/Little Snitch"*|"/Library/Preferences/at.obdev.LittleSnitch"*|"/Library/LaunchDaemons/at.obdev"*) return 0 ;;

        # Devin / Codex / MCP 运行态与登录态，避免清缓存后工具链失效。
        "$HOME/.codeium/windsurf/mcp_config.json"|"$HOME/.codeium/windsurf/cascade"*|"$HOME/.codeium/windsurf/memories"*|"$HOME/.codeium/windsurf/skills"*|"$HOME/.codeium/windsurf/installation_id"|"$HOME/.codeium/windsurf/user_settings.pb") return 0 ;;
        "$HOME/Library/Application Support/Devin/Cookies"*|"$HOME/Library/Application Support/Devin/Local Storage"*|"$HOME/Library/Application Support/Devin/WebStorage"*|"$HOME/Library/Application Support/Devin/User/settings.json"|"$HOME/Library/Application Support/Devin/machineid") return 0 ;;
        "$CODEX_DIR/config.toml"*|"$CODEX_DIR/auth.json"*|"$CODEX_DIR/session_index.jsonl"*|"$CODEX_DIR/installation_id") return 0 ;;
        "$CODEX_DIR/plugins"*|"$CODEX_DIR/local-marketplaces"*|"$CODEX_DIR/skills"*|"$CODEX_DIR/sessions"*|"$CODEX_DIR/archived_sessions"*|"$CODEX_DIR/memories"*|"$CODEX_DIR/memories_1.sqlite"*) return 0 ;;
        "$CODEX_DIR/state_"*.sqlite*|"$CODEX_DIR/goals_"*.sqlite*|"$CODEX_DIR/computer-use"*|"$CODEX_DIR/vendor_imports"*|"$CODEX_DIR/cache"*) return 0 ;;
        "$CODEX_DIR/.tmp/plugins"*|"$CODEX_DIR/.tmp/plugins-clone-"*|"$CODEX_DIR/.tmp/marketplaces"*|"$CODEX_DIR/.tmp/bundled-marketplaces"*) return 0 ;;
        "$HOME/Library/Application Support/Codex"*) return 0 ;;
        # Claude Code MCP 主配置与插件本体（只清 plugins/cache，不删 plugins 本体）
        "$HOME/.claude.json"*|"$HOME/.claude/plugins"|"$HOME/.claude/plugins/"*) return 0 ;;
        "$HOME/.claude/projects"*|"$HOME/.claude/skills"*|"$HOME/.claude/settings.json"*|"$HOME/.claude/CLAUDE.md"*|"$HOME/.claude/override.md") return 0 ;;
        # 切号工具配置与账号凭据数据库（含多账号 token，严禁清理）
        "$HOME/.cc-switch"*|"$HOME/.antigravity_cockpit"*|"$HOME/.antigravitycli"*) return 0 ;;
        # 系统凭据目录
        "$HOME/.ssh"*|"$HOME/.aws"*|"$HOME/.gnupg"*|"$HOME/.kaggle"*|"$HOME/.cdsapirc"*|"$HOME/.docker"*|"$HOME/.kube"*) return 0 ;;
        # Devin 登录态与会话（只清纯缓存，保护登录态）
        "$HOME/Library/Application Support/Devin/Local Storage"*|"$HOME/Library/Application Support/Devin/Cookies"*|"$HOME/Library/Application Support/Devin/User"*|"$HOME/Library/Application Support/Devin/IndexedDB"*) return 0 ;;
        # Qoder CN 整个目录保护（清理后会丢失账号信息，用户明确要求不清理）
        "$HOME/Library/Application Support/QoderCN"*) return 0 ;;
        # MostLogin 内置浏览器二进制与登录态
        "$HOME/Library/Application Support/MostLogin/chrome-bin"*|"$HOME/Library/Application Support/MostLogin/profile-user-data"*|"$HOME/Library/Application Support/MostLogin/Fonts"*) return 0 ;;

        # 聊天数据库、附件主目录与云文档缓存，本脚本只允许清理外围临时缓存。
        "$HOME/Library/Containers/com.tencent.qq/Data/Library/Application Support/QQ/nt_qq_"*/nt_data/Msg*|"$HOME/Library/Containers/com.tencent.qq/Data/Library/Application Support/QQ/"*/FileRecv*|"$HOME/Library/Containers/com.tencent.qq/Data/Library/Application Support/QQ/"*/Image*) return 0 ;;
        "$HOME/Library/Containers/com.tencent.xinWeChat/Data/Documents/xwechat_files/"*/msg*|"$HOME/Library/Containers/com.tencent.xinWeChat/Data/Documents/xwechat_files/"*/FileStorage*|"$HOME/Library/Containers/com.tencent.xinWeChat/Data/Documents/xwechat_files/"*/Backup*) return 0 ;;
        "$HOME/Library/Group Containers/6N38VWS5BX.ru.keepcoder.Telegram/appstore/account-"*/postbox*|"$HOME/Library/Group Containers/6N38VWS5BX.ru.keepcoder.Telegram/appstore/account-"*/media*) return 0 ;;
        "$HOME/Library/Containers/com.kingsoft.wpsoffice.mac/Data/Library/Application Support/Kingsoft/WPS Cloud Files/userdata/qing/filecache"*) return 0 ;;
    esac
    return 1
}

# 判断目录或文件是否正在被进程使用；正在使用则跳过，避免损坏数据库和运行态缓存。
path_has_open_files() {
    local target="$1"
    command -v lsof >/dev/null 2>&1 || return 1
    [ -e "$target" ] || return 1
    local tmp="/tmp/macos_safe_cleanup_lsof_$$.txt"
    if [ -d "$target" ]; then
        lsof +D "$target" > "$tmp" 2>/dev/null
    else
        lsof "$target" > "$tmp" 2>/dev/null
    fi
    local lines=0
    [ -f "$tmp" ] && lines=$(wc -l < "$tmp" | tr -d ' ')
    rm -f "$tmp"
    [ "$lines" -gt 1 ] 2>/dev/null
}

# 只删除确认属于“可重建”的缓存、临时文件、日志、旧更新包。
safe_remove_rebuildable_path() {
    local target="$1"
    local desc="$2"
    [ -e "$target" ] || return 0
    if is_protected_path "$target"; then
        print_warning "  已保护，跳过：$target"
        return 0
    fi
    if path_has_open_files "$target"; then
        print_warning "  正在被应用使用，跳过：$target"
        return 0
    fi
    local before=$(get_size_bytes "$target")
    [ "$before" -le 0 ] 2>/dev/null && return 0
    echo -e "  ${CYAN}$desc${NC}: $(format_size $before)"
    if [ "$DRY_RUN" -eq 1 ] 2>/dev/null; then
        print_info "  演练模式：不删除"
        return 0
    fi
    rm -rf "$target" 2>/dev/null
    local after=0
    [ -e "$target" ] && after=$(get_size_bytes "$target")
    local freed=$((before - after))
    [ "$freed" -lt 0 ] && freed=0
    TOTAL_FREED=$((TOTAL_FREED + freed))
    print_success "  已清理 $(format_size $freed)"
}

# 计算 Codex 日志 SQLite 主库、WAL、SHM 的总大小。
calculate_sqlite_bundle_size_bytes() {
    local db="$1"
    local total=0
    local file_path
    for file_path in "$db" "$db-wal" "$db-shm"; do
        [ -e "$file_path" ] && total=$((total + $(get_size_bytes "$file_path")))
    done
    echo "$total"
}

# 只清空 Codex 运行日志表并压缩数据库，保留数据库文件结构。
clean_codex_log_db() {
    local db="$1"
    local desc="$2"
    [ -f "$db" ] || return 0

    local before
    before=$(calculate_sqlite_bundle_size_bytes "$db")
    [ "$before" -le 0 ] 2>/dev/null && return 0
    echo -e "  ${CYAN}$desc${NC}: $(format_size $before)"

    if [ "$DRY_RUN" -eq 1 ] 2>/dev/null; then
        print_info "  演练模式：不清空日志数据库"
        return 0
    fi
    if ! command -v sqlite3 >/dev/null 2>&1; then
        print_warning "  未找到 sqlite3，已跳过 Codex 日志数据库"
        return 0
    fi

    local has_logs_table
    has_logs_table=$(sqlite3 "$db" "SELECT name FROM sqlite_schema WHERE type='table' AND name='logs' LIMIT 1;" 2>/dev/null)
    if [ "$has_logs_table" != "logs" ]; then
        print_warning "  未找到 logs 表，已跳过：$db"
        return 0
    fi

    if sqlite3 "$db" "PRAGMA busy_timeout=15000; PRAGMA wal_checkpoint(TRUNCATE); DELETE FROM logs; VACUUM; PRAGMA wal_checkpoint(TRUNCATE);" >/dev/null 2>&1; then
        local after
        after=$(calculate_sqlite_bundle_size_bytes "$db")
        local freed=$((before - after))
        [ "$freed" -lt 0 ] && freed=0
        TOTAL_FREED=$((TOTAL_FREED + freed))
        print_success "  已清空 Codex 日志并压缩数据库，释放 $(format_size $freed)"
    else
        print_warning "  Codex 日志数据库正在被占用或无法写入，关闭 Codex 后再运行会更彻底"
    fi
}

# ----------------------------------------------------------------------------
# 启动横幅
# ----------------------------------------------------------------------------
echo ""
echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}  macOS 系统数据安全清理工具${NC}"
echo -e "${CYAN}  by 传康KK${NC}"
echo -e "${CYAN}  github.com/1837620622/devin-tools${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""
print_warning "此脚本只清理缓存和临时文件，不会删除重要数据"
print_info "每一步都会询问确认，可随时跳过"
if [ "$SAFE_AUTO" -eq 1 ] 2>/dev/null; then
    print_info "当前为保守自动清理模式：只自动确认明确可重建的应用缓存/日志；系统、网络、开发仓库、身份数据默认跳过"
fi
echo ""

# ----------------------------------------------------------------------------
# 登录与数据保护清单（硬编码，严格不动）
# ----------------------------------------------------------------------------
echo -e "${GREEN}[保护清单]${NC} 以下路径在本脚本任何步骤中均不会被清理："
echo -e "  ${CYAN}iCloud / Apple 系统${NC}"
echo -e "    ~/Library/Mobile Documents/                  iCloud Drive 数据本体"
echo -e "    ~/Library/Caches/com.apple.bird              iCloud 文件提供程序缓存"
echo -e "    ~/Library/Caches/CloudKit                    iCloud 同步缓存"
echo -e "    ~/Library/Caches/com.apple.nsurlsessiond     后台下载"
echo -e "    ~/Library/Keychains/                         钥匙串（密码）"
echo -e "    /private/var/db/Spotlight-V100/              Spotlight 索引"
echo -e "    /System/Library/Caches/                      系统级缓存"
echo -e "  ${CYAN}Devin 登录与对话${NC}"
echo -e "    ~/.codeium/windsurf/cascade/*.pb             对话历史"
echo -e "    ~/.codeium/windsurf/memories/                用户记忆"
echo -e "    ~/.codeium/windsurf/skills/                  技能"
echo -e "    ~/.codeium/windsurf/mcp_config.json          MCP 配置"
echo -e "    ~/.codeium/windsurf/installation_id          设备标识"
echo -e "    ~/.codeium/windsurf/user_settings.pb         用户设置"
echo -e "    ~/Library/Application Support/Devin/Cookies*       登录 Cookies"
echo -e "    ~/Library/Application Support/Devin/Local Storage  会话数据"
echo -e "    ~/Library/Application Support/Devin/WebStorage     内嵌登录态"
echo -e "    ~/Library/Application Support/Devin/User/settings.json  编辑器设置"
echo -e "    ~/Library/Application Support/Devin/machineid      设备 ID"
echo -e "  ${CYAN}Claude Code MCP 与插件${NC}"
echo -e "    ~/.claude.json                               MCP 主配置（git/context7/playwright等）"
echo -e "    ~/.claude/plugins/                           插件本体（只清 plugins/cache）"
echo -e "    ~/.claude/projects/                          项目历史"
echo -e "    ~/.claude/skills/                            技能"
echo -e "    ~/.claude/settings.json                      编辑器设置"
echo -e "  ${CYAN}切号工具与账号凭据${NC}"
echo -e "    ~/.cc-switch/                                cc-switch 账号数据库与凭据"
echo -e "    ~/.antigravity_cockpit/                      antigravity 多账号 token"
echo -e "    ~/.ssh ~/.aws ~/.gnupg ~/.kaggle            系统凭据目录"
echo -e "  ${CYAN}Qoder / Devin 登录态${NC}"
echo -e "    ~/Library/Application Support/QoderCN/       Qoder 整个目录（清理会丢账号）"
echo -e "    ~/Library/Application Support/Devin/Local Storage 等   Devin 登录态与会话"
echo -e "  ${CYAN}Codex 插件、对话与记忆${NC}"
echo -e "    ~/.codex/plugins/                         插件缓存和 MCP 插件本体"
echo -e "    ~/.codex/local-marketplaces/              本地插件 marketplace"
echo -e "    ~/.codex/.tmp/plugins*                    远程插件临时克隆"
echo -e "    ~/.codex/.tmp/bundled-marketplaces*       bundled 插件 marketplace"
echo -e "    ~/.codex/skills/                          skills"
echo -e "    ~/.codex/sessions/                        对话会话"
echo -e "    ~/.codex/memories*                        记忆"
echo -e "    ~/.codex/config.toml / auth.json          配置和登录认证"
echo -e "    ~/.codex/computer-use/                    Computer Use 本地服务"
echo -e "    ~/.codex/logs_*.sqlite                    仅在 Codex 日志专项中清空 logs 表"
echo -e "  ${CYAN}网络、代理与证书${NC}"
echo -e "    Clash Verge / mihomo / Shadowrocket / Tailscale / Little Snitch 相关目录"
echo -e "    ~/Library/Keychains/                         钥匙串与证书"
echo -e "    ~/Library/Group Containers/group.com.liguangming.Shadowrocket"
echo -e "    ~/Library/Application Support/io.github.clash-verge-rev.clash-verge-rev"
echo -e "  ${CYAN}聊天、账号与文档${NC}"
echo -e "    微信/QQ/Telegram 主数据库、聊天附件、FileRecv、云文档 filecache 默认只扫描不删除"
echo ""

# ============================================================================
# 第一部分：低风险清理（纯缓存，删除后系统自动重建）
# ============================================================================
echo -e "\n${GREEN}${SECTION_BAR}${NC}"
echo -e "${GREEN}  第一部分: 低风险清理（纯缓存，系统会自动重建）${NC}"
echo -e "${GREEN}${SECTION_BAR}${NC}\n"

# 1. 用户基础应用缓存、系统日志与照片ML分析数据
print_info "1. 用户基础应用缓存、系统日志与照片ML分析数据"
print_warning "系统核心数据（如 iCloud/Apple 登录凭证等）已自动加以保护和隔离"
if confirm "  是否清理用户应用缓存、日志以及照片ML分析数据？"; then
    # 1.1 用户缓存目录（排除 iCloud / Apple 系统关键缓存）
    if [ -d "$HOME/Library/Caches" ]; then
        PROTECTED_CACHES=(
            "com.apple.bird"                    # iCloud 文件提供程序
            "CloudKit"                          # iCloud 同步缓存
            "com.apple.nsurlsessiond"           # 后台下载
            "FamilyCircle"                      # 家人共享
            "com.apple.iCloudHelper"            # iCloud 助手
            "com.apple.akd"                     # Apple ID 守护进程
            "com.apple.Safari"                  # Safari 缓存（保留，统一在后面的 Safari 单项清理）
            "Homebrew"                          # Homebrew 缓存（后面单独处理）
            "com.apple.amsengagementd"          # Apple 媒体服务
            "com.apple.appleaccountd"           # Apple 账户
            "io.github.clash-verge-rev.clash-verge-rev" # Clash Verge 缓存，避免影响代理运行态
            "com.exafunction.windsurf"          # Devin 基础缓存单独处理，避免误删登录态
            "com.openai.codex"                  # Codex 缓存，避免影响当前工具
            "com.openai.sky.CUAService"         # Codex Computer Use 缓存
        )
        USER_CACHE_CLEANABLE=0
        for sub in "$HOME/Library/Caches"/*; do
            [ ! -d "$sub" ] && continue
            base=$(basename "$sub")
            skip=0
            for p in "${PROTECTED_CACHES[@]}"; do
                if [ "$base" = "$p" ]; then skip=1; break; fi
            done
            [ "$skip" -eq 1 ] && continue
            sz=$(get_size_bytes "$sub")
            USER_CACHE_CLEANABLE=$((USER_CACHE_CLEANABLE + sz))
        done
        if [ "$USER_CACHE_CLEANABLE" -gt 0 ]; then
            echo -e "  ${CYAN}用户应用缓存 (~/Library/Caches)${NC}: $(format_size $USER_CACHE_CLEANABLE)"
            for sub in "$HOME/Library/Caches"/*; do
                [ ! -d "$sub" ] && continue
                base=$(basename "$sub")
                skip=0
                for p in "${PROTECTED_CACHES[@]}"; do
                    if [ "$base" = "$p" ]; then skip=1; break; fi
                done
                [ "$skip" -eq 1 ] && continue
                safe_remove_rebuildable_path "$sub" "用户应用缓存 $(basename "$sub")"
            done
            print_success "  用户应用缓存已按保护规则处理完成"
        fi
    fi

    # 1.2 用户日志目录
    silent_clean_dir "$HOME/Library/Logs" "用户日志 (~/Library/Logs)"

    # 1.3 Apple 照片分析缓存
    MEDIA_ANALYSIS="$HOME/Library/Containers/com.apple.mediaanalysisd"
    if [ -d "$MEDIA_ANALYSIS" ]; then
        MEDIA_CACHE="$MEDIA_ANALYSIS/Data/Library/Caches"
        if [ -d "$MEDIA_CACHE" ]; then
            silent_clean_dir "$MEDIA_CACHE" "照片分析缓存"
        else
            print_info "  未发现照片分析 Caches 子目录，已保留照片分析数据库与模型数据"
        fi
    fi
else
    print_info "  已跳过系统基础缓存与日志清理"
fi
echo ""

# 2. 常用开发包管理与构建缓存 (Homebrew, npm, pip, Maven, Playwright)
print_info "2. 开发包管理与构建工具缓存"
print_warning "注意：Maven/Playwright 清理后在下次使用时需重新下载依赖/浏览器二进制包"
if confirm "  是否清理开发工具缓存（Homebrew垃圾、npm/npx、pip、Maven依赖、Playwright、通用隐藏缓存）？"; then
    # 2.1 Homebrew 缓存
    if command -v brew &>/dev/null; then
        BREW_CACHE=$(brew --cache 2>/dev/null)
        if [ -n "$BREW_CACHE" ] && [ -d "$BREW_CACHE" ]; then
            size=$(get_size_bytes "$BREW_CACHE")
            echo -e "  ${CYAN}Homebrew 下载缓存${NC}: $(format_size $size)"
        fi
        if [ "$DRY_RUN" -eq 1 ] 2>/dev/null; then
            print_info "  演练模式：不执行 brew cleanup"
        else
            before=$(df -k / | tail -1 | awk '{print $4}')
            brew cleanup --prune=all 2>/dev/null
            after=$(df -k / | tail -1 | awk '{print $4}')
            freed=$(( (after - before) * 1024 ))
            if [ "$freed" -gt 0 ]; then
                TOTAL_FREED=$((TOTAL_FREED + freed))
                print_success "  Homebrew 释放了 $(format_size $freed)"
            else
                print_success "  Homebrew 缓存已是最新"
            fi
        fi
    fi

    # 2.2 npm 缓存
    NPM_CACHE="$HOME/.npm"
    if [ -d "$NPM_CACHE" ]; then
        silent_clean_dir "$NPM_CACHE/_cacache" "npm 下载缓存"
        silent_clean_dir "$NPM_CACHE/_npx" "npx 临时缓存"
    fi

    # 2.3 通用隐藏缓存 (安全过滤，不清理关键插件的依赖运行环境)
    silent_remove_dir "$HOME/.cache/uv" "uv 包缓存"
    silent_remove_dir "$HOME/.cache/selenium" "Selenium 驱动缓存"
    silent_remove_dir "$HOME/.cache/vscode-ripgrep" "VS Code ripgrep 缓存"
    silent_remove_dir "$HOME/.wdm" "WebDriver Manager 缓存"
    silent_remove_dir "$HOME/Library/Caches/node-gyp" "node-gyp 构建缓存"

    # 2.4 pip 缓存
    silent_clean_dir "$HOME/Library/Caches/pip" "pip 下载缓存"

    # 2.5 Maven 本地仓库：可重建但代价高，单独确认
    if [ -d "$HOME/.m2/repository" ]; then
        print_warning "  Maven 本地仓库可重建，但清理后所有 Java 项目需要重新下载依赖"
        if confirm "  是否单独清理 Maven 本地仓库？"; then
            silent_remove_dir "$HOME/.m2/repository" "Maven 本地仓库"
        else
            print_info "  已保留 Maven 本地仓库"
        fi
    fi

    # 2.6 Playwright 浏览器：可重建但下载体积大，单独确认
    if [ -d "$HOME/Library/Caches/ms-playwright" ]; then
        print_warning "  Playwright 浏览器可重建，但清理后需要重新下载浏览器二进制"
        if confirm "  是否单独清理 Playwright 浏览器缓存？"; then
            silent_remove_dir "$HOME/Library/Caches/ms-playwright" "Playwright 浏览器"
        else
            print_info "  已保留 Playwright 浏览器缓存"
        fi
    fi
else
    print_info "  已跳过开发工具缓存清理"
fi
echo ""

# 3. DNS 缓存刷新
print_info "3. DNS 缓存刷新"
if confirm "  刷新 DNS 缓存？"; then
    if [ "$DRY_RUN" -eq 1 ] 2>/dev/null; then
        print_info "  演练模式：不刷新 DNS/mDNS 缓存"
    else
        sudo dscacheutil -flushcache 2>/dev/null
        sudo killall -HUP mDNSResponder 2>/dev/null
        print_success "  DNS 缓存已刷新"
    fi
else
    print_info "  已跳过"
fi
echo ""

# ============================================================================
# 第二部分：中等风险清理（应用缓存，不影响核心功能）
# ============================================================================
echo -e "\n${YELLOW}${SECTION_BAR}${NC}"
echo -e "${YELLOW}  第二部分: 中等风险清理（应用缓存，建议先关闭对应应用）${NC}"
echo -e "${YELLOW}${SECTION_BAR}${NC}\n"

# 11. 微信缓存（合并一键清理，不影响聊天记录）
print_info "11. 微信缓存"
WECHAT_CONTAINER="$HOME/Library/Containers/com.tencent.xinWeChat"
if [ -d "$WECHAT_CONTAINER" ]; then
    WECHAT_DATA="$WECHAT_CONTAINER/Data/Library/Application Support/com.tencent.xinWeChat"
    WECHAT_CACHE="$WECHAT_CONTAINER/Data/Library/Caches"
    WECHAT_TMP="$WECHAT_CONTAINER/Data/tmp"
    # 微信新版本 app_data 路径（日志/插件/radium 缓存）
    WECHAT_APPDATA="$WECHAT_CONTAINER/Data/Documents/app_data"
    
    WECHAT_CLEANABLE=0
    [ -d "$WECHAT_CACHE" ] && WECHAT_CLEANABLE=$((WECHAT_CLEANABLE + $(get_size_bytes "$WECHAT_CACHE")))
    [ -d "$WECHAT_TMP" ] && WECHAT_CLEANABLE=$((WECHAT_CLEANABLE + $(get_size_bytes "$WECHAT_TMP")))
    
    if [ -d "$WECHAT_DATA" ]; then
        MSG_TEMP="$WECHAT_DATA/2.0b4.0.1.15/Message/MessageTemp"
        FILE_CACHE="$WECHAT_DATA/2.0b4.0.0.15/FileStorage/Cache"
        IMAGE_CACHE="$WECHAT_DATA/2.0b4.0.0.15/FileStorage/ImageCache"
        VIDEO_CACHE="$WECHAT_DATA/2.0b4.0.0.15/FileStorage/VideoCache"
        for cache_dir in "$MSG_TEMP" "$FILE_CACHE" "$IMAGE_CACHE" "$VIDEO_CACHE"; do
            [ -d "$cache_dir" ] && WECHAT_CLEANABLE=$((WECHAT_CLEANABLE + $(get_size_bytes "$cache_dir")))
        done
    fi
    # app_data 下的日志/插件/radium 缓存（可重建）
    WECHAT_LOG="$WECHAT_APPDATA/log"
    WECHAT_XPLUGIN="$WECHAT_APPDATA/xplugin/plugins"
    WECHAT_RADIUM="$WECHAT_APPDATA/radium"
    [ -d "$WECHAT_LOG" ] && WECHAT_CLEANABLE=$((WECHAT_CLEANABLE + $(get_size_bytes "$WECHAT_LOG")))
    [ -d "$WECHAT_XPLUGIN" ] && WECHAT_CLEANABLE=$((WECHAT_CLEANABLE + $(get_size_bytes "$WECHAT_XPLUGIN")))
    [ -d "$WECHAT_RADIUM" ] && WECHAT_CLEANABLE=$((WECHAT_CLEANABLE + $(get_size_bytes "$WECHAT_RADIUM")))
    
    if [ "$WECHAT_CLEANABLE" -gt 0 ]; then
        echo -e "  ${CYAN}微信可清理缓存与临时文件${NC}: $(format_size $WECHAT_CLEANABLE)"
        print_info "  包含：缓存、临时文件、日志(.xlog)、插件缓存、radium缓存（均会自动重建）"
        print_info "  已保护：聊天记录、聊天数据库、附件主目录、账号配置"
        if confirm "  是否先退出微信再清理缓存（避免数据库损坏）？"; then
            kill_app_process "微信" "com.tencent.xinWeChat"
            # ----------------------------------------------------------------
            # 级联静默清理所有子目录，确保交互流畅
            # ----------------------------------------------------------------
            silent_clean_dir "$WECHAT_CACHE" "微信缓存目录"
            silent_clean_dir "$WECHAT_TMP" "微信临时文件"
            if [ -d "$WECHAT_DATA" ]; then
                silent_clean_dir "$MSG_TEMP" "微信临时消息文件"
                silent_clean_dir "$FILE_CACHE" "微信文件存储缓存"
                silent_clean_dir "$IMAGE_CACHE" "微信图片缓存"
                silent_clean_dir "$VIDEO_CACHE" "微信视频缓存"
            fi
            # app_data 下的可重建缓存
            silent_clean_dir "$WECHAT_LOG" "微信运行日志 (.xlog，会自动重建)"
            silent_clean_dir "$WECHAT_XPLUGIN" "微信插件缓存 (会自动重新下载)"
            silent_clean_dir "$WECHAT_RADIUM" "微信 radium 缓存 (会自动重建)"
            print_success "  微信缓存清理完成"
        else
            print_info "  已跳过微信缓存清理"
        fi
    else
        print_info "  未检测到微信可清理的缓存数据"
    fi
fi
echo ""

# 12. WPS Office 缓存（合并一键清理）
print_info "12. WPS Office 缓存"
WPS_CONTAINER="$HOME/Library/Containers/com.kingsoft.wpsoffice.mac"
if [ -d "$WPS_CONTAINER" ]; then
    WPS_CACHE="$WPS_CONTAINER/Data/Library/Caches"
    WPS_TMP="$WPS_CONTAINER/Data/tmp"
    WPS_CLEANABLE=0
    [ -d "$WPS_CACHE" ] && WPS_CLEANABLE=$((WPS_CLEANABLE + $(get_size_bytes "$WPS_CACHE")))
    [ -d "$WPS_TMP" ] && WPS_CLEANABLE=$((WPS_CLEANABLE + $(get_size_bytes "$WPS_TMP")))
    
    if [ "$WPS_CLEANABLE" -gt 0 ]; then
        echo -e "  ${CYAN}WPS Office 可清理缓存${NC}: $(format_size $WPS_CLEANABLE)"
        if confirm "  是否清理 WPS Office 缓存与临时文件？"; then
            silent_clean_dir "$WPS_CACHE" "WPS 缓存"
            silent_clean_dir "$WPS_TMP" "WPS 临时文件"
            print_success "  WPS Office 缓存清理完成"
        else
            print_info "  已跳过 WPS Office 缓存清理"
        fi
    else
        print_info "  未检测到 WPS Office 可清理的缓存数据"
    fi
fi
echo ""

# 13. Telegram 缓存（合并一键清理）
print_info "13. Telegram 缓存"
TG_CACHE="$HOME/Library/Group Containers/6N38VWS5BX.ru.keepcoder.Telegram"
if [ -d "$TG_CACHE" ]; then
    TG_TARGETS=()
    while IFS= read -r tg_dir; do TG_TARGETS+=("$tg_dir"); done < <(find "$TG_CACHE" -type d \( -name "Caches" -o -name "tmp" -o -name "temp" -o -name "logs" \) 2>/dev/null)
    # Telegram 媒体缓存（cached 目录，按消息ID命名，会自动重新下载）
    while IFS= read -r tg_cached; do TG_TARGETS+=("$tg_cached"); done < <(find "$TG_CACHE" -type d -name "cached" 2>/dev/null)
    # Telegram 动画贴纸缓存（trlottie-animations，会自动重新下载）
    add_target_if_exists_tg() { [ -d "$1" ] && TG_TARGETS+=("$1"); }
    add_target_if_exists_tg "$TG_CACHE/appstore/trlottie-animations"
    
    TG_CLEANABLE=0
    for tg_dir in "${TG_TARGETS[@]}"; do
        [ -d "$tg_dir" ] && TG_CLEANABLE=$((TG_CLEANABLE + $(get_size_bytes "$tg_dir")))
    done
    if [ "$TG_CLEANABLE" -gt 0 ]; then
        echo -e "  ${CYAN}Telegram 可清理临时目录、日志和媒体缓存${NC}: $(format_size $TG_CLEANABLE)"
        print_info "  包含：Caches、tmp、temp、logs、cached(媒体缓存)、trlottie(动画贴纸缓存)"
        print_info "  已保护：postbox 数据库（聊天记录）、accounts-metadata、账号配置"
        if confirm "  是否先退出 Telegram 再清理缓存（避免数据库损坏）？"; then
            kill_app_process "Telegram" "ru.keepcoder.Telegram"
            for tg_dir in "${TG_TARGETS[@]}"; do
                safe_remove_rebuildable_path "$tg_dir" "Telegram 可重建缓存 $(basename "$tg_dir")"
            done
            print_success "  Telegram 临时目录、日志和媒体缓存处理完成"
        else
            print_info "  已跳过 Telegram 缓存清理"
        fi
    else
        print_info "  未检测到 Telegram 可清理缓存"
    fi
fi
echo ""

# 14. QQ 缓存（合并一键清理，不影响聊天记录）
print_info "14. QQ 缓存"
QQ_CONTAINER="$HOME/Library/Containers/com.tencent.qq"
if [ -d "$QQ_CONTAINER" ]; then
    QQ_CACHE="$QQ_CONTAINER/Data/Library/Caches"
    QQ_TMP="$QQ_CONTAINER/Data/tmp"
    QQ_DATA="$QQ_CONTAINER/Data/Library/Application Support/QQ"
    # QQ 小程序数据（Group Container，会自动重新下载）
    QQ_QQEX="$HOME/Library/Group Containers/FN2V63AD2J.com.tencent/qqex"
    
    QQ_CLEANABLE=0
    [ -d "$QQ_CACHE" ] && QQ_CLEANABLE=$((QQ_CLEANABLE + $(get_size_bytes "$QQ_CACHE")))
    [ -d "$QQ_TMP" ] && QQ_CLEANABLE=$((QQ_CLEANABLE + $(get_size_bytes "$QQ_TMP")))
    if [ -d "$QQ_DATA" ]; then
        LOG_CACHE="$QQ_DATA/Logs"
        # FileRecv、Image、Pic 等可能包含用户手动保存或聊天附件，默认绝不删除。
        [ -d "$LOG_CACHE" ] && QQ_CLEANABLE=$((QQ_CLEANABLE + $(get_size_bytes "$LOG_CACHE")))
        while IFS= read -r qq_cache_dir; do
            [ -d "$qq_cache_dir" ] && QQ_CLEANABLE=$((QQ_CLEANABLE + $(get_size_bytes "$qq_cache_dir")))
        done < <(find "$QQ_DATA" -type d \( -name "Cache" -o -name "Code Cache" -o -name "GPUCache" -o -name "DawnWebGPUCache" -o -name "DawnGraphiteCache" -o -name "ThumbTemp" -o -name "log-cache" -o -name "nt_temp" \) 2>/dev/null)
        # nt_data 下的日志和缓存（可重建）
        while IFS= read -r qq_ntdir; do
            [ -d "$qq_ntdir" ] && QQ_CLEANABLE=$((QQ_CLEANABLE + $(get_size_bytes "$qq_ntdir")))
        done < <(find "$QQ_DATA" -type d \( -path "*/nt_data/log" -o -path "*/nt_data/log-cache" -o -path "*/nt_data/Pic" -o -path "*/nt_data/Video" -o -path "*/nt_data/Emoji" -o -path "*/nt_data/avatar" \) 2>/dev/null)
        # 旧版本残留目录（非当前版本的版本号目录，可安全删除）
        if [ -d "$QQ_DATA/versions" ]; then
            while IFS= read -r qq_oldver; do
                [ -d "$qq_oldver" ] && QQ_CLEANABLE=$((QQ_CLEANABLE + $(get_size_bytes "$qq_oldver")))
            done < <(find "$QQ_DATA/versions" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
        fi
    fi
    # qqex 小程序数据
    [ -d "$QQ_QQEX" ] && QQ_CLEANABLE=$((QQ_CLEANABLE + $(get_size_bytes "$QQ_QQEX")))
    
    if [ "$QQ_CLEANABLE" -gt 0 ]; then
        echo -e "  ${CYAN}QQ 可清理缓存与临时文件${NC}: $(format_size $QQ_CLEANABLE)"
        print_info "  包含：缓存、日志、旧版本残留、小程序数据、图片/表情/视频缓存（均会自动重建）"
        print_info "  已保护：FileRecv、聊天消息(Msg)、聊天附件原图、账号配置"
        if confirm "  是否先退出 QQ 再清理缓存（避免数据库损坏）？"; then
            kill_app_process "QQ" "com.tencent.qq"
            silent_clean_dir "$QQ_CACHE" "QQ缓存目录"
            silent_clean_dir "$QQ_TMP" "QQ临时文件"
            if [ -d "$QQ_DATA" ]; then
                silent_clean_dir "$LOG_CACHE" "QQ日志缓存"
                while IFS= read -r qq_cache_dir; do
                    safe_remove_rebuildable_path "$qq_cache_dir" "QQ 可重建缓存 $(basename "$qq_cache_dir")"
                done < <(find "$QQ_DATA" -type d \( -name "Cache" -o -name "Code Cache" -o -name "GPUCache" -o -name "DawnWebGPUCache" -o -name "DawnGraphiteCache" -o -name "ThumbTemp" -o -name "log-cache" -o -name "nt_temp" \) 2>/dev/null)
                # nt_data 下的日志和缓存
                while IFS= read -r qq_ntdir; do
                    safe_remove_rebuildable_path "$qq_ntdir" "QQ $(basename "$qq_ntdir") 缓存"
                done < <(find "$QQ_DATA" -type d \( -path "*/nt_data/log" -o -path "*/nt_data/log-cache" -o -path "*/nt_data/Pic" -o -path "*/nt_data/Video" -o -path "*/nt_data/Emoji" -o -path "*/nt_data/avatar" \) 2>/dev/null)
                # 旧版本残留目录
                find "$QQ_DATA/versions" -maxdepth 1 -type d 2>/dev/null | while IFS= read -r qq_oldver; do
                    [ "$qq_oldver" = "$QQ_DATA/versions" ] && continue
                    safe_remove_rebuildable_path "$qq_oldver" "QQ 旧版本残留 $(basename "$qq_oldver")"
                done
                # 旧更新压缩包
                find "$QQ_DATA/versions" -maxdepth 1 -type f -name "*.zip" 2>/dev/null | while IFS= read -r qq_zip; do
                    safe_remove_rebuildable_path "$qq_zip" "QQ 旧更新压缩包"
                done
            fi
            # qqex 小程序数据（会自动重新下载）
            safe_remove_rebuildable_path "$QQ_QQEX" "QQ 小程序数据 (qqex，会自动重新下载)"
            print_success "  QQ 缓存清理完成"
        else
            print_info "  已跳过 QQ 缓存清理"
        fi
    else
        print_info "  未检测到 QQ 可清理的缓存数据"
    fi
fi
echo ""

# 15. Google Chrome 缓存（合并一键清理）
print_info "15. Google Chrome 缓存"
CHROME_DIR="$HOME/Library/Application Support/Google/Chrome"
if [ -d "$CHROME_DIR" ]; then
    CHROME_CACHE="$CHROME_DIR/Default/Service Worker"
    CHROME_CACHE2="$CHROME_DIR/Default/Cache"
    CHROME_CODE="$CHROME_DIR/Default/Code Cache"
    CHROME_COMPONENT="$CHROME_DIR/component_crx_cache"
    CHROME_SODA_LANG="$CHROME_DIR/SODALanguagePacks"
    CHROME_SODA="$CHROME_DIR/SODA"
    CHROME_MODEL="$CHROME_DIR/optimization_guide_model_store"
    CHROME_GR_SHADER="$CHROME_DIR/GrShaderCache"
    CHROME_GRAPHITE="$CHROME_DIR/GraphiteDawnCache"
    CHROME_SHADER="$CHROME_DIR/ShaderCache"
    CHROME_BROWSER_METRICS="$CHROME_DIR/BrowserMetrics"
    CHROME_SNAPSHOTS="$CHROME_DIR/Snapshots"
    CHROME_EXT_CRX="$CHROME_DIR/extensions_crx_cache"
    CHROME_CRASHPAD="$CHROME_DIR/Crashpad"
    CHROME_USER_CACHE="$HOME/Library/Caches/Google/Chrome/Default/Cache"
    CHROME_USER_CODE="$HOME/Library/Caches/Google/Chrome/Default/Code Cache"
    CHROME_USER_GPU="$HOME/Library/Caches/Google/Chrome/Default/GPUCache"

    CHROME_CLEANABLE=0
    for cache_dir in "$CHROME_USER_CACHE" "$CHROME_USER_CODE" "$CHROME_USER_GPU" "$CHROME_CACHE" "$CHROME_CACHE2" "$CHROME_CODE" "$CHROME_COMPONENT" "$CHROME_SODA_LANG" "$CHROME_SODA" "$CHROME_MODEL" "$CHROME_GR_SHADER" "$CHROME_GRAPHITE" "$CHROME_SHADER" "$CHROME_BROWSER_METRICS" "$CHROME_SNAPSHOTS" "$CHROME_EXT_CRX" "$CHROME_CRASHPAD"; do
        [ -d "$cache_dir" ] && CHROME_CLEANABLE=$((CHROME_CLEANABLE + $(get_size_bytes "$cache_dir")))
    done

    if [ "$CHROME_CLEANABLE" -gt 0 ]; then
        echo -e "  ${CYAN}Chrome 可清理缓存${NC}: $(format_size $CHROME_CLEANABLE)"
        print_info "  已保护：登录态、书签、扩展配置、Service Worker 离线数据"
        if confirm "  是否先退出 Chrome 再清理缓存（避免数据库损坏）？"; then
            kill_app_process "Google Chrome" "com.google.Chrome"
            silent_remove_dir "$CHROME_USER_CACHE" "Chrome 实际网页缓存"
            silent_remove_dir "$CHROME_USER_CODE" "Chrome 实际代码缓存"
            silent_remove_dir "$CHROME_USER_GPU" "Chrome 实际 GPU 缓存"
            # Application Support 下的 Service Worker 可能包含站点离线数据，保守跳过。
            print_info "  已保留 Chrome Service Worker（可能含站点离线数据）"
            silent_remove_dir "$CHROME_CACHE2" "Chrome 网页缓存"
            silent_remove_dir "$CHROME_CODE" "Chrome 代码缓存"
            silent_remove_dir "$CHROME_COMPONENT" "Chrome 组件下载缓存"
            silent_remove_dir "$CHROME_SODA_LANG" "Chrome 语音语言包缓存"
            silent_remove_dir "$CHROME_SODA" "Chrome 语音模型缓存"
            silent_remove_dir "$CHROME_MODEL" "Chrome 优化模型缓存"
            silent_remove_dir "$CHROME_GR_SHADER" "Chrome GrShader 缓存"
            silent_remove_dir "$CHROME_GRAPHITE" "Chrome GraphiteDawn 缓存"
            silent_remove_dir "$CHROME_SHADER" "Chrome Shader 缓存"
            silent_remove_dir "$CHROME_BROWSER_METRICS" "Chrome BrowserMetrics 缓存"
            silent_remove_dir "$CHROME_SNAPSHOTS" "Chrome Snapshots 缓存"
            silent_remove_dir "$CHROME_EXT_CRX" "Chrome 扩展安装包缓存"
            silent_remove_dir "$CHROME_CRASHPAD" "Chrome Crashpad 缓存"
            print_success "  Google Chrome 缓存清理完成"
        else
            print_info "  已跳过 Google Chrome 缓存清理"
        fi
    else
        print_info "  未检测到 Google Chrome 可清理缓存"
    fi
fi
echo ""

# 16. 系统级桌面图片缓存
print_info "16. 桌面图片缓存 (/Library/Caches/Desktop Pictures)"
safe_remove_dir "/Library/Caches/Desktop Pictures" "桌面图片缓存"
echo ""

# 17. Devin IDE 缓存（合并一键清理，针对"对话长卡顿"专项优化）
print_info "17. Devin IDE 缓存（针对对话长卡顿专项优化）"
WS_DIR="$HOME/Library/Application Support/Devin"
if [ -d "$WS_DIR" ]; then
    echo -e "  ${GREEN}[保留]${NC} cascade/*.pb（对话历史）、memories、skills、mcp_config.json"
    echo -e "  ${GREEN}[保留]${NC} Cookies*、Local Storage、WebStorage、installation_id、machineid（登录态）"
    echo -e "  ${GREEN}[保留]${NC} settings.json / keybindings.json（个人编辑器设置）"
    
    # ── 计算 Devin 可清理项总大小 ────────────────────────────────
    WS_CLEANABLE=0
    # Electron 内核缓存
    for cache_dir in "Cache" "CachedData" "GPUCache" "Code Cache" "DawnWebGPUCache" "DawnGraphiteCache" "Shared Dictionary"; do
        [ -d "$WS_DIR/$cache_dir" ] && WS_CLEANABLE=$((WS_CLEANABLE + $(get_size_bytes "$WS_DIR/$cache_dir")))
    done
    # UI / 脚本缓存
    for cache_dir in "Service Worker/CacheStorage" "Service Worker/ScriptCache" "blob_storage"; do
        [ -d "$WS_DIR/$cache_dir" ] && WS_CLEANABLE=$((WS_CLEANABLE + $(get_size_bytes "$WS_DIR/$cache_dir")))
    done
    # 日志 / 崩溃报告
    for cache_dir in "logs" "Crashpad/completed" "Crashpad/pending"; do
        [ -d "$WS_DIR/$cache_dir" ] && WS_CLEANABLE=$((WS_CLEANABLE + $(get_size_bytes "$WS_DIR/$cache_dir")))
    done
    # 扩展与 Profile 残留
    for cache_dir in "CachedExtensionVSIXs" "CachedProfilesData"; do
        [ -d "$WS_DIR/$cache_dir" ] && WS_CLEANABLE=$((WS_CLEANABLE + $(get_size_bytes "$WS_DIR/$cache_dir")))
    done
    # state.vscdb.backup
    STATE_BACKUP="$WS_DIR/User/globalStorage/state.vscdb.backup"
    [ -f "$STATE_BACKUP" ] && WS_CLEANABLE=$((WS_CLEANABLE + $(get_size_bytes "$STATE_BACKUP")))
    # state.vscdb size before vacuum
    STATE_DB="$WS_DIR/User/globalStorage/state.vscdb"
    [ -f "$STATE_DB" ] && WS_CLEANABLE=$((WS_CLEANABLE + $(get_size_bytes "$STATE_DB")))
    # workspaceStorage size before vacuum
    WS_STORAGE_DIR="$WS_DIR/User/workspaceStorage"
    [ -d "$WS_STORAGE_DIR" ] && WS_CLEANABLE=$((WS_CLEANABLE + $(get_size_bytes "$WS_STORAGE_DIR")))
    # /tmp snapshot count
    SNAPSHOT_COUNT=$(ls /tmp/devin-terminal-*.snapshot 2>/dev/null | wc -l | tr -d ' ')
    # AI 索引
    for ai_dir in "$HOME/.codeium/windsurf/implicit" "$HOME/.codeium/windsurf/code_tracker"; do
        [ -d "$ai_dir" ] && WS_CLEANABLE=$((WS_CLEANABLE + $(get_size_bytes "$ai_dir")))
    done

    if [ "$WS_CLEANABLE" -gt 0 ] 2>/dev/null; then
        echo -e "  ${CYAN}Devin 可清理/可优化项目总计${NC}: $(format_size $WS_CLEANABLE)"
        if confirm "  是否一键清理 Devin 缓存、日志、AI索引并压缩数据库（不影响登录和历史对话，解决长对话卡顿）？"; then
            # 1. 清理 Electron 内核缓存
            silent_remove_dir "$WS_DIR/Cache" "Devin Cache（浏览器缓存）"
            silent_remove_dir "$WS_DIR/CachedData" "Devin CachedData（编译缓存）"
            silent_remove_dir "$WS_DIR/GPUCache" "Devin GPUCache"
            silent_remove_dir "$WS_DIR/Code Cache" "Devin Code Cache"
            silent_remove_dir "$WS_DIR/DawnWebGPUCache" "Devin DawnWebGPUCache"
            silent_remove_dir "$WS_DIR/DawnGraphiteCache" "Devin DawnGraphiteCache"
            silent_remove_dir "$WS_DIR/Shared Dictionary" "Devin Shared Dictionary"

            # 2. 清理 UI / 脚本缓存
            print_info "  已保留 Devin IndexedDB（可能含工作区状态，不作为纯缓存删除）"
            silent_clean_dir "$WS_DIR/Service Worker/CacheStorage" "Devin Service Worker CacheStorage"
            silent_clean_dir "$WS_DIR/Service Worker/ScriptCache" "Devin Service Worker ScriptCache"
            silent_clean_dir "$WS_DIR/blob_storage" "Devin blob_storage"

            # 3. 清理 日志 / 崩溃报告
            silent_clean_dir "$WS_DIR/logs" "Devin 运行日志"
            silent_clean_dir "$WS_DIR/Crashpad/completed" "Devin Crashpad completed"
            silent_clean_dir "$WS_DIR/Crashpad/pending" "Devin Crashpad pending"

            # 4. 清理 扩展与 Profile 残留
            silent_clean_dir "$WS_DIR/CachedExtensionVSIXs" "Devin 旧扩展安装包"
            silent_clean_dir "$WS_DIR/CachedProfilesData" "Devin CachedProfilesData"

            # 5. 清理 state.vscdb.backup
            if [ -f "$STATE_BACKUP" ]; then
                safe_remove_rebuildable_path "$STATE_BACKUP" "Devin 旧 state.vscdb.backup"
            fi

            # 6. state.vscdb VACUUM 优化
            if [ -f "$STATE_DB" ] && command -v sqlite3 &>/dev/null; then
                if [ "$DRY_RUN" -eq 1 ] 2>/dev/null; then
                    print_info "  演练模式：不压缩 state.vscdb"
                else
                    before=$(get_size_bytes "$STATE_DB")
                    if sqlite3 "$STATE_DB" "VACUUM;" 2>/dev/null; then
                        after=$(get_size_bytes "$STATE_DB")
                        diff=$((before - after))
                        [ "$diff" -lt 0 ] && diff=0
                        TOTAL_FREED=$((TOTAL_FREED + diff))
                        print_success "  state.vscdb VACUUM 完成，释放 $(format_size $diff)"
                    fi
                fi
            fi

            # 7. workspaceStorage 批量 VACUUM
            if [ -d "$WS_STORAGE_DIR" ] && command -v sqlite3 &>/dev/null; then
                if [ "$DRY_RUN" -eq 1 ] 2>/dev/null; then
                    print_info "  演练模式：不批量压缩 workspaceStorage 数据库"
                else
                    WS_VACUUM_COUNT=0
                    WS_VACUUM_FREED=0
                    while IFS= read -r ws_db; do
                        [ -z "$ws_db" ] && continue
                        wb=$(get_size_bytes "$ws_db")
                        if sqlite3 "$ws_db" "VACUUM;" 2>/dev/null; then
                            wa=$(get_size_bytes "$ws_db")
                            wd=$((wb - wa))
                            [ "$wd" -lt 0 ] && wd=0
                            WS_VACUUM_FREED=$((WS_VACUUM_FREED + wd))
                            WS_VACUUM_COUNT=$((WS_VACUUM_COUNT + 1))
                        fi
                    done < <(find "$WS_STORAGE_DIR" -maxdepth 2 -name "state.vscdb" -type f 2>/dev/null)
                    TOTAL_FREED=$((TOTAL_FREED + WS_VACUUM_FREED))
                    print_success "  已批量 VACUUM $WS_VACUUM_COUNT 个工作区数据库，释放 $(format_size $WS_VACUUM_FREED)"
                fi
            fi

            # 8. /tmp 终端快照清理
            if [ "$SNAPSHOT_COUNT" -gt 0 ] 2>/dev/null; then
                if [ "$DRY_RUN" -eq 1 ] 2>/dev/null; then
                    print_info "  演练模式：不删除 $SNAPSHOT_COUNT 个终端快照"
                else
                    rm -f /tmp/devin-terminal-*.snapshot 2>/dev/null
                    print_success "  已清理 $SNAPSHOT_COUNT 个终端快照"
                fi
            fi

            # 9. AI 索引缓存清理
            for ai_dir in "$HOME/.codeium/windsurf/implicit" "$HOME/.codeium/windsurf/code_tracker"; do
                if [ -d "$ai_dir" ]; then
                    safe_remove_rebuildable_path "$ai_dir" "Devin $(basename "$ai_dir") AI 索引缓存"
                fi
            done
            print_success "  Devin 缓存清理与卡顿优化完成"
        else
            print_info "  已跳过 Devin 缓存清理"
        fi
    fi

    # ── WebStorage / Local Storage / Cookies 默认保留提示 ────────────────
    WS_WEB_STORAGE="$WS_DIR/WebStorage"
    [ -d "$WS_WEB_STORAGE" ] && echo -e "  ${YELLOW}[已保留] WebStorage${NC}: $(format_size $(get_size_bytes "$WS_WEB_STORAGE"))（登录态）"
    WS_LOCAL_STORAGE="$WS_DIR/Local Storage"
    [ -d "$WS_LOCAL_STORAGE" ] && echo -e "  ${YELLOW}[已保留] Local Storage${NC}: $(format_size $(get_size_bytes "$WS_LOCAL_STORAGE"))（会话数据）"

    # ── Devin 设备 ID 强制重置（仍独立保留确认，因为有重登风险） ──────
    if [ "${FORCE_RESET_ID:-0}" = "1" ] || [ "${FORCE_RESET_ID:-0}" = "true" ]; then
        echo ""
        print_warning "[手动重置模式] 重置 Devin 设备 ID（可能需要重新登录）"
        print_info     "  默认不会重置；只有设置 FORCE_RESET_ID=1 才会进入本步骤"
        if confirm "  是否重置 Devin 设备 ID？"; then
            if [ "$DRY_RUN" -eq 1 ] 2>/dev/null; then
                print_info "  演练模式：不重置 Devin 设备 ID"
            else
            INSTALL_ID_FILE="$HOME/.codeium/windsurf/installation_id"
            MACHINE_ID_FILE="$WS_DIR/machineid"
            STORAGE_JSON="$WS_DIR/User/globalStorage/storage.json"

            NEW_INSTALL_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')
            NEW_MACHINE_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')

            [ -f "$INSTALL_ID_FILE" ] && echo "$NEW_INSTALL_ID" > "$INSTALL_ID_FILE" && print_success "  installation_id 已重置"
            [ -f "$MACHINE_ID_FILE" ] && echo "$NEW_MACHINE_ID" > "$MACHINE_ID_FILE" && print_success "  machineid 已重置"

            if [ -f "$STORAGE_JSON" ] && command -v python3 &>/dev/null; then
                NEW_DEV_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')
                NEW_SQM_ID=$(uuidgen | tr '[:upper:]' '[:upper:]')
                NEW_MAC_MID=$(od -An -tx1 -N16 /dev/urandom | tr -d ' \n')
                NEW_TEL_MID=$(od -An -tx1 -N32 /dev/urandom | tr -d ' \n')
                python3 - "$STORAGE_JSON" "$NEW_DEV_ID" "$NEW_MAC_MID" "$NEW_TEL_MID" "$NEW_SQM_ID" << 'PYEOF'
import json, sys
p, dev, mac, tel, sqm = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5]
try:
    with open(p, 'r') as f: d = json.load(f)
    d['telemetry.devDeviceId'] = dev
    d['telemetry.macMachineId'] = mac
    d['telemetry.machineId'] = tel
    d['telemetry.sqmId'] = sqm
    with open(p, 'w') as f: json.dump(d, f, indent=2, ensure_ascii=False)
    print("  storage.json telemetry ID 已重置")
except Exception as e:
    print(f"  storage.json 重置失败: {e}")
PYEOF
            fi

            STATE_DB="$WS_DIR/User/globalStorage/state.vscdb"
            if [ -f "$STATE_DB" ] && command -v sqlite3 &>/dev/null; then
                sqlite3 "$STATE_DB" <<SQLEOF 2>/dev/null
UPDATE ItemTable SET value = '"$NEW_TEL_MID"' WHERE key = 'telemetry.machineId';
UPDATE ItemTable SET value = '"$NEW_DEV_ID"' WHERE key = 'telemetry.devDeviceId';
UPDATE ItemTable SET value = '"$NEW_SQM_ID"' WHERE key = 'telemetry.sqmId';
UPDATE ItemTable SET value = '"$NEW_MAC_MID"' WHERE key = 'telemetry.macMachineId';
UPDATE ItemTable SET value = '"$NEW_INSTALL_ID"' WHERE key = 'storage.serviceMachineId';
SQLEOF
                print_success "  state.vscdb telemetry 键已同步"
            fi
            fi
        else
            print_info "  已跳过 ID 重置"
        fi
    fi
fi
echo ""

# 18. Choice 临时与日志缓存（合并一键清理）
print_info "18. Choice 临时与日志缓存"
CHOICE_DIR="$HOME/Library/Application Support/Choice"
if [ -d "$CHOICE_DIR" ]; then
    CHOICE_CLEANABLE=0
    for cache_dir in "temp" "logs" "crash/Reports" "crash/Data"; do
        [ -d "$CHOICE_DIR/$cache_dir" ] && CHOICE_CLEANABLE=$((CHOICE_CLEANABLE + $(get_size_bytes "$CHOICE_DIR/$cache_dir")))
    done

    if [ "$CHOICE_CLEANABLE" -gt 0 ]; then
        echo -e "  ${CYAN}Choice 可清理缓存${NC}: $(format_size $CHOICE_CLEANABLE)"
        if confirm "  是否清理 Choice 临时文件、日志和崩溃报告？"; then
            silent_remove_dir "$CHOICE_DIR/temp" "Choice 临时目录"
            silent_remove_dir "$CHOICE_DIR/logs" "Choice 日志目录"
            silent_remove_dir "$CHOICE_DIR/crash/Reports" "Choice 崩溃报告"
            silent_remove_dir "$CHOICE_DIR/crash/Data" "Choice 崩溃数据"
            print_success "  Choice 缓存清理完成"
        else
            print_info "  已跳过 Choice 缓存清理"
        fi
    else
        print_info "  未检测到 Choice 可清理缓存"
    fi
fi
echo ""

# 19. MathWorks 日志与本地作业缓存（合并一键清理）
print_info "19. MathWorks 日志与本地作业缓存"
MATHWORKS_DIR="$HOME/Library/Application Support/MathWorks"
if [ -d "$MATHWORKS_DIR" ]; then
    MW_CLEANABLE=0
    [ -d "$MATHWORKS_DIR/ServiceHost/logs" ] && MW_CLEANABLE=$((MW_CLEANABLE + $(get_size_bytes "$MATHWORKS_DIR/ServiceHost/logs")))
    [ -d "$MATHWORKS_DIR/MATLAB/local_cluster_jobs" ] && MW_CLEANABLE=$((MW_CLEANABLE + $(get_size_bytes "$MATHWORKS_DIR/MATLAB/local_cluster_jobs")))

    if [ "$MW_CLEANABLE" -gt 0 ]; then
        echo -e "  ${CYAN}MathWorks 可清理缓存${NC}: $(format_size $MW_CLEANABLE)"
        if confirm "  是否清理 MathWorks ServiceHost 日志与 MATLAB 本地作业缓存？"; then
            silent_remove_dir "$MATHWORKS_DIR/ServiceHost/logs" "MathWorks ServiceHost 日志"
            silent_remove_dir "$MATHWORKS_DIR/MATLAB/local_cluster_jobs" "MathWorks 本地作业缓存"
            print_success "  MathWorks 缓存清理完成"
        else
            print_info "  已跳过 MathWorks 缓存清理"
        fi
    else
        print_info "  未检测到 MathWorks 可清理缓存"
    fi
fi
echo ""

# ============================================================================
# 第三部分：开发工具清理
# ============================================================================
echo -e "\n${BLUE}${SECTION_BAR}${NC}"
echo -e "${BLUE}  第三部分: 开发工具清理${NC}"
echo -e "${BLUE}${SECTION_BAR}${NC}\n"

# 20. Safari 浏览器缓存（合并一键清理）
print_info "20. Safari 浏览器缓存"
SAFARI_CACHE="$HOME/Library/Caches/com.apple.Safari"
SAFARI_WEBKIT="$HOME/Library/Caches/com.apple.WebKit.WebContent"
SAFARI_FS="$HOME/Library/Safari/LocalStorage"
SAFARI_ICONS="$HOME/Library/Safari/Icons"
SAFARI_PERF="$HOME/Library/Caches/com.apple.Safari/PerSitePreferences"

SAFARI_CLEANABLE=0
# LocalStorage 与 PerSitePreferences 可能包含站点数据和偏好，默认保留。
for cache_dir in "$SAFARI_CACHE" "$SAFARI_WEBKIT" "$SAFARI_ICONS"; do
    [ -d "$cache_dir" ] && SAFARI_CLEANABLE=$((SAFARI_CLEANABLE + $(get_size_bytes "$cache_dir")))
done

if [ "$SAFARI_CLEANABLE" -gt 0 ]; then
    echo -e "  ${CYAN}Safari 可清理缓存${NC}: $(format_size $SAFARI_CLEANABLE)"
    if confirm "  是否清理 Safari 浏览器网页缓存与图标缓存？"; then
        silent_clean_dir "$SAFARI_CACHE" "Safari 浏览器缓存"
        silent_clean_dir "$SAFARI_WEBKIT" "Safari WebKit 缓存"
        print_info "  已保留 Safari LocalStorage 与站点特定配置"
        silent_clean_dir "$SAFARI_ICONS" "Safari 网站图标缓存"
        print_success "  Safari 缓存清理完成"
    else
        print_info "  已跳过 Safari 缓存清理"
    fi
else
    print_info "  未检测到 Safari 可清理缓存"
fi
echo ""

# 21. Xcode 缓存和派生数据（合并一键清理）
print_info "21. Xcode 派生数据和缓存"
XCODE_DERIVED="$HOME/Library/Developer/Xcode/DerivedData"
XCODE_ARCHIVES="$HOME/Library/Developer/Xcode/Archives"
XCODE_SIMULATOR_CACHE="$HOME/Library/Developer/CoreSimulator/Caches"

XCODE_CLEANABLE=0
[ -d "$XCODE_DERIVED" ] && XCODE_CLEANABLE=$((XCODE_CLEANABLE + $(get_size_bytes "$XCODE_DERIVED")))
[ -d "$XCODE_SIMULATOR_CACHE" ] && XCODE_CLEANABLE=$((XCODE_CLEANABLE + $(get_size_bytes "$XCODE_SIMULATOR_CACHE")))

if [ "$XCODE_CLEANABLE" -gt 0 ]; then
    echo -e "  ${CYAN}Xcode 可清理缓存/派生数据${NC}: $(format_size $XCODE_CLEANABLE)"
    if confirm "  是否清理 Xcode 派生数据与模拟器缓存？"; then
        silent_clean_dir "$XCODE_DERIVED" "Xcode DerivedData (派生数据)"
        print_info "  已保留 Xcode Archives（历史归档不是缓存）"
        silent_clean_dir "$XCODE_SIMULATOR_CACHE" "CoreSimulator Caches (模拟器缓存)"
        print_success "  Xcode 缓存清理完成"
    else
        print_info "  已跳过 Xcode 缓存清理"
    fi
else
    print_info "  未检测到 Xcode 可清理缓存"
fi
echo ""

# 22. iOS/iPadOS 备份文件
print_info "22. iOS/iPadOS 备份文件"
IOS_BACKUP="$HOME/Library/Application Support/MobileSync/Backup"
if [ -d "$IOS_BACKUP" ]; then
    backup_size=$(get_size_bytes "$IOS_BACKUP")
    if [ "$backup_size" -gt 0 ]; then
        echo -e "  ${CYAN}iOS 备份${NC}: $(format_size $backup_size)"
        print_warning "  iOS 备份不是可自动重建缓存，默认只提示不删除"
        if [ "${ALLOW_DELETE_IOS_BACKUPS:-0}" = "1" ] && confirm "  已设置 ALLOW_DELETE_IOS_BACKUPS=1，是否删除 iOS 备份？"; then
            if [ "$DRY_RUN" -eq 1 ] 2>/dev/null; then
                print_info "  演练模式：不删除 iOS 备份"
            else
                before=$(get_size_bytes "$IOS_BACKUP")
                find "$IOS_BACKUP" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null
                after=$(get_size_bytes "$IOS_BACKUP")
                freed=$((before - after))
                [ "$freed" -lt 0 ] && freed=0
                TOTAL_FREED=$((TOTAL_FREED + freed))
                print_success "  iOS 备份已清理 $(format_size $freed)"
            fi
        else
            print_info "  已保留 iOS 备份"
        fi
    fi
fi
echo ""

# 23. 不活跃项目的 node_modules
print_info "23. 不活跃项目的 node_modules"
print_warning "以下 node_modules 可以清理，需要时用 npm install 重新安装"
echo ""
NODE_MODULES_TOTAL=0
while IFS= read -r dir; do
    if [ -d "$dir" ]; then
        size=$(get_size_bytes "$dir")
        NODE_MODULES_TOTAL=$((NODE_MODULES_TOTAL + size))
        echo -e "  ${CYAN}$(echo $dir | sed "s|$HOME|~|")${NC}: $(format_size $size)"
    fi
done < <(find "$HOME/Downloads" -maxdepth 3 -name "node_modules" -type d 2>/dev/null)

if [ "$NODE_MODULES_TOTAL" -gt 0 ]; then
    echo ""
    echo -e "  合计: $(format_size $NODE_MODULES_TOTAL)"
    if confirm "  清理 Downloads 下的所有 node_modules？"; then
        while IFS= read -r nm_dir; do
            safe_remove_rebuildable_path "$nm_dir" "Downloads 下 node_modules"
        done < <(find "$HOME/Downloads" -maxdepth 3 -name "node_modules" -type d 2>/dev/null)
        print_success "  node_modules 处理完成"
    else
        print_info "  已跳过"
    fi
fi
echo ""

# 24. __pycache__ 目录
print_info "24. Python __pycache__ 缓存"
PYCACHE_COUNT=$(find "$HOME" -maxdepth 6 -name "__pycache__" -type d 2>/dev/null | wc -l | tr -d ' ')
if [ "$PYCACHE_COUNT" -gt 0 ]; then
    echo -e "  找到 ${CYAN}$PYCACHE_COUNT${NC} 个 __pycache__ 目录"
    if confirm "  清理所有 __pycache__？"; then
        while IFS= read -r pc_dir; do
            safe_remove_rebuildable_path "$pc_dir" "Python __pycache__"
        done < <(find "$HOME" -maxdepth 6 -name "__pycache__" -type d 2>/dev/null)
        print_success "  __pycache__ 处理完成"
    else
        print_info "  已跳过"
    fi
fi
echo ""

# 25. Saved Application State（应用窗口位置缓存，应用重启会重建）
print_info "25. Saved Application State（应用状态缓存，应用会自动重建）"
SAS_DIR="$HOME/Library/Saved Application State"
if [ -d "$SAS_DIR" ]; then
    size=$(get_size_bytes "$SAS_DIR")
    if [ "$size" -gt 0 ]; then
        echo -e "  ${CYAN}Saved Application State${NC}: $(format_size $size)"
        print_info "  存放 App 关闭前的窗口位置/tab 状态，清理后应用会重新记住位置"
        if confirm "  清理此项？"; then
            silent_clean_dir "$SAS_DIR" "Saved Application State"
        else
            print_info "  已跳过"
        fi
    fi
fi
echo ""

# 26. WebKit 缓存（Safari / 内嵌 WebView 的缓存，系统会重建）
print_info "26. WebKit 缓存（Safari/内嵌 WebView，系统会重建）"
WEBKIT_DIR="$HOME/Library/WebKit"
if [ -d "$WEBKIT_DIR" ]; then
    WEBKIT_TARGETS=()
    while IFS= read -r wk_cache; do WEBKIT_TARGETS+=("$wk_cache"); done < <(find "$WEBKIT_DIR" -type d -name "Caches" 2>/dev/null)
    WEBKIT_CLEANABLE=0
    for wk_cache in "${WEBKIT_TARGETS[@]}"; do
        [ -d "$wk_cache" ] && WEBKIT_CLEANABLE=$((WEBKIT_CLEANABLE + $(get_size_bytes "$wk_cache")))
    done
    if [ "$WEBKIT_CLEANABLE" -gt 0 ]; then
        echo -e "  ${CYAN}WebKit Caches 可清理缓存${NC}: $(format_size $WEBKIT_CLEANABLE)"
        print_info "  保留 WebsiteData、LocalStorage、IndexedDB 以及数据库 WAL/SHM"
        if confirm "  清理 WebKit Caches？"; then
            before_total=$TOTAL_FREED
            for wk_cache in "${WEBKIT_TARGETS[@]}"; do
                safe_remove_rebuildable_path "$wk_cache" "WebKit Caches"
            done
            diff=$((TOTAL_FREED - before_total))
            [ "$diff" -lt 0 ] && diff=0
            print_info "  已保留 WebKit WebsiteData、LocalStorage、IndexedDB 与数据库 WAL/SHM"
            print_success "  WebKit 缓存处理完成，释放 $(format_size $diff)"
        else
            print_info "  已跳过 WebKit 缓存清理"
        fi
    else
        print_info "  未检测到 WebKit Caches 可清理缓存"
    fi
fi
echo ""

# ============================================================================
# 第四部分：系统级清理（需要 sudo）
# ============================================================================
echo -e "\n${RED}${SECTION_BAR}${NC}"
echo -e "${RED}  第四部分: 系统级清理（需要管理员密码）${NC}"
echo -e "${RED}${SECTION_BAR}${NC}\n"

# 27. 系统诊断日志、系统日志与临时文件一键清理（合并一键清理，需要 sudo 密码）
print_info "27. 系统级日志与临时文件清理"
SYS_DIAG_DIR="/private/var/db/diagnostics"
SYS_LOG_DIR="/private/var/log"
SYS_FOLDER_DIR="/private/var/folders"

SYS_CLEANABLE=0
[ -d "$SYS_DIAG_DIR" ] && SYS_CLEANABLE=$((SYS_CLEANABLE + $(du -sk "$SYS_DIAG_DIR" 2>/dev/null | awk '{print $1 * 1024}')))
[ -d "/private/var/db/uuidtext" ] && SYS_CLEANABLE=$((SYS_CLEANABLE + $(du -sk "/private/var/db/uuidtext" 2>/dev/null | awk '{print $1 * 1024}')))
[ -d "$SYS_LOG_DIR" ] && SYS_CLEANABLE=$((SYS_CLEANABLE + $(du -sk "$SYS_LOG_DIR" 2>/dev/null | awk '{print $1 * 1024}')))
# /private/var/folders 只在后面的“定向垃圾清理”中处理，避免误删运行态缓存。

if [ "$SYS_CLEANABLE" -gt 0 ]; then
    echo -e "  ${CYAN}系统级可清理垃圾${NC}: $(format_size $SYS_CLEANABLE)"
    print_warning "  此操作需要管理员权限，用户在确认后只需输入一次密码"
    if confirm "  是否一键清理系统诊断日志与30天以上的旧系统日志？"; then
        SYS_BEFORE=0
        [ -d "$SYS_DIAG_DIR" ] && SYS_BEFORE=$((SYS_BEFORE + $(du -sk "$SYS_DIAG_DIR" 2>/dev/null | awk '{print $1 * 1024}')))
        [ -d "/private/var/db/uuidtext" ] && SYS_BEFORE=$((SYS_BEFORE + $(du -sk "/private/var/db/uuidtext" 2>/dev/null | awk '{print $1 * 1024}')))
        [ -d "$SYS_LOG_DIR" ] && SYS_BEFORE=$((SYS_BEFORE + $(du -sk "$SYS_LOG_DIR" 2>/dev/null | awk '{print $1 * 1024}')))
        if [ -d "$SYS_DIAG_DIR" ]; then
            echo -e "  ${CYAN}正在清理系统诊断日志...${NC}"
            if [ "$DRY_RUN" -eq 1 ] 2>/dev/null; then
                print_info "  演练模式：不删除系统诊断日志"
            else
                sudo rm -rf /private/var/db/diagnostics/* 2>/dev/null
                sudo rm -rf /private/var/db/uuidtext/* 2>/dev/null
            fi
            print_success "  系统诊断日志清理完成"
        fi

        if [ -d "$SYS_LOG_DIR" ]; then
            echo -e "  ${CYAN}正在清理30天以上的旧日志...${NC}"
            if [ "$DRY_RUN" -eq 1 ] 2>/dev/null; then
                print_info "  演练模式：不删除系统旧日志"
            else
                sudo find /private/var/log -name "*.log" -mtime +30 -delete 2>/dev/null
                sudo find /private/var/log -name "*.gz" -mtime +30 -delete 2>/dev/null
                sudo find /private/var/log -name "*.bz2" -mtime +30 -delete 2>/dev/null
            fi
            print_success "  系统日志清理完成"
        fi

        print_info "  已跳过 /private/var/folders 广泛清理，改由后续定向规则处理"
        
        SYS_AFTER=0
        [ -d "$SYS_DIAG_DIR" ] && SYS_AFTER=$((SYS_AFTER + $(du -sk "$SYS_DIAG_DIR" 2>/dev/null | awk '{print $1 * 1024}')))
        [ -d "/private/var/db/uuidtext" ] && SYS_AFTER=$((SYS_AFTER + $(du -sk "/private/var/db/uuidtext" 2>/dev/null | awk '{print $1 * 1024}')))
        [ -d "$SYS_LOG_DIR" ] && SYS_AFTER=$((SYS_AFTER + $(du -sk "$SYS_LOG_DIR" 2>/dev/null | awk '{print $1 * 1024}')))
        SYS_FREED=$((SYS_BEFORE - SYS_AFTER))
        [ "$SYS_FREED" -lt 0 ] && SYS_FREED=0
        [ "$DRY_RUN" -eq 1 ] 2>/dev/null && SYS_FREED=0
        TOTAL_FREED=$((TOTAL_FREED + SYS_FREED))
        print_success "  系统级大类清理全部完成，释放 $(format_size $SYS_FREED)"
    else
        print_info "  已跳过系统级清理"
    fi
else
    print_info "  未检测到系统级可清理数据"
fi
echo ""

# 30. /private/var/folders 定向垃圾清理
print_info "30. /private/var/folders 定向垃圾清理"
print_warning "只清理已识别为可重复生成的临时克隆、memmap 和构建缓存"
TARGET_PATHS=()
# Chrome 代码签名临时克隆（684M+，可安全删除，Chrome启动自动重建）
while IFS= read -r path; do TARGET_PATHS+=("$path"); done < <(find /private/var/folders -path "*/X/com.google.Chrome.code_sign_clone" 2>/dev/null)
# Codex 代码签名临时克隆（可达7.1G，每次启动累积副本，可安全删除）
while IFS= read -r path; do TARGET_PATHS+=("$path"); done < <(find /private/var/folders -path "*/X/com.openai.codex.code_sign_clone" 2>/dev/null)
# 其他可重建临时目录（3天以上）
while IFS= read -r path; do TARGET_PATHS+=("$path"); done < <(find /private/var/folders -path "*/T/joblib_memmapping_folder_*" -mtime +3 2>/dev/null)
while IFS= read -r path; do TARGET_PATHS+=("$path"); done < <(find /private/var/folders -path "*/T/node-gyp-tmp-*" -mtime +3 2>/dev/null)
while IFS= read -r path; do TARGET_PATHS+=("$path"); done < <(find /private/var/folders -path "*/T/node-compile-cache" -mtime +3 2>/dev/null)

TARGET_TOTAL=0
TARGET_COUNT=0
for path in "${TARGET_PATHS[@]}"; do
    if [ -e "$path" ]; then
        size=$(get_size_bytes "$path")
        if [ "$size" -gt 0 ]; then
            TARGET_TOTAL=$((TARGET_TOTAL + size))
            TARGET_COUNT=$((TARGET_COUNT + 1))
        fi
    fi
done

RECENT_COUNT=0
while IFS= read -r _; do
    RECENT_COUNT=$((RECENT_COUNT + 1))
done < <(
    find /private/var/folders \( -path "*/X/com.google.Chrome.code_sign_clone" \
        -o -path "*/X/com.openai.codex.code_sign_clone" \
        -o -path "*/T/joblib_memmapping_folder_*" \
        -o -path "*/T/node-gyp-tmp-*" \
        -o -path "*/T/node-compile-cache" \) -mtime -3 2>/dev/null
)

if [ "$RECENT_COUNT" -gt 0 ] 2>/dev/null; then
    print_info "  检测到 $RECENT_COUNT 个近期仍在活跃的临时目录，出于安全未纳入本次清理"
fi

if [ "$TARGET_TOTAL" -gt 0 ]; then
    print_info "  已识别 $TARGET_COUNT 个陈旧定向临时垃圾，合计 $(format_size $TARGET_TOTAL)"
    if confirm "  是否清理这些陈旧定向临时垃圾？"; then
        TARGET_BEFORE=$TARGET_TOTAL
        for path in "${TARGET_PATHS[@]}"; do
            [ -e "$path" ] || continue
            if is_protected_path "$path"; then
                print_warning "  已保护，跳过：$path"
                continue
            fi
            if path_has_open_files "$path"; then
                print_warning "  正在被应用使用，跳过：$path"
                continue
            fi
            if [ "$DRY_RUN" -eq 1 ] 2>/dev/null; then
                print_info "  演练模式：不删除 $path"
            else
                rm -rf "$path" 2>/dev/null || sudo rm -rf "$path" 2>/dev/null
            fi
        done
        TARGET_AFTER=0
        for path in "${TARGET_PATHS[@]}"; do
            [ -e "$path" ] && TARGET_AFTER=$((TARGET_AFTER + $(get_size_bytes "$path")))
        done
        TARGET_FREED=$((TARGET_BEFORE - TARGET_AFTER))
        [ "$TARGET_FREED" -lt 0 ] && TARGET_FREED=0
        [ "$DRY_RUN" -eq 1 ] 2>/dev/null && TARGET_FREED=0
        TOTAL_FREED=$((TOTAL_FREED + TARGET_FREED))
        print_success "  陈旧定向临时垃圾处理完成，释放 $(format_size $TARGET_FREED)"
    else
        print_info "  已跳过陈旧定向临时垃圾清理"
    fi
else
    print_info "  未检测到可清理的陈旧定向临时垃圾"
fi
echo ""

# ============================================================================
# 第五部分: AI 工具深度清理 (Claude Code / Codex / Gemini CLI / OpenCode)
# ============================================================================
echo -e "\n${CYAN}${SECTION_BAR}${NC}"
echo -e "${CYAN}  第五部分: AI 工具深度清理 (Claude/Codex/Gemini/OpenCode)${NC}"
echo -e "${CYAN}${SECTION_BAR}${NC}\n"

# 31. Claude Code 缓存清理（合并一键清理）
print_info "31. Claude Code 缓存"
CLAUDE_DIR="$HOME/.claude"
if [ -d "$CLAUDE_DIR" ]; then
    CLAUDE_CACHE="$CLAUDE_DIR/cache"
    CLAUDE_DEBUG="$CLAUDE_DIR/debug"
    CLAUDE_DOWNLOADS="$CLAUDE_DIR/downloads"
    CLAUDE_PASTE="$CLAUDE_DIR/paste-cache"
    CLAUDE_PLUGINS_CACHE="$CLAUDE_DIR/plugins/cache"
    CLAUDE_SESSION_DATA="$CLAUDE_DIR/session-data"
    CLAUDE_FILE_HISTORY="$CLAUDE_DIR/file-history"
    CLAUDE_SHELL_SNAPSHOTS="$CLAUDE_DIR/shell-snapshots"
    CLAUDE_TASKS="$CLAUDE_DIR/tasks"
    CLAUDE_TODOS="$CLAUDE_DIR/todos"
    CLAUDE_SESSION_ENV="$CLAUDE_DIR/session-env"
    CLAUDE_IDE="$CLAUDE_DIR/ide"
    CLAUDE_METRICS="$CLAUDE_DIR/metrics"
    CLAUDE_TELEMETRY="$CLAUDE_DIR/telemetry"
    CLAUDE_BACKUPS="$CLAUDE_DIR/backups"

    CLAUDE_CLEANABLE=0
    # 只统计纯缓存、调试日志、下载缓存、粘贴缓存和插件缓存。
    # session-data、file-history、tasks、todos、backups 等可能是用户工作记录，默认保留。
    for cache_dir in "$CLAUDE_CACHE" "$CLAUDE_DEBUG" "$CLAUDE_DOWNLOADS" "$CLAUDE_PASTE" "$CLAUDE_PLUGINS_CACHE" "$CLAUDE_METRICS" "$CLAUDE_TELEMETRY"; do
        [ -d "$cache_dir" ] && CLAUDE_CLEANABLE=$((CLAUDE_CLEANABLE + $(get_size_bytes "$cache_dir")))
    done

    if [ "$CLAUDE_CLEANABLE" -gt 0 ]; then
        echo -e "  ${CYAN}Claude Code 可清理缓存${NC}: $(format_size $CLAUDE_CLEANABLE)"
        if confirm "  是否清理 Claude Code 纯缓存、下载缓存、调试日志与遥测缓存？"; then
            silent_clean_dir "$CLAUDE_CACHE" "Claude 缓存"
            silent_clean_dir "$CLAUDE_DEBUG" "Claude 调试日志"
            silent_clean_dir "$CLAUDE_DOWNLOADS" "Claude 下载缓存"
            silent_clean_dir "$CLAUDE_PASTE" "Claude 粘贴剪切板缓存"
            silent_clean_dir "$CLAUDE_PLUGINS_CACHE" "Claude 插件缓存"
            print_info "  已保留 Claude 会话、文件历史、任务、待办、环境与备份数据"
            silent_clean_dir "$CLAUDE_METRICS" "Claude 度量监控缓存"
            silent_clean_dir "$CLAUDE_TELEMETRY" "Claude 遥测缓存"
            print_success "  Claude Code 缓存清理完成"
        else
            print_info "  已跳过 Claude Code 缓存清理"
        fi
    else
        print_info "  未检测到 Claude Code 可清理缓存"
    fi
else
    print_info "  未检测到 Claude Code"
fi
echo ""

# 32. Codex 日志清理（保留插件、会话、记忆和登录）
print_info "32. Codex 日志清理"
if [ -d "$CODEX_DIR" ]; then
    echo -e "  ${GREEN}[保留]${NC} plugins/cache、local-marketplaces、skills、sessions、memories、auth.json、config.toml、computer-use"
    echo -e "  ${GREEN}[保留]${NC} .tmp/plugins*、.tmp/plugins-clone-*、.tmp/marketplaces、.tmp/bundled-marketplaces*"

    CODEX_LOG_CLEANABLE=0
    CODEX_LOG_DBS=()
    while IFS= read -r codex_db; do
        [ -f "$codex_db" ] || continue
        CODEX_LOG_DBS+=("$codex_db")
        CODEX_LOG_CLEANABLE=$((CODEX_LOG_CLEANABLE + $(calculate_sqlite_bundle_size_bytes "$codex_db")))
    done < <(find "$CODEX_DIR" -maxdepth 1 -type f -name "logs_*.sqlite" 2>/dev/null)

    if [ "$CODEX_LOG_CLEANABLE" -gt 0 ] 2>/dev/null; then
        echo -e "  ${CYAN}Codex 可清理运行日志数据库${NC}: $(format_size $CODEX_LOG_CLEANABLE)"
        if confirm "  是否清理 Codex 日志数据库（只清空 logs 表，不清理插件、对话、记忆和登录）？"; then
            for codex_db in "${CODEX_LOG_DBS[@]}"; do
                clean_codex_log_db "$codex_db" "Codex 日志数据库 $(basename "$codex_db")"
            done
            print_success "  Codex 日志清理完成"
        else
            print_info "  已跳过 Codex 日志清理"
        fi
    else
        print_info "  未检测到 Codex 可清理日志数据库"
    fi
else
    print_info "  未检测到 Codex 目录: $CODEX_DIR"
fi
echo ""

# 33. Gemini CLI 缓存清理（合并一键清理）
print_info "33. Gemini CLI 缓存"
GEMINI_DIR="$HOME/.gemini"
if [ -d "$GEMINI_DIR" ]; then
    GEMINI_CACHE="$GEMINI_DIR/cache"
    GEMINI_TMP="$GEMINI_DIR/tmp"
    GEMINI_TELEMETRY="$GEMINI_DIR/telemetry.log"

    GEMINI_CLEANABLE=0
    [ -d "$GEMINI_CACHE" ] && GEMINI_CLEANABLE=$((GEMINI_CLEANABLE + $(get_size_bytes "$GEMINI_CACHE")))
    [ -d "$GEMINI_TMP" ] && GEMINI_CLEANABLE=$((GEMINI_CLEANABLE + $(get_size_bytes "$GEMINI_TMP")))
    [ -f "$GEMINI_TELEMETRY" ] && GEMINI_CLEANABLE=$((GEMINI_CLEANABLE + $(get_size_bytes "$GEMINI_TELEMETRY")))

    if [ "$GEMINI_CLEANABLE" -gt 0 ]; then
        echo -e "  ${CYAN}Gemini CLI 可清理数据${NC}: $(format_size $GEMINI_CLEANABLE)"
        if confirm "  是否清理 Gemini CLI 缓存、临时文件与遥测日志？"; then
            silent_clean_dir "$GEMINI_CACHE" "Gemini 缓存目录"
            silent_clean_dir "$GEMINI_TMP" "Gemini 临时文件夹"
            if [ -f "$GEMINI_TELEMETRY" ]; then
                safe_remove_rebuildable_path "$GEMINI_TELEMETRY" "Gemini telemetry.log"
            fi
            print_success "  Gemini CLI 缓存清理完成"
        else
            print_info "  已跳过 Gemini CLI 缓存清理"
        fi
    else
        print_info "  未检测到 Gemini CLI 可清理缓存"
    fi
else
    print_info "  未检测到 Gemini CLI"
fi
echo ""

# 34. OpenCode 缓存清理（合并一键清理）
print_info "34. OpenCode 缓存"
OPENCODE_CACHE="$HOME/Library/Caches/opencode"
OPENCODE_DATA="$HOME/.local/share/opencode"
OPENCODE_CONFIG="$HOME/.config/opencode"
OPENCODE_LOG="$HOME/Library/Logs/opencode"

if [ -d "$OPENCODE_CACHE" ] || [ -d "$OPENCODE_DATA" ] || [ -d "$OPENCODE_CONFIG" ] || [ -d "$OPENCODE_LOG" ]; then
    OPENCODE_CLEANABLE=0
    for cache_dir in "$OPENCODE_CACHE" "$OPENCODE_DATA/log" "$OPENCODE_LOG"; do
        [ -d "$cache_dir" ] && OPENCODE_CLEANABLE=$((OPENCODE_CLEANABLE + $(get_size_bytes "$cache_dir")))
    done
    OPENCODE_DB_SHM="$OPENCODE_DATA/opencode.db-shm"
    OPENCODE_DB_WAL="$OPENCODE_DATA/opencode.db-wal"
    # tool-output、snapshot、db-wal/db-shm 可能包含用户工作输出或活动数据库状态，默认保留。

    if [ "$OPENCODE_CLEANABLE" -gt 0 ]; then
        echo -e "  ${CYAN}OpenCode 可清理缓存${NC}: $(format_size $OPENCODE_CLEANABLE)"
        if confirm "  是否清理 OpenCode 浏览器缓存与日志？"; then
            silent_clean_dir "$OPENCODE_CACHE" "OpenCode 浏览器缓存"
            silent_clean_dir "$OPENCODE_DATA/log" "OpenCode 内部日志"
            silent_clean_dir "$OPENCODE_LOG" "OpenCode 系统日志"
            print_info "  已保留 OpenCode tool-output、snapshot 与数据库 wal/shm"
            print_success "  OpenCode 缓存清理完成"
        else
            print_info "  已跳过 OpenCode 缓存清理"
        fi
    else
        print_info "  未检测到 OpenCode 可清理缓存"
    fi
else
    print_info "  未检测到 OpenCode"
fi
echo ""


# ============================================================================
# 第六部分: 本机实测新增安全清理（只删可重建缓存）
# ============================================================================
echo -e "\n${GREEN}${SECTION_BAR}${NC}"
echo -e "${GREEN}  第六部分: 本机实测新增安全清理（只删可重建缓存）${NC}"
echo -e "${GREEN}${SECTION_BAR}${NC}\n"

print_info "35. 本机实测可重建缓存与临时文件"
print_warning "本节只处理本机扫描确认的缓存、临时目录、日志和旧更新包；聊天数据库、云文档、代理/VPN 配置均受保护"
REBUILDABLE_TARGETS=()
add_target_if_exists() {
    local target="$1"
    local desc="$2"
    local item=""
    [ -e "$target" ] || return 0
    if is_protected_path "$target"; then
        return 0
    fi
    for item in "${REBUILDABLE_TARGETS[@]}"; do
        [ "${item%%|*}" = "$target" ] && return 0
    done
    REBUILDABLE_TARGETS+=("$target|$desc")
}
USER_TEMP_DIR="$(getconf DARWIN_USER_TEMP_DIR 2>/dev/null)"

# 用户临时目录：解压包、Node 编译缓存、浏览器临时下载残留。
if [ -n "$USER_TEMP_DIR" ] && [ -d "$USER_TEMP_DIR" ]; then
    while IFS= read -r p; do add_target_if_exists "$p" "用户临时解压浏览器缓存"; done < <(find "$USER_TEMP_DIR" -maxdepth 1 -type d -name "decompressed-browser*" 2>/dev/null)
    add_target_if_exists "$USER_TEMP_DIR/node-compile-cache" "Node 编译临时缓存"
fi

# pnpm 未完成的临时工具目录。
while IFS= read -r p; do add_target_if_exists "$p" "pnpm 未完成临时工具目录"; done < <(find "$HOME/Library/pnpm/.tools/pnpm" -maxdepth 1 -type d -name "*_tmp_*" 2>/dev/null)

# Apple 地理定位临时目录与 App Store 缓存。
add_target_if_exists "$HOME/Library/Containers/com.apple.geod/Data/tmp" "Apple 地理定位临时目录"
add_target_if_exists "$HOME/Library/Containers/com.apple.AppStore/Data/Library/Caches" "App Store 可重建缓存"

# QQEX 文档内嵌浏览器缓存与编译缓存。
QQEX_BASE="$HOME/Library/Containers/com.tencent.qqexdoc/Data/Library/Application Support/QQEX"
if [ -d "$QQEX_BASE" ]; then
    while IFS= read -r p; do add_target_if_exists "$p" "QQEX 可重建网页/服务缓存"; done < <(find "$QQEX_BASE" -type d \( -name "Cache" -o -name "Code Cache" -o -name "GPUCache" -o -name "DawnWebGPUCache" -o -name "DawnGraphiteCache" -o -name "CacheStorage" -o -name "ScriptCache" -o -name "v8-compile-cache" \) 2>/dev/null)
fi

# 微信：仅临时目录、小程序代码缓存、网页 Cache、崩溃报告；不动聊天库和附件主目录。
WECHAT_ROOT="$HOME/Library/Containers/com.tencent.xinWeChat/Data/Documents"
if [ -d "$WECHAT_ROOT" ]; then
    while IFS= read -r p; do add_target_if_exists "$p" "微信收藏/收发临时缓存"; done < <(find "$WECHAT_ROOT/xwechat_files" -type d \( -path "*/business/favorite/temp" -o -path "*/temp" -o -path "*/cache" \) 2>/dev/null)
    while IFS= read -r p; do add_target_if_exists "$p" "微信小程序/内嵌网页可重建缓存"; done < <(find "$WECHAT_ROOT/app_data" -type d \( -name "Cache" -o -name "GPUCache" -o -name "DawnWebGPUCache" -o -name "DawnGraphiteCache" -o -name "CacheStorage" -o -name "ScriptCache" -o -name "codecache" -o -path "*/xfile/cache" -o -path "*/radium/cache" -o -name "crashinfo" \) 2>/dev/null)
fi

# QQ：旧更新压缩包、分区网页缓存、缩略图临时目录、日志缓存；不动 FileRecv、聊天消息和原图。
QQ_ROOT="$HOME/Library/Containers/com.tencent.qq/Data/Library/Application Support/QQ"
if [ -d "$QQ_ROOT" ]; then
    while IFS= read -r p; do add_target_if_exists "$p" "QQ 旧更新压缩包"; done < <(find "$QQ_ROOT/versions" -maxdepth 1 -type f -name "*.zip" 2>/dev/null)
    while IFS= read -r p; do add_target_if_exists "$p" "QQ 可重建网页/缩略/日志缓存"; done < <(find "$QQ_ROOT" -type d \( -name "Cache" -o -name "Code Cache" -o -name "GPUCache" -o -name "DawnWebGPUCache" -o -name "DawnGraphiteCache" -o -name "ThumbTemp" -o -name "log-cache" -o -name "nt_temp" \) 2>/dev/null)
fi

# WPS：只清插件网页缓存、临时目录、转换临时文件；云文档 filecache 默认受保护。
WPS_ROOT="$HOME/Library/Containers/com.kingsoft.wpsoffice.mac/Data"
if [ -d "$WPS_ROOT" ]; then
    add_target_if_exists "$WPS_ROOT/tmp" "WPS 临时目录"
    while IFS= read -r p; do add_target_if_exists "$p" "WPS 插件网页可重建缓存"; done < <(find "$WPS_ROOT/.kingsoft/wps/addons/data/mac-universal" -type d \( -name "Cache" -o -name "Code Cache" -o -name "GPUCache" -o -name "cache" -o -name "temp" \) 2>/dev/null)
fi

# Telegram：只清临时目录和日志，不动 postbox 数据库和媒体主缓存。
add_target_if_exists "$HOME/Library/Containers/ru.keepcoder.Telegram/Data/tmp" "Telegram 临时目录"
add_target_if_exists "$HOME/Library/Group Containers/6N38VWS5BX.ru.keepcoder.Telegram/appstore/logs" "Telegram 日志"
add_target_if_exists "$HOME/Library/Group Containers/6N38VWS5BX.ru.keepcoder.Telegram/appstore/temp" "Telegram 临时目录"

# 百度网盘：临时目录和普通 Cache。
add_target_if_exists "$HOME/Library/Containers/com.baidu.netdisk/Data/Library/Application Support/com.baidu.netdisk/tmp" "百度网盘临时目录"
add_target_if_exists "$HOME/Library/Containers/com.baidu.netdisk/Data/Library/Application Support/baidunetdisk/Cache" "百度网盘缓存"

# Chrome 真正的用户缓存目录。
add_target_if_exists "$HOME/Library/Caches/Google/Chrome/Default/Cache" "Chrome 网页缓存"
add_target_if_exists "$HOME/Library/Caches/Google/Chrome/Default/Code Cache" "Chrome 代码缓存"
add_target_if_exists "$HOME/Library/Caches/Google/Chrome/Default/GPUCache" "Chrome GPU 缓存"

# npm 下载缓存中的 tmp 只存放未完成/临时内容，保留 content-v2 与 index，避免影响离线依赖命中。
add_target_if_exists "$HOME/.npm/_cacache/tmp" "npm 未完成下载临时缓存"

# 深扫新增：常见 Electron/网盘/协作工具缓存，只清缓存目录，不动账号、数据库、下载目录和云盘文件。
add_target_if_exists "$HOME/Library/Caches/GeoServices" "GeoServices 地理服务缓存"
add_target_if_exists "$HOME/Library/Caches/typescript" "TypeScript 可重建缓存"
add_target_if_exists "$HOME/Library/Containers/com.apple.mediaanalysisd/Data/tmp" "Apple 照片分析临时目录"
add_target_if_exists "$HOME/Library/Containers/com.apple.photolibraryd/Data/tmp" "Apple 照片图库临时目录"

TEAMS_ROOT="$HOME/Library/Application Support/Microsoft/Teams"
if [ -d "$TEAMS_ROOT" ]; then
    for teams_dir in "Cache" "Code Cache" "GPUCache" "DawnWebGPUCache" "DawnGraphiteCache" "logs" "tmp"; do
        add_target_if_exists "$TEAMS_ROOT/$teams_dir" "Microsoft Teams 可重建缓存"
    done
fi

X_APP_ROOT="$HOME/Library/Application Support/x"
if [ -d "$X_APP_ROOT" ]; then
    while IFS= read -r p; do add_target_if_exists "$p" "X 应用可重建网页缓存"; done < <(find "$X_APP_ROOT" -type d \( -name "Cache" -o -name "Code Cache" -o -name "GPUCache" -o -name "DawnWebGPUCache" -o -name "DawnGraphiteCache" -o -name "DawnCache" \) 2>/dev/null)
fi

for cloud_root in "$HOME/Library/Application Support/uc-cloud-drive" "$HOME/Library/Application Support/quark-cloud-drive"; do
    if [ -d "$cloud_root" ]; then
        while IFS= read -r p; do add_target_if_exists "$p" "网盘客户端可重建网页缓存"; done < <(find "$cloud_root" -type d \( -name "Cache" -o -name "Code Cache" -o -name "GPUCache" -o -name "DawnWebGPUCache" -o -name "DawnGraphiteCache" -o -name "DawnCache" \) 2>/dev/null)
    fi
done

# WPS 与百度网盘补充小缓存，继续保护 WPS Cloud filecache 和百度网盘下载文件。
add_target_if_exists "$HOME/Library/Containers/com.kingsoft.wpsoffice.mac/Data/.kingsoft/office6/docerFonts/cache" "WPS 字体可重建缓存"
add_target_if_exists "$HOME/Library/Containers/com.kingsoft.wpsoffice.mac/Data/.kingsoft/office6/pdf/temp" "WPS PDF 临时目录"
BAIDU_APP_ROOT="$HOME/Library/Containers/com.baidu.netdisk/Data/Library/Application Support/baidunetdisk"
if [ -d "$BAIDU_APP_ROOT" ]; then
    while IFS= read -r p; do add_target_if_exists "$p" "百度网盘可重建网页缓存"; done < <(find "$BAIDU_APP_ROOT" -maxdepth 2 -type d \( -name "Code Cache" -o -name "GPUCache" -o -name "DawnCache" -o -name "DawnWebGPUCache" -o -name "DawnGraphiteCache" \) 2>/dev/null)
fi

REBUILDABLE_TOTAL=0
for item in "${REBUILDABLE_TARGETS[@]}"; do
    path="${item%%|*}"
    [ -e "$path" ] || continue
    if is_protected_path "$path"; then
        continue
    fi
    REBUILDABLE_TOTAL=$((REBUILDABLE_TOTAL + $(get_size_bytes "$path")))
done

if [ "$REBUILDABLE_TOTAL" -gt 0 ] 2>/dev/null; then
    echo -e "  ${CYAN}本机实测新增可重建缓存${NC}: $(format_size $REBUILDABLE_TOTAL)"
    if confirm "  是否清理这些可重建缓存？"; then
        for item in "${REBUILDABLE_TARGETS[@]}"; do
            path="${item%%|*}"
            desc="${item#*|}"
            safe_remove_rebuildable_path "$path" "$desc"
        done
        print_success "  本机实测新增安全清理完成"
    else
        print_info "  已跳过本机实测新增安全清理"
    fi
else
    print_info "  未检测到本机实测新增可重建缓存"
fi
echo ""

# ============================================================================
# 第七部分: 实测新增安全清理项（废纸篓/AI工具/Photos/manicode/iMessage等）
# ============================================================================
echo -e "\n${GREEN}${SECTION_BAR}${NC}"
echo -e "${GREEN}  第七部分: 实测新增安全清理（废纸篓/AI工具/Photos/manicode/iMessage等）${NC}"
echo -e "${GREEN}${SECTION_BAR}${NC}\n"

# 36. 废纸篓
print_info "36. 废纸篓"
TRASH_DIR="$HOME/.Trash"
if [ -d "$TRASH_DIR" ]; then
    TRASH_SIZE=$(get_size_bytes "$TRASH_DIR")
    if [ "$TRASH_SIZE" -gt 0 ]; then
        echo -e "  ${CYAN}废纸篓${NC}: $(format_size $TRASH_SIZE)"
        if confirm "  是否清空废纸篓？"; then
            silent_clean_dir "$TRASH_DIR" "废纸篓"
        else
            print_info "  已跳过"
        fi
    else
        print_info "  废纸篓已是空的"
    fi
fi
echo ""

# 37. Qoder CN IDE（已保护：清理后会丢失账号信息）
print_info "37. Qoder CN IDE（已保护，不清理）"
QODER_DIR="$HOME/Library/Application Support/QoderCN"
if [ -d "$QODER_DIR" ]; then
    QODER_SIZE=$(get_size_bytes "$QODER_DIR")
    echo -e "  ${YELLOW}[已保护]${NC} Qoder CN: $(format_size $QODER_SIZE)（清理后会丢失账号信息，已加入保护清单）"
fi
echo ""

# 38. Devin 缓存（保护登录态和会话）
print_info "38. Devin 缓存"
DEVIN_DIR="$HOME/Library/Application Support/Devin"
if [ -d "$DEVIN_DIR" ]; then
    DEVIN_CLEANABLE=0
    for dd in "CachedData" "CachedProfilesData" "GPUCache" "DawnWebGPUCache" "DawnGraphiteCache" "clp" "logs"; do
        [ -d "$DEVIN_DIR/$dd" ] && DEVIN_CLEANABLE=$((DEVIN_CLEANABLE + $(get_size_bytes "$DEVIN_DIR/$dd")))
    done
    if [ "$DEVIN_CLEANABLE" -gt 0 ]; then
        echo -e "  ${CYAN}Devin 可清理缓存${NC}: $(format_size $DEVIN_CLEANABLE)"
        print_info "  已保护：Local Storage、Cookies、User、IndexedDB（登录态与会话）"
        if confirm "  是否先退出 Devin 再清理缓存？"; then
            kill_app_process "Devin" "com.devin.desktop"
            for dd in "CachedData" "CachedProfilesData" "GPUCache" "DawnWebGPUCache" "DawnGraphiteCache" "clp" "logs"; do
                silent_remove_dir "$DEVIN_DIR/$dd" "Devin $dd"
            done
            print_success "  Devin 缓存清理完成"
        else
            print_info "  已跳过"
        fi
    else
        print_info "  未检测到 Devin 可清理缓存"
    fi
fi
echo ""

# 39. 腾讯会议缓存
print_info "39. 腾讯会议缓存"
MEETING_DIR="$HOME/Library/Containers/com.tencent.meeting"
if [ -d "$MEETING_DIR" ]; then
    MEETING_DATA="$MEETING_DIR/Data/Library/Global/Data"
    MEETING_LOGS="$MEETING_DIR/Data/Library/Global/Logs"
    MEETING_CLEANABLE=0
    [ -d "$MEETING_DATA" ] && MEETING_CLEANABLE=$((MEETING_CLEANABLE + $(get_size_bytes "$MEETING_DATA")))
    [ -d "$MEETING_LOGS" ] && MEETING_CLEANABLE=$((MEETING_CLEANABLE + $(get_size_bytes "$MEETING_LOGS")))
    if [ "$MEETING_CLEANABLE" -gt 0 ]; then
        echo -e "  ${CYAN}腾讯会议可清理缓存${NC}: $(format_size $MEETING_CLEANABLE)"
        if confirm "  是否先退出腾讯会议再清理缓存？"; then
            kill_app_process "腾讯会议" "com.tencent.meeting"
            silent_clean_dir "$MEETING_DATA" "腾讯会议缓存数据"
            silent_clean_dir "$MEETING_LOGS" "腾讯会议日志"
            print_success "  腾讯会议缓存清理完成"
        else
            print_info "  已跳过"
        fi
    else
        print_info "  未检测到腾讯会议可清理缓存"
    fi
fi
echo ""

# 40. Photos 缩略图缓存（系统会自动重建）
print_info "40. Photos 缩略图缓存（derivatives，系统自动重建）"
PHOTOS_DERIV="$HOME/Pictures/Photos Library.photoslibrary/resources/derivatives"
if [ -d "$PHOTOS_DERIV" ]; then
    PHOTOS_SIZE=$(get_size_bytes "$PHOTOS_DERIV")
    if [ "$PHOTOS_SIZE" -gt 0 ]; then
        echo -e "  ${CYAN}Photos derivatives 缩略图缓存${NC}: $(format_size $PHOTOS_SIZE)"
        print_info "  删除后系统会自动重建缩略图，不影响原始照片"
        print_info "  已保护：originals（原始照片）、database（照片数据库）"
        if confirm "  是否清理 Photos 缩略图缓存？"; then
            silent_clean_dir "$PHOTOS_DERIV" "Photos derivatives 缩略图缓存"
        else
            print_info "  已跳过"
        fi
    fi
fi
echo ""

# 41. manicode 聊天历史缓存
print_info "41. manicode 聊天历史缓存"
MANICODE_CHATS="$HOME/.config/manicode/projects"
if [ -d "$MANICODE_CHATS" ]; then
    MANICODE_SIZE=$(get_size_bytes "$MANICODE_CHATS")
    if [ "$MANICODE_SIZE" -gt 0 ]; then
        echo -e "  ${CYAN}manicode 聊天历史缓存${NC}: $(format_size $MANICODE_SIZE)"
        print_info "  聊天历史记录，删除后不影响 manicode 使用，只是丢失历史对话"
        if confirm "  是否清理 manicode 聊天历史？"; then
            silent_clean_dir "$MANICODE_CHATS" "manicode 聊天历史"
        else
            print_info "  已跳过"
        fi
    fi
fi
echo ""

# 42. iMessage 缓存（保护 chat.db 聊天数据库）
print_info "42. iMessage 缓存（保护 chat.db 聊天数据库）"
IMESSAGE_CACHE="$HOME/Library/Messages/Caches"
if [ -d "$IMESSAGE_CACHE" ]; then
    IMESSAGE_SIZE=$(get_size_bytes "$IMESSAGE_CACHE")
    if [ "$IMESSAGE_SIZE" -gt 0 ]; then
        echo -e "  ${CYAN}iMessage 缓存${NC}: $(format_size $IMESSAGE_SIZE)"
        print_info "  已保护：chat.db（聊天记录）、Attachments（附件）"
        if confirm "  是否清理 iMessage 缓存？"; then
            silent_clean_dir "$IMESSAGE_CACHE" "iMessage 缓存"
        else
            print_info "  已跳过"
        fi
    fi
fi
echo ""

# 43. uv/tools 工具缓存
print_info "43. uv/tools 工具缓存"
UV_TOOLS="$HOME/.local/share/uv/tools"
if [ -d "$UV_TOOLS" ]; then
    UV_TOOLS_SIZE=$(get_size_bytes "$UV_TOOLS")
    if [ "$UV_TOOLS_SIZE" -gt 0 ]; then
        echo -e "  ${CYAN}uv/tools 工具缓存${NC}: $(format_size $UV_TOOLS_SIZE)"
        print_info "  uv 安装的工具缓存，删除后可用 uv tool install 重新安装"
        if confirm "  是否清理 uv/tools 工具缓存？"; then
            silent_clean_dir "$UV_TOOLS" "uv/tools 工具缓存"
        else
            print_info "  已跳过"
        fi
    fi
fi
echo ""

# 44. 诊断报告（崩溃报告，可安全删除）
print_info "44. 诊断报告（崩溃报告）"
DIAG_USER="$HOME/Library/Logs/DiagnosticReports"
DIAG_SYS="/Library/Logs/DiagnosticReports"
DIAG_CLEANABLE=0
[ -d "$DIAG_USER" ] && DIAG_CLEANABLE=$((DIAG_CLEANABLE + $(get_size_bytes "$DIAG_USER")))
[ -d "$DIAG_SYS" ] && DIAG_CLEANABLE=$((DIAG_CLEANABLE + $(get_size_bytes "$DIAG_SYS")))
if [ "$DIAG_CLEANABLE" -gt 0 ]; then
    echo -e "  ${CYAN}诊断报告（崩溃报告）${NC}: $(format_size $DIAG_CLEANABLE)"
    if confirm "  是否清理诊断报告？"; then
        silent_clean_dir "$DIAG_USER" "用户诊断报告"
        if [ -d "$DIAG_SYS" ]; then
            if [ "$DRY_RUN" -eq 1 ] 2>/dev/null; then
                print_info "  演练模式：不清理系统诊断报告"
            else
                sudo find "$DIAG_SYS" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null
                print_success "  系统诊断报告已清理"
            fi
        fi
    else
        print_info "  已跳过"
    fi
fi
echo ""

# 45. Codeium/Devin 非配置缓存（严格保护 MCP 配置和登录态）
print_info "45. Codeium/Devin 非配置缓存（严格保护 MCP 配置）"
CODEIUM_WS="$HOME/.codeium/windsurf"
if [ -d "$CODEIUM_WS" ]; then
    CODEIUM_CLEANABLE=0
    for cd in "implicit" "code_tracker"; do
        [ -d "$CODEIUM_WS/$cd" ] && CODEIUM_CLEANABLE=$((CODEIUM_CLEANABLE + $(get_size_bytes "$CODEIUM_WS/$cd")))
    done
    if [ "$CODEIUM_CLEANABLE" -gt 0 ]; then
        echo -e "  ${CYAN}Codeium/Devin AI 索引缓存${NC}: $(format_size $CODEIUM_CLEANABLE)"
        print_info "  已保护：mcp_config.json、cascade(对话历史)、memories、skills、installation_id、user_settings.pb"
        if confirm "  是否清理 Codeium/Devin AI 索引缓存？"; then
            for cd in "implicit" "code_tracker"; do
                safe_remove_rebuildable_path "$CODEIUM_WS/$cd" "Devin $(basename "$cd") AI 索引缓存"
            done
            print_success "  Codeium/Devin AI 索引缓存清理完成"
        else
            print_info "  已跳过"
        fi
    else
        print_info "  未检测到 Codeium/Devin 可清理缓存"
    fi
fi
echo ""

# ============================================================================
# 清理完成
# ============================================================================
echo -e "\n${GREEN}${SECTION_BAR}${NC}"
echo -e "${GREEN}  清理完成！${NC}"
echo -e "${GREEN}${SECTION_BAR}${NC}\n"

if [ "$DRY_RUN" -eq 1 ] 2>/dev/null; then
    echo -e "本次为演练/扫描模式，实际释放空间: ${GREEN}0B${NC}"
else
    echo -e "本次清理释放空间: ${GREEN}$(format_size $TOTAL_FREED)${NC}"
fi
echo ""
print_warning "清理后建议重启电脑，让系统重新计算存储空间"
echo ""
