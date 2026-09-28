# GBALVNS(laqieer,GBA,BSD-3-Clause)

仓库已完整 clone:`research/gbalvns/`(最新提交 `289ff8b`)。

## 性质(重要)

**GBALVNS 不是"直接读 Windows 原版数据的运行时",而是自带资产管线的通用 GBA VN 引擎**:

- 资产:PNG 图(`asset/image/*.png`)经 grit 转 GBA tile;WAV(`asset/sound/tr_*.wav`)经 `tool/wav28ad` 转 8AD;脚本用手写汇编/文本 `asset/script/*.S`。
- 脚本:作者用**文本标记语言**编写事件/消息/动画,编译成 `SCN%03d.dat` 二进制(样例 `asset/script/SCN001.S` → `SCN000.dat`)。
- 它演示的样例游戏是"Summer"(自由素材),**不含雫数据**。

因此:**gbalvns 的运行时架构/opcode 体系可作参考,但其资源管线不能直接读取我们的 PAK**。真正读原版数据的是它继承的 sizuku_gba2/akkera 工具链(见 sizuku-gba.md)。

## 代码要点

- `core/script.h`:事件/消息/动画状态机,`SCRIPT_MAX_SCN_CNT=197`(与原版雫 197 个 SCN 一致)。
- `core/anime.c`、`core/res/ani_*.txt`:动画/特效脚本(继承 sizuku_gba2)。
- `core/res/bin_k12x10g.bmp`/`bin_k12x10w.bmp`:12×10 点阵字体(白/绿),与雫的 K12x10 同源;`txt_sjis2leaf.txt` = SJIS→Leaf 字形映射。
- `EVTDef.s`:事件 opcode 常量表(0x00 End…0xff EndAll),与原版 `script.c` switch 逐项对应。
- `tool/wav28ad`、`tool/imgfix.py`:GBA 专用转换(8AD/LZ77)。

## 对本项目的参考价值

1. 事件 opcode 编号(已与原版 `script.c` 交叉确认)。
2. 运行时状态机结构(事件/消息/动画/等待/选择/历史/菜单)可作为 macOS 引擎的骨架蓝本。
3. 12×10 字体渲染思路(glyph atlas)对 macOS 端文字渲染有参考。
4. 许可 BSD-3-Clause,可复用。

## 差异警示

- gbalvns 的 SCN 二进制(它自己的编译器产物)与原版 SCN **不同**:原版是"事件段+消息段各自 LZS",gbalvns 是 `EVT/MSG 偏移+尺寸` 扁平布局。不要混用。
