# Project Engineering Milestones & Acceptance Criteria
## Agile Iterations and Technical Verification Standards for Native macOS Restoration of *Shizuku*

> 🌐 **Language / 多语言**: [🇨🇳 简体中文](MILESTONES.md) ｜ [🇺🇸 English](MILESTONES-en.md) ｜ [🇯🇵 日本語](MILESTONES-jp.md)

---

## 1. Milestone Overview

The restoration of *Shizuku* follows an agile systems engineering trajectory structured into five discrete phases:

| Milestone | Engineering Domain | Key Deliverables & Milestones | Acceptance Status |
|---|---|---|---|
| **Phase 1 (M1)** | Asset Decryption & Format Verification | 403 PAK files extracted, 24×24 KNJ font exported, LFG decoders | ✅ **Fully Accepted** |
| **Phase 2 (M2)** | Scenario Disassembly & VM Foundation | 197 SCN disassembly dumps, outer block jump model, 13 skip opcodes | ✅ **Fully Accepted** |
| **Phase 3 (M3)** | Native Audio Subsystem & Mixing | 25 Ogg BGM loop playback, 13 WAV SFX mixer, CoreAudio resampler | ✅ **Fully Accepted** |
| **Phase 4 (M4)** | Metal Pipeline & Visual Fidelity | 25×13 Sound Novel grid, drop shadow font, 13 transitions, music room | ✅ **Fully Accepted** |
| **Phase 5 (M5)** | Platform Tuning, Hardening & Release | macOS App Nap lock, bilingual build pipeline, standalone DMG bundle | ✅ **Production Release** |

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

### Phase 5: System Optimization & Release (M5)
- **M5.1: macOS App Nap Throttle Override**
  - Applied `ProcessInfo.beginActivity([.userInitiated, .latencyCritical])`.
  - **Acceptance Criteria**: Display loop locks solidly at 60.0 FPS throughout dialogue waits and animations.
- **M5.2: Standalone Release Packaging**
  - Generated self-contained `.app` bundle and distributable DMG disk image.
  - **Acceptance Criteria**: Clean standalone execution on modern Apple Silicon Macs without external dependencies.
