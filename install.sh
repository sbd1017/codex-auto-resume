#!/bin/bash
# Installs codex-auto-resume for this user: the script, a launchd agent that runs its background
# loop, and a `codex-auto-resume` command on your PATH. Run it again to update.
set -euo pipefail
LABEL="local.codex-auto-resume"
APP_DIR="$HOME/Library/Application Support/CodexAutoResume"
LOG_DIR="$HOME/Library/Logs/CodexAutoResume"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
cd "$(dirname "$0")"

if [ ! -x /usr/bin/python3 ]; then
  echo "codex-auto-resume needs /usr/bin/python3: run 'xcode-select --install' first." >&2
  exit 1
fi

mkdir -p "$APP_DIR/bin" "$LOG_DIR" "$(dirname "$PLIST")"
install -m 755 codex-auto-resume "$APP_DIR/bin/codex-auto-resume"
install -m 755 uninstall.sh "$APP_DIR/uninstall.sh"

cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/python3</string>
    <string>$APP_DIR/bin/codex-auto-resume</string>
    <string>daemon</string>
  </array>
  <key>EnvironmentVariables</key><dict><key>PATH</key><string>/usr/bin:/bin:/usr/sbin:/sbin</string></dict>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><dict><key>SuccessfulExit</key><false/></dict>
  <key>ThrottleInterval</key><integer>30</integer>
  <key>ProcessType</key><string>Adaptive</string>
  <key>StandardOutPath</key><string>$LOG_DIR/daemon.out.log</string>
  <key>StandardErrorPath</key><string>$LOG_DIR/daemon.out.log</string>
</dict>
</plist>
PLIST

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"

LINKED=""
for dir in /opt/homebrew/bin /usr/local/bin; do
  if [ -d "$dir" ] && [ -w "$dir" ]; then
    ln -sf "$APP_DIR/bin/codex-auto-resume" "$dir/codex-auto-resume"
    LINKED="$dir/codex-auto-resume"
    break
  fi
done

echo "Installed codex-auto-resume ${LINKED:+($LINKED) }and its background agent."
[ -n "$LINKED" ] || echo "Run it as: \"$APP_DIR/bin/codex-auto-resume\""
"$APP_DIR/bin/codex-auto-resume" doctor || true
