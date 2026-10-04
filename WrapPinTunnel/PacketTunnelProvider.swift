import Foundation
import NetworkExtension

/// Routes only the local remote-pairing peer. This is not a general VPN.
final class PacketTunnelProvider: NEPacketTunnelProvider {
    private var isRunning = false

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        let configuredAddress = (protocolConfiguration as? NETunnelProviderProtocol)?
            .providerConfiguration?["localAddress"] as? String ?? "10.7.0.2/30"
        guard let (address, mask) = Self.parseLocalAddress(configuredAddress) else {
            completionHandler(NSError(domain: "WrapPinTunnelConfiguration", code: 1,
                                      userInfo: [NSLocalizedDescriptionKey: "Invalid local tunnel address"]))
            return
        }
        let ipv4 = NEIPv4Settings(addresses: [address], subnetMasks: [mask])
        ipv4.includedRoutes = [NEIPv4Route(destinationAddress: "10.7.0.1", subnetMask: "255.255.255.255")]
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "10.7.0.1")
        settings.ipv4Settings = ipv4
        setTunnelNetworkSettings(settings) { [weak self] error in
            guard error == nil else { completionHandler(error); return }
            self?.isRunning = true
            self?.reflectPackets()
            completionHandler(nil)
        }
    }

    private static func parseLocalAddress(_ value: String) -> (String, String)? {
        let parts = value.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 2, let prefix = Int(parts[1]), (1...32).contains(prefix) else { return nil }
        let octets = parts[0].split(separator: ".", omittingEmptySubsequences: false)
        guard octets.count == 4 else { return nil }
        let numbers = octets.compactMap { Int($0) }
        guard numbers.count == 4, numbers.allSatisfy({ (0...255).contains($0) }),
              (1...223).contains(numbers[0]), numbers[0] != 127,
              numbers != [10, 7, 0, 1] else { return nil }
        let address = numbers.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        let mask = UInt32.max << (32 - prefix)
        if prefix < 31 && (address & ~mask == 0 || address & ~mask == ~mask) { return nil }
        let maskText = [24, 16, 8, 0].map { String((mask >> $0) & 0xff) }.joined(separator: ".")
        return (numbers.map(String.init).joined(separator: "."), maskText)
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        isRunning = false
        completionHandler()
    }

    private func reflectPackets() {
        packetFlow.readPackets { [weak self] packets, protocols in
            guard let self, self.isRunning else { return }
            var reflected: [Data] = []
            var reflectedProtocols: [NSNumber] = []
            for index in packets.indices where protocols.indices.contains(index) && protocols[index].int32Value == AF_INET {
                // Swap IPv4 source and destination, as the local pairing service
                // is reached through the virtual peer address. Do not modify payloads.
                guard packets[index].count >= 20,
                      packets[index][0] >> 4 == 4,
                      Int(packets[index][0] & 0x0F) * 4 <= packets[index].count else { continue }
                var packet = packets[index]
                packet.withUnsafeMutableBytes { bytes in
                    guard let base = bytes.baseAddress else { return }
                    let header = base.assumingMemoryBound(to: UInt8.self)
                    for offset in 0..<4 {
                        let oldSource = header[12 + offset]
                        header[12 + offset] = header[16 + offset]
                        header[16 + offset] = oldSource
                    }
                }
                reflected.append(packet)
                reflectedProtocols.append(protocols[index])
            }
            if !reflected.isEmpty {
                self.packetFlow.writePackets(reflected, withProtocols: reflectedProtocols)
            }
            self.reflectPackets()
        }
    }
}
