import Foundation
import Combine

/// Configuration for launching a session.
struct SessionConfig: Sendable {
    var executable: String
    var arguments: [String]
    var environment: [String: String]
    var workingDirectory: String
    var columns: Int
    var rows: Int

    static func login(
        shell: String = Shell.defaultShell(),
        columns: Int = 80,
        rows: Int = 24,
        workingDirectory: String = FileManager.default.homeDirectoryForCurrentUser.path,
        environment: [String: String] = Shell.makeEnvironment()
    ) -> SessionConfig {
        SessionConfig(
            executable: shell,
            arguments: Shell.loginArguments(for: shell),
            environment: environment,
            workingDirectory: workingDirectory,
            columns: columns,
            rows: rows
        )
    }
}

/// Owns a single terminal: PTY + parser + emulator. Bytes from the shell flow
/// through the parser into the emulator on a serial queue; coalesced snapshots
/// are published to the renderer at frame cadence.
///
/// The type is `@MainActor` so `@Published` UI state is updated safely. The
/// emulator/parser/PTY are `nonisolated(unsafe)` because they are only ever
/// touched from the serial `queue`, which provides the synchronization.
@MainActor
final class TerminalSession: ObservableObject, Identifiable {
    nonisolated let id = UUID()

    @Published var title: String = "Terminal"
    @Published var hasExited = false

    nonisolated(unsafe) private let emulator: TerminalEmulator
    nonisolated(unsafe) private let parser: Parser
    nonisolated(unsafe) private let pty = PTY()
    nonisolated private let queue = DispatchQueue(label: "falcon.session")

    nonisolated(unsafe) private var viewportOffset = 0
    nonisolated(unsafe) private var renderScheduled = false
    nonisolated private let frameInterval = 1.0 / 60.0

    /// Delivered on the main thread with each coalesced frame.
    var onSnapshot: (@MainActor (TerminalSnapshot) -> Void)?
    var onBell: (@MainActor () -> Void)?

    nonisolated(unsafe) private var _columns: Int
    nonisolated(unsafe) private var _rows: Int

    init(columns: Int = 80, rows: Int = 24) {
        _columns = columns
        _rows = rows
        emulator = TerminalEmulator(rows: rows, columns: columns)
        parser = Parser(performer: emulator)

        emulator.onTitleChange = { [weak self] newTitle in
            DispatchQueue.main.async {
                self?.title = newTitle.isEmpty ? "Terminal" : newTitle
            }
        }
        emulator.onBell = { [weak self] in
            DispatchQueue.main.async { self?.onBell?() }
        }
        emulator.onRespond = { [weak self] response in
            self?.pty.write(response)
        }
    }

    // MARK: - Lifecycle

    func start(config: SessionConfig) {
        queue.sync {
            _columns = config.columns
            _rows = config.rows
            emulator.resize(rows: config.rows, columns: config.columns)
        }

        pty.onData = { [weak self] data in
            self?.queue.async {
                guard let self else { return }
                self.parser.feed(data)
                self.scheduleRender()
            }
        }
        pty.onExit = { [weak self] _ in
            DispatchQueue.main.async { self?.hasExited = true }
        }

        do {
            try pty.start(
                executable: config.executable,
                arguments: config.arguments,
                environment: config.environment,
                workingDirectory: config.workingDirectory,
                columns: config.columns,
                rows: config.rows
            )
        } catch {
            let msg = "Failed to launch \(config.executable): \(error)\r\n"
            queue.async {
                self.parser.feed(Array(msg.utf8))
                self.scheduleRender()
            }
        }
    }

    func terminate() {
        pty.terminate()
    }

    // MARK: - Input

    func send(_ string: String) {
        snapToBottom()
        pty.write(string)
    }

    func send(_ data: Data) {
        snapToBottom()
        pty.write(data)
    }

    /// Paste text, wrapping in bracketed-paste markers if the app enabled it.
    func paste(_ text: String) {
        snapToBottom()
        let bracketed = queue.sync { emulator.bracketedPasteEnabled }
        if bracketed {
            pty.write("\u{1b}[200~" + text + "\u{1b}[201~")
        } else {
            pty.write(text)
        }
    }

    private func snapToBottom() {
        queue.async {
            if self.viewportOffset != 0 {
                self.viewportOffset = 0
                self.scheduleRender()
            }
        }
    }

    // MARK: - Resize

    func resize(columns: Int, rows: Int) {
        guard columns > 0, rows > 0 else { return }
        queue.async {
            guard columns != self._columns || rows != self._rows else { return }
            self._columns = columns
            self._rows = rows
            self.emulator.resize(rows: rows, columns: columns)
            self.pty.resize(columns: columns, rows: rows)
            self.scheduleRender()
        }
    }

    // MARK: - Scrollback

    func scrollBy(lines delta: Int) {
        queue.async {
            let maxOffset = self.emulator.scrollbackCount
            let newOffset = max(0, min(self.viewportOffset + delta, maxOffset))
            guard newOffset != self.viewportOffset else { return }
            self.viewportOffset = newOffset
            self.scheduleRender()
        }
    }

    func scrollToBottom() {
        queue.async {
            guard self.viewportOffset != 0 else { return }
            self.viewportOffset = 0
            self.scheduleRender()
        }
    }

    var applicationCursorKeys: Bool {
        queue.sync { emulator.applicationCursorKeysEnabled }
    }

    /// Synchronous plain-text extraction of the whole buffer (for select-all).
    func allText() -> String {
        queue.sync { emulator.allText() }
    }

    /// The shell's current working directory, if available.
    func currentDirectory() -> String? {
        pty.currentDirectory()
    }

    // MARK: - Rendering

    nonisolated private func scheduleRender() {
        guard !renderScheduled else { return }
        renderScheduled = true
        queue.asyncAfter(deadline: .now() + frameInterval) { [weak self] in
            guard let self else { return }
            self.renderScheduled = false
            let snapshot = self.emulator.makeSnapshot(viewportOffset: self.viewportOffset)
            DispatchQueue.main.async { self.onSnapshot?(snapshot) }
        }
    }

    /// Force an immediate snapshot (used right after a view appears/resizes).
    func requestRender() { queue.async { self.scheduleRender() } }
}
