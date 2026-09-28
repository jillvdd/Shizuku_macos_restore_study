# Project Milestones & Acceptance Criteria

> 🌐 **Language / 多语言**: [🇨🇳 简体中文](MILESTONES.md) ｜ [🇺🇸 English](MILESTONES-en.md) ｜ [🇯🇵 日本語](MILESTONES-jp.md)

Roadmap and agile engineering milestones for the native macOS restoration of *Shizuku*:

## Milestone Overview

| Milestone | Target Area | Status | Acceptance Standard |
|---|---|---|---|
| **M1** | Foundation & Asset Verification | **Completed** | Full extraction of 403 PAK files, LFG decoding, font rendering |
| **M2** | Standalone Disassembler & Toolchain | **Completed** | Disassembly of all 197 SCN scenario scripts into readable assembly |
| **M3** | Audio Subsystem & Packaging | **Completed** | Ogg BGM loop playback, WAV/PCM mixing, independent app bundle |
| **M4.1 - M4.5** | Dual-Layer VM & Rendering Core | **Completed** | Event VM branching, inline macro staging, Sound Novel 25×13 layout |
| **M4.6 - M4.10** | Audio Fidelity & Screen Effects | **Completed** | 13 transition algorithms, CoreAudio 11,025Hz fix, App Nap override |
| **M4.11** | Secret Music Room & Polish | **Completed** | Clock tower (448, 128) disassembly, sound room restoration |
| **M5** | Release & Documentation (Ver.1.0) | **Completed** | Full cross-language technical documentation and GitHub Pages launch |

## Key Verification Criteria

1. **Rendering Fidelity**: Pixel-accurate 640×400 canvas, three-pass drop shadow font rendering, and outward spiral transition (GURUGURU).
2. **Audio Stability**: Zero CoreAudio crashes during mono sound effect mixing; seamless looping on Ogg background music.
3. **Engine Robustness**: Clean execution across all 197 scenario scripts with strict LZS3 boundary truncation.
