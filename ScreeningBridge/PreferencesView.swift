import SwiftUI

struct PreferencesView: View {
    @AppStorage("hapticsEnabled") private var haptics = true
    @AppStorage("appearance") private var appearance = AppAppearance.system.rawValue
    @State private var backendURL = LiveConfiguration.current.backendURL
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Haptic Feedback", isOn: $haptics).accessibilityIdentifier("hapticsToggle")
                } footer: { Text("Subtle feedback when you change a selection or save a plan. All feedback also appears on screen.") }
                Section("Appearance") {
                    Picker("Appearance", selection: $appearance) { ForEach(AppAppearance.allCases) { Text($0.rawValue).tag($0.rawValue) } }
                }
                Section("About Screening Bridge") {
                    Text("Screening Bridge").font(.headline)
                    Text("Choose Sample for an offline preview or Live for the Brooklyn research demo. Plans, evidence and edited introductions are saved on this device. Nothing is sent automatically.").font(.subheadline).foregroundStyle(.secondary)
                }
                #if DEBUG
                Section("Development Connection") {
                    TextField("Backend URL", text: $backendURL).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Text(LiveConfiguration.current.accessToken.isEmpty ? "Live access is not configured in this build." : "Development access is configured. Your provider keys stay on the server.").font(.footnote).foregroundStyle(.secondary)
                }
                #endif
            }
            .navigationTitle("Preferences").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close Preferences", systemImage: "xmark") { dismiss() } } }
        }.presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
            .onDisappear { UserDefaults.standard.set(backendURL.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "backendURL") }
    }
}

struct PreviewStatesView: View {
    @Bindable var store: ScreeningStore
    @Environment(\.dismiss) private var dismiss
    private let screens = [("Film selection", "film"), ("Screening details", "details"), ("Finding partners", "research"), ("Partner shortlist", "partners"), ("Partner detail", "detail"), ("Plan review", "plan"), ("Saved plan", "saved"), ("No matches", "no-matches"), ("Search interrupted", "search-error"), ("Save failed", "save-error")]
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("These controls exercise sample states for interface review. They don’t run research or contact anyone.").font(.subheadline).foregroundStyle(.secondary)
                }
                Section("Next Operation") {
                    Picker("Search Result", selection: $store.nextSearchOutcome) { ForEach(SearchOutcome.allCases) { Text($0.rawValue).tag($0) } }
                    Toggle("Fail Next Save", isOn: $store.failNextSave)
                    Toggle("Slow Saving Preview", isOn: $store.slowSave)
                }
                Section("Jump to a Screen") {
                    ForEach(screens, id: \.1) { title, key in
                        Button(title) { dismiss(); store.preview(key) }
                    }
                }
            }
            .navigationTitle("Preview States").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close Preview States", systemImage: "xmark") { dismiss() } } }
        }
    }
}
