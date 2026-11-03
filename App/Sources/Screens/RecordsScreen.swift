import AMSIcons
import SwiftUI
import WorkoutCore

/// Every machine's best, newest record first (since 1.11).
struct RecordsScreen: View {
    @Environment(Library.self) private var library

    var body: some View {
        let rows = Stats.records(library.gym)
        ScrollView {
            VStack(spacing: 0) {
                if rows.isEmpty {
                    Text("No records yet. Log some sets at the gym and your best on each machine shows up here.")
                        .font(.subheadline).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
                        .padding(.top, 40).padding(.horizontal, 16)
                        .accessibilityIdentifier("records-empty")
                }
                ForEach(Array(rows.enumerated()), id: \.element.id) { i, r in
                    NavigationLink { VisitScreen(visitID: r.visitID) } label: { row(r) }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("records-row-\(i + 1)")
                    if i < rows.count - 1 { Divider().padding(.leading, 66) }
                }
            }
            .background(rows.isEmpty ? Color.clear : Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, 16).padding(.vertical, 8)
        }
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle("Records")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ r: RecordRow) -> some View {
        HStack(spacing: 10) {
            MachinePhoto(name: r.machine.photo, height: 44, icon: r.machine.icon).frame(width: 44)
            VStack(alignment: .leading, spacing: 1) {
                Text(r.machine.name).font(.body.weight(.semibold)).foregroundStyle(Theme.ink).lineLimit(1)
                Text(r.set.isTime ? r.set.text : library.gym.text(r.set, machine: r.machine.id))
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Gym.tint)
                Text(r.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).year()))
                    .font(.caption).foregroundStyle(Theme.muted)
            }
            Spacer()
            IconMark(.hand("trophy"), size: 20, colour: Gym.tint)
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .contentShape(Rectangle())
    }
}
