# Shizuku macOS Restoration — Context Resume Prompt

> 🌐 **Language / 多语言**: [🇨🇳 简体中文](RESUME_PROMPT.md) ｜ [🇺🇸 English](RESUME_PROMPT-en.md) ｜ [🇯🇵 日本語](RESUME_PROMPT-jp.md)

Operational summary and architecture baseline for new development sessions:

## Project Synopsis

Restore Leaf's seminal 1996 visual novel *Shizuku* as a native macOS application (Swift + Metal) without Wine emulation or legacy Windows PE runtime dependencies.

## Core Binary Facts

- **PAK Decryption**: 11-byte rolling keystream `71 48 6a 55 9f 13 58 f7 d1 7c 3e`.
- **Script Decompression**: Inverted-flag LZS3 (ring buffer `0x1011`) with mandatory output truncation by header uncompressed size.
- **Font Layout**: `KNJ_ALL.KNJ` (133,344 bytes) containing 1,852 glyphs (24×24 px, 1bpp, 72 bytes/glyph) organized into 3 vertical columns. Leaf font codes are direct 1-based indices (`code - 1`).
- **VM Hierarchy**: Outer Event VM executes scenario blocks and choices; Inner Inline VM executes ASCII staging tokens (`B/E`, `C`, `D`, `S`, `A`, `V`, `H`, `M`, `P`, `F`, `Q`, `X`, `s`, `k`, `p`, `$`).
- **Secret Room**: VA `0x430ebc` in `Sizuku.exe` contains a 5th invisible title screen rectangle mapping to the clock tower window at `(448, 128)`.
