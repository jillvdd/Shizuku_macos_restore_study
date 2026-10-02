# システム技術基準およびクイックリファレンスマニュアル
## ——Leaf LVNS エンジン主要定数・メモリ配置・アーキテクチャ定義 (Ver.1.5)

> 🌐 **Language / 多言語**: [🇨🇳 简体中文](RESUME_PROMPT.md) ｜ [🇺🇸 English](RESUME_PROMPT-en.md) ｜ [🇯🇵 日本語](RESUME_PROMPT-jp.md)

---

## 1. 主要定数および検証済み基準値一覧

開発者およびリバースエンジニアリング研究者の参照用として、『雫～しずく～』macOS ネイティブ移植版（Ver.1.5 二言語正式版）の実機検証済み定数を整理しました：

| パラメータ種別 | 定数値 / 16進定数 / オフセット | 技術的制約および意味論 |
|---|---|---|
| **基準描画解像度** | `640 × 400` | 原版 16:10 描画ターゲット、Metal による Retina ディスプレイへの整数倍等比拡大 |
| **画面更新同期** | `60.0 Hz` | `CVDisplayLink` 厳格同期、`ProcessInfo.beginActivity` 注入による App Nap 抑制 |
| **PAK 累積加算鍵** | `71 48 6a 55 9f 13 58 f7 d1 7c 3e` | 11 バイト加算循環キーストリーム（ASCII `"qHjU…"`） |
| **PAK ファイル識別数** | `0x0193` (403 ファイル) | LEAFPACK ヘッダの u16 宣言、『雫』Windows 版を特定 |
| **スクリプト展開バッファ** | `0x1011` | 反転フラグ LZS3（`~flag`）伸張、ヘッダ指定サイズで厳密切断 |
| **日本語フォント長** | `133,344` バイト | 1,852 字、24×24 px、1bpp、1字72バイト（3垂直走査列） |
| **日本語葉コード参照** | `1-based` 直接配列インデックス | 文字物理オフセット = `(leaf_code - 1) * 72` |
| **中国語フォント長** | `340,272` バイト | 4,726 スロット（`cnfont_4726.bin`）、前 1,852 槽は日文同等、後部は中国語拡張 |
| **中国語コード表マッピング** | `2,872` 文字 | 曖昧 NCC 照合＋単語出現頻度事前情報に基づく単調 DP で解出 |
| **全量中国語コーパス** | `3,834` 行 | 全 195 SCN スクリプト（`zh_text.json`）、日本語拍に比例スライス同期 |
| **PC-98 FM 音声パック** | 24 曲 (43.3 MiB) | YM2608 (OPNA) 実機内部直接録音、Ogg Vorbis q5 44.1kHz |
| **FM シームレスループ点** | `MUS11`: 8.750s / `MUS16`: 9.000s | イントロを 1 回再生後、継ぎ目なくループ区間へ自動遷移 |
| **FM ワンショット曲** | 6 曲（MUS00/14/17/18/20/23） | 音楽モードにて 1 回再生後自動停止（曲間無音 $\le -91\text{ dB}$） |
| **選択肢テキストグリッド** | 原版 tvram グリッド + `choiceRowGap = 1` | `'X' * 8` px 座標オフセット、選択肢間に 1 行の垂直余白行を挿入 |
| **メタセーブ共有フラグ** | `[0x00, 0x01, 0x45, 0x46]` | GBA SRAM `0x10` 相当の 4 フラグ、読込時再適用、幽霊選択肢を根治 |
| **文字表示・早送り速度** | 表示 30ms (2 flips) / 早送り遅档 17/60s | `Sizuku.exe` 逆アセンブルに準拠、遅い早送りは 59.1 字/秒 |
| **確定的視覚回帰基準** | `113 / 113` 確定フレーム | サンドボックス化 `SaveClock` 凍結時計、`MANIFEST.sha256` 照合 |
| **二言語正式配布物** | `build/` (JP) / `build_chs/` (ZH) | `Shizuku_Restored_Ver.1.5.dmg` および `Shizuku_Restored_CHS_Ver.1.5.dmg` |

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

## 3. Swift ネイティブ再実装モジュール構成 (Ver.1.5)

```swift
// ShizukuCore: バイナリストリーム、点陣字模、データモデル
public struct LeafPackArchive { ... }
public final class CnDotFont {
    public static func glyphData(forLeafCode code: Int) -> Data?
    public static func unicode(forLeafCode code: Int) -> Character?
}

// ShizukuEngine: 二層仮想マシン、二重音源ディスパッチャ、言語透過セーブ
public final class Engine {
    public var bgmSource: Int // 0=Windows原音, 1=PC-98 FM音源
    public var language: GameLanguage // .jp または .zh (ビルド時定数)
    public func sliceChineseText(_ text: String, jpBeats: Int) -> [String]
    public func skipCNEmptyBeats()
}

// ShizukuRender: Metal パイプライン、テキストグリッド、13 種トランジション
public final class SceneComposer {
    public static let choiceRowGap: Int = 1 // 選択肢垂直余白行
    public func drawCNMatrixText(...)
    public func choiceOptionRects(engine: Engine) -> [(option: Int, rect: CGRect)]
}

// ShizukuApp: AppKit ホスト、SwiftUI バージョン情報窓、113 フレーム回帰具
public final class AppDelegate: NSObject, NSApplicationDelegate {
    public func showAbout(_ sender: Any?) // 原生 SwiftUI バージョン情報ウィンドウ
}
```

---

## 4. 解析ツール CLI コマンド早見表

```bash
# 全 176 単体・統合テストの自動実行
swift test

# ヘッドレス 113 フレーム確定的視覚回帰検証（JP / ZH）
SHIZUKU_SHOT=spec ./build/Shizuku_Restored_Ver.1.5.app/Contents/MacOS/ShizukuApp
SHIZUKU_SHOT=spec ./build_chs/Shizuku_Restored_CHS_Ver.1.5.app/Contents/MacOS/ShizukuApp

# 全 13 エンディング自動巡回・回帰検証
SHIZUKU_SHOT=endingscan ./build/Shizuku_Restored_Ver.1.5.app/Contents/MacOS/ShizukuApp

# 漢化後書き 15 ページ通し検証
SHIZUKU_SHOT=afterword ./build_chs/Shizuku_Restored_CHS_Ver.1.5.app/Contents/MacOS/ShizukuApp

# 二言語 DMG 単体パッケージ署名作成
./package.sh jp && ./package.sh zh
```
