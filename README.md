# rustdesk-win-builder

在线构建最新版 RustDesk Windows 客户端，并可生成自动导入自建服务器配置的安装程序。

## 工作流入口

- GitHub Actions: `.github/workflows/build-rustdesk-win.yml`
- 手动触发参数:
	- `rustdesk_ref`: RustDesk 分支、标签或提交
	- `upload_release`: 是否发布到 GitHub Release

工作流会先按所选的 `rustdesk_ref` 生成 Flutter Rust Bridge 源码，再交给 Windows 任务编译。这样不会因 RustDesk 未提交生成文件而出现 `bridge_generated` 缺失或 `EventToUI: IntoIntoDart` 不兼容的错误。若 `rustdesk_ref` 包含 `/`，仅产物文件名会将其替换为 `-`；源码检出仍使用原始 ref。

## 自建服务器配置

RustDesk 的普通 Windows 安装包不会从构建环境变量持久化自建服务器配置。本工作流在配置 Secret 后生成单一自包含安装 EXE；它安装 RustDesk 后自动调用官方 `rustdesk.exe --config` 命令写入服务器配置。

如需构建已配置的客户端，请设置以下 GitHub Secrets:

- `RUSTDESK_HOST`: 必填，通常是 hbbs 地址
- `RUSTDESK_KEY`: 必填，服务器公钥
- `RUSTDESK_RELAY`: 可选，hbbr 地址
- `RUSTDESK_API`: 可选，RustDesk Pro API 地址

只要设置了任一上述 Secret，就必须同时提供 `RUSTDESK_HOST` 和 `RUSTDESK_KEY`；否则工作流会在编译前明确失败，避免产出配置不完整的客户端。

也可使用 `RUSTDESK_CONFIG` 保存由 RustDesk 客户端导出的完整 Server Config 字符串；当未设置分项 Secret 时，工作流会使用该值。

未设置任何上述 Secret 时，工作流分发原生 `rustdesk-*-install.exe`。设置了完整的自建服务器配置后，工作流只分发 `rustdesk-*-selfhosted-setup.exe`；用户双击该 EXE 即可完成安装和配置导入。

工作流每次只分发一个终端用户安装 EXE。未配置自建服务器时为原生 `rustdesk-*-install.exe`；配置后为 `rustdesk-*-selfhosted-setup.exe`。

- GitHub Actions Artifact 直接包含该安装 EXE。Actions Artifact 固定以 ZIP 形式下载，解压一次后即可运行 EXE。
- 手动运行时将 `upload_release` 设为 `true`，GitHub Release 会直接提供该安装 EXE 下载，不再附加重复 ZIP 或展开目录。

## 说明

- 当前方案兼容 RustDesk 开源版常规构建流程，不依赖 Pro 的 custom client generator
- 当前工作流仅构建 Windows x64（`x86_64-pc-windows-msvc`）；Artifact 与 Release 名称均包含 `windows-x64`
- 如果未设置上述任何自建服务器 Secret，工作流仍会正常构建未配置客户端
- Windows runner 上的 NASM 和 vcpkg 不能盲目跟随最新版本；本仓库固定 NASM 2.16.03 和 RustDesk 上游 CI 使用的 vcpkg commit，以避免 `aom:x64-windows-static` 在新工具链上构建失败
- 为降低上游 `master` 变化带来的风险，日常发布建议在 `rustdesk_ref` 中填写已验证的 RustDesk tag 或 commit；工作流会为指定 ref 单独生成匹配的 Bridge 文件
