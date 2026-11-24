import SwiftUI
import WorkoutCore

/// The warm-up running (since 2.0): the session clock top left, a big countdown, −1 / +1 min, Pause and
/// "Done — to the machines". On a time machine he types speed, level and heart rate; with moves a big
/// animated figure shows each move and the voice says what is next.
struct WarmUpRunScreen: View {
    @Environment(Library.self) private var library
    let run: WarmRun
    let day: Date
    let gymID: UUID?
    let finished: () -> Void

    @State private var now = Date()
    @State private var segments: [WarmRun.Segment] = []
    @State private var index = 0
    @State private var endsAt = Date()
    @State private var total: TimeInterval = 60
    @State private var pausedAt: Date?
    @State private var over = false
    @State private var reached: [String] = []
    @State private var speed = ""
    @State private var level = ""
    @State private var heart = ""
    @FocusState private var typing: Bool

    private let tick = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()
    private var isMoves: Bool { run.kind == .moves }
    private var machine: Machine? { run.machineID.flatMap { library.gym.machine($0) } }
    private var remaining: TimeInterval { max(0, endsAt.timeIntervalSince(pausedAt ?? now)) }
    private var step: TimeInterval { isMoves ? 10 : 60 }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                SessionClockPill(day: day, gymID: gymID)
                Spacer()
            }
            Text(title)
                .font(.largeTitle.weight(.bold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1).minimumScaleFactor(0.7)
                .accessibilityIdentifier("warmup-title")
            ScrollView {
                VStack(spacing: 14) {
                    if isMoves, segments.indices.contains(index) {
                        let seg = segments[index]
                        FigureView(id: seg.id, size: 200, mirrored: seg.mirrored, animated: !(pausedAt != nil), tint: Theme.accent)
                            .frame(height: 200)
                            .accessibilityIdentifier("warmup-figure")
                        Text(seg.mirrored ? "\(seg.name) — other side" : seg.name)
                            .font(.title3.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .accessibilityIdentifier("warmup-name")
                        Text("\(index + 1) of \(segments.count) · \(seg.seconds) s")
                            .font(.caption).foregroundStyle(Theme.muted)
                    }
                    ring
                    HStack(spacing: 10) {
                        adjust(isMoves ? "−10 s" : "−1 min", id: "warmup-minus") { move(-step) }
                        adjust(pausedAt == nil ? "Pause" : "Resume", id: "warmup-pause") { togglePause() }
                        adjust(isMoves ? "+10 s" : "+1 min", id: "warmup-plus") { move(step) }
                    }
                    if isMoves {
                        Button { skip() } label: {
                            Text("Skip").font(.subheadline.weight(.semibold)).foregroundStyle(Gym.tint)
                                .frame(maxWidth: .infinity, minHeight: 40)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("warmup-skip")
                    } else if run.kind == .cardio {
                        fields
                    }
                }
                .padding(.top, 4)
            }
            .scrollDismissesKeyboard(.interactively)
            Button { finish() } label: {
                Text("Done — to the machines")
            }
            .buttonStyle(BigButtonStyle(fill: Theme.accent, ink: .white, height: 52))
            .accessibilityIdentifier("warmup-done")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .readableWidth(560)
        .background(Theme.bg.ignoresSafeArea())
        .onAppear(perform: setup)
        .onReceive(tick) { date in
            now = date
            if pausedAt == nil, !over, date >= endsAt { segmentOver() }
        }
        .onDisappear { Cues.shared.end() }
    }

    private var title: String { "Warm-up" }

    // MARK: Pieces

    private var ring: some View {
        let progress = total > 0 ? remaining / total : 0
        return ZStack {
            Circle().stroke(Theme.accent.opacity(0.15), lineWidth: isMoves ? 10 : 16)
            Circle().trim(from: 0, to: progress)
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: isMoves ? 10 : 16, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Text(Self.mmss(remaining))
                    .font(.system(size: isMoves ? 44 : 60, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(Theme.ink)
                    .accessibilityIdentifier("warmup-clock")
                Text(isMoves ? "left on this move" : "left of \(Int((total / 60).rounded())) min")
                    .font(.caption).foregroundStyle(Theme.muted)
            }
        }
        .frame(width: isMoves ? 160 : 230, height: isMoves ? 160 : 230)
        .padding(8)
    }

    private func adjust(_ title: String, id: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Gym.tint)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(Gym.soft, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }

    private var fields: some View {
        VStack(spacing: 0) {
            fieldRow("Speed", unit: "km/h", text: $speed, pad: .decimalPad, id: "warmup-speed")
            if machine?.hasLevel != false {
                Divider()
                fieldRow("Level", unit: "", text: $level, pad: .decimalPad, id: "warmup-level")
            }
            Divider()
            fieldRow("Heart rate", unit: "bpm", text: $heart, pad: .numberPad, id: "warmup-hr")
        }
        .padding(.horizontal, 12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func fieldRow(_ name: String, unit: String, text: Binding<String>, pad: UIKeyboardType, id: String) -> some View {
        HStack {
            Text(name)
            Spacer()
            TextField("—", text: text)
                .keyboardType(pad)
                .multilineTextAlignment(.trailing)
                .font(.body.weight(.semibold).monospacedDigit())
                .focused($typing)
                .frame(maxWidth: 90)
                .accessibilityIdentifier(id)
            if !unit.isEmpty { Text(unit).foregroundStyle(Theme.muted) }
        }
        .frame(minHeight: 44)
    }

    // MARK: Running

    static func mmss(_ s: TimeInterval) -> String {
        let n = Int(s.rounded(.up))
        return String(format: "%02d:%02d", n / 60, n % 60)
    }

    private func setup() {
        Cues.shared.begin()
        if isMoves {
            segments = WarmRun.segments(run.moves)
            guard let first = segments.first else { finish(); return }
            begin(segment: 0, first)
        } else {
            total = TimeInterval(run.minutes * 60)
            endsAt = Date().addingTimeInterval(total)
        }
        now = Date()
    }

    private func begin(segment i: Int, _ seg: WarmRun.Segment) {
        index = i
        total = TimeInterval(seg.seconds)
        endsAt = Date().addingTimeInterval(total)
        if !reached.contains(seg.id) { reached.append(seg.id) }
        Cues.shared.speak(seg.mirrored ? "Other side" : "Next: \(seg.name)")
    }

    private func segmentOver() {
        if isMoves, index + 1 < segments.count { begin(segment: index + 1, segments[index + 1]) } else { finish() }
    }

    private func skip() {
        guard isMoves else { return }
        let here = segments[index].id
        if let next = segments.indices.first(where: { $0 > index && segments[$0].id != here }) {
            begin(segment: next, segments[next])
        } else { finish() }
    }

    /// −1 / +1 min (moves: 10 s) changes the time that is left, live.
    private func move(_ by: TimeInterval) {
        let base = pausedAt ?? Date()
        let left = max(0, endsAt.timeIntervalSince(base) + by)
        endsAt = base.addingTimeInterval(left)
        total = max(total + by, left, 1)
        now = Date()
    }

    private func togglePause() {
        if let p = pausedAt {
            endsAt = endsAt.addingTimeInterval(Date().timeIntervalSince(p))
            pausedAt = nil
        } else { pausedAt = Date() }
    }

    /// Time up, Done, or the last move skipped: saves the warm-up and goes back to the gym page.
    private func finish() {
        guard !over else { return }
        over = true
        typing = false
        let end = Date()
        let hr = Int(heart.trimmingCharacters(in: .whitespaces))
        let cardio = run.kind == .cardio
        library.changeGym {
            $0.endWarmup(visitID: run.visitID, at: end,
                         speed: cardio ? WarmNumber.parse(speed) : nil,
                         level: cardio ? WarmNumber.parse(level) : nil,
                         heartRate: cardio ? hr : nil,
                         names: isMoves ? reached : nil)
        }
        Cues.shared.finished("Warm-up done")
        // Only a cardio warm-up asks Apple Health; a number he typed always wins.
        if cardio, hr == nil, let start = library.gym.visits.first(where: { $0.id == run.visitID })?.warmup?.start {
            let id = run.visitID
            Task { @MainActor in
                if let avg = await HealthHeartRate.average(from: start, to: end) {
                    library.changeGym { log in
                        guard let w = log.visits.first(where: { $0.id == id })?.warmup, w.heartRate == nil else { return }
                        log.editWarmup(visitID: id, minutes: nil, speed: w.speed, level: w.level, heartRate: avg)
                    }
                }
            }
        }
        finished()
    }
}

struct WarmEdit { let minutes: Int; let speed: Double?; let level: Double?; let heartRate: Int? }

/// The warm-up chip's sheet: change the minutes, speed, level and heart rate afterwards (since 2.0).
struct WarmUpChipSheet: View {
    let visitID: UUID
    let part: VisitPart
    let hasLevel: Bool
    let done: (WarmEdit?) -> Void

    @State private var minutes: Int
    @State private var speed: String
    @State private var level: String
    @State private var heart: String
    @State private var reading = false
    @State private var readNote: String?

    init(visitID: UUID, part: VisitPart, hasLevel: Bool,
         done: @escaping (WarmEdit?) -> Void) {
        self.visitID = visitID; self.part = part; self.hasLevel = hasLevel; self.done = done
        _minutes = State(initialValue: max(1, part.minutes))
        _speed = State(initialValue: WarmNumber.text(part.speed))
        _level = State(initialValue: WarmNumber.text(part.level))
        _heart = State(initialValue: part.heartRate.map(String.init) ?? "")
    }

    var body: some View {
        Form {
            Section {
                Stepper(value: $minutes, in: 1...180) {
                    HStack { Text("Minutes"); Spacer(); Text("\(minutes)").monospacedDigit().accessibilityIdentifier("warmup-chip-minutes") }
                }
                .accessibilityIdentifier("warmup-chip-stepper")
            }
            if part.kind == .cardio {
                Section {
                    row("Speed", "km/h", $speed, .decimalPad, "warmup-chip-speed")
                    if hasLevel { row("Level", "", $level, .decimalPad, "warmup-chip-level") }
                    row("Heart rate", "bpm", $heart, .numberPad, "warmup-chip-hr")
                    if heart.trimmingCharacters(in: .whitespaces).isEmpty {
                        Text(readNote ?? HealthHeartRate.waiting)
                            .font(.footnote).foregroundStyle(Theme.muted)
                            .accessibilityIdentifier("warmup-hr-note")
                    }
                    Button {
                        readAgain()
                    } label: {
                        Text(reading ? "Reading …" : "Read again").foregroundStyle(Gym.tint)
                    }
                    .accessibilityIdentifier("warmup-hr-read")
                }
            }
        }
        .navigationTitle("Warm-up")
        .navigationBarTitleDisplayMode(.inline)
        .bottomActions(cancel: { done(nil) }, save: {
            done(WarmEdit(minutes: minutes, speed: WarmNumber.parse(speed), level: WarmNumber.parse(level),
                          heartRate: Int(heart.trimmingCharacters(in: .whitespaces))))
        }, saveTitle: "Save", tint: Gym.fill, cancelID: "warmup-chip-cancel", saveID: "warmup-chip-save")
    }

    private func row(_ name: String, _ unit: String, _ text: Binding<String>, _ pad: UIKeyboardType, _ id: String) -> some View {
        HStack {
            Text(name)
            Spacer()
            TextField("—", text: text).keyboardType(pad).multilineTextAlignment(.trailing)
                .frame(maxWidth: 90).accessibilityIdentifier(id)
            if !unit.isEmpty { Text(unit).foregroundStyle(Theme.muted) }
        }
    }

    private func readAgain() {
        guard !reading, let end = part.end else { return }
        reading = true
        Task { @MainActor in
            let avg = await HealthHeartRate.average(from: part.start, to: end)
            reading = false
            if let avg { heart = String(avg); readNote = nil } else { readNote = HealthHeartRate.waiting }
        }
    }
}
