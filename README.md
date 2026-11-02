# Hkit — 代理协议一键部署脚本

Hkit 在一台全新的 VPS 上一键部署以下协议，并自动提供一个包含全部节点的 **HTTPS 订阅链接**，小火箭、Clash Verge、v2rayN、v2rayNG 和 sing-box 系客户端都能直接导入：

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
4. 自动启动订阅服务，并向 Let's Encrypt 申请这台服务器 IP 的 HTTPS 证书（不需要域名）。
5. 安装中途出错时，脚本会自动清理已安装的部分，修复问题后直接重新运行即可。

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
sudo ufw allow 2096/tcp    # 订阅服务
sudo ufw allow 80/tcp      # 订阅证书申请与续期
```

以安装结束时屏幕上显示的端口为准，没装的协议不用放行。

> **订阅需要 80/TCP 和 2096/TCP 都放行。** 80 端口用于申请和续期 HTTPS 证书（证书约 6 天自动续期一次），不放行就拿不到证书，订阅链接会打不开；单个节点链接不受影响。

---

## 四、导入客户端

### 1. 获取订阅链接（推荐）

```bash
sudo hkit links
```

最上方会列出各客户端专用的订阅链接，格式如下：

```text
小火箭 Shadowrocket
https://你的IP:2096/随机令牌/shadowrocket

Clash Verge / Mihomo
https://你的IP:2096/随机令牌/clash

v2rayN
https://你的IP:2096/随机令牌/v2rayn

v2rayNG
https://你的IP:2096/随机令牌/v2rayng

sing-box（SFA / SFI / SFM / Hiddify）
https://你的IP:2096/随机令牌/singbox
```

复制对应客户端的那一条，在客户端里"添加订阅 / 从 URL 导入"即可：

| 客户端 | 导入位置 | 订阅内容 |
| --- | --- | --- |
| 小火箭 Shadowrocket | 首页右上角 `+` → 类型选 Subscribe → 粘贴 URL | 全部节点的分享链接 |
| Clash Verge Rev / Mihomo Party / FlClash | 订阅 → 粘贴链接 → 导入 | 完整配置：国内直连、其余走代理，含"自动选择"节点组 |
| v2rayN | 订阅分组 → 订阅分组设置 → 添加 → 粘贴 URL → 更新订阅 | 全部节点的分享链接 |
| v2rayNG | 右上角菜单 → 订阅分组设置 → `+` → 粘贴 URL → 更新订阅 | 全部节点的分享链接 |
| sing-box（SFA / SFI / SFM）/ Hiddify | Profiles → 新建 → 类型选 Remote → 粘贴 URL | 完整配置：国内直连、其余走代理（需 sing-box 1.13 及以上） |

菜单名称随客户端版本略有不同。Clash Verge 和 sing-box 的完整配置会从 jsDelivr 下载国内分流规则，首次导入需要几秒钟。

**订阅链接里的随机令牌相当于密码**：任何拿到链接的人都能看到你全部节点。不要截图发到公开场合。

各协议在订阅里的支持情况：

| 协议 | 小火箭 / v2rayN / v2rayNG | Clash Verge | sing-box |
| --- | --- | --- | --- |
| Reality | 有 | 有 | 有 |
| Hysteria2 | 有 | 有 | 有 |
| XHTTP | 有 | 有 | 无（sing-box 不支持 XHTTP） |
| AnyTLS | 有 | 有 | 有 |
| Mieru | 无（没有通用链接格式） | 有 | 无 |

> 各客户端对协议的支持随版本变化，导入失败时请先把客户端更新到最新版。

### 2. 单个节点链接与配置文件

同样执行 `sudo hkit links`，订阅链接下方是每个节点单独的分享链接，可以复制单条导入。

`sudo hkit files` 列出所有配置文件的位置（在 `/var/lib/hkit/artifacts/output/`），适合不想用订阅、手动导入的情况：

| 文件 | 内容 |
| --- | --- |
| `subscription-recommended-raw.txt` | 每行一个分享链接 |
| `subscription-recommended-base64.txt` | Base64 订阅内容 |
| `mihomo-complete.yaml` | 完整 Mihomo（Clash Meta）配置 |
| `mihomo-provider.yaml` | 只含节点的 proxy-provider，已有自己的分流规则时使用 |
| `sing-box-complete-modern.json` | 完整 sing-box 配置 |

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
| `sudo hkit links` | 显示订阅链接和节点分享链接 |
| `hkit files` | 列出客户端配置文件位置 |
| `sudo hkit restart` | 重启全部服务 |
| `sudo hkit logs` | 查看最近日志；`sudo hkit logs xray` 只看某个服务，订阅服务是 `publisher` |
| `sudo hkit uninstall` | 卸载 Hkit |
| `hkit version` | 查看版本 |

对应的 systemd 服务名：`hkit-xray`、`hkit-hysteria2`、`hkit-singbox`、`hkit-mieru`，订阅服务是 `hkit-publisher`。

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
| `--reality-target HOST:443` | Reality 目标站点 | 自动选择（见下方说明） |
| `--reality-sni NAME` | Reality SNI，需与目标站点证书匹配；只填这一项时目标站点自动设为同名的 443 端口 | 自动选择 |
| `--tls-sni NAME` | 自签证书使用的域名 | 每台服务器随机 |
| `--sub-port PORT` | 订阅服务的 HTTPS 端口 | 2096 |
| `--no-subscription` | 不启动订阅服务（只提供单个节点链接和配置文件） | — |

示例：Reality 改用 8080 端口，并换一个目标站点：

```bash
curl -fsSL https://raw.githubusercontent.com/hcloudlab/Hkit/v1.0.2/install.sh | \
  sudo bash -s -- --protocols reality --reality-port 8080 \
  --reality-target www.microsoft.com:443 --reality-sni www.microsoft.com
```

> **Reality 目标站点默认自动选择**：安装时从 VPS 上逐个测试 NVIDIA、AMD、Intel、Samsung、Oracle、AWS 的官网，只保留同时满足 TLS 1.3（X25519）、HTTP/2、证书有效、不跳转到其他域名的站点，再选握手最快的一个。这样每台服务器选到的站点可能不同，不会所有人都用同一个。
>
> 手动指定时也会做同样的检查，不合格会直接报错。自选站点建议用离 VPS 近、非 Cloudflare 的大型网站。

---

## 八、常见问题

**安装提示 `unsupported_platform`**
系统或架构不在支持范围内。请换成 Ubuntu 22.04/24.04 或 Debian 12/13 的 x86_64 系统。

**提示 `port_in_use`**
端口被其他程序占用。用 `ss -tulpn | grep 端口号` 查看是谁占用，或用对应的 `--xxx-port` 参数换一个端口。

**提示 `target_exists`**
服务器上已有 Hkit 的安装目录。先执行 `sudo hkit uninstall` 卸载，再重新安装。

**提示 `reality_target_unavailable` 或 `reality_target_unsuitable`**
VPS 访问不了候选站点，或者你指定的站点不满足 Reality 要求。换一个站点手动指定，例如 `--reality-sni www.amd.com`；也可以先用 `curl -I https://www.nvidia.com` 检查 VPS 的外网是否正常。

**提示 `public_ipv4_unknown`**
无法自动获取公网 IP（比如服务器访问不了外网检测服务）。加上 `--public-ipv4 你的IP` 重新运行。

**`--interactive` 提示没有终端**
在不能交互的环境（如自动化脚本）里运行时，请改用 `--protocols` 指定协议。

**客户端连不上**
1. `hkit status` 确认服务是 `active`；
2. 检查服务商安全组是否放行了端口，Hysteria2 要放行 **UDP**；
3. `sudo hkit logs` 查看报错；
4. 确认客户端是最新版本。

**订阅链接打不开 / 提示证书错误**
1. 确认云防火墙和 UFW 都放行了 **80/TCP** 和 **2096/TCP**；
2. 放行后等 1～2 分钟，证书会自动签发，再执行 `sudo hkit links`，看是否还有"证书尚未签发"的提示；
3. 仍不行时用 `sudo hkit logs publisher` 查看原因；
4. 订阅服务出问题不影响节点本身，可以先用单个节点链接。

**80 端口被占用（比如装了 Nginx）**
安装会给出提示并跳过订阅服务，节点照常可用。可以先停掉占用 80 端口的程序再重新安装，或者用单个节点链接。

**只有 IPv6 的服务器能用吗**
暂不支持，需要公网 IPv4。

---

## 安全说明

- 安装脚本固定在具体版本标签（如 `v1.0.2`），不会跟随 `main` 分支变化。
- 正式发布包使用 Minisign 签名，签名公钥和校验脚本的 SHA-256 写死在 `install.sh` 中；签名、哈希、文件清单任何一项不符都会在执行安装代码前终止。
- 不修改 SSH、UFW、BBR/sysctl 等系统设置。
- 各协议服务使用独立的低权限系统用户运行，并禁止代理流量访问服务器本机和内网地址（包括云厂商元数据地址）。
- 订阅服务只走 HTTPS（Let's Encrypt 签发的 IP 证书），只响应带 48 位随机令牌的固定路径，其他路径一律返回 404。

发布流程与签名身份见 [docs/releasing.md](docs/releasing.md)，版本与 Core 提交的对应关系见 [versions.json](versions.json)。
