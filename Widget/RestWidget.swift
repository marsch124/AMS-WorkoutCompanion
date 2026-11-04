import ActivityKit
import AMSIcons
import SwiftUI
import UIKit
import WidgetKit
import WorkoutCore

/// The rest on the lock screen and in the Dynamic Island (since 1.15): what you rest from,
/// the countdown, a bar filling up, and the next set. When the time is up it says "Go".
@main
struct RestWidgetBundle: WidgetBundle {
    var body: some Widget { RestLiveActivity() }
}

private extension Color {
    static func pair(_ light: UInt32, _ dark: UInt32) -> Color {
        func ui(_ v: UInt32) -> UIColor {
            UIColor(red: CGFloat((v >> 16) & 0xff) / 255, green: CGFloat((v >> 8) & 0xff) / 255,
                    blue: CGFloat(v & 0xff) / 255, alpha: 1)
        }
        let l = ui(light), d = ui(dark)
        return Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? d : l })
    }
}

private extension RestCard {
    /// Gym indigo or workout blue — the same colours as in the app.
    var tint: Color {
        kind == .gym ? .pair(0x4f46e5, 0x9d97ff) : .pair(0x2f6fe0, 0x8db4ff)
    }
    /// In the Dynamic Island the background is always black: the night colours.
    var islandTint: Color { kind == .gym ? Color(red: 0.62, green: 0.59, blue: 1) : Color(red: 0.55, green: 0.71, blue: 1) }
    var range: ClosedRange<Date> { start...max(end, start.addingTimeInterval(1)) }
}

struct RestLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestActivityAttributes.self) { context in
            LockScreenRest(card: context.state.card, over: context.isStale)
                .activityBackgroundTint(nil)
        } dynamicIsland: { context in
            let card = context.state.card
            let over = context.isStale
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        IconMark(.hand("stopwatch"), size: 20, colour: card.islandTint)
                        Text(card.title).font(.headline).lineLimit(1)
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Countdown(card: card, over: over, font: .title2)
                        .foregroundStyle(card.islandTint)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(over ? "Go: \(card.next)" : "Next: \(card.next)")
                            .font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                        RestBar(card: card, over: over, tint: card.islandTint)
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                IconMark(.hand("stopwatch"), size: 16, colour: card.islandTint)
            } compactTrailing: {
                Countdown(card: card, over: over, font: .subheadline)
                    .foregroundStyle(card.islandTint)
                    .frame(maxWidth: 46)
            } minimal: {
                IconMark(.hand("stopwatch"), size: 16, colour: card.islandTint)
            }
            .keylineTint(card.islandTint)
        }
    }
}

/// "1:12" counting down, or "Go" when the rest is over.
private struct Countdown: View {
    let card: RestCard
    let over: Bool
    let font: Font

    var body: some View {
        Group {
            if over {
                Text("Go")
            } else {
                Text(timerInterval: card.range, countsDown: true)
                    .multilineTextAlignment(.trailing)
            }
        }
        .font(font.weight(.semibold).monospacedDigit())
    }
}

/// A thin bar filling up as the rest passes.
private struct RestBar: View {
    let card: RestCard
    let over: Bool
    let tint: Color

    var body: some View {
        if over {
            Capsule().fill(tint).frame(height: 6)
        } else {
            ProgressView(timerInterval: card.range, countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
                .progressViewStyle(.linear)
                .tint(tint)
        }
    }
}

private struct LockScreenRest: View {
    let card: RestCard
    let over: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                IconMark(.hand("stopwatch"), size: 26, colour: card.tint)
                VStack(alignment: .leading, spacing: 1) {
                    Text(over ? "Rest over" : "Rest · \(card.title)")
                        .font(.headline)
                        .lineLimit(1)
                    Text(over ? "Go: \(card.next)" : "Next: \(card.next)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                Countdown(card: card, over: over, font: .title)
                    .foregroundStyle(card.tint)
                    .frame(maxWidth: 110, alignment: .trailing)
            }
            RestBar(card: card, over: over, tint: card.tint)
        }
        .padding(14)
    }
}
