import Foundation

extension GymLog {
    /// Gives a gym its own photo, or takes it away with nil (since 1.29, his idea: a small photo of
    /// the actual gym beside its name in the gym chooser). The old photo's file is tidied away by
    /// the app once nothing uses it — `photosInUse` counts the gyms' photos too.
    public mutating func setPhoto(gym gymID: UUID, _ name: String?) {
        guard let i = gyms.firstIndex(where: { $0.id == gymID }) else { return }
        gyms[i].photo = name
    }
}
