import Foundation

enum MCPError: LocalizedError {
    case invalidArgument(String)
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .invalidArgument(let detail): return detail
        case .failed(let detail): return detail
        }
    }
}

/// Servidor MCP (JSON-RPC 2.0 sobre stdio). Mesmo cofre da janela do app.
final class MCPServer {
    static let serverName = "chaves"
    static let serverVersion = "1.0.0"
    static let defaultProtocolVersion = "2025-06-18"
    static let supportedProtocolVersions: Set<String> = ["2024-11-05", "2025-03-26", "2025-06-18"]

    private let tools: [MCPTool]
    private let output = FileHandle.standardOutput

    init(tools: [MCPTool] = MCPToolCatalog.all()) {
        self.tools = tools
    }

    func run() {
        log("servidor MCP pronto (\(tools.count) ferramentas)")
        while let line = readLine(strippingNewline: true) {
            guard !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            handle(line: line)
        }
        log("stdin encerrado")
    }

    private func handle(line: String) {
        guard let data = line.data(using: .utf8),
              let message = try? JSONSerialization.jsonObject(with: data) else {
            send(errorFor: NSNull(), code: -32700, message: "JSON inválido")
            return
        }
        if let batch = message as? [[String: Any]] {
            batch.forEach { handle(message: $0) }
        } else if let single = message as? [String: Any] {
            handle(message: single)
        } else {
            send(errorFor: NSNull(), code: -32600, message: "Requisição inválida")
        }
    }

    private func handle(message: [String: Any]) {
        guard let method = message["method"] as? String else { return }
        let id = message["id"]
        let params = message["params"] as? [String: Any] ?? [:]
        let isNotification = id == nil

        switch method {
        case "initialize":
            send(result: initializeResult(params: params), id: id)
        case "notifications/initialized", "notifications/cancelled", "notifications/progress":
            break
        case "ping":
            if !isNotification { send(result: [:], id: id) }
        case "tools/list":
            send(result: ["tools": tools.map(\.descriptor)], id: id)
        case "tools/call":
            guard !isNotification else { return }
            send(result: callTool(params: params), id: id)
        case "resources/list":
            send(result: ["resources": []], id: id)
        case "resources/templates/list":
            send(result: ["resourceTemplates": []], id: id)
        case "prompts/list":
            send(result: ["prompts": []], id: id)
        case "logging/setLevel":
            if !isNotification { send(result: [:], id: id) }
        default:
            if !isNotification {
                send(errorFor: id, code: -32601, message: "Método não suportado: \(method)")
            }
        }
    }

    private func initializeResult(params: [String: Any]) -> [String: Any] {
        let requested = params["protocolVersion"] as? String
        let version = requested.flatMap { Self.supportedProtocolVersions.contains($0) ? $0 : nil }
            ?? Self.defaultProtocolVersion
        return [
            "protocolVersion": version,
            "capabilities": ["tools": ["listChanged": false]],
            "serverInfo": ["name": Self.serverName, "version": Self.serverVersion],
            "instructions": """
            Cofre de chaves API e créditos. Mesmo Mongo env_keys do QClaw.

            Use `list_keys` para ver o que está configurado (valores mascarados) \
            e o último saldo conhecido. `refresh_credits` sonda os provedores agora. \
            `upsert_key` grava uma variável. O valor completo nunca volta nas tools.
            """,
        ]
    }

    private func callTool(params: [String: Any]) -> [String: Any] {
        guard let name = params["name"] as? String else {
            return Self.toolResult(text: "Parâmetro 'name' ausente.", isError: true)
        }
        guard let tool = tools.first(where: { $0.name == name }) else {
            return Self.toolResult(text: "Ferramenta desconhecida: \(name)", isError: true)
        }
        let arguments = params["arguments"] as? [String: Any] ?? [:]
        do {
            let payload = try tool.handler(arguments)
            return Self.toolResult(text: Self.jsonText(payload))
        } catch {
            log("falha em \(name): \(error.localizedDescription)")
            return Self.toolResult(text: error.localizedDescription, isError: true)
        }
    }

    static func toolResult(text: String, isError: Bool = false) -> [String: Any] {
        [
            "content": [["type": "text", "text": text]],
            "isError": isError,
        ]
    }

    static func jsonText(_ payload: Any) -> String {
        if let text = payload as? String { return text }
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(
                  withJSONObject: payload,
                  options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]),
              let text = String(data: data, encoding: .utf8)
        else { return String(describing: payload) }
        return text
    }

    private func send(result: Any, id: Any?) {
        var message: [String: Any] = ["jsonrpc": "2.0", "result": result]
        message["id"] = id ?? NSNull()
        write(message)
    }

    private func send(errorFor id: Any?, code: Int, message text: String) {
        var message: [String: Any] = [
            "jsonrpc": "2.0",
            "error": ["code": code, "message": text],
        ]
        message["id"] = id ?? NSNull()
        write(message)
    }

    private func write(_ message: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: message,
                                                     options: [.withoutEscapingSlashes]) else { return }
        var line = data
        line.append(0x0A)
        output.write(line)
    }

    private func log(_ text: String) {
        FileHandle.standardError.write(Data("[chaves-mcp] \(text)\n".utf8))
    }
}
