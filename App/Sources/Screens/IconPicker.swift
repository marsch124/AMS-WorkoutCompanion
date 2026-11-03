import AMSIcons
import SwiftUI

/// Choose one of the hand-drawn icons. Put it in a NavigationStack (a sheet).
/// Nothing is kept until Save; "Use the usual icon" gives nil.
struct IconPicker: View {
    let current: String?
    let tint: Color
    let onSave: (String?) -> Void
    let onCancel: () -> Void

    @State private var query = ""
    @State private var chosen: String?

    init(current: String?, tint: Color = Theme.accent, onSave: @escaping (String?) -> Void, onCancel: @escaping () -> Void) {
        self.current = current
        self.tint = tint
        self.onSave = onSave
        self.onCancel = onCancel
        _chosen = State(initialValue: current)
    }

    private var sections: [IconSection] { IconLibrary.search(query) { $0.kind == .hand } }
    private let columns = [GridItem(.adaptive(minimum: 64, maximum: 90), spacing: 6)]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10, pinnedViews: []) {
                Button { chosen = nil } label: {
                    HStack {
                        Text("Use the usual icon").font(.body.weight(.semibold))
                        Spacer()
                        if chosen == nil {
                            ControlMarkView(.check, size: 16, colour: tint)
                        }
                    }
                    .foregroundStyle(tint)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("icon-picker-usual")

                ForEach(sections) { section in
                    Text(section.groupTitle)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(tint)
                        .padding(.top, 4)
                    LazyVGrid(columns: columns, spacing: 6) {
                        ForEach(section.refs, id: \.id) { ref in
                            let on = chosen == ref.name
                            Button { chosen = ref.name } label: {
                                VStack(spacing: 2) {
                                    IconMark(ref, size: 28, colour: on ? Color.white : tint)
                                    Text(IconLibrary.label(for: ref) ?? ref.name)
                                        .font(.caption2)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                        .foregroundStyle(on ? Color.white : Theme.muted)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(on ? tint : tint.opacity(0.1),
                                            in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(IconLibrary.label(for: ref) ?? ref.name)
                            .accessibilityIdentifier("icon-\(ref.name)")
                        }
                    }
                }
                if sections.isEmpty {
                    Text("No icon found.").font(.subheadline).foregroundStyle(Theme.muted)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Theme.bg.ignoresSafeArea())
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search icons")
        .navigationTitle("Icon")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("icon-picker-cancel")
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { onSave(chosen) }
                    .saveButton()
                    .accessibilityIdentifier("icon-picker-save")
            }
        }
    }
}

/// A form row "Icon" showing the current icon; opens the picker in a sheet.
struct IconRow: View {
    let icon: String?
    let usual: String
    let tint: Color
    let identifier: String
    let onSave: (String?) -> Void
    @State private var open = false

    var body: some View {
        Button { open = true } label: {
            HStack {
                Text("Icon").foregroundStyle(Theme.ink)
                Spacer()
                IconMark(.hand(icon ?? usual), size: 24, colour: tint)
                ControlMarkView(.chevron, size: 12, colour: Theme.muted)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(icon ?? usual)
        .accessibilityIdentifier(identifier)
        .sheet(isPresented: $open) {
            NavigationStack {
                IconPicker(current: icon, tint: tint) { key in
                    onSave(key); open = false
                } onCancel: { open = false }
            }
        }
    }
}
