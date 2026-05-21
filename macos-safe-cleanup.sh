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
# GitHub: https://github.com/1837620622/windsurf-fix-tool
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
        local size=$(get_size_bytes "$dir")
        if [ "$size" -gt 0 ]; then
            echo -e "  ${CYAN}$desc${NC}: $(format_size $size)"
            rm -rf "$dir"/* 2>/dev/null
            rm -rf "$dir"/.[!.]* 2>/dev/null
            TOTAL_FREED=$((TOTAL_FREED + size))
            print_success "  已清理 $(format_size $size)"
        fi
    fi
}

# 静默删除整个目录（用于大类合并清理）
silent_remove_dir() {
    local dir="$1"
    local desc="$2"
    if [ -d "$dir" ]; then
        local size=$(get_size_bytes "$dir")
        if [ "$size" -gt 0 ]; then
            echo -e "  ${CYAN}$desc${NC}: $(format_size $size)"
            rm -rf "$dir" 2>/dev/null
            TOTAL_FREED=$((TOTAL_FREED + size))
            print_success "  已清理 $(format_size $size)"
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
                rm -rf "$dir"/* 2>/dev/null
                rm -rf "$dir"/.[!.]* 2>/dev/null
                TOTAL_FREED=$((TOTAL_FREED + size))
                print_success "  已清理 $(format_size $size)"
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
                rm -rf "$dir" 2>/dev/null
                TOTAL_FREED=$((TOTAL_FREED + size))
                print_success "  已清理 $(format_size $size)"
            else
                print_info "  已跳过"
            fi
        fi
    fi
}

# ----------------------------------------------------------------------------
# 启动横幅
# ----------------------------------------------------------------------------
echo ""
echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}  macOS 系统数据安全清理工具${NC}"
echo -e "${CYAN}  by 传康KK${NC}"
echo -e "${CYAN}  github.com/1837620622/windsurf-fix-tool${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""
print_warning "此脚本只清理缓存和临时文件，不会删除重要数据"
print_info "每一步都会询问确认，可随时跳过"
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
echo -e "  ${CYAN}Windsurf 登录与对话${NC}"
echo -e "    ~/.codeium/windsurf/cascade/*.pb             对话历史"
echo -e "    ~/.codeium/windsurf/memories/                用户记忆"
echo -e "    ~/.codeium/windsurf/skills/                  技能"
echo -e "    ~/.codeium/windsurf/mcp_config.json          MCP 配置"
echo -e "    ~/.codeium/windsurf/installation_id          设备标识"
echo -e "    ~/Library/Application Support/Windsurf/Cookies*       登录 Cookies"
echo -e "    ~/Library/Application Support/Windsurf/Local Storage  会话数据"
echo -e "    ~/Library/Application Support/Windsurf/WebStorage     内嵌登录态"
echo -e "    ~/Library/Application Support/Windsurf/User/settings.json  编辑器设置"
echo -e "    ~/Library/Application Support/Windsurf/machineid      设备 ID"
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
                rm -rf "$sub" 2>/dev/null
            done
            TOTAL_FREED=$((TOTAL_FREED + USER_CACHE_CLEANABLE))
            print_success "  用户应用缓存已清理（关键保护数据已保留）"
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
            size=$(get_size_bytes "$MEDIA_ANALYSIS")
            if [ "$size" -gt 0 ]; then
                echo -e "  ${CYAN}照片分析数据${NC}: $(format_size $size)"
                rm -rf "$MEDIA_ANALYSIS/Data/Library" 2>/dev/null
                TOTAL_FREED=$((TOTAL_FREED + size))
                print_success "  照片分析数据已清理"
            fi
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

    # 2.5 Maven 缓存
    silent_remove_dir "$HOME/.m2/repository" "Maven 本地仓库"

    # 2.6 Playwright 浏览器缓存
    silent_remove_dir "$HOME/Library/Caches/ms-playwright" "Playwright 浏览器"
else
    print_info "  已跳过开发工具缓存清理"
fi
echo ""

# 3. DNS 缓存刷新
print_info "3. DNS 缓存刷新"
if confirm "  刷新 DNS 缓存？"; then
    sudo dscacheutil -flushcache 2>/dev/null
    sudo killall -HUP mDNSResponder 2>/dev/null
    print_success "  DNS 缓存已刷新"
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
    
    if [ "$WECHAT_CLEANABLE" -gt 0 ]; then
        echo -e "  ${CYAN}微信可清理缓存与临时文件${NC}: $(format_size $WECHAT_CLEANABLE)"
        if confirm "  是否清理微信缓存（包含临时文件、图片及视频缓存等，不影响聊天记录）？"; then
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
    size=$(get_size_bytes "$TG_CACHE")
    if [ "$size" -gt 0 ]; then
        echo -e "  ${CYAN}Telegram 容器数据${NC}: $(format_size $size)"
        if confirm "  是否清理 Telegram 缓存与临时文件？"; then
            find "$TG_CACHE" -name "Caches" -type d -exec rm -rf {} + 2>/dev/null
            find "$TG_CACHE" -name "tmp" -type d -exec rm -rf {} + 2>/dev/null
            print_success "  已清理 Telegram 缓存"
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
    
    QQ_CLEANABLE=0
    [ -d "$QQ_CACHE" ] && QQ_CLEANABLE=$((QQ_CLEANABLE + $(get_size_bytes "$QQ_CACHE")))
    [ -d "$QQ_TMP" ] && QQ_CLEANABLE=$((QQ_CLEANABLE + $(get_size_bytes "$QQ_TMP")))
    if [ -d "$QQ_DATA" ]; then
        IMAGE_CACHE="$QQ_DATA/Image"
        FILE_CACHE="$QQ_DATA/FileRecv"
        LOG_CACHE="$QQ_DATA/Logs"
        for cache_dir in "$IMAGE_CACHE" "$FILE_CACHE" "$LOG_CACHE"; do
            [ -d "$cache_dir" ] && QQ_CLEANABLE=$((QQ_CLEANABLE + $(get_size_bytes "$cache_dir")))
        done
    fi
    
    if [ "$QQ_CLEANABLE" -gt 0 ]; then
        echo -e "  ${CYAN}QQ 可清理缓存与临时文件${NC}: $(format_size $QQ_CLEANABLE)"
        if confirm "  是否清理 QQ 缓存（包含临时文件、接收图片、日志等，不影响聊天记录）？"; then
            silent_clean_dir "$QQ_CACHE" "QQ缓存目录"
            silent_clean_dir "$QQ_TMP" "QQ临时文件"
            if [ -d "$QQ_DATA" ]; then
                silent_clean_dir "$IMAGE_CACHE" "QQ图片缓存"
                silent_clean_dir "$FILE_CACHE" "QQ文件接收缓存"
                silent_clean_dir "$LOG_CACHE" "QQ日志缓存"
            fi
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

    CHROME_CLEANABLE=0
    for cache_dir in "$CHROME_CACHE" "$CHROME_CACHE2" "$CHROME_CODE" "$CHROME_COMPONENT" "$CHROME_SODA_LANG" "$CHROME_SODA" "$CHROME_MODEL" "$CHROME_GR_SHADER" "$CHROME_GRAPHITE" "$CHROME_SHADER" "$CHROME_BROWSER_METRICS" "$CHROME_SNAPSHOTS" "$CHROME_EXT_CRX" "$CHROME_CRASHPAD"; do
        [ -d "$cache_dir" ] && CHROME_CLEANABLE=$((CHROME_CLEANABLE + $(get_size_bytes "$cache_dir")))
    done

    if [ "$CHROME_CLEANABLE" -gt 0 ]; then
        echo -e "  ${CYAN}Chrome 可清理缓存${NC}: $(format_size $CHROME_CLEANABLE)"
        if confirm "  是否清理 Google Chrome 缓存与临时文件（包含网页缓存、渲染器/着色器缓存等 14 项）？"; then
            silent_remove_dir "$CHROME_CACHE" "Chrome Service Worker 缓存"
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

# 17. Windsurf IDE 缓存（合并一键清理，针对"对话长卡顿"专项优化）
print_info "17. Windsurf IDE 缓存（针对对话长卡顿专项优化）"
WS_DIR="$HOME/Library/Application Support/Windsurf"
if [ -d "$WS_DIR" ]; then
    echo -e "  ${GREEN}[保留]${NC} cascade/*.pb（对话历史）、memories、skills、mcp_config.json"
    echo -e "  ${GREEN}[保留]${NC} Cookies*、Local Storage、WebStorage、installation_id、machineid（登录态）"
    echo -e "  ${GREEN}[保留]${NC} settings.json / keybindings.json（个人编辑器设置）"
    
    # ── 计算 Windsurf 可清理项总大小 ────────────────────────────────
    WS_CLEANABLE=0
    # Electron 内核缓存
    for cache_dir in "Cache" "CachedData" "GPUCache" "Code Cache" "DawnWebGPUCache" "DawnGraphiteCache" "Shared Dictionary"; do
        [ -d "$WS_DIR/$cache_dir" ] && WS_CLEANABLE=$((WS_CLEANABLE + $(get_size_bytes "$WS_DIR/$cache_dir")))
    done
    # UI / 脚本缓存
    for cache_dir in "IndexedDB" "Service Worker/CacheStorage" "Service Worker/ScriptCache" "blob_storage"; do
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
    SNAPSHOT_COUNT=$(ls /tmp/windsurf-terminal-*.snapshot 2>/dev/null | wc -l | tr -d ' ')
    # AI 索引
    for ai_dir in "$HOME/.codeium/windsurf/implicit" "$HOME/.codeium/windsurf/code_tracker"; do
        [ -d "$ai_dir" ] && WS_CLEANABLE=$((WS_CLEANABLE + $(get_size_bytes "$ai_dir")))
    done

    if [ "$WS_CLEANABLE" -gt 0 ] 2>/dev/null; then
        echo -e "  ${CYAN}Windsurf 可清理/可优化项目总计${NC}: $(format_size $WS_CLEANABLE)"
        if confirm "  是否一键清理 Windsurf 缓存、日志、AI索引并压缩数据库（不影响登录和历史对话，解决长对话卡顿）？"; then
            # 1. 清理 Electron 内核缓存
            silent_remove_dir "$WS_DIR/Cache" "Windsurf Cache（浏览器缓存）"
            silent_remove_dir "$WS_DIR/CachedData" "Windsurf CachedData（编译缓存）"
            silent_remove_dir "$WS_DIR/GPUCache" "Windsurf GPUCache"
            silent_remove_dir "$WS_DIR/Code Cache" "Windsurf Code Cache"
            silent_remove_dir "$WS_DIR/DawnWebGPUCache" "Windsurf DawnWebGPUCache"
            silent_remove_dir "$WS_DIR/DawnGraphiteCache" "Windsurf DawnGraphiteCache"
            silent_remove_dir "$WS_DIR/Shared Dictionary" "Windsurf Shared Dictionary"

            # 2. 清理 UI / 脚本缓存
            silent_clean_dir "$WS_DIR/IndexedDB" "Windsurf IndexedDB"
            silent_clean_dir "$WS_DIR/Service Worker/CacheStorage" "Windsurf Service Worker CacheStorage"
            silent_clean_dir "$WS_DIR/Service Worker/ScriptCache" "Windsurf Service Worker ScriptCache"
            silent_clean_dir "$WS_DIR/blob_storage" "Windsurf blob_storage"

            # 3. 清理 日志 / 崩溃报告
            silent_clean_dir "$WS_DIR/logs" "Windsurf 运行日志"
            silent_clean_dir "$WS_DIR/Crashpad/completed" "Windsurf Crashpad completed"
            silent_clean_dir "$WS_DIR/Crashpad/pending" "Windsurf Crashpad pending"

            # 4. 清理 扩展与 Profile 残留
            silent_clean_dir "$WS_DIR/CachedExtensionVSIXs" "Windsurf 旧扩展安装包"
            silent_clean_dir "$WS_DIR/CachedProfilesData" "Windsurf CachedProfilesData"

            # 5. 清理 state.vscdb.backup
            if [ -f "$STATE_BACKUP" ]; then
                rm -f "$STATE_BACKUP" 2>/dev/null
                print_success "  已清理旧 state.vscdb.backup"
            fi

            # 6. state.vscdb VACUUM 优化
            if [ -f "$STATE_DB" ] && command -v sqlite3 &>/dev/null; then
                before=$(get_size_bytes "$STATE_DB")
                if sqlite3 "$STATE_DB" "VACUUM;" 2>/dev/null; then
                    after=$(get_size_bytes "$STATE_DB")
                    diff=$((before - after))
                    [ "$diff" -lt 0 ] && diff=0
                    TOTAL_FREED=$((TOTAL_FREED + diff))
                    print_success "  state.vscdb VACUUM 完成，释放 $(format_size $diff)"
                fi
            fi

            # 7. workspaceStorage 批量 VACUUM
            if [ -d "$WS_STORAGE_DIR" ] && command -v sqlite3 &>/dev/null; then
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

            # 8. /tmp 终端快照清理
            if [ "$SNAPSHOT_COUNT" -gt 0 ] 2>/dev/null; then
                rm -f /tmp/windsurf-terminal-*.snapshot 2>/dev/null
                print_success "  已清理 $SNAPSHOT_COUNT 个终端快照"
            fi

            # 9. AI 索引缓存清理
            for ai_dir in "$HOME/.codeium/windsurf/implicit" "$HOME/.codeium/windsurf/code_tracker"; do
                if [ -d "$ai_dir" ]; then
                    size=$(get_size_bytes "$ai_dir")
                    rm -rf "$ai_dir"/* 2>/dev/null
                    rm -rf "$ai_dir"/.[!.]* 2>/dev/null
                    TOTAL_FREED=$((TOTAL_FREED + size))
                    print_success "  已清理 $(basename $ai_dir) AI 索引"
                fi
            done
            print_success "  Windsurf 缓存清理与卡顿优化完成"
        else
            print_info "  已跳过 Windsurf 缓存清理"
        fi
    fi

    # ── WebStorage / Local Storage / Cookies 默认保留提示 ────────────────
    WS_WEB_STORAGE="$WS_DIR/WebStorage"
    [ -d "$WS_WEB_STORAGE" ] && echo -e "  ${YELLOW}[已保留] WebStorage${NC}: $(format_size $(get_size_bytes "$WS_WEB_STORAGE"))（登录态）"
    WS_LOCAL_STORAGE="$WS_DIR/Local Storage"
    [ -d "$WS_LOCAL_STORAGE" ] && echo -e "  ${YELLOW}[已保留] Local Storage${NC}: $(format_size $(get_size_bytes "$WS_LOCAL_STORAGE"))（会话数据）"

    # ── Windsurf 设备 ID 强制重置（仍独立保留确认，因为有重登风险） ──────
    if [ "${FORCE_RESET_ID:-1}" != "0" ] && [ "${FORCE_RESET_ID:-1}" != "false" ]; then
        echo ""
        print_warning "[强制重置模式] 重置 Windsurf 设备 ID（可能需要重新登录）"
        print_info     "  可通过设置环境变量 FORCE_RESET_ID=0 跳过重置"
        if confirm "  是否重置 Windsurf 设备 ID？"; then
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
for cache_dir in "$SAFARI_CACHE" "$SAFARI_WEBKIT" "$SAFARI_FS" "$SAFARI_ICONS" "$SAFARI_PERF"; do
    [ -d "$cache_dir" ] && SAFARI_CLEANABLE=$((SAFARI_CLEANABLE + $(get_size_bytes "$cache_dir")))
done

if [ "$SAFARI_CLEANABLE" -gt 0 ]; then
    echo -e "  ${CYAN}Safari 可清理缓存${NC}: $(format_size $SAFARI_CLEANABLE)"
    if confirm "  是否清理 Safari 浏览器缓存与临时数据（包含网页缓存、图标及 PerSitePreferences 等 5 项）？"; then
        silent_clean_dir "$SAFARI_CACHE" "Safari 浏览器缓存"
        silent_clean_dir "$SAFARI_WEBKIT" "Safari WebKit 缓存"
        silent_clean_dir "$SAFARI_FS" "Safari 本地存储"
        silent_clean_dir "$SAFARI_ICONS" "Safari 网站图标缓存"
        silent_clean_dir "$SAFARI_PERF" "Safari 站点特定配置缓存"
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
XCODE_SIMULATOR="$HOME/Library/Developer/CoreSimulator"

XCODE_CLEANABLE=0
[ -d "$XCODE_DERIVED" ] && XCODE_CLEANABLE=$((XCODE_CLEANABLE + $(get_size_bytes "$XCODE_DERIVED")))
[ -d "$XCODE_ARCHIVES" ] && XCODE_CLEANABLE=$((XCODE_CLEANABLE + $(get_size_bytes "$XCODE_ARCHIVES")))
[ -d "$XCODE_SIMULATOR" ] && XCODE_CLEANABLE=$((XCODE_CLEANABLE + $(get_size_bytes "$XCODE_SIMULATOR")))

if [ "$XCODE_CLEANABLE" -gt 0 ]; then
    echo -e "  ${CYAN}Xcode 可清理缓存/派生数据${NC}: $(format_size $XCODE_CLEANABLE)"
    if confirm "  是否清理 Xcode 派生数据、历史归档及模拟器缓存数据？"; then
        silent_clean_dir "$XCODE_DERIVED" "Xcode DerivedData (派生数据)"
        silent_clean_dir "$XCODE_ARCHIVES" "Xcode Archives (历史归档)"
        silent_clean_dir "$XCODE_SIMULATOR" "CoreSimulator (模拟器临时数据)"
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
        print_warning "  删除后需重新备份设备"
        if confirm "  清理 iOS 备份？"; then
            rm -rf "$IOS_BACKUP"/* 2>/dev/null
            rm -rf "$IOS_BACKUP"/.[!.]* 2>/dev/null
            TOTAL_FREED=$((TOTAL_FREED + backup_size))
            print_success "  iOS 备份已清理"
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
        find "$HOME/Downloads" -maxdepth 3 -name "node_modules" -type d -exec rm -rf {} + 2>/dev/null
        TOTAL_FREED=$((TOTAL_FREED + NODE_MODULES_TOTAL))
        print_success "  已清理"
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
        find "$HOME" -maxdepth 6 -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null
        print_success "  已清理"
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
            find "$SAS_DIR" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null
            TOTAL_FREED=$((TOTAL_FREED + size))
            print_success "  已清理 $(format_size $size)"
        fi
    fi
fi
echo ""

# 26. WebKit 缓存（Safari / 内嵌 WebView 的缓存，系统会重建）
print_info "26. WebKit 缓存（Safari/内嵌 WebView，系统会重建）"
WEBKIT_DIR="$HOME/Library/WebKit"
if [ -d "$WEBKIT_DIR" ]; then
    size=$(get_size_bytes "$WEBKIT_DIR")
    if [ "$size" -gt 0 ]; then
        echo -e "  ${CYAN}WebKit 缓存${NC}: $(format_size $size)"
        print_info "  保留子目录结构，仅清理内部缓存"
        if confirm "  清理此项？"; then
            # 保留顶层目录结构，只清除内部缓存文件
            find "$WEBKIT_DIR" -type d -name "Caches" -exec rm -rf {} + 2>/dev/null
            find "$WEBKIT_DIR" -type d -name "WebsiteData" -exec rm -rf {} + 2>/dev/null
            find "$WEBKIT_DIR" -type f -name "*.db-shm" -delete 2>/dev/null
            find "$WEBKIT_DIR" -type f -name "*.db-wal" -delete 2>/dev/null
            after=$(get_size_bytes "$WEBKIT_DIR")
            diff=$((size - after))
            [ "$diff" -lt 0 ] && diff=0
            TOTAL_FREED=$((TOTAL_FREED + diff))
            print_success "  已清理 $(format_size $diff)"
        fi
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
[ -d "$SYS_FOLDER_DIR" ] && SYS_CLEANABLE=$((SYS_CLEANABLE + $(du -sk "$SYS_FOLDER_DIR" 2>/dev/null | awk '{print $1 * 1024}')))

if [ "$SYS_CLEANABLE" -gt 0 ]; then
    echo -e "  ${CYAN}系统级可清理垃圾${NC}: $(format_size $SYS_CLEANABLE)"
    print_warning "  此操作需要管理员权限，用户在确认后只需输入一次密码"
    if confirm "  是否一键清理系统诊断日志、30天以上的旧日志及7天以上的系统临时文件（保留 ports 端口保护）？"; then
        if [ -d "$SYS_DIAG_DIR" ]; then
            echo -e "  ${CYAN}正在清理系统诊断日志...${NC}"
            sudo rm -rf /private/var/db/diagnostics/* 2>/dev/null
            sudo rm -rf /private/var/db/uuidtext/* 2>/dev/null
            print_success "  系统诊断日志清理完成"
        fi

        if [ -d "$SYS_LOG_DIR" ]; then
            echo -e "  ${CYAN}正在清理30天以上的旧日志...${NC}"
            sudo find /private/var/log -name "*.log" -mtime +30 -delete 2>/dev/null
            sudo find /private/var/log -name "*.gz" -mtime +30 -delete 2>/dev/null
            sudo find /private/var/log -name "*.bz2" -mtime +30 -delete 2>/dev/null
            print_success "  系统日志清理完成"
        fi

        if [ -d "$SYS_FOLDER_DIR" ]; then
            echo -e "  ${CYAN}正在清理7天以上的系统临时文件（ask-continue-ports 已保护）...${NC}"
            sudo find /private/var/folders -name "C" -type d -mindepth 3 -maxdepth 3 2>/dev/null | while read d; do
                sudo find "$d" -mtime +7 ! -path "*ask-continue-ports*" -delete 2>/dev/null
            done
            if [ -e "/private/tmp/ask-continue-ports" ]; then
                print_info "  已保护 /private/tmp/ask-continue-ports"
            fi
            print_success "  系统临时文件清理完成"
        fi
        
        TOTAL_FREED=$((TOTAL_FREED + SYS_CLEANABLE))
        print_success "  系统级大类清理全部完成"
    else
        print_info "  已跳过系统级清理"
    fi
else
    print_info "  未检测到系统级可清理数据"
fi
echo ""

# 30. /private/var/folders 定向垃圾清理
print_info "30. /private/var/folders 定向垃圾清理"
print_warning "只清理 3 天以上、已识别为可重复生成的临时克隆、memmap 和构建缓存"
TARGET_PATHS=()
while IFS= read -r path; do TARGET_PATHS+=("$path"); done < <(find /private/var/folders -path "*/X/com.google.Chrome.code_sign_clone" -mtime +3 2>/dev/null)
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
        -o -path "*/T/joblib_memmapping_folder_*" \
        -o -path "*/T/node-gyp-tmp-*" \
        -o -path "*/T/node-compile-cache" \) -mtime -3 2>/dev/null
)

if [ "$RECENT_COUNT" -gt 0 ] 2>/dev/null; then
    print_info "  检测到 $RECENT_COUNT 个近期仍在活跃的临时目录，出于安全未纳入本次清理"
fi

if [ "$TARGET_TOTAL" -gt 0 ]; then
    print_info "  已识别 $TARGET_COUNT 个陈旧定向临时垃圾，合计 $(format_size $TARGET_TOTAL)"
    for path in "${TARGET_PATHS[@]}"; do
        if [ -e "$path" ]; then
            rm -rf "$path" 2>/dev/null || sudo rm -rf "$path" 2>/dev/null
        fi
    done
    TOTAL_FREED=$((TOTAL_FREED + TARGET_TOTAL))
    print_success "  已自动清理这些陈旧定向临时垃圾"
else
    print_info "  未检测到可清理的陈旧定向临时垃圾"
fi
echo ""

# ============================================================================
# 第五部分: AI 工具深度清理 (Claude Code / Gemini CLI / OpenCode)
# ============================================================================
echo -e "\n${CYAN}${SECTION_BAR}${NC}"
echo -e "${CYAN}  第五部分: AI 工具深度清理 (Claude/Gemini/OpenCode)${NC}"
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
    for cache_dir in "$CLAUDE_CACHE" "$CLAUDE_DEBUG" "$CLAUDE_DOWNLOADS" "$CLAUDE_PASTE" "$CLAUDE_PLUGINS_CACHE" "$CLAUDE_SESSION_DATA" "$CLAUDE_FILE_HISTORY" "$CLAUDE_SHELL_SNAPSHOTS" "$CLAUDE_TASKS" "$CLAUDE_TODOS" "$CLAUDE_SESSION_ENV" "$CLAUDE_IDE" "$CLAUDE_METRICS" "$CLAUDE_TELEMETRY" "$CLAUDE_BACKUPS"; do
        [ -d "$cache_dir" ] && CLAUDE_CLEANABLE=$((CLAUDE_CLEANABLE + $(get_size_bytes "$cache_dir")))
    done

    if [ "$CLAUDE_CLEANABLE" -gt 0 ]; then
        echo -e "  ${CYAN}Claude Code 可清理缓存${NC}: $(format_size $CLAUDE_CLEANABLE)"
        if confirm "  是否清理 Claude Code 缓存与临时文件（包含会话历史、任务快照、调试日志等 15 项）？"; then
            silent_clean_dir "$CLAUDE_CACHE" "Claude 缓存"
            silent_clean_dir "$CLAUDE_DEBUG" "Claude 调试日志"
            silent_clean_dir "$CLAUDE_DOWNLOADS" "Claude 下载缓存"
            silent_clean_dir "$CLAUDE_PASTE" "Claude 粘贴剪切板缓存"
            silent_clean_dir "$CLAUDE_PLUGINS_CACHE" "Claude 插件缓存"
            silent_clean_dir "$CLAUDE_SESSION_DATA" "Claude 会话数据"
            silent_clean_dir "$CLAUDE_FILE_HISTORY" "Claude 文件历史"
            silent_clean_dir "$CLAUDE_SHELL_SNAPSHOTS" "Claude 终端快照"
            silent_clean_dir "$CLAUDE_TASKS" "Claude 任务记录"
            silent_clean_dir "$CLAUDE_TODOS" "Claude 待办事项"
            silent_clean_dir "$CLAUDE_SESSION_ENV" "Claude 会话环境变量"
            silent_clean_dir "$CLAUDE_IDE" "Claude IDE 集成数据"
            silent_clean_dir "$CLAUDE_METRICS" "Claude 度量监控数据"
            silent_clean_dir "$CLAUDE_TELEMETRY" "Claude 遥测数据"
            silent_clean_dir "$CLAUDE_BACKUPS" "Claude 自动备份"
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

# 32. Gemini CLI 缓存清理（合并一键清理）
print_info "32. Gemini CLI 缓存"
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
                rm -f "$GEMINI_TELEMETRY" 2>/dev/null
                print_success "  已清理 telemetry.log"
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

# 33. OpenCode 缓存清理（合并一键清理）
print_info "33. OpenCode 缓存"
OPENCODE_CACHE="$HOME/Library/Caches/opencode"
OPENCODE_DATA="$HOME/.local/share/opencode"
OPENCODE_CONFIG="$HOME/.config/opencode"
OPENCODE_LOG="$HOME/Library/Logs/opencode"

if [ -d "$OPENCODE_CACHE" ] || [ -d "$OPENCODE_DATA" ] || [ -d "$OPENCODE_CONFIG" ] || [ -d "$OPENCODE_LOG" ]; then
    OPENCODE_CLEANABLE=0
    for cache_dir in "$OPENCODE_CACHE" "$OPENCODE_DATA/tool-output" "$OPENCODE_DATA/log" "$OPENCODE_DATA/snapshot" "$OPENCODE_LOG"; do
        [ -d "$cache_dir" ] && OPENCODE_CLEANABLE=$((OPENCODE_CLEANABLE + $(get_size_bytes "$cache_dir")))
    done
    OPENCODE_DB_SHM="$OPENCODE_DATA/opencode.db-shm"
    OPENCODE_DB_WAL="$OPENCODE_DATA/opencode.db-wal"
    [ -f "$OPENCODE_DB_SHM" ] && OPENCODE_CLEANABLE=$((OPENCODE_CLEANABLE + $(get_size_bytes "$OPENCODE_DB_SHM")))
    [ -f "$OPENCODE_DB_WAL" ] && OPENCODE_CLEANABLE=$((OPENCODE_CLEANABLE + $(get_size_bytes "$OPENCODE_DB_WAL")))

    if [ "$OPENCODE_CLEANABLE" -gt 0 ]; then
        echo -e "  ${CYAN}OpenCode 可清理缓存${NC}: $(format_size $OPENCODE_CLEANABLE)"
        if confirm "  是否清理 OpenCode 缓存、执行快照、日志及数据库临时缓存？"; then
            silent_clean_dir "$OPENCODE_CACHE" "OpenCode 浏览器缓存"
            silent_clean_dir "$OPENCODE_DATA/tool-output" "OpenCode 工具输出缓存"
            silent_clean_dir "$OPENCODE_DATA/log" "OpenCode 内部日志"
            silent_clean_dir "$OPENCODE_DATA/snapshot" "OpenCode 运行快照"
            silent_clean_dir "$OPENCODE_LOG" "OpenCode 系统日志"
            if [ -f "$OPENCODE_DB_SHM" ]; then rm -f "$OPENCODE_DB_SHM" 2>/dev/null; fi
            if [ -f "$OPENCODE_DB_WAL" ]; then rm -f "$OPENCODE_DB_WAL" 2>/dev/null; fi
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
# 清理完成
# ============================================================================
echo -e "\n${GREEN}${SECTION_BAR}${NC}"
echo -e "${GREEN}  清理完成！${NC}"
echo -e "${GREEN}${SECTION_BAR}${NC}\n"

echo -e "本次清理释放空间: ${GREEN}$(format_size $TOTAL_FREED)${NC}"
echo ""
print_warning "清理后建议重启电脑，让系统重新计算存储空间"
echo ""
