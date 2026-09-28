# 原版ファイル構成一覧 — original-files.md

> 🌐 **Language / 多言語**: [🇨🇳 简体中文](original-files.md) ｜ [🇺🇸 English](original-files-en.md) ｜ [🇯🇵 日本語](original-files-jp.md)

Windows 95 原版ディスクの収録ファイル構成：

| ファイル名 | サイズ（バイト） | 種別 | 説明 |
|---|---|---|---|
| `MAX_DATA.PAK` | 5,756,792 | LEAFPACK | 主データパック（195枚 LFG画像、197本 SCNスクリプト、10本 P16音声、1本 KNJフォント） |
| `bgmfile.PAK` | 47,449,363 | LAC | BGM パッケージ（25 曲 Ogg Vorbis） |
| `soundds.PAK` | 700,960 | LAC | SE パッケージ（13 本 RIFF/WAVE） |
| `Sizuku.exe` | 249,856 | Win32 PE | 原版日本語ゲーム実行ファイル（エンジン本体） |
| `Sizuku_cn.exe` | 1,217,439 | Win32 PE | 自己解凍型ローダー |
| `manual.txt` | 3,144 | テキスト | 原版マニュアル（Shift-JIS） |

### `MAX_DATA.PAK` 内包 403 ファイルの内訳

- **195 枚の `.LFG` 画像**：立ち絵（`MAX_C00-`）、背景（`MAX_S00-`）、Hシーン（`HVS01-35`）。
- **197 本の `.DAT` シナリオスクリプト**：`SCN000.DAT` 〜 `SCN196.DAT`。
- **10 本の `.P16` 音声**：11,025Hz 16-bit PCM 音声（`SZ_VD01-10.P16`）。
- **1 本の `.KNJ` フォント**：`KNJ_ALL.KNJ`（24×24 1bpp、1,852 字、133,344 バイト）。
