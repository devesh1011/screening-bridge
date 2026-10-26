import SwiftUI

struct FilmSearchView: View {
    @Bindable var store: ScreeningStore
    @State private var query = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var films: [Film] {
        let library = store.draft.isLive ? store.liveCatalog?.films.map(\.film) ?? [] : [.perfectDays]
        return library.filter { query.isEmpty || "\($0.title) \($0.director) \($0.year)".localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        List {
            Picker("Research Mode", selection: Binding(get: { store.draft.isLive ? "live" : "sample" }, set: store.setDiscoveryMode)) {
                Text("Sample").tag("sample")
                Text("Live").tag("live")
            }.pickerStyle(.segmented).accessibilityIdentifier("researchMode")
            if store.draft.isLive {
                Text("Brooklyn starter demo · two films and Nitehawk Williamsburg. Nothing is booked.").font(.footnote).foregroundStyle(.secondary)
                if let error = store.catalogError {
                    Text(error).foregroundStyle(.secondary)
                    Button("Retry Connection") { Task { await store.loadLiveCatalog() } }
                } else if store.liveCatalog == nil { ProgressView("Connecting to live research") }
            }
            ForEach(films) { film in
                Button {
                    withAnimation(reduceMotion ? nil : .snappy(duration: 0.15)) { store.draft.film = film }
                    AppHaptics.selection()
                    store.persistDraft()
                } label: {
                    HStack(spacing: 16) {
                        Image(film.image).resizable().scaledToFill().frame(width: 78, height: 104).clipShape(.rect(cornerRadius: 14)).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(film.title).font(.headline).foregroundStyle(.primary)
                            Text("\(film.year.formatted(.number.grouping(.never))) · \(film.director)").font(.subheadline).foregroundStyle(.secondary)
                            SampleBadge(isLive: store.draft.isLive)
                        }
                        Spacer(minLength: 0)
                        SelectionIndicator(selected: store.draft.film?.id == film.id)
                    }.padding(.vertical, 10)
                }
                .buttonStyle(.plain).accessibilityIdentifier(film.title == "Perfect Days" ? "filmPerfectDays" : "film-\(film.id)")
                .accessibilityLabel("\(film.title), \(film.year), \(film.director)")
                .accessibilityValue(store.draft.film?.id == film.id ? "Selected" : "Not selected")
                Text("Check the title and year before continuing.").font(.subheadline).foregroundStyle(.secondary)
            }
            if films.isEmpty && (!store.draft.isLive || store.liveCatalog != nil) {
                ContentUnavailableView.search(text: query)
                Text(store.draft.isLive ? "This live starter library includes Perfect Days and School of Rock." : "The sample film library includes Perfect Days.").font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .listStyle(.plain).navigationTitle("Choose a Film")
        .searchable(text: $query, prompt: "Search Films")
        .task(id: store.draft.isLive) { if store.draft.isLive { await store.loadLiveCatalog() } }
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
                if store.draft.isLive {
                    LabeledContent("Cinema", value: store.draft.cinema)
                    Text(store.draft.area).foregroundStyle(.secondary)
                    Text("Starter venue · confirm the address before continuing.").font(.footnote).foregroundStyle(.secondary)
                } else {
                LabeledContent("Cinema") {
                    TextField("Cinema name", text: $store.draft.cinema).multilineTextAlignment(.trailing).accessibilityIdentifier("cinemaField")
                }
                LabeledContent("Area") {
                    TextField("Area or address", text: $store.draft.area).multilineTextAlignment(.trailing).accessibilityIdentifier("areaField")
                }
                }
            }
            Section {
                DatePicker("Date", selection: $store.draft.date, displayedComponents: .date)
                DatePicker("Time", selection: $store.draft.date, displayedComponents: .hourAndMinute)
                Picker("Search Radius", selection: $store.draft.radius) {
                    ForEach([1, 2, 5, 10], id: \.self) { value in Text("\(value) \(value == 1 ? "mile" : "miles")").tag(value) }
                }
            } header: { Text("When & Where") } footer: { Text(store.draft.isLive ? "Times are shown in New York time. Distances are straight-line estimates." : "Start nearby. You can widen the area later.") }
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
        .environment(\.timeZone, TimeZone(identifier: store.draft.venueTimezone ?? "") ?? .current)
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
