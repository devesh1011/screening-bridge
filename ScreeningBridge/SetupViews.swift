import SwiftUI

struct FilmSearchView: View {
    @Bindable var store: ScreeningStore
    @State private var query = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var matches: Bool { query.isEmpty || "Perfect Days Wim Wenders 2023".localizedCaseInsensitiveContains(query) }

    var body: some View {
        List {
            if matches {
                Button {
                    withAnimation(reduceMotion ? nil : .snappy(duration: 0.15)) { store.draft.film = .perfectDays }
                    AppHaptics.selection()
                    store.persistDraft()
                } label: {
                    HStack(spacing: 16) {
                        Image("FilmCover").resizable().scaledToFill().frame(width: 78, height: 104).clipShape(.rect(cornerRadius: 14)).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Perfect Days").font(.headline).foregroundStyle(.primary)
                            Text("2023 · Wim Wenders").font(.subheadline).foregroundStyle(.secondary)
                            SampleBadge()
                        }
                        Spacer(minLength: 0)
                        SelectionIndicator(selected: store.draft.film != nil)
                    }.padding(.vertical, 10)
                }
                .buttonStyle(.plain).accessibilityIdentifier("filmPerfectDays")
                .accessibilityLabel("Perfect Days, 2023, Wim Wenders")
                .accessibilityValue(store.draft.film == nil ? "Not selected" : "Selected")
                Text("Check the title and year before continuing.").font(.subheadline).foregroundStyle(.secondary)
            } else {
                ContentUnavailableView.search(text: query)
                Text("The sample film library includes Perfect Days.").font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .listStyle(.plain).navigationTitle("Choose a Film")
        .searchable(text: $query, prompt: "Search Films")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Continue") { store.path.append(.details) }
                    .buttonStyle(.glassProminent).disabled(store.draft.film == nil)
                    .accessibilityIdentifier("continueFilm")
            }
        }
    }
}

struct ScreeningDetailsView: View {
    @Bindable var store: ScreeningStore
    @State private var optionalDetails = false

    var body: some View {
        Form {
            Section { FilmSummary(draft: store.draft) }.listRowBackground(Color.clear).listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 16, trailing: 0))
            Section("Venue") {
                LabeledContent("Cinema") {
                    TextField("Cinema name", text: $store.draft.cinema).multilineTextAlignment(.trailing).accessibilityIdentifier("cinemaField")
                }
                LabeledContent("Area") {
                    TextField("Area or address", text: $store.draft.area).multilineTextAlignment(.trailing).accessibilityIdentifier("areaField")
                }
            }
            Section {
                DatePicker("Date", selection: $store.draft.date, displayedComponents: .date)
                DatePicker("Time", selection: $store.draft.date, displayedComponents: .hourAndMinute)
                Picker("Search Radius", selection: $store.draft.radius) {
                    ForEach([1, 2, 5, 10], id: \.self) { value in Text("\(value) \(value == 1 ? "mile" : "miles")").tag(value) }
                }
            } header: { Text("When & Where") } footer: { Text("Start nearby. You can widen the area later.") }
            Section {
                DisclosureGroup("Optional Details", isExpanded: $optionalDetails) {
                    TextField("Budget, existing partners, or ideas to explore", text: $store.draft.notes, axis: .vertical).lineLimit(3...6)
                }
            }
            if !store.draft.isValid {
                Section { Text("Add a cinema and area to continue.").font(.subheadline).foregroundStyle(.secondary) }
            }
            if let error = store.persistenceError { Section { Text(error).foregroundStyle(.red).font(.subheadline) } }
        }
        .navigationTitle("Screening").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) } }
            ToolbarSpacer(.flexible, placement: .bottomBar)
            ToolbarItem(placement: .bottomBar) {
                PrimaryAction(title: "Find Partners", id: "findPartners", disabled: !store.draft.isValid) {
                    store.persistDraft()
                    store.path.append(.research)
                }
            }.sharedBackgroundVisibility(.hidden)
        }
        .onDisappear { store.persistDraft() }
    }
}
