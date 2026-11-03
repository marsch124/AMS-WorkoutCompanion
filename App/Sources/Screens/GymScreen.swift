import AMSIcons
import SwiftUI
import WorkoutCore

/// The gym log's colour: its headings, buttons and marks.
enum Gym {
    static let swatch = IconColour.of(key: "indigo")!
    static var fill: Color { swatch.fillColor }
    static var ink: Color { swatch.inkColor }
    /// Headings, words and marks on the page: indigo by day, a lighter indigo by night.
    static let tint = Color.pair("#4f46e5", "#9d97ff")
    /// A machine marked Busy: orange, so it stands out from the indigo of the rest.
    static let busy = IconColour.of(key: "orange")!
    static let busyTint = Color.pair("#c2410c", "#fdba74")
}

/// A machine on the gym screen, to open it.
struct MachineRef: Hashable {
    let id: UUID
}

/// The card at the top of Workouts that opens the gym log.
struct GymCard: View {
    @Environment(Library.self) private var library
    let open: () -> Void
    @State private var changingIcon = false

    private var summary: String {
        if let today = library.gym.visits.first(where: { Calendar.current.isDateInToday($0.date) && $0.setCount > 0 }) {
            return "Today: \(today.entries.count) machine\(today.entries.count == 1 ? "" : "s") · \(today.setCount) set\(today.setCount == 1 ? "" : "s")"
        }
        let n = library.gym.machines.count
        return n == 0 ? "Photo, weight and reps per machine" : "\(n) machine\(n == 1 ? "" : "s")"
    }

    var body: some View {
        Button(action: open) {
            HStack(spacing: 12) {
                IconMark(.hand(library.gym.homeIcon ?? "gym"), size: 34, colour: Gym.ink)
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("At the gym")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Gym.ink)
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(Gym.ink.opacity(0.85))
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                ControlMarkView(.chevron, size: 16, colour: Gym.ink)
                    .padding(.trailing, 6)
            }
            .padding(.vertical, 18)
            .padding(.leading, 12)
            .background(Gym.fill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("At the gym, \(summary)")
        .accessibilityIdentifier("open-gym")
        .contextMenu {
            Button("Change icon…") { changingIcon = true }
                .accessibilityIdentifier("gym-change-icon")
        }
        .sheet(isPresented: $changingIcon) {
            NavigationStack {
                IconPicker(current: library.gym.homeIcon, tint: Gym.tint) { key in
                    library.changeGym { $0.homeIcon = key }
                    changingIcon = false
                } onCancel: { changingIcon = false }
            }
        }
    }
}

/// The gym: which gym, today's date, an optional plan, a photo tile per machine in any order, and Finish.
struct GymScreen: View {
    @Environment(Library.self) private var library
    @State private var day = Date()
    @State private var camera = false
    @State private var newMachine: Machine?
    @State private var opened: MachineRef?
    @State private var summary: GymVisit?
    @State private var planning = false
    @State private var naming: GymNaming?
    @State private var gymName = ""
    @State private var pickingDay = false
    @State private var search = ""
    @State private var namingRepeat = false
    @State private var repeatName = ""

    private var gymID: UUID? { library.gym.currentGym?.id }
    private var visit: GymVisit? { library.gym.visit(on: day, gym: gymID) }
    private var machines: [Machine] { library.gym.machines(in: gymID) }
    private var plan: DayPlan? { library.gym.plan(on: day, gym: gymID) }
    private var isToday: Bool { Calendar.current.isDateInToday(day) }
    private let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    gymMenu
                    Spacer()
                }
                if !isToday {
                    HStack {
                        Text("Logging for \(day.formatted(.dateTime.weekday(.wide).day().month(.wide)))")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Gym.busyTint)
                        Spacer()
                        Button("Back to today") { day = Date() }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Gym.tint)
                            .accessibilityIdentifier("gym-today")
                    }
                    .padding(10)
                    .background(Gym.busy.fillColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityIdentifier("gym-earlier-day")
                }
                Text(machines.isEmpty
                     ? "At each machine: take a photo, give it a name, then log your sets."
                     : plan == nil ? "Tap the machine you'll use next — or plan today's order." : "Follow the plan, or tap any machine that is free.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                    .accessibilityIdentifier("gym-intro")

                planSection

                let busy = library.gym.busy(on: day).compactMap { library.gym.machine($0) }.filter { $0.gymID == gymID }
                if !busy.isEmpty {
                    Text("Come back to")
                        .font(.headline)
                        .foregroundStyle(Gym.busyTint)
                        .accessibilityIdentifier("gym-come-back")
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(busy) { tile($0, busy: true) }
                    }
                }
                if !busy.isEmpty || plan != nil, busy.count < machines.count {
                    Text(busy.isEmpty ? "All machines" : "Other machines")
                        .font(.headline)
                        .foregroundStyle(Gym.tint)
                        .padding(.top, 4)
                }

                // A long list gets a search field (since 1.11): name or setting ("Seat 4").
                if machines.count > GymScreen.searchFrom {
                    HStack(spacing: 6) {
                        AppMarkView(.search, size: 16, colour: Gym.tint)
                        TextField("Find a machine", text: $search)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .accessibilityIdentifier("gym-search")
                        if !search.isEmpty {
                            Button { search = "" } label: { ControlMarkView(.close, size: 12, colour: Theme.muted) }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Clear")
                                .accessibilityIdentifier("gym-search-clear")
                        }
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 36)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Gym.fill.opacity(0.5), lineWidth: 1))
                }
                let found = Set(library.gym.machines(in: gymID, matching: search).map(\.id))
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(machines.filter { m in !busy.contains { $0.id == m.id } && found.contains(m.id) }) { tile($0, busy: false) }
                    Button(action: addMachine) { NewMachineTile() }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("gym-new-machine")
                }

                if let visit, visit.setCount > 0 {
                    Button { finish(visit) } label: {
                        MarkLabel(title: "Finish this session", mark: .check, size: 22, colour: Gym.ink)
                    }
                    .buttonStyle(BigButtonStyle(fill: Gym.fill, ink: Gym.ink, height: 52))
                    .padding(.top, 6)
                    .accessibilityLabel("Finish this session")
                    .accessibilityIdentifier("gym-finish")
                }

                let earlier = library.gym.visits(in: gymID).filter { $0.id != visit?.id }
                if !earlier.isEmpty {
                    Text("Earlier visits")
                        .font(.headline)
                        .foregroundStyle(Gym.tint)
                        .padding(.top, 10)
                    VStack(spacing: 0) {
                        ForEach(Array(earlier.enumerated()), id: \.element.id) { i, v in
                            NavigationLink(value: v) {
                                VisitRow(visit: v)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("gym-visit-\(i + 1)")
                            if i < earlier.count - 1 { Divider().padding(.leading, 12) }
                        }
                    }
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.line, lineWidth: 1))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle("At the gym")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            if library.gym.gyms.isEmpty { library.changeGym { $0.ensureGym() } }
        }
        .navigationDestination(item: $opened) { ref in
            MachineScreen(machineID: ref.id, day: day, gymID: gymID) { next in
                if let next {
                    library.changeGym { $0.setBusy(next, false, on: day) }
                    opened = MachineRef(id: next)
                } else {
                    opened = nil
                }
            }
            .id(ref.id)
        }
        .navigationDestination(for: GymVisit.self) { v in
            VisitScreen(visitID: v.id)
        }
        .fullScreenCover(isPresented: $camera) {
            CameraPicker { data in
                camera = false
                guard let data else { return }
                newMachine = Machine(gymID: gymID, photo: library.storePhoto(data))
            }
            .ignoresSafeArea()
            // Push-ups or a plank have no machine to photograph: on to the form without a photo.
            .overlay(alignment: .top) {
                Button {
                    camera = false
                    newMachine = Machine(gymID: gymID)
                } label: {
                    Text("Skip photo")
                        .font(.headline)
                        .foregroundStyle(Gym.ink)
                        .padding(.horizontal, 20)
                        .frame(height: 44)
                        .background(Gym.fill, in: Capsule())
                }
                .padding(.top, 110)
                .accessibilityIdentifier("machine-skip-photo")
            }
        }
        .sheet(item: $newMachine) { m in
            NavigationStack {
                MachineForm(machine: m, isNew: true) { saved in
                    newMachine = nil
                    // Straight on to logging the first set.
                    if let saved { opened = MachineRef(id: saved.id) }
                }
            }
            .environment(library)
        }
        .sheet(item: $summary) { v in
            NavigationStack {
                SummaryScreen(visitID: v.id) { summary = nil }
            }
            .environment(library)
        }
        .sheet(isPresented: $pickingDay) {
            NavigationStack {
                DayPicker(day: day) { picked in
                    pickingDay = false
                    if let picked { day = picked }
                }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $planning) {
            NavigationStack {
                PlanSheet(machines: machines, gymID: gymID, order: plan?.order ?? []) { order in
                    planning = false
                    if let order { library.changeGym { $0.setPlan(order, on: day, gym: gymID) } }
                }
            }
        }
        .alert(naming == .new ? "New gym" : "Rename gym", isPresented: Binding(
            get: { naming != nil }, set: { if !$0 { naming = nil } }
        )) {
            TextField("For example: City gym", text: $gymName)
                .accessibilityIdentifier("gym-place-name")
            Button("Cancel", role: .cancel) { naming = nil }
                .accessibilityIdentifier("gym-place-cancel")
            Button("Save") { saveGymName() }
                .accessibilityIdentifier("gym-place-save")
        } message: {
            Text(naming == .new ? "Each gym has its own machines." : "")
        }
    }

    // MARK: Which gym

    private var gymMenu: some View {
        Menu {
            ForEach(library.gym.gyms) { g in
                Button {
                    library.changeGym { $0.currentGymID = g.id }
                } label: {
                    Text(g.id == gymID ? "\(g.name) — here now" : g.name)
                }
                .accessibilityIdentifier("gym-place-\(g.name)")
            }
            Divider()
            Button("New gym…") {
                gymName = ""
                naming = .new
            }
            .accessibilityIdentifier("gym-place-new")
            Button("Log an earlier day…") { pickingDay = true }
                .accessibilityIdentifier("gym-pick-day")
            Button("Rename this gym…") {
                gymName = library.gym.currentGym?.name ?? ""
                naming = .rename
            }
            .accessibilityIdentifier("gym-place-rename")
        } label: {
            HStack(spacing: 6) {
                Text(library.gym.currentGym?.name ?? GymLog.firstGymName)
                    .font(.headline)
                    .foregroundStyle(Gym.tint)
                    .lineLimit(1)
                ControlMarkView(.chevron, size: 12, colour: Gym.tint)
                    .rotationEffect(.degrees(90))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Gym.fill.opacity(0.12), in: Capsule())
        }
        .accessibilityLabel("Gym: \(library.gym.currentGym?.name ?? GymLog.firstGymName)")
        .accessibilityIdentifier("gym-place-menu")
    }

    private func saveGymName() {
        let name = gymName.trimmingCharacters(in: .whitespacesAndNewlines)
        defer { naming = nil }
        guard !name.isEmpty else { return }
        if naming == .new {
            library.changeGym { $0.addGym(name) }
        } else if let id = gymID {
            library.changeGym { $0.renameGym(id, to: name) }
        }
    }

    // MARK: Today's plan

    @ViewBuilder private var planSection: some View {
        if let plan {
            let next = library.gym.upNext(on: day, gym: gymID)
            HStack {
                Text("Today's plan")
                    .font(.headline)
                    .foregroundStyle(Gym.tint)
                Spacer()
                Button("Change") { planning = true }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Gym.tint)
                    .accessibilityIdentifier("gym-plan")
            }
            VStack(spacing: 0) {
                ForEach(Array(plan.order.enumerated()), id: \.element) { i, id in
                    if let m = library.gym.machine(id) {
                        planRow(i, m, plan: plan, isNext: id == next)
                        if i < plan.order.count - 1 { Divider().padding(.leading, 48) }
                    }
                }
            }
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Gym.fill.opacity(0.5), lineWidth: 1))
            Text("Touch and hold a machine: later, skip today or swap.")
                .font(.caption)
                .foregroundStyle(Theme.muted)
        } else if !machines.isEmpty {
            HStack(spacing: 8) {
            Button { planning = true } label: {
                MarkLabel(title: "Plan today", mark: .list, size: 18, colour: Gym.tint)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Gym.tint)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .overlay(Capsule().stroke(Gym.fill, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("gym-plan")
            // Same machines, same order as last time — a plan in one tap (since 1.7).
            let repeatOrder = library.gym.lastOrder(gym: gymID, before: day)
            if !repeatOrder.isEmpty {
                Button {
                    library.changeGym { $0.setPlan(repeatOrder, on: day, gym: gymID) }
                } label: {
                    MarkLabel(title: "Repeat last visit", mark: .play, size: 16, colour: Gym.ink)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Gym.ink)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Gym.fill, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("gym-repeat")
                // Keep last visit as a template, without planning first (since 1.11).
                Button {
                    repeatName = ""
                    namingRepeat = true
                } label: {
                    Text("Save as template")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Gym.tint)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .overlay(Capsule().stroke(Gym.fill, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("gym-repeat-template")
            }
            }
            .alert("Save last visit as template", isPresented: $namingRepeat) {
                TextField("For example: Leg day", text: $repeatName)
                Button("Cancel", role: .cancel) {}
                    .accessibilityIdentifier("gym-repeat-template-cancel")
                Button("Save") {
                    let name = repeatName, o = library.gym.lastOrder(gym: gymID, before: day), g = gymID
                    library.changeGym { _ = $0.saveTemplate(named: name, order: o, gym: g) }
                }
                .accessibilityIdentifier("gym-repeat-template-save")
            } message: {
                Text("Last visit's machines, in their order. Use it later under Plan today. The same name in this gym is replaced.")
            }
        }
    }

    private func planRow(_ i: Int, _ m: Machine, plan: DayPlan, isNext: Bool) -> some View {
        let done = library.gym.isDone(m.id, on: day, gym: gymID)
        let skipped = plan.skipped.contains(m.id)
        let busy = library.gym.isBusy(m.id, on: day)
        let status = done ? "done" : skipped ? "skipped today" : busy ? "busy" : isNext ? "up next" : nil
        return Button { open(m.id) } label: {
            HStack(spacing: 10) {
                Text("\(i + 1)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(isNext ? Gym.ink : Gym.tint)
                    .frame(width: 26, height: 26)
                    .background(isNext ? Gym.fill : Gym.fill.opacity(0.12), in: Circle())
                VStack(alignment: .leading, spacing: 1) {
                    Text(m.name)
                        .font(.body.weight(isNext ? .semibold : .regular))
                        .foregroundStyle(skipped ? Theme.muted : Theme.ink)
                        .strikethrough(skipped)
                    if let status {
                        Text(status.prefix(1).uppercased() + status.dropFirst())
                            .font(.caption)
                            .foregroundStyle(busy && !done ? Gym.busyTint : done ? Theme.muted : Gym.tint)
                    }
                }
                Spacer()
                if done {
                    ControlMarkView(.check, size: 16, colour: Gym.tint)
                } else {
                    ControlMarkView(.chevron, size: 14, colour: Theme.muted)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isNext ? Gym.fill.opacity(0.08) : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Later") { library.changeGym { $0.later(m.id) } }
            Button(skipped ? "Back in today's plan" : "Skip today") { library.changeGym { $0.skip(m.id, !skipped) } }
            let others = machines.filter { !plan.order.contains($0.id) }
            if !others.isEmpty {
                Menu("Swap for") {
                    ForEach(others) { o in
                        Button(o.name) { library.changeGym { $0.swap(m.id, for: o.id) } }
                    }
                }
            }
            Button("Remove from plan", role: .destructive) { library.changeGym { $0.removeFromPlan(m.id) } }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(i + 1), \(m.name)\(status.map { ", \($0)" } ?? "")")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("plan-row-\(i + 1)")
    }

    private func open(_ id: UUID) {
        if library.gym.isBusy(id, on: day) { library.changeGym { $0.setBusy(id, false, on: day) } }
        opened = MachineRef(id: id)
    }

    /// A machine's tile, with its own Busy button on the photo.
    private func tile(_ m: Machine, busy: Bool) -> some View {
        Button {
            // At the machine, it is free: the Busy mark has done its job.
            open(m.id)
        } label: {
            MachineTile(machine: m, status: status(of: m), done: doneToday(m), busy: busy)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("machine-\(m.name)")
        .overlay(alignment: .topLeading) {
            Button {
                library.changeGym { $0.setBusy(m.id, !busy, on: day) }
            } label: {
                BusyPill(on: busy)
            }
            .buttonStyle(.plain)
            .padding(10)
            .accessibilityLabel(busy ? "\(m.name) is busy" : "Mark \(m.name) busy")
            .accessibilityIdentifier("busy-\(m.name)")
        }
    }

    private func addMachine() {
        // The camera first, as at the machine; UI tests and a Mac without a camera go straight to the name.
        if CameraPicker.available && !Cues.shared.quiet {
            camera = true
        } else {
            newMachine = Machine(gymID: gymID)
        }
    }

    private func doneToday(_ m: Machine) -> Bool {
        (visit?.entries.contains { $0.machineID == m.id && !$0.sets.isEmpty }) ?? false
    }

    private func status(of m: Machine) -> String {
        if let visit {
            let sets = visit.entries.filter { $0.machineID == m.id }.reduce(0) { $0 + $1.sets.count }
            if sets > 0 { return m.logs == .time ? "Done today" : "\(sets) set\(sets == 1 ? "" : "s") done" }
        }
        if let last = library.gym.last(m.id, excluding: visit?.id) {
            if m.logs == .time, let first = last.entry.sets.first { return "Last: \(first.text)" }
            if m.logs == .reps { return "Last: \(last.entry.mostReps) reps" }
            return "Last: \(GymSet.weight(last.entry.heaviest))"
        }
        return "New"
    }

    private func finish(_ visit: GymVisit) {
        let now = Date()
        library.changeGym { $0.finish(visit: visit.id, at: now) }
        Cues.shared.finished("Well done")
        summary = library.gym.visits.first { $0.id == visit.id }
    }
}

extension GymScreen {
    /// More machines than this, and the gym screen gets a search field.
    static let searchFrom = 8
}

private enum GymNaming { case new, rename }

/// For a session you forgot to log: pick the day. Nothing changes until Done.
private struct DayPicker: View {
    @State var day: Date
    let done: (Date?) -> Void

    var body: some View {
        Form {
            DatePicker("Day", selection: $day, in: ...Date(), displayedComponents: .date)
                .datePickerStyle(.graphical)
                .tint(Gym.fill)
                .accessibilityIdentifier("gym-date")
        }
        .navigationTitle("Log an earlier day")
        .navigationBarTitleDisplayMode(.inline)
        .bottomActions(cancel: { done(nil) }, save: { done(day) }, saveTitle: "Done", tint: Gym.fill,
                       cancelID: "gym-date-cancel", saveID: "gym-date-done")
    }
}

/// Plan today: tap the machines in the order you want them. Nothing is kept until Save.
private struct PlanSheet: View {
    @Environment(Library.self) private var library
    let machines: [Machine]
    let gymID: UUID?
    @State var order: [UUID]
    let done: ([UUID]?) -> Void
    @State private var namingTemplate = false
    @State private var templateName = ""
    @State private var deleting: PlanTemplate?

    private var templates: [PlanTemplate] { library.gym.templates(gym: gymID) }

    var body: some View {
        List {
            if !templates.isEmpty {
                Section {
                    ForEach(templates) { t in
                        HStack {
                            Button {
                                order = library.gym.order(of: t)
                            } label: {
                                HStack {
                                    Text(t.name).foregroundStyle(Theme.ink)
                                    Spacer()
                                    let n = library.gym.order(of: t).count
                                    Text(n == 1 ? "1 machine" : "\(n) machines")
                                        .font(.subheadline).foregroundStyle(.secondary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("plan-template-\(t.name)")
                            Button { deleting = t } label: {
                                ControlMarkView(.close, size: 18, colour: .red)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Delete the template \(t.name)")
                            .accessibilityIdentifier("plan-template-delete-\(t.name)")
                        }
                    }
                    .moveDisabled(true)
                    .deleteDisabled(true)
                } header: {
                    Text("Use a template")
                }
            }
            // Today's order with drag handles (1.9.3, his "adjust the plan — maybe with drag handles?").
            if !order.isEmpty {
                Section {
                    ForEach(Array(order.enumerated()), id: \.element) { i, id in
                        if let m = machines.first(where: { $0.id == id }) {
                            HStack(spacing: 10) {
                                Text("\(i + 1)")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(Gym.ink)
                                    .frame(width: 26, height: 26)
                                    .background(Gym.fill, in: Circle())
                                MachinePhoto(name: m.photo, height: 36, icon: m.icon)
                                    .frame(width: 36)
                                Text(m.name).foregroundStyle(Theme.ink)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("\(i + 1), \(m.name)")
                            .accessibilityIdentifier("plan-order-\(i + 1)")
                        }
                    }
                    .onMove { order.move(fromOffsets: $0, toOffset: $1) }
                    .onDelete { order.remove(atOffsets: $0) }
                } header: {
                    Text("Today's order")
                } footer: {
                    Text("Drag the handles to change the order; the red minus takes a machine out.")
                }
                // Right under the order, so it is never hidden behind Cancel and Save (1.10).
                Section {
                    Button {
                        templateName = ""
                        namingTemplate = true
                    } label: {
                        Text("Save as template…")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Gym.ink)
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .background(Gym.fill, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .accessibilityIdentifier("plan-save-template")
                }
            }
            Section {
                ForEach(machines) { m in
                    let n = order.firstIndex(of: m.id).map { $0 + 1 }
                    Button {
                        if let i = order.firstIndex(of: m.id) { order.remove(at: i) } else { order.append(m.id) }
                    } label: {
                        HStack(spacing: 10) {
                            Text(n.map(String.init) ?? "")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Gym.ink)
                                .frame(width: 26, height: 26)
                                .background(n == nil ? AnyShapeStyle(Color.clear) : AnyShapeStyle(Gym.fill), in: Circle())
                                .overlay(Circle().stroke(Gym.fill, lineWidth: n == nil ? 1.5 : 0))
                            MachinePhoto(name: m.photo, height: 36, icon: m.icon)
                                .frame(width: 36)
                            Text(m.name).foregroundStyle(Theme.ink)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("plan-machine-\(m.name)")
                }
                .moveDisabled(true)
                .deleteDisabled(true)
            } header: {
                Text(order.isEmpty ? "Machines" : "Add or take out")
            } footer: {
                Text("Tap the machines in the order you want them; tap again to take one out. You can still use any machine at the gym.")
            }
            if !order.isEmpty {
                Section {
                    Button("Clear the plan", role: .destructive) { order = [] }
                        .accessibilityIdentifier("plan-clear")
                }
            }
        }
        .alert("Save as template", isPresented: $namingTemplate) {
            TextField("For example: Leg day", text: $templateName)
            Button("Cancel", role: .cancel) {}
                .accessibilityIdentifier("plan-template-cancel")
            Button("Save") {
                let name = templateName, o = order, g = gymID
                library.changeGym { _ = $0.saveTemplate(named: name, order: o, gym: g) }
            }
            .accessibilityIdentifier("plan-template-name-save")
        } message: {
            Text("The same name in this gym is replaced.")
        }
        .alert("Delete the template \"\(deleting?.name ?? "")\"?", isPresented: Binding(
            get: { deleting != nil }, set: { if !$0 { deleting = nil } }
        )) {
            Button("Cancel", role: .cancel) { deleting = nil }
            Button("Delete", role: .destructive) {
                if let t = deleting { library.changeGym { $0.deleteTemplate(t.id) } }
                deleting = nil
            }
        } message: {
            Text("Today's plan stays.")
        }
        // Always in edit mode, so the handles show without an Edit button.
        .environment(\.editMode, .constant(.active))
        .navigationTitle("Plan today")
        .navigationBarTitleDisplayMode(.inline)
        .bottomActions(cancel: { done(nil) }, save: { done(order) }, tint: Gym.fill,
                       cancelID: "plan-cancel", saveID: "plan-save")
    }
}

/// A machine's photo with its name and how far it is today.
private struct MachineTile: View {
    @Environment(Library.self) private var library
    let machine: Machine
    let status: String
    let done: Bool
    let busy: Bool

    private var border: Color { busy ? Gym.busy.fillColor : done ? Gym.fill : Theme.line }
    private var stripe: IconColour? { library.gym.muscle(for: machine).flatMap { IconColour.of(key: $0.colour) } }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack(alignment: .topTrailing) {
                MachinePhoto(name: machine.photo, height: 96, icon: machine.icon)
                if done {
                    ControlMarkView(.check, size: 14, colour: Gym.ink)
                        .frame(width: 26, height: 26)
                        .background(Gym.fill, in: Circle())
                        .padding(6)
                }
            }
            Text(machine.name.isEmpty ? "Untitled" : machine.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
            Text(busy ? "Busy — come back later" : status)
                .font(.caption)
                .foregroundStyle(busy ? Gym.busyTint : done ? Gym.tint : Theme.muted)
                .lineLimit(1)
        }
        .padding(6)
        .padding(.leading, stripe == nil ? 0 : 3)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        // The machine's muscle group colour, as a thin stripe down the left edge (since 1.11).
        .overlay(alignment: .leading) {
            if let stripe {
                stripe.fillColor
                    .frame(width: 5)
                    .accessibilityIdentifier("tile-stripe-\(machine.name)")
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(border, lineWidth: busy ? 1.5 : 1))
        .accessibilityElement(children: .combine)
    }
}

/// "Busy" on a machine's photo: full orange when marked, a light outline when not.
private struct BusyPill: View {
    let on: Bool

    var body: some View {
        HStack(spacing: 4) {
            IconMark(.hand("stopwatch"), size: 14, colour: on ? Gym.busy.inkColor : Gym.busyTint)
            Text("Busy")
                .font(.caption.weight(.semibold))
                .foregroundStyle(on ? Gym.busy.inkColor : Gym.busyTint)
        }
        .padding(.horizontal, 8)
        .frame(height: 26)
        .background(on ? AnyShapeStyle(Gym.busy.fillColor) : AnyShapeStyle(Theme.card.opacity(0.92)), in: Capsule())
        .overlay(Capsule().stroke(Gym.busy.fillColor, lineWidth: on ? 0 : 1))
        .contentShape(Capsule())
    }
}

private struct NewMachineTile: View {
    var body: some View {
        VStack(spacing: 6) {
            IconMark(.hand("camera"), size: 34, colour: Gym.tint)
            Text("New machine\nor exercise")
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(Gym.tint)
        }
        .frame(maxWidth: .infinity, minHeight: 142)
        .background(Gym.fill.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(Gym.fill, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])))
        .accessibilityElement(children: .combine)
    }
}

/// A machine's photo, or its hand-drawn mark when there is none.
struct MachinePhoto: View {
    @Environment(Library.self) private var library
    let name: String?
    var height: CGFloat
    var icon: String? = nil

    var body: some View {
        // The photo fills a fixed box and is cut to it — for drawing AND for taps. Before 1.9.2 an
        // upright photo on a wide tile reached invisibly above it and took the taps meant for
        // "Plan today" (his home gym: tapping Plan today opened Dumbbell).
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .overlay {
                if let image = library.image(name) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    IconMark(.hand(icon ?? "strength"), size: height * 0.42, colour: Gym.tint)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Gym.fill.opacity(0.1))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .accessibilityHidden(true)
    }
}

private struct VisitRow: View {
    let visit: GymVisit

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(visit.title ?? visit.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).year()))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Text((visit.title == nil ? "" : visit.date.formatted(.dateTime.day().month(.abbreviated)) + " · ")
                     + "\(visit.entries.count) machine\(visit.entries.count == 1 ? "" : "s") · \(visit.setCount) set\(visit.setCount == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            ControlMarkView(.chevron, size: 14, colour: Theme.muted)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

extension GymVisit {
    /// "Tuesday at City gym" — the suggestion when there is no title yet.
    func suggestedTitle(in log: GymLog) -> String {
        let place = log.gyms.first { $0.id == gymID }?.name ?? "the gym"
        return "\(date.formatted(.dateTime.weekday(.wide))) at \(place)"
    }
}


/// After Finish: what this session came to, and a title and notes for it.
struct SummaryScreen: View {
    @Environment(Library.self) private var library
    let visitID: UUID
    let done: () -> Void
    @State private var title = ""
    @State private var notes = ""

    var body: some View {
        let visit = library.gym.visits.first { $0.id == visitID }
        let bests = visit.map { library.gym.newBests(in: $0) } ?? []
        List {
            Section {
                VStack(spacing: 8) {
                    IconMark(.hand(bests.isEmpty ? "strength" : "trophy"), size: 56, colour: Gym.tint)
                    Text("Well done")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Theme.ink)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            if let visit {
                Section {
                    TextField(visit.suggestedTitle(in: library.gym), text: $title)
                        .font(.headline)
                        .accessibilityIdentifier("gym-summary-title")
                    TextField("Notes — how it went, what to remember", text: $notes, axis: .vertical)
                        .lineLimit(2...6)
                        .accessibilityIdentifier("gym-summary-notes")
                } header: {
                    Text("Title and notes")
                }
                Section {
                    row("Machines", "\(visit.entries.count)", id: "gym-summary-machines")
                    row("Sets", "\(visit.setCount)", id: "gym-summary-sets")
                    if let minutes = visit.minutes {
                        row("Time", "\(minutes) min", id: "gym-summary-time")
                    }
                    if visit.minutesOnMachines > 0 {
                        row("On time machines", "\(visit.minutesOnMachines) min", id: "gym-summary-cardio")
                    }
                    if visit.totalKg > 0 {
                        row("Lifted in all", "\(GymSet.number(visit.totalKg)) kg", id: "gym-summary-total")
                    }
                }
                if !bests.isEmpty {
                    Section("New bests") {
                        ForEach(bests, id: \.self) { id in
                            let top = library.gym.top(id, in: visit)
                            let isReps = library.gym.machine(id)?.logs == .reps
                            HStack {
                                IconMark(.hand("trophy"), size: 20, colour: Gym.tint)
                                Text(library.gym.machine(id)?.name ?? "Machine")
                                Spacer()
                                Text(isReps ? "\(Int(top)) reps" : GymSet.weight(top)).foregroundStyle(Gym.tint).fontWeight(.semibold)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Session done")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            title = visit?.title ?? ""
            notes = visit?.notes ?? ""
        }
        .bottomActions(cancel: nil, save: {
            library.changeGym { $0.describe(visit: visitID, title: title, notes: notes) }
            done()
        }, saveTitle: "Done", tint: Gym.fill, saveID: "gym-summary-done")
    }

    private func row(_ title: String, _ value: String, id: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).fontWeight(.semibold).accessibilityIdentifier(id)
        }
    }
}

extension GymLog {
    /// Made-up machines and visits for the screen tour (-gymdemo) — never real data.
    static func demo(now: Date = Date()) -> GymLog {
        let cal = Calendar.current
        let press = Machine(name: "Chest press", setting: "Seat 4, handles 2")
        let leg = Machine(name: "Leg press", setting: "Back rest 3")
        let lat = Machine(name: "Lat pulldown", setting: "Knee pad 5")
        let tread = Machine(name: "Treadmill", logs: .time)
        var log = GymLog(machines: [press, leg, lat, tread])
        let plan: [(Int, UUID, Double, [Int])] = [
            (-14, press.id, 25, [12, 11, 10]), (-14, leg.id, 50, [12, 12, 12]),
            (-10, press.id, 27.5, [12, 10, 10]), (-10, lat.id, 30, [10, 10, 9]),
            (-7, press.id, 27.5, [12, 12, 11]), (-7, leg.id, 55, [12, 11, 10]),
            (-3, press.id, 30, [12, 12, 12]), (-3, lat.id, 32.5, [10, 9, 9]),
        ]
        for (days, id, kg, reps) in plan {
            let day = cal.date(byAdding: .day, value: days, to: now)!
            for r in reps { log.add(GymSet(kg: kg, reps: r), machine: id, on: day, now: day) }
        }
        let last = cal.date(byAdding: .day, value: -3, to: now)!
        log.add(GymSet(seconds: 25 * 60, level: 8, incline: 2), machine: tread.id, on: last, now: last)
        for v in log.visits { log.finish(visit: v.id, at: v.date.addingTimeInterval(50 * 60)) }
        if let v = log.visit(on: last) {
            log.nextTime(visit: v.id, machine: lat.id, set: GymSet(kg: 32.5, reps: 10), note: "Last set was heavy — stay at 32.5.")
        }
        log.ensureGym()
        return log
    }

    /// For tests and pictures of 1.11 (-gymextras) — made-up data.
    mutating func addExtras() {
        let groups = ["Chest press": "chest", "Leg press": "legs", "Lat pulldown": "back"]
        for i in machines.indices { machines[i].muscle = groups[machines[i].name] }
        let gym = currentGym?.id
        for (name, muscle) in [("Shoulder press", "shoulders"), ("Biceps curl", "arms"), ("Triceps pushdown", "arms"),
                               ("Leg curl", "legs"), ("Seated row", "back"), ("Ab crunch", "core")] {
            var m = Machine(gymID: gym, name: name)
            m.muscle = muscle
            save(m)
        }
        if let a = machines.first(where: { $0.name == "Chest press" }), let b = machines.first(where: { $0.name == "Lat pulldown" }) {
            pair(a.id, with: b.id)
        }
    }
}
