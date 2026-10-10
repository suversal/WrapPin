# 安装与侧载

WrapPin 暂未通过 App Store 或 TestFlight 分发。正式版本以未签名 IPA 的形式发布，需要签名后安装。

[返回中文首页](../README.zh-CN.md) · [English](Installation.md)

## 选择版本

每个 GitHub Release 提供两个 IPA，功能相同，区别在于设备隧道的来源和签名要求。

| | 标准版 `WrapPin-Standard-…` | 隧道版 `WrapPin-Tunnel-…` |
| --- | --- | --- |
| 设备隧道 | 需要另装 LocalDevVPN 等外部隧道 | 内置，开始定位时自动连接 |
| 签名要求 | 免费 Apple 账号即可（SideStore） | 带 Packet Tunnel 权限的付费证书 |
| 续签 | 免费账号每七天刷新 | 取决于证书和描述文件的有效期 |

两个版本使用不同的 App ID，可以同时安装，但设置和配对记录各自保存。没有付费证书时请使用标准版。

## 准备工作

- 一台运行 iOS 27 或更高版本的实体 iPhone。
- 在“设置 → 隐私与安全性”中开启开发者模式。两个版本都需要：WrapPin 依赖的本机配对和定位模拟属于系统的开发者服务，与使用哪种证书签名无关。
- 标准版：在 iPhone 上安装 [LocalDevVPN](https://apps.apple.com/app/localdevvpn/id6755608044)。隧道版不需要。
- 标准版：准备 SideStore；也可以在 Mac 上使用 Xcode 和自己的开发者团队编译安装。
- 隧道版：准备带 Packet Tunnel 权限的付费签名配置，见下文“安装隧道版”。

## 使用 SideStore 安装标准版

1. 从本仓库对应的 GitHub Release 下载 IPA，不要使用来源不明的网盘或镜像。
2. 在 SideStore 中轻点 **+**，选择下载好的 IPA。
3. 让 SideStore 使用你的 Apple 账号完成签名和安装。
4. 打开 WrapPin，完成首次使用说明和本机配对。
5. 打开 LocalDevVPN 并连接本地隧道，然后再启动模拟定位。

免费 Apple 账号通常需要在七天内刷新侧载 App，并受同时启用的 App 和 App ID 数量限制。这是 Apple 的签名限制，不是 WrapPin 的订阅规则。

更新时可以直接覆盖安装新版 IPA。不要先删除旧版，否则本地设置会一并删除，并可能需要重新配对。

## 安装隧道版

隧道版的主 App 和内嵌的 `WrapPinTunnel.appex` 扩展都要签名，并且两者的描述文件都必须实际授予 `com.apple.developer.networking.networkextension` 中的 `packet-tunnel-provider`。免费 Apple 账号无法取得这项权限，SideStore 的免费签名也不能用于隧道版。

### 使用付费证书和签名工具

适合没有 Mac 的情况，全程在 iPhone 上完成。

1. 取得一份绑定了本机 UDID 的付费证书和描述文件。可以来自你自己的 Apple Developer 账号，也可以来自第三方证书服务。
2. 在 iPhone 上安装支持导入证书的 IPA 签名工具，并导入证书和描述文件。
3. 从本仓库对应的 GitHub Release 下载 `WrapPin-Tunnel-…-unsigned.ipa`，导入签名工具。
4. 签名并安装。
5. 打开 WrapPin Tunnel，首次启动隧道时允许添加 VPN 配置，然后完成本机配对。

注意事项：

- 取得证书前先确认它支持 VPN / Network Extension 类 App。只支持普通 IPA 的证书签出来可以安装，但内置隧道无法启动。
- 签名工具必须同时重签内嵌扩展。可以修改 Bundle ID，但扩展的 Bundle ID 必须是主 App 的 Bundle ID 加 `.tunnel`，否则 App 找不到扩展。
- 第三方证书属于他人的开发者账号：设备绑定后通常不能更换或退款，证书也可能被吊销。本项目不提供、不推荐也不担保任何证书服务。
- 不要把证书私钥、p12 密码、描述文件或 UDID 发到 Issue 或公开渠道。

### 使用 Xcode 和付费开发者账号

1. 克隆本仓库，把 `Configuration/Local.private.xcconfig.example` 复制为 `Configuration/Local.private.xcconfig`。
2. 填入自己的团队和 App ID，示例文件里用不到的行可以删掉；扩展会自动使用该 ID 加 `.tunnel`：

   ```
   DEVELOPMENT_TEAM = 你的 Team ID
   WRAPPIN_TUNNEL_BUNDLE_IDENTIFIER = com.example.wrappin.selfsigned
   ```

3. 使用 Xcode 27 或更高版本打开 `WrapPin.xcodeproj`，选择 **WrapPin Tunnel** scheme。
4. 连接 iPhone，选择该设备并运行。工程使用自动签名，Xcode 会注册设备、创建两个 App ID 并生成带 Network Extensions 能力的描述文件。

如果想用自己的账号重签发布的 IPA 而不编译源码，需要在开发者后台为主 App 和扩展各建一个开启 Network Extensions 的显式 App ID 和描述文件，先签扩展、再签主 App。签名要求和签名后的验收步骤见[内置隧道版说明](BuiltInTunnelResearch.zh-CN.md)。

更新隧道版时同样直接覆盖安装，并使用与上次相同的证书和 Bundle ID。

## 使用 Xcode 安装标准版

1. 克隆本仓库，使用 Xcode 27 或更高版本打开 `WrapPin.xcodeproj`。
2. 选择 **WrapPin Standard** scheme，在 `WrapPinStandard` target 的 **Signing & Capabilities** 中选择你自己的开发者团队。
3. 连接 iPhone，选择该设备并运行项目。

仓库不会保存 Apple 开发者团队、签名文件或线上统计目标。Xcode 可能在本机记录你选择的团队，请勿提交签名材料或 `Configuration/Local.private.xcconfig`。

模拟器只能检查界面，不能完成实体 iPhone 配对，也不能真正启动模拟定位。

## 校验下载文件

GitHub Release 会提供 IPA 的 SHA-256。下载后可在 Mac 终端运行：

```sh
shasum -a 256 下载的文件名.ipa
```

输出应与对应 Release 页面列出的 SHA-256 完全一致。校验通过只代表文件与发布者上传的版本一致，仍应确认下载来源是本仓库。

安装完成后请继续阅读[使用手册](UserGuide.zh-CN.md)。
