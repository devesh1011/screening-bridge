import SwiftUI

@main
struct ScreeningBridgeApp: App {
    @State private var store = ScreeningStore()
    @AppStorage("appearance") private var appearance = AppAppearance.system.rawValue

    private var scheme: ColorScheme? {
        if ProcessInfo.processInfo.arguments.contains("--dark") { return .dark }
        return appearance == "Dark" ? .dark : appearance == "Light" ? .light : nil
    }

    var body: some Scene {
        WindowGroup {
            AppRootView(store: store)
                .tint(.blue)
                .preferredColorScheme(scheme)
        }
    }
}

struct AppRootView: View {
    @Bindable var store: ScreeningStore
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack(path: $store.path) {
            ScreeningsView(store: store)
                .navigationDestination(for: ScreenRoute.self) { route in
                    switch route {
                    case .film: FilmSearchView(store: store)
                    case .details: ScreeningDetailsView(store: store)
                    case .research: ResearchView(store: store)
                    case .partners: PartnersView(store: store)
                    case .partner(let id):
                        if let partner = SampleContent.partner(id) { PartnerDetailView(store: store, partner: partner) }
                    case .plan: PlanView(store: store)
                    case .recovery(let outcome): RecoveryView(store: store, outcome: outcome)
                    }
                }
        }
        .fullScreenCover(item: $store.confirmation) { plan in
            SavedPlanView(store: store, plan: plan)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background && !store.path.isEmpty && store.confirmation == nil { store.persistDraft() }
        }
    }
}
