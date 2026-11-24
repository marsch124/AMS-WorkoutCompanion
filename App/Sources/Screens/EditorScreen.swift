import AMSIcons
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
    @State private var needsName = false
    @State private var needsSteps = false
    @State private var removing: Exercise?
    @State private var mine = IntervalPreset.mine()
    @State private var askPresetName = false
    @State private var presetName = ""

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
                    .onChange(of: draft.name) { needsName = false }
                if needsName {
                    Text("Give it a name first.")
                        .font(.footnote)
                        .foregroundStyle(Theme.problem)
                        .accessibilityIdentifier("editor-name-needed")
                }
            }

            Section("Colour") {
                SwatchGrid(selected: $draft.colour)
            }

            Section {
                IconRow(icon: draft.icon, usual: draft.usualIcon, tint: draft.swatch.fillColor,
                        identifier: "editor-icon") { draft.icon = $0 }
            }

            Section("Type") {
                Picker("Type", selection: $draft.kind) {
                    Text("Sets").tag(WorkoutKind.reps)
                    Text("List").tag(WorkoutKind.checklist)
                    Text("Intervals").tag(WorkoutKind.intervals)
                    Text("Tailored").tag(WorkoutKind.tailored)
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
                    presetMenu
                }
                Section {
                    NumberRow(title: "Rounds", value: $draft.rounds, range: 1...99, step: 1, id: "editor-rounds")
                    NumberRow(title: "Work", value: $draft.workSeconds, range: 5...900, step: 5, isTime: true, id: "editor-work")
                    NumberRow(title: "Rest", value: $draft.offSeconds, range: 0...900, step: 5, isTime: true, id: "editor-off")
                } header: {
                    Text("Intervals")
                } footer: {
                    Text("Total \(Clock.text(draft.intervalTotal)), after a 5-second get ready.")
                }
            case .tailored:
                measuresSection
                stepsSection
            case .checklist:
                // The order is dragged (since 2.4, his rule: drag and drop, never arrows or Move up / Move down).
                if draft.exercises.count >= 2 {
                    Section {
                        ForEach(orderLines) { line in
                            Text(line.name)
                                .foregroundStyle(Theme.ink)
                                .lineLimit(1)
                                .accessibilityIdentifier("exercise-order-\(line.number)")
                        }
                        .onMove { draft.exercises.move(fromOffsets: $0, toOffset: $1) }
                    } header: {
                        Text("Order")
                    } footer: {
                        Text("Hold ≡ and drag to put the exercises in order.")
                    }
                }
                ForEach($draft.exercises) { $exercise in
                    let n = (draft.exercises.firstIndex { $0.id == exercise.id } ?? 0) + 1
                    Section {
                        ExerciseFields(exercise: $exercise, number: n)
                    } header: {
                        ExerciseHeader(number: n, remove: { removing = exercise })
                    }
                }
                Section {
                    Button {
                        withAnimation { draft.exercises.append(Exercise()) }
                    } label: {
                        MarkLabel(title: "Add exercise", mark: .addCircle, colour: Theme.accent)
                            .font(.body.weight(.semibold))
                    }
                    .buttonStyle(.borderless)
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
        // The steps of a Tailored workout show their ≡ grip and red minus all the time: drag and drop, no arrows.
        .environment(\.editMode, .constant(draft.kind == .tailored || draft.kind == .checklist ? .active : .inactive))
        .confirmationDialog("Remove \(removing.map { orderName($0, number: 0) } ?? "")?", isPresented: Binding(
            get: { removing != nil }, set: { if !$0 { removing = nil } }
        ), titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                if let r = removing { withAnimation { draft.exercises.removeAll { $0.id == r.id } } }
                removing = nil
            }
            .accessibilityIdentifier("exercise-remove-confirm")
        }
        .scrollContentBackground(.hidden)
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle(isNew ? draft.kind.title : "Edit workout")
        .navigationBarTitleDisplayMode(.inline)
        .bottomActions(cancel: onDone, save: {
            // Never a grey, disabled Save: it says what is missing instead.
            guard canSave else { needsName = true; return }
            if draft.kind == .tailored, draft.steps.isEmpty { needsSteps = true; return }
            library.save(draft)
            onDone()
        }, cancelID: "editor-cancel", saveID: "editor-save")
        .confirmationDialog("Delete \(draft.name)?", isPresented: $askDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                library.delete(draft)
                onDone()
            }
        }
    }

    /// What each step of a Tailored workout carries (since 2.5, his pick "pick per workout"): four words
    /// to tap — Pace, Power, Weight, Level. A chosen word is filled in the workout's colour.
    @ViewBuilder private var measuresSection: some View {
        Section {
            HStack(spacing: 6) {
                ForEach(StepMeasure.allCases, id: \.self) { measure in
                    let on = draft.measures.contains(measure)
                    Button {
                        draft.toggle(measure)
                    } label: {
                        Text(measure.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(on ? draft.swatch.inkColor : Theme.muted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .padding(.vertical, 7)
                            .frame(maxWidth: .infinity)
                            .background(on ? draft.swatch.fillColor : Theme.line, in: Capsule())
                    }
                    .buttonStyle(.borderless)
                    .accessibilityAddTraits(on ? .isSelected : [])
                    .accessibilityIdentifier("measure-\(measure.rawValue)")
                }
            }
        } header: {
            Text("Each step has")
        } footer: {
            Text("Tap what this workout needs. Every step then gets a box for it.")
        }
    }

    /// The steps of a Tailored intervals workout (since 2.3): his word, the length, − and +; the ≡ grip
    /// drags a line, the red minus removes it.
    @ViewBuilder private var stepsSection: some View {
        Section {
            ForEach($draft.steps) { $step in
                StepRow(step: $step, number: (draft.steps.firstIndex { $0.id == step.id } ?? 0) + 1,
                        measures: draft.shownMeasures, fill: draft.swatch.fillColor, ink: draft.swatch.inkColor)
            }
            .onMove { draft.steps.move(fromOffsets: $0, toOffset: $1) }
            .onDelete { draft.steps.remove(atOffsets: $0) }
            if draft.steps.count < IntervalStep.most {
                Button {
                    needsSteps = false
                    withAnimation { draft.steps.append(draft.nextStep()) }
                } label: {
                    MarkLabel(title: "Add step", mark: .addCircle, colour: Theme.accent)
                        .font(.body.weight(.semibold))
                }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("editor-add-step")
            }
            if needsSteps {
                Text("Add a step first.")
                    .font(.footnote)
                    .foregroundStyle(Theme.problem)
                    .accessibilityIdentifier("editor-steps-needed")
            }
        } header: {
            Text("Steps")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text("Total \(Clock.text(draft.tailoredTotal)), after a 5-second get ready.")
                    .accessibilityIdentifier("editor-steps-total")
                Text("Tap a time to choose a length; − and + change it in small steps. Hold ≡ and drag to put the steps in order. The red minus removes a step.")
                Text("Effort: tap the word to choose Easy, Steady, Hard or All-out. An Easy step runs on a grey ring.")
            }
        }
    }

    private func slug(_ name: String) -> String {
        name.lowercased().replacingOccurrences(of: " ", with: "-")
    }

    private func apply(_ p: IntervalPreset) {
        draft.rounds = p.rounds
        draft.workSeconds = p.workSeconds
        draft.offSeconds = p.offSeconds
        if draft.name.trimmingCharacters(in: .whitespaces).isEmpty { draft.name = p.name }
    }

    /// Ready-made interval patterns and his own (since 1.23).
    @ViewBuilder private var presetMenu: some View {
        Menu {
            ForEach(IntervalPreset.builtIn) { p in
                Button("\(p.name) · \(p.summary)") { apply(p) }
                    .accessibilityIdentifier("preset-\(slug(p.name))")
            }
            if !mine.isEmpty {
                Divider()
                ForEach(mine) { p in
                    Button("\(p.name) · \(p.summary)") { apply(p) }
                        .accessibilityIdentifier("preset-\(slug(p.name))")
                }
                Menu("Remove my preset") {
                    ForEach(mine) { p in
                        Button(p.name, role: .destructive) {
                            mine.removeAll { $0.id == p.id }
                            IntervalPreset.saveMine(mine)
                        }
                        .accessibilityIdentifier("preset-remove-\(slug(p.name))")
                    }
                }
            }
        } label: {
            HStack {
                Text("Presets").foregroundStyle(Theme.ink)
                Spacer()
                Text("Choose").foregroundStyle(Theme.accent)
            }
        }
        .accessibilityIdentifier("preset-menu")
        Button("Save as preset") {
            presetName = ""
            askPresetName = true
        }
        .accessibilityIdentifier("preset-save")
        .alert("Save as preset", isPresented: $askPresetName) {
            TextField("Name", text: $presetName)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                let name = presetName.trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { return }
                mine.append(IntervalPreset(name: name, rounds: draft.rounds,
                                           workSeconds: draft.workSeconds, offSeconds: draft.offSeconds))
                IntervalPreset.saveMine(mine)
            }
        } message: {
            Text("\(draft.rounds) × \(draft.workSeconds) s / \(draft.offSeconds) s")
        }
    }

    private var placeholder: String {
        switch draft.kind {
        case .reps: return "For example: Push-ups"
        case .checklist: return "For example: Knee exercises"
        case .intervals: return "For example: Tabata"
        case .tailored: return "For example: Jog and walk"
        }
    }

    /// The lines of the Order block. Each has an identity of its own: the exercises' own identities
    /// already name the sections below, and two rows with one identity in the same list cannot be dragged.
    private var orderLines: [OrderLine] {
        draft.exercises.enumerated().map {
            OrderLine(id: "order-\($1.id.uuidString)", name: orderName($1, number: $0 + 1), number: $0 + 1)
        }
    }

    /// An exercise's line in the Order block and in "Remove …?": its name, or "Exercise 3" while it has none.
    private func orderName(_ exercise: Exercise, number: Int) -> String {
        let name = exercise.name.trimmingCharacters(in: .whitespaces)
        if !name.isEmpty { return name }
        let n = number > 0 ? number : (draft.exercises.firstIndex { $0.id == exercise.id } ?? 0) + 1
        return "Exercise \(n)"
    }
}

/// The AMS-Icons hub's fifteen colours, in two rows of eight.
private struct SwatchGrid: View {
    @Binding var selected: String

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 8), spacing: 10) {
            ForEach(IconColour.palette) { s in
                Button {
                    selected = s.key
                } label: {
                    Circle()
                        .fill(s.fillColor)
                        .aspectRatio(1, contentMode: .fit)
                        .overlay {
                            if selected == s.key {
                                ControlMarkView(.check, size: 16, colour: s.inkColor)
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

/// One step of a Tailored intervals workout: his word for it, its length (a tap offers ready lengths), − and +;
/// under them, since 2.5, one box for each number the workout uses (pace, power, weight, level).
private struct StepRow: View {
    @Binding var step: IntervalStep
    let number: Int
    let measures: [StepMeasure]
    let fill: Color
    let ink: Color
    /// A "Speed or power" text typed in 2.4 stays on its step, to change or empty; new steps have no such line.
    @State private var hadTarget = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            top
            // The effort word first (since 2.6), then a box for each number the workout uses.
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 6)], alignment: .leading, spacing: 6) {
                effortMenu
                ForEach(measures, id: \.self) { measure in
                    MeasureBox(measure: measure, step: $step, number: number)
                }
            }
            if hadTarget {
                TextField("Speed or power", text: $step.target)
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .accessibilityIdentifier("step-target-\(number)")
            }
        }
        .onAppear { hadTarget = step.shownTarget != nil }
    }

    /// The step's effort (since 2.6, his pick "Four ready efforts"): its word — Easy grey, the others in the
    /// workout's colour — or a grey "Effort" in an outline when it has none. A tap offers the four.
    private var effortMenu: some View {
        Menu {
            ForEach(StepEffort.allCases, id: \.self) { effort in
                Button(effort.title) { step.effort = effort }
            }
            Divider()
            Button("No effort") { step.effort = nil }
        } label: {
            Text(step.effort?.title ?? "Effort")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(step.effort == nil || step.isCalm ? Theme.muted : ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background {
                    if step.effort == nil {
                        Capsule().stroke(Theme.muted.opacity(0.55), lineWidth: 1.5)
                    } else {
                        Capsule().fill(step.isCalm ? Theme.line : fill)
                    }
                }
                .contentShape(Capsule())
        }
        .accessibilityLabel("Effort of step \(number): \(step.effort?.title ?? "none")")
        .accessibilityIdentifier("step-effort-\(number)")
    }

    private var top: some View {
        HStack(spacing: 8) {
            TextField("Step \(number)", text: $step.name)
                .font(.body.weight(.semibold))
                .accessibilityIdentifier("step-name-\(number)")
            Menu {
                ForEach(IntervalStep.lengths, id: \.self) { s in
                    Button(Clock.text(s)) { step.seconds = s }
                }
            } label: {
                Text(Clock.text(step.seconds))
                    .font(.system(.body, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.accent.opacity(0.14), in: Capsule())
            }
            .accessibilityIdentifier("step-time-\(number)")
            Stepper("Length of step \(number)") {
                step.seconds = IntervalStep.stepped(step.seconds, up: true)
            } onDecrement: {
                step.seconds = IntervalStep.stepped(step.seconds, up: false)
            }
            .labelsHidden()
            .accessibilityIdentifier("step-stepper-\(number)")
        }
    }
}

/// One number of a step in its box: typed freely, read when it makes sense, tidied when he leaves the box.
private struct MeasureBox: View {
    let measure: StepMeasure
    @Binding var step: IntervalStep
    let number: Int
    @State private var text = ""
    @FocusState private var typing: Bool

    var body: some View {
        HStack(spacing: 3) {
            TextField(measure.title, text: $text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.ink)
                .keyboardType(.numbersAndPunctuation)
                .autocorrectionDisabled()
                .multilineTextAlignment(.trailing)
                .focused($typing)
                .accessibilityLabel("\(measure.title) of step \(number)")
                .accessibilityIdentifier("step-\(measure.rawValue)-\(number)")
            Text(measure.unit)
                .font(.footnote)
                .foregroundStyle(Theme.muted)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Theme.muted.opacity(0.55), lineWidth: 1.5))
        .onAppear { text = step.value(measure).map(measure.text) ?? "" }
        .onChange(of: text) { _, typed in
            let value = measure.parse(typed)
            if value != step.value(measure) { step.set(measure, value) }
        }
        .onChange(of: typing) { _, now in
            if !now { text = step.value(measure).map(measure.text) ?? "" }
        }
    }
}

private struct OrderLine: Identifiable {
    let id: String
    let name: String
    let number: Int
}

/// An exercise's heading: its number and the red word Remove (since 2.4; before, a ••• menu with
/// Move up, Move down and Remove — the order is dragged in the Order block now).
private struct ExerciseHeader: View {
    let number: Int
    let remove: () -> Void

    var body: some View {
        HStack {
            Text("Exercise \(number)")
            Spacer()
            Button("Remove", action: remove)
                .font(.footnote.weight(.semibold))
                .textCase(nil)
                .foregroundStyle(Theme.problem)
                .buttonStyle(.borderless)
                .accessibilityIdentifier("exercise-remove-\(number)")
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
                    MarkLabel(title: "Replace photo", mark: .photo, colour: Theme.accent)
                }
                Spacer()
                Button("Remove photo", role: .destructive) { exercise.photo = nil }
            }
            .buttonStyle(.borderless)
        } else {
            PhotosPicker(selection: $pick, matching: .images) {
                MarkLabel(title: "Add photo", mark: .photo, colour: Theme.accent)
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
