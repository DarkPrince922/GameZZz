#!/usr/bin/env python3
"""Verify the CI screenshots are real renders, not blank frames.

For every PNG in the given directory we require:
  * a non-trivial size,
  * a luminance standard deviation above a threshold (a solid fill is blank),
  * a minimum number of distinct colours (flat rectangles still vary a lot).
Fails with a non-zero exit code otherwise, so the screenshots job goes red.
"""
import glob
import os
import sys

from PIL import Image

MIN_STDDEV = 12.0
MIN_DISTINCT = 16
MIN_AREA = 320 * 240


def check(path: str) -> None:
    with Image.open(path) as im:
        im = im.convert("RGB")
        if im.width * im.height < MIN_AREA:
            raise SystemExit("blank: %s is too small (%dx%d)" % (path, im.width, im.height))
        pixels = list(im.getdata())
        n = len(pixels)
        mean = sum(r + g + b for r, g, b in pixels) / (3 * n)
        variance = sum(((r - mean) ** 2 + (g - mean) ** 2 + (b - mean) ** 2) for r, g, b in pixels) / (3 * n)
        stddev = variance ** 0.5
        distinct = len(set(pixels))
        if stddev < MIN_STDDEV:
            raise SystemExit("blank: %s has luminance stddev %.1f < %.1f" % (path, stddev, MIN_STDDEV))
        if distinct < MIN_DISTINCT:
            raise SystemExit("blank: %s has only %d distinct colours" % (path, distinct))
        print("ok: %s stddev=%.1f colours=%d" % (os.path.basename(path), stddev, distinct))


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: check_shots.py <dir>", file=sys.stderr)
        return 2
    directory = sys.argv[1]
    files = sorted(glob.glob(os.path.join(directory, "*.png")))
    if not files:
        print("error: no PNG files in %s" % directory, file=sys.stderr)
        return 1
    for path in files:
        check(path)
    print("checked %d screenshots" % len(files))
    return 0


if __name__ == "__main__":
    sys.exit(main())
