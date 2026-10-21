#!/bin/sh
# Installs the HDR compositor as a separate login session; the stock COSMIC
# session is left untouched. Usage: sudo ./install.sh <connector>, e.g. DP-1
# (list connectors with `cosmic-randr list`).
set -e
[ -n "$1" ] || { echo "usage: sudo $0 <connector, e.g. DP-1>" >&2; exit 1; }
REPO="$(cd "$(dirname "$0")/.." && pwd)"
install -Dm755 "$REPO/target/release/cosmic-comp" /opt/cosmic-hdr/bin/cosmic-comp
install -Dm755 "$REPO/hdr-session/start-cosmic-hdr" /opt/cosmic-hdr/bin/start-cosmic-hdr
install -Dm644 "$REPO/hdr-session/cosmic-hdr.desktop" /usr/share/wayland-sessions/cosmic-hdr.desktop
printf 'COSMIC_HDR_OUTPUT=%s\n' "$1" > /opt/cosmic-hdr/env
echo "Installed with HDR on $1. Pick 'COSMIC (HDR)' at the login screen."
