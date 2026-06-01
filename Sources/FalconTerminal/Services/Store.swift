import Foundation

/// JSON-file persistence under Application Support. Each kind of data lives in
/// its own file so a corrupt one never takes the others down.
final class Store: @unchecked Sendable {
    static let shared = Store()

    private let directory: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        directory = base.appendingPathComponent("FalconTerminal", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder = JSONDecoder()
    }

    private func url(_ file: String) -> URL {
        directory.appendingPathComponent(file)
    }

    func load<T: Decodable>(_ type: T.Type, from file: String) -> T? {
        guard let data = try? Data(contentsOf: url(file)) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    func save<T: Encodable>(_ value: T, to file: String) {
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: url(file), options: .atomic)
    }

    func delete(_ file: String) {
        try? FileManager.default.removeItem(at: url(file))
    }

    // Well-known file names.
    enum Files {
        static let settings = "settings.json"
        static let profiles = "profiles.json"
        static let sshHosts = "ssh_hosts.json"
        static let session = "session_state.json"
        static let history = "command_history.json"
    }
}
