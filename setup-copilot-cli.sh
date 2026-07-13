#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "=================================================="
echo "   Installing GitHub Copilot CLI & Language LSPs  "
echo "=================================================="

# Pre-flight: ensure npm is available
if ! command -v npm &> /dev/null; then
    echo "ERROR: npm is not installed. Please install Node.js and npm first."
    exit 1
fi

# Detect the actual user and home directory if run with sudo
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
REAL_HOME="${REAL_HOME:-$HOME}"

# Token limit constants (single source of truth)
MAX_PROMPT_TOKENS=840000
MAX_OUTPUT_TOKENS=128000

# 1. Install Copilot CLI globally via npm
echo -e "\n[1/5] Installing GitHub Copilot CLI..."
npm install -g @github/copilot

# Verify Copilot CLI installed successfully
if ! command -v copilot &> /dev/null; then
    echo "ERROR: Copilot CLI installation failed. Check npm output above."
    exit 1
fi
echo "--> Copilot CLI installed successfully."

# 2. Prompt user for custom provider configuration
# Note: '< /dev/tty' ensures prompts work even if the script is piped (e.g., via curl | bash)
echo -e "\n[2/5] Configuring Custom LLM Provider..."
read -p "Enter Custom Provider Base URL (e.g., https://api.yourprovider.com/v1): " PROVIDER_URL < /dev/tty
read -s -p "Enter Custom Provider API Key: " API_KEY < /dev/tty
echo "" # Print a newline after hidden input
read -p "Enter Model ID (e.g., deepseek-v4-pro): " MODEL_ID < /dev/tty

# Detect active shell configuration file to persist variables
SHELL_RC=""
if [[ "$SHELL" == */zsh ]]; then
    SHELL_RC="$REAL_HOME/.zshrc"
elif [[ "$SHELL" == */bash ]]; then
    SHELL_RC="$REAL_HOME/.bashrc"
else
    SHELL_RC="$REAL_HOME/.profile"
fi

# Append the Copilot custom provider variables to the shell configuration (idempotent)
echo -e "\n--> Persisting environment variables to $SHELL_RC..."
if grep -q "# GitHub Copilot CLI - Custom BYOK Provider Setup" "$SHELL_RC" 2>/dev/null; then
    echo "--> Copilot CLI environment variables already exist in $SHELL_RC. Skipping append."
else
    {
        echo ""
        echo "# GitHub Copilot CLI - Custom BYOK Provider Setup"
        echo "export COPILOT_PROVIDER_BASE_URL=\"$PROVIDER_URL\""
        echo "export COPILOT_PROVIDER_API_KEY=\"$API_KEY\""
        echo "export COPILOT_MODEL=\"$MODEL_ID\""
        if [[ "$MODEL_ID" == "deepseek-v4-pro" ]]; then
            echo "export COPILOT_PROVIDER_MAX_PROMPT_TOKENS=$MAX_PROMPT_TOKENS"
            echo "export COPILOT_PROVIDER_MAX_OUTPUT_TOKENS=$MAX_OUTPUT_TOKENS"
        fi
        # COPILOT_OFFLINE=true disables cloud-assisted features (telemetry, remote model fallback).
        echo "export COPILOT_OFFLINE=true"
    } >> "$SHELL_RC"
fi

# Export the variables immediately into the current terminal session
export COPILOT_PROVIDER_BASE_URL="$PROVIDER_URL"
export COPILOT_PROVIDER_API_KEY="$API_KEY"
export COPILOT_MODEL="$MODEL_ID"
if [[ "$MODEL_ID" == "deepseek-v4-pro" ]]; then
    export COPILOT_PROVIDER_MAX_PROMPT_TOKENS=$MAX_PROMPT_TOKENS
    export COPILOT_PROVIDER_MAX_OUTPUT_TOKENS=$MAX_OUTPUT_TOKENS
fi
export COPILOT_OFFLINE=true

# 3. Setup LSPs for TypeScript, Ruby, and Python (Fully via npm)
echo -e "\n[3/5] Installing LSP Binaries via npm..."

# TypeScript, JavaScript, Ruby (Fast LSP), and Python (Pyright)
echo "--> Installing typescript, ruby-fast-lsp, and pyright..."
npm install -g typescript typescript-language-server @ruby-fast/lsp pyright

# Verify LSP installations
echo "--> Verifying LSP installations..."
LSP_MISSING=()
for cmd in typescript-language-server ruby-fast-lsp pyright-langserver; do
    if command -v "$cmd" &> /dev/null; then
        echo "    ✓ $cmd"
    else
        echo "    ✗ $cmd not found"
        LSP_MISSING+=("$cmd")
    fi
done

if [ ${#LSP_MISSING[@]} -gt 0 ]; then
    echo "WARNING: Some LSP binaries were not found. Check npm output above."
    echo "Missing: ${LSP_MISSING[*]}"
fi

# 4. Link LSPs to Copilot CLI Configuration
echo -e "\n[4/5] Activating LSPs in Copilot Configuration..."
mkdir -p "$REAL_HOME/.copilot"

cat << 'EOF' > "$REAL_HOME/.copilot/lsp-config.json"
{
  "lspServers": {
    "typescript": {
      "command": "typescript-language-server",
      "args": ["--stdio"],
      "fileExtensions": {
        ".ts": "typescript",
        ".tsx": "typescriptreact",
        ".js": "javascript",
        ".jsx": "javascriptreact"
      }
    },
    "ruby": {
      "command": "ruby-fast-lsp",
      "args": ["--stdio"],
      "fileExtensions": {
        ".rb": "ruby",
        ".rake": "ruby"
      }
    },
    "python": {
      "command": "pyright-langserver",
      "args": ["--stdio"],
      "fileExtensions": {
        ".py": "python"
      }
    }
  }
}
EOF

echo "--> Created LSP map at $REAL_HOME/.copilot/lsp-config.json"

# 5. Optional: Provision Caveman Mode Agent and set as default
echo -e "\n[5/5] Optional: Caveman Mode Agent (terse, low-token responses)"
read -p "Install Caveman Mode agent and set it as default? (y/N): " INSTALL_CAVEMAN < /dev/tty
INSTALL_CAVEMAN=$(echo "$INSTALL_CAVEMAN" | tr '[:upper:]' '[:lower:]')

if [[ "$INSTALL_CAVEMAN" == "y" || "$INSTALL_CAVEMAN" == "yes" ]]; then
    echo "--> Provisioning Custom Caveman Agent..."
    mkdir -p "$REAL_HOME/.copilot/agents"

    cat << 'EOF' > "$REAL_HOME/.copilot/agents/caveman-mode.agent.md"
---
name: caveman-mode
description: 'Terse, low-token responses. Minimal words, no fluff. Full capabilities preserved.'
---
You are a blunt, token-conscious developer. Your job: answer fast, use minimal words, no fluff. Say only what's needed. Use terse, direct language. Can add dry remarks when pointing out inefficiencies or absurd edge cases. Full tool access. Same capabilities, fewer words.

Core Directives
- Terse Output: One sentence max per thought. No elaboration unless asked. Target 50-70% fewer tokens than normal mode.
- Structure: Bullets, short code blocks, tables. No prose paragraphs. No greetings, summaries, meta-commentary.
- Word Budget: Answer in fewest words that convey meaning. Trim every sentence.
- Code Same: Code output is standard (readable, well-formatted). Only chat responses are terse.
- Tools Unrestricted: Full tool access, same as default mode.
- Questions: Ask only one, direct question. No multi-part questions.

Communication Rules
- Use short, 3-6 word sentences.
- No emojis. No padding. No "here's what I did" narration.
- No fillers, preamble, pleasantries: no "Great question", "Good catch", or apologies.
- Drop articles: "Me fix code" not "I will fix the code."
EOF

    echo "--> Created Custom Agent configuration at $REAL_HOME/.copilot/agents/caveman-mode.agent.md"

    # Set caveman-mode as the default agent
    echo "--> Setting caveman-mode as the default agent..."
    export COPILOT_DEFAULT_AGENT="caveman-mode"

    # Persist default agent to shell config (if not already present)
    if ! grep -q "COPILOT_DEFAULT_AGENT" "$SHELL_RC" 2>/dev/null; then
        echo "export COPILOT_DEFAULT_AGENT=\"caveman-mode\"" >> "$SHELL_RC"
    fi

    CAVEMAN_INSTALLED=true
else
    echo "--> Skipping Caveman Mode agent."
    CAVEMAN_INSTALLED=false
fi

echo "=================================================="
echo "        Setup Successfully Completed!             "
echo "=================================================="
echo "To apply changes to your current terminal session, run:"
echo "source $SHELL_RC"
echo ""
if [[ "$CAVEMAN_INSTALLED" == "true" ]]; then
    echo "Once sourced, run 'copilot' to boot instantly into Caveman Mode."
else
    echo "Run 'copilot' to start using GitHub Copilot CLI."
fi