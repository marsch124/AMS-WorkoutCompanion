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
    /// Rest between sets, before +15 s.
    static let restSeconds = 90
}

/// A machine on the gym screen, to open it.
struct MachineRef: Hashable {
    let id: UUID
}

/// The card at the top of Workouts that opens the gym log.
struct GymCard: View {
    @Environment(Library.self) private var library
    let open: () -> Void

    private var summary: String {
        let today = library.gym.visit(on: Date())
        if let today, today.setCount > 0 {
            return "Today: \(today.entries.count) machine\(today.entries.count == 1 ? "" : "s") · \(today.setCount) set\(today.setCount == 1 ? "" : "s")"
        }
        let n = library.gym.machines.count
        return n == 0 ? "Photo, weight and reps per machine" : "\(n) machine\(n == 1 ? "" : "s")"
    }

    var body: some View {
        Button(action: open) {
            HStack(spacing: 12) {
                IconTile(.hand("strength"), colour: Gym.swatch, fallbackTint: Theme.accent, letter: "G", size: 44)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("At the gym")
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                ControlMarkView(.chevron, size: 16, colour: Gym.tint)
                    .padding(.trailing, 6)
            }
            .padding(.vertical, 8)
            .padding(.leading, 10)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Gym.fill.opacity(0.5), lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("At the gym, \(summary)")
        .accessibilityIdentifier("open-gym")
    }
}

/// The gym: today's date, a photo tile per machine in any order, and Finish.
struct GymScreen: View {
    @Environment(Library.self) private var library
    @State private var day = Date()
    @State private var camera = false
    @State private var newMachine: Machine?
    @State private var opened: MachineRef?
    @State private var summary: GymVisit?

    private var visit: GymVisit? { library.gym.visit(on: day) }
    private var isToday: Bool { Calendar.current.isDateInToday(day) }
    private let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(isToday ? "Today" : "Date")
                        .font(.headline)
                        .foregroundStyle(Gym.tint)
                    Spacer()
                    DatePicker("Date", selection: $day, in: ...Date(), displayedComponents: .date)
                        .labelsHidden()
                        .accessibilityIdentifier("gym-date")
                }
                Text(library.gym.machines.isEmpty
                     ? "At each machine: take a photo, give it a name, then log your sets."
                     : "Tap whichever machine is free.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)

                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(library.gym.machines) { m in
                        Button { opened = MachineRef(id: m.id) } label: {
                            MachineTile(machine: m, status: status(of: m), done: doneToday(m))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("machine-\(m.name)")
                    }
                    Button(action: addMachine) { NewMachineTile() }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("gym-new-machine")
                }

                if let visit, visit.setCount > 0 {
                    Button { finish(visit) } label: {
                        MarkLabel(title: "Finish", mark: .check, size: 22, colour: Gym.ink)
                    }
                    .buttonStyle(BigButtonStyle(fill: Gym.fill, ink: Gym.ink, height: 52))
                    .padding(.top, 6)
                    .accessibilityIdentifier("gym-finish")
                }

                let earlier = library.gym.visitsNewestFirst.filter { $0.id != visit?.id }
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
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $opened) { ref in
            MachineScreen(machineID: ref.id, day: day)
        }
        .navigationDestination(for: GymVisit.self) { v in
            VisitScreen(visitID: v.id)
        }
        .fullScreenCover(isPresented: $camera) {
            CameraPicker { data in
                camera = false
                guard let data else { return }
                newMachine = Machine(photo: library.storePhoto(data))
            }
            .ignoresSafeArea()
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
    }

    private func addMachine() {
        // The camera first, as at the machine; UI tests and a Mac without a camera go straight to the name.
        if CameraPicker.available && !Cues.shared.quiet {
            camera = true
        } else {
            newMachine = Machine()
        }
    }

    private func doneToday(_ m: Machine) -> Bool {
        (visit?.entries.contains { $0.machineID == m.id && !$0.sets.isEmpty }) ?? false
    }

    private func status(of m: Machine) -> String {
        if let visit {
            let sets = visit.entries.filter { $0.machineID == m.id }.reduce(0) { $0 + $1.sets.count }
            if sets > 0 { return "\(sets) set\(sets == 1 ? "" : "s") done" }
        }
        if let last = library.gym.last(m.id, excluding: visit?.id) {
            return "Last: \(GymSet.weight(last.entry.heaviest))"
        }
        return "New"
    }

    private func finish(_ visit: GymVisit) {
        var v = visit
        v.finished = Date()
        library.changeGym { $0.put(v) }
        Cues.shared.finished("Well done")
        summary = v
    }
}

/// A machine's photo with its name and how far it is today.
private struct MachineTile: View {
    @Environment(Library.self) private var library
    let machine: Machine
    let status: String
    let done: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack(alignment: .topTrailing) {
                MachinePhoto(name: machine.photo, height: 96)
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
            Text(status)
                .font(.caption)
                .foregroundStyle(done ? Gym.tint : Theme.muted)
                .lineLimit(1)
        }
        .padding(6)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(done ? Gym.fill : Theme.line, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

private struct NewMachineTile: View {
    var body: some View {
        VStack(spacing: 6) {
            IconMark(.hand("camera"), size: 34, colour: Gym.tint)
            Text("New machine")
                .font(.subheadline.weight(.semibold))
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

    var body: some View {
        Group {
            if let image = library.image(name) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                IconMark(.hand("strength"), size: height * 0.42, colour: Gym.tint)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Gym.fill.opacity(0.1))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityHidden(true)
    }
}

private struct VisitRow: View {
    let visit: GymVisit

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(visit.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).year()))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Text("\(visit.entries.count) machine\(visit.entries.count == 1 ? "" : "s") · \(visit.setCount) set\(visit.setCount == 1 ? "" : "s")")
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

/// One earlier visit: every machine with its sets.
struct VisitScreen: View {
    @Environment(Library.self) private var library
    let visitID: UUID

    var body: some View {
        let visit = library.gym.visits.first { $0.id == visitID }
        List {
            if let visit {
                Section {
                    ForEach(visit.entries) { e in
                        HStack(spacing: 10) {
                            MachinePhoto(name: library.gym.machine(e.machineID)?.photo, height: 40)
                                .frame(width: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(library.gym.machine(e.machineID)?.name ?? "Machine")
                                    .font(.body.weight(.semibold))
                                Text(e.text)
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.muted)
                            }
                        }
                    }
                } footer: {
                    Text("\(visit.setCount) sets · \(GymSet.number(visit.totalKg)) kg lifted in all")
                }
            }
        }
        .navigationTitle(visit?.date.formatted(date: .abbreviated, time: .omitted) ?? "Visit")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// After Finish: what this visit came to.
struct SummaryScreen: View {
    @Environment(Library.self) private var library
    let visitID: UUID
    let done: () -> Void

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
                    row("Machines", "\(visit.entries.count)", id: "gym-summary-machines")
                    row("Sets", "\(visit.setCount)", id: "gym-summary-sets")
                    if let start = visit.started {
                        let minutes = max(1, Int((visit.finished ?? Date()).timeIntervalSince(start) / 60))
                        row("Time", "\(minutes) min", id: "gym-summary-time")
                    }
                    row("Lifted in all", "\(GymSet.number(visit.totalKg)) kg", id: "gym-summary-total")
                }
                if !bests.isEmpty {
                    Section("New bests") {
                        ForEach(bests, id: \.self) { id in
                            let top = visit.entries.filter { $0.machineID == id }.map(\.heaviest).max() ?? 0
                            HStack {
                                IconMark(.hand("trophy"), size: 20, colour: Gym.tint)
                                Text(library.gym.machine(id)?.name ?? "Machine")
                                Spacer()
                                Text(GymSet.weight(top)).foregroundStyle(Gym.tint).fontWeight(.semibold)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Workout done")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done", action: done)
                    .saveButton()
                    .accessibilityIdentifier("gym-summary-done")
            }
        }
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
        var log = GymLog(machines: [press, leg, lat])
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
        return log
    }
}
