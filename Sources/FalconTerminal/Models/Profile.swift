import Foundation

/// A reusable launch configuration: appearance + shell + startup command.
struct Profile: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var name: String
    var themeName: String
    var fontName: String
    var fontSize: Double
    var shellPath: String
    /// Optional command run automatically when a session with this profile
    /// starts (e.g. `kubectl get pods` or `claude`).
    var startupCommand: String

    init(
        id: UUID = UUID(),
        name: String,
        themeName: String = "Falcon Dark",
        fontName: String = "SFMono-Regular",
        fontSize: Double = 13,
        shellPath: String = Shell.defaultShell(),
        startupCommand: String = ""
    ) {
        self.id = id
        self.name = name
        self.themeName = themeName
        self.fontName = fontName
        self.fontSize = fontSize
        self.shellPath = shellPath
        self.startupCommand = startupCommand
    }

    static let defaultProfile = Profile(name: "Default")

    /// Seed profiles matching the product's named workflows.
    static let seeds: [Profile] = [
        Profile(name: "Development", themeName: "Falcon Dark"),
        Profile(name: "Production", themeName: "Tokyo Night"),
        Profile(name: "Docker", themeName: "Nord", startupCommand: "docker ps"),
        Profile(name: "Kubernetes", themeName: "Dracula", startupCommand: "kubectl get pods"),
        Profile(name: "AI", themeName: "Falcon Dark", startupCommand: "")
    ]
}
