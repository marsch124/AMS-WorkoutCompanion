import SwiftUI
import WorkoutCore

/// How to use a machine, full screen (since 2.0): the instruction plate photo, the machine photo,
/// the setting and his own words. Empty parts are left out.
struct InstructionViewScreen: View {
    @Environment(Library.self) private var library
    let machine: Machine
    let close: () -> Void

    private var words: String { (machine.howTo ?? "").trimmingCharacters(in: .whitespacesAndNewlines) }
    private var hasPlate: Bool { library.image(machine.instructions) != nil }
    private var hasPhoto: Bool { library.image(machine.photo) != nil }
    private var hasSetting: Bool { !machine.setting.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(machine.name)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Theme.ink)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("howto-name")
                    if hasPlate {
                        ZoomableImage(image: library.image(machine.instructions))
                            .accessibilityIdentifier("howto-plate")
                    }
                    if hasPhoto {
                        MachinePhoto(name: machine.photo, height: 200, icon: machine.icon)
                            .accessibilityIdentifier("howto-photo")
                    }
                    if hasSetting {
                        Text("Your setting: \(machine.setting)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Gym.tint)
                            .accessibilityIdentifier("howto-setting")
                    }
                    if !words.isEmpty {
                        Text(words)
                            .font(.body)
                            .foregroundStyle(Theme.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityIdentifier("howto-words")
                    }
                    if !hasPlate && !hasPhoto && !hasSetting && words.isEmpty {
                        Text("No instructions yet — add a photo or a few words in the machine's settings.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.muted)
                            .accessibilityIdentifier("howto-empty")
                    }
                }
                .padding(16)
            }
            Button("Close", action: close)
                .buttonStyle(BigButtonStyle(fill: Gym.fill, ink: Gym.ink, height: 50))
                .keyboardShortcut(.cancelAction)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .accessibilityIdentifier("howto-close")
        }
        .background(Theme.bg.ignoresSafeArea())
    }
}

/// A photo that can be pinched bigger and dragged; double tap resets it.
private struct ZoomableImage: View {
    let image: UIImage?
    @State private var scale: CGFloat = 1
    @State private var base: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var dragBase: CGSize = .zero

    var body: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .scaleEffect(scale)
                .offset(offset)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .gesture(
                    MagnifyGesture()
                        .onChanged { scale = max(1, min(6, base * $0.magnification)) }
                        .onEnded { _ in
                            base = scale
                            if scale == 1 { offset = .zero; dragBase = .zero }
                        }
                )
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { if scale > 1 { offset = CGSize(width: dragBase.width + $0.translation.width, height: dragBase.height + $0.translation.height) } }
                        .onEnded { _ in dragBase = offset }
                )
                .onTapGesture(count: 2) { scale = 1; base = 1; offset = .zero; dragBase = .zero }
        }
    }
}

/// The small picture for a machine: its instruction plate photo, else its photo, else its mark.
struct HowToThumb: View {
    let machine: Machine
    var size: CGFloat = 34

    var body: some View {
        MachinePhoto(name: machine.instructions ?? machine.photo, height: size, icon: machine.icon, corner: 8)
            .frame(width: size)
    }
}
