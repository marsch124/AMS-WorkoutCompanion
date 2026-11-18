import AMSIcons
import SwiftUI
import WorkoutCore

/// The workout's plan, to read only (since 1.28, his ask): a tap on a workout's panel shows this page.
/// Nothing starts here and nothing can be changed — the pen edits, the play button starts.
struct WorkoutPlanScreen: View {
    @Environment(Library.self) private var library
    let workout: Workout
    let done: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                head
                if workout.kind == .checklist {
                    exercises
                } else {
                    lines
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle("Plan")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("plan-screen")
        .bottomActions(cancel: nil, save: done, saveTitle: "Done", tint: workout.fill, saveID: "plan-done")
        // Escape on the Mac closes the page.
        .background {
            Button("Close", action: done)
                .keyboardShortcut(.cancelAction)
                .opacity(0)
                .accessibilityHidden(true)
        }
    }

    /// The workout's icon, name and kind, on its own colour.
    private var head: some View {
        HStack(spacing: 12) {
            IconMark(.hand(workout.shownIcon), size: 42, colour: workout.inkOnFill)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(workout.name.isEmpty ? "Untitled" : workout.name)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(workout.inkOnFill)
                    .accessibilityIdentifier("plan-name")
                Text(workout.kind.title)
                    .font(.subheadline)
                    .foregroundStyle(workout.inkOnFill.opacity(0.85))
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(workout.fill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    /// Sets & reps and Interval timer: label on the left, number on the right.
    private var lines: some View {
        VStack(spacing: 0) {
            ForEach(Array(workout.plan.enumerated()), id: \.offset) { n, line in
                if n > 0 { Divider().overlay(Theme.line) }
                HStack {
                    Text(line.label)
                        .font(.body)
                        .foregroundStyle(Theme.ink)
                    Spacer(minLength: 8)
                    Text(line.value)
                        .font(.system(.title3, design: .rounded).weight(.bold).monospacedDigit())
                        .foregroundStyle(Theme.ink)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("plan-line-\(n + 1)")
            }
        }
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    /// Exercise list: every exercise in order, with its amount, note and photo.
    @ViewBuilder private var exercises: some View {
        if workout.exercises.isEmpty {
            Text("No exercises yet")
                .font(.body)
                .foregroundStyle(Theme.muted)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .accessibilityIdentifier("plan-empty")
        } else {
            ForEach(Array(workout.exercises.enumerated()), id: \.element.id) { n, e in
                VStack(alignment: .leading, spacing: 0) {
                    if let image = library.image(e.photo) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 150)
                            .frame(maxWidth: .infinity)
                            .clipped()
                            .accessibilityHidden(true)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("\(n + 1)")
                            .font(.system(.headline, design: .rounded).monospacedDigit())
                            .foregroundStyle(workout.inkOnFill)
                            .frame(width: 26, height: 26)
                            .background(workout.fill, in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(e.name.isEmpty ? "Exercise \(n + 1)" : e.name)
                                .font(.headline)
                                .foregroundStyle(Theme.ink)
                            if !e.amount.isEmpty {
                                Text(e.amount)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.ink)
                            }
                            if !e.note.isEmpty {
                                Text(e.note)
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.muted)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("plan-exercise-\(n + 1)")
            }
        }
    }
}
