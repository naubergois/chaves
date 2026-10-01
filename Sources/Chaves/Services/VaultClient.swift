import Foundation

enum VaultError: LocalizedError {
    case pythonNotFound
    case packageMissing
    case commandFailed(String)
    case decodeFailed

    var errorDescription: String? {
        switch self {
        case .pythonNotFound:
            return "Python 3 não encontrado. Instale o Xcode CLT ou o venv do QClaw."
        case .packageMissing:
            return "Pacote python/chaves não encontrado ao lado do app."
        case .commandFailed(let detail):
            return detail
        case .decodeFailed:
            return "A resposta do cofre não veio como JSON."
        }
    }
}

enum PythonRuntime {
    static var home: URL { FileManager.default.homeDirectoryForCurrentUser }

    static func pythonExecutable() -> String? {
        if let override = ProcessInfo.processInfo.environment["CHAVES_PYTHON"],
           FileManager.default.isExecutableFile(atPath: override) {
            return override
        }
        let candidates = [
            home.appendingPathComponent("qclawmonitor/.venv/bin/python").path,
            "/Users/naubergois/qclawmonitor/.venv/bin/python",
            "/Volumes/NAUBER/qclawmonitor/.venv/bin/python",
            "/opt/homebrew/bin/python3",
            "/usr/bin/python3",
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
            ?? ProcessRunner.locate("python3")
    }

    static func packageRoot() -> URL? {
        if let override = ProcessInfo.processInfo.environment["CHAVES_PYTHON_ROOT"] {
            let url = URL(fileURLWithPath: override)
            if FileManager.default.fileExists(atPath: url.appendingPathComponent("chaves").path) {
                return url
            }
        }
        let bundle = Bundle.main.resourceURL?.appendingPathComponent("python")
        if let bundle, FileManager.default.fileExists(atPath: bundle.appendingPathComponent("chaves").path) {
            return bundle
        }
        let file = URL(fileURLWithPath: #filePath)
        let repoPython = file
            .deletingLastPathComponent() // Services
            .deletingLastPathComponent() // Chaves
            .deletingLastPathComponent() // Sources
            .deletingLastPathComponent() // repo
            .appendingPathComponent("python")
        if FileManager.default.fileExists(atPath: repoPython.appendingPathComponent("chaves").path) {
            return repoPython
        }
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("python")
        if FileManager.default.fileExists(atPath: cwd.appendingPathComponent("chaves").path) {
            return cwd
        }
        return nil
    }

    static func pythonPath(packageRoot: URL) -> String {
        var parts = [packageRoot.path]
        var qclaw = [
            home.appendingPathComponent("qclawmonitor").path,
            "/Users/naubergois/qclawmonitor",
            "/Volumes/NAUBER/qclawmonitor",
        ]
        if let override = ProcessInfo.processInfo.environment["CHAVES_QCLAW_ROOT"], !override.isEmpty {
            qclaw.insert(override, at: 0)
        }
        for root in qclaw {
            let src = URL(fileURLWithPath: root).appendingPathComponent("src").path
            if FileManager.default.fileExists(atPath: src) {
                parts.append(src)
                break
            }
        }
        return parts.joined(separator: ":")
    }

    static func run(_ arguments: [String], timeout: TimeInterval = 90) throws -> Data {
        guard let python = pythonExecutable() else { throw VaultError.pythonNotFound }
        guard let root = packageRoot() else { throw VaultError.packageMissing }
        var env = ProcessInfo.processInfo.environment
        env["PYTHONPATH"] = pythonPath(packageRoot: root)
        env["PYTHONUNBUFFERED"] = "1"
        env["PYTHONDONTWRITEBYTECODE"] = "1"
        let result = try ProcessRunner.run(
            executable: python,
            arguments: ["-m", "chaves"] + arguments,
            environment: env,
            currentDirectory: root.path,
            timeout: timeout
        )
        let output = result.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        if output.isEmpty {
            let err = result.standardError.trimmingCharacters(in: .whitespacesAndNewlines)
            throw VaultError.commandFailed(err.isEmpty ? "comando sem saída" : err)
        }
        guard let data = output.data(using: .utf8) else { throw VaultError.decodeFailed }
        return data
    }
}

enum VaultClient {
    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        return decoder
    }()

    static func list(credits: Bool = true, refresh: Bool = false) throws -> VaultPayload {
        var args = ["list"]
        if credits { args.append("--credits") }
        if refresh { args.append("--refresh") }
        return try decode(VaultPayload.self, arguments: args, timeout: refresh ? 90 : 20)
    }

    static func status() throws -> ServiceStatus {
        try decode(ServiceStatus.self, arguments: ["status"], timeout: 15)
    }

    static func refreshCredits(providers: [String] = []) throws -> CreditsPayload {
        var args = ["credits"]
        for provider in providers { args += ["--provider", provider] }
        return try decode(CreditsPayload.self, arguments: args, timeout: 90)
    }

    static func upsert(name: String, value: String) throws -> MutationResult {
        try decode(MutationResult.self, arguments: ["upsert", "--name", name, "--value", value], timeout: 20)
    }

    static func delete(name: String) throws -> MutationResult {
        try decode(MutationResult.self, arguments: ["delete", "--name", name], timeout: 20)
    }

    private static func decode<T: Decodable>(_ type: T.Type, arguments: [String], timeout: TimeInterval) throws -> T {
        let data = try PythonRuntime.run(arguments, timeout: timeout)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = object["error"] as? String {
                throw VaultError.commandFailed(message)
            }
            throw VaultError.decodeFailed
        }
    }
}
