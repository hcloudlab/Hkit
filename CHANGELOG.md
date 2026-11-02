# Changelog

## 1.0.2（未发布）

- 支持 Ubuntu 22.04/24.04、Debian 12/13，并在下载前检查系统与 x86_64 架构。
- Debian 上自动安装依赖。
- 中文 README，英文说明移至 README_EN.md。
- 配套 Core 1.0.2：随机证书名、证书指纹固定、XHTTP/AnyTLS 分享链接、`hkit` 管理命令、失败自动回滚、自动检测公网 IP。

## 1.0.1

- Include every runtime dependency required by the Format 2 Core installer.
- Support the version-pinned URL bootstrap on Ubuntu 24.04 without cloning the
  public repository.
- Add release-package and Linux installation acceptance coverage for the
  bootstrap-to-Core path.

## 1.0.0

- Initial signed Hkit release with five protocol components.
