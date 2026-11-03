import AMSIcons
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import WorkoutCore

/// Settings → Backups (since 1.6): one file with everything — workouts, gym log, history and every
/// photo — to keep in Files or iCloud Drive; restore it after asking; a weekly copy on this iPhone.
struct BackupScreen: View {
    @Environment(Library.self) private var library
    @State private var sharing: SharedFile?
    @State private var importing = false
    @State private var pending: Pending?
    @State private var message: String?
    @State private var copies: [(url: URL, made: Date)] = []

    private static let colour = IconColour.of(key: "navy")!

    var body: some View {
        List {
            Section {
                Button(action: backUp) {
                    MarkLabel(title: "Back up now", mark: .check, colour: Self.colour.inkColor)
                }
                .buttonStyle(BigButtonStyle(fill: Self.colour.fillColor, ink: Self.colour.inkColor, height: 50))
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                .accessibilityIdentifier("backup-now")
                Button("Restore from a file…") { importing = true }
                    .foregroundStyle(Theme.accent)
                    .accessibilityIdentifier("backup-restore-file")
            } footer: {
                Text("One file with all workouts, the gym log, history and every photo. Save it to Files or iCloud Drive — it stays safe even if the app is deleted.")
            }
            if let message {
                Section {
                    Text(message)
                        .foregroundStyle(Theme.ink)
                        .accessibilityIdentifier("backup-message")
                }
            }
            Section {
                ForEach(Array(copies.enumerated()), id: \.offset) { i, copy in
                    Button { open(copy.url) } label: {
                        HStack {
                            IconMark(.hand("box"), size: 20, colour: Self.colour.fillColor)
                            Text(copy.made.formatted(.dateTime.weekday(.wide).day().month(.wide).hour().minute()))
                                .foregroundStyle(Theme.ink)
                            Spacer()
                            Text("Restore").font(.subheadline).foregroundStyle(Theme.accent)
                        }
                    }
                    .accessibilityIdentifier("backup-copy-\(i)")
                }
                Button("Keep a copy now") {
                    library.weeklyBackup(force: true)
                    copies = library.weeklyCopies()
                    message = "Copy kept on this iPhone."
                }
                .foregroundStyle(Theme.accent)
                .accessibilityIdentifier("backup-keep-copy")
            } header: {
                Text("On this iPhone").foregroundStyle(Self.colour.fillColor)
            } footer: {
                Text("Once a week the app keeps a copy here by itself; the newest 4 stay. They go if the app is deleted — so also keep one in Files.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle("Backups")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { copies = library.weeklyCopies() }
        .sheet(item: $sharing) { file in
            ShareSheet(url: file.url)
                .presentationDetents([.medium, .large])
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            guard case .success(let url) = result else { return }
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            open(url)
        }
        .alert(pending.map { "Restore the backup from \($0.contents.made.formatted(date: .abbreviated, time: .shortened))?" } ?? "",
               isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } })) {
            Button("Cancel", role: .cancel) { pending = nil }
            Button("Restore", role: .destructive) { restore() }
                .accessibilityIdentifier("backup-restore-confirm")
        } message: {
            Text((pending?.contents.text ?? "") + ".\n\nIt replaces what is on this iPhone now. Today's data is kept aside first.")
        }
    }

    // MARK: Actions

    private func backUp() {
        guard let url = library.backupFile() else {
            message = "The backup could not be made. Is the iPhone full?"
            return
        }
        sharing = SharedFile(url: url)
    }

    /// Reads a backup and asks before restoring; a file that is not a backup is refused.
    private func open(_ url: URL) {
        guard let data = try? Data(contentsOf: url),
              let backup = try? Backup.decode(data),
              let contents = try? backup.contents() else {
            message = "This file is not a Workouts backup, or it is damaged. Nothing was changed."
            return
        }
        pending = Pending(backup: backup, contents: contents)
    }

    private func restore() {
        guard let p = pending else { return }
        pending = nil
        do {
            try library.restore(p.backup)
            message = "Restored: \(p.contents.text)."
        } catch {
            message = "The backup could not be restored. What was on this iPhone is kept aside."
        }
    }
}

private struct Pending {
    let backup: Backup
    let contents: Backup.Contents
}

private struct SharedFile: Identifiable {
    let url: URL
    var id: URL { url }
}

/// The iPhone's share sheet: Save to Files, AirDrop, Mail.
private struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
