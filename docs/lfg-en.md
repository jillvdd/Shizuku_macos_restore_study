# LFG Image Format (LEAFCODE)

> 🌐 **Language / 多语言**: [🇨🇳 简体中文](lfg.md) ｜ [🇺🇸 English](lfg-en.md) ｜ [🇯🇵 日本語](lfg-jp.md)

Reference implementations: lfview `plugins/lfgdec.c`, mglvns `lfg.c` (Go Watanabe).
Verified against physical asset: `HVS01.LFG` = 640×400 resolution, uncompressed payload size = 128,000 bytes (= 640×400 / 2).

## Header Layout

```text
0..7     "LEAFCODE" (8 B magic)
8..31    24 B palette (16 colors × 3 channels, 4-bit packed nibbles)
32..33   u16 BE xoffset
34..35   u16 BE yoffset
36..37   u16 BE width  = (val + 1) * 8
38..39   u16 BE height = val + 1
40       direction flag (0 = VERTICAL column-major, non-zero = HORIZONTAL row-major)
41       transparent color index
42..43   reserved (verified 0x00, 0x00)
44..47   u32 LE uncompressed pixel buffer size (= width * height / 2, 2 pixels/byte)
48..     LZS compressed pixel stream (decompressed into size bytes via leafpack_lzs)
```

Palette nibble decoding: bytes follow `RG BR GB RG BR ...`. Each byte is split into high/low 4-bit nibbles and expanded via `(nibble << 4) | nibble` to yield full 8-bit RGBA channels.

Pixel representation: each decompressed byte stores two 4-bit indices (MSB first). In VERTICAL mode, pixels are scanned in two-column strips top-to-bottom.

## Verified Properties

- Base resolution: 640×400.
- Color depth: 16-color indexed palette.
- Character portraits embed `xoffset`/`yoffset` for coordinate positioning.
- Transparent color index is specified on a per-graphic basis.
