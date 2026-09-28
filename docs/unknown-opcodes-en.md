# Analysis of Unknown & Infrequent Opcodes

> 🌐 **Language / 多语言**: [🇨🇳 简体中文](unknown-opcodes.md) ｜ [🇺🇸 English](unknown-opcodes-en.md) ｜ [🇯🇵 日本語](unknown-opcodes-jp.md)

Engineering principle: When encountering undocumented opcodes, verify operand widths via static bytecode disassemblers before attempting runtime instruction advancement.

## Outer Event Stream Opcodes

| Opcode | Handler in `script.c` | Verified Operand Width | Semantics |
|---|---|---|---|
| 0x03 | Unknown | 2 Bytes | Dummy parameter pass / skip opcode |
| 0x06 | Unknown | 1 Byte | Frame synchronizer / skip opcode |
| 0x08 | Table offset | 0 Bytes | Branch table marker |
| 0x5a | Unknown | 1 Byte | Delay / effect timing placeholder |
| 0x5c | Unknown | 2 Bytes | Extended skip opcode |
| 0x60-0x66 | Unknown | 1 Byte | Internal diagnostic anchors |
| 0x6f / 0x73 | Unknown | 1 Byte | Audio synchronization markers |
| 0x38 | LvnsDisp | 2 Bytes | Screen buffer transition and BGM queue dispatch |

## Inline Dialogue Token Parameters

- `0` (0x30): Infrequently used single-byte padding token.
- `X`: Horizontal pixel indentation offset.
- `s`: Typewriter speed delay timer.
- `P`: PCM audio trigger (`P01` to `P13`).
