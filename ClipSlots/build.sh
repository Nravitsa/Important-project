#!/bin/bash
# ─────────────────────────────────────────────────────────────────
#  build.sh — Compiles ClipSlots and creates ClipSlots.app
#
#  STEP 1:  Open Terminal (⌘Space → type Terminal → Enter)
#  STEP 2:  Install build tools if needed (one-time):
#             xcode-select --install
#  STEP 3:  Navigate to this folder, e.g.:
#             cd ~/Desktop/ClipSlots
#  STEP 4:  Run:
#             bash build.sh
#  STEP 5:  Launch:
#             open ClipSlots.app
#  STEP 6:  macOS will ask for Accessibility permission.
#           Go to System Settings → Privacy & Security → Accessibility
#           → toggle ClipSlots ON → then run: open ClipSlots.app
# ─────────────────────────────────────────────────────────────────
set -e

APP="ClipSlots"
APP_DIR="${APP}.app/Contents"

ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
  TARGET="arm64-apple-macosx13.0"
else
  TARGET="x86_64-apple-macosx13.0"
fi

echo ""
echo "🔨  Compiling ${APP}.swift  (${ARCH})…"
swiftc -O \
  -sdk "$(xcrun --sdk macosx --show-sdk-path)" \
  -target "$TARGET" \
  "${APP}.swift" \
  -o "${APP}_bin"

echo "📦  Building app bundle…"
rm -rf "${APP}.app"
mkdir -p "${APP_DIR}/MacOS"
cp "${APP}_bin" "${APP_DIR}/MacOS/${APP}"
cp "Info.plist"  "${APP_DIR}/"
rm -f "${APP}_bin"

echo ""
echo "✅  Done!  (~$(du -sh ${APP}.app | cut -f1) on disk)"
echo ""
echo "  Run:  open ${APP}.app"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  HOW TO USE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Just copy normally with ⌘C — ClipSlots tracks"
echo "  your last 10 copied items automatically."
echo ""
echo "  Click 📋 in the menu bar to see your history."
echo "  Click any item to paste it instantly."
echo "  Right-click (or hover) an item to pin it."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
