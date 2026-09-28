# コンテナフォーマット — LEAFPACK および LAC

> 🌐 **Language / 多言語**: [🇨🇳 简体中文](containers.md) ｜ [🇺🇸 English](containers-en.md) ｜ [🇯🇵 日本語](containers-jp.md)

## LEAFPACK (`MAX_DATA.PAK` 等)

参考実装：XLVNS / mglvns `leafpack.c`（Go Watanabe 氏、©1999-2000、BSD ライセンス）。
検証結果：自作 Python 抽出器（`research/tools/unpack_leafpack.py`）により、実機 `MAX_DATA.PAK` 内の全 403 ファイルを正常に抽出完了。

### バイナリ構造レイアウト

```text
offset  0:  "LEAFPACK" (8 B マジックナンバー)
offset  8:  u16 LE 収録ファイル総数 file_num
offset 10:  ファイルペイロード部（ローリング暗号鍵による加算難読化）
末尾 24*n: ディレクトリテーブル（24 B / 項目）、同様に暗号化
```

収録ファイル数によってゲーム種別を自動識別可能（leafpack.c と一致）：

| file_num | タイトル |
|---|---|
| 0x0193 (403) | 『雫』Windows 版 |
| 0x01fb (511) | 『痕』Windows 版 |
| 0x0248 / 0x03e1 | 『To Heart』 |
| 0x0072 (114) | 『さおりんといっしょ!!』 |

### 難読化キーストリーム（11 バイト）

暗号化規則：`stored = (plain + key[k]) & 0xff`。鍵インデックス `k` はファイル境界を越えてリセットされず連続加算されます（データ領域先頭を 0 として開始）。

デフォルト鍵（雫 2007 年版実測、pakwriter 定数と同一）：
`71 48 6a 55 9f 13 58 f7 d1 7c 3e`（ASCII `qHjU…`）— `Sizuku.exe` 内の `"LEAFPACKqHjU"` と一致。

`guess_key()` アルゴリズムにより、ファイル名末尾の空白パディング特性を利用してテーブル自身から鍵を復元可能なため、鍵のハードコードなしに**任意の LEAFPACK アーカイブを復号可能**です。

### ディレクトリテーブル項目（24 バイト）

```text
0..7   ファイル名（最大 8 文字、半角空白埋め、'.' は非保持）
8..10  拡張子（3 文字）
11     0x00 終端文字
12..15 u32 LE ペイロードデータ先頭オフセット
16..19 u32 LE ファイル長（圧縮時または非圧縮時）
20..23 u32 LE 次ファイルオフセット（未使用）
```

ファイル名は 8.3 形式（例：`SCN000.DAT`）として再構成されます。

### ペイロード領域

- 非圧縮ファイル：1 バイトごとに `plain = (stored - key[i % 11]) & 0xff`。
- 圧縮ファイル（LZS 展開対象）：8 バイトヘッダ `[u32 BE 圧縮後サイズ][u32 BE 展開後サイズ]` + 圧縮ストリーム。

### LZS 伸張バリアント

- `lzs`：標準正論理フラグ、リングバッファ `0x1000`、初期ポインタ `0x0FEE`。
- `lzs2` / `lzs3`：反転フラグ論理（`~flag`）、リングバッファ `0x1011`。
- 検証結果：SCN シナリオスクリプトは **lzs3（反転フラグ・正方向書き込み）** を採用。LFG 画像ビットマップは標準 `lzs` を採用。

---

## LAC (`bgmfile.PAK` / `soundds.PAK`)

バイナリ解析による構造定義：

```text
offset 0: "LAC\0"
offset 4: u32 LE ファイル数
以降:     ディレクトリ部（約 42 B / 項目）:
          +0  ファイル名（8 B, Shift-JIS）
          +36 u32 LE ペイロードオフセット
          +40 u32 LE ファイルサイズ
以降:     ファイル実体部
```

- `bgmfile.PAK`：25 項目、44.1kHz ステレオ **Ogg Vorbis** 音声。
- `soundds.PAK`：13 項目、GoldWave により生成された **RIFF/WAVE** 音声。
