# AMS WorkoutCompanion — specification

Version 1.6. iPhone only, portrait, iOS 17+, light and dark. The name under the app icon is "Workouts" (not "Companion": Apple refuses it, error 90129).

## Workouts (home, since 1.5: three tabs)
- A tab bar at the bottom with hand-drawn marks: Train, History, Settings. Train keeps its place when switching tabs (the gym screen stays where you were); History and Settings open fresh each time their tab is chosen. The Train tab is headed "Workout Companion"; the name under the app icon stays "Workouts".
- Train: a wide full-colour indigo "At the gym" tile at the top; below it one full-colour tile per workout in two columns: hand-drawn icon on the workout's colour, name, one-line summary, a play mark, a pencil at the top right; then a dashed "New workout" tile.
- Tap the tile: the workout starts (full screen). Pencil: the editor. Touch and hold: Edit, Duplicate, Delete (Delete asks first). + (top right) also makes a new workout.
- History is its own tab (no longer a card among the workouts). Settings is a tab: no Done button, and the gear at the top left is gone.
- A fresh install has three starters: Push-ups (Sets & reps, 5 × 20, rest 1:30, orange), Intervals (8 × 0:40 work / 0:20 rest, green), Doctor's exercises (Exercise list, empty, pink).
- Summaries: `5 × 20 · rest 1:30`; `8 × 0:40 work / 0:20 rest · 7:40`; `No exercises yet` / `1 exercise` / `4 exercises`.

## At the gym (since 1.2)
- A wide tile "At the gym" at the top of the Train tab (a card at the top of Workouts before 1.5) (hand-drawn "strength" icon, indigo — the gym log's colour for its headings, buttons and marks). Its line: "Today: n machines · n sets", else "n machines", else "Photo, weight and reps per machine". The screen stays on while at the gym.
- Gym screen: "Today". Since 1.5 there is no date at the top right: the day is always today. "Log an earlier day…" in the gym-name menu opens a calendar (no future days; Cancel and Done); while an earlier day is chosen an orange bar "Logging for Saturday 31 October" with "Back to today" shows, and sets go to the visit on that day. Two columns of machine tiles in the order they were made: photo (or the strength mark), name, and "n sets done" (indigo, with a tick and an indigo border) or "Last: 30 kg" or "New". A dashed add tile, since 1.6 "New machine or exercise" ("New machine" before). Finish this session (full indigo, since 1.4; "Finish" before) once the day has a set. "Earlier visits", newest first: date, "n machines · n sets" → the visit: each machine's sets and "n sets · n kg lifted in all".
- Busy (since 1.3): every machine tile has a small "Busy" pill at the top left of its photo (hand-drawn stopwatch; orange outline). Tap it: the pill turns full orange, the tile gets an orange border and the line "Busy — come back later", and the machine moves to a row "Come back to" (orange heading) above the others, in the order marked; the rest are then headed "Other machines". Tap the pill again: the mark goes. Tapping a busy machine opens it and takes the mark away; a set done on it does too. Finish clears every mark of that day; marking a machine drops marks from other days. Deleting a machine removes its mark. Marks are kept in gym.json, so they survive closing the app.
- New machine or exercise: the camera opens first (the photo library when there is no camera; UI tests skip it). Since 1.6 a "Skip photo" button (`machine-skip-photo`) on the camera goes straight to the form without a photo; the tile then shows the hand-drawn strength mark. Then the machine form: photo (Take photo / Take photo again, Choose from Photos), Name, How it is set up (shown on the machine). Cancel and Save; since 1.5, for weight machines, a section "On this machine" (see below); Save without a name says "Give it a name first." After Save the machine opens straight away.
- Machine screen: photo (tap: full screen), setting in indigo, "Last time, 27 Oct: 30 kg × 12, 12, 10" or "First time on this machine.", the suggestion, today's sets (tap one: change weight/reps or Remove set, with Cancel and Save), then "Set n" with weight (− / + the machine's weight step, usual 2.5 kg, type with a decimal pad; 0 = body weight) and reps (− / + 1, ≥ 1), and Set done. Pencil: edit or delete the machine (asks; deletes its sets too).
- The next set's numbers: the set just done on this machine today; else last time's first set — with one weight step more (usual 2.5 kg) and two reps fewer than the machine's "More weight at" number (usual 12, so 10) when every set last time reached it ("Try 45 kg — every set last time reached 10 reps"); else 20 kg × 10.
- Set done: saved at once, a tap, "Rest" spoken, the machine's rest (usual 1:30; with rest set to none no ring and it goes straight on to the next set) as a ring with +15 s and Skip rest ("Skip" before 1.4); the last three seconds tick; at the end a tone and "Set n". "New best" (trophy) when the weight is heavier than any earlier visit on that machine.
- History: a line chart of the heaviest weight per visit (from two visits) and a row per visit, newest first.
- Finish this session: "Session done" (was "Workout done" before 1.4) with Well done (a trophy when there are new bests), Machines, Sets, Time (first set → Finish, in minutes), Lifted in all (Σ kg × reps) and New bests per machine. Done closes it.
- Words: "30 kg × 12", "Body weight × 15"; an entry "30 kg × 12, 12, 10", or "30 × 12, 32.5 × 8 kg" when the weight changes.

### On this machine (since 1.5)
- Machine form, weight machines only, section "On this machine": Rest after each set (none = 0, up to 5:00, 15 s steps; usual 1:30), Weight step (1, 2.5 or 5 kg; usual 2.5) and "More weight at" N reps (3–50; usual 12).
- The step is used by − / + on the machine and in "Next time" and by the suggestion. When every set last time reached N reps, the next time suggests one step more with N − 2 reps. With rest none, Set done goes straight on to the next set.
- Machines not changed keep 1:30, 2.5 kg and 12 reps.

### Exercises without a machine (since 1.6)
- Machine form, "What you log": Weight × reps, Time or **Reps only** (`logs` = `reps`) — push-ups, sit-ups, pull-ups. The form is titled "New exercise" / "Edit exercise" and the delete button says "Delete exercise". Section "This exercise": Rest (none–5:00, 15 s steps, usual 1:30). No Weight step and no "More weight at". A new reps-only exercise starts at 10 reps (no weight); an existing machine keeps its sets.
- Exercise screen: only reps (− / + 1, ≥ 1, or typed); sets are stored with `kg` 0. The set editor and "Next time" ask for reps only. Rest ring after Set done as for weight machines.
- Suggestion: when every set last time reached the first set's reps, one rep more — "Try 16 reps — every set last time reached 15"; else last time's first set. "New best" = the most reps in one set on that exercise. The history chart (from two visits) is in reps (axis "reps").
- Words: a set "12 reps"; an entry "15, 15, 12 reps"; gym tile status "Last: 15 reps" (or "n sets done" today). Plan today, Busy, Next ›, notes, Next time and visit history work as for machines.
- A plank: choose Time and turn "Has a level" and "Has an incline" off.
- Kilograms: a visit or week with no weight shows no "0 kg" — the "Lifted" tile and month kilograms in History, the visit page footer and "Lifted in all" in the Finish summary are hidden when the total is 0.

### Gyms (since 1.4)
- The gym's name is a button at the top of the gym screen. Tap: the list of gyms (a tick on the current one), "New gym…" (asks for a name) and "Rename this gym…". Each gym has its own machines, visits, busy marks and plan; nothing is shared between gyms.
- Everything made before 1.4 is moved into one gym called "My gym" (renameable). The app opens at the gym used last (`currentGym`).

### Plan today (since 1.4, optional)
- Each gym has its own plan (since 1.6: `gym.json` key `plans`, a list of day plans, one per gym; the old single `plan` key from 1.4–1.5 is read as a one-item list and no longer written). Planning one gym never changes another gym's plan.
- Button "Plan today": the machines of this gym are tapped in the order wanted (numbered 1, 2, 3 …; tap again to take one out), then Save (Cancel leaves it). An empty plan is no plan.
- With a plan the gym screen shows "Today's plan": the machines in plan order with their number and a state: Up next (the first not done, not busy, not skipped), Done (a set today), Busy, or Skipped. The other machines are listed under "Other machines"; any machine can still be tapped, in any order.
- Touch and hold a planned machine: Later (moves it to the end), Skip today / Back in today's plan, Swap for… (pick another machine to take its place), Remove from plan. Busy machines are passed over when working out Up next.
- Finish this session ends the plan. A plan belongs to one day and one gym (`plan` in gym.json); one from another day is ignored.

### Done with this machine (since 1.4; "Next ›" button since 1.5)
- Since 1.5 the separate button under the sets is gone. Once there is one set on the machine, a green "Next ›" button sits on the same line as "Set done" (labelled "Done" on a time machine), with the next planned machine's name in small letters under "Next" (nothing under it without a next planned machine). It does the job below.
- (1.4–1.4.x) A button under today's sets once there is one set on the machine. With a plan it goes straight to the next planned machine (labelled "Next: Leg press"); without a plan, or at the end of it, back to the machines.
- During the rest, once the sets done today equal the sets last time (or more), a large full-colour "Next machine: X" button appears under the ring and does the same; without a planned next machine it reads "Done with this machine" and goes back to the machines.

### Machines for time (since 1.4)
- Since 1.5, in the machine's edit page, "On this machine" has two switches for a time machine: "Has a level" and "Has an incline", both on by default (`noLevel`, `noIncline` in gym.json, optional true). With one off, the machine screen and "Next time" only show and ask for the other values, and the words leave it out ("25 min · incline 3 %"). Turning one off does not delete sets already logged.
- Machine form, "What you log": Weight × reps (default) or Time (`logs` = `weight` or `time`). A new machine can be either; an existing one keeps its sets.
- A time set has Minutes, Level and Incline in % (optional), each changed with − / + or typed. A new time machine starts at 20 min, level 5. Words: "25 min · level 8 · incline 2.5 %" (the incline part only when set). An entry is listed as its sets in that form.
- No rest ring after a set, no suggestion of more weight, no New best and no kilograms lifted for time machines; history shows minutes per visit.

### Next time and notes (since 1.4)
- After the first set on a machine today: "How did it feel? Next time…" (a form with Cancel and Save): next time's weight and reps (or minutes, level and incline), and a note. Saved on today's entry as `nextTime` and `note`.
- The next visit opens with those numbers instead of the usual suggestion ("Your plan from last time: 45 kg × 15"); the note shows under "Last time". Earlier visits (history rows and the visit page) show the plan and the note too.

### Instructions photo (since 1.4)
- Machine form, "Instructions": Take photo / Choose from Photos / Remove, stored like the machine photo in `Documents/Photos/` (`instructions` on the machine). On the machine screen a small "Instructions" picture opens it full screen. Unused photos are removed on save as before.

### After Finish: title and notes (since 1.4)
- "Session done" has a Title field (suggested "Tuesday at My gym": weekday, the gym's name) and Notes, saved with Done. `title` and `notes` on the visit.
- Earlier visits are listed with their title (else the date). The pencil on a visit opens title and notes with Cancel and Save.

## History (since 1.4)
- The "History" tab (plum, hand-drawn mark; a card under At the gym before 1.5). Its line shows this week's sessions.
- The list: every gym session with at least one set (finished or not) and every Sets & reps, Interval and Exercise-list workout, finished or ended early (marked "ended early"), newest first. A row: title (or workout name), date, the gym or kind, minutes and, for the gym, kilograms lifted.
- Filter chips: All, At the gym, and one per workout name that has sessions. Since 1.5 each chip has its own colour: All plum, At the gym indigo, each workout its own colour.
- At the top: "This week" — since 1.5 four full-colour tiles: Sessions (plum), Minutes (green), Lifted (indigo) and Weeks in a row (orange): sessions, minutes, kilograms lifted, and weeks in a row (consecutive weeks, ending this week or last, with at least one session); a line for this month (sessions · minutes); a bar chart of minutes per week for the last 8 weeks (this week's bar included).
- Tap a workout: its details (kind, start, minutes, what was done), a pencil for title and notes (Cancel and Save) and "Delete from History" (asks first; Cancel keeps it). Tap a gym session: the visit page (fixed in 1.5: in 1.4 it showed an empty page with a yellow warning triangle). A gym session cannot be deleted from History (its sets can be changed or removed on the machine).
- Sessions are recorded when a workout ends: Close after Well done (finished) or End workout (ended early).
- Apple Health is not used (the owner logs on a Garmin watch, which syncs to Health).

## New workout and editor
- New workout: three cards — Sets & reps, Exercise list, Interval timer — then the editor. Cancel on both.
- Editor: Name, Colour (the fifteen AMS-Icons colours, two rows of eight), Type (Sets / List / Intervals). Cancel and Save; Save is a full-colour pill and without a name it says "Give it a name first." instead of being greyed out. Nothing is kept before Save.
- Sets & reps: Sets 1–50, Reps per set 1–500, Rest 0–10:00 in 15 s steps (0 = None).
- Interval timer: Rounds 1–99, Work 0:05–15:00 and Rest 0:00–15:00 in 5 s steps; the total is shown.
- Exercise list: per exercise Name, Amount (free text), Note, Photo (from Photos, stored scaled to 1600 px). ••• moves it up, down, or removes it. Add exercise adds one.
- Changing the type keeps every other type's numbers. An existing workout can be deleted (asks first).

## Running a Sets & reps workout
- Set: "SET", the set number large with "/ total", the reps on a pill in the workout's colour, dots for the sets, and a large Done.
- Done starts the rest (if rest > 0): a ring counting down, "REST", "Next: set n of N", +15 s and Skip rest (was "Skip" before 1.4). The rest ends by itself.
- After the last set: Well done and Close.

## Running an Interval timer
- 5-second Get ready, then Work and Rest rounds; the ring shows the time left (work in the workout's colour, rest grey). Pause/Resume and Skip rest (during rest; "Skip" otherwise). Ends with Well done.
- The clock is kept as end times, so a late tick never loses time.

## Running an Exercise list
- A card per exercise: photo (tap to enlarge), number, name, amount pill, note, a tick circle. Tapping ticks it off and scrolls to the next one. "n of N done" and a bar at the top. All ticked: Well done and Close.

## Cues
- Start of a set/round: a tone, a vibration and words ("Set 2 of 5. 20 reps.", "Round 3. Go!", "Last round. Go!"). Rest: a vibration and "Rest". Last 3 seconds: a tick and a tap. End: a three-note tone and "Well done".
- Plays with the silent switch on and mixes with music. The screen stays on during a workout. US English voice.

## Settings
- Backups (since 1.6), How it works (a part for every area, including "Exercises without a machine" and "Backups"), What's new (every version, newest first), Version "1.6 (build)" (Settings is a tab since 1.5).

## Backups (since 1.6)
- Settings → Backups. "Back up now" (full-colour navy button, `backup-now`) writes one file named `Workouts backup yyyy-MM-dd HHmm.json` (e.g. "Workouts backup 2026-11-03 1530.json") to the temporary folder and opens the share sheet (Files, iCloud Drive, AirDrop, Mail). If it cannot be written: "The backup could not be made. Is the iPhone full?"
- File format: JSON `{"app":"AMS WorkoutCompanion","version":1,"made":<ISO 8601>,"files":{"workouts.json":<base64>,"gym.json":<base64>,"history.json":<base64>},"photos":{"<name>.jpg":<base64>,…}}` — the three data files and every photo in `Documents/Photos/`, byte for byte as on the iPhone, so restore loses nothing between versions. Keys of `files` other than the three names are ignored.
- "Restore from a file…" (`backup-restore-file`) opens the Files picker (JSON). The app reads the file and every data file inside it before anything changes. A file that is not a backup (wrong `app`, `version` other than 1, not JSON) or is damaged is refused: "This file is not a Workouts backup, or it is damaged. Nothing was changed."
- A valid file shows an alert "Restore the backup from <date>?" with what it holds — "3 workouts · 12 machines · 40 gym visits · 25 other sessions · 30 photos" (singular for 1) — and "It replaces what is on this iPhone now. Today's data is kept aside first." Cancel / Restore (`backup-restore-confirm`).
- Restore: first today's three files and `Photos/` are copied into `Documents/Before restore <seconds since 1970>/`; then the three files are replaced by the backup's (a file the backup lacks is removed), `Photos/` is emptied and refilled with the backup's photos, and the app reloads. If it fails: "The backup could not be restored. What was on this iPhone is kept aside." On success: "Restored: …".
- "On this iPhone": at app start, if the newest copy in `Documents/Backups/` is 7 days old or older (or there is none), the app writes a copy with the same file name and format; only the newest 4 stay, older ones are removed. They are listed with weekday, date and time; tap one for the same Restore question (`backup-copy-n`). "Keep a copy now" (`backup-keep-copy`) makes one at once ("Copy kept on this iPhone."). These copies are inside the app, so they go if the app is deleted — the footer says to keep one in Files too.

## Data
- `Documents/workouts.json` (`{"version":1,"workouts":[…]}`), `Documents/gym.json`, `Documents/history.json` (since 1.4) and photos in `Documents/Photos/`. Dates are ISO 8601. Photos no workout and no machine uses are removed on save. A file that cannot be read is kept aside, never overwritten; while gym.json is unreadable no photo is removed. No iCloud, nothing leaves the iPhone unless the owner saves a backup file (see Backups); weekly copies are kept in `Documents/Backups/` and "Before restore <seconds>" folders hold data set aside by a restore.
- `gym.json`: `{"version":1,"machines":[…],"visits":[…],"busy":[{"machineID","day"}],"gyms":[{"id","name"}],"currentGym":"<id>","plans":[…],"homeIcon":…,"muscles":[…],"templates":[…]}`. `busy` since 1.3; `gyms`, `currentGym` and `plan` since 1.4 (`plans` per gym since 1.6); `muscles` and `templates` since 1.10. Machines, visits, busy marks and plan carry their gym; a file without the new keys is read as one gym "My gym" holding everything.
- Machine: `logs` (`weights` or `time`, default `weights`) and `instructions` (photo file name, optional), and since 1.5 `restSeconds`, `step` and `topReps` (the "On this machine" settings), and for time machines `noLevel` and `noIncline` (optional true: no level / no incline; missing = has it) (missing = the usual 90 s, 2.5 kg, 12 reps). Since 1.6 `logs` may also be `reps` (reps only; sets stored with `kg` 0, so older readers still see valid sets); older files read as before. Set: `seconds`, `level`, `incline` for time sets (optional; weight and reps for the others). Entry (a machine's sets in a visit): `nextTime` (the weight/reps or time/level/incline wanted next) and `note`. Visit: `title` and `notes`. All optional, so older files read as before.
- `history.json`: `{"version":1,"sessions":[…]}` — one record per finished or ended workout (`id`, `workoutID`, `kind`, `name`, `colour`, `started`, `ended`, `completed` (false = ended early), `detail`, `title`, `notes`). Gym sessions are read from gym.json; the file never holds a second copy.
- The gym log keeps every visit; History keeps the other workouts' sessions.
- The camera asks once: "A photo of each gym machine, so you recognise it and its setting next time."
- The camera asks once: "A photo of each gym machine, so you recognise it and its setting next time."

## Look
- Save / Done at the top right of every edit page: a full-colour capsule (blue; never grey).
- Page and text colours as AMS Packing (light / dark pairs). Workout colours, icons and the marks on buttons (ControlMark) all from AMS-Icons, pinned to one commit. No stock symbols, no emoji.

## Icons (since 1.6)
- Hand-drawn icons from the AMS-Icons hub only (`.hand` keys), chosen in `IconPicker`: search field, icons grouped by heading, the current one highlighted, Cancel (Escape) and Save, and "Use the usual icon" (back to nil).
- Workout: `Workout.icon` (nil = the kind's usual icon); edit page row "Icon" (`editor-icon`).
- At the gym tile: `GymLog.homeIcon` in `gym.json` (`homeIcon`); touch and hold the tile → "Change icon…" (`gym-change-icon`).
- Machine or exercise without a photo: `Machine.icon`; form row "Icon" (`machine-icon`), shown only while there is no photo; tiles and the machine screen show it instead of the usual strength mark.
- The At the gym tile title is `.title2` bold (1.5: `.title3`).

## Repeat last visit (since 1.7)
- Gym screen, no plan today and a last visit at this gym before today: capsule "Repeat last visit" (`gym-repeat`, full indigo) beside "Plan today".
- `GymLog.lastOrder(gym:before:)`: the latest visit of this gym before the start of the day with sets; its machines in first-use order, without duplicates and without deleted machines. Tapping sets today's plan for this gym to that order.

## Automatic backup (since 1.7)
- Backups → section "Automatic": "Back up automatically…" (`backup-auto-on`) opens the folder picker. The folder is kept as a bookmark in the app's settings (`autoBackupFolder`); the last time in `autoBackupLast`.
- Due once per calendar day (`Backup.dailyDue`): checked at launch and when the app goes to the background. The file is the same as Back up now ("Workouts backup YYYY-MM-DD HHMM.json"). Only files named "Workouts backup *.json" in that folder are counted; the newest 7 stay.
- Shown: folder (`backup-auto-folder`), last time (`backup-auto-last`), a red line on failure; "Choose another folder…" (`backup-auto-change`), "Stop automatic backup" (`backup-auto-stop`, leaves the files).
- One file picker on the page serves Restore and the folder (two pickers on one page do not open in SwiftUI).

## Rest alarm (since 1.8)
- `RestAlarm.set(end, words)` (Cues.swift): one pending local notification "rest-over" ("Rest over", body e.g. "Set 3 on Leg press", default sound, time-sensitive). Replaced on every new rest, +15 s or pause/resume; removed on skip, when the rest ends in the app, and when the screen closes. Permission asked the first time a rest starts. Silent in UI tests.
- Gym machine screen: follows `restEnd`. Sets & reps / Intervals: armed for rest, get ready and off phases, with the next set or round.

## Undo (since 1.8)
- `Library.keepForUndo(label)` keeps workouts, gym log and history as they were just before a delete: workout (home menu, editor), machine/exercise, a set, a History session (`changeGym(undo:)`, `delete`, `deleteRecord`).
- Root overlay `UndoBar` (`undo-bar`, `undo-button`) for 10 seconds; Undo restores and saves all three files. Unused-photo cleanup waits until the bar is gone.

## Backup reminder (since 1.8)
- `Backup.reminderDue(lastBackup:oldestData:later:now:)`: 14 days since the last backup (Back up now or automatic, `lastBackup` setting), or since the oldest gym visit / session when there never was one; quiet 3 days after Later. Train top card `backup-reminder` with `backup-reminder-open` (Backups) and `backup-reminder-later`. UI tests: `-backupdue`; their settings live in a separate store emptied at each launch.

## Week picture and Check my data (since 1.8)
- History: 12 weeks; `history-week-switch` Sessions | Minutes; this week full colour; tapping a bar lists that week (`history-week-detail`, `History.sessions(_:weekStarting:)`).
- Settings → "Check my data" (`settings-health`): `HealthCheck.run(files:photoNames:otherFileNames:)` — each file readable, counts, photos referenced but missing, unreadable files kept aside (problems), "Before restore" folders (counted). `health-ok` or `health-problem-<n>`; read-only.

## Quality (since 1.8)
- `LargeDataTests`: 2 years of visits (312 visits, 2 gyms, 16 machines), 300 sessions, 30 workouts, 200 photos × 300 KB; file round-trip, History, Backup (≈83 MB, < 1 s locally) and machine look-ups within limits.
- GitHub Tests: the runner's compiler gave up on one long sum in `GymTests`; written as a typed constant.

## Version 1.9.1
- **Statistics** (History, `Stats.swift`): `stats-period` This week | This month; tiles `stats-week`/`stats-month` (sessions, minutes, exercises = one per machine per visit, sets, kg when > 0); `stats-muscle` sets per `Muscle`; time machines without a muscle = cardio, others "Not chosen"; `stats-warmup` minutes per time machine; `stats-streak` weeks in a row, best streak, records this month (a machine's best beaten; first time is no record); `stats-badges` 7 badges (`stats-badge-<id>`). Stats use all items, not the chip filter.
- **Muscle group**: `Machine.muscle: Muscle?` (chest, back, shoulders, arms, legs, core, cardio); unknown values read as nil. Picker `machine-muscle` in the machine form.
- **Machine screen**: back arrow hidden; bottom pill `machine-done-pill` "Exercise done" = back to the machine list (`moveOn(nil)`; hiding the back arrow also turns off swipe-back, so this is the way back); the green Next goes to the next planned machine; History per visit with sets, `history-visit-recommendation`, `history-visit-note`.
- **Bottom actions**: `.bottomActions(...)` in Theme.swift — Cancel (soft, Escape) left, Save/Done full colour right, pinned to the bottom of every edit page; identifiers unchanged.
- **Gym screen**: large bold title; `gym-intro` "Tap the machine you'll use next — or plan today's order."
- **Icons**: AMS-Icons 089121f adds hand icons `gym` and `pushup` (end of Sport) and a 6-tooth gear for the `settings` control mark. At the gym tile usual icon `gym`; `Workout.shownIcon` = chosen icon, else `pushup` for a name containing "push-up", else the kind's icon. Not yet in AMS Packing's catalog or the icon-library folder (its build script is out of date).

## Version 1.9.1
- Tab bar: `RootView` is a VStack — pages end above the bar (before, a bottom safe-area inset let pushed pages run under it: "Exercise done" and the last History row were hidden). The bar hides while the keyboard is up. Test `testNothingHidesUnderTheTabBar` (seen red on the old layout).
- Gym visit page (`VisitScreen`): indigo header with day and gym, tiles Time/Sets/Lifted/Machines (`visit-time`, `visit-sets`, `visit-kg`, `visit-machines`), New best line (`visit-bests`), a card per machine (`visit-machine-<name>`) with a muscle-colour stripe and chip (`Muscle.colourKey`), sets as wrapping chips, next time and note.
- Replay of a real-data problem on the Mac only: `ReplayUITests` with `TEST_RUNNER_REPLAY_GYM` (and `TEST_RUNNER_REPLAY_PHOTOS`); the app reads `-gymfile`/`-photosdir` only under `-uitest`. Real data is never committed.

## Version 1.9.2
- `MachinePhoto`: a clear box of fixed size with the photo as an overlay, clipped AND given a content shape — an upright photo scaled to fill a wide tile no longer reaches above the tile for taps (it caught "Plan today" in his home gym). Test `testPlanTodayOpensThePlanWithUprightPhotos` (`-tallphotos`: 1200 × 1600 photo on every demo machine), seen red with the old view.
- `Library.load`: the starter workouts are written only after the gym log and history are read; writing them first ran the unused-photo tidy-up against an empty gym log and deleted every gym photo. Test `testAFirstStartKeepsTheGymPhotos` (Check my data must say All good), seen red.

## Version 1.9.3
- Plan sheet: the List is always in edit mode. Section "Today's order" (shown once something is chosen): rows `plan-order-<n>` with drag handles (`onMove`) and the red minus (`onDelete`). Section "Add or take out": the tap-to-toggle rows `plan-machine-<name>` (move and delete off). Test `testThePlanOrderCanBeDraggedAndAMachineTakenOut` drags by the "Reorder" handle.

## Version 1.10
- **Muscle groups you can change.** `MuscleGroup {id: String, name, colour}` (colour = AMS-Icons key; 12 to choose: red, orange, yellow, olive, green, plum, blue, indigo, violet, pink, brown, slate). `GymLog.muscles` in the owner's order, stored as `muscles` in gym.json; a file without it gets `MuscleGroup.defaults` — the 7 groups of 1.9 with their old names as ids (`chest`, `back`, `shoulders`, `arms`, `legs`, `core`, `cardio`) and old colours, so `Machine.muscle` (now a `String?` group id) from 1.9 needs no conversion. A machine whose id matches no group counts as Not chosen. `GymLog.muscle(for:)`: own group, else the `cardio` group for a time machine (only while it exists), else nil. `save(muscle:)` adds at the end or updates (trimmed; empty name ignored), `moveMuscles(from:to:)` (List drag semantics), `delete(muscle:)` sets its machines to nil (sets stay), `machineCount(muscle:)`. Groups are shared by all gyms.
- Settings → Muscle groups (`open-muscle-groups`, `MuscleGroupsScreen`): rows `muscle-row-<name>` (colour dot, name, machine count) with drag handles; tap → sheet with `muscle-name`, colour circles `muscle-colour-<key>`, `muscle-cancel`/`muscle-save` at the bottom, `muscle-delete` (asks: machines go back to Not chosen, sets stay). `muscle-add` opens the same sheet empty. Deleting from the list also asks.
- Machine form picker `machine-muscle`, History `stats-muscle` bars and visit cards use the stored groups: names, colours, order. `Stats.muscles`: most sets first, ties in the owner's order, Not chosen last.
- **Plan templates.** `PlanTemplate {id, name, gymID, order: [UUID]}`, `GymLog.templates`, stored as `templates` in gym.json. `saveTemplate(named:order:gym:)` (trimmed; empty name or order → nil; same name in the same gym, any case, replaces), `templates(gym:)`, `order(of:)` (machines that still exist), `deleteTemplate`. Deleting a machine removes it from every template; an emptied template is removed.
- Plan sheet: section "Use a template" at the top when the gym has templates (`plan-template-<name>`, tap = today's order becomes the template's order; delete asks, today's plan stays). With a non-empty order, `plan-save-template` "Save as template…" asks for a name (alert) and saves at once for the current gym; the sheet's own Save/Cancel still decide today's plan.
- Tests: `MusclesAndTemplatesTests` (8, data; seen failing on 1.9.3), `MuscleGroupsUITests`, `TemplatesUITests`.
