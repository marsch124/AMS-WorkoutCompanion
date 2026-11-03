import SwiftUI
import WorkoutCore

/// Settings → Rest times (since 1.11): the usual rest after a set for heavy machines, light machines
/// and exercises without a machine. A machine with its own rest keeps it. Nothing is kept until Save.
struct RestTimesScreen: View {
    @Environment(Library.self) private var library
    @Environment(\.dismiss) private var dismiss
    @State private var draft = RestDefaults()
    @State private var loaded = false

    var body: some View {
        Form {
            Section {
                row("Heavy machines", value: $draft.heavy, id: "rest-heavy")
                row("Light machines", value: $draft.light, id: "rest-light")
                row("Exercises", value: $draft.exercise, id: "rest-exercise")
            } footer: {
                Text("A machine is heavy when \"Heavy machine\" is on in its settings (the pencil). Exercises are push-ups, sit-ups and others without a machine. A machine with its own rest keeps it.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle("Rest times")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            if !loaded { draft = library.gym.rests; loaded = true }
        }
        .bottomActions(cancel: { dismiss() }, save: {
            let d = draft
            library.changeGym { $0.rests = d }
            dismiss()
        }, tint: Gym.fill, cancelID: "rest-cancel", saveID: "rest-save")
    }

    private func row(_ title: String, value: Binding<Int>, id: String) -> some View {
        Stepper(value: value, in: 0...300, step: 15) {
            HStack {
                Text(title)
                Spacer()
                Text(value.wrappedValue == 0 ? "None" : Clock.text(value.wrappedValue))
                    .foregroundStyle(Gym.tint)
                    .monospacedDigit()
                    .accessibilityIdentifier("\(id)-value")
            }
        }
        .accessibilityIdentifier(id)
    }
}
