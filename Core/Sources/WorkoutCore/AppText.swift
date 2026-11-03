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
        Release(version: "1.4", date: "3 November 2026", items: [
            "New: more than one gym. The gym's name sits at the top of the gym screen — tap it to switch gym, to make a \"New gym…\" or to \"Rename this gym…\". Each gym has its own machines and its own visits. Everything you had before is now in \"My gym\" (you can rename it). The app opens at the gym you used last.",
            "New: Plan today (you do not have to use it). Tap \"Plan today\", tap the machines in the order you want them, then Save. \"Today's plan\" lists them with numbers and shows Up next, Done, Busy or Skipped.",
            "New: touch and hold a planned machine for Later (to the end of the plan), Skip today (and Back in today's plan), Swap for… or Remove from plan. You can still tap any machine whenever you like. A busy machine is passed over, and Finish ends the plan.",
            "New: \"Done with this machine\" under the sets, from the first set on. With a plan it goes straight to the next planned machine (\"Next: Leg press\"); without one it takes you back to the machines.",
            "New: during the rest, once you have done as many sets as last time, a big \"Next machine\" button appears (with the machine's name when there is a plan).",
            "New: machines for time — treadmill, rowing machine, bike. In the machine form, \"What you log\" is Weight × reps or Time. Time logs minutes, level and incline (%), shown like \"25 min · level 8 · incline 2.5 %\". A new time machine starts at 20 min, level 5. There is no rest ring and no New best for time.",
            "New: \"How did it feel? Next time…\" after the first set. Choose next time's weight and reps (or time, level and incline) and write a note. Next time the machine starts with those numbers (\"Your plan from last time: 45 kg × 15\") and shows your note under \"Last time\". Earlier visits show them too.",
            "New: Instructions photo. In the machine form, \"Instructions\" lets you take or choose a photo of the machine's instruction plate. On the machine screen a small \"Instructions\" picture opens it full screen.",
            "New: after Finish (\"Session done\") you can give the visit a title (suggested: \"Tuesday at My gym\") and write notes. They are saved with Done. Earlier visits show the title, and the pencil on a visit changes its title and notes (Cancel and Save).",
            "New: History — a new plum card under At the gym on the home screen. It lists every gym session and every Sets & reps, Interval and Exercise-list workout you did, newest first, finished or ended early (marked \"ended early\").",
            "New: History has filter chips — All, At the gym, and one for each workout. At the top: this week (sessions, minutes, kilograms lifted, weeks in a row), a line for this month, and a bar chart of minutes per week for the last 8 weeks.",
            "New: tap a workout in History to see its details; the pencil changes its title and notes, and \"Delete from History\" removes it after asking. Tap a gym session to open the visit.",
            "Changed: \"Skip\" during a rest now says \"Skip rest\" — at the gym and in Sets & reps and Interval workouts.",
            "Changed: \"Finish\" at the gym now says \"Finish this session\".",
            "Fixed: correcting or removing a set you had already done, and saving a plan, could close the app. They no longer do.",
        ]),
        Release(version: "1.3", date: "3 November 2026", items: [
            "New: Busy. When someone is on a machine, tap Busy on its photo. The machine turns orange and moves up to a new row, \"Come back to\", at the top of the gym screen — so you remember it once you have done the others.",
            "New: when the machine is free, just tap it. Opening it, or doing a set on it, takes the Busy mark away by itself. A second tap on Busy also takes it away.",
            "New: Finish clears every Busy mark of the day, and a mark left from another day never comes back.",
            "Changed: the machines that are not busy are listed under \"Other machines\" while something is busy; otherwise the gym screen looks as before.",
        ]),
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
        ("Sets & reps", "For one exercise in sets, like push-ups 5 × 20. During the workout you see the set and the reps in large numbers. Tap Done after each set; the rest timer starts by itself. +15 s gives more rest, Skip rest ends the rest early. A finished or ended workout goes into History."),
        ("Exercise lists", "For a list of different exercises, like the ones from your doctor. Each exercise has a name, an amount (\"3 × 10\"), a note on how to do it and, if you like, a photo. During the workout, tap an exercise to tick it off; tap the photo to see it large. When every exercise is ticked, the list says Well done."),
        ("Interval timers", "Rounds of work and rest against the clock, after a 5-second Get ready. Pause stops the clock, Skip rest goes straight to the next part. A finished or ended workout goes into History."),
        ("Sounds and words", "At the start of every set, round and rest the iPhone beeps, vibrates and says what comes next. The last three seconds of a countdown tick. The screen stays on while a workout runs, and the sound plays even with the ring/silent switch on."),
        ("At the gym", "The card at the top of Workouts. The gym's name is at the top of the gym screen: tap it to switch gym, make a \"New gym…\" or \"Rename this gym…\". Each gym has its own machines and visits; the app opens at the gym you used last. At each machine: tap New machine, take a photo, give it a name and, if you like, how it is set up — \"Seat 4, handles 2\". Next time, tap the machine's photo; use the machines in any order, whichever is free. The date is today; the date at the top changes it for an earlier day."),
        ("Plan today", "If you like to know what comes next: tap Plan today, tap the machines in the order you want, then Save. Today's plan shows numbers and Up next, Done, Busy or Skipped. Touch and hold a planned machine for Later, Skip today (and Back in today's plan), Swap for… or Remove from plan. You can still tap any machine you like, busy machines are passed over, and Finish ends the plan."),
        ("Done with this machine", "Under the sets, from the first set on. With a plan it takes you straight to the next planned machine (\"Next: Leg press\"); without one, back to the machines. During the rest, once you have done as many sets as last time, a big \"Next machine\" button does the same."),
        ("Busy machines", "Someone on a machine? Tap Busy on its photo. It turns orange and moves to \"Come back to\" at the top, so you do the other machines first and do not forget it. When it is free, tap the machine — the Busy mark goes by itself. Tap Busy again to take the mark away without opening it. Finish clears every Busy mark."),
        ("Logging a set", "On a machine you see what you did last time, and the weight and reps are already filled in from it. Change what is different with − and + (2.5 kg, 1 rep) or tap the number to type it; 0 kg means body weight. Set done saves the set and starts a 1:30 rest — +15 s for more, Skip rest to go on. Tap a set you did to change or remove it."),
        ("Machines for time", "For a treadmill, rowing machine or bike, choose Time under \"What you log\" in the machine form. You log minutes, level and incline (%) — \"25 min · level 8 · incline 2.5 %\". A new time machine starts at 20 min, level 5. There is no rest ring and no New best for time."),
        ("Next time and notes", "After the first set, \"How did it feel? Next time…\" lets you choose next time's weight and reps (or time, level and incline) and write a note. Next time the machine starts with those numbers (\"Your plan from last time: 45 kg × 15\") and shows your note under \"Last time\". Earlier visits show them too."),
        ("Instructions photo", "In the machine form, \"Instructions\" takes or chooses a photo of the machine's instruction plate. On the machine screen a small \"Instructions\" picture opens it full screen."),
        ("Getting stronger", "When every set last time reached 12 reps, the machine suggests 2.5 kg more. A weight heavier than you ever did on that machine shows New best. Each machine shows its history and a small chart of your heaviest weight per visit. Finish this session shows the whole visit: machines, sets, time, kilograms lifted and the new bests. Then you can give the visit a title (like \"Tuesday at My gym\") and notes, saved with Done; the pencil on an earlier visit changes them. The pencil on a machine changes its photo, name, setting or what it logs, or deletes it with all its sets."),
        ("History", "The plum card under At the gym. Every gym session and every Sets & reps, Interval and Exercise-list workout, newest first — finished or \"ended early\". Chips filter: All, At the gym, or one workout. At the top: this week (sessions, minutes, kilograms lifted, weeks in a row), a line for this month and a bar chart of minutes per week for the last 8 weeks. Tap a workout for its details; the pencil changes its title and notes, and \"Delete from History\" removes it after asking. Tap a gym session to open the visit."),
        ("Making a workout", "Give it a name, pick a colour and choose its type. The numbers change with − and +. For an exercise list, Add exercise adds one; its ••• menu moves it up or down or removes it. Add photo takes a picture from your Photos. Nothing is kept until you tap Save; Cancel leaves everything as it was. Save needs a name — without one it tells you so."),
        ("Where things are kept", "Everything stays on this iPhone. The gym log keeps every visit in every gym, and History keeps your workouts, so you can see last time and your progress. Apple Health is not connected."),
    ]
}
