import AMSIcons
import Charts
import PhotosUI
import SwiftUI
import UIKit
import WorkoutCore

/// One machine: its photo and setting, last time, today's sets, the next set and the rest.
struct MachineScreen: View {
    @Environment(Library.self) private var library
    let machineID: UUID
    let day: Date

    @State private var kg: Double = GymLog.starter.kg
    @State private var reps: Int = GymLog.starter.reps
    @State private var restEnd: Date?
    @State private var restLength: Double = Double(Gym.restSeconds)
    @State private var now = Date()
    @State private var editing = false
    @State private var changingSet: Int?
    @State private var zoom = false
    @State private var newBest = false
    @FocusState private var typing: Bool

    private let clock = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

    private var machine: Machine? { library.gym.machine(machineID) }
    private var visit: GymVisit { library.gym.visit(on: day) ?? GymVisit(date: day) }
    private var today: [GymSet] { visit.entries.last { $0.machineID == machineID }?.sets ?? [] }
    private var next: NextSet { library.gym.next(machineID, in: visit) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if let machine {
                    Button { zoom = machine.photo != nil } label: {
                        MachinePhoto(name: machine.photo, height: machine.photo == nil ? 90 : 180)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("gym-photo")

                    if !machine.setting.isEmpty {
                        Text(machine.setting)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Gym.tint)
                            .accessibilityIdentifier("gym-setting")
                    }
                }
                lastTime
                if today.isEmpty, let reason = next.reason {
                    HStack(spacing: 8) {
                        IconMark(.hand("trophy"), size: 20, colour: Gym.tint)
                        Text(reason).font(.subheadline)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Gym.fill.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("gym-suggestion")
                }

                if !today.isEmpty { setsDone }

                if let restEnd {
                    rest(until: restEnd)
                } else {
                    entry
                }

                history
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle(machine?.name ?? "Machine")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { editing = true } label: { ControlMarkView(.edit, size: 22, colour: Gym.tint) }
                    .accessibilityLabel("Edit machine")
                    .accessibilityIdentifier("gym-edit-machine")
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { typing = false }
            }
        }
        .onAppear(perform: prefill)
        .onReceive(clock) { t in
            now = t
            if let end = restEnd {
                let left = end.timeIntervalSince(t)
                if left <= 0 {
                    restEnd = nil
                    Cues.shared.go("Set \(today.count + 1)")
                } else if left < 3.2, Int(left.rounded(.up)) != Int((left + 0.25).rounded(.up)) {
                    Cues.shared.countdown()
                }
            }
        }
        .sheet(isPresented: $editing) {
            if let machine {
                NavigationStack {
                    MachineForm(machine: machine, isNew: false) { _ in editing = false }
                }
                .environment(library)
            }
        }
        .sheet(item: Binding(get: { changingSet.map { SetIndex(index: $0) } }, set: { changingSet = $0?.index })) { s in
            NavigationStack {
                SetEditor(number: s.index + 1, set: today[s.index]) { result in
                    if let result {
                        library.changeGym { $0.change(visit: visit.id, machine: machineID, set: s.index, to: result) }
                    }
                    changingSet = nil
                } remove: {
                    library.changeGym { $0.change(visit: visit.id, machine: machineID, set: s.index, to: nil) }
                    changingSet = nil
                }
            }
            .presentationDetents([.medium])
        }
        .fullScreenCover(isPresented: $zoom) {
            ZoomedMachine(name: machine?.photo) { zoom = false }
        }
    }

    // MARK: Parts

    @ViewBuilder private var lastTime: some View {
        if let last = library.gym.last(machineID, excluding: visit.id) {
            Text("Last time, \(last.visit.date.formatted(.dateTime.day().month(.abbreviated))): \(last.entry.text)")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .accessibilityIdentifier("gym-last")
        } else {
            Text("First time on this machine.")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .accessibilityIdentifier("gym-last")
        }
    }

    private var setsDone: some View {
        VStack(spacing: 0) {
            ForEach(Array(today.enumerated()), id: \.offset) { i, s in
                Button { changingSet = i } label: {
                    HStack {
                        Text("Set \(i + 1)").foregroundStyle(Theme.muted)
                        Spacer()
                        Text(s.text).fontWeight(.semibold).foregroundStyle(Theme.ink)
                        ControlMarkView(.check, size: 16, colour: Gym.tint)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Set \(i + 1), \(s.text)")
                .accessibilityIdentifier("gym-set-\(i + 1)")
                if i < today.count - 1 { Divider().padding(.leading, 12) }
            }
        }
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.line, lineWidth: 1))
    }

    private var entry: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Set \(today.count + 1)")
                    .font(.headline)
                    .foregroundStyle(Gym.tint)
                    .accessibilityIdentifier("gym-next-set")
                Spacer()
                if newBest {
                    HStack(spacing: 4) {
                        IconMark(.hand("trophy"), size: 18, colour: Gym.tint)
                        Text("New best").font(.subheadline.weight(.semibold)).foregroundStyle(Gym.tint)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("gym-new-best")
                }
            }
            Stepper2(title: "kg", id: "gym-weight",
                     minus: { kg = max(0, kg - GymLog.step) }, plus: { kg += GymLog.step }) {
                TextField("0", value: $kg, format: .number.precision(.fractionLength(0...2)))
                    .keyboardType(.decimalPad)
                    .focused($typing)
            }
            Stepper2(title: "reps", id: "gym-reps",
                     minus: { reps = max(1, reps - 1) }, plus: { reps += 1 }) {
                TextField("0", value: $reps, format: .number)
                    .keyboardType(.numberPad)
                    .focused($typing)
            }
            Button(action: setDone) {
                MarkLabel(title: "Set done", mark: .check, size: 24, colour: Gym.ink)
            }
            .buttonStyle(BigButtonStyle(fill: Gym.fill, ink: Gym.ink, height: 58))
            .accessibilityIdentifier("gym-set-done")
            if today.isEmpty {
                Text(kg <= 0 ? "0 kg means body weight." : "Filled in from last time — change only what is different.")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
        }
        .padding(12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Gym.fill.opacity(0.5), lineWidth: 1))
    }

    private func rest(until end: Date) -> some View {
        let left = max(0, end.timeIntervalSince(now))
        return VStack(spacing: 10) {
            ZStack {
                Ring(fractionLeft: left / max(1, restLength), colour: Gym.fill, width: 12)
                VStack(spacing: 0) {
                    Text("REST").font(.caption.weight(.bold)).foregroundStyle(Theme.muted)
                    Text(Clock.text(Int(left.rounded(.up))))
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.ink)
                        .accessibilityIdentifier("gym-rest")
                }
            }
            .frame(width: 160, height: 160)
            Text("Next: set \(today.count + 1) · \(GymSet(kg: kg, reps: reps).text)")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
            HStack(spacing: 10) {
                Button("+15 s") {
                    restEnd = end.addingTimeInterval(15)
                    restLength += 15
                }
                .buttonStyle(SoftButtonStyle(height: 48))
                .accessibilityIdentifier("gym-rest-more")
                Button { restEnd = nil } label: {
                    MarkLabel(title: "Skip", mark: .skip, colour: Gym.ink)
                }
                .buttonStyle(BigButtonStyle(fill: Gym.fill, ink: Gym.ink, height: 48))
                .accessibilityIdentifier("gym-rest-skip")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder private var history: some View {
        let points = library.gym.history(machineID)
        if !points.isEmpty {
            Text("History")
                .font(.headline)
                .foregroundStyle(Gym.tint)
                .padding(.top, 8)
            VStack(alignment: .leading, spacing: 6) {
                if points.count > 1 {
                    Chart(points, id: \.date) { p in
                        LineMark(x: .value("Day", p.date), y: .value("kg", p.kg))
                            .foregroundStyle(Gym.tint)
                            .interpolationMethod(.monotone)
                        PointMark(x: .value("Day", p.date), y: .value("kg", p.kg))
                            .foregroundStyle(Gym.tint)
                    }
                    .chartYScale(domain: max(0, (points.map(\.kg).min() ?? 0) - 5)...((points.map(\.kg).max() ?? 0) + 5))
                    .chartYAxisLabel("kg")
                    .frame(height: 120)
                    .accessibilityIdentifier("gym-chart")
                }
                ForEach(points.reversed(), id: \.date) { p in
                    HStack {
                        Text(p.date.formatted(.dateTime.day().month(.abbreviated).year()))
                            .foregroundStyle(Theme.muted)
                        Spacer()
                        Text(p.entry.text).foregroundStyle(Theme.ink)
                    }
                    .font(.subheadline)
                }
            }
            .padding(12)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.line, lineWidth: 1))
        }
    }

    // MARK: Actions

    private func prefill() {
        let n = next.set
        kg = n.kg
        reps = n.reps
    }

    private func setDone() {
        typing = false
        let set = GymSet(kg: max(0, kg), reps: max(1, reps))
        let before = library.gym.best(machineID)
        library.changeGym { $0.add(set, machine: machineID, on: day) }
        newBest = before.map { set.kg > $0 } ?? false
        Cues.shared.tap()
        restLength = Double(Gym.restSeconds)
        restEnd = Date().addingTimeInterval(restLength)
        now = Date()
        Cues.shared.rest("Rest")
    }
}

private struct SetIndex: Identifiable {
    let index: Int
    var id: Int { index }
}

/// "− [ 30 ] kg +" — large, for thumbs at the gym.
private struct Stepper2<Field: View>: View {
    let title: String
    let id: String
    let minus: () -> Void
    let plus: () -> Void
    @ViewBuilder let field: () -> Field

    var body: some View {
        HStack(spacing: 10) {
            round(.minus, action: minus).accessibilityIdentifier("\(id)-minus")
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                field()
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(Theme.ink)
                    .fixedSize()
                    .accessibilityIdentifier(id)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Theme.muted)
            }
            .frame(maxWidth: .infinity)
            round(.plus, action: plus).accessibilityIdentifier("\(id)-plus")
        }
    }

    private enum Sign { case minus, plus }

    private func round(_ sign: Sign, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if sign == .plus {
                    ControlMarkView(.add, size: 22, colour: Gym.tint)
                } else {
                    Capsule().fill(Gym.fill).frame(width: 16, height: 2.2)
                }
            }
            .frame(width: 50, height: 50)
            .background(Gym.fill.opacity(0.12), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(sign == .plus ? "More \(title)" : "Less \(title)")
    }
}

/// Change or remove one set. Cancel leaves it as it was.
private struct SetEditor: View {
    let number: Int
    @State var set: GymSet
    let done: (GymSet?) -> Void
    let remove: () -> Void

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Weight")
                    Spacer()
                    TextField("0", value: $set.kg, format: .number.precision(.fractionLength(0...2)))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .accessibilityIdentifier("set-edit-kg")
                    Text("kg").foregroundStyle(Theme.muted)
                }
                Stepper("Reps: \(set.reps)", value: $set.reps, in: 1...500)
                    .accessibilityIdentifier("set-edit-reps")
            }
            Section {
                Button("Remove set", role: .destructive, action: remove)
                    .accessibilityIdentifier("set-edit-remove")
            }
        }
        .navigationTitle("Set \(number)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { done(nil) }
                    .accessibilityIdentifier("set-edit-cancel")
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { done(set) }
                    .saveButton()
                    .accessibilityIdentifier("set-edit-save")
            }
        }
    }
}

/// New machine or change one: photo, name, setting. Nothing is kept until Save.
struct MachineForm: View {
    @Environment(Library.self) private var library
    @State private var draft: Machine
    let isNew: Bool
    let done: (Machine?) -> Void
    @State private var needsName = false
    @State private var camera = false
    @State private var pick: PhotosPickerItem?
    @State private var askDelete = false

    init(machine: Machine, isNew: Bool, done: @escaping (Machine?) -> Void) {
        _draft = State(initialValue: machine)
        self.isNew = isNew
        self.done = done
    }

    var body: some View {
        Form {
            Section {
                MachinePhoto(name: draft.photo, height: draft.photo == nil ? 80 : 200)
                    .listRowInsets(EdgeInsets())
                if CameraPicker.available {
                    Button { camera = true } label: {
                        MarkLabel(title: draft.photo == nil ? "Take photo" : "Take photo again", mark: .photo, colour: Gym.tint)
                    }
                    .accessibilityIdentifier("machine-camera")
                }
                PhotosPicker(selection: $pick, matching: .images) {
                    MarkLabel(title: "Choose from Photos", mark: .photo, colour: Gym.tint)
                }
                .accessibilityIdentifier("machine-photos")
            }
            Section {
                TextField("For example: Chest press", text: $draft.name)
                    .font(.title3.weight(.semibold))
                    .accessibilityIdentifier("machine-name")
                    .onChange(of: draft.name) { needsName = false }
                if needsName {
                    Text("Give it a name first.")
                        .font(.footnote)
                        .foregroundStyle(Theme.problem)
                        .accessibilityIdentifier("machine-name-needed")
                }
            } header: {
                Text("Name")
            }
            Section {
                TextField("For example: Seat 4, handles 2", text: $draft.setting, axis: .vertical)
                    .accessibilityIdentifier("machine-setting")
            } header: {
                Text("How it is set up")
            } footer: {
                Text("Shown each time you use the machine.")
            }
            if !isNew {
                Section {
                    Button("Delete machine", role: .destructive) { askDelete = true }
                        .accessibilityIdentifier("machine-delete")
                }
            }
        }
        .navigationTitle(isNew ? "New machine" : "Edit machine")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { done(nil) }
                    .accessibilityIdentifier("machine-cancel")
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .saveButton()
                    .accessibilityIdentifier("machine-save")
            }
        }
        .onChange(of: pick) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self),
                   let name = library.storePhoto(data) {
                    draft.photo = name
                }
            }
        }
        .fullScreenCover(isPresented: $camera) {
            CameraPicker { data in
                camera = false
                if let data, let name = library.storePhoto(data) { draft.photo = name }
            }
            .ignoresSafeArea()
        }
        .confirmationDialog("Delete \(draft.name) and all its sets?", isPresented: $askDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                library.changeGym { $0.delete(machine: draft.id) }
                done(nil)
            }
        }
    }

    private func save() {
        guard !draft.name.trimmingCharacters(in: .whitespaces).isEmpty else {
            needsName = true
            return
        }
        library.changeGym { $0.save(draft) }
        done(draft)
    }
}

/// The machine's photo, full screen.
private struct ZoomedMachine: View {
    @Environment(Library.self) private var library
    let name: String?
    let close: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            if let image = library.image(name) {
                Image(uiImage: image).resizable().scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            CloseButton(action: close).padding(16)
        }
        .onTapGesture(perform: close)
    }
}

/// The iPhone camera; on a device without one, the photo library.
struct CameraPicker: UIViewControllerRepresentable {
    static var available: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }
    let finished: (Data?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = CameraPicker.available ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(finished: finished) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let finished: (Data?) -> Void
        init(finished: @escaping (Data?) -> Void) { self.finished = finished }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = info[.originalImage] as? UIImage
            finished(image?.jpegData(compressionQuality: 0.9))
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            finished(nil)
        }
    }
}
