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
    @State private var stretchingNow = false
    @State private var namingTemplate = false
    @State private var templateName = ""
    @State private var savedTemplate: String?
    @State private var showingPhotos = false

    /// 2.0: Stretch now opens his stretches (chooser → timer) for this visit; the time joins the visit.
    private func stretch() { stretchingNow = true }

    var body: some View {
        let visit = library.gym.visits.first { $0.id == visitID }
        let bests = visit.map { library.gym.newBests(in: $0) } ?? []
        List {
            Section {
                VStack(spacing: 8) {
                    heroPicture(visit: visit, gold: !bests.isEmpty)
                    Text("Well done")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity, alignment: visit?.photos?.first != nil ? .leading : .center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowBackground(Color.clear)
            }
            if let visit {
                // Since 2.2 (his ask, a marked screenshot): Stretch now, then Save as template, right under
                // Well done. Before, both were near the bottom, under the numbers and Against last visit.
                if library.gym.stretchID != GymLog.noStretch, visit.stretching == nil {
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
                            StretchGuideScreen(libraryIDs: library.gym.stretchBook?.ticked.filter { StretchLibrary.item($0) != nil })
                        } label: {
                            HStack(spacing: 8) {
                                AppMarkView(.template, size: 20, colour: Gym.tint)
                                Text("How to do the stretches").foregroundStyle(Gym.tint)
                            }
                        }
                        .accessibilityIdentifier("gym-stretch-guide")
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
            }
            if let visit {
                let split = visit.split
                let hasBar = split.warmup > 0 || split.stretch > 0
                do {
                    Section {
                        VStack(spacing: 8) {
                            if hasBar { timeBar(split) }
                            weekTile(visit)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                    }
                }
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
        // Since 1.32 (his ask) Stretch now starts the guided timer with voice cues; since 2.0 his chosen
        // stretches, and the stretching time joins this visit.
        .fullScreenCover(isPresented: $stretchingNow) {
            StretchSessionEntry(visitID: visitID) { part in
                if let part { library.changeGym { $0.setStretching(visitID: visitID, part: part) } }
                stretchingNow = false
            }
            .environment(library)
        }
        .sheet(isPresented: $showingPhotos) {
            NavigationStack {
                ScrollView { SessionPhotos(visitID: visitID).padding(16) }
                    .navigationTitle("Photos of this session")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showingPhotos = false } } }
            }
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

    private static let gold = Color.pair("#d4a017", "#f5c542")
    private static let warmOrange = Warmup.tint  // the same warm-up colour as on the machine page (sign check)

    /// The first session photo big with the trophy badge on its lower-right corner; no photo: the trophy large.
    @ViewBuilder private func heroPicture(visit: GymVisit?, gold: Bool) -> some View {
        let colour = gold ? Self.gold : Gym.tint
        let value = gold ? "gold" : "plain"
        if let name = visit?.photos?.first, let ui = library.image(name) {
            Button { showingPhotos = true } label: {
                Color.clear
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .overlay { Image(uiImage: ui).resizable().scaledToFill() }
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Session photo")
            .accessibilityIdentifier("done-photo")
            .overlay(alignment: .bottomTrailing) {
                IconMark(.hand("trophy"), size: 30, colour: colour)
                    .frame(width: 56, height: 56)
                    .background(Theme.card, in: Circle())
                    .overlay(Circle().stroke(colour.opacity(0.5), lineWidth: 1.5))
                    .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
                    .offset(x: 6, y: 10)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Trophy")
                    .accessibilityValue(value)
                    .accessibilityIdentifier("done-trophy")
            }
            .padding(.bottom, 10)
        } else {
            IconMark(.hand("trophy"), size: 56, colour: colour)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Trophy")
                .accessibilityValue(value)
                .accessibilityIdentifier("done-trophy")
        }
    }

    /// Warm-up (orange), machines (blue), stretching (green) as one capsule, with the minutes under it.
    private func timeBar(_ split: (warmup: Int, machines: Int, stretch: Int)) -> some View {
        let parts: [(String, Int, Color, String)] = [
            ("Warm-up", split.warmup, Self.warmOrange, "done-time-warmup"),
            ("Machines", split.machines, Gym.fill, "done-time-machines"),
            ("Stretching", split.stretch, Gym.done, "done-time-stretch"),
        ].filter { $0.1 > 0 }
        let total = max(1, parts.reduce(0) { $0 + $1.1 })
        return VStack(spacing: 6) {
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(parts.indices, id: \.self) { i in
                        Rectangle().fill(parts[i].2)
                            .frame(width: max(4, (geo.size.width - CGFloat(parts.count - 1) * 2) * CGFloat(parts[i].1) / CGFloat(total)))
                    }
                }
                .clipShape(Capsule())
            }
            .frame(height: 12)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Time split")
            .accessibilityValue(parts.map { "\($0.0) \($0.1) min" }.joined(separator: ", "))
            .accessibilityIdentifier("done-timebar")
            ForEach(parts.indices, id: \.self) { i in
                HStack(spacing: 6) {
                    Circle().fill(parts[i].2).frame(width: 8, height: 8)
                    Text(parts[i].0).font(.subheadline).foregroundStyle(Theme.ink)
                    Spacer()
                    Text("\(parts[i].1) min").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                        .accessibilityIdentifier(parts[i].3)
                }
            }
        }
    }

    /// "Sessions this week" with the count, this one included.
    private func weekTile(_ visit: GymVisit) -> some View {
        let n = library.gym.sessionsThisWeek(containing: visit.date, including: visit.id)
        return VStack(alignment: .leading, spacing: 0) {
            Text("Sessions this week").font(.caption.weight(.semibold)).foregroundStyle(Gym.done)
            Text("\(n)").font(.title2.weight(.bold)).monospacedDigit().foregroundStyle(Theme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Gym.done.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("done-week")
    }

    private func row(_ title: String, _ value: String, id: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).fontWeight(.semibold).accessibilityIdentifier(id)
        }
    }
}
