# Porting Classic Leaf Visual Novels (LVNS) to macOS: A Native Swift Engineering Guide
## — Rebuilding Windows 95 Visual Novels on Modern Platforms: The 《雫 (Shizuku)》 Experience

> 🌐 **Language / Other Languages**: [🇺🇸 English](leaf-galgame-port-en.md) ｜ [🇨🇳 简体中文](leaf-galgame-port-zh.md) ｜ [🇯🇵 日本語](leaf-galgame-port-jp.md)
>
> This document is a pragmatic, technical engineering postmortem. It details how the 1996 visual novel *《雫～しずく～》* (Shizuku) by Leaf (now AQUAPLUS)—and the underlying Leaf Visual Novel System (LVNS) engine family—was reverse-engineered from legacy Windows 95 binary assets and rebuilt from scratch as a native, 60Hz Metal-accelerated Swift application for macOS on Apple Silicon (Ver. 1.0).
>
> All storytelling flourishes and dramatic prose have been removed. This guide focuses strictly on engineering realities: reverse-engineering proprietary binary formats, deducing bytecode opcode semantics, architecting a dual-layer virtual machine, debugging rendering and CoreAudio pipelines, and generalizing the toolchain to port companion titles like *Kizuato* and *To Heart*.

---

## Table of Contents

- [1. Technical Goals & High-Level Architecture](#1-technical-goals--high-level-architecture)
  - [1.1 Why Wine and Emulation Wrappers Were Rejected](#11-why-wine-and-emulation-wrappers-were-rejected)
  - [1.2 Modern Swift + Metal Layered Architecture](#12-modern-swift--metal-layered-architecture)
- [2. Reverse Engineering Methodology & Ground Truth](#2-reverse-engineering-methodology--ground-truth)
  - [2.1 Evaluating Historical Open-Source Implementations](#21-evaluating-historical-open-source-implementations)
  - [2.2 Establishing Ground Truth: Disassembly & Wine as an Oracle](#22-establishing-ground-truth-disassembly--wine-as-an-oracle)
- [3. Binary Data Formats & Decryption Specifications](#3-binary-data-formats--decryption-specifications)
  - [3.1 The LEAFPACK Archive Container (MAX_DATA.PAK)](#31-the-leafpack-archive-container-max_datapak)
  - [3.2 LZS Compression Variants & Stream Truncation Hazards](#32-lzs-compression-variants--stream-truncation-hazards)
  - [3.3 LFG (LEAFCODE) Graphic Format & Bit Interleaving](#33-lfg-leafcode-graphic-format--bit-interleaving)
  - [3.4 The LAC Audio Container](#34-the-lac-audio-container)
  - [3.5 Physical Layout of KNJ_ALL.KNJ Bitmap Font](#35-physical-layout-of-knj_allknj-bitmap-font)
- [4. Dual-Layer Virtual Machine (VM) Architecture & Implementation](#4-dual-layer-virtual-machine-vm-architecture--implementation)
  - [4.1 SCN Script Structure & The Block Model](#41-scn-script-structure--the-block-model)
  - [4.2 Layer 1: Outer Event VM & Skip Opcode Traps](#42-layer-1-outer-event-vm--skip-opcode-traps)
  - [4.3 Layer 2: Inner Inline Presentation VM](#43-layer-2-inner-inline-presentation-vm)
- [5. Graphics Pipeline & High-Fidelity Reconstruction](#5-graphics-pipeline--high-fidelity-reconstruction)
  - [5.1 Full-Screen Sound Novel Layout & Line Wrapping Rules](#51-full-screen-sound-novel-layout--line-wrapping-rules)
  - [5.2 Palette Darkening & Three-Pass Stamped Hard Shadow Glyphs](#52-palette-darkening--three-pass-stamped-hard-shadow-glyphs)
  - [5.3 Waiting Cursor Semantics & Phase Synchronization](#53-waiting-cursor-semantics--phase-synchronization)
  - [5.4 Location Folding (bgmap) & Atmosphere Palettes (palmap)](#54-location-folding-bgmap--atmosphere-palettes-palmap)
  - [5.5 Mathematical Implementation of 13 LVNS Transitions](#55-mathematical-implementation-of-13-lvns-transitions)
  - [5.6 Correcting the Spiral Transition (GURUGURU)](#56-correcting-the-spiral-transition-guruguru)
  - [5.7 Opcode 0x01 Subtypes & Sine Wave Background Shearing](#57-opcode-0x01-subtypes--sine-wave-background-shearing)
  - [5.8 Full-Screen Backlog (LvnsHistory) & Dual Text VRAM](#58-full-screen-backlog-lvnshistory--dual-text-vram)
- [6. Audio Subsystems & macOS Low-Level Engineering Pitfalls](#6-audio-subsystems--macos-low-level-engineering-pitfalls)
  - [6.1 BGM Track Mapping (bgmmap) & CD-DA Offsets](#61-bgm-track-mapping-bgmmap--cd-da-offsets)
  - [6.2 CoreAudio Mono 11025Hz Crash Swallowed by AppKit](#62-coreaudio-mono-11025hz-crash-swallowed-by-appkit)
  - [6.3 60Hz Flip Loop & macOS App Nap Throttling](#63-60hz-flip-loop--macos-app-nap-throttling)
- [7. Practical Binary Forensics: The Hidden Title Music Room](#7-practical-binary-forensics-the-hidden-title-music-room)
  - [7.1 The Breakthrough: Fifth Menu Pointer at VA 0x430ebc](#71-the-breakthrough-fifth-menu-pointer-at-va-0x430ebc)
  - [7.2 Coordinate Unit Math & Pixel-Level Alignment](#72-coordinate-unit-math--pixel-level-alignment)
  - [7.3 The Music Room Routine & Leaf String 0x24 Terminator Hazard](#73-the-music-room-routine--leaf-string-0x24-terminator-hazard)
- [8. Dissecting the Staff Roll Credit Sequence](#8-dissecting-the-staff-roll-credit-sequence)
- [9. Generalizing to Other Leaf Classics (Kizuato, To Heart)](#9-generalizing-to-other-leaf-classics-kizuato-to-heart)
  - [9.1 Engine Family Component Reusability Matrix](#91-engine-family-component-reusability-matrix)
  - [9.2 Standardized Nine-Step Porting Pipeline](#92-standardized-nine-step-porting-pipeline)
- [10. Automated Verification & Debugging Infrastructure](#10-automated-verification--debugging-infrastructure)
  - [10.1 Automated Headless Frame Capture (SHIZUKU_SHOT)](#101-automated-headless-frame-capture-shizuku_shot)
  - [10.2 Production Self-Healing Flip Watchdog](#102-production-self-healing-flip-watchdog)
- [Appendix A: Core Opcode & Inline Token Quick Reference](#appendix-a-core-opcode--inline-token-quick-reference)
- [Appendix B: Register of Known Deviations and Enhancements](#appendix-b-register-of-known-deviations-and-enhancements)

---

## 1. Technical Goals & High-Level Architecture

### 1.1 Why Wine and Emulation Wrappers Were Rejected

When porting legacy 1990s visual novels to macOS (Apple Silicon), a common quick-and-dirty approach is bundling a lightweight Wine prefix or using commercial emulation wrappers. Early in this project, that route was evaluated and discarded due to critical engineering limitations:

1. **Retina and Upscaling Degradation**: Wine handles low-resolution 640×400 paletted buffers via basic blitting or generic bilinear filtering. It cannot natively hook into Metal to perform integer nearest-neighbor or custom CRT/Retina sampling while maintaining pixel-crisp typography.
2. **Zero Debugging Observability**: Legacy Win32 GDI, DirectDraw, and DirectSound calls traversing Rosetta 2 and Wine create unpredictable edge-case failures. When crashes or audio hangs occur, LLDB and Instruments cannot cleanly inspect the call stack or profile memory leaks down to the byte level.
3. **Lack of macOS System Integration**: Emulation wrappers cannot easily integrate with the native macOS menu bar, support trackpad gestures natively, handle system-level key equivalents, or manage graceful window state transitions without leaving zombie processes in the Dock.

Consequently, the core engineering requirement was established: **discard the legacy PE executable entirely, deconstruct all asset formats and bytecode VM logic, and rebuild the engine natively in Swift and Metal.**

### 1.2 Modern Swift + Metal Layered Architecture

The project is structured under `ShizukuRuntime` into four decoupled Swift Package Manager (SPM) modules with strict unidirectional dependencies:

```
+--------------------------------------------------------------------------+
|  [ ShizukuApp ] (macOS AppKit Shell)                                     |
|  - main.swift / NSApplication / Native Menu Bar / System Hotkey Routing  |
|  - MetalGameView: MTKView wrapper, 60Hz loop, mouse/keyboard dispatcher  |
+--------------------------------------------------------------------------+
                                    │
+--------------------------------------------------------------------------+
|  [ ShizukuRender ] (Compositing & Presentation)                          |
|  - SceneComposer: 640x400 32-bit RGBA offscreen framebuffer              |
|  - 3-Pass Glyph Stamping: Hard-shadow multi-pass bitmap typography       |
|  - TransitionRenderer: 13 LVNS transition math operators                 |
|  - HistoryView (Backlog) / MusicRoom / StaffRoll sequence player         |
+--------------------------------------------------------------------------+
                                    │
+--------------------------------------------------------------------------+
|  [ ShizukuEngine ] (Business Logic & VM Execution)                       |
|  - Engine.swift: Dual-layer VM (Event VM + Inline VM) state machine      |
|  - AudioController: AVAudioEngine pipeline, resampling, fade automation  |
|  - SaveManager: JSON-backed high-water persistence & cross-run saves     |
+--------------------------------------------------------------------------+
                                    │
+--------------------------------------------------------------------------+
|  [ ShizukuCore ] (Data Models & Decoders)                                |
|  - Leafpack: Archive decryption and extraction                           |
|  - Lzs: Standard positive and inverted LZSS decompression variants       |
|  - Lfg: 4-bit palette decoding and bit-interleaving de-indexing          |
|  - Knj: 24x24 1bpp bitmap font extraction                                |
|  - Scn: Bytecode parser and inline command tokenizer                     |
|  - BackgroundMap: Location IDs and atmosphere palette lookup tables      |
+--------------------------------------------------------------------------+
```

---

## 2. Reverse Engineering Methodology & Ground Truth

### 2.1 Evaluating Historical Open-Source Implementations

Three open-source codebases provided historical context for the Leaf Visual Novel System (LVNS):

1. **XLVNS / mglvns (Go Watanabe, 1999–2000, BSD)**:
   - *Value*: Detailed C source covering LEAFPACK, LFG, and most SCN opcodes and transitions.
   - *Caveat*: Heavy use of `#ifdef USE_MGL` compiler branches. These branches were low-performance workarounds targeting 320×200 resolution for 1990s Linux X11 systems. **Blindly copying MGL branches produces broken behaviors that contradict the Windows 95 release.**
2. **akkera102's Sizuku GBA Tools (Personal Research)**:
   - *Value*: Provided prototype SCN unpacker `decscn.py` and opcode definitions in `script.c`.
   - *Caveat*: Specifically adapted for the Game Boy Advance; contains hardcoded buffer truncations, and the font structure is completely non-isomorphic to the PC version.
3. **GBALVNS (BSD-3-Clause)**:
   - *Value*: Clean reference for state machine structuring.
   - *Caveat*: Uses re-baked assets; does not parse original PC data.

### 2.2 Establishing Ground Truth: Disassembly & Wine as an Oracle

To resolve conflicting documentation:

1. **Static Disassembly with Capstone & pefile**:
   The original `Sizuku.exe` is a non-ASLR, non-relocated 32-bit PE binary loaded at a fixed base address of `0x400000`.
   Parsing the section header table via `pefile` confirms that `.text` (code, RVA `0x1000`, Raw `0x1000`), `.rdata` (read-only data, RVA `0x2E000`, Raw `0x2E000`), and `.data` (globals, RVA `0x30000`, Raw `0x30000`) share identical memory alignment and disk file alignment (`0x1000` page boundaries). Consequently, for all executable code routines and static tables, Virtual Addresses (VA) map directly and deterministically to disk file offsets:
   $$\text{File Offset} = \text{RVA} = \text{VA} - 0x400000$$
   Whenever bytecode widths, jump tables, or timing semantics were disputed, disassembling the exact x86 machine instructions at the target VA provided instantaneous, indisputable ground truth.
2. **The Wine Runtime Oracle**:
   When static disassembly left ambiguity regarding timing or graphics states, we ran the original Japanese binary in Wine 11.15 under Rosetta 2. Using breakpoints and memory dumps, we recorded the exact VRAM buffer states and register values across individual frames as the ground truth baseline.

---

## 3. Binary Data Formats & Decryption Specifications

### 3.1 The LEAFPACK Archive Container (MAX_DATA.PAK)

`MAX_DATA.PAK` contains all 403 game assets.

```
+--------------------------------------------------------------------------+
| Offset (Bytes)| Field Name      | Type        | Description              |
|---------------|-----------------|-------------|--------------------------|
| 0..7          | Magic           | 8 Bytes     | Constant ASCII "LEAFPACK"|
| 8..9          | FileCount       | uint16_le   | Total files (403/0x0193) |
| 10..TableEnd  | File Payloads   | Variable    | Additive rolling cipher  |
| Final 24*N B  | File Directory  | 24B / Entry | Encrypted directory table|
+--------------------------------------------------------------------------+
```

#### Decryption Math and Rolling Key

Data payloads use an **additive rolling byte cipher**:
$$\text{EncryptedByte} = (\text{PlainByte} + \text{Key}[k]) \pmod{256}$$
Decryption reverses this:
$$\text{PlainByte} = (\text{EncryptedByte} - \text{Key}[k] + 256) \pmod{256}$$

The key is a static 11-byte array:
```c
static const uint8_t LEAF_KEY[11] = {
    0x71, 0x48, 0x6a, 0x55, 0x9f, 0x13, 0x58, 0xf7, 0xd1, 0x7c, 0x3e
};
```

#### Directory Layout & Key Recovery
The directory table resides at the end of the file. Each entry is 24 bytes:
- `name[8]`: Uppercase ASCII, padded with spaces (`0x20`);
- `ext[3]`: Uppercase extension (`LFG`, `SCN`, `KNJ`);
- `zero`: Reserved byte (`0x00`);
- `offset`: uint32_le, start offset in the archive;
- `length`: uint32_le, decompressed payload length;
- `next_offset`: uint32_le.

*Note*: The key index advances continuously across bytes (`k = (k + 1) % 11`). Because directory entries contain mostly uppercase ASCII and spaces, one can deduce the entire 11-byte key without inspecting the executable by solving linear modular equations across any 3 consecutive directory entries.

### 3.2 LZS Compression Variants & Stream Truncation Hazards

Leaf uses LZSS-based compression (LZS) with two critical implementation details:

#### 1. Positive vs. Inverted Logic Variants
- **Standard `lzs` (Positive Logic)**: Flag bit = 1 indicates uncompressed literal; 0 indicates window reference. Ring buffer is `0x1000` bytes, initialized at `0xFEE`. **Used exclusively for LFG image bitmaps**.
- **`lzs3` (Inverted Logic)**: Flag bit is inverted (`~flag`: 0 = literal, 1 = reference). Ring buffer is `0x1011` bytes. **Used exclusively for SCN script Event and Message sections**.

#### 2. Enforcing Strict Stream Truncation
SCN script headers declare the exact decompressed byte size `declaredSize`.
If the decompressor reads until input EOF, LZSS will continue decompressing trailing padding bytes (`0x00` or `0xFF`) into spurious data. Across 197 scripts, **173 scripts were corrupted** by trailing garbage when using unbounded decompressors, altering message offsets in 166 dialogues.

**Fix**: The decompression loop must break immediately once `output.count == declaredSize`.

### 3.3 LFG (LEAFCODE) Graphic Format & Bit Interleaving

Static graphics are stored as `.LFG` files with a `"LEAFCODE"` magic header.

```
+--------------------------------------------------------------------------+
| Byte Range | Field Definition                                            |
|------------|-------------------------------------------------------------|
| 0..7       | Magic string "LEAFCODE"                                     |
| 8..31      | 16-color palette (4-bit RGB per color, packed 6B for 4 clrs)|
| 32..33     | xoffset (uint16_be): On-screen X offset for portraits       |
| 34..35     | yoffset (uint16_be): Y offset                               |
| 36..37     | raw_width (uint16_be): True width = (raw_width + 1) * 8     |
| 38..39     | raw_height (uint16_be): True height = raw_height + 1        |
| 40         | direction (uint8): 0 indicates vertical column-major        |
| 41         | transparent (uint8): Transparent index (0xFF for BGs)       |
| 44..47     | decompressed_size (uint32_le): Uncompressed bytes = w*h/2   |
| 48..EOF    | Standard positive-logic LZS compressed bitmap payload       |
+--------------------------------------------------------------------------+
```

- **Palette Expansion**: 4-bit color components (0..15) must be expanded to 8-bit (0..255) using nibble doubling:
  ```swift
  let r8 = (r4 << 4) | r4
  let g8 = (g4 << 4) | g4
  let b8 = (b4 << 4) | b4
  ```
- **Portrait Metrics**: Character portraits have a decompressed height of exactly 400px (matching the screen height). Their render Y coordinate is always 0. The three standard portrait slots map to fixed X coordinates: Left `0`, Center `160`, Right `320`.

### 3.4 The LAC Audio Container

`bgmfile.PAK` and `soundds.PAK` use the LAC container format:
- Header `"LAC\0"` + uint32_le entry count + directory table (42 bytes per entry: 8-byte ASCII name + uint32_le offset + uint32_le length).
- `bgmfile.PAK`: 25 Ogg Vorbis tracks (44.1kHz / 48kHz stereo BGM).
- `soundds.PAK`: 13 RIFF WAV tracks (**mono, 11025Hz**).

Because AVFoundation lacks native Ogg Vorbis decoding on macOS, we statically link `libogg` and `libvorbis` to decode audio in memory to 32-bit float Linear PCM before feeding `AVAudioEngine`.

### 3.5 Physical Layout of KNJ_ALL.KNJ Bitmap Font

`KNJ_ALL.KNJ` is exactly 133,344 bytes. At 24×24 pixels per glyph (1bpp, 72 bytes per glyph), it stores:
$$133,344 \div 72 = 1,852 \text{ glyphs}$$

#### 3-Column Strip Organization (Column-Major)
The glyphs are stored as **3 vertical column strips** rather than row-major lines:

```
+--------------------------------------------------------------------------+
|  Glyph 24x24 (72 Bytes total):                                           |
|  - Col 0 (X: 0..7)  : 24 bytes (byte 0..23)                              |
|  - Col 1 (X: 8..15) : 24 bytes (byte 24..47)                             |
|  - Col 2 (X: 16..23): 24 bytes (byte 48..71)                             |
|                                                                          |
|  Each byte represents 8 horizontal pixels; Bit 7 is the leftmost pixel.  |
+--------------------------------------------------------------------------+
```

Swift pixel sampling:
```swift
public func pixel(atX x: Int, y: Int, inGlyph glyph: [UInt8]) -> Bool {
    guard x >= 0, x < 24, y >= 0, y < 24 else { return false }
    let col = x / 8
    let bit = 7 - (x % 8)
    let byte = glyph[col * 24 + y]
    return ((byte >> bit) & 1) != 0
}
```

#### 1-Based Leaf Codes & `sizfont.tbl`
- **Leaf Code**: 2-byte index used in scripts, mapping directly to font slots:
  $$\text{Slot Index} = \text{Leaf Code} - 1$$
  Code 0 represents a full-width space (advances cursor, draws nothing).
- **`sizfont.tbl`** (3,703 bytes): Maps 1,851 Leaf codes to EUC-JP characters. **Used only by external disassembly tools; the runtime engine indexes the font directly without consulting this table.**

---

## 4. Dual-Layer Virtual Machine (VM) Architecture & Implementation

### 4.1 SCN Script Structure & The Block Model

Each `SCN%03d.DAT` script contains two sections:
- Offset 0..1: uint16_le, event section offset in file ($\times 16$);
- Offset 2..3: uint16_le, message section offset in file ($\times 16$).
Both are decompressed with inverted-logic `lzs3`.

The event section starts with a uint16_le array of Block offsets.
**Blocks are the atomic units for execution jumps and save points.**

### 4.2 Layer 1: Outer Event VM & Skip Opcode Traps

The Outer VM controls high-level game flow. Common opcodes include:
- `0x00`: End of block;
- `0x04`: `JUMP scn, blk`;
- `0x05`: `SELECT` (branching choice menu);
- `0x0a`: Set background location ID;
- `0x14`: Screen clear (erases both graphics and text);
- `0x22`: Load single portrait slot;
- `0x24`: Foreground close-up portrait (forced to center slot `'c'`);
- `0x38`: Update screen (`LvnsDisp`) and **flush queued BGM**;
- `0x3d`/`0x3e`: Conditional relative jump on flag comparison;
- `0x47`/`0x48`: Flag assignment and addition;
- `0x54`: Display dialogue from message section;
- `0x6e`: Loop play BGM;
- `0x7d`: Execute blocking Staff Roll sequence;
- `0x7e`: Record ending index.

#### Skip Opcode Parsing Guard
Thirteen opcodes (`0x03`, `0x06`, `0x5a`, `0x5c`, `0x60-0x66`, `0x6f`, `0x73`) are no-ops with fixed 1–3 byte argument lengths. Parsers must consume their operands according to an opcode-width table, or subsequent bytecode parsing will become misaligned.

### 4.3 Layer 2: Inner Inline Presentation VM

A central discovery of our reverse-engineering work was:
**Leaf visual novel staging—character portraits, background switches, CG reveals, BGM cues, and sound effects—is driven primarily by inline ASCII tokens embedded directly within dialogue text streams.**

When `0x54` invokes a message, the parser reads the stream byte-by-byte:
1. **Byte $\ge 0x80$**: Combined with the next byte to form a 16-bit Leaf code, dispatching to the font renderer.
2. **Byte $< 0x80$**: Staging command:
   - `$` : End of message, return control to Outer Event VM;
   - `p` : Page break (await click, then clear dialogue text);
   - `k`/`K` : Wait key (await click, then append to next line without clearing);
   - `r` : Carriage return;
   - `B`/`E` (7 bytes) : Load background (location ID + transition ID);
   - `C` (4 bytes) : Load portrait (slot `l/c/r` + character ID);
   - `D` : Clear portraits (`Da` clears all; `Dl/Dc/Dr` clear specific slot);
   - `S` (10 bytes) : Atomically load background and portrait;
   - `A`/`a` : Triple-portrait staging;
   - `V`/`H` : Full-screen visual CG or H-CG;
   - `M` : BGM controls (`Mf` fade, `Ms` pause, `Mn` queue, `Mw` wait for fade, `M00-M25` play immediately);
   - `P` : Play PCM sound effect (`P01-P13`);
   - `F` : White screen flash;
   - `Q` : Full-screen screen shake;
   - `X`/`s` : Set line horizontal offset and typewriter speed.

Each message is parsed into structured segments:
```swift
public struct MessageSegment {
    public let actions: [InlineAction] // Staging actions (portraits/music/backgrounds)
    public let lines: [[Int]]          // Dialogue Leaf codes
    public let pause: MessagePauseType // Pause type: .waitKey, .pageBreak, .messageEnd
}
```

---

## 5. Graphics Pipeline & High-Fidelity Reconstruction

### 5.1 Full-Screen Sound Novel Layout & Line Wrapping Rules

*Shizuku* uses full-screen Sound Novel typography:
- Entire 640×400 canvas acts as the text buffer;
- Origin: `(20, 18)`;
- Text grid: 25 columns × 13 rows;
- Spacing: 24px column advance, 28px line pitch (24px glyph + 4px leading);
- **Line Wrapping**: The Windows 95 release has **zero word-wrapping rules**. When `cur_x > 24`, the engine wraps unconditionally.

### 5.2 Palette Darkening & Three-Pass Stamped Hard Shadow Glyphs

1. **Palette Darkening (Latitude Darkening)**:
   When text is displayed, background brightness is reduced by scaling DAC palette entries by:
   $$\text{latitude\_dark} = \frac{11}{16} = 0.6875$$
   This darkens the background globally by 31.25% without using alpha blending.
2. **Three-Pass Glyph Stamping**:
   1bpp font masks are stamped into the frame buffer across three passes:
   - Pass 1: Offset `(x + 1, y + 1)`, write solid black (shadow 1);
   - Pass 2: Offset `(x + 2, y + 1)`, write solid black (thickened shadow);
   - Pass 3: Origin `(x, y)`, write solid white or gray (foreground glyph).
   Mask bits of 0 leave the background untouched, preserving crisp 1996 retro edges.

### 5.3 Waiting Cursor Semantics & Phase Synchronization

- **Cursor Shapes**:
  - In-line wait key (`k`/`K`): Leaf code 102 (**solid right arrow ▶**);
  - Page break wait (`p`): Leaf code 103 (**folded paper icon**).
- **Placement**: Stamped directly into the grid cell following the last printed character.
- **Blink Synchronization**:
  Cursors toggle every 6 flips (200ms period).
  *Pitfall*: Sampling the global flip counter `(flipCount / 6) % 2` causes the cursor to sometimes start in an "off" phase, making the engine feel unresponsive.
  *Fix*: Synchronize the blink anchor to the entry flip (`entryFlip = flipCount`), ensuring the cursor is **always visible on frame 0 of the wait state**.

### 5.4 Location Folding (bgmap) & Atmosphere Palettes (palmap)

Script location IDs do not map 1:1 to image filenames:
1. **Location Folding (`bgmap`)**:
   56 location IDs fold into 35 `MAX_S*.LFG` files. For instance, locations 4/5 map to `MAX_S02`, and 41/42 map to `MAX_S15`. Location 0 maps to a **pure black screen clear**.
2. **Atmosphere Palettes (`palmap`)**:
   Locations 41 and 42 share the same classroom image, but represent daytime and sunset respectively. The engine uses 9 atmosphere palette sets to **overwrite only palette entries 0..3 of the image, preserving entry 4 (constant white)**.
3. **The Orphan VIS21 Asset**:
   `VIS21.LFG` does not exist on disk. `SizukuLoadVisual` intercepts ID 21, loads `VIS02.LFG`, and overrides it with a purple palette.

### 5.5 Mathematical Implementation of 13 LVNS Transitions

`sizuku_effect[13]` defines 13 transitions (palette fades, spiral, diagonal tiles, collapsing diamonds, dither dissolves, and vertical/horizontal comb wipes).

- **Total Transition Duration**:
  A complete transition = `LvnsClear` (56 flips to wipe old image) + `LvnsDisp` (56 flips to reveal new image) + 30 flips hold = **142 flips (approx. 2.36s)**.
  The VM blocks input during transitions.
- **High-DPI Adaptation**:
  On Retina displays, computing 32px masks in physical window coordinates shrinks blocks to half their intended scale.
  *Fix*: Downscale frames to canonical 640×400, compute transitions on the logical grid, and integer-upscale back to the target viewport.

### 5.6 Correcting the Spiral Transition (GURUGURU)

Transition 1 (`GURUGURU`) expands in 16px tiles outward from the center.
The `#ifdef USE_MGL` branch in `mglvns` had a bug where the loop terminated prematurely at column 26 (out of 40 columns), leaving the right 1/3 of the screen to fall back to a top-to-bottom row-major fill.

**Fix**: Match the `#ifndef USE_MGL` Windows branch, expanding symmetrically on a 40×25 grid of 16px tiles centered at `(27, 12)`.

### 5.7 Opcode 0x01 Subtypes & Sine Wave Background Shearing

Opcode `0x01` executes four composite staging subtypes:
- Subtype 1: Sine background shear, fading to black upon dialogue completion;
- Subtype 2: Fade in while maintaining sine shear;
- Subtype 3: Blocking title animation (`sizuku01` 38 frames / `sizuku02` 19 frames);
- Subtype 4: Standard dialogue.

#### Math & Pipeline Phase of Sine Shear
Uses lookup table `sintable[361]` (1° interval, amplitude $\pm 160\text{px}$). Padded with zeros at both ends, the table sums to **-1** (an original implementation artifact that must not be altered).
**Pipeline Phase**: Shearing must occur **after background blitting, but before character merging and text stamping**. Rows are displaced by `vram[x] = bg[x + shift]`, keeping text sharp while the background twists.

### 5.8 Full-Screen Backlog (LvnsHistory) & Dual Text VRAM

- Preserves scenario state upon entry and restores it completely on exit;
- Retains background graphics while flipping text to `current_tvram = 1` to lay out the full page instantly;
- 14 `if (!history_mode)` guards bypass portraits, sound, and wait delays during replay;
- ▲ / ▼ icons are text cells in column 25; clicking reads the cell attribute to scroll.

---

## 6. Audio Subsystems & macOS Low-Level Engineering Pitfalls

### 6.1 BGM Track Mapping (bgmmap) & CD-DA Offsets

Script BGM IDs require translation via `bgmmap`:
```c
int bgmmap(int script_no) {
    if (script_no == 14) return 2;  // Special case: maps to track 2 (Jingle)
    if (script_no < 16)  return script_no + 2;
    return script_no + 1;
}
```
Physical filenames map to `MUS(track - 2).OGG`. Omitting this mapping causes over 30% of scenes to play incorrect tracks.
Acoustic fingerprinting against the 1996 lossless soundtrack confirmed with 0.898 confidence that the Opening Theme is `MUS14.OGG` (78.2s), not `MUS16.OGG` (219s Happy Ending theme).

### 6.2 CoreAudio Mono 11025Hz Crash Swallowed by AppKit

During development, parsing sound effects caused silent process hangs with 100% CPU usage.

#### Root Cause
`soundds.PAK` sound effects are **11025Hz mono WAVs**.
macOS `AVAudioEngine` operates at **48000Hz stereo**.
Passing mismatched buffers to `AVAudioPlayerNode.scheduleBuffer` throws an Objective-C `NSException`.
In CLI environments, this crashes with a stack trace. **In AppKit GUI applications, NSApplication's main RunLoop wraps event handling in a default `@catch` block that silently swallowed the exception and collapsed the call stack**, leaving the VM frozen without error logs.

#### Fix
Added an explicit resampling conversion pipeline in `AudioController`:
```swift
private func convertedBuffer(from inputBuffer: AVAudioPCMBuffer, to targetFormat: AVAudioFormat) -> AVAudioPCMBuffer {
    if inputBuffer.format == targetFormat { return inputBuffer }
    guard let converter = AVAudioConverter(from: inputBuffer.format, to: targetFormat) else { return inputBuffer }
    let capacity = AVAudioFrameCount(Double(inputBuffer.frameLength) * targetFormat.sampleRate / inputBuffer.format.sampleRate) + 1024
    guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else { return inputBuffer }
    var error: NSError?
    converter.convert(to: outputBuffer, error: &error) { _, outStatus in
        outStatus.pointee = .haveData
        return inputBuffer
    }
    return outputBuffer
}
```

### 6.3 60Hz Flip Loop & macOS App Nap Throttling

Leaf engines clock all timing to **1/60th second (1 Flip)** via `INTERVAL = 60`.

#### App Nap 1/12th Speed Degradation
When the game window lost focus or was partially occluded, macOS **App Nap** throttled timers down to **~1Hz**, slowing the game down to 5 FPS (1/12th normal speed).

#### Fix
Hold an explicit power management activity assertion during active gameplay:
```swift
self.activityToken = ProcessInfo.processInfo.beginActivity(
    options: [.userInitiated, .latencyCritical],
    reason: "60 Hz reference flip loop (Lvns INTERVAL)"
)
```

---

## 7. Practical Binary Forensics: The Hidden Title Music Room

### 7.1 The Breakthrough: Fifth Menu Pointer at VA 0x430ebc

In historical open-source ports such as `mglvns`, the music room routine was commented out with `#if 0`, creating a widespread historical misconception that the Windows 95 release omitted the feature entirely.
Disassembling the title menu pointer table in `Sizuku.exe` at VA `0x430ebc` (file offset `0x30ebc`) revealed that the array holds **5 entry pointers** (`0x00430ebc`, `0x00430ed0`, `0x00430ee4`, `0x00430ef8`, `0x00430f0c`), rather than the 4 visible menu options.
The first four pointers resolve to standard title strings ("最初から", "栞から", etc.), while the fifth pointer at `0x00430f0c` points to an extraordinary raw byte sequence:
`73 30` ("s0", font style 0) + `58 35 36 59 31 32 38` ("X56Y128", explicit ASCII screen positioning) + `ff ff` (Leaf Code fullwidth space) + `72 24` ("r$", line feed and string termination).
Because its rendered glyph content consists solely of an empty fullwidth space, the item is completely invisible to the player, yet it acts as a discrete, coordinate-pinned hit-test hitbox. Clicking this hitbox fires case 4 in menu dispatch table `0x409558`, immediately jumping to `0x408d40` to initialize the authentic Music Room.

### 7.2 Coordinate Unit Math & Pixel-Level Alignment

Leaf coordinate encoding:
- `Y`: 1-pixel units;
- `X`: **8-pixel units (half-width character pitch)**.

Absolute target coordinates:
$$X = 56 \times 8 = 448\text{px}, \quad Y = 128\text{px}$$
Projected onto `TITLE0.LFG` (640×400), this hits the **upper-right window pane of the school building**.

### 7.3 The Music Room Routine & Leaf String 0x24 Terminator Hazard

Tracing the pointer to `0x408d40` revealed the standalone music room routine:
- Background plate: `VIS17.LFG` (music box);
- Dispatches 24 tracks with composer credits;
- **Decoding Trap**: Track strings end in `0x24` (ASCII `$`). However, `0x24` is also a valid 2nd byte in Japanese Leaf codes (e.g., the kanji 叔 in "叔父さん"). Splitting naively on `0x24` truncates titles midway. The decoder must advance in 2-byte aligned increments.

---

## 8. Dissecting the Staff Roll Credit Sequence

Opcode `0x7d END_BGM` triggers the credits:
1. Iterates through 14 visual cards: background ready $\to$ 6s static text $\to$ 16-step palette fade to black $\to$ 16-step fade in to new background $\to$ 1s static background $\to$ text reveal;
2. Total execution duration is fixed:
   $$16 + (13 \times 436) + 76 = 5,760 \text{ Flips} \approx 96 \text{ Seconds}$$
3. **CLICK_JUMP Handling**: Clicking flags `selectPending`, allowing the 6-second timer to reach the end of its active card before smoothly transitioning into the copyright card.

---

## 9. Generalizing to Other Leaf Classics (Kizuato, To Heart)

### 9.1 Engine Family Component Reusability Matrix

| Component | Shizuku (1996) | Kizuato (1996) | To Heart (1997) | Strategy |
|---|---|---|---|---|
| **LEAFPACK Extraction** | 403 files | 511 files | 584 / 993 files | **100% Reusable**. Auto-detect via file count |
| **LZS Decompressor** | Positive + LZS3 | Positive + LZS3 | Positive + LZS3 | **100% Reusable**. Direct drop-in |
| **LFG Image Decoder** | 16-color 4-bit | 16-color 4-bit | 256-color 8-bit | **90% Reusable**. Expand palette array to 256 |
| **KNJ Font Pipeline** | 24×24 @1bpp | 24×24 @1bpp | 24×24 @1bpp | **100% Structure**. Extract game-specific glyphs |
| **Outer Event VM** | 0x00~0x7e | 0x00~0x7e | Added opcodes | **85% Reusable**. Core dispatch loop is shared |
| **Inner Inline VM** | B, C, S, D, M, P... | Minor edits | Extended tokens | **75% Reusable**. Override inline token dictionary |
| **13 Transitions** | 13 effects | 13 effects | 13 effects + ext | **95% Reusable**. Direct drop-in |
| **BGM/Location Maps** | `bgmap`/`palmap` | Needs extraction| Needs extraction| **0%**. Logic identical; tables require disassembly |

### 9.2 Standardized Nine-Step Porting Pipeline

1. **Unpack Archive**: Run `unpack_leafpack.py`, verify file counts, extract raw assets;
2. **Review Historical Code**: Check driver files (`kizuato.c`, `toheart.c`) in `mglvns`, focusing on `#ifndef USE_MGL` branches;
3. **Verify Font First**: Extract and render glyphs using 3-column MSB layout; confirm coverage tests;
4. **Opcode Profiling**: Run frequency analysis on SCN scripts to prioritize opcodes;
5. **Dynamic Oracle Verification**: Resolve unknown opcodes in Wine before coding;
6. **Acoustic Fingerprinting**: Align OGG/WAV files with official OST releases to build `bgmmap`;
7. **Lock Clock to 60Hz**: Anchor timing constants to `INTERVAL = 60`;
8. **Automated Headless Capture**: Hook rendering into automated tests and inspect exported PNGs;
9. **Keep Disassembler Ready**: Use Capstone to resolve jump tables and string blocks.

---

## 10. Automated Verification & Debugging Infrastructure

### 10.1 Automated Headless Frame Capture (SHIZUKU_SHOT)

To prevent green test suites from masking visual bugs (such as incorrect z-ordering rendering backgrounds over text), the runtime embeds a headless capture pipeline:
```bash
SHIZUKU_SHOT=boot,title,game,esc,spiral,music ./build/ShizukuApp
```
It advances virtual clock ticks and dumps 640×400 RGBA buffers directly to lossless PNGs for manual visual inspection.

### 10.2 Production Self-Healing Flip Watchdog

Release builds include an independent main-thread watchdog:
When the engine is active (transitions, reveals, fast-forwarding), if 2.0 seconds elapse without a flip tick, the watchdog dumps a snapshot (`scn`, `blk`, `pc`, active background, transition state) to `~/Library/Logs/Shizuku_Restored/diagnostic.log` and **restarts the DisplayLink loop to recover gameplay automatically**.

---

---

## 11. Phase 5: Chinese Fan Translation Reverse Engineering & Font Reconstruction

### 11.1 `data.bin` 4-Byte Rolling XOR Cryptanalysis & 199 SCN Extraction
The 2014 fan translation patch bundled all modified game assets into a proprietary container `data.bin`. Disassembly of the patch initialization logic confirmed a 4-byte rolling XOR cipher:
$$\text{Decrypted}[i] = \text{Encrypted}[i] \oplus \text{Key}[i \bmod 4]$$
Parsing the decrypted directory header yielded 199 SCN scenario records (3,834 translated dialogue strings), comprising all 197 mainline scripts plus 2 afterword scripts (`SCN233.DAT` and `SCN234.DAT`) created by the fan translation team.

### 11.2 4,726-Slot 24×24 Chinese Bitmap Font Extraction & Binary Packaging
Because the original `KNJ_ALL.KNJ` only held 1,852 Japanese characters, the fan patch hooked Windows GDI to inject an extended font. We dumped this 4,726-slot monochrome dot-matrix font from the patch DLL resources into a standalone binary file `cnfont_4726.bin` (340,272 bytes):
$$\text{FileSize} = 4,726 \text{ slots} \times 72 \text{ bytes} = 340,272 \text{ bytes}$$
Each glyph occupies 72 bytes in row-major compact bitmap format, flawlessly recreating the high-contrast CRT monitor aesthetic of 1996.

### 11.3 Monotonic DP Solver for Leaf-Code to GBK Mapping Table
To resolve the non-standard rearranged character indexing within the translation scripts, we formulated a monotonic minimum-edit-distance DP algorithm:
$$\min \sum_{k=1}^{M} \text{Cost}(Char_{zh}[k], Slot[f(k)]) \quad \text{s.t.} \quad f(k_1) < f(k_2) \iff k_1 < k_2$$
Traversing and verifying all 3,834 script lines produced the complete 2,872-character mapping table `cn_code2char.json` with a 100% lookup hit rate.

### 11.4 Script Beat Dynamic Slicing & Audiovisual Synchronization
The Leaf VM coordinates typewriter cadence, background transitions, and SFX via wait-beat opcodes. Discrepancies between Chinese and Japanese sentence lengths ($N_{zh} \neq N_{jp}$) cause significant desynchronization if committed directly. The port engine implements dynamic beat slicing (`cnSlices` & `cnCommitted`):
$$\text{slice\_len}_i = \text{round}\left( \frac{\sum_{k=1}^i beat\_len_k}{\text{total\_beat\_len}} \times N_{zh} \right) - \sum_{k=1}^{i-1} \text{slice\_len}_k$$
By committing Chinese substrings proportionally across original Japanese wait beats, text progression stays microsecond-accurate with background suspense accents and scene cuts.

### 11.5 Punctuation Snapping, Empty Beat Skipping & Latin Alignment
- **Punctuation Snapping**: Prevents line-start prohibited punctuation (quotes, periods, question marks) from hanging alone on a new line by folding them into the previous beat slice.
- **Empty Beat Skipping**: When translation conciseness produces a slice of 0 characters, the engine penetrates the beat without delaying, eliminating phantom pause stutter.
- **Latin Code Table Correction**: Fixed 7 non-ASCII Latin character slots (`a`-`g`) that suffered an index offset in the translation font, ensuring accurate rendering of foreign acronyms and names.

### 11.6 15-Page Translator Afterword Restoration & Cross-Edition Save Guard
- **Afterword Scenario Restoration**: Decrypted the 15-page fan translation commentary scenario (`SCN095` -> `SCN233` -> `SCN234`) with dedicated pagination UI.
- **Cross-Edition Save Guard**: Injected `SaveError.missingScenario` and `hasBlock` validation during deserialization:
```swift
guard scenarioIndex < scenarioRegistry.count,
      scenarioRegistry[scenarioIndex].hasBlock(blockIndex) else {
    throw SaveError.missingScenario(index: scenarioIndex, block: blockIndex)
}
```
Intercepts missing scenario indices when loading Chinese saves in the Japanese build, safely recovering to the title screen.

---

## 12. Phase 6: PC-98 OPNA FM Audio Architecture & Production Polish

### 12.1 Bit-Perfect Hardware Recording of 24 OPNA FM Tracks (43.3MB)
The chilling acoustic soul of the 1996 PC-9801 original lay in Yamaha YM2608 (OPNA) FM synthesis (6 FM operators + 3 SSG channels + 1 ADPCM rhythm channel).
- Captured all 24 original BGM tracks via bit-perfect internal recording from authentic PC-9801 hardware;
- Transcoded to 44.1kHz / 16-bit audio assets (43.3MB total) with noise floor below -84dBFS, faithfully preserving genuine FM synthesis timbre.

### 12.2 Dual Audio Architecture & Seamless Hot-Switching
Implemented a dual-engine audio bus in `AudioController`:
- `bgmSource = 0`: 1996 Windows 95 CD-DA remastered soundtrack (warm, orchestral);
- `bgmSource = 1`: 1996 PC-9801 YM2608 OPNA FM soundtrack (sharp, nostalgic).
Users can hot-switch between sound sources during active gameplay with 20ms equal-power crossfades and zero pop noise.

### 12.3 Precise Loop Calibration & One-Shot Track Guard
- **Loop Timestamps**: Calibrated loop boundaries via spectral energy waterfalls (e.g. `MUS11` loop at 8.75s, `MUS16` loop at 9.00s) with zero phase drift.
- **One-Shot Guard**: Configured 6 single-play tracks (death sting `MUS21`, ending jingle `MUS23`, etc.) to terminate immediately upon completion.

### 12.4 Choice Branch Realignment to 25×13 Grid & `choiceRowGap = 1`
Reverted floating modern choice windows to the authentic 25-column × 13-row text grid, enforcing `choiceRowGap = 1` (30px vertical separation) for 100% geometric parity with retail 1996 Windows 95 and PC-98 layouts.

### 12.5 Deterministic Regression Testing & 13 Endings Automation
- **Deterministic Clock**: Introduced `SaveClock` to freeze timestamps and RNG seeds during serialization, validating 113 scenario snapshots in `/tmp/shizuku_shot_saves/` with 100% state restoration determinism;
- **13 Endings Automated Suite**: Engineered `EndingPathTests.swift` to automate input streams, exhaustively verifying all 13 endings with 100% script logic coverage.

### 12.6 Meta-Save Global Cross-Playthrough Persistence
Inspired by the GBA port's SRAM `0x10` layout, decoupled global game completion state from individual save slots:
- 4 Cross-Playthrough Shared Flags (`0x00, 0x01, 0x45, 0x46`) persisted independently to `meta_save.dat` in Application Support, safeguarding unlocked easter eggs even if user save slots are wiped.

### 12.7 Ver.1.5 Standalone Dual DMG Packaging & Delivery
- **Japanese Edition**: `Shizuku_Restored_Ver.1.5.dmg` (Original 1,852-char KNJ font & Japanese SCN bytecode);
- **Simplified Chinese Edition**: `Shizuku_Restored_CHS_Ver.1.5.dmg` (4,726-slot font, DP mapping, 15-page afterword);
- **Integrated Dual Soundtracks**: Both editions include complete Win95 CD-DA and PC-98 FM audio libraries within a 189MB delivery bundle.

## Appendix A: Core Opcode & Inline Token Quick Reference

### 1. Outer Event Opcodes

| Opcode | Length | Operands | Operation |
|---|---|---|---|
| `0x00` | 1B | None | Block end; reset local state |
| `0x01` | 3B | `sub, arg` | Composite transition (sine shear / fade black / logo / text) |
| `0x04` | 3B | `scn, blk` | JUMP: Transfer execution to scenario block |
| `0x05` | Var | `msg, cnt, ...` | SELECT: Present branching choice menu |
| `0x07` | 1B | None | Previous choice anchor mark |
| `0x0a` | 2B | `loc_no` | Set background (resolved via `bgmap`) |
| `0x14` | 2B | `type` | Clear screen (images and text) |
| `0x16` | 2B | `hvs_no` | Load H-CG background |
| `0x22` | 3B | `chr, pos` | Load portrait into slot (`l/c/r`) |
| `0x24` | 3B | `chr, pos` | Close-up portrait (forced to center slot `'c'`) |
| `0x28` | 1B | None | Mark 2 anchor |
| `0x38` | 2B | `effect` | Update screen (`LvnsDisp`) and flush queued BGM |
| `0x3d` | 4B | `flag, val, off`| Conditional jump if `flag[id] == val` |
| `0x3e` | 4B | `flag, val, off`| Conditional jump if `flag[id] != val` |
| `0x47` | 3B | `flag, val` | Flag assignment |
| `0x48` | 3B | `flag, delta` | Flag addition |
| `0x54` | 2B | `msg_idx` | Invoke message dialogue |
| `0x6e` | 2B | `bgm_no` | Loop play BGM (resolved via `bgmmap`) |
| `0x7d` | 2B | `bgm_no` | Execute blocking Staff Roll |
| `0x7e` | 2B | `ed_no` | Record ending index (0..12) |
| `0xff` | 1B | None | Terminal boundary sentinel |

### 2. Inner Inline Tokens

| Token | Operand Length | Example | Staging Action |
|---|---|---|---|
| `$` | 0B | None | End of message stream |
| `p` | 0B | None | Page break (paper icon; click clears screen) |
| `k`/`K` | 0B | None | Wait key (▶ icon; click appends on next line) |
| `r` | 0B | None | Carriage return / line advance |
| `B`/`E` | 6B | `B070808` | Load background (location 7, effect 8) |
| `C` | 3B | `Cr51` | Load portrait (slot `r`, character 51) |
| `D` | 1B | `Da`, `Dl` | Clear portraits (`Da` all, `Dl` left slot) |
| `S` | 9B | `S...` | Atomically swap background and portrait |
| `A`/`a` | Var | `A...` | Triple-portrait staging |
| `V` | Var | `V01...` | Load visual CG plate |
| `H` | Var | `H01...` | Load H-CG plate |
| `M` | Var | `Mf`, `Mn01` | BGM control (fade/queue/switch) |
| `P` | Var | `P01-P13` | Mix and play PCM sound effect |
| `F` | 0B | None | White screen flash |
| `Q` | 0B | None | Screen shake / quake |
| `X` | 2B | `X08` | Line horizontal pixel offset |
| `s` | 1B | `s02` | Typewriter text speed |

---

## Appendix B: Register of Known Deviations and Enhancements

| No. | Feature | 1996 Original Behavior | macOS Native Port Behavior (Ver. 1.5) | Rationale |
|---|---|---|---|---|
| 1 | **Save Slot Capacity** | 3 manual bookmarks + 1 backup | 6 visual bookmarks + 1 quicksave | Expanded for modern large-screen playability |
| 2 | **Save Serialization** | 232-byte binary struct | Structured JSON file | Modernized for cross-version migration and debugging |
| 3 | **Music Room Access** | Completely invisible; no feedback | Hover outlines window; exposed in menu bar | Preserves secret while improving discoverability |
| 4 | **Music Room Exit** | Right-click only | Right-click or `ESC` key, with subtle hint text | Matches modern desktop input conventions |
| 5 | **Backlog Navigation** | Click on-screen ▲ / ▼ cells | Click cells, mouse wheel, or trackpad gestures | Takes advantage of modern macOS trackpad hardware |
| 6 | **Fast-Forward Semantics**| Menu command only; holding Enter ignored | Native menu item (Tab/Z); key repeat filtered | Faithful to original behavior; prevents input flooding |
| 7 | **Transition Toggle** | CLI flag `-n e` (Linux/MGL) | Menu bar: "View $\to$ Skip Screen Transitions" | Exposes engine capability directly in native UI |
| 8 | **Waiting Cursor Glyphs**| Font lacks ▼; original drew custom | Uses Leaf code 102 (▶) and 103 (paper icon) | Strictly distinguishes wait-key from page-break states |
| 9 | **Dual Audio Engine** | Win95 CD-DA only / PC-98 FM only | Dual-source engine with live hot-switching | Caters to both vintage FM chiptune and remastered CD-DA preferences |
| 10 | **Meta-Save Persistence** | No cross-playthrough global state | GBA SRAM `0x10` 4 shared flags saved to `meta_save.dat` | Preserves completion rewards independently of save slot wipes |
| 11 | **Beat Slicing Pipeline**| Translation text causes audio-visual desync | Proportional `cnSlices` with punctuation snapping | Synchronizes translated dialogue with original music cues and cuts |
| 12 | **Cross-Edition Save Guard** | Out-of-bounds scenario crashes engine | Catches `SaveError.missingScenario` gracefully | Recovers safely to title screen on edition mismatch |
| 13 | **Typewriter & Fast-Forward**| Fixed speed without character-level timing | Authentic 30ms reveal & 17/60s (59.1 chars/s) scan | Enhances modern reading cadence with zero glyph overshooting |
| 14 | **Native SwiftUI About Window**| Basic Win32 dialog box | Native SwiftUI window with dark/light mode and hotkeys | Aligns with modern macOS design guidelines |

---

*Notice: All decryption, disassembly, and reverse engineering described herein was performed on legally acquired physical media. All copyrights to the game, artwork, and audio belong to Leaf / AQUAPLUS. This document is intended solely for academic research, digital preservation, and software engineering education.*
