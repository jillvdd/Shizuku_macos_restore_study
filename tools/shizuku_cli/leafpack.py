"""
leafpack — LEAFPACK archive format parser

Reference: mglvns leafpack.c by Go Watanabe (BSD-licensed)
"""

import struct
from dataclasses import dataclass
from typing import List, Optional

KEY_LEN = 11
MAGIC = b"LEAFPACK"

@dataclass
class FileEntry:
    name: str
    offset: int  # Position in data section
    size: int
    next_offset: int  # Next entry position (unused)

def guess_key(data: bytes) -> List[int]:
    """Recover the 11-byte rolling key from the archive's own file table."""
    n = int.from_bytes(data[8:10], "little")
    if n < 3:
        raise ValueError("need >= 3 files to guess key")
    start = len(data) - 24 * n
    p = data[start:start + 24 * 4]
    key = [0] * KEY_LEN
    key[0] = p[11]
    key[1] = (p[12] - 0x0a) & 0xFF
    key[2] = p[13]
    key[3] = p[14]
    key[4] = p[15]
    key[5] = (p[38] - p[22] + key[0]) & 0xFF
    key[6] = (p[39] - p[23] + key[1]) & 0xFF
    key[7] = (p[62] - p[46] + key[2]) & 0xFF
    key[8] = (p[63] - p[47] + key[3]) & 0xFF
    key[9] = (p[20] - p[36] + key[3]) & 0xFF
    key[10] = (p[21] - p[37] + key[4]) & 0xFF
    return key

def dekey(buf: bytes, key: List[int]) -> bytes:
    return bytes(((b - key[i % KEY_LEN]) & 0xFF) for i, b in enumerate(buf))

def parse_table(data: bytes) -> List[FileEntry]:
    """Parse file table, decrypting with recovered key."""
    key = guess_key(data)
    n = int.from_bytes(data[8:10], "little")
    start = len(data) - 24 * n
    files = []
    k = 0
    for _ in range(n):
        raw = bytes(((b - key[(k + j) % KEY_LEN]) & 0xFF) for j, b in enumerate(data[start:start + 24]))
        k = (k + 24) % KEY_LEN
        start += 24
        name = ""
        i = 0
        while i < 8 and raw[i] != 0x20:
            name += chr(raw[i])
            i += 1
        ext = raw[8:11].decode("latin1")
        name = name.rstrip()
        name += "." + ext
        pos = int.from_bytes(raw[12:16], "little")
        ln = int.from_bytes(raw[16:20], "little")
        nxt = int.from_bytes(raw[20:24], "little")
        files.append(FileEntry(name=name, offset=pos, size=ln, next_offset=nxt))
    return files

def open_archive(path: str) -> tuple:
    """Open archive and return (key, file_entries, raw_data)."""
    with open(path, 'rb') as f:
        data = f.read()
    if data[:8] != MAGIC:
        raise ValueError(f"Not a LEAFPACK archive: {data[:8]!r}")
    n = int.from_bytes(data[8:10], "little")
    key = guess_key(data)
    files = parse_table(data)
    return key, files, data

def extract_file(archive_data: bytes, entry: FileEntry) -> bytes:
    """Extract single file from archive, decrypting and decompressing."""
    key, files, data = None, None, None  # caller passes raw data
    # Get key from caller
    pass

def extract_file_raw(archive_data: bytes, entry: FileEntry, key: List[int]) -> bytes:
    """Extract raw (XOR-decrypted, possibly LZ-compressed) file data."""
    raw = dekey(archive_data[entry.offset:entry.offset + entry.size], key)
    return raw


def lzs3(src: bytes, out_size: int) -> bytes:
    """leafpack_lzs3: LZSS with 0x1011-byte ring buffer, inverted flag bits."""
    out = bytearray(out_size)
    tb = bytearray(0x1011)
    idx = 0xFEE
    src_i = 0
    flag = 0
    flag_count = 0
    wrote = 0
    while wrote < out_size:
        if flag_count > 0:
            flag_count -= 1
            flag = (flag << 1) & 0xFF
        else:
            flag = ~src[src_i] & 0xFF
            src_i += 1
            flag_count = 7
        if flag & 0x80:
            b = ~src[src_i] & 0xFF
            src_i += 1
            tb[idx] = b
            idx = (idx + 1) & 0xFFF
            out[wrote] = b
            wrote += 1
        else:
            lflag = ~(src[src_i] + (src[src_i + 1] << 8)) & 0xFFFF
            src_i += 2
            ln = (lflag & 0xF) + 3
            lindex = (lflag >> 4) & 0xFFF
            for _ in range(ln):
                b = tb[lindex]
                lindex = (lindex + 1) & 0xFFF
                tb[idx] = b
                idx = (idx + 1) & 0xFFF
                out[wrote] = b
                wrote += 1
    return bytes(out)


def lzs(src: bytes, out_size: int) -> bytes:
    """leafpack_lzs: same, but non-inverted flag bits, ring buffer 0x1000."""
    out = bytearray(out_size)
    ring = bytearray(0x1000)
    m = 0xFEE
    c = 0
    flag = 0
    i = 0
    s = 0
    while i < out_size:
        c -= 1
        if c < 0:
            flag = src[s]
            s += 1
            c = 7
        if flag & 0x80:
            b = src[s]
            s += 1
            out[i] = ring[m] = b
            m &= 0xFFF
            i += 1
        else:
            d = src[s] + (src[s + 1] << 8)
            s += 2
            ln = (d & 0x0F) + 3
            pos = d >> 4
            for _ in range(ln):
                out[i] = ring[m] = ring[pos]
                m &= 0xFFF
                pos &= 0xFFF
                i += 1
        flag = (flag << 1) & 0xFF
    return bytes(out)
