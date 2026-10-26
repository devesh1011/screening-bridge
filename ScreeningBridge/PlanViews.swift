import SwiftUI
import UIKit

struct PlanView: View {
    @Bindable var store: ScreeningStore
    @State private var editingPartner: Partner?
    @State private var evidencePartner: Partner?
    @State private var saveTask: Task<Void, Never>?
    @State private var openedPreview = false
    private let steps = ["Review the introductions", "Contact your chosen partners", "Record their replies"]

    var body: some View {
        List {
            if let error = store.saveError {
                Section { InlineFailure(title: "Couldn’t Save Plan", message: error) }.listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
            }
            Section { FilmSummary(draft: store.draft, showVenue: true) }.listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 12, trailing: 0)).listRowBackground(Color.clear)
            ForEach(Array(store.draft.selectedPartners.enumerated()), id: \.element.id) { index, partner in
                Section {
                    HStack(spacing: 14) {
                        PartnerArtwork(partner: partner).frame(width: 72, height: 78).clipped().clipShape(.rect(cornerRadius: 12)).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(partner.name).font(.headline)
                            Text(partner.activity).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }.padding(.vertical, 4)
                    Button { editingPartner = partner } label: {
                        HStack { Text("Preview Introduction").foregroundStyle(.primary); Spacer(); Image(systemName: "chevron.right").foregroundStyle(.tertiary) }
                    }.accessibilityIdentifier("introduction-\(partner.id)")
                    if partner.evidence != nil {
                        Button("View Evidence") { evidencePartner = partner }
                    }
                } header: { if index == 0 { Text("Partners") } }
            }
            Section("Next Steps") {
                ForEach(steps, id: \.self) { step in
                    Button {
                        if store.draft.completedSteps.contains(step) { store.draft.completedSteps.remove(step) }
                        else { store.draft.completedSteps.insert(step) }
                        AppHaptics.selection()
                        store.persistDraft()
                    } label: {
                        HStack(spacing: 14) {
                            SelectionIndicator(selected: store.draft.completedSteps.contains(step))
                            Text(step).foregroundStyle(.primary)
                        }
                    }.buttonStyle(.plain)
                    .accessibilityLabel(step).accessibilityValue(store.draft.completedSteps.contains(step) ? "Complete" : "Not complete")
                }
            }
            Section { Label("Nothing is sent automatically.", systemImage: "info.circle").font(.footnote).foregroundStyle(.secondary) }.listRowBackground(Color.clear)
        }
        .listStyle(.insetGrouped).scrollContentBackground(.hidden).background(Color(.systemBackground))
        .navigationTitle("Your Plan").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    saveTask = Task { await store.savePlan() }
                } label: {
                    if store.isSaving { HStack(spacing: 6) { Text("Saving"); ProgressView().controlSize(.small) } }
                    else { Text(store.saveError == nil ? "Save" : "Retry") }
                }
                .buttonStyle(.glassProminent).disabled(store.isSaving || store.draft.selectedIDs.isEmpty || !store.hasCurrentResults)
                .accessibilityLabel(store.isSaving ? "Saving plan" : store.saveError == nil ? "Save plan" : "Retry saving plan")
                .accessibilityIdentifier("savePlan")
            }
        }
        .sheet(item: $editingPartner) { partner in MessageDraftView(store: store, partner: partner) }
        .sheet(item: $evidencePartner) { partner in EvidenceView(partner: partner) }
        .onDisappear { saveTask?.cancel() }
        .task {
            guard !openedPreview else { return }
            openedPreview = true
            if ProcessInfo.processInfo.arguments.contains("--preview=message") { editingPartner = SampleContent.partners[0] }
        }
    }
}

struct MessageDraftView: View {
    @Bindable var store: ScreeningStore
    let partner: Partner
    let original: String
    @State private var message: String
    @State private var copied = false
    @State private var discard = false
    @State private var draftSaveFailed = false
    @State private var copyTask: Task<Void, Never>?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(store: ScreeningStore, partner: Partner) {
        self.store = store
        self.partner = partner
        original = store.draft.introduction(for: partner)
        _message = State(initialValue: original)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    SampleBadge(isLive: store.draft.isLive)
                    LabeledContent("To", value: partner.name)
                    Divider()
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Subject").font(.subheadline).foregroundStyle(.secondary)
                        Text("A local screening collaboration")
                    }
                    Divider()
                    TextEditor(text: $message).font(.body).scrollContentBackground(.hidden)
                        .frame(minHeight: 280).accessibilityLabel("Introduction message")
                        .accessibilityIdentifier("messageEditor")
                    Text("Review and personalize before sharing.").font(.footnote).foregroundStyle(.secondary)
                }.padding(24)
            }
            .navigationTitle("Introduction").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { if message != original { discard = true } else { dismiss() } }
                        .accessibilityIdentifier("cancelIntroduction")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let previous = store.draft.introductions[partner.id]
                        store.draft.introductions[partner.id] = message
                        if store.persistDraft() { dismiss() }
                        else {
                            store.draft.introductions[partner.id] = previous
                            draftSaveFailed = true
                        }
                    }.buttonStyle(.glassProminent).disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("saveIntroduction")
                }
                ToolbarSpacer(.flexible, placement: .bottomBar)
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        UIPasteboard.general.string = message
                        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.15)) { copied = true }
                        UIAccessibility.post(notification: .announcement, argument: "Message copied")
                        copyTask?.cancel()
                        copyTask = Task {
                            do { try await Task.sleep(for: .seconds(1.7)); copied = false } catch { }
                        }
                    } label: { Label(copied ? "Copied" : "Copy Message", systemImage: copied ? "checkmark" : "doc.on.doc").contentTransition(.symbolEffect(.replace)) }
                    .buttonStyle(.glass).controlSize(.large).accessibilityIdentifier("copyMessage")
                }.sharedBackgroundVisibility(.hidden)
            }
            .confirmationDialog("Discard your changes?", isPresented: $discard, titleVisibility: .visible) {
                Button("Discard Changes", role: .destructive) { dismiss() }
                Button("Keep Editing", role: .cancel) { }
            } message: { Text("Your previously saved introduction will be kept.") }
            .alert("Couldn’t Save Introduction", isPresented: $draftSaveFailed) {
                Button("Keep Editing", role: .cancel) { }
            } message: { Text("Your edits are still in this editor. Please try saving again.") }
        }
        .interactiveDismissDisabled(message != original)
        .onDisappear { copyTask?.cancel() }
    }
}

struct SavedPlanView: View {
    @Bindable var store: ScreeningStore
    let plan: SavedScreening
    @State private var revealed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var textSize

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    HStack {
                        Image(systemName: "checkmark.circle").font(.largeTitle).foregroundStyle(.green)
                            .scaleEffect(revealed ? 1 : 0.9).opacity(revealed ? 1 : 0)
                            .accessibilityHidden(true)
                        Spacer()
                        if !textSize.isAccessibilitySize { ProgrammeArt(name: "ProgrammeSaved", height: 82).frame(width: 120) }
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Plan Saved").font(.largeTitle.bold()).accessibilityIdentifier("planSavedHeading")
                        Text("Your introductions are ready to review.").foregroundStyle(.secondary)
                    }
                    FilmSummary(draft: plan.draft, showVenue: true)
                    VStack(alignment: .leading, spacing: 14) {
                        Text("\(plan.draft.selectedIDs.count) Partners").font(.title3.weight(.semibold))
                        ForEach(plan.draft.selectedPartners) { partner in
                            HStack(spacing: 16) {
                                PartnerArtwork(partner: partner).frame(width: 65, height: 70).clipped().clipShape(.rect(cornerRadius: 12)).accessibilityHidden(true)
                                Text(partner.name).font(.headline)
                                Spacer(minLength: 0)
                            }
                            if partner.id != plan.draft.selectedPartners.last?.id { Divider() }
                        }
                    }.padding(18).background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 24))
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Next: review your first introduction.", systemImage: "arrow.right").font(.subheadline.weight(.medium))
                        Text("Nothing has been sent.").font(.footnote).foregroundStyle(.secondary)
                    }
                }.padding(24)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Back to Screenings", systemImage: "xmark") { store.finish() }.accessibilityIdentifier("closeSaved") }
                ToolbarSpacer(.flexible, placement: .bottomBar)
                ToolbarItem(placement: .bottomBar) { PrimaryAction(title: "View Plan", id: "viewSavedPlan") { store.showSavedPlan() } }.sharedBackgroundVisibility(.hidden)
            }
            .task { withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) { revealed = true } }
        }
    }
}

struct EvidenceView: View {
    let partner: Partner?
    var livePartners: [Partner] = []
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if partner?.evidence != nil || !livePartners.isEmpty {
                        SampleBadge(isLive: true)
                        ForEach(partner.map { [$0] } ?? livePartners) { item in
                            if let evidence = item.evidence {
                                Text(item.name).font(.title3.weight(.semibold))
                                evidenceRow("Cultural Signal", symbol: "point.3.connected.trianglepath.dotted", color: .blue, subtitle: "Qloo · rank \(evidence.qlooRank) in this search", body: "Relative cultural affinity, not a prediction of attendance or partner interest.")
                                Text("Researched \(evidence.researchedAt.formatted(date: .abbreviated, time: .shortened))").font(.footnote).foregroundStyle(.secondary)
                                ForEach(evidence.facts, id: \.self) { Text($0).font(.subheadline) }
                                ForEach(evidence.sources) { source in
                                    Link(destination: source.url) { Label(source.title, systemImage: "arrow.up.right.square").frame(minHeight: 44) }
                                }
                                evidenceRow("Still to Confirm", symbol: "questionmark.circle", color: .orange, subtitle: "Interest and availability are unconfirmed.", body: evidence.stillToConfirm.joined(separator: "\n"))
                                Divider()
                            }
                        }
                    } else {
                    SampleBadge()
                    evidenceRow("Cultural Signal", symbol: "book.closed", color: .blue, subtitle: "Qloo taste affinity", body: "An illustrative connection between the film and \(partner?.id == "records" ? "music" : partner?.id == "studio" ? "creative" : "literary") interests.")
                    Divider()
                    evidenceRow("Public Source", symbol: "globe", color: .green, subtitle: partner?.id == "records" ? "northline.example" : partner?.id == "studio" ? "sundaystudio.example" : "chapterhouse.example", body: "Sample source for this preview.")
                    Divider()
                    evidenceRow("Still to Confirm", symbol: "questionmark.circle", color: .orange, subtitle: "Audience fit, interest, availability and the event format.", body: "A cultural connection is a starting point, not a guarantee.")
                    Text("This screen uses sample evidence. Live research will be connected in the next stage.").font(.footnote).foregroundStyle(.secondary)
                    }
                }.padding(24)
            }
            .navigationTitle("Why This Connection").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close Evidence", systemImage: "xmark") { dismiss() }.accessibilityIdentifier("closeEvidence") } }
        }
        .presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
    }

    private func evidenceRow(_ title: String, symbol: String, color: Color, subtitle: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: symbol).font(.title3).foregroundStyle(color).frame(width: 42, height: 42).background(color.opacity(0.09), in: Circle()).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 8) { Text(title).font(.headline); Text(subtitle).foregroundStyle(.secondary); Text(body).font(.subheadline) }
        }
    }
}
