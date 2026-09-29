import Foundation
import NetworkExtension

/// Routes only the local remote-pairing peer. This is not a general VPN.
final class PacketTunnelProvider: NEPacketTunnelProvider {
    private var isRunning = false

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        let ipv4 = NEIPv4Settings(addresses: ["10.7.0.2"], subnetMasks: ["255.255.255.252"])
        ipv4.includedRoutes = [NEIPv4Route(destinationAddress: "10.7.0.1", subnetMask: "255.255.255.255")]
        ipv4.excludedRoutes = [.default()]
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "10.7.0.1")
        settings.ipv4Settings = ipv4
        setTunnelNetworkSettings(settings) { [weak self] error in
            guard error == nil else { completionHandler(error); return }
            self?.isRunning = true
            self?.reflectPackets()
            completionHandler(nil)
        }
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
