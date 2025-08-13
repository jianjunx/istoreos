#!/bin/bash

# iStoreOS ARM 镜像处理脚本
# 用于解压和处理 iStoreOS ARM 镜像文件

set -e

# 设置变量
IMAGE_DIR="/opt/istoreos/image"
MOUNT_DIR="/opt/istoreos/mount"
ROOTFS_DIR="/opt/istoreos/rootfs"
LOG_FILE="/opt/istoreos/process.log"

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# 错误处理函数
error_exit() {
    log "错误: $1"
    cleanup
    exit 1
}

# 清理函数
cleanup() {
    log "开始清理..."
    
    # 卸载所有挂载点
    for mount_point in $(mount | grep "$MOUNT_DIR" | awk '{print $3}' | sort -r); do
        log "卸载: $mount_point"
        umount "$mount_point" 2>/dev/null || true
    done
    
    # 分离loop设备
    for loop_device in $(losetup -a | grep "$IMAGE_DIR" | cut -d: -f1); do
        log "分离loop设备: $loop_device"
        losetup -d "$loop_device" 2>/dev/null || true
    done
    
    # 清理挂载目录
    rm -rf "$MOUNT_DIR"/*
    
    log "清理完成"
}

# 信号处理
trap cleanup EXIT
trap 'error_exit "脚本被中断"' INT TERM

# 检查是否以root权限运行
check_root() {
    if [ "$EUID" -ne 0 ]; then
        error_exit "此脚本需要root权限运行"
    fi
}

# 查找镜像文件
find_image_file() {
    local image_file=$(find "$IMAGE_DIR" -name "*.img.gz" -type f | head -n 1)
    
    if [ -z "$image_file" ]; then
        error_exit "在 $IMAGE_DIR 中未找到 .img.gz 文件"
    fi
    
    echo "$image_file"
}

# 解压镜像文件
extract_image() {
    local compressed_file="$1"
    local extracted_file="${compressed_file%.gz}"
    
    log "开始解压镜像文件: $(basename "$compressed_file")"
    
    if [ -f "$extracted_file" ]; then
        log "镜像文件已存在，跳过解压: $(basename "$extracted_file")"
    else
        gunzip -k "$compressed_file" || error_exit "解压镜像文件失败"
        log "镜像文件解压完成: $(basename "$extracted_file")"
    fi
    
    echo "$extracted_file"
}

# 设置loop设备
setup_loop_device() {
    local image_file="$1"
    
    log "设置loop设备: $(basename "$image_file")"
    
    local loop_device=$(losetup -f)
    losetup -P "$loop_device" "$image_file" || error_exit "设置loop设备失败"
    
    log "Loop设备已设置: $loop_device"
    echo "$loop_device"
}

# 列出分区信息
list_partitions() {
    local loop_device="$1"
    
    log "分析分区信息..."
    
    # 等待分区设备创建
    sleep 2
    
    # 列出分区
    fdisk -l "$loop_device" | tee -a "$LOG_FILE"
    
    # 查找可用的分区
    local partitions=$(ls "${loop_device}"p* 2>/dev/null | sort)
    
    if [ -z "$partitions" ]; then
        error_exit "未找到任何分区"
    fi
    
    log "发现分区: $partitions"
    echo "$partitions"
}

# 挂载分区
mount_partitions() {
    local loop_device="$1"
    
    log "开始挂载分区..."
    
    # 创建挂载点
    mkdir -p "$MOUNT_DIR"
    
    # 尝试挂载各个分区
    local partition_num=1
    for partition in "${loop_device}"p*; do
        if [ -e "$partition" ]; then
            local mount_point="$MOUNT_DIR/p${partition_num}"
            mkdir -p "$mount_point"
            
            log "尝试挂载分区: $partition -> $mount_point"
            
            # 检测文件系统类型
            local fs_type=$(blkid -o value -s TYPE "$partition" 2>/dev/null || echo "unknown")
            log "分区 $partition 文件系统类型: $fs_type"
            
            # 尝试挂载
            if mount -o ro "$partition" "$mount_point" 2>/dev/null; then
                log "成功挂载分区: $partition"
                
                # 列出挂载点内容
                log "分区内容预览:"
                ls -la "$mount_point" | head -10 | tee -a "$LOG_FILE"
                
                # 如果是根文件系统，复制到rootfs目录
                if [ -d "$mount_point/etc" ] && [ -d "$mount_point/usr" ]; then
                    log "检测到根文件系统，开始复制..."
                    mkdir -p "$ROOTFS_DIR"
                    cp -r "$mount_point"/* "$ROOTFS_DIR"/ 2>/dev/null || true
                    log "根文件系统复制完成"
                fi
            else
                log "无法挂载分区: $partition (可能是交换分区或未知文件系统)"
                rmdir "$mount_point" 2>/dev/null || true
            fi
        fi
        
        ((partition_num++))
    done
}

# 分析iStoreOS系统
analyze_istoreos() {
    log "分析iStoreOS系统信息..."
    
    # 检查版本信息
    if [ -f "$ROOTFS_DIR/etc/openwrt_release" ]; then
        log "OpenWrt版本信息:"
        cat "$ROOTFS_DIR/etc/openwrt_release" | tee -a "$LOG_FILE"
    fi
    
    if [ -f "$ROOTFS_DIR/etc/istoreos_version" ]; then
        log "iStoreOS版本信息:"
        cat "$ROOTFS_DIR/etc/istoreos_version" | tee -a "$LOG_FILE"
    fi
    
    # 检查已安装的软件包
    if [ -f "$ROOTFS_DIR/usr/lib/opkg/status" ]; then
        log "已安装软件包数量: $(grep -c "^Package:" "$ROOTFS_DIR/usr/lib/opkg/status" 2>/dev/null || echo "0")"
    fi
    
    # 检查iStore相关文件
    if [ -d "$ROOTFS_DIR/usr/share/istore" ]; then
        log "发现iStore应用商店文件"
    fi
    
    # 检查网络配置
    if [ -f "$ROOTFS_DIR/etc/config/network" ]; then
        log "网络配置文件存在"
    fi
}

# 生成报告
generate_report() {
    local report_file="/opt/istoreos/analysis_report.txt"
    
    log "生成分析报告: $report_file"
    
    cat > "$report_file" << EOF
iStoreOS ARM 镜像分析报告
========================

分析时间: $(date)
镜像文件: $(basename "$(find_image_file)")

系统信息:
$(cat "$ROOTFS_DIR/etc/openwrt_release" 2>/dev/null || echo "未找到版本信息")

磁盘分区:
$(fdisk -l 2>/dev/null | grep -A 20 "$(basename "$(find_image_file)" .gz)" || echo "分区信息不可用")

目录结构:
$(ls -la "$ROOTFS_DIR" 2>/dev/null | head -20 || echo "目录结构不可用")

分析完成时间: $(date)
EOF

    log "分析报告已生成"
}

# 主函数
main() {
    log "=== iStoreOS ARM 镜像处理开始 ==="
    log "开始时间: $(date)"
    
    # 检查权限
    check_root
    
    # 查找镜像文件
    local image_file=$(find_image_file)
    log "找到镜像文件: $(basename "$image_file")"
    
    # 解压镜像
    local extracted_file=$(extract_image "$image_file")
    
    # 设置loop设备
    local loop_device=$(setup_loop_device "$extracted_file")
    
    # 列出分区
    local partitions=$(list_partitions "$loop_device")
    
    # 挂载分区
    mount_partitions "$loop_device"
    
    # 分析系统
    analyze_istoreos
    
    # 生成报告
    generate_report
    
    log "=== iStoreOS ARM 镜像处理完成 ==="
    log "结束时间: $(date)"
    
    # 保持容器运行（用于调试）
    if [ "${KEEP_RUNNING:-false}" = "true" ]; then
        log "容器将保持运行状态..."
        tail -f "$LOG_FILE"
    fi
}

# 如果脚本被直接执行，运行主函数
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
