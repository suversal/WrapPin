<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="Design/WrapPin-AppIcon-Dark.png">
    <source media="(prefers-color-scheme: light)" srcset="Design/WrapPin-AppIcon-Light.png">
    <img src="Design/WrapPin-AppIcon-Light.png" width="128" height="128" alt="WrapPin icon">
  </picture>
</p>

<h1 align="center">WrapPin</h1>

<p align="center">
  Choose, test and move the location your iPhone reports to the system, on one map.
</p>

<p align="center">
  <a href="README.md">简体中文</a> · <strong>English</strong>
</p>

<p align="center">
  <a href="https://github.com/suversal/WrapPin/releases/latest">Download the latest release</a> ·
  <a href="Documentation/UserGuide.md">User guide</a> ·
  <a href="https://x.com/suversal">@suversal on X</a>
</p>

WrapPin sets a fixed location or moves along a walking or driving route on an iPhone running **iOS 27 or newer**, without a jailbreak and without installing a MITM root certificate. It uses the iOS developer location simulation service. The app interface is available in English and Simplified Chinese and follows the system language.

WrapPin is an unofficial community fork of [Roam Control](https://github.com/seanhowarthdev/Roam-Control) by Sean Howarth, maintained by suversal. Upstream provides the core pairing, fixed-location, walking and restore features. WrapPin adds Simplified Chinese localisation, setup and connection guidance, coordinate-mode selection, driving routes, connection diagnostics and an optional built-in tunnel. It keeps the original author's attribution and is not an official upstream release.

> Use WrapPin only on devices you own and control. Do not use it to deceive other people, fabricate evidence, bypass security restrictions, or break the rules of third-party services.

## Contents

- [What you need](#what-you-need)
- [Which edition to download](#which-edition-to-download)
- [Install step by step](#install-step-by-step)
- [Pair this iPhone](#pair-this-iphone)
- [Simulate a location](#simulate-a-location)
- [Stop and restore your real location](#stop-and-restore-your-real-location)
- [Wi-Fi and mobile data](#wi-fi-and-mobile-data)
- [Keep the apps signed](#keep-the-apps-signed)
- [Tunnel edition](#tunnel-edition)
- [Troubleshooting](#troubleshooting)
- [Limits you should know](#limits-you-should-know)
- [How it works](#how-it-works)

## What you need

This guide uses the free route: **iLoader + SideStore + LocalDevVPN + WrapPin**.

- A physical iPhone running iOS 27 or newer, with a passcode set.
- A Mac, Windows or Linux computer. It is needed only once, to install SideStore.
- A USB cable that carries data.
- An Apple account. A free account is enough.
- Wi-Fi. SideStore needs Wi-Fi and LocalDevVPN whenever it installs or refreshes an app.

Download everything from its official source:

| Tool | Where it runs | Source |
| --- | --- | --- |
| iLoader | Computer | [iloader.app](https://iloader.app/) |
| SideStore | iPhone, installed by iLoader | [SideStore installation docs](https://docs.sidestore.io/docs/installation/prerequisites) |
| LocalDevVPN | iPhone | [App Store](https://apps.apple.com/app/localdevvpn/id6755608044) |
| WrapPin IPA | iPhone | [GitHub Releases](https://github.com/suversal/WrapPin/releases/latest) |

Do not install an IPA from an unknown mirror or file-sharing link. It may have been repackaged.

## Which edition to download

Each release provides two IPA files with the same features.

| | Standard `WrapPin-Standard-…` | Tunnel `WrapPin-Tunnel-…` |
| --- | --- | --- |
| Device tunnel | Uses LocalDevVPN | Built in; connects automatically |
| Signing | Free Apple account through SideStore | Paid certificate with the Packet Tunnel entitlement |
| Renewal | Every seven days | Depends on the certificate |

**If you are not sure, download the Standard edition.** The main guide below installs it. The Tunnel edition cannot be signed with a free account or with SideStore; see [Tunnel edition](#tunnel-edition) if you have a paid certificate.

## Install step by step

### 1. Install LocalDevVPN on the iPhone

1. Install [LocalDevVPN](https://apps.apple.com/app/localdevvpn/id6755608044) from the App Store. It is not listed in every region's store, for example mainland China; use an account from a region where it is available.
2. Open it and tap **Connect**.
3. Allow it to add a VPN configuration and enter your passcode.
4. Check that it shows as connected.

Despite its name, LocalDevVPN does not change your public IP address or route your traffic anywhere. It only lets SideStore and WrapPin reach services on the iPhone itself. Connecting it disconnects any other VPN or proxy app that is running.

### 2. Install SideStore with iLoader

1. Install [iLoader](https://iloader.app/) on your computer.
2. Connect the iPhone with the cable and unlock it. If the iPhone asks whether to trust this computer, tap **Trust** and enter your passcode.
3. Open iLoader and check that the iPhone appears in the device list. If it does not, try another cable and confirm that Finder, iTunes or Apple Devices can see the iPhone.
4. Sign in to iLoader with your Apple account. Enter the two-factor code if asked.
5. Select the iPhone and choose the latest **SideStore (Stable)**. To use the exact build this guide was tested with instead, see the note below.
6. Wait for signing and installation to finish. Do not unplug the cable.

Use the latest SideStore Stable release, or the exact build this guide was tested with. Other versions, especially older builds, are likely to fail on iOS 27.

The tested build is the Nightly build `SideStore-0.7.0-20260914.1447+1fce70de.ipa`, used in September 2026 because the Stable release available at that time did not work. To install it:

1. Sign in to GitHub and download [this build artifact](https://github.com/SideStore/SideStore/actions/runs/34800395893/artifacts/10331626491). Unzip it and find the IPA with that name.
2. Follow steps 1–4 above, then select the iPhone in iLoader.
3. Choose **INSTALLERS → Import IPA**, select that IPA and follow the prompts. Do not choose **SideStore (Nightly)**: it downloads the current Nightly build, not the tested one.
4. Open SideStore and check that the version shown at the bottom is `0.7.0-20260914.1447+1fce70de`.

If a different SideStore version is already installed, try installing the tested build over it first, signed in with the same Apple account as before. If iLoader reports that it cannot install over the existing app, delete SideStore on the iPhone and repeat step 3. Deleting SideStore also removes its pairing file, so afterwards choose **Manage Pairing File** in iLoader and tap **Place** next to SideStore before you open it.

GitHub deletes build artifacts after a retention period, so the download link may stop working. If it has, use the latest Stable release.

If iLoader asks whether to revoke an existing certificate, check first whether you use the same Apple account with another sideloading tool. Revoking the certificate can stop apps that were signed with it.

### 3. Trust the developer and turn on Developer Mode

1. Open **Settings → General → VPN & Device Management**. Under **Developer App**, select your Apple account and tap **Trust**.
2. Open **Settings → Privacy & Security → Developer Mode** and turn it on.
3. Restart the iPhone when asked. After it restarts, unlock it and confirm that you want Developer Mode on.

Developer Mode does not require a paid Apple Developer Program membership. WrapPin depends on it, so this step cannot be skipped. If the Developer Mode switch is missing, confirm that SideStore was installed and trusted, then look again.

If Apple reports that your account has no development team, sign in at [developer.apple.com/register](https://developer.apple.com/register/) and accept the agreement. This is free.

### 4. Refresh SideStore once

1. Connect to Wi-Fi and connect LocalDevVPN.
2. Open SideStore and sign in with the same Apple account you used in iLoader.
3. Open **My Apps** and tap **7 DAYS** next to SideStore to refresh it.
4. Follow any prompt about creating a new certificate.

SideStore is fully set up once this refresh succeeds. You no longer need the computer for everyday use.

### 5. Download the WrapPin IPA

1. Open [GitHub Releases](https://github.com/suversal/WrapPin/releases/latest) and download `WrapPin-Standard-…-unsigned.ipa`.
2. Save it to the **Files** app on the iPhone. If you downloaded it on a computer, send it over with AirDrop, iCloud Drive or the cable.

Each release lists the SHA-256 checksum of its IPA files. To check a download on a Mac, run `shasum -a 256 <file>.ipa` and compare the result.

### 6. Sideload WrapPin with SideStore

> [!IMPORTANT]
> Do not use SideStore's install-from-URL option or paste the GitHub download link. Some SideStore versions read the remote file name as the bundle ID and fail with a bundle ID mismatch. Save the IPA to **Files** first and choose it from there.

1. Confirm that Wi-Fi and LocalDevVPN are both connected.
2. Open SideStore and go to **My Apps**.
3. Tap **+** and choose the WrapPin IPA from **Files**.
4. Wait for SideStore to sign and install it. Keep SideStore open, and keep Wi-Fi and LocalDevVPN connected.
5. Check that the WrapPin icon is on the Home Screen.

To update WrapPin later, install the new IPA over the existing app. Do not delete the old version first: deleting the app removes its favourites, history and settings, and you may need to pair again.

## Pair this iPhone

1. Open WrapPin and read the introduction. Allow Local Network access when iOS asks; without it, WrapPin cannot find the device.
2. On **Device Setup**, tap **Pair This iPhone**. WrapPin shows a six-digit code. The code also appears in a notification.
3. Open **Settings → Privacy & Security → Developer Mode → Pair with WrapPin**.
4. Enter your iPhone passcode if asked, then enter the six-digit code from WrapPin. These are two different codes.
5. Return to WrapPin and check that the status shows **Ready**.

Pairing is normally needed only once. The pairing record is stored in this iPhone's Keychain and is not uploaded. Do not share the pairing record, the code, your Apple account or your signing material.

## Simulate a location

### A fixed location

1. Make sure LocalDevVPN is connected.
2. Choose a place: search for it, enter coordinates such as `51.50740, -0.12780`, tap the map, or pick a favourite or recent location.
3. Choose the **simulation coordinate mode** on the location card. Use **WGS84** for places outside mainland China and try **GCJ-02** for places inside it. This is only a starting suggestion; if the position is offset, switch to the other mode.
4. Tap **Start Location** and follow any LocalDevVPN or network guidance that appears.
5. Wait for the status to show that the location is active.
6. Open Apple Maps and confirm that your position has changed.

Check the result in Apple Maps first, not in a third-party app. Other apps may also use your IP address, Wi-Fi, cell towers, account region, cached data or their own risk signals. WrapPin changes only the location reported by the developer simulation service.

To move while a session is active, choose another place and tap **Update Location**. You do not need to pair or reconnect.

### A walking or driving route

1. Choose a destination and tap **Preview Walk** or **Preview Drive**.
2. Check the route, distance and estimated time. When Apple Maps offers several routes, choose one on the card or tap it on the map.
3. Set the speed: a walking pace or 1–12 km/h for walking, 5–240 km/h for driving.
4. Tap **Start Walking** or **Start Driving**.

You can pause and resume along the way. Routes come from Apple Maps, so WrapPin cannot offer a route where Apple Maps has none. The [user guide](Documentation/UserGuide.md) describes the route controls in full.

## Stop and restore your real location

Do not force-quit WrapPin to end a session.

1. Return to WrapPin and tap **Stop & Restore**.
2. Keep WrapPin in the foreground until it confirms that the real location is restored.
3. Open Apple Maps and check your position.

Until the restore finishes, do not rely on navigation, ride-hailing, emergency or location-sharing apps.

If WrapPin quits unexpectedly during a session, it shows a recovery screen the next time it opens. You can continue the previous session or choose **Restore Real Location**. The recovery screen never starts anything by itself.

## Wi-Fi and mobile data

**On Wi-Fi:** confirm that LocalDevVPN is connected. If WrapPin stays on **Finding This iPhone…**, turn LocalDevVPN off and on again, then tap **Try Again**. Pause any other VPN or proxy app first, because iOS lets only one app control the system VPN tunnel at a time.

**On 4G or 5G:** WrapPin may ask you to turn mobile data off briefly.

1. Start the selected location.
2. When **Turn Mobile Data Off** appears, switch mobile data off.
3. Return to WrapPin and wait for it to find the iPhone. Tap **Continue** if it does not carry on by itself.
4. When **Turn Mobile Data Back On** appears, switch mobile data on again.

Mobile data needs to be off only while the local connection is being set up. Once the session is active, it keeps working with mobile data on.

## Keep the apps signed

Apps signed with a free Apple account expire after seven days. You do not need the computer to renew them as long as SideStore itself has not expired.

1. Connect to Wi-Fi and connect LocalDevVPN.
2. Open SideStore and go to **My Apps**.
3. Tap **Refresh All**, or tap the days remaining next to each app.
4. Wait until both SideStore and WrapPin are refreshed.

Refreshing extends the signature and keeps WrapPin's data. If SideStore itself has expired, it cannot open and cannot renew itself: connect the iPhone to the computer, reinstall SideStore with iLoader over the existing copy, then refresh your apps again.

The seven-day limit and the limits on the number of apps and App IDs are Apple's rules for free accounts, not WrapPin subscriptions.

## Tunnel edition

The Tunnel edition has its own device tunnel, so it does not need LocalDevVPN. Both the app and its embedded extension must be signed with a paid certificate whose provisioning profile grants the Packet Tunnel (Network Extension) entitlement.

There are two ways to sign it. These are outlines only:

- **A paid certificate and a signing tool on the iPhone.** Import the certificate and provisioning profile into an IPA signing tool, import `WrapPin-Tunnel-…-unsigned.ipa`, then sign and install it. Confirm beforehand that the certificate supports VPN / Network Extension apps. This project does not provide, recommend or vouch for any certificate service.
- **Xcode and a paid Apple Developer account.** Set your team and bundle ID in `Configuration/Local.private.xcconfig`, select the **WrapPin Tunnel** scheme and run it on your iPhone. The maintainer has not tested this route.

After installing:

1. Turn on Developer Mode and pair the iPhone as described in this guide. Both editions need this.
2. The first time the tunnel starts, allow WrapPin Tunnel to add a VPN configuration.
3. Start a location. With **Use Built-in Tunnel** selected in Settings, the tunnel connects when a session starts and disconnects after the real location is restored.

Wherever this guide tells you to connect LocalDevVPN before using WrapPin, the built-in tunnel does that job instead. See [Installation](Documentation/Installation.md#install-the-tunnel-edition) for more detail.

## Troubleshooting

**SideStore says there is no Wi-Fi or LocalDevVPN.** Confirm that both are connected. Turn off other DNS, proxy and VPN tools, then restart LocalDevVPN and SideStore.

**SideStore stops partway through installing the IPA.** Make sure you are on the latest SideStore Stable release or on the tested build named in step 2, and switch to one of them if not. Then try, in order: reopen SideStore, clear its cache, switch to another Anisette server, restart the iPhone. If it still fails, use iLoader to replace the pairing file or reinstall SideStore.

**SideStore's pairing file is no longer valid.** An iOS update or a device restore can invalidate it. Connect the iPhone to the computer, remove the old pairing in iLoader, trust the computer again, and use **Manage Pairing File** to place a new one in SideStore.

**WrapPin cannot find this iPhone.** Check that LocalDevVPN is connected, that no other VPN is using the system tunnel, that Local Network access is allowed for WrapPin, and that you are following the right flow for Wi-Fi or mobile data. Turn LocalDevVPN off and on, then try again. If WrapPin reports that the pairing record is invalid, remove it and pair again.

**WrapPin shows the location as active, but another app has not changed.** Check Apple Maps. If Apple Maps has moved and the other app has not, that app is using cached data or other signals. WrapPin does not change your IP address, Wi-Fi, cell towers, Apple account region or anything stored on a third-party server.

**The real location does not come back after stopping.** Reopen WrapPin, choose **Restore Real Location** and keep the app in the foreground. Then check Apple Maps. If needed, turn Location Services off and on.

**You want to report a problem.** Open **Settings → Connection Health** in WrapPin, run the check and copy the diagnostic information into a [GitHub issue](https://github.com/suversal/WrapPin/issues). Include the iPhone model, the full iOS version and the step that failed. Do not include pairing records, codes, signing material, account credentials or private locations.

## Limits you should know

- WrapPin supports only physical iPhones running iOS 27 or newer. The simulator can show the interface but cannot pair or simulate a location.
- WrapPin changes the developer-simulated location. It does not change your public IP address, carrier, Apple account region or App Store region.
- Not every third-party app accepts a simulated location.
- LocalDevVPN usually cannot run at the same time as another app that controls the system VPN.
- Simulated location does not change Apple Watch regional eligibility, eSIM, carrier or satellite features.
- Foreground fixed locations, walking and restore have been verified. Long sessions with the screen locked still need testing on more devices and iOS versions, and are not guaranteed.

## How it works

WrapPin uses the iOS **developer location simulation** channel. It does not fake an IP address through a proxy and does not intercept or rewrite Apple's location requests.

1. WrapPin creates a pairing record on the iPhone and stores it in the Keychain.
2. LocalDevVPN, or the built-in tunnel in the Tunnel edition, exposes the iPhone's own remote pairing service so that WrapPin can find it.
3. WrapPin verifies the device identity and opens an encrypted developer session.
4. WrapPin sets coordinates through the iOS LocationSimulation service, and keeps updating them along a route.
5. When you stop, WrapPin tells iOS to clear the simulated location.

The older WLOC approach used a proxy and a local CA certificate to rewrite Apple's Wi-Fi and cell-tower location responses. Some WLOC forks report that TLS validation changes in iOS 27 block that method, while others say they have adapted. WrapPin is not a newer version of WLOC: the two change different signals, and neither changes your public IP address or account region.

The SwiftUI interface talks to the native session through a small Rust-to-Swift bridge built on the MIT-licensed [`idevice`](https://github.com/jkcoxson/idevice) library.

## Build from source

Building needs Xcode 27 or newer and your own Apple development team. See [Installation](Documentation/Installation.md) for the Xcode steps for each edition and [Build and Release](Documentation/BuildAndRelease.md) for packaging and the native engine.

## Privacy and licence

Locations, coordinates, searches, favourites, history, routes and pairing records stay on the iPhone. WrapPin asks GitHub for the latest public release when it opens, without sending location or pairing data. Anonymous usage statistics are off by default. See [Privacy](Documentation/Privacy.md).

WrapPin is released under the [PolyForm Noncommercial License 1.0.0](LICENSE). The source is available, and non-commercial use, modification and distribution are allowed under its terms. It is not an OSI-approved open-source licence. Third-party dependencies keep their own licences.

## Feedback

Report reproducible problems through [GitHub Issues](https://github.com/suversal/WrapPin/issues) and security problems privately through GitHub Security Advisories. You can also reach the maintainer on X at [@suversal](https://x.com/suversal). Contributions are welcome; read [CONTRIBUTING.md](CONTRIBUTING.md) first.

If WrapPin helped you, a **Star** on the repository is appreciated.
