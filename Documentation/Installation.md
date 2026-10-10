# Installation

WrapPin is not distributed through the App Store or TestFlight. Release builds are supplied as unsigned IPA files that must be signed before installation.

## Choose an edition

Each GitHub Release provides two IPA files. They offer the same features and differ in where the device tunnel comes from and how they must be signed.

| | Standard `WrapPin-Standard-…` | Tunnel `WrapPin-Tunnel-…` |
| --- | --- | --- |
| Device tunnel | Requires an external tunnel such as LocalDevVPN | Built in; connects automatically when a location starts |
| Signing | A free Apple account is enough (SideStore) | A paid certificate with the Packet Tunnel entitlement |
| Renewal | Every seven days with a free account | Depends on the certificate and provisioning profile |

The two editions use different App IDs and can be installed side by side, but each keeps its own settings and pairing record. Use the Standard edition if you do not have a paid certificate.

## Requirements

- An iPhone running iOS 27 or newer.
- Developer Mode enabled under **Settings → Privacy & Security**. Both editions need it: the on-device pairing and location simulation WrapPin relies on are system developer services, regardless of which certificate signs the app.
- Standard edition: [LocalDevVPN](https://apps.apple.com/app/localdevvpn/id6755608044) installed on the iPhone. The Tunnel edition does not need it.
- Standard edition: SideStore, or Xcode on a Mac with an Apple development team.
- Tunnel edition: a paid signing configuration with the Packet Tunnel entitlement. See "Install the Tunnel edition" below.

## Install the Standard edition with SideStore

1. Download the IPA attached to the matching GitHub Release. Do not download an IPA from an untrusted mirror.
2. In SideStore, tap **+** and choose the downloaded IPA.
3. Allow SideStore to sign and install WrapPin with your Apple account.
4. Open WrapPin and complete its introduction and device-pairing flow.
5. Open LocalDevVPN and enable its local tunnel before starting a location.

Free Apple accounts normally require sideloaded apps to be refreshed within seven days and limit the number of simultaneously active apps/App IDs. These are Apple signing limits, not WrapPin subscriptions.

When updating, install the newer IPA over the existing copy. Deleting the app first also deletes its local settings and may require pairing again.

## Install the Tunnel edition

Both the main app and the embedded `WrapPinTunnel.appex` extension must be signed, and both provisioning profiles must actually grant `packet-tunnel-provider` under `com.apple.developer.networking.networkextension`. Free Apple accounts cannot obtain this entitlement, so SideStore's free signing cannot be used for the Tunnel edition.

### With a paid certificate and a signing tool

This route needs no Mac and is completed on the iPhone.

1. Obtain a paid certificate and provisioning profile that include this device's UDID. They can come from your own Apple Developer account or from a third-party certificate service.
2. Install an IPA signing tool that can import certificates on the iPhone, then import the certificate and profile.
3. Download `WrapPin-Tunnel-…-unsigned.ipa` from the matching GitHub Release and import it into the signing tool.
4. Sign and install it.
5. Open WrapPin Tunnel, allow it to add a VPN configuration the first time the tunnel starts, then complete device pairing.

Notes:

- Before obtaining a certificate, confirm that it supports VPN / Network Extension apps. A certificate that only supports ordinary IPA files produces an app that installs but cannot start the built-in tunnel.
- The signing tool must also re-sign the embedded extension. The bundle ID may be changed, but the extension's bundle ID must be the main app's bundle ID plus `.tunnel`, otherwise the app cannot find its extension.
- A third-party certificate belongs to someone else's developer account: a registered device usually cannot be changed or refunded, and the certificate may be revoked. This project does not provide, recommend, or vouch for any certificate service.
- Do not post certificate private keys, p12 passwords, provisioning profiles, or UDIDs in issues or public channels.

### With Xcode and a paid developer account

1. Clone the repository and copy `Configuration/Local.private.xcconfig.example` to `Configuration/Local.private.xcconfig`.
2. Fill in your own team and App ID, and delete the example lines you do not need. The extension automatically uses that ID plus `.tunnel`:

   ```
   DEVELOPMENT_TEAM = YOUR-TEAM-ID
   WRAPPIN_TUNNEL_BUNDLE_IDENTIFIER = com.example.wrappin.selfsigned
   ```

3. Open `WrapPin.xcodeproj` with Xcode 27 or newer and select the **WrapPin Tunnel** scheme.
4. Select a connected iPhone and press **Run**. The project uses automatic signing, so Xcode registers the device, creates both App IDs, and generates profiles with the Network Extensions capability.

To re-sign a released IPA with your own account instead of building from source, create an explicit App ID and provisioning profile with Network Extensions enabled for the main app and for the extension, then sign the extension before the main app. Signing requirements and post-signing checks are described in the [built-in tunnel notes](BuiltInTunnelResearch.zh-CN.md) (Chinese).

Update the Tunnel edition by installing over the existing copy with the same certificate and bundle ID as before.

## Build the Standard edition with Xcode

1. Clone the repository and open `WrapPin.xcodeproj`.
2. Select the **WrapPin Standard** scheme and choose your own team under **Signing & Capabilities** for the `WrapPinStandard` target.
3. Select a connected iPhone and press **Run**.

The tracked build configuration has no Apple team or TelemetryDeck destination. Xcode may save your selected team locally. Do not commit signing material or `Configuration/Local.private.xcconfig`.

The simulator can test the interface but cannot complete the physical iPhone pairing handshake or start a real location session.

## Verify a release

Each GitHub Release publishes the IPA's SHA-256 checksum. On a Mac, calculate the checksum of the IPA you downloaded:

```sh
shasum -a 256 WrapPin-1.0.0-build1.ipa
```

Compare the result with the SHA-256 value shown on the matching GitHub Release before installing it.

See the [user guide](UserGuide.md) for pairing and everyday operation.
