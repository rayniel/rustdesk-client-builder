# rustdesk-client-builder

在线构建最新版 RustDesk Windows 与 Linux x64 客户端，并可将自建服务器默认配置编译进客户端。

## 工作流入口

- Windows GitHub Actions: `.github/workflows/build-rustdesk-win.yml`
- Linux GitHub Actions: `.github/workflows/build-rustdesk-linux.yml`
- 手动触发参数:
	- `rustdesk_ref`: RustDesk 分支、标签或提交
	- `upload_release`: 是否发布到 GitHub Release

两个工作流都会先按所选的 `rustdesk_ref` 生成 Flutter Rust Bridge 源码，再交给对应平台任务编译。这样不会因 RustDesk 未提交生成文件而出现 `bridge_generated` 缺失或 `EventToUI: IntoIntoDart` 不兼容的错误。若 `rustdesk_ref` 包含 `/`，仅产物文件名会将其替换为 `-`；源码检出仍使用原始 ref。

## 自建服务器配置

工作流在编译前补丁 RustDesk 固定版本的 `hbb_common` 配置常量。设置 Secret 后，ID 服务器和公钥会编译进最终客户端；安装后无需导入配置、执行脚本或在客户端手工填写网络参数。

如需构建已配置的客户端，请设置以下 GitHub Secrets:

- `RUSTDESK_HOST`: 必填，通常是 hbbs 地址
- `RUSTDESK_KEY`: 必填，服务器公钥
- `RUSTDESK_RELAY`: 当前同域名、默认端口部署不需要；hbbs 会提供中继信息
- `RUSTDESK_API`: 当前开源服务器部署不需要；不参与此编译期配置

只要设置了任一 `RUSTDESK_HOST` 或 `RUSTDESK_KEY`，就必须同时提供二者；否则工作流会在编译前明确失败。若 RustDesk 上游改变配置常量位置，补丁同样会明确失败，而不会静默生成未配置客户端。

未设置任何上述 Secret 时，工作流保持 RustDesk 上游默认服务器。设置了完整的 `RUSTDESK_HOST` 和 `RUSTDESK_KEY` 时，生成的 Windows 与 Linux 客户端均已内置自建服务器默认值。

Windows 工作流每次只分发一个原生 `rustdesk-*-install.exe`。

- GitHub Actions Artifact 直接包含该安装 EXE。Actions Artifact 固定以 ZIP 形式下载，解压一次后即可运行 EXE。
- 手动运行时将 `upload_release` 设为 `true`，GitHub Release 会直接提供该安装 EXE 下载，不再附加重复 ZIP 或展开目录。

Linux 工作流构建原生 Linux x64 包：

- `.deb`：适用于 Ubuntu、Debian 及其他 Debian 系发行版。
- `.rpm`：适用于 Fedora、RHEL、Rocky Linux、AlmaLinux、CentOS Stream 及其他 RPM 系发行版。
- `.AppImage`：可在大多数 x64 Linux 发行版直接运行；下载后执行 `chmod +x rustdesk-*.AppImage`。

Linux Artifact 直接包含这三个文件；手动运行时将 `upload_release` 设为 `true`，Release 会提供三者的直接下载。

### 验证自建服务器

“设置 → 网络”显示为空是正常的：内置值不会被写入用户的自定义网络设置。工作流将 `EXE_RENDEZVOUS_SERVER` 设为内置服务器，使它优先于当前 Windows 用户已缓存的服务器列表；工作流也会在打包前检查实际会被压入安装包的 `librustdesk.dll` 是否包含配置的 `RUSTDESK_HOST`，检查失败时不会上传安装包。

便携安装包的“直接使用”模式会解压到 `%LOCALAPPDATA%\rustdesk`，但内置 ID 服务器会优先于当前 Windows 用户缓存的 `rendezvous-servers`。请不填写任何网络参数启动客户端，并在 `hbbs` 日志中确认该客户端 ID 的注册或心跳连接。

## 说明

- 当前方案兼容 RustDesk 开源版常规构建流程，不依赖 Pro 的 custom client generator
- 当前工作流构建 Windows x64（`x86_64-pc-windows-msvc`）和 Linux x64（`x86_64-unknown-linux-gnu`）；Artifact 与 Release 名称均包含平台和 `x64`
- 如果未设置上述任何自建服务器 Secret，工作流仍会正常构建未配置客户端
- Windows runner 上的 NASM 和 vcpkg 不能盲目跟随最新版本；本仓库固定 NASM 2.16.03 和 RustDesk 上游 CI 使用的 vcpkg commit，以避免 `aom:x64-windows-static` 在新工具链上构建失败
- 为降低上游 `master` 变化带来的风险，日常发布建议在 `rustdesk_ref` 中填写已验证的 RustDesk tag 或 commit；工作流会为指定 ref 单独生成匹配的 Bridge 文件
