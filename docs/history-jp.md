# 過去プロジェクト研究：XLVNS / MGLVNS / lfview / leafpak / PVNS

> 🌐 **Language / 多言語**: [🇨🇳 简体中文](history.md) ｜ [🇺🇸 English](history-en.md) ｜ [🇯🇵 日本語](history-jp.md)

## 系譜図

```text
Leaf LVNS エンジン系列 (c) 1996-1999 Leaf / AQUAPLUS
  ├─ lfview   (TF 氏, 1997-)        LFG/LF2 画像ビューア
  ├─ leafpak  (TF 氏, ~2000)        PAK 抽出ユーティリティ
  ├─ PVNS     (yossy 氏, 1999)      PalmOS 移植版
  ├─ XLVNS    (Go Watanabe 氏, 1999-) X11 移植版（BSD/Linux/Solaris）
  ├─ ZVNS     (S.TAKe 氏, 2000-01)  Zaurus Linux 移植版
  └─ MGLVNS   (TF 氏, ~2001)        NetBSD hpcmips 移植版
```

## 主要リファレンス資産

| リソース | 役割 | 技術的価値 |
|---|---|---|
| `leafpack.c` (mglvns-1.0) | アーカイバ | 11 バイト XOR 復号とファイル名テーブル解析 |
| `lfg.c` / `lfgdec.c` | 画像デコーダ | ビットインターリーブ展開と 4-bit パレット復元 |
| `decscn.py` (akkera) | スクリプト抽出 | SCN コンテナ構造と LZS3 伸張 |
| `script.c` (akkera) | バイトコード VM | イベントおよびインラインオペコード体系の完全定義 |
| `sizuku_menu.c` (mglvns) | UI 制御 | セーブ・ロードおよびバックログ操作の参照実装 |
