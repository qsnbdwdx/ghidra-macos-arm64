#!/usr/bin/env bash
# Install prebuilt Ghidra macOS arm64 native binaries into an existing Ghidra 12.1.4 install.
# Usage:
#   ./install.sh
#   GHIDRA_INSTALL_DIR=/path/to/ghidra_12.1.4_PUBLIC ./install.sh
set -euo pipefail

RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; BOLD=$'\033[1m'; RESET=$'\033[0m'
say()  { printf '%s\n' "$*"; }
ok()   { printf '%s✓%s %s\n' "$GREEN" "$RESET" "$*"; }
warn() { printf '%s!%s %s\n' "$YELLOW" "$RESET" "$*"; }
die()  { printf '%s✗%s %s\n' "$RED" "$RESET" "$*" >&2; exit 1; }

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BIN_DIR="$SCRIPT_DIR/bin"

[ "$(uname -s)" = "Darwin" ] || die "This package is for macOS only."
[ "$(uname -m)" = "arm64" ] || die "This package is for Apple Silicon (arm64). Detected: $(uname -m)"

# ---- locate Ghidra -----------------------------------------------------------
find_ghidra() {
  if [ -n "${GHIDRA_INSTALL_DIR:-}" ]; then
    printf '%s\n' "$GHIDRA_INSTALL_DIR"; return
  fi
  local c
  for c in \
    /Applications/ghidra_12.1.4_PUBLIC \
    "$HOME"/Applications/ghidra_12.1.4_PUBLIC \
    /Applications/ghidra_*_PUBLIC
  do
    # shellcheck disable=SC2086
    for d in $c; do
      [ -f "$d/support/analyzeHeadless" ] && { printf '%s\n' "$d"; return; }
    done
  done
}

GHIDRA=$(find_ghidra || true)
[ -n "${GHIDRA:-}" ] || die "Ghidra not found. Set GHIDRA_INSTALL_DIR=/path/to/ghidra_12.1.4_PUBLIC"

[ -f "$GHIDRA/support/analyzeHeadless" ] || die "Not a Ghidra install: $GHIDRA (support/analyzeHeadless missing)"

ok "Found Ghidra: $GHIDRA"

# ---- version check -----------------------------------------------------------
APP_PROPS="$GHIDRA/Ghidra/application.properties"
if [ -f "$APP_PROPS" ]; then
  VERSION=$(grep -E '^application.version=' "$APP_PROPS" | head -1 | cut -d= -f2)
  say "   version: ${VERSION:-unknown}"
  case "${VERSION:-}" in
    12.1.*) : ;;
    12.1)   : ;;
    *) warn "These binaries were built for Ghidra 12.1.4. Version ${VERSION:-unknown} is untested and may crash." ;;
  esac
fi

# ---- Java check (Ghidra needs JDK 21+) ---------------------------------------
if command -v java >/dev/null 2>&1; then
  JV=$(java -version 2>&1 | head -1)
  say "   java:    $JV"
else
  warn "No 'java' on PATH. Ghidra requires JDK 21 or newer."
fi

# ---- install -----------------------------------------------------------------
DEST="$GHIDRA/Ghidra/Features/Decompiler/os/mac_arm_64"
mkdir -p "$DEST"

for f in decompile sleigh; do
  [ -f "$BIN_DIR/$f" ] || die "Missing $BIN_DIR/$f (run from the repo root, and confirm bin/ is present)"

  if [ -f "$DEST/$f" ]; then
    BAK="$DEST/$f.bak.$(date +%Y%m%d%H%M%S)"
    cp "$DEST/$f" "$BAK"
    warn "Existing $f backed up → $BAK"
  fi

  cp "$BIN_DIR/$f" "$DEST/$f"
  chmod +x "$DEST/$f"
  ok "Installed $f → $DEST/$f"
done

# ---- verify ------------------------------------------------------------------
say ""
say "${BOLD}Verification${RESET}"
for f in decompile sleigh; do
  ARCH=$(file -b "$DEST/$f")
  case "$ARCH" in
    *arm64*) ok "$f: $ARCH" ;;
    *)       die "$f has unexpected architecture: $ARCH" ;;
  esac
done

# checksum check when available
if [ -f "$SCRIPT_DIR/SHA256SUMS" ]; then
  if (cd "$SCRIPT_DIR" && shasum -a 256 -c SHA256SUMS >/dev/null 2>&1); then
    ok "Checksums match"
  else
    warn "Checksum mismatch — binaries may be corrupted. Re-download before use."
  fi
fi

say ""
say "${GREEN}${BOLD}Done.${RESET} Restart Ghidra, then open any binary and double-click a function to see decompiled C."
