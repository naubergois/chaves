# Chaves

Cada provedor que o Cursor e o QClaw usam mora num único cofre. A janela mostra o que está gravado, o pedaço visível da chave e o saldo — quando o provedor publica esse número.

O Mongo é o mesmo `env_keys` do painel `/chaves`. Nada aqui inventa um segundo lugar para secret.

## O que aparece

A lista cobre modelos (OpenAI, DeepSeek, Grok, OpenRouter), imagem e vídeo (HeyGen, fal, Replicate, Kling), voz (ElevenLabs, Suno) e o restante das variáveis do catálogo. O miolo do secret some. O crédito vem de uma sonda HTTP; se o provedor não tiver API de saldo, a linha diz isso sem fingir um número.

O mesmo binário atende os outros serviços: `Chaves --mcp` fala JSON-RPC em stdio. `list_keys`, `refresh_credits` e `upsert_key` são a porta que o Cursor e o restante dos MCPs usam.

## Requisitos

| Item | Detalhe |
|---|---|
| macOS | 13 ou superior |
| Swift | 5.9+ |
| Python 3 | o venv do QClaw (`~/qclawmonitor/.venv`) ou `python3` do sistema |
| Mongo | o `env_keys` do QClaw, em geral `mongodb://localhost:27017` / banco `gois` |

## Instalação

```bash
cd ~/chaves
make test
make app
make install
make mcp-install-cursor
```

Depois, `/Applications/Chaves.app` abre a janela. Reinicie o Cursor para o servidor MCP entrar.

## MCP

```json
{
  "mcpServers": {
    "chaves": {
      "command": "/Applications/Chaves.app/Contents/MacOS/Chaves",
      "args": ["--mcp"]
    }
  }
}
```

Ferramentas: `list_keys`, `get_key`, `refresh_credits`, `upsert_key`, `delete_key`, `service_status`. Nenhuma delas devolve o valor completo da chave.

Antes de um lote caro de vídeo ou imagem, `refresh_credits` é o recado: o número na tela é o da API, não um chute.
