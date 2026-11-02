# AMS WorkoutCompanion — specification

Version 1.1. iPhone only, portrait, iOS 17+, light and dark.

## Workouts (home)
- One card per workout: its tile (hand-drawn icon from AMS-Icons on the workout's colour), name, one-line summary, a play button in the workout's colour, a pencil.
- Tap the card: the workout starts (full screen). Pencil: the editor. Touch and hold: Edit, Duplicate, Delete (Delete asks first).
- Gear (top left): Settings. + (top right): New workout.
- A fresh install has three starters: Push-ups (Sets & reps, 5 × 20, rest 1:30, orange), Intervals (8 × 0:40 work / 0:20 rest, green), Doctor's exercises (Exercise list, empty, pink).
- Summaries: `5 × 20 · rest 1:30`; `8 × 0:40 work / 0:20 rest · 7:40`; `No exercises yet` / `1 exercise` / `4 exercises`.

## New workout and editor
- New workout: three cards — Sets & reps, Exercise list, Interval timer — then the editor. Cancel on both.
- Editor: Name, Colour (the fifteen AMS-Icons colours, two rows of eight), Type (Sets / List / Intervals). Cancel and Save; Save only with a name. Nothing is kept before Save.
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
- How it works, What's new (every version, newest first), Version "1.1 (build)".

## Data
- `Documents/workouts.json` (`{"version":1,"workouts":[…]}`), photos in `Documents/Photos/`. Unused photos are removed on save. A file that cannot be read is kept aside, never overwritten. No history, no iCloud, nothing leaves the iPhone.

## Look
- Page and text colours as AMS Packing (light / dark pairs). Workout colours, icons and the marks on buttons (ControlMark) all from AMS-Icons, pinned to one commit. No stock symbols, no emoji.
