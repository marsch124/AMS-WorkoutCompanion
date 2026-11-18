import AMSIcons
import Combine
import SwiftUI
import WorkoutCore

/// The guided stretch timer (since 1.32, his ask): it walks through a stretch list and speaks the
/// cues — what comes next, hold, switch sides, halfway, ten seconds, three-two-one — into his
/// AirPods (or the phone's speaker), alongside his music. The screen stays on while it runs.
struct StretchTimerScreen: View {
    @Environment(Library.self) private var library
    let workout: Workout
    let onClose: () -> Void

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
    @State private var picked: Set<UUID> = []
    @State private var held: Set<UUID> = []
    /// The stretches the running phases belong to, in order (a phase's index points here).
    @State private var order: [Exercise] = []
    @State private var choosing = true
    @State private var rechoosing = false
    private let tick = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()

    private var phase: StretchPhase? { phases.indices.contains(at) ? phases[at] : nil }
    private var left: Double {
        if let endsAt { return max(0, endsAt.timeIntervalSince(now)) }
        return leftWhenPaused
    }
    private var all: [Exercise] { StretchTimer.choosable(workout.exercises) }
    private var chosenList: [Exercise] { all.filter { picked.contains($0.id) } }
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
                StretchChooser(all: all, picked: $picked, tint: workout.fill, ink: workout.inkOnFill,
                               title: "Start", action: begin)
            } else if finished {
                Spacer()
                VStack(spacing: 18) {
                    IconMark(.hand("yoga"), size: 72, colour: SessionGoingLine.green)
                    Text("Stretch done").font(.title.weight(.bold)).foregroundStyle(Theme.ink)
                    Text("\(held.count) of \(stretchCount) stretch\(stretchCount == 1 ? "" : "es") · \(Clock.text(Int(Date().timeIntervalSince(startedAt))))")
                        .font(.subheadline).foregroundStyle(Theme.muted)
                    Button("Close", action: close)
                        .buttonStyle(BigButtonStyle(fill: workout.fill, ink: workout.inkOnFill))
                        .accessibilityIdentifier("stretch-timer-close-done")
                }
                .padding(24)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("stretch-timer-done")
                Spacer()
            } else if let phase {
                ScrollView {
                    VStack(spacing: 14) {
                        Text(label(phase))
                            .font(.caption.weight(.bold))
                            .tracking(1)
                            .foregroundStyle(colour(phase.kind))
                            .padding(.horizontal, 12)
                            .frame(height: 26)
                            .background(colour(phase.kind).opacity(0.14), in: Capsule())
                            .accessibilityIdentifier("stretch-timer-phase")
                        ZStack {
                            Ring(fractionLeft: left / Double(max(1, phase.seconds)), colour: colour(phase.kind), width: 14)
                                .animation(.linear(duration: 0.2), value: left)
                            Text("\(Int(left.rounded(.up)))")
                                .font(.system(size: 64, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(Theme.ink)
                                .contentTransition(.numericText(countsDown: true))
                                .accessibilityIdentifier("stretch-timer-seconds")
                        }
                        .frame(width: 200, height: 200)
                        Text(phase.name)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.center)
                            .accessibilityIdentifier("stretch-timer-name")
                        if let move = StretchRoutine.move(named: phase.name) {
                            VStack(alignment: .leading, spacing: 5) {
                                ForEach(Array(move.steps.enumerated()), id: \.offset) { n, step in
                                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                                        Text("\(n + 1).").font(.subheadline.weight(.semibold)).foregroundStyle(Gym.tint)
                                            .frame(width: 18, alignment: .trailing)
                                        Text(step).font(.subheadline).foregroundStyle(Theme.ink)
                                    }
                                }
                                Text(move.feel).font(.footnote).foregroundStyle(SessionGoingLine.green).padding(.top, 2)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        } else if let e = workout.exercises.first(where: { $0.name == phase.name }), !e.note.isEmpty {
                            Text(e.note).font(.subheadline).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
                        }
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
                StretchChooser(all: all, picked: $picked, tint: workout.fill, ink: workout.inkOnFill,
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

    private var header: some View {
        VStack(spacing: 10) {
            HStack {
                CloseButton(action: close)
                    .accessibilityIdentifier("stretch-timer-close")
                Spacer()
                VStack(spacing: 2) {
                    Text(workout.name.isEmpty ? "Stretch" : workout.name)
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
                    Capsule().fill(workout.fill)
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
        held.insert(order[p.index].id)
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
        guard !kept, let r = SessionRecord.ofStretch(workout, started: startedAt, ended: Date(),
                                                     held: held.count, chosen: stretchCount) else { return }
        kept = true
        library.record(r)
    }

    private func close() {
        keep()
        onClose()
    }
}

/// Tick the stretches to do this time (since 1.34, his ask). All are ticked at first;
/// stretches already held show a check and stay as they are.
struct StretchChooser: View {
    let all: [Exercise]
    @Binding var picked: Set<UUID>
    let tint: Color
    let ink: Color
    let title: String
    var held: Set<UUID> = []
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
