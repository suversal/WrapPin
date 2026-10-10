# Loon setup

[简体中文](LoonIntegration.zh-CN.md)

WrapPin can use Loon as its tunnel handoff app. The Standard edition always offers this choice; the Tunnel edition offers it when its built-in tunnel is not in use. This integration does not read or change Loon's VPN state. When the paired-device channel is unreachable, WrapPin uses Loon's official URL scheme `loon://on` to ask it to turn on its VPN, then keeps checking for the pairing service.

## Requirements

- Loon build 1007 (3.5.3) or later.
- The plugin below is enabled, so the route and IP Rewrite settings are in effect.

```ini
[General]
ipv6-vif = off
include-tun = 10.7.0.1/32

[IP Rewrite]
10.7.0.1 = reflect
```

`include-tun` sends connections to `10.7.0.1` into Loon's TUN. `reflect` sends them back to the device, so WrapPin can reach the iPhone's own developer services. `ipv6-vif = off` keeps tools that depend on this IPv4 on-device channel from choosing an IPv6 VPN interface.

Loon's documentation says `include-tun` may be set in the main configuration or in a plugin, while the IP Rewrite needed for on-device loopback is declared in a plugin. Importing the repository's [`WrapPin-Loon.lpx`](WrapPin-Loon.lpx) is therefore the recommended route. The plugin carries a `loon_version=3.5.3(1007)` requirement, so an older Loon does not appear to enable it while lacking these settings.

## WrapPin settings

1. In WrapPin, choose Loon under **Settings → Tunnel App**.
2. Pair the device once.
3. Start a location. If the device channel is unreachable, WrapPin asks Loon to turn on its VPN.
4. After Loon turns on, return to WrapPin manually; WrapPin keeps checking the connection.

If the check fails on mobile data, verify on Wi-Fi first. WrapPin can only check whether the paired-device channel is reachable; it cannot read Loon's VPN switch.

## References

- Loon URL scheme documentation: <https://nsloon.app/docs/Scheme/>
- Loon `include-tun` documentation: <https://nsloon.app/docs/General/#include-tun>
