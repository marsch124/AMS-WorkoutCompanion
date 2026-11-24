import AMSIcons
import SwiftUI
import WorkoutCore

/// Settings: How it works, What's new and the version.
struct SettingsScreen: View {
    @Environment(Library.self) private var library
    /// Nil in the Settings tab, which needs no Done.
    var onDone: (() -> Void)? = nil

    private var version: String {
        let info = Bundle.main.infoDictionary
        let v = info?["CFBundleShortVersionString"] as? String ?? "?"
        let b = info?["CFBundleVersion"] as? String ?? "?"
        return "\(v) (\(b))"
    }

    /// One row: a small hand-drawn mark on its block's colour, then the words.
    private func row(_ title: String, _ icon: String, _ colour: String) -> some View {
        HStack(spacing: 10) {
            IconTile(.hand(icon), colour: IconColour.of(key: colour), fallbackTint: Theme.accent, letter: title, size: 28)
                .accessibilityHidden(true)
            Text(title).foregroundStyle(Theme.ink)
        }
    }

    /// Rows as tall as their mark and words: 28 points plus 8 above and below = 44.
    private static let rowInsets = EdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14)

    private func heading(_ title: String, _ colour: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(IconColour.of(key: colour)?.fillColor ?? Theme.accent)
            .textCase(nil)
    }

    var body: some View {
        List {
            // Three named blocks, each with its own colour and a hand-drawn mark per row (since 2.6;
            // before, two unnamed blocks of words only, rows about 52 points tall).
            Section {
                NavigationLink { HowItWorksScreen() } label: { row("How it works", "book", "orange") }
                    .listRowInsets(Self.rowInsets)
                    .accessibilityIdentifier("settings-how")
                NavigationLink { WhatsNewScreen() } label: { row("What's new", "gift", "orange") }
                    .listRowInsets(Self.rowInsets)
                    .accessibilityIdentifier("settings-new")
            } header: { heading("Help", "orange") }
            Section {
                NavigationLink { MuscleGroupsScreen() } label: { row("Muscle groups", "strength", "blue") }
                    .listRowInsets(Self.rowInsets)
                    .accessibilityIdentifier("open-muscle-groups")
                NavigationLink { TemplatesScreen() } label: { row("Plan templates", "notebook", "blue") }
                    .listRowInsets(Self.rowInsets)
                    .accessibilityIdentifier("open-templates")
                NavigationLink { RestTimesScreen() } label: { row("Rest times", "stopwatch", "blue") }
                    .listRowInsets(Self.rowInsets)
                    .accessibilityIdentifier("open-rest-times")
                NavigationLink { SoundsScreen() } label: { row("Sounds", "headphones", "blue") }
                    .listRowInsets(Self.rowInsets)
                    .accessibilityIdentifier("settings-sounds")
                NavigationLink { GymExtrasScreen() } label: { row("Reminder and stretch", "yoga", "blue") }
                    .listRowInsets(Self.rowInsets)
                    .accessibilityIdentifier("settings-gym-extras")
            } header: { heading("Training", "blue") }
            Section {
                // 3.0: iCloud first, with the status dot at the end of its row.
                NavigationLink { ICloudScreen() } label: {
                    HStack(spacing: 10) {
                        MarkTile(mark: .cloud, colour: IconColour.of(key: "green"))
                        Text("iCloud").foregroundStyle(Theme.ink)
                        Spacer()
                        Text(library.syncStatus.words).font(.subheadline).foregroundStyle(Theme.muted).lineLimit(1)
                        SyncDot(status: library.syncStatus)
                    }
                    .accessibilityElement(children: .combine)
                }
                .listRowInsets(Self.rowInsets)
                .accessibilityIdentifier("settings-icloud")
                NavigationLink { BackupScreen() } label: { row("Backups", "box", "green") }
                    .listRowInsets(Self.rowInsets)
                    .accessibilityIdentifier("settings-backups")
                NavigationLink { HealthCheckScreen() } label: { row("Check my data", "pulse", "green") }
                    .listRowInsets(Self.rowInsets)
                    .accessibilityIdentifier("settings-health")
                NavigationLink { BoardLinkScreen() } label: { row("Garmin Board", "watch", "green") }
                    .listRowInsets(Self.rowInsets)
                    .accessibilityIdentifier("settings-board")
            } header: { heading("Your data", "green") }
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
        .environment(\.defaultMinListRowHeight, 44)
        .listSectionSpacing(.compact)
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
