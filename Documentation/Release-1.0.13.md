# WrapPin 1.0.13（Build 41）

## 中文

本版开始同时提供两个版本，来自同一份源码和同一个版本号。

- **标准版**：供 SideStore 或其他自签方式安装，继续使用 LocalDevVPN／Shadowrocket 等外部设备隧道。功能与 1.0.12 相同，不含隧道代码和扩展。
- **隧道版**：内置 Packet Tunnel 设备隧道，不需要另装隧道 App。开始定位时自动连接，停止并恢复真实位置后自动断开；在设置里手动开启的隧道会保持连接，直到手动关闭。也可以在设置中切回外部隧道。

隧道版的主 App 和扩展都需要带 Packet Tunnel（Network Extension）权限的签名配置，免费 Apple 账号和 SideStore 无法签名。它只路由本机 `10.7.0.1` 的设备连接，不解密 HTTPS、不安装证书、不改变公网出口。两个版本的 App ID、桌面名称和回调地址各自独立，可以同时安装，设置和配对记录分别保存。

### 下载与验证

- 标准版：`WrapPin-Standard-1.0.13-build41-unsigned.ipa`；Bundle ID `com.suversal.wrappin`；SHA-256 `794ce2cc86f27eb1b9d21183db04cddf3ce3608e7393869bb79e9955e316fcbc`
- 隧道版：`WrapPin-Tunnel-1.0.13-build41-unsigned.ipa`；Bundle ID `com.suversal.wrappin.selfsigned`，扩展 `com.suversal.wrappin.selfsigned.tunnel`；SHA-256 `8d4c8f27c3e640d24f5db02b18a4dfc4ee54cb024a48ca982a8f04a912c4ee58`
- 最低系统：iOS 27.0；架构：arm64；均为未签名包。
- 本地化、后台定位生命周期、错误分类、Release Archive 以及 IPA 身份、版本、完整性和扩展有无检查均已通过。
- 同一功能代码的 Build 40 两个包已由维护者完成真机测试；Build 41 在更新版本号并重命名工程 target 后重新构建，只完成了包级校验。

### 已知边界

隧道版暂不显示更新提示，请关注 Releases 页面。iOS 同时只允许一个 VPN 生效，开启内置隧道可能断开其他 VPN。蜂窝网络下仍需按引导暂时关闭数据。坐标模式和第三方 App 对模拟位置的接受情况与 1.0.12 相同。

## English

WrapPin 1.0.13 ships two editions built from one source tree and one version.

The **standard edition** is for SideStore or other self-signing tools and keeps using an external device tunnel such as LocalDevVPN. It behaves like 1.0.12 and contains no tunnel code or extension. The **tunnel edition** embeds a Packet Tunnel extension that provides the paired-device connection itself: it connects when a location session starts and disconnects after the real location is restored, while a manually started tunnel stays on until stopped. Its app and extension both need signing profiles with Packet Tunnel permission, which free Apple accounts and SideStore cannot provide. It routes only the local `10.7.0.1` device connection. The editions have separate App IDs, names and callback schemes and can be installed side by side.

The unsigned packages require iOS 27.0 or later. `WrapPin-Standard-1.0.13-build41-unsigned.ipa` has SHA-256 `794ce2cc86f27eb1b9d21183db04cddf3ce3608e7393869bb79e9955e316fcbc`; `WrapPin-Tunnel-1.0.13-build41-unsigned.ipa` has SHA-256 `8d4c8f27c3e640d24f5db02b18a4dfc4ee54cb024a48ca982a8f04a912c4ee58`. The same feature code passed the maintainer's device test as Build 40. Build 41 was rebuilt after the version change and an Xcode target rename and passed archive, identity, version, integrity, localization and lifecycle checks only. The tunnel edition does not show update notices yet.
