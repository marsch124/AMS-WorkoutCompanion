import Foundation

public extension GymSet {
    /// A number typed into a number box (since 1.33): "32,5" or "32.5" → 32.5;
    /// nil when nothing sensible is written (empty, letters, below 0, 10 000 or more).
    static func typed(_ text: String) -> Double? {
        let clean = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard !clean.isEmpty, let v = Double(clean), v >= 0, v < 10_000 else { return nil }
        return v
    }
}
