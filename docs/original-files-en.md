# Retail File Manifest — original-files.md

> 🌐 **Language / 多语言**: [🇨🇳 简体中文](original-files.md) ｜ [🇺🇸 English](original-files-en.md) ｜ [🇯🇵 日本語](original-files-jp.md)

Inventory of retail disc assets for *Shizuku* (1996 Windows retail release):

| File | Size (Bytes) | Category | Description |
|---|---|---|---|
| `MAX_DATA.PAK` | 5,756,792 | LEAFPACK | Main archive: 195 LFG images, 197 SCN scripts, 10 P16 sounds, 1 KNJ font |
| `bgmfile.PAK` | 47,449,363 | LAC | Background music package: 25 Ogg Vorbis streams |
| `soundds.PAK` | 700,960 | LAC | Sound effects package: 13 RIFF/WAVE files |
| `Sizuku.exe` | 249,856 | Win32 PE | Original Japanese retail game executable |
| `Sizuku_cn.exe` | 1,217,439 | Win32 PE | Self-extracting translation loader |
| `manual.txt` | 3,144 | Plaintext | Original Japanese release documentation |

### Internal Contents of `MAX_DATA.PAK` (403 Files)

- **195 `.LFG` images**: Character portraits (`MAX_C00-`), backgrounds (`MAX_S00-`), and H-scenes (`HVS01-35`).
- **197 `.DAT` scenario scripts**: Numbered `SCN000.DAT` to `SCN196.DAT`.
- **10 `.P16` audio clips**: 16-bit mono 11,025Hz PCM sound clips (`SZ_VD01-10.P16`).
- **1 `.KNJ` bitmap font**: `KNJ_ALL.KNJ`, storing 1,852 glyphs in 24×24 1bpp vertical columns (133,344 bytes).
