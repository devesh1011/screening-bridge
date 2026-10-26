import SwiftUI

struct ResearchView: View {
    @Bindable var store: ScreeningStore
    private var stages: [String] { store.draft.isLive ? ["Confirming film and cinema", "Researching nearby partners", "Checking cultural ranking", "Preparing your shortlist"] : ["Finding cultural connections", "Checking nearby places", "Preparing your shortlist"] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 38) {
                FilmSummary(draft: store.draft, compact: true)
                VStack(spacing: 18) {
                    ProgressView().controlSize(.large)
                    Text("Looking for local connections").font(.title3.weight(.semibold)).multilineTextAlignment(.center)
                    Text(store.draft.isLive ? "Live research · you can go back to cancel" : "Sample search preview").font(.subheadline).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity).padding(.top, 45)
                VStack(spacing: 22) {
                    ForEach(stages.indices, id: \.self) { index in
                        HStack(spacing: 18) {
                            Group {
                                if index < store.stage { Image(systemName: "checkmark.circle.fill").foregroundStyle(.blue) }
                                else if index == store.stage { ProgressView() }
                                else { Image(systemName: "circle").foregroundStyle(.tertiary) }
                            }.frame(width: 28)
                            Text(stages[index]).foregroundStyle(index > store.stage ? .secondary : .primary)
                            Spacer(minLength: 0)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityValue(index < store.stage ? "Complete" : index == store.stage ? "In progress" : "Waiting")
                    }
                }
                Text("Your screening details are saved.").font(.subheadline).foregroundStyle(.secondary).frame(maxWidth: .infinity)
            }.padding(24)
        }
        .navigationTitle("Finding Partners").navigationBarTitleDisplayMode(.inline)
        .task { await store.runSearch() }
    }
}

struct PartnersView: View {
    @Bindable var store: ScreeningStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var textSize
    @State private var emphasis = false
    @State private var filters = false
    @State private var evidence = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                FilmSummary(draft: store.draft, compact: true)
                Text("\(store.visiblePartners.count == 3 ? "Three places" : "Places") worth a conversation.").foregroundStyle(.secondary)
                if store.draft.isLive, let warnings = store.draft.researchWarnings {
                    ForEach(warnings, id: \.self) { Text($0).font(.footnote).foregroundStyle(.secondary) }
                }
                ForEach(Array(store.visiblePartners.enumerated()), id: \.element.id) { index, partner in
                    VStack(alignment: .leading, spacing: 12) {
                        if index == 0 {
                            Button { store.path.append(.partner(partner.id)) } label: {
                                PartnerArtwork(partner: partner)
                                    .frame(height: textSize.isAccessibilitySize ? 130 : 175)
                                    .frame(maxWidth: .infinity).clipped().clipShape(.rect(cornerRadius: 22))
                            }.buttonStyle(.plain).accessibilityLabel("View \(partner.name)")
                        }
                        HStack(alignment: .center, spacing: 10) {
                            Button {
                                withAnimation(reduceMotion ? nil : .snappy(duration: 0.15)) { store.toggle(partner) }
                            } label: { SelectionIndicator(selected: store.draft.selectedIDs.contains(partner.id)) }
                            .buttonStyle(.plain).accessibilityLabel("Select \(partner.name)")
                            .accessibilityValue(store.draft.selectedIDs.contains(partner.id) ? "Selected" : "Not selected")
                            .accessibilityAddTraits(store.draft.selectedIDs.contains(partner.id) ? .isSelected : [])
                            .accessibilityIdentifier("select-\(partner.id)")
                            if index > 0 && !textSize.isAccessibilitySize {
                                PartnerArtwork(partner: partner).frame(width: 70, height: 84).clipped().clipShape(.rect(cornerRadius: 14)).accessibilityHidden(true)
                            }
                            Button { store.path.append(.partner(partner.id)) } label: {
                                HStack(spacing: 8) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(partner.name).font(.headline).foregroundStyle(.primary)
                                        Text(partner.subtitle).font(.subheadline).foregroundStyle(.secondary)
                                        Text(partner.rationale).font(.subheadline).foregroundStyle(.primary)
                                            .padding(.vertical, 2)
                                            .background(Color.orange.opacity(index == 0 && emphasis ? 0.13 : 0), in: .rect(cornerRadius: 6))
                                    }.fixedSize(horizontal: false, vertical: true)
                                    Spacer(minLength: 0)
                                    Image(systemName: "chevron.right").font(.subheadline.weight(.semibold)).foregroundStyle(.tertiary)
                                }.frame(minHeight: 44)
                            }.buttonStyle(.plain).accessibilityIdentifier("partner-\(partner.id)")
                        }
                        if index < store.visiblePartners.count - 1 { Divider().padding(.leading, 54) }
                    }
                }
                Button { evidence = true } label: {
                    HStack { Label("Why These Places?", systemImage: "info.circle"); Spacer(); Image(systemName: "chevron.right").foregroundStyle(.tertiary) }.frame(minHeight: 44)
                }.accessibilityIdentifier("whyPlaces")
                if store.draft.selectedIDs.isEmpty {
                    Text("Select a partner to continue.").font(.subheadline).foregroundStyle(.secondary)
                }
            }.padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 20)
        }
        .navigationTitle("Partners")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { Button("Filter Partners", systemImage: "slider.horizontal.3") { filters = true } }
            ToolbarItem(placement: .bottomBar) {
                Text("\(store.draft.selectedIDs.count) selected").font(.subheadline.weight(.medium))
                    .contentTransition(.numericText()).accessibilityIdentifier("selectionCount")
            }.sharedBackgroundVisibility(.hidden)
            ToolbarSpacer(.flexible, placement: .bottomBar)
            ToolbarItem(placement: .bottomBar) {
                PrimaryAction(title: "Build Plan", id: "buildPlan", disabled: store.draft.selectedIDs.isEmpty) { store.path.append(.plan) }
            }.sharedBackgroundVisibility(.hidden)
        }
        .sheet(isPresented: $filters) { PartnerFiltersView(store: store) }
        .sheet(isPresented: $evidence) { EvidenceView(partner: nil, livePartners: store.draft.isLive ? store.visiblePartners : []) }
        .task(id: store.resultGeneration) {
            guard store.revealedGeneration != store.resultGeneration else { return }
            store.revealedGeneration = store.resultGeneration
            guard !reduceMotion else { return }
            do {
                try await Task.sleep(for: .milliseconds(300))
                withAnimation(.easeOut(duration: 0.15)) { emphasis = true }
                try await Task.sleep(for: .milliseconds(250))
                withAnimation(.easeOut(duration: 0.2)) { emphasis = false }
            } catch { emphasis = false }
        }
    }
}

struct PartnerDetailView: View {
    @Bindable var store: ScreeningStore
    let partner: Partner
    @State private var evidence = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PartnerArtwork(partner: partner).frame(height: 285).frame(maxWidth: .infinity).clipped().accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 25) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(partner.name).font(.largeTitle.bold())
                        Text(partner.subtitle).foregroundStyle(.secondary)
                        SampleBadge(isLive: store.draft.isLive)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("The Connection").font(.title3.weight(.semibold))
                        Text(partner.connection)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("An Idea to Explore").font(.title3.weight(.semibold))
                        Text(partner.idea)
                    }
                    Divider()
                    Button { evidence = true } label: {
                        HStack { Label("Why This Connection?", systemImage: "info.circle"); Spacer(); Image(systemName: "chevron.right") }.frame(minHeight: 44)
                    }.accessibilityIdentifier("partnerEvidence")
                    Divider()
                    Text("Interest and availability still need confirmation.").font(.footnote).foregroundStyle(.secondary)
                }.padding(24)
            }
        }
        .ignoresSafeArea(edges: .top)
        .navigationTitle("").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarSpacer(.flexible, placement: .bottomBar)
            ToolbarItem(placement: .bottomBar) {
                PrimaryAction(title: store.draft.selectedIDs.contains(partner.id) ? "Remove from Plan" : "Add to Plan", id: "addPartner") {
                    store.toggle(partner)
                    store.path.removeLast()
                }
            }.sharedBackgroundVisibility(.hidden)
        }
        .sheet(isPresented: $evidence) { EvidenceView(partner: partner) }
    }
}

struct RecoveryView: View {
    @Bindable var store: ScreeningStore
    let outcome: SearchOutcome
    var body: some View {
        ScrollView {
            VStack(spacing: 26) {
                FilmSummary(draft: store.draft, compact: true)
                VStack(spacing: 20) {
                    if outcome == .noMatches { ProgrammeArt(name: "ProgrammeSearch", height: 160) }
                    else { Image(systemName: "network.slash").font(.largeTitle).foregroundStyle(.secondary).padding(24).accessibilityHidden(true) }
                    Text(store.recoveryInputField != nil ? "Check Your Screening" : outcome == .noMatches ? "No Useful Matches Yet" : "Search Interrupted").font(.title2.weight(.semibold)).multilineTextAlignment(.center)
                    Text(store.recoveryReason ?? (outcome == .noMatches ? "We couldn’t support a shortlist within \(store.draft.radius) miles.\nTry a wider area or adjust your preferences." : "We couldn’t finish this sample search. Please try again in a moment."))
                        .foregroundStyle(.secondary).multilineTextAlignment(.center)
                    PrimaryAction(title: outcome == .noMatches || store.recoveryInputField != nil ? "Edit Search" : "Try Again", id: "recoverSearch") {
                        if let field = store.recoveryInputField { store.path = field == "film" ? [.film] : [.film, .details] }
                        else if outcome == .noMatches { store.path.removeLast() }
                        else { store.path[store.path.count - 1] = .research }
                    }
                    Label("Your screening details are saved.", systemImage: "lock").font(.footnote).foregroundStyle(.secondary)
                }.padding(.top, 60)
            }.padding(24)
        }
        .navigationTitle("Partners")
    }
}

struct PartnerFiltersView: View {
    @Bindable var store: ScreeningStore
    @Environment(\.dismiss) private var dismiss
    @State private var radius = 2
    @State private var categories: Set<String> = []
    var body: some View {
        NavigationStack {
            Form {
                Section("Search Area") {
                    Picker("Radius", selection: $radius) { ForEach([1, 2, 5, 10], id: \.self) { Text("\($0) miles").tag($0) } }
                }
                Section("Partner Types") {
                    ForEach(PartnerCategory.allCases.map { $0.display.label }, id: \.self) { category in
                        Toggle(category, isOn: Binding(get: { categories.contains(category) }, set: { if $0 { categories.insert(category) } else { categories.remove(category) } }))
                    }
                }
                Section { Text("Selections outside these filters will be removed.").font(.footnote).foregroundStyle(.secondary) }
            }
            .navigationTitle("Filter Partners").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", systemImage: "xmark") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        store.applyFilters(radius: radius, categories: categories)
                        dismiss()
                    }.buttonStyle(.glassProminent).disabled(categories.isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
        .onAppear { radius = store.draft.radius; categories = store.allowedCategories }
    }
}
