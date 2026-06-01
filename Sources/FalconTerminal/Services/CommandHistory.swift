import Foundation

/// Persistent command history that powers inline autosuggestions. Stored in
/// our own file, seeded once from the user's existing `~/.zsh_history` /
/// `~/.bash_history` so suggestions are useful from the first launch.
@MainActor
final class CommandHistory {
    static let shared = CommandHistory()

    /// Most-recent-first list of unique commands.
    private(set) var entries: [String] = []
    private let maxEntries = 5_000

    private init() {
        if let saved = Store.shared.load([String].self, from: Store.Files.history) {
            entries = saved
        } else {
            entries = Self.seedFromShellHistory(limit: 2_000)
            persist()
        }
    }

    /// The completion suffix for `prefix`: the remainder of the most recent
    /// command that starts with `prefix`. Nil when there is no useful match.
    func suggestionSuffix(for prefix: String) -> String? {
        guard prefix.count >= 2 else { return nil }
        for entry in entries where entry.hasPrefix(prefix) && entry.count > prefix.count {
            return String(entry.dropFirst(prefix.count))
        }
        return nil
    }

    func record(_ rawCommand: String) {
        let command = rawCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard command.count >= 2 else { return }
        entries.removeAll { $0 == command }
        entries.insert(command, at: 0)
        if entries.count > maxEntries { entries.removeLast(entries.count - maxEntries) }
        persist()
    }

    private func persist() {
        let snapshot = entries
        DispatchQueue.global(qos: .utility).async {
            Store.shared.save(snapshot, to: Store.Files.history)
        }
    }

    // MARK: - Seeding

    private static func seedFromShellHistory(limit: Int) -> [String] {
        let home = NSHomeDirectory()
        var commands: [String] = []
        commands += parse(zshHistory: "\(home)/.zsh_history")
        commands += parsePlain("\(home)/.bash_history")

        // De-duplicate, keep order (these files are oldest-first), then take the
        // newest `limit` and present most-recent-first.
        var seen = Set<String>()
        var unique: [String] = []
        for cmd in commands where !cmd.isEmpty {
            if seen.insert(cmd).inserted { unique.append(cmd) }
        }
        return Array(unique.suffix(limit).reversed())
    }

    private static func parse(zshHistory path: String) -> [String] {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return [] }
        return content.split(separator: "\n").map { line -> String in
            // Extended history format: ": <timestamp>:<elapsed>;<command>"
            if line.hasPrefix(":"), let semicolon = line.firstIndex(of: ";") {
                return String(line[line.index(after: semicolon)...])
            }
            return String(line)
        }.map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private static func parsePlain(_ path: String) -> [String] {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return [] }
        return content.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
    }
}
