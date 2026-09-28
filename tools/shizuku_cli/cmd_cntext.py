"""
cmd_cntext — extract Chinese text from SCN scripts (identity mapping)

CN 汉化 = 纯字库内容替换。SCN 脚本与 JP byte-identical（叶码 1..1851 不变），
CN 团队重建了 cn_KNJ_ALL.KNJ 使 slot N = leaf 码 N 直接存中文字形。
引擎渲染 = font[leaf_code]，不存在运行时叶码→槽位表（见 memory shizuku-leaf-identity）。

本命令复用 cmd_disasm 的 LZS 解码 + 叶码公式，然后：
  - 用 CN 字库 identity 渲染每个叶码为中文字形（column-major 布局，bit7=最左像素）
  - 输出 SVG（HTML 可读）便于人工校验
  - 可选输出 Unicode 文本（需 slot→char 表，默认给出未知码点）

用法:
  python3 -m shizuku_cli cntext SCN001.DAT --font research/extracted/cn_KNJ_ALL.KNJ --out /tmp/cn.svg
"""

import sys
import os

pkg_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if pkg_dir not in sys.path:
    sys.path.insert(0, pkg_dir)

import argparse
import struct

from shizuku_cli.cmd_disasm import lzs_decode_inv, TEXT_CMDS

# 与 knj.render_ascii 一致的布局常量（确保来源唯一）
GLYPH_SIZE = 72   # 24 行 x 3 列
COLS = 3
ROWS = 24


def glyph_pixels(font: bytes, slot: int):
    """返回 24x24 像素矩阵 (list[list[int]] 0/1)，column-major 布局，bit7=最左。"""
    base = slot * GLYPH_SIZE
    if base + GLYPH_SIZE > len(font):
        return None
    out = []
    for row in range(ROWS):
        line = []
        for col in range(COLS):
            b = font[base + col * ROWS + row]
            for bit in range(7, -1, -1):
                line.append((b >> bit) & 1)
        out.append(line)
    return out


def leaf_stream(data: bytes):
    """分解为 leaf 码序列（保留 0=全角空格，丢弃控制字符）。"""
    out = []
    i = 0
    while i < len(data):
        c = data[i]
        if c & 0x80:
            if i + 1 >= len(data):
                break
            out.append(((c & 0x7f) << 8) | data[i + 1])
            i += 2
        elif c == 0x00:
            out.append(0)          # 全角空格
            i += 1
        else:
            ch = chr(c)
            if ch == '$':
                break              # MSG_END
            # 其余控制字符（分页/等待键/换行/速度等）不产出图形
            i += 1
    return out


def decode_messages(raw: bytes):
    """返回 list of leaf-code lists，对应每个消息。"""
    if len(raw) < 4:
        return []
    mo = struct.unpack_from('<H', raw, 2)[0] * 0x10
    if mo < 16 or mo >= len(raw) - 4:
        return []
    ms = struct.unpack_from('<I', raw, mo)[0]
    if mo + 4 + ms > len(raw):
        ms = len(raw) - (mo + 4)
    md = lzs_decode_inv(raw[mo + 4:mo + 4 + ms])
    if len(md) < 2:
        return []
    last = struct.unpack_from('<H', md, 0)[0]
    tbl = struct.unpack_from('<%dH' % (last + 1), md, 2)
    msgs = []
    for off in tbl:
        if off < len(md):
            msgs.append(leaf_stream(md[off:]))
    return msgs


def slot_to_glyph(font: bytes, leaf: int, scale: int = 1):
    """leaf 码 -> SVG path 的像素串（identity：slot=leaf）。"""
    px = glyph_pixels(font, leaf)
    if px is None:
        return None
    w = COLS * 8
    rects = []
    for row in range(ROWS):
        for col in range(w):
            if px[row][col]:
                rects.append((col * scale, row * scale, scale, scale))
    return rects


def render_message_svg(font: bytes, leaves, scale: int = 3, cpl: int = 26):
    """把一个消息的叶码渲染成 SVG，按每行 cpl 字换行。"""
    w = COLS * 8 * scale + 4
    lines = []
    for i in range(0, len(leaves), cpl):
        lines.append(leaves[i:i + cpl])
    cell = (COLS * 8 + 1) * scale
    height = len(lines) * (ROWS * scale + 6) + 8
    parts = ['<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d">' % (cpl * cell + 8, height)]
    parts.append('<rect width="100%%" height="100%%" fill="#fff"/>')
    parts.append('<g fill="#000">')
    for li, ln in enumerate(lines):
        y0 = 8 + li * (ROWS * scale + 6)
        for ci, leaf in enumerate(ln):
            if leaf == 0:
                continue
            rects = slot_to_glyph(font, leaf, scale)
            if not rects:
                continue
            x0 = 8 + ci * cell
            for (cx, cy, cw, ch) in rects:
                parts.append('<rect x="%d" y="%d" width="%d" height="%d"/>' % (x0 + cx, y0 + cy, cw, ch))
    parts.append('</g></svg>')
    return '\n'.join(parts)


def main(args):
    parser = argparse.ArgumentParser(description='Extract Chinese text from SCN (identity, CN font)')
    parser.add_argument('files', nargs='+', help='SCN*.DAT files')
    parser.add_argument('--font', default='research/extracted/cn_KNJ_ALL.KNJ', help='CN KNJ font')
    parser.add_argument('--out', help='Write SVG to file (per-file appended, msg-separated)')
    parser.add_argument('--msg', type=int, default=None, help='Only this message index')
    args = parser.parse_args(args)

    font = open(args.font, 'rb').read()
    buf = []

    for path in args.files:
        raw = open(path, 'rb').read()
        msgs = decode_messages(raw)
        for idx, leaves in enumerate(msgs):
            if args.msg is not None and idx != args.msg:
                continue
            svg = render_message_svg(font, leaves)
            buf.append('<!-- %s msg[%d] leaves=%d -->\n%s' % (os.path.basename(path), idx, len(leaves), svg))
            print('%s msg[%d]: %d leaf codes' % (os.path.basename(path), idx, len(leaves)))

    text = '\n'.join(buf)
    if args.out:
        open(args.out, 'w').write(text)
        print('wrote %s' % args.out)
    else:
        sys.stdout.write(text)


if __name__ == '__main__':
    main(sys.argv[1:])
