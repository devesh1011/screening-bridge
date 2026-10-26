import Foundation

enum PartnerCategory: String, CaseIterable {
    case bookshop, record_shop, ceramics_studio
    var display: (label: String, symbol: String) {
        switch self {
        case .bookshop: ("Bookshop", "books.vertical")
        case .record_shop: ("Record shop", "opticaldisc")
        case .ceramics_studio: ("Ceramics studio", "hands.sparkles")
        }
    }
    static func fromLabel(_ label: String) -> PartnerCategory? { allCases.first { $0.display.label == label } }
}

struct Film: Codable, Hashable, Identifiable {
    let id: String
    let title: String
    let year: Int
    let director: String
    let image: String

    static let perfectDays = Film(id: "perfect-days-2023", title: "Perfect Days", year: 2023, director: "Wim Wenders", image: "FilmCover")
}

struct Partner: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let category: String
    let image: String
    let walkingMinutes: Int
    let distanceMiles: Double
    let rationale: String
    let connection: String
    let idea: String
    let activity: String
    var evidence: PartnerEvidence? = nil

    var subtitle: String {
        evidence == nil ? "\(category) · \(walkingMinutes) min walk" : "\(category) · \(distanceMiles.formatted(.number.precision(.fractionLength(1)))) mi straight-line"
    }
}

struct PartnerEvidence: Codable, Hashable {
    var facts: [String]
    var sources: [EvidenceSource]
    var researchedAt: Date
    var qlooRank: Int
    var qlooAffinity: Double
    var qlooQueryID: String
    var filmEntityID: String
    var candidatePoolIDs: [String]
    var introduction: String
    var stillToConfirm: [String]
}

struct EvidenceSource: Codable, Hashable, Identifiable {
    var id: String
    var title: String
    var url: URL
    var retrievedAt: Date
}

enum SampleContent {
    static let partners = [
        Partner(id: "books", name: "Chapter House Books", category: "Bookshop", image: "Bookshop", walkingMinutes: 12, distanceMiles: 0.6,
                rationale: "Try a reading before the screening.",
                connection: "A literary audience could connect with Perfect Days’ quiet, observant storytelling.",
                idea: "Invite the bookshop to host a short reading before the film.", activity: "Reading + screening"),
        Partner(id: "records", name: "Northline Records", category: "Record shop", image: "RecordShop", walkingMinutes: 18, distanceMiles: 0.9,
                rationale: "Explore a pre-film listening session.",
                connection: "The film’s love of music offers a starting point for a conversation with a local record shop.",
                idea: "Explore a short listening session before the screening.", activity: "Listening session + screening"),
        Partner(id: "studio", name: "Sunday Studio", category: "Ceramics studio", image: "Studio", walkingMinutes: 9, distanceMiles: 0.4,
                rationale: "Consider a quiet-making event.",
                connection: "The attention to daily rituals could inspire a thoughtful making-and-screening programme.",
                idea: "Discuss a small making session followed by the film.", activity: "Making session + screening")
    ]
    static func partner(_ id: String) -> Partner? { partners.first { $0.id == id } }
}

struct ScreeningDraft: Codable, Equatable, Identifiable {
    var id = UUID()
    var film: Film?
    var cinema = "Lantern Cinema"
    var area = "Brooklyn"
    var date = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 30, hour: 19)) ?? Date()
    var radius = 2
    var notes = ""
    var selectedIDs: Set<String> = []
    var introductions: [String: String] = [:]
    var completedSteps: Set<String> = []
    // Optional fields preserve compatibility with earlier ID-only sample archives.
    var discoveryMode: String?
    var partnerSnapshots: [Partner]?
    var researchWarnings: [String]?
    var researchFingerprint: String?
    var briefRevision: Int?
    var allowedPartnerCategories: [String]?
    var venueTimezone: String?
    // Full wire result retains coordinates, address, claim/source associations,
    // omitted IDs and provenance even when the presentation model is simpler.
    var discoveryPayload: Data?

    var isLive: Bool { discoveryMode == "live" }

    var isValid: Bool { film != nil && !cinema.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !area.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var selectedPartners: [Partner] {
        (partnerSnapshots ?? (isLive ? [] : SampleContent.partners)).filter { selectedIDs.contains($0.id) }
    }
    var dateLabel: String {
        var format = Date.FormatStyle.dateTime.weekday(.abbreviated).day().month(.abbreviated)
        format.timeZone = TimeZone(identifier: venueTimezone ?? "") ?? .current
        return date.formatted(format)
    }
    var timeLabel: String {
        var format = Date.FormatStyle(date: .omitted, time: .shortened)
        format.timeZone = TimeZone(identifier: venueTimezone ?? "") ?? .current
        return date.formatted(format)
    }

    func introduction(for partner: Partner) -> String {
        introductions[partner.id] ?? partner.evidence?.introduction ?? "Hello, we’re planning a screening of \(film?.title ?? "the film") at \(cinema) on \(date.formatted(.dateTime.day().month(.wide))). Would you be open to discussing \(partner.id == "books" ? "a short reading before the film" : partner.id == "records" ? "a listening session before the film" : "a small making session alongside the film")? We can work out the format together."
    }
}

struct SavedScreening: Codable, Identifiable, Equatable {
    var draft: ScreeningDraft
    var savedAt: Date
    var id: UUID { draft.id }
}

enum ScreenRoute: Hashable {
    case film, details, research, partners, partner(String), plan, recovery(SearchOutcome)
}

enum SearchOutcome: String, CaseIterable, Hashable, Identifiable {
    case ready = "Partner results", noMatches = "No matches", interrupted = "Search interrupted"
    var id: String { rawValue }
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case system = "System", light = "Light", dark = "Dark"
    var id: String { rawValue }
}
