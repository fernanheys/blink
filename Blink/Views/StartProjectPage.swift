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

                HStack(spacing: 6) {
                    TextField("~/Projetos/pugnplay/pug-email", text: $path)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .monospaced))
                        .focused($isFocused)
                        .disabled(isStarting)
                        .onSubmit { start() }

                    // Cmd+V into a TextField hosted in a non-activating
                    // NSPanel is unreliable with no app menu to back it —
                    // read the pasteboard directly instead of relying on it.
                    Button {
                        if let clipboard = NSPasteboard.general.string(forType: .string) {
                            path = clipboard.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    } label: {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Paste from clipboard")

                    Button {
                        let panel = NSOpenPanel()
                        panel.canChooseDirectories = true
                        panel.canChooseFiles = false
                        panel.allowsMultipleSelection = false
                        if panel.runModal() == .OK, let url = panel.url {
                            path = url.path
                        }
                    } label: {
                        Image(systemName: "folder")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Choose a folder")
                }
                .padding(8)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))

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

                if !appState.recentProjectPaths.isEmpty {
                    recents
                }
            }
            .padding(16)

            Spacer()
        }
        .onAppear { isFocused = true }
    }

    private var recents: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("RECENT")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.tertiary)

            ForEach(appState.recentProjectPaths, id: \.self) { recent in
                Button {
                    path = recent
                    start()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        Text((recent as NSString).lastPathComponent)
                            .font(.system(size: 12, weight: .medium))
                        Text(Self.abbreviated(recent))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.head)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isStarting)
            }
        }
        .padding(.top, 4)
    }

    private static func abbreviated(_ path: String) -> String {
        let home = NSHomeDirectory()
        guard path.hasPrefix(home) else { return path }
        return "…" + path.dropFirst(home.count)
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
