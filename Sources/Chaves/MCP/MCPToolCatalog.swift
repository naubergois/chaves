import Foundation

struct MCPTool {
    var name: String
    var description: String
    var inputSchema: [String: Any]
    var handler: ([String: Any]) throws -> Any

    var descriptor: [String: Any] {
        ["name": name, "description": description, "inputSchema": inputSchema]
    }
}

enum MCPToolCatalog {
    static func all() -> [MCPTool] {
        [listKeys, getKey, refreshCredits, upsertKey, deleteKey, serviceStatus]
    }

    static let listKeys = MCPTool(
        name: "list_keys",
        description: """
        Lista as chaves API do cofre (Mongo env_keys), com valor mascarado e \
        último saldo conhecido. Nunca devolve o secret completo. Use antes de \
        gerar vídeo, imagem ou lote caro, e quando o utilizador perguntar \
        quais chaves estão configuradas.
        """,
        inputSchema: object(properties: [
            "configured_only": ["type": "boolean", "description": "Só as que já estão no cofre. Padrão: false."],
            "category": ["type": "string", "description": "llm, media, voice, aws, other, …"],
            "refresh": ["type": "boolean", "description": "Sondar créditos agora (mais lento). Padrão: false."],
        ]),
        handler: { arguments in
            let refresh = boolean(arguments["refresh"]) ?? false
            var payload = try VaultClient.list(credits: true, refresh: refresh)
            if boolean(arguments["configured_only"]) == true {
                payload.keys = payload.keys.filter(\.configured)
            }
            if let category = stringOptional(arguments["category"]) {
                payload.keys = payload.keys.filter { $0.category == category }
            }
            return try dictionary(from: payload)
        }
    )

    static let getKey = MCPTool(
        name: "get_key",
        description: "Estado de uma variável: configurada, mascarada, categoria e crédito. Sem o valor completo.",
        inputSchema: object(
            properties: [
                "name": ["type": "string", "description": "Ex.: HEYGEN_API_KEY, OPENAI_API_KEY."],
            ],
            required: ["name"]
        ),
        handler: { arguments in
            let name = try requiredString(arguments["name"], field: "name").uppercased()
            let payload = try VaultClient.list(credits: true, refresh: false)
            guard let key = payload.keys.first(where: { $0.name == name }) else {
                throw MCPError.invalidArgument("chave não encontrada: \(name)")
            }
            return try dictionary(from: key)
        }
    )

    static let refreshCredits = MCPTool(
        name: "refresh_credits",
        description: """
        Sonda o saldo/cota dos provedores (OpenRouter, HeyGen, ElevenLabs, \
        DeepSeek, Gamma, Stability, Grok, OpenAI, CivitAI, Replicate, fal). \
        Use quando o utilizador pedir créditos, saldo ou quanto resta.
        """,
        inputSchema: object(properties: [
            "provider": ["type": "string", "description": "Filtrar: openrouter, heygen, elevenlabs, …"],
        ]),
        handler: { arguments in
            var providers: [String] = []
            if let provider = stringOptional(arguments["provider"]) {
                providers = [provider]
            }
            let credits = try VaultClient.refreshCredits(providers: providers)
            return try dictionary(from: credits)
        }
    )

    static let upsertKey = MCPTool(
        name: "upsert_key",
        description: "Grava ou atualiza uma variável no Mongo env_keys. O valor completo não volta na resposta.",
        inputSchema: object(
            properties: [
                "name": ["type": "string", "description": "Nome da variável (OPENAI_API_KEY)."],
                "value": ["type": "string", "description": "Valor completo. Não será ecoado."],
            ],
            required: ["name", "value"]
        ),
        handler: { arguments in
            let name = try requiredString(arguments["name"], field: "name")
            let value = try requiredString(arguments["value"], field: "value")
            let result = try VaultClient.upsert(name: name, value: value)
            if !result.ok {
                throw MCPError.failed(result.error ?? "não gravou")
            }
            return [
                "ok": true,
                "name": result.name ?? name.uppercased(),
                "masked": result.masked ?? "",
            ]
        }
    )

    static let deleteKey = MCPTool(
        name: "delete_key",
        description: "Remove uma variável do cofre Mongo.",
        inputSchema: object(
            properties: ["name": ["type": "string"]],
            required: ["name"]
        ),
        handler: { arguments in
            let name = try requiredString(arguments["name"], field: "name")
            let result = try VaultClient.delete(name: name)
            if !result.ok {
                throw MCPError.failed(result.error ?? "não apagou")
            }
            return ["ok": true, "deleted": result.deleted ?? [name]]
        }
    )

    static let serviceStatus = MCPTool(
        name: "service_status",
        description: "Saúde do cofre: Mongo no ar, quantas chaves, raiz do QClaw.",
        inputSchema: object(properties: [:]),
        handler: { _ in
            try dictionary(from: VaultClient.status())
        }
    )

    static func object(properties: [String: Any], required: [String] = []) -> [String: Any] {
        var schema: [String: Any] = ["type": "object", "properties": properties]
        if !required.isEmpty { schema["required"] = required }
        return schema
    }

    static func requiredString(_ value: Any?, field: String) throws -> String {
        guard let text = value as? String,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MCPError.invalidArgument("'\(field)' é obrigatório.")
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func stringOptional(_ value: Any?) -> String? {
        guard let text = value as? String else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func boolean(_ value: Any?) -> Bool? {
        if let flag = value as? Bool { return flag }
        if let number = value as? NSNumber { return number.boolValue }
        if let text = value as? String {
            switch text.lowercased() {
            case "true", "1", "sim", "yes": return true
            case "false", "0", "nao", "não", "no": return false
            default: return nil
            }
        }
        return nil
    }

    static func dictionary<T: Encodable>(from value: T) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw MCPError.failed("falha ao serializar")
        }
        return object
    }
}
