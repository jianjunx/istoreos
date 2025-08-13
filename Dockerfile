# iStoreOS ARM Native Docker Image
# 此 Dockerfile 基于从官方 .img.gz 文件提取的完整根文件系统构建
# 
# 构建方式：
# 1. 从官方下载 istoreos-*.img.gz 文件
# 2. 解压并挂载镜像文件
# 3. 提取根文件系统为 rootfs.tar
# 4. 基于 scratch 构建原生 iStoreOS 容器
#
# 注意：此文件仅作为参考，实际构建在 GitHub Actions 中动态生成

FROM scratch

# 添加 iStoreOS 根文件系统
ADD rootfs.tar /

# 设置默认启动命令为 systemd init
CMD ["/sbin/init"]

# 标签信息
LABEL maintainer="iStoreOS ARM Docker Project"
LABEL description="Native iStoreOS ARM Docker Image built from official rootfs"
LABEL architecture="arm64"
LABEL base="scratch"

# 暴露常用端口
EXPOSE 80 443 22 53
