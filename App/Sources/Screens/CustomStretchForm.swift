import AMSIcons
import PhotosUI
import SwiftUI
import WorkoutCore

/// Make or change his own stretch (since 2.0): name, time, one side or both, note, area, optional photo.
struct CustomStretchForm: View {
    @Environment(Library.self) private var library
    let initial: CustomStretch?
    let onSave: (CustomStretch) -> Void
    let onDelete: ((String) -> Void)?
    let onCancel: () -> Void

    @State private var name = ""
    @State private var seconds = 30
    @State private var bothSides = false
    @State private var note = ""
    @State private var area = ""
    @State private var photo: String?
    @State private var pick: PhotosPickerItem?
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name — for example: Calf on a stair", text: $name)
                        .font(.body.weight(.semibold))
                        .accessibilityIdentifier("stretch-own-name")
                    Stepper(value: $seconds, in: 5...600, step: 5) {
                        HStack { Text("Hold"); Spacer(); Text("\(seconds) s").foregroundStyle(Theme.muted) }
                    }
                    .accessibilityIdentifier("stretch-own-seconds")
                    Picker("Sides", selection: $bothSides) {
                        Text("One side").tag(false)
                        Text("Both sides").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("stretch-own-sides")
                    Picker("Area", selection: $area) {
                        Text("No area").tag("")
                        ForEach(StretchArea.allCases.filter { $0 != .warm }, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
                    }
                    .accessibilityIdentifier("stretch-own-area")
                    TextField("Note — how to do it", text: $note, axis: .vertical)
                        .lineLimit(1...5)
                        .accessibilityIdentifier("stretch-own-note")
                }
                Section {
                    if let image = library.image(photo) {
                        Image(uiImage: image).resizable().scaledToFill()
                            .frame(height: 140).frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        HStack {
                            PhotosPicker(selection: $pick, matching: .images) {
                                MarkLabel(title: "Replace photo", mark: .photo, colour: Theme.accent)
                            }
                            Spacer()
                            Button("Remove photo", role: .destructive) { photo = nil }
                        }
                        .buttonStyle(.borderless)
                    } else {
                        PhotosPicker(selection: $pick, matching: .images) {
                            MarkLabel(title: "Add photo", mark: .photo, colour: Theme.accent)
                        }
                        .accessibilityIdentifier("stretch-own-photo")
                    }
                }
                if let initial, let onDelete {
                    Section {
                        Button("Delete this stretch", role: .destructive) { onDelete(initial.id) }
                            .accessibilityIdentifier("stretch-own-delete")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle(initial == nil ? "Own stretch" : "Edit stretch")
            .navigationBarTitleDisplayMode(.inline)
            .bottomActions(cancel: onCancel, save: save, tint: Gym.fill,
                           cancelID: "stretch-own-cancel", saveID: "stretch-own-save")
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            if let c = initial {
                name = c.name; seconds = c.seconds; bothSides = c.sides == 2
                note = c.note; area = c.area ?? ""; photo = c.photo
            }
        }
        .onChange(of: pick) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let n = library.storePhoto(data) { photo = n }
                pick = nil
            }
        }
    }

    private func save() {
        let n = name.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty else { return }
        var c = initial ?? CustomStretch(name: n)
        c.name = n; c.seconds = seconds; c.sides = bothSides ? 2 : 1
        c.note = note; c.area = area.isEmpty ? nil : area; c.photo = photo
        onSave(c)
    }
}
