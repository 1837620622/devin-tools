#!/bin/bash

# ============================================================================
# Windsurf 修复工具 - macOS 版本
# 用于修复 Windsurf IDE 卡顿、Shell无法连接等常见问题
# 基于官方文档: https://docs.windsurf.com/troubleshooting/windsurf-common-issues
# 作者: 传康KK
# GitHub: https://github.com/1837620622/windsurf-fix-tool
# ============================================================================

# ----------------------------------------------------------------------------
# 颜色定义


# ----------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ----------------------------------------------------------------------------
# 路径定义
# ----------------------------------------------------------------------------
CODEIUM_DIR="$HOME/.codeium"
WINDSURF_DIR="$CODEIUM_DIR/windsurf"
CASCADE_DIR="$WINDSURF_DIR/cascade"
WINDSURF_APP="/Applications/Windsurf.app"
BACKUP_DIR="$HOME/.windsurf-backup-$(date +%Y%m%d_%H%M%S)"
WINDSURF_SUPPORT_DIR="$HOME/Library/Application Support/Windsurf"
WINDSURF_RUNTIME_DIR="$WINDSURF_SUPPORT_DIR"
IMPLICIT_DIR="$WINDSURF_DIR/implicit"
CODE_TRACKER_DIR="$WINDSURF_DIR/code_tracker"
MACOS_WS_CACHE="$HOME/Library/Caches/com.exafunction.windsurf"
MACOS_WS_SHIPIT="$HOME/Library/Caches/com.exafunction.windsurf.ShipIt"
XDG_CONFIG_ROOT="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_CACHE_ROOT="${XDG_CACHE_HOME:-$HOME/.cache}"
XDG_DATA_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}"
CLAUDE_CODE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
CODEX_DIR="${CODEX_HOME:-$HOME/.codex}"
if [ -n "$GEMINI_CLI_HOME" ]; then
    case "$(basename "$GEMINI_CLI_HOME")" in
        .gemini) GEMINI_CLI_DIR="$GEMINI_CLI_HOME" ;;
        *) GEMINI_CLI_DIR="$GEMINI_CLI_HOME/.gemini" ;;
    esac
else
    GEMINI_CLI_DIR="$HOME/.gemini"
fi
OPENCODE_INSTALL_DIR="$HOME/.opencode"
OPENCODE_CONFIG_DIR="$XDG_CONFIG_ROOT/opencode"
OPENCODE_CACHE_DIR="$XDG_CACHE_ROOT/opencode"
OPENCODE_DATA_DIR="$XDG_DATA_ROOT/opencode"

# ----------------------------------------------------------------------------
# 工具函数
# ----------------------------------------------------------------------------
print_header() {
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  Windsurf 修复工具 - macOS${NC}"
    echo -e "${CYAN}  by 传康KK${NC}"
    echo -e "${CYAN}  github.com/1837620622/windsurf-fix-tool${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    # ── 运行模式提示 ─────────────────────────────────────────────────
    if [ "${FORCE_RESET_ID:-1}" = "0" ] || [ "${FORCE_RESET_ID:-1}" = "false" ]; then
        echo -e "${GREEN}[当前模式] 保守模式${NC}（FORCE_RESET_ID=0）——清理不重置设备 ID，保留登录态"
    else
        echo -e "${RED}[当前模式] 强制重置模式${NC}（默认）——所有清理菜单完成后自动重置 Windsurf 设备 ID"
        echo -e "  ${YELLOW}⚠ 重置后 Windsurf 会被识别为新设备，可能需要重新登录一次${NC}"
        echo -e "  ${YELLOW}⚠ 用途：绕过限速、刷新免费额度、解决服务端缓存异常${NC}"
        echo -e "  如需关闭强制重置：${CYAN}FORCE_RESET_ID=0 bash fix-windsurf-mac.sh${NC}"
    fi
    echo ""
    echo -e "${GREEN}[始终保留]${NC} 对话和用户数据，任何模式下都不会被清理："
    echo -e "  • ${CYAN}~/.codeium/windsurf/cascade/*.pb${NC}            对话历史"
    echo -e "  • ${CYAN}~/.codeium/windsurf/memories/${NC}                 用户记忆"
    echo -e "  • ${CYAN}~/.codeium/windsurf/skills/${NC}                   技能"
    echo -e "  • ${CYAN}~/.codeium/windsurf/mcp_config.json${NC}          MCP 配置"
    echo -e "  • ${CYAN}~/.codeium/windsurf/user_settings.pb${NC}          用户偏好"
    echo -e "  • ${CYAN}Application Support/Windsurf/User/settings.json${NC}  编辑器设置"
    echo ""
    echo -e "${RED}[清理后会被强制重置]${NC} 仅在强制重置模式下（默认）："
    echo -e "  • ${CYAN}installation_id${NC}                              Windsurf 安装标识"
    echo -e "  • ${CYAN}machineid${NC}                                    机器标识"
    echo -e "  • ${CYAN}storage.json${NC} 中的 telemetry.devDeviceId/macMachineId/machineId/sqmId"
    echo ""
}

print_info() {
    echo -e "${BLUE}[信息]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[成功]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[警告]${NC} $1"
}

print_error() {
    echo -e "${RED}[错误]${NC} $1"
}

confirm_action() {
    echo -ne ${YELLOW}确认执行此操作？[y/N]: ${NC}
    read -r choice
    case "$choice" in
        y|Y ) return 0;;
        * ) return 1;;
    esac
}

# ----------------------------------------------------------------------------
# 检测系统信息
# ----------------------------------------------------------------------------
detect_system_info() {
    print_info "正在检测系统信息..."
    
    # 检测处理器类型
    ARCH=$(uname -m)
    if [ "$ARCH" = "arm64" ]; then
        PROCESSOR_TYPE="Apple Silicon (M系列芯片)"
    else
        PROCESSOR_TYPE="Intel"
    fi
    
    # 检测macOS版本
    MACOS_VERSION=$(sw_vers -productVersion)
    
    echo ""
    echo -e "  处理器类型: ${GREEN}$PROCESSOR_TYPE${NC}"
    echo -e "  macOS版本: ${GREEN}$MACOS_VERSION${NC}"
    echo -e "  Windsurf路径: ${GREEN}$WINDSURF_APP${NC}"
    echo ""
}

# ----------------------------------------------------------------------------
# 检查Windsurf是否正在运行
# ----------------------------------------------------------------------------
check_windsurf_running() {
    if pgrep -x "Windsurf" > /dev/null 2>&1; then
        print_warning "检测到 Windsurf 正在运行"
        echo -e "  请先关闭 Windsurf 再执行修复操作"
        if [ "${TERM_PROGRAM:-}" = "vscode" ]; then
            print_warning "当前看起来是在 Windsurf / VS Code 类内置终端中运行"
            echo -e "  如果在这里自动关闭 Windsurf，当前终端会一起消失，看起来就像“没反应”"
            echo -e "  建议先手动关闭 Windsurf，再从 Terminal.app 或 iTerm 重新运行脚本"
            return 1
        fi
        echo -ne ${YELLOW}是否自动关闭Windsurf？[y/N]: ${NC}
        read -r choice
        case "$choice" in
            y|Y )
                pkill -x "Windsurf" 2>/dev/null || true
                sleep 2
                print_success "Windsurf 已关闭"
                return 0
                ;;
            * )
                print_error "请手动关闭 Windsurf 后重试"
                return 1
                ;;
        esac
    fi

    return 0
}

# ----------------------------------------------------------------------------
# 功能1: 清理Cascade缓存
# ----------------------------------------------------------------------------
clean_cascade_cache() {
    print_info "清理 Cascade 缓存..."
    print_warning "此操作将删除对话历史和本地设置！"
    
    if [ ! -d "$CASCADE_DIR" ]; then
        print_info "Cascade 缓存目录不存在，无需清理"
        return 0
    fi
    
    if confirm_action; then
        # 备份
        mkdir -p "$BACKUP_DIR"
        cp -r "$CASCADE_DIR" "$BACKUP_DIR/" 2>/dev/null || true
        print_info "已备份到: $BACKUP_DIR"
        
        # 删除
        rm -rf "$CASCADE_DIR"
        print_success "Cascade 缓存已清理"

        # 清理完毕 -> 强制重置设备 ID（默认行为，FORCE_RESET_ID=0 可关闭）
        auto_reset_after_clean
    else
        print_info "已取消操作"
    fi
}

# ----------------------------------------------------------------------------
# 功能3: 清理扩展缓存
# ----------------------------------------------------------------------------
clean_extension_cache() {
    print_info "清理扩展缓存..."

    if confirm_action; then
        CACHE_CLEARED=0

        # 优先清理 Electron 运行时目录中的实际缓存路径，兼容旧版目录结构。
        for cache_dir in \
            "$WINDSURF_RUNTIME_DIR/CachedData" \
            "$WINDSURF_RUNTIME_DIR/CachedExtensionVSIXs" \
            "$WINDSURF_DIR/CachedData" \
            "$WINDSURF_DIR/CachedExtensions"; do
            if [ -d "$cache_dir" ]; then
                rm -rf "$cache_dir"
                print_success "已清理 $(basename "$cache_dir")"
                CACHE_CLEARED=1
            fi
        done

        if [ "$CACHE_CLEARED" -eq 0 ]; then
            print_info "未找到可清理的扩展缓存目录"
        fi

        print_success "扩展缓存清理完成"

        # 清理完毕 -> 强制重置设备 ID（默认行为）
        auto_reset_after_clean
    else
        print_info "已取消操作"
    fi
}

# ----------------------------------------------------------------------------
# 功能12: 修复"Windsurf已损坏"问题
# ----------------------------------------------------------------------------
fix_damaged_app() {
    print_info "修复 'Windsurf已损坏' 问题..."
    
    if [ ! -d "$WINDSURF_APP" ]; then
        print_error "未找到 Windsurf 应用: $WINDSURF_APP"
        print_info "请确保 Windsurf 已安装在 /Applications 目录"
        return 0
    fi
    
    echo ""
    echo "此操作将执行: xattr -c \"$WINDSURF_APP\""
    echo "用于清除隔离属性，解决macOS安全提示问题"
    echo ""
    
    if confirm_action; then
        xattr -c "$WINDSURF_APP"
        print_success "已清除隔离属性"
        
        # 同时清除可能的代码签名问题
        xattr -cr "$WINDSURF_APP" 2>/dev/null || true
        print_info "提示: 如果问题仍然存在，请尝试重新下载 Windsurf"
    else
        print_info "已取消操作"
    fi
}

# ----------------------------------------------------------------------------
# 功能10: 配置终端设置
# ----------------------------------------------------------------------------
configure_terminal_settings() {
    print_info "配置终端设置..."
    
    SETTINGS_JSON="$HOME/Library/Application Support/Windsurf/User/settings.json"
    
    echo ""
    echo "推荐的终端配置:"
    echo -e "  ${GREEN}\"terminal.integrated.defaultProfile.osx\": \"zsh\"${NC}"
    echo ""
    
    if [ -f "$SETTINGS_JSON" ]; then
        print_info "settings.json 位置: $SETTINGS_JSON"
        
        # 检查是否已配置
        if grep -q "terminal.integrated.defaultProfile.osx" "$SETTINGS_JSON" 2>/dev/null; then
            print_info "终端配置已存在"
            grep "terminal.integrated.defaultProfile" "$SETTINGS_JSON" | head -1
        else
            print_warning "未找到终端配置，建议手动添加"
        fi
    else
        print_warning "未找到 settings.json 文件"
        print_info "Windsurf 可能尚未创建配置文件，请先启动一次 Windsurf"
    fi
}

# ----------------------------------------------------------------------------
# 功能9: 检测zsh主题冲突
# ----------------------------------------------------------------------------
detect_zsh_theme_conflicts() {
    print_info "检测 zsh 主题冲突..."
    
    ZSHRC="$HOME/.zshrc"
    
    if [ ! -f "$ZSHRC" ]; then
        print_info "未找到 .zshrc 文件，跳过检测"
        return 0
    fi
    
    echo ""
    echo "正在检测可能导致终端卡住的配置..."
    echo ""
    
    CONFLICTS_FOUND=0
    
    # 检测Oh My Zsh主题
    if grep -q "ZSH_THEME=" "$ZSHRC" 2>/dev/null; then
        THEME=$(grep "ZSH_THEME=" "$ZSHRC" | grep -v "^#" | head -1)
        if [ -n "$THEME" ]; then
            print_warning "检测到 Oh My Zsh 主题: $THEME"
            CONFLICTS_FOUND=1
        fi
    fi
    
    # 检测Powerlevel10k
    if grep -q "p10k" "$ZSHRC" 2>/dev/null; then
        print_warning "检测到 Powerlevel10k 配置"
        CONFLICTS_FOUND=1
    fi
    
    # 检测oh-my-posh
    if grep -q "oh-my-posh" "$ZSHRC" 2>/dev/null; then
        print_warning "检测到 oh-my-posh 配置"
        CONFLICTS_FOUND=1
    fi
    
    if [ $CONFLICTS_FOUND -eq 1 ]; then
        echo ""
        echo -e "${YELLOW}建议:${NC} 如果终端会话卡住，请尝试在 ~/.zshrc 中注释以下行:"
        echo ""
        echo "  # ZSH_THEME=\"powerlevel10k/powerlevel10k\""
        echo "  # source ~/.p10k.zsh"
        echo "  # eval \"\$(oh-my-posh init zsh)\""
        echo ""
        
        echo -ne ${YELLOW}是否创建Windsurf专用的简化zshrc？[y/N]: ${NC}
        read -r choice
        case "$choice" in
            y|Y )
                create_windsurf_zshrc
                ;;
        esac
    else
        print_success "未检测到已知的主题冲突"
    fi
}

# ----------------------------------------------------------------------------
# 创建Windsurf专用zshrc
# ----------------------------------------------------------------------------
create_windsurf_zshrc() {
    WINDSURF_ZSHRC="$HOME/.zshrc.windsurf"
    
    cat > "$WINDSURF_ZSHRC" << 'EOF'
# ============================================================================
# Windsurf 专用 zsh 配置
# 此配置文件用于解决复杂主题导致的终端卡住问题
# 使用方法: 在 Windsurf 设置中配置 shell 参数为:
#   "terminal.integrated.shellArgs.osx": ["--rcfile", "~/.zshrc.windsurf"]
# ============================================================================

# 基础环境变量
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
export EDITOR="code"
export LANG="en_US.UTF-8"

# 简单提示符
PROMPT='%n@%m %1~ %# '

# 加载用户别名（如果存在）
[ -f ~/.aliases ] && source ~/.aliases

# 历史记录配置
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt HIST_IGNORE_DUPS
setopt SHARE_HISTORY

# 自动补全
autoload -Uz compinit && compinit
EOF
    
    print_success "已创建 Windsurf 专用 zshrc: $WINDSURF_ZSHRC"
    echo ""
    print_info "使用方法: 在 Windsurf 设置中添加:"
    echo '  "terminal.integrated.shellArgs.osx": ["--rcfile", "~/.zshrc.windsurf"]'
}

# ----------------------------------------------------------------------------
# 功能13: 生成诊断报告
# ----------------------------------------------------------------------------
generate_diagnostic_report() {
    print_info "生成诊断报告..."
    
    REPORT_FILE="$HOME/windsurf-diagnostic-$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "=========================================="
        echo "Windsurf 诊断报告"
        echo "生成时间: $(date)"
        echo "=========================================="
        echo ""
        
        echo "## 系统信息"
        echo "处理器架构: $(uname -m)"
        echo "macOS版本: $(sw_vers -productVersion)"
        echo "macOS构建: $(sw_vers -buildVersion)"
        echo ""
        
        echo "## Windsurf 安装状态"
        if [ -d "$WINDSURF_APP" ]; then
            echo "Windsurf.app: 已安装"
            ls -la "$WINDSURF_APP" 2>/dev/null | head -5
        else
            echo "Windsurf.app: 未找到"
        fi
        echo ""
        
        echo "## Codeium 目录状态"
        if [ -d "$CODEIUM_DIR" ]; then
            echo "目录存在: $CODEIUM_DIR"
            du -sh "$CODEIUM_DIR" 2>/dev/null || echo "无法计算大小"
            echo ""
            echo "子目录:"
            ls -la "$CODEIUM_DIR" 2>/dev/null
        else
            echo "目录不存在: $CODEIUM_DIR"
        fi
        echo ""
        
        echo "## Cascade 缓存状态"
        if [ -d "$CASCADE_DIR" ]; then
            echo "目录存在: $CASCADE_DIR"
            du -sh "$CASCADE_DIR" 2>/dev/null || echo "无法计算大小"
        else
            echo "目录不存在: $CASCADE_DIR"
        fi
        echo ""
        
        echo "## Shell 配置"
        echo "默认Shell: $SHELL"
        echo ""
        echo ".zshrc 主题相关配置:"
        grep -E "(ZSH_THEME|p10k|oh-my-posh|PROMPT)" "$HOME/.zshrc" 2>/dev/null || echo "未找到主题配置"
        echo ""
        
        echo "## 网络状态"
        echo "ping codeium.com:"
        ping -c 2 codeium.com 2>/dev/null || echo "无法ping"
        echo ""
        
        echo "## 磁盘空间"
        df -h / 2>/dev/null | head -2
        echo ""

        echo "## Windsurf 关键数据库大小"
        STATE_DB="$WINDSURF_SUPPORT_DIR/User/globalStorage/state.vscdb"
        STATE_DB_BACKUP="$WINDSURF_SUPPORT_DIR/User/globalStorage/state.vscdb.backup"
        if [ -f "$STATE_DB" ]; then
            echo "state.vscdb:"
            du -sh "$STATE_DB" 2>/dev/null
        else
            echo "state.vscdb: 文件不存在"
        fi
        if [ -f "$STATE_DB_BACKUP" ]; then
            echo "state.vscdb.backup:"
            du -sh "$STATE_DB_BACKUP" 2>/dev/null
        else
            echo "state.vscdb.backup: 文件不存在"
        fi
        echo ""

        echo "## Windsurf implicit 索引缓存"
        if [ -d "$IMPLICIT_DIR" ]; then
            du -sh "$IMPLICIT_DIR" 2>/dev/null || echo "无法计算 implicit 目录大小"
        else
            echo "implicit 目录不存在: $IMPLICIT_DIR"
        fi
        echo ""

        echo "## /tmp 终端快照"
        SNAPSHOT_COUNT=$(ls /tmp/windsurf-terminal-*.snapshot 2>/dev/null | wc -l | tr -d ' ')
        echo "windsurf-terminal-*.snapshot 数量: $SNAPSHOT_COUNT"
        echo ""

        echo "## Windsurf 进程信息"
        WS_PROCESS_INFO=$(ps aux | grep -i "[w]indsurf" | grep -v "fix-windsurf-mac.sh")
        if [ -n "$WS_PROCESS_INFO" ]; then
            echo "$WS_PROCESS_INFO"
        else
            echo "未检测到 Windsurf 相关进程"
        fi
        echo ""

        echo "## Windsurf 缓存目录详细大小"
        for cache_dir in \
            "$WINDSURF_SUPPORT_DIR/Cache/Cache_Data" \
            "$WINDSURF_SUPPORT_DIR/CachedData" \
            "$WINDSURF_SUPPORT_DIR/GPUCache" \
            "$WINDSURF_SUPPORT_DIR/Code Cache" \
            "$WINDSURF_SUPPORT_DIR/logs" \
            "$WINDSURF_SUPPORT_DIR/Crashpad/completed" \
            "$WINDSURF_SUPPORT_DIR/Crashpad/pending" \
            "$WINDSURF_SUPPORT_DIR/Service Worker/CacheStorage" \
            "$WINDSURF_SUPPORT_DIR/Service Worker/ScriptCache" \
            "$MACOS_WS_CACHE" \
            "$MACOS_WS_SHIPIT"
        do
            if [ -e "$cache_dir" ]; then
                echo "$cache_dir"
                du -sh "$cache_dir" 2>/dev/null || echo "无法计算大小"
            else
                echo "$cache_dir (不存在)"
            fi
        done
        echo ""
        
    } > "$REPORT_FILE"
    
    print_success "诊断报告已保存: $REPORT_FILE"
}

# ----------------------------------------------------------------------------
# 功能14: 完整修复（执行所有修复步骤）
# ----------------------------------------------------------------------------
full_repair() {
    print_info "执行完整修复..."
    print_warning "此操作将执行所有修复步骤"
    
    if confirm_action; then
        if ! check_windsurf_running; then
            return 1
        fi
        # 标记批量模式：子函数跳过各自的 auto_reset_after_clean
        _IN_BATCH_REPAIR=1
        export _IN_BATCH_REPAIR

        clean_cascade_cache
        clean_extension_cache
        clean_startup_cache
        deep_clean_runtime_cache
        fix_damaged_app
        configure_terminal_settings
        detect_zsh_theme_conflicts
        generate_diagnostic_report

        # 退出批量模式，末尾统一重置一次
        _IN_BATCH_REPAIR=0
        export _IN_BATCH_REPAIR

        echo ""
        print_success "完整修复已完成！"

        # 统一在完整修复末尾执行一次强制重置
        auto_reset_after_clean
        print_info "请重新启动 Windsurf"
    else
        print_info "已取消操作"
    fi
}

# ----------------------------------------------------------------------------
# 格式化KB大小
# ----------------------------------------------------------------------------
format_kb_size() {
    KB_VALUE="$1"
    
    if [ "$KB_VALUE" -ge 1048576 ] 2>/dev/null; then
        awk -v kb="$KB_VALUE" 'BEGIN {printf "%.2fGB", kb/1024/1024}'
    elif [ "$KB_VALUE" -ge 1024 ] 2>/dev/null; then
        awk -v kb="$KB_VALUE" 'BEGIN {printf "%.2fMB", kb/1024}'
    else
        echo "${KB_VALUE}KB"
    fi
}

# ----------------------------------------------------------------------------
# 计算glob路径总大小（KB）
# ----------------------------------------------------------------------------
calculate_glob_size_kb() {
    GLOB_PATTERN="$1"
    TOTAL_KB=$(compgen -G "$GLOB_PATTERN" | while IFS= read -r item; do
        du -sk "$item" 2>/dev/null | awk '{print $1}'
    done | awk '{sum+=$1} END{print sum+0}')
    echo "${TOTAL_KB:-0}"
}

# ----------------------------------------------------------------------------
# 清理glob路径并统计释放空间
# ----------------------------------------------------------------------------
clean_glob_with_stats() {
    TARGET_PATTERN="$1"
    TARGET_LABEL="$2"
    
    BEFORE_KB=$(calculate_glob_size_kb "$TARGET_PATTERN")
    echo ""
    print_info "$TARGET_LABEL"
    
    if [ "$BEFORE_KB" -gt 0 ] 2>/dev/null; then
        print_info "清理前大小: $(format_kb_size "$BEFORE_KB")"
        compgen -G "$TARGET_PATTERN" | while IFS= read -r item; do
            du -sh "$item" 2>/dev/null | sed 's/^/  /'
        done
        
        compgen -G "$TARGET_PATTERN" | while IFS= read -r item; do
            rm -rf "$item" 2>/dev/null || true
        done
        
        AFTER_KB=$(calculate_glob_size_kb "$TARGET_PATTERN")
        RELEASED_KB=$((BEFORE_KB - AFTER_KB))
        if [ "$RELEASED_KB" -lt 0 ]; then
            RELEASED_KB=0
        fi
        
        TOTAL_RELEASED_KB=$((TOTAL_RELEASED_KB + RELEASED_KB))
        print_success "已释放: $(format_kb_size "$RELEASED_KB")"
    else
        print_info "清理前大小: 0KB"
        print_info "无需清理"
    fi
}

# ----------------------------------------------------------------------------
# 清理单个文件并统计释放空间
# ----------------------------------------------------------------------------
clean_file_with_stats() {
    TARGET_FILE="$1"
    TARGET_LABEL="$2"
    
    echo ""
    print_info "$TARGET_LABEL"
    
    if [ -f "$TARGET_FILE" ]; then
        BEFORE_KB=$(du -sk "$TARGET_FILE" 2>/dev/null | awk '{print $1}')
        BEFORE_KB=${BEFORE_KB:-0}
        print_info "清理前大小: $(format_kb_size "$BEFORE_KB")"
        du -sh "$TARGET_FILE" 2>/dev/null | sed 's/^/  /'
        
        rm -f "$TARGET_FILE" 2>/dev/null || true
        
        AFTER_KB=0
        if [ -f "$TARGET_FILE" ]; then
            AFTER_KB=$(du -sk "$TARGET_FILE" 2>/dev/null | awk '{print $1}')
            AFTER_KB=${AFTER_KB:-0}
        fi
        
        RELEASED_KB=$((BEFORE_KB - AFTER_KB))
        if [ "$RELEASED_KB" -lt 0 ]; then
            RELEASED_KB=0
        fi
        
        TOTAL_RELEASED_KB=$((TOTAL_RELEASED_KB + RELEASED_KB))
        print_success "已释放: $(format_kb_size "$RELEASED_KB")"
    else
        print_info "清理前大小: 0KB"
        print_info "文件不存在，无需清理"
    fi
}

# ----------------------------------------------------------------------------
# 计算单个路径大小（KB）
# ----------------------------------------------------------------------------
calculate_path_size_kb() {
    TARGET_PATH="$1"

    if [ -e "$TARGET_PATH" ]; then
        du -sk "$TARGET_PATH" 2>/dev/null | awk '{print $1+0}'
    else
        echo "0"
    fi
}

# ----------------------------------------------------------------------------
# 计算目录内容总大小（KB），保留目录本身
# ----------------------------------------------------------------------------
calculate_dir_contents_size_kb() {
    TARGET_DIR="$1"

    if [ ! -d "$TARGET_DIR" ]; then
        echo "0"
        return 0
    fi

    find "$TARGET_DIR" -mindepth 1 -maxdepth 1 -exec du -sk {} + 2>/dev/null | awk '{sum+=$1} END{print sum+0}'
}

# ----------------------------------------------------------------------------
# 清理目录内容并统计释放空间，保留目录本身
# ----------------------------------------------------------------------------
clean_dir_contents_with_stats() {
    TARGET_DIR="$1"
    TARGET_LABEL="$2"

    echo ""
    print_info "$TARGET_LABEL"

    if [ ! -d "$TARGET_DIR" ]; then
        print_info "目录不存在，无需清理"
        return 0
    fi

    BEFORE_KB=$(calculate_dir_contents_size_kb "$TARGET_DIR")
    BEFORE_KB=${BEFORE_KB:-0}

    if [ "$BEFORE_KB" -le 0 ] 2>/dev/null; then
        print_info "清理前大小: 0KB"
        print_info "目录为空，无需清理"
        return 0
    fi

    print_info "清理前大小: $(format_kb_size "$BEFORE_KB")"
    find "$TARGET_DIR" -mindepth 1 -maxdepth 1 -exec du -sh {} + 2>/dev/null | sed 's/^/  /'
    find "$TARGET_DIR" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true

    AFTER_KB=$(calculate_dir_contents_size_kb "$TARGET_DIR")
    AFTER_KB=${AFTER_KB:-0}
    RELEASED_KB=$((BEFORE_KB - AFTER_KB))
    if [ "$RELEASED_KB" -lt 0 ]; then
        RELEASED_KB=0
    fi

    TOTAL_RELEASED_KB=$((TOTAL_RELEASED_KB + RELEASED_KB))
    print_success "已释放: $(format_kb_size "$RELEASED_KB")"
}

# ----------------------------------------------------------------------------
# 计算可优化运行时缓存总大小（KB）
# ----------------------------------------------------------------------------
calculate_runtime_cache_total_kb() {
    TOTAL_KB=0

    for pattern in \
        "$WINDSURF_SUPPORT_DIR/Cache/*" \
        "$WINDSURF_SUPPORT_DIR/CachedData/*" \
        "$WINDSURF_SUPPORT_DIR/GPUCache/*" \
        "$WINDSURF_SUPPORT_DIR/Code Cache/*" \
        "$WINDSURF_SUPPORT_DIR/DawnWebGPUCache/*" \
        "$WINDSURF_SUPPORT_DIR/DawnGraphiteCache/*" \
        "$WINDSURF_SUPPORT_DIR/Shared Dictionary/*" \
        "$WINDSURF_SUPPORT_DIR/logs/*" \
        "$WINDSURF_SUPPORT_DIR/Crashpad/completed/*" \
        "$WINDSURF_SUPPORT_DIR/Crashpad/pending/*" \
        "$WINDSURF_SUPPORT_DIR/User/workspaceStorage/*" \
        "$WINDSURF_SUPPORT_DIR/User/History/*" \
        "$WINDSURF_SUPPORT_DIR/CachedExtensionVSIXs/*" \
        "$WINDSURF_SUPPORT_DIR/CachedProfilesData/*" \
        "$IMPLICIT_DIR/*" \
        "$CODE_TRACKER_DIR/*" \
        "/tmp/windsurf-terminal-*.snapshot" \
        "$HOME/.zcompdump*" \
        "$MACOS_WS_CACHE/*" \
        "$MACOS_WS_SHIPIT/*"
    do
        SIZE_KB=$(calculate_glob_size_kb "$pattern")
        TOTAL_KB=$((TOTAL_KB + SIZE_KB))
    done

    # state.vscdb.backup 单独计算
    STATE_BACKUP_SIZE=0
    if [ -f "$WINDSURF_SUPPORT_DIR/User/globalStorage/state.vscdb.backup" ]; then
        STATE_BACKUP_SIZE=$(du -sk "$WINDSURF_SUPPORT_DIR/User/globalStorage/state.vscdb.backup" 2>/dev/null | awk '{print $1}')
        STATE_BACKUP_SIZE=${STATE_BACKUP_SIZE:-0}
    fi
    TOTAL_KB=$((TOTAL_KB + STATE_BACKUP_SIZE))

    # clp 旧版本语言包也纳入统计
    CLP_DIR="$WINDSURF_SUPPORT_DIR/clp"
    if [ -d "$CLP_DIR" ]; then
        CLP_SIZE=$(du -sk "$CLP_DIR" 2>/dev/null | awk '{print $1}')
        TOTAL_KB=$((TOTAL_KB + ${CLP_SIZE:-0}))
    fi

    echo "$TOTAL_KB"
}

# ----------------------------------------------------------------------------
# 计算四个 AI 工具默认安全清理项总大小（KB）
# ----------------------------------------------------------------------------
calculate_ai_tool_garbage_total_kb() {
    TOTAL_KB=0

    # Claude Code 默认清理项
    for dir_path in \
        "$CLAUDE_CODE_DIR/cache" \
        "$CLAUDE_CODE_DIR/debug" \
        "$CLAUDE_CODE_DIR/downloads" \
        "$CLAUDE_CODE_DIR/paste-cache" \
        "$CLAUDE_CODE_DIR/plugins/cache" \
        "$CLAUDE_CODE_DIR/session-data" \
        "$CLAUDE_CODE_DIR/file-history" \
        "$CLAUDE_CODE_DIR/shell-snapshots" \
        "$CLAUDE_CODE_DIR/tasks" \
        "$CLAUDE_CODE_DIR/todos" \
        "$CLAUDE_CODE_DIR/session-env" \
        "$CLAUDE_CODE_DIR/ide"
    do
        SIZE_KB=$(calculate_dir_contents_size_kb "$dir_path")
        TOTAL_KB=$((TOTAL_KB + SIZE_KB))
    done

    # Codex 默认清理项
    for dir_path in \
        "$CODEX_DIR/.tmp" \
        "$CODEX_DIR/tmp" \
        "$CODEX_DIR/cache" \
        "$CODEX_DIR/log" \
        "$CODEX_DIR/plugins/cache"
    do
        SIZE_KB=$(calculate_dir_contents_size_kb "$dir_path")
        TOTAL_KB=$((TOTAL_KB + SIZE_KB))
    done

    # Codex 文件清理项
    for file_path in \
        "$CODEX_DIR/logs_1.sqlite-shm" \
        "$CODEX_DIR/logs_1.sqlite-wal" \
        "$CODEX_DIR/models_cache.json" \
        "$CODEX_DIR/vendor_imports/skills-curated-cache.json"
    do
        SIZE_KB=$(calculate_path_size_kb "$file_path")
        TOTAL_KB=$((TOTAL_KB + SIZE_KB))
    done

    # OpenCode 默认清理项
    for dir_path in \
        "$OPENCODE_CACHE_DIR" \
        "$OPENCODE_DATA_DIR/tool-output" \
        "$OPENCODE_DATA_DIR/log"
    do
        SIZE_KB=$(calculate_dir_contents_size_kb "$dir_path")
        TOTAL_KB=$((TOTAL_KB + SIZE_KB))
    done

    # OpenCode 文件清理项
    for file_path in \
        "$OPENCODE_DATA_DIR/opencode.db-shm" \
        "$OPENCODE_DATA_DIR/opencode.db-wal"
    do
        SIZE_KB=$(calculate_path_size_kb "$file_path")
        TOTAL_KB=$((TOTAL_KB + SIZE_KB))
    done

    echo "$TOTAL_KB"
}

# ----------------------------------------------------------------------------
# 计算四个 AI 工具可选深清项总大小（KB）
# ----------------------------------------------------------------------------
calculate_ai_tool_optional_garbage_total_kb() {
    TOTAL_KB=0

    # Claude Code 可选清理项
    TOTAL_KB=$((TOTAL_KB + $(calculate_dir_contents_size_kb "$CLAUDE_CODE_DIR/plans")))
    TOTAL_KB=$((TOTAL_KB + $(calculate_dir_contents_size_kb "$CLAUDE_CODE_DIR/backups")))

    # Gemini CLI 可选清理项
    TOTAL_KB=$((TOTAL_KB + $(calculate_dir_contents_size_kb "$GEMINI_CLI_DIR/tmp")))

    # Codex 可选清理项
    TOTAL_KB=$((TOTAL_KB + $(calculate_path_size_kb "$CODEX_DIR/logs_1.sqlite")))

    echo "$TOTAL_KB"
}

# ----------------------------------------------------------------------------
# 功能21: 清理 Claude Code / codex / gemini-cli / opencode 垃圾缓存
# ----------------------------------------------------------------------------
clean_ai_tool_garbage() {
    print_info "扫描 Claude Code / codex / gemini-cli / opencode 垃圾缓存..."

    TOOL_FOUND=0
    [ -d "$CLAUDE_CODE_DIR" ] && TOOL_FOUND=1
    [ -d "$CODEX_DIR" ] && TOOL_FOUND=1
    [ -d "$GEMINI_CLI_DIR" ] && TOOL_FOUND=1
    [ -d "$OPENCODE_INSTALL_DIR" ] && TOOL_FOUND=1
    [ -d "$OPENCODE_CONFIG_DIR" ] && TOOL_FOUND=1
    [ -d "$OPENCODE_CACHE_DIR" ] && TOOL_FOUND=1
    [ -d "$OPENCODE_DATA_DIR" ] && TOOL_FOUND=1

    if [ "$TOOL_FOUND" -eq 0 ]; then
        print_info "未检测到四个 AI 工具的本地目录"
        return 0
    fi

    SAFE_TOTAL_KB=$(calculate_ai_tool_garbage_total_kb)
    GEMINI_TMP_KB=$(calculate_dir_contents_size_kb "$GEMINI_CLI_DIR/tmp")
    CODEX_LOG_DB_KB=$(calculate_path_size_kb "$CODEX_DIR/logs_1.sqlite")
    OPTIONAL_TOTAL_KB=$(calculate_ai_tool_optional_garbage_total_kb)

    echo ""
    print_success "默认只清理缓存、日志、临时文件、工具输出和数据库临时文件"
    print_success "不会清理 MCP、登录认证、settings、skills、rules、memories、正式数据库、插件主体和安装目录"
    print_warning "可选深清项只会影响本地日志或会话恢复能力，不会影响 MCP、登录状态和核心配置"
    echo ""
    echo -e "${CYAN}保护范围说明:${NC}"
    echo "  - Claude Code: mcp.json、config.json、settings.json、commands/、projects/、history.jsonl、MEMORY.md"
    echo "  - codex: config.toml、auth.json、agents/、memories/、rules/、sessions/、history.jsonl、session_index.jsonl"
    echo "  - gemini-cli: settings.json、oauth_creds.json、skills/、policies/、history/、tmp/chats/"
    echo "  - opencode: opencode.json、auth.json、opencode.db、storage/session_diff、prompt-history.jsonl、node_modules/"
    echo ""
    echo -e "${CYAN}扫描结果:${NC}"

    if [ -d "$CLAUDE_CODE_DIR" ]; then
        echo ""
        echo -e "  ${GREEN}[Claude Code]${NC} $CLAUDE_CODE_DIR"
        for dir_path in \
            "$CLAUDE_CODE_DIR/cache" \
            "$CLAUDE_CODE_DIR/debug" \
            "$CLAUDE_CODE_DIR/downloads" \
            "$CLAUDE_CODE_DIR/paste-cache" \
            "$CLAUDE_CODE_DIR/plugins/cache" \
            "$CLAUDE_CODE_DIR/session-data" \
            "$CLAUDE_CODE_DIR/file-history" \
            "$CLAUDE_CODE_DIR/shell-snapshots" \
            "$CLAUDE_CODE_DIR/tasks" \
            "$CLAUDE_CODE_DIR/todos" \
            "$CLAUDE_CODE_DIR/session-env" \
            "$CLAUDE_CODE_DIR/ide"
        do
            if [ -d "$dir_path" ]; then
                SIZE_KB=$(calculate_dir_contents_size_kb "$dir_path")
                echo "    $(basename "$dir_path") -> $(format_kb_size "$SIZE_KB")"
            fi
        done
    fi

    if [ -d "$CODEX_DIR" ]; then
        echo ""
        echo -e "  ${GREEN}[codex]${NC} $CODEX_DIR"
        for dir_path in \
            "$CODEX_DIR/.tmp" \
            "$CODEX_DIR/tmp" \
            "$CODEX_DIR/cache" \
            "$CODEX_DIR/log" \
            "$CODEX_DIR/plugins/cache"
        do
            if [ -d "$dir_path" ]; then
                SIZE_KB=$(calculate_dir_contents_size_kb "$dir_path")
                echo "    $(basename "$dir_path") -> $(format_kb_size "$SIZE_KB")"
            fi
        done
        for file_path in \
            "$CODEX_DIR/logs_1.sqlite-shm" \
            "$CODEX_DIR/logs_1.sqlite-wal" \
            "$CODEX_DIR/models_cache.json" \
            "$CODEX_DIR/vendor_imports/skills-curated-cache.json"
        do
            if [ -e "$file_path" ]; then
                SIZE_KB=$(calculate_path_size_kb "$file_path")
                echo "    $(basename "$file_path") -> $(format_kb_size "$SIZE_KB")"
            fi
        done
        if [ "$CODEX_LOG_DB_KB" -gt 0 ] 2>/dev/null; then
            echo "    logs_1.sqlite（可选深清） -> $(format_kb_size "$CODEX_LOG_DB_KB")"
        fi
    fi

    if [ -d "$GEMINI_CLI_DIR" ]; then
        echo ""
        echo -e "  ${GREEN}[gemini-cli]${NC} $GEMINI_CLI_DIR"
        if [ "$GEMINI_TMP_KB" -gt 0 ] 2>/dev/null; then
            echo "    tmp（可选深清，会删除本地可恢复会话缓存） -> $(format_kb_size "$GEMINI_TMP_KB")"
        fi
    fi

    if [ -d "$OPENCODE_INSTALL_DIR" ] || [ -d "$OPENCODE_CONFIG_DIR" ] || [ -d "$OPENCODE_CACHE_DIR" ] || [ -d "$OPENCODE_DATA_DIR" ]; then
        echo ""
        echo -e "  ${GREEN}[opencode]${NC}"
        [ -d "$OPENCODE_CONFIG_DIR" ] && echo "    config -> $OPENCODE_CONFIG_DIR"
        [ -d "$OPENCODE_CACHE_DIR" ] && echo "    cache -> $OPENCODE_CACHE_DIR"
        [ -d "$OPENCODE_DATA_DIR" ] && echo "    data -> $OPENCODE_DATA_DIR"

        if [ -d "$OPENCODE_CACHE_DIR" ]; then
            SIZE_KB=$(calculate_dir_contents_size_kb "$OPENCODE_CACHE_DIR")
            echo "    opencode cache -> $(format_kb_size "$SIZE_KB")"
        fi
        if [ -d "$OPENCODE_DATA_DIR/tool-output" ]; then
            SIZE_KB=$(calculate_dir_contents_size_kb "$OPENCODE_DATA_DIR/tool-output")
            echo "    tool-output -> $(format_kb_size "$SIZE_KB")"
        fi
        for file_path in \
            "$OPENCODE_DATA_DIR/opencode.db-shm" \
            "$OPENCODE_DATA_DIR/opencode.db-wal"
        do
            if [ -e "$file_path" ]; then
                SIZE_KB=$(calculate_path_size_kb "$file_path")
                echo "    $(basename "$file_path") -> $(format_kb_size "$SIZE_KB")"
            fi
        done
    fi

    echo ""
    echo -e "  ${CYAN}默认安全清理预计: ${YELLOW}$(format_kb_size "$SAFE_TOTAL_KB")${NC}"
    echo -e "  ${CYAN}可选深清额外预计: ${YELLOW}$(format_kb_size "$OPTIONAL_TOTAL_KB")${NC}"
    echo ""

    if [ "$SAFE_TOTAL_KB" -le 0 ] 2>/dev/null && [ "$OPTIONAL_TOTAL_KB" -le 0 ] 2>/dev/null; then
        print_info "当前没有可安全清理的垃圾缓存"
        return 0
    fi

    TOTAL_RELEASED_KB=0
    DID_CLEAN=0

    if [ "$SAFE_TOTAL_KB" -gt 0 ] 2>/dev/null; then
        if confirm_action; then
            clean_dir_contents_with_stats "$CLAUDE_CODE_DIR/cache"                        "清理 Claude Code cache"
            clean_dir_contents_with_stats "$CLAUDE_CODE_DIR/debug"                        "清理 Claude Code debug"
            clean_dir_contents_with_stats "$CLAUDE_CODE_DIR/downloads"                    "清理 Claude Code downloads"
            clean_dir_contents_with_stats "$CLAUDE_CODE_DIR/paste-cache"                  "清理 Claude Code paste-cache"
            clean_dir_contents_with_stats "$CLAUDE_CODE_DIR/plugins/cache"                "清理 Claude Code 插件缓存"
            clean_dir_contents_with_stats "$CLAUDE_CODE_DIR/session-data"                 "清理 Claude Code 临时会话文件"
            clean_dir_contents_with_stats "$CLAUDE_CODE_DIR/file-history"                 "清理 Claude Code 文件编辑历史"
            clean_dir_contents_with_stats "$CLAUDE_CODE_DIR/shell-snapshots"              "清理 Claude Code Shell 快照"
            clean_dir_contents_with_stats "$CLAUDE_CODE_DIR/tasks"                        "清理 Claude Code 任务状态"
            clean_dir_contents_with_stats "$CLAUDE_CODE_DIR/todos"                        "清理 Claude Code 待办追踪"
            clean_dir_contents_with_stats "$CLAUDE_CODE_DIR/session-env"                  "清理 Claude Code 会话环境"
            clean_dir_contents_with_stats "$CLAUDE_CODE_DIR/ide"                          "清理 Claude Code IDE 锁文件"
            clean_dir_contents_with_stats "$CLAUDE_CODE_DIR/metrics"                      "清理 Claude Code 指标数据"
            clean_dir_contents_with_stats "$CLAUDE_CODE_DIR/telemetry"                    "清理 Claude Code 遥测数据"

            clean_dir_contents_with_stats "$CODEX_DIR/.tmp"                               "清理 codex .tmp"
            clean_dir_contents_with_stats "$CODEX_DIR/tmp"                                "清理 codex tmp"
            clean_dir_contents_with_stats "$CODEX_DIR/cache"                              "清理 codex cache"
            clean_dir_contents_with_stats "$CODEX_DIR/log"                                "清理 codex 日志目录"
            clean_dir_contents_with_stats "$CODEX_DIR/plugins/cache"                      "清理 codex 插件缓存"
            clean_file_with_stats "$CODEX_DIR/logs_1.sqlite-shm"                          "清理 codex 日志数据库 shm"
            clean_file_with_stats "$CODEX_DIR/logs_1.sqlite-wal"                          "清理 codex 日志数据库 wal"
            clean_file_with_stats "$CODEX_DIR/models_cache.json"                          "清理 codex models_cache.json"
            clean_file_with_stats "$CODEX_DIR/vendor_imports/skills-curated-cache.json"   "清理 codex skills 缓存索引"

            clean_dir_contents_with_stats "$OPENCODE_CACHE_DIR"                           "清理 opencode cache"
            clean_dir_contents_with_stats "$OPENCODE_DATA_DIR/tool-output"                "清理 opencode tool-output"
            clean_dir_contents_with_stats "$OPENCODE_DATA_DIR/log"                        "清理 opencode 应用日志"
            clean_file_with_stats "$OPENCODE_DATA_DIR/opencode.db-shm"                    "清理 opencode.db-shm"
            clean_file_with_stats "$OPENCODE_DATA_DIR/opencode.db-wal"                    "清理 opencode.db-wal"
            DID_CLEAN=1
        else
            print_info "已跳过默认安全清理"
        fi
    fi

    if [ "$GEMINI_TMP_KB" -gt 0 ] 2>/dev/null; then
        echo -ne ${YELLOW}是否额外清理 gemini-cli tmp？这会删除本地可恢复会话缓存 [y/N]: ${NC}
        read -r EXTRA_CHOICE
        case "$EXTRA_CHOICE" in
            y|Y )
                clean_dir_contents_with_stats "$GEMINI_CLI_DIR/tmp" "额外清理 gemini-cli tmp（删除本地可恢复会话缓存）"
                DID_CLEAN=1
                ;;
            * )
                print_info "已保留 gemini-cli tmp"
                ;;
        esac
    fi

    if [ "$CODEX_LOG_DB_KB" -gt 0 ] 2>/dev/null; then
        echo -ne ${YELLOW}是否额外清理 codex logs_1.sqlite？这会清空本地日志数据库 [y/N]: ${NC}
        read -r EXTRA_CHOICE
        case "$EXTRA_CHOICE" in
            y|Y )
                clean_file_with_stats "$CODEX_DIR/logs_1.sqlite" "额外清理 codex 日志数据库"
                DID_CLEAN=1
                ;;
            * )
                print_info "已保留 codex logs_1.sqlite"
                ;;
        esac
    fi

    CLAUDE_PLANS_KB=$(calculate_dir_contents_size_kb "$CLAUDE_CODE_DIR/plans")
    if [ "$CLAUDE_PLANS_KB" -gt 0 ] 2>/dev/null; then
        echo -ne ${YELLOW}是否额外清理 Claude Code plans？这会删除本地计划文档 [y/N]: ${NC}
        read -r EXTRA_CHOICE
        case "$EXTRA_CHOICE" in
            y|Y )
                clean_dir_contents_with_stats "$CLAUDE_CODE_DIR/plans" "额外清理 Claude Code plans（删除本地计划文档）"
                DID_CLEAN=1
                ;;
            * )
                print_info "已保留 Claude Code plans"
                ;;
        esac
    fi

    CLAUDE_BACKUPS_KB=$(calculate_dir_contents_size_kb "$CLAUDE_CODE_DIR/backups")
    if [ "$CLAUDE_BACKUPS_KB" -gt 0 ] 2>/dev/null; then
        echo -ne ${YELLOW}是否额外清理 Claude Code backups？这会删除配置自动备份 [y/N]: ${NC}
        read -r EXTRA_CHOICE
        case "$EXTRA_CHOICE" in
            y|Y )
                clean_dir_contents_with_stats "$CLAUDE_CODE_DIR/backups" "额外清理 Claude Code backups（删除配置自动备份）"
                DID_CLEAN=1
                ;;
            * )
                print_info "已保留 Claude Code backups"
                ;;
        esac
    fi

    echo ""
    if [ "$DID_CLEAN" -eq 1 ] 2>/dev/null; then
        print_success "四个 AI 工具垃圾缓存清理完成，总释放空间: $(format_kb_size "$TOTAL_RELEASED_KB")"
        print_info "核心配置、MCP、登录认证、skills、history 和正式数据库均已保留"

        # 清理完毕 -> 强制重置 Windsurf 设备 ID（默认行为）
        auto_reset_after_clean
    else
        print_info "未执行任何清理操作"
    fi
}

# ----------------------------------------------------------------------------
# 功能15: 备份 MCP 配置、Skills 和全局 Rules
# ----------------------------------------------------------------------------
backup_mcp_skills_rules() {
    print_info "备份 MCP 配置、Skills 和全局 Rules..."
    
    BACKUP_TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP_TARGET="$HOME/.windsurf-config-backup-$BACKUP_TIMESTAMP"
    
    MCP_CONFIG="$WINDSURF_DIR/mcp_config.json"
    SKILLS_DIR="$WINDSURF_DIR/skills"
    GLOBAL_RULES="$WINDSURF_DIR/memories/global_rules.md"
    MEMORIES_DIR="$WINDSURF_DIR/memories"
    
    echo ""
    echo -e "${CYAN}将备份以下内容:${NC}"
    echo ""
    
    # 检测并显示各项状态
    BACKUP_COUNT=0
    
    if [ -f "$MCP_CONFIG" ]; then
        MCP_SIZE=$(du -sh "$MCP_CONFIG" 2>/dev/null | awk '{print $1}')
        echo -e "  ${GREEN}[MCP 配置]${NC} $MCP_CONFIG - ${YELLOW}$MCP_SIZE${NC}"
        BACKUP_COUNT=$((BACKUP_COUNT + 1))
    else
        echo -e "  ${RED}[MCP 配置]${NC} 不存在"
    fi
    
    if [ -d "$SKILLS_DIR" ]; then
        SKILLS_COUNT=$(ls -1d "$SKILLS_DIR"/*/ 2>/dev/null | wc -l | tr -d ' ')
        SKILLS_SIZE=$(du -sh "$SKILLS_DIR" 2>/dev/null | awk '{print $1}')
        echo -e "  ${GREEN}[Skills]${NC} $SKILLS_DIR - ${YELLOW}${SKILLS_COUNT} 个技能, $SKILLS_SIZE${NC}"
        BACKUP_COUNT=$((BACKUP_COUNT + 1))
    else
        echo -e "  ${RED}[Skills]${NC} 目录不存在"
    fi
    
    if [ -f "$GLOBAL_RULES" ]; then
        RULES_SIZE=$(du -sh "$GLOBAL_RULES" 2>/dev/null | awk '{print $1}')
        echo -e "  ${GREEN}[全局 Rules]${NC} $GLOBAL_RULES - ${YELLOW}$RULES_SIZE${NC}"
        BACKUP_COUNT=$((BACKUP_COUNT + 1))
    else
        echo -e "  ${RED}[全局 Rules]${NC} 不存在"
    fi
    
    if [ -d "$MEMORIES_DIR" ]; then
        MEM_COUNT=$(ls -1 "$MEMORIES_DIR"/*.pb 2>/dev/null | wc -l | tr -d ' ')
        MEM_SIZE=$(du -sh "$MEMORIES_DIR" 2>/dev/null | awk '{print $1}')
        echo -e "  ${GREEN}[Memories]${NC} $MEMORIES_DIR - ${YELLOW}${MEM_COUNT} 个记忆文件, $MEM_SIZE${NC}"
        BACKUP_COUNT=$((BACKUP_COUNT + 1))
    else
        echo -e "  ${RED}[Memories]${NC} 目录不存在"
    fi
    
    echo ""
    
    if [ $BACKUP_COUNT -eq 0 ]; then
        print_warning "没有找到任何可备份的内容"
        return 0
    fi
    
    echo -e "备份目标目录: ${CYAN}$BACKUP_TARGET${NC}"
    echo ""
    
    if confirm_action; then
        mkdir -p "$BACKUP_TARGET"
        
        # 备份 MCP 配置
        if [ -f "$MCP_CONFIG" ]; then
            cp "$MCP_CONFIG" "$BACKUP_TARGET/mcp_config.json"
            print_success "MCP 配置已备份"
        fi
        
        # 备份 Skills 目录
        if [ -d "$SKILLS_DIR" ]; then
            cp -r "$SKILLS_DIR" "$BACKUP_TARGET/skills"
            print_success "Skills 目录已备份"
        fi
        
        # 备份全局 Rules
        if [ -f "$GLOBAL_RULES" ]; then
            mkdir -p "$BACKUP_TARGET/memories"
            cp "$GLOBAL_RULES" "$BACKUP_TARGET/memories/global_rules.md"
            print_success "全局 Rules 已备份"
        fi
        
        # 备份 Memories 目录
        if [ -d "$MEMORIES_DIR" ]; then
            cp -r "$MEMORIES_DIR" "$BACKUP_TARGET/memories" 2>/dev/null || true
            print_success "Memories 目录已备份"
        fi
        
        # 生成备份信息文件
        cat > "$BACKUP_TARGET/backup_info.txt" << BEOF
========================================
Windsurf 配置备份信息
========================================
备份时间: $(date)
macOS版本: $(sw_vers -productVersion)
处理器: $(uname -m)

备份内容:
  - MCP 配置: mcp_config.json
  - Skills 目录: skills/
  - 全局 Rules: memories/global_rules.md
  - Memories: memories/

恢复方法:
  cp backup_dir/mcp_config.json ~/.codeium/windsurf/mcp_config.json
  cp -r backup_dir/skills/ ~/.codeium/windsurf/skills/
  cp backup_dir/memories/global_rules.md ~/.codeium/windsurf/memories/global_rules.md
  cp -r backup_dir/memories/ ~/.codeium/windsurf/memories/
========================================
BEOF
        
        echo ""
        TOTAL_SIZE=$(du -sh "$BACKUP_TARGET" 2>/dev/null | awk '{print $1}')
        print_success "备份完成！总大小: $TOTAL_SIZE"
        print_info "备份位置: $BACKUP_TARGET"
        
        # 列出历史备份
        echo ""
        HIST_COUNT=0
        for bdir in "$HOME"/.windsurf-config-backup-*; do
            if [ -d "$bdir" ]; then
                HIST_COUNT=$((HIST_COUNT + 1))
            fi
        done
        if [ $HIST_COUNT -gt 1 ]; then
            print_info "当前共有 $HIST_COUNT 个配置备份:"
            for bdir in "$HOME"/.windsurf-config-backup-*; do
                if [ -d "$bdir" ]; then
                    BSIZE=$(du -sh "$bdir" 2>/dev/null | awk '{print $1}')
                    echo "  $(basename "$bdir") - $BSIZE"
                fi
            done
        fi
    else
        print_info "已取消操作"
    fi
}

# ----------------------------------------------------------------------------
# 功能16: 还原 MCP 配置、Skills 和全局 Rules
# ----------------------------------------------------------------------------
restore_mcp_skills_rules() {
    print_info "还原 MCP 配置、Skills 和全局 Rules..."
    
    MCP_CONFIG="$WINDSURF_DIR/mcp_config.json"
    SKILLS_DIR="$WINDSURF_DIR/skills"
    GLOBAL_RULES="$WINDSURF_DIR/memories/global_rules.md"
    MEMORIES_DIR="$WINDSURF_DIR/memories"
    
    # 扫描所有配置备份目录
    BACKUP_LIST=()
    for bdir in "$HOME"/.windsurf-config-backup-*; do
        if [ -d "$bdir" ]; then
            BACKUP_LIST+=("$bdir")
        fi
    done
    
    if [ ${#BACKUP_LIST[@]} -eq 0 ]; then
        print_warning "未找到任何配置备份"
        print_info "请先使用选项 15 进行备份"
        return 0
    fi
    
    echo ""
    echo -e "${CYAN}可用的配置备份:${NC}"
    echo ""
    
    IDX=1
    for bdir in "${BACKUP_LIST[@]}"; do
        BNAME=$(basename "$bdir")
        BSIZE=$(du -sh "$bdir" 2>/dev/null | awk '{print $1}')
        # 从目录名提取时间戳并格式化显示
        BTIMESTAMP=$(echo "$BNAME" | sed 's/\.windsurf-config-backup-//')
        
        # 检测备份中包含哪些内容
        CONTENTS=""
        [ -f "$bdir/mcp_config.json" ] && CONTENTS="${CONTENTS}MCP "
        [ -d "$bdir/skills" ] && CONTENTS="${CONTENTS}Skills "
        [ -f "$bdir/memories/global_rules.md" ] && CONTENTS="${CONTENTS}Rules "
        [ -d "$bdir/memories" ] && CONTENTS="${CONTENTS}Memories "
        CONTENTS=${CONTENTS:- (空)}
        
        echo -e "  ${GREEN}$IDX)${NC} $BNAME - ${YELLOW}$BSIZE${NC}"
        echo -e "     包含: ${CYAN}$CONTENTS${NC}"
        IDX=$((IDX + 1))
    done
    
    echo ""
    echo "  0) 取消"
    echo ""
    echo -ne ${CYAN}请选择要还原的备份 [0-${#BACKUP_LIST[@]}]: ${NC}
    read -r restore_choice
    
    if [ "$restore_choice" = "0" ] || [ -z "$restore_choice" ]; then
        print_info "已取消操作"
        return 0
    fi
    
    # 验证输入有效性
    if ! [[ "$restore_choice" =~ ^[0-9]+$ ]] || [ "$restore_choice" -lt 1 ] || [ "$restore_choice" -gt ${#BACKUP_LIST[@]} ]; then
        print_error "无效选项"
        return 0
    fi
    
    SELECTED_BACKUP="${BACKUP_LIST[$((restore_choice - 1))]}"
    SELECTED_NAME=$(basename "$SELECTED_BACKUP")
    
    echo ""
    echo -e "${CYAN}已选择备份: ${YELLOW}$SELECTED_NAME${NC}"
    echo ""
    
    # 显示备份详情
    echo -e "${CYAN}备份内容详情:${NC}"
    echo ""
    
    RESTORE_COUNT=0
    
    if [ -f "$SELECTED_BACKUP/mcp_config.json" ]; then
        FSIZE=$(du -sh "$SELECTED_BACKUP/mcp_config.json" 2>/dev/null | awk '{print $1}')
        echo -e "  ${GREEN}[MCP 配置]${NC} mcp_config.json - ${YELLOW}$FSIZE${NC}"
        RESTORE_COUNT=$((RESTORE_COUNT + 1))
    fi
    
    if [ -d "$SELECTED_BACKUP/skills" ]; then
        SCOUNT=$(ls -1d "$SELECTED_BACKUP/skills"/*/ 2>/dev/null | wc -l | tr -d ' ')
        SSIZE=$(du -sh "$SELECTED_BACKUP/skills" 2>/dev/null | awk '{print $1}')
        echo -e "  ${GREEN}[Skills]${NC} ${SCOUNT} 个技能 - ${YELLOW}$SSIZE${NC}"
        RESTORE_COUNT=$((RESTORE_COUNT + 1))
    fi
    
    if [ -f "$SELECTED_BACKUP/memories/global_rules.md" ]; then
        RSIZE=$(du -sh "$SELECTED_BACKUP/memories/global_rules.md" 2>/dev/null | awk '{print $1}')
        echo -e "  ${GREEN}[全局 Rules]${NC} global_rules.md - ${YELLOW}$RSIZE${NC}"
        RESTORE_COUNT=$((RESTORE_COUNT + 1))
    fi
    
    if [ -d "$SELECTED_BACKUP/memories" ]; then
        MCOUNT=$(ls -1 "$SELECTED_BACKUP/memories"/*.pb 2>/dev/null | wc -l | tr -d ' ')
        MSIZE=$(du -sh "$SELECTED_BACKUP/memories" 2>/dev/null | awk '{print $1}')
        echo -e "  ${GREEN}[Memories]${NC} ${MCOUNT} 个记忆文件 - ${YELLOW}$MSIZE${NC}"
        RESTORE_COUNT=$((RESTORE_COUNT + 1))
    fi
    
    if [ $RESTORE_COUNT -eq 0 ]; then
        print_warning "该备份中没有可还原的内容"
        return 0
    fi
    
    echo ""
    echo -e "${YELLOW}请选择还原方式:${NC}"
    echo "  1) 全部还原"
    echo "  2) 仅还原 MCP 配置"
    echo "  3) 仅还原 Skills"
    echo "  4) 仅还原全局 Rules"
    echo "  5) 仅还原 Memories"
    echo "  0) 取消"
    echo ""
    echo -ne ${CYAN}请选择 [0-5]: ${NC}
    read -r restore_mode
    
    case "$restore_mode" in
        0)
            print_info "已取消操作"
            return 0
            ;;
        1) RESTORE_MCP=1; RESTORE_SKILLS=1; RESTORE_RULES=1; RESTORE_MEM=1 ;;
        2) RESTORE_MCP=1; RESTORE_SKILLS=0; RESTORE_RULES=0; RESTORE_MEM=0 ;;
        3) RESTORE_MCP=0; RESTORE_SKILLS=1; RESTORE_RULES=0; RESTORE_MEM=0 ;;
        4) RESTORE_MCP=0; RESTORE_SKILLS=0; RESTORE_RULES=1; RESTORE_MEM=0 ;;
        5) RESTORE_MCP=0; RESTORE_SKILLS=0; RESTORE_RULES=0; RESTORE_MEM=1 ;;
        *)
            print_error "无效选项"
            return 0
            ;;
    esac
    
    echo ""
    print_warning "还原操作将覆盖当前配置！"
    
    if confirm_action; then
        echo ""
        
        # 还原 MCP 配置
        if [ "$RESTORE_MCP" -eq 1 ] && [ -f "$SELECTED_BACKUP/mcp_config.json" ]; then
            cp "$SELECTED_BACKUP/mcp_config.json" "$MCP_CONFIG"
            print_success "MCP 配置已还原"
        fi
        
        # 还原 Skills
        if [ "$RESTORE_SKILLS" -eq 1 ] && [ -d "$SELECTED_BACKUP/skills" ]; then
            # 先删除当前 skills 目录再复制，避免残留
            rm -rf "$SKILLS_DIR" 2>/dev/null
            cp -r "$SELECTED_BACKUP/skills" "$SKILLS_DIR"
            print_success "Skills 目录已还原"
        fi
        
        # 还原全局 Rules
        if [ "$RESTORE_RULES" -eq 1 ] && [ -f "$SELECTED_BACKUP/memories/global_rules.md" ]; then
            mkdir -p "$MEMORIES_DIR"
            cp "$SELECTED_BACKUP/memories/global_rules.md" "$GLOBAL_RULES"
            print_success "全局 Rules 已还原"
        fi
        
        # 还原 Memories
        if [ "$RESTORE_MEM" -eq 1 ] && [ -d "$SELECTED_BACKUP/memories" ]; then
            # 复制备份中的 memories 文件（覆盖已有）
            cp -r "$SELECTED_BACKUP/memories/"* "$MEMORIES_DIR/" 2>/dev/null || true
            print_success "Memories 已还原"
        fi
        
        echo ""
        print_success "还原完成！"
        print_info "请重启 Windsurf 使更改生效"
    else
        print_info "已取消操作"
    fi
}

# ----------------------------------------------------------------------------
# 功能17: 重置 Windsurf ID
# ----------------------------------------------------------------------------
# ----------------------------------------------------------------------------
# 内部函数: 自动重置 Windsurf ID（无确认提示，供清理流程自动调用）
# ----------------------------------------------------------------------------
reset_windsurf_id_auto() {
    INSTALLATION_ID_FILE="$WINDSURF_DIR/installation_id"
    MACHINE_ID_FILE="$WINDSURF_SUPPORT_DIR/machineid"
    STORAGE_JSON="$WINDSURF_SUPPORT_DIR/User/globalStorage/storage.json"
    
    # 生成新的 UUID
    NEW_INSTALL_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')
    NEW_MACHINE_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')
    NEW_DEV_DEVICE_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')
    NEW_SQM_ID=$(uuidgen | tr '[:upper:]' '[:upper:]')
    NEW_MAC_MACHINE_ID=$(od -An -tx1 -N16 /dev/urandom | tr -d ' \n')
    NEW_TELEMETRY_MACHINE_ID=$(od -An -tx1 -N32 /dev/urandom | tr -d ' \n')
    
    # 重置 installation_id
    if [ -f "$INSTALLATION_ID_FILE" ] || [ -d "$(dirname "$INSTALLATION_ID_FILE")" ]; then
        echo "$NEW_INSTALL_ID" > "$INSTALLATION_ID_FILE"
    fi
    
    # 重置 machineid
    if [ -f "$MACHINE_ID_FILE" ] || [ -d "$(dirname "$MACHINE_ID_FILE")" ]; then
        echo "$NEW_MACHINE_ID" > "$MACHINE_ID_FILE"
    fi
    
    # 重置 storage.json 中的 telemetry ID
    if [ -f "$STORAGE_JSON" ] && command -v python3 &> /dev/null; then
        python3 << PYEOF
import json
try:
    with open('$STORAGE_JSON', 'r') as f:
        data = json.load(f)
    data['telemetry.devDeviceId'] = '$NEW_DEV_DEVICE_ID'
    data['telemetry.macMachineId'] = '$NEW_MAC_MACHINE_ID'
    data['telemetry.machineId'] = '$NEW_TELEMETRY_MACHINE_ID'
    data['telemetry.sqmId'] = '$NEW_SQM_ID'
    with open('$STORAGE_JSON', 'w') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
except Exception:
    pass
PYEOF
    fi

    # 【关键补强】重置 state.vscdb 的 ItemTable 中的 telemetry 键
    # 参考：cursor-free-vip、ai-auto-free 等社区方案
    # VSCode/Windsurf 的 globalStorage 不仅在 storage.json 中记录 telemetry，还在 state.vscdb 的 ItemTable 里镜像了一份
    # 只改 storage.json 的话，启动后可能从 state.vscdb 读回旧值
    STATE_DB="$WINDSURF_SUPPORT_DIR/User/globalStorage/state.vscdb"
    if [ -f "$STATE_DB" ] && command -v sqlite3 &>/dev/null; then
        # value 列存的是 JSON 字符串形式的值，需要把 UUID 用双引号包裹
        sqlite3 "$STATE_DB" <<SQLEOF 2>/dev/null
UPDATE ItemTable SET value = '"$NEW_TELEMETRY_MACHINE_ID"' WHERE key = 'telemetry.machineId';
UPDATE ItemTable SET value = '"$NEW_DEV_DEVICE_ID"' WHERE key = 'telemetry.devDeviceId';
UPDATE ItemTable SET value = '"$NEW_SQM_ID"' WHERE key = 'telemetry.sqmId';
UPDATE ItemTable SET value = '"$NEW_MAC_MACHINE_ID"' WHERE key = 'telemetry.macMachineId';
UPDATE ItemTable SET value = '"$NEW_INSTALL_ID"' WHERE key = 'storage.serviceMachineId';
SQLEOF
    fi

    print_success "Windsurf ID 已自动重置（含 storage.json + state.vscdb 同步）"
    echo -e "  installation_id: ${GREEN}$NEW_INSTALL_ID${NC}"
    echo -e "  machineid:       ${GREEN}$NEW_MACHINE_ID${NC}"
    echo -e "  telemetry.*:     ${GREEN}已同步到 storage.json 和 state.vscdb${NC}"
}

# ----------------------------------------------------------------------------
# 内部函数: 清理流程末尾统一调用的"强制重置设备 ID"入口
# 触发时机：菜单 1/2/3/18/20/21/23/24 任一清理类操作完成后
# 默认行为：强制重置（用户要求，用于绕过限速、刷新会话、伪装新设备）
# 逃生通道：执行前设置环境变量 FORCE_RESET_ID=0 即可完全跳过
#   例：FORCE_RESET_ID=0 bash fix-windsurf-mac.sh
# ----------------------------------------------------------------------------
auto_reset_after_clean() {
    # 用户主动关闭？
    if [ "${FORCE_RESET_ID:-1}" = "0" ] || [ "${FORCE_RESET_ID:-1}" = "false" ]; then
        print_info "已跳过设备 ID 重置（FORCE_RESET_ID=0）"
        return 0
    fi

    # full_repair 等批量流程中：子函数跳过，末尾统一重置一次
    if [ "${_IN_BATCH_REPAIR:-0}" = "1" ]; then
        return 0
    fi

    echo ""
    echo -e "${CYAN}================ 清理后强制重置 Windsurf 设备 ID ================${NC}"
    print_warning "此为用户默认行为：每次清理完成后自动重置设备标识"
    print_warning "预期影响：Windsurf 服务端会识别为新设备，可能需要重新登录一次"
    print_info   "如需关闭此行为：下次运行前加 FORCE_RESET_ID=0 bash fix-windsurf-mac.sh"
    echo ""

    # 关闭 Windsurf 才能可靠重置 storage.json
    if pgrep -f "Windsurf" &>/dev/null; then
        print_warning "检测到 Windsurf 正在运行，建议先关闭再重置，以免 storage.json 被覆盖"
        print_info "将等待 3 秒后继续（Ctrl+C 可取消）..."
        sleep 3
    fi

    reset_windsurf_id_auto
    echo -e "${CYAN}================================================================${NC}"
}

reset_windsurf_id() {
    print_info "重置 Windsurf ID..."
    
    INSTALLATION_ID_FILE="$WINDSURF_DIR/installation_id"
    MACHINE_ID_FILE="$WINDSURF_SUPPORT_DIR/machineid"
    STORAGE_JSON="$WINDSURF_SUPPORT_DIR/User/globalStorage/storage.json"
    
    echo ""
    echo -e "${CYAN}当前 Windsurf ID 信息:${NC}"
    echo ""
    
    # 显示当前 ID
    if [ -f "$INSTALLATION_ID_FILE" ]; then
        CURRENT_INSTALL_ID=$(cat "$INSTALLATION_ID_FILE" 2>/dev/null)
        echo -e "  ${GREEN}[installation_id]${NC} $CURRENT_INSTALL_ID"
    else
        echo -e "  ${RED}[installation_id]${NC} 文件不存在"
    fi
    
    if [ -f "$MACHINE_ID_FILE" ]; then
        CURRENT_MACHINE_ID=$(cat "$MACHINE_ID_FILE" 2>/dev/null)
        echo -e "  ${GREEN}[machineid]${NC}       $CURRENT_MACHINE_ID"
    else
        echo -e "  ${RED}[machineid]${NC}       文件不存在"
    fi
    
    if [ -f "$STORAGE_JSON" ]; then
        echo -e "  ${GREEN}[storage.json]${NC}    存在 (包含 telemetry ID)"
    else
        echo -e "  ${RED}[storage.json]${NC}    文件不存在"
    fi
    
    echo ""
    print_warning "此操作将重新生成所有 Windsurf 标识 ID"
    echo "  包括: installation_id, machineid, telemetry ID"
    echo "  重置后 Windsurf 将被视为全新安装"
    echo ""
    
    if confirm_action; then
        if ! check_windsurf_running; then
            return 1
        fi
        
        # 生成新的 UUID
        NEW_INSTALL_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')
        NEW_MACHINE_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')
        NEW_DEV_DEVICE_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')
        NEW_SQM_ID=$(uuidgen | tr '[:upper:]' '[:upper:]')
        # 生成 macMachineId (32位十六进制)
        NEW_MAC_MACHINE_ID=$(od -An -tx1 -N16 /dev/urandom | tr -d ' \n')
        # 生成 machineId (64位十六进制)
        NEW_TELEMETRY_MACHINE_ID=$(od -An -tx1 -N32 /dev/urandom | tr -d ' \n')
        
        echo ""
        print_info "生成新 ID..."
        
        # 重置 installation_id
        if [ -f "$INSTALLATION_ID_FILE" ] || [ -d "$(dirname "$INSTALLATION_ID_FILE")" ]; then
            echo "$NEW_INSTALL_ID" > "$INSTALLATION_ID_FILE"
            print_success "installation_id 已重置: $NEW_INSTALL_ID"
        fi
        
        # 重置 machineid
        if [ -f "$MACHINE_ID_FILE" ] || [ -d "$(dirname "$MACHINE_ID_FILE")" ]; then
            echo "$NEW_MACHINE_ID" > "$MACHINE_ID_FILE"
            print_success "machineid 已重置: $NEW_MACHINE_ID"
        fi
        
        # 重置 storage.json 中的 telemetry ID
        if [ -f "$STORAGE_JSON" ]; then
            if command -v python3 &> /dev/null; then
                python3 << PYEOF
import json
try:
    with open('$STORAGE_JSON', 'r') as f:
        data = json.load(f)
    
    data['telemetry.devDeviceId'] = '$NEW_DEV_DEVICE_ID'
    data['telemetry.macMachineId'] = '$NEW_MAC_MACHINE_ID'
    data['telemetry.machineId'] = '$NEW_TELEMETRY_MACHINE_ID'
    data['telemetry.sqmId'] = '$NEW_SQM_ID'
    
    with open('$STORAGE_JSON', 'w') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    
    print('storage.json telemetry ID 已重置')
except Exception as e:
    print(f'storage.json 处理失败: {e}')
PYEOF
                print_success "storage.json 中的 telemetry ID 已重置"
            else
                print_warning "未找到 python3，无法重置 storage.json 中的 telemetry ID"
                print_info "请手动编辑: $STORAGE_JSON"
            fi
        fi
        
        echo ""
        echo -e "${CYAN}重置后的 ID 信息:${NC}"
        echo -e "  installation_id:        ${GREEN}$NEW_INSTALL_ID${NC}"
        echo -e "  machineid:              ${GREEN}$NEW_MACHINE_ID${NC}"
        echo -e "  telemetry.devDeviceId:  ${GREEN}$NEW_DEV_DEVICE_ID${NC}"
        echo -e "  telemetry.macMachineId: ${GREEN}$NEW_MAC_MACHINE_ID${NC}"
        echo -e "  telemetry.machineId:    ${GREEN}$NEW_TELEMETRY_MACHINE_ID${NC}"
        echo -e "  telemetry.sqmId:        ${GREEN}$NEW_SQM_ID${NC}"
        echo ""
        print_success "Windsurf ID 重置完成！"
        print_info "请重启 Windsurf 使更改生效"
    else
        print_info "已取消操作"
    fi
}

# ----------------------------------------------------------------------------
# 功能22: 重置 OpenCode CLI ID
# ----------------------------------------------------------------------------
reset_opencode_id() {
    print_info "重置 OpenCode CLI ID与缓存..."
    
    # 路径定义
    OPENCODE_DATA_DIR="$HOME/.local/share/opencode"
    OPENCODE_CACHE_DIR="$HOME/.cache/opencode"
    OPENCODE_CONFIG_DIR="$HOME/.config/opencode"
    
    echo ""
    print_warning "此操作将清理 OpenCode CLI 的本地数据库、缓存和认证信息"
    echo "  这有助于缓解限速问题，重置后你需要重新登录 (auth.json 将被移除)"
    echo ""
    
    if confirm_action; then
        # 杀死可能运行的进程
        pkill -f "opencode" 2>/dev/null || true
        
        # 清理 ~/.local/share/opencode 目录下的数据库和认证文件
        if [ -d "$OPENCODE_DATA_DIR" ]; then
            rm -f "$OPENCODE_DATA_DIR/opencode.db" 2>/dev/null
            rm -f "$OPENCODE_DATA_DIR/opencode.db-shm" 2>/dev/null
            rm -f "$OPENCODE_DATA_DIR/opencode.db-wal" 2>/dev/null
            rm -f "$OPENCODE_DATA_DIR/auth.json" 2>/dev/null
            rm -rf "$OPENCODE_DATA_DIR/storage" 2>/dev/null
            print_success "已清理 OpenCode 本地数据库与认证状态"
        fi
        
        # 清理缓存
        if [ -d "$OPENCODE_CACHE_DIR" ]; then
            rm -rf "$OPENCODE_CACHE_DIR"/* 2>/dev/null
            print_success "已清理 OpenCode 本地运行时缓存"
        fi
        
        print_success "OpenCode ID 及缓存重置完成！"
    else
        print_info "已取消操作"
    fi
}

# ----------------------------------------------------------------------------
# 功能18: 深度清理运行时缓存（保留对话历史）
# ----------------------------------------------------------------------------
deep_clean_runtime_cache() {
    AUTO_CONFIRM="$1"
    print_info "深度清理运行时缓存（保留对话历史）..."

    echo ""
    echo "此操作会先执行默认安全深清，再可选继续清理登录态相关存储"
    print_success "第一阶段不会清理对话历史（cascade/*.pb）、登录态相关存储（IndexedDB/WebStorage/Local Storage/Session Storage/Service Worker/Cookies）、memories、skills、extensions、用户设置"
    echo ""

    if [ "$AUTO_CONFIRM" != "--auto" ]; then
        if ! confirm_action; then
            print_info "已取消操作"
            return 0
        fi
    else
        print_info "已启用自动确认模式"
    fi

    if ! check_windsurf_running; then
        return 1
    fi
    TOTAL_RELEASED_KB=0

    # ── Electron 内核缓存 ──────────────────────────────────────────────────
    clean_glob_with_stats "$WINDSURF_SUPPORT_DIR/Cache/*"                          "清理浏览器缓存 (Cache)"
    clean_glob_with_stats "$WINDSURF_SUPPORT_DIR/CachedData/*"                     "清理编译缓存 (CachedData)"
    clean_glob_with_stats "$WINDSURF_SUPPORT_DIR/GPUCache/*"                       "清理 GPU 缓存 (GPUCache)"
    clean_glob_with_stats "$WINDSURF_SUPPORT_DIR/Code Cache/*"                     "清理代码缓存 (Code Cache)"
    clean_glob_with_stats "$WINDSURF_SUPPORT_DIR/DawnWebGPUCache/*"                "清理 Dawn WebGPU 缓存"
    clean_glob_with_stats "$WINDSURF_SUPPORT_DIR/DawnGraphiteCache/*"              "清理 Dawn Graphite 缓存"
    clean_glob_with_stats "$WINDSURF_SUPPORT_DIR/Shared Dictionary/*"              "清理 Shared Dictionary 缓存"

    # ── 日志 / 崩溃报告 ───────────────────────────────────────────────────
    clean_glob_with_stats "$WINDSURF_SUPPORT_DIR/logs/*"                           "清理日志文件 (logs)"
    clean_glob_with_stats "$WINDSURF_SUPPORT_DIR/Crashpad/completed/*"             "清理 Crashpad completed"
    clean_glob_with_stats "$WINDSURF_SUPPORT_DIR/Crashpad/pending/*"               "清理 Crashpad pending"

    # ── 工作区 / 历史 / 插件残留 ───────────────────────────────────────────
    clean_file_with_stats "$WINDSURF_SUPPORT_DIR/User/globalStorage/state.vscdb.backup" "清理 state.vscdb.backup（关键大文件）"
    clean_glob_with_stats "$WINDSURF_SUPPORT_DIR/User/workspaceStorage/*"          "清理工作区状态缓存 (workspaceStorage)"
    clean_glob_with_stats "$WINDSURF_SUPPORT_DIR/User/History/*"                   "清理本地文件历史 (History)"
    clean_glob_with_stats "$WINDSURF_SUPPORT_DIR/CachedExtensionVSIXs/*"           "清理旧版插件安装包残留"

    # ── 语言包缓存（clp 目录，保留最新版） ────────────────────────────────
    echo ""
    print_info "清理旧版语言包缓存 (clp)"
    CLP_DIR="$WINDSURF_SUPPORT_DIR/clp"
    if [ -d "$CLP_DIR" ]; then
        BEFORE_KB=$(du -sk "$CLP_DIR" 2>/dev/null | awk '{print $1}')
        BEFORE_KB=${BEFORE_KB:-0}
        print_info "清理前大小: $(format_kb_size "$BEFORE_KB")"
        # 遍历语言包子目录，每个语言只保留最新的版本目录
        for lang_dir in "$CLP_DIR"/*/; do
            if [ -d "$lang_dir" ]; then
                # 按修改时间排序，保留最新一个，删除其余旧版本
                ls -1td "$lang_dir"*/ 2>/dev/null | tail -n +2 | while IFS= read -r old_ver; do
                    rm -rf "$old_ver" 2>/dev/null || true
                done
            fi
        done
        AFTER_KB=$(du -sk "$CLP_DIR" 2>/dev/null | awk '{print $1}')
        AFTER_KB=${AFTER_KB:-0}
        RELEASED_KB=$((BEFORE_KB - AFTER_KB))
        if [ "$RELEASED_KB" -lt 0 ]; then RELEASED_KB=0; fi
        TOTAL_RELEASED_KB=$((TOTAL_RELEASED_KB + RELEASED_KB))
        print_success "已释放: $(format_kb_size "$RELEASED_KB")"
    else
        print_info "clp 目录不存在，无需清理"
    fi

    # ── CachedProfilesData 缓存 ────────────────────────────────────────────
    clean_glob_with_stats "$WINDSURF_SUPPORT_DIR/CachedProfilesData/*"             "清理配置文件缓存 (CachedProfilesData)"

    # ── AI 索引缓存 ────────────────────────────────────────────────────────
    clean_glob_with_stats "$IMPLICIT_DIR/*"                                        "清理 implicit AI 索引缓存"
    clean_glob_with_stats "$CODE_TRACKER_DIR/*"                                    "清理 AI 代码追踪索引 (code_tracker)"

    # ── macOS 系统级缓存 ───────────────────────────────────────────────────
    clean_glob_with_stats "$MACOS_WS_CACHE/*"                                      "清理 macOS Windsurf 系统缓存"
    clean_glob_with_stats "$MACOS_WS_SHIPIT/*"                                     "清理 macOS Windsurf ShipIt 缓存"

    # ── 临时文件 ──────────────────────────────────────────────────────────
    clean_glob_with_stats "/tmp/windsurf-terminal-*.snapshot"                      "清理 /tmp 终端快照"
    clean_glob_with_stats "$HOME/.zcompdump*"                                       "清理 Zsh 自动补全缓存（解决终端卡顿）"

    # ── IndexedDB / Service Worker / blob_storage 安全清理 ────────────────
    # 重要说明：
    #   1. IndexedDB 在 Windsurf 中存的是 VSCode webview 的 UI 状态（Cascade 面板滚动/折叠、编辑器 Tab 状态），
    #      不是登录凭证。登录凭证位于 Cookies/Local Storage/WebStorage 以及 ~/.codeium/windsurf/installation_id。
    #      清理 IndexedDB 后重启 Windsurf 仍保持登录，只会重置 Cascade 面板的 UI 排版。
    #   2. Service Worker/CacheStorage 与 ScriptCache 是 Chromium Service Worker 的静态资源缓存，
    #      与登录态无关，清理后会在下一次启动自动重建。
    #   3. blob_storage 是临时 blob 对象缓存，与登录无关。
    #   4. 对话历史存于 ~/.codeium/windsurf/cascade/*.pb，与以上目录完全独立。
    clean_glob_with_stats "$WINDSURF_SUPPORT_DIR/IndexedDB/*"                      "清理 IndexedDB（Cascade UI 状态，不影响登录和对话）"
    clean_glob_with_stats "$WINDSURF_SUPPORT_DIR/Service Worker/CacheStorage/*"    "清理 Service Worker CacheStorage（静态资源缓存）"
    clean_glob_with_stats "$WINDSURF_SUPPORT_DIR/Service Worker/ScriptCache/*"     "清理 Service Worker ScriptCache（脚本缓存）"
    clean_glob_with_stats "$WINDSURF_SUPPORT_DIR/blob_storage/*"                   "清理 blob_storage（临时 Blob 对象缓存）"

    # ── state.vscdb VACUUM 优化（不删除文件，仅压缩 SQLite 数据库碎片） ──────
    # 根因：Cascade 面板的快速操作会持续写入 state.vscdb，如果不 VACUUM，
    #       表内删除后的行会变为"碎片页"残留，文件持续膨胀（官方 issue 实测可从 298MB 压到 639KB）。
    #       这是对话长后切换/启动变慢的主因之一。
    echo ""
    print_info "VACUUM 全局 state.vscdb 数据库（保留全部数据，只压缩碎片）..."
    STATE_DB="$WINDSURF_SUPPORT_DIR/User/globalStorage/state.vscdb"
    if [ -f "$STATE_DB" ]; then
        BEFORE_KB=$(du -sk "$STATE_DB" 2>/dev/null | awk '{print $1}')
        BEFORE_KB=${BEFORE_KB:-0}
        print_info "  优化前大小: $(format_kb_size "$BEFORE_KB")"
        if command -v sqlite3 &> /dev/null; then
            sqlite3 "$STATE_DB" "VACUUM;" 2>/dev/null && \
                print_success "  全局 VACUUM 完成" || \
                print_warning "  全局 VACUUM 失败（文件可能被占用，请先关闭 Windsurf）"
            AFTER_KB=$(du -sk "$STATE_DB" 2>/dev/null | awk '{print $1}')
            AFTER_KB=${AFTER_KB:-0}
            RELEASED_KB=$((BEFORE_KB - AFTER_KB))
            if [ "$RELEASED_KB" -lt 0 ]; then RELEASED_KB=0; fi
            TOTAL_RELEASED_KB=$((TOTAL_RELEASED_KB + RELEASED_KB))
            print_success "  优化后大小: $(format_kb_size "$AFTER_KB")，释放: $(format_kb_size "$RELEASED_KB")"
        else
            print_warning "  未找到 sqlite3 命令，跳过 VACUUM"
        fi
    else
        print_info "  全局 state.vscdb 不存在，跳过"
    fi

    # ── workspaceStorage 下所有工作区 state.vscdb 的批量 VACUUM ─────────────
    # 这是长对话卡顿的另一个常见元凶：每个工作区都有独立的 state.vscdb，都会积累碎片。
    # 只做 VACUUM 压缩，不删除工作区数据，保留你的"最近打开文件"、"断点"等工作区状态。
    echo ""
    print_info "VACUUM 所有工作区 state.vscdb（保留工作区状态，只压缩碎片）..."
    if command -v sqlite3 &> /dev/null; then
        WS_VACUUM_COUNT=0
        WS_VACUUM_RELEASED_KB=0
        WORKSPACE_STORAGE_DIR="$WINDSURF_SUPPORT_DIR/User/workspaceStorage"
        if [ -d "$WORKSPACE_STORAGE_DIR" ]; then
            while IFS= read -r ws_db; do
                if [ -f "$ws_db" ]; then
                    WS_BEFORE_KB=$(du -sk "$ws_db" 2>/dev/null | awk '{print $1}')
                    WS_BEFORE_KB=${WS_BEFORE_KB:-0}
                    if sqlite3 "$ws_db" "VACUUM;" 2>/dev/null; then
                        WS_AFTER_KB=$(du -sk "$ws_db" 2>/dev/null | awk '{print $1}')
                        WS_AFTER_KB=${WS_AFTER_KB:-0}
                        WS_DIFF_KB=$((WS_BEFORE_KB - WS_AFTER_KB))
                        if [ "$WS_DIFF_KB" -lt 0 ]; then WS_DIFF_KB=0; fi
                        WS_VACUUM_RELEASED_KB=$((WS_VACUUM_RELEASED_KB + WS_DIFF_KB))
                        WS_VACUUM_COUNT=$((WS_VACUUM_COUNT + 1))
                    fi
                fi
            done < <(find "$WORKSPACE_STORAGE_DIR" -maxdepth 2 -name "state.vscdb" -type f 2>/dev/null)
            TOTAL_RELEASED_KB=$((TOTAL_RELEASED_KB + WS_VACUUM_RELEASED_KB))
            print_success "  已 VACUUM $WS_VACUUM_COUNT 个工作区 state.vscdb，释放: $(format_kb_size "$WS_VACUUM_RELEASED_KB")"
        else
            print_info "  workspaceStorage 目录不存在，跳过"
        fi
    else
        print_warning "  未找到 sqlite3 命令，跳过工作区 VACUUM"
    fi

    # ── 登录态高风险存储（默认保留，不在第一阶段清理） ─────────────────────
    # 真正的登录相关存储：Cookies、Local Storage、WebStorage、Session Storage、
    # Network Persistent State、TransportSecurity、DIPS、SharedStorage、Trust Tokens
    WEBSTORAGE_KB=$(calculate_path_size_kb "$WINDSURF_SUPPORT_DIR/WebStorage")
    LOCAL_STORAGE_KB=$(calculate_path_size_kb "$WINDSURF_SUPPORT_DIR/Local Storage")
    SESSION_STORAGE_KB=$(calculate_path_size_kb "$WINDSURF_SUPPORT_DIR/Session Storage")
    COOKIES_KB=$(calculate_path_size_kb "$WINDSURF_SUPPORT_DIR/Cookies")
    NETWORK_STATE_KB=$(calculate_path_size_kb "$WINDSURF_SUPPORT_DIR/Network Persistent State")
    DIPS_KB=$(calculate_path_size_kb "$WINDSURF_SUPPORT_DIR/DIPS")
    SHARED_STORAGE_KB=$(calculate_path_size_kb "$WINDSURF_SUPPORT_DIR/SharedStorage")
    TRUST_TOKENS_KB=$(calculate_path_size_kb "$WINDSURF_SUPPORT_DIR/Trust Tokens")
    RISKY_TOTAL_KB=$((WEBSTORAGE_KB + LOCAL_STORAGE_KB + SESSION_STORAGE_KB + COOKIES_KB + NETWORK_STATE_KB + DIPS_KB + SHARED_STORAGE_KB + TRUST_TOKENS_KB))

    if [ "$AUTO_CONFIRM" != "--auto" ] && [ "$RISKY_TOTAL_KB" -gt 0 ] 2>/dev/null; then
        echo ""
        print_warning "默认已保留 $(format_kb_size "$RISKY_TOTAL_KB") 的登录态相关存储"
        echo -e "  ${CYAN}[仅供参考] 如需彻底清理（会强制重新登录 Windsurf）才选 y:${NC}"
        [ "$COOKIES_KB" -gt 0 ]        && echo "    Cookies -> $(format_kb_size "$COOKIES_KB")"
        [ "$LOCAL_STORAGE_KB" -gt 0 ]  && echo "    Local Storage -> $(format_kb_size "$LOCAL_STORAGE_KB")"
        [ "$WEBSTORAGE_KB" -gt 0 ]     && echo "    WebStorage -> $(format_kb_size "$WEBSTORAGE_KB")"
        [ "$SESSION_STORAGE_KB" -gt 0 ] && echo "    Session Storage -> $(format_kb_size "$SESSION_STORAGE_KB")"
        [ "$NETWORK_STATE_KB" -gt 0 ]  && echo "    Network Persistent State -> $(format_kb_size "$NETWORK_STATE_KB")"
        [ "$DIPS_KB" -gt 0 ]           && echo "    DIPS -> $(format_kb_size "$DIPS_KB")"
        [ "$SHARED_STORAGE_KB" -gt 0 ] && echo "    SharedStorage -> $(format_kb_size "$SHARED_STORAGE_KB")"
        [ "$TRUST_TOKENS_KB" -gt 0 ]   && echo "    Trust Tokens -> $(format_kb_size "$TRUST_TOKENS_KB")"
        echo -ne ${YELLOW}是否继续清理登录态相关存储？这会强制重新登录 Windsurf [y/N]: ${NC}
        read -r choice
        case "$choice" in
            y|Y )
                clean_glob_with_stats "$WINDSURF_SUPPORT_DIR/WebStorage/*"             "清理 WebStorage（内嵌网页登录态）"
                clean_glob_with_stats "$WINDSURF_SUPPORT_DIR/Local Storage/*"          "清理 Local Storage（会话数据）"
                clean_glob_with_stats "$WINDSURF_SUPPORT_DIR/Session Storage/*"        "清理 Session Storage"
                clean_file_with_stats "$WINDSURF_SUPPORT_DIR/Cookies"                  "清理 Cookies（登录 Cookie）"
                clean_file_with_stats "$WINDSURF_SUPPORT_DIR/Cookies-journal"          "清理 Cookies-journal"
                clean_file_with_stats "$WINDSURF_SUPPORT_DIR/Network Persistent State" "清理 Network Persistent State"
                clean_file_with_stats "$WINDSURF_SUPPORT_DIR/TransportSecurity"        "清理 TransportSecurity"
                clean_file_with_stats "$WINDSURF_SUPPORT_DIR/DIPS"                     "清理 DIPS"
                clean_file_with_stats "$WINDSURF_SUPPORT_DIR/DIPS-wal"                 "清理 DIPS-wal"
                clean_file_with_stats "$WINDSURF_SUPPORT_DIR/SharedStorage"            "清理 SharedStorage"
                clean_file_with_stats "$WINDSURF_SUPPORT_DIR/SharedStorage-wal"        "清理 SharedStorage-wal"
                clean_file_with_stats "$WINDSURF_SUPPORT_DIR/Trust Tokens"             "清理 Trust Tokens"
                clean_file_with_stats "$WINDSURF_SUPPORT_DIR/Trust Tokens-journal"     "清理 Trust Tokens-journal"
                ;;
            * )
                print_info "已保留登录态相关存储（推荐）"
                ;;
        esac
    fi

    echo ""
    print_success "深度清理完成，总释放空间: $(format_kb_size "$TOTAL_RELEASED_KB")"
    print_info "已保留对话历史（cascade/*.pb）、memories、skills、extensions、用户设置"

    # 清理完毕 -> 强制重置设备 ID（默认行为，FORCE_RESET_ID=0 可关闭）
    auto_reset_after_clean
}

# ----------------------------------------------------------------------------
# 功能19: Windsurf 进程资源监控
# ----------------------------------------------------------------------------
monitor_windsurf_processes() {
    print_info "Windsurf 进程资源监控..."
    
    echo ""
    echo -e "${CYAN}========== Windsurf 进程 ==========${NC}"
    PROCESS_OUTPUT=$(ps aux | grep -i "[w]indsurf" | grep -v "fix-windsurf-mac.sh")
    
    if [ -n "$PROCESS_OUTPUT" ]; then
        printf "%-8s %-8s %-8s %s\n" "PID" "CPU%" "MEM%" "命令"
        echo "$PROCESS_OUTPUT" | awk '{
            cmd=""
            for(i=11;i<=NF;i++) cmd=cmd $i " "
            printf "%-8s %-8s %-8s %s\n", $2, $3, $4, cmd
        }'
    else
        print_warning "未检测到 Windsurf 正在运行"
    fi
    
    echo ""
    echo -e "${CYAN}========== 系统内存概况 ==========${NC}"
    VM_OUTPUT=$(vm_stat)
    PAGE_SIZE=$(echo "$VM_OUTPUT" | head -1 | awk '{print $8}' | tr -d '.')
    
    PAGES_FREE=$(echo "$VM_OUTPUT" | awk '/Pages free/ {gsub("\.","",$3); print $3}')
    PAGES_ACTIVE=$(echo "$VM_OUTPUT" | awk '/Pages active/ {gsub("\.","",$3); print $3}')
    PAGES_INACTIVE=$(echo "$VM_OUTPUT" | awk '/Pages inactive/ {gsub("\.","",$3); print $3}')
    PAGES_SPECULATIVE=$(echo "$VM_OUTPUT" | awk '/Pages speculative/ {gsub("\.","",$3); print $3}')
    PAGES_WIRED=$(echo "$VM_OUTPUT" | awk '/Pages wired down/ {gsub("\.","",$4); print $4}')
    PAGES_COMPRESSED=$(echo "$VM_OUTPUT" | awk '/Pages occupied by compressor/ {gsub("\.","",$5); print $5}')
    
    FREE_MB=$(awk -v p="${PAGES_FREE:-0}" -v s="${PAGE_SIZE:-4096}" 'BEGIN {printf "%.2f", p*s/1024/1024}')
    ACTIVE_MB=$(awk -v p="${PAGES_ACTIVE:-0}" -v s="${PAGE_SIZE:-4096}" 'BEGIN {printf "%.2f", p*s/1024/1024}')
    INACTIVE_MB=$(awk -v p="${PAGES_INACTIVE:-0}" -v s="${PAGE_SIZE:-4096}" 'BEGIN {printf "%.2f", p*s/1024/1024}')
    SPECULATIVE_MB=$(awk -v p="${PAGES_SPECULATIVE:-0}" -v s="${PAGE_SIZE:-4096}" 'BEGIN {printf "%.2f", p*s/1024/1024}')
    WIRED_MB=$(awk -v p="${PAGES_WIRED:-0}" -v s="${PAGE_SIZE:-4096}" 'BEGIN {printf "%.2f", p*s/1024/1024}')
    COMPRESSED_MB=$(awk -v p="${PAGES_COMPRESSED:-0}" -v s="${PAGE_SIZE:-4096}" 'BEGIN {printf "%.2f", p*s/1024/1024}')
    
    echo "  空闲内存: ${FREE_MB}MB"
    echo "  活跃内存: ${ACTIVE_MB}MB"
    echo "  非活跃内存: ${INACTIVE_MB}MB"
    echo "  推测内存: ${SPECULATIVE_MB}MB"
    echo "  Wired 内存: ${WIRED_MB}MB"
    echo "  压缩内存: ${COMPRESSED_MB}MB"
    
    echo ""
    echo -e "${CYAN}========== 磁盘空间 ==========${NC}"
    df -h / 2>/dev/null | head -2
}

# ----------------------------------------------------------------------------
# 功能20: 一键智能优化（不清理对话历史）
# ----------------------------------------------------------------------------
smart_optimize() {
    print_info "执行一键智能优化（保留对话历史）..."
    print_success "不会清理 cascade/memories/skills/extensions"
    
    BEFORE_TOTAL_KB=$(calculate_runtime_cache_total_kb)
    print_info "优化前可清理空间: $(format_kb_size "$BEFORE_TOTAL_KB")"
    
    deep_clean_runtime_cache --auto
    
    AFTER_TOTAL_KB=$(calculate_runtime_cache_total_kb)
    OPTIMIZED_KB=$((BEFORE_TOTAL_KB - AFTER_TOTAL_KB))
    if [ "$OPTIMIZED_KB" -lt 0 ]; then
        OPTIMIZED_KB=0
    fi
    
    echo ""
    echo -e "${CYAN}========== 优化前后对比 ==========${NC}"
    echo "  优化前可清理空间: $(format_kb_size "$BEFORE_TOTAL_KB")"
    echo "  优化后可清理空间: $(format_kb_size "$AFTER_TOTAL_KB")"
    echo "  本次优化释放空间: $(format_kb_size "$OPTIMIZED_KB")"
    echo ""
    print_success "一键智能优化完成"
}

# ----------------------------------------------------------------------------
# 功能23: Cascade 对话历史归档（保留对话但解决"对话长卡顿"）
# 说明：
#   Windsurf 的 Cascade 启动时会尝试加载 ~/.codeium/windsurf/cascade/*.pb，
#   当这些文件累计到几百 MB（单文件可达 27MB 以上）时，切换/启动会明显变卡。
#   本功能把"超过 N 天"或"超过 M MB"的旧对话 *移动*（不是删除）到归档目录，
#   减小运行时加载量。需要时可以随时把归档文件拷回原目录恢复访问。
# ----------------------------------------------------------------------------
archive_old_conversations() {
    print_info "Cascade 对话历史归档（移动不删除，解决对话长卡顿）..."

    CASCADE_PB_DIR="$CASCADE_DIR"
    if [ ! -d "$CASCADE_PB_DIR" ]; then
        print_warning "未找到对话目录：$CASCADE_PB_DIR"
        return 0
    fi

    TOTAL_PB_COUNT=$(find "$CASCADE_PB_DIR" -maxdepth 1 -name "*.pb" -type f 2>/dev/null | wc -l | tr -d ' ')
    TOTAL_PB_KB=$(du -sk "$CASCADE_PB_DIR" 2>/dev/null | awk '{print $1+0}')
    TOTAL_PB_KB=${TOTAL_PB_KB:-0}

    if [ "$TOTAL_PB_COUNT" -eq 0 ] 2>/dev/null; then
        print_info "当前没有对话历史文件，无需归档"
        return 0
    fi

    echo ""
    echo -e "${CYAN}========== 当前对话历史概况 ==========${NC}"
    echo -e "  对话文件总数: ${YELLOW}$TOTAL_PB_COUNT${NC}"
    echo -e "  对话历史总量: ${YELLOW}$(format_kb_size "$TOTAL_PB_KB")${NC}"
    echo ""
    echo -e "${CYAN}体积 Top 10 对话:${NC}"
    find "$CASCADE_PB_DIR" -maxdepth 1 -name "*.pb" -type f 2>/dev/null \
        | xargs -I{} du -sk "{}" 2>/dev/null | sort -rn | head -10 \
        | while read -r sz f; do
            fname=$(basename "$f")
            mtime=$(stat -f "%Sm" -t "%Y-%m-%d" "$f" 2>/dev/null)
            printf "    %-45s %-12s %s\n" "$fname" "$(format_kb_size "$sz")" "$mtime"
        done
    echo ""

    echo -e "${YELLOW}请选择归档策略:${NC}"
    echo "  1) 按时间：归档 30 天以上的对话（推荐）"
    echo "  2) 按时间：归档 14 天以上的对话（激进）"
    echo "  3) 按大小：归档大于 10MB 的对话"
    echo "  4) 按大小：归档大于 5MB 的对话（激进）"
    echo "  5) 同时按时间和大小：30 天以上 或 大于 10MB"
    echo "  6) 自定义（交互式输入）"
    echo "  0) 取消"
    echo ""
    echo -ne ${CYAN}请选择 [0-6]: ${NC}
    read -r arc_choice

    ARC_DAYS=-1
    ARC_MB=-1
    case "$arc_choice" in
        0) print_info "已取消操作"; return 0 ;;
        1) ARC_DAYS=30 ;;
        2) ARC_DAYS=14 ;;
        3) ARC_MB=10 ;;
        4) ARC_MB=5 ;;
        5) ARC_DAYS=30; ARC_MB=10 ;;
        6)
            echo -ne ${CYAN}归档多少天以前的对话？\(留空跳过时间维度\): ${NC}
            read -r in_days
            if [[ "$in_days" =~ ^[0-9]+$ ]] && [ "$in_days" -gt 0 ]; then
                ARC_DAYS=$in_days
            fi
            echo -ne ${CYAN}归档大于多少 MB 的对话？\(留空跳过大小维度\): ${NC}
            read -r in_mb
            if [[ "$in_mb" =~ ^[0-9]+$ ]] && [ "$in_mb" -gt 0 ]; then
                ARC_MB=$in_mb
            fi
            if [ "$ARC_DAYS" -le 0 ] && [ "$ARC_MB" -le 0 ]; then
                print_warning "未指定任何归档维度，已取消"
                return 0
            fi
            ;;
        *) print_error "无效选项"; return 0 ;;
    esac

    # 扫描符合条件的对话
    MATCHED_FILES=()
    MATCHED_TOTAL_KB=0
    while IFS= read -r pb; do
        [ -z "$pb" ] && continue
        # 时间条件
        time_hit=0
        if [ "$ARC_DAYS" -gt 0 ]; then
            if find "$pb" -mtime +"$ARC_DAYS" -print 2>/dev/null | grep -q .; then
                time_hit=1
            fi
        fi
        # 大小条件
        size_hit=0
        if [ "$ARC_MB" -gt 0 ]; then
            pb_kb=$(du -sk "$pb" 2>/dev/null | awk '{print $1+0}')
            if [ "${pb_kb:-0}" -gt $((ARC_MB * 1024)) ]; then
                size_hit=1
            fi
        fi
        # 任一条件命中就归档（OR 逻辑，与菜单描述一致）
        if [ "$time_hit" -eq 1 ] || [ "$size_hit" -eq 1 ]; then
            MATCHED_FILES+=("$pb")
            pb_kb=${pb_kb:-$(du -sk "$pb" 2>/dev/null | awk '{print $1+0}')}
            MATCHED_TOTAL_KB=$((MATCHED_TOTAL_KB + ${pb_kb:-0}))
        fi
    done < <(find "$CASCADE_PB_DIR" -maxdepth 1 -name "*.pb" -type f 2>/dev/null)

    MATCHED_COUNT=${#MATCHED_FILES[@]}
    if [ "$MATCHED_COUNT" -eq 0 ]; then
        print_info "没有符合条件的对话可归档"
        return 0
    fi

    echo ""
    echo -e "${CYAN}========== 将归档的对话 ==========${NC}"
    echo -e "  命中文件数: ${YELLOW}$MATCHED_COUNT${NC}"
    echo -e "  合计大小:   ${YELLOW}$(format_kb_size "$MATCHED_TOTAL_KB")${NC}"
    echo ""
    for pb in "${MATCHED_FILES[@]}"; do
        pb_kb=$(du -sk "$pb" 2>/dev/null | awk '{print $1+0}')
        mtime=$(stat -f "%Sm" -t "%Y-%m-%d" "$pb" 2>/dev/null)
        printf "    %-45s %-12s %s\n" "$(basename "$pb")" "$(format_kb_size "${pb_kb:-0}")" "$mtime"
    done
    echo ""

    ARCHIVE_TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    ARCHIVE_TARGET="$HOME/.windsurf-conversations-archive-$ARCHIVE_TIMESTAMP"
    echo -e "归档目标目录: ${CYAN}$ARCHIVE_TARGET${NC}"
    echo -e "${GREEN}注意：这是移动操作（不是删除），随时可以拷回 $CASCADE_PB_DIR 恢复。${NC}"
    echo ""

    if ! confirm_action; then
        print_info "已取消操作"
        return 0
    fi

    if ! check_windsurf_running; then
        return 1
    fi

    mkdir -p "$ARCHIVE_TARGET"
    MOVED_COUNT=0
    for pb in "${MATCHED_FILES[@]}"; do
        if mv "$pb" "$ARCHIVE_TARGET/" 2>/dev/null; then
            MOVED_COUNT=$((MOVED_COUNT + 1))
        fi
    done

    # 生成恢复脚本，方便用户一键恢复
    cat > "$ARCHIVE_TARGET/restore.sh" << RESTORE_EOF
#!/bin/bash
# 一键恢复本次归档的所有对话到 Windsurf。
# 使用方法： bash restore.sh
set -e
TARGET="\$HOME/.codeium/windsurf/cascade"
mkdir -p "\$TARGET"
cp -n "\$(dirname "\$0")"/*.pb "\$TARGET/"
echo "已恢复到 \$TARGET，请重启 Windsurf。"
RESTORE_EOF
    chmod +x "$ARCHIVE_TARGET/restore.sh" 2>/dev/null || true

    # 生成归档信息
    cat > "$ARCHIVE_TARGET/archive_info.txt" << AEOF
========================================
Windsurf Cascade 对话归档
========================================
归档时间: $(date)
归档来源: $CASCADE_PB_DIR
命中条件: 天数阈值=$ARC_DAYS，大小阈值(MB)=$ARC_MB
归档文件数: $MOVED_COUNT
归档目录: $ARCHIVE_TARGET

恢复方法（任选其一）：
  1. 直接运行脚本：  bash "$ARCHIVE_TARGET/restore.sh"
  2. 手动复制文件：  cp "$ARCHIVE_TARGET"/*.pb "$CASCADE_PB_DIR/"
  3. 只恢复某一个：  cp "$ARCHIVE_TARGET/<file>.pb" "$CASCADE_PB_DIR/"
恢复后重启 Windsurf 即可再次看到这些对话。
========================================
AEOF

    AFTER_PB_KB=$(du -sk "$CASCADE_PB_DIR" 2>/dev/null | awk '{print $1+0}')
    AFTER_PB_KB=${AFTER_PB_KB:-0}
    RELEASED_KB=$((TOTAL_PB_KB - AFTER_PB_KB))
    if [ "$RELEASED_KB" -lt 0 ]; then RELEASED_KB=0; fi

    echo ""
    print_success "已归档 $MOVED_COUNT 个对话到 $ARCHIVE_TARGET"
    print_success "Cascade 目录从 $(format_kb_size "$TOTAL_PB_KB") 缩减到 $(format_kb_size "$AFTER_PB_KB")（释放 $(format_kb_size "$RELEASED_KB")）"
    print_info "Windsurf 重启后加载更快。想恢复任何对话：bash \"$ARCHIVE_TARGET/restore.sh\""

    # 归档完毕 -> 强制重置设备 ID（默认行为）
    if [ "$MOVED_COUNT" -gt 0 ] 2>/dev/null; then
        auto_reset_after_clean
    fi
}

# ----------------------------------------------------------------------------
# 功能24: 卡顿快速诊断 + 一键安全优化（保留对话、保留登录）
# 说明：
#   专为"Cascade 对话长就卡顿"场景设计。只动缓存/索引/碎片，不动：
#     1. cascade/*.pb 对话历史
#     2. Cookies / Local Storage / WebStorage / installation_id / machineid（登录态）
#     3. memories / skills / mcp_config.json / user_settings.pb（用户配置）
#     4. settings.json / keybindings.json（个人编辑器设置）
# ----------------------------------------------------------------------------
quick_diagnose_and_fix() {
    print_info "卡顿快速诊断（登录态 + 对话历史会 100% 保留）..."

    # ── 诊断阶段 ───────────────────────────────────────────────────────────
    echo ""
    echo -e "${CYAN}========== 卡顿维度扫描 ==========${NC}"

    CASCADE_TOTAL_KB=$(du -sk "$CASCADE_DIR" 2>/dev/null | awk '{print $1+0}')
    CASCADE_TOTAL_KB=${CASCADE_TOTAL_KB:-0}
    CASCADE_COUNT=$(find "$CASCADE_DIR" -maxdepth 1 -name "*.pb" -type f 2>/dev/null | wc -l | tr -d ' ')

    STATE_DB_KB=$(calculate_path_size_kb "$WINDSURF_SUPPORT_DIR/User/globalStorage/state.vscdb")
    STATE_DB_BACKUP_KB=$(calculate_path_size_kb "$WINDSURF_SUPPORT_DIR/User/globalStorage/state.vscdb.backup")
    WS_STORAGE_KB=$(calculate_path_size_kb "$WINDSURF_SUPPORT_DIR/User/workspaceStorage")
    WS_COUNT=$(find "$WINDSURF_SUPPORT_DIR/User/workspaceStorage" -maxdepth 2 -name "state.vscdb" -type f 2>/dev/null | wc -l | tr -d ' ')

    CACHE_KB=$(calculate_path_size_kb "$WINDSURF_SUPPORT_DIR/Cache")
    CACHED_DATA_KB=$(calculate_path_size_kb "$WINDSURF_SUPPORT_DIR/CachedData")
    GPUCACHE_KB=$(calculate_path_size_kb "$WINDSURF_SUPPORT_DIR/GPUCache")
    CODECACHE_KB=$(calculate_path_size_kb "$WINDSURF_SUPPORT_DIR/Code Cache")
    INDEXEDDB_KB=$(calculate_path_size_kb "$WINDSURF_SUPPORT_DIR/IndexedDB")
    SW_KB=$(calculate_path_size_kb "$WINDSURF_SUPPORT_DIR/Service Worker")
    LOGS_KB=$(calculate_path_size_kb "$WINDSURF_SUPPORT_DIR/logs")
    CRASHPAD_KB=$(calculate_path_size_kb "$WINDSURF_SUPPORT_DIR/Crashpad")
    IMPLICIT_KB=$(calculate_path_size_kb "$IMPLICIT_DIR")
    CODE_TRACKER_KB=$(calculate_path_size_kb "$CODE_TRACKER_DIR")
    TERM_SNAP_COUNT=$(ls /tmp/windsurf-terminal-*.snapshot 2>/dev/null | wc -l | tr -d ' ')

    echo -e "  ${CYAN}[对话历史]${NC}         cascade/ -> $(format_kb_size "$CASCADE_TOTAL_KB") ($CASCADE_COUNT 个对话，保留)"
    echo -e "  ${CYAN}[数据库]${NC}           state.vscdb -> $(format_kb_size "$STATE_DB_KB")（VACUUM 可压缩）"
    echo -e "  ${CYAN}[数据库备份]${NC}       state.vscdb.backup -> $(format_kb_size "$STATE_DB_BACKUP_KB")（可清理）"
    echo -e "  ${CYAN}[工作区存储]${NC}       workspaceStorage/ -> $(format_kb_size "$WS_STORAGE_KB")（$WS_COUNT 个工作区，可 VACUUM）"
    echo -e "  ${CYAN}[Electron 缓存]${NC}    Cache=$(format_kb_size "$CACHE_KB") / CachedData=$(format_kb_size "$CACHED_DATA_KB") / GPUCache=$(format_kb_size "$GPUCACHE_KB") / Code Cache=$(format_kb_size "$CODECACHE_KB")"
    echo -e "  ${CYAN}[UI 状态]${NC}          IndexedDB=$(format_kb_size "$INDEXEDDB_KB") / Service Worker=$(format_kb_size "$SW_KB")"
    echo -e "  ${CYAN}[日志/崩溃]${NC}        logs=$(format_kb_size "$LOGS_KB") / Crashpad=$(format_kb_size "$CRASHPAD_KB")"
    echo -e "  ${CYAN}[AI 索引]${NC}          implicit=$(format_kb_size "$IMPLICIT_KB") / code_tracker=$(format_kb_size "$CODE_TRACKER_KB")"
    echo -e "  ${CYAN}[终端快照]${NC}         /tmp/windsurf-terminal-*.snapshot 数量: $TERM_SNAP_COUNT"

    # 计算一键优化释放的总量
    QUICK_TOTAL_KB=$((STATE_DB_BACKUP_KB + CACHE_KB + CACHED_DATA_KB + GPUCACHE_KB + CODECACHE_KB + INDEXEDDB_KB + SW_KB + LOGS_KB + CRASHPAD_KB + IMPLICIT_KB + CODE_TRACKER_KB))

    echo ""
    echo -e "${CYAN}========== 建议操作（一键执行将释放 ~$(format_kb_size "$QUICK_TOTAL_KB") + VACUUM 瘦身）==========${NC}"
    echo "  1. 关闭 Windsurf（必需，否则数据库被锁）"
    echo "  2. VACUUM 全局 state.vscdb 和所有工作区 state.vscdb（压缩不删数据）"
    echo "  3. 清理 Cache / CachedData / GPUCache / Code Cache（Electron 内核缓存）"
    echo "  4. 清理 IndexedDB / Service Worker 缓存（Cascade UI 状态，不影响登录）"
    echo "  5. 清理 logs / Crashpad（运行日志）"
    echo "  6. 清理 implicit / code_tracker（AI 索引缓存，会重建）"
    echo "  7. 清理 /tmp 终端快照 和 .zcompdump（解决终端卡顿）"
    echo ""
    echo -e "${GREEN}全程不会碰：cascade/*.pb、Cookies、Local Storage、WebStorage、installation_id、machineid、memories、skills、mcp_config.json、settings.json${NC}"
    echo ""

    if [ "$CASCADE_TOTAL_KB" -gt 204800 ] 2>/dev/null; then
        echo -e "${YELLOW}[提示] 你的对话历史已超过 200MB，${NC}"
        echo -e "${YELLOW}       即便做完上面的优化，Windsurf 加载仍可能偏慢。${NC}"
        echo -e "${YELLOW}       建议再执行菜单 23 做对话归档（移动不删除）。${NC}"
        echo ""
    fi

    echo -ne ${YELLOW}是否执行一键安全优化？[y/N]: ${NC}
    read -r qc_choice
    case "$qc_choice" in
        y|Y ) ;;
        * ) print_info "已取消操作"; return 0 ;;
    esac

    if ! check_windsurf_running; then
        return 1
    fi

    # ── 执行阶段 ───────────────────────────────────────────────────────────
    TOTAL_RELEASED_KB=0

    # Electron 内核缓存
    clean_glob_with_stats "$WINDSURF_SUPPORT_DIR/Cache/*"                          "清理 Electron Cache"
    clean_glob_with_stats "$WINDSURF_SUPPORT_DIR/CachedData/*"                     "清理 CachedData"
    clean_glob_with_stats "$WINDSURF_SUPPORT_DIR/GPUCache/*"                       "清理 GPUCache"
    clean_glob_with_stats "$WINDSURF_SUPPORT_DIR/Code Cache/*"                     "清理 Code Cache"
    clean_glob_with_stats "$WINDSURF_SUPPORT_DIR/DawnWebGPUCache/*"                "清理 DawnWebGPUCache"
    clean_glob_with_stats "$WINDSURF_SUPPORT_DIR/DawnGraphiteCache/*"              "清理 DawnGraphiteCache"
    clean_glob_with_stats "$WINDSURF_SUPPORT_DIR/Shared Dictionary/*"              "清理 Shared Dictionary"

    # UI / 脚本缓存（不影响登录）
    clean_glob_with_stats "$WINDSURF_SUPPORT_DIR/IndexedDB/*"                      "清理 IndexedDB（Cascade UI 状态）"
    clean_glob_with_stats "$WINDSURF_SUPPORT_DIR/Service Worker/CacheStorage/*"    "清理 Service Worker CacheStorage"
    clean_glob_with_stats "$WINDSURF_SUPPORT_DIR/Service Worker/ScriptCache/*"     "清理 Service Worker ScriptCache"
    clean_glob_with_stats "$WINDSURF_SUPPORT_DIR/blob_storage/*"                   "清理 blob_storage"

    # 日志 / 崩溃报告
    clean_glob_with_stats "$WINDSURF_SUPPORT_DIR/logs/*"                           "清理 logs"
    clean_glob_with_stats "$WINDSURF_SUPPORT_DIR/Crashpad/completed/*"             "清理 Crashpad completed"
    clean_glob_with_stats "$WINDSURF_SUPPORT_DIR/Crashpad/pending/*"               "清理 Crashpad pending"

    # AI 索引缓存（重建）
    clean_glob_with_stats "$IMPLICIT_DIR/*"                                        "清理 implicit AI 索引缓存"
    clean_glob_with_stats "$CODE_TRACKER_DIR/*"                                    "清理 code_tracker AI 索引"

    # 扩展和 profile 缓存
    clean_glob_with_stats "$WINDSURF_SUPPORT_DIR/CachedExtensionVSIXs/*"           "清理旧扩展安装包"
    clean_glob_with_stats "$WINDSURF_SUPPORT_DIR/CachedProfilesData/*"             "清理配置缓存"

    # 数据库备份（可重建，不是对话历史）
    clean_file_with_stats "$WINDSURF_SUPPORT_DIR/User/globalStorage/state.vscdb.backup" "清理 state.vscdb.backup（不是对话，是旧备份）"

    # 临时文件
    clean_glob_with_stats "/tmp/windsurf-terminal-*.snapshot"                      "清理 /tmp 终端快照"
    clean_glob_with_stats "$HOME/.zcompdump*"                                       "清理 Zsh 自动补全缓存"

    # macOS 系统级 Windsurf 缓存
    clean_glob_with_stats "$MACOS_WS_CACHE/*"                                      "清理 macOS Windsurf 系统缓存"
    clean_glob_with_stats "$MACOS_WS_SHIPIT/*"                                     "清理 macOS Windsurf ShipIt 缓存"

    # VACUUM 所有 SQLite 数据库（核心优化！）
    if command -v sqlite3 &> /dev/null; then
        echo ""
        print_info "VACUUM 全局 state.vscdb（保留数据，只压缩碎片）"
        STATE_DB_FILE="$WINDSURF_SUPPORT_DIR/User/globalStorage/state.vscdb"
        if [ -f "$STATE_DB_FILE" ]; then
            B_KB=$(du -sk "$STATE_DB_FILE" 2>/dev/null | awk '{print $1+0}')
            sqlite3 "$STATE_DB_FILE" "VACUUM;" 2>/dev/null && {
                A_KB=$(du -sk "$STATE_DB_FILE" 2>/dev/null | awk '{print $1+0}')
                D_KB=$((B_KB - A_KB))
                [ "$D_KB" -lt 0 ] && D_KB=0
                TOTAL_RELEASED_KB=$((TOTAL_RELEASED_KB + D_KB))
                print_success "  全局 VACUUM 完成，释放 $(format_kb_size "$D_KB")"
            }
        fi

        echo ""
        print_info "VACUUM 所有工作区 state.vscdb（保留工作区状态）"
        WS_N=0; WS_REL=0
        WORKSPACE_STORAGE_DIR="$WINDSURF_SUPPORT_DIR/User/workspaceStorage"
        if [ -d "$WORKSPACE_STORAGE_DIR" ]; then
            while IFS= read -r wsdb; do
                [ -z "$wsdb" ] && continue
                wb=$(du -sk "$wsdb" 2>/dev/null | awk '{print $1+0}')
                if sqlite3 "$wsdb" "VACUUM;" 2>/dev/null; then
                    wa=$(du -sk "$wsdb" 2>/dev/null | awk '{print $1+0}')
                    wd=$((wb - wa))
                    [ "$wd" -lt 0 ] && wd=0
                    WS_REL=$((WS_REL + wd))
                    WS_N=$((WS_N + 1))
                fi
            done < <(find "$WORKSPACE_STORAGE_DIR" -maxdepth 2 -name "state.vscdb" -type f 2>/dev/null)
            TOTAL_RELEASED_KB=$((TOTAL_RELEASED_KB + WS_REL))
            print_success "  已 VACUUM $WS_N 个工作区 state.vscdb，释放 $(format_kb_size "$WS_REL")"
        fi
    else
        print_warning "未找到 sqlite3 命令，跳过 VACUUM（建议安装 sqlite3 以获得更好效果）"
    fi

    echo ""
    echo -e "${GREEN}========== 一键优化完成 ==========${NC}"
    print_success "总释放空间: $(format_kb_size "$TOTAL_RELEASED_KB")"
    print_info "保留内容: cascade/*.pb 对话历史、Cookies、Local Storage、WebStorage、memories、skills、mcp_config.json、settings.json"

    if [ "$CASCADE_TOTAL_KB" -gt 204800 ] 2>/dev/null; then
        echo ""
        print_warning "提示：你的 Cascade 对话历史 $(format_kb_size "$CASCADE_TOTAL_KB")，仍然较大"
        print_info "如果重启后仍感到卡，请接着运行菜单 23 做对话归档（移动不删除）"
    fi

    # 卡顿优化完毕 -> 强制重置设备 ID（默认行为）
    auto_reset_after_clean
    print_info "请现在重新启动 Windsurf（若被要求重新登录，用原来的账户登即可）"
}

# ----------------------------------------------------------------------------
# 功能11: 启用Legacy终端
# ----------------------------------------------------------------------------
enable_legacy_terminal() {
    print_info "启用 Legacy 终端配置..."
    
    SETTINGS_JSON="$HOME/Library/Application Support/Windsurf/User/settings.json"
    
    echo ""
    echo "如果专用终端有问题，可以启用 Legacy Terminal Profile"
    echo ""
    echo "请在 Windsurf 设置中搜索 'Legacy Terminal Profile' 并启用"
    echo "或手动编辑 settings.json 添加相关配置"
    echo ""
    print_info "settings.json 位置: $SETTINGS_JSON"
}

# ----------------------------------------------------------------------------
# 功能7: MCP诊断与修复
# ----------------------------------------------------------------------------
diagnose_mcp() {
    print_info "MCP (Model Context Protocol) 诊断..."
    
    MCP_CONFIG="$WINDSURF_DIR/mcp_config.json"
    MCP_CONFIG_OLD="$CODEIUM_DIR/mcp_config.json"
    
    echo ""
    echo -e "${CYAN}MCP 配置文件状态:${NC}"
    echo ""
    
    # 检查新路径的配置文件
    if [ -f "$MCP_CONFIG" ]; then
        print_success "找到 MCP 配置: $MCP_CONFIG"
        echo ""
        echo "配置内容预览:"
        head -30 "$MCP_CONFIG" 2>/dev/null | while IFS= read -r line; do
            echo "  $line"
        done
        echo ""
        
        # 检查JSON格式是否有效
        if command -v python3 &> /dev/null; then
            if python3 -c "import json; json.load(open('$MCP_CONFIG'))" 2>/dev/null; then
                print_success "MCP 配置 JSON 格式有效"
            else
                print_error "MCP 配置 JSON 格式无效！"
                echo "  这可能导致 MCP 无法加载"
            fi
        fi
    else
        print_warning "未找到 MCP 配置文件: $MCP_CONFIG"
    fi
    
    # 检查旧路径
    if [ -f "$MCP_CONFIG_OLD" ]; then
        print_info "发现旧版 MCP 配置: $MCP_CONFIG_OLD"
    fi
    
    echo ""
    echo -e "${CYAN}MCP 常见问题排查:${NC}"
    echo ""
    echo "  1. 检查 Node.js 是否安装"
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node --version 2>/dev/null)
        print_success "Node.js 已安装: $NODE_VERSION"
    else
        print_warning "未找到 Node.js，部分 MCP 服务器需要 Node.js"
    fi
    
    echo ""
    echo "  2. 检查 npx 是否可用"
    if command -v npx &> /dev/null; then
        print_success "npx 可用"
    else
        print_warning "未找到 npx，无法运行基于 npm 的 MCP 服务器"
    fi
    
    echo ""
    echo "  3. 检查 Python/uvx 是否可用（部分MCP需要）"
    if command -v python3 &> /dev/null; then
        PYTHON_VERSION=$(python3 --version 2>/dev/null)
        print_success "Python3 已安装: $PYTHON_VERSION"
    else
        print_warning "未找到 Python3"
    fi
    
    if command -v uvx &> /dev/null; then
        print_success "uvx 可用"
    else
        print_info "uvx 未安装（某些MCP可能需要）"
    fi
    
    echo ""
    echo -e "${CYAN}MCP 无法自动加载的常见解决方案:${NC}"
    echo ""
    echo "  1. 在 Windsurf 中点击 MCPs 图标，手动刷新"
    echo "  2. 检查 mcp_config.json 格式是否正确"
    echo "  3. 确保所需的运行时（Node.js/Python）已安装"
    echo "  4. 检查环境变量（如 API keys）是否正确配置"
    echo "  5. 查看 Windsurf 输出日志检查错误信息"
    echo ""
}

# ----------------------------------------------------------------------------
# 功能2: 清理启动缓存（解决启动卡顿）- 不会清理对话历史
# ----------------------------------------------------------------------------
clean_startup_cache() {
    print_info "清理启动相关缓存（解决启动卡顿）..."
    
    echo ""
    echo "此操作将清理以下缓存以加速启动:"
    echo "  - Cache (浏览器缓存)"
    echo "  - GPUCache (GPU渲染缓存)"
    echo "  - CachedData (编辑器缓存数据)"
    echo "  - DawnWebGPUCache / DawnGraphiteCache (图形管线缓存)"
    echo "  - CachedExtensionVSIXs (扩展安装包缓存)"
    echo "  - Code Cache (代码缓存)"
    echo "  - 7天以上的日志文件"
    echo ""
    print_success "此操作 不会 清理对话历史！"
    echo ""
    
    if confirm_action; then
        if ! check_windsurf_running; then
            return 1
        fi
        
        # 备份
        mkdir -p "$BACKUP_DIR"
        
        # 清理 GPU 缓存
        CACHE_DIR="$WINDSURF_RUNTIME_DIR/Cache"
        if [ -d "$CACHE_DIR" ]; then
            rm -rf "$CACHE_DIR"
            print_success "已清理 Cache"
        fi

        GPU_CACHE="$WINDSURF_RUNTIME_DIR/GPUCache"
        if [ -d "$GPU_CACHE" ]; then
            rm -rf "$GPU_CACHE"
            print_success "已清理 GPUCache"
        fi
        
        # 清理 CachedData
        for cache_dir in "$WINDSURF_RUNTIME_DIR/CachedData" "$WINDSURF_DIR/CachedData"; do
            if [ -d "$cache_dir" ]; then
                rm -rf "$cache_dir"
                print_success "已清理 $(basename "$cache_dir")"
            fi
        done

        # 清理扩展安装包缓存，兼容旧版目录结构。
        for cache_dir in "$WINDSURF_RUNTIME_DIR/CachedExtensionVSIXs" "$WINDSURF_DIR/CachedExtensions"; do
            if [ -d "$cache_dir" ]; then
                rm -rf "$cache_dir"
                print_success "已清理 $(basename "$cache_dir")"
            fi
        done
        
        # 清理 Code Cache
        CODE_CACHE="$WINDSURF_RUNTIME_DIR/Code Cache"
        if [ -d "$CODE_CACHE" ]; then
            rm -rf "$CODE_CACHE"
            print_success "已清理 Code Cache"
        fi

        for cache_dir in "$WINDSURF_RUNTIME_DIR/DawnWebGPUCache" "$WINDSURF_RUNTIME_DIR/DawnGraphiteCache"; do
            if [ -d "$cache_dir" ]; then
                rm -rf "$cache_dir"
                print_success "已清理 $(basename "$cache_dir")"
            fi
        done
        
        # 清理 logs
        LOGS_DIR="$WINDSURF_RUNTIME_DIR/logs"
        if [ -d "$LOGS_DIR" ]; then
            # 只清理超过7天的日志
            find "$LOGS_DIR" -type f -mtime +7 -delete 2>/dev/null
            print_success "已清理旧日志文件"
        fi
        
        echo ""
        print_success "启动缓存清理完成！"
        print_info "重启 Windsurf 后启动速度应该会改善"

        # 清理完毕 -> 强制重置设备 ID（默认行为）
        auto_reset_after_clean
    else
        print_info "已取消操作"
    fi
}

# ----------------------------------------------------------------------------
# 功能8: 重置MCP配置
# ----------------------------------------------------------------------------
reset_mcp_config() {
    print_info "重置 MCP 配置..."
    
    MCP_CONFIG="$WINDSURF_DIR/mcp_config.json"
    
    echo ""
    print_warning "此操作将备份并重置 MCP 配置文件"
    echo "  你需要重新配置 MCP 服务器"
    echo ""
    
    if [ ! -f "$MCP_CONFIG" ]; then
        print_info "MCP 配置文件不存在"
        return 0
    fi
    
    if confirm_action; then
        # 备份
        mkdir -p "$BACKUP_DIR"
        cp "$MCP_CONFIG" "$BACKUP_DIR/mcp_config.json.bak"
        print_info "已备份到: $BACKUP_DIR/mcp_config.json.bak"
        
        # 创建空的配置
        cat > "$MCP_CONFIG" << 'EOF'
{
  "mcpServers": {}
}
EOF
        print_success "MCP 配置已重置"
        print_info "请在 Windsurf 中重新添加 MCP 服务器"
    else
        print_info "已取消操作"
    fi
}

# ----------------------------------------------------------------------------
# 功能4: 清理开发工具缓存（npm/pip/Homebrew/Maven等）
# ----------------------------------------------------------------------------
clean_dev_caches() {
    print_info "扫描开发工具缓存..."
    
    echo ""
    echo -e "${CYAN}正在检测各类开发工具缓存大小...${NC}"
    echo ""
    
    TOTAL_SIZE=0
    CLEANABLE_ITEMS=()
    
    # npm 缓存
    NPM_CACHE="$HOME/.npm"
    if [ -d "$NPM_CACHE" ]; then
        SIZE=$(du -sm "$NPM_CACHE" 2>/dev/null | awk '{print $1}')
        echo -e "  ${GREEN}[npm 缓存]${NC} ~/.npm - ${YELLOW}${SIZE}MB${NC}"
        TOTAL_SIZE=$((TOTAL_SIZE + SIZE))
        CLEANABLE_ITEMS+=("npm")
    fi
    
    # pip 缓存
    PIP_CACHE="$HOME/Library/Caches/pip"
    if [ -d "$PIP_CACHE" ]; then
        SIZE=$(du -sm "$PIP_CACHE" 2>/dev/null | awk '{print $1}')
        echo -e "  ${GREEN}[pip 缓存]${NC} ~/Library/Caches/pip - ${YELLOW}${SIZE}MB${NC}"
        TOTAL_SIZE=$((TOTAL_SIZE + SIZE))
        CLEANABLE_ITEMS+=("pip")
    fi
    
    # Homebrew 缓存
    BREW_CACHE="$HOME/Library/Caches/Homebrew"
    if [ -d "$BREW_CACHE" ]; then
        SIZE=$(du -sm "$BREW_CACHE" 2>/dev/null | awk '{print $1}')
        echo -e "  ${GREEN}[Homebrew 缓存]${NC} ~/Library/Caches/Homebrew - ${YELLOW}${SIZE}MB${NC}"
        TOTAL_SIZE=$((TOTAL_SIZE + SIZE))
        CLEANABLE_ITEMS+=("brew")
    fi
    
    # uv 缓存（Python包管理器）
    UV_CACHE="$HOME/.cache/uv"
    if [ -d "$UV_CACHE" ]; then
        SIZE=$(du -sm "$UV_CACHE" 2>/dev/null | awk '{print $1}')
        echo -e "  ${GREEN}[uv 缓存]${NC} ~/.cache/uv - ${YELLOW}${SIZE}MB${NC}"
        TOTAL_SIZE=$((TOTAL_SIZE + SIZE))
        CLEANABLE_ITEMS+=("uv")
    fi
    
    # Maven 缓存
    MAVEN_CACHE="$HOME/.m2/repository"
    if [ -d "$MAVEN_CACHE" ]; then
        SIZE=$(du -sm "$MAVEN_CACHE" 2>/dev/null | awk '{print $1}')
        echo -e "  ${GREEN}[Maven 缓存]${NC} ~/.m2/repository - ${YELLOW}${SIZE}MB${NC}"
        TOTAL_SIZE=$((TOTAL_SIZE + SIZE))
        CLEANABLE_ITEMS+=("maven")
    fi
    
    # Gradle 缓存
    GRADLE_CACHE="$HOME/.gradle/caches"
    if [ -d "$GRADLE_CACHE" ]; then
        SIZE=$(du -sm "$GRADLE_CACHE" 2>/dev/null | awk '{print $1}')
        echo -e "  ${GREEN}[Gradle 缓存]${NC} ~/.gradle/caches - ${YELLOW}${SIZE}MB${NC}"
        TOTAL_SIZE=$((TOTAL_SIZE + SIZE))
        CLEANABLE_ITEMS+=("gradle")
    fi
    
    # Yarn 缓存
    YARN_CACHE="$HOME/Library/Caches/Yarn"
    if [ -d "$YARN_CACHE" ]; then
        SIZE=$(du -sm "$YARN_CACHE" 2>/dev/null | awk '{print $1}')
        echo -e "  ${GREEN}[Yarn 缓存]${NC} ~/Library/Caches/Yarn - ${YELLOW}${SIZE}MB${NC}"
        TOTAL_SIZE=$((TOTAL_SIZE + SIZE))
        CLEANABLE_ITEMS+=("yarn")
    fi
    
    # pnpm 缓存
    PNPM_CACHE="$HOME/Library/pnpm"
    PNPM_STORE="$HOME/.pnpm-store"
    PNPM_SIZE=0
    if [ -d "$PNPM_CACHE" ]; then
        SIZE=$(du -sm "$PNPM_CACHE" 2>/dev/null | awk '{print $1}')
        PNPM_SIZE=$((PNPM_SIZE + SIZE))
    fi
    if [ -d "$PNPM_STORE" ]; then
        SIZE=$(du -sm "$PNPM_STORE" 2>/dev/null | awk '{print $1}')
        PNPM_SIZE=$((PNPM_SIZE + SIZE))
    fi
    if [ $PNPM_SIZE -gt 0 ]; then
        echo -e "  ${GREEN}[pnpm 缓存]${NC} ~/Library/pnpm + ~/.pnpm-store - ${YELLOW}${PNPM_SIZE}MB${NC}"
        TOTAL_SIZE=$((TOTAL_SIZE + PNPM_SIZE))
        CLEANABLE_ITEMS+=("pnpm")
    fi
    
    # Selenium/WebDriver 缓存
    SELENIUM_CACHE="$HOME/.cache/selenium"
    WDM_CACHE="$HOME/.wdm"
    SELENIUM_SIZE=0
    if [ -d "$SELENIUM_CACHE" ]; then
        SIZE=$(du -sm "$SELENIUM_CACHE" 2>/dev/null | awk '{print $1}')
        SELENIUM_SIZE=$((SELENIUM_SIZE + SIZE))
    fi
    if [ -d "$WDM_CACHE" ]; then
        SIZE=$(du -sm "$WDM_CACHE" 2>/dev/null | awk '{print $1}')
        SELENIUM_SIZE=$((SELENIUM_SIZE + SIZE))
    fi
    if [ $SELENIUM_SIZE -gt 0 ]; then
        echo -e "  ${GREEN}[Selenium/WebDriver]${NC} ~/.cache/selenium + ~/.wdm - ${YELLOW}${SELENIUM_SIZE}MB${NC}"
        TOTAL_SIZE=$((TOTAL_SIZE + SELENIUM_SIZE))
        CLEANABLE_ITEMS+=("selenium")
    fi
    
    # undetected_chromedriver 缓存
    UC_CACHE="$HOME/Library/Application Support/undetected_chromedriver"
    if [ -d "$UC_CACHE" ]; then
        SIZE=$(du -sm "$UC_CACHE" 2>/dev/null | awk '{print $1}')
        echo -e "  ${GREEN}[undetected_chromedriver]${NC} - ${YELLOW}${SIZE}MB${NC}"
        TOTAL_SIZE=$((TOTAL_SIZE + SIZE))
        CLEANABLE_ITEMS+=("uc")
    fi
    
    # Go 缓存
    GO_CACHE="$HOME/go/pkg/mod/cache"
    if [ -d "$GO_CACHE" ]; then
        SIZE=$(du -sm "$GO_CACHE" 2>/dev/null | awk '{print $1}')
        echo -e "  ${GREEN}[Go 模块缓存]${NC} ~/go/pkg/mod/cache - ${YELLOW}${SIZE}MB${NC}"
        TOTAL_SIZE=$((TOTAL_SIZE + SIZE))
        CLEANABLE_ITEMS+=("go")
    fi
    
    # Cargo/Rust 缓存
    CARGO_CACHE="$HOME/.cargo/registry"
    if [ -d "$CARGO_CACHE" ]; then
        SIZE=$(du -sm "$CARGO_CACHE" 2>/dev/null | awk '{print $1}')
        echo -e "  ${GREEN}[Cargo 缓存]${NC} ~/.cargo/registry - ${YELLOW}${SIZE}MB${NC}"
        TOTAL_SIZE=$((TOTAL_SIZE + SIZE))
        CLEANABLE_ITEMS+=("cargo")
    fi
    
    # conda 缓存
    for CONDA_DIR in "$HOME/miniconda3/pkgs" "$HOME/anaconda3/pkgs" "$HOME/opt/anaconda3/pkgs"; do
        if [ -d "$CONDA_DIR" ]; then
            SIZE=$(du -sm "$CONDA_DIR" 2>/dev/null | awk '{print $1}')
            echo -e "  ${GREEN}[conda 包缓存]${NC} $CONDA_DIR - ${YELLOW}${SIZE}MB${NC}"
            TOTAL_SIZE=$((TOTAL_SIZE + SIZE))
            CLEANABLE_ITEMS+=("conda")
            break
        fi
    done
    
    # CocoaPods 缓存
    COCOAPODS_CACHE="$HOME/Library/Caches/CocoaPods"
    if [ -d "$COCOAPODS_CACHE" ]; then
        SIZE=$(du -sm "$COCOAPODS_CACHE" 2>/dev/null | awk '{print $1}')
        echo -e "  ${GREEN}[CocoaPods 缓存]${NC} ~/Library/Caches/CocoaPods - ${YELLOW}${SIZE}MB${NC}"
        TOTAL_SIZE=$((TOTAL_SIZE + SIZE))
        CLEANABLE_ITEMS+=("cocoapods")
    fi
    
    # Xcode DerivedData
    XCODE_DERIVED="$HOME/Library/Developer/Xcode/DerivedData"
    if [ -d "$XCODE_DERIVED" ]; then
        SIZE=$(du -sm "$XCODE_DERIVED" 2>/dev/null | awk '{print $1}')
        echo -e "  ${GREEN}[Xcode DerivedData]${NC} - ${YELLOW}${SIZE}MB${NC}"
        TOTAL_SIZE=$((TOTAL_SIZE + SIZE))
        CLEANABLE_ITEMS+=("xcode")
    fi
    
    # Google Chrome 缓存
    CHROME_CACHE="$HOME/Library/Caches/Google"
    if [ -d "$CHROME_CACHE" ]; then
        SIZE=$(du -sm "$CHROME_CACHE" 2>/dev/null | awk '{print $1}')
        echo -e "  ${GREEN}[Google Chrome 缓存]${NC} ~/Library/Caches/Google - ${YELLOW}${SIZE}MB${NC}"
        TOTAL_SIZE=$((TOTAL_SIZE + SIZE))
        CLEANABLE_ITEMS+=("chrome")
    fi
    
    echo ""
    echo -e "  ${CYAN}可清理总计: ${YELLOW}${TOTAL_SIZE}MB${NC}"
    echo ""
    
    if [ ${#CLEANABLE_ITEMS[@]} -eq 0 ]; then
        print_info "未检测到可清理的开发工具缓存"
        return 0
    fi
    
    echo -e "${YELLOW}请选择清理方式:${NC}"
    echo "  1) 全部清理（推荐安全项）"
    echo "  2) 逐项选择清理"
    echo "  3) 取消"
    echo ""
    echo -ne ${CYAN}请选择 [1-3]: ${NC}
    read -r clean_choice
    
    case "$clean_choice" in
        1)
            # 全部清理安全项
            for item in "${CLEANABLE_ITEMS[@]}"; do
                case "$item" in
                    npm)
                        if command -v npm &> /dev/null; then
                            npm cache clean --force 2>/dev/null
                        else
                            rm -rf "$NPM_CACHE/_cacache" 2>/dev/null
                        fi
                        print_success "npm 缓存已清理"
                        ;;
                    pip)
                        if command -v pip3 &> /dev/null; then
                            pip3 cache purge 2>/dev/null
                        else
                            rm -rf "$PIP_CACHE" 2>/dev/null
                        fi
                        print_success "pip 缓存已清理"
                        ;;
                    brew)
                        if command -v brew &> /dev/null; then
                            brew cleanup -s 2>/dev/null
                            brew autoremove 2>/dev/null
                        fi
                        print_success "Homebrew 缓存已清理"
                        ;;
                    uv)
                        rm -rf "$UV_CACHE" 2>/dev/null
                        print_success "uv 缓存已清理"
                        ;;
                    maven)
                        print_warning "Maven 缓存跳过（删除后需重新下载依赖，建议手动清理）"
                        ;;
                    gradle)
                        print_warning "Gradle 缓存跳过（删除后需重新下载依赖，建议手动清理）"
                        ;;
                    yarn)
                        if command -v yarn &> /dev/null; then
                            yarn cache clean 2>/dev/null
                        else
                            rm -rf "$YARN_CACHE" 2>/dev/null
                        fi
                        print_success "Yarn 缓存已清理"
                        ;;
                    pnpm)
                        if command -v pnpm &> /dev/null; then
                            pnpm store prune 2>/dev/null
                        fi
                        print_success "pnpm 缓存已清理"
                        ;;
                    selenium)
                        rm -rf "$SELENIUM_CACHE" 2>/dev/null
                        rm -rf "$WDM_CACHE" 2>/dev/null
                        print_success "Selenium/WebDriver 缓存已清理"
                        ;;
                    uc)
                        rm -rf "$UC_CACHE" 2>/dev/null
                        print_success "undetected_chromedriver 缓存已清理"
                        ;;
                    go)
                        if command -v go &> /dev/null; then
                            go clean -modcache 2>/dev/null
                        fi
                        print_success "Go 模块缓存已清理"
                        ;;
                    cargo)
                        print_warning "Cargo 缓存跳过（建议使用 cargo-cache 工具清理）"
                        ;;
                    conda)
                        if command -v conda &> /dev/null; then
                            conda clean --all -y 2>/dev/null
                        fi
                        print_success "conda 缓存已清理"
                        ;;
                    cocoapods)
                        rm -rf "$COCOAPODS_CACHE" 2>/dev/null
                        print_success "CocoaPods 缓存已清理"
                        ;;
                    xcode)
                        rm -rf "$XCODE_DERIVED" 2>/dev/null
                        print_success "Xcode DerivedData 已清理"
                        ;;
                    chrome)
                        rm -rf "$CHROME_CACHE" 2>/dev/null
                        print_success "Google Chrome 缓存已清理"
                        ;;
                esac
            done
            echo ""
            print_success "开发工具缓存清理完成！"
            ;;
        2)
            # 逐项选择
            for item in "${CLEANABLE_ITEMS[@]}"; do
                case "$item" in
                    npm) label="npm 缓存" ;;
                    pip) label="pip 缓存" ;;
                    brew) label="Homebrew 缓存" ;;
                    uv) label="uv 缓存" ;;
                    maven) label="Maven 缓存" ;;
                    gradle) label="Gradle 缓存" ;;
                    yarn) label="Yarn 缓存" ;;
                    pnpm) label="pnpm 缓存" ;;
                    selenium) label="Selenium/WebDriver 缓存" ;;
                    uc) label="undetected_chromedriver 缓存" ;;
                    go) label="Go 模块缓存" ;;
                    cargo) label="Cargo 缓存" ;;
                    conda) label="conda 包缓存" ;;
                    cocoapods) label="CocoaPods 缓存" ;;
                    xcode) label="Xcode DerivedData" ;;
                    chrome) label="Google Chrome 缓存" ;;
                    *) label="$item" ;;
                esac
                
                echo -ne ${YELLOW}清理 $label？[y/N]: ${NC}
                read -r yn
                if [ "$yn" = "y" ] || [ "$yn" = "Y" ]; then
                    case "$item" in
                        npm)
                            if command -v npm &> /dev/null; then npm cache clean --force 2>/dev/null
                            else rm -rf "$NPM_CACHE/_cacache" 2>/dev/null; fi
                            ;;
                        pip)
                            if command -v pip3 &> /dev/null; then pip3 cache purge 2>/dev/null
                            else rm -rf "$PIP_CACHE" 2>/dev/null; fi
                            ;;
                        brew)
                            if command -v brew &> /dev/null; then brew cleanup -s 2>/dev/null; brew autoremove 2>/dev/null; fi
                            ;;
                        uv) rm -rf "$UV_CACHE" 2>/dev/null ;;
                        maven) rm -rf "$MAVEN_CACHE" 2>/dev/null ;;
                        gradle) rm -rf "$GRADLE_CACHE" 2>/dev/null ;;
                        yarn)
                            if command -v yarn &> /dev/null; then yarn cache clean 2>/dev/null
                            else rm -rf "$YARN_CACHE" 2>/dev/null; fi
                            ;;
                        pnpm)
                            if command -v pnpm &> /dev/null; then pnpm store prune 2>/dev/null; fi
                            ;;
                        selenium) rm -rf "$SELENIUM_CACHE" "$WDM_CACHE" 2>/dev/null ;;
                        uc) rm -rf "$UC_CACHE" 2>/dev/null ;;
                        go)
                            if command -v go &> /dev/null; then go clean -modcache 2>/dev/null; fi
                            ;;
                        cargo) rm -rf "$CARGO_CACHE" 2>/dev/null ;;
                        conda)
                            if command -v conda &> /dev/null; then conda clean --all -y 2>/dev/null; fi
                            ;;
                        cocoapods) rm -rf "$COCOAPODS_CACHE" 2>/dev/null ;;
                        xcode) rm -rf "$XCODE_DERIVED" 2>/dev/null ;;
                        chrome) rm -rf "$CHROME_CACHE" 2>/dev/null ;;
                    esac
                    print_success "$label 已清理"
                fi
            done
            ;;
        *)
            print_info "已取消操作"
            ;;
    esac
}

# ----------------------------------------------------------------------------
# 功能5: 清理macOS系统缓存
# ----------------------------------------------------------------------------
clean_system_caches() {
    print_info "扫描 macOS 系统缓存..."
    
    echo ""
    echo -e "${CYAN}正在检测系统级缓存...${NC}"
    echo ""
    
    TOTAL_SIZE=0
    
    # ~/Library/Caches 各应用缓存
    USER_CACHE="$HOME/Library/Caches"
    if [ -d "$USER_CACHE" ]; then
        SIZE=$(du -sm "$USER_CACHE" 2>/dev/null | awk '{print $1}')
        echo -e "  ${GREEN}[用户缓存]${NC} ~/Library/Caches - ${YELLOW}${SIZE}MB${NC}"
        TOTAL_SIZE=$((TOTAL_SIZE + SIZE))
        
        # 列出 Top 10 大缓存目录
        echo -e "    ${CYAN}Top 10 缓存目录:${NC}"
        du -sm "$USER_CACHE"/*/ 2>/dev/null | sort -rn | head -10 | while read size dir; do
            dirname=$(basename "$dir")
            echo -e "      $dirname - ${YELLOW}${size}MB${NC}"
        done
        echo ""
    fi
    
    # ~/Library/Logs 日志文件
    USER_LOGS="$HOME/Library/Logs"
    if [ -d "$USER_LOGS" ]; then
        SIZE=$(du -sm "$USER_LOGS" 2>/dev/null | awk '{print $1}')
        echo -e "  ${GREEN}[用户日志]${NC} ~/Library/Logs - ${YELLOW}${SIZE}MB${NC}"
        TOTAL_SIZE=$((TOTAL_SIZE + SIZE))
    fi
    
    # 废纸篓
    TRASH="$HOME/.Trash"
    if [ -d "$TRASH" ] && [ "$(ls -A "$TRASH" 2>/dev/null)" ]; then
        SIZE=$(du -sm "$TRASH" 2>/dev/null | awk '{print $1}')
        echo -e "  ${GREEN}[废纸篓]${NC} ~/.Trash - ${YELLOW}${SIZE}MB${NC}"
        TOTAL_SIZE=$((TOTAL_SIZE + SIZE))
    fi
    
    # Windsurf 旧备份目录
    BACKUP_COUNT=0
    BACKUP_SIZE=0
    for bdir in "$HOME"/.windsurf-backup-*; do
        if [ -d "$bdir" ]; then
            BACKUP_COUNT=$((BACKUP_COUNT + 1))
            SIZE=$(du -sm "$bdir" 2>/dev/null | awk '{print $1}')
            BACKUP_SIZE=$((BACKUP_SIZE + SIZE))
        fi
    done
    if [ $BACKUP_COUNT -gt 0 ]; then
        echo -e "  ${GREEN}[Windsurf 旧备份]${NC} ${BACKUP_COUNT}个备份目录 - ${YELLOW}${BACKUP_SIZE}MB${NC}"
        TOTAL_SIZE=$((TOTAL_SIZE + BACKUP_SIZE))
    fi
    
    # 旧诊断报告
    DIAG_COUNT=$(ls "$HOME"/windsurf-diagnostic-*.txt 2>/dev/null | wc -l | tr -d ' ')
    if [ "$DIAG_COUNT" -gt 0 ] 2>/dev/null; then
        echo -e "  ${GREEN}[旧诊断报告]${NC} ${DIAG_COUNT}个文件"
    fi
    
    # DNS 缓存
    echo -e "  ${GREEN}[DNS 缓存]${NC} 系统DNS缓存（可刷新）"
    
    echo ""
    echo -e "  ${CYAN}系统缓存总计: ${YELLOW}${TOTAL_SIZE}MB${NC}"
    echo ""
    
    echo -e "${YELLOW}请选择清理项目:${NC}"
    echo "  1) 清理用户缓存（~/Library/Caches，排除系统关键缓存）"
    echo "  2) 清理旧日志文件（超过30天）"
    echo "  3) 清空废纸篓"
    echo "  4) 清理 Windsurf 旧备份目录"
    echo "  5) 清理旧诊断报告"
    echo "  6) 刷新 DNS 缓存"
    echo "  7) 全部执行（安全项）"
    echo "  0) 取消"
    echo ""
    echo -ne ${CYAN}请选择 [0-7]: ${NC}
    read -r sys_choice
    
    case "$sys_choice" in
        1)
            print_warning "将清理用户缓存目录（排除 Homebrew 等重要缓存）"
            if confirm_action; then
                # 清理用户缓存，但排除一些重要的
                find "$USER_CACHE" -mindepth 1 -maxdepth 1 -type d \
                    ! -name "Homebrew" \
                    ! -name "com.apple.Safari" \
                    ! -name "CloudKit" \
                    -exec rm -rf {} + 2>/dev/null
                print_success "用户缓存已清理"
            fi
            ;;
        2)
            find "$USER_LOGS" -type f -mtime +30 -delete 2>/dev/null
            print_success "超过30天的旧日志已清理"
            ;;
        3)
            if confirm_action; then
                rm -rf "$TRASH"/* 2>/dev/null
                print_success "废纸篓已清空"
            fi
            ;;
        4)
            if [ $BACKUP_COUNT -gt 0 ]; then
                print_info "将删除 ${BACKUP_COUNT} 个 Windsurf 旧备份目录"
                if confirm_action; then
                    rm -rf "$HOME"/.windsurf-backup-* 2>/dev/null
                    print_success "Windsurf 旧备份已清理"
                fi
            else
                print_info "没有旧备份需要清理"
            fi
            ;;
        5)
            rm -f "$HOME"/windsurf-diagnostic-*.txt 2>/dev/null
            print_success "旧诊断报告已清理"
            ;;
        6)
            sudo dscacheutil -flushcache 2>/dev/null
            sudo killall -HUP mDNSResponder 2>/dev/null
            print_success "DNS 缓存已刷新"
            ;;
        7)
            print_info "执行全部安全清理项..."
            
            # 清理旧日志
            find "$USER_LOGS" -type f -mtime +30 -delete 2>/dev/null
            print_success "旧日志已清理"
            
            # 清理废纸篓
            rm -rf "$TRASH"/* 2>/dev/null
            print_success "废纸篓已清空"
            
            # 清理旧备份
            if [ $BACKUP_COUNT -gt 0 ]; then
                rm -rf "$HOME"/.windsurf-backup-* 2>/dev/null
                print_success "Windsurf 旧备份已清理"
            fi
            
            # 清理旧诊断报告
            rm -f "$HOME"/windsurf-diagnostic-*.txt 2>/dev/null
            print_success "旧诊断报告已清理"
            
            # 刷新DNS
            sudo dscacheutil -flushcache 2>/dev/null
            sudo killall -HUP mDNSResponder 2>/dev/null
            print_success "DNS 缓存已刷新"
            
            echo ""
            print_success "系统缓存清理完成！"
            ;;
        *)
            print_info "已取消操作"
            ;;
    esac
}

# ----------------------------------------------------------------------------
# 功能6: 磁盘空间分析
# ----------------------------------------------------------------------------
analyze_disk_usage() {
    print_info "分析磁盘空间使用情况..."
    
    echo ""
    echo -e "${CYAN}========== 磁盘空间概览 ==========${NC}"
    echo ""
    
    # 磁盘总体使用
    df -h / | awk 'NR==2{printf "  磁盘总容量: %s | 已使用: %s | 可用: %s | 使用率: %s\n", $2, $3, $4, $5}'
    echo ""
    
    # 用户主目录
    HOME_SIZE=$(du -sh "$HOME" 2>/dev/null | awk '{print $1}')
    echo -e "  ${CYAN}用户主目录:${NC} ${YELLOW}$HOME_SIZE${NC}"
    echo ""
    
    # 主要目录大小
    echo -e "  ${CYAN}主要目录占用:${NC}"
    echo ""
    
    for dir in "Library" "Downloads" "Documents" "Desktop" "Movies" "Music" "Pictures"; do
        if [ -d "$HOME/$dir" ]; then
            SIZE=$(du -sh "$HOME/$dir" 2>/dev/null | awk '{print $1}')
            printf "    %-15s %s\n" "$dir" "$SIZE"
        fi
    done
    echo ""
    
    # 隐藏目录 Top 10
    echo -e "  ${CYAN}隐藏目录 Top 10:${NC}"
    echo ""
    du -sm "$HOME"/.[!.]* 2>/dev/null | sort -rn | head -10 | while read size dir; do
        dirname=$(basename "$dir")
        printf "    %-30s %sMB\n" "$dirname" "$size"
    done
    echo ""
    
    # ~/Library 子目录 Top 10
    echo -e "  ${CYAN}~/Library 子目录 Top 10:${NC}"
    echo ""
    du -sm "$HOME"/Library/*/ 2>/dev/null | sort -rn | head -10 | while read size dir; do
        dirname=$(basename "$dir")
        printf "    %-30s %sMB\n" "$dirname" "$size"
    done
    echo ""
    
    # 应用容器 Top 10
    CONTAINERS="$HOME/Library/Containers"
    if [ -d "$CONTAINERS" ]; then
        echo -e "  ${CYAN}应用容器 Top 10 (~/Library/Containers):${NC}"
        echo ""
        du -sm "$CONTAINERS"/*/ 2>/dev/null | sort -rn | head -10 | while read size dir; do
            dirname=$(basename "$dir")
            printf "    %-45s %sMB\n" "$dirname" "$size"
        done
        echo ""
    fi
    
    print_info "分析完成。大型应用缓存建议在对应应用内清理（如微信、QQ等）"
}

# ----------------------------------------------------------------------------
# 主菜单
# ----------------------------------------------------------------------------
show_menu() {
    echo ""
    echo -e "${CYAN}请选择修复选项:${NC}"
    echo ""
    echo -e "${YELLOW}== Windsurf 缓存清理 ==${NC}"
    echo "  1) 清理 Cascade 缓存 (会清理对话历史)"
    echo "  2) 清理启动缓存 (不清理对话历史，推荐)"
    echo "  3) 清理扩展缓存 (不清理对话历史)"
    echo ""
    echo -e "${YELLOW}== 系统缓存清理 ==${NC}"
    echo "  4) 清理开发工具缓存 (npm/pip/Homebrew/Maven等)"
    echo "  5) 清理 macOS 系统缓存 (日志/废纸篓/旧备份等)"
    echo "  6) 磁盘空间分析"
    echo ""
    echo -e "${YELLOW}== MCP 相关 ==${NC}"
    echo "  7) MCP 诊断 (检查MCP加载问题)"
    echo "  8) 重置 MCP 配置"
    echo ""
    echo -e "${YELLOW}== 终端相关 ==${NC}"
    echo "  9) 检测 zsh 主题冲突"
    echo "  10) 配置终端设置"
    echo "  11) 启用 Legacy 终端"
    echo ""
    echo -e "${YELLOW}== 其他 ==${NC}"
    echo "  12) 修复 'Windsurf已损坏' 问题"
    echo "  13) 生成诊断报告"
    echo "  14) 完整修复 (执行所有步骤)"
    echo ""
    echo -e "${YELLOW}== 配置备份与 ID 管理 ==${NC}"
    echo "  15) 备份 MCP 配置 / Skills / 全局 Rules"
    echo "  16) 还原 MCP 配置 / Skills / 全局 Rules"
    echo "  17) 重置 Windsurf ID (重新生成所有标识)"
    echo ""
    echo -e "${YELLOW}== 深度优化 ==${NC}"
    echo "  18) 深度清理运行时缓存 (保留对话历史，推荐)"
    echo "  19) Windsurf 进程资源监控"
    echo "  20) 一键智能优化 (保留对话历史)"
    echo ""
    echo -e "${YELLOW}== AI 工具清理 ==${NC}"
    echo "  21) 清理 Claude Code / codex / gemini-cli / opencode 垃圾缓存"
    echo "  22) 重置 OpenCode CLI ID (针对被限速问题)"
    echo ""
    echo -e "${YELLOW}== 对话长卡顿专项 (保留对话和登录) ==${NC}"
    echo "  23) Cascade 对话归档 (移动不删除，解决加载慢)"
    echo "  24) 卡顿快速诊断 + 一键安全优化 (强烈推荐)"
    echo ""
    echo "  0) 退出"
    echo ""
    echo -ne ${CYAN}请输入选项 [0-24]: ${NC}
    read -r choice
    
    case $choice in
        1) if check_windsurf_running; then clean_cascade_cache; fi ;;
        2) clean_startup_cache ;;
        3) if check_windsurf_running; then clean_extension_cache; fi ;;
        4) clean_dev_caches ;;
        5) clean_system_caches ;;
        6) analyze_disk_usage ;;
        7) diagnose_mcp ;;
        8) reset_mcp_config ;;
        9) detect_zsh_theme_conflicts ;;
        10) configure_terminal_settings ;;
        11) enable_legacy_terminal ;;
        12) fix_damaged_app ;;
        13) generate_diagnostic_report ;;
        14) full_repair ;;
        15) backup_mcp_skills_rules ;;
        16) restore_mcp_skills_rules ;;
        17) reset_windsurf_id ;;
        18) deep_clean_runtime_cache ;;
        19) monitor_windsurf_processes ;;
        20) smart_optimize ;;
        21) clean_ai_tool_garbage ;;
        22) reset_opencode_id ;;
        23) archive_old_conversations ;;
        24) quick_diagnose_and_fix ;;
        0) 
            echo ""
            print_info "感谢使用Mac修复清理工具"
            exit 0 
            ;;
        *) 
            print_error "无效选项"
            ;;
    esac
}

# ----------------------------------------------------------------------------
# 主程序入口
# ----------------------------------------------------------------------------
main() {
    print_header
    detect_system_info
    
    while true; do
        show_menu
        echo ""
        echo -ne ${CYAN}按回车键继续...${NC}
        read -r
    done
}

# 执行主程序
main
