# sizuku advance / sizuku_gba2(akkera102,GBA)

> 🌐 **Language / 多语言**: [🇨🇳 简体中文](sizuku-gba.md) ｜ [🇺🇸 English](sizuku-gba-en.md) ｜ [🇯🇵 日本語](sizuku-gba-jp.md)


## 资料获取

- 老站 `gbadev_old/` 全部在线,四个 zip 已下载到 `research/thirdparty/akkera/`:
  - `76_sizuku_viewer.zip`(LFG→BMP 查看器,`1_lfg2bmp.py`)
  - `77_sizuku_snd_test.zip`(8AD 音效测试,转换链 `wav(44.1k 2ch)→sox(13379Hz 1ch)→8ad`)
  - `78_sizuku_scn_test.zip`(**`scndec.py`** = 原版 SCN 解码器;`script.c` 雏形)
  - `79_sizuku_gba.zip`(sizuku advance:**`decscn.py`、`declfg.py`、`script.c/h`、`anime.c/h`、`sizuku.c/h`、字体工具 `font2leaf.py`/`sizfont.txt`/`k12x10_fnt.txt`、`sjis2leaf.txt`**)
- 四个 zip 均注明"运行需要 Win95/98 版雫 MAX_DATA.PAK"——确认 GBA 工具直接解析原版数据。

## 关键产出(对本项目价值)

1. **`decscn.py` / `scndec.py`**:把原版 SCN 解包(16 字节头 + 事件段/消息段 LZS3 解压)并重打包成 GBA 用格式。SCN 容器结构由此 100% 确认。
2. **`script.c`**:完整的原版事件/文本解释器,opcode 语义最完整的一手来源(0x00-0xff 各命令、选择、旗标、结局判定、系统菜单、存档 SRAM)。
3. **`anime.c`**(17KB):动画/特效引擎,GBALVNS 的 `core/anime.c` 即其血统。
4. **字体工具**:`font2leaf.py` + `sizfont.txt`/`k12x10_fnt.txt` 演示了"K12x10 点阵 → Leaf 字形"的生成流程;`sjis2leaf.txt` 即 gbalvns `txt_sjis2leaf.txt` 前身。
5. 确认了音频转换链是 **GBA 特化**(8AD),macOS 不应照搬。

## 与 GBALVNS 的继承关系(确认)

```
Akkera102 sizuku advance(79,2007-07)→ sizuku_gba2(新版,NO.100)
                                        → gbalvns(laqieer,2021,BSD-3)
```
GameBrew 页称 gbalvns 基于 sizuku_gba2;gbalvns README 同述。`EVTDef.s` 事件 opcode 与原版 `script.c` 的 switch 一致 → **opcode 编号即原版雫的编号(置信度:高)**。

## 注意

- GBA 工具读取的是"解包后的 SCN 重打包格式"(`HHHHLL` 头);解释器跑在转换后数据上,但 opcode 语义与原版一致。
- `79` 的 `_readme.txt` 确认原版 `MAX_DATA.PAK` 大小 5,757,223 B(1996-06-28),与本拷贝 5,756,792 B 相差 431 B —— 汉化重打包痕迹,格式兼容。
