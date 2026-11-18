import ActivityKit
import AMSIcons
import SwiftUI
import UserNotifications
import WorkoutCore

// New in 1.23: the pills for effort and feel, opening hours, Settings → Reminder and stretch,
// the session on the lock screen and the gym reminder.

/// A row of equal pills, one chosen: full colour when chosen, an outline otherwise.
struct ChoicePills<Value: Hashable>: View {
    /// Value, words, and the end of the identifier.
    let options: [(Value, String, String)]
    let chosen: Value?
    let id: String
    let fill: Color
    let ink: Color
    let tint: Color
    let pick: (Value) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(options, id: \.0) { value, title, key in
                let on = value == chosen
                Button { pick(value) } label: {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .foregroundStyle(on ? ink : tint)
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                        .background(on ? AnyShapeStyle(fill) : AnyShapeStyle(Color.clear), in: Capsule())
                        .overlay(Capsule().stroke(fill, lineWidth: on ? 0 : 1))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(title)
                .accessibilityAddTraits(on ? .isSelected : [])
                .accessibilityIdentifier("\(id)-\(key)")
            }
        }
    }
}

extension GymLog {
    /// "None" for the stretch after a session: the Stretch now button is hidden.
    static let noStretch = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
}

// MARK: Opening hours

struct HoursResult {
    var value: [DayHours?]?
}

/// The gym's opening hours, day by day (since 1.23). Nothing is kept until Save.
struct HoursForm: View {
    let gym: GymPlace
    let done: (HoursResult?) -> Void

    private struct Day {
        var open = false
        var from = HoursForm.time(6 * 60)
        var to = HoursForm.time(22 * 60)
    }
    @State private var days: [Day] = Array(repeating: Day(), count: 7)
    @State private var loaded = false

    private static func time(_ minutes: Int) -> Date {
        Calendar.current.date(bySettingHour: min(23, minutes / 60), minute: minutes >= 1440 ? 59 : minutes % 60, second: 0, of: Date()) ?? Date()
    }
    private static func minutes(_ date: Date) -> Int {
        Calendar.current.component(.hour, from: date) * 60 + Calendar.current.component(.minute, from: date)
    }

    var body: some View {
        Form {
            Section {
                ForEach(0..<7, id: \.self) { i in
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle(GymPlace.dayNames[i], isOn: $days[i].open)
                            .tint(Gym.fill)
                            .accessibilityIdentifier("hours-day-\(i + 1)")
                        if days[i].open {
                            HStack {
                                DatePicker("From", selection: $days[i].from, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                    .accessibilityIdentifier("hours-from-\(i + 1)")
                                Text("to").foregroundStyle(Theme.muted)
                                DatePicker("To", selection: $days[i].to, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                    .accessibilityIdentifier("hours-to-\(i + 1)")
                                Spacer()
                            }
                        } else {
                            Text("Closed").font(.subheadline).foregroundStyle(Theme.muted)
                        }
                    }
                    if i == 0 {
                        // Right under Monday, where it is used — not below the last day.
                        Button("Same as Monday for every day") {
                            for d in 1..<7 { days[d] = days[0] }
                        }
                        .foregroundStyle(Gym.tint)
                        .accessibilityIdentifier("hours-copy")
                    }
                }
            } header: {
                Text(gym.name)
            } footer: {
                Text("With hours given, the gym screen and the At the gym card say whether it is open now and when it closes. All days closed takes the hours away.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle("Opening hours")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard !loaded else { return }
            loaded = true
            if let hours = gym.hours, hours.count == 7 {
                days = hours.map { h in
                    h.map { Day(open: true, from: Self.time($0.open), to: Self.time($0.close)) } ?? Day()
                }
            }
        }
        .bottomActions(cancel: { done(nil) }, save: {
            let hours: [DayHours?] = days.map { d in
                let a = Self.minutes(d.from), b = Self.minutes(d.to)
                return d.open && b > a ? DayHours(open: a, close: b) : nil
            }
            done(HoursResult(value: hours))
        }, tint: Gym.fill, cancelID: "hours-cancel", saveID: "hours-save")
    }
}

// MARK: Settings → Reminder and stretch

/// The gym reminder after days without a visit, and which list is the stretch after a session
/// (since 1.23). Nothing is kept until Save.
struct GymExtrasScreen: View {
    @Environment(Library.self) private var library
    @Environment(\.dismiss) private var dismiss
    @State private var remind = true
    @State private var days = GymLog.usualNudgeDays
    @State private var stretch: UUID?
    @State private var loaded = false

    private var lists: [Workout] { library.workouts.filter { $0.kind == .checklist } }

    var body: some View {
        Form {
            Section {
                Toggle("Remind me to go", isOn: $remind)
                    .tint(Gym.fill)
                    .accessibilityIdentifier("extras-remind")
                if remind {
                    Stepper(value: $days, in: 2...14) {
                        HStack {
                            Text("After")
                            Spacer()
                            Text("\(days) days without the gym")
                                .foregroundStyle(Gym.tint)
                                .monospacedDigit()
                                .accessibilityIdentifier("extras-days-value")
                        }
                    }
                    .accessibilityIdentifier("extras-days")
                }
            } header: {
                Text("Gym reminder")
            } footer: {
                Text("The phone reminds you at 10:00 on that day. A visit before then moves the reminder on.")
            }
            Section {
                Picker("Stretch list", selection: $stretch) {
                    Text("After-gym stretch (the app's own)").tag(UUID?.none)
                    ForEach(lists) { w in
                        Text(w.name.isEmpty ? "Exercise list" : w.name).tag(UUID?.some(w.id))
                    }
                    Text("None").tag(UUID?.some(GymLog.noStretch))
                }
                .pickerStyle(.inline)
                .labelsHidden()
                .tint(Gym.fill)
                .accessibilityIdentifier("extras-stretch")
            } header: {
                Text("Stretch after a session")
            } footer: {
                Text("The Session done page offers \"Stretch now\" with this list. The app's own list is made the first time you use it and is then yours to change. None hides the button.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle("Reminder and stretch")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            guard !loaded else { return }
            loaded = true
            remind = library.gym.nudgeAfter > 0
            days = remind ? min(14, max(2, library.gym.nudgeAfter)) : GymLog.usualNudgeDays
            let id = library.gym.stretchID
            stretch = id == GymLog.noStretch || lists.contains { $0.id == id } ? id : nil
        }
        .bottomActions(cancel: { dismiss() }, save: {
            let n = remind ? days : 0, s = stretch
            library.changeGym {
                $0.nudgeDays = n == GymLog.usualNudgeDays ? nil : n
                $0.stretchID = s
            }
            GymNudge.sync(library.gym)
            dismiss()
        }, tint: Gym.fill, cancelID: "extras-cancel", saveID: "extras-save")
    }
}

// MARK: The session on the lock screen

/// The gym session on the lock screen and in the Dynamic Island (since 1.23): one at a time.
/// Every change to the gym log brings it up to date; with no session going it ends.
@MainActor
enum SessionLive {
    private static var shown: SessionCard?

    static func sync(_ gym: GymLog) {
        guard !Cues.shared.quiet else { return }
        let now = Date()
        var card = gym.sessionCard(on: now, gym: gym.currentGym?.id, now: now)
        // The start moves a little with every reading; keep the one on show unless it truly changed.
        if var c = card, let s = shown, abs(c.start.timeIntervalSince(s.start)) < 2 {
            c.start = s.start
            card = c
        }
        guard card != shown else { return }
        shown = card
        guard let card else {
            for activity in Activity<SessionActivityAttributes>.activities {
                Task { await activity.end(nil, dismissalPolicy: .immediate) }
            }
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let content = ActivityContent(state: SessionActivityAttributes.ContentState(card: card), staleDate: card.pauseAt)
        if let current = Activity<SessionActivityAttributes>.activities.first {
            Task { await current.update(content) }
        } else {
            _ = try? Activity.request(attributes: SessionActivityAttributes(), content: content, pushType: nil)
        }
    }
}

// MARK: The gym reminder

/// "4 days since your last gym visit" at 10:00 (since 1.23): one reminder, moved on by every visit.
@MainActor
enum GymNudge {
    private static let id = "gym-nudge"

    static func sync(_ gym: GymLog) {
        let centre = UNUserNotificationCenter.current()
        centre.removePendingNotificationRequests(withIdentifiers: [id])
        guard !Cues.shared.quiet, let at = gym.nudgeDate(now: Date()) else { return }
        let days = gym.nudgeAfter
        centre.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Time for the gym?"
            content.body = "\(days) days since your last gym visit."
            content.sound = .default
            let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: at)
            let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            centre.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        }
    }
}
