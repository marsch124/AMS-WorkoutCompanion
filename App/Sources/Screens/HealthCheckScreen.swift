import SwiftUI
import WorkoutCore

/// "Check my data": looks at the files in the app and says if all is well. It never changes or deletes anything.
struct HealthCheckScreen: View {
    @Environment(Library.self) private var library
    @State private var report: HealthReport?

    private let good = Color.pair("#1f8a4c", "#5fd18a")
    private let bad = Color.pair("#c8372d", "#ff8a80")

    var body: some View {
        List {
            if let r = report {
                Section {
                    if r.isAllGood {
                        Label("All good", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(good)
                            .font(.headline)
                            .accessibilityIdentifier("health-ok")
                    } else {
                        ForEach(Array(r.problems.enumerated()), id: \.offset) { i, text in
                            Label(text, systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(bad)
                                .accessibilityIdentifier("health-problem-\(i + 1)")
                        }
                    }
                }
                Section("What is in the app") {
                    count("Workouts", r.workouts)
                    count("Machines", r.machines)
                    count("Gym visits", r.gymVisits)
                    count("Other sessions", r.otherSessions)
                    count("Photos", r.photos)
                    if !r.beforeRestoreFolders.isEmpty { count("Kept before a restore", r.beforeRestoreFolders.count) }
                }
            }
            Section {
                Button { check() } label: {
                    Text("Check again")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .accessibilityIdentifier("health-again")
            } footer: {
                Text("This only looks. Nothing is changed or deleted.")
            }
        }
        .navigationTitle("Check my data")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if report == nil { check() } }
    }

    private func count(_ title: String, _ n: Int) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text("\(n)").monospacedDigit().foregroundStyle(Theme.muted)
        }
    }

    private func check() {
        let fm = FileManager.default
        var files: [String: Data?] = [:]
        for name in ["workouts.json", "gym.json", "history.json"] {
            files[name] = try? Data(contentsOf: library.folder.appendingPathComponent(name))
        }
        let photos = Set((try? fm.contentsOfDirectory(atPath: library.photoFolder.path)) ?? [])
        let others = (try? fm.contentsOfDirectory(atPath: library.folder.path)) ?? []
        report = HealthCheck.run(files: files, photoNames: photos, otherFileNames: others)
    }
}
