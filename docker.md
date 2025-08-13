# iStoreOS ARM Docker 使用指南

## 📖 概述

本指南详细介绍如何使用 iStoreOS ARM Docker 镜像，包括安装、配置、运行和故障排除。

## 🚀 快速开始

### 1. 拉取镜像

```bash
# 拉取最新版本
docker pull ghcr.io/jianjunx/istoreos:latest

# 或拉取特定版本
docker pull ghcr.io/jianjunx/istoreos:2025080813
```

### 2. 基本运行

```bash
# 最简单的运行方式
docker run -it --privileged ghcr.io/jianjunx/istoreos:latest
```

## 🔧 高级配置

### 容器运行选项

#### 特权模式（必需）

```bash
docker run -it --privileged ghcr.io/jianjunx/istoreos:latest
```

**为什么需要特权模式？**

- 挂载和卸载文件系统
- 创建和管理 loop 设备
- 访问块设备
- 分析磁盘分区

#### 数据卷挂载

```bash
# 挂载主机目录来保存提取的文件系统
docker run -it --privileged \
  -v $(pwd)/rootfs:/opt/istoreos/rootfs \
  -v $(pwd)/images:/opt/istoreos/image \
  ghcr.io/jianjunx/istoreos:latest
```

#### 环境变量配置

```bash
docker run -it --privileged \
  -e KEEP_RUNNING=true \
  -e TZ=Asia/Shanghai \
  ghcr.io/jianjunx/istoreos:latest
```

### 网络配置

```bash
# 使用主机网络模式
docker run -it --privileged --network host ghcr.io/jianjunx/istoreos:latest

# 端口映射（如果需要）
docker run -it --privileged \
  -p 80:80 \
  -p 443:443 \
  -p 22:22 \
  ghcr.io/jianjunx/istoreos:latest
```

## 🛠️ 使用场景

### 场景 1: 镜像分析

```bash
# 分析 iStoreOS 镜像内容
docker run --privileged \
  -v $(pwd)/analysis:/opt/istoreos/rootfs \
  ghcr.io/jianjunx/istoreos:latest

# 查看分析报告
cat analysis_report.txt
```

### 场景 2: 开发环境

```bash
# 创建持久化的开发环境
docker run -it --privileged \
  --name istoreos-dev \
  -v $(pwd)/workspace:/workspace \
  -e KEEP_RUNNING=true \
  ghcr.io/jianjunx/istoreos:latest

# 重新连接到开发环境
docker exec -it istoreos-dev /bin/bash
```

### 场景 3: CI/CD 集成

```yaml
# GitHub Actions 示例
- name: Test with iStoreOS
  run: |
    docker run --privileged \
      -v ${{ github.workspace }}:/workspace \
      ghcr.io/jianjunx/istoreos:latest \
      /workspace/test-script.sh
```

### 场景 4: 自动化测试

```bash
# 运行自动化测试脚本
docker run --privileged \
  -v $(pwd)/tests:/tests \
  ghcr.io/jianjunx/istoreos:latest \
  /tests/run-tests.sh
```

## 📊 监控和日志

### 查看容器日志

```bash
# 查看容器启动日志
docker logs istoreos-container

# 实时跟踪日志
docker logs -f istoreos-container
```

### 进入运行中的容器

```bash
# 获取新的 shell
docker exec -it istoreos-container /bin/bash

# 查看处理日志
docker exec istoreos-container cat /opt/istoreos/process.log
```

### 资源监控

```bash
# 查看资源使用情况
docker stats istoreos-container

# 查看详细信息
docker inspect istoreos-container
```

## 🔍 故障排除

### 常见错误及解决方案

#### 1. 权限相关错误

**错误**: `Operation not permitted` 或 `Permission denied`

**解决方案**:

```bash
# 确保使用 --privileged 标志
docker run -it --privileged ghcr.io/jianjunx/istoreos:latest
```

#### 2. Loop 设备错误

**错误**: `losetup: cannot find an unused loop device`

**解决方案**:

```bash
# 在主机上加载 loop 模块
sudo modprobe loop

# 增加可用的 loop 设备数量
echo 'options loop max_loop=64' | sudo tee /etc/modprobe.d/loop.conf
```

#### 3. 镜像下载失败

**错误**: 无法下载或解压镜像文件

**解决方案**:

```bash
# 手动下载镜像文件
mkdir -p image
wget -O image/istoreos.img.gz "https://fw.koolcenter.com/iStoreOS/armsr/最新文件名"

# 使用本地镜像运行
docker run -it --privileged \
  -v $(pwd)/image:/opt/istoreos/image \
  ghcr.io/jianjunx/istoreos:latest
```

#### 4. 磁盘空间不足

**错误**: `No space left on device`

**解决方案**:

```bash
# 清理 Docker 缓存
docker system prune -f

# 清理未使用的镜像
docker image prune -f

# 查看磁盘使用情况
df -h
docker system df
```

#### 5. 容器启动失败

**错误**: 容器无法启动或立即退出

**解决方案**:

```bash
# 查看详细错误信息
docker logs 容器名

# 以调试模式运行
docker run -it --privileged \
  --entrypoint /bin/bash \
  ghcr.io/jianjunx/istoreos:latest

# 手动执行处理脚本
/opt/istoreos/process_image.sh
```

### 调试技巧

#### 1. 交互式调试

```bash
# 以 bash 作为入口点启动
docker run -it --privileged \
  --entrypoint /bin/bash \
  ghcr.io/jianjunx/istoreos:latest

# 在容器内手动执行步骤
cd /opt/istoreos
ls -la
./process_image.sh
```

#### 2. 保持容器运行

```bash
# 设置环境变量保持运行
docker run -it --privileged \
  -e KEEP_RUNNING=true \
  ghcr.io/jianjunx/istoreos:latest
```

#### 3. 挂载调试工具

```bash
# 挂载包含调试工具的目录
docker run -it --privileged \
  -v $(pwd)/debug-tools:/debug \
  ghcr.io/jianjunx/istoreos:latest
```

## 📈 性能优化

### 1. 缓存优化

```bash
# 使用 BuildKit 缓存
export DOCKER_BUILDKIT=1
docker build --cache-from ghcr.io/jianjunx/istoreos:latest .
```

### 2. 多阶段构建

```dockerfile
# 在 Dockerfile 中使用多阶段构建
FROM ubuntu:22.04 as builder
# ... 构建步骤 ...

FROM ubuntu:22.04 as runtime
# ... 运行时配置 ...
```

### 3. 资源限制

```bash
# 限制内存和 CPU 使用
docker run -it --privileged \
  --memory=2g \
  --cpus=2 \
  ghcr.io/jianjunx/istoreos:latest
```

## 🔄 版本管理

### 标签策略

- `latest`: 最新稳定版本
- `24.10.2-2025080813`: 完整版本号（软件版本-时间戳）
- `24.10.2`: 软件版本号
- `2025080813`: 时间戳版本
- `20250109`: 每日构建标签
- `dev`: 开发版本（如果有）

### 版本升级

```bash
# 拉取最新版本
docker pull ghcr.io/jianjunx/istoreos:latest

# 停止旧容器
docker stop old-container
docker rm old-container

# 启动新容器
docker run -it --privileged \
  --name new-container \
  ghcr.io/jianjunx/istoreos:latest
```

## 🛡️ 安全考虑

### 1. 特权模式风险

特权模式给予容器几乎与主机相同的权限，仅在可信环境中使用。

### 2. 网络隔离

```bash
# 使用自定义网络
docker network create istoreos-net
docker run -it --privileged --network istoreos-net ghcr.io/jianjunx/istoreos:latest
```

### 3. 用户权限

```bash
# 在容器内切换到非 root 用户（如果可能）
docker exec -it --user nobody 容器名 /bin/bash
```

## 📝 最佳实践

1. **总是使用最新版本**: 定期更新镜像以获得最新功能和安全修复
2. **数据持久化**: 使用卷挂载保存重要数据
3. **资源监控**: 定期检查容器资源使用情况
4. **日志管理**: 配置适当的日志轮转和存储
5. **备份策略**: 定期备份重要的分析结果和配置

## 🔗 相关资源

- [Docker 官方文档](https://docs.docker.com/)
- [iStoreOS 官方网站](https://www.istoreos.com/)
- [项目 GitHub 仓库](https://github.com/jianjunx/istoreos-arm)
- [GitHub Container Registry](https://github.com/jianjunx/istoreos/pkgs/container/istoreos)

---

如有问题或建议，请在 [GitHub Issues](https://github.com/jianjunx/istoreos-arm/issues) 中提出。
