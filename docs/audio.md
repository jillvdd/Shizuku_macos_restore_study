# 音频格式

> 🌐 **Language / 多语言**: [🇨🇳 简体中文](audio.md) ｜ [🇺🇸 English](audio-en.md) ｜ [🇯🇵 日本語](audio-jp.md)


雫 2007 版(本用户拷贝)的音频极简,几乎无编解码负担。

## BGM — `bgmfile.PAK`(LAC 容器)

- 25 条,内容为 **Ogg Vorbis**(strings 实测 8144 个 `OggS`;44.1kHz 立体声)。
- `Sizuku.exe` 内可见 `%s.ogg` / `%s_a.ogg` 格式串:部分曲目有 `_a` 变体(动作/替用)。
- 播放:BGM 循环(引擎 `ScriptMusicStart(no, loop)`)。

## SE — `soundds.PAK`(LAC 容器)

- 13 条,内容为 **RIFF/WAVE**,`fmt ` 与 `data` chunk 齐全;strings 显示由 **GoldWave** 生成。
- 播放:一次性 SE,可与 BGM 混音。

## 效果音 — `MAX_DATA.PAK` 内 `SZ_VD01-10.P16`

- 10 条,每条 = 4 字节头(`02 00 0c 00`)+ **16-bit 小端 PCM** 数据。
- 实测:92635 样本/条(11025Hz 下 ≈8.4s),幅值小(±5000),疑似环境音/SE。
- 头字段语义(前两个 u16)待 Phase 2 用频谱/波形确认;播放时按原始采样率(先试 11025/16000/22050Hz)。

## macOS 播放方案

```
LAC 容器 → 解包 → Ogg/WAV/PCM → AVAudioEngine(AVAudioPlayerNode)
```
- 不需要 8AD/13kHz 之类 GBA 转换(那是 GBA 专用;见 sizuku-gba.md)。
- 若需与原版 44.1kHz 行为对齐,直接原样播放即可。
