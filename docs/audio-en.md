# Audio Specifications

> 🌐 **Language / 多语言**: [🇨🇳 简体中文](audio.md) ｜ [🇺🇸 English](audio-en.md) ｜ [🇯🇵 日本語](audio-jp.md)

## Background Music (BGM) — `bgmfile.PAK`

- 25 entries packaged inside an LAC container.
- Audio codec: Stereo 44.1kHz **Ogg Vorbis** (identified by `OggS` packet headers).
- Target playback: Loop playback managed by `AVAudioEngine` and `AVAudioPlayerNode`.

## Sound Effects (SE) — `soundds.PAK`

- 13 entries in an LAC container.
- Audio format: Standard **RIFF/WAVE** PCM format.
- Generated originally via GoldWave audio workstation.

## Ambient / Voice — `SZ_VD01-10.P16`

- 10 entries stored in `MAX_DATA.PAK`.
- Structure: 4-byte header (`02 00 0c 00`) followed by raw **16-bit signed little-endian PCM** at 11,025Hz.
- On macOS CoreAudio, mono 11,025Hz streams must be converted via `AVAudioConverter` to stereo float32 before mixing into the main output node to prevent CoreAudio internal format mismatch exceptions.
