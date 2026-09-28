# Phase 0/1 Architecture Reverse Engineering & Feasibility Report
## Technical Survey for Native macOS Restoration of Leaf's *Shizuku* (1996 LVNS Engine)

> 🌐 **Language / 多语言**: [🇨🇳 简体中文](SHIZUKU_PORT_RESEARCH_REPORT.md) ｜ [🇺🇸 English](SHIZUKU_PORT_RESEARCH_REPORT-en.md) ｜ [🇯🇵 日本語](SHIZUKU_PORT_RESEARCH_REPORT-jp.md)

---

## 1. Executive Summary & Feasibility Matrix

This report synthesizes the preliminary reverse engineering findings and feasibility analysis for restoring Leaf's (now AQUAPLUS) seminal 1996 visual novel *Shizuku* (*雫～しずく～*) as a modern, native macOS application.

Through code audits of historical open-source efforts (XLVNS, MGLVNS, lfview, akkera's tools, GBALVNS) combined with byte-for-byte validation against retail game media, **the proprietary LVNS binary asset structures were proven to be fully coherent, self-contained, and completely viable for clean-room native reimplementation**.

| Component | Target Retail Assets | Cryptographic & Structural Insights | Native macOS Implementation Strategy |
|---|---|---|---|
| **Payload Archives** | `MAX_DATA.PAK` | 11-byte rolling additive XOR cipher; 24-byte directory slot recovery | Streamed Swift unpacker with automated key derivation (`ShizukuCore`) |
| **Audio Containers** | `bgmfile.PAK`, `soundds.PAK` | LAC container format; `bgmmap` offset formula & OST acoustic alignment | `AVAudioEngine` + `AVAudioPlayerNode` hardware-accelerated mixing |
| **Graphic Decoders** | `*.LFG` (LEAFCODE) | 16-color 4-bit palette nibble duplication; vertical column-major interleaving | Metal offscreen textures & compute/CPU bitplane decoding |
| **Script Engine** | `SCN*.DAT` (197 files) | Dual-segment inverted LZS3 decompression; outer/inner VM decoupling | Coroutine-driven Dual-Layer Virtual Machine (Event VM + Inline VM) |
| **Typography** | `KNJ_ALL.KNJ` | 24×24 1bpp vertical strip layout; direct 1-based Leaf code indexing | 1,852-glyph texture atlas + three-pass drop shadow rendering |

---

## 2. LVNS Architectural Overview

*Shizuku*, *Kizuato*, and *To Heart* established the foundation of Leaf's early visual novel engine family (LVNS: Leaf Visual Novel System, 1996–1999).

```text
                     ┌────────────────────────┐
                     │ Windows 95 Sizuku.exe  │
                     └───────────┬────────────┘
                                 │
        ┌────────────────────────┼────────────────────────┐
        ▼                        ▼                        ▼
 ┌─────────────┐          ┌─────────────┐          ┌─────────────┐
 │ MAX_DATA    │          │ bgmfile.PAK │          │ soundds.PAK │
 │ (LEAFPACK)  │          │ (LAC / Ogg) │          │ (LAC / WAV) │
 └──────┬──────┘          └─────────────┘          └─────────────┘
        │
   ┌────┴───────────────────────────┬──────────────────────┐
   ▼                                ▼                      ▼
197 SCN Scripts               195 LFG Images         1 KNJ Font
(Bytecode & Dialogue)         (16-color CGs/BGs)     (24x24 1bpp Bitmap)
```

1. **Execution Pipeline**: The engine initializes by mounting `MAX_DATA.PAK` directory indices and loading `SCN%03d.DAT` bytecode blocks on demand.
2. **Event & Message Decoupling**: SCN files are physically split into an Event section (state transitions, jumps, flags) and a Message section (dialogues, inline asset staging).
3. **Compositing**: The native canvas operates at 640×400 resolution, blending 16-color background and character planes.

---

## 3. Binary Asset Validation

### 3.1 LEAFPACK Archive Decryption
`MAX_DATA.PAK` (5,756,792 bytes) uses the proprietary LEAFPACK container, starting with an 8-byte magic header `"LEAFPACK"` followed by a uint16 little-endian file count (`0x0193` = 403 files).

The stream is obfuscated via an 11-byte rolling additive cipher:
$$\text{StoredByte} = (\text{PlainByte} + \text{Key}[k \bmod 11]) \bmod 256$$
Using the trailing space padding in 24-byte filename records, the key sequence `71 48 6a 55 9f 13 58 f7 d1 7c 3e` (`qHjU…`) was extracted directly from ciphertext statistics. All 403 assets extract cleanly.

### 3.2 LFG Graphics Decoding (LEAFCODE)
The 195 `*.LFG` images store 16-color 4-bit indexed palettes:
- **Nibble Expansion**: 4-bit channel nibbles are duplicated via `(nibble << 4) | nibble` to expand into standard 8-bit RGB channels.
- **Vertical Interleaving**: When `direction == 0` (vertical mode), pixels are stored in two-column vertical strips top-to-bottom, requiring linear rearrangement into row-major RGBA buffers.

### 3.3 SCN Bytecode Decompression
All 197 scenario scripts (`SCN000.DAT` to `SCN196.DAT`) package two distinct compressed segments using inverted-flag LZS3 (ring buffer `0x1011`). Decompression must truncate strictly at header-declared bounds to prevent trailing garbage bytes.

---

## 4. Modern Architecture & Platform Strategy

### 4.1 Abandoning Wine and Emulation Layers
Evaluation of Wine/emulation wrapper approaches revealed significant deficiencies:
1. **Audio Latency**: Legacy DirectSound interfaces suffer from jitter and loop timing misalignment under compatibility layers.
2. **Display Scaling**: Emulation layers fail to provide clean integer-ratio pixel scaling or native 60Hz display synchronization on Apple Silicon displays.
3. **HIG Integration**: Windows compatibility layers cannot offer macOS-native menu bars, trackpad swipe gestures, or modern JSON state persistence.

Consequently, the project committed to a clean-room **native Swift + Metal architecture**.

### 4.2 Decoupled Subsystem Architecture

```text
┌─────────────────────────────────────────────────────────┐
│               ShizukuApp (AppKit / HIG)                 │
│      Native Window, Menu Bar, Save/Load, Sound Room     │
├──────────────────────────┬──────────────────────────────┤
│ ShizukuEngine (Core VM)  │   ShizukuRender (Metal 3D)   │
│  Event VM + Inline VM    │  640x400 Target, Transitions │
├──────────────────────────┴──────────────────────────────┤
│               ShizukuCore (Foundation)                  │
│   Binary Stream, Crypto, LZS3, LFG Decoders, Font Atlas │
└─────────────────────────────────────────────────────────┘
```

---

## 5. Conclusion

This feasibility study confirms that retail Windows 95 assets for *Shizuku* are fully decipherable and robust. The architectural separation provides a solid theoretical and practical foundation for long-term digital preservation and high-fidelity native playback.
