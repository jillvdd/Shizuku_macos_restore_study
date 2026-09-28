# 容器格式 — LEAFPACK 与 LAC

> 🌐 **Language / 多语言**: [🇨🇳 简体中文](containers.md) ｜ [🇺🇸 English](containers-en.md) ｜ [🇯🇵 日本語](containers-jp.md)


## LEAFPACK(`MAX_DATA.PAK` 等)

参考实现:XLVNS/mglvns `leafpack.c`(Go Watanabe,©1999-2000,BSD 系许可)。
本项目已验证:移植版 Python 解包器(`research/tools/unpack_leafpack.py`)成功解出真实 `MAX_DATA.PAK` 全部 403 个文件。

### 布局

```
offset  0:  "LEAFPACK" (8 B magic)
offset  8:  u16 LE 文件数 file_num
offset 10:  文件数据区(每个字节按滚动密钥做加法混淆)
末尾 24*n: 文件表(24 B/项),每字节同样混淆
```

文件数可判别游戏类型(与 leafpack.c 一致):

| file_num | 游戏 |
|---|---|
| 0x0193 (403) | 雫 for Windows |
| 0x01fb (511) | 痕 for Windows |
| 0x0248 / 0x03e1 | To Heart |
| 0x0072 (114) | さおりんといっしょ!! |

### 混淆密钥(11 字节)

加密:`stored = (plain + key[k]) & 0xff`,k 循环推进(表在条目间**不重置**,数据区从 0 开始)。
默认密钥(雫 2007 版实测,也是 pakwriter 常量):`71 48 6a 55 9f 13 58 f7 d1 7c 3e`,即 ASCII `qHjU…` —— 对应 `Sizuku.exe` 内字符串 `"LEAFPACKqHjU"`。
`guess_key()` 可从表自身恢复密钥(要求 ≥3 个文件),公式见 leafpack.c/解包器,故**任意 LEAFPACK 档案可破解**,不必硬编码密钥。

### 文件表条目(24 B)

```
0..7   文件名(≤8 字符,空格补齐;'.' 不存)
8..10  扩展名(3 字符)
11     0x00 终止符
12..15 u32 LE 数据区偏移
16..19 u32 LE 长度
20..23 u32 LE 下一文件偏移(未用)
```

文件名还原为 8.3 形式,如 `SCN000.DAT`。

### 数据区

- 普通文件:逐字节 `plain = (stored - key[i%11]) & 0xff`。
- 压缩文件(供 LZS 解压):8 字节头 `[u32 大端压缩大小][u32 大端原始大小]` + 压缩体;条目长度含 8 字节头(mglvns `put_compressed_file` 写法)。原版雫的 SCN/LFG 是否带此头见各格式笔记——SCN 是 16 字节头+独立 LZ 段,详见 scripts.md。

### LZS 解压(三个变体)

- `lzs`   :flag 位正逻辑,ring 0x1000,`m` 起始 0xfee。
- `lzs2`/`lzs3`:flag 位反逻辑(`~`),ring 0x1011。lzs3 输出从尾部向前写。
- 已验证:SCN 用 **lzs3(反逻辑、正向写入)**;LFG 位图用 `lzs`(lfview/lfg.c 调用 `leafpack_lzs`)。

## LAC(`bgmfile.PAK` / `soundds.PAK`)

实测结构(无现成文档,依据 hexdump + magic 对齐反推):

```
offset 0: "LAC\0"
offset 4: u32 LE 文件数
之后:     目录区,每条目约 42 B:
          +0  名称(8 B,Shift-JIS)
          +36 u32 LE 文件数据偏移
          +40 u32 LE 长度
之后:     文件数据
```

- `bgmfile.PAK`:25 个条目,内容为 **Ogg Vorbis**(44.1kHz 立体声,已用 strings 证实)。
- `soundds.PAK`:13 个条目,内容为 **RIFF/WAVE**(GoldWave 生成;WAVEfmt 可见)。
- 条目数(25/13)与文件实际个数吻合;bgmfile 有 2 个条目非 Ogg(命中 23/25),可能是列表/静音轨之类。

对 macOS 运行时而言,音频解包后直接交给 AVAudioEngine 播放即可,无编解码负担。
