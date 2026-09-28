# 雫 macOS 移植研究レポート (Phase 0/1)

> 🌐 **Language / 多言語**: [🇨🇳 简体中文](SHIZUKU_PORT_RESEARCH_REPORT.md) ｜ [🇺🇸 English](SHIZUKU_PORT_RESEARCH_REPORT-en.md) ｜ [🇯🇵 日本語](SHIZUKU_PORT_RESEARCH_REPORT-jp.md)

『雫～しずく～』（Leaf 1996 / 2007 年再版）の macOS ネイティブ移植に関する基礎研究および検証レポート。

## 0. 総合所見

**実現可能性：100% 実行可能であり、当初の想定より極めて高精度な再現が可能。**

過去のオープンソースプロジェクト（XLVNS、MGLVNS、lfview、akkera 氏の sizuku 関連ツール群、GBALVNS）により、LVNS エンジンのコンテナ、画像、シナリオバイトコード、フォント、オペコード体系がすべて解析され、BSD ライセンス下で公開されています。実機データ（`MAX_DATA.PAK`）に対する全数検証を実施：
- 403 個の全ファイルを正常に抽出完了。
- 197 本の SCN シナリオスクリプトを完全伸張。
- `sizfont.tbl` による葉文字コード復号で、完全な日本語シナリオテキストの復元を確認。
- LFG 画像ヘッダの 640×400 解像度（非圧縮 128,000 バイト）を実機一致で確認。

## 1. 原版エンジン構造

『雫』『痕』『To Heart』は Leaf 独自の LVNS（Leaf Visual Novel Series）エンジンを共有：
- **アーカイブ**：`MAX_DATA.PAK`（LEAFPACK コンテナ、403 ファイル）、`bgmfile.PAK` / `soundds.PAK`（LAC コンテナ）、`Sizuku.exe`。
- **データフロー**：起動 → `MAX_DATA.PAK` ロード → 要求に応じて `SCN%03d.DAT` 伸張 → 外層イベント VM がシーンを駆動、内層メッセージ VM がテキストと演出を進行 → 各種 LFG 画像（640×400、16色パレット）、24×24 KNJ フォント、PCM/Ogg 音声を並行再生。
- **シナリオ構成**：197 本の SCN ファイルからなり、ブロック単位で分岐とセーブを管理。

## 2. 解析済みフォーマット一覧

| ファイル | 種別 | 検証結果 | パーサー・実装 |
|---|---|---|---|
| `MAX_DATA.PAK` | LEAFPACK | 403/403 ファイル抽出成功 | `leafpack.c` / `shizuku_cli` |
| `bgmfile.PAK` | LAC | 25 曲 Ogg Vorbis | 自作 LAC 抽出ツール |
| `soundds.PAK` | LAC | 13 本 RIFF/WAV | 自作 LAC 抽出ツール |
| `*.LFG` | LEAFCODE | 640×400 16色画像 | `lfgdec.c` / Swift Metal パイプライン |
| `SCN*.DAT` | SCN | 197 本のスクリプト | `decscn.py` / Swift Event VM |
| `KNJ_ALL.KNJ` | 1bpp フォント | 1,852 字（133,344 バイト） | 24×24 縦列走査デコーダ |
| `SZ_VD*.P16` | 16-bit PCM | 11,025Hz モノラル音声 | `AVAudioConverter` リサンプラー |
