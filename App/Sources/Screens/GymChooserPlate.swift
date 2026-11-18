import AMSIcons
import PhotosUI
import SwiftUI
import WorkoutCore

/// What the four buttons on the gym chooser plate do, once the plate has closed.
enum GymChooserAction { case new, rename, hours, earlierDay }

/// The gym chooser (since 1.29, his pick 2 of three pictures: "Plate from the bottom"). Before, the
/// gym's name pill opened Apple's plain glass menu. Now a plate slides up: "Choose gym", every gym
/// as its own row with a small photo of the gym (his idea), four buttons, and Done.
struct GymChooserPlate: View {
    @Environment(Library.self) private var library
    let choose: (GymPlace) -> Void
    let act: (GymChooserAction) -> Void
    let done: () -> Void

    /// The gym whose photo is being taken, chosen or removed.
    @State private var photoFor: GymPlace?
    @State private var camera = false
    @State private var picking = false
    @State private var pick: PhotosPickerItem?
    @State private var photoGym: UUID?

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 10) {
                    Text("Choose gym")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 18)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(library.gym.gyms) { row($0) }
                    LazyVGrid(columns: columns, spacing: 10) {
                        action("New gym", id: "gym-place-new", .new) { ControlMarkView(.add, size: 22, colour: Gym.tint) }
                        action("Rename this gym", id: "gym-place-rename", .rename) { ControlMarkView(.edit, size: 22, colour: Gym.tint) }
                        action("Opening hours", id: "gym-place-hours", .hours) { AppMarkView(.clock, size: 22, colour: Gym.tint) }
                        action("Log an earlier day", id: "gym-pick-day", .earlierDay) { AppMarkView(.calendar, size: 22, colour: Gym.tint) }
                    }
                    .padding(.top, 6)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
            Button("Done", action: done)
                .buttonStyle(BigButtonStyle(fill: Gym.fill, ink: Gym.ink, height: 50))
                .keyboardShortcut(.cancelAction)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .accessibilityIdentifier("gym-place-done")
        }
        .background(Theme.bg.ignoresSafeArea())
        .confirmationDialog(photoFor.map { "Photo of \($0.name)" } ?? "", isPresented: Binding(
            get: { photoFor != nil }, set: { if !$0 { photoFor = nil } }
        ), titleVisibility: .visible) {
            if CameraPicker.available {
                Button("Take photo") { photoGym = photoFor?.id; camera = true }
            }
            Button("Choose from Photos") { photoGym = photoFor?.id; picking = true }
            if let g = photoFor, g.photo != nil {
                Button("Remove photo", role: .destructive) { library.changeGym { $0.setPhoto(gym: g.id, nil) } }
            }
            Button("Cancel", role: .cancel) { }
        }
        .fullScreenCover(isPresented: $camera) {
            CameraPicker { data in
                camera = false
                store(data)
            }
            .ignoresSafeArea()
        }
        .photosPicker(isPresented: $picking, selection: $pick, matching: .images)
        .onChange(of: pick) { _, item in
            guard let item else { return }
            Task {
                let data = try? await item.loadTransferable(type: Data.self)
                await MainActor.run {
                    store(data)
                    pick = nil
                }
            }
        }
    }

    private func store(_ data: Data?) {
        guard let id = photoGym, let data, let name = library.storePhoto(data) else { return }
        library.changeGym { $0.setPhoto(gym: id, name) }
    }

    /// One gym: its photo (or the gym mark with a small camera, to add one), its name on one line,
    /// the open-now line when hours are given, "Here now" and the check for the gym in use.
    private func row(_ g: GymPlace) -> some View {
        let here = g.id == library.gym.currentGym?.id
        let line = g.openLine(at: Date())
        return HStack(spacing: 10) {
            Button { photoFor = g } label: { thumb(g) }
                .buttonStyle(.plain)
                .accessibilityLabel(g.photo == nil ? "Add a photo of \(g.name)" : "Change the photo of \(g.name)")
                .accessibilityIdentifier("gym-photo-\(g.name)")
            Button { choose(g) } label: {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(g.name)
                            .font(.headline)
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        if let line {
                            Text(line.text)
                                .font(.caption)
                                .foregroundStyle(line.open ? SessionGoingLine.green : Theme.muted)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 4)
                    if here {
                        Text("Here now")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(SessionGoingLine.green)
                            .lineLimit(1)
                            .fixedSize()
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(SessionGoingLine.green.opacity(0.14), in: Capsule())
                    }
                    if here {
                        ControlMarkView(.check, size: 15, colour: Gym.ink)
                            .frame(width: 26, height: 26)
                            .background(Gym.fill, in: Circle())
                    } else {
                        Circle().stroke(Theme.muted.opacity(0.5), lineWidth: 1.5).frame(width: 26, height: 26)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(here ? "\(g.name), here now" : g.name)
            .accessibilityIdentifier("gym-place-\(g.name)")
        }
        .padding(8)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(here ? Gym.tint : Theme.line, lineWidth: here ? 2 : 1))
    }

    /// 48 × 48: the gym's photo; without one, the gym mark on pale indigo with a small camera at the corner.
    @ViewBuilder private func thumb(_ g: GymPlace) -> some View {
        if let image = library.image(g.photo) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        } else {
            IconMark(.hand("gym"), size: 24, colour: Gym.tint)
                .frame(width: 48, height: 48)
                .background(Gym.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                .overlay(alignment: .bottomTrailing) {
                    IconMark(.hand("camera"), size: 12, colour: Gym.ink)
                        .frame(width: 20, height: 20)
                        .background(Gym.fill, in: Circle())
                        .offset(x: 5, y: 5)
                }
        }
    }

    private func action<Mark: View>(_ title: String, id: String, _ what: GymChooserAction,
                                    @ViewBuilder mark: () -> Mark) -> some View {
        Button { act(what) } label: {
            VStack(spacing: 5) {
                mark()
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Gym.tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 62)
            .background(Gym.tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityIdentifier(id)
    }
}
