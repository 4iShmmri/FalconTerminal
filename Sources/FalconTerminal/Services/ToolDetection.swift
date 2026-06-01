import Foundation

/// Lightweight PATH lookups so the UI can show which external CLIs are present
/// (AI tools, Docker, kubectl). Results are cached for the session.
enum ToolDetection {
    nonisolated(unsafe) private static var cache: [String: Bool] = [:]
    private static let lock = NSLock()

    static func isInstalled(_ tool: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        if let cached = cache[tool] { return cached }
        let found = resolve(tool) != nil
        cache[tool] = found
        return found
    }

    /// Absolute path to the executable if found on a typical PATH.
    static func resolve(_ tool: String) -> String? {
        let searchPaths = candidatePaths()
        for dir in searchPaths {
            let full = (dir as NSString).appendingPathComponent(tool)
            if FileManager.default.isExecutableFile(atPath: full) { return full }
        }
        return nil
    }

    private static func candidatePaths() -> [String] {
        var paths = ProcessInfo.processInfo.environment["PATH"]?.split(separator: ":").map(String.init) ?? []
        // Common GUI-launch PATH gaps.
        paths += [
            "/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin",
            "\(NSHomeDirectory())/.local/bin", "\(NSHomeDirectory())/.cargo/bin",
            "/usr/local/go/bin"
        ]
        return Array(NSOrderedSet(array: paths)) as? [String] ?? paths
    }

    static var dockerAvailable: Bool { isInstalled("docker") }
    static var kubectlAvailable: Bool { isInstalled("kubectl") }
}
