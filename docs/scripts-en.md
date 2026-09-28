# SCN Scenario Script Format (SCN%03d.DAT)

> 🌐 **Language / 多语言**: [🇨🇳 简体中文](scripts.md) ｜ [🇺🇸 English](scripts-en.md) ｜ [🇯🇵 日本語](scripts-jp.md)

Reference implementations: akkera102 `decscn.py` / `script.c`, GBALVNS `EVTDef.s`, XLVNS `LvnsScript.c`.
Fully verified across all 197 scenario scripts (`SCN000.DAT` - `SCN196.DAT`).

## File Structure

```text
0..1   u16 LE Event section file offset = val * 0x10
2..3   u16 LE Message section file offset = val * 0x10
[padding up to event offset]
Event Section:   u32 LE uncompressed size d1Size + lzs3 payload
Message Section: u32 LE uncompressed size d2Size + lzs3 payload
```

## Event Section (Decompressed)

```text
0..1   u16 LE Last block index
2..    Array of u16 LE block offsets (Block 0..last)
after  Event bytecode stream
```

Blocks represent scenario execution units: the engine dispatches by `(scnNo, blkNo)`. Jump opcode `0x04` routes directly to `SCN%03d.DAT Block %d`.

### Primary Event Opcodes

| Opcode | Length | Semantics |
|---|---|---|
| 0x00 | 1 | End of block (stop BGM, terminate execution) |
| 0x01 | 3 | Subcommand: 01/02/04 display text; 03 animation wait |
| 0x04 | 3 | Jump to `SCN%03d.DAT block %02x` |
| 0x05 | 3+2N | Branching choice: prompt text, option count, pairs of (msg, jump) |
| 0x07 | 1 | Mark anchor for previous choice |
| 0x0a | 2 | Set background `MAX_S%02d` |
| 0x14 | 2 | Clear screen buffer |
| 0x16 | 2 | Load H-CG visual `HVS%02d` |
| 0x22 | 3 | Set portrait `MAX_C%02x` at position (left/center/right) |
| 0x24 | 3 | Set close-up portrait (forced center) |
| 0x38 | 2 | Display refresh / transition effect with fade |
| 0x3d | 4 | Conditional branch `if flag[c1] == c2` |
| 0x3e | 4 | Conditional branch `if flag[c1] != c2` |
| 0x47 | 3 | Assign system flag `flag[c1] = c2` |
| 0x48 | 3 | Increment system flag `flag[c1] += c2` |
| 0x54 | 2 | Invoke message dialogue index |
| 0x6e | 2 | Loop play BGM |
| 0x7d | 2 | Staff roll credits execution |
| 0x7e | 2 | Ending index evaluation |
| 0xff | 1 | Terminal sentinel |

## Message Section (Decompressed)

Text is stored in **Leaf font codes** (1-based index into `KNJ_ALL.KNJ`). Bytes with MSB set (`c[0] & 0x80`) represent 2-byte glyph codes: `((c[0] & 0x7f) << 8) | c[1]`.

Control tokens (ASCII < 0x80):
- `$`: Message termination
- `p`: Page advance (clears text buffer on click)
- `k` / `K`: Wait key (advances to next line on click)
- `r`: Line break
- `B` / `E`: Staged background change
- `C`: Staged portrait change
- `D`: Clear portrait slots
- `S`: Atomically swap background and portrait
- `A` / `a`: Three-character portrait layout
- `V`: Visual event CG
- `H`: H-CG scene
- `M`: BGM fade, next track, or stop
- `P`: PCM audio playback
- `Q`: Palette dimming / darkening
- `F`: Screen flash
- `X`: Horizontal line indentation
- `s`: Typewriter speed
