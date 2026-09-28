# Shizuku_macos_restore_study
## Leaf LVNS ビジュアルノベルエンジン解析と macOS ネイティブ移植研究リポジトリ
### 1996年 Leaf 処女作『雫～しずく～』のリバースエンジニアリングと Swift + Metal 現代再構築

> 🌐 **Language / 多言語**: [🇨🇳 简体中文](README.md) ｜ [🇺🇸 English](README-en.md) ｜ [🇯🇵 日本語](README-jp.md)

---

## 📖 リポジトリ概要

本リポジトリは、Leaf（現アクアプラス）が1996年にリリースした伝説的ビジュアルノベル『雫～しずく～』および同系統の LVNS（Leaf Visual Novel Series）エンジンに関する**完全なリバースエンジニアリング、独自データフォーマット仕様書、歴史的研究資料、解析ツール群、および現代 macOS ネイティブ再実装のリファレンス資料庫**です。

Windows 95 時代のレガシーバイナリ資産を構造レベルで解体し、最新の Apple Silicon / macOS 上で Swift と Metal パイプラインを用いて 60Hz 描画のネイティブアプリケーションとして再構築する全工程を体系的に整理しています。

---

## 📑 核心技術仕様書（長編技術ドキュメント）

徹底したリバースエンジニアリングと実機検証に基づき、3言語で完全同期された技術文書を提供しています：

- 🇨🇳 **[中国語技術解説（中文）](articles/leaf-galgame-port-zh.md)**：加算ローリング暗号の解析、LZS3 境界ガード、24×24 縦列優先フォント展開、二層仮想マシン（Event VM + Inline VM）、パレット暗転処理、13 種トランジションの幾何アルゴリズム、時計塔 (448, 128) の隠し音楽室の逆アセンブルを詳解。
- 🇺🇸 **[英語技術仕様書 (English)](articles/leaf-galgame-port-en.md)**：A rigorous, pragmatic systems engineering postmortem covering proprietary PAK cryptanalysis, dual-layer VM coroutine design, 24x24 1bpp vertical font decoding, CoreAudio exception swallowing, and Apple Silicon adaptations.
- 🇯🇵 **[日本語技術仕様書](articles/leaf-galgame-port-jp.md)**：LVNS エンジンのバイナリ解析、2 層仮想マシン設計、描画および CoreAudio 障害追究、タイトル画面 VA 0x430ebc の第 5 不可視ポインタから導く隠し音楽室の復元など、全工程を実務的に解説した技術仕様書。

---

## 📐 独自フォーマット解析仕様書

Windows 95 原版で使用されている各種バイナリフォーマットのフィールド定義：

1. [**LEAFPACK コンテナと 11 バイト排他的論理和復号仕様**](docs/containers.md)：8 バイトヘッダ、uint16 ファイル数、加算ローリング XOR キーストリーム、ディレクトリ差分解析アルゴリズム。
2. [**LFG 画像フォーマットとビットインターリーブ仕様**](docs/lfg.md)：16 色 4bit パレットのニブル複製展開（`(c << 4) | c`）、垂直列優先ビットプレーン展開、400px 立ち絵ビューポート。
3. [**SCN スクリプト構造と二層仮想マシン**](docs/scripts.md)：外層ブロック遷移モデル、13 個のダミー Skip 命令、インライン ASCII マクロ（B/E, C, S, D, M, P, F, Q）ディスパッチ。
4. [**LAC 音声コンテナと BGM マッピング**](docs/audio.md)：`bgmmap` 変換式、CD-DA オフセット補正、OST 音響指紋照合。
5. [**LVNS エンジンの歴史と系譜**](docs/history.md)：PC-98 版から Windows 95 版への技術的変遷。
6. [**Windows 95 原版ファイル構成一覧**](docs/original-files.md)：リテール版ディスク収録ファイルの機能別一覧。
7. [**未知命令と 13 個の Skip Opcode 解析**](docs/unknown-opcodes.md)：未公開オペコードの引数長特定と安全なステップ実行。
8. [**GBALVNS オープンソース構造リファレンス**](docs/gbalvns.md)：ゲームボーイアドバンス移植版ステートマシンと実装検証。
9. [**GBA 移植版との比較分析**](docs/sizuku-gba.md)：PC 原版と携帯機版データ構造の差異。

---

## 📋 研究レポートと開発日誌

プロジェクトの検証記録と実機デバッグログ：

- [**Phase 0/1 初期検証レポート**](reports/SHIZUKU_PORT_RESEARCH_REPORT.md)：立案時のフォーマット特定、ツールチェーン検証、実現可能性評価。
- [**完全開発引き継ぎ日誌 (HANDOVER)**](reports/HANDOVER.md)：M4.10 描画再現、M4.11 トランジションと隠し音楽室の逆アセンブル、11025Hz モノラル音源による CoreAudio 例外追究、macOS App Nap 対策を含む 340KB の開発記録。
- [**マイルストーンと受入基準**](reports/MILESTONES.md)：アジャイル開発マイルストーンと検証チェックリスト。
- [**コンテキスト復元ベースライン**](reports/RESUME_PROMPT.md)：開発環境とステートマシンプロンプト基準。

---

## 🗂 リポジトリ構成一覧

```text
Shizuku_macos_restore_study/
├── README.md                      # メインインデックス（中国語）
├── README-en.md                   # メインインデックス（英語）
├── README-jp.md                   # メインインデックス（日本語）
├── _config.yml                    # GitHub Pages (Jekyll) 設定ファイル
├── _layouts/                      # Web レイアウト（3言語対応ナビゲーション・フッター）
│   └── default.html
├── assets/                        # スタイルシート・静的リソース
│   └── css/
│       └── style.css
│
├── articles/                      # 核心技術仕様書（中・英・日同期）
│   ├── leaf-galgame-port-zh.md    # 中国語版技術解説
│   ├── leaf-galgame-port-en.md    # 英語版技術仕様書
│   └── leaf-galgame-port-jp.md    # 日本語版技術仕様書
│
├── docs/                          # バイナリフォーマット仕様書（全9本）
│   ├── containers.md              # LEAFPACK コンテナと復号仕様
│   ├── lfg.md                     # LFG 画像とビットインターリーブ
│   ├── scripts.md                 # SCN バイトコードと二層 VM
│   ├── audio.md                   # LAC 音声と BGM 番号対応
│   ├── history.md                 # LVNS エンジン進化の歴史
│   ├── original-files.md          # Win95 原版ファイル構成
│   ├── unknown-opcodes.md         # 未知命令と Skip Opcode 解析
│   ├── gbalvns.md                 # GBALVNS アーキテクチャ参考
│   └── sizuku-gba.md              # GBA 移植版の比較分析
│
├── reports/                       # 全量研究レポート・開発日誌（全4本）
│   ├── SHIZUKU_PORT_RESEARCH_REPORT.md  # Phase 0/1 初期研究レポート
│   ├── HANDOVER.md                # 開発引き継ぎ日誌（340KB）
│   ├── MILESTONES.md              # マイルストーンと受入基準
│   └── RESUME_PROMPT.md           # コンテキスト復元ベースライン
│
├── tools/                         # 解析・抽出ツール群
│   ├── shizuku_cli/               # モジュール式 Python CLI
│   └── scripts/                   # 各種単体スクリプト
│
├── disasm/                        # シナリオスクリプト逆アセンブル出力
│   └── SCN000.txt ... SCN196.txt  # 197 本の SCN スクリプトダンプ
│
├── preview/                       # 復号画像および検証レンダリング
│   ├── knj_atlas.png              # 1,852 字フォントアトラス
│   ├── hvs01_decoded.png          # 立ち絵デコード画像（月島瑠璃子）
│   ├── hvs01_from_tool.png        # CLI レンダリングテスト
│   ├── preview_bg01.png           # 背景デコード画像プレビュー
│   └── preview_leaf.png           # パレット検証フレーム
│
├── references/                    # 過去のオープンソース実装リファレンス
│
└── runtime_reference/             # 現代 Swift + Metal ネイティブ実装リファレンス
    ├── Package.swift              # SPM パッケージ構成定義
    └── Sources/                   # ShizukuCore, ShizukuEngine, ShizukuRender, ShizukuApp
```

---

## 🛠 主なリバースエンジニアリング成果

1. **LEAFPACK アーカイブと 11 バイトローリングキーストリーム**：
   - 鍵系列：`71 48 6a 55 9f 13 58 f7 d1 7c 3e`
   - ディレクトリ領域の 24 バイトファイル名スロット末尾（スペースパディング）に着目した差分ブラインド暗号解読。
2. **LZS 伸張バリアントと 173/197 スクリプト末尾ゴミ詰まりの解消**：
   - LFG 画像用の標準 LZS と SCN スクリプト用の反転フラグ `lzs3`（リングバッファ `0x1011`）を厳格に分離。
   - ヘッダ記載の非圧縮サイズによる強制ストリーム切断処理を導入し、原版 173 本のスクリプト末尾にあった破損バグを完全解消。
3. **KNJ ビットマップフォント物理配置と 1-based 直接アドレッシング**：
   - `KNJ_ALL.KNJ`（133,344 バイト）は 1,852 文字（24×24 px、1bpp、1文字72バイト）を 3 垂直走査ストリップで保持。
   - 葉コードは配列の直接インデックス（`code - 1`）であることを立証。
4. **二層入れ子仮想マシン（Event VM + Inline VM）のアーキテクチャ**：
   - 外層イベントストリームに存在する 13 個のダミー Skip 命令を同定。
   - 立ち絵・背景・BGM・効果音・画面揺れ・白フラッシュなどの演出の 90% が会話テキスト内のインライン ASCII マクロとして埋め込まれている構造を解明。
5. **ビジュアル表現の高精度復元**：
   - 25×13 サウンドノベルテキストグリッド、3 パス影文字描画、全体 `11/16` パレット暗転。
   - `(27, 12)` を中心とする 16px タイルブロックの外向き螺回転換（GURUGURU）アルゴリズムを完全再現。
6. **タイトル画面隠し音楽室の逆アセンブル解明**：
   - 原版 EXE の仮想アドレス `0x430ebc` に存在する第 5 の不可視ポインタを特定し、校舎時計塔右上窓 `(448, 128)` の座標を算出。
   - `0x408d40` の音楽室メインループを解析し、`VIS17.LFG` 上で完全に再現。
7. **macOS 低レイヤー障害の解消**：
   - 11025Hz モノラル音源が CoreAudio ステレオノードでクラッシュする問題を `AVAudioConverter` のリサンプリングで解決。
   - macOS App Nap による 60Hz タイマーの 5 FPS への極端なクロックダウンを `ProcessInfo.beginActivity` で抑止。

---

## 🚀 解析ツールの使用方法

```bash
# シナリオスクリプトを可読アセンブリに逆コンパイル
python3 tools/scripts/shizuku-scn-disasm.py /path/to/SCN001.DAT -o SCN001.txt

# 24×24 KNJ フォントアトラスを生成
python3 tools/scripts/shizuku-knj-font.py /path/to/KNJ_ALL.KNJ --atlas preview/knj_atlas.png

# LFG 画像アセットを PNG にデコード
python3 tools/scripts/shizuku-lfg-image.py /path/to/HVS01.LFG -o preview/hvs01.png

# モジュール式 CLI で PAK アーカイブを検査・抽出
python3 -m tools.shizuku_cli inspect /path/to/MAX_DATA.PAK
python3 -m tools.shizuku_cli extract /path/to/MAX_DATA.PAK -o output_dir/
```

---

## 📜 著作権および免責事項

- 本リポジトリに収録された研究資料、解析ツール、逆アセンブル解説、および再構築コードは、コンピュータソフトウェア工学の研究、レガシーシステムの互換性検証、およびデジタル文化遺産の保存を目的としています。
- 『雫～しずく～』ならびに関連するキャラクター、シナリオ、音楽、美術資産の著作権は Leaf / 株式会社アクアプラスに帰属します。
- 本リポジトリは、製品版ゲームの著作権で保護されたオリジナルリソース（CD-ROMイメージやPAKファイル等）の再配布を行いません。
