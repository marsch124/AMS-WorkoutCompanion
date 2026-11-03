# AMS WorkoutCompanion — specification

Version 1.3. iPhone only, portrait, iOS 17+, light and dark. The name under the app icon is "Workouts" (not "Companion": Apple refuses it, error 90129).

## Workouts (home)
- One card per workout: its tile (hand-drawn icon from AMS-Icons on the workout's colour), name, one-line summary, a play button in the workout's colour, a pencil.
- Tap the card: the workout starts (full screen). Pencil: the editor. Touch and hold: Edit, Duplicate, Delete (Delete asks first).
- Gear (top left): Settings. + (top right): New workout.
- A fresh install has three starters: Push-ups (Sets & reps, 5 × 20, rest 1:30, orange), Intervals (8 × 0:40 work / 0:20 rest, green), Doctor's exercises (Exercise list, empty, pink).
- Summaries: `5 × 20 · rest 1:30`; `8 × 0:40 work / 0:20 rest · 7:40`; `No exercises yet` / `1 exercise` / `4 exercises`.

## At the gym (since 1.2)
- A card "At the gym" at the top of Workouts (hand-drawn "strength" icon, indigo — the gym log's colour for its headings, buttons and marks). Its line: "Today: n machines · n sets", else "n machines", else "Photo, weight and reps per machine". The screen stays on while at the gym.
- Gym screen: "Today" and a date (compact picker, no future days; default today — sets go to the visit on that day). Two columns of machine tiles in the order they were made: photo (or the strength mark), name, and "n sets done" (indigo, with a tick and an indigo border) or "Last: 30 kg" or "New". A dashed "New machine" tile. Finish (full indigo) once the day has a set. "Earlier visits", newest first: date, "n machines · n sets" → the visit: each machine's sets and "n sets · n kg lifted in all".
- Busy (since 1.3): every machine tile has a small "Busy" pill at the top left of its photo (hand-drawn stopwatch; orange outline). Tap it: the pill turns full orange, the tile gets an orange border and the line "Busy — come back later", and the machine moves to a row "Come back to" (orange heading) above the others, in the order marked; the rest are then headed "Other machines". Tap the pill again: the mark goes. Tapping a busy machine opens it and takes the mark away; a set done on it does too. Finish clears every mark of that day; marking a machine drops marks from other days. Deleting a machine removes its mark. Marks are kept in gym.json, so they survive closing the app.
- New machine: the camera opens first (the photo library when there is no camera; UI tests skip it), then the machine form: photo (Take photo / Take photo again, Choose from Photos), Name, How it is set up (shown on the machine). Cancel and Save; Save without a name says "Give it a name first." After Save the machine opens straight away.
- Machine screen: photo (tap: full screen), setting in indigo, "Last time, 27 Oct: 30 kg × 12, 12, 10" or "First time on this machine.", the suggestion, today's sets (tap one: change weight/reps or Remove set, with Cancel and Save), then "Set n" with weight (− / + 2.5 kg, type with a decimal pad; 0 = body weight) and reps (− / + 1, ≥ 1), and Set done. Pencil: edit or delete the machine (asks; deletes its sets too).
- The next set's numbers: the set just done on this machine today; else last time's first set — with 2.5 kg more and 10 reps when every set last time reached 12 reps ("Try 32.5 kg — every set last time reached 12 reps"); else 20 kg × 10.
- Set done: saved at once, a tap, "Rest" spoken, a 1:30 ring with +15 s and Skip; the last three seconds tick; at the end a tone and "Set n". "New best" (trophy) when the weight is heavier than any earlier visit on that machine.
- History: a line chart of the heaviest weight per visit (from two visits) and a row per visit, newest first.
- Finish: "Workout done" with Well done (a trophy when there are new bests), Machines, Sets, Time (first set → Finish, in minutes), Lifted in all (Σ kg × reps) and New bests per machine. Done closes it.
- Words: "30 kg × 12", "Body weight × 15"; an entry "30 kg × 12, 12, 10", or "30 × 12, 32.5 × 8 kg" when the weight changes.

## New workout and editor
- New workout: three cards — Sets & reps, Exercise list, Interval timer — then the editor. Cancel on both.
- Editor: Name, Colour (the fifteen AMS-Icons colours, two rows of eight), Type (Sets / List / Intervals). Cancel and Save; Save is a full-colour pill and without a name it says "Give it a name first." instead of being greyed out. Nothing is kept before Save.
- Sets & reps: Sets 1–50, Reps per set 1–500, Rest 0–10:00 in 15 s steps (0 = None).
- Interval timer: Rounds 1–99, Work 0:05–15:00 and Rest 0:00–15:00 in 5 s steps; the total is shown.
- Exercise list: per exercise Name, Amount (free text), Note, Photo (from Photos, stored scaled to 1600 px). ••• moves it up, down, or removes it. Add exercise adds one.
- Changing the type keeps every other type's numbers. An existing workout can be deleted (asks first).

## Running a Sets & reps workout
- Set: "SET", the set number large with "/ total", the reps on a pill in the workout's colour, dots for the sets, and a large Done.
- Done starts the rest (if rest > 0): a ring counting down, "REST", "Next: set n of N", +15 s and Skip. The rest ends by itself.
- After the last set: Well done and Close.

## Running an Interval timer
- 5-second Get ready, then Work and Rest rounds; the ring shows the time left (work in the workout's colour, rest grey). Pause/Resume and Skip. Ends with Well done.
- The clock is kept as end times, so a late tick never loses time.

## Running an Exercise list
- A card per exercise: photo (tap to enlarge), number, name, amount pill, note, a tick circle. Tapping ticks it off and scrolls to the next one. "n of N done" and a bar at the top. All ticked: Well done and Close.

## Cues
- Start of a set/round: a tone, a vibration and words ("Set 2 of 5. 20 reps.", "Round 3. Go!", "Last round. Go!"). Rest: a vibration and "Rest". Last 3 seconds: a tick and a tap. End: a three-note tone and "Well done".
- Plays with the silent switch on and mixes with music. The screen stays on during a workout. US English voice.

## Settings
- How it works, What's new (every version, newest first), Version "1.3 (build)".

## Data
- `Documents/workouts.json` (`{"version":1,"workouts":[…]}`) and `Documents/gym.json` (`{"version":1,"machines":[…],"visits":[…],"busy":[{"machineID","day"}]}`, dates ISO 8601; `busy` since 1.3, a file without it reads as no marks), photos in `Documents/Photos/`. Photos no workout and no machine uses are removed on save. A file that cannot be read is kept aside, never overwritten; while gym.json is unreadable no photo is removed. The gym log keeps every visit; the other workouts keep no history. No iCloud, nothing leaves the iPhone.
- The camera asks once: "A photo of each gym machine, so you recognise it and its setting next time."

## Look
- Save / Done at the top right of every edit page: a full-colour capsule (blue; never grey).
- Page and text colours as AMS Packing (light / dark pairs). Workout colours, icons and the marks on buttons (ControlMark) all from AMS-Icons, pinned to one commit. No stock symbols, no emoji.
