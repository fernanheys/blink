import Foundation

// Manual escape hatch for processes that pass the port-scanner's heuristics
// (known binary name, real project cwd) but aren't actually a dev server for
// that project — e.g. a background daemon that happens to share cwd with a
// project because that's where it was first launched from.
struct HiddenServer: Codable, Identifiable {
    // Port is part of the identity: the same command+cwd can legitimately
    // run twice on different ports (e.g. a standing instance plus one
    // started to test something), and hiding one shouldn't hide the other.
    var id: String { "\(command.lowercased())|\(projectPath)|\(port)" }
    let command: String
    let projectPath: String
    let projectName: String
    let port: Int

    init(command: String, projectPath: String, projectName: String, port: Int) {
        self.command = command
        self.projectPath = projectPath
        self.projectName = projectName
        self.port = port
    }
}

enum IgnoredServers {
    private static let defaultsKey = "ignoredServersV3"

    static func hide(command: String, projectPath: String, port: Int) {
        var list = all()
        let entry = HiddenServer(
            command: command,
            projectPath: projectPath,
            projectName: ProcessResolver.resolveProjectName(from: projectPath),
            port: port
        )
        guard !list.contains(where: { $0.id == entry.id }) else { return }
        list.append(entry)
        save(list)
    }

    static func isHidden(command: String, projectPath: String, port: Int) -> Bool {
        let id = HiddenServer(command: command, projectPath: projectPath, projectName: "", port: port).id
        return all().contains { $0.id == id }
    }

    static func unhide(id: String) {
        save(all().filter { $0.id != id })
    }

    static func all() -> [HiddenServer] {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let list = try? JSONDecoder().decode([HiddenServer].self, from: data) else {
            return []
        }
        return list
    }

    static var count: Int { all().count }

    static func clearAll() {
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }

    private static func save(_ list: [HiddenServer]) {
        guard let data = try? JSONEncoder().encode(list) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}
