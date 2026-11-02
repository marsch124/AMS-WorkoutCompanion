import Foundation

/// One version in What's new.
public struct Release: Sendable, Equatable {
    public let version: String
    public let date: String
    public let items: [String]
}

/// The words of Settings: What's new (every version, newest first) and How it works.
public enum AppText {
    public static let releases: [Release] = [
        Release(version: "1.1", date: "2 November 2026", items: [
            "New: Settings, from the gear at the top left of Workouts — with How it works, What's new and the version number.",
            "New: every icon is hand-drawn, from the shared AMS icon library — a kettlebell for Sets & reps, a stretching figure for Exercise lists, a stopwatch for Interval timers.",
            "New: the app icon is a white hand-drawn stopwatch on a calm orange background.",
            "Changed: the colours are the fifteen shared AMS colours, in two rows of eight. A workout that had Light blue or Light yellow now shows orange until you pick again.",
            "Changed: Workouts, New workout and the exercise list are more compact — smaller tiles, less space between rows, standard text sizes.",
            "Changed: a new workout has Cancel as well as Save.",
        ]),
        Release(version: "1.0", date: "2 November 2026", items: [
            "The first version: Sets & reps with a rest timer, Exercise lists with a note and a photo per exercise, and Interval timers.",
            "Sound, vibration and spoken words during a workout; the screen stays on.",
            "Three examples to start with: Push-ups, Intervals and Doctor's exercises.",
        ]),
    ]

    public static let howItWorks: [(title: String, text: String)] = [
        ("Workouts", "Your workouts, one card each, in their own colour. Tap a card to start it. The pencil changes it. Touch and hold a card to duplicate or delete it. The + at the top right makes a new one."),
        ("Sets & reps", "For one exercise in sets, like push-ups 5 × 20. During the workout you see the set and the reps in large numbers. Tap Done after each set; the rest timer starts by itself. +15 s gives more rest, Skip ends the rest early."),
        ("Exercise lists", "For a list of different exercises, like the ones from your doctor. Each exercise has a name, an amount (\"3 × 10\"), a note on how to do it and, if you like, a photo. During the workout, tap an exercise to tick it off; tap the photo to see it large. When every exercise is ticked, the list says Well done."),
        ("Interval timers", "Rounds of work and rest against the clock, after a 5-second Get ready. Pause stops the clock, Skip goes straight to the next part."),
        ("Sounds and words", "At the start of every set, round and rest the iPhone beeps, vibrates and says what comes next. The last three seconds of a countdown tick. The screen stays on while a workout runs, and the sound plays even with the ring/silent switch on."),
        ("Making a workout", "Give it a name, pick a colour and choose its type. The numbers change with − and +. For an exercise list, Add exercise adds one; its ••• menu moves it up or down or removes it. Add photo takes a picture from your Photos. Nothing is kept until you tap Save; Cancel leaves everything as it was."),
        ("Where things are kept", "Everything stays on this iPhone. There is no history: the app helps while you exercise and keeps nothing afterwards."),
    ]
}
