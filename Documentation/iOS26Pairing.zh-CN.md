# iOS 18–26：通过电脑完成首次配对

WrapPin 从 1.0.21 起支持安装在 iOS/iPadOS 18.0 及以上。这份指南适用于标准版和隧道版在 iOS/iPadOS 18–26 上的首次配对。两版使用同一种 RPPairing 文件格式。[下载最新正式版](https://github.com/suversal/WrapPin/releases/latest)

iOS 27 或更高版本继续在“设置 → 隐私与安全性 → 开发者模式”中输入 WrapPin 的六位配对码。iOS 18–26 的首次配对按下面操作。

## 生成文件

1. 在 Mac、Windows 或 Linux 电脑上下载作者发布的 [idevice_pair](https://github.com/jkcoxson/idevice_pair/releases/latest)。
2. 用数据线连接要使用 WrapPin 的 iPhone，解锁，按提示轻点“信任”。
3. 在 idevice_pair 中选择这台 iPhone，选择 **Remote pairing（RPPairing）**，点 Create 生成文件。v1.1.0 会在生成成功后才显示 Validate 和 Save to file；先点 Validate，显示 Works 后再保存这份文件。保存后先不要再次点 Create。
4. 通过隔空投送等方式把文件传到同一台 iPhone，保存到“文件”App。

请选择 Remote pairing。普通 Lockdown / SideStore `.mobiledevicepairing` 文件不能直接使用；改文件名也不会改变配对类型。WrapPin 校验实际内容，不以文件扩展名判断记录是否有效。

## 导入 WrapPin

1. 安装 WrapPin 正式版，打开“设备连接”。iOS/iPadOS 18–26 会显示电脑配对说明和“导入 RPPairing 文件”。
2. 轻点“导入 RPPairing 文件”，选择刚生成的文件。也可复制文件的 XML 内容，主动轻点“从剪贴板粘贴 RPPairing”；App 不会自动读取剪贴板。
3. 确认显示“配对文件已就绪”。这表示文件通过校验并保存在钥匙串，还需要用下面步骤验证真实连接。
4. 保持开发者模式开启，打开 Wi-Fi。隧道版按提示允许添加 VPN 配置；标准版连接 LocalDevVPN 等已配置的设备隧道。
5. 设置一个固定位置，在苹果地图确认效果；然后停止并确认恢复真实位置。

两个版本各自保存配对记录；切换版本后需要分别导入。同一台 iPhone 的有效 RPPairing 文件可以分别导入两个版本。替换文件失败会保留原来有效的记录；进行中的定位或配对会话需要先停止。

配对文件只保存在本机钥匙串，不会上传。不要把包含私钥的文件、XML 内容或六位码发到 Issue、群聊或支持邮件。

## 真机验收

首轮先测标准版的启动、文件导入、隧道、固定定位、路线、后台运行和恢复真实位置；随后测试隧道版，并回归 iOS 27 本机配对。兼容性验收应分别覆盖 iOS 18.x、26.0–26.3 和 26.4 以后的系统。

重启设备后再次连接，检查设备是否依赖其他开发工具准备的临时状态。已导入配对、隧道连通但定位服务仍不可用时，请确认开发者模式已开启，并检查开发者镜像（DDI）是否就绪。

标准版在 iOS 26.5 上的早期成功反馈见 [1.0.21 构建说明](Release-1.0.21.zh-CN.md)。iOS 18.x 真机测试覆盖仍有限。
