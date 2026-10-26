import Foundation
import Observation
import UIKit

struct PlanArchive {
    var plans: [SavedScreening] = []
    var draft: ScreeningDraft?
}

struct LocalPlanRepository {
    let directory: URL

    init(directory: URL = URL.applicationSupportDirectory.appending(path: "ScreeningBridge", directoryHint: .isDirectory)) {
        self.directory = directory
    }

    func loadPlans() throws -> [SavedScreening] {
        let file = directory.appending(path: "plans.json")
        guard FileManager.default.fileExists(atPath: file.path) else { return [] }
        return try JSONDecoder().decode([SavedScreening].self, from: Data(contentsOf: file))
    }

    func savePlans(_ plans: [SavedScreening]) throws {
        try write(plans, filename: "plans.json")
    }

    func loadDraft() throws -> ScreeningDraft? {
        let file = directory.appending(path: "draft.json")
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        return try JSONDecoder().decode(ScreeningDraft.self, from: Data(contentsOf: file))
    }

    func saveDraft(_ draft: ScreeningDraft) throws { try write(draft, filename: "draft.json") }

    func clearDraft() throws {
        let file = directory.appending(path: "draft.json")
        if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }
    }

    private func write<T: Encodable>(_ value: T, filename: String) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(value).write(to: directory.appending(path: filename), options: .atomic)
    }
}

@MainActor
enum AppHaptics {
    static var enabled: Bool {
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") { return false }
        return UserDefaults.standard.object(forKey: "hapticsEnabled") == nil || UserDefaults.standard.bool(forKey: "hapticsEnabled")
    }
    static func selection() {
        guard enabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }
    static func success() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    static func failure() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}

@Observable @MainActor
final class ScreeningStore {
    var path: [ScreenRoute] = []
    var draft = ScreeningDraft()
    var saved: [SavedScreening] = []
    var hasRecoverableDraft = false
    var persistenceError: String?
    var stage = 0
    var isSaving = false
    var saveError: String?
    var confirmation: SavedScreening?
    var resultGeneration = UUID()
    var revealedGeneration: UUID?
    var nextSearchOutcome: SearchOutcome = .ready
    var failNextSave = false
    var slowSave = false
    var liveCatalog: LiveCatalog?
    var catalogError: String?
    var recoveryReason: String?
    var recoveryInputField: String?
    var activeRequestID: String?
    var allowedCategories: Set<String> {
        get { Set(draft.allowedPartnerCategories ?? PartnerCategory.allCases.map { $0.display.label }) }
        set { draft.allowedPartnerCategories = newValue.sorted() }
    }
    @ObservationIgnored let repository: LocalPlanRepository
    @ObservationIgnored let discoveryService: any DiscoveryServing

    init(repository: LocalPlanRepository = LocalPlanRepository(), discoveryService: any DiscoveryServing = LiveDiscoveryClient()) {
        self.discoveryService = discoveryService
        let isolated = ProcessInfo.processInfo.arguments.contains("--ui-testing") && repository.directory == LocalPlanRepository().directory
        self.repository = isolated ? LocalPlanRepository(directory: URL.applicationSupportDirectory.appending(path: "ScreeningBridgeUITesting", directoryHint: .isDirectory)) : repository
        do {
            saved = try self.repository.loadPlans()
            if let restored = try self.repository.loadDraft() {
                draft = restored
                hasRecoverableDraft = true
            }
        } catch {
            persistenceError = "Your saved data couldn’t be opened. The existing files have been kept."
        }
        configurePreview()
    }

    var visiblePartners: [Partner] {
        let partners = draft.isLive ? (hasCurrentResults ? draft.partnerSnapshots ?? [] : []) : SampleContent.partners
        return partners.filter { $0.distanceMiles <= Double(draft.radius) && allowedCategories.contains($0.category) }
    }

    var briefFingerprint: String {
        [draft.film?.id ?? "", draft.cinema, draft.area, String(draft.date.timeIntervalSince1970), String(draft.radius), draft.notes, allowedCategories.sorted().joined(separator: ",")].joined(separator: "\u{1F}")
    }
    var hasCurrentResults: Bool { !draft.isLive || draft.researchFingerprint == briefFingerprint }
    func partner(_ id: String) -> Partner? { (draft.partnerSnapshots ?? (draft.isLive ? [] : SampleContent.partners)).first { $0.id == id } }

    func applyFilters(radius: Int, categories: Set<String>) {
        draft.radius = radius; allowedCategories = categories
        if draft.isLive {
            // Retain eligible selections until the new result set arrives.
            if !path.isEmpty { path[path.count - 1] = .research }
        } else {
            draft.selectedIDs.formIntersection(visiblePartners.map(\.id))
            if visiblePartners.isEmpty, !path.isEmpty { path[path.count - 1] = .recovery(.noMatches) }
        }
        persistDraft()
    }

    func setDiscoveryMode(_ mode: String) {
        guard (mode == "live") != draft.isLive else { return }
        activeRequestID = nil
        draft = ScreeningDraft()
        draft.discoveryMode = mode
        if mode == "live" {
            draft.cinema = ""; draft.area = ""
            var calendar = Calendar.current
            calendar.timeZone = TimeZone(identifier: "America/New_York")!
            draft.date = calendar.date(from: DateComponents(year: 2026, month: 10, day: 30, hour: 19)) ?? Date()
        }
        catalogError = nil; recoveryReason = nil
        persistDraft()
    }

    func loadLiveCatalog() async {
        do {
            let catalog = try await discoveryService.catalog()
            try Task.checkCancellation()
            liveCatalog = catalog; catalogError = nil
            if draft.isLive, draft.cinema.isEmpty, let venue = catalog.venues.first {
                draft.cinema = venue.name; draft.area = venue.address
                draft.venueTimezone = venue.timezone
            }
        } catch is CancellationError { return }
        catch {
            catalogError = error.localizedDescription
        }
    }

    func runSearch() async {
        guard draft.isLive else { await runSampleSearch(); return }
        guard activeRequestID == nil else { return }
        if liveCatalog == nil { await loadLiveCatalog() }
        guard let film = liveCatalog?.films.first(where: { $0.entityId == draft.film?.id }), let venue = liveCatalog?.venues.first(where: { $0.name == draft.cinema && $0.address == draft.area }) else {
            recoveryReason = catalogError ?? "Choose a supported film and venue before researching."
            if path.last == .research { path[path.count - 1] = .recovery(.interrupted) }
            return
        }
        let id = UUID().uuidString
        activeRequestID = id
        defer { if activeRequestID == id { activeRequestID = nil } }
        draft.briefRevision = (draft.briefRevision ?? 0) + 1
        let revision = draft.briefRevision!
        let fingerprint = briefFingerprint
        let request = LiveRequest(requestId: id, briefRevision: revision, film: film, venue: venue, screeningAt: ISO8601DateFormatter().string(from: draft.date), radiusM: Int((Double(draft.radius) * 1609.344).rounded()), categories: allowedCategories.compactMap { PartnerCategory.fromLabel($0)?.rawValue }.sorted(), notes: draft.notes)
        stage = 0; recoveryReason = nil; recoveryInputField = nil
        persistDraft()
        do {
            try await discoveryService.discover(request) { [self] event in
                try Task.checkCancellation()
                guard activeRequestID == id, briefFingerprint == fingerprint, event.requestId.lowercased() == id.lowercased(), event.briefRevision == revision, path.last == .research else { return }
                if event.type == "progress" {
                    stage = ["resolving": 0, "researching": 1, "ranking": 2, "preparing": 3][event.stage ?? ""] ?? stage
                } else if event.type == "completed" {
                    guard let rows = event.recommendations, (1...3).contains(rows.count), let sources = event.sources, let rawJSON = event.rawJSON else { throw DiscoveryClientError.invalidResponse }
                    let partners = try rows.map { try $0.partner(sources: sources) }
                    guard Set(partners.map(\.id)).count == partners.count, rows.allSatisfy({ $0.culturalSignal.filmEntityId.lowercased() == film.entityId.lowercased() }) else { throw DiscoveryClientError.invalidResponse }
                    draft.partnerSnapshots = partners
                    draft.discoveryPayload = rawJSON
                    draft.researchWarnings = event.warnings
                    draft.researchFingerprint = fingerprint
                    draft.selectedIDs.formIntersection(partners.map(\.id))
                    resultGeneration = UUID()
                    persistDraft()
                    path[path.count - 1] = .partners
                } else {
                    recoveryReason = event.message ?? "Research could not finish. Your brief is safe."
                    recoveryInputField = event.type == "needs_input" ? event.inputField : nil
                    path[path.count - 1] = .recovery(event.type == "no_matches" ? .noMatches : .interrupted)
                }
            }
        } catch is CancellationError { return }
        catch {
            guard activeRequestID == id, path.last == .research else { return }
            recoveryReason = error.localizedDescription
            path[path.count - 1] = .recovery(.interrupted)
        }
    }

    func newScreening() {
        activeRequestID = nil
        draft = ScreeningDraft()
        saveError = nil
        path = [.film]
    }

    func resumeDraft() { path = draft.film == nil ? [.film] : [.details] }

    @discardableResult func persistDraft() -> Bool {
        do {
            try repository.saveDraft(draft)
            hasRecoverableDraft = true
            persistenceError = nil
            return true
        } catch {
            persistenceError = "Your draft couldn’t be saved on this device. Keep the app open and try again."
            return false
        }
    }

    func toggle(_ partner: Partner) {
        if draft.selectedIDs.contains(partner.id) { draft.selectedIDs.remove(partner.id) }
        else { draft.selectedIDs.insert(partner.id) }
        AppHaptics.selection()
        persistDraft()
    }

    func runSampleSearch() async {
        stage = 0
        let outcome = nextSearchOutcome
        nextSearchOutcome = .ready
        do {
            for step in 0..<3 {
                try Task.checkCancellation()
                stage = step
                try await Task.sleep(for: .milliseconds(520))
            }
            try Task.checkCancellation()
            resultGeneration = UUID()
            let resolved: SearchOutcome = outcome == .ready && visiblePartners.isEmpty ? .noMatches : outcome
            guard path.last == .research else { return }
            path[path.count - 1] = resolved == .ready ? .partners : .recovery(resolved)
        } catch { /* Leaving the view cancels only the sample search. */ }
    }

    func savePlan() async {
        guard !isSaving, draft.isValid, !draft.selectedIDs.isEmpty, hasCurrentResults else { return }
        isSaving = true
        saveError = nil
        defer { isSaving = false }
        do {
            if slowSave { try await Task.sleep(for: .seconds(1.5)) }
            try Task.checkCancellation()
            if failNextSave {
                failNextSave = false
                throw CocoaError(.fileWriteUnknown)
            }
            var snapshot = draft
            if !snapshot.isLive && snapshot.partnerSnapshots == nil { snapshot.partnerSnapshots = SampleContent.partners }
            for partner in snapshot.selectedPartners where snapshot.introductions[partner.id] == nil {
                snapshot.introductions[partner.id] = snapshot.introduction(for: partner)
            }
            let plan = SavedScreening(draft: snapshot, savedAt: Date())
            var updated = saved.filter { $0.id != plan.id }
            updated.insert(plan, at: 0)
            try repository.savePlans(updated)
            saved = updated
            draft = snapshot
            hasRecoverableDraft = false
            do { try repository.clearDraft() } catch { persistenceError = "The plan is saved, but its temporary draft couldn’t be cleared." }
            confirmation = plan
            AppHaptics.success()
        } catch is CancellationError {
            return
        } catch {
            saveError = "Your edits are still here. Please try again."
            AppHaptics.failure()
        }
    }

    func open(_ plan: SavedScreening) {
        draft = plan.draft
        saveError = nil
        path = [.plan]
    }

    func showSavedPlan() { path = [.plan]; confirmation = nil }
    func finish() { path = []; confirmation = nil }

    func preview(_ name: String) {
        draft = ScreeningDraft()
        draft.film = .perfectDays
        draft.selectedIDs = ["books", "records"]
        saveError = nil
        switch name {
        case "empty": path = []; saved = []
        case "film": draft.film = nil; path = [.film]
        case "details": path = [.details]
        case "research": path = [.details, .research]
        case "partners": draft.selectedIDs = []; path = [.details, .partners]
        case "selected": path = [.details, .partners]
        case "detail": path = [.partners, .partner("books")]
        case "plan", "message", "saving": path = [.plan]; slowSave = name == "saving"
        case "saved": confirmation = SavedScreening(draft: draft, savedAt: Date())
        case "populated": saved = [SavedScreening(draft: draft, savedAt: Date())]; path = []
        case "no-matches": path = [.details, .recovery(.noMatches)]
        case "search-error": path = [.details, .recovery(.interrupted)]
        case "save-error": path = [.plan]; saveError = "Your edits are still here. Please try again."
        default: break
        }
    }

    private func configurePreview() {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--reset-demo-data") && args.contains("--ui-testing") {
            saved = []; hasRecoverableDraft = false; draft = ScreeningDraft()
            try? repository.savePlans([]); try? repository.clearDraft()
        }
        if let argument = args.first(where: { $0.hasPrefix("--preview=") }) { preview(String(argument.dropFirst(10))) }
        failNextSave = args.contains("--fail-next-save")
        slowSave = slowSave || args.contains("--slow-save")
        #endif
    }
}
