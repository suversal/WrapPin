import CryptoKit
import Foundation
import Security

struct PairingRecordSummary: Codable, Equatable, Sendable {
    let identifier: String
    let fingerprint: String
    let importedAt: Date
}

protocol PairingService: Sendable {
    func storedRecord() async throws -> PairingRecordSummary?
    func importRecord(from url: URL) async throws -> PairingRecordSummary
    func importRecord(data: Data) async throws -> PairingRecordSummary
    func storeGeneratedRecord(_ data: Data, hostAltIRK: Data?) async throws -> PairingRecordSummary
    func pairingRecordData() async throws -> Data?
    func removeRecord() async throws
}

actor SecurePairingService: PairingService {
    private let keychainService = "com.suversal.wrappin.rppairing"
    private let keychainAccount = "current-device"

    func storedRecord() throws -> PairingRecordSummary? {
        guard let stored = try readStoredRecord() else { return nil }
        return try Self.validate(stored.data, importedAt: stored.importedAt)
    }

    func importRecord(from url: URL) throws -> PairingRecordSummary {
        let hasScopedAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasScopedAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        return try importRecord(data: data)
    }

    func importRecord(data: Data) throws -> PairingRecordSummary {
        let importedAt = Date()
        let summary = try Self.validate(data, importedAt: importedAt)
        try save(StoredPairingRecord(data: data, importedAt: importedAt, hostAltIRK: nil))
        return summary
    }

    func storeGeneratedRecord(_ data: Data, hostAltIRK: Data?) throws -> PairingRecordSummary {
        if let hostAltIRK, hostAltIRK.count != 16 {
            throw PairingServiceError.invalidHostIdentity
        }

        let importedAt = Date()
        let summary = try Self.validate(data, importedAt: importedAt)
        try save(StoredPairingRecord(
            data: data,
            importedAt: importedAt,
            hostAltIRK: hostAltIRK
        ))
        return summary
    }

    func pairingRecordData() throws -> Data? {
        try readStoredRecord()?.data
    }

    func removeRecord() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw PairingServiceError.keychain(status)
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
    }

    private func readStoredRecord() throws -> StoredPairingRecord? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess, let data = result as? Data else {
            throw PairingServiceError.keychain(status)
        }

        do {
            return try PropertyListDecoder().decode(StoredPairingRecord.self, from: data)
        } catch {
            throw PairingServiceError.corruptStoredRecord
        }
    }

    private func save(_ record: StoredPairingRecord) throws {
        let encoded = try PropertyListEncoder().encode(record)
        let attributes: [String: Any] = [kSecValueData as String: encoded]
        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)

        if updateStatus == errSecSuccess {
            return
        }

        guard updateStatus == errSecItemNotFound else {
            throw PairingServiceError.keychain(updateStatus)
        }

        var addQuery = baseQuery
        addQuery[kSecValueData as String] = encoded
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw PairingServiceError.keychain(addStatus)
        }
    }

    static func validate(_ data: Data, importedAt: Date) throws -> PairingRecordSummary {
        let propertyList: Any
        do {
            propertyList = try PropertyListSerialization.propertyList(from: data, format: nil)
        } catch {
            throw PairingServiceError.notAPropertyList
        }

        guard let dictionary = propertyList as? [String: Any] else {
            throw PairingServiceError.notRPPairing
        }

        if dictionary["public_key"] == nil, dictionary["private_key"] == nil,
           dictionary["HostID"] != nil || dictionary["HostCertificate"] != nil {
            throw PairingServiceError.lockdownRecord
        }

        guard
            let publicKey = dictionary["public_key"] as? Data,
            publicKey.count == 32,
            let privateKey = dictionary["private_key"] as? Data,
            privateKey.count == 32,
            let identifier = dictionary["identifier"] as? String,
            !identifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw PairingServiceError.notRPPairing
        }

        // Discovery and the native session both require this device identity.
        guard dictionary["alt_irk"] != nil else {
            throw PairingServiceError.missingDeviceIdentity
        }
        guard let altIRK = dictionary["alt_irk"] as? Data, altIRK.count == 16 else {
            throw PairingServiceError.notRPPairing
        }

        do {
            let signingKey = try Curve25519.Signing.PrivateKey(rawRepresentation: privateKey)
            guard signingKey.publicKey.rawRepresentation == publicKey else {
                throw PairingServiceError.keyMismatch
            }
        } catch let error as PairingServiceError {
            throw error
        } catch {
            throw PairingServiceError.notRPPairing
        }

        let digest = SHA256.hash(data: publicKey)
        let fingerprint = digest.prefix(6).map { String(format: "%02X", $0) }.joined(separator: ":")

        return PairingRecordSummary(
            identifier: identifier,
            fingerprint: fingerprint,
            importedAt: importedAt
        )
    }
}

private struct StoredPairingRecord: Codable {
    let data: Data
    let importedAt: Date
    let hostAltIRK: Data?
}

enum PairingServiceError: LocalizedError, Equatable {
    case notAPropertyList
    case notRPPairing
    case lockdownRecord
    case missingDeviceIdentity
    case keyMismatch
    case invalidHostIdentity
    case corruptStoredRecord
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case .notAPropertyList:
            String(localized: "That file is not a valid property list.")
        case .notRPPairing:
            String(localized: "That is not a valid RPPairing file.")
        case .lockdownRecord:
            String(localized: "This is a Lockdown pairing file. In idevice_pair on your computer, choose Remote pairing (RPPairing), create a new file, and import it here.")
        case .missingDeviceIdentity:
            String(localized: "This RPPairing file is missing its device identity. Create a new Remote pairing file with idevice_pair and import it again.")
        case .keyMismatch:
            String(localized: "The pairing file's public and private keys do not match.")
        case .invalidHostIdentity:
            String(localized: "The generated pairing identity was not valid.")
        case .corruptStoredRecord:
            String(localized: "The stored pairing record could not be read.")
        case .keychain(let status):
            String(format: NSLocalizedString("The pairing record could not be stored securely (Keychain error %d).", comment: ""), status)
        }
    }
}
