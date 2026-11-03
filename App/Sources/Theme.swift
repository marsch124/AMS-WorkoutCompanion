import SwiftUI
import UIKit
import AMSIcons
import WorkoutCore

extension UIColor {
    convenience init(hex: String) {
        let s = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        let v = UInt32(s, radix: 16) ?? 0
        self.init(red: CGFloat((v >> 16) & 0xff) / 255, green: CGFloat((v >> 8) & 0xff) / 255,
                  blue: CGFloat(v & 0xff) / 255, alpha: 1)
    }
}

extension Color {
    init(hex: String) {
        self.init(uiColor: UIColor(hex: hex))
    }

    /// A light / dark pair, never a single hex (AMS colours).
    static func pair(_ light: String, _ dark: String) -> Color {
        let l = UIColor(hex: light), d = UIColor(hex: dark)
        return Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? d : l })
    }
}

/// Page and text colours — the same pairs as AMS Packing (docs/colours.md).
enum Theme {
    static let bg = Color.pair("#f4f6f7", "#0e1416")
    static let card = Color.pair("#ffffff", "#161f22")
    static let ink = Color.pair("#16232a", "#e7edee")
    static let muted = Color.pair("#5f7078", "#94a6ac")
    static let line = Color.pair("#e2e8ea", "#26343a")
    static let accent = Color(hex: "#2f6fe0")
    static let problem = Color(hex: "#dc3d43")
}

extension Workout {
    /// The workout's colour from the AMS-Icons hub; an unknown key is orange.
    var swatch: IconColour { IconColour.of(key: colour) ?? IconColour.of(key: "orange")! }
    var fill: Color { swatch.fillColor }
    var inkOnFill: Color { swatch.inkColor }
}

/// The rounded tile with the workout's hand-drawn icon, in its colour — the hub's IconTile.
struct WorkoutTile: View {
    let workout: Workout
    var size: CGFloat = 44

    var body: some View {
        IconTile(.hand(workout.shownIcon), colour: workout.swatch, fallbackTint: Theme.accent,
                 letter: workout.name, size: size)
            .accessibilityHidden(true)
    }
}

/// A countdown ring: the coloured part is the time still left.
struct Ring: View {
    var fractionLeft: Double
    var colour: Color
    var width: CGFloat = 22

    var body: some View {
        ZStack {
            Circle().stroke(Theme.line, lineWidth: width)
            Circle()
                .trim(from: 0, to: max(0.0001, min(1, fractionLeft)))
                .stroke(colour, style: StrokeStyle(lineWidth: width, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.25), value: fractionLeft)
        }
    }
}

/// The big filled button used during a workout.
struct BigButtonStyle: ButtonStyle {
    var fill: Color
    var ink: Color
    var height: CGFloat = 64

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 22, weight: .bold, design: .rounded))
            .foregroundStyle(ink)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(fill, in: RoundedRectangle(cornerRadius: height * 0.32, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

/// A quieter button on the card colour.
struct SoftButtonStyle: ButtonStyle {
    var height: CGFloat = 64

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 20, weight: .semibold, design: .rounded))
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: height * 0.32, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: height * 0.32, style: .continuous).stroke(Theme.line, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

/// Close button in the top corner of a running workout.
struct CloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ControlMarkView(.close, size: 18, colour: Theme.muted)
                .frame(width: 44, height: 44)
                .background(Theme.card, in: Circle())
        }
        .accessibilityLabel("Close")
        .accessibilityIdentifier("run-close")
    }
}

/// The "Well done" circle at the end.
struct FinishedBadge: View {
    let workout: Workout

    var body: some View {
        VStack(spacing: 20) {
            Circle()
                .fill(workout.fill)
                .frame(width: 160, height: 160)
                .overlay(ControlMarkView(.check, size: 84, colour: workout.inkOnFill))
                .shadow(color: workout.fill.opacity(0.45), radius: 24)
            Text("Well done")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.ink)
            Text(workout.name)
                .font(.title3)
                .foregroundStyle(Theme.muted)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("run-finished")
    }
}

extension View {
    /// Save (or Done) at the top right: a full-colour pill, never grey (AMS rule: the main button is full colour).
    func saveButton(_ colour: Color = Theme.accent) -> some View {
        self.buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(colour)
            .fontWeight(.semibold)
    }
}

/// Cancel (soft, left) and Save (full colour, right) pinned at the bottom, within thumb reach.
struct BottomActionsBar: ViewModifier {
    var cancel: (() -> Void)?
    var cancelTitle = "Cancel"
    let save: () -> Void
    var saveTitle = "Save"
    var tint: Color = Theme.accent
    var cancelID = "cancel"
    var saveID = "save"

    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom, spacing: 0) {
            HStack(spacing: 12) {
                if let cancel {
                    Button(cancelTitle, action: cancel)
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                        .tint(Theme.muted)
                        .foregroundStyle(Theme.ink)
                        .keyboardShortcut(.cancelAction)
                        .accessibilityIdentifier(cancelID)
                }
                Button(saveTitle, action: save)
                    .saveButton(tint)
                    .accessibilityIdentifier(saveID)
            }
            .controlSize(.large)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .background(Theme.bg.opacity(0.96).ignoresSafeArea(edges: .bottom))
        }
    }
}

extension View {
    /// Cancel and Save (or Done) at the bottom for one-handed use.
    func bottomActions(cancel: (() -> Void)?, cancelTitle: String = "Cancel", save: @escaping () -> Void,
                       saveTitle: String = "Save", tint: Color = Theme.accent,
                       cancelID: String = "cancel", saveID: String = "save") -> some View {
        modifier(BottomActionsBar(cancel: cancel, cancelTitle: cancelTitle, save: save, saveTitle: saveTitle,
                                  tint: tint, cancelID: cancelID, saveID: saveID))
    }
}
