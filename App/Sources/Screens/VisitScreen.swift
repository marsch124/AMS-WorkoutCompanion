import AMSIcons
import SwiftUI
import WorkoutCore

/// One earlier visit: its title and notes, and every machine with its sets.
struct VisitScreen: View {
    @Environment(Library.self) private var library
    let visitID: UUID
    @State private var editing = false
    @State private var timing = false
    @State private var changing: ChangingSet?
    @State private var picture: Image?
    /// How many machine photos the share picture holds — read by a test.
    @State private var sharePhotos = 0

    private struct ChangingSet: Identifiable {
        let entryID: UUID
        let index: Int
        var id: String { "\(entryID)-\(index)" }
    }

    // A colourful page (1.9.1, his "This history page is boring"): the visit in tiles, then a card per machine.
    var body: some View {
        let visit = library.gym.visits.first { $0.id == visitID }
        ScrollView {
            if let visit {
                VStack(alignment: .leading, spacing: 10) {
                    header(visit)
                    let bests = library.gym.newBests(in: visit)
                    if !bests.isEmpty {
                        HStack(spacing: 8) {
                            IconMark(.hand("trophy"), size: 22, colour: Gym.tint)
                            Text("New best: " + bests.compactMap { library.gym.machine($0)?.name }.joined(separator: ", "))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.ink)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Gym.fill.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("visit-bests")
                    }
                    if visit.title != nil || visit.notes != nil {
                        VStack(alignment: .leading, spacing: 4) {
                            if let t = visit.title {
                                Text(t).font(.headline).foregroundStyle(Gym.tint).accessibilityIdentifier("visit-title")
                            }
                            if let n = visit.notes {
                                Text(n).font(.subheadline).foregroundStyle(Theme.ink).accessibilityIdentifier("visit-notes")
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Photos").font(.headline).foregroundStyle(Gym.tint)
                        SessionPhotos(visitID: visit.id)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    ForEach(Array(visit.entries.enumerated()), id: \.element.id) { n, e in machineCard(e, position: n + 1) }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle(visit?.date.formatted(date: .abbreviated, time: .omitted) ?? "Visit")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { renderPicture() }
        .onChange(of: visit) { _, _ in renderPicture() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let visit, let picture {
                    ShareLink(item: picture, preview: SharePreview(visit.title ?? "Gym visit", image: picture)) {
                        ShareMark().stroke(Gym.tint, style: StrokeStyle(lineWidth: 1.9, lineCap: .round, lineJoin: .round)).frame(width: 22, height: 22)
                    }
                    .accessibilityLabel("Share this visit")
                    .accessibilityValue("\(sharePhotos) photos")
                    .accessibilityIdentifier("visit-share")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { editing = true } label: { ControlMarkView(.edit, size: 22, colour: Gym.tint) }
                    .accessibilityLabel("Title and notes")
                    .accessibilityIdentifier("visit-edit")
            }
        }
        .sheet(item: $changing) { c in
            if let e = visit?.entries.first(where: { $0.id == c.entryID }), e.sets.indices.contains(c.index) {
                NavigationStack {
                    VisitSetEditor(set: e.sets[c.index], logs: library.gym.machine(e.machineID)?.logs ?? .weights,
                                   hasLevel: library.gym.machine(e.machineID)?.hasLevel ?? true,
                                   hasIncline: library.gym.machine(e.machineID)?.hasIncline ?? true) { result, remove in
                        changing = nil
                        if remove {
                            library.changeGym(undo: "Set removed") { $0.change(visit: visitID, entry: c.entryID, set: c.index, to: nil) }
                        } else if let result {
                            library.changeGym { $0.change(visit: visitID, entry: c.entryID, set: c.index, to: result) }
                        }
                    }
                }
                .presentationDetents([.medium, .large])
            }
        }
        .sheet(isPresented: $timing) {
            if let visit {
                NavigationStack {
                    VisitTimeEditor(minutes: visit.minutes ?? 0, byHand: visit.minutesByHand != nil) { result in
                        timing = false
                        if let result { library.changeGym { $0.setMinutes(visit: visitID, result) } }
                    }
                }
                .presentationDetents([.medium])
            }
        }
        .sheet(isPresented: $editing) {
            if let visit {
                NavigationStack {
                    NotesForm(placeholder: visit.suggestedTitle(in: library.gym), title: visit.title ?? "",
                              notes: visit.notes ?? "", colour: Gym.fill) { result in
                        editing = false
                        if let result { library.changeGym { $0.describe(visit: visitID, title: result.title, notes: result.notes) } }
                    }
                }
            }
        }
    }

    private func renderPicture() {
        guard let visit = library.gym.visits.first(where: { $0.id == visitID }) else { return }
        let drawn = VisitShareCard.render(visit, gym: library.gym) { library.image($0) }
        picture = drawn?.image
        sharePhotos = drawn?.photos ?? 0
        // Test runs keep a copy of the picture, to look at it (never on his iPhone: -uitest only).
        if ProcessInfo.processInfo.arguments.contains("-uitest"), let ui = VisitShareCard.renderUIImage(visit, gym: library.gym, photo: { library.image($0) }) {
            try? ui.pngData()?.write(to: FileManager.default.temporaryDirectory.appendingPathComponent("uitest/share.png"))
        }
    }

    private func header(_ visit: GymVisit) -> some View {
        let place = library.gym.gyms.first { $0.id == visit.gymID }?.name ?? "At the gym"
        return VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 0) {
                Text(GymVisit.dateText(visit.date))
                    .font(.title2.weight(.bold))
                    .accessibilityIdentifier("visit-date")
                    .foregroundStyle(Gym.ink)
                Text(place).font(.subheadline.weight(.semibold)).foregroundStyle(Gym.ink.opacity(0.85))
            }
            HStack(spacing: 8) {
                tile("Time", visit.minutes.map { "\($0) min" } ?? "–", "green", id: "visit-time", editable: true)
                    .contentShape(Rectangle())
                    .onTapGesture { timing = true }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint("Change the time")
                tile("Sets", "\(visit.setCount)", "orange", id: "visit-sets")
            }
            HStack(spacing: 8) {
                // No "0 kg" on a cardio-only visit: its time-machine minutes instead (1.13).
                if visit.totalKg > 0 {
                    tile("Lifted", "\(GymSet.number(visit.totalKg)) kg", "plum", id: "visit-kg")
                } else {
                    tile("On time machines", "\(visit.minutesOnMachines) min", "plum", id: "visit-cardio")
                }
                tile("Machines", "\(visit.entries.count)", "blue", id: "visit-machines")
            }
        }
        .padding(12)
        .background(Gym.fill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func tile(_ title: String, _ value: String, _ colour: String, id: String, editable: Bool = false) -> some View {
        let c = IconColour.of(key: colour) ?? Gym.busy
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Text(title).font(.caption.weight(.semibold)).foregroundStyle(c.inkColor.opacity(0.85))
                if editable { ControlMarkView(.edit, size: 11, colour: c.inkColor.opacity(0.85)) }
            }
            Text(value).font(.title3.weight(.bold)).monospacedDigit().foregroundStyle(c.inkColor)
                .accessibilityIdentifier(id)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(c.fillColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func machineCard(_ e: MachineEntry, position: Int) -> some View {
        let m = library.gym.machine(e.machineID)
        let muscle = library.gym.muscle(for: m)
        let accent = muscle.flatMap { IconColour.of(key: $0.colour) }?.fillColor ?? Gym.fill
        return HStack(alignment: .top, spacing: 10) {
            MachinePhoto(name: m?.photo, height: 56, icon: m?.icon)
                .frame(width: 56)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(m?.name ?? "Machine").font(.body.weight(.semibold)).foregroundStyle(Theme.ink)
                    if let muscle {
                        Text(muscle.name)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .overlay(Capsule().stroke(accent, lineWidth: 1))
                    }
                }
                // Each set as a small chip: "32,5 × 12".
                FlowChips(items: e.sets.enumerated().map { i, set in
                    let said = set.isTime || m?.logs == .reps ? library.gym.text(set, machine: e.machineID)
                        : "\(set.kg <= 0 ? "BW" : GymSet.number(set.kg)) × \(set.reps)"
                    return ChipItem(text: (set.isWarmup ? "W " : "") + said, warmup: set.isWarmup, id: "visit-set-\(position)-\(i + 1)")
                }, colour: accent) { i in changing = ChangingSet(entryID: e.id, index: i) }
                if let next = e.nextTime {
                    Text("Next time: \(library.gym.text(next, machine: e.machineID))")
                        .font(.caption.weight(.semibold)).foregroundStyle(Gym.tint)
                }
                if let note = e.note {
                    Text("“\(note)”").font(.caption).foregroundStyle(Theme.ink)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2).fill(accent).frame(width: 4).padding(.vertical, 10)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("visit-machine-\(m?.name ?? "")")
    }
}

struct ChipItem {
    let text: String
    let warmup: Bool
    let id: String
}

/// Small capsules that wrap onto the next line; tap one to change that set.
private struct FlowChips: View {
    let items: [ChipItem]
    let colour: Color
    let tap: (Int) -> Void

    var body: some View {
        ChipLayout(spacing: 5) {
            ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                Button { tap(i) } label: {
                    Text(item.text)
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(item.warmup ? Theme.muted : Theme.ink)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(colour.opacity(item.warmup ? 0.07 : 0.16), in: Capsule())
                        .overlay(item.warmup ? Capsule().stroke(colour.opacity(0.4), lineWidth: 1) : nil)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(item.id)
            }
        }
    }
}

/// The time of a visit, typed by hand (since 1.11.2) — for a session whose time came out wrong.
private struct VisitTimeEditor: View {
    @State var minutes: Int
    let byHand: Bool
    let done: (Int?) -> Void

    init(minutes: Int, byHand: Bool, done: @escaping (Int?) -> Void) {
        _minutes = State(initialValue: minutes)
        self.byHand = byHand
        self.done = done
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Minutes")
                    Spacer()
                    TextField("30", value: $minutes, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .accessibilityIdentifier("visit-time-minutes")
                }
            } footer: {
                Text("How long the session really took. It counts in History and the statistics.")
            }
            if byHand {
                Section {
                    Button("Use the time from my sets") { done(0) }
                        .accessibilityIdentifier("visit-time-reset")
                }
            }
        }
        .navigationTitle("Session time")
        .navigationBarTitleDisplayMode(.inline)
        .bottomActions(cancel: { done(nil) }, save: { done(max(0, minutes)) }, tint: Gym.fill,
                       cancelID: "visit-time-cancel", saveID: "visit-time-save")
    }
}

/// Change or remove one set of an earlier visit.
private struct VisitSetEditor: View {
    @State var value: GymSet
    let logs: MachineLogs
    let hasLevel: Bool
    let hasIncline: Bool
    let done: (GymSet?, Bool) -> Void
    @State private var minutes: Double

    init(set: GymSet, logs: MachineLogs, hasLevel: Bool, hasIncline: Bool, done: @escaping (GymSet?, Bool) -> Void) {
        _value = State(initialValue: set)
        _minutes = State(initialValue: Double(set.seconds ?? 0) / 60)
        self.logs = logs
        self.hasLevel = hasLevel
        self.hasIncline = hasIncline
        self.done = done
    }

    private var isTime: Bool { value.isTime }

    var body: some View {
        Form {
            Section {
                if isTime {
                    field("Minutes", "", "visit-set-minutes", $minutes)
                    if value.level != nil { field("Level", "", "visit-set-level", levelBinding) }
                    if value.incline != nil { field("Incline", "%", "visit-set-incline", inclineBinding) }
                } else {
                    if logs != .reps { field("Weight", "kg", "visit-set-kg", $value.kg) }
                    HStack {
                        Text("Reps")
                        Spacer()
                        TextField("0", value: $value.reps, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("visit-set-reps")
                    }
                    Toggle("Warm-up", isOn: Binding(get: { value.isWarmup }, set: { value.warmup = $0 ? true : nil }))
                        .tint(Gym.fill)
                        .accessibilityIdentifier("visit-set-warmup")
                }
            }
            Section {
                Button("Remove this set", role: .destructive) { done(nil, true) }
                    .accessibilityIdentifier("visit-set-remove")
            }
        }
        .navigationTitle("Change set")
        .navigationBarTitleDisplayMode(.inline)
        .bottomActions(cancel: { done(nil, false) }, save: { done(result, false) }, tint: Gym.fill,
                       cancelID: "visit-set-cancel", saveID: "visit-set-save")
    }

    private var result: GymSet {
        var s = value
        if isTime { s.seconds = max(1, Int((minutes * 60).rounded())) } else { s.reps = max(0, s.reps) }
        return s
    }

    private var levelBinding: Binding<Double> { Binding(get: { value.level ?? 0 }, set: { value.level = $0 }) }
    private var inclineBinding: Binding<Double> { Binding(get: { value.incline ?? 0 }, set: { value.incline = $0 }) }

    private func field(_ title: String, _ unit: String, _ id: String, _ value: Binding<Double>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", value: value, format: .number.precision(.fractionLength(0...2)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .accessibilityIdentifier(id)
            if !unit.isEmpty { Text(unit).foregroundStyle(Theme.muted) }
        }
    }
}

private struct ChipLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        rows(proposal.width ?? 300, subviews).last.map { CGSize(width: proposal.width ?? 300, height: $0.y + $0.h) } ?? .zero
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (i, p) in place(bounds.width, subviews).enumerated() {
            subviews[i].place(at: CGPoint(x: bounds.minX + p.x, y: bounds.minY + p.y), proposal: .unspecified)
        }
    }

    private func place(_ width: CGFloat, _ subviews: Subviews) -> [CGPoint] {
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, out: [CGPoint] = []
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > 0 && x + s.width > width { x = 0; y += rowH + spacing; rowH = 0 }
            out.append(CGPoint(x: x, y: y))
            x += s.width + spacing
            rowH = max(rowH, s.height)
        }
        return out
    }

    private func rows(_ width: CGFloat, _ subviews: Subviews) -> [(y: CGFloat, h: CGFloat)] {
        var y: CGFloat = 0, x: CGFloat = 0, rowH: CGFloat = 0, out: [(CGFloat, CGFloat)] = []
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > 0 && x + s.width > width { out.append((y, rowH)); x = 0; y += rowH + spacing; rowH = 0 }
            x += s.width + spacing
            rowH = max(rowH, s.height)
        }
        if !subviews.isEmpty { out.append((y, rowH)) }
        return out.map { (y: $0.0, h: $0.1) }
    }
}

/// A hand-drawn share mark (tray with an arrow up) on the 24-point grid; the icon hub has none yet.
private struct ShareMark: Shape {
    func path(in rect: CGRect) -> Path {
        let k = min(rect.width, rect.height) / 24
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * k, y: rect.minY + y * k) }
        var p = Path()
        p.move(to: pt(12, 15)); p.addLine(to: pt(12, 4))
        p.move(to: pt(8, 8)); p.addLine(to: pt(12, 4)); p.addLine(to: pt(16, 8))
        p.move(to: pt(8, 11)); p.addLine(to: pt(5.5, 11)); p.addLine(to: pt(5.5, 20)); p.addLine(to: pt(18.5, 20)); p.addLine(to: pt(18.5, 11)); p.addLine(to: pt(16, 11))
        return p
    }
}
