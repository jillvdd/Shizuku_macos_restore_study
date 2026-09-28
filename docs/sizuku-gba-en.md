# sizuku advance & sizuku_gba2 Reference Analysis

> 🌐 **Language / 多语言**: [🇨🇳 简体中文](sizuku-gba.md) ｜ [🇺🇸 English](sizuku-gba-en.md) ｜ [🇯🇵 日本語](sizuku-gba-jp.md)

Source archives by akkera102:
- `76_sizuku_viewer.zip`: Python LFG to BMP converter (`1_lfg2bmp.py`).
- `78_sizuku_scn_test.zip`: `scndec.py`, the earliest open-source SCN parser.
- `79_sizuku_gba.zip`: Complete toolchain including `decscn.py`, `declfg.py`, `script.c`, `anime.c`, and font conversion utilities.

## Core Breakthroughs

1. `decscn.py`: Confirmed the 16-byte SCN header and the inverted-flag LZS3 decompression algorithm.
2. `script.c`: Provides the authoritative reference implementation for the event and text bytecode interpreter.
3. Proved that GBA 8AD audio conversion was a hardware-specific constraint and should be bypassed in favor of native 44.1kHz audio on macOS.
