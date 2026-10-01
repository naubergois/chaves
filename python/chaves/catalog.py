"""Catálogo das chaves que o Cursor, o QClaw e os MCPs consomem."""

from __future__ import annotations

from typing import Any

CATEGORY_LABELS: dict[str, str] = {
    "llm": "Modelos",
    "media": "Imagem e vídeo",
    "voice": "Voz e música",
    "aws": "AWS",
    "messaging": "Mensagens",
    "email": "E-mail",
    "observability": "Observabilidade",
    "memory": "Memória",
    "auth": "Autenticação",
    "env": "Ambiente",
    "other": "Outras",
}

# name, label, category, hint, credit (id da sonda ou vazio)
_ROWS: list[tuple[str, str, str, str, str]] = [
    ("DEEPSEEK_API_KEY", "DeepSeek", "llm", "Chat, recovery e agentes deepseek-*.", "deepseek"),
    ("DEEPSEEK_API_BASE", "DeepSeek base URL", "llm", "Override do endpoint OpenAI-compatível.", ""),
    ("DEEPSEEK_MODEL", "DeepSeek modelo", "llm", "Modelo padrão quando ninguém pede outro.", ""),
    ("OPENAI_API_KEY", "OpenAI", "llm", "GPT, Codex, transcrição.", "openai"),
    ("OPENAI_ADMIN_API_KEY", "OpenAI Admin", "llm", "Gasto da organização em /v1/organization/costs.", "openai"),
    ("ANTHROPIC_API_KEY", "Anthropic Claude", "llm", "Claude Fable, Opus, Sonnet.", ""),
    ("GEMINI_API_KEY", "Google Gemini", "llm", "Gemini, Imagen, Lyria.", ""),
    ("GOOGLE_API_KEY", "Google API (alias)", "llm", "Fallback se GEMINI_API_KEY faltar.", ""),
    ("XAI_API_KEY", "xAI Grok", "llm", "Grok Imagine e chat.", ""),
    ("XAI_MANAGEMENT_KEY", "xAI Management", "llm", "Saldo prepaid — não é a chave de inferência.", "grok"),
    ("XAI_TEAM_ID", "xAI Team ID", "llm", "UUID do time no console.x.ai.", "grok"),
    ("OPENROUTER_API_KEY", "OpenRouter", "llm", "Um endpoint para muitos modelos.", "openrouter"),
    ("PERPLEXITY_API_KEY", "Perplexity", "llm", "Pesquisa com Sonar.", ""),
    ("MISTRAL_API_KEY", "Mistral", "llm", "Mistral Large / Codestral.", ""),
    ("GROQ_API_KEY", "Groq", "llm", "Inferência rápida Llama/Mixtral.", ""),
    ("MOONSHOT_API_KEY", "Moonshot Kimi", "llm", "Kimi K3 / Kimi 3.", ""),
    ("ZAI_API_KEY", "Z.AI GLM", "llm", "GLM-5 via api.z.ai.", ""),
    ("ZHIPU_API_KEY", "Zhipu GLM", "llm", "GLM-4.x via open.bigmodel.cn.", ""),
    ("DASHSCOPE_API_KEY", "DashScope Qwen", "llm", "Qwen via Alibaba.", ""),
    ("TOGETHER_API_KEY", "Together AI", "llm", "Modelos open-source hospedados.", ""),
    ("FIREWORKS_API_KEY", "Fireworks", "llm", "Llama e Mixtral.", ""),
    ("COHERE_API_KEY", "Cohere", "llm", "Command / Embed.", ""),
    ("CEREBRAS_API_KEY", "Cerebras", "llm", "Inferência ultra-rápida.", ""),
    ("NVIDIA_API_KEY", "NVIDIA NIM", "llm", "build.nvidia.com.", ""),
    ("CURSOR_API_KEY", "Cursor Agent", "llm", "Dashboard Cursor → API Keys.", ""),
    ("QCLAW_LLM_API_KEY", "QClaw LLM gateway", "llm", "Chave do proxy interno.", ""),
    ("QCLAW_LLM_BASE_URL", "QClaw LLM base URL", "llm", "URL do gateway interno.", ""),
    ("FAL_KEY", "fal.ai", "media", "FLUX, LTX, Wan, Pika Effects.", "fal"),
    ("REPLICATE_API_TOKEN", "Replicate", "media", "Kling, Wan, Sora, Veo, FLUX.", "replicate"),
    ("HEYGEN_API_KEY", "HeyGen", "media", "Avatar, Video Agent, tradução.", "heygen"),
    ("GAMMA_API_KEY", "Gamma", "media", "Lâminas 16:9.", "gamma"),
    ("STABILITY_API_KEY", "Stability AI", "media", "Stable Diffusion 3.x.", "stability"),
    ("STABILITY_AI_API_KEY", "Stability AI (alias)", "media", "Alias aceite pelo MCP.", "stability"),
    ("RUNWAYML_API_SECRET", "Runway", "media", "Gen-4.5 e image-to-video.", ""),
    ("RUNWAY_API_KEY", "Runway (alias)", "media", "Mesmo cofre que RUNWAYML_API_SECRET.", ""),
    ("KLING_ACCESS_KEY", "Kling access", "media", "Par JWT com KLING_SECRET_KEY.", ""),
    ("KLING_SECRET_KEY", "Kling secret", "media", "Par com KLING_ACCESS_KEY.", ""),
    ("KLING_API_KEY", "Kling Bearer", "media", "Alternativa ao par ACCESS+SECRET.", ""),
    ("BYTEPLUS_API_KEY", "BytePlus Seedream", "media", "Seedream / SeedEdit.", ""),
    ("WAVESPEED_API_KEY", "WaveSpeed", "media", "FLUX alternativo.", ""),
    ("ACEDATACLOUD_API_TOKEN", "Ace Data Cloud", "media", "Seedance e Suno.", ""),
    ("CIVITAI_API_TOKEN", "CivitAI", "media", "Buzz e Orchestration.", "civitai"),
    ("HF_TOKEN", "Hugging Face", "media", "Download de checkpoints e LoRAs.", ""),
    ("MESHY_API_KEY", "Meshy", "media", "Imagem → modelo 3D.", ""),
    ("ELEVENLABS_API_KEY", "ElevenLabs", "voice", "Narração TTS.", "elevenlabs"),
    ("SUNOAPI_API_KEY", "SunoAPI.org", "voice", "Geração Suno estável.", ""),
    ("SUNOR_API_KEY", "Sunor.cc", "voice", "Revendedor Suno.", ""),
    ("SUNO_API_TOKEN", "Suno JWT", "voice", "Sessão suno.com — cai com o login.", ""),
    ("AWS_ACCESS_KEY_ID", "AWS Access Key", "aws", "Cost Explorer, EC2, RDS.", ""),
    ("AWS_SECRET_ACCESS_KEY", "AWS Secret", "aws", "Par da access key.", ""),
    ("AWS_SESSION_TOKEN", "AWS Session", "aws", "Credencial temporária STS.", ""),
    ("AWS_DEFAULT_REGION", "AWS região", "aws", "Ex.: sa-east-1.", ""),
    ("AWS_PROFILE", "AWS profile", "aws", "Perfil em ~/.aws/credentials.", ""),
    ("QCLAW_AWS_FX_BRL", "FX USD→BRL", "aws", "Taxa dos relatórios de custo.", ""),
    ("TELEGRAM_BOT_TOKEN", "Telegram bot", "messaging", "Bot do Telegram.", ""),
    ("QCLAW_TELEGRAM_BOT_TOKEN", "QClaw Telegram", "messaging", "Bot do monitor.", ""),
    ("GMAIL_APP_PASSWORD", "Gmail app password", "email", "Senha de app, não a da conta.", ""),
    ("GOOGLE_APP_PASSWORD", "Google app password", "email", "Alias de GMAIL_APP_PASSWORD.", ""),
    ("TEAM_SMTP_PASSWORD", "SMTP do time", "email", "Envio de e-mail da equipe.", ""),
    ("NOTION_API_KEY", "Notion", "other", "Páginas e bancos Notion.", ""),
    ("TAVILY_API_KEY", "Tavily", "other", "Busca para agentes.", ""),
    ("BRIGHTDATA_API_KEY", "Bright Data", "other", "Proxy e scraping.", ""),
    ("YOUTUBE_API_KEY", "YouTube Data", "other", "Metadados e thumbnails.", ""),
    ("COMIC_VINE_API_KEY", "Comic Vine", "other", "HQ ocidental.", ""),
    ("POSTIZ_API_KEY", "Postiz", "other", "Agendar posts.", ""),
    ("CANVA_ACCESS_TOKEN", "Canva", "other", "Import de design.", ""),
    ("LITELLM_MASTER_KEY", "LiteLLM", "observability", "Proxy LiteLLM.", ""),
    ("LANGFUSE_PUBLIC_KEY", "Langfuse public", "observability", "Traces.", ""),
    ("LANGFUSE_SECRET_KEY", "Langfuse secret", "observability", "Par da public.", ""),
    ("MEM0_API_KEY", "Mem0", "memory", "Memória de swarm.", ""),
    ("SECRET_KEY", "Secret key (app)", "auth", "Assinatura de sessão.", ""),
    ("ADMIN_PASSWORD", "Admin password", "auth", "Painel /chaves.", ""),
    ("MONGODB_URI", "MongoDB URI", "env", "Onde este cofre mora.", ""),
    ("MONGODB_DB", "MongoDB database", "env", "Nome do banco (default gois).", ""),
]


def _entry(name: str, label: str, category: str, hint: str, credit: str) -> dict[str, Any]:
    return {
        "name": name,
        "label": label,
        "category": category,
        "category_label": CATEGORY_LABELS.get(category, category),
        "hint": hint,
        "credit_provider": credit,
    }


CATALOG: dict[str, dict[str, Any]] = {
    name: _entry(name, label, category, hint, credit)
    for name, label, category, hint, credit in _ROWS
}


def catalog_entry(name: str) -> dict[str, Any]:
    key = (name or "").strip().upper()
    if key in CATALOG:
        return dict(CATALOG[key])
    return _entry(
        key,
        key.replace("_", " ").title(),
        "env",
        "Fora do catálogo — gravada no Mongo mesmo assim.",
        "",
    )


def all_catalog_names() -> list[str]:
    return [row[0] for row in _ROWS]
