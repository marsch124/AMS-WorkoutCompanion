import AMSIcons
import SwiftUI
import WorkoutCore

/// A neat picture of one visit to send or save (since 1.11). Fixed light look and width, so it reads the same everywhere.
struct VisitShareCard: View {
    let visit: GymVisit
    let gym: GymLog

    private let ink = Color(red: 0.11, green: 0.11, blue: 0.14)
    private let muted = Color(red: 0.42, green: 0.42, blue: 0.48)
    private let indigo = Color(red: 0.31, green: 0.27, blue: 0.90)

    var body: some View {
        let place = gym.gyms.first { $0.id == visit.gymID }?.name ?? "At the gym"
        let bests = Set(gym.newBests(in: visit))
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(visit.title ?? visit.date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(.title2.weight(.bold)).foregroundStyle(.white)
                Text((visit.title != nil ? visit.date.formatted(.dateTime.weekday(.wide).day().month(.wide)) + " · " : "") + place)
                    .font(.subheadline.weight(.semibold)).foregroundStyle(.white.opacity(0.9))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(indigo, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            HStack(spacing: 8) {
                tile("Time", visit.minutes.map { "\($0) min" } ?? "–", Color(red: 0.13, green: 0.55, blue: 0.30))
                tile("Sets", "\(visit.setCount)", Color(red: 0.85, green: 0.45, blue: 0.08))
                tile("Lifted", "\(GymSet.number(visit.totalKg)) kg", Color(red: 0.55, green: 0.25, blue: 0.65))
            }
            ForEach(visit.entries) { e in
                let m = gym.machine(e.machineID)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(m?.name ?? "Machine").font(.subheadline.weight(.bold)).foregroundStyle(ink)
                        if bests.contains(e.machineID) {
                            Text("New best").font(.caption2.weight(.bold)).foregroundStyle(.white)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color(red: 0.85, green: 0.55, blue: 0.0), in: Capsule())
                        }
                    }
                    Text(e.sets.map { s in
                        (s.isWarmup ? "W " : "") + (s.isTime || m?.logs == .reps ? gym.text(s, machine: e.machineID)
                            : "\(s.kg <= 0 ? "BW" : GymSet.number(s.kg)) × \(s.reps)")
                    }.joined(separator: "  ·  "))
                        .font(.footnote).monospacedDigit().foregroundStyle(muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Text("AMS Workout Companion").font(.caption2.weight(.semibold)).foregroundStyle(muted)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(16)
        .frame(width: 390, alignment: .leading)
        .background(Color.white)
        .environment(\.colorScheme, .light)
    }

    private func tile(_ title: String, _ value: String, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(c)
            Text(value).font(.headline).monospacedDigit().foregroundStyle(ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(c.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    /// The picture, drawn at three times the size.
    @MainActor static func render(_ visit: GymVisit, gym: GymLog) -> Image? {
        let r = ImageRenderer(content: VisitShareCard(visit: visit, gym: gym))
        r.scale = 3
        guard let ui = r.uiImage else { return nil }
        return Image(uiImage: ui)
    }
}
