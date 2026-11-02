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
