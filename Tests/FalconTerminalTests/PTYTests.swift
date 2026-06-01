import Testing
import Foundation
@testable import FalconTerminal

struct PTYTests {
    @Test("PTY runs a command and streams its output")
    func runsCommand() throws {
        let pty = PTY()
        let collected = OutputCollector()
        let done = DispatchSemaphore(value: 0)

        pty.onData = { data in collected.append(data) }
        pty.onExit = { _ in done.signal() }

        try pty.start(
            executable: "/bin/sh",
            arguments: ["-c", "printf 'falcon-pty-ok'"],
            environment: Shell.makeEnvironment(),
            workingDirectory: FileManager.default.currentDirectoryPath,
            columns: 80,
            rows: 24
        )

        let result = done.wait(timeout: .now() + 5)
        #expect(result == .success)
        // Give the read source a beat to drain any final bytes.
        Thread.sleep(forTimeInterval: 0.15)
        #expect(collected.string.contains("falcon-pty-ok"))
    }

    @Test("PTY reports the requested window size to the child")
    func windowSize() throws {
        let pty = PTY()
        let collected = OutputCollector()
        let done = DispatchSemaphore(value: 0)
        pty.onData = { collected.append($0) }
        pty.onExit = { _ in done.signal() }

        try pty.start(
            executable: "/bin/sh",
            arguments: ["-c", "stty size"],
            environment: Shell.makeEnvironment(),
            workingDirectory: FileManager.default.currentDirectoryPath,
            columns: 100,
            rows: 30
        )

        _ = done.wait(timeout: .now() + 5)
        Thread.sleep(forTimeInterval: 0.15)
        // `stty size` prints "rows cols".
        #expect(collected.string.contains("30 100"))
    }
}

/// Thread-safe accumulator for PTY output in tests.
final class OutputCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func append(_ chunk: Data) {
        lock.lock(); data.append(chunk); lock.unlock()
    }

    var string: String {
        lock.lock(); defer { lock.unlock() }
        return String(decoding: data, as: UTF8.self)
    }
}
