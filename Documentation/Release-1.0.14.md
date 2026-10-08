# WrapPin 1.0.14（Build 47）

## 中文

两个版本来自同一份源码和同一个版本号，改动相同。

### 新增

- **备选路线**：预览步行或驾车时，Apple 地图给出多条路线的话，最多显示三条。可以在预览卡片上选择，也可以直接轻点地图上的路线；距离、预计用时和到达时间随所选路线更新。开始后地图上只保留所选路线。

### 改进

- 在“连接中”点停止会立即生效，不再等待剩余的连接步骤，也不会先短暂写入所选位置再清除。
- 隧道版现在和标准版一样，启动时检查最新的 GitHub Release 并显示更新提示。

### 修复

- 系统语言为简体中文时，“连接健康”里的失败阶段曾显示为未知；有两条设备发现失败在任何语言下都无法归类。定位引擎现在直接返回阶段码，分类不再依赖提示文字或语言。
- 停止并恢复后，“当前位置”按钮可能把地图居中到上一个模拟位置。地图现在会忽略被 iOS 标记为模拟的定位结果，等待真实结果。
- 已选择 Shadowrocket 时，“设备连接”、引导页和使用指南仍显示 LocalDevVPN。现在显示所选的隧道应用；“设备连接”和“连接健康”里的按钮在该应用已安装时直接打开它，未安装时打开 App Store 页面。
- “设备连接”里的配对步骤、“连接前的准备”和指纹标签在中文环境下曾显示英文。
- iPhone 未确认停止时的提示现在按 App 语言显示。

### 下载与验证

- 标准版：`WrapPin-Standard-1.0.14-build47-unsigned.ipa`；Bundle ID `com.suversal.wrappin`；SHA-256 `5b538b6d8c900664bb26421354ea966fe8305779009e13448afc272f703c62f9`
- 隧道版：`WrapPin-Tunnel-1.0.14-build47-unsigned.ipa`；Bundle ID `com.suversal.wrappin.selfsigned`，扩展 `com.suversal.wrappin.selfsigned.tunnel`；SHA-256 `77eada290adc810fed300df26f6b54a1916ca88fadce0b0d49bc9a5f1408a531`
- 最低系统：iOS 27.0；架构：arm64；均为未签名包。
- 本地化、后台定位生命周期、失败阶段、坐标模式、路线恢复、隧道跳转、路线选择检查，原生引擎测试，Release Archive 以及 IPA 身份、版本、完整性和扩展有无检查均已通过。
- 同一功能代码的 Build 46 两个包已由维护者完成真机测试；Build 47 在更新版本号后重新构建，只完成了包级校验。

### 已知边界

- 备选路线上的用时按所设模拟速度计算，不是实时路况时间。
- 异常退出后恢复路线时，会从最后位置按 Apple 地图的推荐路线重新规划，不一定是之前选择的那条备选路线。
- 连接失败的个别提示仍会出现 LocalDevVPN 字样，即使使用的是 Shadowrocket 或内置隧道。
- 停止后如果 iOS 暂时拿不到真实定位，“当前位置”按钮会等待而不会跳转，目前没有单独提示。
- 隧道版的签名要求、蜂窝网络下的引导流程、坐标模式和第三方 App 对模拟位置的接受情况与 1.0.13 相同。

## English

WrapPin 1.0.14 ships the same changes in both editions, built from one source tree and one version.

**Added.** Walking and driving previews offer up to three routes when Apple Maps suggests alternatives. Choose one on the preview card or tap it on the map; distance, travel time and arrival time follow the chosen route, and only that route stays on the map after starting.

**Improved.** Stopping while a session is still connecting takes effect at once, without waiting for the remaining connection steps or briefly applying the selected location. The tunnel edition now checks the latest GitHub Release and shows update notices.

**Fixed.** Failure stages in Connection Health were reported as unknown in Simplified Chinese, and two device-discovery failures were unclassified in every language; the location engine now reports a stage code. After Stop & Restore the current-location button could centre on the last simulated place; fixes that iOS marks as simulated are now ignored. Device Setup, the introduction and the guide now name the selected tunnel app instead of always naming LocalDevVPN, and the tunnel-app button in Device Setup and Connection Health opens the app when it is installed. Device Setup no longer shows its pairing steps, requirement list and fingerprint labels in English when the app runs in Chinese.

The unsigned packages require iOS 27.0 or later. `WrapPin-Standard-1.0.14-build47-unsigned.ipa` has SHA-256 `5b538b6d8c900664bb26421354ea966fe8305779009e13448afc272f703c62f9`; `WrapPin-Tunnel-1.0.14-build47-unsigned.ipa` has SHA-256 `77eada290adc810fed300df26f6b54a1916ca88fadce0b0d49bc9a5f1408a531`. The same feature code passed the maintainer's device test as Build 46 in both editions. Build 47 was rebuilt after the version change and passed the source checks, native engine tests and archive, identity, version and integrity checks only.

Known limits: times on route options use the simulated speed, not live traffic; resuming an interrupted route replans with the suggested route rather than a previously chosen alternative; a few connection failure messages still name LocalDevVPN when another tunnel is in use.
