import SwiftUI
import UniformTypeIdentifiers
import WorkoutCore

/// Settings → Garmin Board (since 1.24): choose the folder in iCloud Drive that the Board on the Mac
/// reads; the app then keeps one small file with the last finished gym sessions there.
struct BoardLinkScreen: View {
    @Environment(Library.self) private var library
    @Environment(\.dismiss) private var dismiss
    @State private var choosing = false

    var body: some View {
        Form {
            Section {
                if let folder = library.boardFolderName {
                    HStack {
                        Text("Folder")
                        Spacer()
                        Text(folder).foregroundStyle(Gym.tint).accessibilityIdentifier("board-folder")
                    }
                    HStack {
                        Text("Last written")
                        Spacer()
                        Text(library.boardLast.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? "Not yet")
                            .foregroundStyle(Theme.muted)
                            .accessibilityIdentifier("board-last")
                    }
                    Button("Write now") { library.writeBoardFile() }
                        .foregroundStyle(Gym.tint)
                        .accessibilityIdentifier("board-write")
                    Button("Choose another folder") { choosing = true }
                        .foregroundStyle(Gym.tint)
                        .accessibilityIdentifier("board-choose")
                    Button("Stop sharing", role: .destructive) { library.stopBoardLink() }
                        .accessibilityIdentifier("board-stop")
                } else {
                    Button { choosing = true } label: {
                        Text("Choose folder")
                            .font(.headline)
                            .foregroundStyle(Gym.ink)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Gym.fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                    .accessibilityIdentifier("board-choose")
                }
                if let problem = library.boardProblem {
                    Text(problem)
                        .font(.subheadline)
                        .foregroundStyle(Theme.problem)
                        .accessibilityIdentifier("board-problem")
                }
            } header: {
                Text("Gym sessions on the Garmin Board")
            } footer: {
                Text(library.boardFolderName == nil
                     ? "Choose the folder \"AMS Garmin\" in iCloud Drive, once. After every finished session the app writes one small file there, and the Board on the Mac shows your gym sessions."
                     : "The file \"\(BoardFile.name)\" holds your last \(BoardFile.most) finished sessions: when, how long, the machines and sets, the kilograms, how it felt and your notes. No photos. It is written after every finished session and when you leave the app. Stop sharing forgets the folder; the file already there stays until you delete it.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle("Garmin Board")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
                    .fontWeight(.bold)
                    .accessibilityIdentifier("board-done")
            }
        }
        .fileImporter(isPresented: $choosing, allowedContentTypes: [.folder]) { result in
            if case .success(let url) = result { library.chooseBoardFolder(url) }
        }
    }
}
