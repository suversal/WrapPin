# Shadowrocket setup

[简体中文](ShadowrocketIntegration.zh-CN.md)

WrapPin can use Shadowrocket as its tunnel handoff app. The Standard edition always offers this choice; the Tunnel edition offers it when its built-in tunnel is not in use. This integration does not read or change Shadowrocket's VPN state. When the paired-device channel is unreachable, WrapPin uses the URL scheme `shadowrocket://connect` to ask it to connect its VPN, then keeps checking for the pairing service.

## Requirements

- Shadowrocket's Settings offer the **Include Route 10.7.0.1/32** switch (shown as “包含路由 10.7.0.1/32” in Chinese). If the switch is missing, update Shadowrocket first.
- That switch is turned on, under the last group of general options in Shadowrocket's Settings.

With the switch on, connections to `10.7.0.1` enter Shadowrocket's tunnel and come back to the device, so WrapPin can reach the iPhone's own developer services. No module import or configuration-file edit is needed.

## WrapPin settings

1. In WrapPin, choose Shadowrocket under **Settings → Tunnel App**.
2. Pair the device once.
3. Start a location. If the device channel is unreachable, WrapPin asks Shadowrocket to connect its VPN.
4. After Shadowrocket connects, return to WrapPin manually; WrapPin keeps checking the connection.

If the check fails on mobile data, verify on Wi-Fi first. WrapPin can only check whether the paired-device channel is reachable; it cannot read Shadowrocket's VPN switch.
