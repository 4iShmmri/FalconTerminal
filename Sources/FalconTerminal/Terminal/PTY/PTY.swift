import Foundation
import Darwin

/// A real pseudo-terminal. Spawns a child process attached to a PTY slave via
/// `forkpty`, exposes the master fd for I/O, and surfaces data / exit events.
///
/// Reading happens on a dedicated `DispatchSource` so the UI never blocks on
/// shell output; writes go straight to the master fd.
final class PTY {
    private(set) var masterFD: Int32 = -1
    private(set) var childPID: pid_t = -1
    private var readSource: DispatchSourceRead?
    private var processSource: DispatchSourceProcess?
    private let ioQueue = DispatchQueue(label: "falcon.pty.io")

    /// Called with raw output bytes from the shell (on `ioQueue`).
    var onData: ((Data) -> Void)?
    /// Called when the child process exits (on `ioQueue`).
    var onExit: ((Int32) -> Void)?

    private(set) var isRunning = false

    deinit { terminate() }

    struct LaunchError: Error { let message: String }

    /// Launch `executable` with `arguments` inside a fresh PTY.
    func start(
        executable: String,
        arguments: [String],
        environment: [String: String],
        workingDirectory: String,
        columns: Int,
        rows: Int
    ) throws {
        var size = winsize(
            ws_row: UInt16(max(1, rows)),
            ws_col: UInt16(max(1, columns)),
            ws_xpixel: 0,
            ws_ypixel: 0
        )

        var master: Int32 = -1
        let argv = makeCArray([executable] + arguments)
        let envp = makeCArray(environment.map { "\($0.key)=\($0.value)" })
        defer {
            freeCArray(argv)
            freeCArray(envp)
        }

        let pid = forkpty(&master, nil, nil, &size)
        if pid < 0 {
            throw LaunchError(message: "forkpty failed: \(String(cString: strerror(errno)))")
        }

        if pid == 0 {
            // Child: only async-signal-safe work before exec.
            workingDirectory.withCString { _ = chdir($0) }
            _ = execve(executable, argv, envp)
            // exec failed.
            _exit(127)
        }

        // Parent.
        masterFD = master
        childPID = pid
        isRunning = true
        configureNonBlocking(master)
        startReading()
        startExitMonitor()
    }

    private func configureNonBlocking(_ fd: Int32) {
        let flags = fcntl(fd, F_GETFL, 0)
        _ = fcntl(fd, F_SETFL, flags | O_NONBLOCK)
    }

    private func startReading() {
        let source = DispatchSource.makeReadSource(fileDescriptor: masterFD, queue: ioQueue)
        source.setEventHandler { [weak self] in
            guard let self else { return }
            var buffer = [UInt8](repeating: 0, count: 65_536)
            let n = buffer.withUnsafeMutableBytes { ptr in
                read(self.masterFD, ptr.baseAddress, ptr.count)
            }
            if n > 0 {
                self.onData?(Data(buffer[0..<n]))
            } else if n == 0 {
                self.handleEOF()
            } else if errno != EAGAIN && errno != EINTR {
                self.handleEOF()
            }
        }
        readSource = source
        source.resume()
    }

    private func startExitMonitor() {
        let source = DispatchSource.makeProcessSource(identifier: childPID, eventMask: .exit, queue: ioQueue)
        source.setEventHandler { [weak self] in
            guard let self else { return }
            var status: Int32 = 0
            waitpid(self.childPID, &status, WNOHANG)
            let code = (status & 0x7f) == 0 ? (status >> 8) & 0xff : 128 + (status & 0x7f)
            self.isRunning = false
            self.onExit?(code)
            self.processSource?.cancel()
        }
        processSource = source
        source.resume()
    }

    private func handleEOF() {
        guard isRunning else { return }
        isRunning = false
        readSource?.cancel()
        onExit?(0)
    }

    // MARK: - I/O

    func write(_ data: Data) {
        guard masterFD >= 0 else { return }
        ioQueue.async { [masterFD] in
            data.withUnsafeBytes { raw in
                var offset = 0
                let base = raw.bindMemory(to: UInt8.self).baseAddress!
                while offset < data.count {
                    let n = Darwin.write(masterFD, base + offset, data.count - offset)
                    if n > 0 { offset += n }
                    else if n < 0 && (errno == EAGAIN || errno == EINTR) { continue }
                    else { break }
                }
            }
        }
    }

    func write(_ string: String) {
        write(Data(string.utf8))
    }

    func resize(columns: Int, rows: Int) {
        guard masterFD >= 0 else { return }
        var size = winsize(
            ws_row: UInt16(max(1, rows)),
            ws_col: UInt16(max(1, columns)),
            ws_xpixel: 0,
            ws_ypixel: 0
        )
        _ = ioctl(masterFD, TIOCSWINSZ, &size)
    }

    /// The child shell's current working directory, queried straight from the
    /// kernel — no shell integration / OSC 7 required.
    func currentDirectory() -> String? {
        guard childPID > 0 else { return nil }
        var info = proc_vnodepathinfo()
        let size = Int32(MemoryLayout<proc_vnodepathinfo>.size)
        let result = proc_pidinfo(childPID, PROC_PIDVNODEPATHINFO, 0, &info, size)
        guard result == size else { return nil }
        let path = withUnsafeBytes(of: &info.pvi_cdir.vip_path) { raw -> String in
            raw.baseAddress!.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) {
                String(cString: $0)
            }
        }
        return path.isEmpty ? nil : path
    }

    func terminate() {
        guard isRunning else { return }
        isRunning = false
        if childPID > 0 { kill(childPID, SIGHUP) }
        readSource?.cancel()
        processSource?.cancel()
        if masterFD >= 0 { close(masterFD); masterFD = -1 }
    }
}

// MARK: - C array helpers

private func makeCArray(_ values: [String]) -> UnsafeMutablePointer<UnsafeMutablePointer<CChar>?> {
    let array = UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>.allocate(capacity: values.count + 1)
    for (i, value) in values.enumerated() {
        array[i] = strdup(value)
    }
    array[values.count] = nil
    return array
}

private func freeCArray(_ array: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) {
    var i = 0
    while let ptr = array[i] {
        free(ptr)
        i += 1
    }
    array.deallocate()
}
