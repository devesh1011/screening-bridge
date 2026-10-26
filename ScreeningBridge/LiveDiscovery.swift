import Foundation

struct LiveCoordinates: Codable, Hashable { let latitude: Double; let longitude: Double }
struct LiveFilm: Codable, Hashable, Identifiable {
    let entityId: String
    let title: String
    let year: Int
    let director: String?
    var id: String { entityId }
    var film: Film { Film(id: entityId, title: title, year: year, director: director ?? "", image: title == "Perfect Days" ? "FilmCover" : "Programme") }
}
struct LiveVenue: Codable, Hashable, Identifiable {
    let entityId: String
    let name: String
    let address: String
    let coordinates: LiveCoordinates
    let timezone: String
    var id: String { entityId }
}
struct LiveCatalog: Codable {
    let films: [LiveFilm]
    let venues: [LiveVenue]
    let scope: String
}
struct LiveRequest: Encodable {
    var schemaVersion = "1.0"
    let requestId: String
    let briefRevision: Int
    var mode = "live"
    let film: LiveFilm
    let venue: LiveVenue
    let screeningAt: String
    let radiusM: Int
    let categories: [String]
    var excludedPartnerIds: [String] = []
    let notes: String
}
struct LiveSource: Codable, Hashable {
    let sourceId: String
    let url: URL
    let title: String
    let retrievedAt: Date
    var evidence: EvidenceSource { EvidenceSource(id: sourceId, title: title, url: url, retrievedAt: retrievedAt) }
}
struct LiveFact: Codable, Hashable { let text: String; let sourceIds: [String] }
struct LiveSignal: Codable, Hashable {
    let queryId: String
    let filmEntityId: String
    let candidatePoolIds: [String]
    let returnedRank: Int
    let affinity: Double
    let retrievedAt: Date
}
struct LiveRecommendation: Codable, Hashable {
    let partnerId: String
    let name: String
    let category: String
    let address: String
    let distanceM: Double
    let identitySourceIds: [String]
    let facts: [LiveFact]
    let culturalSignal: LiveSignal
    let interpretation: String
    let proposedActivity: String
    let introduction: String
    let stillToConfirm: [String]

    func partner(sources: [LiveSource]) throws -> Partner {
        let refs = Set(identitySourceIds + facts.flatMap(\.sourceIds))
        guard !refs.isEmpty, refs.isSubset(of: Set(sources.map(\.sourceId))) else { throw DiscoveryClientError.invalidResponse }
        let categoryName = ["bookshop": "Bookshop", "record_shop": "Record shop", "ceramics_studio": "Ceramics studio"][category] ?? category
        var partner = Partner(id: partnerId, name: name, category: categoryName, image: "", walkingMinutes: 0, distanceMiles: distanceM / 1609.344, rationale: proposedActivity, connection: interpretation, idea: proposedActivity, activity: proposedActivity)
        partner.evidence = PartnerEvidence(facts: facts.map(\.text), sources: sources.filter { refs.contains($0.sourceId) }.map(\.evidence), researchedAt: culturalSignal.retrievedAt, qlooRank: culturalSignal.returnedRank, qlooAffinity: culturalSignal.affinity, qlooQueryID: culturalSignal.queryId, filmEntityID: culturalSignal.filmEntityId, candidatePoolIDs: culturalSignal.candidatePoolIds, introduction: introduction, stillToConfirm: stillToConfirm)
        return partner
    }
}
struct LiveEvent: Decodable {
    let schemaVersion: String
    let requestId: String
    let briefRevision: Int
    let mode: String
    let sequence: Int
    let type: String
    let stage: String?
    let message: String?
    let recommendations: [LiveRecommendation]?
    let sources: [LiveSource]?
    let warnings: [String]?
}

enum DiscoveryClientError: LocalizedError {
    case notConfigured, rejected(Int), interrupted, invalidResponse
    var errorDescription: String? {
        switch self {
        case .notConfigured: "Live discovery is not configured. Open Preferences to check the backend connection."
        case .rejected(let status): status == 401 ? "This backend needs a valid access token. Check Preferences." : status == 429 ? "Research is busy or its daily limit has been reached. Please try later." : "The backend could not start this search (\(status)). Your brief is safe."
        case .interrupted: "The connection ended before research finished. Your brief is safe; try again."
        case .invalidResponse: "The backend returned an unsupported result. Your brief is safe; try again."
        }
    }
}

protocol DiscoveryServing {
    func catalog() async throws -> LiveCatalog
    func discover(_ request: LiveRequest, onEvent: @escaping @MainActor (LiveEvent) throws -> Void) async throws
}

struct LiveConfiguration: Decodable {
    let backendURL: String
    let accessToken: String
    static var current: LiveConfiguration {
        let bundled = Bundle.main.url(forResource: "LiveConfig", withExtension: "json").flatMap { try? Data(contentsOf: $0) }.flatMap { try? JSONDecoder().decode(LiveConfiguration.self, from: $0) }
        return LiveConfiguration(backendURL: UserDefaults.standard.string(forKey: "backendURL") ?? bundled?.backendURL ?? "", accessToken: bundled?.accessToken ?? "")
    }
}

struct LiveDiscoveryClient: DiscoveryServing {
    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let value = try decoder.singleValueContainer().decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: value) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: value) else { throw DiscoveryClientError.invalidResponse }
            return date
        }
        return decoder
    }

    private func request(path: String) throws -> URLRequest {
        let config = LiveConfiguration.current
        guard let base = URL(string: config.backendURL), ["https", "http"].contains(base.scheme ?? ""), base.host != nil else { throw DiscoveryClientError.notConfigured }
        var request = URLRequest(url: base.appending(path: path))
        request.timeoutInterval = 100
        if !config.accessToken.isEmpty { request.setValue("Bearer \(config.accessToken)", forHTTPHeaderField: "Authorization") }
        let sessionID = UserDefaults.standard.string(forKey: "discoverySessionID") ?? UUID().uuidString
        UserDefaults.standard.set(sessionID, forKey: "discoverySessionID")
        request.setValue(sessionID, forHTTPHeaderField: "X-Session-ID")
        return request
    }

    func catalog() async throws -> LiveCatalog {
        let (data, response) = try await URLSession.shared.data(for: request(path: "v1/catalog"))
        guard let response = response as? HTTPURLResponse, response.statusCode == 200 else { throw DiscoveryClientError.invalidResponse }
        return try Self.decoder().decode(LiveCatalog.self, from: data)
    }

    func discover(_ payload: LiveRequest, onEvent: @escaping @MainActor (LiveEvent) throws -> Void) async throws {
        var request = try request(path: "v1/discoveries")
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let encoder = JSONEncoder(); encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(payload)
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let response = response as? HTTPURLResponse else { throw DiscoveryClientError.invalidResponse }
        guard response.statusCode == 200 else { throw DiscoveryClientError.rejected(response.statusCode) }
        var terminal = false
        var lastSequence = 0
        for try await line in bytes.lines {
            try Task.checkCancellation()
            guard line.hasPrefix("data: ") else { continue }
            guard !terminal else { throw DiscoveryClientError.invalidResponse }
            let event = try Self.decoder().decode(LiveEvent.self, from: Data(line.dropFirst(6).utf8))
            guard event.schemaVersion == "1.0", event.mode == "live", event.requestId.lowercased() == payload.requestId.lowercased(), event.briefRevision == payload.briefRevision, event.sequence > lastSequence else { throw DiscoveryClientError.invalidResponse }
            guard ["progress", "completed", "no_matches", "needs_input", "unavailable", "cancelled"].contains(event.type) else { throw DiscoveryClientError.invalidResponse }
            lastSequence = event.sequence
            terminal = event.type != "progress"
            try await onEvent(event)
        }
        if !terminal { throw DiscoveryClientError.interrupted }
    }
}
