# iOS 26: first-time pairing with a computer

This guide targets the iOS 26 series starting at 26.0. Standard and Tunnel use the same RPPairing record format. 1.0.21 Build 69 is a local compatibility candidate with initial Standard success reported on iOS 26.5; the remaining regression is pending, and the public 1.0.20 Build 66 still requires iOS 27.

On iOS 27 or later, keep using the six-digit WrapPin code in Settings → Privacy & Security → Developer Mode. On iOS 26, follow these steps once.

## Create the record

1. Download the author's [idevice_pair release](https://github.com/jkcoxson/idevice_pair/releases/latest) on Mac, Windows or Linux.
2. Connect the target iPhone by USB, unlock it and approve Trust when asked.
3. Select that iPhone in idevice_pair, choose **Remote pairing (RPPairing)**, then click Create. In v1.1.0, Validate and Save to file appear only after creation succeeds. Validate it, wait for Works, then save that same record; avoid clicking Create again after saving.
4. Transfer it to the same iPhone, for example with AirDrop, and save it in Files.

Choose Remote pairing. A classic Lockdown / SideStore `.mobiledevicepairing` record cannot be used directly; renaming it does not convert it. WrapPin checks contents rather than assuming a file extension identifies its pairing type.

## Import into WrapPin

1. Install the candidate and open Device Setup. iOS 26 shows computer instructions and Import RPPairing File instead of Pair This iPhone.
2. Choose the saved file. Alternatively, copy its XML contents and explicitly tap Paste RPPairing from Clipboard; WrapPin never reads the clipboard automatically.
3. Confirm Pairing file ready. This means validation and Keychain storage succeeded, not that a real device connection has been verified.
4. Keep Developer Mode and Wi-Fi on. Tunnel asks to add its VPN configuration; Standard needs LocalDevVPN or another configured device tunnel.
5. Start a fixed location, confirm it in Apple Maps, then stop and confirm that the real location returns.

The editions store records separately, so import into each one. A valid RPPairing file for the same iPhone may be imported into both editions. An invalid replacement preserves the existing valid record. Stop any current location or pairing session before changing the record.

Records stay in the on-device Keychain and are not uploaded. Do not share the private file, XML contents or PIN in issues, chats or support email.

## Physical-device acceptance

Test Standard first: launch, import, tunnel connection, fixed location, routes, background continuity and restoration. Then test Tunnel and regress iOS 27 on-device pairing. Coverage for the entire iOS 26 series should include 26.0–26.3 and 26.4 or later.

Connect again after reboot to expose reliance on temporary state prepared by another developer tool. If importing succeeds and the tunnel is reachable but the location service is unavailable, check Developer Mode and the Developer Disk Image (DDI), rather than assuming a VPN failure. This candidate adds no DDI download or mount capability; its readiness remains a first-round device acceptance item.

Initial Standard success on iOS 26.5 is recorded in the [candidate notes](Release-1.0.21.md). Restoration, routes, background operation, reboot and other edition/OS combinations still need separate confirmation.
