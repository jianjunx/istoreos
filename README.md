# iStoreOS ARM Docker 镜像

🚀 **iStoreOS ARM 平台原生 Docker 镜像自动构建项目**

这个项目提供了一个自动化工具，用于从官方 iStoreOS ARM `.img.gz` 文件中提取完整的根文件系统，并构建基于 `FROM scratch` 的原生 Docker 镜像。

## 📋 项目特点

- ✅ **原生镜像**: 基于 `FROM scratch` 构建，包含完整的 iStoreOS 根文件系统
- ✅ **自动提取**: 从官方 `.img.gz` 文件中自动提取 `rootfs.tar`
- ✅ **自动检测**: 每 6 小时检查 iStoreOS ARM 平台的最新版本
- ✅ **自动构建**: 检测到新版本时自动构建原生 Docker 镜像
- ✅ **ARM64 优化**: 专门针对 ARM64 架构构建
- ✅ **版本管理**: 自动打标签和发布到 GitHub Releases
- ✅ **Docker Hub**: 自动推送到 Docker Hub

## 🔄 最新版本

- **最新镜像版本**: 从 [iStoreOS ARM 官方下载](https://fw.koolcenter.com/iStoreOS/armsr/) 自动获取
- **Docker Hub**: [jjxie233/istoreos-arm](https://hub.docker.com/r/jjxie233/istoreos-arm)
- **更新频率**: 每 6 小时检查一次（全天候自动同步）

## 🐳 Docker 镜像使用

### 快速开始

```bash
# 拉取最新镜像
docker pull jjxie233/istoreos-arm:latest

# 拉取指定完整版本
docker pull jjxie233/istoreos-arm:24.10.2-2025080813

# 拉取指定软件版本
docker pull jjxie233/istoreos-arm:24.10.2

# 运行原生 iStoreOS 容器（需要特权模式运行系统服务）
docker run -it --privileged jjxie233/istoreos-arm:latest

# 后台运行 iStoreOS 系统
docker run -d --privileged \
  --name istoreos-system \
  jjxie233/istoreos-arm:latest

# 进入运行中的容器
docker exec -it istoreos-system /bin/bash
```

### 可用标签

- `latest`: 始终指向最新版本
- `24.10.2-2025080813`: 完整版本号（软件版本-时间戳）
- `24.10.2`: 软件版本号
- `2025080813`: 时间戳版本
- `20250109`: 构建日期标签

### 环境变量

| 变量名         | 默认值          | 描述                               |
| -------------- | --------------- | ---------------------------------- |
| `KEEP_RUNNING` | `false`         | 设置为 `true` 保持容器运行用于调试 |
| `TZ`           | `Asia/Shanghai` | 时区设置                           |

## 🛠️ 本地开发

### 前置要求

- Docker 和 Docker Buildx
- Linux 环境（用于处理镜像文件）
- qemu-utils, wget, curl 等工具

### 克隆项目

```bash
git clone https://github.com/jianjunx/istoreos-arm.git
cd istoreos-arm
```

### 本地提取根文件系统

```bash
# 给脚本执行权限
chmod +x extract_rootfs.sh

# 运行根文件系统提取
./extract_rootfs.sh
```

这个脚本会：

1. 自动下载最新的 iStoreOS ARM 镜像
2. 解压并挂载镜像文件
3. 提取根文件系统为 `rootfs.tar`

### 本地构建原生镜像

```bash
# 创建构建目录
mkdir docker-build && cd docker-build

# 复制 rootfs.tar
cp ../rootfs.tar .

# 创建 Dockerfile
cat > Dockerfile <<'EOF'
FROM scratch
ADD rootfs.tar /
CMD ["/sbin/init"]
EOF

# 构建镜像
docker build -t istoreos-arm:local .

# 运行测试
docker run -it --privileged istoreos-arm:local
```

## 📁 项目结构

```
istoreos-arm/
├── .github/
│   └── workflows/
│       └── build-arm-image.yml    # GitHub Actions 自动构建工作流
├── Dockerfile                     # Docker 构建文件 (参考用)
├── extract_rootfs.sh             # 本地根文件系统提取脚本
├── update_istoreos_image.sh       # 版本检查脚本 (向后兼容)
├── process_image.sh              # 镜像分析脚本 (向后兼容)
├── setup.sh                      # 项目初始化脚本
├── README.md                     # 项目说明
├── docker.md                    # Docker 使用指南
├── LICENSE                       # MIT 许可证
└── .gitignore                   # Git 忽略规则
```

## ⚙️ GitHub Actions 配置

### 必需的 Secrets

在 GitHub 仓库设置中添加以下 Secrets：

| Secret 名称               | 描述                               |
| ------------------------- | ---------------------------------- |
| `DOCKER_HUB_USERNAME`     | Docker Hub 用户名 (可选，已硬编码) |
| `DOCKER_HUB_ACCESS_TOKEN` | Docker Hub 访问令牌 (必需)         |

**注意**: Docker Hub 用户名已在工作流中设置为 `jjxie233`，您只需要配置访问令牌即可。

### 工作流触发条件

- **定时触发**: 每 6 小时自动检查一次 (0 _/6 _ \* \*)
- **手动触发**: 在 GitHub Actions 页面手动运行
- **强制构建**: 可通过手动触发时选择强制构建选项

### 构建流程

1. **版本检测**: 从官方网站检查最新的 `.img.gz` 文件
2. **文件下载**: 下载最新的 iStoreOS ARM 镜像文件
3. **根文件系统提取**: 使用 NBD 设备挂载并提取 `rootfs.tar`
4. **Docker 构建**: 基于 `FROM scratch` 构建原生容器镜像
5. **多标签推送**: 推送多个版本标签到 Docker Hub
6. **版本管理**: 创建 Git 标签和 GitHub Release

## 🔧 自定义配置

### 修改检查频率

编辑 `.github/workflows/build-arm-image.yml` 文件中的 cron 表达式：

```yaml
schedule:
  - cron: '0 */6 * * *' # 修改这行来改变检查时间 (当前为每6小时)
```

### 修改镜像源

如需修改镜像下载源，编辑工作流文件中的 `ISTOREOS_URL` 环境变量：

```yaml
env:
  ISTOREOS_URL: https://fw.koolcenter.com/iStoreOS/armsr/
```

## 📊 版本追踪

项目会自动追踪以下信息：

- ✅ 当前版本号
- ✅ 镜像文件大小
- ✅ 下载时间
- ✅ 构建状态
- ✅ 发布历史

## 🚀 使用场景

### 开发测试

```bash
# 用于开发环境测试
docker run -it --privileged \
  -e KEEP_RUNNING=true \
  您的用户名/istoreos-arm:latest
```

### 持续集成

```yaml
# 在 CI 中使用
steps:
  - name: Test with iStoreOS
    run: |
      docker pull 您的用户名/istoreos-arm:latest
      docker run --privileged 您的用户名/istoreos-arm:latest
```

## 🐛 故障排除

### 常见问题

1. **权限错误**: 确保以 `--privileged` 模式运行容器
2. **下载失败**: 检查网络连接和官方下载源可用性
3. **镜像过大**: ARM 镜像文件通常在 150-200MB 左右

### 调试模式

```bash
# 启用调试模式
docker run -it --privileged \
  -e KEEP_RUNNING=true \
  您的用户名/istoreos-arm:latest
```

### 查看日志

```bash
# 查看处理日志
docker run --privileged \
  您的用户名/istoreos-arm:latest \
  cat /opt/istoreos/process.log
```

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

### 开发流程

1. Fork 本仓库
2. 创建功能分支
3. 提交更改
4. 发起 Pull Request

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

## 🔗 相关链接

- [iStoreOS 官方](https://www.istoreos.com/)
- [iStoreOS ARM 下载](https://fw.koolcenter.com/iStoreOS/armsr/)
- [Docker Hub 仓库](https://hub.docker.com/r/您的用户名/istoreos-arm)
- [GitHub Releases](https://github.com/您的用户名/istoreos-arm/releases)

## 💖 支持项目

如果这个项目对您有帮助，请考虑：

- ⭐ 给项目加星
- 🐛 报告问题
- 📝 改进文档
- 💡 提出建议

---

**注意**: 请将文档中的 "您的用户名" 替换为您的实际 GitHub 用户名和 Docker Hub 用户名。
