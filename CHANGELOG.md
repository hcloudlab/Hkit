# Changelog

## 1.0.3

- 自动放行防火墙端口：UFW 或 firewalld 已启用时，只放行所装协议的端口和订阅需要的 2096/TCP、80/TCP；不启用、不重置防火墙；卸载时只删除这些规则。`--no-firewall` 关闭。
- 小火箭支持 Mieru：小火箭订阅和 `hkit links` 中加入 `mierus://` 链接。
- 新增 `clash-mieru` 订阅：只含 Mieru 节点的 Clash Verge / Mihomo 完整配置。
- 安装前一次性列出所有冲突（端口占用及进程、同名系统用户和用户组、服务文件、`/run/mita`），并给出旧 mita 的清理命令。
- 安装提示、协议菜单和错误说明改为中文。
- 配套 Core 1.0.3。

## 1.0.2

- 支持 Ubuntu 22.04/24.04、Debian 12/13，并在下载前检查系统与 x86_64 架构。
- Debian 上自动安装依赖。
- 中文 README，英文说明移至 README_EN.md。
- Reality 不再默认使用 www.cloudflare.com：安装时在 VPS 上测试 NVIDIA、AMD 等候选站点，自动选出合格且最快的目标。
- 安装后自动提供包含全部节点的 HTTPS 订阅（小火箭、Clash Verge、v2rayN、v2rayNG、sing-box），使用 Let's Encrypt IP 证书，无需域名。
- 配套 Core 1.0.2：随机证书名、证书指纹固定、XHTTP/AnyTLS 分享链接、`hkit` 管理命令、失败自动回滚、自动检测公网 IP。

## 1.0.1

- Include every runtime dependency required by the Format 2 Core installer.
- Support the version-pinned URL bootstrap on Ubuntu 24.04 without cloning the
  public repository.
- Add release-package and Linux installation acceptance coverage for the
  bootstrap-to-Core path.

## 1.0.0

- Initial signed Hkit release with five protocol components.
