#!/usr/bin/env python3
"""
shizuku-lfg-image.py — LEAFCODE LFG image -> PNG converter
===========================================================
Converts Leaf's proprietary LFG image format (used by 雫 / ToHeart / Kizuato,
and generally by the LVNS engine) to a standard PNG. Pure Python stdlib.

Format (validated against research/extracted/HVS01.LFG and all 195 *.LFG):
    0..7     "LEAFCODE" magic
    8..31    24 B palette (16 colors x 3 channels, 4-bit packed, 6 B/color)
             Each byte holds two nibbles; each nibble is expanded to 8 bit
             via `nibble | nibble << 4`. Channel order RG BR GB RG BR ...
             (= little-endian R,G,B triplets packed 4-bit per channel)
    32..33   u16 xoffset  (in units of 8 px; note: LITTLE-endian on disk,
             verified against mglvns lfg.c: `data[33]<<8 | data[32]`)
    34..35   u16 yoffset  (LITTLE-endian, plain px)
    36..37   u16 width    = (value + 1) * 8     (LITTLE-endian)
    38..39   u16 height   = value + 1            (LITTLE-endian)
    40       direction    (0 = VERTICAL column-major, else HORIZONTAL)
    41       transparent color index (0xff = none)
    42..43   reserved
    44..47   u32 LE decompressed pixel byte count (size = rwidth*rheight/2)
    48..     LZS-compressed pixel data -> leafpack_lzs decompresses to `size`
             bytes, each holding two 4-bit pixels (high nibble first)

Compression is the classic LZSS variant `leafpack_lzs` (ring buffer 0x1000,
window start 0xfee, NO inverted flag bits). It is NOT the inverted-flag
`leafpack_lzs3` used by kizuato_op.c — do not swap the two.

Pixels are expanded into a row-major rwidth x rheight array (row stride =
rwidth). This matches both the reference decoders (mglvns lfg.c and lfview
lfgdec.c write q[rwidth*y+x]) and the engine's screen blit, which walks the
array row-major with stride rwidth (mglvns lvnsimage_copy_to_sximage). Using
rheight as the stride would transpose the image and overflow the buffer for
tall sprites (rw < rh), e.g. the MAX_Cxx character images.

NOTE: research/preview/preview_hvs01.png and preview_leaf.png were generated
with a transposed stride (LFGBMP.EXE-style rheight indexing). They match this
tool only in size and rough color distribution, not pixel-for-pixel. The
reference C engine code above is authoritative for the real game layout.

The pixel data is the image CONTENT only (rwidth x rheight = width - xoffset
by height - yoffset). To produce the final image, the content is blitted at
(xoffset, yoffset) onto a width x height canvas; pixels outside the blitted
area stay transparent. Stand-alone chara sprites (MAX_Cxx) carry nonzero
offsets so the caller places them on screen; full-screen backgrounds (HVSxx,
VISxx, MAX_Sxx, NEXTxx) have zero offset.

Usage:
    python3 shizuku-lfg-image.py <in.LFG> <out.png> [--keep-offset-canvas]

    --keep-offset-canvas   render on the full width x height canvas with the
                           content blitted at its xoffset/yoffset (matches how
                           the engine composes). Default is to output only the
                           rwidth x rheight content rectangle, which is what
                           you want for inspecting a single sprite.
"""

import struct
import sys
import zlib

MAGIC = b"LEAFCODE"


# --------------------------------------------------------------------------
# LZS decompression (leafpack_lzs, non-inverted flag bits)
# --------------------------------------------------------------------------
def lzs_decode(src: bytes, out_size: int) -> bytes:
    """leafpack_lzs: LZSS with 0x1000-byte ring buffer, no inverted flag bits.

    Ported 1:1 from mglvns `leafpack.c` leafpack_lzs() by Go Watanabe.
    `out_size` is the exact expected output length (LFG header field 44..47).
    """
    out = bytearray(out_size)
    ring = bytearray(0x1000)
    m = 0xFEE  # next ring write position
    c = 0      # flag bits remaining in the current flag byte
    flag = 0
    i = 0      # source index
    s = 0      # output index
    while i < out_size:
        c -= 1
        if c < 0:
            flag = src[s]
            s += 1
            c = 7
        if flag & 0x80:
            # literal byte
            b = src[s]
            s += 1
            out[i] = b
            ring[m] = b
            m &= 0xFFF
            i += 1
        else:
            # copy from ring buffer
            d = src[s] + (src[s + 1] << 8)
            s += 2
            ln = (d & 0x0F) + 3
            pos = d >> 4
            for _ in range(ln):
                b = ring[pos]
                out[i] = b
                ring[m] = b
                m &= 0xFFF
                pos &= 0xFFF
                i += 1
        flag = (flag << 1) & 0xFF
    return bytes(out)


# --------------------------------------------------------------------------
# LFG parsing / decoding
# --------------------------------------------------------------------------
def decode_lfg(data: bytes):
    """Return dict with palette, index pixels, geometry and transparency."""
    if data[:8] != MAGIC:
        raise ValueError("not a LEAFCODE file (magic=%r)" % data[:8])

    # --- palette: 24 bytes, 4-bit per channel, LE R,G,B triplets ----------
    pal_vals = []
    for b in data[8:32]:
        hi = b >> 4
        lo = b & 0x0F
        pal_vals.append((hi << 4) | hi)
        pal_vals.append((lo << 4) | lo)
    palette = [tuple(pal_vals[i:i + 3]) for i in range(0, 48, 3)]

    # --- geometry (LITTLE-endian, despite docs calling it BE) -------------
    xoff = struct.unpack("<H", data[32:34])[0] * 8
    yoff = struct.unpack("<H", data[34:36])[0]
    width = (struct.unpack("<H", data[36:38])[0] + 1) * 8
    height = struct.unpack("<H", data[38:40])[0] + 1
    direction = data[40]
    transparent = data[41]
    size = struct.unpack("<I", data[44:48])[0]

    rwidth = width - xoff
    rheight = height - yoff
    if size != rwidth * rheight // 2:
        raise ValueError(
            "size %d != rwidth*rheight/2 = %d (w=%d h=%d xoff=%d yoff=%d)"
            % (size, rwidth * rheight // 2, width, height, xoff, yoff)
        )

    body = lzs_decode(data[48:], size)

    # --- expand 4-bit pixels ----------------------------------------------
    # IMPORTANT: the output array is row-major with row stride = rwidth
    # (not rheight). This is the layout the engine uses both when decoding
    # (lfg.c/lfgdec.c: q[rwidth * y + x]) and when blitting to screen
    # (mglvns lvnsimage_copy_to_sximage walks row-major with stride rwidth).
    # Using rheight as the stride would transpose images and overflow for
    # tall sprites (e.g. MAX_Cxx where rwidth < rheight), so never do that.
    idx = [0] * (rwidth * rheight)
    if direction == 0:  # VERTICAL: column-major, two pixels per column step
        x = 0
        y = 0
        for byte in body:
            pix1 = (
                ((byte & 0x80) >> 4)
                | ((byte & 0x20) >> 3)
                | ((byte & 0x08) >> 2)
                | ((byte & 0x02) >> 1)
            )
            pix2 = (
                ((byte & 0x40) >> 3)
                | ((byte & 0x10) >> 2)
                | ((byte & 0x04) >> 1)
                | (byte & 0x01)
            )
            idx[rwidth * y + x] = pix1
            idx[rwidth * y + x + 1] = pix2
            y += 1
            if y >= rheight:
                y = 0
                x += 2
    else:  # HORIZONTAL: row-major, two pixels per row step
        x = 0
        y = 0
        for byte in body:
            pix1 = (
                ((byte & 0x80) >> 4)
                | ((byte & 0x20) >> 3)
                | ((byte & 0x08) >> 2)
                | ((byte & 0x02) >> 1)
            )
            pix2 = (
                ((byte & 0x40) >> 3)
                | ((byte & 0x10) >> 2)
                | ((byte & 0x04) >> 1)
                | (byte & 0x01)
            )
            idx[rwidth * y + x] = pix1
            idx[rwidth * y + x + 1] = pix2
            x += 2
            if x >= rwidth:
                x = 0
                y += 1

    return {
        "palette": palette,
        "idx": idx,
        "width": width,
        "height": height,
        "xoff": xoff,
        "yoff": yoff,
        "rwidth": rwidth,
        "rheight": rheight,
        "direction": direction,
        "transparent": transparent,
    }


# --------------------------------------------------------------------------
# PNG writer (no external deps)
# --------------------------------------------------------------------------
def write_png(path, w, h, rgba_rows):
    """rgba_rows: iterable of w*h*4 byte strings (row-major)."""
    raw = bytearray()
    for row in rgba_rows:
        raw.append(0)  # filter type 0 (None)
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
def main(argv):
    if len(argv) < 3:
        print(__doc__)
        return 2

    in_path = argv[1]
    out_path = argv[2]
    keep_canvas = "--keep-offset-canvas" in argv

    with open(in_path, "rb") as f:
        data = f.read()

    lfg = decode_lfg(data)
    pal = lfg["palette"]
    trans = lfg["transparent"] if lfg["transparent"] < 16 else None

    if keep_canvas:
        w, h = lfg["width"], lfg["height"]
        xoff, yoff = lfg["xoff"], lfg["yoff"]
        rw, rh = lfg["rwidth"], lfg["rheight"]
        rows = []
        for y in range(h):
            row = bytearray(w * 4)
            # outside the blitted content -> transparent
            for x in range(w):
                row[x * 4 + 3] = 0
            if yoff <= y < yoff + rh:
                for x in range(rw):
                    idx = lfg["idx"][rw * (y - yoff) + x]
                    px = xoff + x
                    r, g, b = pal[idx]
                    row[px * 4] = r
                    row[px * 4 + 1] = g
                    row[px * 4 + 2] = b
                    row[px * 4 + 3] = 0 if idx == trans else 255
            rows.append(bytes(row))
        print("wrote %s (%dx%d, content at +%d+%d)" % (out_path, w, h, xoff, yoff))
    else:
        w, h = lfg["rwidth"], lfg["rheight"]
        idx = lfg["idx"]
        rows = []
        for y in range(h):
            row = bytearray(w * 4)
            base = y * w
            for x in range(w):
                ii = idx[base + x]
                r, g, b = pal[ii]
                row[x * 4] = r
                row[x * 4 + 1] = g
                row[x * 4 + 2] = b
                row[x * 4 + 3] = 0 if ii == trans else 255
            rows.append(bytes(row))
        print("wrote %s (%dx%d)" % (out_path, w, h))

    write_png(out_path, w, h, rows)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
