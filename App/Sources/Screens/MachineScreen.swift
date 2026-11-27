import AMSIcons
import Charts
import PhotosUI
import SwiftUI
import UIKit
import WorkoutCore

/// One machine: its photo and setting, last time, today's sets, the next set and the rest.
struct MachineScreen: View {
    @Environment(Library.self) private var library
    let machineID: UUID
    let day: Date
    let gymID: UUID?
    /// Done with this machine: the next planned machine, or nil for back to the gym screen.
    let moveOn: (UUID?) -> Void

    @State private var kg: Double = GymLog.starter.kg
    @State private var reps: Int = GymLog.starter.reps
    @State private var minutes: Double = 20
    @State private var level: Double = 5
    @State private var incline: Double = 0
    @State private var nextTimeOpen = false
    @State private var zoomInstructions = false
    @State private var restEnd: Date?
    @State private var restLength: Double = Double(GymLog.restSeconds)
    @State private var now = Date()
    @State private var editing = false
    @State private var changingSet: Int?
    @State private var zoom = false
    /// The how-to full screen, and the rest marks already said in this rest (since 2.0).
    @State private var showHowTo = false
    @State private var restSaid: Set<Int> = []
    @State private var newBest = false
    /// The next set is a warm-up (since 1.11); off again after that set.
    @State private var warmup = false
    /// A hold against the clock — a plank (since 1.23): its seconds, and the countdown while it runs.
    @State private var holdSeconds = 30
    @State private var holdEnd: Date?
    @FocusState private var typing: NumberBox?

    private let clock = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

    private var machine: Machine? { library.gym.machine(machineID) }
    private var visit: GymVisit { library.gym.openVisit(on: day, gym: gymID) ?? GymVisit(gymID: gymID, date: day) }
    private var entryToday: MachineEntry? { visit.entries.last { $0.machineID == machineID } }
    private var isTime: Bool { machine?.logs == .time }
    /// Push-ups, sit-ups: reps only, no weight (since 1.6).
    private var isReps: Bool { machine?.logs == .reps }
    private var isHold: Bool { machine?.isHold == true }
    private func said(_ s: GymSet) -> String { library.gym.text(s, machine: machineID) }
    private var step: Double { machine?.weightStep ?? GymLog.step }
    private var upNext: Machine? {
        library.gym.upNext(on: day, gym: gymID, excluding: machineID).flatMap { library.gym.machine($0) }
    }
    /// Last time's number of sets: once reached, the rest offers the next machine.
    private var target: Int? { library.gym.last(machineID, excluding: visit.id)?.entry.sets.count }
    private var today: [GymSet] { visit.entries.last { $0.machineID == machineID }?.sets ?? [] }
    private var next: NextSet { library.gym.next(machineID, in: visit) }
    /// The superset partner, done in turn with this machine (since 1.11).
    private var partner: Machine? { library.gym.partner(of: machineID) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if let machine {
                    Button { zoom = machine.photo != nil } label: {
                        MachinePhoto(name: machine.photo, height: machine.photo == nil ? 90 : 180, icon: machine.icon)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("gym-photo")

                    HStack(alignment: .top) {
                        if !machine.setting.isEmpty {
                            Text(machine.setting)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Gym.tint)
                                .accessibilityIdentifier("gym-setting")
                        }
                        Spacer()
                        if machine.instructions != nil {
                            Button { zoomInstructions = true } label: {
                                HStack(spacing: 6) {
                                    MachinePhoto(name: machine.instructions, height: 34).frame(width: 34)
                                    Text("Instructions").font(.subheadline.weight(.semibold)).foregroundStyle(Gym.tint)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("gym-instructions")
                        }
                    }
                    if let partner {
                        HStack(spacing: 8) {
                            AppMarkView(.pair, size: 20, colour: Superset.tint)
                            Text("Superset with \(partner.name)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Superset.tint)
                            Spacer()
                            Text("no rest between")
                                .font(.caption)
                                .foregroundStyle(Theme.muted)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Superset.swatch.fillColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("gym-superset")
                    }
                }
                compareBox
                lastNotes
                if today.isEmpty, let reason = next.reason {
                    HStack(spacing: 8) {
                        IconMark(.hand("trophy"), size: 20, colour: Gym.tint)
                        Text(reason).font(.subheadline)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Gym.fill.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("gym-suggestion")
                }

                if !today.isEmpty, !isTime { effortRow }

                if let holdEnd {
                    hold(until: holdEnd)
                } else if let restEnd {
                    rest(until: restEnd)
                } else if isTime {
                    timeEntry
                } else {
                    entry
                }

                if !today.isEmpty {
                    nextTimeRow
                    painRow
                }

                history
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .readableWidth(720)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle(machine?.name ?? "Machine")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            // With no set yet it says "Back to gym" and logs nothing (since 1.19, his ask; his word since 1.20); Escape on the Mac.
            // Since 1.22 the ONE way on (his ask): after a set "Exercise done" goes to the next planned machine
            // ("Next: Hantel" under it), else back to the gym. The green Next beside Set done is gone.
            let leaving = today.isEmpty ? "Back to gym" : "Exercise done"
            let next = today.isEmpty ? nil : upNext
            Button { moveOn(next?.id) } label: {
                VStack(spacing: 0) {
                    Text(leaving)
                    if let next {
                        Text("Next: \(next.name)").font(.caption.weight(.semibold)).lineLimit(1)
                    }
                }
            }
            // Pale blue with blue words since 1.33 (his ask: set it apart from the full-blue Set done).
            .buttonStyle(BigButtonStyle(fill: Gym.soft, ink: Gym.tint, height: 50))
            // A blue frame like a done machine tile (since 1.34, his ask).
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Gym.fill, lineWidth: 2))
            .keyboardShortcut(today.isEmpty ? .cancelAction : nil)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(Theme.bg.ignoresSafeArea(edges: .bottom))
            // The page fades out above the button (since 2.6); before, words were cut through at its edge.
            .overlay(alignment: .top) {
                LinearGradient(colors: [Theme.bg.opacity(0), Theme.bg], startPoint: .top, endPoint: .bottom)
                    .frame(height: 20)
                    .offset(y: -20)
                    .allowsHitTesting(false)
            }
            .accessibilityLabel(leaving)
            .accessibilityValue(next.map { "Next: \($0.name)" } ?? "")
            .accessibilityIdentifier("machine-done-pill")
        }
        .toolbar {
            // How long the session has been going, small at the top left (since 1.31, his ask).
            ToolbarItem(placement: .topBarLeading) { SessionClockPill(day: day, gymID: gymID) }
            // A small picture beside the machine name opens how to use it (since 2.0).
            ToolbarItem(placement: .principal) {
                if let machine {
                    HStack(spacing: 8) {
                        Button { showHowTo = true } label: { HowToThumb(machine: machine, size: 34) }
                            .buttonStyle(.plain)
                            .accessibilityLabel("How to use \(machine.name)")
                            .accessibilityIdentifier("machine-howto-thumb")
                        Text(machine.name)
                            .font(.headline)
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { editing = true } label: { ControlMarkView(.edit, size: 22, colour: Gym.tint) }
                    .accessibilityLabel("Edit machine")
                    .accessibilityIdentifier("gym-edit-machine")
            }
            ToolbarItemGroup(placement: .keyboard) {
                // Weight → Next → Reps (since 3.3), then Done closes the keyboard.
                if typing == .restKg || typing == .kg {
                    Button("Next") { typing = typing == .restKg ? .restReps : .reps }
                        .accessibilityIdentifier("keyboard-next")
                }
                Spacer()
                Button("Done") { typing = nil }
                    .accessibilityIdentifier("keyboard-done")
            }
        }
        .onAppear(perform: prefill)
        // No swipe back on the machine page: a finger sliding while tapping a number left the page (since 1.33).
        .noSwipeBack()
        // A locked iPhone still buzzes when the rest is over (since 1.8).
        .onChange(of: restEnd) { _, end in
            RestAlarm.set(end, "Set \(today.count + 1) on \(machine?.name ?? "the machine")")
            // …and the countdown on the lock screen and in the Dynamic Island (since 1.15).
            RestLive.show(end.map {
                library.gym.restCard(machine: machineID, in: visit,
                                     start: $0.addingTimeInterval(-restLength), end: $0)
            })
        }
        .onDisappear {
            RestAlarm.set(nil, "")
            RestLive.show(nil)
        }
        .onReceive(clock) { t in
            now = t
            if let end = holdEnd {
                // The hold counts down, ticks at 3, 2, 1 and saves itself at zero (since 1.23).
                let left = end.timeIntervalSince(t)
                if left <= 0 {
                    holdEnd = nil
                    timeDone()
                } else if left < 3.2, Int(left.rounded(.up)) != Int((left + 0.25).rounded(.up)) {
                    Cues.shared.countdown()
                }
            }
            if let end = restEnd {
                let left = end.timeIntervalSince(t)
                if left <= 0 {
                    restEnd = nil
                    Cues.shared.go("Set \(today.count + 1)")
                } else if let mark = RestCuePlan.due(secondsLeft: left, marks: RestCuePlan.marks(restSeconds: Int(restLength)),
                                                     said: restSaid) {
                    // Thirty, Twenty, Ten seconds, Three, Two, One: each once per rest (since 2.0).
                    restSaid.insert(mark)
                    Cues.shared.restMark(mark)
                }
            }
        }
        .fullScreenCover(isPresented: $showHowTo) {
            if let machine {
                InstructionViewScreen(machine: machine) { showHowTo = false }
                    .environment(library)
            }
        }
        .sheet(isPresented: $editing) {
            if let machine {
                NavigationStack {
                    MachineForm(machine: machine, isNew: false) { _ in editing = false }
                }
                .environment(library)
            }
        }
        .sheet(item: Binding(get: { changingSet.map { SetIndex(index: $0) } }, set: { changingSet = $0?.index })) { s in
            NavigationStack {
                SetEditor(number: s.index + 1, repsOnly: isReps, set: today[s.index]) { result in
                    if let result {
                        library.changeGym { $0.change(visit: visit.id, machine: machineID, set: s.index, to: result) }
                    }
                    changingSet = nil
                } remove: {
                    library.changeGym(undo: "Set \(s.index + 1) removed") { $0.change(visit: visit.id, machine: machineID, set: s.index, to: nil) }
                    changingSet = nil
                }
            }
            .presentationDetents([.medium])
        }
        .fullScreenCover(isPresented: $zoom) {
            ZoomedMachine(name: machine?.photo) { zoom = false }
        }
        .fullScreenCover(isPresented: $zoomInstructions) {
            ZoomedMachine(name: machine?.instructions) { zoomInstructions = false }
        }
        .sheet(isPresented: $nextTimeOpen) {
            NavigationStack {
                NextTimeForm(isTime: isTime, repsOnly: isReps, step: step,
                             set: entryToday?.nextTime ?? today.last ?? next.set,
                             note: entryToday?.note ?? "") { result in
                    nextTimeOpen = false
                    if let result {
                        library.changeGym { $0.nextTime(visit: visit.id, machine: machineID, set: result.set, note: result.note) }
                    }
                }
            }
            .presentationDetents([.large])   // full height: the note field stays clear of the bottom Save bar (1.9)
        }
    }

    // MARK: Parts

    /// Last time beside today (since 3.3, his pick 3 of a numbered picture): one row per set — last time's
    /// set in grey on the left, today's in green on the right, each with its own kg; a warm-up in the
    /// warm-up yellow. Before: a grey line "Last time, 24 Nov: BW × 20, 2,5 × 20, 5 × 14, 7,5 × 7 kg"
    /// (the one "kg" at the end looked as if it belonged to the last set only) and today's sets in a
    /// separate blue-grey box.
    @ViewBuilder private var compareBox: some View {
        let last = library.gym.last(machineID, excluding: visit.id)
        let before = last?.entry.sets ?? []
        let rows = max(before.count, today.count)
        if rows == 0 {
            Text("First time on this machine.")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .accessibilityIdentifier("gym-last")
        } else {
            let hasLast = !before.isEmpty
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Color.clear.frame(width: Self.labelWidth, height: 1)
                    if hasLast, let last {
                        Text("Last time · \(last.visit.date.formatted(.dateTime.day().month(.abbreviated)))")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Theme.muted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .padding(.horizontal, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityIdentifier("gym-last")
                    }
                    Text(hasLast ? "Today" : "Today · first time on this machine")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Gym.doneTint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.horizontal, 8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .background(Gym.doneWash)
                        .accessibilityIdentifier(hasLast ? "gym-today-head" : "gym-last")
                }
                .padding(.top, 7)
                .padding(.bottom, 3)
                .background(alignment: .trailing) { headWash(hasLast: hasLast) }
                .fixedSize(horizontal: false, vertical: true)
                ForEach(0..<rows, id: \.self) { i in
                    Divider().padding(.leading, 10)
                    compareRow(i, before: i < before.count ? before[i] : nil, hasLast: hasLast)
                }
            }
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Gym.fill.opacity(0.35), lineWidth: 1))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("gym-compare")
        }
    }

    /// The pale green of the Today column carried up behind its heading.
    private func headWash(hasLast: Bool) -> some View {
        GeometryReader { g in
            let w = g.size.width - Self.labelWidth
            Gym.doneWash.frame(width: hasLast ? w / 2 : w).frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private static let labelWidth: CGFloat = 84

    /// One set: its name, last time's set and today's (or "next", or nothing yet).
    private func compareRow(_ i: Int, before: GymSet?, hasLast: Bool) -> some View {
        let done = i < today.count ? today[i] : nil
        let warm = done?.isWarmup ?? before?.isWarmup ?? false
        return HStack(spacing: 0) {
            HStack(spacing: 3) {
                if warm { AppMarkView(.warmup, size: 13, colour: Warmup.tint) }
                Text(warm ? "Warm-up" : "Set \(i + 1)")
                    .foregroundStyle(warm ? Warmup.tint : Theme.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .font(.subheadline)
            .padding(.leading, 10)
            .frame(width: Self.labelWidth, alignment: .leading)
            if hasLast {
                Text(before.map(short) ?? "—")
                    .font(.subheadline)
                    .foregroundStyle(before?.isWarmup == true ? Warmup.tint : Theme.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .padding(.horizontal, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("gym-last-\(i + 1)")
            }
            Group {
                if let done {
                    todayCell(done, i)
                } else {
                    Text(i == today.count ? "next" : "")
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                        .padding(.horizontal, 8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .background(Theme.line.opacity(0.35))
                }
            }
        }
        .frame(minHeight: 34)
        .fixedSize(horizontal: false, vertical: true)
    }

    /// Today's set, green — done and proud (since 3.3, his ask); a tap changes it.
    private func todayCell(_ s: GymSet, _ i: Int) -> some View {
        Button { changingSet = i } label: {
            HStack(spacing: 4) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 3) {
                        Text(short(s))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Gym.doneTint)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        if beats(s, i) {
                            // More than the same set last time (since 1.16): the gold arrow.
                            AppMarkView(.up, size: 13, colour: Gym.better)
                        } else {
                            ControlMarkView(.check, size: 11, colour: Gym.doneTint)
                        }
                    }
                    if let effort = s.effort {
                        Text(effort.title)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Gym.effort(effort).tint)
                    }
                }
                Spacer(minLength: 2)
                // The pencil says a tap changes the set (the tick means done, 2.0 mark check).
                ControlMarkView(.edit, size: 11, colour: Gym.tint)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(Gym.doneWash)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(s.isWarmup ? "Warm-up" : "Set \(i + 1)"), \(said(s))\(s.effort.map { ", \($0.title.lowercased())" } ?? "")\(beats(s, i) ? ", more than last time" : "")")
        .accessibilityIdentifier("gym-set-\(i + 1)")
    }

    /// One set short enough for a column, each with its own kg: "2,5 kg × 20", "BW × 20", "12 reps", "10 min · level 4".
    private func short(_ s: GymSet) -> String {
        if s.isTime { return s.text }
        if isReps { return "\(s.reps) reps" }
        return "\(s.kg <= 0 ? "BW" : GymSet.number(s.kg) + " kg") × \(s.reps)"
    }

    /// Last time's note and pain flag, under the box.
    @ViewBuilder private var lastNotes: some View {
        if let last = library.gym.last(machineID, excluding: visit.id), last.entry.note != nil || last.entry.pain == true {
            VStack(alignment: .leading, spacing: 2) {
                if let note = last.entry.note {
                    Text("“\(note)”")
                        .font(.subheadline)
                        .foregroundStyle(Theme.ink)
                        .accessibilityIdentifier("gym-last-note")
                }
                if last.entry.pain == true {
                    // Pain was flagged here last time (since 1.23).
                    Text("Pain flagged last time — go easy.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.problem)
                        .accessibilityIdentifier("gym-last-pain")
                }
            }
        }
    }

    private func beats(_ s: GymSet, _ i: Int) -> Bool {
        library.gym.beatsLastTime(s, at: i, machine: machineID, visit: visit.id)
    }

    private var entry: some View {
        VStack(spacing: 10) {
            HStack {
                Text(warmup ? "Warm-up set" : "Set \(today.count + 1)")
                    .font(.headline)
                    .foregroundStyle(warmup ? Warmup.tint : Gym.tint)
                    .accessibilityIdentifier("gym-next-set")
                Spacer()
                // Warm-up: kept, but never a record or a reason for more weight (since 1.11).
                Button { warmup.toggle() } label: {
                    HStack(spacing: 4) {
                        AppMarkView(.warmup, size: 15, colour: warmup ? Warmup.swatch.inkColor : Warmup.tint)
                        Text("Warm-up").font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(warmup ? Warmup.swatch.inkColor : Warmup.tint)
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background(warmup ? AnyShapeStyle(Warmup.swatch.fillColor) : AnyShapeStyle(Color.clear), in: Capsule())
                    .overlay(Capsule().stroke(Warmup.swatch.fillColor, lineWidth: warmup ? 0 : 1))
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(warmup ? "Warm-up on" : "Warm-up off")
                .accessibilityAddTraits(warmup ? .isSelected : [])
                .accessibilityIdentifier("gym-warmup")
                if newBest {
                    HStack(spacing: 4) {
                        IconMark(.hand("trophy"), size: 18, colour: Gym.tint)
                        Text("New best").font(.subheadline.weight(.semibold)).foregroundStyle(Gym.tint)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("gym-new-best")
                }
            }
            // The same set last time, faintly (since 1.23): "Last time: 40 kg × 10 · hard".
            if !warmup, let line = library.gym.lastSetLine(machineID, place: today.filter { !$0.isWarmup }.count, excluding: visit.id) {
                Text(line)
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted.opacity(0.85))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("gym-last-set")
            }
            if !isReps {
                Stepper2(title: "kg", id: "gym-weight", value: $kg, box: .kg, typing: $typing,
                         minus: { kg = max(0, kg - step) }, plus: { kg += step })
            }
            Stepper2(title: "reps", id: "gym-reps", value: whole($reps), decimals: false, box: .reps, typing: $typing,
                     minus: { reps = max(1, reps - 1) }, plus: { reps += 1 })
            HStack(spacing: 8) {
                Button(action: setDone) {
                    MarkLabel(title: "Set done", mark: .check, size: 24, colour: .white)
                }
                // Green since 1.33 build 2 (his ask: "something positive"); it was indigo.
                .buttonStyle(BigButtonStyle(fill: Gym.done, ink: .white, height: 58))
                .accessibilityIdentifier("gym-set-done")
            }
            if today.isEmpty {
                Text(isReps ? "Filled in from last time — your own body weight, reps only."
                     : kg <= 0 ? "0 kg means body weight." : "Filled in from last time — change only what is different.")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
        }
        .padding(12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Gym.fill.opacity(0.5), lineWidth: 1))
    }

    private func rest(until end: Date) -> some View {
        let left = max(0, end.timeIntervalSince(now))
        return VStack(spacing: 10) {
            ZStack {
                // Orange → yellow → green as the rest runs out (since 1.16; before: always indigo).
                let key = RestColour.key(fractionLeft: left / max(1, restLength))
                Ring(fractionLeft: left / max(1, restLength), colour: IconColour.of(key: key)?.fillColor ?? Gym.fill, width: 14)
                    .animation(.easeInOut(duration: 0.6), value: key)
                    .accessibilityElement()
                    .accessibilityLabel("Rest ring")
                    .accessibilityValue(key)
                    .accessibilityIdentifier("gym-rest-ring")
                VStack(spacing: 0) {
                    Text("REST").font(.caption.weight(.bold)).foregroundStyle(Theme.muted)
                    Text(Clock.text(Int(left.rounded(.up))))
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.ink)
                        .accessibilityIdentifier("gym-rest")
                }
            }
            .frame(width: 180, height: 180)
            // −15, Skip and +15 sit on the bottom of the ring, like a watch (since 3.3, his pick 6 of a
            // numbered picture: "smaller and integrated with the countdown"). Before: three wide buttons
            // in a row under Weight and Reps, 48 points tall.
            .padding(.bottom, 30)
            .overlay { ringButtons(end) }
            Text("Next: set \(today.count + 1) · \(said(GymSet(kg: isReps ? 0 : kg, reps: reps)))")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
            // Change the next set's weight while resting (since 1.31, his ask).
            if !isReps && !isTime {
                restRow("Weight", unit: "kg", id: "gym-rest-weight", value: $kg, decimals: true, box: .restKg,
                        minus: { kg = max(0, kg - step) }, plus: { kg += step })
            }
            // The reps of the next set, typed or −/+ (since 1.33, his ask).
            if !isTime {
                restRow("Reps", unit: "reps", id: "gym-rest-reps", value: whole($reps), decimals: false, box: .restReps,
                        minus: { reps = max(1, reps - 1) }, plus: { reps += 1 })
            }
            if RestLive.isShowing {
                // The same countdown is on the lock screen and in the Dynamic Island (since 1.15).
                Text("Also on your lock screen")
                    .font(.footnote)
                    .foregroundStyle(Gym.tint)
                    .accessibilityIdentifier("gym-rest-lock")
            }
            if let partner {
                // A superset round is done: after the rest, the partner again (since 1.11).
                Button { moveOn(partner.id) } label: {
                    HStack(spacing: 8) {
                        AppMarkView(.pair, size: 18, colour: Superset.swatch.inkColor)
                        Text("Next: \(partner.name)")
                    }
                }
                .buttonStyle(BigButtonStyle(fill: Superset.swatch.fillColor, ink: Superset.swatch.inkColor, height: 48))
                .accessibilityIdentifier("gym-superset-next")
            } else if let target, today.count >= target {
                // As many sets as last time: offer to move on.
                Button { moveOn(upNext?.id) } label: {
                    MarkLabel(title: upNext.map { "Next machine: \($0.name)" } ?? "Done with this machine",
                              mark: .chevron, size: 16, colour: Gym.ink)
                }
                .buttonStyle(BigButtonStyle(fill: Gym.fill, ink: Gym.ink, height: 48))
                .accessibilityIdentifier("gym-next-machine")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// The three rest buttons on the ring (since 3.3): −15 at about eight o'clock, Skip at six, +15 at four.
    /// The ring is 180 points across, its line 14 wide; the buttons sit on that line.
    private func ringButtons(_ end: Date) -> some View {
        let r: CGFloat = 83
        let side = CGFloat(cos(Double.pi / 4)) * r
        return ZStack {
            ringButton(size: 44, tint: Gym.less, id: "gym-rest-less", label: "15 seconds less") {
                // Never below five seconds left: the countdown still ticks.
                let cut = min(15, max(0, end.timeIntervalSince(Date()) - 5))
                restEnd = end.addingTimeInterval(-cut)
                restLength = max(5, restLength - cut)
            } content: {
                Text("−15").font(.subheadline.weight(.bold)).monospacedDigit()
            }
            .offset(x: -side - 6, y: side - 15)
            ringButton(size: 58, tint: Gym.skip, id: "gym-rest-skip", label: "Skip rest") {
                restEnd = nil
                typing = nil
            } content: {
                VStack(spacing: 0) {
                    ControlMarkView(.skip, size: 17, colour: Gym.skip.ink)
                    Text("Skip").font(.caption2.weight(.bold))
                }
            }
            .offset(y: r - 15 + 4)
            ringButton(size: 44, tint: Gym.more, id: "gym-rest-more", label: "15 seconds more") {
                restEnd = end.addingTimeInterval(15)
                restLength += 15
            } content: {
                Text("+15").font(.subheadline.weight(.bold)).monospacedDigit()
            }
            .offset(x: side + 6, y: side - 15)
        }
    }

    private func ringButton<Content: View>(size: CGFloat, tint: (fill: Color, ink: Color), id: String, label: String,
                                           action: @escaping () -> Void, @ViewBuilder content: () -> Content) -> some View {
        Button(action: action) {
            content()
                .foregroundStyle(tint.ink)
                .frame(width: size, height: size)
                .background(tint.fill, in: Circle())
                .overlay(Circle().stroke(tint.ink.opacity(0.25), lineWidth: 1))
                .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(id)
    }

    /// "Weight  −  34,5 kg  +" — under the rest ring (since 1.31, his ask: adjust the weight during the rest).
    /// Since 1.33 the number can be typed: tap it and write the new one; the same for the reps.
    private func restRow(_ title: String, unit: String, id: String, value: Binding<Double>, decimals: Bool,
                         box: NumberBox, minus: @escaping () -> Void, plus: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Gym.tint)
            Spacer(minLength: 0)
            Button(action: minus) {
                Capsule().fill(Gym.ink).frame(width: 14, height: 2.2)
                    .frame(width: 34, height: 34)
                    .background(Gym.fill, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Less \(title.lowercased())")
            .accessibilityIdentifier("\(id)-minus")
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                NumberField(value: value, decimals: decimals, box: box, typing: $typing)
                    .font(.system(.title3, design: .rounded).weight(.bold).monospacedDigit())
                    .foregroundStyle(Theme.ink)
                    .accessibilityIdentifier(id)
                Text(unit).font(.subheadline).foregroundStyle(Theme.muted)
            }
            .frame(minWidth: 92, minHeight: 34)
            .contentShape(Rectangle())
            .onTapGesture { typing = box }
            Button(action: plus) {
                ControlMarkView(.add, size: 18, colour: Gym.ink)
                    .frame(width: 34, height: 34)
                    .background(Gym.fill, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("More \(title.lowercased())")
            .accessibilityIdentifier("\(id)-plus")
        }
        .padding(.leading, 12)
        .padding(.trailing, 6)
        .padding(.vertical, 5)
        .background(Gym.fill.opacity(0.10), in: Capsule())
    }

    /// An Int number as a Double for the number boxes.
    private func whole(_ v: Binding<Int>) -> Binding<Double> {
        Binding(get: { Double(v.wrappedValue) }, set: { v.wrappedValue = Int($0.rounded()) })
    }

    /// Time, level and incline — for a treadmill, a rowing machine, a bike.
    private var timeEntry: some View {
        VStack(spacing: 10) {
            Text(today.isEmpty ? "Time" : "Again")
                .font(.headline)
                .foregroundStyle(Gym.tint)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("gym-next-set")
            if isHold {
                // A hold is entered in seconds and can count down by itself (since 1.23).
                Stepper2(title: "sec", id: "gym-seconds", value: whole($holdSeconds), decimals: false, box: .seconds, typing: $typing,
                         minus: { holdSeconds = max(5, holdSeconds - 5) }, plus: { holdSeconds += 5 })
                Button {
                    typing = nil
                    holdSeconds = max(5, holdSeconds)
                    restEnd = nil
                    holdEnd = Date().addingTimeInterval(Double(holdSeconds))
                    now = Date()
                    Cues.shared.go("Go")
                } label: {
                    MarkLabel(title: "Start countdown", mark: .play, size: 22, colour: Gym.ink)
                }
                .buttonStyle(BigButtonStyle(fill: Gym.fill, ink: Gym.ink, height: 58))
                .accessibilityIdentifier("gym-hold-start")
            } else {
                Stepper2(title: "min", id: "gym-minutes", value: $minutes, box: .minutes, typing: $typing,
                         minus: { minutes = max(1, minutes - 1) }, plus: { minutes += 1 })
            }
            if machine?.hasLevel != false {
                Stepper2(title: "level", id: "gym-level", value: $level, box: .level, typing: $typing,
                         minus: { level = max(0, level - 1) }, plus: { level += 1 })
            }
            if machine?.hasIncline != false {
                Stepper2(title: "% incline", id: "gym-incline", value: $incline, box: .incline, typing: $typing,
                         minus: { incline = max(0, incline - 0.5) }, plus: { incline += 0.5 })
            }
            HStack(spacing: 8) {
                if isHold {
                    Button(action: timeDone) {
                        MarkLabel(title: "Done without countdown", mark: .check, size: 18, colour: Gym.tint)
                    }
                    .buttonStyle(SoftButtonStyle(height: 48))
                    .accessibilityIdentifier("gym-set-done")
                } else {
                    Button(action: timeDone) {
                        MarkLabel(title: "Done", mark: .check, size: 24, colour: Gym.ink)
                    }
                    .buttonStyle(BigButtonStyle(fill: Gym.fill, ink: Gym.ink, height: 58))
                    .accessibilityIdentifier("gym-set-done")
                }
            }
            if today.isEmpty {
                Text(isHold ? "A hold, like a plank: the countdown saves it by itself when the time is up."
                     : "Level and incline can be switched off for this machine with the pencil. With both off it becomes a hold in seconds, with a countdown.")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
        }
        .padding(12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Gym.fill.opacity(0.5), lineWidth: 1))
    }

    /// The hold counting down (since 1.23): a ring, the seconds, and Stop, which saves nothing.
    private func hold(until end: Date) -> some View {
        let left = max(0, end.timeIntervalSince(now))
        return VStack(spacing: 10) {
            ZStack {
                Ring(fractionLeft: left / Double(max(1, holdSeconds)), colour: Gym.fill, width: 14)
                VStack(spacing: 0) {
                    Text("HOLD").font(.caption.weight(.bold)).foregroundStyle(Theme.muted)
                    Text(Clock.text(Int(left.rounded(.up))))
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.ink)
                        .accessibilityIdentifier("gym-hold")
                }
            }
            .frame(width: 180, height: 180)
            Button("Stop") { holdEnd = nil }
                .buttonStyle(SoftButtonStyle(height: 48))
                .accessibilityIdentifier("gym-hold-stop")
            Text("Stop saves nothing. At zero the hold is saved and the rest begins.")
                .font(.caption)
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// How the last set felt (since 1.23): Easy, OK or Hard — the same again takes it away.
    private var effortRow: some View {
        HStack(spacing: 8) {
            Text("Last set felt")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .fixedSize()
            // Easy green, OK blue, Hard orange (since 3.3, his ask "colour code"); before: all three blue.
            ChoicePills(options: Effort.allCases.map { ($0, $0.title, $0.rawValue) }, chosen: today.last?.effort,
                        id: "gym-effort", fill: Gym.fill, ink: Gym.ink, tint: Gym.tint,
                        colours: { Gym.effort($0) }) { e in
                library.changeGym { $0.effort(visit: visit.id, machine: machineID, set: today.count - 1, e) }
            }
        }
    }

    /// Pain on this machine today (since 1.23): shown next time, and no more weight is suggested then.
    private var painRow: some View {
        let on = entryToday?.pain == true
        return HStack(spacing: 10) {
            Button {
                library.changeGym { $0.pain(visit: visit.id, machine: machineID, !on) }
            } label: {
                Text("Pain here")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(on ? Color.white : Theme.problem)
                    .padding(.horizontal, 14)
                    .frame(height: 32)
                    .background(on ? Theme.problem : Color.clear, in: Capsule())
                    .overlay(Capsule().stroke(Theme.problem, lineWidth: 1))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(on ? "Pain flagged" : "Pain here")
            .accessibilityAddTraits(on ? .isSelected : [])
            .accessibilityIdentifier("gym-pain")
            if on {
                Text("Flagged — shown next time, and no more weight is suggested.")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 0)
        }
        .animation(nil, value: on)
    }

    /// How it felt, and what to do next time — shown here the next time as "Last time".
    private var nextTimeRow: some View {
        Button { nextTimeOpen = true } label: {
            HStack(spacing: 10) {
                IconMark(.hand("notebook"), size: 22, colour: Gym.tint)
                VStack(alignment: .leading, spacing: 2) {
                    if let planned = entryToday?.nextTime {
                        Text("Next time: \(planned.text)").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                    } else {
                        Text("How did it feel? Next time…").font(.subheadline.weight(.semibold)).foregroundStyle(Gym.tint)
                    }
                    if let note = entryToday?.note {
                        Text(note).font(.caption).foregroundStyle(Theme.muted).lineLimit(2)
                    }
                }
                Spacer()
                ControlMarkView(.edit, size: 16, colour: Gym.tint)
            }
            .padding(10)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.line, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("gym-next-time")
    }

    @ViewBuilder private var history: some View {
        let points = library.gym.history(machineID)
        if !points.isEmpty {
            Text("History")
                .font(.headline)
                .foregroundStyle(Gym.tint)
                .padding(.top, 8)
            VStack(alignment: .leading, spacing: 6) {
                if points.count > 1 {
                    Chart(points, id: \.date) { p in
                        LineMark(x: .value("Day", p.date), y: .value("kg", p.kg))
                            .foregroundStyle(Gym.tint)
                            .interpolationMethod(.monotone)
                        PointMark(x: .value("Day", p.date), y: .value("kg", p.kg))
                            .foregroundStyle(Gym.tint)
                    }
                    .chartYScale(domain: max(0, (points.map(\.kg).min() ?? 0) - 5)...((points.map(\.kg).max() ?? 0) + 5))
                    .chartYAxisLabel(isReps ? "reps" : "kg")
                    .frame(height: 120)
                    .accessibilityIdentifier("gym-chart")
                }
                ForEach(Array(points.reversed().enumerated()), id: \.element.date) { i, p in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(p.date.formatted(.dateTime.day().month(.abbreviated).year()))
                                .foregroundStyle(Theme.muted)
                            Spacer()
                            Text(library.gym.text(p.entry)).foregroundStyle(Theme.ink)
                                .multilineTextAlignment(.trailing)
                        }
                        .font(.subheadline)
                        if let plan = p.entry.nextTime {
                            Text("Next time: \(library.gym.text(plan, machine: machineID))")
                                .font(.caption).foregroundStyle(Gym.tint)
                                .accessibilityIdentifier("history-visit-recommendation")
                        }
                        if let note = p.entry.note, !note.isEmpty {
                            Text(note).font(.caption).foregroundStyle(Theme.ink)
                                .accessibilityIdentifier("history-visit-note")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if i < points.count - 1 { Divider() }
                }
            }
            .padding(12)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.line, lineWidth: 1))
        }
    }

    // MARK: Actions

    private func prefill() {
        let n = next.set
        if let seconds = n.seconds {
            // A hold's first time: 30 seconds, not a treadmill's 20 minutes.
            holdSeconds = isHold && today.isEmpty && library.gym.last(machineID, excluding: visit.id) == nil ? 30 : seconds
            minutes = Double(seconds) / 60
            level = n.level ?? 0
            incline = n.incline ?? 0
        } else {
            kg = n.kg
            reps = n.reps
        }
    }

    private func timeDone() {
        typing = nil
        let set = GymSet(seconds: isHold ? max(1, holdSeconds) : max(1, Int((minutes * 60).rounded())),
                         level: machine?.hasLevel == false ? nil : level,
                         incline: machine?.hasIncline == false ? nil : incline)
        library.changeGym { $0.add(set, machine: machineID, on: day) }
        Cues.shared.tap()
        Cues.shared.finished("Done")
        if isHold {
            // A hold rests like a set (since 1.23).
            restLength = Double(library.gym.rest(for: machine))
            restSaid = []
            restEnd = restLength > 0 ? Date().addingTimeInterval(restLength) : nil
            now = Date()
        }
    }

    private func setDone() {
        typing = nil
        let set = GymSet(kg: isReps ? 0 : max(0, kg), reps: max(1, reps), warmup: warmup)
        let before = library.gym.best(machineID)
        library.changeGym { $0.add(set, machine: machineID, on: day) }
        newBest = !set.isWarmup && (before.map { library.gym.score(set, machine: machineID) > $0 } ?? false)
        warmup = false
        Cues.shared.tap()
        // Superset: straight on to the partner while it is behind — no rest in between (since 1.11).
        if let jump = library.gym.supersetJump(after: machineID, in: library.gym.openVisit(on: day, gym: gymID)) {
            moveOn(jump)
            return
        }
        restLength = Double(library.gym.rest(for: machine))
        // A machine with no rest goes straight on to the next set.
        restSaid = []
        restEnd = restLength > 0 ? Date().addingTimeInterval(restLength) : nil
        now = Date()
        Cues.shared.rest("Rest")
        // The keyboard opens on Weight with the number picked, to type the next set's weight
        // (since 3.3, his pick: he almost always changes it during the rest); reps-only: on Reps.
        // Screen tests keep the old way unless they ask for it with -restkeyboard.
        if restEnd != nil, MachineScreen.restKeyboard {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                if restEnd != nil { typing = isReps ? .restReps : .restKg }
            }
        }
    }

    /// Off in screen tests (they tap the ring buttons right after a set), unless -restkeyboard.
    static var restKeyboard: Bool {
        let args = ProcessInfo.processInfo.arguments
        return !args.contains("-uitest") || args.contains("-restkeyboard")
    }
}

private struct SetIndex: Identifiable {
    let index: Int
    var id: Int { index }
}

/// Which number box has the keyboard (since 1.33: one per box, so a tap on a number opens the right one).
enum NumberBox: Hashable { case kg, reps, seconds, minutes, level, incline, restKg, restReps }

/// A number box that can be typed in (since 1.33): the whole number is selected on the first tap,
/// so writing "32,5" replaces it; a comma or a point both work.
struct NumberField: View {
    @Binding var value: Double
    var decimals = true
    let box: NumberBox
    var typing: FocusState<NumberBox?>.Binding
    @State private var text = ""

    var body: some View {
        TextField("0", text: $text)
            .keyboardType(decimals ? .decimalPad : .numberPad)
            .multilineTextAlignment(.trailing)
            .fixedSize()
            .focused(typing, equals: box)
            .onAppear { text = GymSet.number(value) }
            .onChange(of: value) { _, v in
                if NumberField.read(text) != v { text = GymSet.number(v) }
            }
            .onChange(of: text) { _, t in
                if let v = NumberField.read(t), v != value { value = decimals ? v : v.rounded() }
            }
            .onChange(of: typing.wrappedValue) { _, now in
                if now == box {
                    DispatchQueue.main.async {
                        UIApplication.shared.sendAction(#selector(UIResponder.selectAll(_:)), to: nil, from: nil, for: nil)
                    }
                } else if NumberField.read(text) == nil || text.isEmpty {
                    text = GymSet.number(value)
                }
            }
    }

    static func read(_ t: String) -> Double? { GymSet.typed(t) }
}

/// "− [ 30 ] kg +" — large, for thumbs at the gym. Since 1.33 a tap anywhere on the number
/// opens the keyboard to type it (before: only exactly on the digits).
private struct Stepper2: View {
    let title: String
    let id: String
    @Binding var value: Double
    var decimals = true
    let box: NumberBox
    var typing: FocusState<NumberBox?>.Binding
    let minus: () -> Void
    let plus: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            round(.minus, action: minus).accessibilityIdentifier("\(id)-minus")
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                NumberField(value: $value, decimals: decimals, box: box, typing: typing)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
                    .accessibilityIdentifier(id)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Theme.muted)
            }
            .frame(maxWidth: .infinity, minHeight: 50)
            .contentShape(Rectangle())
            .onTapGesture { typing.wrappedValue = box }
            round(.plus, action: plus).accessibilityIdentifier("\(id)-plus")
        }
    }

    private enum Sign { case minus, plus }

    private func round(_ sign: Sign, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if sign == .plus {
                    ControlMarkView(.add, size: 22, colour: Gym.tint)
                } else {
                    Capsule().fill(Gym.fill).frame(width: 16, height: 2.2)
                }
            }
            .frame(width: 50, height: 50)
            .background(Gym.fill.opacity(0.12), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(sign == .plus ? "More \(title)" : "Less \(title)")
    }
}

/// Change or remove one set. Cancel leaves it as it was.
private struct SetEditor: View {
    let number: Int
    var repsOnly = false
    @State var set: GymSet
    let done: (GymSet?) -> Void
    let remove: () -> Void

    var body: some View {
        Form {
            Section {
                if !repsOnly {
                HStack {
                    Text("Weight")
                    Spacer()
                    TextField("0", value: $set.kg, format: .number.precision(.fractionLength(0...2)))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .accessibilityIdentifier("set-edit-kg")
                    Text("kg").foregroundStyle(Theme.muted)
                }
                }
                FormNumberRow(title: "Reps", unit: "", id: "set-edit-reps", decimals: false,
                              value: Binding(get: { Double(set.reps) }, set: { set.reps = max(1, Int($0.rounded())) }),
                              minus: { set.reps = max(1, set.reps - 1) }, plus: { set.reps = min(500, set.reps + 1) })
                Toggle("Warm-up", isOn: Binding(get: { set.isWarmup }, set: { set.warmup = $0 ? true : nil }))
                    .tint(Warmup.swatch.fillColor)
                    .accessibilityIdentifier("set-edit-warmup")
            } footer: {
                Text("A warm-up is kept, but never counts as a best or for more weight next time.")
            }
            Section {
                Button("Remove set", role: .destructive, action: remove)
                    .accessibilityIdentifier("set-edit-remove")
            }
        }
        .navigationTitle("Set \(number)")
        .navigationBarTitleDisplayMode(.inline)
        .bottomActions(cancel: { done(nil) }, save: { done(set) }, cancelID: "set-edit-cancel", saveID: "set-edit-save")
    }
}

/// After the sets: what to do next time and how it felt. Nothing is kept until Save.
private struct NextTimeForm: View {
    let isTime: Bool
    var repsOnly = false
    let step: Double
    @State var set: GymSet
    @State var note: String
    @State private var planned = true
    let done: ((set: GymSet?, note: String)?) -> Void

    var body: some View {
        Form {
            Section {
                Toggle("A plan for next time", isOn: $planned)
                    .tint(Gym.fill)
                    .accessibilityIdentifier("next-time-on")
                if planned {
                    if isTime {
                        Stepper("Minutes: \(GymSet.duration(set.seconds ?? 0))",
                                onIncrement: { set.seconds = (set.seconds ?? 0) + 60 },
                                onDecrement: { set.seconds = max(60, (set.seconds ?? 0) - 60) })
                        if set.level != nil {
                            Stepper("Level: \(GymSet.number(set.level ?? 0))",
                                    onIncrement: { set.level = (set.level ?? 0) + 1 },
                                    onDecrement: { set.level = max(0, (set.level ?? 0) - 1) })
                        }
                        if set.incline != nil {
                            Stepper("Incline: \(GymSet.number(set.incline ?? 0)) %",
                                    onIncrement: { set.incline = (set.incline ?? 0) + 0.5 },
                                    onDecrement: { set.incline = max(0, (set.incline ?? 0) - 0.5) })
                        }
                    } else {
                        if !repsOnly {
                            FormNumberRow(title: "Weight", unit: "kg", id: "next-time-kg", decimals: true,
                                          value: $set.kg,
                                          minus: { set.kg = max(0, set.kg - step) }, plus: { set.kg += step })
                        }
                        FormNumberRow(title: "Reps", unit: "", id: "next-time-reps", decimals: false,
                                      value: Binding(get: { Double(set.reps) }, set: { set.reps = max(1, Int($0.rounded())) }),
                                      minus: { set.reps = max(1, set.reps - 1) }, plus: { set.reps = min(500, set.reps + 1) })
                    }
                }
            } footer: {
                Text("Next time this machine starts with these numbers.")
            }
            Section("How did it feel?") {
                TextField("For example: easy — go up next time", text: $note, axis: .vertical)
                    .lineLimit(2...6)
                    .accessibilityIdentifier("next-time-note")
            }
        }
        .navigationTitle("Next time")
        .navigationBarTitleDisplayMode(.inline)
        .bottomActions(cancel: { done(nil) }, save: { done((planned ? set : nil, note)) }, tint: Gym.fill,
                       cancelID: "next-time-cancel", saveID: "next-time-save")
    }
}

/// New machine or change one: photo, name, setting. Nothing is kept until Save.
struct MachineForm: View {
    @Environment(Library.self) private var library
    @State private var draft: Machine
    let isNew: Bool
    let done: (Machine?) -> Void
    @State private var needsName = false
    @State private var camera = false
    @State private var pick: PhotosPickerItem?
    @State private var askDelete = false
    @State private var instructionsCamera = false
    @State private var instructionsPick: PhotosPickerItem?

    init(machine: Machine, isNew: Bool, done: @escaping (Machine?) -> Void) {
        _draft = State(initialValue: machine)
        self.isNew = isNew
        self.done = done
    }

    var body: some View {
        Form {
            Section {
                MachinePhoto(name: draft.photo, height: draft.photo == nil ? 80 : 200, icon: draft.icon)
                    .listRowInsets(EdgeInsets())
                if draft.photo == nil {
                    IconRow(icon: draft.icon, usual: "strength", tint: Gym.tint,
                            identifier: "machine-icon") { draft.icon = $0 }
                }
                if CameraPicker.available {
                    Button { camera = true } label: {
                        MarkLabel(title: draft.photo == nil ? "Take photo" : "Take photo again", mark: .photo, colour: Gym.tint)
                    }
                    .accessibilityIdentifier("machine-camera")
                }
                PhotosPicker(selection: $pick, matching: .images) {
                    MarkLabel(title: "Choose from Photos", mark: .photo, colour: Gym.tint)
                }
                .accessibilityIdentifier("machine-photos")
            }
            Section {
                TextField("For example: Chest press", text: $draft.name)
                    .font(.title3.weight(.semibold))
                    .accessibilityIdentifier("machine-name")
                    .onChange(of: draft.name) { needsName = false }
                if needsName {
                    Text("Give it a name first.")
                        .font(.footnote)
                        .foregroundStyle(Theme.problem)
                        .accessibilityIdentifier("machine-name-needed")
                }
            } header: {
                Text("Name")
            }
            Section {
                TextField("For example: Seat 4, handles 2", text: $draft.setting, axis: .vertical)
                    .accessibilityIdentifier("machine-setting")
            } header: {
                Text("How it is set up")
            } footer: {
                Text("Shown each time you use the machine.")
            }
            Section {
                Picker("Muscle group", selection: $draft.muscle) {
                    Text("Not chosen").tag(String?.none)
                    ForEach(library.gym.muscles) { m in
                        Text(m.name).tag(String?.some(m.id))
                    }
                }
                .tint(Gym.tint)
                .accessibilityIdentifier("machine-muscle")
            }
            Section {
                Picker("Logs", selection: $draft.logs) {
                    Text("Weight × reps").tag(MachineLogs.weights)
                    Text("Time").tag(MachineLogs.time)
                    Text("Reps only").tag(MachineLogs.reps)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("machine-logs")
            } header: {
                Text("What you log")
            } footer: {
                Text(draft.logs == .time ? "Minutes, level and incline — for a treadmill, rowing machine or bike. A plank: Time, with level and incline off."
                     : draft.logs == .reps ? "Reps per set, no weight — push-ups, sit-ups, pull-ups."
                     : "Weight and reps per set.")
            }
            Section {
                TextField("A few words on how to use it", text: Binding(
                    get: { draft.howTo ?? "" },
                    set: { draft.howTo = $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
                ), axis: .vertical)
                    .lineLimit(3...8)
                    .accessibilityIdentifier("machine-howto-field")
            } header: {
                Text("How to use it")
            } footer: {
                Text("Shown with the instruction photo when you tap the small picture beside the machine name.")
            }
            if draft.logs == .time {
                Section {
                    Toggle("Has a level", isOn: Binding(get: { draft.hasLevel }, set: { draft.noLevel = $0 ? nil : true }))
                        .tint(Gym.fill)
                        .accessibilityIdentifier("machine-has-level")
                    Toggle("Has an incline", isOn: Binding(get: { draft.hasIncline }, set: { draft.noIncline = $0 ? nil : true }))
                        .tint(Gym.fill)
                        .accessibilityIdentifier("machine-has-incline")
                } header: {
                    Text("On this machine")
                } footer: {
                    Text("A treadmill often has no level; a bike or rowing machine no incline.")
                }
            }
            if draft.logs != .time {
                Section {
                    if draft.logs == .weights {
                        Toggle("Heavy machine", isOn: Binding(get: { draft.isHeavy }, set: { draft.heavy = $0 ? true : nil }))
                            .tint(Gym.fill)
                            .accessibilityIdentifier("machine-heavy")
                    }
                    // Its own rest, or the usual one for its type (Settings → Rest times, since 1.11).
                    let rest = draft.restSeconds ?? usualRest
                    Stepper(value: Binding(get: { rest }, set: { draft.restSeconds = $0 }), in: 0...300, step: 15) {
                        HStack {
                            Text("Rest")
                            Spacer()
                            Text(draft.restSeconds == nil ? "Usual · \(Clock.text(rest))" : rest == 0 ? "None" : Clock.text(rest))
                                .foregroundStyle(Gym.tint).monospacedDigit()
                                .accessibilityIdentifier("machine-rest-value")
                        }
                    }
                    .accessibilityIdentifier("machine-rest")
                    if draft.restSeconds != nil {
                        Button("Use the usual rest (\(Clock.text(usualRest)))") { draft.restSeconds = nil }
                            .foregroundStyle(Gym.tint)
                            .accessibilityIdentifier("machine-rest-usual")
                    }
                    if draft.logs == .weights {
                    Picker("Weight step", selection: Binding(get: { draft.weightStep }, set: { draft.step = $0 })) {
                        Text("1 kg").tag(1.0)
                        Text("2.5 kg").tag(2.5)
                        Text("5 kg").tag(5.0)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("machine-step")
                    Stepper(value: Binding(get: { draft.repsForMore }, set: { draft.topReps = $0 }), in: 3...50) {
                        HStack {
                            Text("More weight at")
                            Spacer()
                            Text("\(draft.repsForMore) reps").foregroundStyle(Gym.tint).monospacedDigit()
                        }
                    }
                    .accessibilityIdentifier("machine-top-reps")
                    }
                } header: {
                    Text(draft.logs == .reps ? "This exercise" : "On this machine")
                } footer: {
                    Text(draft.logs == .reps ? "Rest after each set. When every set reaches the first set's reps, it suggests one rep more next time."
                         : "Rest after each set; how much − and + change the weight; and when every set reaches this many reps, the machine suggests one step more next time.")
                }
            }
            if draft.logs != .time {
                Section {
                    Picker("Superset with", selection: $draft.partner) {
                        Text("None").tag(UUID?.none)
                        ForEach(partners) { m in
                            Text(m.name).tag(UUID?.some(m.id))
                        }
                    }
                    .tint(Superset.tint)
                    .accessibilityIdentifier("machine-partner")
                } header: {
                    Text("Superset")
                } footer: {
                    Text("Two machines in turn: after a set here, straight on to the other with no rest; the rest comes after both.")
                }
            }
            Section {
                if draft.instructions != nil {
                    MachinePhoto(name: draft.instructions, height: 160)
                        .listRowInsets(EdgeInsets())
                }
                if CameraPicker.available {
                    Button { instructionsCamera = true } label: {
                        MarkLabel(title: draft.instructions == nil ? "Take photo of the instructions" : "Take it again",
                                  mark: .photo, colour: Gym.tint)
                    }
                    .accessibilityIdentifier("machine-instructions-camera")
                }
                PhotosPicker(selection: $instructionsPick, matching: .images) {
                    MarkLabel(title: "Choose from Photos", mark: .photo, colour: Gym.tint)
                }
                .accessibilityIdentifier("machine-instructions-photos")
                if draft.instructions != nil {
                    Button("Remove instructions photo", role: .destructive) { draft.instructions = nil }
                        .accessibilityIdentifier("machine-instructions-remove")
                }
            } header: {
                Text("Instructions")
            } footer: {
                Text("The plate on the machine that shows how to use it.")
            }
            if !isNew {
                Section {
                    Button(draft.logs == .reps ? "Delete exercise" : "Delete machine", role: .destructive) { askDelete = true }
                        .accessibilityIdentifier("machine-delete")
                }
            }
        }
        .navigationTitle(draft.logs == .reps ? (isNew ? "New exercise" : "Edit exercise") : (isNew ? "New machine" : "Edit machine"))
        .navigationBarTitleDisplayMode(.inline)
        .bottomActions(cancel: { done(nil) }, save: save, cancelID: "machine-cancel", saveID: "machine-save")
        .onChange(of: pick) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self),
                   let name = library.storePhoto(data) {
                    draft.photo = name
                }
            }
        }
        .fullScreenCover(isPresented: $camera) {
            CameraPicker { data in
                camera = false
                if let data, let name = library.storePhoto(data) { draft.photo = name }
            }
            .ignoresSafeArea()
        }
        .onChange(of: instructionsPick) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self),
                   let name = library.storePhoto(data) {
                    draft.instructions = name
                }
            }
        }
        .fullScreenCover(isPresented: $instructionsCamera) {
            CameraPicker { data in
                instructionsCamera = false
                if let data, let name = library.storePhoto(data) { draft.instructions = name }
            }
            .ignoresSafeArea()
        }
        .confirmationDialog("Delete \(draft.name) and all its sets?", isPresented: $askDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                library.changeGym(undo: "\(draft.name) deleted") { $0.delete(machine: draft.id) }
                done(nil)
            }
        }
    }

    /// The usual rest for this machine's type, from Settings → Rest times.
    private var usualRest: Int {
        var d = draft
        d.restSeconds = nil
        return library.gym.rest(for: d)
    }

    /// Machines and exercises of the same gym that can be its superset partner.
    private var partners: [Machine] {
        library.gym.machines(in: draft.gymID).filter { $0.id != draft.id && $0.logs != .time }
    }

    private func save() {
        guard !draft.name.trimmingCharacters(in: .whitespaces).isEmpty else {
            needsName = true
            return
        }
        // Pairs go both ways: the old partner is let go, the new one points back.
        let chosen = draft.logs == .time ? nil : draft.partner
        var d = draft
        d.partner = library.gym.machine(d.id)?.partner
        library.changeGym {
            $0.save(d)
            if chosen != d.partner { $0.pair(d.id, with: chosen) }
        }
        draft.partner = chosen
        done(draft)
    }
}

/// The machine's photo, full screen.
private struct ZoomedMachine: View {
    @Environment(Library.self) private var library
    let name: String?
    let close: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            if let image = library.image(name) {
                Image(uiImage: image).resizable().scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            CloseButton(action: close).padding(16)
        }
        .onTapGesture(perform: close)
    }
}

/// The iPhone camera; on a device without one, the photo library.
struct CameraPicker: UIViewControllerRepresentable {
    static var available: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }
    let finished: (Data?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = CameraPicker.available ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(finished: finished) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let finished: (Data?) -> Void
        init(finished: @escaping (Data?) -> Void) { self.finished = finished }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = info[.originalImage] as? UIImage
            finished(image?.jpegData(compressionQuality: 0.9))
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            finished(nil)
        }
    }
}

/// The session's clock as a small green pill: a dot that breathes while it runs, h:mm:ss or m:ss
/// (since 1.31, his ask: "a small cool timer"). Grey and still when the clock is paused.
struct SessionClockPill: View {
    @Environment(Library.self) private var library
    let day: Date
    let gymID: UUID?
    @State private var pulse = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            if let c = library.gym.sessionClock(on: day, gym: gymID, now: context.date) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(c.paused ? Theme.muted : SessionGoingLine.green)
                        .frame(width: 7, height: 7)
                        .scaleEffect(pulse && !c.paused ? 1.35 : 1)
                        .opacity(pulse && !c.paused ? 0.55 : 1)
                    Text(GymVisit.clock(c.seconds))
                        .font(.system(.subheadline, design: .rounded).weight(.bold).monospacedDigit())
                        .foregroundStyle(c.paused ? Theme.muted : SessionGoingLine.green)
                        .contentTransition(.numericText())
                }
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background((c.paused ? Theme.muted : SessionGoingLine.green).opacity(0.14), in: Capsule())
                .fixedSize()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(c.paused ? "Session paused" : "Session going")
                .accessibilityValue(GymVisit.clock(c.seconds))
                .accessibilityIdentifier("machine-session-clock")
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
}

/// "Reps   [ 10 ]  − +" in a form (since 1.33, his ask): the number can be typed as well as stepped.
private struct FormNumberRow: View {
    let title: String
    let unit: String
    let id: String
    let decimals: Bool
    @Binding var value: Double
    let minus: () -> Void
    let plus: () -> Void
    @FocusState private var typing: NumberBox?

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
            Spacer(minLength: 4)
            NumberField(value: $value, decimals: decimals, box: .reps, typing: $typing)
                .monospacedDigit()
                .accessibilityIdentifier(id)
            if !unit.isEmpty { Text(unit).foregroundStyle(Theme.muted) }
            Stepper(title, onIncrement: plus, onDecrement: minus)
                .labelsHidden()
                .accessibilityIdentifier("\(id)-stepper")
        }
        .contentShape(Rectangle())
        .onTapGesture { typing = .reps }
    }
}
