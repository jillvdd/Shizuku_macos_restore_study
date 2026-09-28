# sizuku advance および sizuku_gba2 解析資料

> 🌐 **Language / 多言語**: [🇨🇳 简体中文](sizuku-gba.md) ｜ [🇺🇸 English](sizuku-gba-en.md) ｜ [🇯🇵 日本語](sizuku-gba-jp.md)

akkera102 氏による過去のアーカイブ資料：
- `76_sizuku_viewer.zip`：Python 製 LFG→BMP 変換スクリプト。
- `78_sizuku_scn_test.zip`：最古のオープンソース SCN パーサー `scndec.py`。
- `79_sizuku_gba.zip`：`decscn.py`、`declfg.py`、`script.c`、`anime.c`、およびフォント生成ツールを含む完全なツールチェーン。

## 主な技術的貢献

1. `decscn.py`：16 バイト SCN ヘッダおよび反転フラグ LZS3 伸張アルゴリズムを確定。
2. `script.c`：原版イベントおよびテキストバイトコード解釈器の決定版リファレンス。
3. GBA 版の 8AD 音声変換は携帯機ハードウェア固有の制約であり、macOS ネイティブ版では 44.1kHz の高音質をそのまま維持すべきであることを確認。
