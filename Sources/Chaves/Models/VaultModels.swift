import Foundation

struct VaultPayload: Codable {
    var ok: Bool
    var keys: [KeyRecord]
    var stats: VaultStats
    var credits: CreditsPayload?
    var store: StoreInfo?
    var error: String?
}

struct VaultStats: Codable {
    var configured: Int
    var total: Int
    var missing: Int
    var withCredit: Int

    enum CodingKeys: String, CodingKey {
        case configured, total, missing
        case withCredit = "with_credit"
    }
}

struct StoreInfo: Codable {
    var mongodbURI: String
    var mongodbDB: String
    var qclawRoot: String

    enum CodingKeys: String, CodingKey {
        case mongodbURI = "mongodb_uri"
        case mongodbDB = "mongodb_db"
        case qclawRoot = "qclaw_root"
    }
}

struct CreditsPayload: Codable {
    var updatedAt: String?
    var providers: [String: CreditSnapshot]

    enum CodingKeys: String, CodingKey {
        case updatedAt = "updated_at"
        case providers
    }
}

struct CreditSnapshot: Codable, Hashable {
    var ok: Bool
    var provider: String
    var status: String
    var label: String
    var detail: String
    var balance: Double?
    var unit: String
    var error: String?

    var isHealthy: Bool { ok }
}

struct KeyRecord: Codable, Identifiable, Hashable {
    var name: String
    var label: String
    var category: String
    var categoryLabel: String
    var hint: String
    var creditProvider: String
    var configured: Bool
    var masked: String
    var source: String
    var credit: CreditSnapshot?

    var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name, label, category, hint, configured, masked, source, credit
        case categoryLabel = "category_label"
        case creditProvider = "credit_provider"
    }
}

struct ServiceStatus: Codable {
    var ok: Bool
    var mongodb: Bool
    var error: String?
    var configured: Int
    var store: StoreInfo?
}

struct MutationResult: Codable {
    var ok: Bool
    var error: String?
    var name: String?
    var masked: String?
    var deleted: [String]?
}

enum SidebarFilter: String, CaseIterable, Identifiable {
    case all
    case configured
    case missing
    case llm
    case media
    case voice
    case aws
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "Todas"
        case .configured: return "No cofre"
        case .missing: return "Faltando"
        case .llm: return "Modelos"
        case .media: return "Imagem e vídeo"
        case .voice: return "Voz e música"
        case .aws: return "AWS"
        case .other: return "Outras"
        }
    }

    var symbol: String {
        switch self {
        case .all: return "key.fill"
        case .configured: return "checkmark.seal"
        case .missing: return "exclamationmark.triangle"
        case .llm: return "brain.head.profile"
        case .media: return "film.stack"
        case .voice: return "waveform"
        case .aws: return "externaldrive.connected.to.line.below"
        case .other: return "ellipsis.circle"
        }
    }

    func matches(_ key: KeyRecord) -> Bool {
        switch self {
        case .all: return true
        case .configured: return key.configured
        case .missing: return !key.configured
        case .llm: return key.category == "llm"
        case .media: return key.category == "media"
        case .voice: return key.category == "voice"
        case .aws: return key.category == "aws"
        case .other: return !["llm", "media", "voice", "aws"].contains(key.category)
        }
    }
}
