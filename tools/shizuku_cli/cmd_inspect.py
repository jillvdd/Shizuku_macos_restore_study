"""
cmd_inspect — inspect LEAFPACK archive contents
"""

import sys
import os

# Add package dir to path for imports
pkg_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if pkg_dir not in sys.path:
    sys.path.insert(0, pkg_dir)

import argparse
from shizuku_cli.leafpack import guess_key, parse_table

def main(args):
    parser = argparse.ArgumentParser(description='Inspect LEAFPACK archive')
    parser.add_argument('archive', help='LEAFPACK file (e.g., MAX_DATA.PAK)')
    parser.add_argument('--by-type', action='store_true', help='Group by file type')
    args = parser.parse_args(args)

    with open(args.archive, 'rb') as f:
        data = f.read()

    if data[:8] != b'LEAFPACK':
        print(f'Error: not a LEAFPACK file (magic: {data[:8]!r})')
        sys.exit(1)

    n = int.from_bytes(data[8:10], 'little')
    print(f'Archive: {os.path.basename(args.archive)}')
    print(f'Files: {n}')
    print()

    files = parse_table(data)

    if args.by_type:
        by_ext = {}
        for f in files:
            ext = os.path.splitext(f.name)[1].lower()
            by_ext.setdefault(ext, []).append(f)

        for ext in sorted(by_ext.keys()):
            print(f'{ext}: {len(by_ext[ext])} files')
            for f in sorted(by_ext[ext], key=lambda x: x.name):
                print(f'  {f.name:20s} {f.size:6d} bytes @ 0x{f.offset:06x}')
            print()
    else:
        for f in files:
            print(f'{f.name:20s} {f.size:6d} bytes @ 0x{f.offset:06x}')
