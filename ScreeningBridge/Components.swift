import SwiftUI

struct SampleBadge: View {
    var body: some View {
        Text("Sample screening")
            .font(.caption).foregroundStyle(.secondary)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(.quaternary.opacity(0.6), in: Capsule())
    }
}

struct FilmSummary: View {
    var draft: ScreeningDraft
    var compact = false
    var showVenue = false

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(draft.film?.image ?? "FilmCover")
                .resizable().scaledToFill()
                .frame(width: compact ? 56 : 78, height: compact ? 64 : 102)
                .clipShape(.rect(cornerRadius: 14)).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 7) {
                Text(draft.film?.title ?? "Perfect Days").font(compact ? .headline : .title2.weight(.semibold))
                if showVenue {
                    Text("\(draft.cinema) · \(draft.dateLabel)").font(.subheadline).foregroundStyle(.secondary)
                } else if !compact {
                    Text(String(draft.film?.year ?? 2023)).font(.subheadline).foregroundStyle(.secondary)
                }
                SampleBadge()
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

struct ProgrammeArt: View {
    var name = "Programme"
    var height: CGFloat = 145
    @Environment(\.dynamicTypeSize) private var textSize

    var body: some View {
        Image(name).resizable().scaledToFit()
            .frame(maxWidth: 220, maxHeight: textSize.isAccessibilitySize ? 80 : height)
            .accessibilityHidden(true)
    }
}

struct SelectionIndicator: View {
    let selected: Bool
    var body: some View {
        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
            .font(.title2).foregroundStyle(selected ? Color.blue : Color.secondary.opacity(0.65))
            .contentTransition(.symbolEffect(.replace))
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityHidden(true)
    }
}

struct InlineFailure: View {
    let title: String
    let message: String
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.circle").foregroundStyle(.red).font(.title3)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline)
                Text(message).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(16).background(Color.red.opacity(0.06), in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }
}

struct PrimaryAction: View {
    let title: String
    var id: String = ""
    var disabled = false
    var action: () -> Void
    var body: some View {
        Button(title, action: action)
            .font(.headline).buttonStyle(.glassProminent)
            .buttonBorderShape(.capsule).controlSize(.large)
            .disabled(disabled).accessibilityIdentifier(id)
    }
}
