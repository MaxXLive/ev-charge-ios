#!/usr/bin/env python3
"""Generate web screenshots from the fastlane framed originals.

Reads ../evcharge/fastlane/screenshots/<fastlaneLocale>/iPhone 17 Pro-*_framed.png,
removes the opaque white padding around the device (flood-fill from the corners,
then auto-crop), and writes public/screenshots/<webLocale>/{map,detail,filter}.png.

Runs for every locale fastlane has produced, so adding a website language is just
a matter of adding it to src/i18n/routing.ts and src/messages/. Re-run after every
`fastlane screenshots`:

    npm run gen:screenshots
"""

import os
import sys

try:
    from PIL import Image, ImageDraw
except ImportError:
    sys.exit("Pillow required:  pip3 install Pillow")

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.normpath(os.path.join(HERE, "..", "..", "evcharge", "fastlane", "screenshots_web"))
OUT = os.path.normpath(os.path.join(HERE, "..", "public", "screenshots"))

# fastlane file name -> web file name
SHOTS = {
    "iPhone 17 Pro-01Map_web_framed.png": "map",
    "iPhone 17 Pro-02StationDetail_web_framed.png": "detail",
    "iPhone 17 Pro-03Filter_web_framed.png": "filter",
}

# fastlane locale dir -> website locale slug
def web_locale(fastlane_locale: str) -> str:
    return fastlane_locale.split("-")[0].lower()


def trim_white(im: Image.Image) -> Image.Image:
    """Flood-fill the white padding from the four corners to transparent, then crop."""
    im = im.convert("RGBA")
    w, h = im.size
    for corner in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]:
        if im.getpixel(corner)[:3] == (255, 255, 255):
            ImageDraw.floodfill(im, corner, (0, 0, 0, 0), thresh=40)
    bbox = im.getbbox()
    return im.crop(bbox) if bbox else im


def main() -> None:
    if not os.path.isdir(SRC):
        sys.exit(f"fastlane screenshots not found at {SRC}")

    total = 0
    for locale in sorted(os.listdir(SRC)):
        src_dir = os.path.join(SRC, locale)
        if not os.path.isdir(src_dir):
            continue
        if not all(os.path.isfile(os.path.join(src_dir, f)) for f in SHOTS):
            continue  # locale without a full iPhone set

        out_dir = os.path.join(OUT, web_locale(locale))
        os.makedirs(out_dir, exist_ok=True)

        for src_name, web_name in SHOTS.items():
            im = trim_white(Image.open(os.path.join(src_dir, src_name)))
            im.save(os.path.join(out_dir, f"{web_name}.png"))
            total += 1
        print(f"  {locale:7s} -> public/screenshots/{web_locale(locale)}/")

    print(f"Done: {total} screenshots across {total // len(SHOTS)} locales.")


if __name__ == "__main__":
    main()
