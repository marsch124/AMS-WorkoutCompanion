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
        Release(version: "1.2", date: "3 November 2026", items: [
            "New: At the gym — the card at the top of Workouts. For a gym where you use machines in whatever order they come free.",
            "New: at a new machine, the camera opens; then you give it a name and, if you like, how it is set up (\"Seat 4, handles 2\"). The date is today by itself; the date at the top changes it.",
            "New: each machine is a photo tile. Tap whichever is free. A tick shows the machines done today; the line under it says how many sets, or the weight last time.",
            "New: on a machine you see its photo (tap to enlarge), its setting, and what you did last time. Weight and reps are filled in from last time, so a set is usually one tap on Set done. − and + change the weight by 2.5 kg and the reps by 1; tap a number to type it. 0 kg means body weight.",
            "New: Set done starts a 1:30 rest with a ring, +15 s and Skip, and a beep and spoken words when the next set starts. Tap a set you did to change or remove it.",
            "New: when every set last time reached 12 reps, the machine suggests 2.5 kg more. A weight heavier than ever before shows New best.",
            "New: every machine keeps its history, with a small chart of your heaviest weight per visit.",
            "New: Finish shows what the visit came to — machines, sets, time, kilograms lifted in all, and the new bests. Earlier visits are listed under the machines.",
            "Changed: Save is now a full-colour button. With no name yet it stays blue and says \"Give it a name first\" instead of being greyed out.",
            "Fixed: two buttons had no name for the app's tests (Cancel on New workout, End workout); now they do.",
        ]),
        Release(version: "1.1", date: "2 November 2026", items: [
            "New: Settings, from the gear at the top left of Workouts — with How it works, What's new and the version number.",
            "New: every icon is hand-drawn, from the shared AMS icon library — a kettlebell for Sets & reps, a stretching figure for Exercise lists, a stopwatch for Interval timers.",
            "New: the marks on the buttons (Done, Skip, Pause, Close, Add, Edit…) are hand-drawn too, from the same shared library.",
            "New: the app icon is a white hand-drawn stopwatch on a calm orange background.",
            "Changed: the colours are the fifteen shared AMS colours, in two rows of eight. A workout that had Light blue or Light yellow now shows orange until you pick again.",
            "Changed: Workouts, New workout and the exercise list are more compact — smaller tiles, less space between rows, standard text sizes.",
            "Changed: a new workout has Cancel as well as Save.",
            "Changed: the name under the app icon is now Workouts. It was Companion, which Apple keeps for one of its own apps.",
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
        ("At the gym", "The card at the top of Workouts. At each machine: tap New machine, take a photo, give it a name and, if you like, how it is set up — \"Seat 4, handles 2\". Next time, tap the machine's photo; use the machines in any order, whichever is free. The date is today; the date at the top changes it for an earlier day."),
        ("Logging a set", "On a machine you see what you did last time, and the weight and reps are already filled in from it. Change what is different with − and + (2.5 kg, 1 rep) or tap the number to type it; 0 kg means body weight. Set done saves the set and starts a 1:30 rest — +15 s for more, Skip to go on. Tap a set you did to change or remove it."),
        ("Getting stronger", "When every set last time reached 12 reps, the machine suggests 2.5 kg more. A weight heavier than you ever did on that machine shows New best. Each machine shows its history and a small chart of your heaviest weight per visit. Finish shows the whole visit: machines, sets, time, kilograms lifted and the new bests. The pencil on a machine changes its photo, name or setting, or deletes it with all its sets."),
        ("Making a workout", "Give it a name, pick a colour and choose its type. The numbers change with − and +. For an exercise list, Add exercise adds one; its ••• menu moves it up or down or removes it. Add photo takes a picture from your Photos. Nothing is kept until you tap Save; Cancel leaves everything as it was. Save needs a name — without one it tells you so."),
        ("Where things are kept", "Everything stays on this iPhone. The gym log keeps every visit, so you can see last time and your progress; the other workouts keep nothing afterwards."),
    ]
}
