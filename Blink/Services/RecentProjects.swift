import Foundation

// Paths that started successfully via "Start a Project" — most recent first,
// so the page can offer them back up instead of making you dig up the path again.
enum RecentProjects {
    private static let defaultsKey = "recentProjectPathsV1"
    private static let limit = 8

    static func record(_ path: String) {
        var list = all().filter { $0 != path }
        list.insert(path, at: 0)
        if list.count > limit {
            list.removeLast(list.count - limit)
        }
        UserDefaults.standard.set(list, forKey: defaultsKey)
    }

    static func all() -> [String] {
        UserDefaults.standard.stringArray(forKey: defaultsKey) ?? []
    }
}
