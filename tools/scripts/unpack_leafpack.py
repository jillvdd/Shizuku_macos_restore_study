#!/usr/bin/env python3
"""
unpack_leafpack.py — LEAFPACK archive unpacker for Leaf 雫 (Shizuku) 2007 re-release
=====================================================================================
Reference implementation ported 1:1 from XLVNS/mglvns `leafpack.c` by Go Watanabe (c) 1999-2000,
BSD-licensed. See research/thirdparty/mglvns/mglvns-1.0/leafpack.c (and mgConvert/pakwriter.c).

Container layout (verified against an actual MAX_DATA.PAK):
    [0..7]   magic "LEAFPACK"
    [8..9]   u16 LE file count
    [10..]   file data, each byte obfuscated by a rolling 11-byte key:
             stored = (plain + key[i % 11]) & 0xff
    [end - 24*n ..]  file table, one 24-byte entry per file, each byte keyed:
             0..7    filename up to 8 chars (space padded)
             8..10   extension 3 chars   (note: the '.' is NOT stored)
             11      NUL terminator
             12..15  u32 LE position in data section
             16..19  u32 LE length
             20..23  u32 LE next position (unused)
The rolling key is recovered from the table itself via guess_key() (needs >= 3 files).
After decryption, some files may be LZSS-compressed (mglvns converts images this way;
the original game data is expected to be plaintext after the XOR).
"""

import sys
import os

KEY_LEN = 11
MAGIC = b"LEAFPACK"


def guess_key(data: bytes) -> list:
    """Recover the 11-byte rolling key from the archive's own file table."""
    n = int.from_bytes(data[8:10], "little")
    if n < 3:
        raise ValueError("need >= 3 files to guess key")
    start = len(data) - 24 * n
    p = data[start:start + 24 * 4]  # only first 4 entries needed for key math
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


def dekey(buf: bytes, key: list) -> bytes:
    return bytes(((b - key[i % KEY_LEN]) & 0xFF) for i, b in enumerate(buf))


def parse_table(data: bytes, key: list):
    """The rolling key index continues ACROSS table entries (never resets),
    exactly like XLVNS leafpack.c extract_table(): k = (++k) % LP_KEY_LEN."""
    n = int.from_bytes(data[8:10], "little")
    start = len(data) - 24 * n
    files = []
    k = 0
    for _ in range(n):
        raw = bytes(((b - key[(k + j) % KEY_LEN]) & 0xFF) for j, b in enumerate(data[start:start + 24]))
        k = (k + 24) % KEY_LEN
        start += 24
        # regularize_name: 8.3
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
        files.append((name, pos, ln, nxt))
    return files


def lzs3(src: bytes, out_size: int) -> bytes:
    """leafpack_lzs3: LZSS with 0x1011-byte ring buffer, inverted flag bits,
    output written front to back into a pre-zeroed buffer."""
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


def main():
    path = sys.argv[1]
    data = open(path, "rb").read()
    if data[:8] != MAGIC:
        print(f"NOT a LEAFPACK archive (magic={data[:8]!r})")
        sys.exit(1)
    n = int.from_bytes(data[8:10], "little")
    print(f"magic OK, file count = {n} (0x{n:04x})")
    if n == 0x193:
        print("  -> type SHIZUKU for Windows (LPTYPE_SIZUWIN)")
    elif n == 0x1fb:
        print("  -> type KIZUATO for Windows")
    elif n == 0x248 or n == 0x3e1:
        print("  -> type TOHEART")
    elif n == 0x72:
        print("  -> type SAORIN")
    key = guess_key(data)
    print("key = " + " ".join(f"{b:02x}" for b in key))
    print("key ascii = " + "".join(chr(b) if 32 <= b < 127 else "." for b in key))
    files = parse_table(data, key)
    print(f"{'name':<16} {'pos':>10} {'len':>9}")
    for name, pos, ln, nxt in files:
        print(f"{name:<16} {pos:>10} {ln:>9}")

    outdir = sys.argv[2] if len(sys.argv) > 2 else "extracted"
    os.makedirs(outdir, exist_ok=True)
    for name, pos, ln, nxt in files:
        blob = dekey(data[pos:pos + ln], key)
        with open(os.path.join(outdir, name), "wb") as f:
            f.write(blob)

    # quick sanity: magic bytes of a few extracted files
    print("\nfirst-16-bytes of extracted files (decrypted):")
    for name, pos, ln, nxt in files[:12]:
        with open(os.path.join(outdir, name), "rb") as f:
            head = f.read(16)
        print(f"  {name:<16} {head.hex()}")


if __name__ == "__main__":
    main()