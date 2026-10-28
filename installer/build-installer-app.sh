#!/bin/bash
# build-installer-app.sh [ZIELORDNER] [--bundle]
# Baut "WoW-Mac Installer.app" (Standard-Ziel: ~/Applications).
# --bundle legt die Installer-Dateien ins App-Bundle (für die herunterladbare Release-App).
set -eu
HERE=$(cd "$(dirname "$0")" && pwd -P)
OUT="${1:-$HOME/Applications}"
BUNDLE=0; [ "${2:-}" = "--bundle" ] && BUNDLE=1
APP="$OUT/WoW-Mac Installer.app"
T=$(mktemp -d /tmp/wowmac-build.XXXXXX)
cat "$HERE/apps/installer.applescript" "$HERE/apps/progress.applescript.inc" > "$T/installer.applescript"
xattr -w com.apple.TextEncoding "utf-8;134217984" "$T/installer.applescript" 2>/dev/null || true
mkdir -p "$OUT"
rm -rf "$APP"
osacompile -o "$APP" "$T/installer.applescript"
P="$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier io.github.wowmac.installer" "$P" 2>/dev/null || /usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string io.github.wowmac.installer" "$P"
/usr/libexec/PlistBuddy -c "Set :CFBundleName WoW-Mac Installer" "$P" 2>/dev/null || /usr/libexec/PlistBuddy -c "Add :CFBundleName string WoW-Mac Installer" "$P"
/usr/libexec/PlistBuddy -c "Add :NSAppleEventsUsageDescription string 'Richtet die WoW-VM in UTM ein.'" "$P" 2>/dev/null || true
if [ "$BUNDLE" = 1 ]; then
  ditto "$HERE" "$APP/Contents/Resources/installer"
fi
codesign --force --deep --sign - "$APP"
rm -rf "$T"
echo "$APP"
