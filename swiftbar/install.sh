#!/bin/bash
# codex-gauge installer — symlink the plugin into your SwiftBar plugin folder.
set -e

DIR="${SWIFTBAR_PLUGIN_DIR:-$HOME/.swiftbar-plugins}"
SRC="$(cd "$(dirname "$0")" && pwd)/codex-gauge.1m.py"

mkdir -p "$DIR"
chmod +x "$SRC"
ln -sf "$SRC" "$DIR/codex-gauge.1m.py"
echo "Linked  $SRC"
echo "   ->   $DIR/codex-gauge.1m.py"

# Point SwiftBar at the folder if it isn't set, then refresh.
defaults write com.ameba.SwiftBar PluginDirectory "$DIR" 2>/dev/null || true
open "swiftbar://refreshallplugins" 2>/dev/null || true

echo
echo "Done. If you don't see it in the menu bar:"
echo "  1) make sure SwiftBar is running (brew install --cask swiftbar)"
echo "  2) in SwiftBar, set the plugin folder to: $DIR"
