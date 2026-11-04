import ActivityKit
import AVFoundation
import UIKit
import UserNotifications
import WorkoutCore

/// Sound, vibration and spoken words during a workout, and the screen kept awake.
/// UI tests start the app with -uitest, which keeps it silent.
@MainActor
final class Cues {
    static let shared = Cues()

    let quiet = ProcessInfo.processInfo.arguments.contains("-uitest")
    private let speech = AVSpeechSynthesizer()
    private var players: [String: AVAudioPlayer] = [:]

    func begin() {
        UIApplication.shared.isIdleTimerDisabled = true
        guard !quiet else { return }
        // Plays with the silent switch on, alongside his music.
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
        for name in ["tick", "go", "done"] where players[name] == nil {
            if let url = Bundle.main.url(forResource: name, withExtension: "wav"),
               let p = try? AVAudioPlayer(contentsOf: url) {
                p.prepareToPlay()
                players[name] = p
            }
        }
    }

    func end() {
        UIApplication.shared.isIdleTimerDisabled = false
        speech.stopSpeaking(at: .immediate)
        guard !quiet else { return }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// The last three seconds of a countdown.
    func countdown() {
        play("tick")
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// Start of a set or a work round.
    func go(_ words: String) {
        play("go")
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        say(words)
    }

    /// Start of a rest.
    func rest(_ words: String) {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        say(words)
    }

    /// The whole workout is done.
    func finished(_ words: String) {
        play("done")
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        say(words)
    }

    /// A tick on the exercise list.
    func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func say(_ words: String) {
        guard !quiet else { return }
        speech.stopSpeaking(at: .word)
        let u = AVSpeechUtterance(string: words)
        u.voice = AVSpeechSynthesisVoice(language: "en-US")
        u.rate = AVSpeechUtteranceDefaultSpeechRate
        speech.speak(u)
    }

    private func play(_ name: String) {
        guard !quiet, let p = players[name] else { return }
        p.currentTime = 0
        p.play()
    }
}

/// The end of a rest as a phone notification, so it buzzes and shows on a locked iPhone or while
/// another app is open (since 1.8). With the app in front the app's own sound plays instead.
/// Asks for permission the first time a rest starts; UI tests stay silent.
@MainActor
enum RestAlarm {
    private static let id = "rest-over"
    private static var asked = false

    /// One alarm at a time: a new rest, +15 s or a skip replaces or removes the last one.
    static func set(_ end: Date?, _ words: String) {
        let centre = UNUserNotificationCenter.current()
        centre.removePendingNotificationRequests(withIdentifiers: [id])
        centre.removeDeliveredNotifications(withIdentifiers: [id])
        guard let end, !Cues.shared.quiet else { return }
        let seconds = end.timeIntervalSinceNow
        guard seconds > 1 else { return }
        let schedule = {
            let content = UNMutableNotificationContent()
            content.title = "Rest over"
            content.body = words
            content.sound = .default
            content.interruptionLevel = .timeSensitive
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
            centre.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        }
        if asked {
            schedule()
        } else {
            asked = true
            centre.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                if granted { Task { @MainActor in schedule() } }
            }
        }
    }
}

/// The rest on the lock screen and in the Dynamic Island (since 1.15): one at a time.
/// A new rest updates it, a skipped or finished rest ends it. The time ticks on by itself,
/// even while the app sleeps; at the end it says "Go" until the app ends it.
@MainActor
enum RestLive {
    private static var current: Activity<RestActivityAttributes>? {
        Activity<RestActivityAttributes>.activities.first
    }

    /// True while the phone holds a rest on the lock screen.
    static var isShowing: Bool {
        Activity<RestActivityAttributes>.activities.contains { $0.activityState == .active || $0.activityState == .stale }
    }

    static func show(_ card: RestCard?) {
        guard let card, card.end.timeIntervalSinceNow > 1 else {
            end()
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let content = ActivityContent(state: RestActivityAttributes.ContentState(card: card), staleDate: card.end)
        if let current {
            Task { await current.update(content) }
        } else {
            _ = try? Activity.request(attributes: RestActivityAttributes(), content: content, pushType: nil)
        }
    }

    /// Ends every rest on the lock screen — also one left over from before the app was closed.
    static func end() {
        for activity in Activity<RestActivityAttributes>.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }
}
