#!/usr/bin/env bash
#
# Helper for the `screenshots` / `reframe` lanes.
#
#   install    clear stale frameit output + drop the rounded title font into the
#              gitignored screenshots/ tree (used by frame_compose.sh)
#   relocale   rename nb -> no for App Store Connect
#
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE/screenshots"
MODE="${1:-}"

case "$MODE" in
  install)
    # Clear prior frameit config so frameit emits clean transparent device frames.
    rm -f "$ROOT/Framefile.json" "$ROOT/background.png"
    find "$ROOT" -name "title.strings" -delete
    find "$ROOT" -name "*_framed.png" -delete
    find "$ROOT" -name "*_ipad_framed.png" -delete
    # SF Pro Display Bold — clean, modern, fits navigation/map aesthetic.
    cp "/Library/Fonts/SF-Pro-Display-Bold.otf" "$ROOT/TitleFont.ttf"
    echo "frame_prepare: cleaned frameit tree, installed title font" ;;

  relocale)
    # Norwegian is captured as "nb" (iOS code) but App Store Connect expects "no".
    if [ -d "$ROOT/nb" ]; then
      rm -rf "$ROOT/no"
      mv "$ROOT/nb" "$ROOT/no"
      echo "frame_prepare: renamed locale nb -> no"
    fi ;;

  *)
    echo "usage: frame_prepare.sh {install|relocale}" >&2
    exit 1 ;;
esac
