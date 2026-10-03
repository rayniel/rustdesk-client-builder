# rustdesk-win-builder

在线构建最新版 RustDesk Windows 客户端，并可在编译时将自建服务器配置嵌入二进制文件。

## 工作流入口

- GitHub Actions: `.github/workflows/build-rustdesk-win.yml`
- 手动触发参数:
	- `rustdesk_ref`: RustDesk 分支、标签或提交
	- `upload_release`: 是否发布到 GitHub Release

工作流会先按所选的 `rustdesk_ref` 生成 Flutter Rust Bridge 源码，再交给 Windows 任务编译。这样不会因 RustDesk 未提交生成文件而出现 `bridge_generated` 缺失或 `EventToUI: IntoIntoDart` 不兼容的错误。若 `rustdesk_ref` 包含 `/`，仅产物文件名会将其替换为 `-`；源码检出仍使用原始 ref。

## 自建服务器配置

RustDesk 上游文档说明，自定义客户端应在构建过程使用 `RS_PUB_KEY`、`RENDEZVOUS_SERVER` 和 `API_SERVER` 环境变量。本工作流将 GitHub Secrets 映射为这些变量，因此配置会直接编译进 Windows 二进制文件；安装后无需、也不会调用 `rustdesk.exe --config`。

如需构建已配置的客户端，请设置以下 GitHub Secrets:

- `RUSTDESK_HOST`: 必填，映射到 `RENDEZVOUS_SERVER`，通常是 hbbs 地址
- `RUSTDESK_KEY`: 必填，服务器公钥
- `RUSTDESK_API`: 可选，映射到 `API_SERVER`，用于 API 地址

`RUSTDESK_KEY` 会映射到上游要求的 `RS_PUB_KEY`。只要设置了任一上述 Secret，就必须同时提供 `RUSTDESK_HOST` 和 `RUSTDESK_KEY`；否则工作流会在编译前明确失败，避免产出配置不完整的客户端。

不要设置 `RUSTDESK_RELAY`：RustDesk 上游文档列出的嵌入式构建变量不包含独立的 relay 变量，因此本工作流不会将它编译进客户端。

未设置任何上述 Secret 时，工作流保持 RustDesk 上游的普通未配置构建。设置了完整的 `RUSTDESK_HOST` 和 `RUSTDESK_KEY` 时，默认产物就是已嵌入自建服务器配置的客户端。

工作流构建完成后，产物目录 `dist` 会包含:
- RustDesk Windows 安装包 `rustdesk-*-install.exe`
- Flutter 构建输出目录内容

同时还会额外生成一个可直接分发的压缩包:

- `rustdesk-windows-x64-<ref>-bundle.zip`

## 说明

- 当前方案兼容 RustDesk 开源版常规构建流程，不依赖 Pro 的 custom client generator
- 当前工作流仅构建 Windows x64（`x86_64-pc-windows-msvc`）；Artifact、ZIP 和 Release 名称均包含 `windows-x64`
- 如果未设置上述任何自建服务器 Secret，工作流仍会正常构建未配置客户端
- Windows runner 上的 NASM 和 vcpkg 不能盲目跟随最新版本；本仓库固定 NASM 2.16.03 和 RustDesk 上游 CI 使用的 vcpkg commit，以避免 `aom:x64-windows-static` 在新工具链上构建失败
- 为降低上游 `master` 变化带来的风险，日常发布建议在 `rustdesk_ref` 中填写已验证的 RustDesk tag 或 commit；工作流会为指定 ref 单独生成匹配的 Bridge 文件
