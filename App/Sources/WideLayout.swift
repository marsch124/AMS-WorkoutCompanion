import AMSIcons
import SwiftUI
import WorkoutCore

// Version 3.0: the wide look (iPad, and the iPad app on the Mac). Everything here is behind
// `horizontalSizeClass == .regular`; the iPhone (compact width) never takes these paths.

/// Keeps a page's content in a comfortable reading column on a wide screen, centred; does nothing on the phone.
struct ReadableWidth: ViewModifier {
    @Environment(\.horizontalSizeClass) private var sizeClass
    var limit: CGFloat

    func body(content: Content) -> some View {
        if sizeClass == .regular {
            content.frame(maxWidth: limit).frame(maxWidth: .infinity)
        } else {
            content
        }
    }
}

extension View {
    /// At most `limit` points wide and centred when the window is wide; unchanged on the phone.
    func readableWidth(_ limit: CGFloat = 680) -> some View { modifier(ReadableWidth(limit: limit)) }
}

/// The side list's four rows and its place on the screen.
enum SideRow: String, CaseIterable {
    case workouts, gym, history, settings
}

/// The left side list of the wide look (his pick: "Side list"): four rows and the iCloud dot at the foot.
struct SideList: View {
    @Environment(Library.self) private var library
    @Binding var selection: SideRow

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Workouts")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.muted)
                .padding(.horizontal, 10)
                .padding(.bottom, 6)
                .accessibilityAddTraits(.isHeader)
            row(.workouts, "Workouts", id: "side-workouts", colour: Gym.busyTint, tile: IconColour.of(key: "orange")!) { c in
                IconMark(.hand("kettlebell"), size: 19, colour: c)
            }
            row(.gym, "At the gym", id: "side-gym", colour: Gym.tint, tile: Gym.swatch) { c in
                IconMark(.hand(library.gym.homeIcon ?? "gym"), size: 19, colour: c)
            }
            row(.history, "History", id: "side-history", colour: Past.tint, tile: Past.swatch) { c in
                AppMarkView(.history, size: 19, colour: c)
            }
            row(.settings, "Settings", id: "side-settings", colour: Color.pair("#475569", "#cbd5e1"),
                tile: IconColour.of(key: "slate")!) { c in
                ControlMarkView(.settings, size: 19, colour: c)
            }
            Spacer(minLength: 12)
            syncLine
        }
        .padding(.horizontal, 10)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .frame(width: 216)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.card.ignoresSafeArea())
        .overlay(alignment: .trailing) {
            Rectangle().fill(Theme.line).frame(width: 1).ignoresSafeArea()
        }
    }

    private func row<M: View>(_ r: SideRow, _ title: String, id: String, colour: Color, tile: IconColour,
                              @ViewBuilder mark: (Color) -> M) -> some View {
        let on = selection == r
        let pill = colour
        return Button { selection = r } label: {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 28 * 0.28, style: .continuous).fill(tile.fillColor)
                    mark(tile.inkColor)
                }
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(on ? pill : Theme.ink)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 9)
            .background(on ? pill.opacity(0.14) : .clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(on ? .isSelected : [])
        .accessibilityIdentifier(id)
    }

    private var syncLine: some View {
        let status = library.syncStatus
        return HStack(spacing: 7) {
            SyncDot(status: status)
            Text(status.words)
                .font(.footnote)
                .foregroundStyle(Theme.muted)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(status.words)
        .accessibilityIdentifier("sync-status")
    }
}
