import PhotosUI
import SwiftUI
import WorkoutCore

/// Create or change a workout. Nothing is stored until Save.
struct EditorScreen: View {
    @Environment(Library.self) private var library
    @State private var draft: Workout
    let isNew: Bool
    let onDone: () -> Void
    @State private var askDelete = false

    init(workout: Workout, isNew: Bool, onDone: @escaping () -> Void) {
        _draft = State(initialValue: workout)
        self.isNew = isNew
        self.onDone = onDone
    }

    private var canSave: Bool { !draft.name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        Form {
            Section("Name") {
                TextField(placeholder, text: $draft.name)
                    .font(.title3.weight(.semibold))
                    .accessibilityIdentifier("editor-name")
            }

            Section("Colour") {
                SwatchGrid(selected: $draft.colour)
            }

            Section("Type") {
                Picker("Type", selection: $draft.kind) {
                    Text("Sets").tag(WorkoutKind.reps)
                    Text("List").tag(WorkoutKind.checklist)
                    Text("Intervals").tag(WorkoutKind.intervals)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("editor-kind")
            }

            switch draft.kind {
            case .reps:
                Section("Sets & reps") {
                    NumberRow(title: "Sets", value: $draft.sets, range: 1...50, step: 1, id: "editor-sets")
                    NumberRow(title: "Reps per set", value: $draft.reps, range: 1...500, step: 1, id: "editor-reps")
                    NumberRow(title: "Rest between sets", value: $draft.restSeconds, range: 0...600, step: 15, isTime: true, id: "editor-rest")
                }
            case .intervals:
                Section {
                    NumberRow(title: "Rounds", value: $draft.rounds, range: 1...99, step: 1, id: "editor-rounds")
                    NumberRow(title: "Work", value: $draft.workSeconds, range: 5...900, step: 5, isTime: true, id: "editor-work")
                    NumberRow(title: "Rest", value: $draft.offSeconds, range: 0...900, step: 5, isTime: true, id: "editor-off")
                } header: {
                    Text("Intervals")
                } footer: {
                    Text("Total \(Clock.text(draft.intervalTotal)), after a 5-second get ready.")
                }
            case .checklist:
                ForEach($draft.exercises) { $exercise in
                    let n = (draft.exercises.firstIndex { $0.id == exercise.id } ?? 0) + 1
                    Section {
                        ExerciseFields(exercise: $exercise, number: n)
                    } header: {
                        ExerciseHeader(number: n, count: draft.exercises.count,
                                       up: { move(exercise.id, by: -1) },
                                       down: { move(exercise.id, by: 1) },
                                       remove: { draft.exercises.removeAll { $0.id == exercise.id } })
                    }
                }
                Section {
                    Button {
                        withAnimation { draft.exercises.append(Exercise()) }
                    } label: {
                        Label("Add exercise", systemImage: "plus.circle.fill")
                            .font(.body.weight(.semibold))
                    }
                    .accessibilityIdentifier("editor-add-exercise")
                }
            }

            if !isNew {
                Section {
                    Button("Delete workout", role: .destructive) { askDelete = true }
                        .accessibilityIdentifier("editor-delete")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle(isNew ? draft.kind.title : "Edit workout")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isNew {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: onDone) }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    library.save(draft)
                    onDone()
                }
                .fontWeight(.bold)
                .disabled(!canSave)
                .accessibilityIdentifier("editor-save")
            }
        }
        .confirmationDialog("Delete \(draft.name)?", isPresented: $askDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                library.delete(draft)
                onDone()
            }
        }
    }

    private var placeholder: String {
        switch draft.kind {
        case .reps: return "For example: Push-ups"
        case .checklist: return "For example: Knee exercises"
        case .intervals: return "For example: Tabata"
        }
    }

    private func move(_ id: UUID, by offset: Int) {
        guard let i = draft.exercises.firstIndex(where: { $0.id == id }) else { return }
        let j = i + offset
        guard draft.exercises.indices.contains(j) else { return }
        withAnimation { draft.exercises.swapAt(i, j) }
    }
}

/// The seventeen colours in two rows of nine.
private struct SwatchGrid: View {
    @Binding var selected: String

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 9), spacing: 10) {
            ForEach(Palette.all, id: \.key) { s in
                Button {
                    selected = s.key
                } label: {
                    Circle()
                        .fill(Color(hex: s.fill))
                        .aspectRatio(1, contentMode: .fit)
                        .overlay {
                            if selected == s.key {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .heavy))
                                    .foregroundStyle(Color(hex: s.ink))
                            }
                        }
                        .overlay(Circle().stroke(Theme.ink, lineWidth: selected == s.key ? 2.5 : 0).padding(-3))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(s.name)
                .accessibilityAddTraits(selected == s.key ? .isSelected : [])
                .accessibilityIdentifier("swatch-\(s.key)")
            }
        }
        .padding(.vertical, 6)
    }
}

private struct NumberRow: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    var isTime = false
    let id: String

    var body: some View {
        Stepper(value: $value, in: range, step: step) {
            HStack {
                Text(title).foregroundStyle(Theme.ink)
                Spacer()
                Text(isTime ? (value == 0 ? "None" : Clock.text(value)) : "\(value)")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
            }
        }
        .accessibilityIdentifier(id)
    }
}

private struct ExerciseHeader: View {
    let number: Int
    let count: Int
    let up: () -> Void
    let down: () -> Void
    let remove: () -> Void

    var body: some View {
        HStack {
            Text("Exercise \(number)")
            Spacer()
            Menu {
                Button(action: up) { Label("Move up", systemImage: "arrow.up") }.disabled(number == 1)
                Button(action: down) { Label("Move down", systemImage: "arrow.down") }.disabled(number == count)
                Button(role: .destructive, action: remove) { Label("Remove", systemImage: "trash") }
            } label: {
                Image(systemName: "ellipsis.circle").font(.body)
            }
            .accessibilityLabel("Exercise \(number) options")
        }
    }
}

/// Name, amount, note and photo of one exercise.
private struct ExerciseFields: View {
    @Environment(Library.self) private var library
    @Binding var exercise: Exercise
    let number: Int
    @State private var pick: PhotosPickerItem?

    var body: some View {
        Group { fields }
            .onChange(of: pick) { _, item in load(item) }
    }

    @ViewBuilder private var fields: some View {
        TextField("Name — for example: Bridge", text: $exercise.name)
            .font(.body.weight(.semibold))
            .accessibilityIdentifier("exercise-name-\(number)")
        TextField("Amount — for example: 3 × 10", text: $exercise.amount)
            .accessibilityIdentifier("exercise-amount-\(number)")
        TextField("Note — how to do it", text: $exercise.note, axis: .vertical)
            .lineLimit(1...6)
            .accessibilityIdentifier("exercise-note-\(number)")

        if let image = library.image(exercise.photo) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(height: 160)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            HStack {
                PhotosPicker(selection: $pick, matching: .images) {
                    Label("Replace photo", systemImage: "photo")
                }
                Spacer()
                Button(role: .destructive) { exercise.photo = nil } label: {
                    Label("Remove", systemImage: "trash").labelStyle(.iconOnly)
                }
                .accessibilityLabel("Remove photo")
            }
            .buttonStyle(.borderless)
        } else {
            PhotosPicker(selection: $pick, matching: .images) {
                Label("Add photo", systemImage: "photo.badge.plus")
            }
        }
    }

    private func load(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let name = library.storePhoto(data) {
                exercise.photo = name
            }
            pick = nil
        }
    }
}
