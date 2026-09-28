"""
cmd_extract — extract files from LEAFPACK archive
"""

import sys
import os

# Add package dir to path for imports
pkg_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if pkg_dir not in sys.path:
    sys.path.insert(0, pkg_dir)

import argparse
from shizuku_cli.leafpack import guess_key, parse_table, lzs

def main(args):
    parser = argparse.ArgumentParser(description='Extract LEAFPACK archive')
    parser.add_argument('archive', help='LEAFPACK file (e.g., MAX_DATA.PAK)')
    parser.add_argument('output_dir', nargs='?', help='Output directory (default: ./extracted)')
    parser.add_argument('--type', help='Only extract files matching type prefix (e.g., SCN, HVS)')
    parser.add_argument('--lzs', action='store_true', help='Decompress LZS files')
    args = parser.parse_args(args)

    output_dir = args.output_dir or 'extracted'
    os.makedirs(output_dir, exist_ok=True)

    with open(args.archive, 'rb') as f:
        data = f.read()

    files = parse_table(data)
    key = guess_key(data)

    extracted = 0
    for f in files:
        if args.type and not f.name.upper().startswith(args.type.upper()):
            continue

        out_path = os.path.join(output_dir, f.name)
        raw = bytearray()
        pos = f.offset
        while pos < f.offset + f.size:
            b = data[pos] ^ key[(pos - f.offset) % 11]
            raw.append(b)
            pos += 1

        # Try LZS decompression if flagged
        if args.lzs and f.name.endswith('.LFG'):
            try:
                if len(raw) > 44:
                    comp_size = int.from_bytes(bytes(raw[44:48]), 'little')
                    decomp = lzs(bytes(raw[48:]), comp_size)
                    if len(decomp) > 0:
                        raw = bytearray(decomp)
            except Exception:
                pass

        with open(out_path, 'wb') as out:
            out.write(raw)
        extracted += 1

    print(f'Extracted {extracted} files to {output_dir}/')
