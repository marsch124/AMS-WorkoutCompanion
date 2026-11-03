import SwiftUI

/// A heading and notes for a gym visit or a workout in History. Nothing is kept until Save.
struct NotesForm: View {
    let placeholder: String
    @State var title: String
    @State var notes: String
    var colour: Color = Theme.accent
    let done: ((title: String, notes: String)?) -> Void

    var body: some View {
        Form {
            Section("Title") {
                TextField(placeholder, text: $title)
                    .accessibilityIdentifier("notes-title")
            }
            Section("Notes") {
                TextField("How it went, what to remember", text: $notes, axis: .vertical)
                    .lineLimit(3...8)
                    .accessibilityIdentifier("notes-notes")
            }
        }
        .navigationTitle("Title and notes")
        .navigationBarTitleDisplayMode(.inline)
        .bottomActions(cancel: { done(nil) }, save: { done((title, notes)) }, tint: colour,
                       cancelID: "notes-cancel", saveID: "notes-save")
    }
}
