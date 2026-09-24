import Foundation

// Given a project path, work out how its dev server is meant to be started —
// same package manager the project already committed to (lockfile), wrapped
// with `op run` when the project's env comes from 1Password.
enum CommandInference {
    struct Plan {
        let executablePath: String
        let arguments: [String]
        let directory: String
    }

    enum ResolutionError: LocalizedError {
        case notFound(String)
        case noPackageManager
        case noDevScript
        case binaryNotFound(String)

        var errorDescription: String? {
            switch self {
            case .notFound(let path): "No folder at \(path)."
            case .noPackageManager: "No lockfile found (yarn.lock, package-lock.json, pnpm-lock.yaml, bun.lockb)."
            case .noDevScript: "package.json has no \"dev\" script."
            case .binaryNotFound(let bin): "Couldn't find \"\(bin)\" on PATH."
            }
        }
    }

    static func resolve(projectPath: String) -> Result<Plan, ResolutionError> {
        let fm = FileManager.default
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: projectPath, isDirectory: &isDirectory), isDirectory.boolValue else {
            return .failure(.notFound(projectPath))
        }

        guard hasDevScript(in: projectPath) else {
            return .failure(.noDevScript)
        }

        guard let manager = packageManager(in: projectPath) else {
            return .failure(.noPackageManager)
        }

        guard let managerPath = binaryPath(for: manager) else {
            return .failure(.binaryNotFound(manager))
        }

        if usesOpRun(in: projectPath) {
            guard let opPath = binaryPath(for: "op") else {
                return .failure(.binaryNotFound("op"))
            }
            return .success(Plan(
                executablePath: opPath,
                arguments: ["run", "--env-file=.env.tpl", "--", managerPath, "dev"],
                directory: projectPath
            ))
        }

        return .success(Plan(executablePath: managerPath, arguments: ["dev"], directory: projectPath))
    }

    private static func hasDevScript(in directory: String) -> Bool {
        let packageJSON = (directory as NSString).appendingPathComponent("package.json")
        guard let data = FileManager.default.contents(atPath: packageJSON),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let scripts = json["scripts"] as? [String: Any] else {
            return false
        }
        return scripts["dev"] != nil
    }

    private static func packageManager(in directory: String) -> String? {
        let fm = FileManager.default
        let dir = directory as NSString
        if fm.fileExists(atPath: dir.appendingPathComponent("bun.lockb")) { return "bun" }
        if fm.fileExists(atPath: dir.appendingPathComponent("pnpm-lock.yaml")) { return "pnpm" }
        if fm.fileExists(atPath: dir.appendingPathComponent("yarn.lock")) { return "yarn" }
        if fm.fileExists(atPath: dir.appendingPathComponent("package-lock.json")) { return "npm" }
        return nil
    }

    private static func usesOpRun(in directory: String) -> Bool {
        let path = (directory as NSString).appendingPathComponent(".env.tpl")
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return false }
        return content.contains("op://")
    }

    // ~/.local/bin comes first so shims like the `op` service-account wrapper
    // (which keeps the token out of the global environment) win over the raw
    // binary a plain PATH search would find in /opt/homebrew/bin.
    private static let fallbackSearchPaths = [
        (NSHomeDirectory() as NSString).appendingPathComponent(".local/bin"),
        "/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin"
    ]

    private static func binaryPath(for name: String) -> String? {
        let fm = FileManager.default
        var directories = fallbackSearchPaths
        if let pathEnv = ProcessInfo.processInfo.environment["PATH"] {
            directories = pathEnv.split(separator: ":").map(String.init) + directories
        }
        for directory in directories {
            let candidate = (directory as NSString).appendingPathComponent(name)
            if fm.isExecutableFile(atPath: candidate) { return candidate }
        }
        return nil
    }
}
