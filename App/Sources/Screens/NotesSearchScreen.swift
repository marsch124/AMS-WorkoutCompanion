import AMSIcons
import SwiftUI
import WorkoutCore

/// Search my notes: a word from a note on a machine, a visit's title and notes, or a machine's setting (since 1.11).
struct NotesSearchScreen: View {
    @Environment(Library.self) private var library
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        let hits = library.gym.searchNotes(text)
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                TextField("A word from a note", text: $text)
                    .focused($focused)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("notes-search-field")
                if !text.trimmingCharacters(in: .whitespaces).isEmpty && hits.isEmpty {
                    Text("Nothing found.").font(.subheadline).foregroundStyle(Theme.muted)
                        .accessibilityIdentifier("notes-empty")
                }
                VStack(spacing: 0) {
                    ForEach(Array(hits.enumerated()), id: \.element.id) { i, hit in
                        Group {
                            if let v = hit.visitID {
                                NavigationLink { VisitScreen(visitID: v) } label: { row(hit) }.buttonStyle(.plain)
                            } else {
                                row(hit)
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("notes-hit-\(i + 1)")
                        if i < hits.count - 1 { Divider().padding(.leading, 10) }
                    }
                }
                .background(hits.isEmpty ? Color.clear : Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
        }
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle("Search my notes")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ hit: NoteHit) -> some View {
        let name = hit.machineID.flatMap { library.gym.machine($0)?.name }
        let title: String
        switch hit.kind {
        case .machineNote: title = name ?? "Machine"
        case .visitNote: title = "Visit"
        case .setting: title = "Setting of " + (name ?? "machine")
        }
        return HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Gym.tint)
                    if let d = hit.date {
                        Text(d.formatted(.dateTime.day().month(.abbreviated).year())).font(.caption).foregroundStyle(Theme.muted)
                    }
                }
                Text(highlighted(hit.text)).font(.subheadline).foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
            if hit.visitID != nil { ControlMarkView(.chevron, size: 14, colour: Theme.muted) }
        }
        .padding(10)
        .contentShape(Rectangle())
    }

    private func highlighted(_ s: String) -> AttributedString {
        var a = AttributedString(s)
        let w = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !w.isEmpty, let r = s.range(of: w, options: [.caseInsensitive, .diacriticInsensitive]),
           let ar = Range(r, in: a) {
            a[ar].font = .subheadline.weight(.bold)
        }
        return a
    }
}
