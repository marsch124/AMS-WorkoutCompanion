import AMSIcons
import SwiftUI
import WorkoutCore

/// The three tabs: Train, History, Settings — each keeps its place while another is shown.
struct RootView: View {
    @Environment(Library.self) private var library
    enum Tab { case train, history, settings }
    @State private var tab = Tab.train

    @State private var typing = false

    var body: some View {
        // The pages end above the tab bar (1.9.1): as a safe-area inset the bar covered the bottom of
        // pushed pages — "Exercise done" and the last History session sat underneath it on his iPhone.
        VStack(spacing: 0) {
            ZStack {
                // Train stays alive underneath, so the gym keeps its place; History and Settings sit on top
                // only while chosen — a hidden page with its own navigation above caught every tap (1.5 test).
                HomeScreen()
                    .opacity(tab == .train ? 1 : 0)
                    .allowsHitTesting(tab == .train)
                    .accessibilityHidden(tab != .train)
                if tab == .history { NavigationStack { HistoryScreen().noSwipeBack() } }
                if tab == .settings { NavigationStack { SettingsScreen().noSwipeBack() } }
            }
            .frame(maxHeight: .infinity)
            // While typing, the keyboard takes the bar's place.
            if !typing { bar }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in typing = true }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in typing = false }
        .overlay(alignment: .bottom) {
            if let point = library.undoPoint {
                UndoBar(point: point)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 64)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: library.undoPoint?.id)
    }

    private var bar: some View {
        HStack(spacing: 0) {
            item(.train, "Workouts", id: "open-train", colour: Theme.accent) { c in IconMark(.hand("kettlebell"), size: 24, colour: c) }
            item(.history, "History", id: "open-history", colour: Past.tint) { c in AppMarkView(.history, size: 24, colour: c) }
            item(.settings, "Settings", id: "open-settings", colour: Theme.accent) { c in ControlMarkView(.settings, size: 24, colour: c) }
        }
        // Since 1.26: a rounded capsule, the chosen tab in a pale pill of its colour. Pages still end above it.
        .padding(4)
        .background(Theme.card, in: Capsule())
        .overlay(Capsule().stroke(Theme.line, lineWidth: 1))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        .padding(.horizontal, 36)
        .padding(.top, 6)
        .padding(.bottom, 2)
        .frame(maxWidth: .infinity)
        .background(Theme.bg.ignoresSafeArea(edges: .bottom))
    }

    private func item<M: View>(_ t: Tab, _ title: String, id: String, colour: Color,
                               @ViewBuilder mark: (Color) -> M) -> some View {
        let on = tab == t
        return Button { tab = t } label: {
            VStack(spacing: 2) {
                mark(on ? colour : Theme.muted)
                Text(title).font(.caption2.weight(on ? .semibold : .regular))
                    .foregroundStyle(on ? colour : Theme.muted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .background(on ? colour.opacity(0.14) : .clear, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(on ? .isSelected : [])
        .accessibilityIdentifier(id)
    }
}

/// Train: the gym as a wide tile, then the workouts in two columns. Tap one to start it; the pencil edits it.
struct HomeScreen: View {
    @Environment(Library.self) private var library
    @State private var running: Workout?
    @State private var editing: Workout?
    @State private var showing: Workout?
    @State private var adding = false
    @State private var deleting: Workout?
    @State private var showGym = false
    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    if let words = library.unreadableNote { UnreadableNote(words: words) }
                    if library.backupReminderDue { BackupReminder() }
                    GymCard { showGym = true }
                    // A gym session is going today (since 1.18, his ask): the same green line as on the gym screen.
                    // Since 1.20 from the moment the gym screen opened today, before any set.
                    if let start = library.gym.sessionStart(on: Date(), gym: library.gym.currentGym?.id) {
                        Button { showGym = true } label: {
                            SessionGoingLine(start: start, visit: library.gym.openVisit(on: Date(), gym: library.gym.currentGym?.id),
                                             identifier: "home-session-going")
                        }
                        .buttonStyle(.plain)
                    }
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(library.workouts) { w in
                            WorkoutCard(workout: w, show: { showing = w }, start: { running = w }, edit: { editing = w })
                                .contextMenu {
                                    Button("Edit") { editing = w }
                                    Button("Duplicate") { library.duplicate(w) }
                                    Button("Delete", role: .destructive) { deleting = w }
                                }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                // Room under the last panel for the round + at the bottom right.
                .padding(.bottom, 84)
            }
            .background(Theme.bg.ignoresSafeArea())
            // New workout: one round + at the bottom right, in reach of the thumb (since 1.28, his picture).
            // Before, a + at the top right (it cut into the heading) and a dashed "New workout" tile.
            .overlay(alignment: .bottomTrailing) {
                Button { adding = true } label: {
                    ControlMarkView(.add, size: 26, colour: .white)
                        .frame(width: 56, height: 56)
                        .background(Theme.accent, in: Circle())
                        .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(.trailing, 16)
                .padding(.bottom, 14)
                .accessibilityLabel("New workout")
                .accessibilityIdentifier("add-workout")
            }
            .navigationTitle("Workout Companion")
            .navigationDestination(isPresented: $showGym) { GymScreen() }
            // The screen stays on (and sounds can play) while at the gym.
            .onChange(of: showGym) { _, on in on ? Cues.shared.begin() : Cues.shared.end() }
        }
        .sheet(item: $editing) { w in
            NavigationStack {
                EditorScreen(workout: w, isNew: false) { editing = nil }
            }
            .environment(library)
        }
        // A tap on a workout's panel only shows its plan (since 1.28, his ask).
        .sheet(item: $showing) { w in
            NavigationStack {
                WorkoutPlanScreen(workout: w) { showing = nil }
            }
            .environment(library)
        }
        .sheet(isPresented: $adding) {
            NavigationStack {
                KindPicker { adding = false }
            }
            .environment(library)
        }
        .fullScreenCover(item: $running) { w in
            Group {
                if w.kind == .checklist {
                    ChecklistScreen(workout: w) { running = nil }
                } else {
                    TimerScreen(workout: w) { running = nil }
                }
            }
            .environment(library)
        }
        .confirmationDialog("Delete \(deleting?.name ?? "")?", isPresented: Binding(
            get: { deleting != nil }, set: { if !$0 { deleting = nil } }
        ), titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let d = deleting { library.delete(d) }
                deleting = nil
            }
        }
    }
}

/// A workout in the grid: full colour, its hand-drawn icon, name and summary, a play mark; the pencil edits.
/// One workout's panel. Since 1.28 (his ask) it has three separate taps: the panel shows the plan,
/// the pen edits, the round play button starts. The icon, the pen and the play button are larger.
private struct WorkoutCard: View {
    let workout: Workout
    let show: () -> Void
    let start: () -> Void
    let edit: () -> Void

    var body: some View {
        Button(action: show) {
            VStack(alignment: .leading, spacing: 4) {
                IconMark(.hand(workout.shownIcon), size: 42, colour: workout.inkOnFill)
                    .accessibilityHidden(true)
                Spacer(minLength: 6)
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.name.isEmpty ? "Untitled" : workout.name)
                        .font(.headline)
                        .foregroundStyle(workout.inkOnFill)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(workout.summary)
                        .font(.caption)
                        .foregroundStyle(workout.inkOnFill.opacity(0.85))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                // Room for the play button at the bottom right: the name and the summary never run under it.
                .padding(.trailing, 48)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 148, alignment: .topLeading)
            .background(workout.fill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(workout.name), \(workout.summary)")
        .accessibilityIdentifier("workout-\(workout.name)")
        .overlay(alignment: .topTrailing) {
            Button(action: edit) {
                ControlMarkView(.edit, size: 24, colour: workout.inkOnFill)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(4)
            .accessibilityLabel("Edit \(workout.name)")
            .accessibilityIdentifier("edit-\(workout.name)")
        }
        .overlay(alignment: .bottomTrailing) {
            Button(action: start) {
                ControlMarkView(.play, size: 20, colour: workout.fill)
                    .frame(width: 44, height: 44)
                    .background(workout.inkOnFill, in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(10)
            .accessibilityLabel("Start \(workout.name)")
            .accessibilityIdentifier("start-\(workout.name)")
        }
    }
}

/// Step one of a new workout: which kind.
struct KindPicker: View {
    let done: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(WorkoutKind.allCases, id: \.self) { kind in
                    NavigationLink(value: kind) {
                        HStack(spacing: 12) {
                            WorkoutTile(workout: Workout(kind: kind))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(kind.title)
                                    .font(.headline)
                                    .foregroundStyle(Theme.ink)
                                Text(kind.blurb)
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.muted)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer(minLength: 0)
                            ControlMarkView(.chevron, size: 16, colour: Theme.muted)
                        }
                        .padding(10)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("new-\(kind.rawValue)")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle("New workout")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: done)
                    .accessibilityIdentifier("new-cancel")
            }
        }
        .navigationDestination(for: WorkoutKind.self) { kind in
            EditorScreen(workout: Workout(kind: kind), isNew: true, onDone: done)
        }
    }
}

/// "Chest press deleted — Undo", for 10 seconds after any delete (since 1.8).
private struct UndoBar: View {
    @Environment(Library.self) private var library
    let point: Library.UndoPoint

    var body: some View {
        HStack(spacing: 10) {
            Text(point.label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .accessibilityIdentifier("undo-bar")
            Spacer(minLength: 8)
            Button("Undo") { library.undo() }
                .font(.subheadline.weight(.bold))
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .tint(Theme.accent)
                .accessibilityIdentifier("undo-button")
        }
        .padding(.leading, 14)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .background(Color(white: 0.16), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.18), lineWidth: 1))
        .task(id: point.id) {
            try? await Task.sleep(for: .seconds(10))
            if !Task.isCancelled { library.forgetUndo(point.id) }
        }
    }
}

/// A file could not be read (since 1.21): a red note at the top of Train, with the way to Backups.
private struct UnreadableNote: View {
    let words: String
    private static let colour = IconColour.of(key: "red")!

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(words)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .accessibilityIdentifier("unreadable-note")
                Text("Nothing is saved over them. Restore a backup to get them back.")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            NavigationLink { BackupScreen() } label: {
                Text("Backups")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Self.colour.inkColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Self.colour.fillColor, in: Capsule())
            }
            .accessibilityIdentifier("unreadable-backups")
        }
        .padding(10)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Self.colour.fillColor, lineWidth: 1.5))
    }
}

/// After 14 days without a backup: a short note at the top of Train (since 1.8).
private struct BackupReminder: View {
    @Environment(Library.self) private var library
    private static let colour = IconColour.of(key: "navy")!

    var body: some View {
        HStack(spacing: 10) {
            IconMark(.hand("box"), size: 22, colour: Self.colour.fillColor)
            Text(library.lastBackup == nil ? "No backup yet." : "No backup for 2 weeks.")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.ink)
                .accessibilityIdentifier("backup-reminder")
            Spacer(minLength: 4)
            Button("Later") { library.backupReminderLater() }
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .accessibilityIdentifier("backup-reminder-later")
            NavigationLink { BackupScreen() } label: {
                Text("Back up")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Self.colour.inkColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Self.colour.fillColor, in: Capsule())
            }
            .accessibilityIdentifier("backup-reminder-open")
        }
        .padding(10)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Self.colour.fillColor.opacity(0.5), lineWidth: 1))
    }
}
