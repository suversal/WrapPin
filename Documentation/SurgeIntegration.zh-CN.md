# Surge iOS 配置

WrapPin 标准版可以把 Surge 作为设备隧道跳转应用。此集成不会读取或修改 Surge 的 VPN 状态；当配对设备通道不可达时，WrapPin 使用 Surge 官方 URL Scheme `surge:///start` 启动当前配置，然后继续检测配对服务。

## 要求

- Surge iOS 5.23.0 或更高版本。
- Surge 使用 VIF 接管流量。
- 当前配置包含下面的路由和 IP Rewrite 设置。

```ini
[General]
ipv6-vif = disabled
tun-included-routes = %INSERT% 10.7.0.1/32

[IP Rewrite]
10.7.0.1 = reflect
```

`tun-included-routes` 让发往 `10.7.0.1` 的连接进入 Surge VIF；`reflect` 把该连接反射回本机，使 WrapPin 可以访问 iPhone 自己的开发者服务。`ipv6-vif = disabled` 避免依赖此 IPv4 本机通道的工具选择 IPv6 VPN 接口。

仓库同时提供可导入的 [`WrapPin-Surge.sgmodule`](WrapPin-Surge.sgmodule)。也可以手动把上面的配置合并到现有区段；不要创建重复的 `[General]` 或 `[IP Rewrite]`。托管配置无法编辑时，请使用模块。

## WrapPin 设置

1. 在 WrapPin 的“设置 → 隧道应用”中选择 Surge。
2. 完成一次设备配对。
3. 开始模拟定位。若当前设备通道不可达，WrapPin 会请求 Surge 启动当前配置。
4. Surge 启动后手动返回 WrapPin；WrapPin 会继续检测连接。

若蜂窝网络下检测失败，请先用 Wi-Fi 验证。WrapPin 只能验证配对设备通道是否可达，无法读取 Surge 的 VPN 开关。

## 依据

- Surge 官方 URL Scheme 文档：<https://manual.nssurge.com/tools/url-scheme.html>
- Surge 官方 IP Rewrite 文档（On-Device Developer Services）：<https://manual.nssurge.com/features/ip-rewrite.html>
