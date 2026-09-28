# Container Formats — LEAFPACK & LAC

> 🌐 **Language / 多语言**: [🇨🇳 简体中文](containers.md) ｜ [🇺🇸 English](containers-en.md) ｜ [🇯🇵 日本語](containers-jp.md)

## LEAFPACK (`MAX_DATA.PAK`, etc.)

Reference implementations: XLVNS / mglvns `leafpack.c` (Go Watanabe, ©1999-2000, BSD license).
Verified: The native Python unpacker (`research/tools/unpack_leafpack.py`) successfully extracts all 403 files from retail `MAX_DATA.PAK`.

### Physical Layout

```text
offset  0:  "LEAFPACK" (8 B magic)
offset  8:  u16 LE file count file_num
offset 10:  File data payload (each byte obfuscated by rolling additive key)
end 24*n :  Directory table (24 B / entry), each byte similarly obfuscated
```

The file count distinguishes different games across the LVNS lineage:

| file_num | Title |
|---|---|
| 0x0193 (403) | *Shizuku* for Windows |
| 0x01fb (511) | *Kizuato* for Windows |
| 0x0248 / 0x03e1 | *To Heart* |
| 0x0072 (114) | *Saorin to Issho!!* |

### Obfuscation Keystream (11 Bytes)

Encryption formula: `stored = (plain + key[k]) & 0xff`. Index `k` advances cyclically across the entire stream (**never reset** across file boundaries; payload begins at index 0).

Default key (verified in retail *Shizuku* and identical to pakwriter constants):
`71 48 6a 55 9f 13 58 f7 d1 7c 3e` (ASCII `qHjU…`) — matching string `"LEAFPACKqHjU"` in `Sizuku.exe`.

`guess_key()` can reconstruct the keystream from directory records alone (requiring ≥ 3 entries). Thus, **any LEAFPACK archive can be cracked** without hardcoding the key.

### Directory Entry Record (24 Bytes)

```text
0..7   Base filename (≤ 8 chars, right-padded with spaces; '.' not stored)
8..10  Extension (3 chars)
11     0x00 null terminator
12..15 u32 LE payload data offset
16..19 u32 LE compressed / raw file length
20..23 u32 LE next file offset (unused)
```

Filenames are restored to standard 8.3 format (e.g., `SCN000.DAT`).

### Payload Data Area

- Uncompressed files: byte-wise `plain = (stored - key[i % 11]) & 0xff`.
- Compressed streams (for LZS): 8-byte header `[u32 BE compressed size][u32 BE raw size]` + compressed stream; entry length includes this 8-byte header.

### LZS Decompression Variants

- `lzs`: Standard positive flag logic, ring buffer `0x1000`, `m` initial pointer `0x0FEE`.
- `lzs2` / `lzs3`: Inverted flag logic (`~flag`), ring buffer `0x1011`.
- Verified: SCN scenario scripts use **lzs3 (inverted flags, forward write)**; LFG graphic bitmaps use standard `lzs`.

---

## LAC (`bgmfile.PAK` / `soundds.PAK`)

Empirical layout reconstructed via binary dissection:

```text
offset 0: "LAC\0"
offset 4: u32 LE file count
after:    Directory entries, ~42 B per entry:
          +0  Name (8 B, Shift-JIS)
          +36 u32 LE payload offset
          +40 u32 LE length
after:    File payloads
```

- `bgmfile.PAK`: 25 entries containing stereo 44.1kHz **Ogg Vorbis** audio streams.
- `soundds.PAK`: 13 entries containing **RIFF/WAVE** audio files generated via GoldWave.
