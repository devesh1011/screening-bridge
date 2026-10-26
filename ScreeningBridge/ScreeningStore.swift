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
    var allowedCategories: Set<String> = Set(SampleContent.partners.map(\.category))
    @ObservationIgnored let repository: LocalPlanRepository

    init(repository: LocalPlanRepository = LocalPlanRepository()) {
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
        SampleContent.partners.filter { $0.distanceMiles <= Double(draft.radius) && allowedCategories.contains($0.category) }
    }

    func newScreening() {
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
        guard !isSaving, draft.isValid, !draft.selectedIDs.isEmpty else { return }
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
        if args.contains("--reset-demo-data") {
            saved = []; hasRecoverableDraft = false; draft = ScreeningDraft()
            try? repository.savePlans([]); try? repository.clearDraft()
        }
        if let argument = args.first(where: { $0.hasPrefix("--preview=") }) { preview(String(argument.dropFirst(10))) }
        failNextSave = args.contains("--fail-next-save")
        slowSave = slowSave || args.contains("--slow-save")
        #endif
    }
}
