# Getting AMS WorkoutCompanion onto the iPhone (TestFlight)

Everything runs on GitHub's Mac. Three things only the account owner can do, once —
all in a browser, the iPhone is enough.

## 1. The app's record in App Store Connect

1. <https://appstoreconnect.apple.com> → **Apps → "+" → New App**.
2. Platform **iOS**. Name **AMS WorkoutCompanion**. Language English.
3. Bundle ID **com.schabbauer.AMSWorkoutCompanion**. If it is not in the list yet,
   register it first at <https://developer.apple.com/account/resources/identifiers>
   (**"+" → App IDs → App**, Explicit, that exact ID, no capabilities).
4. SKU `AMSWorkoutCompanion`. Create.
5. **TestFlight → Internal Testing → "+"**: a group with yourself in it.

## 2. The three secrets in this repository

Your App Store Connect API key (one key serves all your apps). At
<https://github.com/marsch124/AMS-WorkoutCompanion/settings/secrets/actions> →
**New repository secret**, three times:

| Name | Value |
|---|---|
| `ASC_KEY_ID` | the key's ID (App Store Connect → Users and Access → Integrations) |
| `ASC_ISSUER_ID` | the Issuer ID, at the top of that same page |
| `ASC_KEY_P8` | the whole text of the `AuthKey_….p8` file |

GitHub never shows a secret again once saved, so they cannot be copied from the
other repository — they come from where they were kept when the key was made.

## 3. Ship

**Actions → TestFlight → Run workflow** (on `main`). It ships only a version whose tests
passed after its push, and numbers the build itself. Then Apple takes a few minutes, and
the TestFlight app offers it.

Or from a Mac with Xcode: archive (Release, `generic/platform=iOS`) and export with
`tools/ExportOptions.plist`, which uploads. Version 1.1 went this way on 2 Nov 2026.

- **Build number** is short since 1.19 (Martin's ask, 5 Nov 2026): `CURRENT_PROJECT_VERSION`
  in `project.yml` — **1** for each new version, then 2, 3 … for another build of the same
  version. Both ways read it from there; do not pass it on the command line. TestFlight then
  shows "1.19 (1)". Up to 1.18 the build number was the date and time (202611051430).
- **Every build must be added to the tester group** in App Store Connect
  (TestFlight → the group → Builds → "+"). A group does not pick new builds up by itself.

## Pictures of every screen, day and night

`UITests/ScreenTour.swift` walks the nine main screens and attaches a picture of each.
It is skipped in normal test runs. To take them, set the simulator to light or dark
(`xcrun simctl ui <device> appearance dark`) and run:

    TEST_RUNNER_SCREEN_TOUR=1 xcodebuild test -project AMSWorkoutCompanion.xcodeproj \
      -scheme AMSWorkoutCompanion -destination "platform=iOS Simulator,id=<device>" \
      -resultBundlePath tour.xcresult -only-testing:AMSWorkoutCompanionUITests/ScreenTour
    xcrun xcresulttool export attachments --path tour.xcresult --output-path shots
