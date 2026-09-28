"""
scn — SCN script parser for Leaf Visual Novel engine

Reference: mglvns decscn.py, sizuku_gba2 script.c, GBALVNS siori.c
"""

import struct
from dataclasses import dataclass
from typing import List, Tuple, Dict, Optional

from shizuku_cli.cmd_disasm import lzs_decode_inv

# NOTE: scn.py formerly carried its own decscn.py-style lzs_decode_inv (ring 0x1011,
# Index=0xFEE, inverted flag sense, `Index-disp-1` addressing). It was wrong — 90/197
# retail SCN files failed to decode. cmd_disasm's variant is byte-verified against
# the Swift LZS.decodeInv used by the runtime.

# Event opcodes
EVENT_OPS: Dict[int, Tuple[str, int, str]] = {
    0x00: ('END',           0, ''),
    0x01: ('SUB',           2, 'msg_mask'),
    0x04: ('JUMP',          2, 'scn,blk'),
    0x05: ('SELECT',        0, 'variable'),
    0x07: ('SEL_BACK',      0, ''),
    0x0a: ('BG',            1, 'hvs_no'),
    0x14: ('CLEAR',         1, ''),
    0x16: ('HBG',           1, 'hvs_no'),
    0x22: ('CHR',           2, 'max_c,pos'),
    0x24: ('CHR2',          2, 'max_c,pos'),
    0x28: ('MARK2',         0, ''),
    0x38: ('EFFECT',        1, 'kind'),
    0x3d: ('IF_EQ',         3, 'flag,val,offset'),
    0x3e: ('IF_NE',         3, 'flag,val,offset'),
    0x47: ('FLAG_SET',      2, 'flag,val'),
    0x48: ('FLAG_ADD',      2, 'flag,val'),
    0x54: ('MSG',           1, 'msg_no'),
    0x6e: ('BGM',           1, 'bgm_no'),
    0x7c: ('ENDING',        0, ''),
    0x7d: ('END_BGM',       1, ''),
    0x7e: ('END_CHK',       1, 'chk_no'),
    0xff: ('UNREACHABLE',   0, ''),
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

TEXT_VARLEN = {
    'B': ('BG',        6),
    'D': ('CHR_ALL',   3),
    'C': ('CHR',       3),
    'S': ('BG_CHR',    9),
    'A': ('CHR3a',     9),
    'a': ('CHR3b',     9),
    'E': ('BG2',       6),
    'V': ('VIS',       6),
    'H': ('HBG',       6),
    'M': ('BGM_CTRL',  -1),
    'P': ('PCM_CTRL',  -1),
}


@dataclass
class ScnBlock:
    index: int
    offset: int
    events: List[Tuple]


@dataclass
class ScnMessage:
    index: int
    offset: int
    text: str


@dataclass
class ScnScript:
    file_index: int
    blocks: List[ScnBlock]
    messages: List[ScnMessage]
    raw_events: bytes
    raw_messages: bytes


def parse_scn(data: bytes, file_index: int = 0) -> ScnScript:
    """
    Parse SCN file (compressed format).

    Layout:
        0..1   u16 LE ev_off_raw * 0x10
        2..3   u16 LE msg_off_raw * 0x10
        ...    (padding to ev_off)
        ev_off u32 LE event_data_size
        ...    event LZ data
        msg_off u32 LE message_data_size
        ...    message LZ data
    """
    ev_off = struct.unpack_from('<H', data, 0)[0] * 0x10
    msg_off = struct.unpack_from('<H', data, 2)[0] * 0x10

    # The u32 at each segment head is the DECOMPRESSED size (Scn.swift Scn.parse):
    # feed the decoder the compressed region (ev data runs to msg_off; msg data to
    # EOF) and clip the output to the declared size. Slicing by the declared size
    # as if it were compressed length overshoots ev into the msg section and gives
    # msg a truncated input, corrupting both streams' tails.
    ev_size = struct.unpack_from('<I', data, ev_off)[0]
    msg_size = struct.unpack_from('<I', data, msg_off)[0]

    ev_raw = lzs_decode_inv(data[ev_off + 4:msg_off])[:ev_size]
    msg_raw = lzs_decode_inv(data[msg_off + 4:])[:msg_size]

    # Parse event blocks
    blocks = []
    if len(ev_raw) >= 4:
        last_blk = struct.unpack_from('<H', ev_raw, 0)[0]
        n_entries = min(last_blk + 1, (len(ev_raw) - 2) // 2)
        blk_table = struct.unpack_from(f'<{n_entries}H', ev_raw, 2)

        for i, offset in enumerate(blk_table):
            if offset < len(ev_raw):
                blk = parse_event_block(ev_raw, offset, i)
                blocks.append(blk)

    # Parse messages
    messages = []
    if len(msg_raw) >= 4:
        last_msg = struct.unpack_from('<H', msg_raw, 0)[0]
        n_msg_entries = min(last_msg + 1, (len(msg_raw) - 2) // 2)
        msg_table = struct.unpack_from(f'<{n_msg_entries}H', msg_raw, 2)

        for i in range(n_msg_entries):
            offset = msg_table[i]
            if offset < len(msg_raw):
                text = decode_message_text(msg_raw, offset)
                messages.append(ScnMessage(index=i, offset=offset, text=text))

    return ScnScript(
        file_index=file_index,
        blocks=blocks,
        messages=messages,
        raw_events=ev_raw,
        raw_messages=msg_raw
    )


def parse_event_block(data: bytes, offset: int, block_index: int) -> ScnBlock:
    """Parse one event block starting at offset."""
    events = []
    i = offset

    while i < len(data) - 1:
        op = data[i]
        i += 1

        if op == 0x00:  # END
            events.append(('END',))
            break
        elif op in EVENT_OPS:
            name, argc, desc = EVENT_OPS[op]
            args = []
            for _ in range(argc):
                if i < len(data):
                    args.append(data[i])
                    i += 1
            events.append((name, *args))
        else:
            events.append((f'UNK_{op:02X}',))

    return ScnBlock(index=block_index, offset=offset, events=events)


def decode_message_text(data: bytes, offset: int) -> str:
    """
    Decode Leaf-encoded text from message segment.

    Leaf encoding:
        0x00-0x7f: ASCII/Latin
        0x80+: double-byte leaf glyph code (0x80XX or 0xXX followed by next byte)
        Control chars: $ = end, p = page, k/K = wait, r = CR
    """
    result = []
    i = offset

    while i < len(data):
        b = data[i]
        i += 1

        if b == 0x00:
            break  # End of text
        elif b < 0x20:
            # Control characters
            if b == 0x0d or b == 0x0a:
                result.append('\n')
            elif chr(b) in TEXT_CMDS:
                name = TEXT_CMDS.get(chr(b), 'CTRL_%02X' % b)
                result.append('[%s]' % name)
            else:
                result.append(f'[{b:02X}]')
        elif b < 0x80:
            # ASCII
            result.append(chr(b))
        elif b == 0x80:
            # Leaf glyph: 80 + next byte
            if i < len(data):
                glyph = data[i]
                i += 1
                # Leaf code: map via sizfont.tbl
                result.append(f'<{glyph:02X}>')
        else:
            # Could be double-byte start
            result.append(f'<{b:02X}>')

    return ''.join(result)


def disassemble(scn: ScnScript) -> str:
    """Generate human-readable disassembly."""
    lines = [f'; SCN{scn.file_index:03d}.DAT']
    lines.append(f'; Blocks: {len(scn.blocks)}, Messages: {len(scn.messages)}')
    lines.append('')

    for msg in scn.messages:
        lines.append(f'[MSG {msg.index}] {msg.text}')

    lines.append('')

    for blk in scn.blocks:
        lines.append(f'--- Block {blk.index} @ 0x blk.offset:04x ---')
        for ev in blk.events:
            lines.append(f'  {ev[0]}' + (f' {ev[1:]}' if len(ev) > 1 else ''))

    return '\n'.join(lines)
