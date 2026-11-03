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
                        IconMark(.hand("pulse"), size: 48, colour: Past.tint)
                        Text("Every workout you finish — or end early — and every gym session is kept here, with your week in numbers.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.muted)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                } else {
                    chips
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

    private var stats: some View {
        let week = History.totals(items, in: History.period(.weekOfYear, around: Date()))
        let month = History.totals(items, in: History.period(.month, around: Date()))
        let streak = History.weekStreak(items, now: Date())
        let showKg = items.contains { $0.kg > 0 }
        return VStack(alignment: .leading, spacing: 6) {
            Text("This week")
                .font(.headline)
                .foregroundStyle(Past.tint)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                tile("Sessions", "\(week.sessions)", "plum", id: "history-week-sessions")
                tile("Minutes", "\(week.minutes)", "green", id: "history-week-minutes")
                if showKg { tile("Lifted", "\(GymSet.number(week.kg)) kg", "indigo", id: "history-week-kg") }
                tile("Weeks in a row", "\(streak)", "orange", id: "history-streak")
            }
            Text("This month: \(month.sessions) session\(month.sessions == 1 ? "" : "s") · \(month.minutes) min"
                 + (showKg ? " · \(GymSet.number(month.kg)) kg" : ""))
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .accessibilityIdentifier("history-month")
        }
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
        let weeks = History.weekly(items, weeks: 8, now: Date())
        return VStack(alignment: .leading, spacing: 6) {
            Text("Minutes per week")
                .font(.headline)
                .foregroundStyle(Past.tint)
                .padding(.top, 4)
            Chart(weeks, id: \.start) { w in
                BarMark(x: .value("Week", w.start, unit: .weekOfYear), y: .value("Minutes", w.minutes))
                    .foregroundStyle(Past.fill)
                    .cornerRadius(3)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .weekOfYear, count: 2)) { _ in
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                }
            }
            .frame(height: 110)
            .padding(10)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.line, lineWidth: 1))
            .accessibilityIdentifier("history-chart")
        }
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
