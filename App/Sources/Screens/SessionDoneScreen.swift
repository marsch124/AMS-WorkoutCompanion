import AMSIcons
import SwiftUI
import WorkoutCore

/// After Finish: what this session came to, and a title and notes for it.
struct SummaryScreen: View {
    @Environment(Library.self) private var library
    let visitID: UUID
    /// Undo Finish — tapped by mistake: the session goes on (since 1.14).
    var undo: (() -> Void)? = nil
    /// Discard session — throw it away after all (since 1.30, his ask); asks once more first.
    var discard: (() -> Void)? = nil
    let done: () -> Void
    @State private var askingDiscard = false
    @State private var title = ""
    @State private var notes = ""
    @State private var stretching: Workout?
    @State private var namingTemplate = false
    @State private var templateName = ""
    @State private var savedTemplate: String?

    /// The stretch list for after a session: the one chosen in Settings, else the app's own, made on first use.
    private func stretch() {
        if let w = library.workouts.first(where: { $0.id == library.gym.stretchID }) {
            stretching = w
            return
        }
        let w = Workout.afterGymStretch()
        library.save(w)
        library.changeGym { $0.stretchID = w.id }
        stretching = w
    }

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
                // How the whole session felt (since 1.23): one tap, the same again takes it away.
                Section {
                    ChoicePills(options: Feel.allCases.map { ($0, $0.title, $0.rawValue) }, chosen: visit.feel,
                                id: "gym-feel", fill: Gym.fill, ink: Gym.ink, tint: Gym.tint) { f in
                        library.changeGym { $0.feel(visit: visitID, visit.feel == f ? nil : f) }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                } header: {
                    Text("How did it feel?")
                }
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
                    SessionPhotos(visitID: visit.id)
                } header: {
                    Text("Photos of this session")
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
                // Today against the visit before, at this gym (since 1.23).
                let lines = library.gym.compare(visit)
                if !lines.isEmpty, let before = library.gym.previous(of: visit) {
                    Section("Against last visit · \(before.date.formatted(.dateTime.day().month(.abbreviated)))") {
                        ForEach(lines) { line in
                            HStack {
                                Text(line.title)
                                Spacer()
                                Text(line.now).foregroundStyle(Theme.muted)
                                Text(line.change)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(line.better == true ? SessionGoingLine.green : line.better == false ? Gym.busyTint : Theme.muted)
                                    .frame(minWidth: 64, alignment: .trailing)
                                    .accessibilityIdentifier("gym-compare-\(line.id)")
                            }
                        }
                    }
                }
                // Save as template — part of finishing since 1.30 (his ask; before: a tile on the gym screen's head).
                let order = visit.templateOrder(in: library.gym)
                if !order.isEmpty {
                    Section {
                        Button {
                            templateName = ""
                            namingTemplate = true
                        } label: {
                            HStack(spacing: 8) {
                                if savedTemplate != nil {
                                    ControlMarkView(.check, size: 20, colour: SessionGoingLine.green)
                                } else {
                                    AppMarkView(.template, size: 22, colour: Gym.tint)
                                }
                                Text(savedTemplate.map { "Saved as template · \($0)" } ?? "Save as template")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(savedTemplate != nil ? SessionGoingLine.green : Gym.tint)
                                    .lineLimit(1)
                                Spacer()
                                if savedTemplate == nil { ControlMarkView(.chevron, size: 14, colour: Gym.tint) }
                            }
                        }
                        .disabled(savedTemplate != nil)
                        .accessibilityIdentifier("gym-summary-template")
                        .alert("Save as template", isPresented: $namingTemplate) {
                            TextField("For example: Leg day", text: $templateName)
                            Button("Cancel", role: .cancel) {}
                            Button("Save") {
                                let name = templateName.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !name.isEmpty else { return }
                                let g = visit.gymID
                                library.changeGym { _ = $0.saveTemplate(named: name, order: order, gym: g) }
                                savedTemplate = name
                            }
                            .accessibilityIdentifier("gym-summary-template-save")
                        } message: {
                            Text("This session's machines, in the order you used them. Use it later under Plan today. The same name in this gym is replaced.")
                        }
                    } footer: {
                        Text("Keep this session's machines and order for another day.")
                    }
                }
                if library.gym.stretchID != GymLog.noStretch {
                    Section {
                        Button(action: stretch) {
                            HStack(spacing: 8) {
                                IconMark(.hand("yoga"), size: 22, colour: Gym.tint)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("Stretch now").fontWeight(.semibold).foregroundStyle(Gym.tint)
                                    Text("Timer with voice cues in your AirPods").font(.caption).foregroundStyle(Theme.muted)
                                }
                                Spacer()
                                ControlMarkView(.chevron, size: 14, colour: Gym.tint)
                            }
                        }
                        .accessibilityIdentifier("gym-stretch")
                        // The guide: how to do each stretch (since 1.30, his ask).
                        NavigationLink {
                            StretchGuideScreen(workout: library.workouts.first { $0.id == library.gym.stretchID }
                                               ?? StretchRoutine.all[0].workout())
                        } label: {
                            HStack(spacing: 8) {
                                AppMarkView(.template, size: 20, colour: Gym.tint)
                                Text("How to do the stretches").foregroundStyle(Gym.tint)
                            }
                        }
                        .accessibilityIdentifier("gym-stretch-guide")
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
        // Since 1.32 (his ask) Stretch now starts the guided timer with voice cues.
        .fullScreenCover(item: $stretching) { w in
            StretchTimerScreen(workout: w) { stretching = nil }
                .environment(library)
        }
        .onAppear {
            title = visit?.title ?? ""
            notes = visit?.notes ?? ""
        }
        .bottomActions(cancel: undo.map { u in {
            library.changeGym { $0.describe(visit: visitID, title: title, notes: notes) }
            u()
        } }, cancelTitle: "Undo Finish", save: {
            library.changeGym { $0.describe(visit: visitID, title: title, notes: notes) }
            done()
        }, saveTitle: "Done", tint: Gym.fill, cancelID: "gym-summary-undo", saveID: "gym-summary-done",
           discard: discard.map { _ in { askingDiscard = true } }, discardTitle: "Discard", discardID: "gym-summary-discard")
        .alert("Discard this session?", isPresented: $askingDiscard) {
            Button("Discard session", role: .destructive) { discard?() }
                .accessibilityIdentifier("gym-summary-discard-confirm")
            Button("Keep the session", role: .cancel) { }
        } message: {
            let n = library.gym.visits.first { $0.id == visitID }?.setCount ?? 0
            Text("All \(n == 1 ? "1 set" : "\(n) sets") of this session are deleted, with its title, notes and photos. It will not show in Earlier visits or History. This cannot be undone.")
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
