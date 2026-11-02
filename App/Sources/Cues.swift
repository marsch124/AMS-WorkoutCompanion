import AVFoundation
import UIKit

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
