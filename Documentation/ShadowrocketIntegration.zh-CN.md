# Shadowrocket 配置

[English](ShadowrocketIntegration.md)

WrapPin 可以把 Shadowrocket 作为设备隧道跳转应用。标准版始终提供这个选项，隧道版在未启用内置隧道时提供。此集成不会读取或修改 Shadowrocket 的 VPN 状态；当配对设备通道不可达时，WrapPin 使用 URL Scheme `shadowrocket://connect` 请求开启 VPN，然后继续检测配对服务。

## 要求

- Shadowrocket 的设置中提供“包含路由 10.7.0.1/32”开关。如果没有这一项，请先更新 Shadowrocket。
- 在 Shadowrocket 的“设置 → 其它”中把“包含路由 10.7.0.1/32”设为开启。

开启后，发往 `10.7.0.1` 的连接会进入 Shadowrocket 的隧道并回到本机，使 WrapPin 可以访问 iPhone 自己的开发者服务。不需要额外导入模块或修改配置文件。

## WrapPin 设置

1. 在 WrapPin 的“设置 → 隧道跳转应用”中选择 Shadowrocket。
2. 完成一次设备配对。
3. 开始模拟定位。若当前设备通道不可达，WrapPin 会请求 Shadowrocket 开启 VPN。
4. Shadowrocket 开启后手动返回 WrapPin；WrapPin 会继续检测连接。

若蜂窝网络下检测失败，请先用 Wi-Fi 验证。WrapPin 只能验证配对设备通道是否可达，无法读取 Shadowrocket 的 VPN 开关。
