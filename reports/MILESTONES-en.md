# Project Engineering Milestones & Acceptance Criteria
## Agile Iterations and Technical Verification Standards for Native macOS Restoration of *Shizuku*

> 🌐 **Language / 多语言**: [🇨🇳 简体中文](MILESTONES.md) ｜ [🇺🇸 English](MILESTONES-en.md) ｜ [🇯🇵 日本語](MILESTONES-jp.md)

---

## 1. Milestone Overview

The restoration of *Shizuku* follows an agile systems engineering trajectory structured into six discrete phases:

| Milestone | Engineering Domain | Key Deliverables & Milestones | Acceptance Status |
|---|---|---|---|
| **Phase 1 (M1)** | Asset Decryption & Format Verification | 403 PAK files extracted, 24×24 KNJ font exported, LFG decoders | ✅ **Fully Accepted** |
| **Phase 2 (M2)** | Scenario Disassembly & VM Foundation | 197 SCN disassembly dumps, outer block jump model, 13 skip opcodes | ✅ **Fully Accepted** |
| **Phase 3 (M3)** | Native Audio Subsystem & Mixing | 25 Ogg BGM loop playback, 13 WAV SFX mixer, CoreAudio resampler | ✅ **Fully Accepted** |
| **Phase 4 (M4)** | Metal Pipeline & Visual Fidelity | 25×13 Sound Novel grid, drop shadow font, 13 transitions, music room | ✅ **Fully Accepted (Ver.1.0)** |
| **Phase 5 (M5)** | Chinese Localization & Font Reconstruction | 2014 patch decrypted (199 SCN), 4,726-slot 24×24 font, DP mapping (2,872 chars), beat slices, 15-page afterword | ✅ **Fully Accepted (Ver.1.2)** |
| **Phase 6 (M6)** | PC-98 OPNA FM Audio & Polish | PC-9801/9821 OPNA FM 24 tracks, dual audio backend, deterministic regression (113/113), 13 endings, dual DMGs | ✅ **Production Release (Ver.1.5)** |

---

## 2. Detailed Milestone Specifications & Acceptance Criteria

### Phase 1: Cryptanalysis & Typography Pipeline (M1)
- **M1.1: Proprietary PAK Decryption**
  - Implemented 11-byte rolling additive decryption for `MAX_DATA.PAK`.
  - **Acceptance Criteria**: 403/403 files verified via byte-level checksums; directory strings decode cleanly without trailing corruption.
- **M1.2: KNJ 24×24 Bitmap Font Decoding**
  - Decoded `KNJ_ALL.KNJ` (133,344 bytes, 1,852 glyphs) across 3 vertical scan strips.
  - **Acceptance Criteria**: Exported `preview/knj_atlas.png` exhibits crisp, complete glyph geometry with 1-based array addressing.

### Phase 2: Dual-Layer VM & Instruction Dispatch (M2)
- **M2.1: SCN Bytecode Decompression & Boundary Truncation**
  - Implemented inverted-flag LZS3 decompression with mandatory output size truncation.
  - **Acceptance Criteria**: Zero trailing garbage bytes across all 197 scenario scripts.
- **M2.2: Event VM & Skip Opcode Neutralization**
  - Classified 13 dummy skip opcodes in the outer stream to ensure safe program counter progression.
  - **Acceptance Criteria**: Seamless cross-script block jumps from `SCN001.DAT` to `SCN002.DAT` without deadlock.

### Phase 3: Native Audio Subsystem Integration (M3)
- **M3.1: LAC Container & Audio Graph Orchestration**
  - Built latency-free audio graph via `AVAudioEngine`, supporting 25 looping BGM tracks and 13 SFX buffers.
  - **Acceptance Criteria**: BGM track switching and volume fades operate smoothly with zero acoustic clipping.
- **M3.2: 11,025Hz Mono CoreAudio Crash Mitigation**
  - Integrated `AVAudioConverter` to dynamically resample mono 11,025Hz assets to 44,100Hz stereo float buffers.
  - **Acceptance Criteria**: Rapid triggering of sound effects (`P01-P13`) produces zero `NSException` events.

### Phase 4: Visual Pipeline & Fidelity Restoration (M4)
- **M4.1: Sound Novel Text Layout & Drop Shadows**
  - Reconstructed 25-column × 13-row monospace grid with 1px character tracking and three-pass shadow rendering.
  - **Acceptance Criteria**: Message box compositing achieves 1:1 pixel parity with retail Windows 95 rendering.
- **M4.2: 13 Transitions & Outward Spiral (GURUGURU) Geometry**
  - Restored 16px tile outward spiral algorithm originating from `(27, 12)`.
  - **Acceptance Criteria**: Full-screen 40×25 tile spiral renders smoothly with zero missing or misaligned blocks.
- **M4.3: Hidden Music Room Disassembly**
  - Reconstructed clock tower window hit-test at `(448, 128)` and reverse-engineered the `0x408d40` main loop.
  - **Acceptance Criteria**: Successfully invokes visual music box on `VIS17.LFG` with mouse and keyboard escape support.

### Phase 5: Chinese Localization & Font Table Reconstruction (M5)
- **M5.1: 2014 Chinese Patch Decryption & Unpacking**
  - Reverse-engineered the 2014 fan translation `data.bin` container (4-byte rolling XOR key), extracting 199 SCN scenario script streams (3,834 translated strings).
  - **Acceptance Criteria**: 199 SCN records verified byte-for-byte; all translated strings cleanly parsed.
- **M5.2: 4,726-Slot 24×24 Chinese Bitmap Font Reconstruction**
  - Extracted extended Chinese font glyphs from the patch DLL, constructing binary atlas `cnfont_4726.bin` (340,272 bytes, 4,726 slots) with 100% visual parity.
  - **Acceptance Criteria**: Dot-matrix glyph extraction yields zero artifacts; 24×24 rendering matches original visual sharpness.
- **M5.3: Monotonic Dynamic Programming (DP) Character Mapping**
  - Resolved encoding mismatches between original Shift-JIS / Leaf-code and GBK via a monotonic DP solver with minimum edit distance, creating a robust 2,872-character mapping table `cn_code2char.json`.
  - **Acceptance Criteria**: 100% hit rate for scenario text lookups; zero empty slot errors or garbled glyphs.
- **M5.4: Script Beat Dynamic Slice Progression Pipeline**
  - Bridged discrepancies between Chinese translation length and original Japanese typing wait-beats. Implemented `cnSlices` and `cnCommitted` dynamic partitioning to sync Chinese dialogue progression with sound effects and transitions without rushing or clipping.
  - **Acceptance Criteria**: Narrative pace aligns perfectly with sound effects and scene cuts; no swallowed characters or desync.
- **M5.5: Sentence-End Punctuation Snapping & Empty Beat Skipping**
  - Snapped trailing punctuation (quotation marks, question marks, exclamation marks) to preceding text beats to prevent dangling punctuation line wraps, while automatically penetrating empty beats (zero-character slices).
  - **Acceptance Criteria**: Zero hanging punctuation lines across all scripts; zero pause anomalies from empty beats.
- **M5.6: Latin Code Table Slot Correction**
  - Fixed 7 misaligned non-ASCII Latin character slots (`a`-`g` offset discrepancy), restoring proper rendering for foreign terminology and names.
  - **Acceptance Criteria**: 100% accuracy in western character and acronym display.
- **M5.7: 2014 15-Page Translator Afterword & Cross-Build Save Guard**
  - Restored the 15-page fan translation team afterword (`SCN095` -> `SCN233` -> `SCN234`); designed `SaveError.missingScenario` and `hasBlock` guard logic to eliminate cross-build save file crashes between Japanese and Chinese releases.
  - **Acceptance Criteria**: Seamless pagination and layout for afterword pages; 100% crash interception and graceful recovery on cross-edition save loading.

### Phase 6: PC-98 OPNA FM Audio, Polish & Ver.1.5 Release (M6)
- **M6.1: PC-9801/9821 OPNA (YM2608) FM Audio Bit-Perfect Recording**
  - Captured all 24 tracks from the original 1996 PC-9801 release via bit-perfect internal recording (44.1kHz / 16-bit / 43.3MB), authentically restoring 6 FM + 3 SSG + 1 ADPCM vintage chiptune timbre.
  - **Acceptance Criteria**: 24 FM audio tracks achieve noise floor below -84dBFS; timbre authentic to PC-9801 hardware.
- **M6.2: Dual Audio Engine Architecture & Dynamic Hot Switching**
  - Implemented dual audio backend in `AudioController` (`bgmSource`: 0=Win95 CD-DA Ogg, 1=PC-98 OPNA FM) with seamless in-game hot switching and zero pop noise.
  - **Acceptance Criteria**: Instant acoustic source switching without pops or clicks; smooth playback position and volume transitions.
- **M6.3: FM Precise Loop Points & One-Shot Safeguards**
  - Calibrated exact loop timestamps via waveform spectral analysis (`MUS11` 8.75s, `MUS16` 9.00s, etc.) and configured 6 one-shot tracks (jingles/death themes) with auto-silence.
  - **Acceptance Criteria**: Phase-aligned loop boundaries with zero rhythmic stutter; one-shot tracks safely terminate upon completion.
- **M6.4: Choice Branch Grid Layout Optimization**
  - Reverted floating centered choice menus to the authentic 25×13 grid coordinate system, applying `choiceRowGap = 1` row spacing for 100% fidelity to the 1996 original.
  - **Acceptance Criteria**: Branch choice visuals achieve 100% parity with retail Windows 95 and PC-98 layouts.
- **M6.5: Deterministic Regression Testing Framework**
  - Engineered headless regression testing with frozen timestamp clock (`SaveClock`) and fixed seed, validating all 113 snapshot saves in `/tmp/shizuku_shot_saves/` with 100% deterministic state matching.
  - **Acceptance Criteria**: 113/113 scenario snapshot saves serialize, deserialize, and restore state with identical checksums.
- **M6.6: 13 Endings Automated Path Regression**
  - Automated path traversal across all 13 endings via `EndingPathTests.swift`, ensuring 100% script logic coverage and zero deadlocks.
  - **Acceptance Criteria**: 13/13 endings verified without deadlocks or unhandled branches; full script path coverage.
- **M6.7: Meta-Save Shared Persistence**
  - Modeled after GBA SRAM `0x10` architecture, persisting 4 cross-playthrough global flags (`0x00, 0x01, 0x45, 0x46`) to `meta_save.dat` to preserve titlescreen unlockables independently of save slots.
  - **Acceptance Criteria**: Titlescreen easter eggs and cleared ending flags persist reliably even when individual save slots are removed.
- **M6.8: Native SwiftUI About Window**
  - Created standard macOS About window showcasing development chronology, credits, and open-source acknowledgments with dark/light mode support.
  - **Acceptance Criteria**: Responsive modal window lifecycle, supports Command+W close shortcut, full dynamic theme compatibility.
- **M6.9: Typewriter Reveal & Slow Fast-Forward**
  - Restored 30ms character reveal cadence (2 screen flips per char) and slow fast-forward speed (17/60s, ~59.1 chars/s) for optimal legibility.
  - **Acceptance Criteria**: Smooth typewriter animation with zero dropped glyphs; immediate precision stop upon releasing fast-forward.
- **M6.10: macOS App Nap & Frame Timing Lock**
  - Configured `latencyCritical` activity tokens to guarantee 60.0 FPS rendering with under 3.5% CPU utilization.
  - **Acceptance Criteria**: Frame pacing locks solidly at 60.0 FPS across all gameplay states with low thermal overhead.
- **M6.11: Ver.1.5 Dual DMG Packaging & Delivery**
  - Automated packaging for Japanese (`Shizuku_Restored_Ver.1.5.dmg`) and Simplified Chinese (`Shizuku_Restored_CHS_Ver.1.5.dmg`), plus 189MB encrypted delivery bundle.
  - **Acceptance Criteria**: Standalone drag-and-drop installation on Apple Silicon and Intel macOS (macOS 14/15/26) without external dependencies.
