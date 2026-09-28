# System Engineering Baseline & Technical Quick Reference
## Leaf LVNS Engine Constants, Memory Maps, and Architectural Interfaces

> 🌐 **Language / 多语言**: [🇨🇳 简体中文](RESUME_PROMPT.md) ｜ [🇺🇸 English](RESUME_PROMPT-en.md) ｜ [🇯🇵 日本語](RESUME_PROMPT-jp.md)

---

## 1. Core Physical Constants & Benchmarks

For systems engineers and reverse engineering researchers, this table consolidates all empirically verified physical constants for Leaf's *Shizuku* (Windows 95 / LVNS engine):

| Parameter | Value / Hex Constant | Engineering Constraints & Context |
|---|---|---|
| **Base Resolution** | `640 × 400` | Native 16:10 offscreen target, integer scaled to modern displays |
| **Frame Rate** | `60.0 Hz` | Strictly synchronized via `CVDisplayLink` / `CAMetalDisplayLink` |
| **PAK Additive Key** | `71 48 6a 55 9f 13 58 f7 d1 7c 3e` | 11-byte rolling keystream (matching ASCII `"qHjU…"`) |
| **PAK Asset Count** | `0x0193` (403 files) | Stored in LEAFPACK header uint16; identifies Windows *Shizuku* |
| **Script Ring Buffer** | `0x1011` | Inverted-flag LZS3 (`~flag`); output truncated by declared size |
| **Font Physical Size** | `133,344` Bytes | 1,852 glyphs (24×24 px, 1bpp, 72 bytes/glyph in 3 vertical strips) |
| **Leaf Code Indexing** | `1-based` Direct Index | Physical glyph offset = `(leaf_code - 1) * 72` |
| **Text Grid Layout** | `25 cols × 13 rows` | 24px glyph pitch, 1px tracking, 6px leading, 20px safe margins |
| **Hidden Music Room** | `(X=448, Y=128)` | Clock tower upper window; points to 5th invisible hit rect at VA `0x430ebc` |
| **Audio Resampling** | `11,025 Hz Mono → 44,100 Hz Stereo` | Eliminates silent CoreAudio `NSException` thrown in stereo graph |

---

## 2. Binary Architecture Diagrams

### 2.1 LEAFPACK Archive Physical Layout (`MAX_DATA.PAK`)

```text
+-------------------+--------------------+------------------------+---------------------+
| "LEAFPACK" (8B)   | FileCount (2B LE)  | Payload Data Stream    | Directory Table     |
| Magic Identifier  | Total = 403 Files  | Cumulative Additive    | 24B * 403 Entries   |
| 0x00 - 0x07       | 0x08 - 0x09        | 0x0A ... End-9672      | End-9672 ... EOF    |
+-------------------+--------------------+------------------------+---------------------+
```

### 2.2 SCN Scenario Script Physical Layout (`SCN%03d.DAT`)

```text
+---------------------+---------------------+---------------------+---------------------+
| EventOffset (2B LE) | MsgOffset (2B LE)   | Event Block Data    | Message Stream Data |
| Offset = Val * 0x10 | Offset = Val * 0x10 | u32 UncompressedSz  | u32 UncompressedSz  |
| 0x00 - 0x01         | 0x02 - 0x03         | + Inverted LZS3     | + Inverted LZS3     |
+---------------------+---------------------+---------------------+---------------------+
```

---

## 3. Swift Modular Architecture Interfaces

```swift
// ShizukuCore: Binary streams and format decoders
public struct LeafPackArchive {
    public let entries: [LeafPackEntry]
    public func extract(entry: LeafPackEntry) -> Data
}

// ShizukuEngine: Dual-Layer VM coroutine orchestration
public final class ScenarioEngine {
    public func advanceEvent() -> EngineStepResult
    public func stepInlineMacro() -> InlineToken?
}

// ShizukuRender: Metal pipeline and transitions
public final class MetalGameRenderer: MTKViewDelegate {
    public func setTransition(type: TransitionType, duration: TimeInterval)
    public func renderFrame(into view: MTKView)
}
```

---

## 4. Reverse Engineering CLI Quick Reference

```bash
# Extract all assets from PAK archive
python3 tools/scripts/shizuku-unpack.py path/to/MAX_DATA.PAK -o output/

# Render 24x24 bitmap font atlas (1,852 glyphs)
python3 tools/scripts/shizuku-knj-font.py path/to/KNJ_ALL.KNJ --atlas preview/knj_atlas.png

# Decode LFG graphic file to PNG
python3 tools/scripts/shizuku-lfg-image.py path/to/HVS01.LFG -o preview/hvs01.png

# Disassemble scenario script into human-readable assembly
python3 tools/scripts/shizuku-scn-disasm.py path/to/SCN001.DAT -o SCN001.txt
```
