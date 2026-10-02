# Audio Architecture & Dual-Source Specification

> 🌐 **Language / 多语言**: [🇨🇳 简体中文](audio.md) ｜ [🇺🇸 English](audio-en.md) ｜ [🇯🇵 日本語](audio-jp.md)

---

## 1. Overview & Architectural Decisions

*Shizuku* historically features two distinct acoustic traditions:
1. **January 1996 NEC PC-9801/9821 Original**: Powered by the Yamaha **YM2608 (OPNA)** sound chip, featuring 6 FM channels, 3 SSG channels, and an ADPCM rhythm unit. It delivers the signature cold, mechanical chiptune atmosphere of 1990s Japanese visual novels.
2. **July 1996 Windows 95 CD Edition** (and subsequent 2003/2007 releases): Rearranged by Leaf composers using high-sample-rate stereo CD-DA, MIDI, and Ogg Vorbis streams, providing a softer, acoustic profile.

The native macOS port (Ver.1.5) implements a **runtime dual-audio backend switching architecture**: defaulting to the Windows original sound while bundling the fully extracted, lossless PC-98 hardware FM audio package, switchable dynamically from the native menu bar.

---

## 2. Windows Original Audio Assets Specification

### 2.1 BGM Pack — `bgmfile.PAK` (LAC Container)
- **Container**: Packaged inside LEAF Audio Container (LAC);
- **Codec**: All 25 tracks (`MUS00.OGG` through `MUS24.OGG`), encoded in standard **Ogg Vorbis** (44.1 kHz stereo);
- **Variants**: `Sizuku.exe` natively handles `%s.ogg` and `%s_a.ogg` variants (used for alternate dramatic tension arrangements);
- **Scenario Track Mapping (`bgmmap`)**:
  Track numbers referenced in SCN scripts do not map 1:1 to filenames, but resolve via an internal lookup table:
  ```swift
  // SCN script argument -> Physical MUS file lookup table
  public static let bgmMap: [Int: Int] = [
      1: 2, 2: 3, 3: 4, 4: 5, 5: 6, 6: 7, 7: 8, 8: 9, 9: 10,
      10: 11, 11: 12, 12: 13, 13: 15, 14: 16, 15: 17, 16: 18,
      17: 19, 18: 20, 19: 21, 20: 22, 21: 23, 22: 24
  ]
  // 0 denotes mute/stop; MUS00 is the Leaf Jingle, MUS14 is the Opening animation track
  ```

### 2.2 Sound Effects (SE) — `soundds.PAK` (LAC Container)
- **Container**: LAC container;
- **Codec**: 13 sound effects (`P01.WAV` ~ `P13.WAV`), standard **RIFF/WAVE** PCM format (mastered in GoldWave);
- **Playback**: One-shot trigger with dedicated sound effect channels mixed concurrently with BGM.

### 2.3 Environmental Sound — `SZ_VD01-10.P16` in `MAX_DATA.PAK`
- **Data Structure**: 4-byte header (`02 00 0c 00`) + **16-bit signed little-endian mono PCM**;
- **Sample Metrics**: 92,635 samples per track (~8.38s at 11,025 Hz), low amplitude ($\pm 5000$), used for white noise and psychoacoustic suspense effects.

---

## 3. PC-98 FM Audio Architecture (Ver.1.5 M6 Core Addition)

### 3.1 Asset Acquisition & Specifications
- **Hardware Reference**: Physical NEC PC-9821 hardware with Yamaha YM2608 (OPNA) internal sound recording;
- **Track Count**: Complete set of 24 tracks (`MUS00.OGG` ~ `MUS23.OGG`, 45,376,141 bytes $\approx 43.3\text{ MiB}$);
- **Audio Metrics**: Ogg Vorbis 44.1 kHz, quality level q5, with dynamic range and noise floor calibrated to real hardware.

### 3.2 Loop Semantics & Seam Calibration
The PC-98 driver semantics (FMP/PMD variants) differ from Windows full-file looping in significant ways:
1. **"Intro Once + Seamless Body Loop" Tracks**:
   Using waveform amplitude scanning and phase correlation, precise loop points were calibrated for two iconic tracks:
   - **`MUS11` (Search / 捜索)**: Intro duration is exactly **8.750 seconds**. The intro plays once upon entry, followed by continuous seamless looping over $[8.750\text{s}, \text{EOF}]$;
   - **`MUS16` (Happy End / ハッピーエンド)**: Intro duration is exactly **9.000 seconds**, seamlessly looping over $[9.000\text{s}, \text{EOF}]$.
   - Modern Engine Implementation: `AudioController.split()` partitions the stream into Intro and Body buffers. The intro buffer plays once, transitioning gaplessly into the body buffer with looping enabled.
2. **Pure Loop Tracks**:
   e.g. `MUS19` (Madness / 狂気), continuous seamless full-file looping, verified pop-free via discrete FFT analysis.
3. **One-Shot (Non-Looping) Tracks**:
   In the Music Room (音楽モード), the original engine plays the following 6 tracks once and stops (gap silence $\le -91\text{ dB}$):
   - `MUS00` (Leaf Jingle)
   - `MUS14` (Opening)
   - `MUS17` (True End)
   - `MUS18` (Bad End)
   - `MUS20` (Music Box 2)
   - `MUS23` (School Chime)

---

## 4. Runtime Dual-Source Pipeline

```
              ┌─────────────────────────────────────┐
              │ User Menu: Options → BGM Audio Source│
              └──────────────────┬──────────────────┘
                                 │ Toggle bgmSource (0=Win, 1=FM)
                                 ▼
              ┌─────────────────────────────────────┐
              │ retuneCurrentBGM()                  │
              └──────────────────┬──────────────────┘
                                 │ Current playback timestamp t
                                 ▼
              bgmURL(track, preferred: bgmSource)
                   ┌─────────────┴─────────────┐
                   ▼                           ▼
            [ PC-98 FM Pack ]           [ Windows Pack ]
          gamedata/bgm_fm/MUSxx       gamedata/bgm/MUSxx
                   │                           │
                   │ (Auto-fallback if missing)│
                   └─────────────┬─────────────┘
                                 ▼
              ┌─────────────────────────────────────┐
              │ AVAudioEngine Master Node           │
              │ - 44.1kHz Stereo Mixing             │
              │ - Dynamic Fade In/Out               │
              │ - Gapless Cross-Scenario Playback   │
              └─────────────────────────────────────┘
```

1. **In-place Retuning**: When toggled during gameplay, the engine captures the current track timestamp and performs a smooth in-place crossfade to the matching position in the target sound pack without resetting the scene.
2. **Graceful Fallback Ladder**: If FM assets are absent or deleted, the engine automatically falls back track-by-track to the Windows pack, preventing deadlocks or runtime crashes.
3. **System Persistence**: User preferences are saved to `system.json` under `GlobalSystemData.bgmSource`, surviving app restarts.
