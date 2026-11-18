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
    private let tick = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()

    private var phase: StretchPhase? { phases.indices.contains(at) ? phases[at] : nil }
    private var left: Double {
        if let endsAt { return max(0, endsAt.timeIntervalSince(now)) }
        return leftWhenPaused
    }
    private var stretchCount: Int { (phases.map(\.index).max() ?? -1) + 1 }
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
            if finished {
                Spacer()
                VStack(spacing: 18) {
                    IconMark(.hand("yoga"), size: 72, colour: SessionGoingLine.green)
                    Text("Stretch done").font(.title.weight(.bold)).foregroundStyle(Theme.ink)
                    Text("\(stretchCount) stretches · \(Clock.text(Int(Date().timeIntervalSince(startedAt))))")
                        .font(.subheadline).foregroundStyle(Theme.muted)
                    Button("Close", action: close)
                        .buttonStyle(BigButtonStyle(fill: workout.fill, ink: workout.inkOnFill))
                        .accessibilityIdentifier("stretch-timer-close-done")
                }
                .padding(24)
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
        .onAppear(perform: start)
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
                    Text(finished ? "Done" : "Stretch \(min(stretchCount, (phase?.index ?? 0) + 1)) of \(stretchCount) · \(Clock.text(totalLeft)) left")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                        .monospacedDigit()
                        .accessibilityIdentifier("stretch-timer-progress")
                }
                Spacer()
                IconMark(.hand("headphones"), size: 22, colour: Gym.tint)
                    .frame(width: 44, height: 44)
                .accessibilityLabel("Voice cues on")
            }
            GeometryReader { g in
                let all = max(1, StretchTimer.total(phases))
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.line)
                    Capsule().fill(workout.fill)
                        .frame(width: finished ? g.size.width : g.size.width * Double(all - totalLeft) / Double(all))
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var controls: some View {
        HStack(spacing: 24) {
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
        }
        .buttonStyle(.plain)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Theme.bg.opacity(0.96).ignoresSafeArea(edges: .bottom))
    }

    // MARK: Running

    private func start() {
        Cues.shared.begin()
        phases = StretchTimer.phases(for: workout.exercises)
        startedAt = Date()
        guard !phases.isEmpty else { finished = true; return }
        enter(0)
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
        if left <= 0 { enter(at + 1); return }
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
        Cues.shared.finished("Stretch done. Well done.")
        keep()
    }

    /// Into History, once, when at least one stretch was held.
    private func keep() {
        let held = finished ? stretchCount : (phase?.index ?? 0)
        guard !kept, held > 0,
              let r = SessionRecord.of(workout, started: startedAt, ended: Date(), ticked: held) else { return }
        kept = true
        library.record(r)
    }

    private func close() {
        keep()
        onClose()
    }
}
