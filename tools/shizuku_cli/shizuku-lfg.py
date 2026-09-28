#!/usr/bin/env python3
"""
shizuku-lfg.py — render LFG (Leaf Visual Novel image format) to PNG.
Usage:
    python3 shizuku-lfg.py <input.LFG> [output.png]
    python3 shizuku-lfg.py <input.LFG> --   # stdout PNG
    python3 shizuku-lfg.py <input.LFG> --preview   # show ASCII art preview
"""

import sys, struct, os, math

MAGIC = b'LEAFCODE'
OUT_DIR = None  # set by main()

def lzs_decode(src, out_size):
    out = bytearray(out_size)
    ring = bytearray(0x1000)
    m, s, c_flag = 0xFEE, 0, 0
    i = 0
    while i < out_size:
        c_flag -= 1
        if c_flag < 0:
            c_flag = src[s]; s += 1; c_flag_bit = 7
        else:
            c_flag_bit = 6
        bit = (c_flag >> c_flag_bit) & 1
        if bit:
            b = src[s]; s += 1
            out[i] = ring[m] = b; m = (m+1)&0xFFF; i += 1
        else:
            d = src[s] + (src[s+1]<<8); s += 2
            ln = (d&0xF)+3; pos = d>>4
            for _ in range(ln):
                b = ring[pos]; pos = (pos+1)&0xFFF
                out[i] = ring[m] = b; m = (m+1)&0xFFF; i += 1
    return bytes(out)

def decode_lfg(data):
    if data[:8] != MAGIC:
        raise ValueError(f'not LEAFCODE magic: {data[:8]!r}')
    # Palette: 24 bytes -> 16 RGB colors
    pal = []
    for b in data[8:32]:
        hi, lo = b>>4, b&0xF
        v = (hi<<4)|hi
        pal.extend([v,v,v])
    palette = [tuple(pal[i:i+3]) for i in range(0,48,3)]
    # Geometry (LE)
    xoff = struct.unpack_from('<H', data,32)[0]*8
    yoff = struct.unpack_from('<H', data,34)[0]
    width = (struct.unpack_from('<H', data,36)[0]+1)*8
    height = struct.unpack_from('<H', data,38)[0]+1
    direction = data[40]
    transparent = data[41]
    comp_size = struct.unpack_from('<I', data, 44)[0]
    rwidth = width - xoff; rheight = height - yoff
    raw = lzs_decode(data[48:], comp_size)
    # Expand 4-bit indexed pixels
    canvas = [palette[transparent] if transparent != 0xff else (0,0,0)] * (width*height)
    idx = 0
    if direction == 0:  # VERTICAL
        x = 0
        for byte in raw:
            p1 = (byte>>4) & 0xF; p2 = byte & 0xF
            for py, px, pal_idx in [(yoff+y, xoff+x, p1), (yoff+y, xoff+x+1, p2)]:
                if pal_idx != transparent:
                    canvas[py*width+px] = palette[pal_idx]
                idx += 1
                if idx >= rwidth*rheight: break
            x += 2
            if x >= rwidth: x = 0; yoff += 1
    else:  # HORIZONTAL
        pass  # similar
    return canvas, width, height, palette

def render_png(pixels, width, height, palette):
    """Build PNG bytes using pure stdlib."""
    import zlib, struct
    def chunk(tag, data):
        crc = zlib.crc32(tag+data) & 0xFFFFFFFF
        return struct.pack('>I', len(data)) + tag + data + struct.pack('>I', crc)
    sig = b'\x89PNG\r\n\x1a\n'
    ihdr = struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0)
    raw = b''
    for y in range(height):
        raw += b'\x00'  # filter byte
        for x in range(width):
            px = pixels[y*width+x]
            raw += bytes(px) + b'\xff'  # RGBA
    return sig + chunk(b'IHDR', ihdr) + chunk(b'IDAT', zlib.compress(raw)) + chunk(b'IEND', b'')

def ascii_preview(pixels, width, height):
    """Return ASCII art preview string."""
    chars = ' .:-=+*#%@'
    out = []
    step_x = max(1, width//80)
    step_y = max(1, height//24)
    for y in range(0, height, step_y):
        row = ''
        for x in range(0, width, step_x):
            px = pixels[y*width+x]
            lum = 0.299*px[0] + 0.587*px[1] + 0.114*px[2]
            idx = min(int(lum/256*len(chars), len(chars)-1)
            row += chars[idx]
        out.append(row)
    return '\n'.join(out)

def main():
    if len(sys.argv) < 2:
        print('Usage: shizuku-lfg.py <input.LFG> [output.png] [--preview]')
        sys.exit(1)
    path = sys.argv[1]
    preview = '--preview' in sys.argv
    out_path = None
    for a in sys.argv[2:]:
        if a == '--preview': continue
        out_path = a
    if out_path is None and not preview:
        base = os.path.splitext(os.path.basename(path))[0]
        out_path = base + '.png'
    data = open(path,'rb').read()
    pixels, width, height, palette = decode_lfg(data)
    print(f'{os.path.basename(path)}: {width}x{height}, palette=LEAFCODE, transparent=palette_idx', file=sys.stderr)
    if preview:
        print(ascii_preview(pixels, width, height))
        return
    png = render_png(pixels, width, height, palette)
    if out_path:
        with open(out_path,'wb') as f: f.write(png)
        print(f'Wrote {out_path} ({len(png)//1024}KB)', file=sys.stderr)
    else:
        sys.stdout.buffer.write(png)

if __name__ == '__main__':
    main()
