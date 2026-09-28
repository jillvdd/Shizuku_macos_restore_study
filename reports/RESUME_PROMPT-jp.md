# システム技術基準およびクイックリファレンスマニュアル
## ——Leaf LVNS エンジン主要定数・メモリ配置・アーキテクチャ定義

> 🌐 **Language / 多言語**: [🇨🇳 简体中文](RESUME_PROMPT.md) ｜ [🇺🇸 English](RESUME_PROMPT-en.md) ｜ [🇯🇵 日本語](RESUME_PROMPT-jp.md)

---

## 1. 主要定数および検証済み基準値一覧

開発者およびリバースエンジニアリング研究者の参照用として、『雫～しずく～』（Windows 95 版 / LVNS エンジン）の実機検証済み定数を整理しました：

| パラメータ種別 | 定数値 / 16進定数 / オフセット | 技術的制約および意味論 |
|---|---|---|
| **基準描画解像度** | `640 × 400` | 原版 16:10 描画ターゲット、現代ディスプレイへの整数倍拡大 |
| **画面更新同期** | `60.0 Hz` | `CVDisplayLink` / `CAMetalDisplayLink` による厳密な位相同期 |
| **PAK 累積加算鍵** | `71 48 6a 55 9f 13 58 f7 d1 7c 3e` | 11 バイト加算循環キーストリーム（ASCII `"qHjU…"`） |
| **PAK ファイル識別数** | `0x0193` (403 ファイル) | LEAFPACK ヘッダの u16 宣言、『雫』Windows 版を特定 |
| **スクリプト展開バッファ** | `0x1011` | 反転フラグ LZS3（`~flag`）伸張、ヘッダ指定サイズで厳密切断 |
| **ビットマップフォント長** | `133,344` バイト | 1,852 字、24×24 px、1bpp、1字72バイト（3垂直走査列） |
| **葉文字コード参照方式** | `1-based` 直接配列インデックス | 文字物理オフセット = `(leaf_code - 1) * 72` |
| **サウンドノベル行組版** | `25 列 × 13 行` | 24px 文字幅、字間 1px、行間 6px、セーフマージン 20px |
| **隠し音楽室窓座標** | `(X=448, Y=128)` | 時計塔右上窓、原版 EXE 仮想アドレス `0x430ebc` の第 5 ポインタ |
| **音声リサンプリング基準** | `11,025 Hz モノラル → 44,100 Hz ステレオ` | CoreAudio ステレオノードでの `NSException` 例外クラッシュを根治 |

---

## 2. 主要バイナリ構造図

### 2.1 LEAFPACK アーカイブ物理配置 (`MAX_DATA.PAK`)

```text
+-------------------+--------------------+------------------------+---------------------+
| "LEAFPACK" (8B)   | FileCount (2B LE)  | Payload Data Stream    | Directory Table     |
| Magic Identifier  | Total = 403 Files  | Cumulative Additive    | 24B * 403 Entries   |
| 0x00 - 0x07       | 0x08 - 0x09        | 0x0A ... End-9672      | End-9672 ... EOF    |
+-------------------+--------------------+------------------------+---------------------+
```

### 2.2 SCN シナリオスクリプト物理配置 (`SCN%03d.DAT`)

```text
+---------------------+---------------------+---------------------+---------------------+
| EventOffset (2B LE) | MsgOffset (2B LE)   | Event Block Data    | Message Stream Data |
| Offset = Val * 0x10 | Offset = Val * 0x10 | u32 UncompressedSz  | u32 UncompressedSz  |
| 0x00 - 0x01         | 0x02 - 0x03         | + Inverted LZS3     | + Inverted LZS3     |
+---------------------+---------------------+---------------------+---------------------+
```

---

## 3. Swift ネイティブ再実装モジュール構成

```swift
// ShizukuCore: バイナリストリームおよびデコーダ群
public struct LeafPackArchive {
    public let entries: [LeafPackEntry]
    public func extract(entry: LeafPackEntry) -> Data
}

// ShizukuEngine: 二層仮想マシン協調スケジューラ
public final class ScenarioEngine {
    public func advanceEvent() -> EngineStepResult
    public func stepInlineMacro() -> InlineToken?
}

// ShizukuRender: Metal パイプラインと 13 種トランジション
public final class MetalGameRenderer: MTKViewDelegate {
    public func setTransition(type: TransitionType, duration: TimeInterval)
    public func renderFrame(into view: MTKView)
}
```

---

## 4. 解析ツール CLI コマンド早見表

```bash
# PAK アーカイブ内全ファイルを抽出
python3 tools/scripts/shizuku-unpack.py path/to/MAX_DATA.PAK -o output/

# 24x24 フォント全図アトラス生成（1,852 字）
python3 tools/scripts/shizuku-knj-font.py path/to/KNJ_ALL.KNJ --atlas preview/knj_atlas.png

# LFG 画像デコード（PNG 出力）
python3 tools/scripts/shizuku-lfg-image.py path/to/HVS01.LFG -o preview/hvs01.png

# SCN スクリプトを可読テキストへ逆アセンブル
python3 tools/scripts/shizuku-scn-disasm.py path/to/SCN001.DAT -o SCN001.txt
```
