#!/bin/bash
# Remove codex-auto-resume. Keeps state and logs unless --purge is given.
set -uo pipefail
LABEL="local.codex-auto-resume"
APP_DIR="$HOME/Library/Application Support/CodexAutoResume"
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null
rm -f "$HOME/Library/LaunchAgents/$LABEL.plist"
for link in /opt/homebrew/bin/codex-auto-resume /usr/local/bin/codex-auto-resume; do [ -L "$link" ] && rm -f "$link"; done
rm -rf "$APP_DIR/bin"
if [ "${1:-}" = "--purge" ]; then
  rm -rf "$APP_DIR" "$HOME/Library/Logs/CodexAutoResume"
  echo "Removed codex-auto-resume, its state and logs."
else
  echo "Removed codex-auto-resume (state kept in $APP_DIR, logs in ~/Library/Logs/CodexAutoResume; use --purge to delete)."
fi
