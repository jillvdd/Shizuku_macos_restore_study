"""
cmd_image — render LFG image to PNG
"""

import sys
import os

# Add package dir to path for imports
pkg_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if pkg_dir not in sys.path:
    sys.path.insert(0, pkg_dir)

import argparse
from shizuku_cli.lfg import decode, parse_header, render_png

def main(args):
    parser = argparse.ArgumentParser(description='Render LFG to PNG')
    parser.add_argument('input', help='Input LFG file')
    parser.add_argument('output', nargs='?', help='Output PNG file')
    parser.add_argument('--preview', action='store_true', help='ASCII preview')
    args = parser.parse_args(args)

    with open(args.input, 'rb') as f:
        data = f.read()

    pixels, width, height = decode(data)

    if args.preview:
        header = parse_header(data)
        print(f'File: {os.path.basename(args.input)}')
        print(f'Dimensions: {width}x{height}')
        print(f'Canvas offset: ({header.xoffset}, {header.yoffset})')
        print(f'Content size: {header.content_width}x{header.content_height}')
        print()

        # Simple ASCII
        chars = ' .:-=+*#%@'
        step_x = max(1, width // 80)
        step_y = max(1, height // 24)

        for y in range(0, height, step_y):
            row = ''
            for x in range(0, width, step_x):
                px = pixels[y * width + x]
                lum = 0.299 * px[0] + 0.587 * px[1] + 0.114 * px[2]
                idx = min(int(lum / 256 * len(chars)), len(chars) - 1)
                row += chars[idx]
            print(row)
        return

    if args.output is None:
        base = os.path.splitext(os.path.basename(args.input))[0]
        args.output = base + '.png'

    png = render_png(pixels, width, height)
    with open(args.output, 'wb') as f:
        f.write(png)

    print(f'Wrote {args.output} ({len(png) // 1024}KB)')
