import SwiftUI
import UIKit
import WorkoutCore

extension UIColor {
    convenience init(hex: String) {
        let c = Palette.rgb(hex)
        self.init(red: c.r, green: c.g, blue: c.b, alpha: 1)
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
    var fill: Color { Color(hex: Palette.swatch(colour).fill) }
    var inkOnFill: Color { Color(hex: Palette.swatch(colour).ink) }
}

/// The rounded tile with the workout's symbol, in its colour.
struct WorkoutTile: View {
    let workout: Workout
    var size: CGFloat = 56

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(workout.fill)
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: workout.kind.symbol)
                    .font(.system(size: size * 0.45, weight: .semibold))
                    .foregroundStyle(workout.inkOnFill)
            )
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
            Image(systemName: "xmark")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Theme.muted)
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
                .overlay(Image(systemName: "checkmark").font(.system(size: 72, weight: .bold)).foregroundStyle(workout.inkOnFill))
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
