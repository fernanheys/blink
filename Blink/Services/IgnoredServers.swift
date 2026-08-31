import Foundation

// Manual escape hatch for processes that pass the port-scanner's heuristics
// (known binary name, real project cwd) but aren't actually a dev server for
// that project — e.g. a background daemon that happens to share cwd with a
// project because that's where it was first launched from.
enum IgnoredServers {
    private static let defaultsKey = "ignoredServers"

    static func hide(command: String, projectPath: String) {
        var set = storedSet()
        set.insert(identity(command: command, projectPath: projectPath))
        UserDefaults.standard.set(Array(set), forKey: defaultsKey)
    }

    static func isHidden(command: String, projectPath: String) -> Bool {
        storedSet().contains(identity(command: command, projectPath: projectPath))
    }

    static var count: Int { storedSet().count }

    static func clearAll() {
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }

    private static func identity(command: String, projectPath: String) -> String {
        "\(command.lowercased())|\(projectPath)"
    }

    private static func storedSet() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: defaultsKey) ?? [])
    }
}
