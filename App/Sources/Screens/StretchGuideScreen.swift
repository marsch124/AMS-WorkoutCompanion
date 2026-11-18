import AMSIcons
import SwiftUI
import WorkoutCore

/// One row in the stretch-list chooser: the name and what it is for (since 1.30).
struct StretchChoiceRow: View {
    let name: String
    let line: String
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(name)
            Text(line).font(.caption).foregroundStyle(Theme.muted)
        }
    }
}

/// How to do each stretch of a list, step by step (since 1.30, his ask: a guide for the after-gym stretch).
/// Stretches the app knows get their steps, where you feel it and what to watch; his own just their note.
struct StretchGuideScreen: View {
    let workout: Workout
    var body: some View {
        List {
            Section {
                Text("Hold each stretch still — no bouncing. Go to a gentle pull, never pain, and breathe slowly. Do both sides where it says each side.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
            }
            ForEach(Array(workout.exercises.enumerated()), id: \.element.id) { i, e in
                let move = StretchRoutine.move(named: e.name)
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("\(i + 1)")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Gym.ink)
                                .frame(width: 24, height: 24)
                                .background(Gym.fill, in: Circle())
                            Text(e.name).font(.headline).foregroundStyle(Theme.ink)
                            Spacer()
                            if !e.amount.isEmpty {
                                Text(e.amount).font(.subheadline.weight(.semibold)).foregroundStyle(Gym.tint)
                            }
                        }
                        if let move {
                            ForEach(Array(move.steps.enumerated()), id: \.offset) { n, step in
                                HStack(alignment: .firstTextBaseline, spacing: 6) {
                                    Text("\(n + 1).").font(.subheadline.weight(.semibold)).foregroundStyle(Gym.tint)
                                        .frame(width: 18, alignment: .trailing)
                                    Text(step).font(.subheadline)
                                }
                            }
                            guideLine("Where you feel it", move.feel, colour: SessionGoingLine.green)
                            guideLine("Careful", move.careful, colour: Gym.busyTint)
                        } else if !e.note.isEmpty {
                            Text(e.note).font(.subheadline)
                        }
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("stretch-guide-\(i + 1)")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle(workout.name.isEmpty ? "Stretch guide" : workout.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func guideLine(_ title: String, _ text: String, colour: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(colour)
            Text(text).font(.subheadline)
        }
    }
}
