import SwiftUI

struct PreferencesView: View {
    @AppStorage("hapticsEnabled") private var haptics = true
    @AppStorage("appearance") private var appearance = AppAppearance.system.rawValue
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
                Section("About This Preview") {
                    Text("Screening Bridge").font(.headline)
                    Text("A native interface with sample film and partner data. Plans and drafts are saved on this device. Nothing is sent automatically.").font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Preferences").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close Preferences", systemImage: "xmark") { dismiss() } } }
        }.presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
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
