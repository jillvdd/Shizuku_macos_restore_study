#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""render_leaf_test.py — 用 CN 字库按"叶码=槽位(identity)"渲染 SCN 消息, 存 PGM 供目测。
用法:
  python3 render_leaf_test.py --scn SCN001.DAT --msg 0 --out /tmp/t.pgm
"""
import sys, os, glob, struct, argparse
sys.path.insert(0, "/Users/abc/Documents/shizuku_macos_experience")
import shizuku_cli.cmd_text as ct

FONT = "/Users/abc/Documents/shizuku_macos_experience/research/extracted/cn_KNJ_ALL.KNJ"
SC = 2  # 放大倍数


def glyph_rows(slot, font, ng):
    if slot < 0 or slot >= ng:
        return None
    g = font[slot * 72:slot * 72 + 72]
    rows = []
    for r in range(24):
        b0, b1, b2 = g[r * 3], g[r * 3 + 1], g[r * 3 + 2]
        px = []
        for bit in range(24):
            byte = b0 if bit < 8 else (b1 if bit < 16 else b2)
            px.append((byte >> (7 - (bit % 8))) & 1)
        rows.append(px)
    return rows


def leaf_stream(data):
    out = []
    i = 0
    while i < len(data):
        c = data[i]
        if c & 0x80:
            out.append(('L', ((c & 0x7f) << 8) | data[i + 1]))
            i += 2
        else:
            out.append(('C', c))
            i += 1
    return out


def render(cells, font, ng, maxch=80, scale=SC):
    W = 24 * scale
    H = 24 * scale
    canvas = [[0] * (len(cells[:maxch]) * W) for _ in range(H + 8)]
    for ci, (kind, code) in enumerate(cells[:maxch]):
        if kind != 'L':
            continue
        rows = glyph_rows(code, font, ng)
        if rows is None:
            continue
        ox = ci * W
        for r in range(24):
            for cx in range(24):
                if rows[r][cx]:
                    for sy in range(scale):
                        for sx in range(scale):
                            canvas[4 + r * scale + sy][ox + cx * scale + sx] = 255
    return canvas


def save_pgm(canvas, path):
    h = len(canvas)
    w = len(canvas[0])
    with open(path, 'wb') as f:
        f.write(b"P5\n%d %d\n255\n" % (w, h))
        for row in canvas:
            f.write(bytes(row))
    print("wrote %s  (%dx%d)" % (path, w, h))


def decode_msgs(raw):
    """Return list of raw (LZS-decoded) message byte-streams, one per message."""
    msgs = []
    mo = struct.unpack_from('<H', raw, 2)[0] * 0x10
    if mo < 16 or mo >= len(raw) - 4:
        return msgs
    ms = struct.unpack_from('<I', raw, mo)[0]
    md = ct.lzs_decode_inv(raw[mo + 4:mo + 4 + ms])
    if len(md) < 2:
        return msgs
    last = struct.unpack_from('<H', md, 0)[0]
    tbl = struct.unpack_from('<%dH' % (last + 1), md, 2)
    for off in tbl:
        if off < len(md):
            msgs.append(md[off:])
    return msgs


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument('--scn', required=True)
    ap.add_argument('--out', required=True)
    ap.add_argument('--max', type=int, default=80)
    ap.add_argument('--msg', type=int, default=0)
    args = ap.parse_args(argv)
    font = open(FONT, 'rb').read()
    ng = len(font) // 72
    raw = open(args.scn, 'rb').read()
    msgs = decode_msgs(raw)
    if args.msg >= len(msgs):
        print("msg %d out of range (n=%d)" % (args.msg, len(msgs)))
        return 1
    cells = leaf_stream(msgs[args.msg])
    canvas = render(cells, font, ng, args.max)
    save_pgm(canvas, args.out)
    # also upscale to PNG via sips for the Read tool
    os.system("sips -s format png %s --out %s.png >/dev/null 2>&1" % (args.out, args.out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
