#!/usr/bin/env python3
"""
shizuku-knj-font.py — Leaf KNJ 24x24 dot-matrix font -> ASCII preview / PNG atlas
==================================================================================
KNJ is Leaf's full-width 24x24 1bpp bitmap font used by the LVNS engine
(雫, ToHeart, Kizuato, ...).

Layout (verified against research/extracted/KNJ_ALL.KNJ and cn_KNJ_ALL.KNJ):
    - 1852 glyphs, each 24x24 1bpp MSB-first = 24 rows x 3 bytes = 72 B.
    - Total 1852 * 72 = 133,344 B (exact file size of both JP and CN fonts).
    - Glyphs are stored consecutively starting at slot 0, one byte per row's
      3-byte group: bit 7..0 of the first byte covers pixels 0..7, second
      byte covers 8..15, third byte covers 16..23. Bit 7 = leftmost pixel.

Commands:
    shizuku-knj-font.py preview <KNJ> <slot> <count> [--ascii]
        Render `count` glyphs starting at slot `slot` as ASCII art.
        '#' = pixel set, '.' = pixel clear.
        --ascii  also label each glyph with "G<slot>:" headers (default is a
                 compact side-by-side rendering when multiple glyphs fit).

    shizuku-knj-font.py atlas <KNJ> <out.png>
        Arrange all 1852 glyphs into a single PNG atlas. Default grid is
        64 columns x 29 rows, each glyph 24x24 scaled x2 to 48x48, drawn
        black-on-white. Use --scale, --grid-w, --grid-h, --bg/--fg to tweak.

Pure Python stdlib (zlib+struct), no third-party dependencies.
"""

import struct
import sys
import zlib

GLYPH_W = 24
GLYPH_H = 24
GLYPH_BYTES = GLYPH_W // 8 * GLYPH_H  # 72
NUM_GLYPHS = 1852
TOTAL_BYTES = NUM_GLYPHS * GLYPH_BYTES  # 133344


# --------------------------------------------------------------------------
def decode_glyph(data: bytes, slot: int):
    """Return a 24x24 list of 0/1 ints (row-major) for glyph `slot`."""
    off = slot * GLYPH_BYTES
    rows = []
    for r in range(GLYPH_H):
        b0, b1, b2 = data[off + r * 3], data[off + r * 3 + 1], data[off + r * 3 + 2]
        row = []
        for b in (b0, b1, b2):
            for bit in range(7, -1, -1):
                row.append((b >> bit) & 1)
        rows.append(row)
    return rows


def glyph_to_ascii(rows, on="#", off="."):
    return "\n".join("".join(on if px else off for px in row) for row in rows)


# --------------------------------------------------------------------------
def write_png(path, w, h, rgba_rows):
    raw = bytearray()
    for row in rgba_rows:
        raw.append(0)  # filter None
        raw += row

    def chunk(typ, payload):
        return (
            struct.pack(">I", len(payload))
            + typ
            + payload
            + struct.pack(">I", zlib.crc32(typ + payload) & 0xFFFFFFFF)
        )

    ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)  # 8-bit RGBA
    png = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", ihdr)
        + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        + chunk(b"IEND", b"")
    )
    with open(path, "wb") as f:
        f.write(png)


# --------------------------------------------------------------------------
def cmd_preview(argv):
    knj_path = argv[1]
    slot = int(argv[2], 0)
    count = int(argv[3], 0)
    ascii_mode = "--ascii" in argv

    with open(knj_path, "rb") as f:
        data = f.read()
    _check_len(data)

    if slot + count > NUM_GLYPHS:
        sys.stderr.write(
            "warning: slot+count exceeds %d glyphs; truncating\n" % NUM_GLYPHS
        )
        count = min(count, NUM_GLYPHS - slot)

    if ascii_mode:
        for g in range(count):
            print("G%d:" % (slot + g))
            print(glyph_to_ascii(decode_glyph(data, slot + g)))
            print()
    else:
        # compact: stack glyphs vertically, 3 glyphs per row
        glyphs = [decode_glyph(data, slot + g) for g in range(count)]
        for start in range(0, count, 3):
            chunk_g = glyphs[start : start + 3]
            print("--- slots %d..%d ---" % (slot + start, slot + start + len(chunk_g) - 1))
            for y in range(GLYPH_H):
                parts = []
                for g in chunk_g:
                    parts.append(
                        "".join("#" if px else "." for px in g[y]) + "  "
                    )
                print("".join(parts))
            print()
    return 0


# --------------------------------------------------------------------------
def cmd_atlas(argv):
    knj_path = argv[1]
    out_path = argv[2]

    scale = 2
    grid_w = 64
    grid_h = 29
    fg = (0, 0, 0)       # glyph color
    bg = (255, 255, 255)  # background color

    args = list(argv[3:])
    i = 0
    while i < len(args):
        a = args[i]
        if a == "--scale" and i + 1 < len(args):
            scale = int(args[i + 1]); i += 2
        elif a == "--grid-w" and i + 1 < len(args):
            grid_w = int(args[i + 1]); i += 2
        elif a == "--grid-h" and i + 1 < len(args):
            grid_h = int(args[i + 1]); i += 2
        elif a == "--fg" and i + 1 < len(args):
            fg = tuple(int(args[i + 1][j : j + 2], 16) for j in (0, 2, 4)); i += 2
        elif a == "--bg" and i + 1 < len(args):
            bg = tuple(int(args[i + 1][j : j + 2], 16) for j in (0, 2, 4)); i += 2
        else:
            sys.stderr.write("unknown option: %s\n" % a)
            return 2

    with open(knj_path, "rb") as f:
        data = f.read()
    _check_len(data)

    if grid_w * grid_h < NUM_GLYPHS:
        sys.stderr.write(
            "error: %dx%d grid too small for %d glyphs\n"
            % (grid_w, grid_h, NUM_GLYPHS)
        )
        return 2

    cell = GLYPH_W * scale
    w = grid_w * cell
    h = grid_h * cell

    canvas = [[bg for _ in range(w)] for _ in range(h)]

    for g in range(NUM_GLYPHS):
        rows = decode_glyph(data, g)
        cx = (g % grid_w) * cell
        cy = (g // grid_w) * cell
        for yy in range(GLYPH_H):
            for xx in range(GLYPH_W):
                if rows[yy][xx]:
                    for dy in range(scale):
                        for dx in range(scale):
                            canvas[cy + yy * scale + dy][cx + xx * scale + dx] = fg

    rows_rgba = []
    for y in range(h):
        row = bytearray(w * 4)
        for x in range(w):
            r, g, b = canvas[y][x]
            row[x * 4] = r
            row[x * 4 + 1] = g
            row[x * 4 + 2] = b
            row[x * 4 + 3] = 255
        rows_rgba.append(bytes(row))

    write_png(out_path, w, h, rows_rgba)
    print(
        "wrote %s (%dx%d, grid %dx%d, scale %d, fg=%02x%02x%02x bg=%02x%02x%02x)"
        % (
            out_path, w, h, grid_w, grid_h, scale,
            fg[0], fg[1], fg[2], bg[0], bg[1], bg[2],
        )
    )
    return 0


# --------------------------------------------------------------------------
def _check_len(data):
    if len(data) < TOTAL_BYTES:
        raise SystemExit(
            "file too small: %d bytes, expected >= %d for %d glyphs"
            % (len(data), TOTAL_BYTES, NUM_GLYPHS)
        )
    if len(data) != TOTAL_BYTES:
        sys.stderr.write(
            "note: file is %d bytes (%d extra beyond %d glyphs)\n"
            % (len(data), len(data) - TOTAL_BYTES, NUM_GLYPHS)
        )


# --------------------------------------------------------------------------
def main(argv):
    if len(argv) < 2 or argv[1] not in ("preview", "atlas"):
        print(__doc__)
        return 2

    cmd = argv[1]
    rest = argv[2:]
    if cmd == "preview" and len(rest) >= 3:
        return cmd_preview(["preview"] + rest)
    if cmd == "atlas" and len(rest) >= 2:
        return cmd_atlas(["atlas"] + rest)

    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
