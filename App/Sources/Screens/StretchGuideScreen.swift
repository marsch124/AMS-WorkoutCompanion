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
/// Since 2.0 each stretch has its drawn figure on top, and the whole library has a guide too
/// (`StretchGuideScreen(libraryIDs:)`). Stretches the app knows get their steps, where you feel it and
/// what to watch; his own just their note.
struct StretchGuideScreen: View {
    struct Entry: Identifiable {
        let id: Int
        let name: String
        let amount: String
        let figure: String?
        let note: String
        let steps: [String]
        let feel: String?
        let careful: String?
    }

    let title: String
    let entries: [Entry]

    init(workout: Workout) {
        title = workout.name.isEmpty ? "Stretch guide" : workout.name
        entries = workout.exercises.enumerated().map { i, e in
            let move = StretchRoutine.move(named: e.name)
            let lib = StretchLibrary.alias(for: e.name)
            return Entry(id: i, name: e.name, amount: e.amount, figure: lib, note: e.note,
                         steps: move?.steps ?? [], feel: move?.feel, careful: move?.careful)
        }
    }

    /// The guide for library stretches and warm-up moves (all of them when no ids are given).
    init(libraryIDs: [String]? = nil, title: String = "Stretch guide") {
        self.title = title
        let items = libraryIDs.map { ids in ids.compactMap(StretchLibrary.item) } ?? StretchLibrary.all
        entries = items.enumerated().map { i, item in
            let g = StretchLibrary.guide(item.id)
            return Entry(id: i, name: item.name, amount: "\(item.seconds) s" + (item.sides == 2 ? " each side" : ""),
                         figure: item.id, note: g?.note ?? "", steps: g?.steps ?? [], feel: g?.feel, careful: g?.careful)
        }
    }

    var body: some View {
        List {
            Section {
                Text("Hold each stretch still — no bouncing. Go to a gentle pull, never pain, and breathe slowly. Do both sides where it says each side.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
            }
            ForEach(entries) { e in
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        if let fig = e.figure {
                            FigureView(id: fig, size: 120)
                                .frame(maxWidth: .infinity)
                                .accessibilityIdentifier("stretch-guide-figure-\(e.id + 1)")
                        }
                        HStack(alignment: .firstTextBaseline) {
                            Text("\(e.id + 1)")
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
                        if !e.steps.isEmpty {
                            ForEach(Array(e.steps.enumerated()), id: \.offset) { n, step in
                                HStack(alignment: .firstTextBaseline, spacing: 6) {
                                    Text("\(n + 1).").font(.subheadline.weight(.semibold)).foregroundStyle(Gym.tint)
                                        .frame(width: 18, alignment: .trailing)
                                    Text(step).font(.subheadline)
                                }
                            }
                            if let feel = e.feel { guideLine("Where you feel it", feel, colour: SessionGoingLine.green) }
                            if let careful = e.careful { guideLine("Careful", careful, colour: Gym.busyTint) }
                        } else if !e.note.isEmpty {
                            Text(e.note).font(.subheadline)
                        }
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("stretch-guide-\(e.id + 1)")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .readableWidth(680)
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func guideLine(_ title: String, _ text: String, colour: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(colour)
            Text(text).font(.subheadline)
        }
    }
}
