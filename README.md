# AMS WorkoutCompanion

An iPhone companion for workouts that change from day to day. Three kinds:

| Kind | For | During the workout |
|---|---|---|
| **Sets & reps** | push-ups 5 × 20 | "Set 2 / 5 · 20 reps", a big **Done**, then a rest ring with +15 s and Skip |
| **Exercise list** | the doctor's exercises | a card per exercise — photo, amount, note — ticked off one by one |
| **Interval timer** | 8 × 40 s work / 20 s rest | a countdown ring, Pause, Skip |
| **At the gym** (1.2) | machines in any order, in one or more gyms | a photo tile per machine; last time's weight and reps filled in, Set done, a rest ring, history and new bests; **Busy** (1.3) puts a taken machine in "Come back to"; 1.4: several gyms, an optional **Plan today**, **Done with this machine** (a green **Next ›** beside Set done since 1.5), time machines (treadmill, rower, bike), a note and numbers for next time, an instructions photo, a title and notes per visit; 1.5: per-machine **rest, weight step and "more weight at" reps**, and **Log an earlier day**; 1.6: **exercises without a machine** (push-ups, sit-ups — reps only, "Skip photo", one more rep when every set reached the first); 1.7: **Repeat last visit** plans today like the last visit |
| **Backups** (1.6) | keeping everything safe | Settings → Backups: **Back up now** makes one file (workouts, gym log, history, photos) to save in Files or iCloud Drive; **Restore from a file…** after a check and a question, keeping today's data aside; a weekly copy on the iPhone (newest 4); 1.7: **automatic backup** once a day to a folder you choose (iCloud Drive), newest 7 |
| **History** (1.4, own tab 1.5) | what you did and when | every gym session and every other workout, newest first, with colourful filters, this week as four coloured tiles, month, and minutes per week for 8 weeks |

Version 1.9. The app has three tabs (1.5): Train, History and Settings. Every workout has its own colour and hand-drawn icon from the shared AMS icon hub
([AMS-Icons](https://github.com/marsch124/AMS-Icons)). Settings has How it works, What's new
and the version. Full description: [`docs/specification.md`](docs/specification.md).
Sound, vibration and spoken cues ("Set 2 of 5. 20 reps.", "Rest", "Last round. Go!"),
and the screen stays awake while a workout runs. The gym log (`Documents/gym.json`) and History
(`Documents/history.json`) keep what you did. It starts with three examples: Push-ups,
Intervals and an empty Doctor's exercises.

## How it is built

- `Core/` — Swift package `WorkoutCore`: the workout, the phases it runs through and
  the clock (`Session`, kept as end times so nothing drifts). `swift test --package-path Core`.
- `App/` — SwiftUI, iPhone only, portrait, iOS 17+. Light and dark with the AMS
  page and text colours (`Theme.swift`, same pairs as AMS Packing `docs/colours.md`).
- Workouts live in `Documents/workouts.json`, photos in `Documents/Photos/`, on the
  iPhone only. A file the app cannot read is set aside, never overwritten.
- `project.yml` — XcodeGen. `xcodegen generate`, then open `AMSWorkoutCompanion.xcodeproj`.
- CI on every push: model tests and UI tests on an iPhone simulator (`.github/workflows/tests.yml`).
- TestFlight from GitHub's Mac, no own Mac needed: [`TESTFLIGHT.md`](TESTFLIGHT.md).

The home screen shows the app as **Workouts** — "AMS WorkoutCompanion" is too long
under an icon, and Apple refuses "Companion" (one of its own apps; upload error 90129).
`CFBundleDisplayName` in `project.yml`.

## Not yet

The Apple Watch and Apple Health (the Garmin watch syncs to Health, but the app does not read it). The camera inside the
app is only for gym machines; exercise-list photos come from the Photos library.
