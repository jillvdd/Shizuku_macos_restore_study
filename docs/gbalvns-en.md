# GBALVNS Architecture Reference

> 🌐 **Language / 多语言**: [🇨🇳 简体中文](gbalvns.md) ｜ [🇺🇸 English](gbalvns-en.md) ｜ [🇯🇵 日本語](gbalvns-jp.md)

Open-source reference: `research/gbalvns/` by laqieer (BSD-3-Clause).

## Architectural Role

GBALVNS is not a direct runtime for Windows 95 assets, but rather a complete Game Boy Advance visual novel engine with its own asset compilation pipeline:
- Scripts are compiled from textual assembly (`asset/script/*.S`) to flat binary files.
- Graphics are converted to GBA 4bpp / 8bpp hardware tiles.
- Audio is converted to 8-bit adaptive delta PCM (8AD).

## Key Engineering Insights

- `core/script.h`: State machine implementation defining transitions between Event, Message, Animation, Choice, and History states.
- `EVTDef.s`: Canonical opcode definitions (0x00 to 0xff) confirming identical opcode numbering with retail Windows *Shizuku*.
- `core/res/bin_k12x10*.bmp`: 12×10 bitmap glyph rendering atlas.
