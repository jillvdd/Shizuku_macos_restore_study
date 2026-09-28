"""
cmd_text — extract text from SCN scripts
"""

import sys
import os

# Add package dir to path for imports
pkg_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if pkg_dir not in sys.path:
    sys.path.insert(0, pkg_dir)

import argparse
import struct
from typing import List

# Event opcodes (from shizuku-scn-disasm.py)
EVENT_OPS = {
    0x00: ('END', 0, ''),
    0x01: ('SUB', 2, 'msg_mask'),
    0x04: ('JUMP', 2, 'scn,blk'),
    0x05: ('SELECT', 0, 'variable'),
    0x07: ('SEL_BACK', 0, ''),
    0x0a: ('BG', 1, 'hvs_no'),
    0x14: ('CLEAR', 1, ''),
    0x16: ('HBG', 1, 'hvs_no'),
    0x22: ('CHR', 2, 'max_c,pos'),
    0x24: ('CHR2', 2, 'max_c,pos'),
    0x28: ('MARK2', 0, ''),
    0x38: ('EFFECT', 1, 'kind'),
    0x3d: ('IF_EQ', 3, 'flag,val,offset'),
    0x3e: ('IF_NE', 3, 'flag,val,offset'),
    0x47: ('FLAG_SET', 2, 'flag,val'),
    0x48: ('FLAG_ADD', 2, 'flag,val'),
    0x54: ('MSG', 1, 'msg_no'),
    0x6e: ('BGM', 1, 'bgm_no'),
    0x7c: ('ENDING', 0, ''),
    0x7d: ('END_BGM', 1, ''),
    0x7e: ('END_CHK', 1, 'chk_no'),
    0xff: ('UNREACHABLE', 0, ''),
}

TEXT_CMDS = {
    '$': 'MSG_END',
    'p': 'PAGE',
    'k': 'WAIT_KEY',
    'K': 'WAIT_KEY2',
    'r': 'CR',
    'Q': 'DARKEN',
    'F': 'FLASH',
    'X': 'OFFSET',
    's': 'SPEED',
}


def lzs_decode_inv(src: bytes) -> bytes:
    """LZS with inverted flag bits."""
    buf = [0x00] * 0x1000
    dst = []
    Index = 0
    i = 0
    FlagCount = 0
    Flag = 0

    while i < len(src):
        if FlagCount > 0:
            FlagCount -= 1
            Flag = (Flag << 1) & 0xff
        else:
            Flag = (~src[i]) & 0xff
            i += 1
            FlagCount = 7
        if i >= len(src):
            break
        if Flag & 0x80:
            dst.append((~src[i]) & 0xff)
            buf[Index] = dst[-1]
            Index = (Index + 1) & 0xfff
            i += 1
        else:
            if i + 1 >= len(src):
                break
            LFlag = (~(src[i] + (src[i + 1] << 8))) & 0xffff
            i += 2
            LLen = (LFlag & 0xf) + 3
            LIndex = LFlag >> 4
            for _ in range(LLen):
                dst.append(buf[LIndex])
                buf[Index] = dst[-1]
                LIndex = (LIndex + 1) & 0xfff
                Index = (Index + 1) & 0xfff
    return bytes(dst)


def disassemble_text(data: bytes, sizfont: bytes, max_chars: int = 200) -> str:
    """Decode message text with leaf code to Japanese."""
    out = []
    i = 0
    while i < len(data) and len(out) < max_chars:
        c = data[i]
        if c == 0x00:
            out.append('　')
            i += 1
            continue
        if c & 0x80:
            if i + 1 >= len(data):
                break
            leaf = ((c & 0x7f) << 8) | data[i + 1]
            if 0 <= leaf < len(sizfont) // 2:
                b0 = sizfont[leaf * 2]
                b1 = sizfont[leaf * 2 + 1]
                try:
                    out.append(bytes([b0, b1]).decode('cp932'))
                except Exception:
                    out.append('?')
            else:
                out.append('<L%04x?>' % leaf)
            i += 2
            continue
        ch = chr(c)
        if ch == '$':
            out.append('<MSG_END>')
            i += 1
            break
        if ch in TEXT_CMDS:
            out.append('<%s>' % TEXT_CMDS[ch])
            i += 1
            continue
        out.append(ch)
        i += 1
    return ''.join(out)


def main(args):
    parser = argparse.ArgumentParser(description='Extract text from SCN scripts')
    parser.add_argument('files', nargs='+', help='SCN*.DAT files')
    parser.add_argument('--msg-only', action='store_true', help='Show only messages')
    parser.add_argument('--sizfont', default='research/thirdparty/mglvns/mglvns-1.0/sizfont.tbl',
                        help='Path to sizfont.tbl')
    args = parser.parse_args(args)

    # Load sizfont
    try:
        with open(args.sizfont, 'rb') as f:
            sizfont = f.read()
    except FileNotFoundError:
        print('Warning: sizfont.tbl not found, leaf codes will be raw')
        sizfont = b'\x00' * (1851 * 2)

    for path in args.files:
        basename = os.path.basename(path)
        with open(path, 'rb') as f:
            raw = f.read()

        print('== %s (%dB) ==' % (basename, len(raw)))

        if len(raw) < 32:
            continue

        # Parse header
        ev_off = struct.unpack_from('<H', raw, 0)[0] * 0x10
        msg_off = struct.unpack_from('<H', raw, 2)[0] * 0x10

        if ev_off < 16 or ev_off >= len(raw) - 4:
            continue
        if msg_off < 16 or msg_off >= len(raw) - 4:
            continue

        # Decode LZ data
        ev_size = struct.unpack_from('<I', raw, ev_off)[0]
        ev_data = lzs_decode_inv(raw[ev_off + 4:ev_off + 4 + ev_size])

        msg_size = struct.unpack_from('<I', raw, msg_off)[0]
        msg_data = lzs_decode_inv(raw[msg_off + 4:msg_off + 4 + msg_size])

        # Parse messages
        if len(msg_data) >= 2:
            last_msg = struct.unpack_from('<H', msg_data, 0)[0]
            msg_table = struct.unpack_from('<%dH' % (last_msg + 1), msg_data, 2)

            for i in range(last_msg + 1):
                offset = msg_table[i]
                if offset < len(msg_data):
                    text = disassemble_text(msg_data[offset:], sizfont)
                    print('  msg[%3d]: %s' % (i, text))

        print()
