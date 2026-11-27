import AMSIcons
import SwiftUI
import WorkoutCore

/// Version 3.3, the planning board (iPad and Mac): plan the next gym session on a big screen — which
/// machines, in which order, and the numbers each starts with. Nothing is kept until Save, except the
/// "Numbers" of a machine, which are saved for next time from their own sheet.
struct PlanningBoardScreen: View {
    @Environment(Library.self) private var library
    @Environment(\.horizontalSizeClass) private var sizeClass
    let gymID: UUID?
    let done: () -> Void

    private enum DayChoice: Hashable { case today, tomorrow, date }

    @State private var order: [UUID] = []
    @State private var choice: DayChoice = .today
    @State private var picked = Date()
    @State private var loaded = false
    @State private var search = ""
    @State private var namingTemplate = false
    @State private var templateName = ""
    @State private var numbersFor: UUID?

    private let cal = Calendar.current

    private var day: Date {
        switch choice {
        case .today: return cal.startOfDay(for: Date())
        case .tomorrow: return cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Date())) ?? Date()
        case .date: return cal.startOfDay(for: picked)
        }
    }

    private var machines: [Machine] { library.gym.machines(in: gymID) }
    private var templates: [PlanTemplate] { library.gym.templates(gym: gymID) }

    private func dayText(_ d: Date) -> String {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("EEEd MMM")
        return f.string(from: d)
    }

    var body: some View {
        NavigationStack {
            Group {
                if sizeClass == .regular {
                    HStack(alignment: .top, spacing: 16) {
                        machinesColumn
                        planColumn
                    }
                } else {
                    VStack(spacing: 12) {
                        machinesColumn
                        planColumn
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .navigationTitle("Planning board")
            .navigationBarTitleDisplayMode(.inline)
            .bottomActions(cancel: done, save: save, tint: Gym.fill, cancelID: "board-cancel", saveID: "board-save")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("board-screen")
        .onAppear(perform: load)
        .alert("Save as template", isPresented: $namingTemplate) {
            TextField("For example: Leg day", text: $templateName)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                let name = templateName, o = order, g = gymID
                library.changeGym { _ = $0.saveTemplate(named: name, order: o, gym: g) }
            }
        } message: {
            Text("The same name in this gym is replaced.")
        }
        .sheet(item: Binding(get: { numbersFor.map { BoardID(id: $0) } }, set: { numbersFor = $0?.id })) { b in
            if let m = library.gym.machine(b.id) {
                NavigationStack {
                    BoardNumbersSheet(machine: m, start: library.gym.startingSet(m.id) ?? GymLog.starter) { result in
                        numbersFor = nil
                        if let result { library.changeGym { _ = $0.setStartingSet(result, machine: m.id) } }
                    }
                }
                .presentationDetents([.medium])
            }
        }
    }

    // MARK: Loading and saving

    private func load() {
        guard !loaded else { return }
        loaded = true
        let today = cal.startOfDay(for: Date())
        if let p = library.gym.plans.first(where: { $0.gymID == gymID }), cal.startOfDay(for: p.day) >= today {
            order = p.order.filter { library.gym.machine($0) != nil }
            let d = cal.startOfDay(for: p.day)
            if d == today { choice = .today }
            else if d == cal.date(byAdding: .day, value: 1, to: today) { choice = .tomorrow }
            else { choice = .date; picked = d }
        }
    }

    private func save() {
        let o = order, d = day, g = gymID
        library.changeGym { $0.setPlan(o, on: d, gym: g) }
        done()
    }

    // MARK: Left: machines

    private var machinesColumn: some View {
        let found = Set(library.gym.machines(in: gymID, matching: search).map(\.id))
        return VStack(alignment: .leading, spacing: 6) {
            Text("Machines")
                .font(.headline).foregroundStyle(Gym.tint)
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: 6) {
                AppMarkView(.search, size: 21, colour: Theme.muted)
                TextField("Find a machine", text: $search)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("board-search")
                if !search.isEmpty {
                    Button { search = "" } label: { ControlMarkView(.close, size: 12, colour: Theme.muted) }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear")
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 36)
            .background(Theme.card, in: Capsule())
            Text("Tap a machine to add it to the plan.")
                .font(.footnote).foregroundStyle(Theme.muted)
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(machines.filter { found.contains($0.id) }) { m in
                        machineCard(m)
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func machineCard(_ m: Machine) -> some View {
        let planned = order.contains(m.id)
        return Button {
            if !planned { order.append(m.id) }
        } label: {
            HStack(spacing: 10) {
                MachinePhoto(name: m.photo, height: 44, icon: m.icon, corner: 8)
                    .frame(width: 60)
                VStack(alignment: .leading, spacing: 1) {
                    Text(m.name).font(.body.weight(.semibold)).foregroundStyle(Theme.ink)
                    Text(planned ? "In the plan" : library.gym.lastText(m))
                        .font(.footnote)
                        .foregroundStyle(planned ? Gym.tint : Theme.muted)
                }
                Spacer(minLength: 0)
            }
            .padding(6)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity(planned ? 0.5 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .draggable(m.id.uuidString)
        .accessibilityIdentifier("board-machine-\(m.name)")
    }

    // MARK: Right: the plan

    private var planColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Plan")
                .font(.headline).foregroundStyle(Gym.tint)
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: 8) {
                Picker("Day", selection: $choice) {
                    Text("Today").tag(DayChoice.today)
                    Text("Tomorrow").tag(DayChoice.tomorrow)
                    Text("Pick a date").tag(DayChoice.date)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("board-day")
                if choice == .date {
                    DatePicker("Day", selection: $picked, in: Date()..., displayedComponents: .date)
                        .labelsHidden()
                        .accessibilityIdentifier("board-date")
                }
            }
            HStack(spacing: 8) {
                boardButton("Repeat last visit", id: "board-repeat") {
                    let o = library.gym.lastOrder(gym: gymID, before: day)
                    if !o.isEmpty { order = o }
                }
                Menu {
                    if templates.isEmpty { Text("No templates yet") }
                    ForEach(templates) { t in
                        Button(t.name) { order = library.gym.order(of: t) }
                    }
                } label: { pill("Use a template") }
                .accessibilityIdentifier("board-template")
                boardButton("Save as template…", id: "board-save-template") {
                    templateName = ""
                    namingTemplate = true
                }
                .disabled(order.isEmpty)
            }
            if let other = library.gym.planDayWarning(for: day, gym: gymID) {
                Text("Saving replaces your plan for \(dayText(other)).")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Gym.busyTint)
                    .accessibilityIdentifier("board-warning")
            }
            if order.isEmpty {
                Text("Nothing planned yet — tap machines on the left.")
                    .font(.subheadline).foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else {
                // A List with an always-active edit mode: the drag handles work on the Mac too.
                List {
                    ForEach(Array(order.enumerated()), id: \.element) { i, id in
                        if let m = library.gym.machine(id) { planRow(i, m) }
                    }
                    .onMove { order.move(fromOffsets: $0, toOffset: $1) }
                }
                .listStyle(.plain)
                .environment(\.editMode, .constant(.active))
                Text("Drag the handles to change the order.")
                    .font(.footnote).foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(8)
        .background(Gym.fill.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .dropDestination(for: String.self) { items, _ in
            var added = false
            for s in items {
                if let id = UUID(uuidString: s), machines.contains(where: { $0.id == id }), !order.contains(id) {
                    order.append(id); added = true
                }
            }
            return added
        }
    }

    private func planRow(_ i: Int, _ m: Machine) -> some View {
        let used = library.gym.last(m.id) != nil
        let start = library.gym.startingSet(m.id)
        return HStack(spacing: 10) {
            Text("\(i + 1)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Gym.ink)
                .frame(width: 26, height: 26)
                .background(Gym.fill, in: Circle())
            MachinePhoto(name: m.photo, height: 40, icon: m.icon, corner: 8)
                .frame(width: 54)
            VStack(alignment: .leading, spacing: 1) {
                Text(m.name).font(.body.weight(.semibold)).foregroundStyle(Theme.ink)
                Text(used ? "Starts with \(start.map { library.gym.text($0, machine: m.id) } ?? "")"
                          : "First time — numbers on the day")
                    .font(.footnote).foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 4)
            if used {
                Button { numbersFor = m.id } label: {
                    HStack(spacing: 4) {
                        PencilMark(size: 15, colour: Gym.tint)
                        Text("Numbers")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Gym.tint)
                }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("board-numbers-\(i + 1)")
            }
            Button { order.removeAll { $0 == m.id } } label: {
                Text("Remove")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.muted)
            }
            .buttonStyle(.borderless)
            .accessibilityIdentifier("board-remove-\(i + 1)")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("board-plan-\(i + 1)")
    }

    private func pill(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Gym.ink)
            .padding(.horizontal, 12)
            .frame(minHeight: 34)
            .background(Gym.fill, in: RoundedRectangle(cornerRadius: 10))
    }

    private func boardButton(_ title: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { pill(title) }
            .buttonStyle(.plain)
            .accessibilityIdentifier(id)
    }
}

private struct BoardID: Identifiable { let id: UUID }

/// A small hand-drawn pencil, for the Numbers button (in the AMS-Icons style).
private struct PencilMark: View {
    let size: CGFloat
    let colour: Color
    var body: some View {
        GridShape(d: "M5 19l1-4 9.5-9.5a2.1 2.1 0 0 1 3 3L9 18Z M14 7l3 3")
            .stroke(colour, style: StrokeStyle(lineWidth: size * 1.9 / 24, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// The numbers a machine starts with next time. Saved from here, right away.
private struct BoardNumbersSheet: View {
    let machine: Machine
    @State var set: GymSet
    let done: (GymSet?) -> Void

    init(machine: Machine, start: GymSet, done: @escaping (GymSet?) -> Void) {
        self.machine = machine
        _set = State(initialValue: start)
        self.done = done
    }

    private var isTime: Bool { machine.logs == .time }
    private var repsOnly: Bool { machine.logs == .reps }

    var body: some View {
        Form {
            Section {
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
                        HStack {
                            Text("Weight")
                            Spacer()
                            TextField("0", value: $set.kg, format: .number.precision(.fractionLength(0...2)))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .fixedSize()
                                .accessibilityIdentifier("board-numbers-kg")
                            Text("kg").foregroundStyle(Theme.muted)
                            Stepper("Weight", onIncrement: { set.kg += machine.weightStep },
                                    onDecrement: { set.kg = max(0, set.kg - machine.weightStep) })
                                .labelsHidden()
                        }
                    }
                    HStack {
                        Text("Reps")
                        Spacer()
                        TextField("0", value: $set.reps, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .fixedSize()
                            .accessibilityIdentifier("board-numbers-reps")
                        Stepper("Reps", onIncrement: { set.reps = min(500, set.reps + 1) },
                                onDecrement: { set.reps = max(1, set.reps - 1) })
                            .labelsHidden()
                    }
                }
            } footer: {
                Text("Saved for next time on this machine.")
            }
        }
        .navigationTitle(machine.name)
        .navigationBarTitleDisplayMode(.inline)
        .bottomActions(cancel: { done(nil) }, save: {
            var s = set
            if s.reps < 1 && !isTime { s.reps = 1 }
            done(s)
        }, tint: Gym.fill, cancelID: "board-numbers-cancel", saveID: "board-numbers-save")
    }
}
