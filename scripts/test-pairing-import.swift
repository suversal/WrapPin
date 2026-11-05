import CryptoKit
import Foundation

@main
struct PairingImportCheck {
    static func main() async throws {
        for major in [18, 26] {
            for minor in [0, 3, 4, 7] {
                precondition(!DevicePairingSupport.supportsOnDevicePairing(
                    on: .init(majorVersion: major, minorVersion: minor, patchVersion: 2)))
            }
        }
        for major in [27, 28] {
            precondition(DevicePairingSupport.supportsOnDevicePairing(
                on: .init(majorVersion: major, minorVersion: 0, patchVersion: 0)))
        }

        let key = Curve25519.Signing.PrivateKey()
        let record: [String: Any] = [
            "public_key": key.publicKey.rawRepresentation,
            "private_key": key.rawRepresentation,
            "identifier": "synthetic-test-record",
            "alt_irk": Data(repeating: 7, count: 16)
        ]
        let date = Date(timeIntervalSince1970: 1_000)
        func encode(_ value: Any, format: PropertyListSerialization.PropertyListFormat = .xml) throws -> Data {
            try PropertyListSerialization.data(fromPropertyList: value, format: format, options: 0)
        }
        let xml = try encode(record)
        let binary = try encode(record, format: .binary)
        let summary = try SecurePairingService.validate(xml, importedAt: date)
        precondition(summary.identifier == "synthetic-test-record" && summary.importedAt == date)
        let binarySummary = try SecurePairingService.validate(binary, importedAt: date)
        precondition(binarySummary == summary)
        // Pasting the XML has the same result as reading the file; no credentials are printed.
        let pasted = Data(String(decoding: xml, as: UTF8.self).utf8)
        let pastedSummary = try SecurePairingService.validate(pasted, importedAt: date)
        precondition(pastedSummary == summary)

        func reject(_ data: Data, as expected: PairingServiceError) {
            do {
                _ = try SecurePairingService.validate(data, importedAt: date)
                preconditionFailure("Invalid pairing record accepted")
            } catch let error as PairingServiceError {
                precondition(error == expected)
            } catch {
                preconditionFailure("Unexpected validation error")
            }
        }
        reject(Data("not a property list".utf8), as: .notAPropertyList)
        reject(try encode(["a", "b"]), as: .notRPPairing)
        reject(try encode(["HostID": "synthetic-host", "HostCertificate": Data([1])]), as: .lockdownRecord)
        var invalid = record
        invalid.removeValue(forKey: "alt_irk")
        reject(try encode(invalid), as: .missingDeviceIdentity)
        for value in [Data(repeating: 0, count: 15) as Any, "invalid" as Any] {
            invalid = record; invalid["alt_irk"] = value
            reject(try encode(invalid), as: .notRPPairing)
        }
        for field in ["public_key", "private_key"] {
            invalid = record; invalid[field] = Data(repeating: 0, count: 31)
            reject(try encode(invalid), as: .notRPPairing)
        }
        invalid = record; invalid["identifier"] = " \n "
        reject(try encode(invalid), as: .notRPPairing)
        invalid = record; invalid["public_key"] = Curve25519.Signing.PrivateKey().publicKey.rawRepresentation
        reject(try encode(invalid), as: .keyMismatch)

        // An invalid replacement must fail before attempting any Keychain write.
        let service = SecurePairingService()
        do {
            _ = try await service.importRecord(data: encode(["HostID": "synthetic-host"]))
            preconditionFailure("Lockdown record reached storage")
        } catch let error as PairingServiceError {
            precondition(error == .lockdownRecord)
        }
        print("Pairing import and iOS 26/27 capability checks passed; no Keychain writes made.")
    }
}
