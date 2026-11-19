import AMSIcons
import SwiftUI
import WorkoutCore

/// Plan today: tap the machines in the order you want them. Nothing is kept until Save.
struct PlanSheet: View {
    @Environment(Library.self) private var library
    let machines: [Machine]
    let gymID: UUID?
    @State var order: [UUID]
    let done: ([UUID]?) -> Void
    @State private var namingTemplate = false
    @State private var templateName = ""

    private var templates: [PlanTemplate] { library.gym.templates(gym: gymID) }

    var body: some View {
        List {
            if !templates.isEmpty {
                Section {
                    ForEach(templates) { t in
                        // Deleting a template lives in Settings → Plan templates (since 1.14).
                        HStack {
                            Button {
                                order = library.gym.order(of: t)
                            } label: {
                                HStack {
                                    Text(t.name).foregroundStyle(Theme.ink)
                                    Spacer()
                                    let n = library.gym.order(of: t).count
                                    Text(n == 1 ? "1 machine" : "\(n) machines")
                                        .font(.subheadline).foregroundStyle(.secondary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("plan-template-\(t.name)")
                        }
                    }
                    .moveDisabled(true)
                    .deleteDisabled(true)
                } header: {
                    Text("Use a template")
                }
            }
            // Today's order with drag handles (1.9.3, his "adjust the plan — maybe with drag handles?").
            if !order.isEmpty {
                Section {
                    ForEach(Array(order.enumerated()), id: \.element) { i, id in
                        if let m = machines.first(where: { $0.id == id }) {
                            HStack(spacing: 10) {
                                Text("\(i + 1)")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(Gym.ink)
                                    .frame(width: 26, height: 26)
                                    .background(Gym.fill, in: Circle())
                                MachinePhoto(name: m.photo, height: 36, icon: m.icon)
                                    .frame(width: 36)
                                Text(m.name).foregroundStyle(Theme.ink)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("\(i + 1), \(m.name)")
                            .accessibilityIdentifier("plan-order-\(i + 1)")
                        }
                    }
                    .onMove { order.move(fromOffsets: $0, toOffset: $1) }
                    .onDelete { order.remove(atOffsets: $0) }
                } header: {
                    Text("Today's order")
                } footer: {
                    Text("Drag the handles to change the order; the red minus takes a machine out.")
                }
                // Right under the order, so it is never hidden behind Cancel and Save (1.10).
                Section {
                    Button {
                        templateName = ""
                        namingTemplate = true
                    } label: {
                        Text("Save as template…")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Gym.ink)
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .background(Gym.fill, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .accessibilityIdentifier("plan-save-template")
                }
            }
            Section {
                ForEach(machines) { m in
                    let n = order.firstIndex(of: m.id).map { $0 + 1 }
                    Button {
                        if let i = order.firstIndex(of: m.id) { order.remove(at: i) } else { order.append(m.id) }
                    } label: {
                        HStack(spacing: 10) {
                            Text(n.map(String.init) ?? "")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Gym.ink)
                                .frame(width: 26, height: 26)
                                .background(n == nil ? AnyShapeStyle(Color.clear) : AnyShapeStyle(Gym.fill), in: Circle())
                                .overlay(Circle().stroke(Gym.fill, lineWidth: n == nil ? 1.5 : 0))
                            MachinePhoto(name: m.photo, height: 36, icon: m.icon)
                                .frame(width: 36)
                            Text(m.name).foregroundStyle(Theme.ink)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("plan-machine-\(m.name)")
                }
                .moveDisabled(true)
                .deleteDisabled(true)
            } header: {
                Text(order.isEmpty ? "Machines" : "Add or take out")
            } footer: {
                Text("Tap the machines in the order you want them; tap again to take one out. You can still use any machine at the gym.")
            }
            if !order.isEmpty {
                Section {
                    Button("Clear the plan", role: .destructive) { order = [] }
                        .accessibilityIdentifier("plan-clear")
                }
            }
        }
        .alert("Save as template", isPresented: $namingTemplate) {
            TextField("For example: Leg day", text: $templateName)
            Button("Cancel", role: .cancel) {}
                .accessibilityIdentifier("plan-template-cancel")
            Button("Save") {
                let name = templateName, o = order, g = gymID
                library.changeGym { _ = $0.saveTemplate(named: name, order: o, gym: g) }
            }
            .accessibilityIdentifier("plan-template-name-save")
        } message: {
            Text("The same name in this gym is replaced.")
        }
        // Always in edit mode, so the handles show without an Edit button.
        .environment(\.editMode, .constant(.active))
        .navigationTitle("Plan today")
        .navigationBarTitleDisplayMode(.inline)
        .bottomActions(cancel: { done(nil) }, save: { done(order) }, tint: Gym.fill,
                       cancelID: "plan-cancel", saveID: "plan-save")
    }
}
