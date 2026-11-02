import AMSIcons
import SwiftUI
import WorkoutCore

/// The list of workouts. Tap one to start it; the pencil edits it.
struct HomeScreen: View {
    @Environment(Library.self) private var library
    @State private var running: Workout?
    @State private var editing: Workout?
    @State private var adding = false
    @State private var deleting: Workout?
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(library.workouts) { w in
                        WorkoutCard(workout: w, start: { running = w }, edit: { editing = w })
                            .contextMenu {
                                Button("Edit") { editing = w }
                                Button("Duplicate") { library.duplicate(w) }
                                Button("Delete", role: .destructive) { deleting = w }
                            }
                    }
                    if library.workouts.isEmpty {
                        EmptyHome { adding = true }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Workouts")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: { Mark(Marks.gear, size: 24, colour: Theme.accent) }
                        .accessibilityLabel("Settings")
                        .accessibilityIdentifier("open-settings")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { adding = true } label: {
                        Mark(Marks.plusAdd, size: 26, colour: Theme.accent)
                    }
                    .accessibilityLabel("New workout")
                    .accessibilityIdentifier("add-workout")
                }
            }
        }
        .sheet(item: $editing) { w in
            NavigationStack {
                EditorScreen(workout: w, isNew: false) { editing = nil }
            }
            .environment(library)
        }
        .sheet(isPresented: $adding) {
            NavigationStack {
                KindPicker { adding = false }
            }
            .environment(library)
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack { SettingsScreen { showSettings = false } }
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

private struct WorkoutCard: View {
    let workout: Workout
    let start: () -> Void
    let edit: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: start) {
                HStack(spacing: 12) {
                    WorkoutTile(workout: workout)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(workout.name.isEmpty ? "Untitled" : workout.name)
                            .font(.headline)
                            .foregroundStyle(Theme.ink)
                            .lineLimit(2)
                        Text(workout.summary)
                            .font(.subheadline)
                            .foregroundStyle(Theme.muted)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    Mark(Marks.play, size: 18, colour: workout.inkOnFill)
                        .frame(width: 38, height: 38)
                        .background(workout.fill, in: Circle())
                }
                .padding(.vertical, 8)
                .padding(.leading, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Start \(workout.name), \(workout.summary)")
            .accessibilityIdentifier("workout-\(workout.name)")

            Button(action: edit) {
                Mark(Marks.pencil, size: 20, colour: Theme.muted)
                    .frame(width: 44, height: 54)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit \(workout.name)")
            .accessibilityIdentifier("edit-\(workout.name)")
        }
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.line, lineWidth: 1))
    }
}

private struct EmptyHome: View {
    let add: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            IconMark(.hand("run"), size: 48, colour: Theme.muted)
            Text("No workouts yet")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.ink)
            Button("New workout", action: add)
                .buttonStyle(BigButtonStyle(fill: Theme.accent, ink: .white, height: 52))
                .frame(maxWidth: 260)
        }
        .padding(.top, 80)
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
                            Mark(Marks.chevron, size: 16, colour: Theme.muted)
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
            ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: done) }
        }
        .navigationDestination(for: WorkoutKind.self) { kind in
            EditorScreen(workout: Workout(kind: kind), isNew: true, onDone: done)
        }
    }
}
