# AMS WorkoutCompanion — specification

Version 2.0. iPhone only, portrait, iOS 17+, light and dark. The name under the app icon is "Workout Companion" since 1.22 (1.5–1.21: "Workouts"; plain "Companion" is refused by Apple, error 90129).

## Workouts (home, since 1.5: three tabs)
- A tab bar at the bottom with hand-drawn marks: Train, History, Settings. Train keeps its place when switching tabs (the gym screen stays where you were); History and Settings open fresh each time their tab is chosen. The Train tab is headed "Workout Companion"; the name under the app icon is "Workout Companion" since 1.22.
- Train: a wide full-colour indigo "At the gym" tile at the top; below it one full-colour tile per workout in two columns: hand-drawn icon on the workout's colour, name, one-line summary, a play mark, a pencil at the top right; then a dashed "New workout" tile.
- Tap the tile: the workout starts (full screen). Pencil: the editor. Touch and hold: Edit, Duplicate, Delete (Delete asks first). + (top right) also makes a new workout.
- History is its own tab (no longer a card among the workouts). Settings is a tab: no Done button, and the gear at the top left is gone.
- A fresh install has three starters: Push-ups (Sets & reps, 5 × 20, rest 1:30, orange), Intervals (8 × 0:40 work / 0:20 rest, green), Doctor's exercises (Exercise list, empty, pink).
- Since 2.3 there is a fourth kind, Tailored intervals; its summary is `10 steps · 18:00` (`1 step · 1:00`, `No steps yet`). The fresh-install starters are unchanged (still three). See Version 2.3.
- Summaries: `5 × 20 · rest 1:30`; `8 × 0:40 work / 0:20 rest · 7:40`; `No exercises yet` / `1 exercise` / `4 exercises`.

## At the gym (since 1.2)
- A wide tile "At the gym" at the top of the Train tab (a card at the top of Workouts before 1.5) (hand-drawn "strength" icon, indigo — the gym log's colour for its headings, buttons and marks). Its line: "Today: n machines · n sets", else "n machines", else "Photo, weight and reps per machine". The screen stays on while at the gym.
- Gym screen: "Today". Since 1.5 there is no date at the top right: the day is always today. "Log an earlier day…" in the gym-name menu opens a calendar (no future days; Cancel and Done); while an earlier day is chosen an orange bar "Logging for Saturday 31 October" with "Back to today" shows, and sets go to the visit on that day. Two columns of machine tiles in the order they were made: photo (or the strength mark), name, and "n sets done" (indigo, with a tick and an indigo border) or "Last: 30 kg" or "New". A dashed add tile, since 1.6 "New machine or exercise" ("New machine" before). Finish this session (full indigo, since 1.4; "Finish" before) once the day has a set. "Earlier visits", newest first: date, "n machines · n sets" → the visit: each machine's sets and "n sets · n kg lifted in all".
- Busy (since 1.3): every machine tile has a small "Busy" pill at the bottom right of its photo, just above the name band (hand-drawn stopwatch; orange outline). Tap it: the pill turns full orange, the tile gets an orange border and the line "Busy — come back later", and the machine moves to a row "Come back to" (orange heading) above the others, in the order marked; the rest are then headed "Other machines". Tap the pill again: the mark goes. Tapping a busy machine opens it and takes the mark away; a set done on it does too. Finish clears every mark of that day; marking a machine drops marks from other days. Deleting a machine removes its mark. Marks are kept in gym.json, so they survive closing the app.
- New machine or exercise: the camera opens first (the photo library when there is no camera; UI tests skip it). Since 1.6 a "Skip photo" button (`machine-skip-photo`) on the camera goes straight to the form without a photo; the tile then shows the hand-drawn strength mark. Then the machine form: photo (Take photo / Take photo again, Choose from Photos), Name, How it is set up (shown on the machine). Cancel and Save; since 1.5, for weight machines, a section "On this machine" (see below); Save without a name says "Give it a name first." After Save the gym screen shows again with the new tile; the machine opens only when tapped (since 1.16.2 — before, Save opened it at once).
- Machine screen: photo (tap: full screen), setting in indigo, "Last time, 27 Oct: 30 kg × 12, 12, 10" or "First time on this machine.", the suggestion, today's sets (tap one: change weight/reps or Remove set, with Cancel and Save), then "Set n" with weight (− / + the machine's weight step, usual 2.5 kg, type with a decimal pad; 0 = body weight) and reps (− / + 1, ≥ 1), and Set done. Pencil: edit or delete the machine (asks; deletes its sets too).
- The next set's numbers: the set just done on this machine today; else last time's first set — with one weight step more (usual 2.5 kg) and two reps fewer than the machine's "More weight at" number (usual 12, so 10) when every set last time reached it ("Try 45 kg — every set last time reached 10 reps"); else 20 kg × 10.
- Set done: saved at once, a tap, "Rest" spoken, the machine's rest (usual 1:30; with rest set to none no ring and it goes straight on to the next set) as a ring with +15 s and Skip rest ("Skip" before 1.4); the last three seconds tick; at the end a tone and "Set n". "New best" (trophy) when the weight is heavier than any earlier visit on that machine.
- History: a line chart of the heaviest weight per visit (from two visits) and a row per visit, newest first.
- Finish this session: "Session done" (was "Workout done" before 1.4) with Well done (a trophy when there are new bests), Machines, Sets, Time (in minutes: first set → last set; each set stores when Set done was tapped (`GymSet.at`, since 1.11.2, not part of set equality, kept by Fix a set). Finish counts only when tapped within 10 minutes after the last set (`GymVisit.finishGrace`); a later Finish adds nothing. A visit never finished still shows first → last set. Old visits without set times: started → Finish, but none (a dash) when over 3 hours (`GymVisit.longestOldVisit`) — such a visit also adds 0 minutes to History and Stats. A time typed by hand (`GymVisit.minutesByHand`, `GymLog.setMinutes`; 0/nil clears) always wins — see the visit page), Lifted in all (Σ kg × reps) and New bests per machine. Done closes it.
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
- New workout: three cards — Sets & reps, Exercise list, Interval timer — then the editor. Cancel on both. Since 2.3 there are four cards: Tailored intervals (`new-tailored`) is added, and it opens the editor with the example steps filled in (see Version 2.3).
- Editor: Name, Colour (the fifteen AMS-Icons colours, two rows of eight), Type (Sets / List / Intervals). Since 2.3 the Type switch has a fourth entry, Tailored (Sets / List / Intervals / Tailored). Cancel and Save; Save is a full-colour pill and without a name it says "Give it a name first." instead of being greyed out. Nothing is kept before Save.
- Sets & reps: Sets 1–50, Reps per set 1–500, Rest 0–10:00 in 15 s steps (0 = None).
- Interval timer: Rounds 1–99, Work 0:05–15:00 and Rest 0:00–15:00 in 5 s steps; the total is shown.
- Exercise list: per exercise Name, Amount (free text), Note, Photo (from Photos, stored scaled to 1600 px). Add exercise adds one. Since 2.4 there is no ••• menu: a block "Order" (two or more exercises) lists the exercises with a ≡ grip to drag them into order, and the red word "Remove" on each heading removes one after asking (see Version 2.4). Before 2.4: ••• moved it up, down, or removed it.
- Changing the type keeps every other type's numbers. An existing workout can be deleted (asks first).

## Running a Sets & reps workout
- Set: "SET", the set number large with "/ total", the reps on a pill in the workout's colour, dots for the sets, and a large Done.
- Done starts the rest (if rest > 0): a ring counting down, "REST", "Next: set n of N", +15 s and Skip rest (was "Skip" before 1.4). The rest ends by itself.
- After the last set: Well done and Close.

## Running an Interval timer
- 5-second Get ready, then Work and Rest rounds; the ring shows the time left (work in the workout's colour, rest grey). Pause/Resume and Skip rest (during rest; "Skip" otherwise). Ends with Well done.
- The clock is kept as end times, so a late tick never loses time.

Since 2.3 a Tailored intervals workout runs on the same screen with one phase per step (see Version 2.3).

## Running an Exercise list
- A card per exercise: photo (tap to enlarge), number, name, amount pill, note, a tick circle. Tapping ticks it off and scrolls to the next one. "n of N done" and a bar at the top. All ticked: Well done and Close.

## Cues
- Start of a set/round: a tone, a vibration and words ("Set 2 of 5. 20 reps.", "Round 3. Go!", "Last round. Go!"). Rest: a vibration and "Rest". Last 3 seconds: a tick and a tap (since 2.2, with "Spoken countdown" on, a rest between sets and an off round also say "Thirty seconds", "Twenty seconds", "Ten seconds" where they fit, then "Three, Two, One"; see Version 2.2). End: a three-note tone and "Well done".
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
- **Plan templates.** `PlanTemplate {id, name, gymID, order: [UUID]}`, `GymLog.templates`, stored as `templates` in gym.json. `saveTemplate(named:order:gym:)` (trimmed; empty name or order → nil; same name in the same gym, any case, replaces), `templates(gym:)`, `order(of:)` (machines that still exist), `deleteTemplate` (since 1.14 called only from Settings → Plan templates). Deleting a machine removes it from every template; an emptied template is removed.
- Plan sheet: section "Use a template" at the top when the gym has templates (`plan-template-<name>`, tap = today's order becomes the template's order; since 1.14 the sheet no longer deletes templates — see Settings → Plan templates). With a non-empty order, `plan-save-template` "Save as template…" asks for a name (alert) and saves at once for the current gym; the sheet's own Save/Cancel still decide today's plan.
- Tests: `MusclesAndTemplatesTests` (8, data; seen failing on 1.9.3), `MuscleGroupsUITests`, `TemplatesUITests`.

## Version 1.11
- **Data.** `GymSet.warmup: Bool?` (nil = a normal set; `isWarmup`). `Machine.heavy: Bool?` (nil = light; `isHeavy`; weight machines only in the form) and `Machine.partner: UUID?` (superset partner). `GymLog.rests: RestDefaults {heavy: 120, light: 90, exercise: 60}` (seconds), stored as `rests` in gym.json; a file without it gets those defaults. Nothing is converted: old files read with no warm-ups, no heavy machines and no pairs. `Machine.restSeconds` (the machine's own rest) still wins.
- **Muscle colour on the tiles.** Each machine tile on the gym screen has a thin stripe down its left edge in the colour of `GymLog.muscle(for:)`; no group = no stripe.
- **Save as template after Repeat last visit.** Gym screen, beside "Repeat last visit" (`gym-repeat`): button `gym-repeat-template` "Save as template" asks for a name (alert) and calls `saveTemplate(named:order:gym:)` with `lastOrder(gym:before:)` — last visit's machines in their order, for the current gym. Same name in the same gym replaces (as in 1.10); an empty name saves nothing.
- **Warm-up sets.** Machine screen: pill `gym-warmup` "Warm-up" before Set done. While on, the next set logged gets `warmup = true`; the pill switches itself off after that one set (tap again for another). Warm-ups show with a "W" (set chips, today's sets, visit page, History). They are kept in the visit and count as sets in the statistics (sets per muscle group, set tiles, balance), but are left out of: New best, `Stats.records`, the chart, "Last:" on the tile, the "more weight" and "one more rep" suggestions, and "Next time" starting numbers (all via `!isWarmup`). A set can be turned into a warm-up or back in the set editor (today, or on an earlier visit, see below).
- **Supersets.** Machine form (pencil) row `machine-partner` "Superset with": the other machines of the same gym, or None. `GymLog.pair(_:with:)` pairs both ways; choosing another machine lets the old partner go (and the new partner's old partner), None or itself takes the pair apart, deleting a machine lets its partner go. `partner(of:)` returns the partner only while both point to each other. Machine page: band `gym-superset` "Superset with <name>". After Set done: `supersetJump(after:in:)` returns the partner while it has fewer sets today than this machine — then the app opens the partner at once, no rest, no ring. When the counts are equal (round over) it returns nil: the normal rest runs, and the rest's Next button goes back to the partner.
- **Find a machine.** More than 8 machines in the gym: search field `gym-search` "Find a machine" above the machine tiles. `GymLog.machines(in:matching:)` matches the machine's name or its setting text ("Seat 4"), diacritic/case-insensitive (`localizedStandardContains`); empty words = all. Up to 8 machines: no field.
- **Muscle balance (History).** Card "Muscle balance — last 4 weeks": `Stats.muscleWeeks(_:weeks:4)` — per muscle group, in the owner's order, four small bars (sets per week, oldest left, this week right) and the total. A group with no sets in the 4 weeks says "Not trained". Machines without a group come last as "Not chosen" (only when they have sets). Sets are counted by the visit's day (`GymVisit.date`), warm-ups included.
- **Records wall.** History → Records: `Stats.records(_:)` — one row per machine used, newest record first (ties by name): weight machines the heaviest weight (most reps at that weight), reps-only exercises the most reps in one set, time machines the longest time; with the day it was first done (the visit's day, first visit reaching the best — a later equal set does not move it). Warm-ups never count. Tapping a row opens that visit.
- **1.13.** Session time: `GymVisit.minutes` takes as start the earliest of `started` and, for every set with `at` and `seconds`, `at − seconds` (a time set is saved when it ends); the result is at least `minutesOnMachines` (his 4 Nov visit: bike 70 + treadmill 50 showed 77 min). Hand time still wins. Session photos: `GymVisit.photos: [String]?` (file names in Photos/), `GymLog.addPhoto/removePhoto(visit:)`, counted in `photosInUse` (never tidied away, in backups, Check my data). View `SessionPhotos` (`session-photos` value "N photos", `session-photo-N`, `session-photo-camera`, `session-photo-add`; viewer `session-photo-remove` → confirm `session-photo-remove-confirm`, `session-photo-done`) on Session done (section "Photos of this session") and the visit page (card "Photos"). `-fakephoto` (UI tests) adds a plain indigo picture instead of the picker. Gym screen: Plan today / Repeat last visit / Save as template are three equal `GymActionTile`s (mark above words, Repeat full colour, others indigo at 14 %); Save as template uses `AppMark.template` (bookmark). Busy pill: 20 pt tall, caption2, bottom right of the photo, 6 pt extra tap area. Visit page: no "Lifted 0 kg" — "On time machines N min" (`visit-cardio`) when nothing was lifted.
- **Finish closes a session; two sessions a day (1.12).** A visit with `finished` set is closed. `GymLog.openVisit(on:gym:)` = the visit of that day and gym with `finished == nil`; the gym screen (`visit`, Finish button `gym-finish`), the machine page, `isDone`, the superset jump and `add` all use it, so after Finish the button goes and the next set makes a NEW `GymVisit` that day (its own `started`, title, notes, time). Without Finish all sets of a day stay in one visit. `GymLog.visits(on:gym:)` = all of that day's visits, earliest first. Earlier visits lists every visit except the open one — a just-finished one shows at once. `visitsNewestFirst` sorts by date, then `started`. After Finish with no open visit, the line "Session done. Tap a machine to start a second session." ("N sessions done…" after more) shows under the intro (`gym-session-done`). Earlier-visit rows show the start time ("14:20 · 3 machines · 9 sets"). The Train card counts the day's sessions ("Today: 2 sessions · 14 sets"). Old data needs no change.
- **Earlier visits and dates (1.11.3).** The gym screen's heading reads "Earlier visits · <gym name>" (`gym-earlier-heading`; plain "Earlier visits" if the gym is unknown). Its rows (`gym-visit-N`) carry their page (`NavigationLink { VisitScreen }`) — a `NavigationLink(value:)` + `navigationDestination(for: GymVisit.self)` never opened (fixed 1.11.3, like History in 1.5). An earlier visit's page shows the date with weekday, day, month and year in the iPhone's language, plus " · today" / " · yesterday" (`GymVisit.dateText`, `visit-date`). A machine tile's line before use today comes from `GymLog.lastText`: newest visit with a set of the machine's own kind — time: "Last: 25 min · level 8" (first time set); reps: "Last: N reps" (most working reps); weights: "Last: 35 kg" (heaviest working set); otherwise "New". Sets of another kind (a machine switched from weights to time) are skipped.
- **Session time by hand (1.11.2).** On an earlier visit's page the Time tile (`visit-time`) shows a small pencil; tapping it opens "Session time" (medium sheet): Minutes (`visit-time-minutes`, number pad), footer "How long the session really took. It counts in History and the statistics.", and — only when a hand time is set — "Use the time from my sets" (`visit-time-reset`). Cancel/Save at the bottom (`visit-time-cancel` / `visit-time-save`).
- **Share a visit.** On the page of an earlier visit a share button renders the visit to a picture (title or date, gym, minutes, sets, kilograms, every machine with its sets, new bests) and opens the share sheet (send or save). Since 1.11.1 each machine has a 52-point square beside it: its photo (scaled to 156 px on the short side before drawing, cut to the square) or, without a photo, its hand-drawn icon on light indigo. The share button carries the accessibility value "N photos" (photos in the picture), checked by `HistoryExtrasUITests.testSharePictureHoldsTheMachinePhotos` with `-tallphotos`. Under `-uitest` the picture is also written to the app's tmp/uitest/share.png, to look at it.
- **Search my notes.** History → Search my notes: `GymLog.searchNotes(_:)` (trimmed, empty = no result), newest first: notes on a machine within a visit (shown with its "next time"), a visit's title and notes, and each machine's setting text (`NoteHit.Kind`: machineNote, visitNote, setting). Tapping a hit opens its visit (a setting has no visit).
- **Rest per exercise type.** Settings → Rest times (`open-rest-times`): three rows (heavy machines usual 2:00, light machines 1:30, exercises without a machine 1:00), Cancel and Save at the bottom. Machine form (weight machines only) switch `machine-heavy` "Heavy machine". `GymLog.rest(for:)`: the machine's own `restSeconds`, else exercise rest for a reps-only exercise, else heavy for a heavy machine, else light. Changed from before: exercises without a machine rest 1:00 instead of 1:30 and heavy machines 2:00, unless changed in Rest times; light machines stay 1:30; machines with their own rest are unchanged.
- **Fixing a set afterwards.** Earlier visit page (History or Earlier visits): tap any set → editor with weight, reps or time, a warm-up switch and Remove, Cancel and Save. `GymLog.change(visit:entry:set:to:)` replaces or (nil) removes one set; an entry left with no sets drops out of the visit, a visit left with no entries is deleted.
- **Identifiers (1.11).** `gym-repeat-template`, `gym-warmup`, `gym-superset`, `gym-search`, `machine-partner`, `machine-heavy`, `open-rest-times`.
- **Not in 1.11:** Apple Health and Apple Watch. The version number shown in the app is 1.11.
- **1.14.** Version 1.14 (4 Nov 2026), five things:
  - **Share picture shows the session's first photo.** When the visit has `photos`, the picture draws the first one wide (full width, cut to a wide band) right under the heading; machine photos beside each machine are unchanged. The share button's accessibilityValue is "N photos" (machine photos in the picture) plus ", session photo" when the session photo is in it (for example "2 photos, session photo").
  - **Undo Finish.** `GymLog.undoFinish(visit:before:)` on the "Session done" page: button `gym-summary-undo` "Undo Finish" beside Done. It takes the visit back to open (`finished` cleared, so `openVisit(on:gym:)` finds it again), restores the day's plan and the Busy marks from the state taken before Finish (`before`), and keeps the title, notes and photos typed in. Finish (`gym-finish`) is back on the gym screen.
  - **Delete a session.** `GymLog.delete(visit:)` removes the visit and all its sets. At the bottom of an earlier visit's page (History or Earlier visits): red button `visit-delete` "Delete this session"; it asks, and the confirm button is `visit-delete-confirm`. `Library.keepForUndo` first, so the dark `UndoBar` (`undo-bar`, `undo-button`) restores it for 10 seconds; its photos are not tidied away until the bar is gone.
  - **Templates deleted in Settings.** Settings → Plan templates (row `open-templates`): each gym's templates are listed (`template-<name>`) with their machines and a bin `template-delete-<name>`; deleting calls `deleteTemplate` after `keepForUndo` (Undo bar, 10 seconds). With no templates the page shows `templates-empty`. Plan today (`plan-template-<name>`) only uses a template or saves one (`plan-save-template`); it has no delete any more.
  - **History icon.** The History tab (`open-history`) and History's empty page draw `AppMark.history` (bars going up on a base line, 24-point grid, 1.9 stroke) instead of the hub's `pulse` mark. Also `AppMark.trash` (bin) for Delete buttons.
  - Version shown in the app: 1.14. What's new and How it works updated (Undo, Plan templates, Sharing a visit, Two sessions in a day, new "Deleting a session").

## Version 1.15 — the rest on the lock screen (4 Nov 2026)
- **Live Activity.** A widget extension `RestWidget` (bundle `com.schabbauer.AMSWorkoutCompanion.RestWidget`, folder `Widget/`, embedded in the app; app Info.plist `NSSupportsLiveActivities = true`). `RestActivityAttributes` (in `App/Shared/`, compiled into both) has no fixed attributes and one state: `card: RestCard`.
- **`RestCard`** (WorkoutCore, `RestCard.swift`): `kind` (.gym / .workout), `title`, `next`, `start`, `end` (never before start); `seconds`, `left(at:)` (never below 0), `progress(at:)` (0…1), `isOver(at:)`. `GymLog.restCard(machine:in:start:end:)`: title = machine name, next = "Set N · " + the numbers `next(_:in:)` offers, said the machine's way (reps-only: "15 reps").
- **Where it starts.** Machine page: on every change of the rest end (Set done, +15 s, Skip rest, rest over) `RestLive.show(card or nil)`, start = end − rest length; leaving the page ends it. Sets & reps / Interval timer: in `armAlarm`, beside the 1.8 rest alarm — "Set n of m · r reps" or "Round r of m", title = workout name; pause, end or leaving ends it. At app start any rest left over is ended.
- **`RestLive`** (Cues.swift): one activity at a time — an existing one is updated, else requested; `staleDate` = rest end, so the widget switches to "Rest over" / "Go: …" by itself while the app sleeps. Nothing when Live Activities are off in iPhone Settings or the rest is under 1 s. `isShowing` = an active or stale activity exists.
- **Look.** Lock screen: hand-drawn stopwatch (AMS hand mark), "Rest · <title>" (headline), "Next: <next>" (subheadline, secondary), countdown `.title` semibold monospaced in the kind's colour (gym indigo #4f46e5 / #9d97ff, workout blue #2f6fe0 / #8db4ff), linear bar below. Dynamic Island: compact = stopwatch + countdown, minimal = stopwatch, expanded = stopwatch + title, countdown, next + bar; night colours always (the island is black). Over: "Go" instead of the countdown, full bar.
- **In the app.** Rest card line "Also on your lock screen" (footnote, gym tint, `gym-rest-lock`) while `RestLive.isShowing`.
- **Tests.** `Version115Tests` (4: card words for weights and reps-only, time left and progress, saving and reading) and UI `RestLiveUITests.testARestShowsOnTheLockScreenAndSkippingEndsIt` (rest → line shows, stays after the home screen, Skip rest → gone). The system's own island is not readable by a UI test — checked by a screen picture in the simulator (stopwatch + "1:25" in the island).

## Version 1.16 — a nicer look at the gym (4 Nov 2026)
His pick 1, 2 and 5 of six visual ideas (a Sonnet helper researched Hevy, Strong, Fitbod, Gentler Streak).
- **Photo tiles.** `MachineTile`: `MachinePhoto` fills the tile (`MachineTile.height` 132, `corner: 0` — new `MachinePhoto.corner`, default 10), tile corners 14. Band over the bottom: name (subheadline semibold) + status (caption, 88 %), white on `Gym.band` #1e1b4b at 82 %; Busy = `Gym.busy` fill with its ink, "Busy — come back later". Identifier `tile-band-<name>`. Done: tick top right as before, edge 2 pt indigo; busy edge 2 pt orange. Muscle stripe unchanged (band text moves 3 pt in when there is one).
- **Busy pill** now `.topLeading` on the tile (was bottom right of the photo since 1.13).
- **Rest ring.** `RestColour.key(fractionLeft:)` (WorkoutCore): > 0.5 "orange", > 0.2 "yellow", else "green" — AMS-Icons colour keys. Machine page ring 180 pt (was 160), width 14 (was 12), countdown 52 pt rounded bold (was 40); colour change animated 0.6 s. Ring element `gym-rest-ring`, value = the key. The Sets & reps / Interval rings are unchanged.
- **Sets that beat last time.** `GymLog.beatsLastTime(_:at:machine:visit:)`: working sets only, compared with the same working set (by place, warm-ups skipped) of `last(_:excluding:)`; weights: more kg, or same kg and more reps; reps-only: more reps; time sets and no last time: false. Row shows `AppMark.up` in `Gym.better` (#b7791f / #f6c453) left of the numbers; label gains ", more than last time".
- **Set rows.** Card on `Gym.fill` 9 % over `Theme.card`, edge `Gym.fill` 35 %; tick = `ControlMark.check` 11 pt in a 20 pt circle (`Gym.fill`, warm-up `Warmup.swatch`).
- **Tests.** `Version116Tests` (5) and UI `LookUITests` (3: band, ring orange, arrow label) — all seen red first.
- **GitHub Tests.** Red since 1.12: stale version lists (fixed in 1.15) and, on GitHub's slower compiler, `VisitRow`'s one-line detail text ("type-check in reasonable time") — now built in steps (`VisitRow.detail`).

## Version 1.16.1 — the Busy pill back where Martin put it (5 Nov 2026)
- **Busy pill** back to the bottom right (his choice in 1.13, undone by 1.16 without asking): `.overlay(alignment: .bottomTrailing)` on the tile button, lifted by the name band's height. The band reports its height with the preference key `BandHeight` (GeometryReader behind the band); `GymScreen.bandHeight` (start 44) is the bottom padding, so the pill sits just above the band at any text size.
- **Guard:** UI test `LookUITests.testBusyPillSitsBottomRightAboveTheNameBand` — pill (`busy-<name>`) in the right and bottom half of the tile (`machine-<name>`) and not lower than the top of the band (`tile-band-<name>`), both unmarked and marked. Seen red first (pill at top left).
- **Rule:** a placement Martin chose is never changed as a side effect of another look change — ask first.

## Version 1.16.2 — a new machine is only defined (5 Nov 2026)
- His report: "When defining a new machine, it jumps automatically into the view set to done, exercise done. I just wanted to define the machine." The new-machine sheet's save closure in `GymScreen` no longer sets `opened`; it only closes the sheet. The tile `machine-<name>` is then on the gym screen.
- Test `testAtTheGymANewMachineTwoSetsAndFinish`: after Save, the tile exists and `gym-set-done` / `machine-done-pill` do not (seen red first); then taps the tile. Tests that relied on the jump now tap the tile (`testAnExerciseWithoutAMachineLogsRepsOnly`, `testASecondGymCanBePlannedToo`, ScreenTour `testNewIn16Tour`).

## Version 1.17 — smaller action tiles, "Session going" (5 Nov 2026)
His two asks from the gym (screenshots): the three tiles too big; "could we make some indication that the session is ongoing?"
- **Action tiles.** `GymActionTile`: mark (15 pt, in a 16 pt box) BESIDE the words (HStack, spacing 4), `.footnote` semibold, leading, up to 2 lines, padding 6 all round. ~45 pt tall (was 82: mark 22 above `.subheadline`, padding 8). Test `LookUITests.testActionTilesAreCompact` (`gym-plan`, `gym-repeat`, `gym-repeat-template` ≤ 52 pt; seen red at 82).
- **Session going.** `SessionGoingLine` under the intro, shown when `openVisit(on:gym:)` has ≥ 1 set: green dot (9 pt) + "Session going · N min · M machines · S sets" (subheadline semibold, green #15803d / #86efac by night, on the same green at 12 %, corners 10). Minutes = now − (`started`, or the earliest set `at`), refreshed every 30 s by a `TimelineView`; machines = entries with sets. Identifier `gym-session-going`. Gone after Finish (then "Session done" shows as before). Test `LookUITests.testTheGymScreenSaysASessionIsGoing` (seen red).
- Tour `ScreenTour.testNewIn117Tour`: 56 Small action tiles, 57 Session going — checked day + night.


## Version 1.18 — "Session going" on Train and on Finish (5 Nov 2026)
His two approved ideas after 1.17: see that a session is going from the Train page, and when scrolled down at the gym.
- **Train page.** `HomeScreen`, right under `GymCard`: when `library.gym.openVisit(on: today, gym: currentGym)` has ≥ 1 set, `SessionGoingLine(visit:identifier: "home-session-going")` — the same view as the gym screen (now internal, not private; identifier is a parameter, default `gym-session-going`), same words, green and 30 s refresh. Wrapped in a plain Button that opens the gym. Not inside the card: the card is indigo and the green line would not read on it. Test `LookUITests.testTheTrainPageSaysASessionIsGoing` (absent before the first set; present with "Session going" and "min" after; tap opens the gym) — seen red.
- **Finish button.** `gym-finish` sits in a `TimelineView` (30 s) and reads "Finish this session · N min" (N from `SessionGoingLine.minutes(of:now:)` = now − `started` or earliest set `at`; without a start just "Finish this session"). Accessibility label stays "Finish this session"; the minutes are its value ("N min"). Chosen over an extra green line above the button: one line less, same news. Test `LookUITests.testTheFinishButtonShowsTheSessionMinutes` (value ends in " min") — seen red.
- Tour `ScreenTour.testNewIn118Tour`: 58 Train with Session going, 59 Finish with minutes — day + night.

## Version 1.19 — leave a machine without a set; short build numbers (5 Nov 2026)
- His report: "I need a way to exit this without pressing set done or exercise done if I choose not to use this machine during this specific session." The machine page has no back arrow (hidden since 1.9); its only way out was the bottom pill `machine-done-pill` "Exercise done". Opening a machine saves nothing, and the pill with no sets saved nothing either — but its words said otherwise.
- Now the pill reads **"Back to machines"** while `today` (this machine's sets in the open visit) is empty, and "Exercise done" after a set. Same action (`moveOn(nil)`). With no sets it is also the cancel action (Escape on the Mac). Test `LookUITests.testAMachineCanBeLeftWithoutLoggingASet` (label "Back to machines", tap → gym, no `gym-session-going`; after a set "Exercise done") — seen red.
- Build numbers: `CURRENT_PROJECT_VERSION` in `project.yml` — 1 per new version, 2, 3 … for a rebuild (was `YYYYMMDDHHMM`). Both the Mac upload and the GitHub TestFlight workflow read it from there (commit 9d06eab).

## Version 1.20 — session starts when the gym opens; "Back to gym" (5 Nov 2026)
- His ask: he expected to see "Session going" and Finish when he walked in, not only after the first set. Also his wording for the machine page's bottom button: "Back to gym" (1.19 said "Back to machines").
- **Model.** New `Arrival {gymID, at}` and `GymLog.arrived` (saved in `gym.json` as `arrived`). `arrive(gym:at:)` is called when the gym screen appears for today. It does nothing when a session with sets is open, when a session was finished today, or when there is already an arrival today. `sessionStart(on:gym:)` = the open visit's start, else the arrival. `add` moves the arrival into `visit.started`; `finish` and the new `leave()` clear it. So the session's time in History counts from arrival; once finished, opening the gym again starts nothing — a second session still starts with its first set.
- **UI.** `SessionGoingLine` now takes start / machines / sets and reads "no sets yet" with 0 sets (gym screen `gym-session-going`, Train `home-session-going`). `gym-finish` shows whenever `sessionStart` exists ("Finish this session · N min"); with no sets it calls `leave()` — the session ends and nothing is saved.
- **Machine page.** `machine-done-pill` reads "Back to gym" before the first set, "Exercise done" after; Escape on the Mac does the same.
- **Tests.** Core `Version120Tests` (5 tests); UI `LookUITests.testFinishWithoutASetEndsTheSession`; the 1.17–1.19 UI tests updated (line present on opening with "no sets yet"; label "Back to gym"). Version lists, What's new and How it works updated.

## Version 1.21 — safety: unreadable workouts file, red note on Train, all-or-nothing Restore (16 Nov 2026)
- A safety release, no new features. Build number 1 (1.21 (1)).
- **Fixed — the workouts file.** If the workouts file on the phone could not be read, the app used to save an empty list over it at the next change and tidy away the workouts' photos. Now it never saves over a workouts file it cannot read and keeps every photo — the same protection the gym log and History already had. The unreadable file is kept aside in the app's folder as before.
- **New — red note on Train.** When the workouts, the gym log or the History could not be read, a red note at the top of Train says so: "Your workouts could not be read" (or "Your gym log could not be read", "Your history could not be read"), with the line "Nothing is saved over them. Restore a backup to get them back." and a "Backups" button that opens Settings → Backups. Accessibility identifiers: the note `unreadable-note`, its button `unreadable-backups`.
- **Changed — Restore is all-or-nothing.** The backup's files and photos are first written to a waiting folder; only when every one of them is written are they put in place. If anything fails on the way (for example the phone is full), everything stays exactly as it was before. As before, today's data is first kept in "Before restore <date>".
- **Texts.** What's new (1.21) and How it works (Backups) updated; version lists in Core `WorkoutCoreTests` and UI `testSettingsShowsTheVersionAndWhatsNew` now expect 1.21.

## Version 1.22 — "Done this session", one button on a machine, session clock, new name (18 Nov 2026)
- His four asks, built together.
- **Name.** The name under the app icon is now "Workout Companion" (was "Workouts"). Train stays headed "Workout Companion". The iPhone may shorten the name under the icon when it is too long.
- **Done this session.** On the gym screen, right under the green Session going line, a list `gym-done-list` with one row per machine that has sets in the open session, in the order they were done. Each row `gym-done-<machine name>` shows a number (1, 2, 3…), the machine name and its sets (for example "30 kg × 12, 12, 10"). Tapping a row opens that machine again (to add a set or look). Not shown before the first set.
- **One button on a machine.** The green "Next" beside Set done (`gym-machine-done`) is removed. The bottom button `machine-done-pill` is the only way on: before the first set "Back to gym" (logs nothing, as before; Escape on the Mac the same); after a set "Exercise done". When today's plan has a machine still to do, "Next: <name>" shows under "Exercise done" and the button goes straight to that machine; with no plan or nothing left it goes back to the gym screen. The "Next machine: <name>" button during the rest (once the sets done equal the sets last time) is unchanged.
- **Session clock.** The green Session going line on the gym screen has a running clock at its right, `gym-session-clock`, counting every second as hours:minutes:seconds ("0:42:15") since the session began (the moment the gym screen opened). The words keep the counts ("Session going · 3 machines · 7 sets"). The Finish button still shows minutes. The line under the At the gym card on Train (`home-session-going`) is unchanged.
- **Texts.** What's new (1.22) and How it works (At the gym, Next machine, Exercise done and one-hand buttons, Workouts) updated; version lists in Core `WorkoutCoreTests` and UI `testSettingsShowsTheVersionAndWhatsNew` now expect 1.22.

## Version 1.23 — 15 changes picked from 50 ideas: set-by-set memory, effort, holds, pain, move to next visit, pausing clock, lock screen, opening hours, session feel, comparison, stretch, reminder, sounds, spoken countdown, presets (18 Nov 2026)
- Build number 2 (1.23 (2)); build 1 was 1.23 (1). Data stays on the phone; the gym file gains new optional fields and older backups still open.
- **Last time, set by set.** In the box for the set about to be done, a faint line `gym-last-set` shows the same set from the last visit ("Last time: 40 kg × 10 · hard"). Rule `GymLog.lastSet` / `lastSetLine`: working sets only (warm-ups not counted); not on time machines or a first time. Before: one line for the whole machine at the top.
- **Effort per set.** Under today's sets a row "Last set felt" with pills `gym-effort-easy`, `gym-effort-ok`, `gym-effort-hard`; the word shows in that set's row; tapping the same pill again removes it; it appears next time in the "Last time" line. Stored as `GymSet.effort`.
- **Holds.** `Machine.isHold`: a time machine with level and incline both off. Entered in seconds (± 5 s). `gym-hold-start` "Start countdown" counts down with a ring, ticks in the last three seconds, saves the set by itself at zero and starts the rest; `gym-hold-stop` "Stop" saves nothing; "Done" logs without a countdown. Times under one minute read "45 s" (before "0:45 min").
- **Pain flag.** After the first set a "Pain here" pill `gym-pain` (red when on). Next visit a red line `gym-last-pain` "Pain flagged last time — go easy"; the app never suggests more weight or reps after a pain flag ("Pain last time — the same again, go easy"). Stored as `MachineEntry.pain`.
- **Move to next visit.** Press and hold a row in today's plan: "Move to next visit". Struck through today ("Moved to next visit"); next time at that gym it stands first under "From last visit" (`gym-carried`, rows `gym-carried-<name>`); a plan made that day gets these machines first. Press and hold: "Not this time" drops it. It leaves the list once a set is logged on it. Before: Skip today only, forgotten after. Stored as `GymLog.carried`.
- **Pausing session clock.** After 20 minutes without a set the clock stands still and the green line says "Paused" instead of "Session going"; the next set starts it again; idle time beyond 20 minutes is not counted (a time set's own minutes always count). The Finish button's minutes and the Train line use the same clock. The time kept in History (first set to last set) is unchanged. Rule `GymVisit.active`, `GymLog.sessionClock`.
- **Clock starts at the first machine.** `GymScreen.open(_:)` (machine tile, plan row, "From last visit" row, "Done this session" row) now calls `arrive()`; `.onAppear` no longer does. So after opening the gym screen there is no `gym-session-going`, `gym-session-clock` or `gym-finish` until a machine has been opened; after opening one and going back (`machine-done-pill`) they show, with "no sets yet" before the first set. The Train line `home-session-going` follows the same rule, and the session time kept in History counts from that moment. Core `arrive` unchanged. Before (1.20 to 1.22): the clock started when the gym screen opened, so choosing the gym, planning or repeating last visit counted as training time.
- **Lock screen clock.** While a session is going, the lock screen and Dynamic Island show "Gym session", the running clock, the gym's name and "3 machines · 7 sets"; it ends with Finish. Rest countdown as before.
- **Opening hours.** Gym menu (gym's name) → "Opening hours…" (`gym-place-hours`): seven rows `hours-day-1…7`, each Open/Closed with from and to; `hours-copy` "Same as Monday for every day"; `hours-save`, `hours-cancel`. `gym-hours-line` under the name: "Open · closes 22:00", "Closes in 40 min", "Closed · opens 06:00", "Closed · opens Monday 06:00". The At the gym card on Train shows the same words.
- **Session done.** How did it feel: pills `gym-feel-great|good|ok|tired|rough` (Great/Good/OK/Tired/Rough), kept with the session, shown on its page and in Earlier visits. "Against last visit": Machines, Sets, Time, Lifted in all (`gym-compare-machines|sets|time|total`) with the change ("+2", "−6 min", "+250 kg", "same"); more is green; not shown on the first visit to a gym. "Stretch now" `gym-stretch` opens a stretch list to tick off; the first time the app makes an ordinary exercise list "After-gym stretch" (six stretches: chest in a doorway, shoulder across the body, hip flexor lunge, hamstring, thigh standing, child's pose), shown as a tile on Train and editable like any list. The list is chosen in Settings → "Reminder and stretch" ("None" hides the button).
- **Gym reminder.** Settings → "Reminder and stretch" (`settings-gym-extras`): "Remind me after N days without the gym", Off or 2–14 days, 4 to begin with; the phone shows "4 days since your last gym visit" at 10:00 that day. Cancel and Save.
- **Sounds.** Settings → "Sounds" (`settings-sounds`): rest-end sound Chime (as before), Bell, Beep or None (the locked-phone rest alarm uses the same); vibration Strong, Light or Off; "Spoken countdown" on/off. Each choice plays or buzzes once when tapped. Cancel and Save.
- **Spoken countdown (interval timer).** The voice says "Three, two, one" at the end of every phase; "Halfway" in work rounds of 20 s or longer; "Ten seconds" in work rounds of 30 s or longer. The tick stays quiet while the voice counts. Since 2.2 an off (rest) round also says the rest marks of a gym rest (see Version 2.2).
- **Presets (interval workouts).** A "Presets" menu in the editor fills rounds, work and rest: Tabata (8 × 20 s / 10 s), 30 / 30, 40 / 20, 45 / 15, Every minute (10 × 60 s / 0 s). "Save as preset" keeps his own under a name; "Remove my preset" deletes one.
- **Planning tiles only before the session (build 2).** In `GymScreen.planSection`, the tiles "Plan today" `gym-plan`, "Repeat last visit" `gym-repeat` and "Save as template" `gym-repeat-template` show only when there is no plan yet and no session is going (`sessionStart == nil` and no set logged today). Once a machine has been opened or a set logged (the green "Session going" line, `gym-session-going`) they are hidden and the hint reads "Tap the machine you'll use next."; a plan made earlier still shows as "Today's plan" with "Change" (also `gym-plan`). After Finish the tiles return. Before, they stayed during the whole session. UI test `Version123UITests.testPlanningTilesHideOnceTheSessionIsGoing`.
- **Texts.** What's new (1.23) and How it works (Interval timers, Sounds and words, At the gym, Plan today, Logging a set, Machines for time, Next time and notes, Session time, Earlier visits, Two sessions in a day, Rest on the lock screen, Rest alarm, Where things are kept) updated; version lists in Core `WorkoutCoreTests` and UI `testSettingsShowsTheVersionAndWhatsNew` now expect 1.23.

## Version 1.24 — Garmin Board link (18 Nov 2026)
- Build number 1 (1.24 (1)). His pick 43 from the ideas list. Before: gym sessions lived only in the app; the Garmin Board on the Mac knew nothing of them. Now: the app writes a small file into his own iCloud Drive folder that the Board (Mac, version 1.10) reads.
- **Page.** Settings → "Garmin Board" (`settings-board`) opens `BoardLinkScreen`. "Choose folder" (`board-choose`) opens the Files picker; he picks the folder "AMS Garmin" in iCloud Drive once. `board-folder` shows the folder's name, `board-last` when the file was last written, `board-write` "Write now" writes at once, `board-stop` "Stop sharing" forgets the folder (the file already there stays), `board-problem` shows a red line if the file cannot be written, `board-done` closes the page.
- **File.** "Workout Companion sessions.json", written by `Library.writeBoardFile()` after every session finished, changed or deleted and when the app is left. Rule `GymLog.boardFile(now:)` in `Core/Sources/WorkoutCore/BoardLink.swift`: format 1, newest first, at most 60, finished sessions with at least one set. Per session: date, start and end, minutes, gym, title, how it felt, notes, machines, sets, kilograms lifted, minutes on time machines, new bests; per machine: name, muscle group, sets, heaviest weight, pain flag. No photos.
- **Board (Mac 1.10).** A "Gym sessions" panel: latest session with its machines, change against the session before, last 7 days against the 7 before, recent sessions.
- **Privacy.** Nothing leaves the phone except this one file into his own iCloud Drive folder; without a chosen folder nothing is written. Backups unchanged.
- **Texts.** What's new (1.24) and How it works (new entry "Garmin Board"; "Where things are kept") updated; version lists in Core `WorkoutCoreTests` and UI `testSettingsShowsTheVersionAndWhatsNew` now expect 1.24.

## Version 1.25 — gym chooser colour, −15 s rest, shorter session line with End (18 Nov 2026)
- Build number 1 (1.25 (1)). Three asks of his own, one round.
- **Gym chooser.** The pill with the gym's name at the top of the gym screen (`gym-place-menu`) is a full plum-coloured pill with light letters. Before: pale indigo with indigo letters, like the rest of the page, so it did not stand out. What it opens is unchanged.
- **Rest.** On the machine screen, the rest after a set now has "−15 s" (`gym-rest-less`) beside "+15 s" (`gym-rest-more`); both are small and sit on one line with "Skip rest" (`gym-rest-skip`). −15 s never takes the rest below 5 seconds left. Before: only +15 s, as a wide button.
- **Session line.** The green line on the gym screen (`gym-session-going`) now reads "7 sets", "1 set", "No sets yet" or "Paused", then the running clock (`gym-session-clock`), then a green "End" button (`gym-session-end`) on the same line. End does exactly what "Finish this session" at the bottom does: with sets, it finishes and opens Session done; with no set, it ends the session and saves nothing. Before: "Session going · 3 machines · 7 sets" and the clock, no button. "Finish this session" stays at the bottom. The line on Train is unchanged ("Session going · 42 min · …"). VoiceOver still reads the long words.
- **Texts.** What's new (1.25) and How it works (Sets & reps, At the gym, Logging a set, Session time, Rest on the lock screen) updated; version lists in Core `WorkoutCoreTests` and UI `testSettingsShowsTheVersionAndWhatsNew` now expect 1.25.
- **Test.** `UITests/Version125UITests.swift`: Leg press, Set done, −15 s and +15 s exist, tap −15 s, Skip rest, back to the machines, End appears, tap it, Session done opens, Done, the green line is gone.

## Version 1.26 — new look "Cards and glass" (18 Nov 2026)
- Build number 1 (1.26 (1)). The owner chose the look from a picture. Same functions, nothing moved in meaning; only colours and shapes.
- **Colours (whole app).** Page background: a soft indigo-tinted wash, day #eef0fa, night #121326. Before: grey, #f4f6f7 / #0e1416. Cards: white by day, deep indigo-grey #1d1f3a by night. Hairlines follow the same tint.
- **Gym head card.** The gym chooser (plum pill), the hint line and the three buttons (Plan today `gym-plan`, Repeat last visit `gym-repeat`, Save as template `gym-repeat-template`) are gathered into ONE rounded card at the top of the gym screen (`gym-head`). The three buttons are one joined row with the mark above the words; Repeat last visit stays full indigo. As before, once a session is going or a plan is set the three buttons are hidden; the card then holds the chooser and the hint.
- **Search field.** `gym-search` ("Find a machine", only with more than 8 machines) is a rounded capsule on the card colour, no outline. Before: outlined.
- **Machine tiles.** Before: the photo filled the tile and the name sat on a dark band over the photo's bottom edge (`tile-band-<name>`). Now each machine (`machine-<name>`) is a card: the photo on top with rounded corners, and under it a light band with the name in dark semibold and "Last: 59 kg" small in indigo. The Busy pill (`busy-<name>`) stays exactly where it was: bottom right of the photo, just above the name band. A busy machine has an orange outline and its line in orange (before: orange band). A machine done today keeps its indigo tick and outline. The muscle-group colour stripe on the left edge stays.
- **Bottom bar.** Train / History / Settings (`open-train`, `open-history`, `open-settings`) is now a rounded capsule, the chosen tab inside a pale pill of its colour. Before: a flat bar across the screen. Pages still end above it.
- **Unchanged.** All identifiers above; data, backups, behaviour.
- **Texts.** What's new (1.26) and How it works (Workouts, At the gym, Busy machines, Repeat last visit, Finding a machine) updated; version lists in Core `WorkoutCoreTests` and UI `testSettingsShowsTheVersionAndWhatsNew` now expect 1.26.
- **Test.** `UITests/Version126UITests.swift`: opens the gym screen (`-gymdemo`); `gym-head` exists; `gym-plan` and `gym-repeat` exist with frames inside the `gym-head` frame; `open-train` exists and is selected.

## Version 1.27 — gym name on the card, red End with a question, no muscle stripe, one indigo (18 Nov 2026)
- Build number 1 (1.27 (1)). Five asks of the owner, one round.
- **At the gym card (Train), second line.** Before: when nothing was logged today and no opening hours were given, it said how many machines were set up (for example "12 machines"). Now: the name of the chosen gym (for example "City gym"). Unchanged: "Today: 3 machines · 7 sets", the open-now line, and "Photo, weight and reps per machine" when there is no machine yet.
- **End button colour.** The "End" button on the green "Session going" line (`gym-session-end`) was green (white words on #15803d by day / #86efac by night), the same as the line. Now it is red: #dc2626 by day, #f87171 by night, so it stands apart from the line.
- **End and Finish ask first.** Before: tapping End (and Finish this session) ended the session at once. Now: `askingEnd` (state in `GymScreen`) opens an alert titled "End this session?" with the message "Are you sure? Your sets are saved and the clock stops." (with no set yet: "Are you sure? There are no sets yet, so nothing is saved."). Two buttons: "End session" (`gym-end-confirm`) and "Continue the session" (`gym-end-continue`); there is no button called Cancel. "End session" does what End did (with sets, finish and open Session done; with no set, end and save nothing). The big "Finish this session" button at the bottom of the gym screen (`gym-finish`) asks the same question too (build 2): before, it finished at once; now it sets the same `askingEnd`, opens the same alert (same texts, same two buttons and identifiers), and only "End session" calls `endSession()`.
- **Muscle stripe removed.** Before (since 1.11): each machine card on the gym screen had a 5-point stripe down the left edge of the photo in the machine's muscle-group colour (`tile-stripe-<name>`). Now: no stripe. Muscle groups themselves are unchanged (the machine's settings, History statistics).
- **One colour for three things.** Before: the gym chooser pill (`gym-place-menu`) was plum (since 1.25) while the At the gym card on Train and the "Back to gym" button on a machine's screen were indigo. Now: `Gym.place` uses the indigo swatch, the same as `Gym.fill` and `Gym.ink`, so all three are one indigo.
- **Texts.** What's new (1.27) and How it works (At the gym, Muscle groups on the tiles) updated; version lists in Core `WorkoutCoreTests` and UI `testSettingsShowsTheVersionAndWhatsNew` now expect 1.27. `project.yml` MARKETING_VERSION 1.27, build number 1.

## Version 1.28 — Workouts tab, bigger panel marks, plan page (18 Nov 2026)
- Build number 1 (1.28 (1)). Asks of the owner, one round.
- **First tab renamed.** Before: the first tab in the bottom bar was "Train". Now: "Workouts". Same page, same kettlebell mark, identifier still `open-train`; the page's big heading is still "Workout Companion".
- **Workout panel sizes (`WorkoutCard`, HomeScreen.swift).** Two panels side by side, one colour each. Workout icon top left: before 30 pt, now 42 pt. Pen top right: before 17 pt, now 24 pt, touch area 44 × 44 pt. Round play button bottom right: before a 28 pt circle with a 13 pt play mark, now a 44 pt circle with a 20 pt play mark. Panel height: before at least 128 pt, now at least 148 pt.
- **Three taps.** Before: a tap anywhere on the panel started the workout (the play mark was only a picture); the pen opened the editor. Now: tapping the panel only shows the plan (`WorkoutPlanScreen`, identifier `plan-screen`), a page that can be read but not changed; nothing starts and nothing can be edited there. Tapping the pen opens the editor as before (`edit-<name>`). Tapping the round play button starts the workout (`start-<name>`, VoiceOver "Start <name>"). The panel keeps its identifier `workout-<name>`; its VoiceOver label is now "<name>, <summary>" (before: "Start <name>, <summary>"). Press and hold on the panel still gives Edit, Duplicate, Delete.
- **Plan page.** Closed with "Done" (`plan-done`); on the Mac Escape closes it. At the top: the workout's icon, name and kind ("Sets & reps", "Exercise list", "Interval timer") on the workout's own colour. The body comes from the Core rule `Workout.plan` (`Core/Sources/WorkoutCore/Version128.swift`), a list of label/value lines with identifiers `plan-line-<n>`:
  - Sets & reps: "Sets" (e.g. 5), "Reps each set" (e.g. 20), "Rest between sets" (e.g. 1:30, or "None" when 0).
  - Interval timer: "Rounds", "Work", "Rest" (or "None"), "Total time".
  - Exercise list: every exercise in order with its number, name, amount, note and photo (`plan-exercise-<n>`); with no exercises: "No exercises yet".
- **New workout button moved (his picture, marks 1 and 2).** Before: `add-workout` was a 26 pt + in the top bar (top right; it cut into the large heading) and a dashed "New workout" tile (`add-workout-tile`) closed the grid. Now: the tile is gone (`NewWorkoutTile` removed, no `add-workout-tile`); `add-workout` is a round button, 56 pt, `Theme.accent` fill, white 26 pt +, soft shadow, bottom right of the page above the tab bar (16 pt from the right, 14 pt from the bottom), VoiceOver "New workout". The grid has 84 pt of room under it so the last panel is never under the button.
- **Unchanged.** Data, backups, the editor, the workout run screens, all other identifiers.
- **Texts.** What's new (1.28) and How it works (Workouts, and every place that called the first tab "Train" now says "Workouts") updated; the version list in Core `WorkoutCoreTests` expects 1.28.

## Version 1.29 — gym chooser plate (18 Nov 2026)
- Asks of the owner, one round: he sent a picture of the old menu, said it looked cheap and wanted it more premium, and picked look 2 of three numbered pictures, "Plate from the bottom".
- **Before.** Tapping the indigo pill with the gym's name (top left of the gym screen, identifier `gym-place-menu`) opened Apple's plain pull-down menu: a see-through glass panel of plain text rows with no icons. Each gym was a row (the one in use marked "— here now"; a long name such as "Basic-Fit Benalmadena" wrapped onto two lines), then "New gym…", "Log an earlier day…", "Rename this gym…", "Opening hours…".
- **Now.** Tapping the pill slides a plate up from the bottom (`GymChooserPlate`): a sheet about 60% of the screen tall with a grabber, which can be pulled up to full height. The pill itself is unchanged (full indigo, the gym's name and a small chevron).
- **Heading.** "Choose gym", large and centred.
- **Gym rows.** Each gym is its own rounded row: a small hand-drawn gym mark in a pale indigo square, the gym's name on ONE line (it shrinks a little rather than wrap), and under it, only when opening hours are given, the open-now line (e.g. "Open until 22:00"). The gym in use has an indigo outline, a small green "Here now" pill and a filled indigo circle with a white check; the others have a thin grey outline and an empty circle. Tapping a gym switches to it and closes the plate. Identifier `gym-place-<name>`; VoiceOver "<name>, here now" for the one in use.
- **Four buttons**, two rows of two, pale indigo with a hand-drawn icon above the word: "New gym" (`gym-place-new`, a plus), "Rename this gym" (`gym-place-rename`, a pen), "Opening hours" (`gym-place-hours`, a clock), "Log an earlier day" (`gym-pick-day`, a calendar). Each closes the plate and then opens what it opened before (the name box, the hours page, the day picker); nothing about those changed.
- **Done.** A full-indigo "Done" button at the bottom (`gym-place-done`; Escape on the Mac) closes the plate without changing anything.
- **Gym photo (his idea, same day).** `GymPlace.photo: String?` — the file name of the gym's own photo in the app's photo folder; nil = none; files from before 1.29 read as nil. `GymLog.setPhoto(gym:_:)` (Core `Version129.swift`) sets or removes it; `GymLog.photosInUse` now counts the gyms' photos, so the tidy-up of unused photos and the health check keep them, and backups carry them like every other photo. On the plate the square at the left of each row (48 × 48 pt, 11 pt corners, button `gym-photo-<name>`) shows the photo; without one it shows the hand-drawn gym mark on pale indigo with a small camera badge at the bottom right corner. Tapping the square opens a choice titled "Photo of <name>": "Take photo" (only where there is a camera), "Choose from Photos", "Remove photo" (only when there is one), "Cancel". The photo is stored through `Library.storePhoto` (scaled to 1600 px). With the launch argument `-tallphotos` the demo's first gym has a photo. Data test: `Version129Tests`.
- **Marks.** Two new hand-drawn marks in the app's own `AppMark` (App/Sources/Marks.swift): `clock` and `calendar` (24-point grid, one 1.9 stroke, round ends).
- **Unchanged.** Backups, the name box, the opening hours page, the day picker, all other identifiers.
- **Texts.** What's new (1.29) and How it works (At the gym) updated; the version list in Core `WorkoutCoreTests` expects 1.29.

## Version 1.30 — green tiles, wide gym button, template after the session, folded Earlier visits (18 Nov 2026)

- **Plan today and Repeat last visit.** Both are green and identical: two equal pale-green tiles, green mark and green words. Green is `#15803d` by day and `#86efac` by night, the same as the "Session going" line. Ids unchanged: `gym-plan`, `gym-repeat`. Before: Plan today was plain indigo words on a pale-indigo row; Repeat last visit was a full indigo tile (the singled-out main one).
- **Gym name button** (`gym-place-menu`, opens the Choose gym plate from 1.29). Full indigo, as wide as the card and 50 pt tall (the height of the two tiles); the gym's name on the left, a down chevron on the right. Before: a small capsule only as wide as the name. The "open now / opens at" hours line now sits under the button instead of beside it.
- **Save as template left the head.** The third tile `gym-repeat-template` (saved LAST visit's machines) is removed. The head shows two tiles only, still hidden once a session is going or a plan is set.
- **Save as template after the session.** After Finish this session → End session, the "Well done" summary has a "Save as template" button (`gym-summary-template`). It opens an alert "Save as template" with a text field (placeholder "For example: Leg day"), Save (`gym-summary-template-save`) and Cancel. It saves THIS session's machines in the order used as a plan template for this gym; the same name in this gym is replaced. Afterwards the button reads "Saved as template · <name>" with a check mark. The template is used under Plan today → templates. Core rule: `GymVisit.templateOrder(in:)` returns the machines with at least one set, in the order used, each once, only machines that still exist. Saving a plan as a template inside Plan today is unchanged, and so is deleting templates in Settings → Plan templates.
- **Earlier visits folded.** On the gym screen the list sits behind a toggle (`gym-earlier-toggle`): a card with a clock-style mark, the title "Earlier visits", a line like "12 sessions at Basic-Fit · last Mon 16 Nov", and a chevron that turns when open. Tap to show or hide; rows are still `gym-visit-1`, `gym-visit-2` … (newest first). Closed each time the gym screen opens. Before: the whole list always showed at the bottom under the heading "Earlier visits · <gym>".
- **Texts.** What's new (1.30) and How it works (At the gym, Plan today, Earlier visits, Two sessions in a day, Repeat last visit, Plan templates) updated.
- **Discard session.** The "End this session?" box (from the red End on the session line or from Finish this session) gets a third, red button "Discard session" (`gym-end-discard`), shown only once the session has at least one set. Before: only "End session" and "Continue the session". It asks again: box "Discard this session?", message "All N sets of this session are deleted. It will not show in Earlier visits or History. This cannot be undone.", buttons "Discard session" (`gym-discard-confirm`) and "Keep the session" (`gym-discard-keep`). Discarding deletes the open session and all its sets, stops the clock and clears that day's Busy marks and plan, like Finish; no Well done summary. Core rule: `GymLog.discard(visit:)`.
- **Discard on Session done.** A red "Discard" button (`gym-summary-discard`) at the LEFT of the bottom bar, beside Undo Finish and Done. Before: only Undo Finish and Done. It asks "Discard this session?" (all sets, title, notes and photos deleted; not in Earlier visits or History; cannot be undone) with "Discard session" (`gym-summary-discard-confirm`) and "Keep the session".
- **Stretch lists.** Settings → Reminder and stretch offers the app's own "After-gym stretch" plus six ready-made lists from `StretchCatalog`, each with a one-line summary under its name: Legs after leg day (calves, thighs and hips · 5 stretches), Upper body after push and pull (6), Lower back and hips (5), Neck and shoulders (6), Quick 3 minutes (4), After cardio (5); the owner's own exercise lists and None as before. A chosen ready-made list becomes an exercise list under Workouts the first time it is saved, then is his to change (`StretchRoutine` makes the Workout). Core: `StretchMove`, `StretchRoutine` (fixed ids 5A0E0001…0007), `StretchRoutine.move(named:)`.
- **Stretch guide.** New page `StretchGuideScreen`: a short how-to at the top (hold still, no bouncing, gentle pull not pain, breathe, both sides), then each stretch numbered with its time, 3–5 steps, "Where you feel it" (green) and "Careful" (orange); the owner's own stretches show their note. Opened from Settings → Reminder and stretch → "How to do these stretches" (`extras-stretch-guide`) and from Session done under Stretch now → "How to do the stretches" (`gym-stretch-guide`).

## Version 1.31 — weight during the rest, session clock on the machine page (18 Nov 2026)

- **Weight during the rest.** Under the rest ring, below "Next: set N · …", a pale-indigo capsule row "Weight (−) 34,5 kg (+)": ids `gym-rest-weight-minus`, `gym-rest-weight`, `gym-rest-weight-plus`. Steps by the machine's weight step; 0 shows "Body". It changes the weight of the next set at once and the "Next: set N" line follows. Only on machines that log weight (not reps-only, not time machines). Before: the weight could not be changed during the rest; Skip rest had to be tapped first.
- **Session clock.** A small pill at the top left of the machine page (`machine-session-clock`): green, with a softly pulsing dot and the session time h:mm:ss, ticking each second; grey and still when the clock is paused (20 minutes without a set). The same clock as the green Session going line on the gym screen. Before: no session time on the machine page, top left empty.
- **Texts.** What's new (1.31) and How it works (Logging a set) updated.

## Version 1.32 — guided stretch timer with voice cues (18 Nov 2026)

- **Timer.** New `StretchTimerScreen` (Core `StretchTimer` + `StretchPhase`). Per stretch: GET READY 8 s (orange): voice "First/Next/Last one: <name>. 30 seconds each side. Get into position.", then Three, Two, One. HOLD (green): "Hold. First side.", with "Halfway", "Ten seconds", Three-Two-One. For "each side" stretches: SWITCH SIDES 5 s (indigo, "Switch sides."), then HOLD side 2 ("Hold. Second side."). Hold time from the stretch's amount: "30 s each side" = 30 s, two sides; "60 s" or "1 min" = 60 s; no time = 30 s. End: "Stretch done. Well done." and a done page with Close; the session goes into History like a ticked list.
- **Screen.** Big ring with the seconds, phase pill, stretch name, guide steps and where you feel it, "Then: <next>", top line "Stretch 2 of 6 · 4:10 left" with a progress bar, headphones mark. Controls: previous stretch, big Pause / Go on (voice says "Paused" / "Go on"), next stretch; Close top left. Screen stays on. Voice plays in AirPods when connected (else the speaker), alongside music, with the silent switch on. Ids: `stretch-timer-phase`, `stretch-timer-seconds`, `stretch-timer-name`, `stretch-timer-progress`, `stretch-timer-next`, `stretch-timer-pause`, `stretch-timer-back`, `stretch-timer-skip`, `stretch-timer-close`, `stretch-timer-done`.
- **Where.** Session done → "Stretch now" starts the timer (line under it: "Timer with voice cues in your AirPods"); before, it opened the tick-off list. Any exercise list with times has a full-colour "Start the timer · Voice cues in your AirPods" button at the top (`run-stretch-timer`) until the first tick.
- **Texts.** What's new (1.32) and How it works (Two sessions in a day) updated.

## Version 1.33 — type weight and reps everywhere, no swipe back (18 Nov 2026)

- **Number area.** `NumberField` / `Stepper2` (kg, reps, and seconds, minutes, level, incline): a tap anywhere on the area between − and + focuses the field and selects the whole number, so typing replaces it (e.g. 32,5). Comma and point both parse. Done on the keyboard closes it. Before: only a tap exactly on the digits opened the keyboard. Ids `gym-weight`, `gym-reps` unchanged.
- **During the rest.** `gym-rest-weight` is now a text box (was a read-out) between `gym-rest-weight-minus` / `gym-rest-weight-plus`. New Reps row under it: `gym-rest-reps-minus`, `gym-rest-reps`, `gym-rest-reps-plus` (step 1); changes the reps of the next set, the "Next: set N" line follows. Typed or −/+. Before: only −/+ for weight (1.31), none for reps.
- **Change a set.** `set-edit-reps`: a typed box plus −/+ (was a stepper only).
- **Next time form.** `next-time-kg`, `next-time-reps`: typed boxes plus −/+ (were steppers only).
- **No swipe back.** `noSwipeBack()` (App/Sources/NoSwipeBack.swift) disables the interactive pop gesture (edge swipe, and the full-page swipe of iOS 26) on the machine page, the gym page, History and Settings. Pages are left only with the Back button (top left) or the bottom button. Before: a sideways finger while double-tapping the weight could go back to the gym page.
- **Texts.** What's new (1.33) and How it works (Logging a set) updated.

### Build 2 — blue instead of indigo (his ask, 18 Nov 2026)
- `Gym.swatch` = `IconColour(key: "gymblue", hex: "#2f6fe0", ink: "#ffffff")` (= `Theme.accent`, the round + on Workouts); before IconColour "indigo" #4f46e5. `Gym.tint` = #2f6fe0 / #8ab4ff (before #4f46e5 / #9d97ff). `Gym.band` = #0f2347 (before #1e1b4b). Everything that used the gym colour follows: At the gym card, gym chooser + plate, Set done, steppers, rest rows, headings.
- `machine-done-pill` (Back to gym / Exercise done): `BigButtonStyle(fill: Gym.soft, ink: Gym.tint)` — solid pale blue #dbe6fb / #1e2f52 with blue words; before full indigo like Set done. `gym-set-done` = full green `Gym.done` #16a34a / #15803d, white words (his ask: "something positive"); before full indigo.
- Rest weight: 0 kg shows "0" in the box (before the text "Body").

### Build 3 — coloured rest buttons (his ask, 18 Nov 2026)
- `SoftButtonStyle` gained `tint: (fill, ink)?` (fill + words + a 25 % ink outline; nil = the old plain card).
- `gym-rest-less` = `Gym.less` (#fef6d8 / #352d0e, words #a16207 / #fcd34d); `gym-rest-more` = `Gym.more` (#ffeedd / #3a2212, words #c2410c / #fdba74); `gym-rest-skip` = `Gym.skip` (#e0f7e7 / #12321f, words #15803d / #86efac) — before white, white, full indigo.

## Version 1.34 — choose your stretches, save a stretch early, framed bottom button (18 Nov 2026)

- **Bottom button.** `machine-done-pill` (Back to gym / Exercise done) gained an overlay stroke `Gym.fill`, width 2 — the same frame as a done machine tile on the gym page. Before: pale blue, no frame.
- **Chooser.** New `StretchChooser`: "Choose the stretches for today", one row per stretch (name + amount), all ticked at first; tap a row to tick/untick. "All" / "None" top right with "4 of 6 chosen". Full-colour Start at the bottom, "About 5 min · voice cues in your AirPods" under it. Only ticked stretches are timed, in list order (`StretchTimer.choosable`). Ids `stretch-choose-1`…`stretch-choose-N`, `stretch-choose-all`, `stretch-choose-all` (says None when all are ticked), `stretch-choose-count`, `stretch-choose-start`. Shown by Well done → Stretch now and by "Start the timer" on a timed list. Before: the timer started at once with every stretch.
- **Choose while stretching.** `stretch-timer-choose` (round list button, bottom left) pauses and opens the chooser as a sheet ("Go on with these"). Stretches already held show "Held" and stay; the timer continues with the first chosen stretch not yet held.
- **Save early.** `stretch-timer-save`: green "Save" pill at the top right; it replaces the headphones mark while the timer runs (the mark stays on the chooser and the done page). Stops and saves what was held; a hold more than half done counts. Done page "3 of 4 stretches · 4:12"; voice "Saved. Well done." (full run: "Stretch done. Well done."). Close (×, `stretch-timer-close`) keeps what was held, as before.
- **History rule.** Core `SessionRecord.ofStretch(_:started:ended:held:chosen:)` (Version134.swift): saved as "3 of 6 stretches" or, when only some were chosen, "3 of 4 chosen stretches" (before "3 of 6 exercises"); complete when all chosen were held. A stretch now counts as held when its hold ran out (before: only when the timer moved past it).
- **Checked.** Warm-up sets are saved with the gym session and show in History as chips with a "W" and a frame on the visit, in the machine's history lines, and in the "Warm-up and cardio" card; a stretch session shows as its own History row (verified by a test).
- **Texts.** What's new (1.34) and How it works (Two sessions in a day; Exercise done and one-hand buttons) updated.

## Version 1.35 — At the gym card without the gym name (18 Nov 2026)

- **At the gym card (Workouts), second line.** Before (1.27 to 1.34): when nothing was logged today and no opening hours were set, the second line showed the name of the chosen gym (for example "City gym"). Now: that case shows no second line, only "At the gym".
- **Unchanged lines.** The second line still appears only when it says something: "Today: N machines · N sets" after sets today, the open-now / opening line (for example "Open until 22:00") when the gym's opening hours are set, and "Photo, weight and reps per machine" before any machine exists. The gym's name is still shown on the gym screen (`gym-place-menu`) and on the Choose gym plate.
- **Texts.** What's new (1.35) and How it works (At the gym) updated; the version list in Core `WorkoutCoreTests` and UI `testSettingsShowsTheVersionAndWhatsNew` now expect 1.35.

## Version 2.0 — warm-up, one stretch library, pictures, one Well done, instruction view, rest voice (19 Nov 2026)

- **Signs in this app (How it works chapter, 2.0).** `AppText.howItWorks` has a chapter "Signs in this app" listing every mark and colour with its meaning (tick = finished machine, pencil + "Change" = change a logged set, green session line, red End, orange Busy pill, yellow Warm-up pill, gold arrow, Pain pill, rest button tints, star, suggested dot, drag handle, trophy gold, time bar colours, instruction picture, mirrored figure). On a logged set the filled-circle tick was replaced by a pencil (`ControlMark.edit`) and the word "Change" (caption, tint); identifier `gym-set-N` unchanged. How it works › History now says five tiles (Sessions, Minutes, Exercises, Sets, Lifted) and a 12-week chart.

Version 2.0 (build 1). Data envelopes stay `"version":1`; every new field is optional and decoded with `decodeIfPresent`, so old files and old backups load unchanged.

### Warm-up
- **Tile.** `gym-warmup-start`, green, "Warm up", in the Plan today / Repeat last visit row. Shown on today's gym page before the first set and until a warm-up has ended (`warmup.end == nil`). Before 2.0 there was no warm-up part, only single warm-up sets (`GymSet.warmup`, unchanged).
- **Chooser (`WarmUpScreen`, cover "Warm-up").** Chips: one per time machine of the gym, `warmup-choose-outside` ("Walk or run to the gym"), `warmup-choose-moves` ("Warm-up moves"). Minutes `warmup-minutes` with `warmup-minutes-minus` / `warmup-minutes-plus` (default 8, remembered). Moves list (`warmup-moves`, rows `warmup-move-<n>`): about 10 `DynamicMove`s, tick, hold and drag to reorder; none ticked = all moves. `warmup-start`, `warmup-cancel`. Last kind, minutes, machine and moves are remembered in `StretchBook.warm` (`WarmPrefs`).
- **Start = session start.** `GymLog` start creates or gets today's visit the way the first set does, stores `GymVisit.warmup` (never as sets) and starts the session clock. Without a warm-up the clock starts at the first machine, as before.
- **Run (`WarmUpRunScreen`).** Session clock pill, ring `warmup-clock` (mm:ss), `warmup-minus` / `warmup-plus` ("−1 min" / "+1 min"), `warmup-pause`, `warmup-skip`, fields `warmup-speed` (Speed), `warmup-level` (Level), `warmup-hr` (Heart rate, cardio), full-blue `warmup-done` ("Done — to the machines"). Moves: `warmup-figure` (animated), `warmup-name`, "n of N", voice "Next: <name>", "Other side", "Warm-up done"; −/+ change the current move by 10 s ("−10 s" / "+10 s"); Skip goes to the next move.
- **Heart rate.** When a cardio warm-up ends with no typed number, the app reads the average from Apple Health (heart rate, window warm-up start to end; read permission asked once, `NSHealthShareUsageDescription`). Line `warmup-hr-note`: "Heart rate comes from Apple Health when your Garmin syncs." A typed number wins; a refusal never blocks the warm-up. Nothing is written to Health.
- **Data.** `GymVisit.warmup: VisitPart?` with `kind` (`cardio`, `moves`, `outside`), `start`, `end`, `machineID`, `plannedMinutes`, `speed`, `level`, `heartRate`, `names` (move ids), `held`, `skipped`. Warm-up minutes are warm-up time only: never cardio minutes, records or New best.
- **Chip.** `gym-warmup-chip`: "Warm-up · 8 min · Treadmill" (or "· Moves", "· Walk or run"). Tap = sheet "Warm-up": `warmup-chip-minutes` / `warmup-chip-stepper`, `warmup-chip-speed`, `warmup-chip-level`, `warmup-chip-hr`, `warmup-hr-read` ("Read again"), `warmup-chip-cancel`, `warmup-chip-save`.
- **Edge cases.** A warm-up-only visit is kept (never removed as entry-less) and shows in Earlier visits and History with its minutes. The 20-minute idle pause does not apply during warm-up or stretching.

### End box, stretching and the session end
- **End box.** "End this session?" (red End and "Finish this session"): `gym-end-stretch` "Stretch now" (hidden when there are no sets and no warm-up), `gym-end-confirm` "End session", `gym-end-discard` "Discard session" (only with sets), `gym-end-continue` "Continue the session". End session on a warm-up-only visit: "Your warm-up is saved and the clock stops." With no sets and no warm-up, End still saves nothing.
- **Stretch now.** The machines end at that moment (`GymVisit.finished`, rule of 1.20), the stretch chooser opens, the clock runs through the stretching; when the timer ends or Save is tapped, `GymVisit.stretching = VisitPart(kind: stretch, start, end, names, held, skipped)` is stored and the one Well done opens. A stretch inside a visit makes no separate `SessionRecord`. Stretch-only from the Workouts tab is unchanged (its own `SessionRecord`).
- **Time rules (Core, `GymVisit`).** Start = `warmup.start` else first set; end = `stretching.end` else the Finish / last-set rule. `minutes` includes warm-up and stretching. The split (warm-up, machines, stretching) is whole minutes; old visits: (0, minutes, 0).

### Stretching
- **Library (`StretchLibrary`, Core, code not data).** 30 `StretchItem`s with fixed ids, in areas Neck and shoulders, Arms, Back and core, Hips and glutes, Legs, Finish; each has name, muscles, default hold, sides, figure and the 1.30 guide fields; plus 10 `DynamicMove`s for the warm-up. Old stretch names resolve through an alias table.
- **Chooser "Stretches" (`StretchChooser`).** `stretch-suggested-line` "Suggested for today: legs, back" (from the muscle groups of today's machines; those stretches pre-ticked, with a dot). "My stretches" (`stretch-mine-<n>`): his order, handle `stretch-drag-<n>` ("Hold the handle and drag to change the order."), circle `stretch-choose-<n>` unticks, star `stretch-fav-<n>` = favourite, tap row = hold sheet (`stretch-hold-sheet`, `stretch-hold-minus` / `stretch-hold-plus`, `stretch-hold-value`, 5-second steps, Cancel `stretch-hold-cancel` / Save `stretch-hold-save`). Library by area (`stretch-area-<key>`), favourites first, tap to add (`stretch-add-<id>`). `stretch-choose-count`, `stretch-choose-all`, `stretch-choose-close`, full-green `stretch-choose-start` "Start · about N min". "Own stretch" `stretch-own-add`.
- **Own stretch (`CustomStretchForm`).** Fields `stretch-own-name`, `stretch-own-seconds`, `stretch-own-sides` (One side / Both sides), `stretch-own-note`, `stretch-own-area`, `stretch-own-photo`; `stretch-own-delete`, `stretch-own-cancel`, `stretch-own-save`. Id "my-<uuid>".
- **Memory: `StretchBook`** (in gym.json, key `book`, `GymLog.stretchBook`): `ticked [String]` (order = list order), `holds [String:Int]`, `favourites [String]`, `custom [CustomStretch]` (id, name, seconds, sides, note, area, photo), `warm WarmPrefs`, `migratedFrom UUID?`. Own-stretch photos count in `photosInUse`.
- **Migration.** First 2.0 launch with no book: the old list (`GymLog.stretchID`) is taken over once: each exercise in order → library id, else a new own stretch (name, amount, note, photo kept); `migratedFrom` makes it idempotent. The old list is never edited. Settings → Reminder and stretch keeps its "Stretch list" picker.
- **Timer (`StretchTimerScreen`).** `stretch-figure` (big, mirrored on side 2) or his photo; `stretch-skip` "Skip" (next stretch, counted as skipped); the 1.34 controls and `stretch-timer-*` ids unchanged. Guide `StretchGuideScreen`: `stretch-guide-figure-<n>` on top of each stretch.
- **History.** Detail text adds "· N skipped" when N > 0. Visit page: Stretching row (minutes, "N held · N skipped").

### Figures
- One string per figure in Core `FigureData` (hand-drawn, one flowing line, no fill; head, limbs, curved back, props), parsed by `FigureParser`; grid 64×64; `FigureView(size:, mirrored:)` in `App/Sources/Figures/`; colour from the area. A warm-up move has two frames, animated in a slow loop (frame 1 when Reduce Motion is on). Side 2 = mirrored, no second drawing. Core tests: every item has a figure, every figure parses and stays inside the grid.

### Well done (`SessionDoneScreen`)
- One page, at the very end (after End session or after the stretching). Top: `done-photo` (first session photo big) with the trophy badge `done-trophy` on its corner; no photo = trophy large and centred. Trophy every visit: gold after a personal best, blue otherwise.
- `done-timebar`: Warm-up (orange), Machines (blue), Stretching (green) with minutes (`done-time-warmup`, `done-time-machines`, `done-time-stretch`); parts at 0 are left out; no bar with machine time only.
- `done-week`: tile "Sessions this week" (Monday start, this one included).
- `gym-stretch` "Stretch now" on Well done only when not stretched yet; opens the same stretching for this visit. Since 2.2 the card sits right under the picture and title (see Version 2.2 for the whole order).
- Share picture and `VisitShare`: lines "Warm-up 8 min · Treadmill" and "Stretching 9 min · 6 stretches" when present. Visit page: Warm-up row (kind, minutes, "9.5 km/h · 128 bpm") and Stretching row.

### Instruction view
- `Machine.howTo: String?` (CodingKeys and `init(from:)`); field `machine-howto-field` "How to use it" in the machine settings, footer "Shown with the instruction photo when you tap the small picture beside the machine name."
- Thumb `machine-howto-thumb` beside the machine name; `plan-howto-<n>` on each Plan today row. Source: instruction photo, else machine photo, else the machine's mark. Tap = `InstructionViewScreen`: `howto-name`, `howto-plate` (pinch to zoom, double-tap resets), `howto-photo`, `howto-setting` "Your setting: …", `howto-words`, `howto-close`. Nothing: `howto-empty` "No instructions yet — add a photo or a few words in the machine's settings."

### Rest voice
- `RestCuePlan.marks(restSeconds:)`: 30, 20, 10 where mark ≤ rest − 2, plus 3, 2, 1 when rest ≥ 4 (90 s → 30, 20, 10, 3, 2, 1; 25 s → 20, 10, 3, 2, 1; 5 s → 3, 2, 1; 3 s → none). Words "Thirty seconds", "Twenty seconds", "Ten seconds", "Three", "Two", "One". Each said once, also after −15 s / +15 s (`due(secondsLeft:marks:said:)`). Settings → Sounds → "Spoken countdown" (`sounds-spoken`) off: ticks only. Since 2.2 the same marks are also said in Sets & reps rests and Interval off rounds (see Version 2.2).
- Ducking: `Cues` ducks other audio while speaking; music returns about 0.4 s after. Needs a real device to hear.
- `RestSound.soft` "Soft chime" is the new default (older settings with another value decode as before); also the lock-screen rest sound.

### Garmin Board file (format stays 1)
- `BoardFile.Session` gains optional `warmupMinutes`, `warmupKind`, `warmupSpeed`, `warmupHeartRate`, `stretchMinutes`, `stretchCount`. `minutes` and `end` include warm-up and stretching; `cardioMinutes` excludes the warm-up. Old readers ignore the new fields.

### Data and backup
- gym.json: `Machine.howTo`; `GymVisit.warmup`, `GymVisit.stretching` (`VisitPart`); `StretchBook` under `book`. Backup files stay `workouts.json`, `gym.json`, `history.json` (the book travels in gym.json); an older backup restores as before and the stretch page then takes over the old list again. Check my data keeps own-stretch photos.

### Tests (lean)
- Core, one per rule: old JSON decodes and new fields round-trip; split and minutes; warm-up-only visit kept; book migration; suggested stretches; rest marks; figures parse; Board fields only when set. UI (by identifier): warm-up to `gym-warmup-chip`; End box buttons; chooser and `stretch-drag-1`; timer `stretch-figure` and `stretch-skip`; Well done `done-trophy`, `done-timebar`, `done-week`; `machine-howto-thumb`; the version list expects 2.0.
- **Texts.** What's new (2.0) and How it works (new chapters Warm-up, Stretching, Instruction pictures, Rest voice; changed Sounds and words, At the gym, Plan today, Instructions photo, Machines for time, Session time, Two sessions in a day, Garmin Board, Sharing a visit, Warm-up sets, Backups, Where things are kept) updated.

## Version 2.1 — warm-up moves that fit today's plan (19 Nov 2026)

Version 2.1 (build 1; the build number goes back to 1). Data envelopes unchanged; no new stored fields.

### Suggested warm-up moves
- **Where.** Gym page, tile `gym-warmup-start`, then chip `warmup-choose-moves` ("Warm-up moves"): the list of the 10 moves (`WarmUpScreen`).
- **Core rule.** `GymLog.suggestedWarmupMoves(gym:on:)` in `Core/Sources/WorkoutCore/Version21Warmup.swift` returns the move ids that suit today's muscle groups. Today's muscle groups are the groups of the machines in today's plan at this gym (machines skipped or removed from the plan do not count); with no plan for today, the machines of the last visit at this gym. Groups: chest, back, shoulders, arms, legs, core; Martin's own group names count when the name says so. With no plan and no last visit the result is empty and everything works as in 2.0.
- **Merge rule.** `WarmPrefs.movesShown(saved:suggested:)` (same file): his remembered ticks and their order stay; suggestions only ADD ticks; suggested moves he does not have yet come right after his own ones. With nothing remembered, only the suggested moves are ticked (before 2.1: all 10 were ticked).
- **Marks.** A suggested move carries a small blue dot and the blue word "suggested" (id `warmup-move-suggested-N`, N = the move's place in the list; the tick button `warmup-move-N` reads "<name>, suggested, ticked"), the same mark the stretch chooser uses. The mark means one thing for stretches and warm-up moves: suggested for today's machines.
- **Line.** Under the list title, `warmup-suggested-line`: "Suggested for today: legs, back" (the groups found). Hidden when nothing is suggested.
- **Start.** The ticked moves are remembered for next time, as before; with none ticked all moves are done (unchanged from 2.0).
- **Library data.** `StretchLibrary` moves: Arm circles now counts for shoulders, chest and arms; Inchworm for legs, core, shoulders and chest (before: no move was linked to chest or arms). The stretches are unchanged.
- **Demo check.** With `-gymdemo -gymextras` the last demo visit did Chest press and Lat pulldown, so the line reads "Suggested for today: chest, back" and Arm circles, Inchworm, Torso turns and World's greatest stretch come first, ticked.

### Tests (lean)
- Core `Version21Tests`: one data test per rule (suggested moves from plan, from last visit, none; merge with remembered ticks and order; nothing remembered → only suggested).
- UI `Version21UITests`: one screen test finding `warmup-suggested-line` and `warmup-move-suggested-N`.
- **Texts.** What's new (2.1), How it works (Warm-up; Signs in this app: the blue dot and "suggested" widened to warm-up moves).

## Version 2.2 — Stretch now and Save as template up top, rest voice in every rest (21 Nov 2026)

Version 2.2 (build 1). Data envelopes unchanged; no new stored fields. Both changes are the owner's ask.

### Session done: new order (`App/Sources/Screens/SessionDoneScreen.swift`)
- **Before (2.1).** Well done (picture and title), `done-timebar` / `done-week`, How did it feel (`gym-feel-*`), Title and notes, Photos, the numbers, Against last visit, Save as template, Stretch now, New bests.
- **Now (2.2).** Well done (picture and title), then the "Stretch now" card (`gym-stretch`, with "How to do the stretches"), then the "Save as template" card (`gym-summary-template`, footer "Keep this session's machines and order for another day."), then `done-timebar` / `done-week`, How did it feel, Title and notes, Photos, the numbers, Against last visit, New bests.
- **Rules unchanged.** "Stretch now" still shows only when the visit has not been stretched yet (so then the Save as template card is directly under the picture and title); Save as template still saves this session's machines in the order used (`GymVisit.templateOrder(in:)`), same name replaces, "Saved as template · <name>" afterwards. Nothing else on the page changed: same cards, buttons, texts and identifiers, only moved. Why: both were far below the numbers and needed scrolling right after a session.
- **Side effect on the UI tests.** Items now below the two cards can be off screen on a small iPhone, so the tests scroll to them with `app.reveal` before tapping or reading: `Version125UITests`, `Version20DoneUITests` (the `done-week` tile), `WorkoutCompanionUITests` (the title field) and `ScreenTour`. `Version123ScreensUITests` now checks that "Stretch now" is above "How did it feel" (it was below before).

### Rest voice in Sets & reps and Interval workouts (`SpokenCue.word`, `Core/Sources/WorkoutCore/Sounds.swift`)
- **Before 2.2.** A rest between sets in a Sets & reps workout and an off (rest) round of an Interval workout said only "Three", "Two", "One". Only a gym machine rest (since 2.0, `RestCuePlan`) said "Thirty seconds", "Twenty seconds", "Ten seconds" first.
- **Now.** Both say the same marks as a gym rest, from `RestCuePlan.marks(restSeconds:)`: 30, 20, 10 where mark ≤ rest − 2 (each only when it falls at least 2 s inside the rest), then 3, 2, 1. Words "Thirty seconds", "Twenty seconds", "Ten seconds", "Three", "Two", "One". Examples: a 20 s rest says "Ten seconds", 3, 2, 1; a 90 s rest says all six.
- **Setting.** Follows Settings → Sounds → "Spoken countdown" (`sounds-spoken`); off: a tick at 3, 2, 1 as before. The tick stays quiet while the voice counts.
- **Unchanged.** Work rounds of an Interval workout: "Halfway" (work 20 s or longer), "Ten seconds" (work 30 s or longer), Three, Two, One. The gym machine rest is as in 2.0 (also after −15 s / +15 s, each said once).

### Tests (lean)
- Core `Version22Tests`: data tests for the new rest marks in `SpokenCue.word` (20 s and 90 s rests).
- `Version123SoundTests`: two lines changed to expect the new rest words.
- UI: see the scroll changes above (`app.reveal`); `Version123ScreensUITests` order check.
- **Texts.** What's new (2.2) and How it works (Two sessions in a day, Stretching, Plan templates, Sets & reps, Interval timers, Sounds and words, Rest voice) updated.

## Version 2.3 — Tailored intervals (23 Nov 2026)

Version 2.3. A fourth workout type, "Tailored intervals": intervals where every part has its own length, for example jog 1 min, walk 1 min, jog 2, walk 2, jog 3, walk 3, jog 2, walk 2, jog 1, walk 1. The owner asked for it on 23 Nov 2026. In a question round he chose three things: a free list of steps (each step its own name and time, rather than jog + walk pairs), a voice that says his word plus the length, and the name "Tailored intervals". The other three types are Sets & reps, Exercise list and Interval timer.

### Data (package Core / WorkoutCore)
- **Kind.** `WorkoutKind.tailored`, raw value "tailored", title "Tailored intervals", blurb "Your own steps, each with its own name and length.", usual colour violet, usual icon the runner ("run").
- **Fields.** `IntervalStep` { id, name, seconds } and `Workout.steps: [IntervalStep]`. A file from before 2.3 has no `steps`: it reads as an empty list. Every kind keeps all its fields, as before.
- **Rules** in `Core/Sources/WorkoutCore/Version23Tailored.swift`:
  - `Workout.tailoredTotal`: the sum of the steps' seconds.
  - `Workout.stepName(at:)`: the trimmed name, or "Step N" when the name is empty.
  - `Workout.nextStep()`: the step that Add step appends. Its name is the name of the step two lines up, else empty; its seconds are those of the last step, else 60.
  - `IntervalStep.lengths`: the ready lengths in the menu: 0:10, 0:15, 0:20, 0:30, 0:45, 1:00, 1:30, 2:00, 2:30, 3:00, 4:00, 5:00, 6:00, 8:00, 10:00, 12:00, 15:00, 20:00, 30:00, 45:00, 60:00.
  - `IntervalStep.stepped(_:up:)` (the − and + buttons): 5 s under one minute, 15 s up to five minutes, 60 s above; never below 0:05 and never above 60:00.
  - `IntervalStep.most` = 60 steps.
  - `IntervalStep.example`: the ten jog/walk steps of 1-1-2-2-3-3-2-2-1-1 minutes, 18:00 in all.
  - `Workout.starting(_ kind:)`: a new workout of a kind; a Tailored one starts with the example.
  - `SpokenLength.words(_:)`: "45 seconds", "1 minute", "2 minutes", "1 minute 30 seconds".
  - `TailoredCue.start(name:seconds:isLast:)`: "Jog. 2 minutes." and, for the last step, "Last step. Walk. 1 minute."
  - `Plan.notices(...)`: the notifications still to come: one per later step and one for the end.
- **Phases.** `Phase.step(seconds:name:number:of:)`. `Plan.phases` for a Tailored workout = Get ready 5 s, then one step phase per step; no steps, no phases.
- **Summary line.** "10 steps · 18:00"; "1 step · 1:00"; "No steps yet". Plan page: one line per step ("1 · Jog" with "1:00") and "Total time".
- **History record.** "N of M steps"; none when the workout ended before the first step was over.

### New workout and editor
- **Chooser.** The new-workout chooser lists four types; the new card has the identifier `new-tailored`. A new Tailored intervals workout opens the editor with the example filled in.
- **Type switch.** Sets / List / Intervals / Tailored.
- **Section "Steps".** Per line: the name field (`step-name-N`); the length as a menu button (`step-time-N`) that opens the ready lengths; − / + (`step-stepper-N`). The ≡ grip at the right drags the line to a new place (drag and drop; the owner's rule of 23 Nov 2026: never arrow buttons for ordering). The red minus at the left removes the line.
- **Add step** (`editor-add-step`).
- **Footer.** The total (`editor-steps-total`) and one sentence saying what a tap on the time, − / + and the ≡ grip do.
- **Save.** With no steps it shows "Add a step first." (`editor-steps-needed`). Save is never grey.

### Run screen (the same `TimerScreen` as the Interval timer)
- **Get ready** shows "First: Jog 1:00".
- **Each step.** The step's name in capitals as the phase word (`run-phase`); the countdown ring in the workout's colour; "Step 3 of 10" under the time; "Next: Walk 2:00" or "Last step" (`run-next`). Pause / Resume and Skip.

### Voice
- At each step start: the rest-over sound and, for example, "Jog. 2 minutes."
- Inside a step: Halfway (step 20 s or longer), Ten seconds (step 30 s or longer), then Three, Two, One.
- At the end: "Well done. Workout complete."

### Phone locked or app in the background
- One notification per coming step change ("Walk · 2:00" with "Step 4 of 10 · <workout name>") and one for the end, with the chosen rest-over sound. They are set again after Pause, Resume and Skip and removed when the workout closes.
- The current step also shows as the lock-screen card (Live Activity) with its end time and what comes next.
- The spoken words need the app open: there is no background audio.

### Tests (lean)
- Core `Core/Tests/WorkoutCoreTests/Version23Tests.swift`: data tests for the rules above.
- UI `UITests/Version23UITests.swift`: one screen test: make a Tailored workout, save it, start it, see the first step.
- **Not proven on a real phone:** the voice outdoors, and the notifications with the phone locked.

## Version 2.4 — speed or power, Effort or Easy, and exercises dragged into order (24 Nov 2026)

Changed in 2.5: the free 'Speed or power' line and the Effort / Easy button were replaced — see Version 2.5.

Version 2.4 has four changes: (A) speed or power for each step of a Tailored intervals workout, (B) Effort or Easy for each step, (C) the plan page with each figure right beside its name, and (D) exercises dragged into order. The notes on D follow after A to C. The owner's rule (23 Nov 2026): every list he puts in order is drag and drop, never up/down arrows or "move up / move down" commands. The Exercise list editor was the last place in this app that still broke it. He said yes to fixing it on 24 Nov 2026.

### A. Speed or power for each step (ask of 24 Nov 2026, with a screenshot of the Steps list)
- **Before 2.4:** a step of a Tailored intervals workout had only a name and a length.
- **Editor.** Every step has a second, smaller line. At its left: a field "Speed or power", free words (for example "8 km/h", "150 W", "5:30 /km"). It may be empty; then nothing is shown anywhere. Identifier `step-target-N`.
- **Where it shows:** the run screen, right under the step's name and above the countdown (`run-target`); after the length in "First: Jog 1:00 · 8 km/h" and "Next: Walk 2:00 · 5 km/h"; the plan page, after the step's length ("1 · Jog 1:00 · 8 km/h"); the notification that marks a change of step with the phone locked ("Jog · 2:00 · 8 km/h"); the lock-screen card ("Jog 8 km/h · <workout name>").
- **Voice:** says it after the length: "Jog. 2 minutes. 8 km/h."
- **Add step** copies the speed or power of the step two lines up, together with its name (the seconds still come from the last step).
- **Data:** `IntervalStep` gains `target: String` (empty by default). A file written before 2.4 without it reads as empty. `Workout.nextStep()` copies name, target and easy from two lines up and the seconds from the last step. `TailoredCue.start(name:seconds:isLast:target:)`. `Plan.notices(phases:index:left:name:steps:)` adds the target to the title. `Workout.step(of:)` gives the step behind a running phase. `Workout.plan` puts the target after the length.

### B. Effort or Easy for each step
- **Before 2.4:** every step ran in the workout's colour.
- **Editor.** On the same second line, at the right: a small button with the word "Effort" (workout's colour) or "Easy" (grey). A tap switches between the two. Identifier `step-effort-N`. The foot text under the list now also says: "Effort or Easy: tap the word to switch. An Easy step runs on a grey ring."
- **Running.** An Effort step: ring and step name as before (workout's colour). An Easy step: grey ring and the name in grey, the same grey as a rest in the other workout types. Nothing else differs: the voice, the countdown words and the Skip button are the same for both.
- **Defaults.** The ready-made example (jog and walk 1, 2, 3, 2, 1 minutes) has Jog as Effort and Walk as Easy (`IntervalStep.example` has the Walk steps easy). Steps saved with 2.3 are all Effort until changed. Add step copies Effort/Easy from the step two lines up.
- **Data:** `IntervalStep` gains `easy: Bool` (false by default = Effort). A file without it reads as Effort.

### C. Plan page: the figure right beside its name
- The plan page opens when the owner taps a workout's tile on Workouts. His rule: a figure stands right beside its name, on the left, never at the far right edge.
- **Before 2.4:** each line had its name at the left and its figure at the far right edge.
- **Now:** the figure follows the name: "Sets 5", "Rest between sets 1:30", "1 · Jog 1:00", "Total time 18:00". This holds for Sets & reps, Interval timer and Tailored intervals. Exercise lists look as before.

### D. Exercises dragged into order (notes below)

### Where
- Workouts, the pen on an Exercise list workout (or the round + then Exercise list), then the editor.

### Before 2.4
- Every exercise's heading ("Exercise 1", "Exercise 2" ...) had a ••• button with a menu: Move up, Move down, Remove. Remove in the menu removed at once, without asking.

### Now
- **Order block.** A new block "Order" sits above the exercises, as soon as the list has two or more exercises. One short line per exercise: its name (or "Exercise 3" while it has no name yet) and the ≡ grip at the right. Hold the grip and drag the line to its place; the exercises below follow at once. Under the block: "Hold ≡ and drag to put the exercises in order."
- **Remove.** The ••• button and its menu are gone. Each exercise's heading has the red word "Remove" instead. A tap asks first: "Remove Bridge?" with a red Remove button (id `exercise-remove-confirm`); a tap beside the question closes it and keeps the exercise.
- **Saving.** As before, nothing is stored until Save; Cancel leaves the workout as it was.
- **Unchanged.** Name, amount, note and photo of an exercise, Add exercise, ticking off a list. No data changed.

### Identifiers
- Order lines `exercise-order-N`, the Remove word `exercise-remove-N`, the confirm button `exercise-remove-confirm`.

### Tests (lean)
- Core `Core/Tests/WorkoutCoreTests/Version24Tests.swift`: data rules for A and B (target and easy defaults, older files, `nextStep()`, example, cue, notices, plan).
- UI `UITests/Version24UITests.swift`: `testAStepCarriesSpeedOrPowerAndEffortOrEasy` (A and B), and `testExercisesAreDraggedIntoOrderAndRemovedByWord`. The drag part is skipped on GitHub's simulator, like the plan-drag test, and runs on the Mac.
- Version lists: `AppTextTests` (2.4 first) and `testSettingsShowsTheVersionAndWhatsNew` (2.4, `whatsnew-2.4`).
- Checked in the simulator, day and night. **Not yet tried by hand on a real phone:** the drag, and speed or power and Effort or Easy on a run.
- **Texts.** What's new (2.4) and How it works (Making a workout, Workouts, Tailored intervals, Signs in this app) updated.

## Version 2.5 — Pace, Power, Weight and Level per step; Effort / Easy removed (24 Nov 2026)

Version 2.5 has two changes to Tailored intervals: (A) Pace, Power, Weight and Level for each step, and (B) the Effort / Easy button is gone. Right after 2.4 the owner wrote: "I'm not sure about your effort solutions. I need to be able to enter [speed] and/or power and/or weights for each step." He was shown one picture with three numbered ways and picked, in a question round: way 1 "Pick per workout", also add Level, remove the Effort / Easy button, and speed entered as pace in minutes per kilometre.

### A. Pace, Power, Weight and Level for each step
- **Before 2.5 (2.4):** a step had one free-text line "Speed or power".
- **Block "Each step has".** In the editor of a Tailored intervals workout, above the Steps list, four words to tap: Pace, Power, Weight, Level (ids `measure-pace`, `measure-power`, `measure-weight`, `measure-level`). A chosen word is filled in the workout's colour; the others are grey. Under them: "Tap what this workout needs. Every step then gets a box for it."
- **Boxes.** Every step then shows a second line with one small box per chosen word, each with its unit: Pace in minutes per kilometre ("5:30 /km"), Power in watts ("150 W"), Weight in kilos ("20 kg"; halves allowed, "22.5 kg"; comma or point), Level as a whole number ("8 lvl" in the box, shown elsewhere as "Level 8"). Ids `step-pace-N`, `step-power-N`, `step-weight-N`, `step-level-N`. A box may stay empty.
- **Pace input.** 5:30, 5.30 and 530 all mean 5 minutes 30 seconds per kilometre; a plain 5 means 5:00.
- **Nothing chosen.** Steps have one line only, as in 2.3. A new workout starts with nothing chosen.
- **Turning a word off** hides its boxes and its numbers everywhere but keeps what was typed; turning it on again brings the numbers back.
- **Where the numbers show** (only the chosen ones, in the order Pace, Power, Weight, Level, joined with " · "): the run screen under the step's name ("5:30 /km · 150 W", id `run-target`); "First: Jog 1:00 · 5:30 /km" and "Next: Walk 2:00 · 7:00 /km"; the plan page after the length; the title of the lock-screen notification; the lock-screen card.
- **Voice.** After the length: "Jog. 2 minutes. 5:30 per kilometre. 150 watts." Weight is said as "20 kilos", Level as "Level 8".
- **Add step** copies the numbers of the step two lines up together with its name, and the length of the last step, as before.
- **The 2.4 text line.** The free line "Speed or power" is no longer offered. A step where the owner already typed something into it keeps that text: the line still shows on that step (so he can change or empty it), and the text is still shown and spoken after the numbers. Nothing he typed is lost.

### B. Effort / Easy removed (his pick)
- **Before (2.4):** each step had a button Effort (workout's colour) or Easy (grey); an Easy step ran on a grey ring with a grey name.
- **Now:** no button. Every step runs with the ring in the workout's colour again, as in 2.3. A grey ring and a grey word on the run screen mean a rest (in Sets & reps and the Interval timer) and Get ready, nothing else. The numbers entered say how hard a step is.
- The ready-made example (jog and walk 1, 2, 3, 2, 1 minutes) has no Easy steps any more.

### Data
- `StepMeasure` (pace, power, weight, level): `title`, `unit`, `parse`, `text`, `shown`, `spoken`.
- `Workout.measures: [StepMeasure]`: what the workout uses; empty in older files.
- `IntervalStep.values: [String: Double]`: keyed by the measure's raw name; pace in seconds per kilometre.
- `IntervalStep.target` (the 2.4 free text) is kept and still read. `IntervalStep.easy` is still read from older files but no longer used.
- `Workout.detail(at:)` gives what is shown for a step; `Workout.spokenDetail(at:)` what is spoken. `Plan.notices(phases:index:left:name:details:)` takes the details for the notification titles.

### Tests (lean)
- Core `Core/Tests/WorkoutCoreTests/Version25Tests.swift`: data rules. The 2.4 data tests are adjusted.
- UI `UITests/Version25UITests.swift`: `testAStepCarriesPacePowerWeightAndLevel`. The 2.4 screen test for speed-or-power and Effort / Easy is retired.
- Version lists: `AppTextTests` (2.5 first) and `testSettingsShowsTheVersionAndWhatsNew` (2.5, `whatsnew-2.5`).
- Checked in the simulator, day and night. **Not yet tried on a real phone.**
- **Texts.** What's new (2.5) and How it works (Tailored intervals, Signs in this app) updated.

## Version 2.6 — four ready efforts per step, and nine look fixes (24 Nov 2026)

Version 2.6 has two parts: (A) efforts are back on the steps of a Tailored intervals workout, as four ready words, and (B) nine look fixes from a look-over. The owner picked all of this on 24 Nov 2026: for A, "Four ready efforts: Easy, Steady, Hard, All-out"; for B, the numbered findings on the picture he saw (number 6 was not picked and is not done).

### A. Four ready efforts: Easy, Steady, Hard, All-out
- **Before:** 2.4 had a button Effort / Easy on each step; 2.5 removed it, so a step had no effort word.
- **Effort button.** Every step has a small effort button at the start of its second line in the editor (id `step-effort-N`). It shows the step's word (Easy, Steady, Hard or All-out), or the grey word "Effort" in an outline when the step has none. A tap opens a short list: Easy, Steady, Hard, All-out, No effort. Easy is grey; Steady, Hard and All-out are filled in the workout's colour. The Pace, Power, Weight and Level boxes of 2.5 stay as they are.
- **Example.** The ready-made example of a new Tailored workout (jog and walk 1, 2, 3, 2, 1 minutes) starts with Jog = Steady and Walk = Easy.
- **Add step** copies the effort of the step two lines up, together with its name and numbers, as before.
- **Older files.** Steps saved as "Easy" in 2.4 (`"easy": true`) are read as effort Easy. All other older steps have no effort until the owner picks one.
- **Where the effort shows.** First in the line under the step's name on the run screen ("Steady · 5:30 /km · 150 W"); after the length in "First: Jog 1:00 · Steady · 5:30 /km" and "Next: Walk 2:00 · Easy"; on the plan page ("1 · Jog 1:00 · Steady · 5:30 /km"); in the notification title; on the lock screen.
- **Voice.** After the length: "Jog. 2 minutes. Steady. 5:30 per kilometre."
- **Run colours.** An Easy step runs on a grey ring with a grey name (as in 2.4). Steady, Hard and All-out run in the workout's colour. Grey on the run screen therefore means: a rest, Get ready, or an Easy step ("take it easy").
- **Foot text of the editor** gains: "Effort: tap the word to choose Easy, Steady, Hard or All-out. An Easy step runs on a grey ring."
- **Empty boxes (look fix 10).** Before, an empty number box showed only its faint unit ("/km", "W"). Now an empty box shows its word in grey (Pace, Power, Weight, Level) and the box outline is stronger, also at night.

### B. Nine look fixes (numbers are those of the picture)
1. **Workouts page.** The big heading "Workout Companion" is gone; the page has the small centred title "Workouts", like History and Settings. Everything below starts about 50 points higher.
2. **Workout tiles.** The line under a workout's name ("5 × 20 · rest 1:30") was caption size at 85 % strength; now footnote size, medium weight, full strength.
3. **At the gym.** The grey hint line under the gym button ("Tap the machine you'll use next — or plan today's order.", "Tap the machine you'll use next.", "Follow the plan, or tap any machine that is free.") is gone once the gym has machines; the first-time hint of an empty gym ("At each machine: take a photo, give it a name, then log your sets.") stays. The big heading "At the gym" becomes a small centred title. Together the machines start about 100 points higher.
4. **Busy pill.** Before, an unmarked machine showed the word Busy in orange with an orange outline, so every machine looked busy. Now an unmarked pill is grey (word and outline) and turns full orange only when tapped. Orange means only "marked busy". Its place (bottom right of the photo) is unchanged.
5. **Machine page.** Before, words of the page (for example the heading "History") showed cut through above the bottom button "Back to gym" / "Exercise done". Now the button's strip is the full page colour (before 96 %) and the page fades out over the 20 points above it (a soft fade from clear to the page colour), so no half words stand at its edge.
6. Not picked, not done.
7. **History.** The heading "This week" / "This month" above the switch is gone. The four tiles (Sessions, Minutes, Exercises, Sets) stand in one row of four (before: three, and Sets alone on a second row). "Lifted" (only when kilograms were lifted) is one wide line under them, its figure right beside the word (`tile(…, wide: true)`; before, a fifth tile). About 70 points less height.
8. **History, Muscle balance.** The number of sets ("12 sets") stands right beside the muscle's name ("Chest 12 sets"), not at the far right edge; the bars follow. The shared `bar` row of Muscle groups and Warm-up and cardio has the same order: name (92 pt), figure (64 pt), bar.
9. **Settings.** Before: two unnamed blocks (2 and 8 rows), rows about 52 points tall, words only. Now three named blocks: "Help" (How it works, What's new), "Training" (Muscle groups, Plan templates, Rest times, Sounds, Reminder and stretch), "Your data" (Backups, Check my data, Garmin Board). Each row has a small hand-drawn mark in its block's colour and is 44 points tall. The version stays at the bottom.
9a. Settings marks (hand-drawn, from the icon library, on a 28 pt tile; row = 28 + 8 above + 8 below = 44 pt, `defaultMinListRowHeight` 44): Help orange — book, gift; Training blue — strength, notebook, stopwatch, headphones, yoga; Your data green — box, pulse, watch. Row identifiers are unchanged.
10. **Tailored steps editor.** Empty boxes show their word in grey; stronger outline (see A).

### Data
- `StepEffort` (easy, steady, hard, allOut) and `IntervalStep.effort` in `Core/Sources/WorkoutCore/Version26Effort.swift`. `IntervalStep.easy` (2.4) is read: `"easy": true` becomes effort Easy.
- No other data change; Backups carry the efforts with the steps.

### Texts
- What's new (2.6) added. How it works updated: Tailored intervals, Signs in this app, Workouts, At the gym, Busy machines, Next machine, History, Statistics, Muscle balance and Records. The sentences saying there is no Effort or Easy button and that every step runs in the workout's colour are corrected.
- Not yet tried on a real phone.

- Old Easy mark: when a step is read, an old `"easy": true` (2.4) gives effort Easy and the old mark is then cleared, so a step later set to "No effort" stays without effort. Test: Version24Tests.
- Checked on the simulator by hand, by day: Workouts, At the gym (Busy off and on), a machine, History, Settings, the Tailored editor (effort list, boxes), the run screen (Hard, Easy grey, Steady). Data tests: 222 green. The screen test Version26UITests was written but not run locally (the Mac was overloaded); GitHub runs it.
