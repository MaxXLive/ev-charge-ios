#!/usr/bin/env bash
# Pad every *_framed.png to an exact App Store Connect screenshot size.
# frameit outputs frame-native dimensions (e.g. 1350x2760) which ASC rejects;
# we fit the framed device onto a TARGET-sized white canvas so the final PNG
# matches an accepted iPhone resolution. Run after `frame_screenshots`.
#
# 6.9" slot = 1290x2796 (also accepts 1320x2868). This canvas is accepted for
# the required iPhone screenshot size regardless of the captured device.
set -euo pipefail

TARGET="${1:-1290x2796}"
BG="${2:-white}"
DIR="${3:-$(cd "$(dirname "$0")/screenshots" && pwd)}"

shopt -s nullglob
count=0
for f in "$DIR"/*/*_framed.png; do
  magick "$f" -resize "${TARGET}" -background "$BG" -gravity center -extent "${TARGET}" "$f"
  count=$((count + 1))
done
echo "padded $count framed screenshots to $TARGET"
