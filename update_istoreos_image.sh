#!/bin/bash

# 设置变量
ISTOREOS_ARM_URL="https://fw.koolcenter.com/iStoreOS/armsr/"
IMAGE_DIR="image"
CURRENT_VERSION_FILE="current_version.txt"

# 创建image目录
mkdir -p "$IMAGE_DIR"

# 函数：获取最新的ARM镜像文件名
get_latest_arm_image() {
    echo "正在检查最新的ARM镜像..."
    
    # 获取页面内容并提取最新的.img.gz文件
    latest_image=$(curl -s "$ISTOREOS_ARM_URL" | \
        grep -oP 'istoreos-[0-9.]+-[0-9]+-armsr-squashfs-combined-efi\.img\.gz' | \
        sort -V | \
        tail -n 1)
    
    if [ -z "$latest_image" ]; then
        echo "错误：无法获取最新的ARM镜像信息"
        exit 1
    fi
    
    echo "发现最新ARM镜像：$latest_image"
    echo "$latest_image"
}

# 函数：提取时间戳版本信息
extract_version() {
    local filename="$1"
    # 从文件名中提取时间戳部分
    # 格式：istoreos-24.10.2-2025080813-armsr-squashfs-combined-efi.img.gz
    echo "$filename" | sed -n 's/istoreos-\([0-9.]*\)-\([0-9]*\)-armsr-squashfs-combined-efi\.img\.gz/\2/p'
}

# 函数：提取完整版本信息
extract_full_version() {
    local filename="$1"
    # 从文件名中提取完整版本信息 (版本号-时间戳)
    # 格式：istoreos-24.10.2-2025080813-armsr-squashfs-combined-efi.img.gz
    echo "$filename" | sed -n 's/istoreos-\([0-9.]*\)-\([0-9]*\)-armsr-squashfs-combined-efi\.img\.gz/\1-\2/p'
}

# 函数：提取软件版本号
extract_software_version() {
    local filename="$1"
    # 从文件名中提取软件版本号部分
    # 格式：istoreos-24.10.2-2025080813-armsr-squashfs-combined-efi.img.gz
    echo "$filename" | sed -n 's/istoreos-\([0-9.]*\)-\([0-9]*\)-armsr-squashfs-combined-efi\.img\.gz/\1/p'
}

# 函数：检查是否有新版本
check_for_update() {
    local latest_image="$1"
    local latest_version=$(extract_version "$latest_image")
    
    if [ ! -f "$CURRENT_VERSION_FILE" ]; then
        echo "未找到当前版本文件，将创建新版本"
        echo "$latest_version" > "$CURRENT_VERSION_FILE"
        return 0
    fi
    
    local current_version=$(cat "$CURRENT_VERSION_FILE")
    
    if [ "$latest_version" != "$current_version" ]; then
        echo "检测到新版本！"
        echo "当前版本：$current_version"
        echo "最新版本：$latest_version"
        echo "$latest_version" > "$CURRENT_VERSION_FILE"
        return 0
    else
        echo "已是最新版本：$current_version"
        return 1
    fi
}

# 函数：下载镜像
download_image() {
    local image_name="$1"
    local download_url="${ISTOREOS_ARM_URL}${image_name}"
    local local_path="${IMAGE_DIR}/${image_name}"
    
    echo "正在下载镜像：$download_url"
    
    # 如果文件已存在，先删除
    if [ -f "$local_path" ]; then
        rm -f "$local_path"
    fi
    
    # 下载文件
    if curl -L -o "$local_path" "$download_url"; then
        echo "镜像下载成功：$local_path"
        
        # 验证文件大小
        local file_size=$(stat -f%z "$local_path" 2>/dev/null || stat -c%s "$local_path" 2>/dev/null)
        if [ "$file_size" -lt 100000000 ]; then  # 小于100MB可能是错误
            echo "警告：下载的文件大小异常（${file_size} bytes）"
            return 1
        fi
        
        return 0
    else
        echo "错误：镜像下载失败"
        return 1
    fi
}

# 主逻辑
main() {
    echo "=== iStoreOS ARM 镜像更新检查 ==="
    echo "开始时间：$(date)"
    
    # 获取最新镜像信息
    latest_image=$(get_latest_arm_image)
    
    if [ -z "$latest_image" ]; then
        echo "错误：无法获取最新镜像信息"
        exit 1
    fi
    
    # 检查是否需要更新
    if check_for_update "$latest_image"; then
        echo "开始下载新镜像..."
        
        if download_image "$latest_image"; then
            echo "镜像更新完成！"
            
            # 设置环境变量供GitHub Actions使用
            if [ -n "$GITHUB_ENV" ]; then
                echo "NEW_VERSION=true" >> "$GITHUB_ENV"
                echo "IMAGE_NAME=$latest_image" >> "$GITHUB_ENV"
                echo "VERSION_TAG=$(extract_version "$latest_image")" >> "$GITHUB_ENV"
                echo "FULL_VERSION_TAG=$(extract_full_version "$latest_image")" >> "$GITHUB_ENV"
                echo "SOFTWARE_VERSION=$(extract_software_version "$latest_image")" >> "$GITHUB_ENV"
            fi
            
            exit 0
        else
            echo "错误：镜像下载失败"
            exit 1
        fi
    else
        echo "无需更新"
        
        # 设置环境变量供GitHub Actions使用
        if [ -n "$GITHUB_ENV" ]; then
            echo "NEW_VERSION=false" >> "$GITHUB_ENV"
        fi
        
        exit 0
    fi
}

# 运行主函数
main "$@"
