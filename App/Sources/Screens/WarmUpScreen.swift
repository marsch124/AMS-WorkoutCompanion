import AMSIcons
import SwiftUI
import WorkoutCore

/// What he chose on the warm-up page.
struct WarmChoice {
    var kind: VisitPart.Kind
    var machineID: UUID?
    var minutes: Int
    /// Warm-up moves: library ids in his order.
    var moves: [String]
}

/// A number typed with a comma or a point.
enum WarmNumber {
    static func parse(_ text: String) -> Double? {
        Double(text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
    }
    static func text(_ v: Double?) -> String { v.map { GymSet.number($0) } ?? "" }
}

/// The warm-up, start to end, as one full-screen cover: choose → run → back to the gym page (since 2.0).
struct WarmUpFlow: View {
    @Environment(Library.self) private var library
    let gymID: UUID?
    let day: Date
    let close: () -> Void
    @State private var run: WarmRun?

    var body: some View {
        Group {
            if let run {
                WarmUpRunScreen(run: run, day: day, gymID: gymID, finished: close)
            } else {
                WarmUpScreen(gymID: gymID, cancel: close) { start($0) }
            }
        }
        .environment(library)
    }

    private func start(_ c: WarmChoice) {
        // Remembered for next time: what, how long, which machine, which moves in which order.
        library.changeGym {
            var book = $0.stretchBook ?? StretchBook()
            var warm = book.warm ?? WarmPrefs()
            warm.kind = c.kind; warm.minutes = c.minutes; warm.machineID = c.machineID
            if c.kind == .moves { warm.moves = c.moves }
            book.warm = warm
            $0.stretchBook = book
        }
        let minutes = c.kind == .moves ? max(1, Int((Double(WarmRun.segments(c.moves).reduce(0) { $0 + $1.seconds }) / 60).rounded(.up))) : c.minutes
        var id = UUID()
        library.changeGym { id = $0.startWarmup(kind: c.kind, gymID: gymID, machineID: c.machineID, plannedMinutes: minutes) }
        run = WarmRun(visitID: id, kind: c.kind, machineID: c.machineID, minutes: minutes, moves: c.moves)
    }
}

/// Which warm-up is running.
struct WarmRun {
    let visitID: UUID
    let kind: VisitPart.Kind
    let machineID: UUID?
    let minutes: Int
    let moves: [String]

    struct Segment { let id: String; let name: String; let seconds: Int; let mirrored: Bool }

    /// Each move for its seconds; a two-sided move runs twice, the second time mirrored.
    static func segments(_ moves: [String]) -> [Segment] {
        moves.compactMap { StretchLibrary.item($0) }.flatMap { m in
            (0..<max(1, m.sides)).map { Segment(id: m.id, name: m.name, seconds: m.seconds, mirrored: $0 == 1) }
        }
    }
}

/// Choose the warm-up: one of his time machines, a walk or run to the gym, or warm-up moves (since 2.0).
struct WarmUpScreen: View {
    @Environment(Library.self) private var library
    let gymID: UUID?
    let cancel: () -> Void
    let start: (WarmChoice) -> Void

    @State private var kind: VisitPart.Kind = .outside
    @State private var machineID: UUID?
    @State private var minutes = 8
    @State private var order: [String] = []
    @State private var ticked: Set<String> = []
    @State private var loaded = false

    private var cardio: [Machine] { library.gym.machines(in: gymID).filter { $0.logs == .time } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    FlowLayout(spacing: 8) {
                        ForEach(Array(cardio.enumerated()), id: \.element.id) { i, m in
                            chip(m.name, on: kind == .cardio && machineID == m.id, id: "warmup-choose-\(i + 1)") {
                                kind = .cardio; machineID = m.id
                            }
                        }
                        chip("Walk or run to the gym", on: kind == .outside, id: "warmup-choose-outside") { kind = .outside }
                        chip("Warm-up moves", on: kind == .moves, id: "warmup-choose-moves") { kind = .moves }
                    }
                    if kind != .moves {
                        HStack {
                            Text("Minutes").font(.headline).foregroundStyle(Gym.tint)
                            Spacer()
                            stepButton("−", id: "warmup-minutes-minus") { minutes = max(1, minutes - 1) }
                            Text("\(minutes)")
                                .font(.system(.title2, design: .rounded).weight(.bold).monospacedDigit())
                                .frame(minWidth: 44)
                                .accessibilityIdentifier("warmup-minutes")
                            stepButton("+", id: "warmup-minutes-plus") { minutes = min(120, minutes + 1) }
                        }
                        .padding(12)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    } else {
                        movesList
                        Text("Hold a move and drag it up or down to change the order.")
                            .font(.caption).foregroundStyle(Theme.muted)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Warm-up")
            .navigationBarTitleDisplayMode(.large)
            .bottomActions(cancel: cancel, save: go, saveTitle: "Start", tint: Theme.accent,
                           cancelID: "warmup-cancel", saveID: "warmup-start")
        }
        .onAppear(perform: load)
    }

    // MARK: Pieces

    private func chip(_ title: String, on: Bool, id: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(on ? Color.white : Theme.ink)
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(on ? Theme.accent : Theme.card, in: Capsule())
                .overlay(Capsule().stroke(Theme.line, lineWidth: on ? 0 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
        .accessibilityIdentifier(id)
    }

    private func stepButton(_ title: String, id: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(Gym.tint)
                .frame(width: 44, height: 36)
                .background(Gym.soft, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title == "+" ? "One minute more" : "One minute less")
        .accessibilityIdentifier(id)
    }

    /// The ten moves: tick, and drag to change the order.
    private var movesList: some View {
        VStack(spacing: 0) {
            ForEach(Array(order.enumerated()), id: \.element) { i, id in
                if let m = StretchLibrary.item(id) {
                    moveRow(i, m)
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                    .onTapGesture { toggle(id) }
                    .draggable(id) { Text(m.name).padding(8).background(Theme.card, in: Capsule()) }
                    .dropDestination(for: String.self) { items, _ in
                        guard let from = items.first, let a = order.firstIndex(of: from), let b = order.firstIndex(of: id) else { return false }
                        withAnimation { order.move(fromOffsets: IndexSet(integer: a), toOffset: b > a ? b + 1 : b) }
                        return true
                    }
                    if i < order.count - 1 { Divider().padding(.leading, 56) }
                }
            }
        }
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.line, lineWidth: 1))
        .accessibilityIdentifier("warmup-moves")
    }

    private func moveRow(_ i: Int, _ m: StretchItem) -> some View {
        let on = ticked.contains(m.id)
        let sub = m.sides == 2 ? "\(m.seconds) s each side" : "\(m.seconds) s"
        return HStack(spacing: 10) {
            Button { toggle(m.id) } label: {
                ZStack {
                    Circle().fill(on ? Gym.done : Color.clear)
                    Circle().stroke(on ? Gym.done : Theme.muted, lineWidth: 1.5)
                    if on { ControlMarkView(.check, size: 13, colour: .white) }
                }
                .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(on ? "\(m.name), ticked" : "\(m.name), not ticked")
            .accessibilityIdentifier("warmup-move-\(i + 1)")
            FigureView(id: m.id, size: 36, tint: Theme.accent)
            VStack(alignment: .leading, spacing: 0) {
                Text(m.name).font(.body)
                Text(sub).font(.caption).foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 4)
        }
    }

    // MARK: Actions

    private func toggle(_ id: String) {
        if ticked.contains(id) { ticked.remove(id) } else { ticked.insert(id) }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        let warm = library.gym.stretchBook?.warm
        minutes = max(1, warm?.minutes ?? 8)
        let all = StretchLibrary.moves.map(\.id)
        let saved = (warm?.moves ?? []).filter { all.contains($0) }
        order = saved + all.filter { !saved.contains($0) }
        ticked = Set(saved.isEmpty ? all : saved)
        let remembered = warm?.machineID.flatMap { id in cardio.first { $0.id == id } }
        switch warm?.kind {
        case .cardio?:
            if let remembered { kind = .cardio; machineID = remembered.id } else { fallback() }
        case .moves?: kind = .moves
        case .outside?: kind = .outside
        default: fallback()
        }
    }

    private func fallback() {
        if let m = cardio.first { kind = .cardio; machineID = m.id } else { kind = .outside }
    }

    private func go() {
        var picked = order.filter { ticked.contains($0) }
        if kind == .moves, picked.isEmpty { picked = order }
        start(WarmChoice(kind: kind, machineID: kind == .cardio ? machineID : nil, minutes: minutes, moves: picked))
    }
}

/// Chips that wrap onto the next line.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layout(subviews, width: proposal.width ?? 320).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let l = layout(subviews, width: bounds.width)
        for (i, p) in l.points.enumerated() {
            subviews[i].place(at: CGPoint(x: bounds.minX + p.x, y: bounds.minY + p.y), proposal: .unspecified)
        }
    }

    private func layout(_ subviews: Subviews, width: CGFloat) -> (size: CGSize, points: [CGPoint]) {
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, maxX: CGFloat = 0
        var points: [CGPoint] = []
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width { x = 0; y += rowH + spacing; rowH = 0 }
            points.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowH = max(rowH, size.height)
            maxX = max(maxX, x - spacing)
        }
        return (CGSize(width: maxX, height: y + rowH), points)
    }
}
