#!/usr/bin/env bash

set -e

CONFIG_DIR="$HOME/.mimoclaude"
CONFIG_FILE="$CONFIG_DIR/config"
BIN_DIR="$HOME/bin"
COMMAND_FILE="$BIN_DIR/mimoclaude"
TOKEN_PLAN_BASE_URL="https://token-plan-sgp.xiaomimimo.com/anthropic"

echo "MiMoClaude installer"
echo

if [ ! -r /dev/tty ]; then
  echo "Error: this installer needs an interactive terminal."
  echo "Please run it from Terminal so it can securely ask for your API key."
  exit 1
fi

exec 3</dev/tty

if ! command -v claude >/dev/null 2>&1; then
  echo "Error: Claude Code was not found."
  echo "Please install Claude Code first, then run this installer again."
  exit 1
fi

echo "Choose your MiMo API type:"
echo "  1. Token Plan"
echo "  2. API Pay-as-you-go"
printf "Selection [1/2]: "
read -r MIMO_API_TYPE_CHOICE <&3

case "$MIMO_API_TYPE_CHOICE" in
  1|"")
    MIMO_API_TYPE="token-plan"
    MIMO_BASE_URL="$TOKEN_PLAN_BASE_URL"
    ;;
  2)
    MIMO_API_TYPE="pay-as-you-go"
    echo
    echo "Paste your MiMo Anthropic-compatible API base URL."
    echo "Example format: https://example.com/anthropic"
    printf "Base URL: "
    read -r MIMO_BASE_URL <&3

    if [ -z "$MIMO_BASE_URL" ]; then
      echo "Error: base URL cannot be empty for API Pay-as-you-go."
      exit 1
    fi
    ;;
  *)
    echo "Error: please choose 1 for Token Plan or 2 for API Pay-as-you-go."
    exit 1
    ;;
esac

echo
echo "Paste your MiMo API key."
if [ "$MIMO_API_TYPE" = "token-plan" ]; then
  echo "Token Plan keys usually start with tp-."
else
  echo "API Pay-as-you-go keys may use a different prefix."
fi
printf "API key: "
read -r -s MIMO_API_KEY <&3
echo

if [ -z "$MIMO_API_KEY" ]; then
  echo "Error: API key cannot be empty."
  exit 1
fi

case "$MIMO_API_KEY" in
  tp-*)
    ;;
  *)
    if [ "$MIMO_API_TYPE" = "token-plan" ]; then
      echo "Warning: this Token Plan API key does not start with tp-."
      printf "Continue anyway? [y/N]: "
      read -r CONTINUE_INSTALL <&3
      case "$CONTINUE_INSTALL" in
        y|Y|yes|YES)
          ;;
        *)
          echo "Install cancelled."
          exit 1
          ;;
      esac
    fi
    ;;
esac

mkdir -p "$CONFIG_DIR"
chmod 700 "$CONFIG_DIR"

{
  printf "MIMO_API_TYPE=%q\n" "$MIMO_API_TYPE"
  printf "MIMO_BASE_URL=%q\n" "$MIMO_BASE_URL"
  printf "MIMO_API_KEY=%q\n" "$MIMO_API_KEY"
} > "$CONFIG_FILE"
chmod 600 "$CONFIG_FILE"

mkdir -p "$BIN_DIR"

cat > "$COMMAND_FILE" <<'EOF'
#!/usr/bin/env bash

set -e

CONFIG_FILE="$HOME/.mimoclaude/config"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Error: MiMoClaude config not found at $CONFIG_FILE"
  echo "Run install.sh again to create it."
  exit 1
fi

# shellcheck disable=SC1090
. "$CONFIG_FILE"

if [ -z "${MIMO_API_KEY:-}" ]; then
  echo "Error: MIMO_API_KEY is missing from $CONFIG_FILE"
  exit 1
fi

if [ -z "${MIMO_BASE_URL:-}" ]; then
  echo "Error: MIMO_BASE_URL is missing from $CONFIG_FILE"
  exit 1
fi

export ANTHROPIC_BASE_URL="$MIMO_BASE_URL"
export ANTHROPIC_AUTH_TOKEN="$MIMO_API_KEY"
export ANTHROPIC_MODEL="mimo-v2.5-pro"
export ANTHROPIC_DEFAULT_SONNET_MODEL="mimo-v2.5-pro"
export ANTHROPIC_DEFAULT_OPUS_MODEL="mimo-v2.5-pro"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="mimo-v2.5"

exec claude "$@"
EOF

chmod +x "$COMMAND_FILE"

SHELL_CONFIG=""
SHELL_CONFIG_LABEL=""

case "${SHELL:-}" in
  */zsh)
    SHELL_CONFIG="$HOME/.zshrc"
    SHELL_CONFIG_LABEL="~/.zshrc"
    ;;
  */bash)
    SHELL_CONFIG="$HOME/.bashrc"
    SHELL_CONFIG_LABEL="~/.bashrc"
    ;;
  *)
    SHELL_CONFIG="$HOME/.profile"
    SHELL_CONFIG_LABEL="~/.profile"
    ;;
esac

PATH_LINE='export PATH="$HOME/bin:$PATH"'

case ":$PATH:" in
  *":$BIN_DIR:"*)
    PATH_ALREADY_ACTIVE=1
    ;;
  *)
    PATH_ALREADY_ACTIVE=0
    ;;
esac

if [ "$PATH_ALREADY_ACTIVE" -eq 0 ]; then
  touch "$SHELL_CONFIG"
  if ! grep -F 'export PATH="$HOME/bin:$PATH"' "$SHELL_CONFIG" >/dev/null 2>&1 &&
     ! grep -F "export PATH=\"$BIN_DIR:\$PATH\"" "$SHELL_CONFIG" >/dev/null 2>&1; then
    {
      echo
      echo "# Added by MiMoClaude installer"
      echo "$PATH_LINE"
    } >> "$SHELL_CONFIG"
    PATH_NOTE="Added ~/bin to PATH in $SHELL_CONFIG_LABEL."
  else
    PATH_NOTE="~/bin already appears in $SHELL_CONFIG_LABEL."
  fi
else
  PATH_NOTE="~/bin is already available in your current PATH."
fi

echo
echo "MiMoClaude installed successfully."
echo
echo "Created:"
echo "  $COMMAND_FILE"
echo "  $CONFIG_FILE"
echo
echo "Configured API type: $MIMO_API_TYPE"
echo "Configured base URL: $MIMO_BASE_URL"
echo
echo "$PATH_NOTE"
echo
echo "Next steps:"
echo "  1. Restart your terminal, or run: source $SHELL_CONFIG_LABEL"
echo "  2. Start Claude Code through your selected MiMo API with: mimoclaude"
echo
echo "Your normal claude command was not changed."
