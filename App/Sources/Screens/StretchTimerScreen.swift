import AMSIcons
import Combine
import SwiftUI
import WorkoutCore

/// The guided stretch timer (since 1.32, his ask): it walks through a stretch list and speaks the
/// cues — what comes next, hold, switch sides, halfway, ten seconds, three-two-one — into his
/// AirPods (or the phone's speaker), alongside his music. The screen stays on while it runs.
struct StretchTimerScreen: View {
    @Environment(Library.self) private var library
    /// The old way (checklists, after a session): a list of exercises, chosen here, saved as a SessionRecord.
    let workout: Workout?
    /// Since 2.0, inside a gym visit: the stretches from the chooser; nothing is recorded here, the
    /// result goes back through `onFinish`.
    let picksIn: [StretchPick]
    let onFinish: ((StretchOutcome) -> Void)?
    let onClose: () -> Void

    init(workout: Workout, onClose: @escaping () -> Void) {
        self.workout = workout; self.picksIn = []; self.onFinish = nil; self.onClose = onClose
        _choosing = State(initialValue: true)
    }

    init(picks: [StretchPick], onFinish: @escaping (StretchOutcome) -> Void, onClose: @escaping () -> Void) {
        self.workout = nil; self.picksIn = picks; self.onFinish = onFinish; self.onClose = onClose
        _choosing = State(initialValue: false)
        _picked = State(initialValue: Set(picks.map(\.id)))
    }

    private var tint: Color { workout?.fill ?? Gym.fill }
    private var ink: Color { workout?.inkOnFill ?? Gym.ink }

    @State private var phases: [StretchPhase] = []
    @State private var at = 0
    /// When the running phase ends; nil while paused.
    @State private var endsAt: Date?
    /// Seconds left when paused.
    @State private var leftWhenPaused: Double = 0
    @State private var lastSaid = -1
    @State private var finished = false
    @State private var startedAt = Date()
    @State private var kept = false
    @State private var now = Date()
    /// Since 1.34 (his ask): which stretches of the list to do this time (all at first), and which were held.
    @State private var picked: Set<String> = []
    @State private var held: Set<String> = []
    /// Held stretches in the order they were done, and the ones skipped (since 2.0).
    @State private var heldOrder: [String] = []
    @State private var skipped: Set<String> = []
    /// The stretches the running phases belong to, in order (a phase's index points here).
    @State private var order: [StretchPick] = []
    @State private var choosing: Bool
    @State private var rechoosing = false
    private let tick = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()

    private var phase: StretchPhase? { phases.indices.contains(at) ? phases[at] : nil }
    private var left: Double {
        if let endsAt { return max(0, endsAt.timeIntervalSince(now)) }
        return leftWhenPaused
    }
    private var all: [StretchPick] { workout.map { StretchTimer.picks(for: $0.exercises) } ?? picksIn }
    private var chosenList: [StretchPick] { all.filter { picked.contains($0.id) } }
    private var stretchCount: Int { chosenList.count }
    /// "Stretch 3 of 4": where the current stretch sits among the chosen ones.
    private var currentNumber: Int {
        guard let p = phase, order.indices.contains(p.index),
              let n = chosenList.firstIndex(where: { $0.id == order[p.index].id }) else { return held.count }
        return n + 1
    }
    /// Seconds still to go in the whole list.
    private var totalLeft: Int {
        Int(left.rounded(.up)) + phases.dropFirst(at + 1).reduce(0) { $0 + $1.seconds }
    }

    private func colour(_ k: StretchPhase.Kind) -> Color {
        switch k {
        case .ready: return Gym.busyTint
        case .hold: return SessionGoingLine.green
        case .switchSides: return Gym.tint
        }
    }

    private func label(_ p: StretchPhase) -> String {
        switch p.kind {
        case .ready: return "GET READY"
        case .switchSides: return "SWITCH SIDES"
        case .hold: return p.sides == 2 ? "HOLD · SIDE \(p.side) OF 2" : "HOLD"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if choosing {
                ListStretchChooser(all: all, picked: $picked, tint: tint, ink: ink,
                                   title: "Start", action: begin)
            } else if finished {
                Spacer()
                VStack(spacing: 18) {
                    IconMark(.hand("yoga"), size: 72, colour: SessionGoingLine.green)
                    Text("Stretch done").font(.title.weight(.bold)).foregroundStyle(Theme.ink)
                    Text("\(held.count) of \(stretchCount) stretch\(stretchCount == 1 ? "" : "es") · \(Clock.text(Int(Date().timeIntervalSince(startedAt))))")
                        .font(.subheadline).foregroundStyle(Theme.muted)
                    Button("Close", action: close)
                        .buttonStyle(BigButtonStyle(fill: tint, ink: ink))
                        .accessibilityIdentifier("stretch-timer-close-done")
                }
                .padding(24)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("stretch-timer-done")
                Spacer()
            } else if let phase {
                ScrollView {
                    VStack(spacing: 12) {
                        Text(label(phase))
                            .font(.caption.weight(.bold))
                            .tracking(1)
                            .foregroundStyle(colour(phase.kind))
                            .padding(.horizontal, 12)
                            .frame(height: 26)
                            .background(colour(phase.kind).opacity(0.14), in: Capsule())
                            .accessibilityIdentifier("stretch-timer-phase")
                        figure(phase)
                        Text(phase.name)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.center)
                            .accessibilityIdentifier("stretch-timer-name")
                        ZStack {
                            Ring(fractionLeft: left / Double(max(1, phase.seconds)), colour: colour(phase.kind), width: 10)
                                .animation(.linear(duration: 0.2), value: left)
                            Text("\(Int(left.rounded(.up)))")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(Theme.ink)
                                .contentTransition(.numericText(countsDown: true))
                                .accessibilityIdentifier("stretch-timer-seconds")
                        }
                        .frame(width: 140, height: 140)
                        Button { jump(1) } label: {
                            Text("Skip")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Gym.tint)
                                .padding(.horizontal, 18)
                                .frame(height: 34)
                                .background(Gym.fill.opacity(0.12), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("stretch-skip")
                        guideCard(phase)
                        if let next = phases.dropFirst(at + 1).first(where: { $0.index != phase.index }) {
                            Text("Then: \(next.name)").font(.subheadline).foregroundStyle(Theme.muted)
                                .accessibilityIdentifier("stretch-timer-next")
                        }
                    }
                    .padding(16)
                }
                controls
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .onAppear(perform: prepare)
        .sheet(isPresented: $rechoosing) {
            NavigationStack {
                ListStretchChooser(all: all, picked: $picked, tint: tint, ink: ink,
                                   title: "Go on with these", held: held) {
                    rechoosing = false
                    rebuild()
                }
                .navigationTitle("Choose stretches")
                .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.large])
        }
        .onDisappear { Cues.shared.end() }
        .onReceive(tick) { date in
            now = date
            step()
        }
    }

    /// The big picture of the stretch (since 2.0): the drawn figure (mirrored on side 2), or his own photo.
    @ViewBuilder private func figure(_ phase: StretchPhase) -> some View {
        let pick = order.indices.contains(phase.index) ? order[phase.index] : nil
        Group {
            if let fig = phase.figureID, FigureView.has(fig) || pick?.photo == nil {
                FigureView(id: fig, size: 200, mirrored: phase.side == 2, animated: false, tint: Theme.accent)
            } else if let image = library.image(pick?.photo) {
                Image(uiImage: image).resizable().scaledToFill()
                    .frame(width: 200, height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                IconMark(.hand("yoga"), size: 96, colour: Theme.accent)
                    .frame(width: 200, height: 200)
            }
        }
        .frame(width: 200, height: 200)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(phase.name)
        .accessibilityIdentifier("stretch-figure")
    }

    @ViewBuilder private func guideCard(_ phase: StretchPhase) -> some View {
        let pick = order.indices.contains(phase.index) ? order[phase.index] : nil
        let steps: [String]? = phase.figureID.flatMap { StretchLibrary.guide($0)?.steps } ?? StretchRoutine.move(named: phase.name)?.steps
        let feel: String? = phase.figureID.flatMap { StretchLibrary.guide($0)?.feel } ?? StretchRoutine.move(named: phase.name)?.feel
        if let steps {
            VStack(alignment: .leading, spacing: 5) {
                ForEach(Array(steps.enumerated()), id: \.offset) { n, step in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(n + 1).").font(.subheadline.weight(.semibold)).foregroundStyle(Gym.tint)
                            .frame(width: 18, alignment: .trailing)
                        Text(step).font(.subheadline).foregroundStyle(Theme.ink)
                    }
                }
                if let feel { Text(feel).font(.footnote).foregroundStyle(SessionGoingLine.green).padding(.top, 2) }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else if let note = pick?.note, !note.isEmpty {
            Text(note).font(.subheadline).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack {
                CloseButton(action: close)
                    .accessibilityIdentifier("stretch-timer-close")
                Spacer()
                VStack(spacing: 2) {
                    Text((workout?.name ?? "").isEmpty ? "Stretch" : workout!.name)
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(Theme.ink)
                    Text(choosing ? "Choose the stretches for today" : finished ? "Done" : "Stretch \(max(1, min(stretchCount, currentNumber))) of \(stretchCount) · \(Clock.text(totalLeft)) left")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                        .monospacedDigit()
                        .accessibilityIdentifier("stretch-timer-progress")
                }
                Spacer()
                if choosing || finished {
                    IconMark(.hand("headphones"), size: 22, colour: Gym.tint)
                        .frame(width: 44, height: 44)
                        .accessibilityLabel("Voice cues on")
                } else {
                    // Save what is done so far and stop (since 1.34, his ask).
                    Button(action: saveNow) {
                        Text("Save")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .frame(height: 34)
                            .background(Gym.done, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Save and stop")
                    .accessibilityIdentifier("stretch-timer-save")
                }
            }
            GeometryReader { g in
                let all = max(1, StretchTimer.total(phases))
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.line)
                    Capsule().fill(tint)
                        .frame(width: choosing ? 0 : finished ? g.size.width : g.size.width * Double(all - totalLeft) / Double(all))
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var controls: some View {
        HStack(spacing: 18) {
            // Change which stretches to do, while stretching (since 1.34, his ask).
            Button { pauseIfRunning(); rechoosing = true } label: {
                ControlMarkView(.list, size: 20, colour: Gym.tint)
            }
                .frame(width: 48, height: 48)
                .background(Gym.fill.opacity(0.12), in: Circle())
                .accessibilityLabel("Choose stretches")
                .accessibilityIdentifier("stretch-timer-choose")
            Button { jump(-1) } label: { ControlMarkView(.skip, size: 22, colour: Gym.tint).scaleEffect(x: -1) }
                .frame(width: 56, height: 56)
                .background(Gym.fill.opacity(0.12), in: Circle())
                .accessibilityLabel("Previous stretch")
                .accessibilityIdentifier("stretch-timer-back")
            Button(action: togglePause) {
                ControlMarkView(endsAt == nil ? .play : .pause, size: 30, colour: Gym.ink)
                    .frame(width: 76, height: 76)
                    .background(Gym.fill, in: Circle())
            }
            .accessibilityLabel(endsAt == nil ? "Go on" : "Pause")
            .accessibilityIdentifier("stretch-timer-pause")
            Button { jump(1) } label: { ControlMarkView(.skip, size: 22, colour: Gym.tint) }
                .frame(width: 56, height: 56)
                .background(Gym.fill.opacity(0.12), in: Circle())
                .accessibilityLabel("Next stretch")
                .accessibilityIdentifier("stretch-timer-skip")
            Color.clear.frame(width: 48, height: 48)
        }
        .buttonStyle(.plain)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Theme.bg.opacity(0.96).ignoresSafeArea(edges: .bottom))
    }

    // MARK: Running

    /// Every stretch is chosen at first; nothing runs until Start (since 1.34).
    private func prepare() {
        if picked.isEmpty { picked = Set(all.map(\.id)) }
        if !choosing && phases.isEmpty && !finished { begin() }
    }

    private func begin() {
        Cues.shared.begin()
        startedAt = Date()
        withAnimation(.easeInOut(duration: 0.25)) { choosing = false }
        rebuild()
    }

    /// The phases of the chosen stretches not yet held, from the first of them.
    private func rebuild() {
        order = chosenList.filter { !held.contains($0.id) }
        phases = StretchTimer.phases(for: order)
        guard !phases.isEmpty else { finish(); return }
        enter(0)
    }

    private func pauseIfRunning() {
        if endsAt != nil { togglePause() }
    }

    /// A hold that ran out counts its stretch as held.
    private func markHeld(_ p: StretchPhase) {
        guard p.kind == .hold, order.indices.contains(p.index) else { return }
        let id = order[p.index].id
        if held.insert(id).inserted { heldOrder.append(id) }
        skipped.remove(id)
    }

    /// Save now: what was held is kept, and a hold more than half done counts too.
    private func saveNow() {
        if let p = phase, p.kind == .hold, left <= Double(p.seconds) / 2 { markHeld(p) }
        finish()
    }

    private func enter(_ i: Int) {
        guard phases.indices.contains(i) else { finish(); return }
        at = i
        lastSaid = -1
        now = Date()
        endsAt = now.addingTimeInterval(Double(phases[i].seconds))
        let p = phases[i]
        if p.kind == .hold { Cues.shared.go(p.spoken) } else { Cues.shared.rest(p.spoken) }
    }

    private func step() {
        guard let p = phase, endsAt != nil, !finished else { return }
        let whole = Int(left.rounded(.up))
        if left <= 0 { markHeld(p); enter(at + 1); return }
        if whole != lastSaid {
            lastSaid = whole
            if whole < p.seconds, let w = StretchTimer.word(p, secondsLeft: whole) {
                if whole <= 3 { Cues.shared.countdown(spoken: w) } else { Cues.shared.speak(w) }
            }
        }
    }

    private func togglePause() {
        if let endsAt {
            leftWhenPaused = max(0, endsAt.timeIntervalSinceNow)
            self.endsAt = nil
            Cues.shared.speak("Paused")
        } else {
            now = Date()
            endsAt = now.addingTimeInterval(leftWhenPaused)
            Cues.shared.speak("Go on")
        }
    }

    /// To the start of the previous or next stretch.
    private func jump(_ by: Int) {
        guard let p = phase else { return }
        let target = p.index + by
        if target < 0 { enter(0); return }
        // Next/Skip leaves a stretch not yet held as skipped (since 2.0).
        if by > 0, !held.contains(p.pickID) { skipped.insert(p.pickID) }
        if let i = phases.firstIndex(where: { $0.index == target }) { enter(i) } else if by > 0 { finish() }
    }

    private func finish() {
        endsAt = nil
        withAnimation(.spring(duration: 0.5)) { finished = true }
        Cues.shared.finished(held.count >= stretchCount ? "Stretch done. Well done." : "Saved. Well done.")
        keep()
    }

    /// Into History, once, when at least one stretch was held — also when stopped early (since 1.34).
    private func keep() {
        if let onFinish {
            guard !kept, !heldOrder.isEmpty else { return }
            kept = true
            onFinish(StretchOutcome(held: heldOrder, skipped: skipped.subtracting(held).count, start: startedAt, end: Date()))
            return
        }
        guard !kept, let workout, let r = SessionRecord.ofStretch(workout, started: startedAt, ended: Date(),
                                                     held: held.count, chosen: stretchCount) else { return }
        kept = true
        library.record(r)
    }

    private func close() {
        keep()
        onClose()
    }
}


/// What a stretch session inside a gym visit hands back (since 2.0).
struct StretchOutcome {
    var held: [String]
    var skipped: Int
    var start: Date
    var end: Date
}
