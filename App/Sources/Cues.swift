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

    /// His sound choices (since 1.23), read again each time a workout or the gym opens.
    private(set) var sounds = SoundChoice.load()

    func begin() {
        UIApplication.shared.isIdleTimerDisabled = true
        sounds = SoundChoice.load()
        prepare()
    }

    /// Audio session and sounds ready; also used by the Sounds screen to let him hear a choice.
    private func prepare() {
        guard !quiet else { return }
        // Plays with the silent switch on, alongside his music.
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
        for name in ["tick", "go", "done", "bell", "beep"] where players[name] == nil {
            if let url = Bundle.main.url(forResource: name, withExtension: "wav"),
               let p = try? AVAudioPlayer(contentsOf: url) {
                p.prepareToPlay()
                players[name] = p
            }
        }
    }

    func reload() { sounds = SoundChoice.load() }

    func end() {
        UIApplication.shared.isIdleTimerDisabled = false
        speech.stopSpeaking(at: .immediate)
        guard !quiet else { return }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// The last three seconds of a countdown. With `spoken` the voice counts and the tick stays quiet.
    func countdown(spoken: String? = nil) {
        if let spoken { speak(spoken) } else { play("tick") }
        impact(.medium)
    }

    /// A spoken word of the interval countdown (Three, Two, One, Halfway, Ten seconds).
    func speak(_ words: String) { say(words) }

    /// Start of a set or a work round.
    func go(_ words: String) {
        playRestOver(sounds.restSound)
        notify()
        say(words)
    }

    /// Start of a rest.
    func rest(_ words: String) {
        impact(.heavy)
        say(words)
    }

    /// The whole workout is done.
    func finished(_ words: String) {
        play("done")
        notify()
        say(words)
    }

    /// Lets him hear a "rest over" sound once (Sounds screen).
    func preview(_ sound: RestSound) {
        prepare()
        playRestOver(sound)
    }

    /// Lets him feel a vibration choice once (Sounds screen).
    func preview(_ buzz: Buzz) {
        switch buzz {
        case .strong: UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .light: UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .off: break
        }
    }

    private func playRestOver(_ sound: RestSound) {
        switch sound {
        case .chime: play("go")
        case .bell: play("bell")
        case .beep: play("beep")
        case .none: break
        }
    }

    /// A buzz that follows his vibration choice: strong as before, light as a light tap, or none.
    private func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        switch sounds.buzz {
        case .strong: UIImpactFeedbackGenerator(style: style).impactOccurred()
        case .light: UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .off: break
        }
    }

    private func notify() {
        switch sounds.buzz {
        case .strong: UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .light: UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .off: break
        }
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
            switch SoundChoice.load().restSound {
            case .chime: content.sound = .default
            case .bell: content.sound = UNNotificationSound(named: UNNotificationSoundName("bell.wav"))
            case .beep: content.sound = UNNotificationSound(named: UNNotificationSoundName("beep.wav"))
            case .none: content.sound = nil
            }
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

extension SoundChoice {
    private static let key = "sounds"

    /// His saved choices; the old sounds when nothing is saved.
    static func load() -> SoundChoice {
        guard let data = UserDefaults.standard.data(forKey: key),
              let c = try? JSONDecoder().decode(SoundChoice.self, from: data) else { return SoundChoice() }
        return c
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) { UserDefaults.standard.set(data, forKey: Self.key) }
        Task { @MainActor in Cues.shared.reload() }
    }
}

extension IntervalPreset {
    private static let key = "intervalPresets"

    /// His own saved presets.
    static func mine() -> [IntervalPreset] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let list = try? JSONDecoder().decode([IntervalPreset].self, from: data) else { return [] }
        return list
    }

    static func saveMine(_ list: [IntervalPreset]) {
        if let data = try? JSONEncoder().encode(list) { UserDefaults.standard.set(data, forKey: key) }
    }
}
