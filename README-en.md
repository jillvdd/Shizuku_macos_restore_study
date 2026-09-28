# Shizuku_macos_restore_study
## Leaf LVNS Visual Novel Engine Reverse Engineering & Native macOS Restoration Repository
### Systems Engineering Postmortem & Source Study for Leaf's *Shizuku* (1996)

> 🌐 **Language / 多语言**: [🇨🇳 简体中文](README.md) ｜ [🇺🇸 English](README-en.md) ｜ [🇯🇵 日本語](README-jp.md)

---

## 📖 Overview

This repository is a comprehensive engineering and reverse engineering knowledge base for Leaf's (now AQUAPLUS) seminal 1996 visual novel *Shizuku* (*雫～しずく～*) and its underlying LVNS engine family.

It documents the end-to-end process of deconstructing legacy Windows 95 binary assets and reconstructing a high-fidelity, native 60Hz macOS application (Apple Silicon, Swift + Metal) from scratch, serving as a pragmatic guide for digital preservation and retro software restoration on modern Unix systems.

---

## 📑 Core Engineering Guides

A rigorous, three-language synchronized technical deep-dive into binary reverse engineering, state machine design, and modern OS migration:

- 🇨🇳 **[Chinese Engineering Guide](articles/leaf-galgame-port-zh.md)**: Comprehensive deep dive into rolling additive decryption, LZS3 truncation guards, 24x24 1bpp vertical font decoding, dual-layer VM coroutine design, palette darkening, 13 transition algorithms, and the clock tower (448, 128) hidden music room.
- 🇺🇸 **[English Technical Guide](articles/leaf-galgame-port-en.md)**: A rigorous, pragmatic systems engineering postmortem covering proprietary PAK cryptanalysis, dual-layer VM coroutine design, 24x24 1bpp vertical font decoding, CoreAudio exception swallowing, and Apple Silicon adaptations.
- 🇯🇵 **[Japanese Technical Specification](articles/leaf-galgame-port-jp.md)**: LVNS エンジンのバイナリ解析、2 層仮想マシン設計、描画および CoreAudio 障害追究、タイトル画面 VA 0x430ebc の第 5 不可視ポインタから導く隠し音楽室の復元など、全工程を実務的に解説した技術仕様書。

---

## 📐 Reverse Engineering Format Specifications

Field-level parsing specifications for legacy Windows 95 proprietary binary formats:

1. [**LEAFPACK Container Format & 11-byte XOR Decryption**](docs/containers.md): 8-byte header, uint16 file count, rolling additive XOR keystream, and differential blind cryptanalysis of directory slots.
2. [**LFG Image Format & Bit Interleaving**](docs/lfg.md): 16-color 4-bit palette nibble duplication (`(c << 4) | c`), vertical column-first bit interleaving, and 400px portrait staging viewports.
3. [**SCN Script Structure & Dual-Layer VM**](docs/scripts.md): Outer block jumping model, 13 skip opcodes, and inline ASCII macros (B/E, C, S, D, M, P, F, Q).
4. [**LAC Audio Container & BGM Mapping**](docs/audio.md): `bgmmap` conversion formula, CD-DA offset calibration, and acoustic fingerprinting with original OST.
5. [**LVNS Engine History**](docs/history.md): Technical evolution from PC-98 to Windows 95.
6. [**Windows 95 Original File Manifest**](docs/original-files.md): Functional breakdown and format catalog of retail disc assets.
7. [**Unknown Opcodes & 13 Skip Opcodes Analysis**](docs/unknown-opcodes.md): Operand width measurement and safe instruction advancing.
8. [**GBALVNS Architecture Reference**](docs/gbalvns.md): Open-source GBA port state machine and reference analysis.
9. [**GBA Port Comparative Study**](docs/sizuku-gba.md): Comparative analysis between PC original and handheld data structures.

---

## 📋 Research Reports & Systems Engineering Postmortems

Authoritative engineering postmortems, low-level debugging logs, and verification standards:

- [**Phase 0/1 Architecture & Feasibility Report**](reports/SHIZUKU_PORT_RESEARCH_REPORT.md): Initial format reverse engineering, toolchain evaluation, and data pipeline assessment.
- [**Engineering Handover Log & Postmortem (HANDOVER)**](reports/HANDOVER.md): Deep-dive postmortem covering 13 transition algorithms, disassembly of the hidden music room, mono 11,025Hz CoreAudio crash root causes, and macOS App Nap mitigation.
- [**Milestones & Acceptance Criteria**](reports/MILESTONES.md): Phased agile engineering milestones and multi-dimensional acceptance specifications.
- [**System Engineering Baseline & Reference**](reports/RESUME_PROMPT.md): Low-level hex offsets, memory map diagrams, and core architectural interface reference manual.

---

## 🗂 Complete Directory Structure

```text
Shizuku_macos_restore_study/
├── README.md                      # Primary knowledge base index (Chinese)
├── README-en.md                   # Primary knowledge base index (English)
├── README-jp.md                   # Primary knowledge base index (Japanese)
├── _config.yml                    # GitHub Pages (Jekyll) configuration
├── _layouts/                      # Web layouts with trilingual navbar and footer
│   └── default.html
├── assets/                        # Styling and static web assets
│   └── css/
│       └── style.css
│
├── articles/                      # Core engineering postmortems (ZH / EN / JP)
│   ├── leaf-galgame-port-zh.md    # Chinese Engineering Guide
│   ├── leaf-galgame-port-en.md    # English Technical Guide
│   └── leaf-galgame-port-jp.md    # Japanese Technical Specification
│
├── docs/                          # Binary format specifications (9 specs)
│   ├── containers.md              # LEAFPACK container & decryption spec
│   ├── lfg.md                     # LFG graphics & decoding spec
│   ├── scripts.md                 # SCN bytecode & dual-layer VM spec
│   ├── audio.md                   # LAC audio & BGM mapping spec
│   ├── history.md                 # LVNS engine historical evolution
│   ├── original-files.md          # Retail Windows 95 file manifest
│   ├── unknown-opcodes.md         # Unknown opcodes & skip analysis
│   ├── gbalvns.md                 # GBALVNS architecture reference
│   └── sizuku-gba.md              # GBA port comparative study
│
├── reports/                       # Full research reports & engineering logs (4 reports)
│   ├── SHIZUKU_PORT_RESEARCH_REPORT.md  # Phase 0/1 initial research
│   ├── HANDOVER.md                # Complete dev handover log (340KB)
│   ├── MILESTONES.md              # Milestones & acceptance criteria
│   └── RESUME_PROMPT.md           # Context resumption baseline
│
├── tools/                         # Analysis tools & extraction scripts
│   ├── shizuku_cli/               # Modular Python CLI package
│   └── scripts/                   # Standalone scripts (unpack, font, image, disasm)
│
├── disasm/                        # Full scenario script disassembly benchmarks
│   └── SCN000.txt ... SCN196.txt  # 197 disassembled SCN script dumps
│
├── preview/                       # Decoded visual assets & verification renders
│   ├── knj_atlas.png              # 1,852 glyph font atlas
│   ├── hvs01_decoded.png          # High-fidelity portrait asset (Ruriko)
│   ├── hvs01_from_tool.png        # CLI tool test render
│   ├── preview_bg01.png           # Decoded background preview
│   └── preview_leaf.png           # Palette & pixel verification frame
│
├── references/                    # Historical open-source references (mglvns, lfview, etc.)
│
└── runtime_reference/             # Modern Swift + Metal restoration reference
    ├── Package.swift              # Swift Package Manager manifest
    └── Sources/                   # ShizukuCore, ShizukuEngine, ShizukuRender, ShizukuApp
```

---

## 🛠 Key Reverse Engineering Breakthroughs

1. **LEAFPACK Archives & 11-Byte Rolling Keystream**:
   - Keystream: `71 48 6a 55 9f 13 58 f7 d1 7c 3e`
   - Reconstructed via differential blind cryptanalysis leveraging space padding in 24-byte filename records.
2. **LZS Variants & 173/197 Scenario Script Truncation**:
   - Differentiated standard LZS (LFG graphics) from inverted-flag `lzs3` (SCN scripts, ring buffer `0x1011`).
   - Discovered mandatory stream truncation by header-declared uncompressed size, resolving trailing garbage corruption across 173 scripts.
3. **KNJ Bitmap Font Layout & 1-based Direct Addressing**:
   - `KNJ_ALL.KNJ` (133,344 bytes) houses 1,852 glyphs (24x24 px, 1bpp, 72 bytes/glyph) organized into 3 vertical columns.
   - Proved that Leaf font codes are 1-based direct array indices (`code - 1`).
4. **Dual-Layer Nested VM Architecture (Event VM + Inline VM)**:
   - Classified 13 dummy skip opcodes in the outer event stream.
   - Identified that ~90% of visual effects, audio triggers, shakes, and flashes are embedded as inline ASCII tokens within dialogue text.
5. **High-Fidelity Visual Reproduction**:
   - 25x13 text grid with three-pass drop shadow glyph rendering and global `11/16` palette darkening.
   - Accurately reverse-engineered the outward spiral transition (GURUGURU) centered at `(27, 12)` in 16px tile blocks.
6. **Hidden Title Screen Music Room Disassembly**:
   - Extracted 5th invisible hit-test rectangle from EXE pointer table at VA `0x430ebc` mapping to clock tower coordinates `(448, 128)`.
   - Reconstructed the `0x408d40` music selector on `VIS17.LFG`.
7. **macOS Subsystem Adaptation**:
   - Solved silent crashes caused by mono 11025Hz WAV playback on stereo CoreAudio nodes using `AVAudioConverter`.
   - Prevented frame rate throttling to 5 FPS under macOS App Nap using `ProcessInfo.beginActivity`.

---

## 🚀 CLI Tool Usage

```bash
# Disassemble scenario script into readable assembly
python3 tools/scripts/shizuku-scn-disasm.py /path/to/SCN001.DAT -o SCN001.txt

# Export 24x24 KNJ glyph atlas
python3 tools/scripts/shizuku-knj-font.py /path/to/KNJ_ALL.KNJ --atlas preview/knj_atlas.png

# Decode LFG graphic asset
python3 tools/scripts/shizuku-lfg-image.py /path/to/HVS01.LFG -o preview/hvs01.png

# Modular CLI inspect and extract
python3 -m tools.shizuku_cli inspect /path/to/MAX_DATA.PAK
python3 -m tools.shizuku_cli extract /path/to/MAX_DATA.PAK -o output_dir/
```

---

## 📜 Copyright & Disclaimer

- The research documentation, reverse engineering tools, disassembled scripts, and runtime references in this repository are provided strictly for computer science education, software interoperability study, and digital heritage preservation.
- *Shizuku* and all associated characters, scenarios, music, and art assets are the intellectual property of Leaf / AQUAPLUS.
- This repository does not distribute proprietary retail game data.
