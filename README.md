# AMS WorkoutCompanion

An iPhone companion for workouts that change from day to day. Three kinds:

| Kind | For | During the workout |
|---|---|---|
| **Sets & reps** | push-ups 5 × 20 | "Set 2 / 5 · 20 reps", a big **Done**, then a rest ring with +15 s and Skip |
| **Exercise list** | the doctor's exercises | a card per exercise — photo, amount, note — ticked off one by one |
| **Interval timer** | 8 × 40 s work / 20 s rest | a countdown ring, Pause, Skip |

Every workout has its own colour and hand-drawn icon from the shared AMS icon hub
([AMS-Icons](https://github.com/marsch124/AMS-Icons)). Settings has How it works, What's new
and the version. Full description: [`docs/specification.md`](docs/specification.md).
Sound, vibration and spoken cues ("Set 2 of 5. 20 reps.", "Rest", "Last round. Go!"),
and the screen stays awake while a workout runs. No history: it helps during the
workout and keeps nothing afterwards. It starts with three examples: Push-ups,
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

## Not in version 1

The Apple Watch, history, Apple Health, the camera inside the app (photos come from
the Photos library — take the picture of the doctor's sheet with the Camera first).
