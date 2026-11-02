import AMSIcons
import SwiftUI
import WorkoutCore

/// Runs an exercise list: each exercise a card with its photo, ticked off one by one.
struct ChecklistScreen: View {
    @Environment(Library.self) private var library
    let workout: Workout
    let onClose: () -> Void

    @State private var done: Set<UUID> = []
    @State private var zoom: ZoomedPhoto?

    private var allDone: Bool { !workout.exercises.isEmpty && done.count == workout.exercises.count }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 10) {
                        if workout.exercises.isEmpty {
                            Text("This list has no exercises yet. Close, then tap the pencil to add them.")
                                .font(.title3)
                                .foregroundStyle(Theme.muted)
                                .multilineTextAlignment(.center)
                                .padding(.top, 60)
                        }
                        ForEach(Array(workout.exercises.enumerated()), id: \.element.id) { i, e in
                            card(e, number: i + 1)
                                .id(e.id)
                        }
                        if allDone {
                            VStack(spacing: 24) {
                                FinishedBadge(workout: workout)
                                Button("Close", action: onClose)
                                    .buttonStyle(BigButtonStyle(fill: workout.fill, ink: workout.inkOnFill))
                                    .accessibilityIdentifier("run-finish-close")
                            }
                            .padding(.vertical, 30)
                            .id("finished")
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(16)
                }
                .onChange(of: done) { _, now in
                    if allDone {
                        Cues.shared.finished("Well done. All exercises done.")
                        withAnimation(.spring(duration: 0.5)) { proxy.scrollTo("finished", anchor: .center) }
                    } else if let next = workout.exercises.first(where: { !now.contains($0.id) }) {
                        withAnimation { proxy.scrollTo(next.id, anchor: .top) }
                    }
                }
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .onAppear { Cues.shared.begin() }
        .onDisappear { Cues.shared.end() }
        .fullScreenCover(item: $zoom) { z in
            ZStack {
                Color.black.ignoresSafeArea()
                Image(uiImage: z.image).resizable().scaledToFit()
            }
            .onTapGesture { zoom = nil }
            .overlay(alignment: .topTrailing) {
                CloseButton { zoom = nil }.padding()
            }
        }
    }

    private var header: some View {
        VStack(spacing: 14) {
            HStack {
                CloseButton(action: onClose)
                Spacer()
                VStack(spacing: 2) {
                    Text(workout.name)
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(Theme.ink)
                    Text("\(done.count) of \(workout.exercises.count) done")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                        .contentTransition(.numericText())
                        .accessibilityIdentifier("run-count")
                }
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.line)
                    Capsule().fill(workout.fill)
                        .frame(width: workout.exercises.isEmpty ? 0 : g.size.width * Double(done.count) / Double(workout.exercises.count))
                }
            }
            .frame(height: 6)
            .animation(.easeInOut, value: done.count)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private func card(_ e: Exercise, number: Int) -> some View {
        let isDone = done.contains(e.id)
        return VStack(alignment: .leading, spacing: 0) {
            if let image = library.image(e.photo) {
                Button { zoom = ZoomedPhoto(image: image) } label: {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 180)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .overlay(alignment: .bottomTrailing) {
                            ControlMarkView(.expand, size: 14, colour: .white)
                                .padding(8)
                                .background(.black.opacity(0.45), in: Circle())
                                .padding(10)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Photo of \(e.name), tap to enlarge")
            }

            Button {
                withAnimation(.spring(duration: 0.3)) {
                    if isDone { done.remove(e.id) } else { done.insert(e.id) }
                }
                Cues.shared.tap()
            } label: {
                HStack(alignment: .top, spacing: 14) {
                    ControlMarkView(isDone ? .ticked : .circle, size: 32, colour: isDone ? workout.fill : Theme.muted)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("\(number)")
                                .font(.system(.subheadline, design: .rounded, weight: .heavy))
                                .foregroundStyle(Theme.muted)
                            Text(e.name.isEmpty ? "Exercise" : e.name)
                                .font(.headline)
                                .foregroundStyle(Theme.ink)
                                .multilineTextAlignment(.leading)
                        }
                        if !e.amount.isEmpty {
                            Text(e.amount)
                                .font(.system(.headline, design: .rounded))
                                .foregroundStyle(workout.inkOnFill)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 5)
                                .background(workout.fill, in: Capsule())
                        }
                        if !e.note.isEmpty {
                            Text(e.note)
                                .font(.body)
                                .foregroundStyle(Theme.muted)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(e.name), \(isDone ? "done" : "not done")")
            .accessibilityIdentifier("check-\(number)")
        }
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(isDone ? workout.fill : Theme.line, lineWidth: isDone ? 2 : 1))
        .opacity(isDone ? 0.6 : 1)
    }
}

private struct ZoomedPhoto: Identifiable {
    let id = UUID()
    let image: UIImage
}
