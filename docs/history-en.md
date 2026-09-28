# Historical Research: XLVNS / MGLVNS / lfview / leafpak / PVNS

> 🌐 **Language / 多语言**: [🇨🇳 简体中文](history.md) ｜ [🇺🇸 English](history-en.md) ｜ [🇯🇵 日本語](history-jp.md)

## Genealogical Tree

```text
Leaf LVNS Engine Family (c) 1996-1999 Leaf / AQUAPLUS
  ├─ lfview   (TF, 1997-)           LFG/LF2/grp graphics viewer
  ├─ leafpak  (TF, ~2000)           PAK extraction utility
  ├─ PVNS     (yossy, 1999)         PalmOS port (SCN analysis & lfview)
  ├─ XLVNS    (Go Watanabe, 1999-)  X11 port (BSD/Linux/Solaris), CVS hosted on denpa.org
  ├─ ZVNS     (S.TAKe, 2000-01)     Sharp Zaurus Linux port based on XLVNS
  └─ MGLVNS   (TF, ~2001)           MGL2 (NetBSD hpcmips) port based on XLVNS
```

## Core Reference Assets

| Source | Role | Significance |
|---|---|---|
| `leafpack.c` (mglvns-1.0) | Archive unpacker | 11-byte XOR cryptanalysis and directory parsing |
| `lfg.c` / `lfgdec.c` | Image decoder | Bit interleaving and 4-bit nibble expansion |
| `decscn.py` (akkera) | Script extractor | SCN container segmentation and LZS decompression |
| `script.c` (akkera) | Bytecode VM | Complete opcode table and branching state machine |
| `sizuku_menu.c` (mglvns) | UI controller | Save/load bookmarking and backlog navigation logic |
