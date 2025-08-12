#!/bin/bash

# Claude Code Environment Setup Script (Enhanced)
# Author: X-@oops073111
# Purpose: Configure Claude Code environment with official/proxy API switching support
# Version: 2.0 - Added safety features and API switching

set -e  # Exit on error

# Colors for output
RED='\033[1;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# API Configuration
OFFICIAL_API_URL="https://api.anthropic.com"  # 官方使用 ANTHROPIC_API_URL
# 默认代理API URL
DEFAULT_PROXY_API_URL="default"
# 初始化为默认值，后续会被命令行参数覆盖
PROXY_API_URL="$DEFAULT_PROXY_API_URL"  # 第三方使用 ANTHROPIC_BASE_URL

# Pre-configured API Keys (用户可自定义)
# 官方密钥 (使用 ANTHROPIC_API_URL + https://api.anthropic.com)
OFFICIAL_API_KEY=""
# 第三方密钥 (使用 ANTHROPIC_BASE_URL + 代理服务器)
PROXY_API_KEY=""

# Global variables
USE_PROXY=false
API_ENDPOINT_URL=""  # 将根据模式设置为 ANTHROPIC_API_URL 或 ANTHROPIC_BASE_URL
API_VAR_NAME=""     # 存储使用的环境变量名
SKIP_JSON_UPDATE=false
USE_PRESET_KEYS=false

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_security() {
    echo -e "${MAGENTA}[SECURITY]${NC} $1"
}

print_prompt() {
    echo -e "${CYAN}[PROMPT]${NC} $1"
}

# Function to display current environment variables
display_current_env() {
    print_info "当前系统环境变量状态："
    echo -e "${BLUE}----------------------------------------${NC}"
    
    # Use printenv to get actual system environment variables
    local anthropic_vars=$(printenv | grep "^ANTHROPIC_" | sort)
    
    if [ -n "$anthropic_vars" ]; then
        # Display actual environment variables, but mask the API key for security
        echo "$anthropic_vars" | while IFS='=' read -r var_name var_value; do
            case "$var_name" in
                ANTHROPIC_API_KEY)
                    if [ ${#var_value} -gt 4 ]; then
                        echo "$var_name=****${var_value: -4}"
                    else
                        echo "$var_name=$var_value"
                    fi
                    ;;
                *)
                    echo "$var_name=$var_value"
                    ;;
            esac
        done
    else
        echo "未检测到ANTHROPIC相关环境变量"
    fi
    
    echo -e "${BLUE}----------------------------------------${NC}"
    
    # Intelligent configuration mode detection and requirements check
    local found_vars=$(printenv | grep "^ANTHROPIC_" | cut -d'=' -f1)
    
    echo -e "${YELLOW}配置模式检测：${NC}"
    
    # Determine current configuration mode
    local has_official_url=false
    local has_proxy_url=false
    local current_mode="未知"
    
    # Check for official configuration (ANTHROPIC_API_URL)
    if echo "$found_vars" | grep -q "^ANTHROPIC_API_URL$"; then
        has_official_url=true
        local api_url=$(printenv ANTHROPIC_API_URL)
        if [[ "$api_url" == "https://api.anthropic.com"* ]]; then
            echo -e "  ✅ 官方配置: ANTHROPIC_API_URL = $api_url"
            current_mode="官方"
        else
            echo -e "  ⚠️  可能的官方配置: ANTHROPIC_API_URL = $api_url"
            current_mode="官方(异常)"
        fi
    fi
    
    # Check for proxy configuration (ANTHROPIC_BASE_URL)
    if echo "$found_vars" | grep -q "^ANTHROPIC_BASE_URL$"; then
        has_proxy_url=true
        local base_url=$(printenv ANTHROPIC_BASE_URL)
        echo -e "  ⚠️  第三方配置: ANTHROPIC_BASE_URL = $base_url"
        if [ "$has_official_url" = false ]; then
            current_mode="第三方"
        else
            current_mode="混合(可能冲突)"
        fi
    fi
    
    # Show current detected mode
    echo -e "  🔍 检测到的模式: ${current_mode}"
    
    # Smart requirements check based on detected mode
    echo -e "\n${YELLOW}必要变量检查(基于检测到的模式)：${NC}"
    
    # API key is always required
    if echo "$found_vars" | grep -q "^ANTHROPIC_API_KEY$"; then
        echo -e "  ✅ API密钥: ANTHROPIC_API_KEY 已设置"
    else
        echo -e "  ❌ API密钥: ANTHROPIC_API_KEY 未设置 (必须)"
    fi
    
    # URL requirement depends on mode
    if [ "$has_official_url" = true ] || [ "$has_proxy_url" = true ]; then
        echo -e "  ✅ API端点: 已配置"
    else
        echo -e "  ❌ API端点: 未配置 (需要 ANTHROPIC_API_URL 或 ANTHROPIC_BASE_URL)"
    fi
    
    # AUTH token is optional but often expected
    if echo "$found_vars" | grep -q "^ANTHROPIC_AUTH_TOKEN$"; then
        echo -e "  ✅ 认证令牌: ANTHROPIC_AUTH_TOKEN 已设置"
    else
        echo -e "  ⚠️  认证令牌: ANTHROPIC_AUTH_TOKEN 未设置 (可选,但建议设置为空值)"
    fi
    echo -e "${BLUE}----------------------------------------${NC}"
}

# Function to show usage
show_usage() {
    echo "使用方法:"
    echo "  方式1 (手动指定密钥):"
    echo "    $0 <api-key> [--official|--proxy] [--skip-json]"
    echo ""
    echo "  方式2 (使用内置密钥):"
    echo "    $0 --official-preset   # 使用内置官方API密钥"
    echo "    $0 --proxy-preset     # 使用内置代理API密钥"
    echo ""
    echo "  方式3 (自定义代理API URL):"
    echo "    $0 <api-key> --proxy --proxy-url <proxy-url>"
    echo ""
    echo "  示例:"
    echo "    $0 sk-ant-xxxxx --proxy --proxy-url https://custom-proxy-api.com/api"
    echo ""
    echo "参数说明:"
    echo "  <api-key>         手动指定Anthropic API密钥"
    echo "  --official        使用官方API (默认,推荐)"
    echo "  --proxy           使用代理API (存在安全风险)"
    echo "  --official-preset 使用内置的官方API密钥和URL"
    echo "  --proxy-preset    使用内置的代理API密钥和URL"
    echo "  --skip-json       跳过.claude.json文件更新"
    echo ""
    echo "示例:"
    echo "  $0 sk-ant-xxxxx --official      # 手动指定密钥"
    echo "  $0 --official-preset            # 快捷切换到官方API"
    echo "  $0 --proxy-preset --skip-json   # 快捷切换到代理API"
}

# Function to show security warning for proxy mode
show_proxy_warning() {
    echo -e "\n${RED}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║                    ⚠️  安全警告 ⚠️                        ║${NC}"
    echo -e "${RED}╠══════════════════════════════════════════════════════════╣${NC}"
    echo -e "${RED}║  您选择了代理API模式，这存在以下风险：                    ║${NC}"
    echo -e "${RED}║                                                          ║${NC}"
    echo -e "${RED}║  🔥 API密钥可能被第三方获取                              ║${NC}"
    echo -e "${RED}║  🔥 对话内容可能被记录或监控                             ║${NC}"
    echo -e "${RED}║  🔥 服务稳定性无法保证                                   ║${NC}"
    echo -e "${RED}║  🔥 可能违反Anthropic服务条款                            ║${NC}"
    echo -e "${RED}║                                                          ║${NC}"
    echo -e "${RED}║  💡 强烈建议使用官方API: $0 <key> --official              ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════╝${NC}"
}

# Function to get user confirmation
get_user_confirmation() {
    local prompt="$1"
    local default="$2"
    
    while true; do
        print_prompt "$prompt [y/N]: "
        read -r response
        
        # Use default if no input
        if [ -z "$response" ]; then
            response="$default"
        fi
        
        case "$response" in
            [yY]|[yY][eE][sS])
                return 0
                ;;
            [nN]|[nN][oO])
                return 1
                ;;
            *)
                print_error "请输入 y/yes 或 n/no"
                ;;
        esac
    done
}

# Parse command line arguments
parse_arguments() {
    if [ $# -eq 0 ]; then
        print_error "缺少必要参数"
        show_usage
        exit 1
    fi
    
    # Check for preset modes first
    case "$1" in
        --official-preset)
            if [ -z "$OFFICIAL_API_KEY" ]; then
                print_error "官方API密钥未配置，请在脚本中设置 OFFICIAL_API_KEY 变量"
                exit 1
            fi
            USE_PRESET_KEYS=true
            USE_PROXY=false
            ANTHROPIC_API_KEY="$OFFICIAL_API_KEY"
            API_ENDPOINT_URL="$OFFICIAL_API_URL"
            API_VAR_NAME="ANTHROPIC_API_URL"
            shift
            ;;
        --proxy-preset)
            if [ -z "$PROXY_API_KEY" ]; then
                print_error "代理API密钥未配置，请在脚本中设置 PROXY_API_KEY 变量"
                exit 1
            fi
            USE_PRESET_KEYS=true
            USE_PROXY=true
            ANTHROPIC_API_KEY="$PROXY_API_KEY"
            API_ENDPOINT_URL="$PROXY_API_URL"
            API_VAR_NAME="ANTHROPIC_BASE_URL"
            shift
            ;;
        --help|-h)
            show_usage
            exit 0
            ;;
        -*)
            print_error "未知参数: $1"
            show_usage
            exit 1
            ;;
        *)
            # Manual key mode
            USE_PRESET_KEYS=false
            ANTHROPIC_API_KEY="$1"
            shift
            # Set default to official API
            USE_PROXY=false
            API_ENDPOINT_URL="$OFFICIAL_API_URL"
            API_VAR_NAME="ANTHROPIC_API_URL"
            ;;
    esac
    
    # Parse remaining options
    while [ $# -gt 0 ]; do
        case "$1" in
            --official)
                if [ "$USE_PRESET_KEYS" = true ]; then
                    print_error "预设模式下不能使用 --official 参数"
                    exit 1
                fi
                USE_PROXY=false
                API_ENDPOINT_URL="$OFFICIAL_API_URL"
            API_VAR_NAME="ANTHROPIC_API_URL"
                ;;
            --proxy)
            if [ "$USE_PRESET_KEYS" = true ]; then
                print_error "预设模式下不能使用 --proxy 参数"
                exit 1
            fi
            USE_PROXY=true
            API_ENDPOINT_URL="$PROXY_API_URL"
            API_VAR_NAME="ANTHROPIC_BASE_URL"
            ;;
        --proxy-url)
            shift
            if [[ -z "$1" ]]; then
                print_error "错误: 请提供代理API URL"
                show_usage
                exit 1
            fi
            PROXY_API_URL="$1"
            USE_PROXY=true
            API_ENDPOINT_URL="$PROXY_API_URL"
            API_VAR_NAME="ANTHROPIC_BASE_URL"
            ;;
            --skip-json)
                SKIP_JSON_UPDATE=true
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                print_error "未知参数: $1"
                show_usage
                exit 1
                ;;
        esac
        shift
    done
    
    # Validate API key format
    if [[ ! "$ANTHROPIC_API_KEY" =~ ^sk-ant- ]]; then
        print_error "API密钥格式错误，应以 'sk-ant-' 开头"
        exit 1
    fi
}

# This will be called by menu system or command line
run_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}Claude Code Environment Setup v2.0${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

# Detect OS and shell
detect_os_and_shell() {
    print_info "检测操作系统和Shell环境..."
    
    # Detect OS
    if [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macOS"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="Linux"
    else
        print_error "不支持的操作系统: $OSTYPE"
        exit 1
    fi
    
    # Detect Shell
    CURRENT_SHELL=$(basename "$SHELL")
    
    # Determine config file based on shell
    case "$CURRENT_SHELL" in
        bash)
            if [[ "$OS" == "macOS" ]]; then
                CONFIG_FILE="$HOME/.bash_profile"
            else
                CONFIG_FILE="$HOME/.bashrc"
            fi
            ;;
        zsh)
            CONFIG_FILE="$HOME/.zshrc"
            ;;
        fish)
            CONFIG_FILE="$HOME/.config/fish/config.fish"
            ;;
        *)
            print_error "不支持的Shell: $CURRENT_SHELL"
            exit 1
            ;;
    esac
    
    print_success "检测完成 - 系统: $OS, Shell: $CURRENT_SHELL"
    print_info "配置文件: $CONFIG_FILE"
}

# Function to add environment variables to config file
add_env_vars() {
    print_info "开始配置环境变量..."
    print_info "API模式: $([ "$USE_PROXY" = true ] && echo '代理模式 ⚠️' || echo '官方模式 ✅')"
    print_info "变量名称: $API_VAR_NAME"
    print_info "API端点: $API_ENDPOINT_URL"
    
    # Create backup
    if [ -f "$CONFIG_FILE" ]; then
        cp "$CONFIG_FILE" "$CONFIG_FILE.backup.$(date +%Y%m%d_%H%M%S)"
        print_info "已备份原配置文件"
    fi
    
    # Check if variables already exist
    if grep -q "ANTHROPIC_BASE_URL" "$CONFIG_FILE" 2>/dev/null || grep -q "ANTHROPIC_API_KEY" "$CONFIG_FILE" 2>/dev/null; then
        print_warning "检测到已存在的Claude Code环境变量配置"
        print_info "正在清理所有现有配置..."
        
        # Remove ALL existing ANTHROPIC environment variable configurations
        # For bash/zsh: export VARIABLE=...
        # For fish: set -x VARIABLE ...
        if [[ "$CURRENT_SHELL" == "fish" ]]; then
            # Fish shell: remove 'set -x VARIABLE ...' patterns
            # Using -E for extended regex on macOS/BSD sed
            sed -i.tmp -E '/^[[:space:]]*set[[:space:]]+-x[[:space:]]+ANTHROPIC_API_URL/d' "$CONFIG_FILE" 2>/dev/null || true
            sed -i.tmp -E '/^[[:space:]]*set[[:space:]]+-x[[:space:]]+ANTHROPIC_BASE_URL/d' "$CONFIG_FILE" 2>/dev/null || true
            sed -i.tmp -E '/^[[:space:]]*set[[:space:]]+-x[[:space:]]+ANTHROPIC_API_KEY/d' "$CONFIG_FILE" 2>/dev/null || true
            sed -i.tmp -E '/^[[:space:]]*set[[:space:]]+-x[[:space:]]+ANTHROPIC_AUTH_TOKEN/d' "$CONFIG_FILE" 2>/dev/null || true
        else
            # Bash/Zsh: remove 'export VARIABLE=...' patterns
            # Using -E for extended regex on macOS/BSD sed
            sed -i.tmp -E '/^[[:space:]]*export[[:space:]]+ANTHROPIC_API_URL=/d' "$CONFIG_FILE" 2>/dev/null || true
            sed -i.tmp -E '/^[[:space:]]*export[[:space:]]+ANTHROPIC_BASE_URL=/d' "$CONFIG_FILE" 2>/dev/null || true
            sed -i.tmp -E '/^[[:space:]]*export[[:space:]]+ANTHROPIC_API_KEY=/d' "$CONFIG_FILE" 2>/dev/null || true
            sed -i.tmp -E '/^[[:space:]]*export[[:space:]]+ANTHROPIC_AUTH_TOKEN=/d' "$CONFIG_FILE" 2>/dev/null || true
        fi
        
        # Also remove the marked sections for backward compatibility
        sed -i.tmp '/# Claude Code Environment Variables/,/# End Claude Code Environment Variables/d' "$CONFIG_FILE" 2>/dev/null || true
        
        # Clean up temporary files
        rm -f "$CONFIG_FILE.tmp"
        
        print_success "已彻底清理所有旧配置，准备写入新配置"
    fi
    
    # Add environment variables based on shell type
    local config_comment="# Claude Code Environment Variables ($([ "$USE_PROXY" = true ] && echo 'PROXY MODE - SECURITY RISK' || echo 'OFFICIAL MODE'))"
    
    if [[ "$CURRENT_SHELL" == "fish" ]]; then
        cat >> "$CONFIG_FILE" << EOF

$config_comment
set -x $API_VAR_NAME "$API_ENDPOINT_URL"
set -x ANTHROPIC_API_KEY "$ANTHROPIC_API_KEY"
set -x ANTHROPIC_AUTH_TOKEN ""
# Generated on $(date)
# End Claude Code Environment Variables
EOF
    else
        cat >> "$CONFIG_FILE" << EOF

$config_comment
export $API_VAR_NAME="$API_ENDPOINT_URL"
export ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY"
export ANTHROPIC_AUTH_TOKEN=""
# Generated on $(date)
# End Claude Code Environment Variables
EOF
    fi
    
    print_success "环境变量已写入配置文件"
}

# Function to update .claude.json (已移除逻辑)
update_claude_json() {
    print_info "跳过 ~/.claude.json 配置更新 (仅切换环境变量和API密钥)"
    return 0
}

# Function to source the config file
activate_config() {
    print_info "激活配置..."
    
    # Export variables for current session
    if [ "$API_VAR_NAME" = "ANTHROPIC_API_URL" ]; then
        export ANTHROPIC_API_URL="$API_ENDPOINT_URL"
        # Clear any existing ANTHROPIC_BASE_URL
        unset ANTHROPIC_BASE_URL 2>/dev/null || true
    else
        export ANTHROPIC_BASE_URL="$API_ENDPOINT_URL"
        # Clear any existing ANTHROPIC_API_URL  
        unset ANTHROPIC_API_URL 2>/dev/null || true
    fi
    export ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY"
    export ANTHROPIC_AUTH_TOKEN=""
    
    print_success "环境变量已在当前会话中激活"
    print_info "要在新的终端会话中使用，请运行以下命令："
    
    if [[ "$CURRENT_SHELL" == "fish" ]]; then
        echo -e "${GREEN}source $CONFIG_FILE${NC}"
    else
        echo -e "${GREEN}source $CONFIG_FILE${NC}"
    fi
    
    print_info "或者重新打开终端窗口"
}

# Function to verify configuration
verify_config() {
    print_info "验证配置..."
    
    # 显示当前使用的API URL
    print_info "当前使用的API URL: $API_ENDPOINT_URL"
    
    # Check if variables are set
    if [ -n "$API_ENDPOINT_URL" ] && [ -n "$ANTHROPIC_API_KEY" ]; then
        print_success "环境变量验证成功"
        echo "  API模式: $([ "$USE_PROXY" = true ] && echo '代理模式 ⚠️' || echo '官方模式 ✅')"
        echo "  ANTHROPIC_BASE_URL: $API_ENDPOINT_URL"
        echo "  ANTHROPIC_API_KEY: ****${ANTHROPIC_API_KEY: -4}"
        echo "  ANTHROPIC_AUTH_TOKEN: ${ANTHROPIC_AUTH_TOKEN:-\"\"}"
    else
        print_error "环境变量验证失败"
        return 1
    fi
    
    # .claude.json 配置已跳过
    print_info "已跳过.claude.json配置更新 (仅配置环境变量)"
}

# Main execution
main() {
    # Show header
    run_header
    
    # Step 1: Detect OS and Shell
    detect_os_and_shell
    echo
    
    # Step 2: Add environment variables
    add_env_vars
    echo
    
    # Step 3: Update .claude.json (已跳过)
    update_claude_json
    echo
    
    # Step 4: Activate configuration
    activate_config
    echo
    
    # Step 5: Verify configuration
    verify_config
    echo
    
    print_success "Claude Code环境配置完成！"
    echo -e "${BLUE}========================================${NC}"
    
    # Show final status
    echo
    if [ "$USE_PROXY" = true ]; then
        echo -e "${YELLOW}╔══════════════════════════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}║                     配置完成 - 代理模式                  ║${NC}"
        echo -e "${YELLOW}║                                                          ║${NC}"
        echo -e "${YELLOW}║  ⚠️  您正在使用代理API，请注意安全风险                   ║${NC}"
        echo -e "${YELLOW}║  📝 请关闭终端后重新打开，开始使用                       ║${NC}"
        echo -e "${YELLOW}║                                                          ║${NC}"
        echo -e "${YELLOW}║  💡 如需切换到官方API:                                   ║${NC}"
        echo -e "${YELLOW}║     $0 --official-preset                          ║${NC}"
        echo -e "${YELLOW}╚══════════════════════════════════════════════════════════╝${NC}"
    else
        echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║                     配置完成 - 官方模式                  ║${NC}"
        echo -e "${GREEN}║                                                          ║${NC}"
        echo -e "${GREEN}║  ✅ 您正在使用官方API，安全可靠                          ║${NC}"
        echo -e "${GREEN}║  📝 请关闭终端后重新打开，开始 claude code 使用          ║${NC}"
        echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
    fi
    echo
}

# Function to show interactive menu
show_menu() {
    echo -e "\n${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                   Claude Code 环境配置工具                  ║${NC}"
    echo -e "${BLUE}╠══════════════════════════════════════════════════════════╣${NC}"
    echo -e "${BLUE}║                                                          ║${NC}"
    echo -e "${GREEN}║  1. ✅ 使用官方API (推荐、安全)                           ║${NC}"
    echo -e "${YELLOW}║  2. ⚠️  使用代理API (存在安全风险)                        ║${NC}"
    echo -e "${BLUE}║  3. 🔍 查看当前配置状态                                  ║${NC}"
    echo -e "${CYAN}║  4. ⚙️  手动指定密钥模式                                  ║${NC}"
    echo -e "${MAGENTA}║  5. ❓ 帮助信息                                           ║${NC}"
    echo -e "${RED}║  0. ❌ 退出                                               ║${NC}"
    echo -e "${BLUE}║                                                          ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
    echo
}

# Function to get menu choice
get_menu_choice() {
    while true; do
        echo -n -e "${CYAN}[请选择] 请选择操作 (0-5): ${NC}" >&2
        read -r choice
        
        case "$choice" in
            1|2|3|4|5|0)
                echo "$choice"
                return 0
                ;;
            *)
                print_error "无效选择，请输入0-5之间的数字"
                ;;
        esac
    done
}

# Function to handle menu selection
handle_menu_choice() {
    local choice="$1"
    
    case "$choice" in
        1)
            print_success "选择了官方API模式"
            if [ -z "$OFFICIAL_API_KEY" ]; then
                print_error "官方API密钥未配置，请在脚本中设置 OFFICIAL_API_KEY 变量"
                return 1
            fi
            # Set configuration
            USE_PRESET_KEYS=true
            USE_PROXY=false
            ANTHROPIC_API_KEY="$OFFICIAL_API_KEY"
            API_ENDPOINT_URL="$OFFICIAL_API_URL"
            API_VAR_NAME="ANTHROPIC_API_URL"
            SKIP_JSON_UPDATE=false
            # Run configuration
            run_configuration
            ;;
        2)
            print_warning "选择了代理API模式"
            if [ -z "$PROXY_API_KEY" ]; then
                print_error "代理API密钥未配置，请在脚本中设置 PROXY_API_KEY 变量"
                return 1
            fi
            
            # Show security warning first
            show_proxy_warning
            echo
            
            if ! get_user_confirmation "您确定要继续使用代理API吗？这存在安全风险" "n"; then
                print_info "已取消操作，返回菜单"
                return 0
            fi
            
            # Set configuration
            USE_PRESET_KEYS=true
            USE_PROXY=true
            ANTHROPIC_API_KEY="$PROXY_API_KEY"
            API_ENDPOINT_URL="$PROXY_API_URL"
            API_VAR_NAME="ANTHROPIC_BASE_URL"
            SKIP_JSON_UPDATE=false
            # Run configuration
            run_configuration
            ;;
        3)
            show_current_config
            return 0
            ;;
        4)
            print_info "手动指定密钥模式"
            print_info "请使用以下命令:"
            echo "  官方API: $0 <your-api-key> --official"
            echo "  代理API: $0 <your-api-key> --proxy"
            echo "  示例: $0 sk-ant-xxxxx --official"
            return 0
            ;;
        5)
            show_usage
            return 0
            ;;
        0)
            print_info "再见！"
            exit 0
            ;;
    esac
}

# Function to run the actual configuration
run_configuration() {
    echo
    print_info "开始配置 Claude Code 环境..."
    print_info "API模式: $([ "$USE_PROXY" = true ] && echo '代理模式 ⚠️' || echo '官方模式 ✅')"
    print_info "API端点: $API_ENDPOINT_URL"
    echo
    
    # Run main configuration
    main
}

# Add function to show current configuration
show_current_config() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}当前配置状态查看${NC}"
    echo -e "${BLUE}========================================${NC}\n"
    
    display_current_env
    
    # Show shell configuration file status
    echo
    print_info "Shell配置文件检查："
    echo -e "${BLUE}----------------------------------------${NC}"
    
    # Detect current shell and config file
    local current_shell=$(basename "$SHELL")
    local config_file=""
    
    case "$current_shell" in
        bash)
            if [[ "$OSTYPE" == "darwin"* ]]; then
                config_file="$HOME/.bash_profile"
            else
                config_file="$HOME/.bashrc"
            fi
            ;;
        zsh)
            config_file="$HOME/.zshrc"
            ;;
        fish)
            config_file="$HOME/.config/fish/config.fish"
            ;;
    esac
    
    if [ -n "$config_file" ] && [ -f "$config_file" ]; then
        if grep -q "ANTHROPIC_" "$config_file" 2>/dev/null; then
            echo -e "  ✅ $current_shell 配置文件: $config_file (包含ANTHROPIC配置)"
            echo -e "${CYAN}  配置内容：${NC}"
            grep "ANTHROPIC_" "$config_file" 2>/dev/null | sed 's/^/    /' || echo "    (无法读取配置内容)"
        else
            echo -e "  ⚠️  $current_shell 配置文件: $config_file (未包含ANTHROPIC配置)"
        fi
    else
        echo -e "  ❌ $current_shell 配置文件: 不存在或无法访问"
    fi
    
    echo -e "${BLUE}----------------------------------------${NC}"
    
    # Show Claude JSON config if exists
    if [ -f "$HOME/.claude.json" ]; then
        echo
        print_info "Claude配置文件状态:"
        echo -e "${BLUE}----------------------------------------${NC}"
        if command -v jq &> /dev/null; then
            echo -e "${CYAN}  ~/.claude.json 内容：${NC}"
            jq '.customApiKeyResponses.approved // []' "$HOME/.claude.json" 2>/dev/null | sed 's/^/    /' || echo "    配置文件格式错误"
        else
            echo "  ✅ ~/.claude.json 存在 (需要安装jq查看详细内容)"
        fi
        echo -e "${BLUE}----------------------------------------${NC}"
    else
        echo
        print_info "Claude配置文件: ~/.claude.json 不存在"
    fi
    
    echo
    print_info "如需重新配置，请运行:"
    echo "  交互菜单: $0"
    echo "  快捷官方: $0 --official-preset"
    echo "  快捷代理: $0 --proxy-preset"
    echo
}

# Check if running without arguments to show menu
if [ $# -eq 0 ]; then
    # Show current configuration first
    display_current_env
    echo
    
    # Show menu and handle user choice
    while true; do
        show_menu
        choice=$(get_menu_choice)
        
        # Handle the choice
        if [ "$choice" -eq 0 ]; then
            # Exit choice, handled in handle_menu_choice
            handle_menu_choice "$choice"
            # This will exit, so we won't reach here
        elif handle_menu_choice "$choice"; then
            if [ "$choice" -eq 1 ] || [ "$choice" -eq 2 ]; then
                # Configuration completed, exit
                break
            else
                # For other successful choices (3,4,5), continue the menu loop
                echo
                print_prompt "按 Enter 键继续..."
                read -r
                clear 2>/dev/null || echo -e "\n\n\n"
            fi
        else
            # Handle failed choices
            echo
            print_prompt "按 Enter 键继续..."
            read -r
            clear 2>/dev/null || echo -e "\n\n\n"
        fi
    done
    
    exit 0
fi

# Parse arguments for command line mode
parse_arguments "$@"

# Show configuration mode info
echo
if [ "$USE_PRESET_KEYS" = true ]; then
    print_info "使用预设密钥模式"
    if [ "$USE_PROXY" = true ]; then
        print_security "预设模式: 代理API"
    else
        print_success "预设模式: 官方API (推荐)"
    fi
else
    print_info "使用手动指定密钥模式"
fi

# Show API mode selection for command line mode
if [ "$USE_PROXY" = true ]; then
    print_security "选择了代理API模式"
    show_proxy_warning
    echo
    
    if ! get_user_confirmation "您确定要继续使用代理API吗？这存在安全风险" "n"; then
        print_info "已取消配置，建议使用官方API"
        if [ "$USE_PRESET_KEYS" = true ]; then
            echo "使用官方API: $0 --official-preset"
        else
            echo "使用官方API: $0 $ANTHROPIC_API_KEY --official"
        fi
        exit 0
    fi
    
    print_warning "用户确认使用代理API，继续配置..."
else
    print_success "选择了官方API模式 (推荐)"
    print_info "API端点: $API_ENDPOINT_URL"
fi
echo

# Run main function
main

# Show usage reminder for command line mode
if [ $# -gt 0 ]; then
    echo -e "${CYAN}使用提示：${NC}"
    echo "  查看当前配置: $0"
    echo "  手动配置:     $0 <api-key> [--official|--proxy] [--skip-json]"
    echo "  快捷切换:     $0 --official-preset 或 $0 --proxy-preset"
    echo "  获取帮助:     $0 --help"
    echo
fi

# Exit successfully
exit 0