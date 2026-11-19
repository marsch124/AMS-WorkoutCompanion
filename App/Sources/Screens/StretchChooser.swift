import AMSIcons
import SwiftUI
import WorkoutCore

/// Small marks of the stretch screens in the AMS-Icons style (24-point grid, 1.9 stroke, round ends).
enum StretchMark: String {
    case star = "M12 4.5l2.4 5l5.4 .7l-3.9 3.8l1 5.4l-4.9 -2.6l-4.9 2.6l1 -5.4l-3.9 -3.8l5.4 -.7Z"
    case plus = "M12 5.5v13 M5.5 12h13"
    case grip = "M5 8h14 M5 12h14 M5 16h14"
}

struct StretchMarkView: View {
    let mark: StretchMark
    var size: CGFloat = 20
    var colour: Color
    var body: some View {
        GridShape(d: mark.rawValue)
            .stroke(colour, style: StrokeStyle(lineWidth: size * 1.9 / 24, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// The small picture of a stretch: its drawn figure, his own photo, or a plain mark.
struct StretchThumb: View {
    @Environment(Library.self) private var library
    let id: String
    let book: StretchBook
    var size: CGFloat = 36
    var body: some View {
        Group {
            if StretchLibrary.item(id) != nil {
                FigureView(id: id, size: size)
            } else if let image = library.image(book.custom(id)?.photo) {
                Image(uiImage: image).resizable().scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                IconMark(.hand("yoga"), size: size * 0.6, colour: Gym.tint)
            }
        }
        .frame(width: size, height: size)
    }
}

/// Choose the stretches (since 2.0, phone B of the pictures): "My stretches" in his order — tick to
/// remove, star, drag to reorder, tap to change the hold time — and the library by body area below.
/// With a visit, today's suggestions are added ticked; they are saved into the book only at Start.
struct StretchChooser: View {
    @Environment(Library.self) private var library
    let visitID: UUID?
    let onStart: ([StretchPick]) -> Void
    let onCancel: () -> Void

    @State private var book = StretchBook()
    /// His order including today's suggestions (shown ticked).
    @State private var mine: [String] = []
    @State private var suggested: Set<String> = []
    @State private var words = ""
    @State private var loaded = false
    @State private var holdFor: String?
    @State private var form: FormTarget?

    struct FormTarget: Identifiable { let id = UUID(); var stretch: CustomStretch? }

    private var minutes: Int {
        let secs = StretchTimer.total(StretchTimer.phases(for: book.picks(mine)))
        return max(1, Int((Double(secs) / 60).rounded()))
    }

    private var areas: [(key: String, title: String, ids: [String])] {
        var out: [(String, String, [String])] = []
        for a in StretchArea.allCases where a != .warm {
            var ids = StretchLibrary.stretches.filter { $0.area == a }.map(\.id)
            ids += book.custom.filter { $0.area == a.rawValue }.map(\.id)
            out.append((a.rawValue, a.title, ids.sorted { book.favourites.contains($0) && !book.favourites.contains($1) }))
        }
        let own = book.custom.filter { c in c.area.flatMap(StretchArea.init(rawValue:)) == nil }.map(\.id)
        if !own.isEmpty { out.append(("own", "My own", own)) }
        return out.filter { !$0.2.isEmpty }
    }

    private func amount(_ id: String) -> String { book.pick(id)?.amount ?? "" }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Stretches").font(.system(.title, design: .rounded).weight(.bold)).foregroundStyle(Theme.ink)
                    Spacer()
                    Button(action: onCancel) { ControlMarkView(.close, size: 18, colour: Theme.muted) }
                        .buttonStyle(.plain)
                        .frame(width: 44, height: 44)
                        .accessibilityLabel("Close")
                        .accessibilityIdentifier("stretch-choose-close")
                }
                HStack {
                    if !words.isEmpty {
                        Text("Suggested for today: \(words)").font(.footnote).foregroundStyle(Theme.muted)
                            .accessibilityIdentifier("stretch-suggested-line")
                    }
                    Spacer()
                    Text("\(mine.count) chosen").font(.footnote).foregroundStyle(Theme.muted)
                        .accessibilityIdentifier("stretch-choose-count")
                    Button(mine.isEmpty ? "Usual" : "None") {
                        mine = mine.isEmpty ? StretchBook.defaultTicks : []
                        suggested = []
                        persist()
                    }
                    .font(.footnote.weight(.semibold)).foregroundStyle(Gym.tint)
                    .accessibilityIdentifier("stretch-choose-all")
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            List {
                Section {
                    ForEach(Array(mine.enumerated()), id: \.element) { i, id in mineRow(i + 1, id) }
                        .onMove { from, to in mine.move(fromOffsets: from, toOffset: to); persist() }
                    if mine.isEmpty {
                        Text("Nothing chosen yet. Tap a stretch below to add it.")
                            .font(.footnote).foregroundStyle(Theme.muted)
                    }
                } header: {
                    Text("My stretches").font(.footnote.weight(.semibold)).foregroundStyle(Gym.tint)
                }
                Section {
                    Button { form = FormTarget(stretch: nil) } label: {
                        MarkLabel(title: "Own stretch", mark: .add, size: 18, colour: Gym.tint)
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("stretch-own-add")
                    Text("Hold the handle and drag to change the order.").font(.caption).foregroundStyle(Theme.muted)
                }
                ForEach(areas, id: \.key) { area in
                    Section {
                        ForEach(area.ids, id: \.self) { libraryRow($0) }
                    } header: {
                        Text(area.title).font(.footnote.weight(.semibold)).foregroundStyle(Gym.tint)
                            .accessibilityIdentifier("stretch-area-\(area.key)")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .environment(\.editMode, .constant(.active))
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, 40)

            VStack(spacing: 4) {
                Button(action: start) {
                    Text("Start · about \(minutes) min").font(.headline)
                }
                .buttonStyle(BigButtonStyle(fill: Gym.done, ink: .white, height: 52))
                .disabled(mine.isEmpty)
                .opacity(mine.isEmpty ? 0.5 : 1)
                .accessibilityIdentifier("stretch-choose-start")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Theme.bg.ignoresSafeArea(edges: .bottom))
        }
        .background(Theme.bg.ignoresSafeArea())
        .onAppear(perform: load)
        .sheet(item: Binding(get: { holdFor.map { HoldTarget(id: $0) } }, set: { holdFor = $0?.id })) { t in
            HoldSheet(id: t.id, book: book,
                      onEdit: { id in holdFor = nil; form = FormTarget(stretch: book.custom(id)) },
                      onSave: { secs in book.setHold(t.id, seconds: secs); persist(); holdFor = nil },
                      onCancel: { holdFor = nil })
                .presentationDetents([.height(300)])
        }
        .sheet(item: $form) { f in
            CustomStretchForm(initial: f.stretch,
                              onSave: { c in
                                  let isNew = book.custom(c.id) == nil
                                  book.save(custom: c)
                                  if isNew { mine.append(c.id) }
                                  persist(); form = nil
                              },
                              onDelete: f.stretch == nil ? nil : { id in
                                  book.delete(custom: id); mine.removeAll { $0 == id }; suggested.remove(id)
                                  persist(); form = nil
                              },
                              onCancel: { form = nil })
        }
    }

    struct HoldTarget: Identifiable { let id: String }

    // MARK: Rows

    private func mineRow(_ n: Int, _ id: String) -> some View {
        let fav = book.favourites.contains(id)
        return HStack(spacing: 10) {
            Button { mine.removeAll { $0 == id }; suggested.remove(id); persist() } label: {
                ZStack {
                    Circle().fill(Gym.done)
                    ControlMarkView(.check, size: 13, colour: .white)
                }
                .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(book.name(of: id) ?? "stretch")")
            .accessibilityIdentifier("stretch-choose-\(n)")
            Button { holdFor = id } label: {
                HStack(spacing: 10) {
                    StretchThumb(id: id, book: book)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(book.name(of: id) ?? id).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.leading)
                        HStack(spacing: 4) {
                            if suggested.contains(id) {
                                Circle().fill(Gym.busyTint).frame(width: 6, height: 6)
                                Text("suggested ·").font(.caption).foregroundStyle(Gym.busyTint)
                            }
                            Text(amount(id)).font(.caption).foregroundStyle(Theme.muted)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("stretch-mine-\(n)")
            starButton(id, fav, "stretch-fav-\(n)")
            // The system handle sits at the right edge in move mode; this names it for tests and VoiceOver.
            Color.clear.frame(width: 1, height: 24)
                .accessibilityElement().accessibilityLabel("Drag to move")
                .accessibilityIdentifier("stretch-drag-\(n)")
        }
    }

    private func libraryRow(_ id: String) -> some View {
        let on = mine.contains(id)
        return HStack(spacing: 10) {
            Button {
                if on { mine.removeAll { $0 == id }; suggested.remove(id) } else { mine.append(id) }
                persist()
            } label: {
                HStack(spacing: 10) {
                    StretchThumb(id: id, book: book)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(book.name(of: id) ?? id).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.leading)
                        Text(amount(id)).font(.caption).foregroundStyle(Theme.muted)
                    }
                    Spacer(minLength: 0)
                    if on { ControlMarkView(.check, size: 16, colour: Gym.done) }
                    else { StretchMarkView(mark: .plus, size: 16, colour: Gym.tint) }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(book.name(of: id) ?? id)
            .accessibilityValue(on ? "chosen" : "not chosen")
            .accessibilityIdentifier("stretch-add-\(id)")
            starButton(id, book.favourites.contains(id), "stretch-libfav-\(id)")
        }
    }

    private func starButton(_ id: String, _ fav: Bool, _ ident: String) -> some View {
        Button { book.toggleFavourite(id); persist() } label: {
            StretchMarkView(mark: .star, size: 18, colour: fav ? Gym.better : Theme.muted)
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(fav ? "Remove favourite" : "Favourite")
        .accessibilityIdentifier(ident)
    }

    // MARK: Memory

    private func load() {
        guard !loaded else { return }
        loaded = true
        // The old stretch list becomes the book on first use; the old list itself stays.
        library.changeGym { $0.migrateStretchBook(workouts: library.workouts) }
        book = library.gym.stretchBook ?? StretchBook()
        mine = book.ticked.filter { book.name(of: $0) != nil }
        if let id = visitID, let visit = library.gym.visits.first(where: { $0.id == id }) {
            words = library.gym.trainedWords(in: visit)
            let extra = library.gym.suggestedStretches(for: visit).filter { !mine.contains($0) }
            suggested = Set(extra)
            mine += extra
        }
    }

    /// Ticks and order without today's suggestions (they join the book at Start).
    private func persist() {
        book.ticked = mine.filter { !suggested.contains($0) }
        let b = book
        library.changeGym { $0.stretchBook = b }
    }

    private func start() {
        suggested = []
        persist()
        book.ticked = mine
        let b = book
        library.changeGym { $0.stretchBook = b }
        onStart(book.picks(mine))
    }
}

/// Change one stretch's hold time, ±5 s (since 2.0).
private struct HoldSheet: View {
    let id: String
    let book: StretchBook
    let onEdit: (String) -> Void
    let onSave: (Int) -> Void
    let onCancel: () -> Void
    @State private var seconds = 30

    var body: some View {
        VStack(spacing: 14) {
            Text(book.name(of: id) ?? "Stretch").font(.headline).foregroundStyle(Theme.ink)
            HStack(spacing: 18) {
                Button { seconds = max(5, seconds - 5) } label: {
                    Text("− 5 s").font(.headline).foregroundStyle(Gym.tint)
                        .frame(width: 84, height: 44).background(Gym.fill.opacity(0.12), in: Capsule())
                }
                .accessibilityIdentifier("stretch-hold-minus")
                Text("\(seconds) s").font(.system(.title, design: .rounded).weight(.bold)).monospacedDigit()
                    .frame(minWidth: 80).accessibilityIdentifier("stretch-hold-value")
                Button { seconds = min(600, seconds + 5) } label: {
                    Text("+ 5 s").font(.headline).foregroundStyle(Gym.tint)
                        .frame(width: 84, height: 44).background(Gym.fill.opacity(0.12), in: Capsule())
                }
                .accessibilityIdentifier("stretch-hold-plus")
            }
            .buttonStyle(.plain)
            Text((book.pick(id)?.sides ?? 1) == 2 ? "each side" : "one hold").font(.footnote).foregroundStyle(Theme.muted)
            if book.custom(id) != nil {
                Button("Edit this stretch") { onEdit(id) }
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Gym.tint)
                    .accessibilityIdentifier("stretch-hold-edit")
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 20)
        .frame(maxWidth: .infinity)
        .background(Theme.bg.ignoresSafeArea())
        .accessibilityIdentifier("stretch-hold-sheet")
        .onAppear { seconds = book.pick(id)?.seconds ?? 30 }
        .bottomActions(cancel: onCancel, save: { onSave(seconds) }, tint: Gym.fill,
                       cancelID: "stretch-hold-cancel", saveID: "stretch-hold-save")
    }
}

/// The old chooser for a stretch list from a checklist (since 1.34, his ask): tick the stretches to do this time. All are ticked at first;
/// stretches already held show a check and stay as they are.
struct ListStretchChooser: View {
    let all: [StretchPick]
    @Binding var picked: Set<String>
    let tint: Color
    let ink: Color
    let title: String
    var held: Set<String> = []
    let action: () -> Void

    private var minutes: Int {
        let secs = StretchTimer.total(StretchTimer.phases(for: all.filter { picked.contains($0.id) && !held.contains($0.id) }))
        return max(1, Int((Double(secs) / 60).rounded()))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 8) {
                    HStack {
                        Text("\(picked.count) of \(all.count) chosen")
                            .font(.subheadline).foregroundStyle(Theme.muted)
                            .accessibilityIdentifier("stretch-choose-count")
                        Spacer()
                        Button(picked.count == all.count ? "None" : "All") {
                            picked = picked.count == all.count ? held : Set(all.map(\.id))
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Gym.tint)
                        .accessibilityIdentifier("stretch-choose-all")
                    }
                    ForEach(Array(all.enumerated()), id: \.element.id) { n, e in
                        let on = picked.contains(e.id)
                        let done = held.contains(e.id)
                        Button {
                            guard !done else { return }
                            if on { picked.remove(e.id) } else { picked.insert(e.id) }
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle().fill(on ? tint : Color.clear)
                                    Circle().stroke(on ? tint : Theme.line, lineWidth: 1.5)
                                    if on { ControlMarkView(.check, size: 14, colour: ink) }
                                }
                                .frame(width: 26, height: 26)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(e.name).font(.body.weight(.semibold)).foregroundStyle(Theme.ink)
                                    if done || !e.amount.isEmpty {
                                        Text(done ? "Held" : e.amount).font(.footnote)
                                            .foregroundStyle(done ? SessionGoingLine.green : Theme.muted)
                                    }
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(on ? tint.opacity(0.6) : Theme.line, lineWidth: 1))
                            .opacity(done ? 0.6 : 1)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(e.name)
                        .accessibilityValue(on ? "chosen" : "not chosen")
                        .accessibilityIdentifier("stretch-choose-\(n + 1)")
                    }
                }
                .padding(16)
            }
            VStack(spacing: 4) {
                Button(action: action) {
                    MarkLabel(title: title, mark: .play, size: 20, colour: ink)
                }
                .buttonStyle(BigButtonStyle(fill: tint, ink: ink, height: 56))
                .disabled(picked.subtracting(held).isEmpty)
                .opacity(picked.subtracting(held).isEmpty ? 0.5 : 1)
                .accessibilityIdentifier("stretch-choose-start")
                Text("About \(minutes) min · voice cues in your AirPods")
                    .font(.footnote).foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Theme.bg.ignoresSafeArea(edges: .bottom))
        }
    }
}
