# WrapPin 1.0.16（Build 52）

## 中文

本版在“隧道跳转应用”中加入 Surge 和 Loon，并统一了 Shadowrocket 的启动方式和说明。标准版始终提供这个选项，隧道版在未启用内置隧道时提供。两个版本来自同一份源码和同一个版本号。

### 新增

- 可选择 Surge 作为隧道跳转应用。配对设备通道不可用时，WrapPin 通过 `surge:///start` 请求 Surge 启动当前配置。需要 Surge iOS 5.23.0 或更高版本，配置见 [Surge iOS 配置](SurgeIntegration.zh-CN.md)。
- 可选择 Loon 作为隧道跳转应用。配对设备通道不可用时，WrapPin 通过 `loon://on` 请求 Loon 开启 VPN。需要 Loon Build 1007 或更高版本，配置见 [Loon 配置](LoonIntegration.zh-CN.md)。
- 仓库提供可导入的 `WrapPin-Surge.sgmodule` 和 `WrapPin-Loon.lpx`。

### 改进

- Shadowrocket 由“只打开应用”改为通过 `shadowrocket://connect` 请求开启 VPN，与 Surge、Loon 一致。它需要在“设置 → 其它”中开启“包含路由 10.7.0.1/32”，见 [Shadowrocket 配置](ShadowrocketIntegration.zh-CN.md)。
- 蜂窝网络下改用 Wi-Fi 的引导和连接检测提示，现在对 Shadowrocket、Surge、Loon 都适用。
- 设置页里三个应用的说明改为同一结构。

### 下载与验证

- 标准版：`WrapPin-Standard-1.0.16-build52-unsigned.ipa`；Bundle ID `com.suversal.wrappin`；SHA-256 `653efba12ee92a6a8b6749957850c7ee2f30fe89b6f5276dadd52c680a98ca5e`
- 隧道版：`WrapPin-Tunnel-1.0.16-build52-unsigned.ipa`；Bundle ID `com.suversal.wrappin.selfsigned`，扩展 `com.suversal.wrappin.selfsigned.tunnel`；SHA-256 `1e045e154fc268357fdd5e408c93b1b6b7eefd56529325782b2ef65d00d9d657`
- 最低系统：iOS 27.0；架构：arm64；均为未签名包。
- 本地化、后台定位生命周期、失败阶段、坐标模式、路线恢复、隧道跳转、路线选择检查，Release Archive 以及 IPA 身份、版本、完整性和扩展有无检查均已通过。原生引擎没有改动，未重跑原生引擎测试。
- 维护者把两个版本的 Build 52 装到实体 iPhone，确认了向 Shadowrocket、Surge、Loon 的跳转。贡献者此前在 Build 49 上通过 Surge 5.102.0 和 LocalDevVPN 完成过定位模拟。
- Build 49 至 51 是本地测试包，没有公开发布。

### 已知边界

- 三个外部应用启动后不会自动返回 WrapPin，需要手动切回。
- WrapPin 无法读取其他应用的 VPN 开关，只能检测配对设备通道是否可达。
- 三个应用在蜂窝网络下的表现本轮没有逐项验证；连接失败时请改用 Wi-Fi。
- Surge 5.22.x 及更早版本不支持 IP Rewrite 的 `reflect`，无法提供设备通道。

### 致谢

Surge 支持由 [@svcvit](https://github.com/svcvit) 在 [#27](https://github.com/suversal/WrapPin/pull/27) 中贡献。

## English

WrapPin 1.0.16 adds Surge and Loon as tunnel handoff apps and brings Shadowrocket in line with them. The Standard edition always offers this choice; the Tunnel edition offers it when its built-in tunnel is not in use. Both editions are built from one source tree and one version.

When the paired-device channel is unavailable, WrapPin asks Surge to start its selected configuration through `surge:///start`, asks Loon to turn on its VPN through `loon://on`, and now asks Shadowrocket to connect through `shadowrocket://connect` instead of only opening it. Surge needs iOS 5.23.0 or later and Loon needs build 1007 or later, each with a route and an IP Rewrite `reflect` rule for `10.7.0.1`; Shadowrocket needs **Include Route 10.7.0.1/32** turned on in its Settings. See the [Surge](SurgeIntegration.md), [Loon](LoonIntegration.md) and [Shadowrocket](ShadowrocketIntegration.md) setup guides. The Wi-Fi guidance on mobile data and the connection-check messages now apply to all three apps.

The unsigned packages require iOS 27.0 or later. `WrapPin-Standard-1.0.16-build52-unsigned.ipa` has SHA-256 `653efba12ee92a6a8b6749957850c7ee2f30fe89b6f5276dadd52c680a98ca5e`; `WrapPin-Tunnel-1.0.16-build52-unsigned.ipa` has SHA-256 `1e045e154fc268357fdd5e408c93b1b6b7eefd56529325782b2ef65d00d9d657`. They passed the source checks and archive, identity, version and integrity checks; native engine tests were not rerun because the engine is unchanged. The maintainer installed Build 52 of both editions on a physical iPhone and confirmed the handoff to Shadowrocket, Surge and Loon. The three apps do not return to WrapPin on their own, and their mobile-data behavior was not itemised in this round. Builds 49 to 51 were local test builds and were not published.

Surge support was contributed by [@svcvit](https://github.com/svcvit) in [#27](https://github.com/suversal/WrapPin/pull/27).
