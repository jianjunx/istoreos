#!/bin/bash

# iStoreOS ARM Docker 项目设置脚本
# 用于初始化项目环境和配置

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查依赖
check_dependencies() {
    log_info "检查系统依赖..."
    
    local missing_deps=()
    
    # 检查 Docker
    if ! command -v docker &> /dev/null; then
        missing_deps+=("docker")
    fi
    
    # 检查 curl
    if ! command -v curl &> /dev/null; then
        missing_deps+=("curl")
    fi
    
    # 检查 wget
    if ! command -v wget &> /dev/null; then
        missing_deps+=("wget")
    fi
    
    # 检查 git
    if ! command -v git &> /dev/null; then
        missing_deps+=("git")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "缺少以下依赖: ${missing_deps[*]}"
        log_info "请安装缺少的依赖后重新运行此脚本"
        exit 1
    fi
    
    log_success "所有依赖检查通过"
}

# 创建必要的目录
create_directories() {
    log_info "创建项目目录..."
    
    local dirs=("image" "mount" "rootfs" "logs")
    
    for dir in "${dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            log_success "创建目录: $dir"
        else
            log_info "目录已存在: $dir"
        fi
    done
}

# 设置脚本权限
set_permissions() {
    log_info "设置脚本执行权限..."
    
    local scripts=("update_istoreos_image.sh" "process_image.sh" "setup.sh")
    
    for script in "${scripts[@]}"; do
        if [ -f "$script" ]; then
            chmod +x "$script"
            log_success "设置权限: $script"
        fi
    done
}

# 检查 Docker 状态
check_docker() {
    log_info "检查 Docker 服务状态..."
    
    if ! docker info &> /dev/null; then
        log_error "Docker 服务未运行或无法访问"
        log_info "请确保 Docker 服务正在运行，并且当前用户有权限访问 Docker"
        
        # 在 macOS 上的特殊处理
        if [[ "$OSTYPE" == "darwin"* ]]; then
            log_info "如果您在 macOS 上，请确保 Docker Desktop 正在运行"
        fi
        
        exit 1
    fi
    
    log_success "Docker 服务正常"
}

# 初始化 Git 仓库（如果需要）
init_git() {
    if [ ! -d ".git" ]; then
        read -p "是否初始化 Git 仓库？(y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "初始化 Git 仓库..."
            git init
            git add .
            git commit -m "Initial commit: iStoreOS ARM Docker project"
            log_success "Git 仓库初始化完成"
        fi
    else
        log_info "Git 仓库已存在"
    fi
}

# 配置 GitHub Secrets 提示
show_github_config() {
    log_info "GitHub Actions 配置说明:"
    echo
    echo "为了使 GitHub Actions 正常工作，请在 GitHub 仓库设置中添加以下 Secrets:"
    echo
    echo "1. DOCKER_HUB_USERNAME - 您的 Docker Hub 用户名"
    echo "2. DOCKER_HUB_ACCESS_TOKEN - Docker Hub 访问令牌"
    echo
    echo "创建 Docker Hub 访问令牌的步骤:"
    echo "1. 登录 Docker Hub (https://hub.docker.com/)"
    echo "2. 点击右上角头像 -> Account Settings"
    echo "3. 选择 Security 标签"
    echo "4. 点击 'New Access Token'"
    echo "5. 输入描述并选择权限"
    echo "6. 复制生成的令牌到 GitHub Secrets"
    echo
}

# 测试脚本功能
test_scripts() {
    read -p "是否测试镜像下载脚本？(y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "测试镜像下载脚本..."
        
        if ./update_istoreos_image.sh; then
            log_success "镜像下载脚本测试通过"
        else
            log_warning "镜像下载脚本测试失败，可能是网络问题"
        fi
    fi
}

# 显示项目信息
show_project_info() {
    log_success "项目设置完成！"
    echo
    echo "项目信息:"
    echo "├── 脚本文件:"
    echo "│   ├── update_istoreos_image.sh - 检查和下载最新镜像"
    echo "│   ├── process_image.sh - 处理镜像文件"
    echo "│   └── setup.sh - 项目设置脚本"
    echo "├── Docker 文件:"
    echo "│   └── Dockerfile - Docker 镜像构建文件"
    echo "├── GitHub Actions:"
    echo "│   └── .github/workflows/build-arm-image.yml"
    echo "└── 文档:"
    echo "    ├── README.md - 项目说明"
    echo "    └── docker.md - Docker 使用指南"
    echo
    echo "下一步:"
    echo "1. 配置 GitHub Secrets (如果使用 GitHub Actions)"
    echo "2. 运行 './update_istoreos_image.sh' 下载最新镜像"
    echo "3. 运行 'docker build -t istoreos-arm .' 构建镜像"
    echo "4. 运行 'docker run -it --privileged istoreos-arm' 测试镜像"
}

# 主函数
main() {
    echo "========================================"
    echo "    iStoreOS ARM Docker 项目设置"
    echo "========================================"
    echo
    
    check_dependencies
    check_docker
    create_directories
    set_permissions
    init_git
    show_github_config
    test_scripts
    show_project_info
    
    echo
    log_success "设置完成！享受使用 iStoreOS ARM Docker 项目吧！"
    echo
    log_info "项目信息:"
    log_info "GitHub: https://github.com/jianjunx/istoreos-arm"
    log_info "Docker Hub: https://hub.docker.com/r/jjxie233/istoreos-arm"
}

# 运行主函数
main "$@"
