import AMSIcons
import SwiftUI
import WorkoutCore

/// Settings → Sounds (since 1.23): the "rest over" sound, the vibration and the spoken countdown.
/// Nothing is kept until Save.
struct SoundsScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft = SoundChoice.load()

    var body: some View {
        Form {
            Section("Rest over sound") {
                ForEach(RestSound.allCases, id: \.self) { s in
                    row(s.title, chosen: draft.restSound == s, id: "sounds-sound-\(s.rawValue)") {
                        draft.restSound = s
                        Cues.shared.preview(s)
                    }
                }
            }
            Section("Vibration") {
                ForEach(Buzz.allCases, id: \.self) { b in
                    row(b.title, chosen: draft.buzz == b, id: "sounds-buzz-\(b.rawValue)") {
                        draft.buzz = b
                        Cues.shared.preview(b)
                    }
                }
            }
            Section {
                Toggle("Spoken countdown", isOn: $draft.spokenCountdown)
                    .tint(Theme.accent)
                    .accessibilityIdentifier("sounds-spoken")
            } footer: {
                Text("Says three, two, one and the halfway point in interval workouts.")
            }
        }
        .scrollContentBackground(.hidden)
        .readableWidth(680)
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle("Sounds")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .bottomActions(cancel: { dismiss() }, save: {
            draft.save()
            dismiss()
        }, cancelID: "sounds-cancel", saveID: "sounds-save")
    }

    private func row(_ title: String, chosen: Bool, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).foregroundStyle(Theme.ink)
                Spacer()
                if chosen { ControlMarkView(.check, size: 18, colour: Theme.accent) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(chosen ? .isSelected : [])
        .accessibilityIdentifier(id)
    }
}
