# AMS WorkoutCompanion — specification

Version 1.4. iPhone only, portrait, iOS 17+, light and dark. The name under the app icon is "Workouts" (not "Companion": Apple refuses it, error 90129).

## Workouts (home)
- One card per workout: its tile (hand-drawn icon from AMS-Icons on the workout's colour), name, one-line summary, a play button in the workout's colour, a pencil.
- Tap the card: the workout starts (full screen). Pencil: the editor. Touch and hold: Edit, Duplicate, Delete (Delete asks first).
- Gear (top left): Settings. + (top right): New workout.
- A fresh install has three starters: Push-ups (Sets & reps, 5 × 20, rest 1:30, orange), Intervals (8 × 0:40 work / 0:20 rest, green), Doctor's exercises (Exercise list, empty, pink).
- Summaries: `5 × 20 · rest 1:30`; `8 × 0:40 work / 0:20 rest · 7:40`; `No exercises yet` / `1 exercise` / `4 exercises`.

## At the gym (since 1.2)
- A card "At the gym" at the top of Workouts (hand-drawn "strength" icon, indigo — the gym log's colour for its headings, buttons and marks). Its line: "Today: n machines · n sets", else "n machines", else "Photo, weight and reps per machine". The screen stays on while at the gym.
- Gym screen: "Today" and a date (compact picker, no future days; default today — sets go to the visit on that day). Two columns of machine tiles in the order they were made: photo (or the strength mark), name, and "n sets done" (indigo, with a tick and an indigo border) or "Last: 30 kg" or "New". A dashed "New machine" tile. Finish this session (full indigo, since 1.4; "Finish" before) once the day has a set. "Earlier visits", newest first: date, "n machines · n sets" → the visit: each machine's sets and "n sets · n kg lifted in all".
- Busy (since 1.3): every machine tile has a small "Busy" pill at the top left of its photo (hand-drawn stopwatch; orange outline). Tap it: the pill turns full orange, the tile gets an orange border and the line "Busy — come back later", and the machine moves to a row "Come back to" (orange heading) above the others, in the order marked; the rest are then headed "Other machines". Tap the pill again: the mark goes. Tapping a busy machine opens it and takes the mark away; a set done on it does too. Finish clears every mark of that day; marking a machine drops marks from other days. Deleting a machine removes its mark. Marks are kept in gym.json, so they survive closing the app.
- New machine: the camera opens first (the photo library when there is no camera; UI tests skip it), then the machine form: photo (Take photo / Take photo again, Choose from Photos), Name, How it is set up (shown on the machine). Cancel and Save; Save without a name says "Give it a name first." After Save the machine opens straight away.
- Machine screen: photo (tap: full screen), setting in indigo, "Last time, 27 Oct: 30 kg × 12, 12, 10" or "First time on this machine.", the suggestion, today's sets (tap one: change weight/reps or Remove set, with Cancel and Save), then "Set n" with weight (− / + 2.5 kg, type with a decimal pad; 0 = body weight) and reps (− / + 1, ≥ 1), and Set done. Pencil: edit or delete the machine (asks; deletes its sets too).
- The next set's numbers: the set just done on this machine today; else last time's first set — with 2.5 kg more and 10 reps when every set last time reached 12 reps ("Try 32.5 kg — every set last time reached 12 reps"); else 20 kg × 10.
- Set done: saved at once, a tap, "Rest" spoken, a 1:30 ring with +15 s and Skip rest ("Skip" before 1.4); the last three seconds tick; at the end a tone and "Set n". "New best" (trophy) when the weight is heavier than any earlier visit on that machine.
- History: a line chart of the heaviest weight per visit (from two visits) and a row per visit, newest first.
- Finish this session: "Session done" (was "Workout done" before 1.4) with Well done (a trophy when there are new bests), Machines, Sets, Time (first set → Finish, in minutes), Lifted in all (Σ kg × reps) and New bests per machine. Done closes it.
- Words: "30 kg × 12", "Body weight × 15"; an entry "30 kg × 12, 12, 10", or "30 × 12, 32.5 × 8 kg" when the weight changes.

### Gyms (since 1.4)
- The gym's name is a button at the top of the gym screen. Tap: the list of gyms (a tick on the current one), "New gym…" (asks for a name) and "Rename this gym…". Each gym has its own machines, visits, busy marks and plan; nothing is shared between gyms.
- Everything made before 1.4 is moved into one gym called "My gym" (renameable). The app opens at the gym used last (`currentGym`).

### Plan today (since 1.4, optional)
- Button "Plan today": the machines of this gym are tapped in the order wanted (numbered 1, 2, 3 …; tap again to take one out), then Save (Cancel leaves it). An empty plan is no plan.
- With a plan the gym screen shows "Today's plan": the machines in plan order with their number and a state: Up next (the first not done, not busy, not skipped), Done (a set today), Busy, or Skipped. The other machines are listed under "Other machines"; any machine can still be tapped, in any order.
- Touch and hold a planned machine: Later (moves it to the end), Skip today / Back in today's plan, Swap for… (pick another machine to take its place), Remove from plan. Busy machines are passed over when working out Up next.
- Finish this session ends the plan. A plan belongs to one day and one gym (`plan` in gym.json); one from another day is ignored.

### Done with this machine (since 1.4)
- A button under today's sets once there is one set on the machine. With a plan it goes straight to the next planned machine (labelled "Next: Leg press"); without a plan, or at the end of it, back to the machines.
- During the rest, once the sets done today equal the sets last time (or more), a large full-colour "Next machine: X" button appears under the ring and does the same; without a planned next machine it reads "Done with this machine" and goes back to the machines.

### Machines for time (since 1.4)
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
- A card "History" under At the gym on the home screen (plum, hand-drawn icon). Its line shows this week's sessions.
- The list: every gym session with at least one set (finished or not) and every Sets & reps, Interval and Exercise-list workout, finished or ended early (marked "ended early"), newest first. A row: title (or workout name), date, the gym or kind, minutes and, for the gym, kilograms lifted.
- Filter chips: All, At the gym, and one per workout name that has sessions.
- At the top: "This week" — sessions, minutes, kilograms lifted, and weeks in a row (consecutive weeks, ending this week or last, with at least one session); a line for this month (sessions · minutes); a bar chart of minutes per week for the last 8 weeks (this week's bar included).
- Tap a workout: its details (kind, start, minutes, what was done), a pencil for title and notes (Cancel and Save) and "Delete from History" (asks first; Cancel keeps it). Tap a gym session: the visit page. A gym session cannot be deleted from History (its sets can be changed or removed on the machine).
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
- How it works, What's new (every version, newest first), Version "1.4 (build)".

## Data
- `Documents/workouts.json` (`{"version":1,"workouts":[…]}`), `Documents/gym.json`, `Documents/history.json` (since 1.4) and photos in `Documents/Photos/`. Dates are ISO 8601. Photos no workout and no machine uses are removed on save. A file that cannot be read is kept aside, never overwritten; while gym.json is unreadable no photo is removed. No iCloud, nothing leaves the iPhone.
- `gym.json`: `{"version":1,"machines":[…],"visits":[…],"busy":[{"machineID","day"}],"gyms":[{"id","name"}],"currentGym":"<id>","plan":{…}}`. `busy` since 1.3; `gyms`, `currentGym` and `plan` since 1.4. Machines, visits, busy marks and plan carry their gym; a file without the new keys is read as one gym "My gym" holding everything.
- Machine: `logs` (`weights` or `time`, default `weights`) and `instructions` (photo file name, optional). Set: `seconds`, `level`, `incline` for time sets (optional; weight and reps for the others). Entry (a machine's sets in a visit): `nextTime` (the weight/reps or time/level/incline wanted next) and `note`. Visit: `title` and `notes`. All optional, so older files read as before.
- `history.json`: `{"version":1,"sessions":[…]}` — one record per finished or ended workout (`id`, `workoutID`, `kind`, `name`, `colour`, `started`, `ended`, `completed` (false = ended early), `detail`, `title`, `notes`). Gym sessions are read from gym.json; the file never holds a second copy.
- The gym log keeps every visit; History keeps the other workouts' sessions.
- The camera asks once: "A photo of each gym machine, so you recognise it and its setting next time."
- The camera asks once: "A photo of each gym machine, so you recognise it and its setting next time."

## Look
- Save / Done at the top right of every edit page: a full-colour capsule (blue; never grey).
- Page and text colours as AMS Packing (light / dark pairs). Workout colours, icons and the marks on buttons (ControlMark) all from AMS-Icons, pinned to one commit. No stock symbols, no emoji.
