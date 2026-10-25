import EarmarkShared
import SwiftUI

/// The only screen. Mirrored for judges during the demo, so the people-met list is big and readable.
struct EventScreen: View {
    @Bindable var model: AppModel
    @State private var confirmingForget = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                switch model.phase {
                case .idle:
                    idle
                case .enrolling:
                    enrolling
                case .running, .ending:
                    PeopleMetList(people: model.people)
                }

                if let status = model.statusMessage {
                    Text(status)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                controls
                debugLine
            }
            .padding()
            .navigationTitle("Earmark")
        }
    }

    private var idle: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("Hang the phone at chest height, mic facing out, AirPods in.")
                .font(.title3)
                .multilineTextAlignment(.center)
            Toggle("Demo mode (20 s re-meet gap)", isOn: $model.demoMode)
            Toggle("Play out loud from the iPhone", isOn: $model.speakerMode)
            if !model.engineLinked {
                Label("Engine not linked yet", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }
            Spacer()
        }
    }

    private var enrolling: some View {
        VStack(spacing: 24) {
            Text("Read this out loud")
                .font(.headline)
                .foregroundStyle(.secondary)
            ScrollView {
                Text(WhisperLines.enrollmentSentence)
                    .font(.title2)
                    .multilineTextAlignment(.leading)
            }
            ProgressView(value: model.enrollmentProgress)
        }
    }

    @ViewBuilder
    private var controls: some View {
        switch model.phase {
        case .idle:
            Button("Start event") { Task { await model.startEvent() } }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!model.engineLinked || model.isTestingGesture)
            Button(model.isTestingGesture ? "Listening for a nod or shake…" : "Test nod / shake") {
                Task { await model.testGesture() }
            }
            .buttonStyle(.bordered)
            .disabled(model.isTestingGesture)
            if model.canForget {
                Button("Forget everyone", role: .destructive) { confirmingForget = true }
                    .disabled(model.isTestingGesture)
                    .confirmationDialog("Delete everyone Earmark remembers?", isPresented: $confirmingForget) {
                        Button("Forget everyone", role: .destructive) { Task { await model.forgetEveryone() } }
                    } message: {
                        Text("Their voice signatures, names and notes are deleted from this phone. Your own voice is kept.")
                    }
                Button("Re-record my voice") { Task { await model.rerecordVoice() } }
                    .disabled(model.isTestingGesture)
            }
        case .enrolling, .running:
            Button("End event", role: .destructive) { Task { await model.endEvent() } }
                .buttonStyle(.bordered)
                .controlSize(.large)
        case .ending:
            ProgressView("Saving…")
        }
    }

    private var debugLine: some View {
        HStack {
            Image(systemName: "airpods.pro")
                .foregroundStyle(model.airPodsMotionConnected ? .green : .secondary)
            Text(model.routeDescription)
        }
        .font(.caption2)
        .foregroundStyle(.tertiary)
    }
}

struct PeopleMetList: View {
    let people: [PersonSummary]

    var body: some View {
        if people.isEmpty {
            ContentUnavailableView("Listening…", systemImage: "ear", description: Text("People you meet show up here."))
        } else {
            List(people) { person in
                VStack(alignment: .leading, spacing: 4) {
                    Text(person.name ?? "Unnamed")
                        .font(.title2.bold())
                    if !person.note.isEmpty {
                        Text(person.note)
                            .font(.body)
                    }
                    Text(person.lastHeard, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            .listStyle(.plain)
        }
    }
}
