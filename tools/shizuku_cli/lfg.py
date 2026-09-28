"""
lfg — LEAFCODE image format parser and renderer

Reference: mglvns lfg.c (L97-125), lfview lfgdec.c (L185-209, L423-461).
Semantics fixed 2026-09-23 after the release audit cross-validated this
against ShizukuCore/Lfg.swift byte-for-byte (195/195 retail LFGs):
  - palette: 24 bytes -> 48 nibbles (hi then lo per byte), color-major, n*17
  - each body byte splits by bit-pairs, NOT nibbles:
    pix1 = bits 7,5,3,1 ; pix2 = bits 6,4,2,0
  - VERTICAL = column-pair major (pix1/pix2 side by side, y advances,
    y overflow -> x += 2); HORIZONTAL = row-major two pixels per step
  - LZS matches straddling the declared tail clamp instead of overrunning
"""

import struct
from dataclasses import dataclass
from typing import List, Tuple, Optional

MAGIC = b"LEAFCODE"

@dataclass
class LFGHeader:
    palette: List[Tuple[int, int, int]]  # 16 RGB colors
    xoffset: int  # pixels, in units of 8
    yoffset: int
    width: int  # canvas width in pixels
    height: int
    direction: int  # 0 = VERTICAL column-major, else HORIZONTAL
    transparent: int  # 0xff = none
    content_width: int  # width - xoffset
    content_height: int  # height - yoffset

def lzs_decode(src: bytes, out_size: int) -> bytes:
    """leafpack_lzs: LZSS with 0x1000 ring buffer, no inverted flag bits.
    Flag byte is consumed MSB-first by left-shifting (lfgdec.c), one bit per
    token; match runs clamp at the declared output size."""
    out = bytearray(out_size)
    ring = bytearray(0x1000)
    i = 0
    s = 0
    c = 0
    m = 0xFEE
    flag = 0
    while i < out_size:
        c -= 1
        if c < 0:
            flag = src[s]
            s += 1
            c = 7
        if flag & 0x80:
            b = src[s]
            s += 1
            out[i] = ring[m] = b
            m = (m + 1) & 0xFFF
            i += 1
        else:
            d = src[s] + (src[s + 1] << 8)
            s += 2
            ln = (d & 0xF) + 3
            pos = d >> 4
            for _ in range(ln):
                b = ring[pos]
                pos = (pos + 1) & 0xFFF
                out[i] = ring[m] = b
                m = (m + 1) & 0xFFF
                i += 1
                if i >= out_size:
                    break   # lfgdec.c's calloc buffer just stops; don't overrun
        flag = (flag << 1) & 0xFF
    return bytes(out)

def _spread_hi(p: int) -> int:   # bits 7,5,3,1 -> 4-bit index (lfg.c)
    return ((p & 0x80) >> 4) | ((p & 0x20) >> 3) | ((p & 0x08) >> 2) | ((p & 0x02) >> 1)

def _spread_lo(p: int) -> int:   # bits 6,4,2,0 -> 4-bit index
    return ((p & 0x40) >> 3) | ((p & 0x10) >> 2) | ((p & 0x04) >> 1) | (p & 0x01)

def parse_header(data: bytes) -> LFGHeader:
    """Parse LFG header and return metadata."""
    if data[:8] != MAGIC:
        raise ValueError(f"Not LEAFCODE magic: {data[:8]!r}")

    # Palette: 24 bytes -> 48 nibbles (hi, lo per byte), color-major, n*17.
    nib: List[int] = []
    for b in data[8:32]:
        nib.append((b >> 4) * 17)
        nib.append((b & 0xF) * 17)
    palette = [(nib[3 * k], nib[3 * k + 1], nib[3 * k + 2]) for k in range(16)]

    xoffset = struct.unpack_from('<H', data, 32)[0] * 8
    yoffset = struct.unpack_from('<H', data, 34)[0]
    width = (struct.unpack_from('<H', data, 36)[0] + 1) * 8
    height = struct.unpack_from('<H', data, 38)[0] + 1
    direction = data[40]
    transparent = data[41]
    comp_size = struct.unpack_from('<I', data, 44)[0]

    return LFGHeader(
        palette=palette,
        xoffset=xoffset,
        yoffset=yoffset,
        width=width,
        height=height,
        direction=direction,
        transparent=transparent,
        content_width=width - xoffset,
        content_height=height - yoffset
    )

def decode(data: bytes) -> Tuple[List[Tuple[int, int, int, int]], int, int]:
    """
    Decode LFG to RGBA pixels.
    Returns (pixels, width, height) where pixels is a flat RGBA list.
    Pixels outside the content (and the transparent index) are (0,0,0,0).
    """
    header = parse_header(data)
    comp_size = struct.unpack_from('<I', data, 44)[0]
    raw = lzs_decode(data[48:], comp_size)

    cw = header.content_width
    ch = header.content_height
    if cw <= 0 or ch <= 0:
        raise ValueError(f"bad LFG content size {cw}x{ch}")

    # Fill the content-space index map first (lfg.c L97-125).
    idx = bytearray(cw * ch)
    if header.direction == 0:  # VERTICAL: column-pair major
        x = 0
        y = 0
        for p in raw:
            if y >= ch or x + 1 >= cw:
                break
            idx[cw * y + x] = _spread_hi(p)
            idx[cw * y + x + 1] = _spread_lo(p)
            y += 1
            if y >= ch:
                y = 0
                x += 2
    else:                      # HORIZONTAL: row-major, two pixels per step
        pos = 0
        for p in raw:
            if pos + 1 >= len(idx):
                break
            idx[pos] = _spread_hi(p)
            idx[pos + 1] = _spread_lo(p)
            pos += 2

    trans = header.transparent
    canvas = [[0, 0, 0, 0] for _ in range(header.width * header.height)]
    pal = header.palette
    ox, oy = header.xoffset, header.yoffset
    for cy in range(ch):
        row = (oy + cy) * header.width + ox
        for cx in range(cw):
            p = idx[cy * cw + cx]
            if p == trans:
                continue
            c = pal[p]
            canvas[row + cx] = [c[0], c[1], c[2], 255]

    canvas = [tuple(px) for px in canvas]
    return canvas, header.width, header.height

def render_png(pixels: List[Tuple[int, int, int, int]], width: int, height: int) -> bytes:
    """Render RGBA pixels to PNG bytes (pure stdlib)."""
    import zlib

    def chunk(tag: bytes, data: bytes) -> bytes:
        crc = zlib.crc32(tag + data) & 0xFFFFFFFF
        return struct.pack('>I', len(data)) + tag + data + struct.pack('>I', crc)

    sig = b'\x89PNG\r\n\x1a\n'
    ihdr = struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0)

    raw = b''
    for y in range(height):
        raw += b'\x00'  # filter byte
        for x in range(width):
            px = pixels[y * width + x]
            raw += bytes(px[:3]) + bytes([px[3] if len(px) > 3 else 255])

    return sig + chunk(b'IHDR', ihdr) + chunk(b'IDAT', zlib.compress(raw)) + chunk(b'IEND', b'')
