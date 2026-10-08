# WrapPin 1.0.15（Build 48）

## 中文

本版只修正连接失败时的提示文字，功能与 1.0.14 相同。两个版本来自同一份源码和同一个版本号。

### 修复

- 有四条连接失败提示写死了 LocalDevVPN，使用 Shadowrocket 或隧道版内置隧道时也会出现。现在统一称为“设备隧道”，例如“WrapPin 无法通过设备隧道连接 iPhone”。

这四条提示来自原生定位引擎，因此两个 xcframework 切片已重建。失败阶段的判断和自动重试从 1.0.14 起按阶段码进行，不受文字改动影响。

### 下载与验证

- 标准版：`WrapPin-Standard-1.0.15-build48-unsigned.ipa`；Bundle ID `com.suversal.wrappin`；SHA-256 `58d30ab5801807708b9f0a04d59869cab684465212226b186966b32272a1b84d`
- 隧道版：`WrapPin-Tunnel-1.0.15-build48-unsigned.ipa`；Bundle ID `com.suversal.wrappin.selfsigned`，扩展 `com.suversal.wrappin.selfsigned.tunnel`；SHA-256 `eefaed0ff692454d610ff45b91780a5216d5c63a65001daa425eca5afb894522`
- 最低系统：iOS 27.0；架构：arm64；均为未签名包。
- 本地化、后台定位生命周期、失败阶段、坐标模式、路线恢复、隧道跳转、路线选择检查，原生引擎测试，Release Archive 以及 IPA 身份、版本、完整性和扩展有无检查均已通过。
- Build 48 没有在真机上安装过，这次的文字改动也没有单独做真机测试。其余功能代码与维护者真机测试过的 Build 46 相同。

### 已知边界

- 备选路线上的用时按所设模拟速度计算，不是实时路况时间。
- 异常退出后恢复路线时，会按 Apple 地图的推荐路线重新规划，不一定是之前选择的那条备选路线。
- 隧道版的签名要求、蜂窝网络下的引导流程、坐标模式和第三方 App 对模拟位置的接受情况与 1.0.14 相同。

## English

WrapPin 1.0.15 only corrects the wording of connection failure messages; it behaves like 1.0.14 otherwise. Both editions are built from one source tree and one version.

Four connection failure messages named LocalDevVPN even when Shadowrocket or the tunnel edition's built-in tunnel was in use. They now refer to the device tunnel. The messages come from the native location engine, so both xcframework slices were rebuilt. Failure classification and automatic retry have used stage codes since 1.0.14 and are unaffected by the wording.

The unsigned packages require iOS 27.0 or later. `WrapPin-Standard-1.0.15-build48-unsigned.ipa` has SHA-256 `58d30ab5801807708b9f0a04d59869cab684465212226b186966b32272a1b84d`; `WrapPin-Tunnel-1.0.15-build48-unsigned.ipa` has SHA-256 `eefaed0ff692454d610ff45b91780a5216d5c63a65001daa425eca5afb894522`. Build 48 has not been installed on a device and the wording change was not device-tested on its own; it passed the source checks, native engine tests and archive, identity, version and integrity checks. The rest of the feature code is the same as Build 46, which passed the maintainer's device test in both editions.
