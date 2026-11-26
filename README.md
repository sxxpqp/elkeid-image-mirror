# Elkeid 镜像同步

从 [Elkeid v1.9.1.4](https://github.com/bytedance/Elkeid/releases/tag/v1.9.1.4) 下载 `elkeidup_image_v1.9.1.tar.gz.00` 至 `.03`，按顺序拼接、检查 gzip 完整性、导入 Docker 并推送阿里云 ACR。工作流保留原镜像标签，将 `elkeid/all-in-one:v1.9.1` 推送为 `registry.cn-hangzhou.aliyuncs.com/sxxpqp/elkeid-all-in-one:v1.9.1`。其他镜像沿用原组件名。推送成功的源与目标映射写入运行摘要。

## 配置与运行

1. 在 GitHub 仓库的 Actions Secrets 中配置 `ALIYUN_REGISTRY_USER` 和 `ALIYUN_REGISTRY_PASSWORD`。
2. Actions Variables 可设置 `ACR_REGISTRY` 和 `ACR_NAMESPACE`。默认地址为 `registry.cn-hangzhou.aliyuncs.com`，命名空间为 `sxxpqp`。凭据需要能推送这些组件仓库。如果 ACR 禁用了自动建仓，先创建对应组件仓库。
3. 推送发布脚本或工作流的改动到 `main` 会自动运行。也可以在 Actions 中选择 **Mirror Elkeid release images**，点击 **Run workflow**。分卷合计约 3.5 GB，Runner 还需有足够磁盘空间存放导入后的 Docker 镜像层。
