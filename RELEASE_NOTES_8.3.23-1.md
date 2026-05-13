## IYUUPlus fnOS 包 8.3.23-1

- 首个对外发版包（fnOS 三方应用格式）。
- **镜像**：`iyuucn/iyuuplus-dev:latest`（Docker Hub 仓库仅提供 `latest` tag，与[官方快速开始](https://doc.iyuu.cn/guide/getting-started)一致）。
- **网络**：`bridge`，Web 入口 `wizard_port` → 容器 `8780`。
- **数据卷**：`${TRIM_PKGETC}` → `/iyuu`，`${TRIM_PKGVAR}/data` → `/data`。
