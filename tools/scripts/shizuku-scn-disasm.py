#!/usr/bin/env python3
"""
shizuku-scn-disasm.py — SCN 反汇编器 (Phase B / shizuku-cli disassemble 命令)

输入:原始 SCN%03d.DAT (research/extracted/SCN*.DAT,LZ 未解)
输出:人类可读的事件流 + 消息文本

文件布局(LZ 未解):
    0..1   u16 LE  ev_off_raw × 0x10
    2..3   u16 LE  msg_off_raw × 0x10
    [padding to ev_off]
    ev_off  u32 LE d1Size (LZ源字节数)
    ev_off+4..+4+d1Size  LZ数据(LZS 反相 flag)
    msg_off u32 LE d2Size
    msg_off+4..+4+d2Size LZ数据

LZ 解压后(目标大小未知,本工具读出"已知 LZ 字节数"全部消费)产生事件段和消息段:

事件段:
    u16 last_blk_no
    u16×(last_blk_no+1) 块偏移表(相对本段字节 0)
    之后字节码流

消息段:
    u16 last_msg_no
    u16×(last_msg_no+1) 偏移表(相对本段字节 0)
    之后 Leaf 编码文本

Leaf 编码:0x80+双字节字形码 = ((c0&0x7f)<<8)|c1;sizfont.tbl[leaf] → SJIS 双字节
控制字节 <0x80:ASCII 命令($=end, p=page, k/K=wait, r=CR, B/C/D/S/A/a/E/V/H=场景, M/P=音乐/PCM, Q/F/X/s=画面)
"""

import sys
import os
import struct
from typing import List, Tuple, Dict, Optional

# ---- 事件 opcode 表 ----
EVENT_OPS: Dict[int, Tuple[str, int, str]] = {
    0x00: ('END',           0, ''),
    0x01: ('SUB',           2, '01=msg,02=msg+fade,03=anim_wait'),
    0x04: ('JUMP',          2, 'scn,blk'),
    0x05: ('SELECT',        0, 'variable'),
    0x07: ('SEL_BACK',      0, ''),
    0x0a: ('BG',            1, 'hvs_no'),
    0x14: ('CLEAR',         1, ''),
    0x16: ('HBG',           1, 'hvs_no'),
    0x22: ('CHR',           2, 'max_c,pos(a/b/c)'),
    0x24: ('CHR2',          2, 'max_c,pos'),
    0x28: ('MARK2',         0, ''),
    0x38: ('EFFECT',        1, 'kind'),
    0x3d: ('IF_EQ',         3, 'flag,val,rel_offset'),
    0x3e: ('IF_NE',         3, 'flag,val,rel_offset'),
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
    '$': 'MSG_END', 'p': 'PAGE', 'k': 'WAIT_KEY', 'K': 'WAIT_KEY2',
    'r': 'CR', 'Q': 'DARKEN', 'F': 'FLASH', 'X': 'OFFSET', 's': 'SPEED',
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


def lzs_decode(src: bytes) -> bytes:
    """LZS 反相 flag 解码 (decscn.py decode() 函数). 消费全部 src."""
    Index = 0xfee
    buf = [0x00] * 0x1011
    dst: List[int] = []
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
            Index = (Index + 1) & 0x0fff
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
                LIndex = (LIndex + 1) & 0x0fff
                Index = (Index + 1) & 0x0fff
    return bytes(dst)


def load_sizfont(path: str) -> bytes:
    with open(path, 'rb') as f:
        return f.read()


def leaf_to_sjis(leaf: int, sizfont: bytes) -> str:
    if leaf < 0 or leaf >= 1851:
        return f'<L{leaf:04x}?>'
    b0 = sizfont[leaf * 2]
    b1 = sizfont[leaf * 2 + 1]
    # sizfont.tbl 编码为 IBM 半角假名 SJIS (cp932 兼容)
    try:
        return bytes([b0, b1]).decode('cp932')
    except Exception:
        return '?'


def disassemble_text(data: bytes, sizfont: bytes, max_chars: int = 200) -> str:
    out: List[str] = []
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
            out.append(leaf_to_sjis(leaf, sizfont))
            i += 2
            continue
        ch = chr(c)
        if ch == '$':
            out.append('<$>')
            i += 1
            break
        if ch in TEXT_CMDS:
            out.append(f'<{TEXT_CMDS[ch]}>')
            i += 1
            continue
        if ch in TEXT_VARLEN:
            name, nlen = TEXT_VARLEN[ch]
            if nlen == -1:
                if i + 1 >= len(data):
                    break
                arg = data[i + 1]
                if ch == 'M':
                    out.append(f'<M:{arg:02x}>')
                    if arg in (0x73,):  # 's' stop
                        i += 2
                    else:
                        if i + 2 < len(data):
                            out.append(f':{data[i+2]:02x}')
                            i += 3
                        else:
                            i += 2
                else:  # P
                    out.append(f'<P:{arg:02x}>')
                    if i + 2 < len(data):
                        out.append(f':{data[i+2]:02x}')
                        i += 3
                    else:
                        i += 2
                continue
            chunk = data[i + 1:i + 1 + nlen]
            out.append(f'<{name}:{chunk.hex()}>')
            i += 1 + nlen
            continue
        out.append(f'<0x{c:02x}>')
        i += 1
    return ''.join(out)


def disassemble_event_block(data: bytes, start: int, end: int) -> List[str]:
    out: List[str] = []
    pc = start
    while pc < end:
        op = data[pc]
        if op == 0x00:
            out.append(f'  {pc:04x}: 00  END')
            pc += 1
            break
        if op == 0xff:
            out.append(f'  {pc:04x}: ff  UNREACHABLE')
            pc += 1
            continue
        if op not in EVENT_OPS:
            out.append(f'  {pc:04x}: {op:02x}?? (skip 1)')
            pc += 1
            continue
        name, nlen, hint = EVENT_OPS[op]
        if op == 0x05:
            if pc + 2 > end:
                out.append(f'  {pc:04x}: 05  SELECT <truncated>')
                break
            prompt = data[pc + 1]
            n_opts = data[pc + 2]
            opt_bytes_needed = n_opts * 3
            options_data = data[pc + 3:pc + 3 + opt_bytes_needed]
            out.append(f'  {pc:04x}: 05  SELECT prompt={prompt} n={n_opts}')
            for k in range(n_opts):
                m = options_data[k * 3]
                lo = options_data[k * 3 + 1]
                hi = options_data[k * 3 + 2]
                blk_off = (hi << 8) | lo
                out.append(f'        opt[{k}]: msg={m} blk_off=0x{blk_off:04x}')
            pc += 3 + opt_bytes_needed
            continue
        if nlen == 0:
            out.append(f'  {pc:04x}: {op:02x}  {name} ({hint})')
            pc += 1
            continue
        chunk = data[pc + 1:pc + 1 + nlen]
        if pc + 1 + nlen > end:
            out.append(f'  {pc:04x}: {op:02x}  {name} <truncated; have {len(chunk)}/{nlen}>')
            break
        out.append(f'  {pc:04x}: {op:02x}{chunk.hex()}  {name} ({hint})')
        pc += 1 + nlen
    if pc < end and pc < len(data):
        out.append(f'  ...trailing {end - pc}B: {data[pc:end].hex()}')
    return out


def disassemble_scn(scn_path: str, sizfont: bytes, verbose: bool = False) -> str:
    with open(scn_path, 'rb') as f:
        raw = f.read()
    if len(raw) < 32:
        return f'(too small, {len(raw)} bytes)'
    ev_off_raw, msg_off_raw = struct.unpack('<HH', raw[0:4])
    ev_off = ev_off_raw * 0x10
    msg_off = msg_off_raw * 0x10
    if ev_off >= len(raw) or msg_off >= len(raw) or msg_off < ev_off:
        return f'(bad offsets: ev={ev_off:#x} msg={msg_off:#x})'
    # LZ 字节流长度由段间距离决定, 不依赖 d1/d2 字段
    ev_lz_len = msg_off - (ev_off + 4)
    msg_lz_len = len(raw) - (msg_off + 4)
    ev_lz = raw[ev_off + 4:ev_off + 4 + ev_lz_len]
    msg_lz = raw[msg_off + 4:msg_off + 4 + msg_lz_len]
    ev_raw = lzs_decode(ev_lz)
    msg_raw = lzs_decode(msg_lz)
    out: List[str] = []
    out.append(f'== {os.path.basename(scn_path)} ({len(raw)}B) ==')
    out.append(f'  ev@0x{ev_off:x} lz={ev_lz_len}B → decoded={len(ev_raw)}B')
    out.append(f'  msg@0x{msg_off:x} lz={msg_lz_len}B → decoded={len(msg_raw)}B')
    if verbose:
        out.append(f'  ev_raw first 64B: {ev_raw[:64].hex()}')
    out.append('')
    if len(ev_raw) < 2:
        return '\n'.join(out)
    last_blk = struct.unpack('<H', ev_raw[0:2])[0]
    blk_offsets = list(struct.unpack(f'<{last_blk + 1}H', ev_raw[2:2 + (last_blk + 1) * 2]))
    out.append(f'  blocks: {last_blk + 1} (blk 0..{last_blk})')
    for blk in range(last_blk + 1):
        bstart = blk_offsets[blk]
        bend = blk_offsets[blk + 1] if blk + 1 <= last_blk else len(ev_raw)
        if bstart >= len(ev_raw):
            out.append(f'--- block {blk} (out of range, off=0x{bstart:x}, ev_raw={len(ev_raw)}B) ---')
            continue
        out.append(f'--- block {blk} (event bytes 0x{bstart:x}..0x{bend:x}) ---')
        out.extend(disassemble_event_block(ev_raw, bstart, bend))
        out.append('')
    # 消息段
    if len(msg_raw) >= 2:
        last_msg = struct.unpack('<H', msg_raw[0:2])[0]
        msg_offsets = list(struct.unpack(f'<{last_msg + 1}H', msg_raw[2:2 + (last_msg + 1) * 2]))
        out.append(f'== messages ({last_msg + 1}) ==')
        for m in range(last_msg + 1):
            mstart = msg_offsets[m]
            mend = msg_offsets[m + 1] if m + 1 <= last_msg else len(msg_raw)
            text_bytes = msg_raw[mstart:mend]
            text = disassemble_text(text_bytes, sizfont)
            out.append(f'  msg[{m:3d}]: {text}')
    return '\n'.join(out)


def main():
    if len(sys.argv) < 2:
        print('usage: shizuku-scn-disasm.py SCN000.DAT [SCN001.DAT ...] [-v]')
        sys.exit(1)
    paths = [a for a in sys.argv[1:] if not a.startswith('-')]
    verbose = '-v' in sys.argv
    sizfont_path = ('/Users/abc/Documents/shizuku_macos_experience/'
                    'research/thirdparty/mglvns/mglvns-1.0/sizfont.tbl')
    sizfont = load_sizfont(sizfont_path)
    for p in paths:
        print(disassemble_scn(p, sizfont, verbose=verbose))
        print()


if __name__ == '__main__':
    main()