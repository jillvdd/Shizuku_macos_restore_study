"""
cmd_font — render KNJ font glyphs
"""

import sys
import os

# Add package dir to path for imports
pkg_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if pkg_dir not in sys.path:
    sys.path.insert(0, pkg_dir)

import argparse
from shizuku_cli.knj import load_font, get_glyph_count, get_glyph_bytes, slot_to_char, render_ascii, render_html, render_svg

def main(args):
    parser = argparse.ArgumentParser(description='Render KNJ font glyphs')
    parser.add_argument('font', help='KNJ font file')
    parser.add_argument('--slot', type=int, help='Render specific slot')
    parser.add_argument('--range', help='Render range (e.g., 0-50)')
    parser.add_argument('--all', action='store_true', help='Render all glyphs')
    parser.add_argument('--html', action='store_true', help='Output HTML')
    parser.add_argument('--svg', action='store_true', help='Output SVG')
    parser.add_argument('--count', action='store_true', help='Show glyph count only')
    args = parser.parse_args(args)

    data = load_font(args.font)
    total = get_glyph_count(data)

    if args.count:
        print(f'Glyphs: {total}')
        return

    def show_slot(slot):
        if slot < 0 or slot >= total:
            return
        glyph = get_glyph_bytes(data, slot)
        char = slot_to_char(slot)
        print(f'; Slot {slot}: {char}')
        if args.html:
            print(render_html(glyph))
        elif args.svg:
            print(render_svg(glyph))
        else:
            print(render_ascii(glyph))
        print()

    if args.slot is not None:
        show_slot(args.slot)
    elif args.range:
        start, end = map(int, args.range.split('-'))
        for slot in range(start, min(end + 1, total)):
            show_slot(slot)
    elif args.all:
        for slot in range(min(total, 100)):
            show_slot(slot)
    else:
        for slot in range(min(10, total)):
            show_slot(slot)
