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
    @State private var newBest = false
    /// The next set is a warm-up (since 1.11); off again after that set.
    @State private var warmup = false
    @FocusState private var typing: Bool

    private let clock = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

    private var machine: Machine? { library.gym.machine(machineID) }
    private var visit: GymVisit { library.gym.openVisit(on: day, gym: gymID) ?? GymVisit(gymID: gymID, date: day) }
    private var entryToday: MachineEntry? { visit.entries.last { $0.machineID == machineID } }
    private var isTime: Bool { machine?.logs == .time }
    /// Push-ups, sit-ups: reps only, no weight (since 1.6).
    private var isReps: Bool { machine?.logs == .reps }
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
                lastTime
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

                if !today.isEmpty { setsDone }

                if let restEnd {
                    rest(until: restEnd)
                } else if isTime {
                    timeEntry
                } else {
                    entry
                }

                if !today.isEmpty {
                    nextTimeRow
                }

                history
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle(machine?.name ?? "Machine")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            // Back to the machines; the green Next goes on to the next planned one.
            // With no set yet it says "Back to gym" and logs nothing (since 1.19, his ask; his word since 1.20); Escape on the Mac.
            let leaving = today.isEmpty ? "Back to gym" : "Exercise done"
            Button { moveOn(nil) } label: {
                Text(leaving)
            }
            .buttonStyle(BigButtonStyle(fill: Gym.fill, ink: Gym.ink, height: 50))
            .keyboardShortcut(today.isEmpty ? .cancelAction : nil)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(Theme.bg.opacity(0.96).ignoresSafeArea(edges: .bottom))
            .accessibilityLabel(leaving)
            .accessibilityIdentifier("machine-done-pill")
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { editing = true } label: { ControlMarkView(.edit, size: 22, colour: Gym.tint) }
                    .accessibilityLabel("Edit machine")
                    .accessibilityIdentifier("gym-edit-machine")
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { typing = false }
            }
        }
        .onAppear(perform: prefill)
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
            if let end = restEnd {
                let left = end.timeIntervalSince(t)
                if left <= 0 {
                    restEnd = nil
                    Cues.shared.go("Set \(today.count + 1)")
                } else if left < 3.2, Int(left.rounded(.up)) != Int((left + 0.25).rounded(.up)) {
                    Cues.shared.countdown()
                }
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

    @ViewBuilder private var lastTime: some View {
        if let last = library.gym.last(machineID, excluding: visit.id) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Last time, \(last.visit.date.formatted(.dateTime.day().month(.abbreviated))): \(library.gym.text(last.entry))")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                    .accessibilityIdentifier("gym-last")
                if let note = last.entry.note {
                    Text("“\(note)”")
                        .font(.subheadline)
                        .foregroundStyle(Theme.ink)
                        .accessibilityIdentifier("gym-last-note")
                }
            }
        } else {
            Text("First time on this machine.")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .accessibilityIdentifier("gym-last")
        }
    }

    private var setsDone: some View {
        VStack(spacing: 0) {
            ForEach(Array(today.enumerated()), id: \.offset) { i, s in
                Button { changingSet = i } label: {
                    HStack {
                        if s.isWarmup {
                            AppMarkView(.warmup, size: 15, colour: Warmup.tint)
                            Text("Warm-up").foregroundStyle(Warmup.tint)
                        } else {
                            Text("Set \(i + 1)").foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        if beats(s, i) {
                            // More than the same set last time (since 1.16).
                            AppMarkView(.up, size: 16, colour: Gym.better)
                        }
                        Text(said(s)).fontWeight(s.isWarmup ? .regular : .semibold).foregroundStyle(s.isWarmup ? Theme.muted : Theme.ink)
                        // A tick in a filled circle (since 1.16; before, a bare tick).
                        ControlMarkView(.check, size: 11, colour: s.isWarmup ? Warmup.swatch.inkColor : Gym.ink)
                            .frame(width: 20, height: 20)
                            .background(s.isWarmup ? Warmup.swatch.fillColor : Gym.fill, in: Circle())
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(s.isWarmup ? "Warm-up" : "Set \(i + 1)"), \(said(s))\(beats(s, i) ? ", more than last time" : "")")
                .accessibilityIdentifier("gym-set-\(i + 1)")
                if i < today.count - 1 { Divider().padding(.leading, 12) }
            }
        }
        // Done sets on a light indigo wash (since 1.16; before, the plain card colour).
        .background(Gym.fill.opacity(0.09), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Gym.fill.opacity(0.35), lineWidth: 1))
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
            if !isReps {
                Stepper2(title: "kg", id: "gym-weight",
                         minus: { kg = max(0, kg - step) }, plus: { kg += step }) {
                    TextField("0", value: $kg, format: .number.precision(.fractionLength(0...2)))
                        .keyboardType(.decimalPad)
                        .focused($typing)
                }
            }
            Stepper2(title: "reps", id: "gym-reps",
                     minus: { reps = max(1, reps - 1) }, plus: { reps += 1 }) {
                TextField("0", value: $reps, format: .number)
                    .keyboardType(.numberPad)
                    .focused($typing)
            }
            HStack(spacing: 8) {
                Button(action: setDone) {
                    MarkLabel(title: "Set done", mark: .check, size: 24, colour: Gym.ink)
                }
                .buttonStyle(BigButtonStyle(fill: Gym.fill, ink: Gym.ink, height: 58))
                .accessibilityIdentifier("gym-set-done")
                if !today.isEmpty { nextButton }
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
            Text("Next: set \(today.count + 1) · \(said(GymSet(kg: isReps ? 0 : kg, reps: reps)))")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
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
            HStack(spacing: 10) {
                Button("+15 s") {
                    restEnd = end.addingTimeInterval(15)
                    restLength += 15
                }
                .buttonStyle(SoftButtonStyle(height: 48))
                .accessibilityIdentifier("gym-rest-more")
                Button { restEnd = nil } label: {
                    MarkLabel(title: "Skip rest", mark: .skip, colour: Gym.ink)
                }
                .buttonStyle(BigButtonStyle(fill: Gym.fill, ink: Gym.ink, height: 48))
                .accessibilityIdentifier("gym-rest-skip")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// Time, level and incline — for a treadmill, a rowing machine, a bike.
    private var timeEntry: some View {
        VStack(spacing: 10) {
            Text(today.isEmpty ? "Time" : "Again")
                .font(.headline)
                .foregroundStyle(Gym.tint)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("gym-next-set")
            Stepper2(title: "min", id: "gym-minutes",
                     minus: { minutes = max(1, minutes - 1) }, plus: { minutes += 1 }) {
                TextField("0", value: $minutes, format: .number.precision(.fractionLength(0...1)))
                    .keyboardType(.decimalPad)
                    .focused($typing)
            }
            if machine?.hasLevel != false {
                Stepper2(title: "level", id: "gym-level",
                         minus: { level = max(0, level - 1) }, plus: { level += 1 }) {
                    TextField("0", value: $level, format: .number.precision(.fractionLength(0...1)))
                        .keyboardType(.decimalPad)
                        .focused($typing)
                }
            }
            if machine?.hasIncline != false {
                Stepper2(title: "% incline", id: "gym-incline",
                         minus: { incline = max(0, incline - 0.5) }, plus: { incline += 0.5 }) {
                    TextField("0", value: $incline, format: .number.precision(.fractionLength(0...1)))
                        .keyboardType(.decimalPad)
                        .focused($typing)
                }
            }
            HStack(spacing: 8) {
                Button(action: timeDone) {
                    MarkLabel(title: "Done", mark: .check, size: 24, colour: Gym.ink)
                }
                .buttonStyle(BigButtonStyle(fill: Gym.fill, ink: Gym.ink, height: 58))
                .accessibilityIdentifier("gym-set-done")
                if !today.isEmpty { nextButton }
            }
            if today.isEmpty {
                Text("Level and incline can be switched off for this machine with the pencil.")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
        }
        .padding(12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Gym.fill.opacity(0.5), lineWidth: 1))
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

    /// Done with this machine — green, beside Set done: on to the next planned machine, or back to the machines.
    private var nextButton: some View {
        let green = IconColour.of(key: "green")!
        return Button { moveOn(upNext?.id) } label: {
            VStack(spacing: 0) {
                HStack(spacing: 4) {
                    Text("Next")
                    ControlMarkView(.chevron, size: 14, colour: green.inkColor)
                }
                .font(.system(.title3, design: .rounded).weight(.bold))
                if let upNext {
                    Text(upNext.name).font(.caption2.weight(.semibold)).lineLimit(1)
                }
            }
            .foregroundStyle(green.inkColor)
            .padding(.horizontal, 6)
        }
        .buttonStyle(BigButtonStyle(fill: green.fillColor, ink: green.inkColor, height: 58))
        .frame(width: 118)
        .accessibilityLabel(upNext.map { "Done with this machine, next: \($0.name)" } ?? "Done with this machine")
        .accessibilityIdentifier("gym-machine-done")
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
            minutes = Double(seconds) / 60
            level = n.level ?? 0
            incline = n.incline ?? 0
        } else {
            kg = n.kg
            reps = n.reps
        }
    }

    private func timeDone() {
        typing = false
        let set = GymSet(seconds: max(1, Int((minutes * 60).rounded())),
                         level: machine?.hasLevel == false ? nil : level,
                         incline: machine?.hasIncline == false ? nil : incline)
        library.changeGym { $0.add(set, machine: machineID, on: day) }
        Cues.shared.tap()
        Cues.shared.finished("Done")
    }

    private func setDone() {
        typing = false
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
        restEnd = restLength > 0 ? Date().addingTimeInterval(restLength) : nil
        now = Date()
        Cues.shared.rest("Rest")
    }
}

private struct SetIndex: Identifiable {
    let index: Int
    var id: Int { index }
}

/// "− [ 30 ] kg +" — large, for thumbs at the gym.
private struct Stepper2<Field: View>: View {
    let title: String
    let id: String
    let minus: () -> Void
    let plus: () -> Void
    @ViewBuilder let field: () -> Field

    var body: some View {
        HStack(spacing: 10) {
            round(.minus, action: minus).accessibilityIdentifier("\(id)-minus")
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                field()
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(Theme.ink)
                    .fixedSize()
                    .accessibilityIdentifier(id)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Theme.muted)
            }
            .frame(maxWidth: .infinity)
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
                Stepper("Reps: \(set.reps)", value: $set.reps, in: 1...500)
                    .accessibilityIdentifier("set-edit-reps")
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
                            Stepper("Weight: \(GymSet.weight(set.kg))",
                                    onIncrement: { set.kg += step },
                                    onDecrement: { set.kg = max(0, set.kg - step) })
                                .accessibilityIdentifier("next-time-kg")
                        }
                        Stepper("Reps: \(set.reps)", value: $set.reps, in: 1...500)
                            .accessibilityIdentifier("next-time-reps")
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
