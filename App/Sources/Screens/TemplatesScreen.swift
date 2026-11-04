import SwiftUI
import WorkoutCore

/// Settings → Plan templates (since 1.14): every saved plan template, by gym, each with its machines and a Delete.
/// Before 1.14 a template was deleted from Plan today — his "totally illogical" there.
struct TemplatesScreen: View {
    @Environment(Library.self) private var library

    /// Gyms that have templates, in the gyms' order; templates from before gyms existed under "My gym".
    private var groups: [(id: UUID?, name: String, templates: [PlanTemplate])] {
        var out: [(UUID?, String, [PlanTemplate])] = []
        let ids: [UUID?] = library.gym.gyms.map { Optional($0.id) } + [nil]
        for id in ids {
            let ts = library.gym.templates(gym: id)
            if ts.isEmpty { continue }
            out.append((id, library.gym.gyms.first { $0.id == id }?.name ?? "My gym", ts))
        }
        return out
    }

    var body: some View {
        List {
            if groups.isEmpty {
                Text("No templates yet. In Plan today, put the machines in order and tap \"Save as template…\".")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                    .accessibilityIdentifier("templates-empty")
            }
            ForEach(groups, id: \.name) { g in
                Section {
                    ForEach(g.templates) { t in row(t) }
                } header: {
                    Text(g.name).foregroundStyle(Gym.tint)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle("Plan templates")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ t: PlanTemplate) -> some View {
        let names = library.gym.order(of: t).compactMap { library.gym.machine($0)?.name }
        return HStack(alignment: .top, spacing: 10) {
            AppMarkView(.template, size: 20, colour: Gym.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(t.name).font(.body.weight(.semibold)).foregroundStyle(Theme.ink)
                Text(names.joined(separator: " · "))
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                library.changeGym(undo: "Template \(t.name) deleted") { $0.deleteTemplate(t.id) }
            } label: {
                AppMarkView(.trash, size: 20, colour: .red)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete the template \(t.name)")
            .accessibilityIdentifier("template-delete-\(t.name)")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("template-\(t.name)")
    }
}
