#!/usr/bin/env bash
#
# Compose final App Store screenshots: branded background + feature title
# (white, SF Pro Rounded) + the frameit device frame.
#
# Input:  fastlane/screenshots/<locale>/*_framed.png  (plain device frames)
# Output: same files overwritten with background+title composite
#         + *_ipad_framed.png  (2048x2732 iPad variant, same device frame)
#
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE/screenshots"
WEB="$HERE/screenshots_web"
SRC="$HERE/frameit"
FONT="$ROOT/TitleFont.ttf"
PHONE_BG="$SRC/background.png"

getstr() {
  grep -E "^\"$2\"" "$1" 2>/dev/null \
    | sed -E 's/^"[^"]*"[[:space:]]*=[[:space:]]*"(.*)";[[:space:]]*$/\1/' \
    | head -1
}

# render <title> <bg> <size> <deviceW> <titleTop> <boxH> <pt> <gap> <out> <devsrc>
render() {
  local title="$1" bg="$2" size="$3" devw="$4" ttop="$5" boxh="$6" pt="$7" gap="$8" out="$9" devsrc="${10}"
  local w="${size%x*}"
  local tmpdev tmptitle dy
  tmpdev="$(mktemp -t evmapdev).png"
  tmptitle="$(mktemp -t evmaptitle).png"
  magick "$devsrc" -resize "${devw}x" "$tmpdev"
  magick -background none -fill white -font "$FONT" -pointsize "$pt" \
    -size "$((w - 150))x${boxh}" -gravity center caption:"$title" "$tmptitle"
  dy="$(( ttop + boxh + gap ))"
  magick "$bg" \
    "$tmptitle" -gravity north -geometry "+0+${ttop}" -composite \
    "$tmpdev"   -gravity north -geometry "+0+${dy}" -composite \
    -extent "$size" \
    "$out"
  rm -f "$tmpdev" "$tmptitle"
}

for langdir in "$ROOT"/*/; do
  lang="$(basename "$langdir")"
  strings="$SRC/$lang/title.strings"
  [ -f "$strings" ] || continue

  for dev in "$langdir"*0[123]*_framed.png; do
    [ -f "$dev" ] || continue
    base="$(basename "$dev")"
    [[ "$base" == *_ipad_* ]] && continue
    key="$(echo "$base" | grep -oE '0[123][A-Za-z]+' | head -1)"
    title="$(getstr "$strings" "$key")"
    [ -n "$title" ] || { echo "compose: no title for $key ($lang), skipping"; continue; }

    # Save transparent device frame for webpage into separate dir (not picked up by deliver)
    mkdir -p "$WEB/$lang"
    web_out="$WEB/$lang/$(basename "${dev%_framed.png}_web_framed.png")"
    cp "$dev" "$web_out"

    render "$title" "$PHONE_BG" 1290x2796 1162  80 320  94 20 "$dev" "$dev"
    echo "compose: $lang/$base  ($title)"
  done
done
