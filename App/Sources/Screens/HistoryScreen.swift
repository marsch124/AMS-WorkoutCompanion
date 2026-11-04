import AMSIcons
import Charts
import SwiftUI
import WorkoutCore

/// History's colour: plum for its headings, chart and marks.
enum Past {
    static let swatch = IconColour.of(key: "plum")!
    static var fill: Color { swatch.fillColor }
    static var ink: Color { swatch.inkColor }
    static let tint = Color.pair("#9c3d8c", "#e29bd6")

}

/// Every workout and gym visit, newest first, with this week and month in numbers.
struct HistoryScreen: View {
    @Environment(Library.self) private var library
    @State private var filter = "all"
    @State private var weekShows = "sessions"
    @State private var pickedWeek: Date?
    @State private var statsMonth = false

    private var all: [HistoryItem] { library.historyItems }
    private var items: [HistoryItem] { filter == "all" ? all : all.filter { $0.group == filter } }

    /// The chips: All, At the gym, then each workout that has been done, by name.
    private var groups: [(key: String, name: String)] {
        var seen: [(String, String)] = []
        for i in all where !seen.contains(where: { $0.0 == i.group }) {
            seen.append((i.group, i.group == History.gymGroup ? "At the gym" : i.name))
        }
        return [("all", "All")] + seen.sorted { a, b in a.0 == History.gymGroup || (b.0 != History.gymGroup && a.1 < b.1) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if all.isEmpty {
                    VStack(spacing: 10) {
                        AppMarkView(.history, size: 48, colour: Past.tint)
                        Text("Every workout you finish — or end early — and every gym session is kept here, with your week in numbers.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.muted)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                } else {
                    chips
                    shortcuts
                    stats
                    chart
                    list
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder private func page(_ source: HistoryItem.Source) -> some View {
        switch source {
        case .gym(let id): VisitScreen(visitID: id)
        case .workout(let id): RecordScreen(recordID: id)
        }
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(groups, id: \.key) { g in
                    let on = filter == g.key
                    let c = chipColour(g.key)
                    Button { filter = g.key } label: {
                        Text(g.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(on ? c.inkColor : c.fillColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(on ? AnyShapeStyle(c.fillColor) : AnyShapeStyle(c.fillColor.opacity(0.14)), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(on ? .isSelected : [])
                    .accessibilityIdentifier(g.key == "all" || g.key == History.gymGroup ? "history-filter-\(g.key)" : "history-filter-\(g.name)")
                }
            }
        }
    }

    /// Each chip in its own colour: plum for All, indigo for the gym, the workout's own colour.
    private func chipColour(_ key: String) -> IconColour {
        if key == "all" { return Past.swatch }
        if key == History.gymGroup { return Gym.swatch }
        return all.first { $0.group == key }.flatMap { IconColour.of(key: $0.colour) } ?? Past.swatch
    }

    // MARK: Statistics (since 1.9)

    private var period: DateInterval { History.period(statsMonth ? .month : .weekOfYear, around: Date()) }

    private var stats: some View {
        let o = Stats.overview(all, gym: library.gym, in: period)
        let key = statsMonth ? "month" : "week"
        return VStack(alignment: .leading, spacing: 6) {
            Text(statsMonth ? "This month" : "This week")
                .font(.headline)
                .foregroundStyle(Past.tint)
            Picker("Period", selection: $statsMonth) {
                Text("This week").tag(false)
                Text("This month").tag(true)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("stats-period")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                tile("Sessions", "\(o.sessions)", "plum", id: "history-\(key)-sessions")
                tile("Minutes", "\(o.minutes)", "green", id: "history-\(key)-minutes")
                tile("Exercises", "\(o.exercises)", "orange", id: "history-\(key)-exercises")
                tile("Sets", "\(o.sets)", "blue", id: "history-\(key)-sets")
                if o.kg > 0 { tile("Lifted", "\(GymSet.number(o.kg)) kg", "indigo", id: "history-\(key)-kg") }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(statsMonth ? "stats-month" : "stats-week")
            muscles
            balance
            warmup
            gamified
        }
    }

    private func card<Content: View>(_ title: String, colour: IconColour, id: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(colour.fillColor)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(colour.fillColor.opacity(0.5), lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(id)
    }

    private func bar(_ label: String, _ value: String, fraction: Double, colour: IconColour) -> some View {
        HStack(spacing: 8) {
            Text(label).font(.subheadline).foregroundStyle(Theme.ink).frame(width: 92, alignment: .leading).lineLimit(1)
            GeometryReader { geo in
                Capsule().fill(colour.fillColor.opacity(0.15))
                    .overlay(alignment: .leading) {
                        Capsule().fill(colour.fillColor).frame(width: max(8, geo.size.width * fraction))
                    }
            }
            .frame(height: 10)
            Text(value).font(.subheadline.weight(.semibold)).monospacedDigit().foregroundStyle(colour.fillColor)
                .frame(minWidth: 48, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
    }

    private var muscles: some View {
        let counts = Stats.muscles(library.gym, in: period)
        let top = Double(counts.map(\.sets).max() ?? 1)
        return card("Muscle groups", colour: IconColour.of(key: "red") ?? Past.swatch, id: "stats-muscle") {
            if counts.isEmpty {
                Text("No gym sets \(statsMonth ? "this month" : "this week") yet.").font(.subheadline).foregroundStyle(Theme.muted)
            }
            ForEach(counts, id: \.muscle?.id) { c in
                bar(c.muscle?.name ?? "Not chosen", "\(c.sets) set\(c.sets == 1 ? "" : "s")", fraction: Double(c.sets) / top,
                    colour: IconColour.of(key: c.muscle?.colour ?? "slate") ?? Past.swatch)
            }
            if counts.contains(where: { $0.muscle == nil }) {
                Text("Choose a muscle group in the machine's edit page.").font(.caption).foregroundStyle(Theme.muted)
            }
        }
    }

    // MARK: Muscle balance, records, notes (since 1.11)

    private var balance: some View {
        let rows = Stats.muscleWeeks(library.gym)
        let top = Double(rows.flatMap(\.weeks).max() ?? 1)
        return card("Muscle balance — last 4 weeks", colour: IconColour.of(key: "green") ?? Past.swatch, id: "stats-muscle-balance") {
            ForEach(rows, id: \.muscle?.id) { r in
                let c = IconColour.of(key: r.muscle?.colour ?? "slate") ?? Past.swatch
                HStack(spacing: 8) {
                    Text(r.muscle?.name ?? "Not chosen")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(c.fillColor)
                        .frame(width: 92, alignment: .leading).lineLimit(1)
                    if r.total == 0 {
                        Text("Not trained").font(.subheadline.weight(.semibold)).foregroundStyle(Gym.busyTint)
                        Spacer(minLength: 0)
                    } else {
                        HStack(alignment: .bottom, spacing: 4) {
                            ForEach(Array(r.weeks.enumerated()), id: \.offset) { _, n in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(n == 0 ? c.fillColor.opacity(0.15) : c.fillColor)
                                    .frame(width: 16, height: max(3, 22 * Double(n) / top))
                            }
                        }
                        .frame(height: 22, alignment: .bottom)
                        Spacer(minLength: 0)
                        Text("\(r.total) set\(r.total == 1 ? "" : "s")").font(.subheadline.weight(.semibold)).monospacedDigit().foregroundStyle(c.fillColor)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("muscle-balance-\(r.muscle?.id ?? "none")")
            }
        }
    }

    private var shortcuts: some View {
        VStack(spacing: 0) {
            NavigationLink { RecordsScreen() } label: { shortcut("trophy", "Records", "yellow") }
                .buttonStyle(.plain)
                .accessibilityIdentifier("open-records")
            Divider().padding(.leading, 52)
            NavigationLink { NotesSearchScreen() } label: { shortcut("notebook", "Search my notes", "blue") }
                .buttonStyle(.plain)
                .accessibilityIdentifier("open-notes-search")
        }
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.line, lineWidth: 1))
    }

    private func shortcut(_ icon: String, _ title: String, _ colour: String) -> some View {
        HStack(spacing: 10) {
            IconTile(.hand(icon), colour: IconColour.of(key: colour) ?? Past.swatch, fallbackTint: Theme.accent, letter: "R", size: 32)
            Text(title).font(.body.weight(.semibold)).foregroundStyle(Theme.ink)
            Spacer()
            ControlMarkView(.chevron, size: 14, colour: Theme.muted)
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .contentShape(Rectangle())
    }

    private var warmup: some View {
        let rows = Stats.cardio(library.gym, in: period)
        let top = Double(rows.map(\.minutes).max() ?? 1)
        return card("Warm-up and cardio", colour: IconColour.of(key: "violet") ?? Past.swatch, id: "stats-warmup") {
            if rows.isEmpty {
                Text("No time on a treadmill, rower or bike \(statsMonth ? "this month" : "this week") yet.").font(.subheadline).foregroundStyle(Theme.muted)
            }
            ForEach(rows, id: \.name) { r in
                bar(r.name, "\(r.minutes) min", fraction: Double(r.minutes) / top, colour: IconColour.of(key: "violet") ?? Past.swatch)
            }
        }
    }

    private static let badgeColour: [String: String] = [
        "first": "green", "sessions10": "blue", "sessions50": "plum", "streak4": "orange",
        "kg1000": "indigo", "pushups100": "red", "cardio60": "violet",
    ]

    private var gamified: some View {
        let streak = History.weekStreak(all, now: Date())
        let best = max(streak, Stats.bestStreak(all))
        let records = Stats.personalRecords(library.gym, in: History.period(.month, around: Date()))
        let badges = Stats.badges(all, gym: library.gym)
        let won = badges.filter(\.earned).count
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                tile("Weeks in a row", "\(streak)", "orange", id: "history-streak")
                tile("Best streak", "\(best)", "red", id: "stats-best")
                tile("Records this month", "\(records)", "yellow", id: "stats-records")
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("stats-streak")
            Text("Badges · \(won) of \(badges.count)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Past.tint)
                .padding(.top, 4)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(badges) { b in badgeView(b) }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("stats-badges")
        }
    }

    private func badgeView(_ b: Badge) -> some View {
        let c = IconColour.of(key: Self.badgeColour[b.id] ?? "plum") ?? Past.swatch
        return HStack(spacing: 8) {
            ZStack {
                Circle().fill(b.earned ? c.fillColor : Color.clear)
                Circle().stroke(b.earned ? c.fillColor : Theme.line, lineWidth: 1.5)
                IconMark(.hand(b.icon), size: 20, colour: b.earned ? c.inkColor : Theme.muted.opacity(0.6))
            }
            .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 1) {
                Text(b.title).font(.subheadline.weight(.semibold)).foregroundStyle(b.earned ? c.fillColor : Theme.muted)
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                Text(b.earned ? "Earned" : b.hint).font(.caption).foregroundStyle(Theme.muted)
                    .lineLimit(3).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(b.earned ? c.fillColor.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(b.earned ? c.fillColor.opacity(0.5) : Theme.line, lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(b.title), \(b.earned ? "earned" : "locked. " + b.hint)")
        .accessibilityIdentifier("stats-badge-\(b.id)")
    }

    private func tile(_ title: String, _ value: String, _ colour: String, id: String) -> some View {
        let c = IconColour.of(key: colour) ?? Past.swatch
        return VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(c.inkColor.opacity(0.85))
            Text(value)
                .font(.title2.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(c.inkColor)
                .accessibilityIdentifier(id)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(c.fillColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var chart: some View {
        let weeks = History.weekly(items, weeks: 12, now: Date())
        let thisWeek = weeks.last?.start
        let showMinutes = weekShows == "minutes"
        let picked = weeks.first { $0.start == pickedWeek }?.start
        return VStack(alignment: .leading, spacing: 6) {
            Text(showMinutes ? "Minutes per week" : "Sessions per week")
                .font(.headline)
                .foregroundStyle(Past.tint)
                .padding(.top, 4)
            Picker("Show", selection: $weekShows) {
                Text("Sessions").tag("sessions")
                Text("Minutes").tag("minutes")
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("history-week-switch")
            Chart(weeks, id: \.start) { w in
                BarMark(x: .value("Week", w.start, unit: .weekOfYear),
                        y: .value(showMinutes ? "Minutes" : "Sessions", showMinutes ? w.minutes : w.sessions))
                    .foregroundStyle(Past.fill.opacity(w.start == thisWeek || w.start == picked ? 1 : 0.4))
                    .cornerRadius(3)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .weekOfYear, count: 2)) { _ in
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .onTapGesture { location in
                            guard let plot = proxy.plotFrame else { return }
                            let x = location.x - geo[plot].origin.x
                            if let date: Date = proxy.value(atX: x),
                               let hit = weeks.first(where: { $0.start <= date && date < ($0.start.addingTimeInterval(7 * 86_400)) }) {
                                pickedWeek = hit.start == pickedWeek ? nil : hit.start
                            }
                        }
                }
            }
            .frame(height: 110)
            .padding(10)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.line, lineWidth: 1))
            .accessibilityIdentifier("history-chart")
            if let start = picked { weekDetail(start) }
        }
    }

    private func weekDetail(_ start: Date) -> some View {
        let found = History.sessions(items, weekStarting: start)
        return VStack(alignment: .leading, spacing: 4) {
            Text("Week of \(start.formatted(.dateTime.day().month(.abbreviated)))")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Past.tint)
            if found.isEmpty {
                Text("Nothing that week.").font(.subheadline).foregroundStyle(Theme.muted)
            }
            ForEach(found) { item in
                HStack {
                    Text(item.heading).font(.subheadline).foregroundStyle(Theme.ink).lineLimit(1)
                    Spacer()
                    Text(item.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                        .font(.caption).foregroundStyle(Theme.muted)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Past.fill.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("history-week-detail")
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Sessions")
                .font(.headline)
                .foregroundStyle(Past.tint)
                .padding(.top, 4)
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                    // The page goes with the row: a looked-up destination showed a warning triangle on the iPhone (1.4).
                    NavigationLink { page(item.source) } label: { row(item) }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(item.heading), \(item.detail), \(item.date.formatted(date: .abbreviated, time: .omitted))")
                        .accessibilityAddTraits(.isButton)
                        .accessibilityIdentifier("history-row-\(i + 1)")
                    if i < items.count - 1 { Divider().padding(.leading, 52) }
                }
            }
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.line, lineWidth: 1))
        }
    }

    private func row(_ item: HistoryItem) -> some View {
        HStack(spacing: 10) {
            IconTile(.hand(item.icon),
                     colour: IconColour.of(key: item.colour) ?? Past.swatch, fallbackTint: Theme.accent, letter: "W", size: 32)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.heading)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text(item.detail)
                    .font(.subheadline)
                    .foregroundStyle(item.completed ? Theme.muted : Gym.busyTint)
                    .lineLimit(1)
                Text(item.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
                     + (item.minutes.map { " · \($0) min" } ?? "")
                     + (item.title != nil ? " · \(item.name)" : ""))
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
            Spacer()
            ControlMarkView(.chevron, size: 14, colour: Theme.muted)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .contentShape(Rectangle())
    }
}

/// One Sets & reps, Interval or Exercise-list workout done: what, when, and its title and notes.
struct RecordScreen: View {
    @Environment(Library.self) private var library
    @Environment(\.dismiss) private var dismiss
    let recordID: UUID
    @State private var editing = false
    @State private var askDelete = false

    var body: some View {
        let r = library.history.first { $0.id == recordID }
        List {
            if let r {
                Section {
                    if let t = r.title {
                        Text(t).font(.headline).foregroundStyle(Past.tint).accessibilityIdentifier("record-title")
                    }
                    if let n = r.notes { Text(n).font(.subheadline) }
                    row("Workout", r.name)
                    row("Done", r.completed ? r.detail : r.detail + " (ended early)")
                    row("Started", r.started.formatted(date: .abbreviated, time: .shortened))
                    row("Time", "\(r.minutes) min")
                }
                Section {
                    Button("Delete from History", role: .destructive) { askDelete = true }
                        .accessibilityIdentifier("record-delete")
                }
            }
        }
        .navigationTitle(r?.started.formatted(date: .abbreviated, time: .omitted) ?? "Workout")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { editing = true } label: { ControlMarkView(.edit, size: 22, colour: Past.tint) }
                    .accessibilityLabel("Title and notes")
                    .accessibilityIdentifier("record-edit")
            }
        }
        .sheet(isPresented: $editing) {
            if let r {
                NavigationStack {
                    NotesForm(placeholder: r.name, title: r.title ?? "", notes: r.notes ?? "", colour: Past.fill) { result in
                        editing = false
                        if let result { library.describe(record: recordID, title: result.title, notes: result.notes) }
                    }
                }
            }
        }
        .confirmationDialog("Delete this workout from History?", isPresented: $askDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                dismiss()
                library.deleteRecord(recordID)
            }
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(Theme.muted)
            Spacer()
            Text(value).multilineTextAlignment(.trailing)
        }
    }
}
