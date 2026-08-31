import SwiftUI

struct StartProjectPage: View {
    let back: () -> Void

    @Environment(AppState.self) private var appState

    @State private var path = ""
    @State private var error: String?
    @State private var isStarting = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            PanelPageHeader(title: "Start a Project", back: back)
            PanelDivider()

            VStack(alignment: .leading, spacing: 10) {
                Text("Paste a project folder — Blink figures out the command (yarn/npm/pnpm/bun, wrapped with op run if the project uses one).")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                TextField("~/Projetos/pugnplay/pug-email", text: $path)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .padding(8)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                    .focused($isFocused)
                    .disabled(isStarting)
                    .onSubmit { start() }

                if let error {
                    Text(error)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.alert)
                }

                Button(action: start) {
                    Text(isStarting ? "Starting…" : "Start")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(Color.accent.opacity(path.isEmpty || isStarting ? 0.4 : 1), in: RoundedRectangle(cornerRadius: 6))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .disabled(path.isEmpty || isStarting)
            }
            .padding(16)

            Spacer()
        }
        .onAppear { isFocused = true }
    }

    private func start() {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        error = nil
        isStarting = true

        Task {
            let expanded = (trimmed as NSString).expandingTildeInPath
            let failure = await appState.startProject(at: expanded)
            isStarting = false
            if let failure {
                error = failure
            } else {
                path = ""
                back()
            }
        }
    }
}
