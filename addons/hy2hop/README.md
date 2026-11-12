# Hkit 配件 · Hysteria2 端口跳跃

给已经装好的 Hkit 加上 Hysteria2 **端口跳跃**：把一段 UDP 端口（默认 `20000-30000`）转发到 Hkit 的 Hysteria2 监听端口。客户端在这段端口里随机切换，可以减轻单个 UDP 端口被限速或封锁的影响。

这是独立的配件，**不修改 Hkit 本身**：

- 只读取 `/etc/hkit/state.json` 里 Hysteria2 的端口，不改 Hkit 的任何文件、服务或订阅。
- 用一张独立的 nftables 表（`hkit_hy2hop`）做转发，开机自动恢复。
- 原来的 Hysteria2 端口照常可用，没开跳跃的客户端不受影响。

核心逻辑来自 [Hysteria2-Hop](https://github.com/hcloudlab/Hysteria2-Hop)（3X-UI 版），区别只是端口从 Hkit 读取。两者使用不同的表名和服务名，互不干扰。

## 安装

前提：已经用 Hkit 安装了 Hysteria2 协议。

```bash
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/hcloudlab/Hkit/main/addons/hy2hop/bootstrap.sh)"
```

打开菜单后选 **1. 一键安装**，跳跃范围直接回车就是 `20000-30000`。

也可以不进菜单，直接指定范围：

```bash
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/hcloudlab/Hkit/main/addons/hy2hop/bootstrap.sh)" _ install --range 20000-30000
```

安装后用 `sudo hkit-hy2hop` 再次打开菜单。

## 客户端设置

Hkit 的订阅**不会**自动带上跳跃端口，需要在客户端里手动加，刷新订阅后要重新加：

| 客户端 | 设置 |
| --- | --- |
| Clash Verge / Mihomo | Hysteria2 节点加一行 `ports: "20000-30000"`，保留原来的 `port` |
| sing-box | `server_ports: ["20000:30000"]` |
| 小火箭 / v2rayN | 分享链接加参数 `mport=20000-30000`，或在节点里填写跳跃端口 |

## 常用命令

| 命令 | 作用 |
| --- | --- |
| `sudo hkit-hy2hop status` | 检查转发规则、防火墙和开机恢复是否正常，并显示已转发的数据包数 |
| `sudo hkit-hy2hop update` | Hkit 重装或 Hysteria2 端口变化后重新生成规则；加 `--range 起-止` 可换范围 |
| `sudo hkit-hy2hop restore` | 删除本配件的规则、服务和它加的 UFW 规则，恢复原样 |

**卸载 Hkit 前先执行 `sudo hkit-hy2hop restore`。** 否则转发规则会留下，指向一个已经不存在的端口。重装 Hkit 后执行 `update` 即可。

## 防火墙

- 启用了 UFW 时，自动放行跳跃范围（UDP）。Hysteria2 的监听端口如果还没放行，也会一起放行。`restore` 只删除本配件加的规则。
- firewalld 只提示，不修改。
- 云服务商的安全组需要自己在后台放行跳跃范围的 UDP（搬瓦工默认没有安全组）。

## 支持的系统

Debian 11 / 12 / 13，Ubuntu 20.04 / 22.04 / 24.04 / 26.04，需要 systemd 和 nftables（没有时自动安装）。不支持 OpenVZ / LXC 等不允许 nftables NAT 的容器型 VPS。

## 测试

```bash
cd addons/hy2hop && python3 -m unittest discover -s tests
```
