# SHIZUKU PORT RESEARCH REPORT

> 🌐 **Language / 多语言**: [🇨🇳 简体中文](SHIZUKU_PORT_RESEARCH_REPORT.md) ｜ [🇺🇸 English](SHIZUKU_PORT_RESEARCH_REPORT-en.md) ｜ [🇯🇵 日本語](SHIZUKU_PORT_RESEARCH_REPORT-jp.md)

*Shizuku* (Leaf 1996 / 2007 Re-release) → Native macOS Systems Engineering — Phase 0/1 Research Report

## 0. Executive Summary

**Feasibility Conclusion: 100% Feasible, with architectural complexity significantly lower than anticipated.**

Historical open-source projects (XLVNS, MGLVNS, lfview, akkera sizuku family, GBALVNS) have thoroughly reverse-engineered the LVNS engine's containers, graphics, scenario bytecode, bitmap fonts, and opcode dispatch tables under BSD licenses. We have verified end-to-end extraction against retail game assets:
- All 403 files in `MAX_DATA.PAK` extracted cleanly.
- SCN scripts decompressed without corruption.
- Dialogue glyph indices decoded into coherent Japanese text via `sizfont.tbl`.
- LFG graphic headers matched byte-for-byte at 640×400 resolution (128,000 bytes uncompressed).

## 1. Engine Architecture Hypotheses

*Shizuku*, *Kizuato*, and *To Heart* share Leaf's proprietary LVNS engine (Leaf Visual Novel System, 1996-1999):
- **Archives**: `MAX_DATA.PAK` (LEAFPACK container, 403 entries), `bgmfile.PAK` / `soundds.PAK` (LAC containers), `Sizuku.exe`.
- **Data Flow**: Boot → Load `MAX_DATA.PAK` → Fetch `SCN%03d.DAT` on demand (LZS3 decompression) → Outer event VM drives scenes, inner message VM drives dialogues and staging → Subsystems render `MAX_*.LFG` / `HVS*.LFG` via palette and column-major bit interleaving, draw 24×24 KNJ glyphs, and mix Ogg/WAV audio streams.
- **Canvas Resolution**: 640×400.
- **Scenario Scripts**: 197 SCN files divided into discrete blocks representing execution and bookmark checkpoints.

## 2. Verified Binary Formats

| Container / File | Format | Verification Evidence | Parser / Implementation |
|---|---|---|---|
| `MAX_DATA.PAK` | LEAFPACK | 403/403 files extracted | `leafpack.c` / `shizuku_cli` |
| `bgmfile.PAK` | LAC | 25 Ogg Vorbis streams | Custom LAC unpacker |
| `soundds.PAK` | LAC | 13 RIFF/WAV audio clips | Custom LAC unpacker |
| `*.LFG` | LEAFCODE | 640×400 16-color bitmaps | `lfgdec.c` / Swift Metal pipeline |
| `SCN*.DAT` | SCN | 197 scenario scripts | `decscn.py` / Swift Event VM |
| `KNJ_ALL.KNJ` | 1bpp font | 1,852 glyphs (133,344 bytes) | 24×24 vertical scan decoder |
| `SZ_VD*.P16` | 16-bit PCM | 11,025Hz mono waveform | `AVAudioConverter` resampler |

## 3. Bytecode and VM Mechanics

- SCN files package two separate data sections: Event Bytecode Section and Message String Section, each individually compressed with inverted-flag LZS3.
- Event opcodes (Jump `0x04`, Choice `0x05`, Background `0x0a`, H-Scene `0x16`, Portrait `0x22`, Conditional Branch `0x3d`/`0x3e`, Flag Math `0x47`/`0x48`, Dialogue `0x54`, BGM `0x6e`, Staff Roll `0x7d`) align with canonical GBALVNS and `script.c` specifications.
- 90% of dynamic staging (portraits, camera shake, white flashes, BGM cues) is driven by inline ASCII tokens directly embedded in the text stream.
