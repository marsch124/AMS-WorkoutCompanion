import AMSIcons
import SwiftUI
import WorkoutCore

/// Settings → Muscle groups: add, rename, recolour, reorder and delete the groups machines belong to.
struct MuscleGroupsScreen: View {
    @Environment(Library.self) private var library
    @State private var editing: MuscleGroup?
    @State private var isNew = false
    @State private var pendingDelete: MuscleGroup?

    private static let tint = IconColour.of(key: "red")!.fillColor

    var body: some View {
        List {
            Section {
                ForEach(library.gym.muscles) { m in
                    Button {
                        isNew = false
                        editing = m
                    } label: {
                        HStack(spacing: 10) {
                            Circle().fill(MuscleGroupsScreen.colour(m.colour)).frame(width: 14, height: 14)
                            Text(m.name).foregroundStyle(Theme.ink)
                            Spacer()
                            let n = library.gym.machineCount(muscle: m.id)
                            if n > 0 {
                                Text(n == 1 ? "1 machine" : "\(n) machines")
                                    .font(.footnote).foregroundStyle(Theme.muted)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("muscle-row-\(m.name)")
                }
                .onMove { from, to in library.changeGym { $0.moveMuscles(from: from, to: to) } }
                .onDelete { offsets in
                    if let i = offsets.first { pendingDelete = library.gym.muscles[i] }
                }
            } footer: {
                Text("History and the machines' edit pages use these groups, in this order.")
            }
            Section {
                Button {
                    isNew = true
                    editing = MuscleGroup(id: UUID().uuidString, name: "", colour: "plum")
                } label: {
                    Text("Add a muscle group")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(Self.tint)
                .listRowBackground(Color.clear)
                .accessibilityIdentifier("muscle-add")
            }
        }
        .environment(\.editMode, .constant(.active))
        .scrollContentBackground(.hidden)
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle("Muscle groups")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { group in
            NavigationStack {
                MuscleGroupForm(group: group, isNew: isNew) { saved in
                    if let saved { library.changeGym { $0.save(muscle: saved) } }
                    editing = nil
                } onDelete: {
                    editing = nil
                    pendingDelete = group
                }
            }
        }
        .confirmationDialog(deleteTitle, isPresented: Binding(get: { pendingDelete != nil },
                                                              set: { if !$0 { pendingDelete = nil } }),
                            titleVisibility: .visible, presenting: pendingDelete) { g in
            Button("Delete", role: .destructive) { library.changeGym { $0.delete(muscle: g.id) } }
            Button("Cancel", role: .cancel) {}
        } message: { g in
            Text("\(count(g)) go back to Not chosen. Their sets stay.")
        }
    }

    private var deleteTitle: String { "Delete \(pendingDelete?.name ?? "this group")?" }

    private func count(_ g: MuscleGroup) -> String {
        let n = library.gym.machineCount(muscle: g.id)
        return n == 1 ? "1 machine" : "\(n) machines"
    }

    static func colour(_ key: String) -> Color { IconColour.of(key: key)?.fillColor ?? Theme.muted }
}

private struct MuscleGroupForm: View {
    @State var group: MuscleGroup
    let isNew: Bool
    let done: (MuscleGroup?) -> Void
    let onDelete: () -> Void

    init(group: MuscleGroup, isNew: Bool, done: @escaping (MuscleGroup?) -> Void, onDelete: @escaping () -> Void) {
        _group = State(initialValue: group)
        self.isNew = isNew
        self.done = done
        self.onDelete = onDelete
    }

    private let red = IconColour.of(key: "red")!.fillColor

    var body: some View {
        Form {
            Section("Name") {
                TextField("Name", text: $group.name)
                    .accessibilityIdentifier("muscle-name")
            }
            Section("Colour") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                    ForEach(MuscleGroup.colours, id: \.self) { key in
                        Button { group.colour = key } label: {
                            Circle().fill(MuscleGroupsScreen.colour(key))
                                .frame(width: 32, height: 32)
                                .overlay(Circle().stroke(Theme.ink, lineWidth: group.colour == key ? 2.5 : 0).padding(-4))
                                .frame(maxWidth: .infinity, minHeight: 40)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(key)
                        .accessibilityIdentifier("muscle-colour-\(key)")
                    }
                }
                .padding(.vertical, 4)
            }
            if !isNew {
                Section {
                    Button("Delete muscle group", role: .destructive, action: onDelete)
                        .accessibilityIdentifier("muscle-delete")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle(isNew ? "New muscle group" : "Muscle group")
        .navigationBarTitleDisplayMode(.inline)
        .bottomActions(cancel: { done(nil) }, save: { done(group) }, tint: red,
                       cancelID: "muscle-cancel", saveID: "muscle-save")
    }
}
