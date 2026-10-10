# Loon 配置

[English](LoonIntegration.md)

WrapPin 可以把 Loon 作为设备隧道跳转应用。标准版始终提供这个选项，隧道版在未启用内置隧道时提供。此集成不会读取或修改 Loon 的 VPN 状态；当配对设备通道不可达时，WrapPin 使用 Loon 官方 URL Scheme `loon://on` 请求开启 VPN，然后继续检测配对服务。

## 要求

- Loon Build 1007（3.5.3）或更高版本。
- 启用下面的插件，使路由和 IP Rewrite 设置生效。

```ini
[General]
ipv6-vif = off
include-tun = 10.7.0.1/32

[IP Rewrite]
10.7.0.1 = reflect
```

`include-tun` 让发往 `10.7.0.1` 的连接进入 Loon 的 TUN；`reflect` 把该连接反射回本机，使 WrapPin 可以访问 iPhone 自己的开发者服务。`ipv6-vif = off` 避免依赖此 IPv4 本机通道的工具选择 IPv6 VPN 接口。

Loon 文档说明 `include-tun` 可以写在主配置或插件中，而本机回环所需的 IP Rewrite 需要在插件中声明，因此建议直接导入仓库提供的 [`WrapPin-Loon.lpx`](WrapPin-Loon.lpx)。插件带有 `loon_version=3.5.3(1007)` 的版本要求，避免旧版 Loon 看似启用、实际却不支持这些设置。

## WrapPin 设置

1. 在 WrapPin 的“设置 → 隧道跳转应用”中选择 Loon。
2. 完成一次设备配对。
3. 开始模拟定位。若当前设备通道不可达，WrapPin 会请求 Loon 开启 VPN。
4. Loon 开启后手动返回 WrapPin；WrapPin 会继续检测连接。

若蜂窝网络下检测失败，请先用 Wi-Fi 验证。WrapPin 只能验证配对设备通道是否可达，无法读取 Loon 的 VPN 开关。

## 依据

- Loon 官方 URL Scheme 文档：<https://nsloon.app/docs/Scheme/>
- Loon 官方 `include-tun` 文档：<https://nsloon.app/docs/General/#include-tun>
