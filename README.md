# Hkit — 代理协议一键部署脚本

Hkit 在一台全新的 VPS 上一键部署以下协议，并自动生成可导入各客户端的节点链接和配置文件：

| 协议 | 底层程序 | 默认端口 | 适合场景 |
| --- | --- | --- | --- |
| VLESS Reality | Xray | 443/TCP | 首选，伪装性好，稳定 |
| Hysteria2 | Hysteria | 8443/UDP | 线路丢包多、需要高速时 |
| VLESS XHTTP | Xray | 8443/TCP | 备用 TCP 协议 |
| AnyTLS | sing-box | 8444/TCP | 备用 TCP 协议 |
| Mieru | mita | 34567/TCP | 备用，仅 Mihomo 内核客户端可用 |

**English:** see [README_EN.md](README_EN.md).

---

## 一、安装前准备

### 1. 系统要求

| 项目 | 要求 |
| --- | --- |
| 系统 | Ubuntu 22.04 / 24.04，Debian 12 / 13（推荐全新系统） |
| 架构 | x86_64（amd64）。暂不支持 ARM |
| 虚拟化 | KVM 等带 systemd 的 VPS（不支持无 systemd 的 OpenVZ/LXC 容器） |
| 权限 | root 用户，或可以使用 `sudo` |
| 网络 | 有公网 IPv4 |

> 查看系统版本：`cat /etc/os-release`；查看架构：`uname -m`（显示 `x86_64` 即可）。

### 2. 确认服务器上没有其他代理

Hkit 不会接管或覆盖你已经装好的 3X-UI、Xray、Hysteria2 等程序。如果端口已被占用，安装会直接停止并提示是哪个端口。建议在**全新系统**上安装。

### 3. 安装 curl

大多数系统自带 curl。如果没有，先执行：

```bash
apt-get update && apt-get install -y curl
```

其余依赖（jq、minisign、python3 等）安装脚本会自动安装。

---

## 二、一键安装

下面的命令都带有 `sudo`。如果你已经是 root 用户，而系统里没有 `sudo`（Debian 最小化安装常见），把命令中的 `sudo bash` 改成 `bash` 即可。

### 方式 A：安装全部协议

```bash
curl -fsSL https://raw.githubusercontent.com/hcloudlab/Hkit/v1.0.2/install.sh | sudo bash
```

### 方式 B：只安装指定协议（推荐）

例如只装 Reality 和 Hysteria2：

```bash
curl -fsSL https://raw.githubusercontent.com/hcloudlab/Hkit/v1.0.2/install.sh | \
  sudo bash -s -- --protocols reality,hysteria2
```

可选协议名：`reality`、`hysteria2`、`xhttp`、`anytls`、`mieru`，多个用英文逗号分隔。

### 方式 C：用菜单选择

```bash
curl -fsSL https://raw.githubusercontent.com/hcloudlab/Hkit/v1.0.2/install.sh | \
  sudo bash -s -- --interactive
```

按提示输入编号（如 `1,2`），回车后输入 `y` 确认。

### 安装过程说明

1. 脚本会自动检测服务器公网 IPv4，并显示出来。检测不准时用 `--public-ipv4 你的IP` 手动指定。
2. 下载约 160 MB 的安装包，先校验数字签名和哈希，校验不通过不会执行任何安装代码。
3. 安装完成后显示每个协议的端口和需要放行的防火墙命令。
4. 安装中途出错时，脚本会自动清理已安装的部分，修复问题后直接重新运行即可。

---

## 三、放行防火墙端口（重要）

Hkit **不会自动修改防火墙**。安装完成后，按屏幕提示放行端口，常见有两处：

**1. VPS 服务商的安全组 / 云防火墙**（阿里云、腾讯云、AWS、搬瓦工等后台）

在控制台里放行对应端口。注意 Hysteria2 是 **UDP**，其他协议是 **TCP**。

**2. 服务器本机的 UFW**（只有你启用了 UFW 才需要）

```bash
sudo ufw allow 443/tcp     # Reality
sudo ufw allow 8443/udp    # Hysteria2
sudo ufw allow 8443/tcp    # XHTTP
sudo ufw allow 8444/tcp    # AnyTLS
sudo ufw allow 34567/tcp   # Mieru
```

以安装结束时屏幕上显示的端口为准，没装的协议不用放行。

---

## 四、获取节点并导入客户端

### 1. 查看分享链接

```bash
sudo hkit links
```

每行一个节点链接，复制整行即可导入客户端。**链接里含有密码，不要发到公开场合。**

### 2. 各客户端用哪个文件

```bash
sudo hkit files
```

会列出所有配置文件的位置（都在 `/var/lib/hkit/artifacts/output/`）：

| 文件 | 用途 | 常见客户端 |
| --- | --- | --- |
| `subscription-recommended-raw.txt` | 每行一个分享链接 | Shadowrocket、v2rayN、NekoBox 等，复制链接导入 |
| `subscription-recommended-base64.txt` | Base64 订阅内容 | 支持 Base64 订阅格式的客户端 |
| `mihomo-complete.yaml` | 完整 Mihomo（Clash Meta）配置 | Clash Verge Rev、Mihomo Party、FlClash |
| `mihomo-provider.yaml` | 只含节点的 proxy-provider | 已有自己的分流规则时使用 |
| `sing-box-complete-modern.json` | 完整 sing-box 配置 | sing-box / SFM / SFI（需 1.13 及以上版本） |

协议与文件对应关系：

| 协议 | 分享链接 | Mihomo | sing-box |
| --- | --- | --- | --- |
| Reality | 有 | 有 | 有 |
| Hysteria2 | 有 | 有 | 有 |
| XHTTP | 有 | 有 | 无（sing-box 不支持 XHTTP） |
| AnyTLS | 有 | 有 | 有 |
| Mieru | 无 | 有 | 无 |

> 各客户端对协议的支持随版本变化，导入失败时请先把客户端更新到最新版。

### 3. 把配置文件下载到电脑

在**你自己的电脑**上执行（把 `服务器IP` 换成你的 VPS IP）：

```bash
scp root@服务器IP:/var/lib/hkit/artifacts/output/mihomo-complete.yaml .
```

### 关于证书

Hysteria2、XHTTP、AnyTLS 使用每台服务器随机生成的自签名证书，证书名也是随机的，不会和其他 Hkit 用户的服务器相同。Mihomo 和 sing-box 配置里已经写入了证书指纹，即使开启了"跳过证书验证"，也只会接受你这台服务器的证书。分享链接中的证书固定是否生效取决于客户端是否支持该参数。

---

## 五、日常管理

| 命令 | 作用 |
| --- | --- |
| `hkit status` | 查看各服务是否在运行、端口 |
| `sudo hkit links` | 显示节点分享链接 |
| `hkit files` | 列出客户端配置文件位置 |
| `sudo hkit restart` | 重启全部服务 |
| `sudo hkit logs` | 查看最近日志；`sudo hkit logs xray` 只看某个协议 |
| `sudo hkit uninstall` | 卸载 Hkit |
| `hkit version` | 查看版本 |

对应的 systemd 服务名：`hkit-xray`、`hkit-hysteria2`、`hkit-singbox`、`hkit-mieru`。

---

## 六、卸载

```bash
sudo hkit uninstall
```

输入 `yes` 确认后，会删除 Hkit 的全部服务、配置、证书和节点信息。之前为 Hkit 放行的防火墙端口需要你自己关闭。

---

## 七、可选参数

在安装命令的 `bash -s --` 后面追加：

| 参数 | 说明 | 默认值 |
| --- | --- | --- |
| `--protocols LIST` | 要安装的协议 | 全部 |
| `--interactive` | 用菜单选择协议（不能和 `--protocols` 同时用） | — |
| `--public-ipv4 IP` | 手动指定服务器公网 IP | 自动检测 |
| `--reality-port` | Reality 端口 | 443 |
| `--hysteria2-port` | Hysteria2 端口（UDP） | 8443 |
| `--xhttp-port` | XHTTP 端口 | 8443 |
| `--anytls-port` | AnyTLS 端口 | 8444 |
| `--mieru-port` | Mieru 端口 | 34567 |
| `--reality-target HOST:443` | Reality 回落目标站点 | `www.cloudflare.com:443` |
| `--reality-sni NAME` | Reality SNI，需与目标站点证书匹配 | `www.cloudflare.com` |
| `--tls-sni NAME` | 自签证书使用的域名 | 每台服务器随机 |

示例：Reality 改用 8080 端口，并换一个目标站点：

```bash
curl -fsSL https://raw.githubusercontent.com/hcloudlab/Hkit/v1.0.2/install.sh | \
  sudo bash -s -- --protocols reality --reality-port 8080 \
  --reality-target www.microsoft.com:443 --reality-sni www.microsoft.com
```

> Reality 目标站点建议选择支持 TLS 1.3、离你 VPS 较近、不经过 CDN 的大型网站。

---

## 八、常见问题

**安装提示 `unsupported_platform`**
系统或架构不在支持范围内。请换成 Ubuntu 22.04/24.04 或 Debian 12/13 的 x86_64 系统。

**提示 `port_in_use`**
端口被其他程序占用。用 `ss -tulpn | grep 端口号` 查看是谁占用，或用对应的 `--xxx-port` 参数换一个端口。

**提示 `target_exists`**
服务器上已有 Hkit 的安装目录。先执行 `sudo hkit uninstall` 卸载，再重新安装。

**提示 `public_ipv4_unknown`**
无法自动获取公网 IP（比如服务器访问不了外网检测服务）。加上 `--public-ipv4 你的IP` 重新运行。

**`--interactive` 提示没有终端**
在不能交互的环境（如自动化脚本）里运行时，请改用 `--protocols` 指定协议。

**客户端连不上**
1. `hkit status` 确认服务是 `active`；
2. 检查服务商安全组是否放行了端口，Hysteria2 要放行 **UDP**；
3. `sudo hkit logs` 查看报错；
4. 确认客户端是最新版本。

**只有 IPv6 的服务器能用吗**
暂不支持，需要公网 IPv4。

---

## 安全说明

- 安装脚本固定在具体版本标签（如 `v1.0.2`），不会跟随 `main` 分支变化。
- 正式发布包使用 Minisign 签名，签名公钥和校验脚本的 SHA-256 写死在 `install.sh` 中；签名、哈希、文件清单任何一项不符都会在执行安装代码前终止。
- 不修改 SSH、UFW、BBR/sysctl 等系统设置。
- 各协议服务使用独立的低权限系统用户运行，并禁止代理流量访问服务器本机和内网地址（包括云厂商元数据地址）。

发布流程与签名身份见 [docs/releasing.md](docs/releasing.md)，版本与 Core 提交的对应关系见 [versions.json](versions.json)。
