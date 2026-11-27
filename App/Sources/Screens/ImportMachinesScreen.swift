import SwiftUI
import UIKit
import WorkoutCore

/// 3.3: paste the link of a gym's or a maker's page, tick the machines it shows, add them to the gym.
struct ImportMachinesScreen: View {
    let gymID: UUID?
    let done: () -> Void

    @Environment(Library.self) private var library
    @State private var link = ""
    @State private var reading = false
    @State private var adding = false
    @State private var error: String?
    @State private var found: [ImportCandidate]?
    @State private var ticked: Set<String> = []
    @FocusState private var linkFocus: Bool

    private static let demo = ProcessInfo.processInfo.arguments.contains("-importdemo")
    private static let agent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 10)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Paste the link of a page that shows machines — your gym's own page or the maker's. Then tick the ones to add.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                    HStack(spacing: 8) {
                        TextField("https://…", text: $link)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($linkFocus)
                            .submitLabel(.go)
                            .onSubmit(find)
                            .padding(10)
                            .background(Theme.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .accessibilityIdentifier("import-url")
                        Button("Paste") {
                            if let s = UIPasteboard.general.string { link = s.trimmingCharacters(in: .whitespacesAndNewlines) }
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                        .tint(Gym.tint)
                        .accessibilityIdentifier("import-paste")
                    }
                    Button(action: find) {
                        Text("Find machines").frame(maxWidth: .infinity)
                    }
                    .saveButton(Gym.fill)
                    .controlSize(.large)
                    .disabled(link.trimmingCharacters(in: .whitespaces).isEmpty || reading || adding)
                    .accessibilityIdentifier("import-find")

                    if reading {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Reading the page…").font(.subheadline).foregroundStyle(Theme.muted)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("import-reading")
                    }
                    if let error {
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(Theme.problem)
                            .accessibilityIdentifier("import-error")
                    }
                    if let found, !found.isEmpty { results(found) }
                }
                .padding(16)
            }
            .background(Theme.bg)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Import from a web page")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom, spacing: 0) { bar }
        }
    }

    // MARK: Results

    @ViewBuilder
    private func results(_ list: [ImportCandidate]) -> some View {
        HStack(spacing: 8) {
            Text("\(list.count) found · \(ticked.count) ticked")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Gym.tint)
                .accessibilityIdentifier("import-count")
            Spacer(minLength: 0)
            Button("All") { ticked = Set(list.filter { !$0.alreadyThere }.map(\.id)) }
                .buttonStyle(.bordered).buttonBorderShape(.capsule).tint(Gym.tint)
                .accessibilityIdentifier("import-all")
            Button("None") { ticked = [] }
                .buttonStyle(.bordered).buttonBorderShape(.capsule).tint(Gym.tint)
                .accessibilityIdentifier("import-none")
        }
        .padding(.top, 4)
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(Array(list.enumerated()), id: \.element.id) { index, item in
                card(item, index: index)
            }
        }
        Text("Tap a machine to tick it. You can rename it and add the seat setting later with its pencil.")
            .font(.footnote)
            .foregroundStyle(Theme.muted)
    }

    private func card(_ item: ImportCandidate, index: Int) -> some View {
        let on = ticked.contains(item.id)
        return Button {
            if on { ticked.remove(item.id) } else { ticked.insert(item.id) }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                picture(item)
                    .overlay(alignment: .topTrailing) {
                        if on { tick.padding(6) }
                    }
                Text(item.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if item.alreadyThere {
                    Text("Already in this gym").font(.caption).foregroundStyle(Theme.muted)
                }
            }
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(on ? Gym.fill : Theme.line, lineWidth: on ? 2 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(on ? "\(item.name), ticked" : item.name)
        .accessibilityIdentifier("import-item-\(index)")
    }

    @ViewBuilder
    private func picture(_ item: ImportCandidate) -> some View {
        if let url = item.imageURL, !Self.demo {
            Color.clear
                .frame(maxWidth: .infinity).frame(height: 110)
                .overlay {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            MachinePhoto(name: nil, height: 110, icon: nil)
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
            MachinePhoto(name: nil, height: 110, icon: nil)
        }
    }

    /// A round tick in the gym blue (green stays for "done today").
    private var tick: some View {
        ZStack {
            Circle().fill(Gym.fill)
            Path { p in
                p.move(to: CGPoint(x: 6.5, y: 12))
                p.addLine(to: CGPoint(x: 10.5, y: 16))
                p.addLine(to: CGPoint(x: 17.5, y: 8))
            }
            .stroke(Gym.ink, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
        }
        .frame(width: 24, height: 24)
        .accessibilityHidden(true)
    }

    // MARK: Bottom bar

    private var bar: some View {
        HStack(spacing: 12) {
            Button("Cancel", action: done)
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .tint(Theme.muted)
                .foregroundStyle(Theme.ink)
                .keyboardShortcut(.cancelAction)
                .disabled(adding)
                .accessibilityIdentifier("import-cancel")
            Spacer(minLength: 0)
            if adding { Text("Adding…").font(.subheadline).foregroundStyle(Theme.muted) }
            Button(addTitle, action: add)
                .saveButton(Gym.fill)
                .disabled(ticked.isEmpty || adding)
                .accessibilityIdentifier("import-add")
        }
        .controlSize(.large)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Theme.bg.opacity(0.96).ignoresSafeArea(edges: .bottom))
    }

    private var addTitle: String {
        ticked.count == 1 ? "Add 1 machine" : "Add \(ticked.count) machines"
    }

    // MARK: Work

    private func find() {
        guard !reading, !adding else { return }
        linkFocus = false
        error = nil
        found = nil
        ticked = []
        let existing = library.gym.machines.filter { $0.gymID == gymID }.map(\.name)
        if Self.demo {
            let list = MachineImport.candidates(html: MachineImport.demoHTML, base: URL(string: "https://example.com/")!, existing: existing)
            show(list)
            return
        }
        guard let url = MachineImport.normalised(link) else {
            error = "Could not read that page. That does not look like a web link."
            return
        }
        reading = true
        Task {
            do {
                var request = URLRequest(url: url, timeoutInterval: 20)
                request.setValue(Self.agent, forHTTPHeaderField: "User-Agent")
                let (data, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                    reading = false
                    error = "Could not read that page. The site answered with code \(http.statusCode)."
                    return
                }
                let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) ?? ""
                let base = response.url ?? url
                reading = false
                show(MachineImport.candidates(html: html, base: base, existing: existing))
            } catch {
                reading = false
                self.error = "Could not read that page. " + ((error as? URLError)?.code == .timedOut ? "It took too long." : "Check the link and the connection.")
            }
        }
    }

    private func show(_ list: [ImportCandidate]) {
        if list.isEmpty { error = "No machines found on this page — try the page that lists them." }
        found = list
    }

    private func add() {
        guard let list = found, !adding else { return }
        let chosen = list.filter { ticked.contains($0.id) }
        guard !chosen.isEmpty else { return }
        adding = true
        Task {
            for item in chosen {
                var stored: String?
                if !Self.demo, let url = item.imageURL {
                    var request = URLRequest(url: url, timeoutInterval: 20)
                    request.setValue(Self.agent, forHTTPHeaderField: "User-Agent")
                    if let (data, _) = try? await URLSession.shared.data(for: request) { stored = library.storePhoto(data) }
                }
                let machine = Machine(gymID: gymID, name: item.name, photo: stored)
                library.changeGym { $0.save(machine) }
            }
            adding = false
            done()
        }
    }
}
