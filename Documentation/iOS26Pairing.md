# iOS 18–26: first-time pairing with a computer

WrapPin has supported installation on iOS/iPadOS 18.0 and later since version 1.0.21. This guide covers first-time pairing on iOS/iPadOS 18–26 for both the Standard and Tunnel editions. Both use the same RPPairing file format. [Download the latest release](https://github.com/suversal/WrapPin/releases/latest)

On iOS 27 or later, keep using the six-digit WrapPin code in Settings → Privacy & Security → Developer Mode. On iOS 18–26, follow these steps once.

## Create the record

1. Download the author's [idevice_pair release](https://github.com/jkcoxson/idevice_pair/releases/latest) on Mac, Windows or Linux.
2. Connect the target iPhone by USB, unlock it and approve Trust when asked.
3. Select that iPhone in idevice_pair, choose **Remote pairing (RPPairing)**, then click Create. In v1.1.0, Validate and Save to file appear only after creation succeeds. Validate it, wait for Works, then save that same record; avoid clicking Create again after saving.
4. Transfer it to the same iPhone, for example with AirDrop, and save it in Files.

Choose Remote pairing. A classic Lockdown / SideStore `.mobiledevicepairing` record cannot be used directly; renaming it does not convert it. WrapPin checks contents rather than assuming a file extension identifies its pairing type.

## Import into WrapPin

1. Install the current release and open Device Setup. On iOS/iPadOS 18–26, it shows the computer-pairing instructions and **Import RPPairing File**.
2. Choose the saved file. Alternatively, copy its XML contents and explicitly tap Paste RPPairing from Clipboard; WrapPin never reads the clipboard automatically.
3. Confirm Pairing file ready. This means validation and Keychain storage succeeded, not that a real device connection has been verified.
4. Keep Developer Mode and Wi-Fi on. Tunnel asks to add its VPN configuration; Standard needs LocalDevVPN or another configured device tunnel.
5. Start a fixed location, confirm it in Apple Maps, then stop and confirm that the real location returns.

The editions store records separately, so import into each one. A valid RPPairing file for the same iPhone may be imported into both editions. An invalid replacement preserves the existing valid record. Stop any current location or pairing session before changing the record.

Records stay in the on-device Keychain and are not uploaded. Do not share the private file, XML contents or PIN in issues, chats or support email.

## Physical-device acceptance

Test Standard first: launch, import, tunnel connection, fixed location, routes, background continuity and restoration. Then test Tunnel and regress iOS 27 on-device pairing. Coverage should include iOS 18.x, 26.0–26.3 and 26.4 or later.

Connect again after reboot to check whether the device depends on temporary state prepared by another developer tool. If importing succeeds and the tunnel is reachable but the location service is unavailable, check that Developer Mode is on and that the Developer Disk Image (DDI) is ready.

See the [1.0.21 release notes](Release-1.0.21.md) for the initial report of Standard working on iOS 26.5. Physical-device test coverage on iOS 18.x is still limited.
