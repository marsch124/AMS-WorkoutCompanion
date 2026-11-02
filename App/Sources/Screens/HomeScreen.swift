import SwiftUI
import WorkoutCore

/// The list of workouts. Tap one to start it; the pencil edits it.
struct HomeScreen: View {
    @Environment(Library.self) private var library
    @State private var running: Workout?
    @State private var editing: Workout?
    @State private var adding = false
    @State private var deleting: Workout?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(library.workouts) { w in
                        WorkoutCard(workout: w, start: { running = w }, edit: { editing = w })
                            .contextMenu {
                                Button { editing = w } label: { Label("Edit", systemImage: "pencil") }
                                Button { library.duplicate(w) } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
                                Button(role: .destructive) { deleting = w } label: { Label("Delete", systemImage: "trash") }
                            }
                    }
                    if library.workouts.isEmpty {
                        EmptyHome { adding = true }
                    }
                }
                .padding(16)
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Workouts")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { adding = true } label: {
                        Image(systemName: "plus.circle.fill").font(.title2)
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
                HStack(spacing: 14) {
                    WorkoutTile(workout: workout)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(workout.name.isEmpty ? "Untitled" : workout.name)
                            .font(.system(.title3, design: .rounded, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(2)
                        Text(workout.summary)
                            .font(.subheadline)
                            .foregroundStyle(Theme.muted)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "play.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(workout.inkOnFill)
                        .frame(width: 44, height: 44)
                        .background(workout.fill, in: Circle())
                }
                .padding(.vertical, 14)
                .padding(.leading, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Start \(workout.name), \(workout.summary)")
            .accessibilityIdentifier("workout-\(workout.name)")

            Button(action: edit) {
                Image(systemName: "pencil")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.muted)
                    .frame(width: 48, height: 72)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit \(workout.name)")
            .accessibilityIdentifier("edit-\(workout.name)")
        }
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Theme.line, lineWidth: 1))
    }
}

private struct EmptyHome: View {
    let add: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.mixed.cardio")
                .font(.system(size: 56))
                .foregroundStyle(Theme.muted)
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
            VStack(spacing: 12) {
                ForEach(WorkoutKind.allCases, id: \.self) { kind in
                    NavigationLink(value: kind) {
                        HStack(spacing: 14) {
                            WorkoutTile(workout: Workout(kind: kind))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(kind.title)
                                    .font(.system(.title3, design: .rounded, weight: .semibold))
                                    .foregroundStyle(Theme.ink)
                                Text(kind.blurb)
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.muted)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").foregroundStyle(Theme.muted)
                        }
                        .padding(14)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Theme.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("new-\(kind.rawValue)")
                }
            }
            .padding(16)
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
