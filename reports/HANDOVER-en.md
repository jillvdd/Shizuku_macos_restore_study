# Engineering Handover Log & Systems Postmortem

> 🌐 **Language / 多语言**: [🇨🇳 简体中文](HANDOVER.md) ｜ [🇺🇸 English](HANDOVER-en.md) ｜ [🇯🇵 日本語](HANDOVER-jp.md)

Detailed engineering handover notes, real-device debugging logs, and verification checkpoints for the native macOS restoration of Leaf's *Shizuku* (1996).

## 1. Architectural Blueprint

The restoration project adopts a strictly decoupled four-layer Swift architecture:
- **ShizukuCore**: Binary asset extraction, 11-byte XOR cryptanalysis, LZS3 decompression, 24×24 KNJ vertical font decoding, and LFG bitmap parsing.
- **ShizukuEngine**: Outer Event VM bytecode coroutine scheduler and Inner Inline VM message tokenizer.
- **ShizukuRender**: Metal graphics pipeline, 640×400 offscreen render target, global `11/16` palette darkening, and 13 transition algorithms.
- **ShizukuApp**: Native AppKit window management, input dispatch, 60Hz display link, backlog history viewer, and secret title screen music room.

## 2. Real-Device Debugging Highlights

- **M4.4 LZS3 Truncation Fix**: Discovered that LZS3 streams without strict length truncation corrupted trailing messages in 173 of 197 scenario scripts. Enforcing header-declared uncompressed bounds permanently solved the issue.
- **CoreAudio Exception Swallowing**: Mono 11,025Hz WAV files thrown silently on stereo output nodes caused unexplained crashes in AppKit. Introducing `AVAudioConverter` upsampling resolved all playback failures.
- **App Nap FPS Throttling**: macOS automatically downgraded the 60Hz display loop to 5 FPS during text waits. Mitigated using `ProcessInfo.beginActivity([.userInitiated, .latencyCritical])`.
- **Clock Tower Music Room Disassembly**: Reconstructed the hidden easter egg at `(448, 128)` by disassembling the 5th menu pointer at VA `0x430ebc` in `Sizuku.exe`.
