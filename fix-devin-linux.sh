#!/bin/bash

# ============================================================================
# Windsurf 修复工具 - Linux 版本
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
BACKUP_DIR="$HOME/.windsurf-backup-$(date +%Y%m%d_%H%M%S)"
XDG_CONFIG_ROOT="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_CACHE_ROOT="${XDG_CACHE_HOME:-$HOME/.cache}"
XDG_DATA_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}"
WINDSURF_CONFIG_DIR="$XDG_CONFIG_ROOT/Windsurf"
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

# 尝试查找Windsurf安装路径
WINDSURF_BIN=""
for path in "/opt/Windsurf" "/usr/share/windsurf" "$HOME/.local/share/windsurf" "/usr/local/bin/windsurf"; do
    if [ -e "$path" ]; then
        WINDSURF_BIN="$path"
        break
    fi
done

# ----------------------------------------------------------------------------
# 工具函数
# ----------------------------------------------------------------------------
print_header() {
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  Windsurf 修复工具 - Linux${NC}"
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
        echo -e "  如需关闭强制重置：${CYAN}FORCE_RESET_ID=0 bash fix-windsurf-linux.sh${NC}"
    fi
    echo ""
    echo -e "${GREEN}[始终保留]${NC} 对话和用户数据，任何模式下都不会被清理："
    echo -e "  • ${CYAN}~/.codeium/windsurf/cascade/*.pb${NC}            对话历史"
    echo -e "  • ${CYAN}~/.codeium/windsurf/memories/${NC}                 用户记忆"
    echo -e "  • ${CYAN}~/.codeium/windsurf/skills/${NC}                   技能"
    echo -e "  • ${CYAN}~/.codeium/windsurf/mcp_config.json${NC}          MCP 配置"
    echo -e "  • ${CYAN}~/.codeium/windsurf/user_settings.pb${NC}          用户偏好"
    echo -e "  • ${CYAN}~/.config/Windsurf/User/settings.json${NC}         编辑器设置"
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
    echo -ne "${YELLOW}确认执行此操作？[y/N]: ${NC}"
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
    
    # 检测发行版
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO="$NAME $VERSION_ID"
    else
        DISTRO="Unknown"
    fi
    
    # 检测内核版本
    KERNEL=$(uname -r)
    
    # 检测架构
    ARCH=$(uname -m)
    
    echo ""
    echo -e "  发行版: ${GREEN}$DISTRO${NC}"
    echo -e "  内核版本: ${GREEN}$KERNEL${NC}"
    echo -e "  架构: ${GREEN}$ARCH${NC}"
    if [ -n "$WINDSURF_BIN" ]; then
        echo -e "  Windsurf路径: ${GREEN}$WINDSURF_BIN${NC}"
    else
        echo -e "  Windsurf路径: ${YELLOW}未检测到${NC}"
    fi
    echo ""
}

# ----------------------------------------------------------------------------
# 检查Windsurf是否正在运行
# ----------------------------------------------------------------------------
check_windsurf_running() {
    if pgrep -f "windsurf" > /dev/null 2>&1; then
        print_warning "检测到 Windsurf 正在运行"
        echo -e "  请先关闭 Windsurf 再执行修复操作"
        if [ "${TERM_PROGRAM:-}" = "vscode" ]; then
            print_warning "当前看起来是在 Windsurf / VS Code 类内置终端中运行"
            echo -e "  如果在这里自动关闭 Windsurf，当前终端会一起消失，看起来像脚本退出"
            echo -e "  建议先手动关闭 Windsurf，再从系统终端重新运行脚本"
            return 1
        fi
        echo -ne "${YELLOW}是否自动关闭Windsurf？[y/N]: ${NC}"
        read -r choice
        case "$choice" in
            y|Y )
                pkill -f "windsurf" 2>/dev/null || true
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

        # 优先清理当前版本的运行时缓存目录，同时兼容旧版 .codeium 路径。
        for cache_dir in \
            "$WINDSURF_CONFIG_DIR/CachedData" \
            "$WINDSURF_CONFIG_DIR/CachedExtensionVSIXs" \
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
# 功能9: 修复chrome-sandbox权限问题
# ----------------------------------------------------------------------------
fix_chrome_sandbox() {
    print_info "修复 chrome-sandbox 权限问题..."
    
    echo ""
    echo "此问题通常导致 Windsurf 静默崩溃或无法启动"
    echo ""
    
    # 查找chrome-sandbox
    SANDBOX_PATH=""
    for path in "/opt/Windsurf/chrome-sandbox" "/usr/share/windsurf/chrome-sandbox" "$HOME/.local/share/windsurf/chrome-sandbox"; do
        if [ -f "$path" ]; then
            SANDBOX_PATH="$path"
            break
        fi
    done
    
    if [ -z "$SANDBOX_PATH" ]; then
        print_warning "未找到 chrome-sandbox 文件"
        echo -ne "${YELLOW}请输入 Windsurf 安装路径: ${NC}"
        read -r custom_path
        if [ -f "$custom_path/chrome-sandbox" ]; then
            SANDBOX_PATH="$custom_path/chrome-sandbox"
        else
            print_error "未找到 chrome-sandbox"
            return 1
        fi
    fi
    
    echo ""
    echo "将执行以下命令修复权限:"
    echo "  sudo chown root:root $SANDBOX_PATH"
    echo "  sudo chmod 4755 $SANDBOX_PATH"
    echo ""
    
    if confirm_action; then
        sudo chown root:root "$SANDBOX_PATH"
        sudo chmod 4755 "$SANDBOX_PATH"
        print_success "chrome-sandbox 权限已修复"
    else
        print_info "已取消操作"
    fi
}

# ----------------------------------------------------------------------------
# 功能10: 配置终端设置
# ----------------------------------------------------------------------------
configure_terminal_settings() {
    print_info "配置终端设置..."
    
    SETTINGS_JSON="$HOME/.config/Windsurf/User/settings.json"
    
    echo ""
    echo "推荐的终端配置:"
    echo -e "  ${GREEN}\"terminal.integrated.defaultProfile.linux\": \"bash\"${NC}"
    echo ""
    
    if [ -f "$SETTINGS_JSON" ]; then
        print_info "settings.json 位置: $SETTINGS_JSON"
        
        if grep -q "terminal.integrated.defaultProfile.linux" "$SETTINGS_JSON" 2>/dev/null; then
            print_info "终端配置已存在"
            grep "terminal.integrated.defaultProfile" "$SETTINGS_JSON" | head -1
        else
            print_warning "未找到终端配置，建议手动添加"
        fi
    else
        print_warning "未找到 settings.json 文件"
        print_info "Windsurf 可能尚未创建配置文件"
    fi
}

# ----------------------------------------------------------------------------
# 功能11: 修复systemd终端上下文跟踪问题
# ----------------------------------------------------------------------------
fix_systemd_osc_context() {
    print_info "检测 systemd 终端上下文跟踪问题..."
    
    echo ""
    echo "此问题常见于 Fedora 43+ 等新版本发行版"
    echo "systemd 的 OSC 3008 转义序列可能干扰 Cascade 的输出解析"
    echo ""
    
    # 检测是否存在问题文件
    OSC_SCRIPT="/etc/profile.d/80-systemd-osc-context.sh"
    if [ -f "$OSC_SCRIPT" ]; then
        print_warning "检测到 systemd OSC 上下文脚本: $OSC_SCRIPT"
        echo ""
        echo "建议解决方案:"
        echo "1. 修改 ~/.bashrc 避免 source /etc/bashrc"
        echo "2. 创建专用于 Windsurf 的简化 shell 配置"
        echo ""
        
        echo -ne "${YELLOW}是否创建 Windsurf 专用的 bashrc？[y/N]: ${NC}"
        read -r choice
        case "$choice" in
            y|Y )
                create_windsurf_bashrc
                ;;
        esac
    else
        print_info "未检测到 systemd OSC 上下文脚本"
    fi
    
    # 检查bashrc中是否source了/etc/bashrc
    if [ -f "$HOME/.bashrc" ]; then
        if grep -q "source /etc/bashrc\|. /etc/bashrc" "$HOME/.bashrc" 2>/dev/null; then
            print_warning "~/.bashrc 中 source 了 /etc/bashrc，可能导致问题"
        fi
    fi
}

# ----------------------------------------------------------------------------
# 创建Windsurf专用bashrc
# ----------------------------------------------------------------------------
create_windsurf_bashrc() {
    WINDSURF_BASHRC="$HOME/.bashrc.windsurf"
    
    cat > "$WINDSURF_BASHRC" << 'EOF'
# ============================================================================
# Windsurf 专用 bash 配置
# 此配置避免加载可能干扰 Cascade 的系统脚本
# ============================================================================

# 基础环境变量
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
export EDITOR="code"
export LANG="en_US.UTF-8"

# 简单提示符
PS1='[\u@\h \W]\$ '

# 加载用户别名（如果存在）
[ -f ~/.bash_aliases ] && source ~/.bash_aliases

# 历史记录配置
HISTSIZE=10000
HISTFILESIZE=20000
HISTCONTROL=ignoredups:erasedups

# 自动补全
if [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
fi
EOF
    
    print_success "已创建 Windsurf 专用 bashrc: $WINDSURF_BASHRC"
    echo ""
    print_info "使用方法: 在 Windsurf 设置中添加:"
    echo '  "terminal.integrated.shellArgs.linux": ["--rcfile", "~/.bashrc.windsurf"]'
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
        
        # 清理 GPU 缓存
        CACHE_DIR="$WINDSURF_CONFIG_DIR/Cache"
        if [ -d "$CACHE_DIR" ]; then
            rm -rf "$CACHE_DIR"
            print_success "已清理 Cache"
        fi

        GPU_CACHE="$WINDSURF_CONFIG_DIR/GPUCache"
        if [ -d "$GPU_CACHE" ]; then
            rm -rf "$GPU_CACHE"
            print_success "已清理 GPUCache"
        fi
        
        # 清理 CachedData
        for cache_dir in "$WINDSURF_CONFIG_DIR/CachedData" "$WINDSURF_DIR/CachedData"; do
            if [ -d "$cache_dir" ]; then
                rm -rf "$cache_dir"
                print_success "已清理 $(basename "$cache_dir")"
            fi
        done

        # 清理扩展安装包缓存，兼容旧版目录结构。
        for cache_dir in "$WINDSURF_CONFIG_DIR/CachedExtensionVSIXs" "$WINDSURF_DIR/CachedExtensions"; do
            if [ -d "$cache_dir" ]; then
                rm -rf "$cache_dir"
                print_success "已清理 $(basename "$cache_dir")"
            fi
        done
        
        # 清理 Code Cache
        CODE_CACHE="$WINDSURF_CONFIG_DIR/Code Cache"
        if [ -d "$CODE_CACHE" ]; then
            rm -rf "$CODE_CACHE"
            print_success "已清理 Code Cache"
        fi

        for cache_dir in "$WINDSURF_CONFIG_DIR/DawnWebGPUCache" "$WINDSURF_CONFIG_DIR/DawnGraphiteCache"; do
            if [ -d "$cache_dir" ]; then
                rm -rf "$cache_dir"
                print_success "已清理 $(basename "$cache_dir")"
            fi
        done
        
        # 清理 logs
        LOGS_DIR="$WINDSURF_CONFIG_DIR/logs"
        if [ -d "$LOGS_DIR" ]; then
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
# 功能7: MCP诊断与修复
# ----------------------------------------------------------------------------
diagnose_mcp() {
    print_info "MCP (Model Context Protocol) 诊断..."
    
    MCP_CONFIG="$WINDSURF_DIR/mcp_config.json"
    MCP_CONFIG_OLD="$CODEIUM_DIR/mcp_config.json"
    
    echo ""
    echo -e "${CYAN}MCP 配置文件状态:${NC}"
    echo ""
    
    if [ -f "$MCP_CONFIG" ]; then
        print_success "找到 MCP 配置: $MCP_CONFIG"
        echo ""
        echo "配置内容预览:"
        head -30 "$MCP_CONFIG" 2>/dev/null | while IFS= read -r line; do
            echo "  $line"
        done
        echo ""
        
        if command -v python3 &> /dev/null; then
            if python3 -c "import json; json.load(open('$MCP_CONFIG'))" 2>/dev/null; then
                print_success "MCP 配置 JSON 格式有效"
            else
                print_error "MCP 配置 JSON 格式无效！"
            fi
        fi
    else
        print_warning "未找到 MCP 配置文件: $MCP_CONFIG"
    fi
    
    if [ -f "$MCP_CONFIG_OLD" ]; then
        print_info "发现旧版 MCP 配置: $MCP_CONFIG_OLD"
    fi
    
    echo ""
    echo -e "${CYAN}运行时检查:${NC}"
    echo ""
    
    if command -v node &> /dev/null; then
        print_success "Node.js: $(node --version 2>/dev/null)"
    else
        print_warning "未找到 Node.js"
    fi
    
    if command -v npx &> /dev/null; then
        print_success "npx 可用"
    else
        print_warning "未找到 npx"
    fi
    
    if command -v python3 &> /dev/null; then
        print_success "Python3: $(python3 --version 2>/dev/null)"
    else
        print_warning "未找到 Python3"
    fi
    
    if command -v uvx &> /dev/null; then
        print_success "uvx 可用"
    else
        print_info "uvx 未安装"
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
    echo ""
    
    if [ ! -f "$MCP_CONFIG" ]; then
        print_info "MCP 配置文件不存在"
        return 0
    fi
    
    if confirm_action; then
        mkdir -p "$BACKUP_DIR"
        cp "$MCP_CONFIG" "$BACKUP_DIR/mcp_config.json.bak"
        print_info "已备份到: $BACKUP_DIR/mcp_config.json.bak"
        
        cat > "$MCP_CONFIG" << 'EOF'
{
  "mcpServers": {}
}
EOF
        print_success "MCP 配置已重置"
    else
        print_info "已取消操作"
    fi
}

# ----------------------------------------------------------------------------
# 功能4: 清理开发工具缓存（npm/pip/Maven等）
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
    PIP_CACHE="$HOME/.cache/pip"
    if [ -d "$PIP_CACHE" ]; then
        SIZE=$(du -sm "$PIP_CACHE" 2>/dev/null | awk '{print $1}')
        echo -e "  ${GREEN}[pip 缓存]${NC} ~/.cache/pip - ${YELLOW}${SIZE}MB${NC}"
        TOTAL_SIZE=$((TOTAL_SIZE + SIZE))
        CLEANABLE_ITEMS+=("pip")
    fi
    
    # apt 缓存 (Debian/Ubuntu)
    APT_CACHE="/var/cache/apt/archives"
    if [ -d "$APT_CACHE" ]; then
        SIZE=$(sudo du -sm "$APT_CACHE" 2>/dev/null | awk '{print $1}')
        if [ -n "$SIZE" ] && [ "$SIZE" -gt 0 ] 2>/dev/null; then
            echo -e "  ${GREEN}[apt 缓存]${NC} /var/cache/apt/archives - ${YELLOW}${SIZE}MB${NC}"
            TOTAL_SIZE=$((TOTAL_SIZE + SIZE))
            CLEANABLE_ITEMS+=("apt")
        fi
    fi
    
    # yum/dnf 缓存 (RHEL/Fedora)
    YUM_CACHE="/var/cache/yum"
    DNF_CACHE="/var/cache/dnf"
    if [ -d "$YUM_CACHE" ] || [ -d "$DNF_CACHE" ]; then
        CACHE_DIR="${DNF_CACHE:-$YUM_CACHE}"
        SIZE=$(sudo du -sm "$CACHE_DIR" 2>/dev/null | awk '{print $1}')
        if [ -n "$SIZE" ] && [ "$SIZE" -gt 0 ] 2>/dev/null; then
            echo -e "  ${GREEN}[yum/dnf 缓存]${NC} $CACHE_DIR - ${YELLOW}${SIZE}MB${NC}"
            TOTAL_SIZE=$((TOTAL_SIZE + SIZE))
            CLEANABLE_ITEMS+=("yum")
        fi
    fi
    
    # uv 缓存
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
    YARN_CACHE="$HOME/.cache/yarn"
    if [ -d "$YARN_CACHE" ]; then
        SIZE=$(du -sm "$YARN_CACHE" 2>/dev/null | awk '{print $1}')
        echo -e "  ${GREEN}[Yarn 缓存]${NC} ~/.cache/yarn - ${YELLOW}${SIZE}MB${NC}"
        TOTAL_SIZE=$((TOTAL_SIZE + SIZE))
        CLEANABLE_ITEMS+=("yarn")
    fi
    
    # pnpm 缓存
    PNPM_STORE="$HOME/.pnpm-store"
    if [ -d "$PNPM_STORE" ]; then
        SIZE=$(du -sm "$PNPM_STORE" 2>/dev/null | awk '{print $1}')
        echo -e "  ${GREEN}[pnpm 缓存]${NC} ~/.pnpm-store - ${YELLOW}${SIZE}MB${NC}"
        TOTAL_SIZE=$((TOTAL_SIZE + SIZE))
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
        echo -e "  ${GREEN}[Selenium/WebDriver]${NC} - ${YELLOW}${SELENIUM_SIZE}MB${NC}"
        TOTAL_SIZE=$((TOTAL_SIZE + SELENIUM_SIZE))
        CLEANABLE_ITEMS+=("selenium")
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
    for CONDA_DIR in "$HOME/miniconda3/pkgs" "$HOME/anaconda3/pkgs"; do
        if [ -d "$CONDA_DIR" ]; then
            SIZE=$(du -sm "$CONDA_DIR" 2>/dev/null | awk '{print $1}')
            echo -e "  ${GREEN}[conda 包缓存]${NC} $CONDA_DIR - ${YELLOW}${SIZE}MB${NC}"
            TOTAL_SIZE=$((TOTAL_SIZE + SIZE))
            CLEANABLE_ITEMS+=("conda")
            break
        fi
    done
    
    # Docker 缓存
    if command -v docker &> /dev/null; then
        DOCKER_SIZE=$(docker system df 2>/dev/null | awk 'NR>1{gsub(/[A-Za-z]/,"",$4); sum+=$4} END{printf "%.0f", sum}' 2>/dev/null)
        if [ -n "$DOCKER_SIZE" ] && [ "$DOCKER_SIZE" -gt 0 ] 2>/dev/null; then
            echo -e "  ${GREEN}[Docker 可回收]${NC} - ${YELLOW}约${DOCKER_SIZE}MB${NC}"
            CLEANABLE_ITEMS+=("docker")
        fi
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
            for item in "${CLEANABLE_ITEMS[@]}"; do
                case "$item" in
                    npm)
                        if command -v npm &> /dev/null; then npm cache clean --force 2>/dev/null
                        else rm -rf "$NPM_CACHE/_cacache" 2>/dev/null; fi
                        print_success "npm 缓存已清理"
                        ;;
                    pip)
                        if command -v pip3 &> /dev/null; then pip3 cache purge 2>/dev/null
                        else rm -rf "$PIP_CACHE" 2>/dev/null; fi
                        print_success "pip 缓存已清理"
                        ;;
                    apt)
                        sudo apt-get clean 2>/dev/null
                        print_success "apt 缓存已清理"
                        ;;
                    yum)
                        if command -v dnf &> /dev/null; then sudo dnf clean all 2>/dev/null
                        else sudo yum clean all 2>/dev/null; fi
                        print_success "yum/dnf 缓存已清理"
                        ;;
                    uv)
                        rm -rf "$UV_CACHE" 2>/dev/null
                        print_success "uv 缓存已清理"
                        ;;
                    maven)
                        print_warning "Maven 缓存跳过（删除后需重新下载依赖）"
                        ;;
                    gradle)
                        print_warning "Gradle 缓存跳过（删除后需重新下载依赖）"
                        ;;
                    yarn)
                        if command -v yarn &> /dev/null; then yarn cache clean 2>/dev/null
                        else rm -rf "$YARN_CACHE" 2>/dev/null; fi
                        print_success "Yarn 缓存已清理"
                        ;;
                    pnpm)
                        if command -v pnpm &> /dev/null; then pnpm store prune 2>/dev/null; fi
                        print_success "pnpm 缓存已清理"
                        ;;
                    selenium)
                        rm -rf "$SELENIUM_CACHE" "$WDM_CACHE" 2>/dev/null
                        print_success "Selenium/WebDriver 缓存已清理"
                        ;;
                    go)
                        if command -v go &> /dev/null; then go clean -modcache 2>/dev/null; fi
                        print_success "Go 模块缓存已清理"
                        ;;
                    cargo)
                        print_warning "Cargo 缓存跳过"
                        ;;
                    conda)
                        if command -v conda &> /dev/null; then conda clean --all -y 2>/dev/null; fi
                        print_success "conda 缓存已清理"
                        ;;
                    docker)
                        docker system prune -f 2>/dev/null
                        print_success "Docker 缓存已清理"
                        ;;
                esac
            done
            echo ""
            print_success "开发工具缓存清理完成！"
            ;;
        2)
            for item in "${CLEANABLE_ITEMS[@]}"; do
                case "$item" in
                    npm) label="npm 缓存" ;;
                    pip) label="pip 缓存" ;;
                    apt) label="apt 缓存" ;;
                    yum) label="yum/dnf 缓存" ;;
                    uv) label="uv 缓存" ;;
                    maven) label="Maven 缓存" ;;
                    gradle) label="Gradle 缓存" ;;
                    yarn) label="Yarn 缓存" ;;
                    pnpm) label="pnpm 缓存" ;;
                    selenium) label="Selenium/WebDriver 缓存" ;;
                    go) label="Go 模块缓存" ;;
                    cargo) label="Cargo 缓存" ;;
                    conda) label="conda 包缓存" ;;
                    docker) label="Docker 可回收空间" ;;
                    *) label="$item" ;;
                esac
                
                echo -ne "${YELLOW}清理 $label？[y/N]: ${NC}"
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
                        apt) sudo apt-get clean 2>/dev/null ;;
                        yum)
                            if command -v dnf &> /dev/null; then sudo dnf clean all 2>/dev/null
                            else sudo yum clean all 2>/dev/null; fi
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
                        go)
                            if command -v go &> /dev/null; then go clean -modcache 2>/dev/null; fi
                            ;;
                        cargo) rm -rf "$CARGO_CACHE" 2>/dev/null ;;
                        conda)
                            if command -v conda &> /dev/null; then conda clean --all -y 2>/dev/null; fi
                            ;;
                        docker) docker system prune -f 2>/dev/null ;;
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
# 功能5: 清理Linux系统缓存
# ----------------------------------------------------------------------------
clean_system_caches() {
    print_info "扫描 Linux 系统缓存..."
    
    echo ""
    echo -e "${CYAN}正在检测系统级缓存...${NC}"
    echo ""
    
    TOTAL_SIZE=0
    
    # 用户缓存目录
    USER_CACHE="$HOME/.cache"
    if [ -d "$USER_CACHE" ]; then
        SIZE=$(du -sm "$USER_CACHE" 2>/dev/null | awk '{print $1}')
        echo -e "  ${GREEN}[用户缓存]${NC} ~/.cache - ${YELLOW}${SIZE}MB${NC}"
        TOTAL_SIZE=$((TOTAL_SIZE + SIZE))
        
        echo -e "    ${CYAN}Top 10 缓存目录:${NC}"
        du -sm "$USER_CACHE"/*/ 2>/dev/null | sort -rn | head -10 | while read size dir; do
            dirname=$(basename "$dir")
            echo -e "      $dirname - ${YELLOW}${size}MB${NC}"
        done
        echo ""
    fi
    
    # 系统日志
    SYS_LOG="/var/log"
    if [ -d "$SYS_LOG" ]; then
        SIZE=$(sudo du -sm "$SYS_LOG" 2>/dev/null | awk '{print $1}')
        if [ -n "$SIZE" ]; then
            echo -e "  ${GREEN}[系统日志]${NC} /var/log - ${YELLOW}${SIZE}MB${NC}"
            TOTAL_SIZE=$((TOTAL_SIZE + SIZE))
        fi
    fi
    
    # 临时文件
    TMP_DIR="/tmp"
    if [ -d "$TMP_DIR" ]; then
        SIZE=$(du -sm "$TMP_DIR" 2>/dev/null | awk '{print $1}')
        echo -e "  ${GREEN}[临时文件]${NC} /tmp - ${YELLOW}${SIZE}MB${NC}"
        TOTAL_SIZE=$((TOTAL_SIZE + SIZE))
    fi
    
    # Windsurf 旧备份
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
    
    # systemd journal 日志
    if command -v journalctl &> /dev/null; then
        JOURNAL_SIZE=$(journalctl --disk-usage 2>/dev/null | grep -oP '[\d.]+[GMKT]' | head -1)
        if [ -n "$JOURNAL_SIZE" ]; then
            echo -e "  ${GREEN}[systemd 日志]${NC} - ${YELLOW}${JOURNAL_SIZE}${NC}"
        fi
    fi
    
    echo ""
    echo -e "  ${CYAN}系统缓存总计: ${YELLOW}${TOTAL_SIZE}MB${NC}"
    echo ""
    
    echo -e "${YELLOW}请选择清理项目:${NC}"
    echo "  1) 清理用户缓存 (~/.cache，排除关键缓存)"
    echo "  2) 清理旧日志文件（超过30天）"
    echo "  3) 清理 /tmp 临时文件（超过7天）"
    echo "  4) 清理 Windsurf 旧备份目录"
    echo "  5) 清理旧诊断报告"
    echo "  6) 清理 systemd journal 日志（保留最近7天）"
    echo "  7) 刷新 DNS 缓存"
    echo "  8) 全部执行（安全项）"
    echo "  0) 取消"
    echo ""
    echo -ne ${CYAN}请选择 [0-8]: ${NC}
    read -r sys_choice
    
    case "$sys_choice" in
        1)
            print_warning "将清理用户缓存目录"
            if confirm_action; then
                find "$USER_CACHE" -mindepth 1 -maxdepth 1 -type d \
                    ! -name "fontconfig" \
                    ! -name "mesa_shader_cache" \
                    -exec rm -rf {} + 2>/dev/null
                print_success "用户缓存已清理"
            fi
            ;;
        2)
            sudo find /var/log -type f -name "*.log" -mtime +30 -delete 2>/dev/null
            sudo find /var/log -type f -name "*.gz" -mtime +30 -delete 2>/dev/null
            print_success "超过30天的旧日志已清理"
            ;;
        3)
            sudo find /tmp -type f -mtime +7 -delete 2>/dev/null
            print_success "/tmp 中超过7天的临时文件已清理"
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
            if command -v journalctl &> /dev/null; then
                sudo journalctl --vacuum-time=7d 2>/dev/null
                print_success "systemd journal 日志已清理（保留7天）"
            else
                print_info "系统未使用 systemd journal"
            fi
            ;;
        7)
            if command -v systemd-resolve &> /dev/null; then
                sudo systemd-resolve --flush-caches 2>/dev/null
            elif command -v resolvectl &> /dev/null; then
                sudo resolvectl flush-caches 2>/dev/null
            fi
            print_success "DNS 缓存已刷新"
            ;;
        8)
            print_info "执行全部安全清理项..."
            
            sudo find /var/log -type f -name "*.log" -mtime +30 -delete 2>/dev/null
            sudo find /var/log -type f -name "*.gz" -mtime +30 -delete 2>/dev/null
            print_success "旧日志已清理"
            
            sudo find /tmp -type f -mtime +7 -delete 2>/dev/null
            print_success "旧临时文件已清理"
            
            if [ $BACKUP_COUNT -gt 0 ]; then
                rm -rf "$HOME"/.windsurf-backup-* 2>/dev/null
                print_success "Windsurf 旧备份已清理"
            fi
            
            rm -f "$HOME"/windsurf-diagnostic-*.txt 2>/dev/null
            print_success "旧诊断报告已清理"
            
            if command -v journalctl &> /dev/null; then
                sudo journalctl --vacuum-time=7d 2>/dev/null
                print_success "systemd journal 日志已清理"
            fi
            
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
    
    df -h / | awk 'NR==2{printf "  磁盘总容量: %s | 已使用: %s | 可用: %s | 使用率: %s\n", $2, $3, $4, $5}'
    echo ""
    
    HOME_SIZE=$(du -sh "$HOME" 2>/dev/null | awk '{print $1}')
    echo -e "  ${CYAN}用户主目录:${NC} ${YELLOW}$HOME_SIZE${NC}"
    echo ""
    
    echo -e "  ${CYAN}主要目录占用:${NC}"
    echo ""
    for dir in "Downloads" "Documents" "Desktop" "Videos" "Music" "Pictures"; do
        if [ -d "$HOME/$dir" ]; then
            SIZE=$(du -sh "$HOME/$dir" 2>/dev/null | awk '{print $1}')
            printf "    %-15s %s\n" "$dir" "$SIZE"
        fi
    done
    echo ""
    
    echo -e "  ${CYAN}隐藏目录 Top 10:${NC}"
    echo ""
    du -sm "$HOME"/.[!.]* 2>/dev/null | sort -rn | head -10 | while read size dir; do
        dirname=$(basename "$dir")
        printf "    %-30s %sMB\n" "$dirname" "$size"
    done
    echo ""
    
    print_info "分析完成"
}

# ----------------------------------------------------------------------------
# 功能12: 检测shell主题冲突
# ----------------------------------------------------------------------------
detect_shell_theme_conflicts() {
    print_info "检测 shell 主题冲突..."
    
    CONFLICTS_FOUND=0
    
    # 检测 .bashrc
    if [ -f "$HOME/.bashrc" ]; then
        echo ""
        echo "检查 ~/.bashrc..."
        
        if grep -q "PS0\|PROMPT_COMMAND" "$HOME/.bashrc" 2>/dev/null; then
            print_warning "检测到 PS0 或 PROMPT_COMMAND 配置"
            CONFLICTS_FOUND=1
        fi
    fi
    
    # 检测 .zshrc
    if [ -f "$HOME/.zshrc" ]; then
        echo ""
        echo "检查 ~/.zshrc..."
        
        if grep -q "ZSH_THEME=" "$HOME/.zshrc" 2>/dev/null; then
            THEME=$(grep "ZSH_THEME=" "$HOME/.zshrc" | grep -v "^#" | head -1)
            if [ -n "$THEME" ]; then
                print_warning "检测到 Oh My Zsh 主题: $THEME"
                CONFLICTS_FOUND=1
            fi
        fi
        
        if grep -q "p10k\|powerlevel" "$HOME/.zshrc" 2>/dev/null; then
            print_warning "检测到 Powerlevel10k 配置"
            CONFLICTS_FOUND=1
        fi
        
        if grep -q "oh-my-posh" "$HOME/.zshrc" 2>/dev/null; then
            print_warning "检测到 oh-my-posh 配置"
            CONFLICTS_FOUND=1
        fi
    fi
    
    if [ $CONFLICTS_FOUND -eq 1 ]; then
        echo ""
        echo -e "${YELLOW}建议:${NC} 如果终端会话卡住，请尝试:"
        echo "  1. 创建简化的 shell 配置专用于 Windsurf"
        echo "  2. 临时注释掉复杂的主题配置"
    else
        print_success "未检测到已知的主题冲突"
    fi
}

# ----------------------------------------------------------------------------
# 功能13: 生成诊断报告
# ----------------------------------------------------------------------------
generate_diagnostic_report() {
    print_info "生成诊断报告..."
    
    REPORT_FILE="$HOME/windsurf-diagnostic-$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "=========================================="
        echo "Windsurf 诊断报告 - Linux"
        echo "生成时间: $(date)"
        echo "=========================================="
        echo ""
        
        echo "## 系统信息"
        echo "发行版:"
        cat /etc/os-release 2>/dev/null | head -5
        echo ""
        echo "内核: $(uname -r)"
        echo "架构: $(uname -m)"
        echo ""
        
        echo "## Windsurf 安装状态"
        which windsurf 2>/dev/null || echo "windsurf 不在 PATH 中"
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
            du -sh "$CASCADE_DIR" 2>/dev/null
        else
            echo "目录不存在"
        fi
        echo ""
        
        echo "## Shell 配置"
        echo "默认Shell: $SHELL"
        echo ""
        
        echo "## 网络状态"
        echo "ping codeium.com:"
        ping -c 2 codeium.com 2>/dev/null || echo "无法ping"
        echo ""
        
        echo "## 磁盘空间"
        df -h / 2>/dev/null | head -2
        echo ""
        
        echo "## chrome-sandbox 状态"
        for path in "/opt/Windsurf/chrome-sandbox" "/usr/share/windsurf/chrome-sandbox"; do
            if [ -f "$path" ]; then
                ls -la "$path"
            fi
        done
        echo ""
        
    } > "$REPORT_FILE"
    
    print_success "诊断报告已保存: $REPORT_FILE"
}

# ----------------------------------------------------------------------------
# 功能14: 完整修复
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
        fix_chrome_sandbox
        configure_terminal_settings
        fix_systemd_osc_context
        detect_shell_theme_conflicts
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
# 格式化KB大小为易读格式
# ----------------------------------------------------------------------------
format_kb_size() {
    KB_VALUE="$1"
    # 大于1GB时显示GB
    if [ "$KB_VALUE" -ge 1048576 ] 2>/dev/null; then
        awk -v kb="$KB_VALUE" 'BEGIN {printf "%.2fGB", kb/1024/1024}'
    # 大于1MB时显示MB
    elif [ "$KB_VALUE" -ge 1024 ] 2>/dev/null; then
        awk -v kb="$KB_VALUE" 'BEGIN {printf "%.2fMB", kb/1024}'
    else
        echo "${KB_VALUE}KB"
    fi
}

# ----------------------------------------------------------------------------
# 计算glob路径下所有文件总大小（返回KB）
# ----------------------------------------------------------------------------
calculate_glob_size_kb() {
    GLOB_PATTERN="$1"
    # 展开glob并逐项统计大小，最后求和
    TOTAL_KB=$(compgen -G "$GLOB_PATTERN" 2>/dev/null | while IFS= read -r item; do
        du -sk "$item" 2>/dev/null | awk '{print $1}'
    done | awk '{sum+=$1} END{print sum+0}')
    echo "${TOTAL_KB:-0}"
}

# ----------------------------------------------------------------------------
# 清理glob路径并统计释放空间（供功能15调用）
# ----------------------------------------------------------------------------
clean_glob_with_stats() {
    TARGET_PATTERN="$1"
    TARGET_LABEL="$2"

    # 统计清理前大小
    BEFORE_KB=$(calculate_glob_size_kb "$TARGET_PATTERN")
    echo ""
    print_info "$TARGET_LABEL"

    if [ "$BEFORE_KB" -gt 0 ] 2>/dev/null; then
        print_info "清理前大小: $(format_kb_size "$BEFORE_KB")"
        # 先打印各项大小
        compgen -G "$TARGET_PATTERN" 2>/dev/null | while IFS= read -r item; do
            du -sh "$item" 2>/dev/null | sed 's/^/  /'
        done
        # 执行删除
        compgen -G "$TARGET_PATTERN" 2>/dev/null | while IFS= read -r item; do
            rm -rf "$item" 2>/dev/null || true
        done
        # 统计释放空间
        AFTER_KB=$(calculate_glob_size_kb "$TARGET_PATTERN")
        RELEASED_KB=$((BEFORE_KB - AFTER_KB))
        if [ "$RELEASED_KB" -lt 0 ]; then
            RELEASED_KB=0
        fi
        # 累加到全局统计变量
        TOTAL_RELEASED_KB=$((TOTAL_RELEASED_KB + RELEASED_KB))
        print_success "已释放: $(format_kb_size "$RELEASED_KB")"
    else
        print_info "清理前大小: 0KB"
        print_info "无需清理"
    fi
}

# ----------------------------------------------------------------------------
# 清理单个文件并统计释放空间（供功能15调用）
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
        # 删除文件
        rm -f "$TARGET_FILE" 2>/dev/null || true
        # 统计释放空间
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
# 计算当前可清理运行时缓存总大小（KB），用于前后对比
# ----------------------------------------------------------------------------
calculate_runtime_cache_total_kb() {
    # Linux Windsurf 配置目录
    LINUX_WS_CONFIG="$HOME/.config/Windsurf"
    TOTAL_KB=0

    for pattern in \
        "$LINUX_WS_CONFIG/Cache/*" \
        "$LINUX_WS_CONFIG/CachedData/*" \
        "$LINUX_WS_CONFIG/GPUCache/*" \
        "$LINUX_WS_CONFIG/Code Cache/*" \
        "$LINUX_WS_CONFIG/DawnWebGPUCache/*" \
        "$LINUX_WS_CONFIG/DawnGraphiteCache/*" \
        "$LINUX_WS_CONFIG/logs/*" \
        "$LINUX_WS_CONFIG/Crashpad/completed/*" \
        "$LINUX_WS_CONFIG/Crashpad/pending/*" \
        "$LINUX_WS_CONFIG/CachedExtensionVSIXs/*" \
        "$WINDSURF_DIR/implicit/*" \
        "$WINDSURF_DIR/code_tracker/*" \
        "/tmp/windsurf-terminal-*.snapshot"
    do
        SIZE_KB=$(calculate_glob_size_kb "$pattern")
        TOTAL_KB=$((TOTAL_KB + SIZE_KB))
    done

    # state.vscdb.backup 单独计算
    STATE_BACKUP="$LINUX_WS_CONFIG/User/globalStorage/state.vscdb.backup"
    STATE_BACKUP_SIZE=0
    if [ -f "$STATE_BACKUP" ]; then
        STATE_BACKUP_SIZE=$(du -sk "$STATE_BACKUP" 2>/dev/null | awk '{print $1}')
        STATE_BACKUP_SIZE=${STATE_BACKUP_SIZE:-0}
    fi
    TOTAL_KB=$((TOTAL_KB + STATE_BACKUP_SIZE))

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
# 功能18: 清理 Claude Code / codex / gemini-cli / opencode 垃圾缓存
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
# 功能15: 深度清理运行时缓存（保留对话历史，解决Windsurf运行卡顿）
# ----------------------------------------------------------------------------
deep_clean_runtime_cache() {
    AUTO_CONFIRM="$1"
    # Linux Windsurf 配置目录
    LINUX_WS_CONFIG="$HOME/.config/Windsurf"
    IMPLICIT_LINUX="$WINDSURF_DIR/implicit"
    CODE_TRACKER_LINUX="$WINDSURF_DIR/code_tracker"

    print_info "深度清理运行时缓存（保留对话历史）..."

    echo ""
    echo "此操作将清理运行时缓存和日志，包含大型 state.vscdb.backup 文件"
    print_success "不会清理对话历史、登录态相关存储（IndexedDB/WebStorage/Local Storage/Session Storage/Service Worker）、memories、skills、extensions、用户设置"
    echo ""

    # 判断是否自动确认（被 smart_optimize 调用时）
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
    # 初始化全局释放空间计数器
    TOTAL_RELEASED_KB=0

    # 逐项清理并统计空间
    clean_glob_with_stats "$LINUX_WS_CONFIG/Cache/*"                              "清理浏览器缓存 (Cache)"
    clean_glob_with_stats "$LINUX_WS_CONFIG/CachedData/*"                         "清理编译缓存 (CachedData)"
    clean_glob_with_stats "$LINUX_WS_CONFIG/GPUCache/*"                           "清理 GPU 缓存 (GPUCache)"
    clean_glob_with_stats "$LINUX_WS_CONFIG/Code Cache/*"                         "清理代码缓存 (Code Cache)"
    clean_glob_with_stats "$LINUX_WS_CONFIG/DawnWebGPUCache/*"                    "清理 Dawn WebGPU 缓存"
    clean_glob_with_stats "$LINUX_WS_CONFIG/DawnGraphiteCache/*"                  "清理 Dawn Graphite 缓存"
    clean_glob_with_stats "$LINUX_WS_CONFIG/logs/*"                               "清理日志文件 (logs)"
    clean_glob_with_stats "$LINUX_WS_CONFIG/Crashpad/completed/*"                 "清理 Crashpad completed"
    clean_glob_with_stats "$LINUX_WS_CONFIG/Crashpad/pending/*"                   "清理 Crashpad pending"
    clean_file_with_stats "$LINUX_WS_CONFIG/User/globalStorage/state.vscdb.backup" "清理 state.vscdb.backup（关键大文件）"
    clean_glob_with_stats "$LINUX_WS_CONFIG/CachedExtensionVSIXs/*"               "清理旧版插件安装包残留"
    clean_glob_with_stats "$IMPLICIT_LINUX/*"                                      "清理 implicit AI 索引缓存"
    clean_glob_with_stats "$CODE_TRACKER_LINUX/*"                                  "清理 AI 代码追踪索引 (code_tracker)"
    clean_glob_with_stats "/tmp/windsurf-terminal-*.snapshot"                     "清理 /tmp 终端快照"

    # 清理 bash 自动补全缓存（可解决终端卡顿）
    if compgen -G "$HOME/.bash_completion*" > /dev/null 2>&1; then
        clean_glob_with_stats "$HOME/.bash_completion*" "清理 Bash 自动补全缓存（解决终端卡顿）"
    fi

    # 如果是 zsh 环境则同时清理 zcompdump
    if compgen -G "$HOME/.zcompdump*" > /dev/null 2>&1; then
        clean_glob_with_stats "$HOME/.zcompdump*" "清理 Zsh 自动补全缓存（解决终端卡顿）"
    fi

    echo ""
    print_success "深度清理完成，总释放空间: $(format_kb_size "$TOTAL_RELEASED_KB")"
    print_info "已保留对话历史、memories、skills、extensions、用户设置"

    # 清理完毕 -> 强制重置设备 ID（默认行为，FORCE_RESET_ID=0 可关闭）
    auto_reset_after_clean
}

# ----------------------------------------------------------------------------
# 功能16: Windsurf 进程资源监控
# ----------------------------------------------------------------------------
monitor_windsurf_processes() {
    print_info "Windsurf 进程资源监控..."

    echo ""
    echo -e "${CYAN}========== Windsurf 进程 ==========${NC}"

    # 过滤出 windsurf 相关进程，排除本脚本自身
    PROCESS_OUTPUT=$(ps aux | grep -i "[w]indsurf" | grep -v "fix-windsurf-linux.sh")

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
    # 读取 /proc/meminfo 获取内存信息
    if [ -f /proc/meminfo ]; then
        MEM_TOTAL=$(awk '/MemTotal/ {printf "%.2f", $2/1024}' /proc/meminfo)
        MEM_FREE=$(awk '/MemFree/ {printf "%.2f", $2/1024}' /proc/meminfo)
        MEM_AVAILABLE=$(awk '/MemAvailable/ {printf "%.2f", $2/1024}' /proc/meminfo)
        MEM_BUFFERS=$(awk '/Buffers/ {printf "%.2f", $2/1024}' /proc/meminfo)
        MEM_CACHED=$(awk '/^Cached/ {printf "%.2f", $2/1024}' /proc/meminfo)
        MEM_USED=$(awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{printf "%.2f", (t-a)/1024}' /proc/meminfo)

        echo "  内存总量:   ${MEM_TOTAL}MB"
        echo "  已使用:     ${MEM_USED}MB"
        echo "  空闲内存:   ${MEM_FREE}MB"
        echo "  可用内存:   ${MEM_AVAILABLE}MB"
        echo "  Buffers:    ${MEM_BUFFERS}MB"
        echo "  Cached:     ${MEM_CACHED}MB"
    else
        print_warning "无法读取 /proc/meminfo"
        free -m 2>/dev/null || true
    fi

    echo ""
    echo -e "${CYAN}========== 磁盘空间 ==========${NC}"
    df -h / 2>/dev/null | head -2

    echo ""
    echo -e "${CYAN}========== 系统负载 ==========${NC}"
    uptime 2>/dev/null || true
}

# ----------------------------------------------------------------------------
# 功能17: 一键智能优化（保留对话历史，清理前后空间对比）
# ----------------------------------------------------------------------------
smart_optimize() {
    print_info "执行一键智能优化（保留对话历史）..."
    print_success "不会清理 cascade/memories/skills/extensions"

    # 优化前计算可清理空间
    BEFORE_TOTAL_KB=$(calculate_runtime_cache_total_kb)
    print_info "优化前可清理空间: $(format_kb_size "$BEFORE_TOTAL_KB")"

    # 调用深度清理（自动确认，无需手动输入）
    deep_clean_runtime_cache --auto

    # 优化后计算残余空间
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
# 功能19: 备份 MCP 配置、Skills 和全局 Rules
# ----------------------------------------------------------------------------
backup_mcp_skills_rules() {
    print_info "备份 MCP 配置、Skills 和全局 Rules..."

    BACKUP_TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP_TARGET="$HOME/.windsurf-config-backup-$BACKUP_TIMESTAMP"

    LINUX_WS_CONFIG="$HOME/.config/Windsurf"
    MCP_CONFIG="$WINDSURF_DIR/mcp_config.json"
    SKILLS_DIR="$WINDSURF_DIR/skills"
    GLOBAL_RULES="$WINDSURF_DIR/memories/global_rules.md"
    MEMORIES_DIR="$WINDSURF_DIR/memories"

    echo ""
    echo -e "${CYAN}将备份以下内容:${NC}"
    echo ""

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

        if [ -f "$MCP_CONFIG" ]; then
            cp "$MCP_CONFIG" "$BACKUP_TARGET/mcp_config.json"
            print_success "MCP 配置已备份"
        fi

        if [ -d "$SKILLS_DIR" ]; then
            cp -r "$SKILLS_DIR" "$BACKUP_TARGET/skills"
            print_success "Skills 目录已备份"
        fi

        if [ -f "$GLOBAL_RULES" ]; then
            mkdir -p "$BACKUP_TARGET/memories"
            cp "$GLOBAL_RULES" "$BACKUP_TARGET/memories/global_rules.md"
            print_success "全局 Rules 已备份"
        fi

        if [ -d "$MEMORIES_DIR" ]; then
            cp -r "$MEMORIES_DIR" "$BACKUP_TARGET/memories" 2>/dev/null || true
            print_success "Memories 目录已备份"
        fi

        cat > "$BACKUP_TARGET/backup_info.txt" << BEOF
========================================
Windsurf 配置备份信息
========================================
备份时间: $(date)
发行版: $(. /etc/os-release 2>/dev/null && echo "$NAME $VERSION_ID" || echo "Unknown")
架构: $(uname -m)

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
    else
        print_info "已取消操作"
    fi
}

# ----------------------------------------------------------------------------
# 功能20: 还原 MCP 配置、Skills 和全局 Rules
# ----------------------------------------------------------------------------
restore_mcp_skills_rules() {
    print_info "还原 MCP 配置、Skills 和全局 Rules..."

    LINUX_WS_CONFIG="$HOME/.config/Windsurf"
    MCP_CONFIG="$WINDSURF_DIR/mcp_config.json"
    SKILLS_DIR="$WINDSURF_DIR/skills"
    GLOBAL_RULES="$WINDSURF_DIR/memories/global_rules.md"
    MEMORIES_DIR="$WINDSURF_DIR/memories"

    BACKUP_LIST=()
    for bdir in "$HOME"/.windsurf-config-backup-*; do
        if [ -d "$bdir" ]; then
            BACKUP_LIST+=("$bdir")
        fi
    done

    if [ ${#BACKUP_LIST[@]} -eq 0 ]; then
        print_warning "未找到任何配置备份"
        print_info "请先使用备份功能进行备份"
        return 0
    fi

    echo ""
    echo -e "${CYAN}可用的配置备份:${NC}"
    echo ""

    IDX=1
    for bdir in "${BACKUP_LIST[@]}"; do
        BNAME=$(basename "$bdir")
        BSIZE=$(du -sh "$bdir" 2>/dev/null | awk '{print $1}')
        BTIMESTAMP=$(echo "$BNAME" | sed 's/\.windsurf-config-backup-//')

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

    if ! [[ "$restore_choice" =~ ^[0-9]+$ ]] || [ "$restore_choice" -lt 1 ] || [ "$restore_choice" -gt ${#BACKUP_LIST[@]} ]; then
        print_error "无效选项"
        return 0
    fi

    SELECTED_BACKUP="${BACKUP_LIST[$((restore_choice - 1))]}"
    SELECTED_NAME=$(basename "$SELECTED_BACKUP")

    echo ""
    echo -e "${CYAN}已选择备份: ${YELLOW}$SELECTED_NAME${NC}"
    echo ""

    echo -e "${CYAN}请选择还原方式:${NC}"
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
        0) print_info "已取消操作"; return 0 ;;
        1) RESTORE_MCP=1; RESTORE_SKILLS=1; RESTORE_RULES=1; RESTORE_MEM=1 ;;
        2) RESTORE_MCP=1; RESTORE_SKILLS=0; RESTORE_RULES=0; RESTORE_MEM=0 ;;
        3) RESTORE_MCP=0; RESTORE_SKILLS=1; RESTORE_RULES=0; RESTORE_MEM=0 ;;
        4) RESTORE_MCP=0; RESTORE_SKILLS=0; RESTORE_RULES=1; RESTORE_MEM=0 ;;
        5) RESTORE_MCP=0; RESTORE_SKILLS=0; RESTORE_RULES=0; RESTORE_MEM=1 ;;
        *) print_error "无效选项"; return 0 ;;
    esac

    echo ""
    print_warning "还原操作将覆盖当前配置！"

    if confirm_action; then
        echo ""

        if [ "$RESTORE_MCP" -eq 1 ] && [ -f "$SELECTED_BACKUP/mcp_config.json" ]; then
            cp "$SELECTED_BACKUP/mcp_config.json" "$MCP_CONFIG"
            print_success "MCP 配置已还原"
        fi

        if [ "$RESTORE_SKILLS" -eq 1 ] && [ -d "$SELECTED_BACKUP/skills" ]; then
            rm -rf "$SKILLS_DIR" 2>/dev/null
            cp -r "$SELECTED_BACKUP/skills" "$SKILLS_DIR"
            print_success "Skills 目录已还原"
        fi

        if [ "$RESTORE_RULES" -eq 1 ] && [ -f "$SELECTED_BACKUP/memories/global_rules.md" ]; then
            mkdir -p "$MEMORIES_DIR"
            cp "$SELECTED_BACKUP/memories/global_rules.md" "$GLOBAL_RULES"
            print_success "全局 Rules 已还原"
        fi

        if [ "$RESTORE_MEM" -eq 1 ] && [ -d "$SELECTED_BACKUP/memories" ]; then
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
# 内部函数: 自动重置 Windsurf ID（无确认提示，供清理流程自动调用）
# ----------------------------------------------------------------------------
reset_windsurf_id_auto() {
    INSTALLATION_ID_FILE="$WINDSURF_DIR/installation_id"
    MACHINE_ID_FILE="$HOME/.config/Windsurf/machineid"
    STORAGE_JSON="$HOME/.config/Windsurf/User/globalStorage/storage.json"

    # 生成新的 UUID
    NEW_INSTALL_ID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen 2>/dev/null || python3 -c "import uuid; print(uuid.uuid4())" 2>/dev/null)
    NEW_MACHINE_ID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen 2>/dev/null || python3 -c "import uuid; print(uuid.uuid4())" 2>/dev/null)
    NEW_DEV_DEVICE_ID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen 2>/dev/null || python3 -c "import uuid; print(uuid.uuid4())" 2>/dev/null)
    NEW_SQM_ID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen 2>/dev/null || python3 -c "import uuid; print(uuid.uuid4().hex.upper())" 2>/dev/null)
    NEW_MAC_MACHINE_ID=$(od -An -tx1 -N16 /dev/urandom | tr -d ' \n')
    NEW_TELEMETRY_MACHINE_ID=$(od -An -tx1 -N32 /dev/urandom | tr -d ' \n')

    if [ -f "$INSTALLATION_ID_FILE" ] || [ -d "$(dirname "$INSTALLATION_ID_FILE")" ]; then
        echo "$NEW_INSTALL_ID" > "$INSTALLATION_ID_FILE"
    fi
    if [ -f "$MACHINE_ID_FILE" ] || [ -d "$(dirname "$MACHINE_ID_FILE")" ]; then
        echo "$NEW_MACHINE_ID" > "$MACHINE_ID_FILE"
    fi
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
    # VSCode/Windsurf 会把 telemetry 同时镜像到 SQLite 里，只改 storage.json 会被覆盖
    STATE_DB="$HOME/.config/Windsurf/User/globalStorage/state.vscdb"
    if [ -f "$STATE_DB" ] && command -v sqlite3 &>/dev/null; then
        sqlite3 "$STATE_DB" <<SQLEOF 2>/dev/null
UPDATE ItemTable SET value = '"$NEW_TELEMETRY_MACHINE_ID"' WHERE key = 'telemetry.machineId';
UPDATE ItemTable SET value = '"$NEW_DEV_DEVICE_ID"' WHERE key = 'telemetry.devDeviceId';
UPDATE ItemTable SET value = '"$NEW_SQM_ID"' WHERE key = 'telemetry.sqmId';
UPDATE ItemTable SET value = '"$NEW_MAC_MACHINE_ID"' WHERE key = 'telemetry.macMachineId';
UPDATE ItemTable SET value = '"$NEW_INSTALL_ID"' WHERE key = 'storage.serviceMachineId';
SQLEOF
    fi

    # 【Linux 补强】尝试刷新 /etc/machine-id（需要 root，失败则跳过）
    # 说明：这是 systemd 层面的机器标识，Windsurf/Electron 不直接读，但某些 sdk 会用
    # 修改它影响面较大，仅在 --system 参数时执行（默认不动）
    # 此处不主动动 /etc/machine-id，以保守为主

    print_success "Windsurf ID 已自动重置（含 storage.json + state.vscdb 同步）"
    echo -e "  installation_id: ${GREEN}$NEW_INSTALL_ID${NC}"
    echo -e "  machineid:       ${GREEN}$NEW_MACHINE_ID${NC}"
    echo -e "  telemetry.*:     ${GREEN}已同步到 storage.json 和 state.vscdb${NC}"
}

# ----------------------------------------------------------------------------
# 内部函数: 清理流程末尾统一调用的"强制重置设备 ID"入口
# 默认行为：强制重置（用户要求，用于绕过限速、刷新会话、伪装新设备）
# 逃生通道：执行前设置环境变量 FORCE_RESET_ID=0 即可完全跳过
# ----------------------------------------------------------------------------
auto_reset_after_clean() {
    if [ "${FORCE_RESET_ID:-1}" = "0" ] || [ "${FORCE_RESET_ID:-1}" = "false" ]; then
        print_info "已跳过设备 ID 重置（FORCE_RESET_ID=0）"
        return 0
    fi

    if [ "${_IN_BATCH_REPAIR:-0}" = "1" ]; then
        return 0
    fi

    echo ""
    echo -e "${CYAN}================ 清理后强制重置 Windsurf 设备 ID ================${NC}"
    print_warning "此为用户默认行为：每次清理完成后自动重置设备标识"
    print_warning "预期影响：Windsurf 服务端会识别为新设备，可能需要重新登录一次"
    print_info   "如需关闭此行为：下次运行前加 FORCE_RESET_ID=0 bash fix-windsurf-linux.sh"
    echo ""

    if pgrep -f "windsurf" &>/dev/null; then
        print_warning "检测到 Windsurf 正在运行，建议先关闭再重置，以免 storage.json 被覆盖"
        print_info "将等待 3 秒后继续（Ctrl+C 可取消）..."
        sleep 3
    fi

    reset_windsurf_id_auto
    echo -e "${CYAN}================================================================${NC}"
}

# ----------------------------------------------------------------------------
# 功能21: 重置 Windsurf ID
# ----------------------------------------------------------------------------
reset_windsurf_id() {
    print_info "重置 Windsurf ID..."

    INSTALLATION_ID_FILE="$WINDSURF_DIR/installation_id"
    MACHINE_ID_FILE="$HOME/.config/Windsurf/machineid"
    STORAGE_JSON="$HOME/.config/Windsurf/User/globalStorage/storage.json"

    echo ""
    echo -e "${CYAN}当前 Windsurf ID 信息:${NC}"
    echo ""

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
        check_windsurf_running

        NEW_INSTALL_ID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen 2>/dev/null || python3 -c "import uuid; print(uuid.uuid4())" 2>/dev/null)
        NEW_MACHINE_ID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen 2>/dev/null || python3 -c "import uuid; print(uuid.uuid4())" 2>/dev/null)
        NEW_DEV_DEVICE_ID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen 2>/dev/null || python3 -c "import uuid; print(uuid.uuid4())" 2>/dev/null)
        NEW_SQM_ID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen 2>/dev/null || python3 -c "import uuid; print(uuid.uuid4().hex.upper())" 2>/dev/null)
        NEW_MAC_MACHINE_ID=$(od -An -tx1 -N16 /dev/urandom | tr -d ' \n')
        NEW_TELEMETRY_MACHINE_ID=$(od -An -tx1 -N32 /dev/urandom | tr -d ' \n')

        echo ""
        print_info "生成新 ID..."

        if [ -f "$INSTALLATION_ID_FILE" ] || [ -d "$(dirname "$INSTALLATION_ID_FILE")" ]; then
            echo "$NEW_INSTALL_ID" > "$INSTALLATION_ID_FILE"
            print_success "installation_id 已重置: $NEW_INSTALL_ID"
        fi

        if [ -f "$MACHINE_ID_FILE" ] || [ -d "$(dirname "$MACHINE_ID_FILE")" ]; then
            echo "$NEW_MACHINE_ID" > "$MACHINE_ID_FILE"
            print_success "machineid 已重置: $NEW_MACHINE_ID"
        fi

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
    echo "  4) 清理开发工具缓存 (npm/pip/apt/Maven等)"
    echo "  5) 清理 Linux 系统缓存 (日志/临时文件/旧备份等)"
    echo "  6) 磁盘空间分析"
    echo ""
    echo -e "${YELLOW}== MCP 相关 ==${NC}"
    echo "  7) MCP 诊断 (检查MCP加载问题)"
    echo "  8) 重置 MCP 配置"
    echo ""
    echo -e "${YELLOW}== 终端相关 ==${NC}"
    echo "  9) 修复 chrome-sandbox 权限 (解决静默崩溃)"
    echo "  10) 配置终端设置"
    echo "  11) 修复 systemd 终端上下文问题"
    echo "  12) 检测 shell 主题冲突"
    echo ""
    echo -e "${YELLOW}== 其他 ==${NC}"
    echo "  13) 生成诊断报告"
    echo "  14) 完整修复 (执行所有步骤)"
    echo ""
    echo -e "${YELLOW}== 配置备份与 ID 管理 ==${NC}"
    echo "  19) 备份 MCP 配置 / Skills / 全局 Rules"
    echo "  20) 还原 MCP 配置 / Skills / 全局 Rules"
    echo "  21) 重置 Windsurf ID (重新生成所有标识)"
    echo ""
    echo -e "${YELLOW}== 深度优化 ==${NC}"
    echo "  15) 深度清理运行时缓存 (保留对话历史，推荐)"
    echo "  16) Windsurf 进程资源监控"
    echo "  17) 一键智能优化 (保留对话历史)"
    echo ""
    echo -e "${YELLOW}== AI 工具清理 ==${NC}"
    echo "  18) 清理 Claude Code / codex / gemini-cli / opencode 垃圾缓存"
    echo ""
    echo "  0) 退出"
    echo ""
    echo -ne ${CYAN}请输入选项 [0-21]: ${NC}
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
        9) fix_chrome_sandbox ;;
        10) configure_terminal_settings ;;
        11) fix_systemd_osc_context ;;
        12) detect_shell_theme_conflicts ;;
        13) generate_diagnostic_report ;;
        14) full_repair ;;
        15) deep_clean_runtime_cache ;;
        16) monitor_windsurf_processes ;;
        17) smart_optimize ;;
        18) clean_ai_tool_garbage ;;
        19) backup_mcp_skills_rules ;;
        20) restore_mcp_skills_rules ;;
        21) reset_windsurf_id ;;
        0) 
            echo ""
            print_info "感谢使用 Windsurf 修复工具"
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
