import Foundation

/// One colour a workout can wear: the fill, and the colour of words and icons on it.
public struct Swatch: Hashable, Sendable {
    public let key: String
    public let name: String
    public let fill: String
    public let ink: String
}

/// The same seventeen colours as the AMS Packing template colours
/// (AMS-Packing-App docs/colours.md): two rows, no teal, each one shade for day and night.
/// The first six are his WET colours — Strength orange, Mobility rose pink, Run green…
public enum Palette {
    public static let all: [Swatch] = [
        Swatch(key: "blue", name: "Blue", fill: "#0a84ff", ink: "#ffffff"),
        Swatch(key: "yellow", name: "Yellow", fill: "#ffd60a", ink: "#3d3000"),
        Swatch(key: "green", name: "Green", fill: "#30d158", ink: "#0b3a17"),
        Swatch(key: "orange", name: "Orange", fill: "#ff8c1a", ink: "#4a2300"),
        Swatch(key: "lavender", name: "Lavender", fill: "#bf9cff", ink: "#2e1a5c"),
        Swatch(key: "pink", name: "Pink", fill: "#ff6fa8", ink: "#5a0f2e"),
        Swatch(key: "red", name: "Red", fill: "#dc3d43", ink: "#ffffff"),
        Swatch(key: "plum", name: "Plum", fill: "#9c3d8c", ink: "#ffffff"),
        Swatch(key: "violet", name: "Violet", fill: "#7c5cd6", ink: "#ffffff"),
        Swatch(key: "indigo", name: "Indigo", fill: "#4f46e5", ink: "#ffffff"),
        Swatch(key: "navy", name: "Navy", fill: "#2a5194", ink: "#ffffff"),
        Swatch(key: "lightblue", name: "Light blue", fill: "#8cc8ff", ink: "#16232a"),
        Swatch(key: "olive", name: "Olive", fill: "#6e7b1f", ink: "#ffffff"),
        Swatch(key: "lightyellow", name: "Light yellow", fill: "#ffef8a", ink: "#16232a"),
        Swatch(key: "sand", name: "Sand", fill: "#d9b98c", ink: "#3d2a10"),
        Swatch(key: "brown", name: "Brown", fill: "#8b5e3c", ink: "#ffffff"),
        Swatch(key: "grey", name: "Grey", fill: "#64748b", ink: "#ffffff"),
    ]

    /// An unknown key falls back to orange rather than failing.
    public static func swatch(_ key: String) -> Swatch {
        all.first { $0.key == key } ?? all[3]
    }

    /// "#ff8c1a" → (1.0, 0.549, 0.102).
    public static func rgb(_ hex: String) -> (r: Double, g: Double, b: Double) {
        let s = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        let v = UInt32(s, radix: 16) ?? 0
        return (Double((v >> 16) & 0xff) / 255, Double((v >> 8) & 0xff) / 255, Double(v & 0xff) / 255)
    }

    /// WCAG contrast ratio between two colours.
    public static func contrast(_ a: String, _ b: String) -> Double {
        func lum(_ hex: String) -> Double {
            let c = rgb(hex)
            func ch(_ x: Double) -> Double { x <= 0.03928 ? x / 12.92 : pow((x + 0.055) / 1.055, 2.4) }
            return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b)
        }
        let l1 = lum(a), l2 = lum(b)
        return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)
    }
}
