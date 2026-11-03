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

/// The card under "At the gym" that opens History.
struct HistoryCard: View {
    @Environment(Library.self) private var library
    let open: () -> Void

    private var summary: String {
        let items = library.historyItems
        guard !items.isEmpty else { return "Every workout you do is kept here" }
        let t = History.totals(items, in: History.period(.weekOfYear, around: Date()))
        return "This week: \(t.sessions) session\(t.sessions == 1 ? "" : "s") · \(t.minutes) min"
    }

    var body: some View {
        Button(action: open) {
            HStack(spacing: 12) {
                IconTile(.hand("pulse"), colour: Past.swatch, fallbackTint: Theme.accent, letter: "H", size: 44)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("History")
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                ControlMarkView(.chevron, size: 16, colour: Past.tint)
                    .padding(.trailing, 6)
            }
            .padding(.vertical, 8)
            .padding(.leading, 10)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Past.fill.opacity(0.5), lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("History, \(summary)")
        .accessibilityIdentifier("open-history")
    }
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
        .navigationDestination(for: HistoryItem.Source.self) { source in
            switch source {
            case .gym(let id): VisitScreen(visitID: id)
            case .workout(let id): RecordScreen(recordID: id)
            }
        }
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(groups, id: \.key) { g in
                    let on = filter == g.key
                    Button { filter = g.key } label: {
                        Text(g.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(on ? Past.ink : Past.tint)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(on ? AnyShapeStyle(Past.fill) : AnyShapeStyle(Past.fill.opacity(0.1)), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(on ? .isSelected : [])
                    .accessibilityIdentifier(g.key == "all" || g.key == History.gymGroup ? "history-filter-\(g.key)" : "history-filter-\(g.name)")
                }
            }
        }
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
                tile("Sessions", "\(week.sessions)", id: "history-week-sessions")
                tile("Minutes", "\(week.minutes)", id: "history-week-minutes")
                if showKg { tile("Lifted", "\(GymSet.number(week.kg)) kg", id: "history-week-kg") }
                tile("Weeks in a row", "\(streak)", id: "history-streak")
            }
            Text("This month: \(month.sessions) session\(month.sessions == 1 ? "" : "s") · \(month.minutes) min"
                 + (showKg ? " · \(GymSet.number(month.kg)) kg" : ""))
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .accessibilityIdentifier("history-month")
        }
    }

    private func tile(_ title: String, _ value: String, id: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(Theme.muted)
            Text(value)
                .font(.title2.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
                .accessibilityIdentifier(id)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.line, lineWidth: 1))
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
                    NavigationLink(value: item.source) { row(item) }
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
