# GBALVNS アーキテクチャリファレンス

> 🌐 **Language / 多言語**: [🇨🇳 简体中文](gbalvns.md) ｜ [🇺🇸 English](gbalvns-en.md) ｜ [🇯🇵 日本語](gbalvns-jp.md)

オープンソース参考資料：`research/gbalvns/`（laqieer 氏、BSD-3-Clause）。

## 位置づけ

GBALVNS は Windows 95 原版データを直接読み込むエンジンではなく、専用のアセットコンパイルパイプラインを備えた汎用 GBA ノベルエンジンです：
- スクリプトはアセンブリ形式テキスト（`asset/script/*.S`）からバイナリへコンパイル。
- 画像は GBA ハードウェアタイル形式（4bpp/8bpp）に変換。
- 音声は GBA 特有の 8AD 形式（8-bit 適応型デルタ PCM）へ変換。

## 活用ポイント

- `core/script.h`：イベント、メッセージ、アニメーション、選択肢、履歴の各状態遷移モデル。
- `EVTDef.s`：0x00〜0xff のオペコード定義が原版『雫』と完全一致していることを立証。
- `core/res/bin_k12x10*.bmp`：12×10 ビットマップフォントレンダリングアトラス。
