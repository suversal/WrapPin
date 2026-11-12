# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概览

WrapPin 是 iOS 18+ 的 SwiftUI App（iPhone 与 iPad；iPad 真机定位待验收；iOS 18–26 通过电脑生成 RPPairing，iOS 27 保留本机配对），通过 iOS **开发者位置模拟服务**（LocationSimulation）设置固定坐标或沿路线移动。它是 Roam Control 的非官方中文社区分支，许可证为 PolyForm Noncommercial 1.0.0，必须保留上游署名与第三方许可证文件。

没有 SPM/CocoaPods 依赖，没有 XCTest target。唯一的原生依赖是仓库内预编译的 `Frameworks/WrapPinPairingFFI.xcframework`（Rust 静态库）。

## 常用命令

构建（需要 Xcode 27+；模拟器只支持 arm64）：

```sh
# 标准版（SideStore 版，无隧道代码）
xcodebuild -project WrapPin.xcodeproj -scheme "WrapPin Standard" -configuration Debug \
  -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO build

# 隧道版（内嵌 WrapPinTunnel.appex）
xcodebuild -project WrapPin.xcodeproj -scheme "WrapPin Tunnel" -configuration Release \
  -destination "generic/platform=iOS" CODE_SIGNING_ALLOWED=NO build
```

PR 要求 Debug 与 Release 都能编译；改动共享代码时两个 scheme 都要构建，因为 `#if WRAPPIN_TUNNEL_EDITION` 分支只在隧道版里编译。

检查脚本（代替单元测试，全部离线、在 macOS 上运行，逐个执行即可）：

```sh
python3 scripts/check-localization.py      # 所有字面量 UI 文案都有 zh-Hans 翻译且无重复 key
python3 scripts/test-failure-stages.py     # Rust 阶段码 ↔ 头文件 ↔ FailureStage 一致，配对错误文案分类覆盖
python3 scripts/test-background-session.py # 后台保活生命周期（用假平台类型编译生产代码）
python3 scripts/test-location-continuity.py # 生产协调器重连取消、耗尽和路线连续性
xcrun swiftc -parse-as-library scripts/test-location-reconnect-policy.swift \
  WrapPin/Services/LocationSessionReconnectPolicy.swift WrapPin/Services/FailureStage.swift \
  -o /tmp/reconnect-check && /tmp/reconnect-check

# 八个 Swift 检查需要与对应的生产源文件一起编译：
xcrun swiftc -parse-as-library scripts/check-fixed-coordinate-mode.swift \
  WrapPin/Services/FixedCoordinateMode.swift WrapPin/Models/LocationTarget.swift \
  WrapPin/Models/SessionRecoveryRecord.swift WrapPin/Models/CoordinateModeMemory.swift \
  -o /tmp/check && /tmp/check
xcrun swiftc -parse-as-library scripts/test-route-recovery.swift \
  WrapPin/Models/SessionRecoveryRecord.swift -o /tmp/check && /tmp/check
xcrun swiftc -parse-as-library scripts/test-session-recovery-policy.swift \
  WrapPin/Services/FailureStage.swift WrapPin/Services/SessionRecoveryPolicy.swift \
  WrapPin/Models/SessionRecoveryRecord.swift -o /tmp/check && /tmp/check
xcrun swiftc -parse-as-library scripts/test-tunnel-handoff.swift \
  WrapPin/Models/AppPreferences.swift WrapPin/App/BuildEdition.swift -o /tmp/check && /tmp/check
xcrun swiftc -parse-as-library scripts/test-route-selection.swift \
  WrapPin/Features/Map/RouteHitTesting.swift -o /tmp/check && /tmp/check
xcrun swiftc -parse-as-library scripts/test-coordinate-input.swift \
  WrapPin/Features/Map/CoordinateInputParser.swift -o /tmp/check && /tmp/check
xcrun swiftc -parse-as-library scripts/test-overseas-search.swift \
  WrapPin/Services/OverseasPlaceSearch.swift -o /tmp/check && /tmp/check
xcrun swiftc -parse-as-library scripts/test-pairing-import.swift \
  WrapPin/Services/Pairing/PairingService.swift WrapPin/Services/Pairing/DevicePairingSupport.swift \
  -o /tmp/check && /tmp/check
```

打包与原生引擎：

```sh
scripts/package-ipa.sh [standard|tunnel|all]  # Release archive → Releases/ 下的未签名 IPA，打印 SHA-256
scripts/build-pairing-engine.sh               # 仅在改动 Native/WrapPinPairingFFI 后重建 xcframework
```

- `package-ipa.sh` 拒绝覆盖已有 build 号的 IPA：先在 `Configuration/Version.xcconfig` 递增 `CURRENT_PROJECT_VERSION`。IPA 必须用 `ditto` 打包（SideStore 对 ZIP 布局敏感）。
- `build-pairing-engine.sh` 需要 Rust target `aarch64-apple-ios` 和 `aarch64-apple-ios-sim`，且输出目录已存在时会中止——先把旧的 xcframework 移开。

Debug 构建的启动参数：`--skip-onboarding`、`--show-device-setup`、`--show-settings`（用于在模拟器中直接进入某个界面）。`--preview-computer-pairing` 仅在 Debug 中预览 iOS 18–26 的电脑配对说明，不模拟握手。

真实的配对与定位会话只能在实体设备上验证；模拟器路径通过 `#if targetEnvironment(simulator)` 被桩掉。真机回归项见 `Documentation/RegressionChecklist.md`。

## 架构

### 两个版本，一套源码

| Scheme | Target | Bundle ID | 回调 scheme | 说明 |
| --- | --- | --- | --- | --- |
| WrapPin Standard | `WrapPinStandard` | `com.suversal.wrappin` | `wrappin://` | 依赖 LocalDevVPN / Shadowrocket 等外部隧道 |
| WrapPin Tunnel | `WrapPinTunnelEdition` + `WrapPinTunnel`（appex） | `…wrappin.selfsigned`（扩展加 `.tunnel`） | `wrappintunnel://` | 内置 Packet Tunnel，需要付费账号的签名配置 |

- 两个 App target 都用 Xcode 的文件系统同步组指向同一个 `WrapPin/` 目录，新增文件会自动进入两个 target。因此**隧道专属代码必须整体包在 `#if WRAPPIN_TUNNEL_EDITION` 里**（参考 `BuiltInTunnelManager.swift`、`BuiltInTunnelSettingsView.swift`），标准版不得链接 NetworkExtension，也不得包含 `PlugIns/`（打包脚本会校验）。
- 版本差异的运行时入口是 `WrapPin/App/BuildEdition.swift`。
- `WrapPinTunnel/PacketTunnelProvider.swift` 不是通用 VPN：只路由 `10.7.0.1` 这一个对端，并把 IPv4 包的源/目的地址互换后写回，使 App 能访问本机的远程配对服务。

### 配置层（xcconfig）

`Configuration/Local.xcconfig`（已提交，公开安全默认值）→ `#include "Version.xcconfig"` → `#include? "Local.private.xcconfig"`（被 gitignore，用于个人签名团队、Bundle ID、TelemetryDeck ID）。

- 版本、build 号、构建时间戳**只在 `Version.xcconfig` 设置**，三个 target 共读；不要在 target 的 build settings 里再写一份，扩展必须与宿主 App 一致。
- 不要把 `DEVELOPMENT_TEAM`、遥测 ID 或 `Local.private.xcconfig` 提交进仓库。

### 运行时分层

```
SwiftUI Views (Features/*)
   └─ AppModel (@MainActor @Observable，通过 .environment 注入)
        ├─ SecurePairingService (actor)      钥匙串中的 RPPairing 记录
        ├─ OnDevicePairingCoordinator        本机配对：Bonjour 发布 + PIN 回调
        ├─ LocalDeviceSessionCoordinator     定位会话状态机（最大、最核心的文件）
        │     ├─ BackgroundLocationKeepAlive 用 Core Location 保持后台存活
        │     └─ BuiltInTunnelManager        仅隧道版
        └─ UsageAnalyticsService             可选匿名统计
                 │
                 ▼  C ABI (wrappin_pairing.h)
        Rust: Native/WrapPinPairingFFI/src/lib.rs → idevice crate（固定 git rev）
```

- `AppModel` 是唯一的应用状态源：UserDefaults 偏好、收藏/历史、`ConnectionState`/`PairingStatus`，并持有各协调器。`ReleaseUpdateModel` 是第二个环境对象，启动时向 GitHub 查询最新 Release。
- `LocalDeviceSessionCoordinator` 负责：发现设备端点（Bonjour 发现，失败回退到 LocalDevVPN 默认地址 `10.7.0.1`）→ 校验配对记录与广播身份 → 调用 `wp_location_session_run`（阻塞，直到会话结束）→ 会话中用 `wp_location_session_update` 换坐标而不重建连接。蜂窝网络下有单独的“临时关闭移动数据”引导流程（`MobileDataGuidance`、`TunnelHandoffPolicy`）。
- FFI 模式：Swift 创建不透明 session 指针，在后台线程运行阻塞的 `*_run`，通过 C 回调（`context` 指针）回到 Swift，结果结构体由对应的 `*_destroy` 释放。修改 Rust 侧签名时要同步 `Native/…/include/wrappin_pairing.h`，并重建 xcframework 的两个切片后提交。
- 停止会话必须走“清除模拟坐标并恢复真实位置”的路径。`SessionRecoveryRecord` 在会话进行时持久化到 UserDefaults；App 异常退出后，下次启动显示 `SessionRecoveryView`，由用户选择继续或恢复，**不会自动开始任何操作**。

### 路线与坐标

- `Features/Map/` 下的 `WalkingRoutePlanner` / `WalkingSimulationController` 同时承担步行和驾车（`RouteMode`），名称里的 “Walking” 是历史遗留。
- 海外搜索（`OverseasPlaceSearch`）：国内 Apple 地图数据缺少海外地点，搜索框切到“海外”后改用 Geoapify（OSM 数据，WGS-84）。只在提交时请求，不做实时补全；查询开头的中文国名转成 `countrycode` 过滤，带门牌号的查询里非 building 结果一律标为大致位置，改动请求或标注规则时递增 `OverseasSearchCache.version`；每台设备每天 50 次、结果缓存 7 天；未配置 `WRAPPIN_GEOAPIFY_API_KEY` 时整个切换隐藏。在中国大陆不开代理可能连不上 Geoapify（2026-10-28 用户实测），连接失败的提示会引导开代理或粘贴坐标；Key 会随 IPA 分发，所有安装共享免费额度，结果必须显示 Geoapify 与 OpenStreetMap 署名。
- `FixedCoordinateMode`（`gcj02` / `wgs84`）由用户选择；`FixedCoordinateTransform` 对所选点做 GCJ-02 的迭代求逆。该模式同时作用于固定位置、路线的起点/途中更新/终点以及恢复记录。`recommended(for:)` 只是初始建议，不限制转换范围。

## 必须保持的跨文件约定

- **本地化**：源码中的 UI 文案是英文字面量 key，`WrapPin/Resources/zh-Hans.lproj/Localizable.strings` 提供中文。新增任何 `Text("…")`、`String(localized:)`、`.navigationTitle` 等字面量，以及 Rust 中任何用户可见错误文案（`"…".to_string()` 或 `LocationError::new/recoverable(阶段, "…")`），都要补 zh-Hans 条目，否则 `check-localization.py` 失败。
- **原生错误分类**：定位会话的错误由 Rust 以 `LocationError { stage, recoverable, message }` 返回，阶段码经 `WPLocationResult.error_stage` 传给 Swift，再由 `FailureStage(nativeLocationStage:)` 映射；文案只用于展示和本地化，改写文案不影响分类。新增阶段时要同时改三处且不得重新编号：`lib.rs` 的 `LocationStage`、头文件的 `WPLocationStage*`、Swift 的映射，否则 `test-failure-stages.py` 失败。Swift 侧自己产生的会话失败在 `fail(_:stage:)` 里直接给出阶段。配对流程仍按英文原文走 `FailureStage.classify`，必须在本地化之前调用（未知文案落入 fallback，不得泄露原文）。
- **持久化兼容**：`SessionRecoveryRecord` 的 JSON 必须能解码旧版本写入的记录（缺少 `fixedCoordinateMode`、旧的步行字段等），两个 Swift 检查脚本覆盖了这一点。
- **不再使用 `BGTaskScheduler`** 启动配对或定位会话（SideStore 重签会改变 Bundle ID 导致失败）；`test-failure-stages.py` 断言协调器里不存在 `submitTaskRequest`。
- **隐私**：统计默认关闭，只允许 `UsageAnalyticsEvent` 中的固定事件集，未配置两个遥测 ID 时客户端不发送任何内容。绝不能把坐标、地点文本、搜索、路线、配对材料、设备名或诊断原文放进事件。改动事件结构时同步 `Documentation/Privacy.md` 和 `PrivacyInfo.xcprivacy`。
- **用途边界**（来自 CONTRIBUTING）：不接受用于绕过访问控制、规避风控、冒充他人或滥用第三方服务的功能；项目范围是用户自有设备上的开发与测试。

## 发布流程要点

- 版本号标识公开发布；build 号标识一次确切的安装包，每次装到测试机或打 IPA 都要递增，普通编译检查不消耗 build 号，且永不回退。
- 两个版本从同一个 commit 打包，挂在同一个 GitHub Release 下。每个分发的 build 在 `Releases/README.md` 记录（SHA-256、Xcode 版本、验证范围、已知问题），并新增 `Documentation/Release-<版本>.md`、更新 `CHANGELOG.md`；README 顶部的版本号也要同步。
- 流程或设置有变化时同步更新中英文文档（`Documentation/*.md` 与 `*.zh-CN.md` 成对存在）。
- 完整步骤见 `Documentation/BuildAndRelease.md`；隧道版签名与真机测试顺序见 `Documentation/BuiltInTunnelResearch.zh-CN.md`。
