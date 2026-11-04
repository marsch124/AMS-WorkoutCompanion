import PhotosUI
import SwiftUI
import WorkoutCore

/// Photos of a gym session (since 1.13): a row of squares, Take photo and Choose from Photos.
/// Shown on "Session done" and on the visit page. Tap a photo to see it large or remove it.
struct SessionPhotos: View {
    @Environment(Library.self) private var library
    let visitID: UUID
    @State private var camera = false
    @State private var pick: PhotosPickerItem?
    @State private var showing: ShownPhoto?

    private struct ShownPhoto: Identifiable { let name: String; var id: String { name } }

    /// UI tests cannot drive the camera or the Photos picker: -fakephoto adds a made-up picture instead.
    private static let fake = ProcessInfo.processInfo.arguments.contains("-fakephoto")

    private var photos: [String] { library.gym.visits.first { $0.id == visitID }?.photos ?? [] }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !photos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(photos.enumerated()), id: \.element) { i, name in
                            Button { showing = ShownPhoto(name: name) } label: {
                                Color.clear
                                    .frame(width: 88, height: 88)
                                    .overlay {
                                        if let ui = library.image(name) {
                                            Image(uiImage: ui).resizable().scaledToFill()
                                        }
                                    }
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Photo \(i + 1)")
                            .accessibilityIdentifier("session-photo-\(i + 1)")
                        }
                    }
                }
            }
            HStack(spacing: 16) {
                if CameraPicker.available && !Self.fake {
                    Button { camera = true } label: {
                        MarkLabel(title: "Take photo", mark: .photo, colour: Gym.tint)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("session-photo-camera")
                }
                if Self.fake {
                    Button(action: addFake) {
                        MarkLabel(title: "Choose from Photos", mark: .photo, colour: Gym.tint)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("session-photo-add")
                } else {
                    PhotosPicker(selection: $pick, matching: .images) {
                        MarkLabel(title: photos.isEmpty ? "Choose from Photos" : "Add from Photos", mark: .photo, colour: Gym.tint)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("session-photo-add")
                }
            }
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(Gym.tint)
        .accessibilityElement(children: .contain)
        .accessibilityValue(photos.count == 1 ? "1 photo" : "\(photos.count) photos")
        .accessibilityIdentifier("session-photos")
        .onChange(of: pick) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) { add(data) }
                pick = nil
            }
        }
        .fullScreenCover(isPresented: $camera) {
            CameraPicker { data in
                camera = false
                if let data { add(data) }
            }
            .ignoresSafeArea()
        }
        .sheet(item: $showing) { shown in
            SessionPhotoViewer(name: shown.name) {
                library.changeGym { $0.removePhoto(visit: visitID, shown.name) }
                showing = nil
            } close: { showing = nil }
        }
    }

    private func add(_ data: Data) {
        guard let name = library.storePhoto(data) else { return }
        library.changeGym { $0.addPhoto(visit: visitID, name) }
    }

    private func addFake() {
        let ui = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 300)).image { c in
            UIColor.systemIndigo.setFill()
            c.fill(CGRect(x: 0, y: 0, width: 400, height: 300))
        }
        if let data = ui.jpegData(compressionQuality: 0.8) { add(data) }
    }
}

/// One session photo, large, with Remove (after asking) and Done.
private struct SessionPhotoViewer: View {
    @Environment(Library.self) private var library
    let name: String
    let remove: () -> Void
    let close: () -> Void
    @State private var asking = false

    var body: some View {
        NavigationStack {
            VStack {
                if let ui = library.image(name) {
                    Image(uiImage: ui).resizable().scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Session photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Remove", role: .destructive) { asking = true }
                        .foregroundStyle(Theme.problem)
                        .accessibilityIdentifier("session-photo-remove")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", action: close)
                        .fontWeight(.semibold)
                        .foregroundStyle(Gym.tint)
                        .accessibilityIdentifier("session-photo-done")
                }
            }
            .confirmationDialog("Remove this photo from the session?", isPresented: $asking, titleVisibility: .visible) {
                Button("Remove photo", role: .destructive, action: remove)
                    .accessibilityIdentifier("session-photo-remove-confirm")
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}
