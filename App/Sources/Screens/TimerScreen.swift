import AMSIcons
import SwiftUI
import WorkoutCore

/// Runs a Sets & reps or an Interval workout: big numbers, a ring, spoken cues.
struct TimerScreen: View {
    @Environment(Library.self) private var library
    let workout: Workout
    let onClose: () -> Void

    @State private var session: Session
    @State private var now = Date()
    @State private var lastBeep = -1
    @State private var askClose = false
    @State private var startedAt = Date()
    @State private var kept = false
    private let clock = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()

    init(workout: Workout, onClose: @escaping () -> Void) {
        self.workout = workout
        self.onClose = onClose
        _session = State(initialValue: Session(phases: Plan.phases(for: workout)))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Spacer(minLength: 12)
            centre
                .frame(maxWidth: .infinity)
                .animation(.spring(duration: 0.35), value: session.index)
            Spacer(minLength: 12)
            controls
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .background(Theme.bg.ignoresSafeArea())
        .onAppear {
            Cues.shared.begin()
            let t = Date()
            now = t
            startedAt = t
            session.start(at: t)
            announce()
        }
        .onDisappear { Cues.shared.end() }
        .onReceive(clock) { t in
            now = t
            if session.tick(at: t) {
                lastBeep = -1
                announce()
            }
            beepIfDue()
        }
        .confirmationDialog("End this workout?", isPresented: $askClose, titleVisibility: .visible) {
            Button("End workout", role: .destructive) {
                keep()
                onClose()
            }
                .accessibilityIdentifier("run-end-confirm")
        }
    }

    // MARK: Parts

    private var header: some View {
        VStack(spacing: 14) {
            HStack {
                CloseButton {
                    if session.isFinished { onClose() } else { askClose = true }
                }
                Spacer()
                VStack(spacing: 2) {
                    Text(workout.name)
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(Theme.ink)
                    Text(workout.summary)
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.line)
                    Capsule().fill(workout.fill).frame(width: g.size.width * session.progress)
                }
            }
            .frame(height: 6)
            .animation(.easeInOut, value: session.progress)
            .accessibilityHidden(true)
        }
        .padding(.top, 8)
    }

    @ViewBuilder private var centre: some View {
        switch session.current {
        case .set(let n, let of, let reps)?:
            SetView(number: n, of: of, reps: reps, workout: workout)
        case let phase?:
            countdown(phase)
        case nil:
            if session.isFinished { FinishedBadge(workout: workout) }
        }
    }

    private func countdown(_ phase: Phase) -> some View {
        let left = session.remaining(at: now) ?? 0
        let (label, sub) = words(for: phase)
        let colour = phase.isRest ? Theme.muted : workout.fill
        return ZStack {
            Ring(fractionLeft: session.fractionLeft(at: now), colour: colour, width: 24)
            VStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .tracking(3)
                    .foregroundStyle(phase.isRest ? Theme.muted : Theme.ink)
                    .accessibilityIdentifier("run-phase")
                Text(Clock.text(Int(left.rounded(.up))))
                    .font(.system(size: 88, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .contentTransition(.numericText(countsDown: true))
                Text(sub)
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(Theme.muted)
                if session.isPaused {
                    Text("PAUSED")
                        .font(.caption.weight(.heavy))
                        .tracking(2)
                        .foregroundStyle(workout.inkOnFill)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(workout.fill, in: Capsule())
                }
            }
            .padding(36)
        }
        .frame(width: 310, height: 310)
    }

    @ViewBuilder private var controls: some View {
        switch session.current {
        case .set?:
            Button { next() } label: {
                MarkLabel(title: "Done", mark: .check, size: 26, colour: workout.inkOnFill)
            }
            .buttonStyle(BigButtonStyle(fill: workout.fill, ink: workout.inkOnFill, height: 96))
            .accessibilityIdentifier("run-done")
        case .rest?:
            HStack(spacing: 12) {
                Button("+15 s") { session.addTime(15) }
                    .buttonStyle(SoftButtonStyle())
                    .accessibilityIdentifier("run-add")
                Button { next() } label: { MarkLabel(title: "Skip rest", mark: .skip, colour: workout.inkOnFill) }
                    .buttonStyle(BigButtonStyle(fill: workout.fill, ink: workout.inkOnFill))
                    .accessibilityIdentifier("run-skip")
            }
        case let phase?:
            HStack(spacing: 12) {
                Button {
                    if session.isPaused { session.resume(at: Date()) } else { session.pause(at: Date()) }
                } label: {
                    MarkLabel(title: session.isPaused ? "Resume" : "Pause",
                              mark: session.isPaused ? .play : .pause, colour: Theme.ink)
                }
                .buttonStyle(SoftButtonStyle())
                .accessibilityIdentifier("run-pause")
                Button { next() } label: {
                    MarkLabel(title: phase.isRest ? "Skip rest" : "Skip", mark: .skip, colour: workout.inkOnFill)
                }
                .buttonStyle(BigButtonStyle(fill: workout.fill, ink: workout.inkOnFill))
                .accessibilityIdentifier("run-skip")
            }
        case nil:
            Button("Close", action: onClose)
                .buttonStyle(BigButtonStyle(fill: workout.fill, ink: workout.inkOnFill))
                .accessibilityIdentifier("run-finish-close")
        }
    }

    // MARK: Behaviour

    private func next() {
        let t = Date()
        now = t
        session.next(at: t)
        lastBeep = -1
        announce()
    }

    /// Into History, once: how far the workout got. Nothing when ended before the first set or round.
    private func keep() {
        guard !kept else { return }
        kept = true
        if let r = SessionRecord.of(workout, started: startedAt, ended: Date(),
                                    phasesDone: Array(session.phases.prefix(session.index)), finished: session.isFinished) {
            library.record(r)
        }
    }

    private func words(for phase: Phase) -> (String, String) {
        switch phase {
        case .getReady: return ("GET READY", "Round 1 of \(workout.rounds)")
        case .rest(_, let next, let of): return ("REST", "Next: set \(next) of \(of)")
        case .work(_, let r, let of): return ("WORK", "Round \(r) of \(of)")
        case .off(_, let next, let of): return ("REST", "Next: round \(next) of \(of)")
        case .set: return ("", "")
        }
    }

    private func announce() {
        let cues = Cues.shared
        switch session.current {
        case nil:
            if session.isFinished {
                keep()
                cues.finished("Well done. Workout complete.")
            }
        case .getReady?:
            cues.rest("Get ready")
        case .set(let n, let of, let reps)?:
            cues.go(n == of ? "Last set. \(reps) reps." : "Set \(n) of \(of). \(reps) reps.")
        case .rest?, .off?:
            cues.rest("Rest")
        case .work(_, let r, let of)?:
            cues.go(r == of ? "Last round. Go!" : "Round \(r). Go!")
        }
    }

    /// A tick and a tap at 3, 2, 1.
    private func beepIfDue() {
        guard !session.isPaused, let left = session.remaining(at: now) else { return }
        let s = Int(left.rounded(.up))
        if (1...3).contains(s), s != lastBeep {
            lastBeep = s
            Cues.shared.countdown()
        }
    }
}

/// The set screen: which set, how many reps, and a big Done.
private struct SetView: View {
    let number: Int
    let of: Int
    let reps: Int
    let workout: Workout

    var body: some View {
        VStack(spacing: 18) {
            Text("SET")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .tracking(3)
                .foregroundStyle(Theme.muted)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(number)")
                    .font(.system(size: 150, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
                Text("/ \(of)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.muted)
            }
            .monospacedDigit()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Set \(number) of \(of)")
            .accessibilityIdentifier("run-set")

            Text("\(reps) reps")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(workout.inkOnFill)
                .padding(.horizontal, 28)
                .padding(.vertical, 12)
                .background(workout.fill, in: Capsule())
                .accessibilityIdentifier("run-reps")

            HStack(spacing: 8) {
                ForEach(1...of, id: \.self) { i in
                    Circle()
                        .fill(i < number ? workout.fill : (i == number ? Theme.ink : Theme.line))
                        .frame(width: 10, height: 10)
                }
            }
            .padding(.top, 6)
            .accessibilityHidden(true)
        }
    }
}
