#!/bin/bash

# iStoreOS ARM 根文件系统提取脚本
# 用于从官方 .img.gz 文件中提取 rootfs.tar

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

# 设置变量
ISTOREOS_URL="https://fw.koolcenter.com/iStoreOS/armsr/"
WORK_DIR="$(pwd)/work"
IMAGE_FILE=""
ROOTFS_TAR="rootfs.tar"

# 错误处理函数
error_exit() {
    log_error "$1"
    cleanup
    exit 1
}

# 清理函数
cleanup() {
    log_info "开始清理..."
    
    # 卸载文件系统
    if [ -d "$WORK_DIR/rootfs" ]; then
        sudo umount "$WORK_DIR/rootfs" 2>/dev/null || true
    fi
    
    # 断开 NBD 设备
    sudo qemu-nbd --disconnect /dev/nbd0 2>/dev/null || true
    
    # 清理工作目录
    sudo rm -rf "$WORK_DIR"
    
    log_success "清理完成"
}

# 信号处理
trap cleanup EXIT
trap 'error_exit "脚本被中断"' INT TERM

# 检查依赖
check_dependencies() {
    log_info "检查系统依赖..."
    
    local missing_deps=()
    
    # 检查必要的工具
    for tool in wget curl qemu-nbd tar gunzip sudo; do
        if ! command -v "$tool" &> /dev/null; then
            missing_deps+=("$tool")
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "缺少以下依赖: ${missing_deps[*]}"
        log_info "请运行以下命令安装依赖:"
        log_info "sudo apt install -y wget curl qemu-utils kpartx e2fsprogs tar gzip zstd bzip2 util-linux parted coreutils"
        exit 1
    fi
    
    # 检查是否可以使用 sudo
    if ! sudo -n true 2>/dev/null; then
        log_warning "需要 sudo 权限来挂载文件系统"
    fi
    
    log_success "依赖检查通过"
}

# 获取最新的镜像文件
get_latest_image() {
    log_info "获取最新的 iStoreOS ARM 镜像信息..."
    
    local latest_file=$(curl -s "$ISTOREOS_URL" | \
        grep -oE 'istoreos-[^ ]+efi.img.gz' | \
        head -n1)
    
    if [ -z "$latest_file" ]; then
        error_exit "无法获取最新镜像文件信息"
    fi
    
    log_success "发现最新镜像: $latest_file"
    echo "$latest_file"
}

# 下载镜像文件
download_image() {
    local filename="$1"
    local url="${ISTOREOS_URL}${filename}"
    local local_file="$WORK_DIR/$filename"
    
    log_info "下载镜像文件: $filename"
    
    mkdir -p "$WORK_DIR"
    
    if [ -f "$local_file" ]; then
        log_warning "文件已存在，跳过下载: $filename"
    else
        log_info "开始下载: $url"
        if wget -O "$local_file" "$url"; then
            log_success "下载完成"
        else
            error_exit "下载失败"
        fi
    fi
    
    # 验证文件大小
    local file_size=$(stat -c%s "$local_file" 2>/dev/null)
    if [ "$file_size" -lt 50000000 ]; then  # 小于50MB可能是错误
        error_exit "下载的文件大小异常: ${file_size} bytes"
    fi
    
    echo "$local_file"
}

# 提取根文件系统
extract_rootfs() {
    local img_gz_file="$1"
    local img_file="${img_gz_file%.gz}"
    
    log_info "开始提取根文件系统..."
    
    # 解压镜像文件
    log_info "解压镜像文件..."
    gunzip -c "$img_gz_file" > "$img_file"
    
    # 加载 NBD 模块
    log_info "加载 NBD 模块..."
    sudo modprobe nbd max_part=8
    
    # 连接 NBD 设备
    log_info "连接 NBD 设备..."
    sudo qemu-nbd --connect=/dev/nbd0 "$img_file"
    sleep 3
    
    # 探测分区
    sudo partprobe /dev/nbd0
    
    # 显示分区信息
    log_info "分区信息:"
    sudo fdisk -l /dev/nbd0
    
    # 创建挂载点
    mkdir -p "$WORK_DIR/rootfs"
    
    # 尝试挂载各个分区，寻找根文件系统
    local mounted=false
    for part in /dev/nbd0p*; do
        if [ -e "$part" ]; then
            log_info "尝试挂载分区: $part"
            if sudo mount -o ro "$part" "$WORK_DIR/rootfs" 2>/dev/null; then
                # 检查是否是根文件系统
                if [ -d "$WORK_DIR/rootfs/etc" ] && [ -d "$WORK_DIR/rootfs/usr" ]; then
                    log_success "找到根文件系统: $part"
                    
                    # 显示根目录内容
                    log_info "根目录内容:"
                    ls -la "$WORK_DIR/rootfs/" | head -10
                    
                    # 检查系统信息
                    if [ -f "$WORK_DIR/rootfs/etc/openwrt_release" ]; then
                        log_info "OpenWrt 版本信息:"
                        cat "$WORK_DIR/rootfs/etc/openwrt_release"
                    fi
                    
                    if [ -f "$WORK_DIR/rootfs/etc/istoreos_version" ]; then
                        log_info "iStoreOS 版本信息:"
                        cat "$WORK_DIR/rootfs/etc/istoreos_version"
                    fi
                    
                    mounted=true
                    break
                else
                    log_warning "分区 $part 不是根文件系统"
                    sudo umount "$WORK_DIR/rootfs"
                fi
            else
                log_warning "无法挂载分区: $part"
            fi
        fi
    done
    
    if [ "$mounted" = false ]; then
        error_exit "未找到有效的根文件系统分区"
    fi
    
    # 创建 rootfs.tar
    log_info "创建 rootfs.tar..."
    sudo tar -cf "$WORK_DIR/$ROOTFS_TAR" -C "$WORK_DIR/rootfs" .
    sudo chown "$USER:$(id -gn)" "$WORK_DIR/$ROOTFS_TAR"
    
    # 移动到当前目录
    mv "$WORK_DIR/$ROOTFS_TAR" "./$ROOTFS_TAR"
    
    local tar_size=$(stat -c%s "$ROOTFS_TAR" 2>/dev/null)
    log_success "rootfs.tar 创建完成，大小: $(( tar_size / 1024 / 1024 )) MB"
    
    # 清理挂载
    sudo umount "$WORK_DIR/rootfs"
    sudo qemu-nbd --disconnect /dev/nbd0
}

# 主函数
main() {
    echo "========================================"
    echo "    iStoreOS ARM 根文件系统提取工具"
    echo "========================================"
    echo
    
    # 检查依赖
    check_dependencies
    
    # 获取最新镜像信息
    local latest_image=$(get_latest_image)
    
    # 下载镜像
    local img_file=$(download_image "$latest_image")
    
    # 提取根文件系统
    extract_rootfs "$img_file"
    
    echo
    log_success "根文件系统提取完成！"
    log_info "输出文件: $ROOTFS_TAR"
    log_info "可以使用以下命令构建 Docker 镜像:"
    echo
    echo "mkdir docker-build && cd docker-build"
    echo "cp ../$ROOTFS_TAR ."
    echo "cat > Dockerfile <<'EOF'"
    echo "FROM scratch"
    echo "ADD $ROOTFS_TAR /"
    echo "CMD [\"/sbin/init\"]"
    echo "EOF"
    echo "docker build -t istoreos-arm:latest ."
    echo
}

# 运行主函数
main "$@"
