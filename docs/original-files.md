# 原版游戏文件清单 — original-files.md

> 数据源:用户持有的「雫～しずく～1996」Windows 95/98 汉化硬盘版。
> 清点时间:2026-08-17。所有文件均为只读参照,未做任何修改。

游戏目录:`/Users/abc/Documents/shizuku_macos_experience/《雫～しずく～1996》`(注意目录名带一个尾随空格)。

## 文件总表

| 文件名 | 大小 | 扩展名 | 推测用途 | 已知格式? | 解析器可用? | 需要逆向? |
|---|---|---|---|---|---|---|
| `MAX_DATA.PAK` | 5,756,792 B | PAK | 主数据包:195 张 LFG 图、197 个 SCN 脚本、10 个 P16 音频、1 个 KNJ 字体 | 是 | 是 | 否(已解包验证) |
| `bgmfile.PAK` | 47,449,363 B | PAK | BGM 音乐包:25 个 Ogg Vorbis | 是 | 是 | 否 |
| `soundds.PAK` | 700,960 B | PAK | 音效包:13 个 RIFF/WAV(经 GoldWave 生成) | 是 | 是 | 否 |
| `Sizuku.exe` | 249,856 B | EXE | 日文原版 PE 可执行文件(引擎本体) | 是(PE) | 否 | 最终目标不需要 |
| `Sizuku_cn.exe` | 1,217,439 B | EXE | 汉化补丁 PE(.data 段比原版大 ~336KB,内含中文字体/界面数据) | 是(PE) | 否 | 最终目标不需要 |
| `manual.txt` | 3,144 B | TXT | 日文说明书(Shift-JIS) | — | — | 无 |
| `用户须知（必读）.txt` | 1,587 B | TXT | AUGUST 汉化委员会声明(GBK) | — | — | 无 |
| `Thumbs.db` | 5,632 B | DB | Windows 缩略图缓存(无关) | — | — | 无 |
| `原声OST（无损）/` | ~365 MB | — | 附赠无损 OST(全轨 WAV + m4a + cue,非游戏数据) | — | — | 无 |

## 容器格式速查

- `MAX_DATA.PAK`:magic `LEAFPACK` + u16 文件数(0x0193 = **403**,即雫 Windows 版),XOR 滚动密钥(11 字节,默认 `71 48 6a 55 9f 13 58 f7 d1 7c 3e`,可经 `guess_key` 从表自身恢复),文件表在文件末尾(24 字节/项)。
- `bgmfile.PAK` / `soundds.PAK`:magic `LAC\0` + u32 文件数 + 目录(条目约 42 字节,偏移字段 +36、长度字段 +40)+ 数据。
- 详见 `containers.md`。

## MAX_DATA.PAK 内部 403 个文件(已实际解包验证)

按扩展名统计:

| 扩展名 | 数量 | 说明 |
|---|---|---|
| `.LFG` | 195 | LEAFCODE 格式图像:HVS01-35(H 场景)、MAX_C00+(立绘)、MAX_S00+(背景)、MAX_D/OP_/TITLE/LEAF 等 |
| `.DAT` | 197 | SCN000-DAT 场景脚本(事件+消息,分块,LZS 压缩) |
| `.P16` | 10 | SZ_VD01-10 16-bit PCM 音频(SE/效果音) |
| `.KNJ` | 1 | KNJ_ALL.KNJ 24×24 点阵字体,1852 字形(133,344 B 精确吻合) |

文件名抽样:`LEAF.LFG`、`HVS01.LFG`…、`MAX_C00.LFG`…、`SCN000.DAT`…、`SZ_VD01.P16`、`KNJ_ALL.KNJ`。

## 关键结论

1. **三大容器全部可解析**:LEAFPACK 由 XLVNS/mglvns 的 `leafpack.c` 文档化且我们已用真实文件验证解包;LAC 已实测解析;LFG 由 `lfg.c` 完整文档化并逐字节对上。
2. **SCN 脚本格式已确定**(见 `scripts.md`):事件段与消息段各自 LZS 压缩,opcode 与 sizuku_gba2/gbalvns 一致。
3. **剧情文本为日文**(Leaf 字形码,经 `sizfont.tbl` 可还原为通顺日文);汉化层在 EXE 内(见报告 §3)。
