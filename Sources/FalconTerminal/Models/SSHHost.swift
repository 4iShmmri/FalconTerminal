import Foundation

/// A saved SSH connection. The terminal connects by spawning the system `ssh`
/// client in a PTY, so all of the user's existing keys, agents, and
/// `~/.ssh/config` settings work unchanged.
struct SSHHost: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var name: String
    var hostname: String
    var port: Int
    var username: String
    /// Optional path to a private key (`ssh -i`).
    var identityFile: String
    /// Sidebar grouping, e.g. "Production", "Development", "Testing".
    var group: String

    init(
        id: UUID = UUID(),
        name: String,
        hostname: String,
        port: Int = 22,
        username: String = "",
        identityFile: String = "",
        group: String = "Development"
    ) {
        self.id = id
        self.name = name
        self.hostname = hostname
        self.port = port
        self.username = username
        self.identityFile = identityFile
        self.group = group
    }

    /// Build the `ssh` argument list for this host.
    var sshArguments: [String] {
        var args: [String] = []
        if port != 22 { args += ["-p", String(port)] }
        if !identityFile.isEmpty { args += ["-i", (identityFile as NSString).expandingTildeInPath] }
        // Keep the connection responsive and request a PTY.
        args += ["-t", "-o", "ServerAliveInterval=30"]
        let target = username.isEmpty ? hostname : "\(username)@\(hostname)"
        args.append(target)
        return args
    }

    var displayTarget: String {
        username.isEmpty ? hostname : "\(username)@\(hostname)"
    }

    /// Example hosts to populate the sidebar on first launch. Users edit or
    /// remove these in Settings ▸ SSH.
    static let seeds: [SSHHost] = [
        SSHHost(name: "Production Web", hostname: "prod.example.com", username: "deploy", group: "Production"),
        SSHHost(name: "Staging", hostname: "staging.example.com", username: "deploy", group: "Development"),
        SSHHost(name: "Test Runner", hostname: "ci.example.com", username: "runner", group: "Testing")
    ]
}
