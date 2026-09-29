# WrapPin 内置隧道测试版（1.0.12 Build 33）

## 对照方案

这里的 Wloc 指 2026 年 9 月发布的开发者定位模拟标准版／隧道版，并非旧 WLOC 的 HTTPS 解密方案。发行说明称：标准版使用 LocalDevVPN 等外部隧道；隧道版附带本机 VPN，首次需允许 VPN 配置，之后开始模拟时自动开启、正常恢复后自动关闭；手动开启的隧道保持运行。发行说明还称免费账号无法签署隧道版。该说明来自第三方转发，未取得项目公开源码核对。

发行说明：https://t.me/s/iosjumo?before=6033

## 本分支实现

WrapPin 沿用 RPPairing → 本机设备发现 → 加密开发者会话 → LocationSimulation。新增 `WrapPinTunnel` Packet Tunnel 扩展，把 `10.7.0.1/32` 设备通道提供给现有会话。设置页选择“使用内置隧道”后，定位开始时自动连接，正常停止并完成清除命令后自动断开；手动开启的隧道保持连接，直到手动关闭。蜂窝网络沿用暂时关闭数据的连接引导。内置模式不显示 LocalDevVPN 的应用跳转选项。

本实现不解密 HTTPS、不安装 CA、不改变公网出口。原有 LocalDevVPN／Shadowrocket 路径保留。本测试分支首次安装默认选择内置模式，也可在设置中切回外部隧道；当前只有无签名编译和包结构验证，没有签名安装或真机定位结果。若清除模拟位置失败，隧道会保持连接，便于重试恢复。

## 明天购买或使用签名之前

请先确认签名服务确实支持 **Packet Tunnel Network Extension**，而不是只提供普通 IPA 签名。主 App 与扩展必须使用同一 Team，并分别获得匹配各自 Bundle ID 的 provisioning profile；两份配置需要实际授予 `com.apple.developer.networking.networkextension` 的 `packet-tunnel-provider`。普通证书、p12 文件或仅在项目里写 entitlement，不能代替 profile 授权。不要提交证书私钥、p12、mobileprovision 或 UDID。

默认 ID 是 `com.suversal.wrappin` 和 `com.suversal.wrappin.tunnel`。如果签名服务要求自己的 ID，需同时改主 App 和扩展，扩展仍须为主 App ID 加 `.tunnel`。用 Xcode 构建时，可在 `Configuration/Local.private.xcconfig` 设置 `DEVELOPMENT_TEAM` 和 `WRAPPIN_BUNDLE_IDENTIFIER` 后重新归档。对现成 IPA 重签时，签名工具也必须正确重签并保留内嵌 `.appex`、它的 Bundle ID 和权限。

Apple 权限文档：https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.networking.networkextension

## 签名后验收

1. 安装前检查签名后的主 App 与 `.appex` 均可通过 `codesign --verify`，两者的实际 entitlement 和内嵌 profile 均含 Packet Tunnel 权限。
2. 安装到 iOS 27 真机，确认可以允许 WrapPin 添加 VPN 配置；在设置中手动启动，系统 VPN 状态应变为已连接，诊断页的“内置 VPN”也应显示已连接。
3. 先在 Wi-Fi 下完成本机配对。选择“使用内置隧道”，设置固定位置，检查自动启动、设备发现、Apple 地图位置；停止并确认真实位置恢复后，检查 VPN 自动断开。
4. 测试步行、驾车、换点、暂停与恢复。再次手动开启 VPN，运行并结束定位，确认此时 VPN 保持连接，直到在设置页手动关闭。
5. 蜂窝网络下测试关闭数据引导、连接成功后重新开启数据、前后台切换、断线重试与停止恢复。测试其他 VPN 已连接、拒绝 VPN 授权和 App 意外退出后的恢复。
6. 每次异常先复制“连接诊断”，记录 iPhone 机型、iOS 版本、签名后的 App/扩展 Bundle ID、实际 VPN 状态与结果；不要发送配对文件、签名私钥或私人位置。

只有签名安装、VPN 启动、定位、停止恢复全通过，才能称为可用的隧道版；无签名 IPA 不能直接安装。

## 本地交付包

- 文件：`Releases/WrapPin-Tunnel-1.0.12-build33-unsigned.ipa`
- SHA-256：`13c681892e61d434b4e973b2a3489cb4e4471063adadb732ed91ecf82858382d`
- 来源：无签名 Release Archive；IPA 结构为 `Payload/WrapPin.app`，内含 `PlugIns/WrapPinTunnel.appex`。App 与扩展均为 arm64，版本 1.0.12 Build 33。
- 本包仅供使用具备 Network Extension 权限的签名配置重签测试；它本身不可直接安装，也不是已通过真机验收的公开版本。
