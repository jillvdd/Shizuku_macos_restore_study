# SCN 脚本格式(`SCN%03d.DAT`)

参考实现:akkera102 `decscn.py`(容器/LZ)、`script.c`(事件与文本解释器,sizuku_gba2 血统)、GBALVNS `EVTDef.s`、XLVNS `LvnsScript.c`。
全部已用真实 `SCN001.DAT` 等验证。

## 文件整体结构

```
0..1   u16 LE 事件段起始 = 值 × 0x10
2..3   u16 LE 消息段起始 = 值 × 0x10
[填充到事件段起始]
事件段: u32 LE 解压后大小 d1Size + LZSS(lzs3)数据
消息段: u32 LE 解压后大小 d2Size + LZSS(lzs3)数据
```

实测 SCN001:头 `01 00 06 00` → 事件段 @0x10、消息段 @0x60。**压缩变体 = 反逻辑 flag 的 lzs3(正向写入)**。

## 事件段(解压后)

```
0..1   u16 LE 末块号 last
2..    每个块一个 u16 LE 偏移(块 0..last),指向块起始
之后   各块事件字节流
```

块(block)是雫的跳转/存档粒度:引擎按 `(scnNo, blkNo)` 加载,`0x04` 跳转命令即指定 `SCN%03d.DAT Block %d`。SCN001 的 block1 是开场场景,block0 多为空 END,block2/3 常在 0xff。

## 事件 opcode(已确认)

| opcode | 长度 | 含义 | 证据 |
|---|---|---|---|
| 0x00 | 1 | 块结束(停 BGM,结束块) | script.c |
| 0x01 | 3 | 子命令:01/02/04 显示消息 c[2];03 动画等待 | script.c |
| 0x04 | 3 | 跳转:`SCN%03d.DAT block %02x`(c[1],c[2]) | script.c |
| 0x05 | 3+2N | 选择:提示消息 c[1],选项数 c[2],每项(消息号,跳转偏移) | script.c |
| 0x07 | 1 | "前一选择"标记点 | script.c/gbalvns |
| 0x0a | 2 | 加载背景 `MAX_S%02d` | script.c |
| 0x14 | 2 | 清屏 | script.c |
| 0x16 | 2 | 加载 H 场景背景 `HVS%02d`(GBALVNS 称 BgH) | script.c |
| 0x22 | 3 | 立绘 `MAX_C%02x` + 位置 c[2](a/b/c=左/右/中) | script.c |
| 0x24 | 3 | 立绘 2(中) | script.c |
| 0x28 | 1 | 选择前的标记数据(Mark2) | gbalvns |
| 0x38 | 2 | 画面更新/特效(带淡入淡出) | script.c |
| 0x3d | 4 | `if 系统旗标[c1] == c2` pc += c3 | script.c |
| 0x3e | 4 | `if 系统旗标[c1] != c2` pc += c3 | script.c |
| 0x47 | 3 | 设置系统旗标 `flag[c1] = c2` | script.c |
| 0x48 | 3 | 旗标累加 `flag[c1] += c2` | script.c |
| 0x54 | 2 | 显示消息 c[1](随后等待) | script.c + 实测 SCN001 |
| 0x6e | 2 | BGM 播放 c[1](循环) | script.c |
| 0x7c | 1 | 结局相关 | gbalvns |
| 0x7d | 2 | 结局 BGM + 动画 | script.c |
| 0x7e | 2 | 结局编号判定(flag 0x46/0 判定) | script.c(附结局表) |
| 0xff | 1 | 不可达/结束标记 | script.c |

实测 SCN001 事件流:`BGM#2 → BG#01 → … → MSG0..5 → IF flg[46]==1 +5 → MSG6 → JUMP SCN002 blk1`。

## 消息段(解压后)

```
0..1   u16 LE 末条号 last
2..    每条一个 u16 LE 偏移(消息 0..last)
之后   消息字节流
```

### 文本命令

文本以 **Leaf 字形码**存储(非 Shift-JIS):`c[0]&0x80` 为字形码,2 字节/字,码值 = `((c[0]&0x7f)<<8)|c[1]`,经 `sizfont.tbl` 映到 SJIS(逐字形映射)。控制字节(<0x80):

| 命令 | 长度 | 含义 |
|---|---|---|
| `$` | 1 | 消息结束 |
| `p` | 1 | 翻页等待 |
| `k` / `K` | 1 | 按键等待 |
| `r` | 1 | 换行 |
| `B` | 7 | 背景 `MAX_S%c%c` + 位置参数 |
| `C` | 4 | 换立绘 `MAX_C%c%c` |
| `D` | 4 | 立绘全替换 |
| `S` | 10 | 背景+立绘同屏 |
| `A` / `a` | 10 | 三立绘同屏 |
| `E` | 7 | 背景(2) |
| `V` | 7 | 视觉图 `VIS%c%c` |
| `H` | 7 | H 场景 `HVS%c%c` |
| `M` | 2+ | BGM 控制:`Mf` 淡出、`Mnxx` 下一曲、`M0x`-`M2x` 播放、`Ms` 停止 |
| `P` | 2+ | PCM 音效控制 |
| `Q` | 1 | 画面压暗 |
| `F` | 1 | 闪屏 |
| `X` | 2 | 显示偏移 |
| `s` | 2 | 显示速度 |

## 关键实证(必须向用户报告)

**剧情文本为日文。** 将 SCN001/100/125/173/174 的消息字形码经 `sizfont.tbl` 还原,全部得到通顺日文(如 SCN001 开场 "―――って ドナフセルの意味かしら…")。Leaf 字形码空间约 0..1500,不足以容纳全套中文;`KNJ_ALL.KNJ` 也是日文 24×24 字形(1852 个)。**汉化层位于 EXE 内部**(Sizuku_cn.exe 的 .data 段比原版大 ~336KB)。置信度:高(多文件抽样 + 结构自洽)。

## 未知/待确认

- 选择块(0x05)与块偏移表在真实数据中的精确落点、0x02/0x03/0x06/0x08/0x09/0x0b/0x5a/0x5c/0x60-0x66/0x6f/0x73 等低使用率 opcode 的确切参数长度与语义(script.c 中多为"未知/单字节"处理)。
- OPTSET.DAT(存档)格式:需在 Wine 下运行原版观测,或逆向 EXE。
