import Foundation

// Manual escape hatch for processes that pass the port-scanner's heuristics
// (known binary name, real project cwd) but aren't actually a dev server for
// that project — e.g. a background daemon that happens to share cwd with a
// project because that's where it was first launched from.
struct HiddenServer: Codable, Identifiable {
    var id: String { "\(command.lowercased())|\(projectPath)" }
    let command: String
    let projectPath: String
    let projectName: String
}

enum IgnoredServers {
    private static let defaultsKey = "ignoredServersV2"

    static func hide(command: String, projectPath: String) {
        var list = all()
        let entry = HiddenServer(
            command: command,
            projectPath: projectPath,
            projectName: ProcessResolver.resolveProjectName(from: projectPath)
        )
        guard !list.contains(where: { $0.id == entry.id }) else { return }
        list.append(entry)
        save(list)
    }

    static func isHidden(command: String, projectPath: String) -> Bool {
        let id = HiddenServer(command: command, projectPath: projectPath, projectName: "").id
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
