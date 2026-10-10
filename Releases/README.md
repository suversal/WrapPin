# WrapPin releases

## Active distribution tracks

- Public release: `v1.0.16` Build 52, with both editions attached to the same GitHub Release.
- Standard edition (SideStore and other self-signing): `WrapPin-Standard-1.0.16-build52-unsigned.ipa`, bundle ID `com.suversal.wrappin`.
- Tunnel edition (signing profiles with Packet Tunnel permission): `WrapPin-Tunnel-1.0.16-build52-unsigned.ipa`, bundle ID `com.suversal.wrappin.selfsigned`, extension `com.suversal.wrappin.selfsigned.tunnel`.

## 1.0.16 (Build 52)

- Created: 10 October 2026 with Xcode 27.0 (`27A266a`) using `scripts/package-ipa.sh standard` and `scripts/package-ipa.sh tunnel` from the same source state
- Standard IPA: `WrapPin-Standard-1.0.16-build52-unsigned.ipa`; SHA-256 `653efba12ee92a6a8b6749957850c7ee2f30fe89b6f5276dadd52c680a98ca5e`; no Packet Tunnel extension.
- Tunnel IPA: `WrapPin-Tunnel-1.0.16-build52-unsigned.ipa`; SHA-256 `1e045e154fc268357fdd5e408c93b1b6b7eefd56529325782b2ef65d00d9d657`; contains `WrapPinTunnel.appex`.
- Both: optimized unsigned Release Archive, arm64 iPhone, iOS 27+. No TelemetryDeck identifiers were configured for this build, so it sends no usage statistics.
- Changes: Surge and Loon added as tunnel handoff apps; Shadowrocket is asked to connect through `shadowrocket://connect`; external-tunnel Wi-Fi guidance and diagnostics apply to all three; setup guides and importable Surge and Loon modules added. No native engine change from Build 48.
- Verification: localization, failure-stage, background-session, coordinate-mode, route-recovery, tunnel-handoff and route-selection checks, both Release archives, IPA ZIP integrity, identifiers, versions and extension presence or absence passed. Native engine tests were not rerun because the engine is unchanged. The maintainer installed both editions on a physical iPhone and confirmed the handoff to Shadowrocket, Surge and Loon.
- Known issues: the device connection through Shadowrocket, Surge or Loon is unreliable on mobile data and is not fixed in this build, so use Wi-Fi with these apps; the three apps do not return to WrapPin automatically. Builds 49 to 51 were local test builds and were not published.
- Publication: GitHub Release `v1.0.16`.

See [the 1.0.16 build notes](../Documentation/Release-1.0.16.md) for details.

## 1.0.15 (Build 48)

- Created: 8 October 2026 with Xcode 27.0 (`27A266a`) using `scripts/package-ipa.sh all`
- Standard IPA: `WrapPin-Standard-1.0.15-build48-unsigned.ipa`; SHA-256 `58d30ab5801807708b9f0a04d59869cab684465212226b186966b32272a1b84d`; no Packet Tunnel extension.
- Tunnel IPA: `WrapPin-Tunnel-1.0.15-build48-unsigned.ipa`; SHA-256 `eefaed0ff692454d610ff45b91780a5216d5c63a65001daa425eca5afb894522`; contains `WrapPinTunnel.appex`.
- Both: optimized unsigned Release Archive, arm64 iPhone, iOS 27+. No TelemetryDeck identifiers were configured for this build, so it sends no usage statistics.
- Changes: four connection failure messages from the native engine refer to the device tunnel instead of naming LocalDevVPN; both xcframework slices rebuilt. No other change from Build 47.
- Verification: localization, failure-stage, background-session, coordinate-mode, route-recovery, tunnel-handoff and route-selection checks, native engine tests, both Release archives, IPA ZIP integrity, identifiers, versions and extension presence or absence passed. Build 48 has not been installed on a device and the wording change was not device-tested on its own.
- Known issues: resuming an interrupted route replans with the suggested route only.
- Publication: GitHub Release `v1.0.15`.

See [the 1.0.15 build notes](../Documentation/Release-1.0.15.md) for details.

## 1.0.14 (Build 47)

- Created: 8 October 2026 with Xcode 27.0 (`27A266a`) using `scripts/package-ipa.sh all`
- Standard IPA: `WrapPin-Standard-1.0.14-build47-unsigned.ipa`; SHA-256 `5b538b6d8c900664bb26421354ea966fe8305779009e13448afc272f703c62f9`; no Packet Tunnel extension.
- Tunnel IPA: `WrapPin-Tunnel-1.0.14-build47-unsigned.ipa`; SHA-256 `77eada290adc810fed300df26f6b54a1916ca88fadce0b0d49bc9a5f1408a531`; contains `WrapPinTunnel.appex`.
- Both: optimized unsigned Release Archive, arm64 iPhone, iOS 27+. No TelemetryDeck identifiers were configured for this build, so it sends no usage statistics.
- Changes: alternative routes in walking and driving previews; the location engine reports failure stage codes and observes a stop during connection, which required rebuilding both xcframework slices; fixes for Chinese failure stages, the current-location button after restore, tunnel-app naming and Device Setup localization; the tunnel edition's update check.
- Verification: localization, failure-stage, background-session, coordinate-mode, route-recovery, tunnel-handoff and route-selection checks, native engine tests, both Release archives, IPA ZIP integrity, identifiers, versions and extension presence or absence passed. Build 47 itself has not been installed on a device; the maintainer reported on 8 October 2026 that the Build 46 packages of both editions, with the same feature code, passed device testing.
- Known issues: a few connection failure messages still name LocalDevVPN when another tunnel is in use; resuming an interrupted route replans with the suggested route only.
- Publication: GitHub Release `v1.0.14`.

See [the 1.0.14 build notes](../Documentation/Release-1.0.14.md) for details.

## 1.0.13 (Builds 42–46, device-test packages)

- Created: 6–8 October 2026 with Xcode 27.0 (`27A266a`); unsigned test packages for the maintainer only, not published.
- Build 42 (Standard): failure stage codes and prompt stop while connecting; SHA-256 `c64e3791c2f1181719f00ddbdc61db2cbccf496dc6b8b7d41142207ef5a38e74`.
- Build 43 (Standard): Device Setup localization; SHA-256 `0ebf747928c4c8c881d68bb0cce47f02d7210fa989b67adb8e3500c330318bbf`.
- Build 44 (Standard): simulated fixes ignored after restore; selected tunnel app named in the interface; SHA-256 `9b8c043a7491fcccb33385a219ec1ba649525563c5c65c3d096d7f11b3b85099`.
- Build 45 (both editions): tunnel-app button opens the installed app; Standard SHA-256 `0bb91e849df93c124d63c02c29f2a99489e55e1e314daf212566362fb330d70b`, Tunnel SHA-256 `8c6389581446a6db4454b384c1010b9b711147c9acef39e75e8b35211d237b69`.
- Build 46 (both editions): alternative routes; Standard SHA-256 `80c1e69360db34c0836f345c53fbbdea1412c645c318eee21897a4652202fa26`, Tunnel SHA-256 `62be1fc440cba99709a30e7fc4f6137a43c3ef2d3213f3dcd639863754a8b12c`.
- Verification: the maintainer reported that Standard Builds 45 and 46 and Tunnel Builds 45 and 46 passed device testing; the individual test cases were not recorded here.

## 1.0.13 (Build 41)

- Created: 4 October 2026 with Xcode 27.0 (`27A266a`) using `scripts/package-ipa.sh all`
- Standard IPA: `WrapPin-Standard-1.0.13-build41-unsigned.ipa`; SHA-256 `794ce2cc86f27eb1b9d21183db04cddf3ce3608e7393869bb79e9955e316fcbc`; no Packet Tunnel extension.
- Tunnel IPA: `WrapPin-Tunnel-1.0.13-build41-unsigned.ipa`; SHA-256 `8d4c8f27c3e640d24f5db02b18a4dfc4ee54cb024a48ca982a8f04a912c4ee58`; contains `WrapPinTunnel.appex`.
- Both: optimized unsigned Release Archive, arm64 iPhone, iOS 27+.
- Changes: first public release with both editions; version metadata 1.0.13; the tunnel app's Xcode target is now named `WrapPinTunnelEdition`. Feature code is the same as Build 40.
- Verification: localization, background-session and failure-stage checks, both Release archives, IPA ZIP integrity, identifiers, versions and extension presence or absence passed. Build 41 itself has not been installed on a device; the maintainer reported that the Build 40 packages passed device testing.
- Publication: GitHub Release `v1.0.13`.

See [the 1.0.13 build notes](../Documentation/Release-1.0.13.md) for details.

## 1.0.12 (Build 40, dual-edition candidate)

- Created: 4 October 2026 with Xcode 27.0 (`27A266a`) using `scripts/package-ipa.sh all`
- Standard IPA: `WrapPin-Standard-1.0.12-build40-unsigned.ipa`; SHA-256 `d4cabc599d1a2f72116c851103d85654b277450e8299c5c6abae14bc3523b0f3`; bundle ID `com.suversal.wrappin`; no Packet Tunnel extension and no NetworkExtension linkage.
- Tunnel IPA: `WrapPin-Tunnel-1.0.12-build40-unsigned.ipa`; SHA-256 `fb075813280cfa772bf51d80953d4b9de9452eb9ae3846d13c3e2fcdd4f6e6ea`; bundle ID `com.suversal.wrappin.selfsigned`; extension ID `com.suversal.wrappin.selfsigned.tunnel`.
- Changes: built-in tunnel code is compiled only into the tunnel edition; version, build and timestamp come from `Configuration/Version.xcconfig` for all targets; a tunnel stopped outside the app no longer stays marked as manually kept running; added the missing Simplified Chinese address hint.
- Verification: both Release archives, localization check, IPA ZIP integrity, identifiers, versions and extension presence or absence passed. The maintainer reported on 4 October 2026 that both packages passed device testing; the individual test cases were not recorded here.

## 1.0.12 (Build 38, internal dual-edition comparison)

- Created: 4 October 2026 with Xcode 27.0 (`27A266a`)
- Standard IPA: `WrapPin-Standard-1.0.12-build38-unsigned.ipa`; SHA-256 `e432b8ebf0f38012351b36f41ed77d33710b9c16baa6b4d612a724423ce16516`; bundle ID `com.suversal.wrappin`; no Packet Tunnel extension.
- Tunnel IPA: `WrapPin-Tunnel-1.0.12-build38-unsigned.ipa`; SHA-256 `2c2322219ebb6526d6d6e70ae22fdb52fb42e59faed221bf71d126b172f8de2c`; bundle ID `com.suversal.wrappin.selfsigned`; extension ID `com.suversal.wrappin.selfsigned.tunnel`.
- Both: optimized unsigned Release Archive, arm64 iPhone, iOS 27+. The Home Screen names and LocalDevVPN return URL schemes are distinct, enabling side-by-side installation when both signing profiles are valid. Their settings and pairing records are separate.
- Verification: both archives succeeded; IPA ZIP integrity, identifiers, names, URL schemes, required resources, code architecture and extension presence or absence passed. Final SideStore and paid-signature device installation remains untested. Build 38 Standard must not be distributed to existing SideStore users. The signing team must provide Packet Tunnel profiles for both new tunnel IDs.

See [the tunnel test guide](../Documentation/BuiltInTunnelResearch.zh-CN.md) for signing and device checks.

## 1.0.12 (Build 37, dual-edition device test)

- Created: 4 October 2026 with Xcode 27.0 (`27A266a`)
- Standard IPA: `WrapPin-Standard-1.0.12-build37-unsigned.ipa`; SHA-256 `98ba8c8370f0603d54c834c23928b4e3af5b55831493ea1629f785c21f8299df`; no Packet Tunnel extension.
- Tunnel IPA: `WrapPin-Tunnel-1.0.12-build37-unsigned.ipa`; SHA-256 `7f3920066cb168ea6cd52c2741fe3d64541055dad54a6fc2c2488396cffee2d5`; contains `WrapPinTunnel.appex`.
- Both: optimized unsigned Release Archive, arm64 iPhone, iOS 27+, bundle ID `com.suversal.wrappin`.
- Changes: separate build schemes from one source tree; dedicated tunnel settings page, editable local IPv4/CIDR, and recovery guidance for a disabled VPN configuration.
- Verification: both archives succeeded; ZIP integrity, package identity, required resources and extension presence/absence passed. A user installed the Standard IPA through SideStore, but iOS then showed “Unable to Verify App” for the SideStore developer identity and would not launch it. The signed installation has not passed device acceptance; the trust-verification cause is still under investigation. Tunnel Build 37 has not been retested on device.
- Signing: standard edition can be signed by SideStore; tunnel edition needs profiles with Packet Tunnel permission for both app and extension. The unsigned IPAs cannot be installed as-is.

See [the tunnel test guide](../Documentation/BuiltInTunnelResearch.zh-CN.md) for the device test sequence.

## 1.0.12 (Build 32)

- Created: 28 September 2026
- Package: `WrapPin-1.0.12-build32.ipa`
- Build: optimized unsigned Xcode Release Archive, arm64 iPhone executable
- Requires: iOS 27.0 or later
- Xcode: 27.0 (`27A266a`)
- Distribution: unsigned IPA for SideStore or another user-side signing tool
- SHA-256: `6f700a8ce62b2e03e31bb4217d45971b4972b3f62dae8df134091232fc9d9999`
- Changes: applies the selected GCJ-02 correction or unchanged WGS84 mode to walking and driving route starts, movement updates, destinations, return trips and interrupted-session recovery.
- Verification: source checks, Release Archive and IPA identity/integrity checks passed. The same feature code passed physical-device testing in the local Build 32 test package; the formal package was rebuilt after applying the 1.0.12 version metadata.
- Known issues: coordinate-mode selection remains source- and region-dependent; third-party simulated-location acceptance and device-tunnel reachability are unchanged.
- Publication: GitHub Release `v1.0.12`.

See [the 1.0.12 build notes](../Documentation/Release-1.0.12.md) for details.

## 1.0.11 (Build 31)

- Created: 23 September 2026
- Package: `WrapPin-1.0.11-build31.ipa`
- Build: optimized unsigned Xcode Release Archive, arm64 iPhone executable
- Requires: iOS 27.0 or later
- Xcode: 27.0 (`27A266a`)
- Distribution: unsigned IPA for SideStore or another user-side signing tool
- SHA-256: `dc0c622184d258341c47bd64356a04834a447eaee1231034de9ec082eac1ab45`
- Changes: custom walking speed now adjusts in 0.1 km/h steps; driving speed now adjusts in 1 km/h steps. Ranges and defaults are unchanged.
- Verification: source checks, Release Archive and IPA identity/integrity checks passed. Build 31 has not yet been independently installed or exercised on an iPhone.
- Known issues: this release does not change route planning, coordinate handling or third-party simulated-location acceptance.
- Publication: GitHub Release `v1.0.11`.

See [the 1.0.11 build notes](../Documentation/Release-1.0.11.md) for details.

## 1.0.10 (Build 30)

- Created: 22 September 2026
- Package: `WrapPin-1.0.10-build30.ipa`
- Build: optimized unsigned Xcode Release Archive, arm64 iPhone executable
- Requires: iOS 27.0 or later
- Xcode: 27.0 (`27A266a`)
- Distribution: unsigned IPA for SideStore or another user-side signing tool
- SHA-256: `f0b152dd54ec110f45ef206cb4fb910da44afb1794701c3890a9e7c27d0d84e2`
- Changes: selectable WGS84/GCJ-02 fixed-location modes, compact route preview, automatic public-release check and location callback diagnostics.
- Verification: source checks, Release Archive and IPA identity/integrity checks passed. Earlier coordinate-mode test builds were exercised on an iPhone; Build 30 has not yet been independently installed or visually checked.
- Known issues: neither coordinate mode guarantees accurate display everywhere or acceptance by third-party apps; Shadowrocket on cellular may still lack the required device connection.
- Publication: GitHub Release `v1.0.10`.

See [the 1.0.10 build notes](../Documentation/Release-1.0.10.md) for details.

## 1.0.9 (Build 18)

- Created: 22 September 2026
- Package: `WrapPin-1.0.9-build18.ipa`
- Build: optimized unsigned Xcode Release Archive, arm64 iPhone executable
- Requires: iOS 27.0 or later
- Xcode: 27.0 (`27A266a`)
- Distribution: unsigned IPA for SideStore or another user-side signing tool
- SHA-256: `95f5a5977efab2c1cdf447e949a3defb1ecbc4be673294c31b64674f136e2f07`
- Changes: optional 1–12 km/h custom walking speed with recovery, plus consistently aligned Settings icons.
- Verification: custom speed passed physical-iPhone testing in Build 16; Settings icons passed in Build 17. Localization, native-error, background-session, tunnel-policy, route-recovery, Release Archive and IPA identity/integrity checks passed. Build 18 itself has not yet been installed independently.
- Known issues: no coordinate-offset fix or guarantee that third-party apps accept simulated locations; regional and carrier feature eligibility is unchanged. Shadowrocket on cellular may still lack a compatible paired-device connection.
- Publication: GitHub Release `v1.0.9`.

See [the 1.0.9 build notes](../Documentation/Release-1.0.9.md) for details.

## 1.0.8 (Build 15)

- Created: 22 September 2026
- Package: `WrapPin-1.0.8-build15.ipa`
- Build: optimized unsigned Xcode Release Archive, arm64 iPhone executable
- Requires: iOS 27.0 or later
- Xcode: 27.0 (`27A266a`)
- Distribution: unsigned IPA for SideStore or another user-side signing tool
- SHA-256: `fcd97b69d1a07e64fd157209e40e89d8c639537b1a0eaf8ed5f69a122f3fb8ca`
- Changes: adds a LocalDevVPN/Shadowrocket handoff choice and clearer Wi-Fi/cellular tunnel guidance. It does not read another app's VPN switch or change location accuracy.
- Verification: localization, native failure classification, background-session lifecycle, tunnel-handoff policy and route-recovery checks passed. The Release Archive and IPA payload, identity, arm64 architecture, unsigned state, privacy manifest and legal resources were checked. After the first IPA triggered `SideSign.Archive.Error 1`, the same Build 15 app was repackaged with `ditto`; the user confirmed that this package installed on an iPhone. Wi-Fi/cellular × both tunnel apps has not been fully verified on the final package. The exact cause of the first installation failure remains unconfirmed.
- Known issue: Shadowrocket on cellular may not expose the paired-device connection; use Wi-Fi or LocalDevVPN. LocalDevVPN on cellular retains its app handoff on each new session. Optional anonymous telemetry is inactive in this public-source build because its ingestion identifiers are blank.
- Publication: GitHub Release `v1.0.8`.

See [the 1.0.8 build notes](../Documentation/Release-1.0.8.md) for details.

## 1.0.7 (Build 11)

- Created: 21 September 2026
- Package: `WrapPin-1.0.7-build11.ipa`
- Build: optimized unsigned Xcode Release Archive, arm64 iPhone executable
- Requires: iOS 27.0 or later
- Xcode: 27.0 (`27A266a`)
- Distribution: unsigned IPA for SideStore or another user-side signing tool
- SHA-256: `070199959d635c1dda049fd2186c8800920dd167648272788a65bc60db2e86fc`
- Changes: adds driving-route preview and constant-speed location simulation, with mode/speed recovery.
- Publication: GitHub Release `v1.0.7`.

See [the 1.0.7 build notes](../Documentation/Release-1.0.7.md) for details.

## 1.0.6 (Build 9)

- Created: 17 September 2026
- Package: `WrapPin-1.0.6-build9.ipa`
- Build: optimized unsigned Xcode Release Archive, arm64 iPhone executable
- Requires: iOS 27.0 or later
- Xcode: 27.0 (`27A266a`)
- Distribution: unsigned IPA for SideStore or another user-side signing tool
- SHA-256: `3ac594075b005162bcd3bd7521400b5d96cceeb7db046882060c0f1bc3a0d499`
- Changes: removes the SideStore-sensitive `BGTaskScheduler` dependency from pairing and location startup, adds a Core Location background keep-alive for active simulations, and reports background-session health in Connection Health.
- Verification: localization, native failure classification, background-session lifecycle, Xcode Release Archive, IPA payload, version, architecture, unsigned state, privacy manifest and legal resources were checked. Basic SideStore physical-device testing found no major problem; more affected-device coverage remains welcome.
- Known issue: this release does not change map coordinates or claim to fix the previously observed walking or mainland-China map offset.
- Publication: GitHub Release `v1.0.6`.

See [the 1.0.6 build notes](../Documentation/Release-1.0.6.md) for details.

## 1.0.5 (Build 6)

- Created: 15 September 2026
- Package: `WrapPin-1.0.5-build6.ipa`
- Build: optimized unsigned Xcode Release Archive, arm64 iPhone executable
- Requires: iOS 27.0 or later
- Xcode: 27.0 (`27A266a`)
- Distribution: unsigned IPA for SideStore or another user-side signing tool
- SHA-256: `723fb61fe08ce9cb7fa99b98875838c3a2770cc61470bd4e9a97efe8728df00b`
- Changes: improves worldwide map-selection address resolution, prevents unresolved loading text from entering saved places, refreshes older unresolved entries, and shows exact coordinates when no readable address is available.
- Verification: Xcode Release Archive, localization, native failure checks, IPA payload, version, architecture, unsigned state, privacy manifest and legal resources were checked. The address-resolution changes passed a SideStore physical-device test.
- Publication: GitHub Release `v1.0.5`.

See [the 1.0.5 build notes](../Documentation/Release-1.0.5.md) for details.

## 1.0.4 (Build 5)

- Created: 15 September 2026
- Package: `WrapPin-1.0.4-build5.ipa`
- Build: optimized unsigned Xcode Release Archive, arm64 iPhone executable
- Requires: iOS 27.0 or later
- Xcode: 27.0 (`27A266a`)
- Distribution: unsigned IPA for SideStore or another user-side signing tool
- SHA-256: `a887d4a8f86bf51317eb47ad65475f1b71487cd101f905984429276aaa99a037`
- Changes: aligns the X profile icon with the other Community icons, changes the Chinese label to “关注我”, and refreshes the README.
- Verification: Xcode Release Archive completed and the IPA payload, version, architecture, unsigned state, required legal resources, Chinese label and X profile URL were checked. Physical-device installation and visual acceptance remain pending.
- Publication: GitHub Release `v1.0.4`.

See [the 1.0.4 build notes](../Documentation/Release-1.0.4.md) for details.

## 1.0.3 (Build 4)

- Created: 15 September 2026
- Package: `WrapPin-1.0.3-build4.ipa`
- Build: optimized unsigned Xcode Release Archive, arm64 iPhone executable
- Requires: iOS 27.0 or later
- Xcode: 27.0 (`27A266a`)
- Distribution: unsigned IPA for SideStore or another user-side signing tool
- SHA-256: `bee2a4f7d29f69d844dc005239c67efbf07276b4a6a1ba206a3ddced4caec605`
- Changes: adds an X profile link to the Community section in Settings.
- Verification: Xcode Release Archive completed and the IPA payload, version, architecture, unsigned state, required legal resources and X profile entry were checked. Physical-device installation is delegated to the release tester.

See [the 1.0.3 release notes](../Documentation/Release-1.0.3.md) for details.

## 1.0.2 (Build 3)

- Created: 14 September 2026
- Package: `WrapPin-1.0.2-build3.ipa`
- Build: optimized unsigned Xcode Release Archive, arm64 iPhone executable
- Requires: iOS 27.0 or later
- Xcode: 27.0 (`27A266a`)
- Distribution: unsigned IPA for SideStore or another user-side signing tool
- SHA-256: `68c8fe1d5ec67f8a0e38108775590036bfe38c294880740d532c0267371b5937`
- Replaces: 1.0.1 Build 2, which SideStore rejected with `SideSign.Archive.Error 1`.
- Verification: Xcode Release Archive completed and the IPA payload, version, architecture and unsigned state were checked. Physical-device installation is delegated to the release tester.

See [the 1.0.2 release notes](../Documentation/Release-1.0.2.md) for details.

## 1.0.0 (Build 1)

- Created: 14 September 2026
- Package: `WrapPin-1.0.0-build1.ipa`
- Build: optimized unsigned Release, arm64 iPhone executable
- Requires: iOS 27.0 or later
- Xcode: 27.0 (`27A266a`)
- Distribution: unsigned IPA for SideStore or another user-side signing tool
- SHA-256: `de371230f51cf16f2309926bc5c504eb67dbdd3640ca30b35d02aedc741f19d6`
- Verified: native iPhone and Apple Silicon simulator bridge builds, localization coverage, failure classification, unsigned Release build, IPA payload integrity, version identity, privacy manifest and legal resources.
- Remaining acceptance: install the final 1.0.0 IPA on a physical iPhone before announcing it as fully released.

See [the 1.0.0 release notes](../Documentation/Release-1.0.0.md) for details.
