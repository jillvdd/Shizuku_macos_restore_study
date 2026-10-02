# System Engineering Baseline & Technical Quick Reference
## Leaf LVNS Engine Constants, Memory Maps, and Architectural Interfaces (Ver.1.5)

> 🌐 **Language / 多语言**: [🇨🇳 简体中文](RESUME_PROMPT.md) ｜ [🇺🇸 English](RESUME_PROMPT-en.md) ｜ [🇯🇵 日本語](RESUME_PROMPT-jp.md)

---

## 1. Core Physical Constants & Benchmarks

For systems engineers and reverse engineering researchers, this table consolidates all empirically verified physical constants for the native macOS restoration (Ver.1.5 dual release):

| Parameter | Value / Hex Constant | Engineering Constraints & Context |
|---|---|---|
| **Base Resolution** | `640 × 400` | Native 16:10 offscreen target, integer scaled via Metal to Retina displays |
| **Frame Rate & Ticker** | `60.0 Hz` | Strictly synchronized via `CVDisplayLink` with `ProcessInfo.beginActivity` lock |
| **PAK Additive Key** | `71 48 6a 55 9f 13 58 f7 d1 7c 3e` | 11-byte rolling keystream (matching ASCII `"qHjU…"`) |
| **PAK Asset Count** | `0x0193` (403 files) | Stored in LEAFPACK header uint16; identifies Windows *Shizuku* assets |
| **Script Ring Buffer** | `0x1011` | Inverted-flag LZS3 (`~flag`); output truncated strictly by declared size |
| **JP Dot Font Size** | `133,344` Bytes | 1,852 glyphs (24×24 px, 1bpp, 72 bytes/glyph in 3 vertical strips) |
| **JP Leaf Code Indexing** | `1-based` Direct Index | Physical glyph offset = `(leaf_code - 1) * 72` |
| **CN Dot Font Size** | `340,272` Bytes | 4,726 slots (`cnfont_4726.bin`), first 1,852 matching JP, tail containing CN glyphs |
| **CN Code Table Mapping** | `2,872` Characters | Solved via monotonic DP solver with fuzzy NCC + word frequency prior |
| **Full Chinese Corpus** | `3,834` Lines | Covers 195 SCN scripts (`zh_text.json`), beat-sliced to JP timing ticks |
| **PC-98 FM Audio Pack** | 24 Tracks (43.3 MiB) | YM2608 (OPNA) bit-perfect hardware recording, Ogg Vorbis q5 44.1kHz |
| **FM Seamless Loop Points** | `MUS11`: 8.750s / `MUS16`: 9.000s | Plays intro once, transitioning gaplessly into body hardware loop |
| **FM One-Shot Tracks** | 6 Tracks (MUS00/14/17/18/20/23) | Plays once in Music Room and stops (residual silence $\le -91\text{ dB}$) |
| **Choice Text Grid** | Native tvram grid + `choiceRowGap = 1` | Inline `'X' * 8` px offset, with 1 empty row vertical breathing gap |
| **Meta-Save Shared Flags** | `[0x00, 0x01, 0x45, 0x46]` | Aligns with GBA SRAM `0x10`, re-applied on load, fixes phantom choices |
| **Typewriter Timing** | Reveal 30ms (2 flips) / FF Slow 17/60s | Aligned with `Sizuku.exe` disassembly; slow fast-forward is 59.1 chars/s |
| **Deterministic Baseline** | `113 / 113` Fixed Frames | Sandboxed `SaveClock` frozen time, verified against `MANIFEST.sha256` |
| **Dual Release Artifacts** | `build/` (JP) / `build_chs/` (ZH) | `Shizuku_Restored_Ver.1.5.dmg` and `Shizuku_Restored_CHS_Ver.1.5.dmg` |

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

## 3. Swift Modular Architecture Interfaces (Ver.1.5)

```swift
// ShizukuCore: Binary streams, dot font models, and format decoders
public struct LeafPackArchive { ... }
public final class CnDotFont {
    public static func glyphData(forLeafCode code: Int) -> Data?
    public static func unicode(forLeafCode code: Int) -> Character?
}

// ShizukuEngine: Dual-Layer VM, dual audio backend, and language-agnostic saves
public final class Engine {
    public var bgmSource: Int // 0 = Windows original, 1 = PC-98 FM audio
    public var language: GameLanguage // .jp or .zh (compile-time constant)
    public func sliceChineseText(_ text: String, jpBeats: Int) -> [String]
    public func skipCNEmptyBeats()
}

// ShizukuRender: Metal pipeline, text grid layout, and 13 LVNS transitions
public final class SceneComposer {
    public static let choiceRowGap: Int = 1 // Vertical spacing gap
    public func drawCNMatrixText(...)
    public func choiceOptionRects(engine: Engine) -> [(option: Int, rect: CGRect)]
}

// ShizukuApp: AppKit host, native SwiftUI About window, and 113-frame test harness
public final class AppDelegate: NSObject, NSApplicationDelegate {
    public func showAbout(_ sender: Any?) // Native SwiftUI About panel
}
```

---

## 4. Verification & Testing Toolchain Commands

```bash
# Execute automated test suite (176 unit & integration tests)
swift test

# Headless 113-frame deterministic visual baseline regression (JP & ZH)
SHIZUKU_SHOT=spec ./build/Shizuku_Restored_Ver.1.5.app/Contents/MacOS/ShizukuApp
SHIZUKU_SHOT=spec ./build_chs/Shizuku_Restored_CHS_Ver.1.5.app/Contents/MacOS/ShizukuApp

# Headless automated scan and path regression for all 13 endings
SHIZUKU_SHOT=endingscan ./build/Shizuku_Restored_Ver.1.5.app/Contents/MacOS/ShizukuApp

# End-to-end 15-page Chinese patch afterword verification
SHIZUKU_SHOT=afterword ./build_chs/Shizuku_Restored_CHS_Ver.1.5.app/Contents/MacOS/ShizukuApp

# Package dual signed standalone macOS DMG bundles
./package.sh jp && ./package.sh zh
```
