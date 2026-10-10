# Surge iOS setup

[简体中文](SurgeIntegration.zh-CN.md)

WrapPin can use Surge as its tunnel handoff app. The Standard edition always offers this choice; the Tunnel edition offers it when its built-in tunnel is not in use. This integration does not read or change Surge's VPN state. When the paired-device channel is unreachable, WrapPin uses Surge's official URL scheme `surge:///start` to start the selected configuration, then keeps checking for the pairing service.

## Requirements

- Surge iOS 5.23.0 or later.
- Surge takes over traffic through its VIF.
- The active configuration contains the route and IP Rewrite settings below.

Surge 5.22.x and earlier have no `reflect` action in `IP Rewrite`. Adding a route or a `DIRECT` rule alone does not replace the on-device reflection, so those versions cannot provide this device channel. If the App Store does not offer 5.23.0 yet, join Surge's official TestFlight first, or keep using LocalDevVPN or Shadowrocket.

```ini
[General]
ipv6-vif = disabled
tun-included-routes = %INSERT% 10.7.0.1/32

[IP Rewrite]
10.7.0.1 = reflect
```

`tun-included-routes` sends connections to `10.7.0.1` into the Surge VIF. `reflect` sends them back to the device, so WrapPin can reach the iPhone's own developer services. `ipv6-vif = disabled` keeps tools that depend on this IPv4 on-device channel from choosing an IPv6 VPN interface.

The repository also provides an importable [`WrapPin-Surge.sgmodule`](WrapPin-Surge.sgmodule). You can instead merge the settings above into the existing sections by hand; do not create a second `[General]` or `[IP Rewrite]` section. Use the module when a managed configuration cannot be edited.

The module file is not required. What is required is that the three settings are in effect once Surge is enabled. The repository module also carries a `CORE_VERSION>=6010000` requirement, so an older Surge does not appear to enable it while lacking `reflect`.

## WrapPin settings

1. In WrapPin, choose Surge under **Settings → Tunnel App**.
2. Pair the device once.
3. Start a location. If the device channel is unreachable, WrapPin asks Surge to start its selected configuration.
4. After Surge starts, return to WrapPin manually; WrapPin keeps checking the connection.

If the check fails on mobile data, verify on Wi-Fi first. WrapPin can only check whether the paired-device channel is reachable; it cannot read Surge's VPN switch.

## References

- Surge URL scheme documentation: <https://manual.nssurge.com/tools/url-scheme.html>
- Surge IP Rewrite documentation (On-Device Developer Services): <https://manual.nssurge.com/features/ip-rewrite.html>
