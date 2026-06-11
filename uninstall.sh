#!/usr/bin/env bash

set -e

CONFIG_DIR="$HOME/.mimoclaude"
COMMAND_FILE="$HOME/bin/mimoclaude"

echo "MiMoClaude uninstaller"
echo

if [ -f "$COMMAND_FILE" ]; then
  rm -f "$COMMAND_FILE"
  echo "Removed $COMMAND_FILE"
else
  echo "No command found at $COMMAND_FILE"
fi

if [ -d "$CONFIG_DIR" ]; then
  rm -rf "$CONFIG_DIR"
  echo "Removed $CONFIG_DIR"
else
  echo "No config directory found at $CONFIG_DIR"
fi

echo
echo "MiMoClaude was uninstalled."
echo
echo "Note: PATH entries were not removed automatically."
echo "If the installer added ~/bin to your shell config, you can remove that line manually from:"
echo "  ~/.zshrc"
echo "  ~/.bashrc"
echo "  ~/.profile"
