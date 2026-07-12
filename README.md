# setup-copilot-cli

One-shot bootstrap script for GitHub Copilot CLI with a custom BYOK LLM provider, language LSPs, and an optional caveman-mode agent.

## Prerequisites

- **Node.js & npm** — required to install Copilot CLI and LSP binaries globally.

## What It Does

| Step | Description |
|------|-------------|
| 1 | Installs `@github/copilot` globally via npm |
| 2 | Prompts for your custom provider URL, API key, and model ID; persists them to your shell rc file |
| 3 | Installs LSP binaries: `typescript-language-server`, `ruby-fast-lsp`, `pyright` |
| 4 | Writes `~/.copilot/lsp-config.json` mapping `.ts/.tsx/.js/.jsx/.rb/.rake/.py` to their LSPs |
| 5 | *(Optional)* Provisions a caveman-mode custom agent (terse, low-token) and sets it as the default |

## Usage

### One-liner (curl)

```bash
curl -fsSL https://raw.githubusercontent.com/themcmxciv/setup-copilot-cli/main/setup-copilot-cli.sh | bash
```

### Manual

```bash
chmod +x setup-copilot-cli.sh
./setup-copilot-cli.sh
```

After the script completes, source your shell config and run Copilot:

```bash
source ~/.zshrc   # or ~/.bashrc / ~/.profile
copilot
```

## Environment Variables Set

| Variable | Purpose |
|----------|---------|
| `COPILOT_PROVIDER_BASE_URL` | Custom LLM provider endpoint |
| `COPILOT_PROVIDER_API_KEY` | API key for the provider |
| `COPILOT_MODEL` | Model ID to use |
| `COPILOT_PROVIDER_MAX_PROMPT_TOKENS` | Max prompt tokens (840000) — only set when model is `deepseek-v4-pro` |
| `COPILOT_PROVIDER_MAX_OUTPUT_TOKENS` | Max output tokens (128000) — only set when model is `deepseek-v4-pro` |
| `COPILOT_OFFLINE` | Disables cloud-assisted features |
| `COPILOT_DEFAULT_AGENT` | *(If caveman installed)* Sets caveman-mode as default |

## Files Created

- `~/.copilot/lsp-config.json` — LSP server mappings
- `~/.copilot/agents/caveman-mode.agent.md` — *(Optional)* Caveman agent definition

## Idempotent

Safe to re-run. The script detects existing shell config entries and skips duplicates. The LSP config and agent file are overwritten on each run.
