import Foundation

struct ProcessResult {
    var exitCode: Int32
    var standardOutput: String
    var standardError: String

    var succeeded: Bool { exitCode == 0 }
}

enum ProcessRunnerError: LocalizedError {
    case executableNotFound(String)
    case timedOut(String, TimeInterval)

    var errorDescription: String? {
        switch self {
        case .executableNotFound(let path):
            return "Executável não encontrado: \(path)"
        case .timedOut(let path, let seconds):
            return "Tempo esgotado (\(Int(seconds))s) ao executar \(path)"
        }
    }
}

enum ProcessRunner {
    static func run(executable: String,
                    arguments: [String],
                    environment: [String: String]? = nil,
                    currentDirectory: String? = nil,
                    timeout: TimeInterval = 90) throws -> ProcessResult {
        guard FileManager.default.isExecutableFile(atPath: executable) else {
            throw ProcessRunnerError.executableNotFound(executable)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        if let currentDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: currentDirectory)
        }
        var env = ProcessInfo.processInfo.environment
        environment?.forEach { env[$0.key] = $0.value }
        process.environment = env

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        let buffer = OutputBuffer()
        outPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty { buffer.appendOut(data) }
        }
        errPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty { buffer.appendErr(data) }
        }

        try process.run()

        var timedOut = false
        let deadline = DispatchWorkItem {
            if process.isRunning {
                timedOut = true
                process.terminate()
            }
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: deadline)
        process.waitUntilExit()
        deadline.cancel()

        outPipe.fileHandleForReading.readabilityHandler = nil
        errPipe.fileHandleForReading.readabilityHandler = nil
        buffer.appendOut(outPipe.fileHandleForReading.availableData)
        buffer.appendErr(errPipe.fileHandleForReading.availableData)

        if timedOut {
            throw ProcessRunnerError.timedOut(executable, timeout)
        }

        return ProcessResult(exitCode: process.terminationStatus,
                             standardOutput: buffer.outString,
                             standardError: buffer.errString)
    }

    static func locate(_ binary: String) -> String? {
        let candidates = [
            "/opt/homebrew/bin/\(binary)",
            "/usr/local/bin/\(binary)",
            "/usr/bin/\(binary)",
            "/bin/\(binary)",
        ]
        for candidate in candidates where FileManager.default.isExecutableFile(atPath: candidate) {
            return candidate
        }
        return nil
    }
}

private final class OutputBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var out = Data()
    private var err = Data()

    func appendOut(_ data: Data) {
        guard !data.isEmpty else { return }
        lock.lock(); out.append(data); lock.unlock()
    }

    func appendErr(_ data: Data) {
        guard !data.isEmpty else { return }
        lock.lock(); err.append(data); lock.unlock()
    }

    var outString: String {
        lock.lock(); defer { lock.unlock() }
        return String(data: out, encoding: .utf8) ?? ""
    }

    var errString: String {
        lock.lock(); defer { lock.unlock() }
        return String(data: err, encoding: .utf8) ?? ""
    }
}
