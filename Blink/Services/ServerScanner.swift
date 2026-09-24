import Foundation

extension AppState {
    fileprivate static let devCommands: Set<String> = [
        "node", "python", "python3", "ruby", "cargo",
        "go", "php", "java", "deno", "bun", "tsx", "npx",
        "next-serv", "uvicorn", "gunicorn", "puma"
    ]

    func scanServers() async -> [DevServer] {
        let ports = await PortScanner.scan()

        let devPorts = ports.filter { port in
            Self.devCommands.contains(port.command.lowercased())
        }

        var seenPorts = Set<Int>()
        var seenPIDs = Set<Int>()
        let uniquePorts = devPorts.filter { port in
            seenPorts.insert(port.port).inserted && seenPIDs.insert(port.pid).inserted
        }

        return await withTaskGroup(of: DevServer?.self) { group in
            for port in uniquePorts {
                group.addTask {
                    guard let info = await ProcessResolver.resolve(pid: port.pid) else {
                        return nil
                    }
                    // No real dev server runs with cwd at the filesystem
                    // root — this is almost always a background daemon
                    // (Raycast, browser helper apps...) that happens to
                    // hold a listening socket under a matched binary name.
                    guard !info.workingDirectory.isEmpty, info.workingDirectory != "/" else {
                        return nil
                    }
                    // claude-mem's worker daemon is a single process shared
                    // across every project — its cwd is just whichever one
                    // last touched it, so it relabels itself (and drifts
                    // past any cwd-keyed Hide entry) on every restart.
                    guard !info.arguments.contains("claude-mem") else {
                        return nil
                    }
                    guard !IgnoredServers.isHidden(command: port.command, projectPath: info.workingDirectory, port: port.port) else {
                        return nil
                    }
                    let framework = ProcessResolver.detectFramework(from: info)
                    let projectName = ProcessResolver.resolveProjectName(from: info.workingDirectory)

                    return DevServer(
                        pid: port.pid,
                        port: port.port,
                        command: port.command,
                        framework: framework,
                        projectName: projectName,
                        projectPath: info.workingDirectory
                    )
                }
            }

            var results: [DevServer] = []
            for await server in group {
                if let server { results.append(server) }
            }
            return results.sorted { $0.port < $1.port }
        }
    }
}
