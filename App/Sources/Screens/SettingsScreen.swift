import SwiftUI
import WorkoutCore

/// Settings: How it works, What's new and the version.
struct SettingsScreen: View {
    /// Nil in the Settings tab, which needs no Done.
    var onDone: (() -> Void)? = nil

    private var version: String {
        let info = Bundle.main.infoDictionary
        let v = info?["CFBundleShortVersionString"] as? String ?? "?"
        let b = info?["CFBundleVersion"] as? String ?? "?"
        return "\(v) (\(b))"
    }

    var body: some View {
        List {
            Section {
                NavigationLink("How it works") { HowItWorksScreen() }
                    .accessibilityIdentifier("settings-how")
                NavigationLink("What's new") { WhatsNewScreen() }
                    .accessibilityIdentifier("settings-new")
            }
            Section {
                HStack {
                    Text("Version").foregroundStyle(Theme.ink)
                    Spacer()
                    Text(version)
                        .monospacedDigit()
                        .foregroundStyle(Theme.muted)
                        .accessibilityIdentifier("settings-version")
                }
            } footer: {
                Text("AMS WorkoutCompanion")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let onDone {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDone)
                        .fontWeight(.bold)
                        .accessibilityIdentifier("settings-done")
                }
            }
        }
    }
}

private struct HowItWorksScreen: View {
    var body: some View {
        List {
            ForEach(AppText.howItWorks, id: \.title) { part in
                Section(part.title) {
                    Text(part.text).foregroundStyle(Theme.ink)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle("How it works")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct WhatsNewScreen: View {
    var body: some View {
        List {
            ForEach(AppText.releases, id: \.version) { r in
                Section {
                    ForEach(r.items, id: \.self) { item in
                        Text(item).foregroundStyle(Theme.ink)
                    }
                } header: {
                    Text("Version \(r.version) · \(r.date)")
                        .accessibilityIdentifier("whatsnew-\(r.version)")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle("What's new")
        .navigationBarTitleDisplayMode(.inline)
    }
}
