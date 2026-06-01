import Foundation

/// Detects the user's login shell and builds the launch environment a real
/// terminal must provide (TERM, COLORTERM, LANG, etc.).
enum Shell {
    /// The user's preferred shell, honoring `$SHELL` then `getpwuid`, with a
    /// zsh → bash → sh fallback chain.
    static func defaultShell() -> String {
        if let env = ProcessInfo.processInfo.environment["SHELL"],
           FileManager.default.isExecutableFile(atPath: env) {
            return env
        }
        if let pw = getpwuid(getuid()), let shellPtr = pw.pointee.pw_shell {
            let path = String(cString: shellPtr)
            if !path.isEmpty, FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        for candidate in ["/bin/zsh", "/bin/bash", "/bin/sh"] {
            if FileManager.default.isExecutableFile(atPath: candidate) { return candidate }
        }
        return "/bin/sh"
    }

    static func displayName(for path: String) -> String {
        (path as NSString).lastPathComponent
    }

    /// Login-shell argv. A leading `-` makes the shell read login profiles,
    /// matching how Terminal.app and iTerm2 launch shells.
    static func loginArguments(for shellPath: String) -> [String] {
        ["-l"]
    }

    /// Build the child environment: inherit the parent's, then set the
    /// terminal-specific variables a modern terminal advertises.
    static func makeEnvironment(
        termType: String = "xterm-256color",
        extra: [String: String] = [:]
    ) -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        env["TERM"] = termType
        env["COLORTERM"] = "truecolor"
        env["TERM_PROGRAM"] = "FalconTerminal"
        env["TERM_PROGRAM_VERSION"] = "1.0"
        if env["LANG"] == nil { env["LANG"] = "en_US.UTF-8" }
        env["LC_TERMINAL"] = "FalconTerminal"
        // Remove variables that would confuse a fresh session.
        env.removeValue(forKey: "TERMCAP")
        for (k, v) in extra { env[k] = v }
        return env
    }
}
