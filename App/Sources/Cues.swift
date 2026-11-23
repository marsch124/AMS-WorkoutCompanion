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

    /// Tells the cues when a word or a sound has finished, so the music can come back up (since 2.0).
    private final class Finisher: NSObject, AVSpeechSynthesizerDelegate, AVAudioPlayerDelegate {
        var finished: (() -> Void)?
        func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) { finished?() }
        func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel u: AVSpeechUtterance) { finished?() }
        func audioPlayerDidFinishPlaying(_ p: AVAudioPlayer, successfully: Bool) { finished?() }
    }
    private let finisher = Finisher()
    /// Words and sounds playing right now; the audio session stays ducked only while this is above 0.
    private var busy = 0
    private var releasing: Task<Void, Never>?

    let quiet = ProcessInfo.processInfo.arguments.contains("-uitest")
    private let speech = AVSpeechSynthesizer()
    private var players: [String: AVAudioPlayer] = [:]

    /// His sound choices (since 1.23), read again each time a workout or the gym opens.
    private(set) var sounds = SoundChoice.load()

    private init() {
        speech.delegate = finisher
        finisher.finished = { [weak self] in
            Task { @MainActor in self?.cueFinished() }
        }
    }

    /// His music dips and a word or sound plays over it (since 2.0). Needs a matching `cueFinished()`.
    private func cueStarted() {
        releasing?.cancel()
        busy += 1
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default,
                                 options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
        try? session.setActive(true)
    }

    /// The word or sound is over: when nothing else plays, the music goes back up.
    private func cueFinished() {
        busy = max(0, busy - 1)
        guard busy == 0 else { return }
        releasing?.cancel()
        // A short pause, so Three, Two, One do not make the music pump up and down between words.
        releasing = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled, self.busy == 0 else { return }
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    func begin() {
        UIApplication.shared.isIdleTimerDisabled = true
        busy = 0
        sounds = SoundChoice.load()
        prepare()
    }

    /// Audio session and sounds ready; also used by the Sounds screen to let him hear a choice.
    private func prepare() {
        guard !quiet else { return }
        // The audio session is only opened while a word or sound plays (see cueStarted),
        // so his music keeps its full volume the rest of the time.
        for name in ["tick", "go", "done", "bell", "beep", "restend"] where players[name] == nil {
            if let url = Bundle.main.url(forResource: name, withExtension: "wav"),
               let p = try? AVAudioPlayer(contentsOf: url) {
                p.delegate = finisher
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
        releasing?.cancel()
        busy = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// The last three seconds of a countdown. With `spoken` the voice counts and the tick stays quiet.
    func countdown(spoken: String? = nil) {
        if let spoken { speak(spoken) } else { play("tick") }
        impact(.medium)
    }

    /// A mark of the rest countdown (since 2.0): Thirty seconds, Twenty, Ten, Three, Two, One.
    /// With the spoken countdown off, the last three marks tick as before and the others stay quiet.
    func restMark(_ mark: Int) {
        if sounds.spokenCountdown, let words = RestCuePlan.words(for: mark) {
            speak(words)
            if mark <= 3 { impact(.medium) }
        } else if mark <= 3 {
            countdown()
        }
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
        case .soft: play("restend")
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
        cueStarted()
        let u = AVSpeechUtterance(string: words)
        u.voice = AVSpeechSynthesisVoice(language: "en-US")
        u.rate = AVSpeechUtteranceDefaultSpeechRate
        speech.speak(u)
    }

    private func play(_ name: String) {
        guard !quiet, let p = players[name] else { return }
        // A sound cut short by itself never reports "finished", so it is not counted twice.
        if !p.isPlaying { cueStarted() }
        p.currentTime = 0
        if !p.play() { cueFinished() }
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
            case .soft: content.sound = UNNotificationSound(named: UNNotificationSoundName("restend.wav"))
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

/// The changes of step of a Tailored intervals workout as phone notifications (since 2.3), so a jog
/// or a walk is marked on a locked iPhone or while another app is open, where the voice cannot speak.
/// All coming changes are set at once and set again after Pause, Resume and Skip.
@MainActor
enum StepAlarms {
    private static let ids = (0...IntervalStep.most).map { "step-\($0)" }
    private static var asked = false

    static func set(_ notices: [StepNotice]) {
        let centre = UNUserNotificationCenter.current()
        centre.removePendingNotificationRequests(withIdentifiers: ids)
        centre.removeDeliveredNotifications(withIdentifiers: ids)
        guard !notices.isEmpty, !Cues.shared.quiet else { return }
        let schedule = {
            let sound: UNNotificationSound?
            switch SoundChoice.load().restSound {
            case .soft: sound = UNNotificationSound(named: UNNotificationSoundName("restend.wav"))
            case .chime: sound = .default
            case .bell: sound = UNNotificationSound(named: UNNotificationSoundName("bell.wav"))
            case .beep: sound = UNNotificationSound(named: UNNotificationSoundName("beep.wav"))
            case .none: sound = nil
            }
            for (i, notice) in notices.prefix(ids.count).enumerated() where notice.after > 1 {
                let content = UNMutableNotificationContent()
                content.title = notice.title
                content.body = notice.body
                content.sound = sound
                content.interruptionLevel = .timeSensitive
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: notice.after, repeats: false)
                centre.add(UNNotificationRequest(identifier: ids[i], content: content, trigger: trigger))
            }
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
