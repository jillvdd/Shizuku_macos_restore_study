# LFG 画像フォーマット仕様書（LEAFCODE）

> 🌐 **Language / 多言語**: [🇨🇳 简体中文](lfg.md) ｜ [🇺🇸 English](lfg-en.md) ｜ [🇯🇵 日本語](lfg-jp.md)

参考実装：lfview `plugins/lfgdec.c`、mglvns `lfg.c`（Go Watanabe 氏）。
実機検証：`HVS01.LFG` = 640×400 解像度、非圧縮ペイロードサイズ = 128,000 バイト（= 640×400 / 2）。

## ヘッダ構造レイアウト

```text
0..7     "LEAFCODE" (8 B マジックナンバー)
8..31    24 B パレット（16色 × 3チャンネル、4-bit パック）
32..33   u16 BE xoffset（立ち絵 X 座標オフセット）
34..35   u16 BE yoffset（立ち絵 Y 座標オフセット）
36..37   u16 BE width  = (値 + 1) * 8
38..39   u16 BE height = 値 + 1
40       描画方向フラグ（0 = VERTICAL 縦列優先、0 以外 = HORIZONTAL 横行優先）
41       透明色インデックス
42..43   予約領域（実測 0x00, 0x00）
44..47   u32 LE 展開後ピクセルバッファサイズ（= width * height / 2、1バイトあたり2ピクセル）
48..     LZS 圧縮ピクセルストリーム（leafpack_lzs により展開）
```

パレットのニブル復号：各バイトは `RG BR GB RG BR ...` の順で格納され、上位/下位 4-bit を `(nibble << 4) | nibble` で 8-bit に拡張して完全な RGBA を生成します。

ピクセル配置：VERTICAL モードでは 2 列ずつの縦帯単位で走査されます。

## 確認済み仕様

- 基準解像度：640×400。
- 色深度：16 色インデックスパレット。
- 立ち絵画像は `xoffset`/`yoffset` を内包し、画面上の描画位置を直接指定。
- 各画像ごとに透明色インデックスを設定可能。
