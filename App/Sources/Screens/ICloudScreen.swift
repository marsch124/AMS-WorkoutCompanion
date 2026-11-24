import AMSIcons
import SwiftUI
import WorkoutCore

/// The dot that says how this device stands with iCloud (since 3.0): green = the same on all
/// devices, orange = on its way, grey = iCloud is off here, red = something stands in the way.
struct SyncDot: View {
    let status: SyncStatus
    var size: CGFloat = 9

    static func colour(_ dot: SyncStatus.Dot) -> Color {
        switch dot {
        case .green: return Color(hex: "#16a34a")
        case .orange: return Color(hex: "#ea580c")
        case .grey: return Theme.muted
        case .red: return Theme.problem
        }
    }

    var body: some View {
        Circle()
            .fill(Self.colour(status.dot))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// A rounded tile with one of the app's own hand-drawn marks, like the hub's IconTile.
struct MarkTile: View {
    let mark: AppMark
    let colour: IconColour?
    var size: CGFloat = 28

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(colour?.fillColor ?? Theme.accent)
            .frame(width: size, height: size)
            .overlay(AppMarkView(mark, size: size * 0.68, colour: colour?.inkColor ?? .white))
            .accessibilityHidden(true)
    }
}

/// Settings → iCloud (since 3.0): how this device stands, Sync now, and what the rules are.
struct ICloudScreen: View {
    @Environment(Library.self) private var library
    private static let colour = IconColour.of(key: "green")!

    private var detail: String {
        switch library.syncStatus {
        case .off:
            return "On this device iCloud is signed out, or iCloud Drive is switched off. Switch it on in the Settings app; until then everything stays on this device only."
        case .working:
            return "Fetching what the other devices changed and sending what changed here."
        case .current(let at):
            return "Checked \(at.formatted(date: .omitted, time: .shortened)). Your workouts, gym log, History, photos and sounds are the same on your iPhone, iPad and Mac."
        case .problem:
            return "Nothing is lost: everything on this device stays as it is. Try Sync now; if it stays like this, update the app on all devices."
        }
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 10) {
                    SyncDot(status: library.syncStatus, size: 12)
                    Text(library.syncStatus.words)
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("icloud-status")
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                    .accessibilityIdentifier("icloud-detail")
                if library.syncStatus != .off {
                    Button("Sync now") { library.cloud?.syncNow() }
                        .buttonStyle(BigButtonStyle(fill: Self.colour.fillColor, ink: Self.colour.inkColor, height: 50))
                        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                        .accessibilityIdentifier("icloud-sync-now")
                }
            }
            Section {
                rule("A change on one device shows on the others within about a minute, while the app is open there.")
                rule("Changed on two devices before they met: both changes are kept. Only when it is the very same thing — one machine, one workout, one gym visit — the newest change stays.")
                rule("Deleted on one device means deleted on all. Nothing else ever removes anything.")
                rule("Each device keeps its own full copy, so the app works without a connection.")
            } header: {
                Text("How the devices meet").foregroundStyle(Self.colour.fillColor)
            }
            if let copy = library.beforeICloudCopies().first {
                Section {
                    Text("Kept on \(copy.made.formatted(date: .abbreviated, time: .shortened)), just before this device first met iCloud. It is under Backups, with a Restore button.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.ink)
                        .accessibilityIdentifier("icloud-before-copy")
                } header: {
                    Text("Copy from before iCloud").foregroundStyle(Self.colour.fillColor)
                }
            }
        }
        .readableWidth()
        .scrollContentBackground(.hidden)
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle("iCloud")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func rule(_ words: String) -> some View {
        Text(words).font(.subheadline).foregroundStyle(Theme.ink)
    }
}
