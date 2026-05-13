#!/usr/bin/env python3
"""Compute the accent color for a wallpaper, mirroring Main.qml's color extractor.

Usage: extract-accent.py <image-path>
Output: hex color (e.g. "#A9C78F") on stdout.
"""
import sys
import colorsys
from PIL import Image


def extract(path: str) -> str:
    img = Image.open(path).convert("RGB").resize((60, 60))
    pixels = list(img.getdata())

    histogram = [0.0] * 36
    sample_colors: list = [None] * 36
    vibrant = False

    for r, g, b in pixels:
        h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
        if s > 0.3 and v > 0.15:
            idx = int((h * 360) // 10) % 36
            weight = s * v
            histogram[idx] += weight
            if sample_colors[idx] is None or weight > sample_colors[idx][1]:
                sample_colors[idx] = ((h, s, v), weight)
            vibrant = True

    if not vibrant:
        avg = sum(
            0.299 * r / 255 + 0.587 * g / 255 + 0.114 * b / 255 for r, g, b in pixels
        ) / len(pixels)
        return "#D0D0D0" if avg < 0.5 else "#404040"

    # Merge red wrap (350-360 and 0-10)
    histogram[0] += histogram[35]

    # Find the mode (loop matches QML: indices 0..34, bucket 35 already merged)
    winner = max(range(35), key=lambda i: histogram[i])
    if sample_colors[winner] is None:
        return "#D0D0D0"

    h, s, _ = sample_colors[winner][0]
    s = max(0.35, min(0.55, s * 0.9))
    r, g, b = colorsys.hsv_to_rgb(h, s, 0.95)
    return "#{:02X}{:02X}{:02X}".format(int(r * 255), int(g * 255), int(b * 255))


if __name__ == "__main__":
    print(extract(sys.argv[1]))
