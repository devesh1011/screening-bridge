import SwiftUI

struct ScreeningsView: View {
    @Bindable var store: ScreeningStore
    @State private var preferences = false
    @State private var previews = false
    @State private var replaceDraft = false

    private func start() {
        if store.hasRecoverableDraft { replaceDraft = true }
        else { store.newScreening() }
    }

    var body: some View {
        Group {
            if store.saved.isEmpty && !store.hasRecoverableDraft {
                GeometryReader { geometry in
                    ScrollView {
                        VStack(spacing: 25) {
                            ProgrammeArt(height: 160)
                            VStack(spacing: 10) {
                                Text("Start with a screening").font(.title3.weight(.semibold))
                                Text("Find local partners who share your audience’s cultural interests.")
                                    .font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center)
                            }
                            PrimaryAction(title: "New Screening", id: "newScreening", action: start)
                            if let error = store.persistenceError {
                                InlineFailure(title: "Saved Data Unavailable", message: error)
                            }
                        }
                        .padding(.horizontal, 28).padding(.vertical, 36)
                        .frame(maxWidth: .infinity).frame(minHeight: geometry.size.height)
                    }
                }
            } else {
                List {
                    if let error = store.persistenceError {
                        Section { Text(error).font(.subheadline).foregroundStyle(.secondary) }
                    }
                    if store.hasRecoverableDraft {
                        Section("Continue Planning") {
                            Button { store.resumeDraft() } label: {
                                Label("Resume Your Draft", systemImage: "doc.text")
                            }.accessibilityIdentifier("resumeDraft")
                        }
                    }
                    Section("Upcoming") {
                        ForEach(store.saved) { plan in
                            Button { store.open(plan) } label: { ScreeningCard(plan: plan) }
                                .buttonStyle(.plain).listRowInsets(EdgeInsets())
                                .accessibilityIdentifier("savedScreening")
                        }
                    }
                }
                .listStyle(.insetGrouped).scrollContentBackground(.hidden)
            }
        }
        .background(Color(.systemBackground))
        .navigationTitle("Screenings")
        .toolbar {
            if !store.saved.isEmpty || store.hasRecoverableDraft {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("New Screening", systemImage: "plus", action: start).accessibilityIdentifier("newScreening")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Preferences", systemImage: "slider.horizontal.3") { preferences = true }
                    #if DEBUG
                    Button("Preview States", systemImage: "rectangle.stack") { previews = true }
                    #endif
                } label: { Label("More", systemImage: "ellipsis") }
                .accessibilityIdentifier("moreMenu")
            }
        }
        .sheet(isPresented: $preferences) { PreferencesView() }
        .sheet(isPresented: $previews) { PreviewStatesView(store: store) }
        .confirmationDialog("Keep your current draft?", isPresented: $replaceDraft, titleVisibility: .visible) {
            Button("Resume Draft") { store.resumeDraft() }
            Button("Start a New Screening", role: .destructive) { store.newScreening() }
        } message: { Text("Starting a new screening replaces the unfinished draft on this device.") }
    }
}

struct ScreeningCard: View {
    let plan: SavedScreening
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(plan.draft.film?.image ?? "FilmCover").resizable().scaledToFill()
                .frame(height: 185).clipped().accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 9) {
                Text(plan.draft.film?.title ?? "Screening").font(.title2.weight(.semibold))
                Text(plan.draft.cinema).foregroundStyle(.secondary)
                Text("\(plan.draft.dateLabel) · \(plan.draft.timeLabel)").font(.subheadline).foregroundStyle(.secondary)
                SampleBadge(isLive: plan.draft.isLive)
                Divider().padding(.vertical, 3)
                HStack {
                    Label("Plan Saved", systemImage: "checkmark.circle.fill").foregroundStyle(.blue)
                    Text("· \(plan.draft.selectedIDs.count) partners").foregroundStyle(.secondary)
                }.font(.subheadline)
                Divider().padding(.vertical, 3)
                HStack { Text("Review Introductions"); Spacer(); Image(systemName: "chevron.right").foregroundStyle(.tertiary) }
            }.padding([.horizontal, .bottom], 18)
        }
        .foregroundStyle(.primary)
    }
}
