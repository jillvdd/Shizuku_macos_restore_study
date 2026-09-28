# 音声フォーマット仕様書

> 🌐 **Language / 多言語**: [🇨🇳 简体中文](audio.md) ｜ [🇺🇸 English](audio-en.md) ｜ [🇯🇵 日本語](audio-jp.md)

## BGM（音楽）— `bgmfile.PAK`

- LAC コンテナに 25 曲を収録。
- コーデック：44.1kHz ステレオ **Ogg Vorbis**（`OggS` パケットヘッダ確認済み）。
- 再生：`AVAudioEngine` および `AVAudioPlayerNode` によるシームレスループ再生。

## SE（効果音）— `soundds.PAK`

- LAC コンテナに 13 ファイルを収録。
- フォーマット：標準 **RIFF/WAVE** PCM 音声（GoldWave で作成）。

## 環境音・音声 — `SZ_VD01-10.P16`

- `MAX_DATA.PAK` 内に 10 ファイルを収録。
- 構造：4 バイトヘッダ（`02 00 0c 00`）+ 11,025Hz 16-bit リトルエンディアン PCM。
- macOS CoreAudio では、モノラル 11,025Hz 音源を `AVAudioConverter` でステレオ Float32 にリサンプリングして再生することで、CoreAudio 内部のフォーマット不一致例外を完全に回避します。
