# 雫 macOS 移植 — 续接 Prompt(RESUME PROMPT)

> 🌐 **Language / 多语言**: [🇨🇳 简体中文](RESUME_PROMPT.md) ｜ [🇺🇸 English](RESUME_PROMPT-en.md) ｜ [🇯🇵 日本語](RESUME_PROMPT-jp.md)


> 用法:在新 chat 里直接粘贴本文件全文(或说"读取 /Users/abc/Documents/shizuku_macos_experience/RESUME_PROMPT.md 并按它继续")。
> 本文件是"截止 2026-08-17 的全部状态快照",新会话应先读一遍本文件,再读下述研究文档,然后继续执行「下一步」。

---

## 0. 项目一句话

把用户合法持有的《雫～しずく～》(Leaf 1996 / 2007 再版·AUGUST汉化硬盘版)解析原版游戏数据,重实现为 macOS 26 原生 Leaf VN 运行时(不走 Wine,不需要 EXE)。完整项目简报见 `SHIZUKU_PORT_RESEARCH_REPORT.md` 及 `docs/research/*.md`。

## 1. 环境与路径(重要)

- 工作目录:`/Users/abc/Documents/shizuku_macos_experience/`
- 游戏目录:`/Users/abc/Documents/shizuku_macos_experience/《雫～しずく～1996》`(**目录名带一个尾随空格**,用通配符或从父目录 find 访问:`ls -d ./*1996*/`)。
- 游戏文件:MAX_DATA.PAK(5.76MB,LEAFPACK 容器)、bgmfile.PAK(47MB,LAC,Ogg)、soundds.PAK(700KB,LAC,WAV)、Sizuku.exe(原版 250KB)、**Sizuku_cn.exe(汉化版 1.2MB,含加密 overlay)**、manual.txt、用户须知.txt、OST 子目录。
- 本机:`Darwin 27.0.0`,无 brew,无 wine;**有 CrossOver 26.3.0**(`/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/wine`,可 `--version` 验证)。**用户暂不同意启动 CrossOver 弹窗**,优先走静态分析。

## 2. 已完成并验证(勿重做)

### 格式(全部用真实数据验证过)
- **LEAFPACK 容器**(MAX_DATA.PAK):magic `LEAFPACK` + u16 文件数(0x193=403,雫) + 逐字节 XOR 滚动 11 字节密钥 + 尾部 24B×N 目录。密钥默认 `71 48 6a 55 9f 13 58 f7 d1 7c 3e`(=ASCII `qHjU…`,对应 EXE 内字符串 `LEAFPACKqHjU`),且可经 `guess_key` 从表自身恢复。**解包成功 403/403**,脚本:`research/tools/unpack_leafpack.py`。
- **LAC 容器**(bgmfile/soundds.PAK):`LAC\0` + u32 数 + 42B 条目(名称8B SJIS、偏移+36、长度+40) + 数据。Ogg Vorbis 25 曲 / RIFF WAV 13 条。
- **LFG 图像**(LEAFCODE):8B magic + 24B 调色板(16色4bit)+ u16BE 几何(宽=(n+1)×8、高=n+1)+ direction + transparent + u32 size + LZS 位图(leafpack_lzs,正相 flag)。实测 640×400、size=128000。已解码出 PNG 预览(`research/preview/`)。参考 `docs/research/lfg.md`。
- **SCN 脚本**(SCN%03d.DAT,197 个):`[u16 事件段偏移×16][u16 消息段偏移×16] + 事件段(u32 大小+LZS3) + 消息段(u32 大小+LZS3)`。LZS3=反相 flag 变体。事件 opcode 与 sizuku_gba2/GBALVNS EVTDef 一致(0x00 End/0x04 Jump/0x05 Select/0x0a BG/0x16 HBG/0x22 Chr/0x3d-3e 条件/0x47-48 旗标/0x54 Msg/0x6e BGM/0x7c-7e 结局/0xff)。文本=**Leaf 字形码**(2字节高位置位),经 `sizfont.tbl` 映射 SJIS。参考 `docs/research/scripts.md`。
- **字体**:KNJ_ALL.KNJ = 24×24 1-bit 点阵 1852 字形(133344B 精确吻合,未压缩);sizfont.tbl 1851 条(码→SJIS 顺序表)。**已渲染字形,确认为日文字形**。

### 调研产物(全部在库)
- `research/thirdparty/mglvns/mglvns-1.0/`(BSD:leafpack.c / lfg.c / lf2.c / Lvns*.c / sizuku*.c / mgConvert/*)
- `research/thirdparty/lfview/lfview-1.1a/`(lfgdec.c / leafpak1.c / leafpak2.c)
- `research/thirdparty/leafpak/leafpak-1.1.1/`
- `research/thirdparty/akkera/`(76-79 四个真实 zip)+ `akkera/src/`(decscn.py / scndec.py / declfg.py / script.c/h / anime.c/h / sizuku.c/h / font2leaf.py / sjis2leaf.txt / sizfont.txt)
- `research/gbalvns/`(git clone,BSD-3;EVTDef.s / core/anime.c / core/res/bin_k12x10*.bmp / txt_sjis2leaf.txt)
- `research/pages/`(denpa 旧站页面抓取与转码)
- `research/extracted/`(403 个解包文件)
- 文档:`SHIZUKU_PORT_RESEARCH_REPORT.md`(16 节主报告)、`docs/research/`(original-files / containers / lfg / scripts / audio / history / sizuku-gba / gbalvns / unknown-opcodes,共 9 篇)

### 尚未完成的资料获取
- **XLVNS 独立源码包**(`xlvns1-1.6b.tar.gz` 及补丁):Wayback 有 CDX 记录(`https://web.archive.org/cdx/search/cdx?url=leafbsd.denpa.org*`),但 **2026-08-17 当天 Internet Archive 整体临时离线(503)**;待恢复后按正确时间戳下载:`20010604082356`(1.6b.tar.gz)、`20010603222408`(1.6a-1.6b.patch)、`20010604140056`(xlvns10.patch01)、`20010604170244`(xlvns20.patch01)、`20010605144813`(xlvns20.patch02)。mglvns 已覆盖 XLVNS 核心,不阻塞。

## 3. 当前关键争议点(最重要,继续时优先处理)

**用户的说法**:`Sizuku_cn.exe` 在 Windows 上运行**显示完整中文汉化版**。
**我方证据**(三个独立验证):SCN 消息经 sizfont.tbl 还原为**通顺日文**(抽查 SCN001/100/125/173/174);KNJ 字形渲染为**日文**字形;两个 EXE 的常规节区里**都没有明文中文**(GBK 扫描无果)。
**结论**:译文不在 PAK/KNJ/普通节区,而是**加密存放在 `Sizuku_cn.exe` 的 overlay(附加数据区)**——`Sizuku.exe` 无 overlay,`Sizuku_cn.exe` 节区结束于文件偏移 0x17000,其后 **overlay 1,123,231 字节(0x11239f),熵≈7.95 均匀高熵(非 zlib/LZMA/简单XOR/无任何明文签名)**。

**下一步唯一主线 = 解密该 overlay,取出中文字幕数据**(供 macOS 端显示)。子选项:
1. **静态逆向**(推荐,用户接受):反汇编 + 追踪解密例程 → 离线写出解密器。
2. 用户在自己的 Windows 机器上运行并截图(兼做项目参考截图),或提供补丁安装包 / 已解密数据。
3. 用户同意后,用 CrossOver 运行并 dump 内存中的解密数据(用户目前倾向不用弹窗方案)。

## 4. 静态逆向现状(接着这里干)

### 文件
- 反汇编全文:`research/cn_disasm.txt`(objdump -d 输出,20947 行,coff-i386)。
- PE 信息:ImageBase 0x400000,AddressOfEntryPoint 0x407b84,.text = 0x401000–0x410000(0xf000),节表: .text/.rdata/.data/.rsrc(4 节),overlay 从文件偏移 0x17000 起。

### 已确认的导入(关键,供追踪)
cn 版导入(槽地址=ImageBase+IAT RVA 0x10000):`CreateFileMappingW`@0x410250、`MapViewOfFile`@0x410254、`UnmapViewOfFile`@0x410268、`GetModuleFileNameA`@0x410214、`ReadFile`@0x410248、`SetFilePointer`@0x41024c、`CreateFileA`@0x410258、`CreateFileW`@0x410264、`VirtualAlloc`@0x4101fc、`WriteFile`@0x4101c8。
→ 补丁用 **CreateFileMappingW + MapViewOfFile 映射自身 exe** 来访问 overlay,或读文件。

### 反汇编里已定位的调用点(下一步从这里追)
- `0x407b84` = 入口点(标准 CRT 启动:SEH 注册 0x4103c8 / 0x40bd30)。
- `0x407b7c: call *0x4100c8`、`0x407baa: call *0x4100c0`、`0x407bf8: call *0x4100c4`、`0x4069a3/0x406d2d-0x406d8c: call *0x4100d0/d4/d8/dc`、`0x407025: call *0x4100cc`、`0x407c7f: call *0x412740`、`0x407ca5: call *0x4100f8`。
- 需要先把 **0x4100c0/0x4100c4/0x4100c8/0x4100cc/0x4100d0/0x4100d4/0x4100d8/0x4100dc/0x4100f8/0x412740 解析出函数名**。⚠️ 我之前直接读 IAT(RVA 0x10000)解析失败(可能 IAT 在磁盘上为零,需改用 **INT/Import Name Table**,即 import 描述符的 OriginalFirstThunk 指向的表;或用 `pefile`/`capstone`,`pip install pefile capstone` 即可)。注意:先前用 import 描述符解析出的 DLL 名是乱码 `MZ\x90`,说明解析有偏差,重做时以 INT 为准。

### 下一步(建议顺序)
1. 修好 IAT→函数名映射(用 INT),把上表槽地址的调用点标上函数名。
2. 顺着 `GetModuleFileNameA → CreateFileMappingW/MapViewOfFile(自身exe) → 定位 overlay(文件偏移 0x17000,可能以 SizeOfHeaders+Σraw 计算)→ 解密循环` 追。
3. 找到解密循环后,观察它的运算(加减/异或滚动密钥、密钥来源、输出长度),用 Python 复刻,离线把 overlay 解出 → 期望得到「中文字形码→GBK 表 / 中文字体 / 译文库(按 SCN+消息索引)」。
4. 解出后:验证与 SCN 日文原文的消息编号对应关系;把「译文显示」作为 macOS 端渲染管线的一部分设计。

### 已知雷区
- overlay 第一字节 0x28 0x59 0x3b…;无 8+ 连续零;4 字节切块无重复模式 → 不像带目录头。
- 不要假设解密后是 zlib/LZMA;极可能是「游戏自带的 LZS 变体(leafpack_lzs/lzs3)+ XOR/加减滚动密钥」,因为补丁作者大概率复用引擎解码器。密钥可能藏在 .rdata/.data 常量或解密例程的立即数中。

## 5. 结论已固化(写报告/内存用)

- 可行性:高。容器/图像/脚本/字体全部有开源参考且已实测。
- 分辨率 640×400;音频 Ogg/WAV/PCM 直放 AVAudioEngine;Metal 整数倍缩放。
- 汉化文本 = 待解密的 EXE overlay(见 §3/§4);SCN 原文为日文。
- 可复用代码与许可:见 `docs/research/history.md` / `gbalvns.md`(BSD 系)。

## 6. 需要用户提供/确认(下次对话开头问)

1. 是否继续静态解密 overlay(推荐),还是由用户在 Windows 上截图/提供补丁包。
2. 目标平台确认:Apple Silicon + macOS 26(默认)。
3. 是否现在启动 Phase 2(shizuku-cli:inspect/extract/disassemble;已具备全部条件)。

## 7. 长期路线(简报 Phase 0-8)

0 调研(基本完成)→ 1 格式识别(完成)→ 2 资源解析器(LFG/SCN/音频,可复用源码+已写解包器)→ 3 脚本解析器+反汇编器+IR → 4 最小 Runtime → 5 完整流程 → 6 全游戏测试(New Game→Ending)→ 7 macOS App → 8 打包。CLI 先行(shizuku-cli),再 .app。测试用真实资源样本;参考截图用 Windows/Wine 原版。未知 opcode 记录于 `docs/research/unknown-opcodes.md`,遇未知不猜、以原版为 oracle。
