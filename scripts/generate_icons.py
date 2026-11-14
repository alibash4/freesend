#!/usr/bin/env python3
"""Regenerate every FreeSend launcher icon from the source logo.

Windows and Linux use the logo exactly as it is. Android gets an adaptive
icon: a #121212 background layer plus the logo as the foreground layer, so
the launcher applies the squircle mask itself. macOS never masks icons, so
Apple's continuous-corner squircle is drawn behind the logo instead.

The desktop tray icons are the mark alone, filling the whole canvas: the tray
host scales them to its own height, so any padding only shrinks the artwork.

Usage:
    python3 scripts/generate_icons.py [logo.png]

The logo defaults to freesend.png in the repository root.
"""

from __future__ import annotations

import io
import struct
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

REPO = Path(__file__).resolve().parent.parent
DEFAULT_LOGO = REPO / "freesend.png"

# The squircle background shared by the Android and macOS icons.
SQUIRCLE_COLOR = (0x12, 0x12, 0x12, 0xFF)

# How much of the squircle the logo mark fills, measured across its width.
# 66% is the largest size that survives every launcher mask: above it a
# circular mask starts biting the mark's tips.
MARK_FRACTION = 0.66

# The tray icons are full-bleed and the tray host picks the display size, so
# one generous resolution covers every DPI.
TRAY_SIZE = 256

# Apple's continuous-corner rounded rectangle, reverse-engineered from the
# macOS icon mask by Liam Rosenfeld: the corner radius is 45% of half the
# shape's width, and the control points sit at these multiples of that
# radius. https://liamrosenfeld.com/posts/apple_icon_quest/
SQUIRCLE_RADIUS = 0.45 / 2

# The macOS icon template: an 824x824 squircle centred on a 1024x1024 canvas.
MACOS_CANVAS = 1024
MACOS_TILE = 824
MACOS_GUTTER = (MACOS_CANVAS - MACOS_TILE) // 2

# Each icon is rendered at this multiple of its final size and downsampled,
# which is what keeps the squircle edge smooth.
SUPERSAMPLE = 4


def _cubic_points(p0, p1, p2, p3, steps=64):
    """Flatten one cubic Bézier into line segments."""
    points = []
    for i in range(1, steps + 1):
        t = i / steps
        u = 1.0 - t
        points.append(
            (
                u * u * u * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t * t * t * p3[0],
                u * u * u * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t * t * t * p3[1],
            )
        )
    return points


def squircle_outline(size):
    """Return the polygon outline of Apple's continuous-corner squircle."""
    radius = SQUIRCLE_RADIUS * size
    width = height = float(size)

    def tl(x, y):
        return (x * radius, y * radius)

    def tr(x, y):
        return (width - x * radius, y * radius)

    def br(x, y):
        return (width - x * radius, height - y * radius)

    def bl(x, y):
        return (x * radius, height - y * radius)

    # Start on the top edge just past the top-left corner, then walk clockwise.
    points = [tl(1.528665, 0.0), tr(1.528665, 0.0)]
    # Top-right corner.
    points += _cubic_points(
        tr(1.528665, 0.0), tr(1.08849296, 0.0), tr(0.86840694, 0.0), tr(0.63149379, 0.07491139)
    )
    points += _cubic_points(
        tr(0.63149379, 0.07491139),
        tr(0.37282383, 0.16905956),
        tr(0.16905956, 0.37282383),
        tr(0.07491139, 0.63149379),
    )
    points += _cubic_points(
        tr(0.07491139, 0.63149379), tr(0.0, 0.86840694), tr(0.0, 1.08849296), tr(0.0, 1.52866498)
    )
    # Right edge, then the bottom-right corner.
    points.append(br(0.0, 1.528665))
    points += _cubic_points(
        br(0.0, 1.528665), br(0.0, 1.08849296), br(0.0, 0.86840694), br(0.07491139, 0.63149379)
    )
    points += _cubic_points(
        br(0.07491139, 0.63149379),
        br(0.16905956, 0.37282383),
        br(0.37282383, 0.16905956),
        br(0.63149379, 0.07491139),
    )
    points += _cubic_points(
        br(0.63149379, 0.07491139), br(0.86840694, 0.0), br(1.08849296, 0.0), br(1.52866498, 0.0)
    )
    # Bottom edge, then the bottom-left corner.
    points.append(bl(1.528665, 0.0))
    points += _cubic_points(
        bl(1.528665, 0.0), bl(1.08849296, 0.0), bl(0.86840694, 0.0), bl(0.63149379, 0.07491139)
    )
    points += _cubic_points(
        bl(0.63149379, 0.07491139),
        bl(0.37282383, 0.16905956),
        bl(0.16905956, 0.37282383),
        bl(0.07491139, 0.63149379),
    )
    points += _cubic_points(
        bl(0.07491139, 0.63149379), bl(0.0, 0.86840694), bl(0.0, 1.08849296), bl(0.0, 1.52866498)
    )
    # Left edge, then the top-left corner.
    points.append(tl(0.0, 1.528665))
    points += _cubic_points(
        tl(0.0, 1.528665), tl(0.0, 1.08849296), tl(0.0, 0.86840694), tl(0.07491139, 0.63149379)
    )
    points += _cubic_points(
        tl(0.07491139, 0.63149379),
        tl(0.16905956, 0.37282383),
        tl(0.37282383, 0.16905956),
        tl(0.63149379, 0.07491139),
    )
    points += _cubic_points(
        tl(0.63149379, 0.07491139), tl(0.86840694, 0.0), tl(1.08849296, 0.0), tl(1.52866498, 0.0)
    )
    return points


def _resize_rgba(image, size):
    """Resize with premultiplied alpha, so translucent edges keep their colour."""
    data = np.asarray(image, dtype=np.float32)
    alpha = data[..., 3:4] / 255.0
    premultiplied = np.concatenate([data[..., :3] * alpha, data[..., 3:4]], axis=2)
    resized = Image.fromarray(premultiplied.astype(np.uint8), "RGBA").resize(size, Image.LANCZOS)

    data = np.asarray(resized, dtype=np.float32)
    alpha = data[..., 3:4] / 255.0
    safe = np.where(alpha == 0.0, 1.0, alpha)
    rgb = np.clip(data[..., :3] / safe, 0, 255)
    return Image.fromarray(np.concatenate([rgb, data[..., 3:4]], axis=2).astype(np.uint8), "RGBA")


def _mark(logo):
    """Crop the logo down to the mark, dropping the faint halo around it."""
    # The source carries a sparse halo of pixels at 3% opacity or less spread
    # over the whole canvas; cropping on any non-zero alpha would size the
    # mark by that halo instead of by the drawn shape.
    alpha = logo.getchannel("A").point(lambda value: 255 if value >= 8 else 0)
    return logo.crop(alpha.getbbox())


def _fit_mark(mark, width):
    """Scale the mark to `width` pixels, keeping its aspect ratio."""
    height = max(1, round(width * mark.height / mark.width))
    return _resize_rgba(mark, (round(width), height))


def _compose(canvas, mark):
    """Alpha-composite `mark` onto `canvas`, centred."""
    canvas.alpha_composite(
        mark, (round((canvas.width - mark.width) / 2), round((canvas.height - mark.height) / 2))
    )


def android_legacy(logo, size):
    """Pre-API-26 icon: the logo on a #121212 square the launcher masks."""
    scaled = size * SUPERSAMPLE
    canvas = Image.new("RGBA", (scaled, scaled), SQUIRCLE_COLOR)
    _compose(canvas, _fit_mark(_mark(logo), MARK_FRACTION * scaled))
    return _resize_rgba(canvas, (size, size))


def android_foreground(logo, size):
    """Adaptive-icon foreground: the logo alone, on transparency."""
    scaled = size * SUPERSAMPLE
    canvas = Image.new("RGBA", (scaled, scaled), (0, 0, 0, 0))
    _compose(canvas, _fit_mark(_mark(logo), MARK_FRACTION * scaled))
    return _resize_rgba(canvas, (size, size))


def macos_icon(logo, size):
    """The Apple squircle tile on the 1024 canvas, with the logo on top."""
    scaled = size * SUPERSAMPLE
    gutter = round(MACOS_GUTTER * scaled / MACOS_CANVAS)
    tile = scaled - 2 * gutter

    mask = Image.new("L", (tile, tile), 0)
    ImageDraw.Draw(mask).polygon(squircle_outline(tile), fill=255)

    canvas = Image.new("RGBA", (scaled, scaled), (0, 0, 0, 0))
    canvas.paste(Image.new("RGBA", (tile, tile), SQUIRCLE_COLOR), (gutter, gutter), mask)
    _compose(canvas, _fit_mark(_mark(logo), MARK_FRACTION * tile))
    return _resize_rgba(canvas, (size, size))


def write_android(logo):
    res = REPO / "android/app/src/main/res"
    densities = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
    # The legacy icons are the 48dp launcher size; the adaptive foreground is
    # the 108dp layer the system masks.
    for density, scale in densities.items():
        folder = res / f"mipmap-{density}"
        folder.mkdir(parents=True, exist_ok=True)
        android_legacy(logo, round(48 * scale)).save(folder / "ic_launcher.png")
        android_foreground(logo, round(108 * scale)).save(folder / "ic_launcher_foreground.png")
        print(f"  mipmap-{density}: ic_launcher.png, ic_launcher_foreground.png")

    anydpi = res / "mipmap-anydpi-v26"
    anydpi.mkdir(parents=True, exist_ok=True)
    (anydpi / "ic_launcher.xml").write_text(
        """<?xml version="1.0" encoding="utf-8"?>
<!-- The launcher masks this adaptive icon, so the squircle shape itself is
     never drawn here: #121212 is the background layer and the logo is the
     foreground layer. -->
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
""",
        encoding="utf-8",
    )
    print("  mipmap-anydpi-v26: ic_launcher.xml")

    values = res / "values"
    values.mkdir(parents=True, exist_ok=True)
    (values / "ic_launcher_background.xml").write_text(
        """<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#121212</color>
</resources>
""",
        encoding="utf-8",
    )
    print("  values: ic_launcher_background.xml")


def write_macos(logo):
    iconset = REPO / "macos/Runner/Assets.xcassets/AppIcon.appiconset"
    for size in (16, 32, 64, 128, 256, 512, 1024):
        macos_icon(logo, size).save(iconset / f"app_icon_{size}.png")
    print(f"  {iconset.relative_to(REPO)}: app_icon_{{16..1024}}.png")


def _png_bytes(image):
    buffer = io.BytesIO()
    image.save(buffer, format="PNG")
    return buffer.getvalue()


def _write_ico(path, images):
    """Write an ICO by hand so every entry is a premultiplied resize."""
    # Icon resource header, then one 16-byte directory entry per size, then the
    # PNG payloads. Windows picks the entry that fits the current DPI best.
    header = struct.pack("<HHH", 0, 1, len(images))
    offset = len(header) + 16 * len(images)
    directory = bytearray()
    payload = bytearray()
    for image in images:
        size = image.width
        data = _png_bytes(image)
        directory += struct.pack(
            "<BBBBHHII",
            0 if size >= 256 else size,
            0 if size >= 256 else size,
            0,  # no palette
            0,  # reserved
            1,  # colour planes
            32,  # bits per pixel
            len(data),
            offset + len(payload),
        )
        payload += data
    path.write_bytes(header + bytes(directory) + bytes(payload))
    print(f"  {path.relative_to(REPO)}")


ICO_SIZES = [16, 24, 32, 48, 64, 128, 256]


def write_windows(logo):
    path = REPO / "windows/runner/resources/app_icon.ico"
    _write_ico(path, [_resize_rgba(logo, (size, size)) for size in ICO_SIZES])


def write_tray_windows(logo):
    """The Windows tray icon: the same full-bleed mark as the PNG trays."""
    path = REPO / "assets/tray/app_icon.ico"
    mark = _mark(logo)
    _write_ico(path, [_fit_mark(mark, size) for size in ICO_SIZES])


def write_linux(logo):
    path = REPO / "linux/runner/resources/app_icon.png"
    path.parent.mkdir(parents=True, exist_ok=True)
    logo.save(path)
    print(f"  {path.relative_to(REPO)}")


def tray_icon(logo, size):
    """The mark filling the whole canvas; the tray host picks the size."""
    scaled = size * SUPERSAMPLE
    canvas = Image.new("RGBA", (scaled, scaled), (0, 0, 0, 0))
    _compose(canvas, _fit_mark(_mark(logo), scaled))
    return _resize_rgba(canvas, (size, size))


def write_tray(logo):
    path = REPO / "assets/tray/app_icon_256.png"
    path.parent.mkdir(parents=True, exist_ok=True)
    tray_icon(logo, TRAY_SIZE).save(path)
    print(f"  {path.relative_to(REPO)}")


def main():
    logo_path = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else DEFAULT_LOGO
    if not logo_path.is_file():
        sys.exit(f"Logo not found: {logo_path}")

    logo = Image.open(logo_path).convert("RGBA")
    print(f"Generating icons from {logo_path} ({logo.width}x{logo.height})")

    write_windows(logo)
    write_linux(logo)
    write_android(logo)
    write_macos(logo)
    write_tray(logo)
    write_tray_windows(logo)


if __name__ == "__main__":
    main()
