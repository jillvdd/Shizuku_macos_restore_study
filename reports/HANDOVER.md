# Shizuku_Restored — 《雫～しずく～》macOS 原生移植 HANDOVER LOG

> **最后更新：2026-09-20（★★以 §21 为准：M4.4/M4.5 已落地；曲目与 OP 构成纠正——OP 曲是 MUS14 而非 MUS16（MUS16=ハッピーエンド）；§20.1/§20.3 部分事实已被证伪；Scn.swift 尚有一处未提交的解析修复待验证提交★★）**
> 本文件是项目的**唯一权威交接文档**（取代并吸收 RESUME_PROMPT.md 的状态快照）。
> 新会话开场：通读本文件 → 查阅 MILESTONES.md → **先读 §21（最新事实与纠正）**，再查 §20.3 操作指南 → 立即开工执行。
> **§21 = 2026-09-20 第二次会话深度核对与 M4.4/M4.5 落地记录（与 §20 冲突处以 §21 为准）；§20 总结原版深度对齐的核心发现；§19 总结 M1 初版与 DMG 打包；§18 是战略调整背景；§14-17 是中文逆向攻坚记录。**
> **★当前项目状态★**：
> 1. **里程碑 M1 进阶**：已产出 51MB 独立安装镜像 `build/Shizuku.dmg` 与 `build/Shizuku.app`（集成 `AppIcon.icns`、403 原版资产）。⚠ 该 DMG 早于 M4.4/M4.5 改动，待重新 `package.sh`。
> 2. **M4.4（双层）与 M4.5 已完成**：commit `6ff45f4`（LZS 截断修复 + 指令宽度校正 + Engine 分段推进）、`95173de`（弟切草全屏排版）。修正后的行内事件实测数：C 671 / B·E 335 / V 70 + H 50 / A 78 / BGM 类 752 / SFX 类 428 / D 208 / F 223 / Q 129 / X·s 216（旧「1567」为欠计数，见 §21.2）。21/21 测试全绿。
> 3. **上一会话遗留的解析修复已提交**（commit `7e5c0fd`：eventOps 补 13 个 skip 类 opcode + parseBlock 块边界截断，CLI 抽查 SCN181/174/82 有界解析正确，21/21 测试全绿）。**下一步按 §21.4 清单推进 M4.6（曲目已纠正为 MUS14）→ M4.7 → 重新打包 DMG**。



---

## 0.1 ★✗ 原"CN 汉化 = 纯字库内容替换"结论 —— 已于 2026-09-03 晚证伪

**过去某轮曾下此结论（现知是错的）**：CN 版把 `cn_KNJ_ALL.KNJ` 按「slot N = leaf 码 N」重建，使 `drawChar(font[leaf_code])` 直接吐中文；SCN 与 JP byte-identical；**不存在运行时翻译表**。

**本会话视觉实证推翻它**：
- 取 SCN001 msg[0] 叶码序列 `[565,3,116,151,101,177,178]`。
- 用 **JP 字库** 和 **CN 字库**、分别在 col-major 与 row-major 下 `font[leaf]` 渲染 → **全部是破碎乱码**（CN[565]=勃、JP[565]=裁、含 ▶ 符号），都不是 msg[0] 那句话的字。
- 旧结论所谓"同叶码各自产出各自语言连贯文本 / 渲染成窗外渗进来的柔"**是未经验证的幻觉**（与该"字体布局 row-major 突破"同期的一批伪阳性一致）。同理，CN 字库 slot 0/1 实际是 徐/除（非旧说的"何/时"，那是另一种误读）。
- **硬性原因**：叶码在全部 394 个 SCN 中达 0x7fff（~9008 个不同值），而字库仅 1852 槽。**数字上不存在 identity** ⇒ **必然存在"叶码→槽位"映射表**（详见 §10.4，本轮独立复现并确认）。

**真结论**：CN 引擎在**渲染层拦截叶码→查"叶码→槽位"表→取 CN 字形**。该表**只在画面真正渲染中文对话那一刻驻留堆内存**（主菜单/读档/动画态都拿不到，旧 dump 扫描 0 命中）⇒ 需**运行时 hook**（用户把游戏操作到显示中文剧情的画面再 dump）。工具已就绪：`research/tools/hook_cn_runtime.py`（`cn_cap` 抓全内存+字库，`cn_analyze` 离线解析）。

**教训**（与本会话 row-major 伪阳性同源）：布局/机制的"突破"必须用**真实数据渲染结果**验证，且要与已知文本对照；凡"渲染出中文"需附实际图片人工目检，不可只凭统计或单字。

## 0.2 本会话确认的真结论（可与 §0.1 证伪对照）

- **字形布局 = col-major 已验证**（真）：`glyph[col*24+row]`（3 列×24 字节，bit7=列顶）。逐字复现 `research/cn_dump/confirm/visual_cn_0_60.png`（徐除僊勝唱將小少床掌…）。JP/CN 字体 0-119 槽全部渲染出连贯汉字/假名。这条保留。
- **CN 字库 = 完整 CJK+假名 1852 字形**（真）：133344B，与 JP 同容器格式，内容全新（逐字节不同）。0-119 槽全为中国汉字，~560 槽起出现 あいうえお 等假名。
- **SCN 的 LZS 变体 = decodeInv（倒排旗标）**（真）：非倒排 LZS 解 SCN001 消息区得到全 0 垃圾；decodeInv 得干净结构（11 消息、偏移合理）。
- **MSG 面板 `*4` 索引 bug（已修）**：`SceneComposer.drawMessageBox`/`drawChoiceMenu` 填充循环写 `pixels[y*width+x]`，漏 `*4`（pixels 是 w*h*4 交错 RGBA）。已改 `(y*width+x)*4`。这就是"中文压在花哨背景上显得碎/没有消息盒白底"的可见病灶之一。

---

## 0. 项目一句话与决策史

把用户合法持有的《雫～しずく～》（Leaf 1996 / 2007 再版 · AUGUST 汉化硬盘版）**解析原版数据、重实现为 macOS 26 原生 VN 运行时**（Swift + Metal，不走 Wine、不运行 EXE）。用户**必须玩到汉化版**（不可只出日文版）。

| 日期 | 决策 |
|---|---|
| 2026-08-17 | Phase 0/1 完成：全部数据格式逆向并验证（见 §3） |
| 2026-08-18 | 旁支项目 `shizuku_macos_emuplay`（Wine 打包模拟器方案）：JP 版跑通，CN 版"新游戏"确定性崩溃，**用户最终放弃模拟器路线，决定专心原生移植** |
| 2026-08-31 | 本研究：彻底研究 emuplay 遗产、修正旧错误结论、确立移植方案（本文件 §4） |

---

## 1. 路径与环境（重要）

- 移植项目（本仓库）：`/Users/abc/Documents/shizuku_macos_experience/`
- 模拟器项目（已停，**只读参考，勿改动**）：`/Users/abc/Documents/shizuku_macos_emuplay/`
- 游戏目录（**目录名带尾随空格**，用 glob `*1996*/` 或 python os.listdir 访问）：
  `《雫～しずく～1996》 /`，内含 Sizuku.exe / Sizuku_cn.exe / MAX_DATA.PAK / bgmfile.PAK / soundds.PAK
- 干净游戏文件拷贝（ASCII 路径，分析用）：`/Users/abc/Documents/shizuku_macos_emuplay/build/game/`
- 可用的 Wine 11.15（x86_64, Rosetta）：`/Users/abc/Documents/shizuku_macos_emuplay/build/Shizuku.app/Contents/SharedSupport/wine/bin/wine`（`--version` 验证过），带 `winedbg`；CN/JP prefix 均在 `.../SharedSupport/prefix_{cn,jp}`
- 本机：Darwin 27，Apple Silicon，**无 brew、无 ffmpeg**；有 CrossOver 26.3（用户不希望弹窗方案）；有 Xcode 工具链（swiftc 可用）

---

## 2. 2026-08-31 对 emuplay 的研究结果（新事实与修正，务必先读）

### 2.1 重大修正：RESUME_PROMPT §4 的 IAT 槽地址全部错误

旧快照把 USER32 区段误当 KERNEL32。**已用 INT（OriginalFirstThunk）完整重解析，正确映射如下**（ImageBase 0x400000）：

| 函数 | 槽地址 |
|---|---|
| GetModuleFileNameA | 0x4100ac |
| VirtualAlloc / VirtualFree | 0x410094 / 0x410098 |
| HeapAlloc / HeapFree | 0x4100c8 / 0x4100cc |
| ReadFile / SetFilePointer | 0x4100e0 / 0x4100e4 |
| **CreateFileMappingW / MapViewOfFile** | **0x4100e8 / 0x4100ec** |
| CreateFileA / CreateFileW | 0x4100f0 / 0x4100fc |
| UnmapViewOfFile / CloseHandle | 0x410100 / 0x410104 |
| LoadLibraryA / GetProcAddress | 0x410048 / 0x4100b4 |
| MultiByteToWideChar / WideCharToMultiByte | 0x41005c / 0x4100b8 |
| GetACP / GetCPInfo / GetOEMCP | 0x410050 / 0x410054 / 0x41004c |

完整表可随时用解析脚本重建（INT 解析法，两分钟活）。

### 2.2 汉化 EXE 的真实结构（已实锤）

- **CN EXE 是自解包壳**：崩溃点 0x40de63 的指令 `mov 0x24(%ecx,%edx,8),%esi`（8B B4 D1 24 00 00 00）**磁盘上不存在**——真实代码运行时从 overlay 解出。emuplay HANDOVER 的判断正确；旧记忆"overlay=纯译文数据"不完整，**overlay = 打包的真代码 + 汉化资源（字体/码表/译文库）**。
- 导入只有 ADVAPI32/USER32/KERNEL32 三 DLL、全部 W API，**无 GDI32/DSOUND/WINMM/MSACM32**（JP 原版都用）→ 补丁重写了引擎核心，GDI/声音运行时经 `LoadLibraryA+GetProcAddress` 动态取。**这解释了 Wine 下的各种怪象**（自解包代码对 Wine API 行为敏感）。
- `.data` 虚拟大小 0x521d6（337KB）但磁盘仅 0x4000 初始化 → 解包产物写入该区。
- CN EXE 内**没有** "LEAFPACK"/默认密钥 `qHjU…` 字符串（JP 原版有，位于文件 0x308c4）→ 数据访问逻辑也在壳内。
- `.rdata` 只有 CRT 样板 + 导入名，**无任何明文游戏字符串**。
- 静态调用图被壳截断：一批 `pushl $thunk; calll 0x401000` 包装桩（如 MapViewOfFile@0x4045d7）**没有任何静态调用者**——经运行时构建的函数指针调用。还有大量防篡改常量比较（`cmpl $0x3bf61486, 0x412094` 等）与垃圾混淆。
- **密钥扩展例程已定位**：`0x404371`（两个调用点 0x40193d/0x402221，后者传全局缓冲 0x412030），对 15 字节种子做 %15 调度（首块写序 [i+2,i,i+3,i+1]，步进 +12，遇 0xc 终止）展开成 ≥44 字节密钥。种子疑似 `0x412030` 处硬编码 15 字节：`a3 1d 92 3b 90 ff 3e b9 28 83 88 6c a5 4c 91`。
- **但**：该 15B 种子做滚动 XOR / 减法、以及首版扩展密钥，对 overlay 全部失败（熵恒 8.0，无 LEAFPACK 签名）。熵对任何短密钥变换不变 → **overlay 是强变换（可能壳代码参与异或，或解密与解压交织），纯静态复刻成本高**。

### 2.3 决定性转机：Wine 下自解包是成功的

emuplay 实测（Wine 11.15，Rosetta x86_64）：CN 版**主菜单正常显示中文**、**读档可进游戏**、只有"开始新游戏"确定性崩 +0xDE63。
→ **壳在 Wine 里完成了 overlay 解密**。因此**运行时内存 dump 是获取汉化数据（码表/字库/译文库/解包后引擎代码）的可靠低成本路径**。原 CrossOver 顾虑不适用：Shizuku.app/wine 命令行运行无弹窗，且用户在 emuplay 项目中已大量运行过。

### 2.4 存档机制（对移植存档系统的输入）

- 游戏把 `SaveDir`（注册表 `Software\Leaf\<名> Origin`）指到游戏目录，写 `MAX_00.SAV` / `OPTSET.DAT` / `SCN000-002.DAT`；**Wine 下这些文件全部 0 字节**（实际状态很可能只在注册表/内存——未深究，不阻塞：移植版自建存档）。
- **存档内容格式有权威参考**：mglvns `sizuku_file.c`（`SizukuSave/SizukuLoad`）：`scn(1B)+blk(1B)+scn_offset(4B BE)+bg_type+bg_no+pal(0)+chr[3]+seen_flag[205]+flag_save[14]+music(1)` = 232 字节/栞，文件名 `sizuku%d.dat`。GBALVNS `siori.c` 结构一致（"SZ"头+公共旗标+9 栞）。**两个常量：SCN 数 205、旗标数 14**。
- 游戏目录里的 `SCN%03d.DAT` 0 字节文件 = 游戏"已读"标记写法（移植版用自建标记即可）。
- emuplay 的整 prefix 快照存读档方案已验证可用（脚本 `shizuku-snapshot.sh`），但其价值仅限模拟器；原生移植有自己的存档（上格式或 JSON）。

### 2.5 emuplay 项目可直接继承的工程经验

- SwiftUI launcher 源码 `build/srclang/Main.swift`（状态栏菜单/快照存读/全屏切换逻辑可参考）
- **坑**：launcher 重编译后必须 `codesign --force --deep --sign -`；swiftc 必须 `-target arm64-apple-macosx13.0`（默认 minos=28 会被 macOS 27 拒）；`FileHandle(forWritingAtPath:)` 需先 `createFile`；启动 wine 用 Windows 路径 + cd 到游戏目录 + `DYLD_FALLBACK_LIBRARY_PATH` 指向 bundle Frameworks
- 字体：CN 用 Songti.ttc/Hiragino Sans GB，JP 用 Hiragino Mincho/〔Kaku Gothic〕，装进 prefix Fonts + 注册表映射（模拟器方案用；原生方案用 CoreText，无需此步骤）

### 2.6 Phase A 内存 dump 实测发现（2026-08-31，最关键）

**已完成的内存 dump**：`research/cn_dump/merged_full.bin`（32MB，301 段合并）。dump 时 Wine 进程 PID 37938 已跑约 3.5 小时（截至 14:50），游戏在主菜单状态稳定。

**主要定位（全部已在 dump 中确认）：**

| 项 | 位置 | 大小 | 备注 |
|---|---|---|---|
| PE 映像基址 | 0x400000 | 0x80000 | 解包后的 .text+.rdata+.data 都在这 |
| 解包缓冲区 (.data) | 0x430000-0x47a000 | ~290KB | 含 CN 字符串与运行时表 |
| 原 KNJ kana zone (堆) | 0xec000c-0xecbfd4 | 49104B (682×72) | 与磁盘 kana 完全一致 |
| 原 KNJ kana zone 堆头 | 0xec0000 | 12B | |
| **CN 完整 KNJ 字体 (堆)** | **0xecc018-0xf14af8** | **133344B (1852×72)** | **已保存到 `research/extracted/cn_KNJ_ALL.KNJ`** |
| LEAFPACK 全目录 | 0x18072e8-0x18098a8 | 8880B (403×24) | HVS01..VIS27，403 个文件全 |
| Heap 主数据区 | 0x1000000-0x2000000 | ~32MB | 含堆分配、DirectDraw surface |

**2.6.1 CN KNJ 字体的关键发现**

- CN 字体是**全新一套 24×24 1bpp 位图**（MSB-first，与磁盘 KNJ 同格式），与磁盘 JP KNJ **逐字节完全不同**（1852/1852 都不匹配磁盘）。
- CN 字体 slot 0 = 'あ'（JP 磁盘 slot 0 = 全角空格），slot 1 = 'い' 等。CN 似乎**删除了全角空格槽位**，所有字形前移 1。
- 渲染验证：`research/cn_dump/cn_font_preview.txt` 包含前 32 字形的 ASCII 渲染，**明显包含中文汉字**（如 glyph 100 是 "纟" 偏旁汉字，glyph 200 是某个汉字等）。
- 含义：CN EXE 自带完整中文字库，**不需要"日文字形替换为中文字形"的映射**。这是 Phase A 的最大胜利。
- sizfont.tbl 的 1851 SJIS 码表是否被替换或沿用尚需进一步验证（见 §6 待办 #2）。

**2.6.2 LEAFPACK 目录**

每条目 24B = name[12] + u32_a + u32_b + u32_c，403 个文件完整：
```
HVS*: 35 (背景图)
KNJ: 1 (字体)
LEA: 1 (LEAF 标志)
MAX: 94 (立绘+CG)
NEX: 8
OP_: 29
SCN: 197 (脚本)
SZ_: 10
TIT: 2
VIS: 26
```
字段语义（基于已知磁盘文件大小推算）：
- `b` = 文件在磁盘上的大小
- `a` = 压缩数据起始偏移（在 MAX_DATA.PAK 内）
- `c` = 下一条目起始偏移

已保存为 `research/cn_dump/leafpack_directory_full.json`（44KB，每条 24B + 字段名）。

**2.6.3 CN 字符串定位**

游戏菜单/对话框 CN 字符串以 UTF-16LE 编码散布于 .data 段（0x430000-0x47a000）和堆中：

- **菜单区**（.data 0x445800-0x445af0）：含 `画面尺`, `全屏(&F)`, `环境设定(&C)`, `下一选项(&S)`, `版本(&V)`, `结束游戏(&Q)`, `播放音乐`, `播放音效`, `文字速度`, `快进未读`, `自动`, `鼠标选项` 等
- **对话框区**（.data 0x476c00-0x477500）：含 `是`, `否`, `即将退出游戏。确定吗？` 等
- **VERSION_INFO 资源**（.rsrc 0x445b50+）：`VS_VERSION_INFO`, `StringFileInfo`, `080404B0`, `VarFileInfo`, `Translation`
- **堆菜单文本**（0x22e000-0x22f800）：`结束游戏(Q)(S)`, `游戏`, `确定` 等运行时实例
- **MENU/DIALOG 资源名**（.rsrc 0x44526a+）：`MAX_MENU`, `MAX_DIALOG`, `REBOOT_DIALOG`, `MAX_CURSOR`, `MAX_ICON`

完整 UTF-16LE 字符串提取保存于 `research/cn_dump/cn_strings.txt`（60KB，含很多误识别——过滤方法见 §6.4）。

**2.6.4 关键未定项（仍需继续）**

- **SCN 脚本翻译机制**：MAX_DATA.PAK 内 SCN000-SCN196 的字节级内容与 JP 版**完全一致**（SCN001 byte-identical 已实锤，MD5 `fdbac95cc85e14a2576d0fb636240a85`），但 CN 显示中文。CN shell 必然在某处拦截了 SCN 文本渲染并替换为 CN 字符串。**最可能**：CN 维护一张 leaf_code → CN 文本 的完整对照表，运行时按 (scn_id, msg_id, leaf_code) 查表替换。**2026-09-01 修正**：该表只存在于渲染中文的瞬间（§9.4），静态 .data / 主菜单 / 动画态堆都没有。
- **未找到的 CN 文本库**：dump 中 0x1000000-0x1b70000 是堆，未发现结构化"leaf_code→CN 文本"表。可能：① 表被压缩/加密 ② 表在 overlay 区（0x400000-0x470000）但形式未知 ③ 表由"码表（leaf→glyph slot）+ 字符串池"组成，需要先找出码表。**2026-09-01 修正**：② 的 overlay 区 .data BSS 实测全 0，overlay 按需解密到堆（§9.3）。
- **CN sizfont 码表**：原 sizfont.tbl 1851 条 SJIS 码是否被替换为 CN GBK 码表？未确认。CN 字体可独立使用，码表可能是冗余查找表。
- **CN 字符 → 字体槽位映射**：sizfont 的 SJIS 0x8f95 ('助' U+52A9) 在 disk 中是 slot 682；CN 字体 slot 682 是某个汉字（不是 '助'）。如果 CN 重排了字体（删了空格），sizfont 表可能完全失效。



---

## 3. 已确认格式速查（全部经真实数据验证，细节见 docs/research/）

| 数据 | 格式要点 | 参考实现 |
|---|---|---|
| LEAFPACK (MAX_DATA.PAK, 403 文件) | magic+u16数+XOR 11B 滚动密钥(`71 48 6a 55 9f 13 58 f7 d1 7c 3e`)+尾 24B×N 目录 | mglvns leafpack.c；自写 `research/tools/unpack_leafpack.py`（403/403） |
| LAC (bgm/soundds.PAK) | `LAC\0`+u32数+42B 条目；Ogg 25 曲 + WAV 13 条 | 自写解析（audio.md） |
| LFG 图 | LEAFCODE 头+16色调色板+u16BE 几何(640×400)+LZS 位图 | lfg.c/lfgdec.c；已出 PNG（research/preview/） |
| SCN 脚本 (197 个) | 双段(事件/消息)各 u16 偏移表+LZS3；块=跳转/存档粒度；opcode 与 sizuku_gba2/GBALVNS 一致 | decscn.py/script.c（scripts.md 含 opcode 全表） |
| 文本编码 | Leaf 字形码 2B（高位标志），经 sizfont.tbl(1851)→SJIS | script.c + sjis2leaf.txt |
| 字体 | KNJ_ALL.KNJ=24×24 点阵 1852 字形=133344B | 直接位图 |
| 存档 | 232B/栞：见 §2.4 | mglvns sizuku_file.c / GBALVNS siori.c |

已解包资源：`research/extracted/`（403 文件）。未知 opcode 清单：`docs/research/unknown-opcodes.md`。

---

## 4. 移植方案（本次核心产出）

### 4.0 总体判断

**可行性：高。** 引擎复杂度低（640×400、16 色图、文本 VN），格式与 opcode 有三套开源参考交叉验证。唯一硬缺口 = **汉化数据**（在 CN EXE overlay 内，未解）。方案按"先拿到译文数据、再建运行时"排序。

### 4.1 Phase A：取得汉化数据（当前主线，唯一阻塞项）

**A1（首选）：Wine 运行时内存 dump**（新确立，成本最低、成功率最高）
1. 用 emuplay 现成 Wine 11.15 + prefix_cn 启动 `Sizuku_cn.exe`（先和用户确认跑一次游戏窗口 OK）
2. 主菜单出现后（此时壳已完成解密、中文资源已就位），attach：
   - 方式① `winedbg --pid`（内置，`WINEDEBUG` 打开 + `winedbg info proc`/`x/` 读内存）
   - 方式② macOS `lldb -p <wine子进程pid>` 直接 dump 进程内存段（最通用）
   - 方式③ 写 wine 内存搜索脚本：在 dump 里扫 GBK 双字节中文模式 / 已知中文菜单串（如"開始"/"开始"、"読込"/"读取"）
3. dump 范围：至少 0x400000–0x480000（映像区，解包后代码+数据都在这）；存 `research/cn_dump/`（不进 git）
4. 分析 dump：对照磁盘版找差异段（=解包产物）→ 识别中文字库位图、字形码→GBK/中文码表、译文索引结构
5. 与 SCN 日文消息编号对齐（SCN 消息有索引号，译文按 (scn, msg_no) 映射的可能性最大）

**A2（备选）：继续静态逆向 overlay**。已有进展：IAT 修正、密钥扩展例程 0x404371 + 种子 0x412030。难点：调用图被运行时指针截断、混淆常量多、可能解密+解压交织。仅当 A1 受阻时投入。**2026-09-01 修正**：旧结论的 0x4120d0/0x41d24c/0x402425 是静态代码非密钥表（§9.3）；overlay 按需解密到堆（§9.4），静态逆向难度更高。

**A3（兜底）**：用户在 Windows 实机运行 CN 版提供截图/或汉化组原始资源。仅作参考校验，不作主路径。

**验收标准**：得到①中文文本库（可与 SCN 消息号对齐）②字形码映射表 ③（若用位图渲染）中文字库位图。**当前进度（2026-09-01）：** ③ ✅ 已完成（`cn_KNJ_ALL.KNJ`），② 部分（CN 字体可独立用但码表待确认），① 未完成（CN 文本池未定位，详 §6.1/§9.4/§9.5）。

### 4.2 Phase B：shizuku-cli（资源层，无阻塞可立即开工）

Swift package（或 Python 先行）：
- `inspect`：PAK 目录树、LAC 曲目表、SCN 头信息
- `extract`：LEAFPACK/LAC 全量解包（复用已验证 Python 逻辑移植 Swift）
- `disassemble`：197 个 SCN → 事件/消息反汇编文本 + 未知 opcode 统计
- `image`：LFG → PNG（校验渲染正确性）
- `font`：KNJ_ALL.KNJ → 字形图集；sizfont.tbl 转换
- `text`：SCN 消息 → 日文原文导出；（Phase A 完成后）与中文译文合并 → 移植版文本库

### 4.3 Phase C：最小运行时（文本能跑起来）

按报告 §14 架构（Swift）：
- **ShizukuCore**：容器/LZS/LZS3 解压、SCN 解析、IR
- **ShizukuEngine**：事件解释器（opcode 表按 script.c/LvnsScript 全量建模）+ 消息状态机（翻页/按键/速度/历史）
- **ShizukuImage**：LFG→RGBA8 → Metal 纹理（16 色调色板展开），640×400 nearest 整数倍缩放
- **渲染**：Metal 窗口 + 调色板纹理上传；文本先 **CoreText**（正确性优先），位图点阵模式作可选项（还原 1996 质感）
- **音频**：AVAudioEngine。⚠️ **修正报告 §13 的一个盲点：macOS AVFoundation 不支持 Ogg Vorbis 解码** → 静态链接 libogg+libvorbis（BSD 许可，Xiph 源码需联网下载一次）解成 PCM 喂给 AVAudioEngine；WAV/PCM 原生直放
- **存档**：自建（JSON 或 232B 二进制，格式按 §2.4），与原版互不兼容（可接受，用户已确认）；已读旗标 SCN205×1B+旗标14B

### 4.4 Phase D：完整引擎

立绘合成（位置 a/b/c、双立绘、三立绘）、特效（0x38 淡入淡出、Q/F 效果）、选择肢（0x05）、条件/旗标（0x3d/3e/47/48）、结局判定（0x7c-7e）、BGM/SE 全接、回想/既读/自动模式（参考 mglvns sizuku_menu.c / LvnsHistory.c 行为）。
未知 opcode：**以 Wine 跑 JP 原版为 oracle**（现已可行）逐个确认，不猜。

### 4.5 Phase E：macOS App 打磨

SwiftUI + Metal：标题画面（用 LFG LEAF.LFG/MAX_* 素材）、版本选择（汉化/日文双语 UI 备选——取决于 Phase A 产出覆盖度）、10 槽存档管理（继承 emuplay 的槽位 UI 设计）、全屏、图标、codesign（注意 §2.5 坑）。

### 4.6 里程碑与顺序

```
M0  Phase A 译文数据到手          ← 唯一硬阻塞，最先做
M1  shizuku-cli 全量资源导出      ← 可与 M0 并行（无依赖）
M2  最小运行时：BG+立绘+日文文本+按键推进
M3  换上中文文本库，打通"新游戏→第一章文本"
M4  完整引擎（选择/旗标/结局/回想）+ 音频
M5  App 化 + 存档/菜单/全屏打磨 → 可通全流程
```

### 4.7 风险表（更新版）

| 风险 | 等级 | 缓解 |
|---|---|---|
| **CN 翻译字符串池定位困难** | **中** | dump 中已确认 SCN 文件字节级与 JP 相同；CN 必然在运行时拦截翻译。需查找 0x1000000-0x1b70000 heap 中的密集 UTF-16LE 区，或重新 dump 一次游戏进入存档后状态用 framebuffer 反推 |
| **Wine 跑游戏需要用户在场点菜单** | 低 | 当前 dump 已成功（PID 37938 跑 ~3.5h 仍稳定）；但用户提醒过会崩，操作尽量原子化 |
| **重新 dump 时 Wine 崩溃** | 中 | 单条 lldb 脚本 + 一次性 batch 输出；不进入交互模式 |
| overlay 内存 dump 拿到的译文结构复杂、对齐困难 | 中 | 同 §4.7 第一行 |
| Ogg 无系统解码 | 低 | libvorbis 静态链（需一次联网下载源码） |
| 未知 opcode 行为 | 中 | JP 原版 Wine oracle 实测 |
| CoreText 渲染与原版点阵观感差异 | 低 | 位图模式可选项（CN KNJ 已就绪可直接用） |
| emuplay 目录被误改 | 低 | 已声明只读；git 无大二进制 |

---

## 5. 本次会话已产出/改动

- **2026-09-01（Phase B）**：构建 `shizuku_cli` 资源解析工具（Python 包，六个子命令）：
  - `inspect`：LEAFPACK 存档目录树（403 文件按类型分组）
  - `extract`：全量解包 LEAFPACK（含 LZS 解压）
  - `disassemble` / `text`：SCN 脚本反汇编 + 消息文本提取（leaf 码 → sizfont → SJIS 日文，已验证 SCN001 输出 12 条日文消息）
  - `image`：LFG → PNG（已出 HVS01 测试图）
  - `font`：KNJ 字形渲染（ASCII/HTML/SVG，已渲染 CN slot 0 = 何、slot 1 = 时）
  - 文件：`shizuku_cli/`（`__main__.py` + `leafpack.py`/`lfg.py`/`scn.py`/`knj.py` + 6 个 `cmd_*.py`）
- **2026-08-31 会话产出（保留）**：
  - 重解析两 EXE 完整导入表（INT 法），修正 IAT 映射（§2.1）
  - 实锤 CN EXE 自解包结构：崩溃指令磁盘不存在、无 LEAFPACK 字符串、.data 解包区、包装桩无静态调用者
  - 定位密钥扩展例程 0x404371 + 疑似种子 0x412030（15B）；验证滚动 XOR/减法失败（熵恒 8.0）
  - 确认存档格式参考（mglvns sizuku_file.c 232B 格式、SCN=205/旗标=14）
  - 读毕 SHIZUKU_PORT_RESEARCH_REPORT.md 全文（§13 音频 Ogg 盲点已在 §4.3 修正）
  - **Phase A 实测（2026-08-31 本日）**：
    - 提取 Wine 进程 dump 至 `research/cn_dump/merged_full.bin`（32MB）
    - 定位 CN KNJ 字体在 0xecc018-0xf14af8，保存为 `research/extracted/cn_KNJ_ALL.KNJ`（133344B，1852 字形，24×24 1bpp MSB-first）
    - 解析 LEAFPACK 全目录（403 文件，24B/项）至 `research/cn_dump/leafpack_directory_full.json`
    - 提取 CN UTF-16LE 字符串清单至 `research/cn_dump/cn_strings.txt`、`cn_rsrc_strings.txt`、`cn_menu_strings.txt`
    - 渲染 CN 字体前 32 字形至 `research/cn_dump/cn_font_preview.txt`（视觉确认含汉字）
- 本 HANDOVER.md（新权威交接文档）

## 6. 下次会话行动清单（按序，Phase A 收尾 + Phase B/C 启动）

### 6.1 Phase A 收尾（仍阻塞翻译完整性）

> **2026-09-01 更新**：清单 1 已尝试（本轮成功进读档态并 dump，见 §9），但翻译池仍未捕获。当前结论：**翻译池只在游戏画面真正显示中文对话时驻留堆内存**；主菜单/读档动画态都拿不到。以下为更新后的行动清单。

1. **重新 dump「画面正在显示中文对话」的状态**（不是读档成功就算数；必须**停在剧情文本画面**）：
   - 进游戏后，把对话推到**正在显示剧情文字**的画面，立刻 dump 堆（0x1000000-0x2400000）与 .data 区。
   - 重点搜：GBK 明文自然句 + 叶码→GBK 映射结构（`00 80 <gbk><gbk>...` 或 u16 数组）。
   - 前置条件已就绪：197 个 SCN 已注入游戏目录（§9.1），读档可正常进入。
   - **注意**：用户提醒过 Wine CN 版会随时崩溃，dump 操作尽量快（lldb 单条命令 + 重定向到文件）。
   - **若仍搜不到**：翻译池可能是 overlay 每小块解密用完即丢 → 改用 hook 方案（§2.3 / §9.5），在渲染函数下断点抓解密后缓冲区。

2. **找 CN sizfont 码表**：
   - CN 字体可独立使用，但游戏运行仍可能沿用 sizfont 1851 条 SJIS 表来查字
   - 候选位置：0x1800000+ heap 区域（与字体相邻）；CN .data 段（0x430000-0x47a000）
   - 启发式：找 1851 个 u16 连续值（3702B）且都在 [0,1852) 范围内
   - 或：先验证 sizfont 是否完全失效（用一个已知 SCN 文本找 leaf 码，对照原 sizfont 解出 JP 字符，看是否对得上 SCN 原文）

3. **找 CN 翻译字符串池**（最大悬而未决；本轮未突破，见 §9.4/§9.5）：
   - 已确认：CN 不修改 SCN（SCN001 byte-identical）、静态 .data 无翻译池、主菜单/动画态堆无翻译池、0x4313c0/0x445800 是编译进 EXE 的静态 UI 文本。
   - 剩余假设：CN 引擎渲染层拦截叶码 → 查表（大概率在 overlay 按需解密区）。
   - 查表方法：在游戏显示中文对话的瞬间 dump，找数千条密集 GBK/UTF-16LE 字符串区。

4. **过滤 cn_strings.txt 误识别**：现在 60KB 文件有大量字形位图误识别。改进提取器只接受以 null 终止、在合法字符串表附近的 UTF-16LE 序列。

### 6.2 短期可立即开工（不阻塞 Phase A）

- **shizuku-cli（Phase B）✅ 已完成（2026-09-01）**：`shizuku_cli/` 已构建并验证
  - `inspect`：`python3 shizuku_cli/__main__.py inspect <PAK> [--by-type]`
  - `extract`：`... extract <PAK> <dir> [--type SCN] [--lzs]`
  - `disassemble`：`... disassemble <SCN*.DAT> [--msg-only] [--sizfont <path>]`
  - `image`：`... image <LFG> [out.png] [--preview]`
  - `font`：`... font <KNJ> [--slot N] [--range 0-50] [--html/--svg/--count]`
  - `text`：`... text <SCN*.DAT> [--msg-only]`
  - 注意：运行时需从项目根目录执行（模块相对路径依赖）

- **shizuku-engine 最小骨架（Phase C 起步）**：
  - Swift 包结构、`Metal` 窗口、调色板纹理上传、LFG 解码
  - 暂时不接文本，先用 SCN 的 JP 文本（用原 sizfont）+ 磁盘 KNJ 显示"日文原版"
  - 收到 Phase A 完整数据后切到 CN 字体 + CN 文本

### 6.3 关键文件路径速查

- `research/cn_dump/merged_full.bin` — Wine 进程 32MB 完整 dump
- `research/cn_dump/leafpack_directory_full.json` — PAK 403 文件目录
- `research/cn_dump/cn_strings.txt` — UTF-16LE CN 字符串粗提取
- `research/cn_dump/cn_rsrc_strings.txt` — .rsrc 区字符串
- `research/cn_dump/cn_menu_strings.txt` — 已知菜单项及位置
- `research/cn_dump/cn_font_preview.txt` — CN 字体前 32 字形 ASCII 渲染
- `research/extracted/cn_KNJ_ALL.KNJ` — **关键！CN 完整字库（1852 字形）**
- `research/extracted/KNJ_ALL.KNJ` — JP 磁盘原版字库（133344B）
- `research/extracted/` — 403 个解包资源文件

### 6.4 dump 重做时的 lldb 命令（紧急用）

```bash
# 查 PID
ps aux | grep Sizuku_cn | grep -v grep

# attach + 一次性 dump 0x400000-0x2000000（按 region 写入）
cat > /tmp/dump2.py << 'PY'
import lldb, os
OUT='/Users/abc/Documents/shizuku_macos_experience/research/cn_dump'
def dumpall(dbg, cmd, res, d):
    p = dbg.GetSelectedTarget().GetProcess()
    e = lldb.SBError()
    for r_start, r_end, tag in [(0x400000, 0x480000, 'image'),
                                 (0x1000000, 0x1800000, 'heap_lo'),
                                 (0x1800000, 0x2000000, 'heap_hi')]:
        addr = r_start
        while addr < r_end:
            ri = lldb.SBMemoryRegionInfo()
            p.GetMemoryRegionInfo(addr, ri)
            base, end = ri.GetRegionBase(), ri.GetRegionEnd()
            if end <= base: break
            data = p.ReadMemory(base, end-base, e)
            if e.Success() and data:
                fn = '%s/mem2_%s_%08x_%08x.bin' % (OUT, tag, base, end)
                with open(fn, 'wb') as f: f.write(data)
                print('DUMPED', hex(base), hex(end), '->', fn.split('/')[-1])
            addr = end
dbg.HandleCommand('command script add -f dumpall.dumpall dumpall')
PY
lldb -p <PID> -o "command script import /tmp/dump2.py" -o "dumpall" -o "quit" -b
```

**重要**：Wine 进程随时会崩（用户已多次确认）。dump 操作尽量在单一原子命令内完成（见上方脚本），避免进入 lldb 交互。

## 7. 长期路线（Phase 0-8 不变）

0 调研 ✅ → 1 格式识别 ✅ → 1.5 汉化数据获取（进行中，§4.1）→ 2 资源解析器 → 3 脚本解析+IR → 4 最小 Runtime → 5 完整流程 → 6 全游戏测试（New Game→Ending，以 Wine JP 为 oracle）→ 7 macOS App → 8 打包。

---

## 8. 2026-08-31 深挖 CN 字体与码表（后续会话，重要新发现）

> 本小节记录在 §2.6 之后继续深挖 CN 字体布局、字形槽位、GBK 码表过程中的**所有尝试、猜测、失败路径与已确认事实**。按用户要求：不能 100% 确定的内容**客观描述观察到的行为**，不武断下结论。最后更新时间：2026-08-31（当日多轮会话）。

### 8.1 突破：CN 字体真实布局 = 3-column 8×24（非 24×24 row-major）

**尝试与失败路径**（按时间顺序）：

1. **最初假设**：KNJ 字体是 24×24 row-major 1bpp，每字形 72B = 24 行 × 3 字节。用此假设渲染 JP 磁盘字体 `research/extracted/KNJ_ALL.KNJ` 与 CN 字体，**结果全是乱码**（字形不可辨认）。
2. 尝试 column-major、plane-major（先全部 24 行的第 1 字节，再第 2 字节…）、LSB-first、tiled 3×3 分块等 6 种以上布局假设，**全部失败**（渲染仍乱码）。
3. **视觉确认**（用户参与）：CN 字体按 24×24 row-major 渲染的 4 个格子像乱码，不像正常汉字/假名；slot 1177 三条横线不像「三」；slot 0/1 不像「あ」「い」。确认 row-major 假设错误。
4. **决定性突破**：测试 **3-column 8×24 布局**——每字形 72B = 3 个 column block，每 block 24 行 × 1 字节（MSB-first）。**JP 与 CN 字库都验证成功**：
   - JP：slot 1 = い、slot 2 = あ、slot 51 = っ、slot 52 = が，与 sizfont.tbl 映射一致。
   - CN：slot 0-60 渲染出清晰汉字（何时将军这于西也刀力户心到电得独…）。
   - 字节布局细节：`字形[block*24 + row]`，bit 7 = 该行该 block 最左像素。
   - 渲染函数见本会话代码：`render_3col(font, slot)` / `slot_blocks(slot)`。

**重要**：此 3-column 布局同时适用于 JP 磁盘 KNJ 和 CN 内存 KNJ（两个 133344B 文件都是），说明**字体容器格式一致**，只是字形内容不同。

### 8.2 CN 字体槽位内容：与 JP 完全不同（已确认）

- CN 字库 `cn_KNJ_ALL.KNJ`（内存 0xecc018-0xf14af8，133344B = 1852 字形 × 72B）与 JP 磁盘字库 `KNJ_ALL.KNJ` **逐字节不同**（1852/1852 都不匹配）。
- **JP slot 0 = 全黑实心方块**（占位符/全角空格），slot 1 = い、slot 2 = あ（假名区）；**CN slot 0 = 何、slot 1 = 时、slot 2 = 将**（汉字，无假名）。
- **结论（已确认）**：CN 字库是全新的汉字点阵字库，槽位语义完全不同于 JP。CN 引擎用这套字库渲染汉字，不依赖 JP 假名槽位。
- **早先误判**（§2.6.1 记录）「CN slot 0 = あ」是**错误**——那是用 row-major 布局误渲染导致；实际 3-column 布局下 CN slot 0 = 何。

### 8.3 码表结构：0x489bbc / 0x489c22 / 0x48a860（已确认 + 部分待验证）

**内存中识别出三张相邻的 u16 表**（均在 CN EXE 解包后的内存镜像 `research/cn_dump/plot/image_merged.bin`，VA 基准 0x400000）：

| 表地址 | 结构 | 已验证内容 | 用途假设 |
|---|---|---|---|
| 0x489bbc | 51 个 0x3f00 占位符 + 20902 个 GBK 码（共 20953 项），连续到 0x493f6e | idx 51 = 0xd2bb（一），idx 52 = 0xb6a1（丁）… | **Unicode→GBK 查表**（idx = 51 + (Unicode−0x4E00)） |
| 0x489c22 | 0x489bbc + 51×2 处，同一张表的「有效起点」（去掉 51 占位符） | idx 0 = 0xd2bb（一），idx 3 = 0xc6df（七），idx 341 = 0xbace（何）… | 与 0x489bbc 是同一张表，只是起点表述不同 |
| 0x48a860 | 0x489c22 + 1567×2 处（0x541F 起），继续同一张表 | idx 0 = 0xd2f7（吟），idx 51 = 0xdfbc（呒）… | 同一张表的延续（U+541F = U+4E00+1567） |

**关键验证**：
- 0x489c22[341] = 0xbace = 「何」的 GBK 码 ✓（0x4F55 − 0x4E00 = 341）
- 0x489c22[352] = 0xc4e3 = 「你」的 GBK 码 ✓（U+4F60）
- 表长 45568 项（读到 0x4a0022 结束），覆盖 U+4E00 起全部 CJK 基本区 + 扩展
- 0x48a860 前面（0x489bbc 前）是大量 0x3f00 填充——**表起点前有对齐填充区**

**用途推测（未 100% 确认）**：CN 引擎渲染文本时，将 leaf 码 →（某机制）→ Unicode → 查 0x489bbc 得 GBK 码 → 再从 GBK 反查字形槽位。**GBK→槽位的映射表**（若有）尚未定位。

### 8.4 CN 字形槽位排列规律（已确认：槽位 51+ = Unicode 连续序）

**用渲染 + 码表交叉验证得出**：

- **CN 槽位 0-50 = 「高频字区」**：自定义排列，非 Unicode 序、非 GBK 序。已渲染确认的字（3-column 布局）：slot 0=何、1=时、2=将、3=军、4=这、5=于、6=西、7=也、8=刀、9=力、10=户、11=心、12=到、13=电、14=得、15=独、16=家、17=当、18=现、19=你、20=没、21=把、22=要、23=哦。GBK 码不递增、Unicode 不递增 → **无单调规律**。
- **CN 槽位 51+ = Unicode 连续序**：槽位 n (n≥51) 的字 = 0x489bbc[51 + (Unicode−0x4E00)] 中 Unicode = 0x541F + (n−51) 的字，即 **slot 51 = U+5452 呒、slot 52 = U+5453 呓、slot 53 = U+5454 呔、slot 54 = U+5455 呕、slot 55 = U+5456 呖、slot 56 = U+5457 呗、slot 57 = U+5458 员**…（全部经字形渲染确认，含 slot 100 = 咃 U+5483）。
- **验证方法**：slot 51-57 的 GBK 码 = 0x489bbc[51 + 1618 + (n−51)] = 0x48a860[n]（0x48a860 = 0x489bbc + 1618 项）。slot 100 渲染 = 咃（口+它）与 0x48a860[100] = 咃 完全一致。

**重要推论**：
- 0x48a860 表（或 0x489bbc 的 1618+ 段）= **「字形槽位→GBK」映射表**（槽位 51 起）。
- 槽位 51 前的 51 个高频字**没有在 0x489bbc 中对应项**（都是 0x3f00 占位符）。高频字的「槽位→字」映射**尚未找到独立表**（见 §8.7）。
- **`0x48a860[0]=吟` 与 slot 0=何 的「矛盾」已解释**：0x48a860 是槽位 51 起的表，slot 0-50 是高频区，不在该表范围内。slot 0=何 与 0x48a860 无对应关系（之前误以为 slot 0 应对应表首）。

### 8.5 尾部槽位（1845-1851）渲染观察（未最终确认）

- 渲染显示这些槽位是**完整汉字字形**（非空白/乱码）：如 slot 1848 左块+中块像「路」、slot 1851 像「到」（至+刂）——**但这些都是目测，未做像素级确认**。
- 用 0x489bbc 表预测：slot 1845-1851 应对应 U+5B54-U+5B5A（孔孕孖字存孙孚）。
- 用 Pillow 渲染这些候选字做点阵匹配，**分数全为负**（矢量渲染 vs 点阵无法可靠对齐，失败路径见 §8.6）——**无法程序化确认尾部槽位内容**。
- **当前状态**：尾部槽位内容未知，需要视觉确认或更好的匹配方法。

### 8.6 失败路径记录（重要：避免重复踩坑）

1. **24×24 row-major 布局**：全部乱码 → 错误（§8.1）。
2. **Pillow 矢量渲染 + 点阵匹配**：用 STHeiti 渲染候选字（各种阈值/缩放/形态学）与 CN 点阵做 IoU/加权分数匹配，**分数区分度极低**（正例负例分数重叠），**无法可靠识别字形**。原因：矢量细线 vs 点阵粗笔画，渲染管线无法对齐。→ 放弃程序化字形识别。
3. **GBK/EUC-JP/SJIS 直接解码 0x431400 区域**：均失败（那些字节不是标准编码，见 §8.8）。
4. **镜像内搜索「槽位→GBK」连续 u16 表**（搜 何时将军这于 的连续码）：**无命中**——槽位表不在 PE 镜像的静态区，可能运行时构建或在使用区。
5. **cn_strings.txt 频率统计**：产生乱码汉字（晦恠捣慡）——**之前误识别的位图数据**，不可用作文本来源。

### 8.7 未解决：高频字区（slot 0-50）的映射表

- 已确认 slot 0-50 的字（至少前 24 个），但**它们的「槽位→字」映射表未找到**。
- 假设：① 运行时构建（从 SCN 文本频率统计）；② 在 overlay 未解密区；③ 硬编码在 CN 引擎代码（非表结构）。
- 影响：若移植版要完全还原 CN 渲染，需要知道 leaf 码 → 槽位 0-50 的映射。但**若翻译池按文本直接给 GBK/Unicode**，可能绕过此表（见 §8.8）。

### 8.8 0x4313c0 区域 = 运行时当前对话缓冲（重大发现，部分确认）

**已确认内容**：
- 0x4313c0 起：`00 00 00 00` + GBK 文本 `bc b4 bd ab cd cb b3 f6 d3 ce cf b7 a1 a3 c8 b7 b6 a8 c2 f0 a3 bf` = **「我将立刻出现于这里。」**（中文完整句子，一次命中，dump 中无其他副本）。
- 0x4313c4：`即将退出游戏`（GBK）→ 0x4313d2：`确定吗` → 后面 `？` → **「即将退出游戏。确定吗？」** 是**退出对话框**的运行时文本（与菜单功能对应）。
- 0x4313e2 附近：`82 b7 82 a9 81 48` = SJIS「おい…」（日文残留）。
- 0x4313f0+：`MAX_DIALOG`、`VbufDIB`、`VmemDIB` 等 ASCII 资源名。
- 0x431400+：`73 30`（= ASCII 's'+'0'）开头、`72 24`（= 'r'+'$'）结尾的**叶码序列块**，每条 0x10 或 0x11 字节。叶码字节（如 8d 4e 91 a7 8c 2e…）用 0x489bbc 表解出生僻字（嬛彴姻埶媁），用 GBK/SJIS/EUC-JP 均无意义——**不是标准文本编码，是 CN 引擎专用叶码格式**。
- 0x431400+0x66 起：指针表（0x431400, 0x431410, 0x431420, 0x431430, 0x431440, 0x431458…）指向块内偏移。

**观察到的行为（未下定论）**：
- 该区域混合了「GBK 中文句子（UI 对话）+ SJIS 日文残留 + 叶码序列块 + ASCII 资源名」。
- 「我将立刻出现于这里。」**只有一处** → 像是**运行时正在处理的当前消息**（从翻译池查表后的结果），而非翻译池本身。
- 叶码块 `s0...r$` 结构疑似游戏文本渲染指令（速度 s + 参数 0x30/0x00 + 叶码 + 回车/结束），但**叶码→字形/文本 的映射未破**。

### 8.9 翻译池搜索（0x430000-0x2400000 全扫描，未找到翻译池）

**方法**：扫描 .data（0x430000-0x47a000）与 heap（0x1000000-0x2400000）中所有「GBK 双字节连续 3+ 字」的片段。

**结果**：
- .data 命中 47 处：仅 0x4313c4「即将退出游戏」/ 0x4313d2「确定吗」是真实中文 UI 文本；0x43135f「中文化委员会」（游戏标题）；0x474xxx-0x476xxx 是**GBK 部首/偏旁字典序列**（佩棋清儒…妁妃妍…纟纡纣…岌屺岍…）——这是码表，不是翻译文本；其余是二进制巧合。
- heap 命中 6012 处：**绝大多数是二进制巧合**（如 0x0100005c「鸡搔师乏甩苔拨」），无一处像自然中文句子。
- **结论（未完全排除）**：翻译池不在 .data 静态区、不在 heap 已扫描区，或**不以 GBK 明文存在**（可能压缩/加密/编码转换）。**当前 dump 的主菜单状态可能还没加载翻译池**（只有退出对话框等 UI 字符串被加载）。

### 8.10 悬而未决问题清单（下次会话优先）

1. **CN 翻译池仍未定位**（任务 #1 未完成）。当前 dump 是主菜单状态，翻译池可能需**进入游戏（读档/新游戏）后加载**才出现。→ 需要重新 dump 游戏内状态（§6.1 清单 1）。
2. **高频字区（slot 0-50）映射表未找到**（§8.7）。
3. **叶码格式未破**（0x431400 区域的 s0…r$ 块）——可能关联翻译池或文本渲染（§8.8）。
4. **尾部槽位内容未确认**（§8.5）。
5. **0x489bbc 表的用途**（Unicode→GBK vs 槽位表）的最终确认——当前证据支持「Unicode→GBK」+「槽位 51+ 直接对应表序」，但 CN 引擎运行时如何用它们渲染（查表顺序）仍需代码级验证。

### 8.11 本会话产生的文件

- `research/cn_dump/confirm/cn_slots_0_60_3col.txt` — CN 槽位 0-60 的 3-column ASCII 渲染
- `research/cn_dump/confirm/cn_all_slots_ascii.txt` — CN 全部 1852 槽位的完整 ASCII 渲染（每槽 3 块并排）
- `research/cn_dump/confirm/cn_all_slots_compact.txt` — 同上，紧凑版（每槽单行缩略）
- `research/cn_dump/plot/image_merged.bin` — 解包 PE 镜像（0x400000 起，720896B，含 0x489bbc/0x489c22/0x48a860 表）
- `HANDOVER.md.bak_20260831` — 本文件更新前备份

## 9. 2026-09-01 后续会话：读档崩溃修复 + overlay 机制修正（新事实，务必先读）

> 本次会话目标：把游戏跑进「读档后的对话状态」以便重新 dump 找翻译池。实际结果：
> **读档崩溃已修复并成功进入游戏**，但翻译池仍未捕获；同时修正了一批旧结论。**下次不要重复本次踩过的坑**。

### 9.1 读档崩溃根因与修复（重大，直接影响 emuplay 只读区的使用方式）

**现象**：新游戏正常、读档即崩溃（winedbg 弹出 program error 窗口）。之前误以为不可复现，实际每次读档必崩。

**根因（已实锤）**：游戏在**读档时**会按 `SCN%03d.DAT` 的编号缓存 SCN 文件内容（供对话渲染回退/定位用）。游戏目录里**只有 SCN001.DAT 一个 SCN 文件**，其余 196 个都被汉化版丢进 MAX_DATA.PAK 打包。读档指向 SCN102（或任意非 001 编号）时，缓存读取得到 0 字节 → 后续做 **NULL 解引用**崩溃。

**修复**：用 `python3 research/tools/unpack_leafpack.py "<game>/MAX_DATA.PAK" <游戏目录>/_scn_tmp` 解包全部 197 个 SCN 文件，按原文件名放入游戏目录。之后**读档可正常进入游戏**，中文菜单/界面可用。

- 教训：**只放 SCN001.DAT 不够，必须 197 个 SCN 齐**。若日后用本机 dump，这是把游戏跑进对话状态的前提。
- SCN001.DAT 解包版与游戏目录版 **byte-identical**（MD5 `fdbac95cc85e14a2576d0fb636240a85`）→ 印证：CN 版 SCN 内容与 JP 完全相同，**CN 不在 SCN 里做文本替换**（详见 §9.4）。

### 9.2 游戏内状态 dump（本轮新增，比 §8.9 的主菜单 dump 更进一步）

按 §9.1 修复后，成功进入读档后的游戏内状态，分三次 dump，每次 300 个区域、共 48MB：
- `research/cn_dump/ingame2/`、`research/cn_dump/ingame3_success/`、`research/cn_dump/ingame3_after_fight/`（每区域一个 `full_<VA>.bin`，共 3×300 个）

**扫描结果（依旧找不到翻译池）**：
- **0x18ba398 运行时对话缓冲**：ingame2 状态存的是 **JP SJIS 文本**（日文原文，如「それでは…」），ingame3_success 状态存的是**动画 float 数据**（每 4 字节一个 float）。→ 这个缓冲存的是**渲染层输入**，不是翻译输出；翻译发生在更底层。
- **0xb8ad84 区域**：稀疏的 u16 GBK codepoint 表（大量 `3f 00` 占位）= **字形映射表**，不是翻译池。
- **0x4313c0「即将退出游戏。确定吗？」**：在主菜单 / ingame2 / ingame3_success 三种状态**逐字节相同** → 是 CN EXE 编译进去的**静态 UI 文本**，非运行时缓冲。
- **0x445800 区域** = 静态 Win32 菜单资源（UTF-16LE）：`画面尺寸(&D)/全屏(&F)/窗口(&W)/环境设定(&C)/快进至下一选项(&S)/版本情报(&V)/结束游戏(&Q)/确定/取消/播放音乐/播放音效/已读文字自动略过/快进时跳过未读文字`，另残留 JP 文本（`雫」～しずく～`、`次に起動した時に...`）。→ 也是**编译进 EXE 的资源**，非翻译池。
- 全部 dump 中真正的中文明文只有两处：`中文化委员会`（0x43135f，标题）与 `即将退出游戏。确定吗？`（0x4313c4）。「你也应该听说了，太田同学…」**是推断的译文，从未在内存中提取到**（见 §9.6）。

### 9.3 overlay 机制修正（推翻了 §2.1 附近的旧结论）

- **旧结论（错误）**：overlay 密钥表在 VA 0x4120d0、字节替换表在 0x41d24c、解密函数 0x402425（见记忆文件 shizuku-overlay-analysis）。
- **实测**：这三个地址是**有效的 x86 代码**，且在所有 dump/状态下逐字节相同 → 是 PE 静态代码区，**不是运行时解密表**。
- **overlay 解密区（VA 0x16000-0x641d6，虚拟大小 0x521d6）在每次 dump 里全为 0** → overlay **不静态解密到 .data BSS**，而是**运行时按需解密到堆**（只有真正渲染中文那一刻才在堆里出现明文）。
- CN EXE PE 结构（已实锤）：`.text` VA 0x1000（file 0x1000/sz 0xf000）；`.rdata` VA 0x10000（sz 0x2000）；`.data` VA 0x12000（file 0x12000/sz 0x4000/**virtual 0x521d6**）；`.rsrc` VA 0x65000（file 0x16000/sz 0x1000）。overlay = 1.12MB 附加数据，位于文件偏移 0x17000。
- **结论**：翻译池（叶码→CN 文本映射）只存在于**游戏真正渲染中文对话的瞬间**的堆里。主菜单/读档后的动画状态下它不在内存中。

### 9.4 翻译架构最终确认：CN 引擎运行时拦截叶码渲染

- SCN 内是叶码（`0x80+glyph`），JP 引擎经 sizfont.tbl(1851 条目)→SJIS 渲染日文。
- CN 版 **SCN 内容不变**（§9.1 已证 byte-identical）→ CN 引擎在**渲染层**拦截叶码，查表替换为 CN 字形/文本。翻译池不在 SCN、不在静态 .data、不在主菜单/动画态堆。
- 补充佐证：原版 JP Sizuku.exe（250KB）在文件偏移 0x30054（VA 0x430054）就有 `LEAFCODE` 字符串、0x308c4（VA 0x4308c4）有 `LEAFPACK` 字符串 → 这些是 JP 原版静态 .data 字符串，不是 CN 新增的翻译结构。
- **LEAF.LFG（LEAFPACK 索引 36，5481B）**：头部为 `LEAFCODE` 魔数 + 16 色板 + LZS 位图 → 是 **LEAFCODE 图像文件**（类似 HVS 背景图），**不是**「叶→文本」映射表。JP/CN 目录里都有它，与翻译无关。

### 9.5 下一步（捕获翻译池的唯一路径）

翻译池只在**游戏画面真正显示中文对话**时驻留堆内存。本次 dump 都在动画/无文本状态（ingame3 全是战斗/演出），对话缓冲 0x18ba398 装的是 JP 原文，说明**引擎先渲染 JP 层、CN 替换发生在更底层**。

下一次尝试（需要用户在场操作游戏到对话画面）：
1. 读档进游戏，**停在剧情文本显示的画面**（不要停在标题/菜单/战斗动画）。
2. 立刻用 §6.4 的命令 dump 堆（尤其 0x1000000-0x2400000）与 .data 区。
3. 重点搜：GBK 明文自然句 + 叶码→GBK 的映射结构（结构特征：`00 80 <gbk> <gbk> ...` 或 u16 数组）。

> 若仍然搜不到：翻译池可能**不在堆里**，而是 overlay 每次解密一小块用完即丢 → 需改用 **hook 方案**（§2.3 CrossOver/Wine 断点，或用 §6.4 的 Wine 进程在渲染函数下断点抓解密后缓冲区）。

### 9.6 本轮已证伪/修正清单（避免重复踩坑）

| 旧结论 | 新事实 |
|---|---|
| overlay 密钥表 0x4120d0 / 替换表 0x41d24c / 解密 0x402425 | 静态 x86 代码，非解密表 |
| overlay 解密到 .data BSS | BSS 全 0；按需解密到堆 |
| 「你也应该听说了，太田同学…」是提取的译文 | 推断的，从未在内存提取到 |
| 读档崩溃「不可复现」 | 缺 SCN 文件导致 NULL 解引用，注入 197 个 SCN 后修复 |
| LEAF.LFG 是叶→文本映射表 | LEAFCODE 图像文件，与翻译无关 |
| 0x4313c0 是运行时对话缓冲 | 静态 UI 文本（各状态逐字节相同） |
| 0x18ba398 存中文对话 | 存 JP SJIS 原文或动画 float |

### 9.7 本轮产生的文件

- `research/cn_dump/ingame2/`、`research/cn_dump/ingame3_success/`、`research/cn_dump/ingame3_after_fight/` — 游戏内状态 dump（各 300 区域）
- `research/cn_dump/cn_data_memory.bin` — 0x430000 区域 86KB
- `research/cn_dump/cn_menu_strings.txt` — UTF-16LE 菜单字符串命中清单
- `research/cn_dump/cn_font_buffer.bin` — 运行时字形缓存（12B 头 + 1852×72B）
- `/tmp/leafpack_unpack/LEAF.LFG` — LEAFCODE 图像（从 MAX_DATA.PAK 解出）
- `research/cn_dump/leafpack_directory_full.json` — 403 文件目录（含 off/name）
- `research/cn_dump/cn_strings.txt` — 1347 条 UTF-16LE 字符串（**含大量误识别需过滤**）

---

## 10. 2026-09-03 后续会话：叶码空间 + 运行时 hook 方案（继续 Phase A）

### 10.1 Unicode→GBK 表字节序（修正 §8.3/§8.4 的读取方式）

关键修正：**该表以 LE u16（低字节在前）存储 GBK**。之前按文件顺序读会得到"灰/〈"等错字。

实测（`research/cn_dump/plot/image_merged.bin`，基址 0x400000）：
- `0x489c22[k] = U+4E00+k`：[0]=一、[1]=丁、[3]=七（U+4E00/01/03）✓
- `0x48a860[k] = U+541F+k`：[0]=吟、[1]=吠、[2]=吡（＝0x489c22 位于 U+4E00+1567 处的延续）✓
- **0x48a860 是 Unicode→GBK 表的延续，不是"字形槽位表"。**

### 10.2 slot→char 公式未定论（否决本会话早期的一个"修正"）

- HANDOVER §8.4 内部自相矛盾：一处写 `slot n = U+541F+(n−51)`，另一处写 `slot 51 = U+5452 呒`。
- 本会话曾据此误提"U+541F 修正 U+5452"——实为把 Unicode→GBK 表的**下标**错当成**槽位数**，**已作废**。
- **这些 VA 每次运行漂移**：同一 0x48a860 在 `ingame2/full_00470000.bin` 里读到的是序列计数器（32 00 33 00…），在 `plot/image_merged.bin` 里才是 Unicode 续表。→ **绝不要硬编码这些 VA**。
- slot→char 的正确性只能靠**用户视觉确认字形**（见 memory `[[shizuku-visual-confirmation]]`）。

### 10.3 叶码空间实测量（重大，说明 cmd_text 不完整）

对全部 394 个 SCN 文件提取叶码（`leaf=((c&0x7f)<<8)|b2`）：
- **~9008 个不同叶码，跨 0x0000–0x7fff 全范围**，高位字节 0x08–0x7f 几乎全覆盖（每页 50–100 个码）。
- `shizuku_cli/cmd_text.py::disassemble_text` **只覆盖叶码 0–1851**（sizfont 1851 项），其余输出 `<L%04x?>` → **对高叶码不完整**。

### 10.4 翻译池=叶码→槽位表，且静态不可得（收敛结论）

- JP 与 CN 的 KNJ 字库**同为 133344B / 1852 字形**（`/tmp/leafx/KNJ_ALL.KNJ` 与 `research/extracted/cn_KNJ_ALL.KNJ` 大小一致）→ 叶码**不可能**直接索引字形（叶码到 0x7fff 而字库仅 1852）→ **必然存在"叶码→槽位"映射表**（把 ~9008 个叶码压进 1852 槽位）。
- 用最严格的判别（**用到的叶码处为 1..1852 非零、未用叶码处为 0、连续 0x8000 项**）扫过全部旧 dump（ingame/plot/merged_full 等）→ **0 命中**。
- → 该表**只在画面真正渲染中文对话那一刻驻留堆**，静态/旧 dump 拿不到 → **必须运行时抓取**（用户已选定 hook 方案）。

### 10.5 本轮新增工具（可复用）

| 工具 | 用途 |
|---|---|
| `research/tools/hook_cn_runtime.py` | lldb 脚本：`cn_find` 探字库、`cn_cap` 在中文对话瞬间抓全内存+KNJ 字库、`cn_analyze` 离线分析 |
| `research/tools/analyze_cn_pool.py` | 离线：叶码→槽位表（严格结构）+ GBK/UTF16 串扫描 |
| `research/tools/find_leaf_table.py` | 叶码→槽位表扫描器；已用合成表验证能在 0x8000 处命中（pass≈0.9996） |

**抓取流程（需用户在场操作到对话画面）**：读档进游戏 → 停在**中文剧情文本显示**的画面 → `cn_cap` → `cn_analyze`。

### 10.6 本会话已证伪/修正清单（追加）

| 旧结论/疑似 | 新事实 |
|---|---|
| "slot n = U+541F+(n−51) 可纠 U+5452" | 把 Unicode→GBK 表下标当槽位数，**作废**；两者都可能错 |
| "0x48a860 是槽位表" | 是 Unicode→GBK 表在 U+541F 的延续 |
| (读取表值时) 按文件顺序解码 | **需按 LE u16（低字节在前）** 解码才是正确 GBK |
| (隐式) 叶码上限 1851 | 叶码达 0x7fff，~9008 个；cmd_text 不完整 |

---

## 11. 2026-09-03 晚（★进入 Phase C 运行时代码阶段的"第一个拦路虎"★）

> 本会话从"原生移植运行时代码"实际开工，第一件事就是把文本渲染跑通验证。**结果：col-major 布局确认正确，但叶码→字形 identity 假设被视觉实证推翻，文本正确渲染被"叶码→槽位映射表缺失"阻塞。**

### 11.1 运行时（Swift 移植）当前真实状态（代码已存在，非空壳）

`ShizukuRuntime/`（Swift Package）：
- **ShizukuCore**：Leafpack / Lfg / Lzs(decodeInv+leafpack_lzs) / Scn(事件+消息解析) / Knj(24×24 col-major 1bpp)。均已实现。
- **ShizukuEngine**：`Engine`（SCN 事件解释器，opcode 0x00/0x04/0x0a/0x05/0x16/0x14/0x22/0x24/0x28/0x38/0x3d/3e/0x47/0x48/0x54/0x6e/0x7c-7e 等，Phase 状态机 waitingMessage/waitingChoice/ended，`advanceMessage`/`selectChoice`/`currentPageLines`）+ `GameData`(197 SCN、CN 字库、懒解码 LFG)。**引擎能完整走完 SCN001 block1（step64、11 条消息、无崩溃）**——这是真实能力。
- **ShizukuRender**：`SceneComposer`(render)→RGBAImage→CGImage→AppKit 窗口；`TextRenderer`(col-major 字形上屏)。**已修 `*4` 面板 bug**。
- 可执行：`shizuku`(headless CLI，帧导出 PNG) + `ShizukuApp`(AppKit 窗口)。

**注意**：`shizuku` 需从**仓库根**以 `.` 运行（内部拼 `research/extracted`），不要传 `research/extracted` 二次拼接：`swift run --package-path ShizukuRuntime shizuku . -scn 1 -blk 1 -max 60 -scale 2`。

### 11.2 文本渲染：本轮最关键的"证伪"

- 已用**真实渲染**确认：SCN001 msg0 叶码 `[565,3,116,151,101,177,178]` 经 `font[leaf]`（col-major/row-major × JP/CN 字库，共 4 种组合）**全部渲染成破碎乱码**。JP[565]=裁、CN[565]=勃、还混有 ▶ 符号 → 都不是 msg0 的字。
- 叶码达 0x7fff（~9008 个），字库仅 1852 槽 ⇒ **必须有"叶码→槽位"映射表**。该表只在渲染中文瞬间驻留堆（§10.4）⇒ **需运行时 hook**。
- 已建 `research/cn_dump/confirm/` 对照物：`visual_cn_0_60.png`（col-major、槽位 0-60 连贯汉字）可作为"字库本身能渲染汉字"的基准，但**不能**当作"叶码能 identity 出中文"的证据。

### 11.3 本会话产出/改动

- 修正记忆：`memory/shizuku-leaf-identity.md`、`memory/verify-font-layout.md`、`MEMORY.md`（划掉"identity/纯字库替换"、去掉"渲染成窗外渗进来的柔"幻觉、保留 col-major 真结论）。
- 修 Swift 运行时真 bug：`ShizukuRender/SceneComposer.swift` 面板填充两次漏 `*4`（消息盒/选择菜单）。
- 验证：`Knj.pixels()` col-major 与 `decode_col_major` 逐字节一致；引擎走完 block1；app 帧与 CLI 帧 byte-identical。
- `HANDOVER.md` 头部 + §0.1/§0.2 重写为"identity 已证伪"。
- 临时调试环境变量保留：`SHIZUKU_DUMP_LEAF`/`SHIZUKU_DUMP_GLYPH`（main.swift，无害，可留可删）。

### 11.4 下一步（唯一能解锁文本渲染的动作）

1. 用 `research/tools/hook_cn_runtime.py` 在**游戏显示中文剧情画面**瞬间抓堆（`cn_cap`），离析"叶码→槽位"表（`cn_analyze` / `analyze_cn_pool.py` / `find_leaf_table.py`）。
2. 拿到表后：Swift `TextRenderer` 从 `font[leaf]` 改为 `font[leaf→slot]`；`Scn.Message.glyphLeafCodes` 过滤逻辑配合表接口。
3. 在此之前，`font[leaf]` 渲染的文本是乱码——**勿把它当文本显示**（可作占位或先隐藏，避免误导)。
4. Phase C/D/E 其余机械部分（引擎解释器、LFG/调色板渲染、消息盒、App 窗口、存读档、全屏）不依赖该表，可先行继续打磨。

---

## 12. 2026-09-03 深夜（★用户锚点已到手；D/E 机械件落地；下一步=指纹锁表★）

> 由续接会话（e7cdd8eb）补记，覆盖 §11 之后 19:17→21:30 的工作。全脚本不同叶码=**1937**（§0.1 的 ~9008 为解析伪影，见 memory）。

### 12.1 ★决定性资产：用户屏幕真值锚点（此前只存在于会话记录，现已固化）★
- 用户在 Wine 原版 Sizuku_cn.exe 读档1剧情画面亲自抄录并确认：
  - **屏幕中文**：「然后不知在某个不经意的瞬间，我察觉到这个无聊的世界已经失去了色彩和声音」（35 字含全角逗号）
  - **运行版本**：wine 原版 `Sizuku_cn.exe`（屏幕为真实汉化文本，锚点有效）
- 重复指纹（0 基）：不@(2,7) 个@(6,19) 的@(10,22) 经@(8,26)，其余字唯一。

### 12.2 运行时抓取已发生（资产在手）
- Wine 启动 CN 版正确姿势：`cd <prefix>/drive_c/Program Files/Shizuku && WINEPREFIX=<prefix> wine Sizuku_cn.exe`（必须 Windows 路径 + 正确 workdir）。
- `cn_cap`（lldb attach PID 47940）→ **309 区 / 57MB** → `research/cn_dump/live/20260903_201407/`（KNJ_mask.bin + manifest.txt）。
- 运行时字库两份（0xe8c018、0x17d5ec0），glyph≈683（偏移 0xc000）后与静态 cn_KNJ_ALL.KNJ 分叉。

### 12.3 静态逆向排除清单（勿重走）
- CN/JP 两个 EXE 完全不同二进制（capstone：CN 21478 insn vs JP 64800 insn），无法指令对齐。
- .data@0xb30 连续小值=常量区非映射表；exe 静态区+全部旧 dump 高多样性表扫描 **0 命中**。
- overlay（0x17000 起 1,123,231B）熵 7.95 无魔数不可直解；CN 字库明文不在其中。
- `[0x414b40]` = 引擎运行时文本缓冲（自引用初值），非表。
- **未做过的新实验（进行中）**：按"翻译槽序列重复指纹"在 57MB dump 直搜 u16∈[0,1852] 序列；指纹匹配 scn_leaf_map.json 锁锚点消息。

### 12.4 Phase C/D/E 代码增量（19:17 后，均已构建通过）
- `ShizukuCore/GlyphMap.swift`：可插拔叶→槽（默认 identity；`from(raw:)` 读 0x8000×u16）。
- `GameData`：`cnMap`+`loadGlyphMap`（自动找 cn_table.bin/leaf_table.bin/cn_map.bin）+`textSlot(forLeaf:)`；SceneComposer 改走 textSlot。
- `ShizukuApp/MetalGameView.swift`：MTKView+内联 MSL，替换旧 CGImage GameView（已删）。
- `package.sh` → `build/Shizuku.app`（release、ad-hoc 签名、gamedata 395 文件）。
- 引擎验证：SCN001 block1 全程走通（step 64）；SELECT 跳转 `pc+jumpOffset` 语义存疑（blk_off 0x0900 级别远超事件流），待 oracle。

### 12.5 下一步（进行中）
1. 指纹匹配 `research/cn_dump/scn_leaf_map.json` → 锁定锚点消息 (scn,msg) 与叶码序列。
2. 同指纹扫 57MB dump 的 u16∈[0,1852] 序列 → 翻译槽缓冲 → 直接得槽码。
3. 渲染 cn_font[slot] 视觉验证 = 用户原句 → 导出 cn_table.bin/全译文 → 重建 app 解锁中文。

---

## 13. 2026-09-04（★映射表概念已废 → 译文库=加密 overlay；主攻 stub 静态逆向★）

> 本节 = 凌晨会话 a0f0051c（9/3 20:15→9/4 07:55，死于连环 API 报错 502/模型 vision 400 + /compact 失败）的完整成果 + 9/4 上午验证。**本节与 §10-12 冲突时以本节为准。**

### 13.1 ★核心结论改写：不存在"叶码→槽位映射表"，翻译按 (scn,msg) 整条消息替换★

决定性证据（全部实锤）：
- **翻译是自由改写**：锚点句 SCN001 msg5 JP「やがていつの頃からか僕は、この退屈な世界から音と色彩が失われてしまっていることに気付く。」→ CN「然后不知在某个不经意的瞬间，我察觉到这个无聊的世界已经失去了色彩和声音。」——45 字 → 36 字、语序重排（音と色彩 → 色彩和声音）。逐叶替换数学上不可能。
- **同一叶码对应不同汉字**：叶码 7(か) 在 msg5 不同位置对应 不/意。
- **JP 叶码字节 0 命中**：显示 msg5 时抓的 57MB dump 里搜不到 msg5 的 JP 叶码字节序列（BE/LE、含/不含控制码段都试过）→ 引擎读 SCN 后立即转换。
- **译文缓冲编码盲扫全灭**（这是本会话工作量最大的部分，均已排除）：GBK/UTF-16LE/UTF-8 明文、u16 槽码连续游程(≥8 全<1852)、23 格重复签名(不@(2,7)/个@(6,19)/的@(10,22)/经@(8,26) 4约束×4编码)、stride 2-8→64 间隙锚子序列、u8 单字节签名。全部 0 命中（命中项均=ASCII 噪声/Wine 库多语种文本）。
- ⇒ **CN 引擎把 (scn,msg) 对应的整条译文现解现渲染、用完即弃。Swift 侧模型应为 "(scn,msg)→中文文本" 库（GlyphMap 的"叶→槽"接口作废）。**

### 13.2 9/4 上午验证（本会话，只读，已确认）

- **GDI 现画字形假设 ✗**：运行时引擎镜像 `/tmp/cn_live_image.bin`（0x400000 起 417792B）导入表完整解析：KERNEL32 94 / USER32 44 / GDI32 12（全为调色板+DIB blit：SetDIBitsToDevice/StretchDIBits/AnimatePalette/CreatePalette/…）/**无任何文字函数**（无 TextOut/GetGlyphOutline/CreateFont）→ 引擎自己从字库缓冲 blit 字形（与 JP 原版同路）。有 MultiByteToWideChar/WideCharToMultiByte（编码转换存在）。
- **[0x414b40] 文本解码上下文指针**：dump 时值 = 0x97503c4 → 指向 **dump 未覆盖的 ~2GB 空洞**（dump 只覆盖 0x2020000 以下与 0x7a850000+）。运行时引擎大量 `movzx word ptr [ecx+eax*2]` 索引它 → 它就是文本流上下文缓冲。

### 13.3 运行时字库 copy B 槽位结构（重大，已部分破译）

`/tmp/f2_font.bin`（=va 0x17d5ec0 的完整运行时字库 133344B；另一副本 0xe8c018≈静态）：
- **槽 0–681**：与静态 `cn_KNJ_ALL.KNJ` **逐字节恒定**（徐除僊勝…音序/繁体汉字+假名区）。此区槽号可直接用。
- **槽 682–1851**：**运行时按场景改写**（两副本分叉点≈683，槽内容为另一批清晰汉字 潔穴倦兼堅絹孤…）。
- **尾部 1230–1851 = Unicode CJK 码点序简体字**（一丁七万三上下不与丑专且世丘业东丝丢…土部…口部大段…终止于 夫=1851/U+592B，覆盖 0x4E07 起 ~620 码点，跳过缺字）。
- 精读锚点（验证条 ±0 确认）：**不=1237、世=1242、个=1251、中=1252、去=1569、在=1794**；静态区：**色=41、世=76、然=123、不=371**（注意"不"在两个区各有一槽——低槽区非简体序）。
- 含义：字库槽位序 =「静态首现/音序区(0-681) + 场景 rare 区(682-1229) + Unicode 码点序区(1230+)」。**运行时字库内容可按场景变** ⇒ 移植版渲染中文不能只用静态字库，需按译文文本动态选槽或自带完整字库。

### 13.4 已确认的新事实链（谁读什么）

1. 游戏实际读取**散装 SCN**（非 PAK 内）：CN≡JP byte-identical（MD5 已验两次）。
2. CN 版 MAX_DATA.PAK 的 PAK-SCN 解出与散装不同（key 滚动假设未破解），但**不阻塞**——散装才是真数据。
3. akkera `sizfont.txt` = 正确 leaf→SJIS 表（mglvns 那份不是 SJIS 映射）；sizfont 与字库 slot 差 1（1-based 工具表偏移）。
4. 静态区 0-681 非简体序（316=龍、320=白、341=囃、543=計、544=雲…）→ 静态字库≈日文汉字/繁体序 + 少量锚字。
5. 0x431138 256B 表 = LFG 图形位交织表（`00 01 10 11 02 03 12 13…`），**不是文本码表**——曾误当金矿，已排除。
6. PAK 提取的正确姿势已找回（per-file key），PAK 内只有素材（LFG/P16/KNJ/SCN），**无独立译文文件**。

### 13.5 死前未完成 + 本会话计划（行动清单）

**主线 A（零依赖，首选）——静态逆向 stub 解 overlay：**
1. 本地复查（不需游戏）：① 上次 1418 个重复签名命中按 **BE 叶码流**重判读（唯一没测过的编码——上次过滤器 `<1852` 会误杀 0x2580 级 BE 叶值；同字=同字节对约束对 BE 流同样成立）；② CN vs JP 游戏目录**文件级 diff**（上次刚起头被打断）。
2. **用 capstone 完整读懂磁盘 stub**（.text 仅 0xf000）的 overlay 读取+解密+解压链。已有线索：密钥扩展 0x404371（调用点 0x40193d/0x402221，全局缓冲 0x412030，15B 种子 `a3 1d 92 3b 90 ff 3e b9 28 83 88 6c a5 4c 91`，%15 调度 [i+2,i,i+3,i+1] 步进+12 遇 0xc 止）；LZSS 0x40131e（0xFEE 窗口，环形缓冲 0x442660）。防篡改常量与运行时函数指针桩会碍事，优先跟"文件读取→大缓冲→解密→解压→写入 0x400000+/heap"的数据流。
3. Python 复刻解密链 → 一次性解开整个 overlay → **代码+译文库全部到手，永久摆脱 Wine 依赖**。

**主线 B（仅当 A 卡住）——live 第二轮：**
- 重启 Wine CN 版 → capstone 在运行时 .text 定位"写 [0x414b40] 上下文缓冲的函数" → lldb 断点 → 每推进一条消息抓一次解码后中文流。或推进前后各 dump 一次做 heap diff（瞬态缓冲必现形）。注意：debugserver kill 曾带崩游戏；AppleScript 点击需辅助功能权限，Quartz 合成点击时窗口须 onscreen。

**Phase C 并行线（不阻塞）**：引擎 opcode 补全；SELECT 跳转 `pc+jumpOffset` 语义存疑待 JP oracle；存读档；文本渲染在译文库到手后改 "(scn,msg)→文本"。

### 13.6 本会话资产清单

| 资产 | 路径 | 说明 |
|---|---|---|
| live 全 dump | `research/cn_dump/live/20260903_201407/` | 309 区 57MB，msg5 显示时抓；KNJ_mask.bin+manifest.txt |
| 运行时字库 B | `/tmp/f2_font.bin` | 0x17d5ec0 完整 133KB；0-681=静态恒等，尾部 Unicode 序 |
| 运行时字库 A | （dump 内 0xe8c018） | ≈静态+少量改动 |
| 运行时引擎镜像 | `/tmp/cn_live_image.bin` | 0x400000 起 417792B，已解析导入表 |
| 字库联系表 | `/tmp/xfont_part{0-5}.png` | 静态字库全 1852 槽分 6 张 |
| 锚点 | msg5 (SCN001) | JP/CN 双句见 §13.1；槽锚点见 §13.3 |

> 教训补充：① 「发现矛盾立即用数据裁决」有效（PAK 提取两次失败都是 key bug，非数据不存在）；② lldb debugserver 清理会带崩 Wine 进程——先 dump 后 hook、hook 单独进程；③ 视觉读字形时上一轮的判读有 ±2 偏差（色=41 非 39/41 混淆），关键槽号必须用放大验证条 ±0 确认。

### 13.7 2026-09-04 下午会话增量（stub 逆向突破 + 动态尝试记录）

**stub 解密链已复刻（Unicorn 模拟验证）**：
- 0x401000 = 万能包装器（EH_prolog + 0x405733 unwind 机器）；298 个 push-ebp 函数中大量是"push $thunk; call 0x401000"的 IAT 包装桩。
- **0x402425 = 核心 8 字节块密码**：先建 256B 表 @0x41d24c：`sbox[i] = (0x22043e6f >> (i%31)) ^ u32table[i] @0x4120d0`（0x4120d0 = 磁盘 .data 的 0x400B 密钥表，磁盘可直接读！）。然后 8 轮对 8B 状态+输入块做 Feistel 混合；0x4053d9/0x405991/0x40622a 三个运算函数全部化简为 **XOR**（混淆常数 0x22043e 相消）。
- **0x401929/0x404371 = 密钥扩展**：`0x404371(dest, seed=0x412030)` 用 %15 调度产 36B 密钥；Unicorn 模拟输出 `6ca54c91 28838890 ff3eb91d 923ba54c 91a38388 6cff3eb9 28923b90 4c91a31d 886ca53e`（0x41d1f4 初始状态）。
- **0x40163f = 8 字节块字符串解密器**（0x404300 是其包装）：`(dest, src, wide)`，共享流状态 @0x41d1f4。已用 Unicorn 解出全部 14 条加密字符串：`NtProtectVirtualMemory / CreateFileW / SetFilePointer / ReadFile / LoadLibraryW / NtFreeVirtualMemory / NtTerminateProcess / LdrLoadDll / NtAllocateVirtualMemory / %lf / %d%m%Y / %.0f / _Inity@16` = **壳的完整自解包 API 清单**。
- 0x4023e2 = 批量解密循环（(state,data,n_blocks)，调 0x402425 n 次）；磁盘上无静态调用者（由解出的代码调用）。
- 0x405ad4 = WinMain；0x403b60 = fs:[0x18] TEB；0x405285 = PEB→Ldr→InLoadOrder 模块遍历（解析 ntdll/kernel32 基址）。
- 工具：`/tmp/stub/emu.py`（Unicorn PE 加载器 + cdecl 调用器，可复用）。

**用直接解密否定了几条捷径**：种子直接批量解 overlay 头部 = 熵不变（失败，密钥含运行时成分）；运行时镜像中无 0x22043e6f 常量（解包后引擎不含此密码——翻译用别的路径）；sbox 字节替换编码搜索 = 0 命中。

**动态捕获尝试（教训为主）**：
- 游戏进程 under lldb 极不稳定：SIGKILL lldb 会留下 TX(trace-stop) 僵尸进程（无法 kill，需等 init 收尸）；已产生 2 只（98975/99733），勿再 attach 后强杀。
- 0x402425 断点在完整启动后 attach 时 0 命中（启动解密早已结束；翻译解密不走此函数——运行时引擎是解包后的新代码）。
- 字体 copy B 每进程基址漂移（0x17d5ec0→0x17d6090→0x17d60d8）；尾部 682-1851 槽**在启动时全部重写**（1170 槽），字形无第二副本 → 源数据（overlay）启动时解密→写入→释放。
- 全进程空间搜 GDI 文本 API 名（GetGlyphOutline/TextOut/CreateFont…）：只命中 Wine DLL 区（0x7xxxxxxxxx）→ **引擎确定自绘字形，GDI 假设彻底死**。
- overlay 原始字节在进程内存 0 命中 → 解密后缓冲被释放/覆写。
- 合成输入可用：`/tmp/click x y n`（CGEvent 左键）、`/tmp/key keycode n`（回车=36、ESC=53）、`/tmp/activate pid`（NSRunningApplication 激活）、`/tmp/winlist`（列 wine 窗口含 PID；**截图/点击前必须核对 pid，用户的窗口 pid=155 勿动**）。lldb batch 模板见 /tmp/lldb_*.py；__lldb_init_module 才能注册命令。

**结论收敛**：译文库 100% 在 EXE overlay（目录 diff 实锤：CN/JP 所有数据文件逐字节同）。下一步唯一正路 = **从入口点整体 Unicorn 模拟 stub**（hook ~10 个 API：CreateFileW 自读、ReadFile、VirtualAlloc、NtProtectVirtualMemory、LdrLoadDll、NtAllocate/FreeVirtualMemory、NtTerminateProcess），一次性解出 overlay 全部内容（引擎+字体源+译文库），彻底离线化。

## 14. 2026-09-05（★原版汉化补丁完整逆向 + MoleBox 模拟器连破 7 关★）

### 14.1 ★用户找到原版汉化补丁 → 已完整解出★
用户提供了官方汉化补丁 `/Users/abc/Documents/shizuku_macos_experience/《雫96》简体中文汉化补丁 1.0.0.1001.exe`（NSIS 安装器）。
- **EP 变体 NSIS 格式**：firstheader 28B @0xbe00（magic=`'NullsoftInstEP'`，loh=0x5045，loa=0x2d8daba）；**头区未压缩**（20,549B，fh+32 起）；数据块 = `[u32 bit31=压缩标志|31位大小][LZMA1]`。zlib/bz2/纯LZMA 工具全不适用 → 用 **Unicorn 模拟安装器自带解压器**（`/tmp/patch_extract/nsis_emu.py`，调 0x402eb2=f(-1,out,0x2000000,total)，IAT 桩 + ReadFile/SetFilePointer/HeapAlloc 虚拟化）一次性解出全部 25,188,941B → `/tmp/patch_extract/nsis_all.bin`。
- **补丁内容清单**：仅 94,208B 未加壳 exe + 文档 + NSIS 插件/界面素材。**没有任何游戏数据/译文文件**。
- **决定性结论**：补丁内 exe 前 94,208B 与游戏目录 `Sizuku_cn.exe` **字节级相同** → MoleBox 版 = 汉化引擎(94KB) + MoleBox 数据(1,123,231B)。译文 100% 在 MoleBox 加密尾部（config 字段 +0x28=0x56ab0 起、+0x1bc=0x129397 止，≈861KB）。**模拟器路线确认为唯一路径**（印证 §13.7 结论收敛）。

### 14.2 MoleBox 全量模拟器（/tmp/stub/full_emu.py）连破 7 关
从 Sizuku_cn.exe 入口整体 Unicorn 模拟（含 MoleBox stub + 模块 blob 解密 + 模块 CRT 启动）。已通关卡：
1. **API 注册栈约定**：dispatcher(0xc18d778) 调用是 stdcall；slot 桩用 `ret N`（mkhook 按 POPARGS 生成 `mov eax,0xDEADC0DE; ret 4*N`）。
2. **R6030**：模块 CRT `_initterm` 后 locale 表空检查 → 运行时补丁 0xc199095 `75 13`→`EB 13`。
3. **DecodePointer 垃圾值**：encode/decode key 不一致 → 两者改恒等。
4. **R6016**：FlsSetValue/FlsFree 返回值被旧 catch-all 清 0 → 拆分支，SetValue/Free=1、GetValue=0。
5. **GetFullPathNameW**：C++ locale facet 依赖 → 实现 copy 语义（dst=arg(2)）。
6. **GetShortPathNameW**：参数序 dst=arg(1)、cap=arg(2)（非 arg(2)）。
7. **★dispatcher2 崩溃（run39-40）→ run41 修复中**：模块第二 dispatcher 0xc18e314（`push id; call` → `jmp [0xc15f0ce+4*id]`）表项预映射到配置区 thunk 槽 0xc100000+0x30*i，**id0/id3 槽被路径字符串覆盖**（"Z:\game\Sizuku_cn.exe"/"Z:\game"），跳进去执行字符串字节崩溃。cfg-exec 钩子（run40）证实 `[esp]=0xc17abea`（call 0xc18e314 返回地址）。修复：表 2 全槽替换 mkhook 桩 `mbx2!slotN`；do_api 头部处理（栈上多一个 id dword：ret 移位覆盖、内层调用后再 pop 4）；36 个 id→ntdll 名映射（run40 日志恢复）；实现 RtlDosPathNameToNtPathName_U/NtCreateSection/NtMapViewOfSection（直接把 CreateFileW 打开的文件数据写入映射）/NtCreateFile/NtReadFile（NT 路径 `\??\Z:\game\...` 解析）等。
- **dispatcher1（0xc18d778，基址 0xc15d5b1）API 名解析**：0xc154180 为 cdecl 3 参数解析器，force-resolve 直接 mkhook('dyn!名字')；0xc185770 打印 arg0 名；0xc185970 打印注册 4 元组。
- 模块 blob 内存图：0xc100000=config(0x10000)/0xc110000=blob(0x40000)/0xc150000=模块(0x70000)/0xc1c0000；fs-patch 22 处；模块 CRT = VC8。
- 关键教训：**Unicorn 崩溃 eip 停在 stub/数据地址上极具迷惑性**——handler 里 mem_write 或跳进数据都会这样显示；cfg-exec/block 钩子 + 栈上返回地址是定位真相的手段。

### 14.3 当前状态与下一步
- run41（pid 50989）后台运行：dispatcher2 全槽 hook + NT 文件 API 已就位。若通过 → 模块应到达 VFS 挂载（MoleBox 打包文件系统），开始对 861KB 尾部逐文件解密。
- **目标不变**：捕获解密输出 → 提取中文译文文本 → 判定格式 → Swift ShizukuRuntime 按 (scn,msg) 替换。
- 若 run41 又崩：按 §14.2 模式继续 fix-iterate（cfg-exec 钩子常开）。
- 模拟器现存诊断：hookwrite/imgwrite 监视器、单步 ss_log（seed 0xc0）、cfg-exec 钩子、STOP 全寄存器 dump、heap_used.bin 堆转储（含 module_blob.bin 提取脚本）。


## 15. 2026-09-05 深夜（★dispatcher2 名表离线全解 25/25 + CRT init 链推进到 ConvertSidToStringSidW★）

> 覆盖 §14.3 之后的 run87→run89 三轮。模拟器 = `/tmp/stub/full_emu.py`（勿动运行中实例），日志 = `/tmp/stub/runNN.log`，产物 = `/tmp/stub/out/`。

### 15.1 ★dispatcher2 名字表离线解密完成（LCG，Python 复现 25/25 全对）★

- 表结构（dump 在 `/tmp/stub/out/alloc_02780000.bin`，base 0x2780000）：jmp 表 `0x278d365`（40 槽，磁盘快照只填 0..23，run73 曾 jmp [0]→0，现 fs3 阶段把 0 槽预填通用 resolver 桩 `0x27bd6ff`）；**名表 `0x278d540`（25 项）**。名表项 = int32 相对偏移（全负），`name_va = 0x278d540 + off`（实际落在 0x278d3c9..0x278d52f）。
- **算法（离线已验证，25/25 名字全对）**：`seed = 4*id`；`esi = (seed + 0xabecaffe) & 0xffffffff`；每字节**先推进再取字节**：`esi = (esi*0x19660d + 0x3c6ef35f) & 0xffffffff`，`ch = ((esi >> (i & 7)) & 0xff) ^ enc[i]`，遇 `ch==0`（NUL）止。
- **★勘误：shift 是 `(i&7)` 不是 `(i&31)`★**——(i&31) 只能解出前 8 字符（`RegOpenK`/`ConvertSo` 后全是乱码），(i&7) 才 25/25 全对（2026-09-05 深夜离线复现，含 id22=ConvertSidToStringSidW、id23=GetTokenInformation、id24=OpenProcessToken 已知明文验证）。
- dispatcher1 名表 `0x278e5ac` 同方案（seed=4*id，见 `/tmp/stub/mb_ks10.py` 头注释；run87 日志 `[r970] seed=00000158`=4*0x56 ↔ GetCurrentProcess）。
- **id 0..24 全表**：RegOpenKeyA / RegOpenKeyW / RegOpenKeyExA / RegOpenKeyExW / RegCreateKeyA / RegCreateKeyW / RegCreateKeyExA / RegCreateKeyExW / RegQueryValueA / RegQueryValueW / RegQueryValueExA / RegQueryValueExW / RegSetValueExW / RegSetValueA / RegSetValueW / RegSetValueExA / RegSetValueExW / RegCloseKey / RegDeleteKeyA / RegDeleteKeyW / RegEnumKeyExA / RegEnumKeyExW / ConvertSidToStringSidW / GetTokenInformation / OpenProcessToken。
- 日志旁证：run89 `[r970] mod=0278d52f seed=0x60 / mod=0278d51b seed=0x5c / mod=0278d504 seed=0x58`——三个加密名 VA 与离线解出的 id24/23/22 名字 VA 逐一吻合（0x60/0x5c/0x58 = 4*24/23/22）。
- 以后再遇未知 disp2 id：直接按上式离线解名即可，**无需再跑模拟器猜**。

### 15.2 run87（23:10）：fake K32 缺 ConvertSidToStringSidW 导出 → d2zero 守卫干净停机

- CRT init（VC8）在启动早期做 token/SID 检查，调用链：**disp1 id0x56 (GetCurrentProcess，[r970] seed=0x158=4*0x56) → disp2 id24 (OpenProcessToken) → id23 (GetTokenInformation) → id22 (ConvertSidToStringSidW)**。每步都被 caller `test eax` + 失败即 `mov ecx,<err>; int3` 硬检查（MoleBox 惯例：0x7a=module、0x8b=name，见 full_emu.py `hook_intr`；OpenProcessToken caller=0x279b75d）。
- run87 时 fake K32（0x7a0000 页）导出表缺 ConvertSidToStringSidW/A → r970 walk 返 0（`[r970-walkret] eax=00000000`）→ **`[d2zero]` 守卫捕获（栈上 ret=0 无法恢复）→ 干净 emu_stop**，无野崩；log 尾 `dec_log entries: 32591` 照常落盘。
- 教训：见 `[d2zero]` / `[r970-walkret] eax=0` 组合 = 缺导出，不是执行流 bug；补名即过。

### 15.3 run88（23:25）：补导出后越过 id22，但 hook 回调内 mem_map = 禁手

- 导出表补入 ConvertSidToStringSidA/W 后推进到 id22 的 handler；handler 在 **hook 回调里调了 `uc.mem_map()`** → Unicorn 不允许 hook 执行中改映射 → `STOP: UC_ERR_MAP eip=00781130`（= `KERNEL32!ConvertSidToStringSidW` hook 桩，bytes `b8 dec0adde c20800` = `mov eax,0xDEADC0DE; ret 8`）。
- （`!! FS_BASE drifted to 00000000` 警告每条 API 都刷，是全程既有监测噪音，非本关特有——定位时别被它带偏。）
- **★铁律：hook 回调里绝不能 `uc.mem_map()`/改映射；一切 handler 缓冲用启动时预映射好的 scratch 区。** 现用 `sidbuf = HEAP+0xf0000 = 0xc0f0000`（HEAP 0xc000000 大小 0x2000000 早已映射）。

### 15.4 run89（23:38）：FreeEnvironmentStringsW 名字匹配修复 ✓，随后倒在 ConvertSidToStringSidW 参数位

- **修复生效**：`'kernel32!FreeEnvironmentStringsW'`（带 dll 前缀的 dyn 名）此前漏匹配 → 落 `[dyn-unknown]` → eax=0；diff run88/run89 确认两处 `[dyn-unknown] FreeEnvironmentStringsW` 消失（full_emu.py do_api 现按三重名匹配，~L1490）。
- **但 log 尾仍 STOP：`UC_ERR_WRITE_UNMAPPED eip=00781130`**（同一 ConvertSidToStringSidW 桩）。原因：handler 把 StringSid 指针写到 `arg(2)`——ConvertSidToStringSidW 只有 2 参（PSID, LPTSTR*），**out 指针是 arg(1)**，arg(2) 是越栈垃圾。
- **现版 full_emu.py 已含修复**（~L1875-1895）：ConvertSidToStringSidA/W 改用 arg(1)、向预映射 sidbuf 写 `S-1-5-18`（W 版 UTF-16）；GetTokenInformation 报 RetLen=0x40 并零填 0x40 字节（run86 修）。
- 【待核实】主会话记录称 "run89 修复后运行中"；实测 run89.log 于 23:38 已以 STOP 结束（上述 arg(2) 崩溃），修复在码中但 **截至 23:45 尚无 run90.log、无 full_emu 进程在跑**——下一步应启动 run90 验证。

### 15.5 fake DLL PE 头规范化要点（`build_fake_dll`，full_emu.py ~L462-519）

- DOS `'MZ'` + `e_lfanew=0x80`；COFF：machine 0x14c、1 节、opt 0xE0、chars 0x22。
- **opt 头：magic 必须 `0x10b`（PE32）**（r970 自带 export walker 校验，run78 踩过）、SizeOfCode=0x1000、**ImageBase=0x400000**（所有 RVA 按它解析）、Section/FileAlignment=0x1000、NumberOfRvaAndSizes=16、**export dir RVA/size = 0x1000/0x1000**、`.edata` 节头（vsize/vaddr 0x8000/0x1000…）。
- 导出目录在 base+0x1000：`dir(20B: Name=dllRva、ordinalBase=1) + NumberOfFunctions=n @+20、NumberOfNames=n @erva+24 + EAT(4n) + nameTab(4n) + ordTab(2n) + 名字 blob`（ord 表项 0 基）。
- **EAT 表项必须指向本 dll 页内的 E9 jmp trampoline（tramp0=0x4000 起、每槽 16B、`E9 rel32` 跳回 hook 桩），不能直接写 hook 桩地址**——MoleBox lazy 路径把"解析出的值"存进 dispatcher 表，其 stage-2 init 会把这些值当指针遍历（run51/52）；trampoline 同时保住 call 路径（→hook→do_api）与值扫描。
- walker 先验 `[hmod]=='MZ'`（日志 `[walk-OK] name=b'MZ'`）再走导出目录。

### 15.6 资产清单（`/tmp/stub/out/`，run89 落盘）

| 资产 | 大小 | 说明 |
|---|---|---|
| `alloc_00400000.bin` | 417,792B | **运行时主镜像 0x400000..0x466000**。已验：0x402425 = 真引擎块密码代码（`55 8b ec 83 ec 14 8b 45 08…`）、0x4120d0 密钥表在位（`17 1f 02 11 12 0f 81 08…`）。磁盘 stub 同 VA 代码与之**仅 ~2.4% 相同**（§13.7）→ 逆向运行时解密算法只能用这份镜像 |
| `dec_log.pkl` | 1.14MB | **32,591 条** 0x402425 块密码调用记录 `(a0, a1, 前8B, 后8B)`；首条 `(0x41d1f4, 0x250078, 6ca54c9128838890 → 2343f42843d34ad1)`，a0=0x41d1f4 即 §13.7 密钥扩展输出缓冲。= 还原算法的现成已知明文集 |
| `alloc_01400000.bin` | 16MB | 模块 heap 全量 |
| `alloc_02780000.bin` | 458,752B | **stage-2 区**（base 0x2780000+0x70000）：disp1/disp2 名表、模块代码、winmm/psapi 修补点、r970 resolver 均在此 |
| `heap_used.bin` | 59,936B | 已用堆 0x1400000..0x140ea20 |
| 其他 | — | `alloc_02600000`(1MB) / `02710000` / `02730000` / `02800000` / `02820000`(94,208B = 明文引擎 exe 大小) / 早期 `dec_blob_*` `dec_cfg` `plain_blob` `module_blob` 等 |

### 15.7 下一步

1. **启动 run90**（ConvertSidToStringSidW arg(1)+sidbuf 修复已在码中）→ 跑通 CRT init 全链 → WinMain。若 id22 之后又卡新 id：`[d2jmp]`/`[r970]` 日志取 seed 与 mod VA → §15.1 LCG 离线解名 → 补 handler，勿再盲猜。
2. **从 `alloc_00400000.bin` 静态还原运行时块密码**（0x402425 真代码 ≠ 磁盘 stub 的 0x40131e LZSS / 0x404371 密钥扩展，仅 2.4% 同）；用 `dec_log.pkl` 32,591 条 (前8B→后8B) 做已知明文校验，直到 100% 复现。
3. 用还原的算法**离线解密 EXE 尾部 861KB**（`Sizuku_cn.exe` 0x56ab0..0x129397）→ **中文译文库**（目标产物 = (scn,msg)→中文 文本，§13.1 模型）。
4. 验证锚点句 SCN001 msg5（§12.1 用户抄录 / §13.1 双句对照）。
5. Swift `ShizukuRuntime` 接入 "(scn,msg)→文本" 库（Phase C/D/E 机械件已就绪，§12.4）。

### 15.8 run90→run93（CRT init 越过 ConvertSidToStringSidW → 死在 0x14002e0，四种假象一次排清）

- run90 越过 id22 → LocalFree → DecodePointer → FlsGetValue/FlsSetValue → InterlockedIncrement → QPF/QPC；run90-93 全部 `STOP: Invalid instruction eip=014002e0`，**栈顶 ret=0x27bf1db**（`call 0x27be314` 返回点）。
- **dispatcher3 解密（0x27be314，表 0x278f0ce）**：代码 `pop eax; xchg [esp],eax; shl eax,2; lea eax,[eax+0x278f0ce]; jmp [eax]`——调用约定同 d2：`push args…; push id; call`，`xchg` 取 id 换回 ret。**名表 0x278f3fc**，与 d2 完全同构（int32 相对偏移 + LCG seed=4*id + xkey 0xabecaffe + **shift=(i&7)**），36 槽全解 = **MBX2_NAMES 全表 0..35**（NtContinue…NtQueryAttributesFile）。crash 调用点 0x27bf1c3：`push 4; push &local; push 0x22(ProcessExecuteFlags); push -1; push 0xf; call d3` = **NtSetInformationProcess(-1, ProcessExecuteFlags, &local, 4)**（DEP 开关）。
- **假象①**：`[d3]` 探针读 `eax>>2` 得垃圾——hook 在**指令执行前**触发，入口 `pop eax` 尚未执行，eax 是旧值。正确探针 = hook **0x27be321**（`jmp [eax]`），此时 eax 就是槽 VA。run94 `[d3j] slot=0278f10a target=014002d0` + table40 快照证明**槽 0..35 全部 = 0x1400000+0x30*i 且填好**（alloc dump 里的 0x06320845 是**上一 run 的陈旧 dump**，勿再被误导）。
- **假象②**：heap tramp `E9 rel32; push nameptr` 的 push-imm 不在我们任何 hook 区——这些 tramp 是 **stub 自己生成**的（每解析一个 ntdll API，`HeapAlloc(0x20)` 拿一块写 `E9 →解析值; push 加密名指针`；`HeapAlloc(0x20)` 对齐后步进恰好 0x30，故 36 槽连成 0x1400000..0x1400690）。
- **★真 root cause（run95 HeapAlloc 日志实证）**：旧 `HeapCreate` handler **每次调用都把 hptr 重置到同一 0x1400000**，三个"堆代"（①主镜像早期块 140/41c4/800 ②36 个 ntdll tramp 块 ③CRT init 的 ~154 个 214/220 块）**互相覆盖**——③盖掉②的 slot15 tramp → `jmp 0x14002d0` 落进③的数据（`01 10 00 00 c1 0a 15 43…`）→ INSN_INVALID@0x14002e0。**修复（已在码中）**：`HeapCreate` 按 handle 独立窗口 `0x1400000+0x400000*n`（handle=0x81000000+n，`heap_map[handle]=[base,bump]`），HeapAlloc/HeapReAlloc 按句柄取各自 bump；dump 改为每 handle 一份 `heap_%08x.bin` + 全域 `heap_used.bin`。
- 悬案同步澄清：alloc_02780000.bin 里 d3 表 slot15=0x06320845 只是"上一 run 崩溃后未填/或运行后期改写"的陈值——**以 `[d3j]` 运行时快照为准**。表槽值由 stub 在 r970 解析时填，磁盘快照从未有过 heap 地址。

### 15.9 资产增量（run94/95）

- `/tmp/stub/out/heap_used.bin`：现含全域 0x1400000..0x1400000+0x400000*n（三窗口），另有逐 handle dump `heap_8100000*.bin`。
- `[d3j]` table40 快照（run94 log 3382 行）：槽 0..35 = `01400000..01400690` 步进 0x30，36..39 = 未填垃圾（ed2c840b…）→ **d3 实际只有 36 槽**。

### 15.10 run96→run99（堆窗口修复链 + Import-Error 全表补齐）

- **run96（0x400000 窗口）**：三堆分离生效，但第 6 次 HeapCreate 的窗口 0x2800000 撞 NtAlloc 区（galloc 0x2600000 起、NtAlloc 已给 0x2800000）→ 旧 OOM cap `>0x2400000` 触发 emu_stop。教训：**堆窗口基址必须避开 NtAlloc 的 galloc 上行区**。
- **run97（窗口 0x400000@0x1000000 起）**：5 个堆独立（dump `heap_8100000*.bin` 各自成段，tramp 堆 0x1400000 完好）✓；但 heap#5 窗口 [0x2400000..0x2800000) 仍与 NtAlloc 0x2800000 相邻碰撞 → mem_map 重叠被 try/except 吞 → HeapAlloc 返未映射 0x2400000 → 写 0x240005c crash。**窗口改 0x100000**（每代用量 <0x23000，32 个堆也只到 0x3000000 之下——0x1000000+0x100000*n 与 galloc 0x2600000 相容至 n=0x16）。
- **run98（0x100000 窗口）**：CRT init 全链跑完，**stage-2 解包推进到逐 DLL LoadLibrary+导出 walk 阶段**；user32 首个加密 API 名 id0 = **MessageBoxA**（mod=0x278ee37 seed=0，LCG 离线解出）——fake K32（user32→K32 页）缺 MessageBoxA 导出 → walk 0 → eip=0 crash。补 user32 常规集导出 + MessageBoxA handler（读 arg1/arg2）。
- **run99**：MessageBoxA 触发成功——弹的是 stub 自检错误 **`Import Error` / `module doesn't have symbol <名>`** ×57 → TerminateProcess。**含义：stub 对每个 import DLL 做符号完备性自检**（LoadLibraryA(name) 返回 K32 页 → r970 在 K32 导出表找每个符号 → 缺即弹窗退出）。57 个缺符号全收集（IsBadCodePtr/_lread/_lwrite/_llseek/_lclose/OpenFile、user32 窗口油漆输入集、gdi32 palette/Blit 集、shell32 SHGet*、msacm32 acmStream* 全家）→ 全部补入 K32 导出表 + POPARGS 表（stdcall 清栈数——**漏了会栈失衡**）。GetModuleBaseNameA/GetModuleFileNameExA/W 加 eax=0x10 handler（run98 [dyn-unknown]）。
- run99 另一发现：TerminateProcess handler 是 [dyn-unknown] eax=0（没停机）→ 后续 eip=0x423f54 crash 是 stub 自检失败后的连锁，非独立 bug。
- **run100 进行中**：预期越过全部 Import-Error 自检 → 真正的 MoleBox 数据容器解包（861KB 尾部的每文件 keystate 派生就在这一步，`dec_log.pkl` 会自动记录）。

### 15.11 模拟器内存布局现状（run97+ 权威版）

| 区 | 范围 | 用途 |
|---|---|---|
| 主镜像 | 0x400000..0x466000 | 运行时解密后真代码（0x402425 块密码等） |
| FSBASE/PEB | 0x700000/0x720000 | 伪 TEB/PEB |
| HOOK 桩 | 0x780000+0x100+hn*0x10 | API hook 表 |
| 伪 ntdll | 0x790000+0x4000+16i | fake DLL（EAT=E9 tramp） |
| 伪 K32 | 0x7a0000+0x4000+16i | 同上（user32/gdi32/msacm32/shell32 全走这里） |
| 堆窗口 | **0x1000000+0x100000*n**（n=HeapCreate 序） | 0..5 = 主镜像代/tramp 代/CRT 三代；OOM=窗口顶 |
| galloc | 0x2600000 起 +0x10000/次 | NtAllocateVirtualMemory 上行区 |
| stage-2 | 0x2780000..0x27f0000 | disp1/2/3 名表、r970、模块代码 |
| HEAP | 0xc000000..0xe000000 | config 0xc100000 / blob 0xc110000 / module 0xc150000..0xc1a8000 / tramp_for 0xc100800 |

### 15.12 run100→run104（Import-Error 清零 → 窗口创建 → 消息循环，三层栈陷阱全排清）

- **run100（57 符号补齐后）**：`Import Error` 归零 ✓（stub 符号自检全过）。新 crash eip=0x423f54 读地址 0——运行时解密后的主镜像代码（0x423f45 = MSVC `__ehhandler` SEH prologue `mov eax,fs:[0]`）在**启动 fs-patch 扫描之后才解出来**，fs:[0] 绝对化漏网。fs3_done 时重扫（[fs4]）得 0 站——**解密发生在 fs3_done 之后**，静态时机不可得。
- **修复（run102）**：**页 0 映射为 TEB 镜像**（`mem_map(0,0x10000)` + 拷贝 TEB 前 0x1000）——任何漏网 `fs:X` 直接读写地址 0 处的同构 TEB 副本，SEH 链自洽。**这是对"fs-patch 时机不可知"类问题的通用解**。
- **run102**：越过 SEH → **RegisterClassExA 阶段**；eax=0（失败）令 caller 走错误分支 eip 落栈（0x24ffb4）。补窗口/GDI 语义：RegisterClassExA 返递增 ATOM 0xC000+、LoadIcon/LoadCursor/GetStockObject/SetCursor 返 0x10000+n 伪句柄、GetSystemMetrics 1024×768、RegQueryValueExA 返 ERROR_FILE_NOT_FOUND(2)。
- **run103**：推进到 **CreateWindowExA → ShowWindow → UpdateWindow → SendMessageA → GetMessageA**；GetMessageA 落 [dyn-unknown] 且**POPARGS 缺失**（默认 pop 0，真协议 4 参 pop 16）→ `ret` 读到栈上参数 0x12 → eip=0x24ff9c 落栈。**教训：dyn! 懒路径 hook 的 stdcall 清栈数必须写 POPARGS，漏写=栈失衡=落栈执行**。补全套消息 API POPARGS + GetMessage 写 MSG{0,WM_QUIT=0x12,0,0,0} 返 0。
- **run104**：GetMessage/循环栈位正确，但 **SendMessageA 后 eip=0x10000**（我们 LoadIcon 伪句柄 0x10000+n 被当 ret）——栈 @esp=0x10001、[esp+4]=0x424025：疑似清栈数或消息参数细节，run105 加 `[SendMessage] hwnd/msg/wp/lp` 探针 + `[CreateWindow] class/title` 探针定位。
- **消息循环语义要点**（后续维护者）：游戏是标准 Win32 消息循环（GetMessage→Translate→Dispatch）；GetMessage 返 0=WM_QUIT 干净退出；SendMessageA 需按 msg id 决定返回值（如 WM_GETICON 类返句柄，否则 0）；DispatchMessageA 应模拟**调用 wndproc**——wndproc 地址在 WNDCLASSEX 注册时（RegisterClassExA arg(0) 结构 +8），必要时 hook 并分发到游戏代码。

---

## 16. 2026-09-05 晚 → 2026-09-06（★per-file cipher 完整逆向 + seed 派生定位到 catalog entry + 模拟器推进到消息循环★）

> 覆盖 run105→run150 + 离线 agent 分析。模拟器 = `/tmp/stub/full_emu.py`，日志 = `/tmp/stub/runNN.log`，产物 = `/tmp/stub/out/`。

### 16.1 ★per-file cipher 完整逆向并验证（pf_cipher.py，roundtrip x300）★

**函数链（VA, 基址 0x2780000 = alloc_02780000.bin）**：
- `0x27b6470` 单块原语：`push count(1); push data; push ksobj; call 0x27be69c`
- `0x27be69c` 入口：count==0 则 ret；否则建帧 → `call 0x27be7b6`（自解码 stub，`pop ebx` = S-box 基址）
- `0x27be7c5` 主循环：每 8B 块 = 9 次 A-step + 8 次 B-step 交错：
  - A: `eax = edx ^ K[ki]; ki+=4; subA(eax); eax ^= H`（subA = al/ah 查 S-box → ror eax,16 → 再查 → ror 16）
  - B: `ah ^= al; eax ^= K[ki]; ki+=4; eax = subB(eax); edx ^= eax`（subB 同 subA 但最后 ror eax,8）
  - 每块消耗 keystream 17 dwords = 68B（A 用 K[0,2,…,16]，B 用 K[1,3,…,15]）
- `0x27b63d0` key schedule：16B seed → mod-15 置换展开 60B（已验证 == boot `_M` 表）
- `0x27b6380` key mixer：15B seed 按 stride 15 铺 60B → 调 `0x27b6310`（内部分配 68B = 每块 keystream + 8B 越界读）
- S-box：内联在 `0x27be6b6`（256B），与 boot S-box 逐字节相同，已导出 `/tmp/stub/pf_sbox.bin`

**验证**：`/tmp/stub/pf_cipher.py` 的 `enc8/dec8` roundtrip OK x300（68B 随机 keystream + 8B 随机明文）。算法实现自洽。

**seed 格式**：15B（16B MD5 digest 前 15B？第 16 字节用途未见）。per-record 路径单块 ECB 式调用（0x27b6470 count=1），未见 IV。

### 16.2 ★seed 派生 = MD5(filename)，已定位到 catalog entry 级★

- `0x27a9950` = MD5(filename)：标准 MD5 init 常量（0x67452301…），strlen 循环 + MD5Update + MD5Final。3 个调用点：0x27ab868 / 0x27ab8d8（两个 fetch wrapper）/ 0x27aceb1（catalog loader）
- 编码字符串解码器 `0x27be636`：`(C ^ 0x1030326) - 0x1030326 & 0xffff` = 表 0x278f59c 内偏移，逐字节 `ah ^= al; al = ror(al,1)`。已解码：
  - `0x1e2b226d / 0x1e36227e` = **`password`**（fetch wrapper 空文件名回退 seed）
  - `0x1f012303` = `g46dgsfet567etwh501bhsd-=352`（catalog loader 的 seed 名）
  - `0x1f26236e` = `STELPACK`，`0x1f372371` = `QUICKBOX`，`0x1f422342` = `STELPACK`(8B)，`0x1e94229c` = `internall`
- per-record 解密 `0x27ad260`：解码 `STELPACK` → `0x27b6380(ecx=edi+0x40, esi)` → 两次 `0x27b6470(count=1)` → `0x27b63d0(ecx=edi+0x40)` → 读流 8B → `0x27b6470` 解密 → 与 `QUICKBOX` 比对
- catalog loader `0x27ace90`：解码 catalog seed → `0x27a9950`（MD5）→ `0x27b63d0`（schedule）→ `0x279b4f0` 读流 8B + `0x27b6470` 解密验 magic
- fetch wrapper：`0x27ab830`（调 0x27ab3f0 core；调用者 0x27a32b6, 0x27bce36），`0x27ab8a0`（调用者 0x27bcec2）

### 16.3 ★卡点精确描述：record-id → per-file seed mapping★

`0x27ad7f0`（record 构造）调 `0x27ad260` 时传参：
```
mov eax,[edi+18h]; mov edx,[eax+ebx*8-4]; lea eax,[eax+ebx*8]; mov edx,[eax-8]
mov eax,[edi+8]; push ecx,edx,eax; call 0x27ad260
```
`0x27ad260` 把 `[esi]` 处 16B 拷进对象 `edi+88h`——**16B record-id 就在 catalog entry 表项指针处**。

**三个未确认**：
1. `[esi]` 这 16B == pkg_tree.bin rec+12 的 16B？（运行时 entry stride 24B ≠ pkg_tree 64B，布局未对应）
2. `0x27b6380(ecx=edi+0x40, esi=[ebp+0x10])` 的 esi 端：吃的是 16B id 还是其他字段？（差 1 个指针别名确认）
3. MD5 输入的文件名字符串：`MD5(变体文件名)` 穷举 vs 199 个 catalog id **0 命中**（试过大小写、`.\`、`Z:\game\`、KNJ/PAK/LFG 名、password/catalog）。真名可能是内部名（如 `internall…`），或 id = MD5(name+salt)。

**失败路径（已排除）**：catalog-MD5-seed + boot T-CBC 解 overlay 0x751cb（无 magic）；id16[:15] / id16[1:] / keytab 15B 窗口 × T-CBC（无结构）；LEAFPACK 11B rolling-sub（随机输出）；单字节 XOR + zlib 头扫描（256 keys，0 命中）；MD5(大小写变体) vs 16B id（0 命中）；CRC32/adler32 vs flags（0 命中）。

### 16.4 ★overlay 结构完整测绘（agent_overlay_findings.md + agent_overlay_map.md）★

**外层 T()-CBC 解密（已验证 32495/32495 块全对）**：
- seed = EXE[0x17178:0x17187] = `12 30 7a 48 b4 19 82 1c 50 8c d7 5b 89 a5 77`
- S-box = EXE[0x120d0] 256 dword + `((0x22043e6f >> ((i+1)%31)) ^ tbl[i]) & 0xff`
- 工具：`/tmp/stub/mb_core.py`（T/expand/_M/mb_decrypt）

**overlay 布局（单模块 + 记录流）**：

| 区段 | file 偏移 | 长度 | 内容 |
|---|---|---|---|
| 头 | 0x17000 | 8B | MoleBox 头 |
| TOC | 0x17008 | 0x1f0 | 壳配置（dword0=0x23f45=引擎 EP RVA；链表 [off,size,crc,next]） |
| 附加密钥表 | 0x171f8 | 0x40 | 未破解（h=102 读取；非 seed1 明文） |
| STEELBOX | 0x17338 | 0x3f778 | 运行时 DLL/壳代码 → 0x2730000/0x2780000 |
| 引擎段表 | 0x56ab0 | 0x12c | PE section table（4 节 × 40B） |
| 引擎 .text | 0x56bdc | 0x19896 | zlib → 184,320B（与 JP .text 仅 6B 差） |
| 引擎 .rdata | 0x70472 | 0xcd8 | zlib → 8,192B（含被壳改写的导入表 0x42e100+） |
| 引擎 .data | 0x7114a | 0x3b42 | zlib → 49,152B（含中文 UI GBK/槽位码，与 JP diff=507B） |
| 引擎 .rsrc | 0x74c8c | 0x53b | zlib → 4,096B（zh-CN 资源） |
| **间隙** | 0x751c7 | 16B | u32 0x129317 + 12B |
| **spack 记录流** | 0x751d7 | 0xb41c8 | **737,752B 加密虚拟文件数据** |

**记录流结构**（overlay_modules.json：table1=47 条，table2=146 条，共 193 条）：
- 头 16B（明文）：`17 93 12 00 | ae 68 ed cd | 5c a8 cc 03 | cb 51 07 00`
- 每条 64B：`[+0:12 零][+12:28 16B id][+28:32 u28(疑似 crc)][+40] pt_size [+44] method(KNJ=7) [+48] (hi<<12)|ct_len [+52] flags(低字节 06) [+56] ct_off(流相对) [+60] 0(KNJ=0xc0005f30)`
- 校验：`f56[k+1]-f56[k] = ct_len[k] + (0x1000 若 cbit[k]=1)`
- 明文总量 t1+t2 = 1,228,240B；加密后 738,504B（总压缩 ~1.66:1）

**高价值嫌疑记录**：

| 记录 | pt 大小 | 身份证据 |
|---|---|---|
| table1[46] id `35e180b5…ed310bbf` | 340,272B | == cn_KNJ_ALL.KNJ 字节级等长；id 尾段 == 运行时 UNK_ed310bbf |
| table2[145] id `d31fbe0d…b50ef7e6` | 144,048B | == UNKNOWN_LEAFCODE.bin；ct 仅 5,152B（~28:1 压缩） |

其余 191 条 pt_size < 15KB（多为 SCN 脚本级尺寸）。

### 16.5 ★cn_pkg 文件（/tmp/stub/out/cn_pkg/，199 个）★

run132 期间从模拟器提取的虚拟文件原始数据：
- SCN001.DAT..SCN201.DAT（195 SCN 文件）：前 16B 明文 SCN 头（`01 00 XX 00 + 12 零`），body 加密（熵 ~5.5-6.0，直接 LZSS 解出 85% 零）
- UNKNOWN_LEAFCODE.bin（144,048B）：头 8B 明文 `LEAFCODE`，body 加密（熵 5.29）
- UNK_ed310bbf（340,272B）：全加密（头 `ff ff ff ff…`）
- UNK_80285788（4,032B）、UNK_cc2d0383（1,856B）

**含义**：cn_pkg = 壳按需解密后的虚拟文件明文，但模拟器在提取时**尚未应用 per-file cipher**（emu 绕过了真实 handler）。这些文件 = per-file 加密后的密文，需要 pf_cipher.py + 正确 seed 才能解出明文。

### 16.6 模拟器推进：run105→run150（消息循环卡点）

- **run105**：越过全部 Import-Error 自检 → RegisterClassExA → **CreateWindowExA**（class=`LEAF_MAX`, title=`[AUGUST中文化委员会] 雫 '96`）→ 崩在 `eip=0x10000`（LoadIcon 伪句柄被当 ret 地址）
- **run106-108**：同上 eip=0x10000 崩溃
- **run109**：越过 CreateWindowExA → CreateFileW("Z:\game\Sizuku_cn.exe") → handle 102 → **INT3 风暴**（0x27a92e3..ed 连续 INT3，MoleBox VM 入口）→ 无 SEH 链 → 死
- **run110-112**：同 INT3 hard-fail
- **run113-150**：全部卡在 **GetSystemMetrics 循环**（eip 在 0x40b8ec..0x40bbd9 之间循环，esi=0/1/2/3 步进）——这是引擎在消息循环中持续调用 GetSystemMetrics(SM_CXSCREEN=0/SM_CYSCREEN=1/SM_CXBORDER=2/SM_CYBORDER=3)，我们的 handler 返回常量但引擎期望真实值或特定行为

**run132 特殊**：`resume run done final eip=0000ff39`——这是 stub 级 resume（eip 在 0xf000 范围），不是引擎级。

**run134**：`final eip=00431362`——引擎 .data 段中文标题串（`中文化委员会] 雫 '96`），说明引擎在读取自身 .data。

### 16.7 关键资产清单（/tmp/stub/out/）

| 资产 | 大小 | 说明 |
|---|---|---|
| `alloc_00400000.bin` | 417,792B | 运行时主镜像（0x400000..0x466000），含真引擎代码 |
| `alloc_02710000.bin` | 65,536B | TOC（seed1 解密后） |
| `alloc_02730000.bin` | 262,144B | **解密后 STEELBOX**（stage-2 代码 + per-file cipher） |
| `alloc_02780000.bin` | 458,752B | stage-2 运行时（disp1/disp2 名表、r970 resolver） |
| `alloc_02820000.bin` | 65,536B | 明文引擎 exe 大小（94,208B 有效） |
| `cn_pkg/` | 199 文件 | 虚拟文件密文（per-file 加密） |
| `dec_log.pkl` | 1.14MB | 32,591 条块密码调用记录（仅 outer cipher） |
| `overlay_modules.json` | — | 193 条记录 (id,size,ct_off,ct_len,flags) |

### 16.8 下一步（按优先级）

**A. 拿到 per-file seed（唯一阻塞项）**：
1. **运行时 catalog 对象快照**（最直接）：在 emu 中让真 shell 跑过 catalog 加载（断点/日志 0x27ad12c 成功分支），dump `[0x2786208]` 对象（+0x18/+0x20 表, +0x24 总数）→ 得到 entry 24B 布局 → 对应出 id/off/size 字节 → 离线构造 per-file seed
2. **fetch 文件名字符串**：hook/log `0x27ab830/0x27ab8a0/0x27ab3f0` 的文件名参数 → 得到 MD5 真输入 → 验证 id==MD5(name)?
3. **静态备选**：精读 `0x27ad260` 开头（`0x27b98c0` 读流 + 两次 `0x27b6470` 的 buffer 语义）与 `0x27ad4c7 call 0x27ac420`（单块/多块选择条件），把 `[ebp+0x10]` 别名钉死

**B. 解开 737KB 尾区后**：
1. 验证锚点句 SCN001 msg5（§13.1 双句对照）
2. 提取 (scn,msg)→中文 文本库
3. Swift `ShizukuRuntime` 接入译文库（Phase C/D/E 机械件已就绪，§12.4）

**C. 模拟器消息循环修复**（并行）：
- GetSystemMetrics 循环：需正确处理 SM_CXSCREEN(0)/SM_CYSCREEN(1)/SM_CXBORDER(2)/SM_CYBORDER(3)，返回真实值（1024×768 或实际屏幕分辨率）
- INT3 风暴：需实现 MoleBox SEH/VEH 链（或绕过 VM 入口直接调真实 handler）
- 目标：引擎进入数据读取阶段 → 触发 per-file 解密 → dec_log 自动记录

### 16.9 工具链速查

| 工具 | 用途 |
|---|---|
| `/tmp/stub/mb_core.py` | 外层 T-CBC 解密（seed + S-box + T() + CBC） |
| `/tmp/stub/pf_cipher.py` | per-file cipher（enc8/dec8，roundtrip verified x300） |
| `/tmp/stub/kpa.py` | key schedule（ks68_sched/ks68_mixer） |
| `/tmp/stub/map_overlay.py` | overlay 测绘（重写 overlay_modules.json） |
| `/tmp/stub/full_emu.py` | MoleBox 模拟器（Unicorn PE 加载器 + API 虚拟化） |
| `/tmp/stub/agent_a_deliv.py` | T/expand/_M/mb_decrypt 工具集 |
| `/tmp/stub/agent_c_decrypt.py` | 外层 cipher 解密脚本（build_S + build_schedule + D） |
| `/Users/abc/Documents/shizuku_macos_experience/shizuku_cli/scn.py` | SCN LZS 解码器（lzs_decode_inv） |

---

## 17. 2026-09-08（★/tmp 重启全丢 → 备份抢救 + per-file cipher 重建验证★）

> 本节覆盖 11:30→12:30。本小时开场发现 `/tmp/stub`（mb_core.py、pf_cipher.py、full_emu.py、全部产物）因 9/7 15:00 重启丢失。用户确认未删任何东西后，从 `~/.claude/file-history/` 抢救 + 亲手重建验证。**教训：/tmp 工具链必须迁入仓库（已执行，research/recovery/stub/），任何重启都抹掉 /tmp。**

### 17.1 抢救清单（全部已迁入 `research/recovery/stub/`）

| 文件 | 来源 | 说明 |
|---|---|---|
| `full_emu.py` (171,362B) | file-history `24b5387d88f1c700@v7` (9/7 11:24) | 最新版模拟器（语法已验 OK） |
| `mb_replay.py` | file-history `c9a534d57754d02a@v2` | 外层解密 Unicorn 重放器（依赖丢失的 alloc_00400000，暂不可跑） |
| `kpa_probe.py` | file-history `3a76ee297e3a8bd5@v2` | per-file KPA 探针（含 ks68_mixer/sched + layout68 真实现，依赖 pf_cipher） |
| `kpa_brute.py` | file-history `d34ca92bcf9eeb84@v2` | asm-literal 分析结论（dec8 方向已验对，见 §17.2） |
| `handover_update_draft.md` | file-history `bc05ce515217392a@v2` | §15 草稿（已并入，无新信息） |

**未抢救回（无备份）**：`mb_core.py`、`pf_cipher.py` 原版、`overlay_modules.json`、`cn_pkg/` 199 文件、`dec_log.pkl`、`alloc_*.bin` 全系。`overlay_modules.json` / `cn_pkg` 需模拟器重跑或离线重建（§17.4）。

### 17.2 ★per-file cipher 重建并验证（research/recovery/pfile/pf_cipher.py，roundtrip 300/300）★

- **S-box 公式裁决**：EXE[0x120d0] 256 u32 直接验证——`(i+1)%31` 给出 256/256 双射，`i%31` 仅 163 unique（碰撞）。**采用 `(i+1)%31`**。磁盘反汇编 0x40245e-0x402482（`idiv 0x1f` + `sar edx,cl`）独立确认 shift=(i+1)%31。
- **★H_0 真语义（本次新发现，HANDOVER §16.1 伪代码未写明）**：明文高 4B（eax_in）= carried state 初值 H_0，不是被 A0 覆盖的垃圾。证据：roundtrip 失败样本恒为"edx 对、eax 错"；改 `H=eax_in`（enc）+ dec 返回 `(edx_0, H_0)` 后 300/300 全过。这是 Feistel 结构（输入两半都参与，enc 单射）。
- enc8 里另修一处 B-step `ah^=al` 死代码（三重赋值互相覆盖）。
- subA/subB/mix 可逆性各 200/200；`expand`（mod-15）与 `layout68`（7→8 零孔）沿用 kpa_probe 的实现（与 §16.1 一致）。
- docstring 里"Verified roundtrip x300"为重建 agent 误标（实际 0/300），已修实现、验证通过后才算数。

### 17.3 外层 stub 块密码 0x402425 反汇编（磁盘 stub，capstone 实测）

- S-box 构建（0x40243f-0x402488）+ 8 轮主循环（0x40248a 起，每轮调 0x4053d9/0x405991/0x40622a）。
- 三子函数化简（全部 XOR，§13.7 结论独立复现）：
  - `0x40622a(a,b,c) = c - ((a&0xff)^(b&0xff))`（imul/and 存 [ebp-8] 从未使用 = 混淆垃圾）
  - `0x4053d9(a,b) = a^b`（经 0x40622a：`0x22043e - (0x22043e - (a^b))`）
  - `0x4059c2(a,b,c) = c + (a^b)` → `0x405991(a,b) = a^b`
- **Unicorn 直调尝试（失败，记录断点）**：keystate=§13.7 的 36B（0x41d1f4 初值）+ CBC(IV=0) 解 STEELBOX 头 64B 得乱码。可能：① CBC 链方向/原语方向不对；② 真 keystate 需跑 0x404371 生成（它有反调试全局量检查 0x412060/0x412090，磁盘全零镜像走 je 分支，Unicorn 需摆全局量）；③ 该 36B 只是"初始状态"非最终 keystate。**下一步：等 full_emu 跑到 0x402425 调用，dec_log 自动记录带真 keystate 的 (a0,a1,前8B,后8B) 对，再离线拟合。**
- 模拟器本小时试跑：240s ≈ 6900 万指令，仍在 strcmp/IAT 解析早期（eip 0x40xxxx）。到 catalog/VFS 需数十亿指令，单次跑不完——后续用 `FULL_EMU_CHK` 快照断点续跑（full_emu.py 已支持）。

### 17.4 下一步（按优先级）

1. **full_emu 快照续跑** → 抓 `[SEED]`（0x27b63d0/0x27b6380 探针已在码中 ~L1185）+ dec_log → per-file seed + 外层真 keystate。
2. 用 seed + §17.2 的 pf_cipher 解记录流（table1[46] 340KB / table2[145] 144KB 先行，LEAFCODE 头 8B 做 KPA 验证）。
3. 外层 T-CBC：用 dec_log 已知明文对拟合 T() 后，解 STEELBOX + 引擎四节（验证：.text zlib→184320B）。
4. `research/recovery/text/zh_text.json` 已有 SCN001 msg5 样本；TranslationStore 脚手架已进 ShizukuRuntime（§17.5）。

### 17.5 Swift TranslationStore 脚手架（本小时并行完成，build 通过）

- 新增 `ShizukuCore/TranslationStore.swift`（`"scn:msg"→中文`，缺 `research/recovery/text/zh_text.json` 即空库，默认行为零变化）。
- `GameData` 加可选 `translationStore`（默认 nil→自动加载 json）；`Engine.translatedText(scn:msg:)`（有库命中中文、无则 nil 走 JP 通路）。
- `Package.swift` 加 testTarget；`Tests/ShizukuCoreTests/TranslationStoreTests.swift` 4 测试（命中/回退/JSON/缺文件/集成）。
- `swift build --package-path ShizukuRuntime` 通过。**未 commit（与恢复文件一起 commit）。**

### 17.6 工具链速查（更新 §16.9，/tmp 一律改为仓库路径）

| 工具 | 用途 |
|---|---|
| `research/recovery/stub/full_emu.py` | MoleBox 模拟器（v7 抢救版，支持 FULL_EMU_CHK/RESUME/KEYS） |
| `research/recovery/stub/mb_replay.py` | 外层解密重放器（待 alloc_00400000，需重跑模拟器） |
| `research/recovery/stub/kpa_probe.py` + `kpa_brute.py` | per-file KPA 探针/asm 结论（需 `sys.path` 指到 pfile） |
| `research/recovery/pfile/pf_cipher.py` | per-file cipher（**重建+验证 300/300**，含 H_0 修正） |
| `research/recovery/text/zh_text.json` | 译文样本（SCN001 msg5 锚点句） |

### 17.7 本轮离线深挖（keyexp 复现 + 外层调用约定钉死 + 方向排除）

- **0x404371 key expansion Unicorn 复现**：`0x401929(dest)` 调 `0x404371(dest, 0x412030)`；摆磁盘镜像直跑，输出 44B，前 36B 与 §13.7 记录逐字节一致。主循环 = %15 调度（首块写序 [i+2,i,i+3,i+1]，遇 0xc 止）；头部 flag 检查只写局部量，不影响输出。seed=EXE file 0x12030（= §13.7 15B）已验一致；密钥区全局量（0x412060/64/90/94/98/ac）磁盘非零。
- **磁盘 0x402425 调用约定钉死**：`0x402425(keystate, data)` = **ECB 原地 8B 块变换**（非 CBC）。证据：0x40163f（字符串解密器）= `0x4065f0`（memmove，rep movsd+跳表，0x4065f0 反汇编确认）取 8B 到栈 → 0x402425(0x41d1f4, buf) 原地变换 → 逐字节拷出；0x4023e2 = 批量循环 `(state, data, n)`；磁盘调用者共 3 处（0x40168b/0x402417/0x4054c4）。
- **三子函数 XOR 化简**（capstone 磁盘实测）：`0x40622a(a,b,c)=c-((a&0xff)^(b&0xff))`（imul 行是混淆垃圾，结果从未使用）；`0x4053d9=0x405991=a^b`。S-box 重建 `(0x22043e6f>>((i+1)%31))^u32table`（idiv 0x1f+sar 实证）。
- **排除结论**：磁盘 0x402425 + keystate 44B，对 STEELBOX/TOC/engsec/stream 做 CBC 与 ECB 解密**均为乱码** → 磁盘 stub 原语只解 stub 自身小配置/字符串，**不解 STEELBOX**。STEELBOX（及 737KB 记录流）由 stage-2 体系（seed1=EXE[0x17178] + T()-CBC）解密，其 Python 实现（mb_core.py）已丢，需重建（§17.4.3）或等模拟器 dec_log。
- **后台长跑进行中**：`FULL_EMU_CHK=/tmp/stub/out/chk_winmain`（目标 WinMain + 0x27ace90 catalog 快照 + [SEED]），50min 上限；本轮内跑到 1.38 亿指令仍在 strcmp/IAT 解析早期。后续会话：查 `/tmp/stub/run_long.log` + `out/chk_winmain*` 是否落盘。

### 17.8 本轮成果（transcript 打捞 + 离线验证 + 模拟器日志分析）

- **mb_core.py 已从 9/7 会话 transcript 打捞恢复**（`research/recovery/stub/mb_core.py`，heredoc 原文逐字恢复 + find_exe 路径适配）：T()/expand()/_M/decrypt 与 §16.4 一致。离线验证：STEELBOX（EXE[0x17338:0x56ab0]，259,960B）解密输出头 `00960500 0019535445454c424f…`（含 `STEELBOX` 明文串），熵 7.18。**外层 T-CBC 工具链正式恢复可用**（§17.4.3 关闭）。
- **pf_cipher.expand 修正**：`research/recovery/pfile/pf_cipher.py` 的 expand 曾被重建 agent 写成 `seed16[i%15]`（与已验证的 boot _M 表不一致）；已改回 `_M` 置换（与 mb_core._M 逐项一致）。roundtrip 重验 **300/300 通过**（expand 只影响 keystream 生成，不影响 enc/dec 自洽，故之前 300/300 是真通过但 keystream 错）。
- **STEELBOX 解密镜像已落盘**：`/tmp/stub/out/alloc_02730000.bin`（259,960B）。内容：头部 8B `00960500 0019` + `STEELBOX` 串；含错误串 `crc of catalog data is invalid` / `no spack` / `offset`（@image+0xb258/0xb290/0xb27d）→ 确认 STEELBOX 内有 catalog 逻辑；无内嵌 PE（MZ+PE 配对 0 命中）；`123456789` 4 处均为 ASCII 表/格式串（`%08X-%04X…` 上下文），非 catalog 魔数。**注意**：该文件在 /tmp，下次重启会丢；已验证可随时用 mb_core.py 重算（秒级），故不迁入仓库。
- **★[SEED] 命中 catalog seed（模拟器日志实证）**：`/tmp/stub/run_long.log:2250` 的 `[SEED] seed=61d41a5d278e5f0049eb617e8007b5` == `MD5("g46dgsfet567etwh501bhsd-=352")[:15]`（catalog loader seed 名，§16.2）。→ **模拟器已跑过 catalog loader（0x27ace90 → MD5 → 0x27b63d0），catalog 解密输入齐了**。
- **模拟器状态**：已进引擎消息循环（PeekMessageA/timeGetTime/Sleep 空转，hb 459M+；引擎四节读取序列在日志 2861-2955 行完整复现：56ab0/56bdc/70472/7114a/74c8c）。**不会自己往前走**（等输入），WinMain/catalog 快照断点已越过、不会再触发。catalog 已在该进程内存里，但无手段 attach 读取。
- **★纠正 §16.4/§17.4 的一个隐含误解**：64B 记录表**只存在于运行时 catalog（pkg_tree.bin，已丢），不在 EXE 静态区**。实证：按 §16.4 字段语义从 EXE[0x751d7] 解析得全垃圾（500/500 stride 失配）；`0x751d7` 处是加密的文件数据流（首 8B `e34bd0be…` 高熵）。`map_overlay.py` 原脚本无备份（transcript 里只有调用记录），但它是"读 EXE + out/pkg_tree.bin"生成的——**重建记录表的唯一路径是先拿到 catalog（运行时内存或离线解密），不是从 EXE 静态解析**。`research/recovery/records/rebuild_overlay.py`（本轮写的静态解析器）已验证走不通，保留作反例/待 catalog 到手后改写。
- **catalog 位置排查（未果，记录断点）**：EXE 全文件 8B 窗口 catalog-seed 解密扫 magic `12345678` = 0 命中；`enc(ks_cat, 8B零)` = `085d1ef07ff9a0b3` 全 EXE 搜索 0 命中；keytab（EXE[0x171f8:0x17238]）用 T-CBC(seed1)/sched(cat)/mixer(cat15)/sched(pwd)/mixer(pwd15) 五种全解不出结构。→ catalog 加密体不在 EXE 静态区，或 seed/keystream 假设仍有误。TOC（0x17008, 0x1f0）亦加密，链表不可读。
- **下一步（按优先级）**：
  1. **KPA 金矿（离线，最有希望）**：CN 记录流里的 SCN 记录明文 ≈ JP 版同名 SCN（LEAFPACK 包，MAX_DATA.PAK 可解，密钥已知）→ 用 JP SCN001 头 8B（LEAFPACK 魔数）在记录流（EXE[0x751d7:0x12939f]）里找密文对应 → 反推 per-file seed → 解 KNJ/LEAFCODE 大包。注意 per-file 是 ECB 单块，需先确认记录内容的块对齐。
  2. **反汇编 STEELBOX 找 keytab/catalog 解密逻辑**：keytab 读取（SetFilePointer 0x171f8 + ReadFile 0x40，ret=027bf28b 上下文）在日志 2128-2136 行；STEELBOX 镜像在手，可静态找 keytab 消费点。
  3. **第二模拟器实例**：另起 full_emu 跑到 [SEED] 后（~4.5 亿指令，约 20 分钟）主动 dump 内存（需先给 full_emu 加 catalog 对象 dump 代码：读 [0x2786208] 对象 + entry 表），不要干等消息循环。

### 17.9 本轮续（KPA 试错 + STEELBOX 反汇编 + seeddump 机制）

- **LEAFCODE KPA（1512 文件名变体，0 命中）**：ct=EXE[0x117f5b:0x117f63]（`1c74910bd0c44145`），pt=`LEAFCODE`。枚举 bases（LEAFCODE/leafcode/UNKNOWN_LEAFCODE/LEA/KNJ/SCN001/MAX_DATA/internall/STELPACK/QUICKBOX/password/catalog-seed名…）× exts（.DAT/.bin/.LFG/.PAK/大小写…）× prefixes（`.\`/`Z:\game\`/MAX_DATA\…）= 1512 个 MD5，sched(16B)+mixer(15B 双窗口) 双路径 dec8 验证，**0 命中**。→ per-file seed 不是 MD5（常见文件名），或 LEAFCODE 记录走 record-id 路径（16B id 做 seed，需 catalog）。
- **KNJ 记录 pt 长度矛盾（记录存疑）**：§16.4 称 table1[46] pt=340272B "== cn_KNJ_ALL.KNJ 字节级等长"，但仓库 `research/extracted/cn_KNJ_ALL.KNJ` 实际 133344B。340272 ≠ 133344。→ "等长"结论不成立（或指另一文件），KNJ 记录的明文身份待重验。CN 字库（133344B）本身是可信资产（§2.6.1），不受影响。
- **★STEELBOX 反汇编突破：catalog loader 静态对应定位（image+0x1dcc0）**：46 个 `push ebp; mov ebp,esp` 中唯一真代码簇：`push 0x1d; push 0x1f012303`（0x1f012303 = catalog seed 名编码常量，len 0x1d=29，§16.2）→ `call strdecode?` → `call MD5?`。前 8 条指令干净（sub esp,0x90 / push ebx,esi,edi / 双 push / mov esi,ecx / call / mov edi,eax / lea+push+call），之后迅速堕入 call 绝对地址垃圾（`call 0x2f55f444` 等，目标超出 0x3f778 镜像）。→ **STEELBOX 镜像只含 stage-2 前半，callees（MD5/读流/0x27b98c0 等）在已丢失的 alloc_02780000 运行时区**；静态反汇编此路不通（至少缺符号基址重定向）。`0x1030326`（strdecode xor 常量）在 image+0x2a0b0 有一处，可作未来锚点。
- **★seeddump 机制已部署**：`research/recovery/stub/full_emu.py` 的 [SEED] 探针（0x27b63d0 处）现自动 dump `stage2_2780000.bin`（0x70000）+ `steel_2730000.bin`（0x40000）+ `toc_2710000.bin`（0x10000）+ seed_hex 到 `/tmp/stub/out/seeddump/`（`FULL_EMU_SEEDDUMP` 可改路径）。语法已验。**KEYS 实例已重启**（PID 59403，FULL_EMU_CHK=chk_keys + FULL_EMU_KEYS=idle2000000,gap500000 + seeddump，`run_keys.py`/`run_keys.log`），约 20 分钟后到 [SEED]。旧实例（PID 49673，消息循环空转）保留不动。
- **旧实例日志的引擎节读取序列归档**（`/tmp/stub/run_long.log:2861-2955`）：h=107 依次 SetFilePointer→ReadFile：0x56ab0/0x12c（段表）→ 0x56bdc/0x19896（.text）→ 0x70472/0xcd8（.rdata）→ 0x7114a/0x3b42（.data）→ 0x74c8c/0x53b（.rsrc），与 §16.4 表逐项吻合。→ 引擎四节 file 偏移结论独立复现，可信。
- **下一步**：
  1. 等 KEYS 实例 [SEED-DUMP]（查 `run_keys.log` + `out/seeddump/`），拿运行时 stage-2/steel/toc 内存镜像 → 离线找 catalog 对象（[0x2786208] + entry 表，§16.8A.1）。
  2. KEYS 注入若把引擎推进到 SCN 加载 → fetch wrapper MD5（文件名）+ per-file 解密 → dec_log/seed 自然产出 → 直接拿 seed 解记录流。
  3. catalog 对象结构未知——seeddump 到手后，搜内存里的 193×64B 记录表特征（12B 零头 + 已知 id 如 table1[46] `35e180b5…ed310bbf`）。

### 17.10 本轮（KEYS 全链跑通 + catalog 静态全逆向 + seeddump v2）

**A. 模拟器 bug 双杀 + 全链跑通（run_keys.log，1553 万行）**：
- **bug① `run_keys.py` 组了 `env` 却没传进 Popen** → 上轮 KEYS 实例（PID 59403）跑 4.7 亿指令，FULL_EMU_KEYS/CHK/SEEDDUMP 全没生效，零注入空转。已修（`env=env` + 同步仓库版 full_emu.py 到 live 树）。
- **bug② `idle2000000` 解析 `[5:]` 切掉首位变 0** → 改 `_kv` helper（兼容 `idle2000000`/`idle=…`/纯数字）。语法已验（2000000/500000）。
- **本轮 KEYS 实例全链跑通**：[SEED]（line 2253，catalog seed `61d41a5d…`==MD5(名)，复现）→ [SEED-DUMP]（stage2/steel/toc+6 个 heap 窗口）→ [chk2] 快照（`chk_keys.stub` 49MB，eip=0x27ace90）→ **[keys] 注入在 idle=2000000 生效**（line 10016190，wndproc 0x409c40 回应：WM_KEYDOWN×2 + LBUTTON ×6 全进 DefWindowProcA，继而 AnimatePalette + GlobalLock 读图序列 `00430ec2→…`）。
- **但**：注入后无新 OpenFile（游戏停在标题画面内响应，未推进到 SCN 加载）；实例最终被 3000s 超时 kill（`run_keys_launcher.out`），非自然退出。**下一步**：调注入节奏/键位（当前 DOWN/DOWN/RETURN/UP/RETURN 轮转 + 点击网格），或多次注入推进菜单。
- **[PF] 探针误读参数已定位**：0x27b6470 真约定 = `(dst, count, ksobj)`（dst=刚 HeapAlloc 的 9B 串缓冲，count=1，ksobj=0x1400fb0），探针按 `(ksobj,data,count)` 读出 `data=1/cnt=20975536` 垃圾。**修法**：按 (dst,count,ksobj)+顺带 log ecx。本轮仅捕获 2 条（STELPACK/QUICKBOX 魔数验证，khead 全 0 可疑——修探针后重跑确认）。

**B. catalog 静态全逆向（seeddump stage2 镜像 + capstone，全部离线可复现）**：
- **seeddump 确定性**：v2 四文件与已入库 v1 **逐字节相同**（stage2/steel/toc/seed_hex）。
- **strdecode 全解**：`0x27be636` 表基址 `0x278f59c`，`off=((C^0x1030326)-0x1030326)&0xffff`，逐字节 `ah^=al; al=ror(al,1)`。已验证解出 catalog 名（`g46dgsfet…-=352`，29B）；同机可解全部内嵌串（password/STELPACK/QUICKBOX/internall…）。
- **MD5 wrapper `0x27a9950`**：栈上 init 常量 + `strlen` 循环（`lea edi,[eax+1]` 特征），标准 MD5。
- **catalog loader `0x27ace90` 全链**：strdecode(0x1d,`0x1f012303`) → MD5 → strfree → `sched 0x27b63d0` → `alloc 0x27b5d30(0x20)` → 流读 `0x279b4f0` → vcall → **multiblock `0x27b6490`** → 对象填充 `0x27ad12c`。
- **multiblock `0x27b6490` = CBC（IV=0，同 ks，`P[0]=dec8(C[0])，P[k]=dec8(C[k])^C[k-1]`）**：每块调一次 `0x27be69c`（ks 不变）+ 异或链；交错 `[esi-2]/[esi+2]` 读数 + 先 xor 后存序化简即标准 CBC decrypt。已实现 `pf_cipher.dec_cbc/enc_cbc`，roundtrip 自测通过（sched+mixer 路径）。**端到端待真实 catalog 密文校验**。
- **catalog 对象布局 `0x27ad12c`**：`+0xc` buf / `+0x18` table1基址 / `+0x1c` table1计数（stride **8**，`[entry+4]+=buf` 重定位）/ `+0x20` table2基址 / `+0x24` table2计数（stride **0x18=24**，同法重定位）。全局指针 `[0x2786208]`（本 dump 为 0，loader 未跑完）。
- **per-file seed 链钉死**：`0x27ad7f0`(ecx=catalog, idx, table2entry=`0x27ac3f0` 返回) → `0x27ad260`：`mixer(edi+0x40, esi=table2entry首字节)`（**seed = 24B entry 前 15B**，含被重定位的 `[entry+4]` 指针！）→ STELPACK/QUICKBOX/`0x1f422342` 三魔数单块验证 → 16B id 存 `edi+0x88`（消费者：`0x27a7eb6` 索引表、`0x27d4861` 数据通路）。数据解密走同 mixer 态 `edi+0x40`：单块 `0x27b6470`×N + multiblock `0x27b6490`×10 处。
- **含义**：record seed 含堆地址（`[entry+4]+=buf`），离线复刻需先有 catalog 明文 + buf 基址——两者都在 `chk_keys.stub` 快照（loader 入口 eip=0x27ace90，45MB 已落盘 /tmp，未入库）+ record-construct 时刻堆。**下一步**：RESUME 快照单步 loader，或等注入推进到 fetch（[PF] 真读数 + [SEED-MIXER]）。
- **mount 路径**：`0x27bf72d` → mount(`0x27aa920`，读 `[0x2786268/0x278626c]` 配置）→ `0x27a8100`（缓冲流分配）→ `0x27ad1e0`（vtable `0x2793068` 流对象）→ loader。引擎文件请求（KNJ/LEAF/OP_/TITLE）走 `OpenFile→_resolve_file→PAK 回退`（本轮 139 次 opens，全 JP 回退数据——**CN 真数据从未被读取，确认 spack VFS 拦截在 shell 层，引擎只能拿到 JP 影子**）。

**C. 本轮资产（`research/recovery/catalog/`，heap 新增，其余复现确认）**：
- `seed_hex.txt` / `stage2_2780000.bin` / `steel_2730000.bin` / `toc_2710000.bin`（v2 == v1 字节级）
- `heap_81000000..05.bin`（6 窗口 used-span：19264/480/576/672/4080/5504B；esi `0x1400fb0` 所在窗口#4 尾部仅见 `68307902…`，seed 名/MD5 在堆 dump 均 MISS——dump 时刻 loader 刚入口，对象尚未构建）
- `/tmp` 未入库：`chk_keys`（55MB，WinMain 快照）+ `chk_keys.stub`（49MB，loader 入口快照，**下一轮 RESUME 起点**）+ `run_keys.log`（1553 万行）+ `alloc_02730000.bin`（可秒重算）

**D. 下一步（按优先级）**：
1. **RESUME `chk_keys.stub` 单步 loader**（`FULL_EMU_RESUME`）：拿 catalog 密文位置+长度 → `dec_cbc` 离线解 → table1/table2 → record seed（含重定位 buf 基址快照内可读）。
2. **修 [PF] 探针参数序**（dst/count/ksobj+ecx）后重跑 KEYS：抓 record-construct 时刻真 seed + [SEED-MIXER]。
3. 注入迭代：游戏已响应按键但停在标题内——换键位/多轮注入推进到 SCN 加载（fetch → per-file 解密自然发生）。
4. catalog 明文到手后：table2 entry → `ks68_mixer(entry[:15])` → 解记录流 → 验 SCN001/KNJ/LEAFCODE 锚点（§17.9 KPA 金矿仍有效）。

### 17.11 本轮（RESUME 链打通 + MB/CAT/OK 探针 + loader 分支诊断）

**A. RESUME 快照链验证通过（`FULL_EMU_RESUME=chk_keys.stub`，冷启动 20min→60s）**：
- 两轮 RESUME（`run_resume_test.log` / `run_resume_probe.log`）：`resume restored eip=027ace90 attrs=54 regions=29`，随即 `[SEED] seed=61d41a5d…` 复现 → 快照链可用。实例随后进消息循环空转，无需再冷启动。
- **SEED ret=027acece**（本轮探针新增 `ret=[esp]`）：refire 的 sched 是 loader 自身 `0x27acec9 call 0x27b63d0`（返回 loader 内部），**不是** per-record `0x27ad2e0`。→ 调用点归属钉死。

**B. 探针三件套就位（`full_emu.py`，未提交，`M research/recovery/stub/full_emu.py`）**：
- **[MB] `0x27b6490`**（前 40 条）：`ks=ecx, data=[esp+4], cnt=[esp+8]`，log data 头 16B + ks 头 16B。
- **[CAT] `0x27ad12c`**（一次性，抓到即 `emu_stop`）：读 esi+0xc(buf)/0x18(t1)/0x1c(n1)/0x20(t2)/0x24(n2)，写 `cat_info.txt` + `cat_buf.bin`(64KB) + `cat_t1.bin`(n1*8) + `cat_t2.bin`(n2*0x18) 到 seeddump，停机。
- **[OK] `0x27ad385`**（前 20 条）：`edi`=record obj，log `mixer32=mem[edi+0x40:32]` + `id16=mem[edi+0x88:16]` —— record-seed 来源逐条记录。
- **[PF] 参数序已修正**（dst/count/ksobj+ecx）：`[PF] #1 dst=014030a0 cnt=1 ksobj=01400fb0`，`khead=68307902…`（= vtable `0x2793068` 对象，mixer 读对象字节作 seed）。修之前 `data=1/cnt=20975536` 垃圾作废。

**C. 反常：loader 自己的 catalog-MB 没现身（分支诊断进行中）**：
- RESUME 两轮都是：`SEED(ret=027acece)` → `[PF]#1-2` → `[MB]#1-5`（**全是引擎节解密**，`ks=02786b60` 全局；data `029f/02a1/02a4/02a6/02a8`，cnt `37/13074/411/1896/167`，紧跟 ReadFile `0x56ab0/0x56bdc/0x70472/0x7114a/0x74c8c` file 偏移，`cnt*8=floor(len/8)*8` 全覆盖）→ 消息循环。**[OK]/[CAT] 零触发**。
- loader 自己的 catalog-MB（栈 ks，非 `0x2786b60` 全局）一次都没 log —— loader 跑了自己的 sched（SEED ret 作证），却没走到 multiblock。
- 假设：loader 在流读/vcall 后**走了 fail 分支 `0x27aceed`** 而非 success `0x27aceef`（spack VFS 下 CN catalog 读不到 → 回退 JP 影子路径，引擎节照常解密映射）。印证 §17.10-B mount 段"CN 真数据从未被读取"。
- **下一步（先做这个，再谈注入）**：`0x27aceed` / `0x27aceef` 加 fail/success 双探针（或 log vcall + `0x279b4f0` 读数字节数），RESUME 重跑一次（~60s 到 MB#5）看分支 verdict。若确为 fail → catalog 密文位置/长度从分支前的流读参数拿（[MB] 抓不到就 hook 流读），`dec_cbc` 离线解仍可行；若 success 但 catalog-MB 形态不同（如 ks 在栈而非 ecx）→ 按实际约定修 [MB] 探针。

**D. 本轮 /tmp 资产（未入库，重启会丢）**：`run_resume_test.log`（310KB）+ `run_resume_probe.log`（619KB，caller-logging 版）+ `out/chk_keys`（57MB）+ `out/chk_keys.stub`（51MB，RESUME 起点）。`research/recovery/catalog/` 无新增（seeddump v3 与 v1/v2 同值，未入库）。

---

## 18. 2026-09-20（★重大战略转向：日文原生先行 + Akkera102 权威规范接入 + 汉化无缝挂载路线图★）

### 18.1 战略重构背景与决策依据
- **原路线困局**：此前开发直接将“汉化版脱壳”作为前置阻塞条件（Phase A），导致开发停留在 Unicorn 汇编探针、分支诊断与内存转储调试（§17.11 停在 loader 内部 fail 分支），原生 Swift 引擎开发（Phase C/D/E）无法大规模展开。
- **决策裁决**：
  1. **阶段性目标切换为日文原版原生移植先行**（终极目标保持汉化双语版不变）。
  2. **双轨并行，零返工架构**：
     - **主干轨道（白盒原生研发）**：日文版所需全部资产（403/403 原版文件、LFG 图像、197 个 SCN 脚本、原版 KNJ 字库、LAC 25 首 Ogg / 13 首 WAV）100% 准备就绪且无任何加密。采用纯 Swift + Metal 直接实现现代高效运行时，迅速达到序章至 13 个结局全通关。
     - **辅线轨道（黑盒数据提取）**：所有中文逆向资产（`pf_cipher.py`、`full_emu.py`、`mb_core.py`、`chk_keys.stub` 60秒恢复快照）**完全保留在库中**，作为独立逆向子项目在后台继续推进，绝不弃绝。
     - **无缝挂载契约**：根据 §13.1 结论，汉化版是整条消息自由重写 `(scn, msg) -> 中文字符串`。日文版构建的是完整的消息排版与状态机底座，已就绪的 `TranslationStore.swift` 作为热插拔翻译层（有 `zh_text.json` 即渲染中文，无则走原生日文）。日文引擎的每一行代码（画面、选择支、音频、存读档）在汉化版中 100% 原样继承，零重构成本。

### 18.2 前人逆向工程文献接入：Akkera102 Ex.21 / Ex.22 权威规范
针对原版《雫》（1996/1998）的引擎细节，正式引入 Akkera102 官方开发维基（`https://akkera102.sakura.ne.jp/gbadev/?Ex.21` & `?Ex.22`）的核心逆向成果，彻底补齐 SCN 虚拟机与字库规范：
1. **虚拟机双层结构（对齐 Akkera script.c）**：
   - **外层事件解析器（`ScriptParserScn`）**：负责全局状态，处理背景（`0x0a` MAX_S）、立绘（`0x22` MAX_C / `0x24` 前景特写）、特殊效果（`0x01` 扭曲暗化）、脚本跳转（`0x04` JUMP）、选择支（`0x05` SELECT）、条件跳转（`0x3d/0x3e` IF_EQ/NE）、标志位加减（`0x47/0x48` FLAG_SET/ADD）、BGM（`0x6e`）、结局触发（`0x7e`）。遇到 `0x54` 调起内层。
   - **内层消息解析器（`ScriptParserTxt`）**：负责逐字渲染与行内控制。
     - `& 0x80`：Leaf 专有字形码。
     - `$`：消息结束，交回外层。
     - `p`：等待翻页（Page update wait）。
     - `k / K`：等待按键点击（Key wait）。
     - `r`：换行（Newline）。
     - `F`：全屏白闪（ScreenImgFlash）。
     - `Q`：屏幕震动（Screen Shake）。
     - `M`：BGM 控制（`Mf` 淡出、`Ms` 停止、`M00-M25` 切曲）。
     - `P`：PCM 音效（`Pl` 加载、`P...` 播放、`Pf` 淡出、`Ps` 停止）。
     - `C / S / D / A`：行内立绘与背景快速切换。
2. **Leaf 字形码真相（1853 槽连续索引）**：
   - 叶码去高位后即原版字库槽位索引：`0x0000` = 全角空格，`0x0001` = ■ 方块，`0x0002` = あ，`0x0003` = い，`0x0004` = う ...
   - 原版 `KNJ_ALL.KNJ`（133,344B）以 Column-Major（3列×24行）直接连续索引。日文排版无需任何映射表，天然 100% 吻合。
3. **全 13 个结局编号与判定标准（0x7e Opcode）**：
   - 0: 卒業式 / 1: 瑞穂 BAD / 2: 破壊 / 3: トースター / 4: 佐織 HAPPY / 5: 佐織 BAD / 6: 瑞穂 HAPPY / 7: 瑞穂 BAD 2 / 8: True Ending / 9: 瑠璃子 HAPPY / a: 大田さん / b: 異次元 / c: 異次元 BAD。
   - 瑠璃子 HAPPY 结局判定 Flag = `0x46`。

### 18.3 移植阶段与实施路线图 (Phase Plan)

#### Stage 1: 日文文本排版与字库管线闭环 (预计 2~3 天)
- [ ] 在 `Knj.swift` 中建立原版 1853 Leaf 码直连索引（基于 Column-Major 24x24 1bpp 解码）。
- [ ] 升级 `ShizukuRender/TextRenderer.swift`，支持消息内嵌控制符（`p` 翻页、`k` 按键等待、`r` 换行）。
- [ ] 使用 `shizuku` CLI 渲染导出 SCN001 前 20 条消息，目检日文排版连贯性。

#### Stage 2: 原生音频引擎搭建 (预计 2 天)
- [ ] 在 `ShizukuEngine` 中创建基于 `AVAudioEngine` 的音频管理器。
- [ ] 接入 `bgmfile.PAK` 中提取的 25 首 Ogg Vorbis 音轨，实现无缝循环与淡入淡出（支持 `0x6e` 及内嵌 `M` 指令）。
- [ ] 接入 `soundds.PAK` 中提取的 13 首 WAV 音效（支持内嵌 `P` 指令）。

#### Stage 3: 虚拟机与分支闭环 (预计 3~4 天)
- [ ] 对照 Akkera102 `ScriptParserScn` 与 `ScriptParserTxt` 补全 `Engine.swift` 的全部 Opcode 分支。
- [ ] 校准 `0x05` SELECT 操作码的跳转偏移，验证选择支跳转准确性。
- [ ] 实现原生存读档系统（参照 MGLVNS `sizuku_file.c`，以 JSON 格式持久化到 Application Support）。
- [ ] 接入 13 个结局判定（`0x7e`）与通关标志位记录。

#### Stage 4: macOS 原生交互与应用发布 (预计 2~3 天)
- [ ] 实现原生标题主菜单（New Game, Load Game, Gallery, Settings）。
- [ ] 实现 Backlog 对话历史回放与 Skip 快进模式。
- [ ] 适配 Retina 高清整数倍缩放、全屏切换与菜单栏快捷键。
- [ ] 运行 `package.sh` 生成已签名的 `Shizuku.app`，完成序章至全结局回归测试。
- **交付里程碑 M1**：发布首个 100% 原生可玩的《雫～しずく～》日文版 macOS App！

#### Stage 5: 汉化终局挂载与双语正式版发布 (并行/后续)
- [ ] 恢复 `chk_keys.stub` 探针测试，诊断 loader `0x27aceed` 失败原因，获取 Catalog 密文流。
- [ ] 用 `pf_cipher.py` 离线解密 737KB 记录流，提取 195 个 CN SCN 译文，导出 `research/recovery/text/zh_text.json`。
- [ ] `zh_text.json` 放入 Bundle Resources，`TranslationStore` 自动热加载。
- [ ] 在系统菜单添加“语言切换（日文原版 / 中文汉化版）”与“字体样式（复古点阵 / 现代矢量）”。
- **交付里程碑 M2**：双语正式版发布！

### 18.4 下一步行动清单 (Immediate Actions)
1. 修改 `ShizukuRuntime/Sources/ShizukuEngine/Engine.swift` 与 `Knj.swift`，接入 1853 Leaf 码直连索引。
2. 运行 `swift run --package-path ShizukuRuntime shizuku . -scn 1 -blk 1 -max 10` 生成首批日文对照帧。

---

## 19. 2026-09-20（★里程碑 M1 达成：macOS 原生日文正式版交付 & 阶段五汉化双语攻坚前瞻★）

### 19.1 阶段一至阶段四交付成果总结

按照 `MILESTONES.md` 敏捷小里程碑体系，已高质量完成 M1 原生日文版的全部研发、测试、交互打磨与打包：

1. **阶段一（Typography）：日文字库与文本排版管线**
   - **M1.1**: 原版 `KNJ_ALL.KNJ`（133,344B）直接索引（`leaf == 0` 为空格，`leaf > 0` 映射到 `leaf - 1` 槽位，Column-Major 3列×24行 1bpp 解码），支持 `cn_KNJ_ALL.KNJ` 回退。
   - **M1.2**: 修复 `LZS.decodeInv` 初始环形缓冲滑动窗口索引至 `0xFEE`，实现全部 197 个 SCN 脚本解压逐字节完全一致；支持 `r`（换行）、`k/K`（按键等待）、`p`（翻页等待）控制符；调优 640x400 半透明毛玻璃底板、28px 行高与 24px 网格。

2. **阶段二（Audio）：原生音频子系统集成**
   - **M2.1**: `AudioController.swift` 基于 `AVAudioEngine` 构建原生音频管线；从原版 `LAC\0` 格式 PAK（`bgmfile.PAK` / `soundds.PAK`）解包并转存 25 首 OGG BGM 与 13 首 WAV SFX。
   - **M2.2**: 响应 `0x6e`（BGM切换）与 `0x7d`（BGM停止），基于 `AVAudioPCMBuffer` 与 `.loops` 选项实现多音轨无缝跨场景循环播放。
   - **M2.3**: 响应内嵌 `P` 系列指令，独立 `sfxPlayer` 声道实时混音（P001.WAV~P013.WAV）。

3. **阶段三（Engine & Logic）：虚拟机核心与游戏闭环**
   - **M3.1**: 补全 Akkera Ex.22 核心操作码：`0x01`（特效暗化/显示文字）、`0x04`（JUMP 跨脚本跳转）、`0x3d/0x3e`（条件字节跳转）、`0x47/0x48`（标志位操作）。
   - **M3.2**: 校准不定长 `0x05` SELECT 选择支字节解析与跳转相对偏移。
   - **M3.3**: `SaveManager.swift` 实现原生 JSON 存读档（普通槽 1..99、快速存档 0、自动存档 -1、system.json），覆盖 SCN、Block、PC、Flag 数组、场景与分页。
   - **M3.4**: 接入全 13 个结局（`0x00`~`0x0c`）与 `0x7e` END_CHK 判定、全局通关记录、多周目 Flag `0x46`（瑠璃子 HAPPY）继承与 Flag 0 状态演变。

4. **阶段四（App & M1 Release）：macOS 原生交互打磨与发布打包**
   - **M4.1**: `MetalGameView.swift` 支持键盘（Space/Enter/上下键/数字键1..9/Tab跳过/S快速存/L快速读）与鼠标推进；等比 640:400 视口拉伸与全屏切换（Cmd-Ctrl-F）。
   - **M4.2**: 原生标题主菜单（はじめから、つづきから、エンディング一覧、終了）与 MUS00.OGG；Backlog 历史对话面板（滚轮向上/左方向键/B键呼出），使用原版 24x24 点阵字体渲染历史记录；全 13 结局图鉴与通关星标。
   - **M4.3**: 完善 `package.sh`，生成独立签名应用 `build/Shizuku.app`（集成 397 个全量资产）；21 项单元测试 100% 通过（`swift test`）。
   - **里程碑 M1（macOS 原生日文版）正式发布交付！**

---

### 19.2 阶段五：汉化文本解密与双语正式版推进指南 (Stage 5: Milestone M2)

- **目标**：在已完全跑通的 M1 原生日文版底座上，提取全部中文剧本文本并生成 `zh_text.json`，通过已内置的 `TranslationStore.swift` 实现中日双语无缝热切换。
- **关键资产状态**：
  - `research/recovery/pfile/pf_cipher.py`：T-CBC / expand 置换解密引擎（300/300 roundtrip 验证通过）。
  - `research/recovery/stub/full_emu.py`：Unicorn x86 模拟器（包含 loader 探针、heap 快照机制与按键注入）。
  - `research/recovery/text/zh_text.json`：已验证首句中文锚点 `{"1:5": "然后不知在某个不经意的瞬间，我察觉到这个无聊的世界已经失去了色彩和声音。"}`。
  - `ShizukuRuntime/Sources/ShizukuEngine/TranslationStore.swift`：已实现 `(scn, msg)` 映射查询，若有译文优先使用，无译文自动回退原生日文。
- **后续任务**：
  1. **M5.1**: 诊断或提取中文密文流，批量解密并生成全量 `zh_text.json`。
  2. **M5.2**: 将 `zh_text.json` 放置到 `Resources/gamedata/`，在 UI 菜单增加“中 / 日”语言切换开关，打包交付 **Milestone M2**。

---

## 20. 2026-09-20（★重大技术突破与原版体验深度对齐：行内指令全解、开场动画还原、弟切草全屏排版与 ESC 菜单系统★）

> ⚠ **本节多处事实已被 §21 纠正（暗化系数、OP 曲目 MUS16、OP 帧数、ESC 菜单顺序、事件统计数）；执行前先读 §21.1 对照表。**

### 20.1 实机审查与核心根因深度诊断 (Ground Truth)

在对 M1 初版构建进行实机审查与 1996 年原版 Leaf Visual Novel System（LVNS 源码 `mglvns` 及 Akkera102 移植项目规范）深度对照后，彻底定位了导致原版体验偏差的四大技术根因：

1. **Leaf Logo 开屏音效与主菜单音乐错位**：
   - 经实测，`research/extracted/bgm/MUS00.OGG` 时长仅 **5.5 秒**，实为原版 **Leaf 社商标开屏 Jingle 音效**（对应 `mglvns` 中 `sizuku_jingle.c` 的 CD-DA Track 2）！
   - 原版真正的 OP 开场曲与主菜单音乐是长达 219 秒的 `MUS16.OGG`（对应 `sizuku_op.c` 的 `opdata` 曲）。
   - 此前代码将 `MUS00` 误作主菜单循环 BGM，导致 Logo 丢失且 5.5s 开屏短音效被死循环播放。
2. **Leaf 社 Logo 与完整 OP 开场动画序列缺失**：
   - 原版资源完整齐备：`LEAF.LFG`、`OP_S00`~`OP_S17.LFG`（涙の雫 18 帧滴落动画）、`OP_V0`~`OP_V1.LFG`（视觉 CG）、`OP_L0`~`OP_L8.LFG`（瑠璃子 9 帧动态）。
   - 原版标准时序为：
     1. `LEAF.LFG` 居中显示 + 播放 5.5 秒 `MUS00.OGG`（按键跳过）。
     2. 循环播放 `MUS16.OGG`，依次播放 `OP_S00`~`OP_S17` 滴泪动画 -> `OP_V0` 闪现 -> `OP_S` 渐变 -> `OP_V1` -> `OP_L0`~`OP_L8` 瑠璃子动画（按任意键跳过）。
     3. 进入标题画面：`TITLE0.LFG` 底板 + `TITLE.LFG` 叠加，显示原版 24×24 点阵字体菜单。
3. **“进游戏只有两张 CG、没有角色立绘、BGM 不变”的重大突破发现**：
   - 在 Leaf 原版架构中，全剧本的 **64 张角色立绘**（`MAX_C*.LFG`）、**56 张背景/CG**（`MAX_S*`, `VIS*`, `HVS*`）以及游戏内 BGM 切曲与音效触发，**全部通过文本消息内的行内标记（Inline Tokens）实时驱动**：
     - `'B'` / `'E'`：加载背景 CG（如 SCN002 的 `B070808` → 加载 `MAX_S07`）
     - `'C'`：加载角色立绘（如 SCN007 的 `Cr51` → 在右侧加载 `MAX_C51`）
     - `'S'`：背景与立绘同时切换（如 `MAX_S03` + `MAX_C01`）
     - `'D'`：清空角色立绘（`Da` 清空全部，`Dl`/`Dc`/`Dr` 清空特定位置）
     - `'A'` / `'a'`：三人立绘同屏排版
     - `'V'` / `'H'`：视觉 CG 全屏显示（`VIS*.LFG` / `HVS*.LFG`）
     - `'M'`：BGM 控制（`Mf` 淡出、`Mn01` 预备、`M03` 播放 Track 3、`Ms` 停止）
     - `'P'`：PCM 音效触发（`P01`~`P13`）
     - `'F'`：全屏白闪特效（Flash）
     - `'Q'`：屏幕震动特效（Shake）
   - 此前 `Scn.swift` 将这些控制符当作未知字符直接过滤丢弃，导致虚拟机从未收到立绘、CG 和切曲指令！这正是原版画面单调、没有立绘的根本原因。
4. **角色立绘尺寸与坐标真相**：
   - 原版立绘 `MAX_C*.LFG` 解压后图像高度即为 **400px**（与屏幕等高！）。
   - 在 `mglvns` `sizuku_etc.c` 中：立绘绘制坐标为 `y = 0`（不需要 `400 - 200` 等复杂计算）。
   - X 坐标：左侧 `'l'` = 0，居中 `'c'` = 160，右侧 `'r'` = 320（对应 640 宽度的 3 个立绘栏位）。
5. **弟切草式全屏幕文字滚动排版真相 (Sound Novel Layout)**：
   - 《雫》是 Sound Novel 典范，非现代美少女游戏的底部对话框。
   - 全屏 640×400 画面即为文本画布：
     - 文本起始坐标：`x = 20`, `y = 18`。
     - 字符网格：25 列 × 13 行；列步进 24px，行高步进 28px。
     - 画面暗化：当存在文字显示时，底层背景图像进行 35% 变暗处理（`latitude_dark`，即 `pixel * 11 / 16` 或 `rgb * 0.65`）。
     - 文字样式：纯白 `RGB(240, 240, 240)`，并在 `(x+1, y+1)` 处绘制 1px 纯黑硬阴影 `RGB(10, 10, 10)`。
     - 滚动与清屏控制：行内 `k`（WAIT_KEY）暂停等待按键，点击后在下方行继续追加文本；行内 `p`（PAGE）暂停等待按键，点击后清屏从顶行重新开始。
6. **ESC 游戏内系统菜单与可视化「しおり」存档系统**：
   - 游戏中随时按 `ESC` 键或点击鼠标右键呼出原版 6 项系统菜单：
     1. `文字を消す`（隐藏文本层，展示全屏纯净原画，点击任意键恢复）
     2. `セーブする`（打开书签保存界面）
     3. `ロードする`（打开书签加载界面）
     4. `シナリオ回想`（查看 Backlog 对话履历）
     5. `一つ前の選択肢に戻る`（直接回滚到上一个选择支节点）
     6. `ゲーム終了`（返回标题画面或退出游戏）
   - 「しおり (Bookmark)」系统：采用 6 槽位可视化卡片，显示存档时间、剧本章节与预览文字，配备覆盖确认弹窗。

---

### 20.2 本会话已完成成果 (Completed in this Session)

1. **M1 原生日文版发布与安装包交付**：
   - 生成 51MB 独立 DMG 镜像 `build/Shizuku.dmg` 与 `build/Shizuku.app`（集成 403 个原版资产、自签名、内嵌 Applications 软链接与高分辨率 `AppIcon.icns`），已实测挂载与运行。
2. **M4.4 第一阶段：SCN 剧本行内指令全量解析器 (Commit `b449e76`)**：
   - 在 `ShizukuRuntime/Sources/ShizukuCore/Scn.swift` 中定义：
     - `InlineAction`：覆盖 `bg`, `visual`, `hVisual`, `portrait`, `clearPortrait`, `bgAndPortrait`, `multiPortrait`, `bgm`, `sfx`, `flash`, `shake`。
     - `MessagePauseType`：`.waitKey` (`k/K`), `.pageBreak` (`p`), `.messageEnd` (`$`)。
     - `MessageSegment`：包含当前片段触发的 `actions`、文本行 `lines`、暂停类型 `pause`。
     - `Message.segments`：将消息流结构化切分为连续执行的分段数组。
   - **实测战果**：遍历全部 197 个 SCN 脚本，精准捕获此前被过滤丢弃的：
     - **544 个立绘事件 (`MAX_C*.LFG`)**
     - **278 个背景/CG 事件 (`MAX_S*`, `VIS*`, `HVS*`)**
     - **493 个 BGM 切曲与控制事件 (`Mxx`, `Mf`, `Ms`)**
     - **252 个 PCM 音效事件 (`Pxx`)**！
3. **单元测试回归 100% 全绿**：
   - 运行 `swift test --package-path ShizukuRuntime`，21/21 项 XCTest 单元测试全部通过（0 失败）。
4. **里程碑计划更新**：
   - 在 `MILESTONES.md` 中建立 M4.4 ~ M4.7 四个子任务，将原版对齐拆解为可渐进交付的清晰单元。

---

### 20.3 下一会话开箱即用的具体执行步骤清单 (Next Steps Implementation Guide)

新会话请**直接按照以下 5 个步骤依次执行**，无需重新调研：

```
[M4.4 Part 2: Engine 接入] → [M4.5: 弟切草全屏排版] → [M4.6: Jingle/OP/Title 动画] → [M4.7: ESC菜单与しおり] → [验证与打包]
```

#### 步骤一：`Engine.swift` 行内指令执行与分段推进 (M4.4 Part 2)
- **目标文件**：`ShizukuRuntime/Sources/ShizukuEngine/Engine.swift`
- **实现要点**：
  1. **状态机扩展**：
     - 在 `ShizukuEngine` 中添加：
       ```swift
       public private(set) var currentSegmentIndex = 0
       public private(set) var displayedLines: [[Int]] = []
       public private(set) var lastSelectSavePoint: SaveState? // 为「一つ前の選択肢に戻る」保留
       ```
  2. **消息触发逻辑（`case 0x01`, `case 0x54`）**：
     - 加载 `currentMsg` 时，初始化 `currentSegmentIndex = 0`，`displayedLines = []`。
     - 调用内部方法 `applyCurrentSegment()`：
       - 遍历 `currentMsg.segments[currentSegmentIndex].actions`：
         - `.bg(name)` / `.visual(name)` / `.hVisual(name)`：设置 `scene.bgName = name`，并自动清除现有普通立绘 `scene.portraits.removeAll()`。
         - `.portrait(pos, name)`：解析 pos（`l` -> x=0, `c` -> x=160, `r` -> x=320, y=0），加入 `scene.portraits`。
         - `.clearPortrait(pos)`：若 `pos == "a"` 清空所有，否则根据位置过滤。
         - `.bgAndPortrait(pos, chrName, bgName)`：同时更新背景与对应位置立绘。
         - `.multiPortrait(entries)`：同时设置多位角色立绘。
         - `.bgm(action, track)`：若 track > 0 调用 `audio?.playBGM(number: track)`；若 action == "f" 或 "s" 调用 `audio?.stopBGM()`。
         - `.sfx(name)`：调用 `audio?.playSFX(name: name)`。
         - `.flash`：设置 `scene.flash = true`。
       - 将当前分段的文本行 `lines` 追加到 `displayedLines` 中。
       - 进入 `phase = .awaitingMessage`。
  3. **消息推进逻辑（`advanceMessage()`）**：
     - 若当前分段的 `pause == .pageBreak`：用户点击后清空 `displayedLines = []`。
     - 若 `currentSegmentIndex + 1 < currentMsg.segments.count`：
       - `currentSegmentIndex += 1`
       - 执行 `applyCurrentSegment()`
     - 否则：当前消息全部播完，`currentMsg = nil`，`displayedLines = []`，恢复 `phase = .running`，继续 `step()`。
  4. **选择支恢复点（`case 0x05 SELECT`）**：
     - 在显示选项前，自动执行 `lastSelectSavePoint = captureSaveState(slot: -99)`。

#### 步骤二：`SceneComposer.swift` 弟切草全屏排版与硬阴影 (M4.5)
- **目标文件**：`ShizukuRuntime/Sources/ShizukuRender/SceneComposer.swift`
- **实现要点**：
  1. **废弃旧底部消息框**：
     - 移除半透明底部小矩形框（`y: 280, h: 110`）。
  2. **全屏背景 35% 暗化（`latitude_dark`）**：
     - 当 `engine.phase == .awaitingMessage` 或 `displayedLines` 非空时，在渲染文字前，将合成画面像素进行暗化：
       ```swift
       let factor = 0.65 // 35% dim
       for i in stride(from: 0, to: pixelCount * 4, by: 4) {
           pixels[i]   = UInt8(Double(pixels[i])   * factor)
           pixels[i+1] = UInt8(Double(pixels[i+1]) * factor)
           pixels[i+2] = UInt8(Double(pixels[i+2]) * factor)
       }
       ```
  3. **全屏 25列×13行流式文字排版**：
     - 基准坐标：`startX = 20 * scale`，`startY = 18 * scale`。
     - 行距步进：`lineAdvance = 28 * scale`。
     - 列距步进：`colAdvance = 24 * scale`。
     - 遍历 `engine.displayedLines`：
       - 对每个 Leaf 码，先在 `(x + scale, y + scale)` 处用纯黑 `(10, 10, 10, 255)` 绘制 1px 硬阴影。
       - 再在 `(x, y)` 处用亮白 `(240, 240, 240, 255)` 绘制字形本体。
  4. **等待输入指示光标**：
     - 若 `engine.phase == .awaitingMessage`，在最后一行最后一个字右下方绘制原版闪烁光标 `▼`。

#### 步骤三：`MetalGameView.swift` 启动序列与原版双层标题 (M4.6)
- **目标文件**：`ShizukuRuntime/Sources/ShizukuApp/MetalGameView.swift`
- **实现要点**：
  1. **游戏视图模式状态机**：
     ```swift
     enum GameMode {
         case jingle           // Leaf Logo + MUS00.OGG
         case openingAnim      // OP 动画序列 + MUS16.OGG
         case titleMenu        // TITLE0.LFG + TITLE.LFG 双层主菜单
         case inGame           // 正常游戏
         case escMenu          // ESC 呼出的 6 项系统菜单
         case saveSlotPicker   // しおり 保存
         case loadSlotPicker   // しおり 读取
         case hideText         // 文字を消す (纯原画鉴赏态)
     }
     ```
  2. **Jingle 阶段**：
     - 加载并居中渲染 `LEAF.LFG`。
     - 播放单次 `MUS00.OGG`（5.5s），音频播放完毕或用户按键/鼠标点击后跳入 `openingAnim`。
  3. **Opening 动画阶段**：
     - 开始循环播放 `MUS16.OGG`。
     - 定时器逐帧步进（支持点击跳过直接进 Title）：
       - `OP_S00` ~ `OP_S17.LFG`（涙の雫滴落）
       - `OP_V0.LFG`（视觉CG）
       - `OP_S.LFG`
       - `OP_V1.LFG`
       - `OP_L0` ~ `OP_L8.LFG`（瑠璃子特写动态）
  4. **Title 菜单阶段**：
     - 底图使用 `TITLE0.LFG` 与 `TITLE.LFG` 双层像素合成。
     - 渲染 4 个原版选项：
       - `▶ ゲームを始める`
       - `　 つづきから`
       - `　 エンディング一覧`
       - `　 終了する`
     - 键盘上下键切换光标，Space/Enter 触发。点击“ゲームを始める”停止 OP 音乐并进入 `inGame`。

#### 步骤四：ESC 游戏内系统菜单与可视化「しおり」系统 (M4.7)
- **目标文件**：`ShizukuRuntime/Sources/ShizukuApp/MetalGameView.swift`
- **实现要点**：
  1. **呼出机制**：
     - 在 `keyDown` 监听 `keyCode == 53`（ESC）以及 `rightMouseDown` 事件。
     - 若当前处于 `inGame`，切换至 `escMenu`；若已在 `escMenu`，退出返回 `inGame`。
  2. **系统菜单 6 大功能**：
     - `文字を消す`：切换到 `hideText` 模式，不绘制暗化层与文字，全屏欣赏背景立绘原画；任意点击返回。
     - `セーブする`：打开 `saveSlotPicker`，选择 1~6 号书签槽，展示覆盖确认，写入并返回。
     - `ロードする`：打开 `loadSlotPicker`，选择已有存档槽，读取恢复并切回 `inGame`。
     - `シナリオ回想`：直接呼出 Backlog 历史面板。
     - `一つ前の選択肢に戻る`：若 `engine.lastSelectSavePoint` 存在，调用 `engine.restoreSaveState(...)` 瞬间回滚。
     - `ゲーム終了`：确认后返回 `titleMenu`（并重新起播 OP 曲或静音）。
  3. **「しおり」UI 设计**：
     - 6 槽位卡片列表，每槽位显示：槽位编号、存档日期时间、剧本位置（如 `SCN001 MSG005`）与第一句预览文本。

#### 步骤五：自动化回归测试与打包验证
1. 运行单元测试保证无回归：
   ```bash
   swift test --package-path ShizukuRuntime
   ```
2. 执行全量打包生成最新 DMG：
   ```bash
   ./package.sh
   ```
3. 挂载并启动验证：
   ```bash
   hdiutil attach build/Shizuku.dmg
   /Volumes/Shizuku/Shizuku.app/Contents/MacOS/ShizukuApp
   ```

---

### 20.4 关键源码、资源与参考资料速查索引

| 类别 | 路径 / 标识符 | 说明 |
|---|---|---|
| **核心剧本模型** | `ShizukuRuntime/Sources/ShizukuCore/Scn.swift` | `InlineAction`, `MessageSegment`, `MessagePauseType` |
| **虚拟机引擎** | `ShizukuRuntime/Sources/ShizukuEngine/Engine.swift` | 剧本事件解释器、消息推进状态机、存读档状态 |
| **画面排版渲染** | `ShizukuRuntime/Sources/ShizukuRender/SceneComposer.swift` | 640×400 视口合成、弟切草 35% 暗化、25×13 字形排版、1px 阴影 |
| **字库渲染管线** | `ShizukuRuntime/Sources/ShizukuRender/TextRenderer.swift` | 1853 Leaf 码直连索引、24×24 1bpp 字形栅格化 |
| **Metal GUI 交互** | `ShizukuRuntime/Sources/ShizukuApp/MetalGameView.swift` | Jingle/OP/Title/ESC/Save/InGame 交互状态机 |
| **音频管理器** | `ShizukuRuntime/Sources/ShizukuEngine/AudioController.swift` | 基于 `AVAudioEngine` 的 25 首 BGM 与 13 首 SFX 播放 |
| **存读档管理** | `ShizukuRuntime/Sources/ShizukuEngine/SaveManager.swift` | JSON 格式多槽位存读档与结局图鉴持久化 |
| **打包脚本** | `package.sh` | 自动化编译、Bundle 装配、代码签名与 DMG 镜像制作 |
| **里程碑清单** | `MILESTONES.md` | M4.4~M4.7 细分任务与阶段五计划 |
| **原版逆向源码** | `research/mglvns/` | `sizuku_jingle.c`, `sizuku_op.c`, `sizuku_etc.c`, `LvnsDisp.c` |
| **Akkera102 移植** | `research/akkera102/` | Ex.21/22 GBA 移植规范与 `ScriptParserScn` |
| **解包素材库** | `research/extracted/` | 全量 64 立绘 (`MAX_C*`)、56 背景 (`MAX_S*`, `VIS*`)、OP 序列帧、BGM OGG、SFX WAV |
| **单元测试套件** | `ShizukuRuntime/Tests/ShizukuRuntimeTests/` | 21 项 XCTest 单元测试（音频、排版、字节跳转、存读档） |

---

## 21. 2026-09-20 第二次会话（★M4.4/M4.5 落地 + 曲目/OP/暗化系数纠错 + 两处解析缺陷修复；与 §20 冲突以本节为准★）

> 本节 = 上一 Claude 会话（`8102acca…`，死于 403 配额报错）的完整成果与事实核准。§20.3 的实施清单已按原版 C 源码（mglvns / gbalvns）逐条核对执行，**其中三条清单事实被证伪**（暗化系数、OP 曲目、ESC 菜单顺序），务必按本节修正执行后续 M4.6/M4.7。

### 21.1 ★被证伪/纠正的 §20 结论（后续会话勿再引用旧值）★

| §20 旧结论 | §21 纠正后事实 | 证据 |
|---|---|---|
| 背景暗化 35%（`rgb*0.65`） | **调色板亮度缩放 `latitude_dark=11/16` ≈ 31% 暗化（亮度 ×0.6875）** | `Lvns.c:72` + `mgImage.c:661` `cmap_m[i][j]=j*i/16` |
| OP 开场曲/主菜单曲 = `MUS16.OGG`（219s） | **OP 曲 = `MUS14.OGG`（78.2s）**；MUS16 = **ハッピーエンド** 曲 | 用户亲耳确认 MUS00=社标、MUS02=新游戏第一首、MUS16=happy end；官方 OST 音频指纹比对（授业中→MUS02 0.947✓、ハッピーエンド→MUS16 0.928✓、オープニング→**MUS14** 0.898 领先次佳 0.193） |
| Leaf Jingle = 5.5s `MUS00`（§20.1 归位正确，保留） | 同左 ✓；且确认 **mglvns 脚本的 `MUSIC n` 是 CD-DA 音轨号 = 文件名号 +2**（音轨 1=数据轨，音轨 2=社标=MUS00）。**SCN 剧本内 `0x6e N` 与 `MUS%02d` 文件直接对应，无需改动** | 偏移只存在于 mglvns 启动脚本（`sizuku_jingle.c`/`sizuku_op.c`）的编号体系 |
| OP 滴泪动画 18 帧（`OP_S00`~`OP_S17`） | **`sizuku[]` 动画表 = OP_S00~OP_S16 共 17 帧**，每帧 time=50、x=160（`OP_S17.LFG` 文件存在但不在 OP 表内） | `sizuku_op.c` 逐项抽取 |
| 瑠璃子段 `OP_L0`~`OP_L8`「9 帧动态」 | **`ruriko[]` = 40 帧序列**（time=50、x=0）：前 24 帧为 L0/L1/L2/L1 眨眼循环，后 16 帧 L0→L3..L8→L7..L6 往返 | 同上 |
| ESC 菜单顺序「セーブする 在 ロードする 前、第四项=シナリオ回想」 | **原版六项顺序（`sizuku_menu.c` MENULINE 行 3-8）：`文字を消す、ロードする、セーブする、シナリオ回想、一つ前の選択肢に戻る、ゲーム終了`（先读后存正确；第四项文本确为「シナリオ回想」，前会话一度误记为「回想モード」，本会话已用 iconv 直读源码裁决）** | `sizuku_menu.c:75-83` |
| §20.2 行内事件统计 544/278/493/252（合计 1567） | 系 LZS 越读污染前的欠计数，修正后见 §21.2 | — |
| （工具误记）`sizfont.tbl` 是 cp932/SJIS | **`sizfont.tbl` 是 EUC-JP**：idx0=U+3000 全角空格、1=■、2=あ | 逐字解码验证 |

**OST 权威曲目对照**（`雫オリジナルサウンドトラック` 1996.11.22，23 首，位于 `《雫～しずく～1996》 /原声OST（无损）/[EAC][961122 ][Leaf]雫オリジナルサウンドトラック/`，m4a）：
社标 Jingle=MUS00 ｜ 授業中(教室)=MUS02 ｜ 瑠璃子=MUS08 ｜ 瑞穂=MUS06 ｜ 沙織=MUS07 ｜ **OP=オープニング=MUS14** ｜ トゥルーエンド=MUS15 ｜ ハッピーエンド=MUS16 ｜ バッドエンド=MUS17。
⚠ 两处不可靠匹配（最佳/次佳分差 <0.04，疑同旋律变奏，待复核）：`03 精神世界`、`08 沙織`。MUS15/MUS99 从未被任何 SCN 剧本引用（启动序列/标题专用曲候选）。

### 21.2 ★两处真实解析缺陷的发现与修复（其中第二处尚未 commit）★

1. **已提交（`6ff45f4`）：`LZS.decodeInv` 越读**。旧实现被喂整个剩余文件后不停在声明长度处，几乎每个脚本尾部多解出一长串 `0x00`/`0xFF` 垃圾，并被消息偏移表算进**最后一条消息**。197 脚本中 **173 个受影响、166 条消息解析结果改变、非法字节残留 881→28**。修复 = 按段头 `d1Size`/`d2Size` 严格截断。
2. **已提交（`7e5c0fd`）：eventOps 缺 13 个 opcode + parseBlock 无块边界**（上一会话在 §20.3 步骤五验证阶段被 403 掐断，本会话复核后落盘）：
   - `Scn.eventOps` 缺 `0x03/0x06/0x5a/0x5c/0x60-0x66/0x6f/0x73`（原版 `ScriptExecEventSkip1/2/3` 占位指令，各有真实宽度；缺失导致操作数被当新 opcode、整块错位解析）。依据 `research/gbalvns/core/script2.c` 的 `ScriptEventTable` 处理器逐一核对宽度。790 block 中 20 个受影响（另 217 个含占位事件）。
   - `parseBlock` 旧实现 `while i < data.count` **只有起点没有终点**；**790 block 中 434 个在自身跨度内没有 END**（靠 JUMP 离场），会越界吞掉后续块（如 SCN181 blk1 跨 204 字节全是 `54` MSG 指令）。修复 = 传入 `end`（下一块偏移或流末尾）并用于 SELECT/参数读取边界。
   - 现状：`swift build` 通过、21/21 测试全绿；CLI `-trace` 抽查 SCN181/174（204/157 字节无 END 块）块内推进正确、SCN082（含全部 7 种 0x60 段 skip 码）解析无异常；全仓 34 个脚本含 skip 类 opcode 均受此修复保护。已随 `7e5c0fd` 提交。

**行内事件准确统计（截断修复后全 197 SCN）**：立绘 `C` 671 ｜ 背景/CG `B`/`E` 335 ｜ 视觉 CG `V` 70 + `H` 50 ｜ 三人立绘 `A` 78 ｜ BGM 类合计 752 ｜ PCM/SFX 类合计 428 ｜ 清空 `D` 208 ｜ 闪光 `F` 223 ｜ 震动 `Q` 129 ｜ 偏移/速度 `X`/`s` 216。

### 21.3 M4.4 / M4.5 已完成实录（commits `6ff45f4` + `95173de`）

- **M4.4 Part 2（Engine 接入）**：`Engine.swift` 新增 `currentSegmentIndex` / `screenLines` / `activeLines` / `revealedGlyphs` / `displayedLines` / `lastSelectSavePoint`（SELECT 前自动 `captureSaveState(slot:-99)`）。`k` 语义=文本**追加**到同屏下方，`p`=**清屏**从顶行重写。立绘坐标按 `sizuku_etc.c`：左 0 / 中 160 / 右 320、**y=0**（立绘 400px 等高，旧 `400-200` 为错）。BGM 区分 `play` 与 `next`（`Mn` 排队，下一次图像切换起播），`Mf`/`Ms`=fade/stop。实测 SCN002 msg0 链路 `Mf→Mn01→B070808` 正确驱动切曲+换背景。
- **M4.5（弟切草排版）**：底部框废除；全屏 25×13 网格，起点 (20,18)、列 24px、行 28px（`LvnsInfo.h` 的 `XPOS/YPOS` 原值）；字形先画右下 1px 纯黑 `(10,10,10)` 硬阴影再叠 `(240,240,240)` 本体；▼ 光标**跟随末行文字末尾**；暗化 11/16（见 §21.1）。
- **视觉亲验**（导出帧目检，含一次自我纠错：首检帧在渲染顺序 bug 修复前，文字层为空即误报完成——**成品描述必须以亲眼确认过的输出为准**）：SCN001 msg0 暗化教室上两行白字带阴影+▼；SCN007 msg0 立绘落槽、调色板与透明色正确。渲染顺序修复（先 reveal 后 render）已含在 `95173de`。
- **测试语义更新**：两项旧测试编码了「一条消息一次点击」模型，改为分段推进；SCN001 的 3 路选择支**仅当 flag 0x46 置位**（二周目）才出现，首周目直通 SCN002——旧断言方向反了。

### 21.4 用户已定夺决策 + 下一步执行清单

**决策（2026-09-20 用户拍板）**：
1. **しおり = 6 格**卡片（原版仅 3 格 + 第 4 格 `SioriSavePrev` 自动备份；6 格更实用，「一つ前の選択肢に戻る」继续用已有的 `lastSelectSavePoint` 独立承担，不占槽）。
2. **存档格式沿用 JSON `SaveManager`**（不回退 GBA SRAM 二进制布局；理由：可读、可迁移、已有测试覆盖，效果优先）。

**下一步（按序）**：
```
[0 ✅] commit 7e5c0fd → [1 ✅] M4.6 Jingle/OP/Title → [2 ✅] M4.7 ESC+しおり → [3 ✅] 回归+重新打包 DMG
```
0. ~~**提交未落盘修复**~~ ✅ 已完成（`7e5c0fd`，CLI 抽查通过）。
1. **M4.6 启动序列**（数据已齐，直接照抄，无需重研）：
   - Jingle：起播 `MUS00.OGG`（5.5s 单次）→ `LEAF.LFG` 于 (80,144) 淡入 → 等待 → 滑动特效 → 计时 6000 后等点击（`sizuku_jingle.c`）。
   - OP：`MUS14.OGG`（78.2s）+ `sizuku[]` 17 帧（OP_S00~S16, time50, x160）→ `OP_V0`/`OP_V1` 各停顿 2s → `ruriko[]` 40 帧（time50, x0）（`sizuku_op.c`，`LvnsAnim.c` 帧时= time*INTERVAL/1000）。任意键跳过。
   - Title：`TITLE0.LFG` + `TITLE.LFG` 双层，24×24 点阵菜单。
2. **M4.7**：ESC/右键呼出六项菜单，**顺序按 §21.1 修正版**；しおり 6 格 + JSON 层；覆盖确认弹窗。
3. **打包**：`./package.sh` 重出 DMG（现有 `build/Shizuku.dmg` 是 M4.4/M4.5 之前的旧版）。

### 21.5 资产与方法增量

| 资产 | 位置 | 说明 |
|---|---|---|
| 官方 OST（无损 m4a×23） | `《雫～しずく～1996》 /原声OST（无损）/[EAC][961122 ][Leaf]雫オリジナルサウンドトラック/` | 曲目名权威对照源；目录名含 JP 字符与尾随空格，glob 访问 |
| 音频指纹比对法 | 工具在 `/tmp/shz/fp3`（**重启即丢**，Swift+Accelerate 解码→单声道→相似度矩阵） | 方法可复现：用两条用户确认锚点（MUS02/MUS16）校验方法可信，再定 OP=MUS14 |
| gbalvns `script2.c`/`script3.c` | `research/gbalvns/core/` | eventOps 宽度与行内指令宽度的权威对齐源（本会话逐条核对） |
| 试听文件 | `~/Desktop/雫_Jingle试听/`（MUS00/02/16） | 用户已听完并给出 §21.1 三项确认 |

### 21.6 ★M4.6 / M4.7 / M4.8 落地实录（本会话，commit `9d781cd`）★

**M4.6 启动序列**（`MetalGameView.swift` 19 阶段 `BootStage` + `SceneComposer` boot canvas 组）：
- 时序：`INTERVAL=60`（`Lvns.h:70`），1 tick=1/60s，ms→tick 截断；60Hz `Timer` 驱动 `advanceBoot()`。调色板淡入淡出=16 步+1≈17 tick、WHITEIN≈18、FadeMask≈32、`WAIT 120→7t / 2000→120t / 1000→60t`；Jingle `TIMER_WAIT 6000ms` 绝对计时；`CLICK_JUMP`=任意 select 快进到该步。
- Jingle：`MUS00` 单次（`LvnsStartMusic` 不循环）→ 黑→白淡入 → `LEAF.LFG`@(80,144) 于黑底、白窗溶解 → `LoadTitle2`（黑底 + 白箱 (0,80)-(639,319) + 再叠 LEAF）→ 边缘滑入擦除 32t → 保持至 6.0s → 点击跳 → 淡出。
- OP：`MUS14` 单次（进标题不再另起乐）→ `sizuku[]` 17 帧 OP_S00~S16 `{time50,x0,y160}` → `OP_V0` 淡入/2s/淡出 → 再 `sizuku[]` → `OP_V1` → 再 `sizuku[]` → `ruriko[]` 40 帧 `{50,0,0}`：`[L0,L1,L2,L1]×6,[L0,L3,L4,L5],[L6,L7,L8,L7]×3`（3t/帧）→ `CLICK_JUMP` → 淡出 → `TITLE0`@(0,0) 淡入 17t+停 60t → `TITLE.LFG`@(0,0) FadeMask≈32t → 进菜单。
- **LFG 落位关键**：`Lfg.decode` 已把 header 的 `xoffset/yoffset` 烘进全画布，`mglimage_add` 再 `+=` 表坐标——故「按表 (x,y) 贴 decode 画布」可 1:1 复现原版（`sizuku[]` 表 x=0 而非 160；ruriko 视觉 x=160 来自 `OP_L*.LFG` 的 xoffset=160 已烘焙）。

**M4.7 ESC 六项菜单 + 6 格しおり**（JSON 层）：
- `GameMode` 新增 `.escMenu/.slotPicker/.escConfirm`；`Esc`/右键呼出六项（顺序按 §21.1 修正版，第四项确为「シナリオ回想」）；「文字を消す」置 `hideTextNow`、「一つ前に…」用 `lastSelectSavePoint` 独立还原、「ゲーム終了」走确认→`startTitleMenu`（`stopBGM` 规避 fadeOut 音量竞态）。
- しおり 6 槽 picker：`SlotRow{label,detail,preview,hasData}`，展示 `yyyy-MM-dd HH:mm  SCN%03d blk%02d` + 首句预览；空槽显示「（から）」。はい/いいえ 确认子菜单默认选中「いいえ」（安全）。
- 菜单绘制：`drawMenuLine`（11/16 暗化 + 24px 点阵居中文本行，选中白+阴影/未选灰，无 ▶ 光标）；`(1)/(2)` 提示用原生字（sizfont 无 ASCII 单元）。

**菜单 leaf 码来源（重要纠偏）**：`MenuStrings.swift` 的 leaf 码须按 **`KNJ_ALL.KNJ` 字体真实槽序**（`GlyphMap.slot(forLeaf:)=leaf-1`，即 leaf=slot+1）离线核对生成，**不可**用 `sizfont.tbl`（那是 CN 表且为逐条 EUC-JP 双字节，整文件连续解码因奇数长度会错位、与 JP 字体槽序不一致）。已用列主序（`glyph[col*24+row]`，bit7=列顶）渲染 slot 图集逐一转录验证。

**修正缺陷**：`drawMenuLine` 返回值原为 `xStart + leaves.count*24`（`xStart` 是缩放像素、`leaves.count*24` 是原生像素，混用），致确认徽标压在假名字形上；改为 `xStart + leaves.count*24*s`（缩放）后徽标正确落到文本右侧。

**验证（§21.3 纪律：只描述实际导出并目检过的帧）**：`SHIZUKU_SHOT=boot,title,game,esc,slotload,slotsave,confirm` 导出 25 帧逐一 Read 目检——Jingle 白窗社标、OP 滴泪/OP_V0/OP_V1/ruriko 落位、TITLE0+红「雫」FadeMask、标题点阵菜单、全屏正文、ESC 六项、しおり 6 格、确认对话框均正确。`swift test` 21/21。`./package.sh` 出 `build/Shizuku.dmg`（51M，gamedata 397 文件），挂载后从卷内直接跑 app 重导帧一致。

---

### 22. 2026-09-21（M5.2 双语热挂载框架完成 + M5.1 离线路线证伪）

**A. M5.1 离线可行性彻底探底（结论：唯一缺口=catalog 密文偏移，须运行时）**：
- **明文 KPA 全表扫描**：游戏目录 7 文件（MAX_DATA/Sizuku.exe/Sizuku_cn.exe/bgmfile/soundds.PAK…）用锚点句在 GBK/GB18030/UTF-16LE/UTF-8/BIG5/ShiftJIS 全文+关键子串检索 → **全 NONE**；放宽到"任意 ≥4 连续汉字"只得高位字节随机落 CJK 码位的伪中文。**→ 中文明文不在盘上，全在加密 overlay 内。**
- **overlay 熵检测**：`Sizuku_cn.exe @0x751d7` 之后区域熵 **7.977**（满熵）= 纯密文，`rebuild_overlay.py` 当明文 64B 记录表解析 500/500 校验失败即因是 CBC 密文。
- **全局密钥捷径排除**：stage2 `0x2786b60` 是对象结构（含指针 `0x3f778/0x17338`）非 68B ks；CN catalog 用独立种子（`catalog/seed_hex.txt`=`61d41a5d…`=catalog MD5），引擎节全局密钥套不上。
- **有界定位扫描**：用 catalog 种子 `ks68_sched/ks68_mixer` 从 0x751d7 试 CBC/ECB 解 → 无 12B 零记录特征；整段滑窗暴力（纯 Python）过慢已终止，且方法学上只在"真 offset"有效=盲猜。
- **唯一缺口**：catalog 密文在 MoleBox 容器内的**起始偏移+长度**，只能靠运行时单步 loader 从流读参数 `0x279b4f0` 抓（`chk_keys.stub` RESUME，但 `/tmp` 快照随重启已丢，且 loader 卡 fail 分支 `0x27aceed`）。`pf_cipher.dec_cbc` roundtrip 已备、种子已备，只差这一步定位。**→ 用户裁决先做 B（框架），脱壳留后台。**

**B. M5.2 双语热挂载框架（Swift，已落地目检，零改日文路径）**：
- **`GameLanguage`（ShizukuCore/TranslationStore.swift）**：`enum { jp, zh }` + `displayName`。`TranslationStore` 增 `contains(scn:msg:)`、`candidatePaths(extractedDir:)`、`loadDefault`（搜索序：`gamedata/zh_text.json` → `research/recovery/text/zh_text.json` → `Bundle.main.resourcePath/gamedata|/`）。
- **`Engine` 中文分页态**：`language`、`cnPages:[[String]]`/`cnPage`、`cnActive/cnCurrentLines/cnOnLastPage`、`cnCharsPerLine=22`/`cnLinesPerPage=11`；`paginateChinese`（按字宽换行+分页，纯逻辑可测）；`beginMessage`→`rebuildCNPresentation`；`advanceMessage` 顶部 CN 分支：逐击翻中文页，**与 JP segment 锁步推进以照常触发内联动作**（bg/立绘/BGM），末页后落回 JP 收尾；`setLanguage` 即时重解析当前消息；`previewMessage(scn:msg:)` 直挂验证口。
- **`SceneComposer`**：`drawTextLayer` 在 `cnActive` 改走 `drawCNTextLayer`（`drawNativeText` 反锯齿 CJK，先 1px 阴影后近白正文，复用 textOriginX/Y+lineAdvance 网格）；`drawEscMenu` 增第 7 行「言語を切り替える 切换语言 → 中文/日本語」（native 字体，前 6 项原版点阵不动）；`escMenuRowCount=7`。
- **持久化**：`SaveState.language?`（旧档 nil→jp）+ `GlobalSystemData.language?`；`MetalGameView` 启动 `setLanguage(system.language ?? .jp)`，ESC 第 7 行/键"7" 切换并写 `system.json`，切换后 toast。
- **打包**：`package.sh` 把 `research/recovery/text/zh_text.json` 复制进 `Resources/gamedata`（缺失静默跳过）。

**C. 验证（§21.3：只描述实际导出并目检过的帧）**：
- `SHIZUKU_SHOT=cn`（`engine.setLanguage(.zh)`+`previewMessage(1,5)`）→ `cn_diag.txt: CN msg=5 pages=1 line0=然后不知在某个不经意的瞬间，我察觉到这个无聊`；Read `cn_game.png`：锚点句两行中文正确换行、白字带阴影。
- `SHIZUKU_SHOT=title,game,esc,slotload,slotsave,confirm,cn` 全画无回归；Read `esc_menu.png`：6 项原版日文点阵 + 第 7 行中文语言切换行；Read `game.png`：JP 正文「細いシャープペンシル…」+▼ 续示符正常。
- `./package.sh` 出 `build/Shizuku.dmg`（52M，gamedata 398 文件含 `zh_text.json` 124B）；**bundle 内 `Shizuku.app/Contents/MacOS/ShizukuApp` 跑 `SHIZUKU_SHOT=cn` 从 gamedata 热挂载成功**（diag 同上）。
- `swift build` 通过。

**D. 下一步**：
1. **M5.1 后台**：冷启动 `full_emu.py` 重生成 `chk_keys.stub` → `0x27aceed/0x27aceef` 双探针诊断分支 → hook 流读拿 catalog 密文偏移+长度 → `dec_cbc` 离线解 catalog → table2 entry seed → 解 737KB 记录流 → 批量导出全 `(scn,msg)→中文` 进 `zh_text.json`（框架即插即用，无需再改代码）。
2. **中文点阵字库挂载（可选升级）**：当前中文用 macOS 系统反锯齿字体（清晰但非原版点阵）。若从 overlay 提取 `cn_KNJ_ALL.KNJ` 的汉字→槽映射表，可加 `CNGlyphTable` 走原生点阵渲染，与 JP 视觉统一。
3. 语料补齐后：标题/ESC 菜单项中文本地化、しおり previewText 中文、M2 双语正式版发布。

---

## 23. 2026-09-21（★用户实机九项清单全部落地：交互/菜单/设置/BGM 曲号 bgmmap/结局解锁选择肢★）

用户在 M4.8 打包件上实机游玩后给出九项反馈清单，本节逐项记录根因、修法与验证。提交链：`a2fa5d7` → `922d1e1` → `653e474` → `4e4d5ce` → `bd5cb48`。测试 24/24 绿；`SHIZUKU_SHOT=boot,title,game,esc` 全画目检无回归。

| # | 用户反馈 | 根因 | 修复 | 提交 |
|---|---|---|---|---|
| 1 | 很多场景 BGM 调用错误 | **脚本号≠文件号**：原版 `sizuku.c:131 bgmmap()` 把脚本号映射为 CD 轨号（`14→2`、`n<16→n+2`、否则 `n+1`），MUS 文件=轨-2（jingle 轨2==MUS00、OP 轨16==MUS14 双指纹）。我们直接 `MUS脚本号` 播放 → 全剧本 286 处引用中 **87 处(30%) 放错曲**（如脚本 19 应放 MUS18 却放 MUS19；脚本 14 应放 MUS00 却放 MUS14） | `ShizukuEngine.musicFileIndex(forScriptNo:)` 移植 bgmmap，`startScriptBGM`/读档恢复统一走映射；`SHIZUKU_DUMP_BGM=1` 审计转储逐号核对 | `bd5cb48` |
| 2 | 部分场景没有 BGM | ① `Mw` 被误实现为**停曲**（原版 `LvnsWaitMusicFade` 只阻塞等待淡出、不停曲）；② `Mf/Ms` 清空了 `Mn` 排队曲（原版 `next_music` 在 fade/pause 后存活）；③ 立绘清除路径缺 `Mn` flush | `Mw`→`bgmHoldSeconds` 门控（淡出 0.5s 内吞输入，对齐 `Lvns.c Interval()`「0.5秒単位」，淡出时长 1.0→0.5s）；fade/stop 保留 pendingBgm；`clearPortrait` 补 flush；`653e474` 已先行落地「曲号0=静音 + Mn 排队到图像刷新才起播」 | `653e474`+`bd5cb48` |
| 3 | 按住 Enter 会跳过选择肢 | 键盘自动重复被当作连续确认 | `event.isARepeat` 守卫：选择肢需**新按键**触发 | `a2fa5d7` |
| 4 | 选项/菜单无鼠标 hover | 未接 mouseMoved | tracking area + `mouseMoved` 同步选项/标题/ESC/しおり/确认选中态 | `a2fa5d7` |
| 5 | 主选单按 ESC 直接退出 | 自创行为（原版无） | 标题 ESC 不再退出，退出只走「終了」 | `a2fa5d7` |
| 6 | 原版没有的菜单按钮突兀 | ESC 第7行「言語を切り替える」为 M5.2 自加 | 移除该行恢复**原版六项**（目检 `esc_menu.png`：文字を消す/ロード/セーブ/シナリオ回想/一つ前の選択肢に戻る/ゲーム終了）；语言切换移入 macOS 菜单栏；删死代码 `drawTitleOverlay`（含违和 "macOS Native Remaster" branding） | `922d1e1`+`a2fa5d7` |
| 7 | 「つづきから」无效果 | 未接任何槽位 | 载入全部槽位（しおり/quicksave/autosave）中**时间戳最新**存档 | `a2fa5d7` |
| 8 | 需设置页：快进跳过已读+热键可配置 | 原版无设置 UI，机制在引擎内 | **已读记忆**还原：`seenHighWater[scn]` 高水位（对齐原版 `seen_flag[SIZUKU_SCN_NO]`/`SizukuSetTextScenarioState`，`sizuku_etc.c:406-423` skip 门 `seen`/`fast_text`），随存档持久化、新开局清零；**快进语义**：未读拒绝进 skip（除非强制）、skip 中遇未读自动停、遇 SELECT 停、内联事件照常执行；`fastWhenSeen` 已读即时显示；设置以 **macOS 菜单栏**承载（既読自動略し/未読スキップ/スキップキー可配置(默认 Tab,兼容 Z)/言語），持久化进 `system.json` | `922d1e1` |
| 9 | 通关特定结局才解锁的选择肢 | 机制=结局持久 flag + 脚本级 `0x3d/0x3e` 条件跳转（原版无逐项隐藏选项，见 `sizuku.c:625-644,706-718`） | 实证链测试：`0x46=1` 时 SCN001 出现 **3 选项**解锁选择肢、`=0` 时直接离开 SCN001（负对照）；`recordEnding`→`system.json`→新周目 `applyGlobalSystem` 继承自动开门。本轮补漏：**flag 1（雑シナリオ）持久化**——原版 `SizukuScenarioInit` 仅清 flag_save[2-6,9-13]，0/1/7/8 永久保留（GBA `siori.c:50-87` SRAM@0x10 同集），我们 reset/recordEnding 此前丢了 flag 1，读它的门槛选择肢会失效，已修 | `4e4d5ce`+`bd5cb48` |

**取证要点（防再错）**：
- `bgmmap` 两处指纹锚定：`sizuku_jingle.c:90 {SCRIPT_MUSIC, 2}`=MUS00；`sizuku_op.c:256 {MUSIC,16}`=MUS14（§20 曾误记 OP 为 MUS16）。脚本号 15/16 同轨(17)、14 特例回 jingle 轨，均为原版行为，**照抄不修正**。
- 原版 `0x7d` = `LvnsStartMusic`（**不循环**一次性 credits 曲）+ `SizukuEnding` + `memcpy(flag_save,flag)` + `SizukuSave`——我们 0x7d/0x7e 语义已对齐（M3.4），本轮仅补 flag1。
- 读档恢复 BGM 曾绕过映射直调 `playBGM(number:)`，已统一走 `startScriptBGM`。

**遗留（转入 §24 审视）**：演出层 14 项差距清单（Q 震动未渲染、F 闪光粘滞、0x14/0x22/0x24 清屏范围、credits 卷轴缺失、`s` 速度语义反了、▼ 光标不闪、0x05 提示语被吞等）——详见 §24。

## 24. 2026-09-21（★深度逆向审视原版程序/脚本设计 → M4.10 演出/文字/选择肢保真度全量落地★）

按目标回读 `sizuku.c`/`LvnsText.c`/`Lvns.c` 全文，与我们的引擎逐项对照，形成 14+ 项差距清单并全部取证。**本轮全部落地**（`b0e1e13` + `eab3fda`），仅余三项大型演出转场类工作划入 M4.11（取证已完成，见 §24.3）。测试 27/27 绿；`SHIZUKU_SHOT=game,choice,esc,title` 全画目检通过。

### 24.1 已落地清单（原版语义 → 我们的修正）

| # | 项 | 原版行为（一手代码依据） | 修正前我们的行为 | 落地 |
|---|---|---|---|---|
| 1 | `'s'` 文字速度 | `char_wait_time = c[1]`（`sizuku.c:474`），单位=LvnsWait flip 数（`LvnsText.c:81`），**越大越慢**；默认 1（`Lvns.c:45`）；**每换行重置为 1**（`LvnsText.c:163`） | 反了：hint 越大越快，且按 0x30=默认速度凑曲线 | `speed(forHint)=v/60`，`defaultTextSpeed=1/60`，`tickReveal` 检测跨行边界即复位（`b0e1e13`） |
| 2 | `'X'` 文本偏移 | USE_MGL 下 `SetTextOffset` 折半生效 | 原值直用 | `scene.textOffset = x / 2` |
| 3 | `'F'` 白闪 | WhiteOut 16 flip + WhiteIn 16 flip 渐变瞬态 | 粘滞布尔（画上后直到下一条消息才清） | `flashTicks=32` 随 ticker 递减，渲染按 `255*intensity/16` 渐变 |
| 4 | `'Q'` 震动 | Vibrato：16 flip 内每帧 `dx,dy=(random%(VIB*2+1))-VIB`（±16px），只抖画面层 | 置布尔后**从未渲染**也从未清除（死代码） | `shakeTicks/shakeDX/shakeDY` 每 flip 重随机，bg+立绘 blit 加偏移，结束归零 |
| 5 | `0x14` CLEAR | `UndispText + LvnsClear` 画面与文本层全清 | 只清立绘 | 清 bg/bgH/立绘/screenLines/activeLines |
| 6 | `0x22` CHR | 只装载目标槽位，其余槽保留 | `portraits.removeAll()` 全清 | 单槽替换 |
| 7 | `0x24` CHR2 | 装载并**强制居中槽 'c'** | 自创 `frontPortrait` 前置通道 + 按 args[1] 定位 | `setPortrait(pos:"c")`，删除 frontPortrait 全链路（Scene 字段/渲染/清屏） |
| 8 | `'D'` 立绘指令 | `SizukuClearCharacter('a')` **清全部槽**再装载单槽（`sizuku.c:310-320`） | 只清同槽再装载 | `clearPortrait(pos:"a")` + `portrait(...)` |
| 9 | `0x05` SELECT | 先把提示语 msg 走 TextParser 画上屏，选择框在其上、文本选择期间保持可见 | 提示语被吞，直接出框 | `beginMessage(prompt)+revealAll+commitActiveLines`，渲染层 awaitingChoice 也画文本层 |
| 10 | ▼ 续点光标 | 本段文字走完后才出现，随 flip 以 ~6 帧周期闪烁（`LvnsWaitKey/LvnsWaitPage` 循环） | 常亮不闪、揭示中也显示 | `flipCount/6` 奇偶门控 + `isRevealing` 抑制 |
| 11 | 主循环 | 原版引擎即常驻 60Hz flip 循环驱动一切时序 | ticker 仅 `isRevealing` 时运行，选择/效果/闪烁全停 | inGame 期间 ticker 常驻，`tickReveal` 统一驱动揭示/效果/hold/闪烁 |
| 12 | 选择框 UI | 原版纯文本行+光标（我们按九项清单要求升级为可 hover 框） | 420px 宽致长选项截断；`1.` 前缀与脚本自带 `1、` 编号重复 | 加宽 560、去重复前缀，仅选中行画 `>`（目检 `choice_menu.png` 三选项完整） |
| 13 | `'p'` 存档点 | 置 `savepoint_flag`（`sizuku.c:252`），主循环在**消息执行完毕**时 `LvnsSetSavePoint`+`memcpy(flag_save,flag)`；`SizukuStartScenario` 以 `selectpoint=savepoint` 播种（`sizuku.c:546`） | 完全缺失 | `lastPageSavePoint`（slot -98）在含 'p' 消息结束处捕获；ESC「一つ前の選択肢に戻る」回退链 `lastSelectSavePoint ?? lastPageSavePoint`（`eab3fda`） |
| 14 | 回归测试 | — | — | 新增 `testTextSpeedIsCharWaitTimeFlips`/`testSelectPromptTextStaysOnScreenWithChoices`/`testFlashAndShakeAreTransient`（全 197 SCN 实扫到真实 'F'/'Q' 消息驱动） |

### 24.2 防再错取证要点

- `LvnsWait(n)` = `n × LvnsFlip`（`Lvns.c:455-460`），我们的 ticker 即 flip 源，1 flip=1/60s 与原版 MGL 端一致。
- `'D'` 尾部固定 `LvnsDisp(lvns, LVNS_EFFECT_FADE_MASK)` 转场——转场类未实现前视觉为直接切换，归入 M4.11。
- `0x24` 第二操作数在真实脚本里出现过 `'0'/'Z'/'8'` 等值，但原版行为是**居中**显示，槽位字母不影响落位——勿再按 args[1] 定位。
- 选择肢文本自带 `1、2、3、` 编号是脚本内容（msg 文本），不是引擎前缀——UI 层不得重复编号。

### 24.3 划入 M4.11 的三项（取证已完成，未落地）

| 项 | 原版依据 | 工作量评估 |
|---|---|---|
| B/S/V/H/E 转场效果码 | `text_effect(c1,c2)`（`sizuku.c:113-127`）：两位十进制 00-0C + 99=NORMAL，表=`FADE_PALETTE, GURUGURU, SLANTTILE, FADE_SQUARE, WIPE_SQUARE_LTOR, FADE_MASK, WIPE_TTOB, WIPE_LTOR, WIPE_MASK_LTOR, VERTCOMPOSITION, SLIDE_LTOR, NORMAL, FADE_MASK`；`LvnsClear(出转场)`→换图→`LvnsDisp(入转场)`；~~事件 `0x66` 走 `sizuku_effect[c[1]]`~~ **更正（§28 复核）：`sizuku.c:762-765` 中 0x66 只是 `c++` 空操作，不查表；查表的是 0x38 `LvnsDisp(sizuku_effect[c[1]])`（`sizuku.c:702`）** | 需实现 13 种转场渲染器（可先做高频的 FADE_MASK/FADE_PALETTE/WIPE_* 5 种），中等 |
| `0x01` 过场子类型 | `sizuku.c:580-602`：`01`=正弦背景扭曲下打印消息+末尾调色板淡出；`02`=先淡入再正弦扭曲；`03`=`LvnsAnimation(sizuku01/02)` 动画插播 | 依赖逐帧背景扭曲 shader 级效果，较大 |
| 结局 credits 卷轴 | `0x7d` 一次性曲 + staff roll 滚动文本 | 独立 UI 件，中等 |

**下一会话建议**：M4.11 从「转场效果码 5 种高频子集」起步（对演出观感提升最大、纯 2D 像素操作即可实现）；`SHIZUKU_DUMP_SEGMENTS` 可扩展转场码统计以定优先级。





## 25. 2026-09-21（★用户实机四项清单：ESC菜单守卫/标题读档列表/选择肢暗色化/BGM无声根因★）

用户在 M4.10+退出确认打包件上实机游玩后给出四项反馈，提交 `ec19c91`。测试 27/27 绿；`SHIZUKU_SHOT=choice,slotload,slotsave,confirm,continuelist` 全画目检通过。

| # | 用户反馈 | 根因 | 修复 |
|---|---|---|---|
| 1 | 菜单栏选 system menu 会「进入一个较早期的游戏存档」 | `openEscMenu` 无模式守卫：标题/启动页点菜单项即 `mode=.escMenu`，其背景渲染 `composer.render(engine)` 显示**陈旧引擎状态**（上次通关/从未开局时的早期 SCN 画面），ESC 退出该菜单又直接 `mode=.inGame` 落回该画面——观感即"误入旧存档" | `openEscMenu` 加 `guard mode == .inGame`；`validateMenuItem` 对 システムメニュー/クイックセーブ/クイックロード/スキップ切替 在非游戏内**灰置**（对齐原版：系统菜单只存在于游戏画面之上） |
| 2 | 主菜单读档不能选存档，直读最新 | §23 第7项当时实现为「つづきから=时间戳最大槽直读」 | 改为弹出**读档列表**：`pickerSlots` 泛化行→槽映射（オートセーブ -1 / クイックセーブ 0 / しおり1-6 共8行），`chooseSaveToContinue` 从标题进入时以标题底图为背景（`titleBackdrop`，不再渲染陈旧游戏画面），`pickerReturnMode`/`confirmCancelMode` 修正取消回退链（标题↔列表↔确认框）；`MenuStrings` 新增 `quickSaveLabel/autoSaveLabel` 点阵码（sizfont.txt 实为 **Shift_JIS** 索引表，非 EUC——本轮实测纠正） |
| 3 | 选择肢白色背景很丑 | 白底板+蓝字与点阵暗色 UI 违和 | `drawChoiceMenu` 重做：暗色半透明面板（选中 `(28,38,62)@235/255`+淡蓝框，未选 `(12,14,20)@200/255`+灰框）、白/灰点阵文字；顺带发现并修复 `dotMatrix` 表**缺 '>' 字形**导致选中光标一直不可见 |
| 4 | 有时没有 BGM（不确定是否游戏设计） | 回读 `LvnsMusic.c` 全文 + `sizuku.c` 全部 `LvnsDisp` 调用点，找到**两个真 bug**：① **淡出竞态**——`fadeOutBGM` 的 Timer 与新曲启动无关联：`'Mf'→'Mn'→图像刷新起播`后，淡出 Timer 走完仍调 `stopBGM()` **杀死新曲**（原版 `LvnsStartMusic*` 必清 `music_fade_mode`，淡出即作废）；② **0x38 漏刷**——原版 `0x38 EFFECT2` 走 `LvnsDisp(lvns, sizuku_effect[c[1]])`（`sizuku.c:702`），而 `LvnsDisp` 开头必调 `LvnsStartNextMusic`，即 0x38 也是 'Mn' 刷出点，我们只当空操作 → 部分场景排队曲永不启动 | ① `AudioController` 引入 `fadeTimer`+`cancelFade()`：`playBGM`（含同曲 no-op 分支，对齐原版同曲也清 fade_mode）与 `stopBGM` 先作废淡出；Timer 结束改调 `stopBGM`（对齐 `LvnsPauseMusic` 置 `current_music=0`）；② `Engine` 0x38 分支补 `flushPendingBGM()` |

**BGM 链路核对结论（防再错）**：
- 原版 'Mn' = `LvnsSetNextMusicLoop`（排队且**循环**）；'M0/M1/M2' 与 `0x6e` = `LvnsStartMusicLoop` 立即播；`0x7d` = `LvnsStartMusic` 一次性（credits）；'Mf' 仅 `current_music≠0` 才置 fade；'Ms'=`LvnsPauseMusic`（`current_music=0` 但 `next_music` 存活）；`start()` 跨场景跳转不清 `next_music`（我们 `pendingBgm` 同，仅 `reset()` 清）——以上与我们实现一致。
- 刷曲点全集（原版 `LvnsDisp` 调用点）：'B','S','D','A','a','C','E','V','H', `0x0a`,`0x16`,`0x22`,`0x24`,`0x38`, 存档点恢复(`sizuku.c:532` 的 WIPE_TTOB)。`0x14 CLEAR`/`0x01` 走 `LvnsClear` **不刷**。
- **已知偏差（暂不修）**：原版 `LvnsWaitMusicFade`('Mw') 顺带 `loop_music=False`（当前曲播完不续）；我们 AVAudioPlayerNode `.loops` 无法无缝中途改环，保留循环（偏"音乐更多"方向，非无声成因）。
- MUS 曲库完整性：`research/extracted/bgm/` MUS00–MUS23+MUS99 全在，bgmmap 映射域内无缺文件。
- 标题页设计如此：原版标题无 BGM（OP 曲在标题下自然结束），`startTitleMenu` 停曲为正确行为。

---

## 26. 2026-09-21（★原版日文字库逻辑与全部绘制调用深度调研 → 逐项对比、双影子叠印等补漏落地★）

> 权威源：XLVNS/mglvns（go watanabe 1999-2001 对 1996 Windows 原版 LVNS 的行为级还原，直接读 `MAX_DATA.PAK`/`KNJ_ALL.KNJ`/`sizfont.tbl`，`#ifndef USE_MGL` 分支=全分辨率原版行为，**本文所有"原版"以此为准**）+ akkera 78/79 与 gbalvns（GBA 同人重实现，仅参照）+ 我方对真实 `KNJ_ALL.KNJ`/`sizfont.tbl` 的逐字节解码实证。

### 26.1 原版字库数据层（全部经真实二进制解码验证）

1. **KNJ_ALL.KNJ = 无头纯字形流**：133,344 B ÷ 72 B = **1852 字形**；每字形 24×24 @1bpp，**列平面优先**：`byte = glyph[col*24 + row]`（col=0..2 自左向右三个 8px 竖条），**bit7=该竖条最左像素**。金标实证（槽=leaf−1）：slot0=■ 全 576 像素实心；slot1=あ 逐行宽 `[0,3,5,6,11,10,5,4,7,12,11,10,10,9,11,10,10,10,13,8,4,4,0,0]`；slot88=・；slot101=实心右指三角（左缘垂直、行11最宽13px）；slot102=文档/页图标；slot103=↵ 回车钩。**row-major 解码（`glyph[row*3+col]`）证伪**——`research/tools/shizuku-knj-font.py` 与 `verify_font_layout.py` 的"已验证 row-major"结论作废（其 --check 指标为伪阳性），Knj.swift:9-12 口径为准。
2. **字形码 1-based**：`drawChar` 偏移 `(code−1)*24*3`（sizuku_etc.c:530-540）；`code==0`（全角空格）只占格推进不绘制（LvnsText.c:39-64）。**无半角概念**：一切字形 24×24 全角格。
3. **sizfont.tbl**：3703 B = **1851 个 EUC 对 + 尾 0x0A**；**条目下标 = leaf 码**（entry0=U+3000、1=■、2=あ、3=い——**纠正 §8.2:417 的"slot1=い/slot2=あ"错位**）；启动时倒排 `jis_to_leaf`（Lvns.c:144-183），EUC 串走 `((b0&0x7f)−33)*94+(b1&0x7f)−33` 查表，SCN 消息流 `(b0&0x7f)<<8|b1` **直作字形码永不查表**——两条入口并存。表内两个 ASCII 特例：entry99=`!?`、entry104=`cr`（对应 ↵ 字形）。
4. **字库中不存在 ▼/▲**（全 1852 槽形状扫描零命中）——见 26.3-④。
5. **装载时序**：`LvnsInitialize` 一次性 malloc 常驻（KNJ 133KB + tbl），裸偏移取字，无缓存换页（Lvns.c:187-213）。我们 `GameData` 启动整读，语义一致。

### 26.2 原版绘制调用链（LvnsText.c → sizuku_etc.c → sximage.c）

```
SCN 双字节叶码 → LvnsPutChar(每字等 char_wait_time 帧, skip/fast 旁路)
  → PutChar: 写 tvram[cur].row[y].column[x]{code,attr} → cur_x++
    → if(code) drawChar(XPOS, YPOS, code, attr) + 26×26 脏矩形刷新
drawChar = 同一 1bpp 掩码三次叠印（bit=0 绝不写目标）:
  ①黑@(x+1,y+1) ②黑@(x+2,y+1) ③本体@(x,y) 白(attr=0)/灰(attr≠0)
调色板: 黑=0, 白=16→RGB(255,255,255), 灰=17→RGB(127,127,127) (sizuku.c:849-851)
文字直接画在含立绘/CG 的背景 vram 上，无独立文字层。
```
- 栅格：`XPOS=x*24+row.offset`（offset 默认 **16**，LvnsText.c:128）、`YPOS=y*28+8`（LvnsInfo.h:57-58；Lvns.h X11 分支另有 y*32+8/TEXT_WIDTH 26 变体）、`TEXT_WIDTH 25`、换行判据 `cur_x>24`。
- 'X' 指令：全分辨率分支**原值直设**且只作用于 `cur_y` 起的行（LvnsText.c:145-153）；`offset/=2` 仅存在于 MGL 半分辨率构建。
- 选择肢：每项整行 `text_attr=i+1` → **灰本体+黑双影**；高亮**无任何光标图形**——扫描 `attribute==text_cursor_state` 的格重画白（LvnsDisp.c:93-129）。
- 等待光标（XLVNS 常量）：按键等待=字形 **102**（实测槽101=实心▶）、翻页等待=字形 **103**（实测槽102=页图标），画在**当前格**（末字后一格、与本行同 YPOS）走完整三 pass，`flip_cnt%6` 每 6 帧翻转（LvnsControl.c:145-147/193-195）。

### 26.3 与本仓逐项对比结论

| # | 项 | 原版（XLVNS 实证） | 我们（本轮前） | 处置 |
|---|---|---|---|---|
| ① | 影子叠印 | **3 pass**：黑@(x+1,y+1)+黑@(x+2,y+1)+本体 | 仅 1 道影子 | **已补**：`drawTextLayer`/`drawMenuLine`/▼ 均加第二道 `x+2s` 影子（SceneComposer.swift），`SHIZUKU_SHOT=game,esc` 出帧目检：字影增厚 1px、无粘连退化 |
| ② | 字库逻辑回归测试 | — | **零覆盖** | **已补**：新增 `FontPipelineTests.swift` 6 项（1852 槽数、col-major 金标逐行宽、▶ 光标字形形状签名、identity 回退 leaf−1、越界槽 nil、MenuStrings 对照 sizfont.tbl 反查「はじめから」「１２３４５６」）；`swift test` **33/33** 绿 |
| ③ | 等待光标形状 | XLVNS 用字库 ▶/页图标；但 §23 用户实机记录为 **▼**（且字库无▼→原版应系引擎程序化绘制） | 自绘 9×5 ▼ | **保留 ▼**（实机观察优先）；**开放问题**：实机按键等待与翻页等待符号是否不同（▶/页图标 vs 统一▼）？待用户实机复核 |
| ④ | 文本原点 | offset16 / Y+8（LvnsInfo.h） | (20,18)（实机目检定） | 保留 (20,18)；**纠正 §21.3**：「起点(20,18)=LvnsInfo.h 原值」表述不实，该文件实为 (16,8)+行距28，我们的值是实机帧校准结果 |
| ⑤ | 文字颜色 | 白 255 / 灰 127 / 黑 0 | 240 / 150 / 10 | 差异 ≤15，视觉亲验过，暂不动；如需绝对保真可一键改 |
| ⑥ | 换行禁则 | Windows 原版（XLVNS）**无**禁则，纯 `cur_x>24`；GBA 版才有 17 类禁则码表 | 无禁则 | 与 Windows 原版一致，**不补**（GBA 特性勿移植） |
| ⑦ | 选择肢 UI | 纯文本行白/灰互换，无框无光标 | 暗色半透明框+`>`（§24-3 用户要求升级） | 保留（用户明示）；`>` 点阵已在 §24 修复 |
| ⑧ | 'X' 折半 | 全分辨率原值直设 | 折半（MGL 语义） | §24 视觉验证通过，保留；取证在案，若实机发现缩进偏小改原值 |
| ⑨ | 其余 | col-major、slot=leaf−1、空格占格、25 列、6-flip、常驻装载、每格存 attr | 全部一致 | 无需动作 |

### 26.4 防再错备忘

- GBA 系（akkera/gbalvns）字库是**离线烘焙的 12×10@4bpp 双表**（白/灰各一张、影子已烤进位图、0-based `code*3` u16），与原版 24×24@1bpp 列平面 1-based 完全不同构——凡从 GBA 源推字库结论必错。
- FONT_PLUS/MGL 分支（12px 系统字体、2bpp 外置、单影）均非原版行为。
- `shizuku_cli/cmd_cntext.py:4-6` 仍写已证伪的「CN=纯字库替换、slot=leaf」，属陈旧工具文案，勿引用。

## 27. 2026-09-21（★非原版字体全量替换：S/L 列表等所有 CoreText 文字改走 KNJ 点阵字库★）

> 用户问题：「有没有办法把目前所有非原作字体/字库的内容（比如 S/L 菜单里的字）全部替换成原版日文字库」。**结论：可行，已全部落地**。唯一保留 CoreText 的是中文热挂载层 `drawCNTextLayer`（M5 设计如此，日文字库无汉字简体字形）。

### 27.1 替换前调用点盘点

`SceneComposer.drawNativeText`（NSString+CGContext 抗锯齿）此前用于 7 处：backlog 标题/空提示、结局列表覆盖层（标题+`ED%02d` 行+达成徽章）、toast 气泡、确认菜单 `（１）（２）` 徽章、S/L 选择列表（页眉/行标签/时间/预览/底部提示）、标题菜单通关徽章（MetalGameView）。其余菜单（标题四项、ESC 六项、确认问句/はい/いいえ）本就走 leaf 点阵，无需动。

### 27.2 字库覆盖度实测（逐字符对照 sizfont.tbl）

- **有**：全角数字 ０-９（leaf 77-86）、全角字母 Ａ-Ｚ（无小写）、假名全集、常用汉字（含 月日時空選択確済変更可終了状況達 等）、`「」『』（）？・○−ー．↑↓`。
- **无**：一切半角 ASCII、全角小写、`：／×，；～＿【】★☆▲▼●◎□`、汉字 **歴、略、翻**。
- **纠错**：上轮记录「entry99=／」不实——实测 entry99=`!?` **连字格**（§26.1-3 的 ASCII 特例），字库根本没有斜杠。日期分隔改用 `月/日/時` 汉字，通关徽章 `9/13` 改写为 `１３中Ｎ`。
- LeafCodec 的 `uncovered(in:)` 把上述缺口全部暴露：首跑测试即揪出「自動略し」「翻訳」两词，文案改写为「自動スキップ」「中文データ」。

### 27.3 新基础设施

- **`ShizukuCore/LeafCodec.swift`**：启动读 `research/extracted/sizfont.tbl`（package.sh 已随 `*.tbl` 打包），EUC 对正排 `char→leaf` + 反排 `leaf→char`（decode 供存档预览）；`fold` 表把半角 ASCII 折到全角（数字/字母→全角大写，`(`→`（`，`-`→`−`，`:`→`・`，空格→U+3000=leaf0 占格），折不了的字符**静默丢弃**（覆盖率测试兜底）。`GameData.leafCodec` 注入，缺表时 `.empty`。
- **`SceneComposer.drawLeafText`**：任意 Unicode 串 → leaves → 逐格 24×24 三 pass 叠印（黑@(x+2s,y+s)+黑@(x+s,y+s)+本体，与 §26.2 drawChar 完全同构），返回右缘 x；`leafTextWidth` 供居中。**`UIText.swift`** 集中管理全部新字符串，注释即约束（必须过覆盖率测试）。

### 27.4 逐屏改写

| 屏 | 改后 |
|---|---|
| S/L 列表 | 三列点阵布局（640px=26.6 格）：标签≤8 格 @x12、日期 12 格 @x210、预览 5 格 @x504；页眉/`（から）`/底部提示全走 drawLeafText；日期格式 `MM月dd日 HH時mm`（无斜杠无冒号） |
| 存档预览 | 原来 JP 模式落到 `SCN100 MSG5` 兜底串——`Engine.captureSaveState` 改为 CN 译文 → **leaf 反查解码正文首行**（`leafCodec.decode`，取前 20 字）→ SCN 兜底。实帧 slot3 显示「細いシャ…」日文正文 |
| 标题徽章 | `１３中Ｎ` 点阵，并**修正错位**：原画在 line7（はじめから 旁），现挂 line9 エンディングリスト 行尾（本来的语义位置） |
| toast | 全部文案改写字库内字符（见 27.2 纠错）；`[ON]`→`（ＯＮ）` 由 fold 承担 |
| backlog/结局/确认徽章 | 标题、空提示、`ＥＤ` 行、`（１）（２）` 全点阵化；**结局列表改单列 13 行**（x16、行距 26px）——全角 24px 格下最长行 25 格=600px，CoreText 时代的双列必互相压字（首版出帧实测撞车后重排） |
| SlotRow | `label:[Int]` → `labelText:String`，MetalGameView 直传「オートセーブ/クイックセーブ/しおり　Ｎ」 |

### 27.5 测试与目检

- `swift test` **37/37** 绿（FontPipelineTests 9 项，新增 3：`testUITextStringsFullyCoveredByFont`（UIText 全部静态串+22 条 toast/页眉/日期串+**13 条结局标题** uncovered 必须为空）、`testLeafCodecFoldRules`（SCN001→ＳＣＮ００１、Tab→ＴＡＢ、`:`→・、歴=nil）、`testLeafCodecDecodeRoundTrip`）。
- `SHIZUKU_SHOT=title,esc,slotload,slotsave,confirm,backlog,endings,toast` **八帧逐张目检**（shot spec 新增 `backlog/endings/toast` 三帧）：八页内**已无任何抗锯齿字体**；S/L 三列无重叠；slot3 新档预览「細いシャ…」为 leaf 解码日文、旧档（slot1/2）`SCN..` 串经 fold 渲染成 `ＳＣＮ..` 全角优雅降级；backlog 标题的 ▲▼ 即字库 ↑↓ 格（1bpp 下形近实心三角）。
- shot 规格 `slotsave` 现会真实写 slot3（`_ = try? saveManager.save`），供预览链路回归。

### 27.6 遗留与故意偏差

- 中文层保留 CoreText（M5 热挂载设计；若要点阵化中文需另建 CN 字库，超出本任务）。
- 字库真缺 略/翻/歴 三字，文案已绕开；未来新 UI 文案必须先过 `uncovered(in:)`。

### 27.7 迭代：S/L 预览「选中行详情带」（用户反馈 5 格预览不够认档）

行内预览列取消（640px=26 格本来就塞不下整句），改为：槽行 28px 行距只放 标签+日期；列表下方 **2 行 ×26 格正文带**（y=328/352），内容随 ↑↓/鼠标悬停光标实时切换，空槽显示 `（から）`；提示行移到 y=376 贴底。配套改动：`captureSaveState` JP 预览从「首行 20 字」改为**前两行 leaf 拼接解码、上限 52 字**（正好填满带）；`SceneComposer.drawLeaves`（新公开 API，drawLeafText 的已编码 leaf 版，供定宽折行）；shot 帧 `slotload/slotsave` 会把光标停在有数据的しおり 3 上，目检两行带「細いシャープペンシルの芯をかちかちと伸ばし、意味も／なくノートのうえを走らせる。」无重叠、右缘 26 格恰好用满。旧档（≤20/26 字预览）只占一行，向后兼容。

### 27.8 迭代：本轮各页视觉观感排版打磨（用户反馈）

四处小改，全部经 `SHIZUKU_SHOT=title,slotload,slotsave,backlog` 导帧目检确认，测试 37/37 仍全绿：

- **S/L 选中光标**：选中的槽行左侧（x=12s）用字库 leaf 102 的 **▶**（sizfont 第 102 条目，XLVNS 的 cursor_key 同源）画金色三点叠印光标，替代原先仅靠高亮色区分，一眼可辨当前行。
- **详情带面板**：正文带（y=322..376）底下垫一层 x=8s..632s 的半透明暗化面板（背景压到 40%），两行预览与教室背景图分离，可读性大增；提示行与面板底边对齐。
- **槽行列位**：标签列移到 x=44s（给 ▶ 让位）、日期列移到 x=252s，行内间距均匀。
- **标题页徽章**：`１３中Ｎ` 徽章从 x=524s 移到 **x=428s**（=「エンディングリスト」文字 8 格×24s+起始位收尾处），紧跟文字而非飘在页面右侧。
- **backlog 正文**：由 CoreText 混排改为统一走 `drawLeaves` 三遍叠印（黑@+2s/+1s 双影 + 本体），字重与其余点阵页一致；头部的 ▲▼ 实测在字库内（27.2 的缺字清单不含 ▲▼，之前记录过窄）。
  - **※ 本条已被 §28 推翻**：半透明 backlog 覆盖层不是原版行为，已整体删除，改为全屏 シナリオ回想 mode。

## 28. 2026-09-21（★用户五项清单逐条取证并落地：全屏回想 mode / 快进是菜单命令 / 十字键无效 / 两种闪烁等待光标 / CG 转场 13 效★）

> 用户清单原文：「1.原版有回想mode 2.原版的快进是在windows窗口菜单单独的按键，而不是长按enter，长按enter是没用的，只有按一下是推进句子。3.原版的十字键是没用的。4.原版的闪烁三角是朝右边的，而且只在页还有其他句子时出现，如果本页结束会使用另外一种闪烁纸张标志 5.原版切cg会有转场效果。」**五条全部取证完毕并落地**，全部经导帧目检，`swift test` **37/37** 绿。取证基准仍是 `research/thirdparty/mglvns/mglvns-1.0`（`#ifndef USE_MGL` 分支＝原分辨率原版行为）。

### 28.1 回想 mode：`LvnsHistory.c` + `sizuku.c:SizukuDispHistory` 全语义还原

**入口两条**，都进同一个 `LvnsHistoryMode`：
- 等待中收到 `cursor_up` —— `LvnsControl.c:142-143`（`LvnsWaitPage`）与 `LvnsWaitKey` 同构分支：`else if (lvns->cursor_up) LvnsHistoryMode(lvns);`
- ESC 系统菜单第 4 项「シナリオ回想」—— `sizuku_menu.c:79` `MENULINE(6,"シナリオ回想",4)`（整表 EUC-JP 解码后为 文字を消す／ロードする／セーブする／**シナリオ回想**／一つ前の選択肢に戻る／ゲーム終了，与我们 ESC 六项同序）→ `sizuku_menu.c:124-127 case 4: LvnsHistoryMode(lvns)`。

**函数体语义**（`LvnsHistory.c:53-146`，逐条对齐）：

| 原版 | 行为 | 我们的落地 |
|---|---|---|
| 存 `scn/blk/fast_text/scn_offset` | 退出时 `LvnsLoadScenario` + 还原偏移，剧情状态零污染 | 回想是纯浏览态，退出即回 `.inGame`，引擎不动 |
| `fast_text = True` | 页内文字一次性出完，不做逐字 | `HistoryView` 一次排完 13 行 |
| `current_tvram = 1` + `LvnsClearText` | **第二块文字 vram**：图像层保留，文字层清空重填 | `mode == .history` 时 `backdrop = composer.render(engine, hideText: true)`（只取图像层） |
| `pos = lvns->history_pos - 1` | 打开即停在**最新一条** | `historyPos = max(0, engine.backlog.count - 1)` |
| `cursor_up && pos>0 → pos--` | 往旧走；**最旧一条再按不动**（无下界提示） | `historyUp()` guard `historyPos > 0` |
| `cursor_down`：`pos<history_pos-1 → pos++`，**else `cancel=True`** | 在最新一条按「下」＝**直接退出回想** | `historyDown()` 末支 `closeHistory()` |
| `lvns->cancel → break` | Esc/右键取消 | `rightMouseDown`、Esc/Enter/Space 均 `closeHistory()` |
| 退出：`current_tvram = 0` + `LvnsDispWindow` | 正文层重新显示 | 回 `.inGame` 走正常 `render` |

**页面绘制**（`sizuku.c:862-881 SizukuDispHistory`）：`LvnsClearText` → `LvnsDispWindow` → `SizukuDispText(..., history_mode=True)` → 两个导航字形。
- `history_mode=True` 使 `SizukuDispText` 内 **14 处 `if (!history_mode)` 守卫全部跳过**（`'p'`/`'k'` 等待、`'C'` 立绘、BGM、演出指令），整条消息一次性铺完 —— 所以回想页绝不会出现等待光标，也不会重放演出。
- 导航字形是**文字格不是按钮**：`LvnsLocate(CUR_X=25, 0)` + `LvnsPuts("↑", 1)`、`LvnsLocate(25, 11)` + `LvnsPuts("↓", 2)`（`CUR_X` 在 `#ifndef USE_MGL` 下＝**25**，即贴 640px 右缘；MGL 分支的 24 非原版）。命中检测由 `checkCursor()` 读鼠标所在格的 `attribute`，`select` 时 `attr==1→cursor_up`、`attr==2→cursor_down`（`LvnsHistory.c:35-50,96-108`）—— 与我们 `HistoryView.upArrowRect/downArrowRect` + `mouseDown` 分支同构。
- 配色：`drawChar`（`sizuku_etc.c:530-539`）黑影 @(x+1,y+1)、(x+2,y+1) 两遍，本体 `attr ? SIZUKU_COL_GRAY(127,127,127) : WHITE`。**attr≠0 只作用于 ▲▼（和被选中的选择肢文字），正文仍是白色**；`SIZUKU_COL_GRAY` 在 `SizukuStart`（`sizuku.c:851`）注册为 127/127/127。
- 背景：回想页正文压在 `LvnsDispWindow` 的文本窗上，视觉为「图像层暗化 + 点阵正文」。`HistoryView.render` 内部先 `img.scaleRGB(by: 11, of: 16)`（`latitude_dark`，与 §21 的文本窗暗化系数同源）再叠字。
- 字形：`↑`/`↓`＝leaf 1269/1270，在 KNJ_ALL 里就是实心 ▲/▼ 造型（沿用 §27.2 实测）。

**已删除的非原版实现**：`SceneComposer.drawBacklogOverlay(into:engine:scrollOffset:)`（半透明滚动条覆盖层，约 40 行）连同 `GameMode.backlog`、`backlogScrollOffset`、`UIText.backlogTitle/backlogEmpty` 一并移除；`SHIZUKU_SHOT` 的 `backlog` token 取消。App 侧新增 `.history` 态与 `openHistory/closeHistory/historyUp/historyDown/handleHistoryKeyDown`，滚轮上＝`cursor_up`（进回想/上一条）、滚轮下＝`cursor_down`（下一条/退出），ESC 菜单第 4 项与 'B' 键同入口。

**目检**：`SHIZUKU_SHOT=history` 出 `history_newest.png` / `history_older.png` —— 暗教室图上单条消息白字双影点阵、右上实心 ▲ 第 0 行、右下实心 ▼ 第 11 行，两者右缘齐 640px；两帧正文不同（首版两帧 md5 相同，根因是 shot 循环绕过 `run()` 只塞进 1 条 backlog，改走真实读者路径 `advance()` 后 `backlog=4 pos=3` 正常）。

### 28.2 快进＝窗口菜单单独命令；长按 Enter 完全无效

- 原版 `LvnsSkipTillSelect`（`LvnsControl.c:65-70`）：**只有 `lvns->seen` 为真才置 `skip=True`**，即未读消息不允许快进。skip 打开后 `LvnsWaitKey/LvnsWaitPage` 的整个等待循环包在 `if (!lvns->skip)` 里（`LvnsControl.c:126,175`）→ 自动推进，遇选择肢/未读自然停下。MGL 前端把它绑到 Alt/Ctrl+S（`mgAction.c:56-59`），Windows 版则是窗口菜单上的独立按钮 —— 与「长按 Enter」无关。
- 落地：菜单项「**選択肢まで早送り**」（`main.swift:170-171`，checkmark 驱动，再点即取消）→ `@objc toggleFastForward`；Tab/Z 只是同一 selector 的快捷键便利。守卫逐条对应：`engine.isCurrentMessageSeen`＝`seen`，`engine.forceSkip`＝`force_skip`（`SkipTillSelectForce`, `LvnsCore.c:307-317`）；`startFastForward` 在 `awaitingChoice`/`ended`/未读处自动 `stopFastForward`。
- **长按 Enter 无用**：`handleInGameKeyDown` 第一行 `if event.isARepeat { return }`（`MetalGameView.swift:1005`），自动重复事件被整体丢弃，只有离散按键才 `advance()`；`handleHistoryKeyDown` 同守卫。

### 28.3 十字键在游戏内无功能

- 原版 Windows 十字键不参与读盘；`cursor_up/cursor_down` 是 X11/MGL 移植才引入的抽象（`mgAction.c:39-46` 绑 `MK_UP`/`k`、`MK_DOWN`/`j`），且其语义是「开回想」「回想翻页」，**不是移动文字光标**；选择肢在原版靠鼠标悬停或数字键 1-9（`LvnsInputNumber`）。
- 落地：`MetalGameView.swift:1036` 显式 `case 123, 124, 125, 126: return // arrow keys — NO function during gameplay (original)`；↑↓ 仅在 `.history` 态内导航（＝原版 `cursor_up/down`），选择肢仍只由 `mouseMoved` 悬停或数字键选定。

### 28.4 闪烁等待光标：右向实心三角 vs 纸张图标，6 帧周期

- 闪烁机构：`LvnsDrawCursor`（`LvnsDisp.c:59-87`）`cursor_state==0` 时画、否则 `LvnsClearCursor` —— 调用一次翻转一次；`LvnsWaitPage/LvnsWaitKey` 里 `if (flip_cnt == 0) LvnsDrawCursor(...); flip_cnt = ++flip_cnt % 6;` → **每 6 帧翻明暗**。位置取 `tvram[cur_x,cur_y]`，即**当前文字格**（本页最后一行的下一格），不是行下方独立符号。
- 两种图形：`LVNS->cursor_key` / `cursor_page` 是**字库 leaf 号**（`Lvns.h:200-201`）。实测 slot＝leaf−1 的 KNJ 位图：102 → **实心右向三角 ▶**，103 → **纸张/文档图标**。（`sizfont.tbl` 把 102/103 解码成 ＞/＜ 只是文本层命名，位图才是真相；§26 已记此矛盾，本节定案。）
- 语义分工：`'k'/'K'`（句内/页内还有后续句子）→ `LvnsWaitKey` → ▶；`'p'`（本页结束、等待翻页）→ `LvnsWaitPage` → 纸张（`sizuku.c:249-264`）。与用户描述完全一致。
- 落地：`SceneComposer.drawContinueIndicator`（`SceneComposer.swift:300-323`）—— `let leaf = (pause == .pageBreak) ? 103 : 102`，`if (engine.flipCount / 6) % 2 != 0 { return }` 同周期，坐标按「最后一行已排字数」定位到当前格，且走 `drawLeaves` 三遍叠印（与正文同字重）。
- 目检：`wait_key.png` —— 「走らせている。」后紧跟实心 ▶，朝右；`wait_page.png` —— 「…り刺激した。」（页尾）后是纸张图标。两者均在文字行内格位而非行下。

### 28.5 CG 切换转场：13 效全表落地并逐效目检

- 原版：脚本图像指令的效果号 → `text_effect(c1,c2)`（`sizuku.c:112-126`）：两位数 `no`，`no==99 → LVNS_EFFECT_NORMAL`，否则索引 `sizuku_effect[13]`（`sizuku.c:92-107`）；`LvnsClear(effect)` 消旧图、`LvnsDisp(effect)` 出新图，解释器阻塞其间（文字层整段 `LvnsUndispText` 隐去）。此外固定用法：立绘载入 `'C'` 写死 `LVNS_EFFECT_FADE_MASK`（`sizuku.c:277`）、读档与「ここまで戻る」写死 `LVNS_EFFECT_WIPE_TTOB`（`sizuku_menu.c:104,133`）。
- 全表（序号→效果→实测几何）：

| no | 效果 | 目检结论 |
|---|---|---|
| 0 | FADE_PALETTE | 整屏调色板 Darken 16 级压到黑 → 新图 Lighten 浮现 |
| 1 | GURUGURU | 中心向外的方块螺旋旋转展开 |
| 2 | SLANTTILE | 16px 斜切瓦片，波前自左下向右上扫过，4 带 |
| 3 | FADE_SQUARE | 32px 方块以对角菱形从四角向中心生长淡出 |
| 4 | WIPE_SQUARE_LTOR | 32px 菱形方块阵自左向右扫过 |
| 5 | FADE_MASK | 4×4 有序 dither 网点均匀发展 |
| 6 | WIPE_TTOB | 横向梳齿逐行下落 |
| 7 | WIPE_LTOR | 细竖梳齿自左向右擦除 |
| 8 | WIPE_MASK_LTOR | 宽竖条掩膜自左向右推（与 7 同向不同齿宽） |
| 9 | VERTCOMPOSITION | 纵向逐行交错展开（垂直合成） |
| 10 | SLIDE_LTOR | 竖板自左向右加宽揭示 |
| 11 | NORMAL | 无转场，单帧硬切（`t=1.000`） |
| 12 | FADE_MASK | 与 5 同效（表尾重复项，两图 **md5 相同**，非缺陷） |

- 落地：`ShizukuCore/LvnsEffect.swift`（`enum LvnsEffect: Int, Codable, CaseIterable` + `LvnsEffectTiming.frames(effect,width:height:)`，帧数按图像宽高缩放，源出自 `LvnsEffect.c`/`lvnsimage_sximage.c`）+ `TransitionRenderer` + `composer.renderTransitionFrame(_:engine:)`；`ShizukuEngine.transition` 非空时 `run()` 让位（`MetalGameView.swift:581-586`），逐帧推进后再续跑指令，忠实还原「解释器阻塞在 LvnsClear/LvnsDisp 之间」。
- 验证双路：
  1. `SHIZUKU_DUMP_TRANSITIONS=1 shizuku <dir>` → 13 张 4 联帧（帧 0/¼/½/¾，源图 MAX_S01 → 目标 TITLE0），**逐张目检方向与形态全部正确**；exact-match 进度度量显示 frame 0 `f=0.94..1.00`、`t` 随进度单调升至 0.9+。
  2. `SHIZUKU_SHOT=trans` → 走真实脚本路径，逐帧泵 `LvnsClear→LvnsDisp`，每 6 帧采样并打印 `clear=`/`disp=` 效果名（单次运行 142 flips：clearing/holding/displaying 三段）。
- 坑：`MAX_C01.LFG` 是 240×400 立绘，不能当 640×400 转场源（探 LFG 头确认），必须用 `TITLE0`。

### 28.6 回归、验证与遗留

- `swift test` **37/37** 全绿。`SaveLoadTests` 原「覆盖层」用例改写为断言回想页：`HistoryView.entry(from:pos:)` 非空、`HistoryView.render(...)` 出帧、`upArrowRect(scale: 1).maxX == composer.nativeWidth`（▲ 必须贴 640px 右缘，即 `CUR_X=25` 的几何后果）。
- `SHIZUKU_SHOT` token 增 `history/waitkey/waitpage/trans`、删 `backlog`。
- 全部 5 项的目检帧：`history_newest/history_older`、`wait_key/wait_page`、`trans_00..12`（13 张）逐张看过并在此记录形态，未看过的不下结论。
- 遗留（M4.11 未完项）：`0x01` 指令子类型未全解；字幕表（credits 滚动）未做；转场目前覆盖 CG↔CG 与 load/restart 路径，脚本内其余固定效果号待脚本全量回归时补齐。
- 故意偏差（记录以免被误当 bug）：滚轮上/下映射 `cursor_up/down`（原版 X11 用 j/k 与 MK_UP/DOWN、Windows 用菜单按钮，macOS 无对应硬件键）；'B' 键进回想是额外便利入口；Tab/Z 快进快捷键同上，菜单项才是原版入口。

## 29. 2026-09-21（★用户实机六项清单全部修复：快进从不生效 / 转场未适配大窗 / 主菜单补「回想モード」CG 画廊 / 开机一次点击跳到主菜单 / 鼠标隔空命中菜单 / 菜单栏显示 NSMenuItem★）

> 用户清单原文：「1.快进无效 2.转场动画是按原分辨率来的，没有适配现在的大尺寸窗口 3.我说的原版的回想是在主菜单有一个回想mode选项，看cg的，在我们的restore版中缺失了 4进入游戏后按理说按一下鼠标跳过leaf logo应该是播开场op，而不是直接跳过来到主菜单 5.鼠标就算完全没有hover而且离按键很远也能点选，说明鼠标选择菜单项的逻辑有很大问题 6.菜单不应叫NSmenuitem」
> **六项全部落地**，逐项导帧目检＋System Events 实测，`swift test` **41/41** 绿（新增 `GalleryTests` 4 例）。
> 说明：§28 把「回想」理解成了游戏内文字回想（`LvnsHistory.c`），那是第 28 节做的事；本节 29.3 才是用户指的**主菜单看 CG 的回想モード**。两者并存、互不冲突（一个在 ESC 菜单第 4 项，一个在标题菜单第 3 项）。

### 29.1 快进无效：根因不在快进代码，而在 `seen_flag` 存错了文件

- §28 落地的 `toggleFastForward` / `startFastForward` 状态机本身是对的，但它的第一道守卫 `engine.isCurrentMessageSeen` **永远为假** → 菜单点「選択肢まで早送り」只会弹「未読のため…」，看起来就是「快进无效」。
- 原版：`int seen_flag[SIZUKU_SCN_NO]`（`sizuku.h`）由 **系统文件** 读写（`sizuku_file.c:70` 读、`:129` 写），所以它跨存档槽共享、重开游戏仍在、开新 game 不清零；`SizukuSetTextScenarioState`（`sizuku_etc.c:406-423`）用 `msg->no >= seen_flag[scn]` 判未读，`LvnsSkipTillSelect`（`LvnsControl.c:65-70`）只在 `lvns->seen` 为真时置 `skip`。
- 我们此前把 high-water 只塞进 **书签**（`SaveState.seenHighWater`），且 `restoreSaveState` 用 `=` 覆盖、`reset()` 直接清空 → 读档会倒退、开新游戏归零，实际游玩中几乎不可能满足守卫。
- 落地（`SaveManager.swift:63-66,261,265-269`、`Engine.swift:70-79,1104-1112,1206`）：`GlobalSystemData.seenHighWater` 进系统文件；`loadGlobalSystem` 灌回引擎；`persistSeenHighWater` 写回，App 侧 `seenPersistTick` 每 120 tick（2 秒@60Hz）节流一次，避免每次翻页都写盘；`restoreSaveState` 改为 `max(现值, 书签值)`（单调，老书签没记录也不会拉低）；`reset()` 不再清。
- 补齐 skip 生命周期两处：`mouseDown(.inGame)` 第一行 `if isFastForward { stopFastForward() }`（点击＝`LvnsSelect`，`LvnsControl.c:29-41` 会清 `lvns->skip`）；`handleInGameKeyDown` 在 `isARepeat` 守卫之后，任何非 skip 热键的离散按键同样 `stopFastForward()`。
- 提示文案改得可操作：「未読です。設定で未読スキップを有効に」（指向「早送り未読スキップ」＝原版 `force_skip`，`LvnsCore.c:307-317`）。

### 29.2 转场未适配大窗：mask 几何改在逻辑 640×400 网格上算，再整数倍还原

- 症状：1280×800 窗口下溶解/块效应看起来像「按原分辨率来的」——每块只有 16px 见方，视觉上细碎不成形。
- 根因：原版三个 mask 单位（32×32／16×16／4×4 一类）都是对**它自己的 640×400 屏幕**而言的绝对像素；我们在 2x 画布上直接套同一批常量，等于把每个块缩小了一半。
- 落地（`TransitionRenderer.swift:20-36,182-215`）：`render(effect:from:to:frame:)` 变薄壳，先按 `factor = from.width / logicalWidth(640)` 把两层 `shrink` 回逻辑尺寸、在逻辑网格跑原几何、再 `grow` 整数倍还原。因为层图像本身就是 640×400 的整数倍放大，`shrink` 取块内一点是**无损**的，`grow` 亦然 —— 既不改原版时序/帧数，也不引入插值糊边。
- 目检：`SHIZUKU_DUMP_TRANSITIONS=1` 在 1280×800 下出的 `trans_0_000..078`（clearing→displaying 全弧）逐张看过，块尺寸现在是画布的 1/20 而非 1/40，与 640×400 下观感一致。

### 29.3 主菜单「回想モード」CG 画廊（新增；**无可逆向对象，是设计项**）

取证结论先说清楚，避免后人误当成还原度缺陷：
> **【2026-09-22 更正论据】** 下面两条「原版没实现」的证据是**从 mglvns 移植源码**推出的，而 §30.3 已证明 mglvns 的缺失不等于原版缺失（音楽モード就是反例）。结论仍然成立，但要换成一手依据：**`Sizuku.exe` 的标题项指针表 `0x430ebc` 恰好 5 项，第 5 项是 `X56Y128` 的隐形音楽モード格，没有留给回想モード的第 6 项**。参见 §30.8.6。
- `sizuku_op.c:182-191` 的标题菜单只实现了三项，「回想モード」与「次回予告」整块在 `#if 0` 里；
- 全仓 `research/thirdparty/mglvns/mglvns-1.0` 搜索：**没有任何**绘制画廊的代码，只有 `ChangeLog.mglvns:22` 提了一句它打算用的棕褐色调。
- 所以本节是**按用户口径的设计**：解锁口径＝「按已读场景解锁」，界面＝「缩略图网格＋点选放大」（用户在 AskUserQuestion 里明确选的高成本项）；「次回予告」用户判定 1996 版没有（「我在原版游戏中通关也没有这个选项」），**不做**。

索引构建（`GameData.swift`，新增 `EventImage{name, scns}` 与 `eventImages()`）：走全部 197 个脚本，收集消息行内指令 `.bg/.visual/.hVisual/.bgAndPortrait` 引用的图，加事件 `0x0a`→MAX_S、`0x16`→HVS；只保留磁盘上真实存在的文件；排序 MAX_S → VIS → HVS，族内 `localizedStandardCompare`。结果 **90 张 / 8 页**（`GALLERY items=90 pages=8`）。

布局（`GalleryView.swift`，新文件 137 行）：4 列 × 3 行＝12 格/页，格 150×94，原点 (5,44)，间距 10 —— 四列 150＋三个 10 间距＝630，正好留 10px 边；三行末在 y=346，第 11 行留给提示文字。缩略图 **等比 fit＋黑边**（VIS 族尺寸很杂：480×393／504×400／504×348／520×368，绝不能拉伸）。降采样用新加的 `RGBAImage.resized(to:_:)`（`Renderer.swift:59-81`）**盒均值**而非取点：1996 素材大量使用有序抖动，取点会把抖动打碎成噪点。绘制顺序是 图 → 灰色格线 → 白色选中框；先画线会被满幅缩略图盖掉（首版 `gallery_open.png` 格线不可见即此因）。

解锁与渲染（`MetalGameView.swift:85-97,1158-1204`）：`item.scns.contains { seenHighWater[$0] ?? 0 > 0 }`，未解锁格**保持黑底＋居中「？」**（leaf 97，字库里有；「／」「覧」没有，所以提示语避开了这些字）。表头「回想モード」＝ `MenuStrings.recallMode`＝leaf `[304,814,139,101,169]`，用 `drawMenuLine(line: 0)` 走点阵字库；底部左「クリックで拡大　矢印で移動」、右对齐「Nページ目（全M）」。

交互（`MetalGameView.swift:1206-1292`、`mouseDown` `.gallery/.galleryZoom` 分支）：标题菜单第 3 项进入；↑↓ 走列并**跨页滚动**（90 张 8 页必须有），←→ 换页且环绕，Enter/Space 或点击放大，放大态任意键/点击溶回网格，Esc 回标题。格/页几何全是纯函数（`cellRect`/`pageCellRects`），命中用 `viewToNative` + `contains`，与 29.5 同约定。网格↔放大之间用 `SceneComposer.blend` 做 16 tick 线性溶解（`galleryFadeTick`，60Hz ticker 驱动，`currentFrame()` 的 `.gallery/.galleryZoom` 分支）。

标题菜单因此从 3 项扩到 5 项（`titleMenuItems`＝New Game／Continue／回想モード／エンディングリスト／Quit，`titleMenuFirstLine = 7`）；键鼠导航计数、数字键映射（18→0,19→1,20→2,21→3,23→4）、结局列表角标的 y 坐标全部改成从表推导（`endingsLine = titleMenuFirstLine + firstIndex(of:)`），不再写死行号。

- 目检 5 帧（全部逐张看过）：`gallery_locked.png`（零进度：满屏灰格线＋「？」，无艺术图泄漏）、`gallery_open.png`（MAX_S 已读页：缩略图铺满、格线可见、白框在选中格）、`gallery_vis.png`（VIS 页：480×393 上下黑边正确、非拉伸）、`gallery_zoom.png`（单张满幅 640×400）、`gallery_fade.png`（50% 溶解，网格与大图叠化中）。

### 29.4 开机一次点击直落主菜单：`CLICK_JUMP` 只跳到**下一个**标记

- 原版 `LvnsScript.c:29-40`：点击把脚本 PC 回卷到**下一个** `LVNS_SCRIPT_CLICK_JUMP` 标记，因此它只跳过当前这一段，绝不会跳过整段开机。jingle 与 OP 各带一个标记（`sizuku_jingle.c:88-111`、`sizuku_op.c:255-291`），OP 尾部是 `WAIT_CLICK` 才打开标题菜单。
- 我们的 `skipBoot()` 把 jingle 与全部 OP 阶段列在同一分支 → 一下点击直接 `.titleIn`，OP 永远看不到，正是用户说的「跳过来到主菜单」。
- 落地（`MetalGameView.swift:313-334`）：jingle 五段 → `.jingleOut`（jingle 自己的标记落点），`.jingleOut` 与 OP 十段 → `.titleIn`，标题三段 → `enterTitleMenu()`。OP 音乐仍由 `advanceBoot()` 在进入 `.opSizuku1` 时以 CD 轨 16（MUS14.OGG）单发播一次，不停止。
- 目检：`SHIZUKU_SHOT=bootclick` 逐个把 19 个 `BootStage` 设为当前态后调 `skipBoot()`，打印 `BOOTCLICK <from> -> <to>`，19 行全部与上表一致（jingle 系 → `.jingleOut`，OP 系 → `.titleIn`，标题系 → 主菜单）。

### 29.5 鼠标隔空命中：命中框与绘制几何同源，且带 x 轴约束

- 根因两条，都真实存在：① 标题菜单用 `SceneComposer.titleMenuRows()`，那是 `(x:80, width:480)` 的**全宽固定带**，只判 y → 鼠标在行的任意水平位置都命中，离字很远也选中；② ESC 菜单与确认框**完全没有 x 约束**，且命中不到时 `idx` 缺失仍会走默认分支。
- 落地：删掉 `titleMenuRows()`，新增纯函数 `SceneComposer.menuLineRect(leaves:line:canvasWidth:)`（`SceneComposer.swift:567-573`），并且让 `drawMenuLine` 自己用它算 `xStart`（`:584-589`）—— 几何与像素从此**同一来源**，改字号/居中逻辑不可能让命中框漂移。宽度随文字长度走：`width = leaves.count * 24`、`x = (canvasWidth - width)/2`，行高仍 24、`y = line*32 + 8`。
- App 侧 `menuRowFromPoint(_:items:firstLine:)`（`MetalGameView.swift:943-951`）统一供标题（`firstLine: 7`）／ESC（`3`）／确认（`6`）三处使用；**命中不到返回 nil，调用方一律不响应**（不再有默认分支）。存档槽选择列表是真·整行列表，用另算的 `slotPickerRowRects(count:)`（`:575-578`，x=8 宽 624）。文字回想页的 ▲▼、选择肢、画廊格也各自有精确矩形，不再有全屏带。
- 顺带把 `.history` 与 `.gallery` 的点击收敛为「只认控件框」：回想页只有两个导航字形可点、点空白不动（原版 `checkCursor()` 读所在文字格 `attribute` 的语义）。
- 目检：`SHIZUKU_SHOT=hit` 打印三张表全部行的 `menuLineRect`（MIN/MAX x,y）并写 `title.png`；把打印值和 `title.png` 上实际字形左/右边缘逐行对齐核对，四项菜单的文字起点 x 与 rect.minX 一致（长行 rect 明显更窄，如「つづきから」5 字＝120px 居中于 260..380，而旧实现是 80..560 全宽）。

### 29.6 菜单栏顶层显示「NSMenuItem」

- 根因：`main.swift` 建 `NSMenu` 时顶层 `NSMenuItem` 没给 title、`NSMenu` 也没给 title，AppKit 找不到名字时就把**类名占位符**印在菜单栏上。
- 落地（`main.swift:107-118,152-158`）：`appItem.title = ShizukuApp.name`、`NSMenu(title: ShizukuApp.name)`；游戏菜单顶层 `gameItem.title = "ゲーム"`、`NSMenu(title: "ゲーム")`。
- 实测（不是目检帧，是 System Events 直接读真实菜单栏）：顶层 `Apple, Shizuku_Restored, ゲーム`；应用菜单 `About Shizuku_Restored | 設定 (Settings) | Quit ... | Quit and Keep Windows`；ゲーム 菜单 `はじめから (New Game) | つづきから (Continue) | クイックセーブ | クイックロード | 選択肢まで早送り | システムメニュー (ESC) | フルスクリーン`。无任何 `NSMenuItem` 残留。

### 29.7 回归、验证与遗留

- `swift test` **41/41**：原 37 例全绿（含因 `menuLineRect` 替换 `titleMenuRows` 而调整的菜单几何用例），新增 `GalleryTests` 4 例 —— ①90 张索引逐张可解码且 `scns` 有序去重、族序 MAX_S→VIS→HVS 不违反；②每族抽 3 张真实解码（全 90 张解码一遍会让单测跑 49 秒，改共享 static fixture 后 8.3 秒）；③解锁规则＝`seenHighWater[scn]>0` 的边界（读 0/读 1/换槽共享）；④页钳制与 12 格全部落在 640×400 内且避开表头第 0 行、提示第 11 行。
- `SHIZUKU_SHOT` token 新增 `bootclick` / `hit` / `gallery`（含 5 帧与一行 `GALLERY items= pages=` 汇总）。
- 打包：`./package.sh` 产出 `build/Shizuku_Restored_Ver.0.1.app` 与 `.dmg`（399 个数据文件、gamedata 内已挂 `zh_text.json`）。首轮 `hdiutil create` 报 `Resource busy` 是**旧实例仍占着 .app**（PID 90295），结束旧进程后重跑 exit=0；不是打包脚本缺陷。
- 遗留（承 §28）：`0x01` 指令子类型未全解；credits 滚动字幕未做；画廊的棕褐色调（`ChangeLog.mglvns:22` 提到的**意图**，无代码）未做 —— 需要定口径：是解锁格统一加棕褐滤镜，还是只在放大态加。
- 故意偏差（记录以免被误当 bug）：①回想モード的界面、翻页、放大、溶解全部是我们的设计，原版 `#if 0` 无实现，**不要拿它当 fidelity 依据**；②画廊解锁跟着系统级 `seenHighWater`，所以它和快进共享同一份进度（见 29.1），这是原版 `seen_flag` 的本来归属；③开机点击只跳一段＝原版 `CLICK_JUMP`，若想要「一次点到底」应做成长按或设置项，而不是改这段语义。

## 30. 2026-09-22（★用户实机六项清单：macOS 菜单语义重设计 / 画廊只收绘画 CG / 反汇编取证并落地原版「音楽モード」 / 转场整屏观感与 `enable_effect` / 去掉「13中1」徽章 / 转场期点击吞页★）

> 用户清单原文：「1.当前这个设定和ゲーム菜单也太不明确了，能不能重新设计一下菜单 2.回想mode原版只有绘画的cg，而不包括背景，详细研究一下 3.原版在主菜单页面点击大楼右侧田字窗口右上角这个会打开音乐播放器，详细研究原版的音乐播放器触发位置和音乐播放器 4.这个转场是从画面左侧播一次转场再把右边用另一种播放模式填满，很突兀很奇怪，有办法让转场全屏还原原版的效果吗 5.这个结局选单的13中1实在是太奇怪了，去掉吧 6.可稳定复现的bug：在播放转场时候点击esc菜单会让转场先卡在当时的状态，然后点击推进剧情会只推进每页的第一句，然后直接换页，且没有小三角指针/翻页图标，直到背景被切换」
> **六项全部落地**，`swift test` **46/41→46/46** 绿（新增 `TransitionTests` 5 例），逐项导帧目检。第 3 项是本轮唯一的**新逆向成果**，取证链最重，单列 30.3。**二次 debug＋视觉复核见 30.8（基线升到 51/51，另修一个旧 bug）。**

### 30.1 macOS 菜单栏按意图重排：`ゲーム` / `設定` / `表示` 三个顶层菜单

- 症状：旧结构把「設定」塞在应用菜单里、只有两项开关＋一个子菜单，而 `ゲーム` 菜单里混着全屏开关；标签是裸日文，用户读不出哪个是哪个。
- 落地（`main.swift:107-215`）：三个按**意图**划分的顶层菜单 —— `ゲーム`＝流程与存档（はじめから／つづきから／音楽モード／クイックセーブ⌘S／クイックロード⌘L／選択肢まで早送り⌘T／システムメニュー⌘E）、`設定`＝文本推进（既読自動略し／未読もスキップ／スキップキー子菜单）、`表示`＝画面与语言（フルスクリーン⌃⌘F／画面エフェクトを省く／表示言語）。
- 两条硬规矩：①**每一项都带中文注释**（「はじめから（重新剧情）」这种格式），因为裸日文标签读不懂；②**快捷键由 AppKit 自己印在菜单上**，所以全部改成 `keyEquivalent` 传入，不再靠"记键位"。
- 实现上抽了两个本地函数消掉重复：`topMenu(_:)`（顶层 item **必须显式给 title**，否则菜单栏印类名占位符，见 29.6）与 `add(_:_:_:_:key:mask:)`（带 target 才能把校验送到 `MetalGameView.validateMenuItem`；AppKit 自带命令传 nil 走响应链）。
- 刻意不给 ⌘N：「はじめから」会直接丢掉进行中的剧情，误触代价高。

### 30.2 回想モード画廊只收「绘画 CG」，剔除背景板

- 用户判定：原版回想里能翻到的只有插画 CG，不含背景；我们 §29.3 的索引把 `MAX_S` 也收进来了，所以满屏是空镜头。
- 取证（`Engine.swift:459-472` 的事件表与脚本内联指令）：**分类的唯一依据是"哪条指令把它装进哪个槽"** —— `'B'`/`'E'`/`'S'` 与事件 `0x0a` 一律写 `MAX_S%02d` 到 **背景槽**（注释即 `BG MAX_S%02d — load into tvram only`），是场景板；`'V'`→`VIS%02d`、`'H'` 与事件 `0x16`（`HBG HVS%02d`）才是插画 CG 槽。
- **用户明确否决了"按复用次数判定"这条捷径**：「强调一下，插画cg根据不同的剧情，分支走向，设定，也可能会出现多次，并不是绝对的」。所以 `eventImages()` 不看引用次数，只看指令族（`GameData.swift:141-204`）。
- 结果：`eventImageFamilies = ["VIS", "HVS"]`，索引从 **90 张 / 8 页** 收敛到 **61 张 / 6 页**（`GALLERY items=61 pages=6`）。`MAX_C%02X`（事件 `0x11/0x12` 的选择肢差分图）同样不属于插画，未收。
- 目检：`gallery_open.png` 首屏现在是 VIS 族插画而非空镜头，`gallery_locked.png` 仍全黑格＋「？」。

### 30.3 ★原版「音楽モード」完整取证并落地（本轮唯一的净新增逆向成果）★

**先纠正一个此前的错误结论**：§29 曾按 mglvns 全仓搜索无果而判定「音乐播放器不存在、是设计项」。**错在只搜了 C 源码**。mglvns 是 Linux 移植，没实现这个模式；**Windows 原版 `Sizuku.exe` 里有完整的实现**，只是入口是一个**看不见的菜单项**，所以从界面上一辈子也发现不了。取证走反汇编（capstone＋pefile，全程只读，中间产物全在 `/tmp`）。

取证链（偏移均为 `Sizuku.exe` 文件偏移＝VA−0x400000）：

1. **入口**：标题菜单的项指针表在 VA `0x430ebc`（文件 `0x30ebc`），**五个**指针而非四个：`0x430ebc / ed0 / ee4 / ef8 / f0c`。前四项的字符串只有字形、没有任何坐标码（由通用菜单引擎自行堆叠）；第 5 项（`0x30f0c`）是 `73 30` `X56Y128` `ff ff` `72 24`，即 **"s0" + 字面 ASCII 定位码 + 一个空格单元 + "r$""** —— 一个用 `X/Y` 单独摆到画面上、内容为空、因此完全不可见的第五菜单项。派发表 `0x409558` case 4 → `0x409537` → `0x408d40`。
2. **坐标单位**：`X` 以 **8 像素**为单位、`Y` 以 **1 像素**为单位。这条由房间自身反证：三个按钮串是 `X22Y300前の曲` / `X37Y300演奏` / `X49Y300次の曲`，按 `X×8` 得 176/296/392，三串宽度 72/48/72，左右间距都是 48px，且整体**正好以 320（画布中心）对称**；按别的单位解释不可能这么齐。于是入口＝原生 `(448, 128)`，即大楼右侧那栋塔楼上排窗子的右上角 —— 与用户描述逐字吻合（`title_music_hint.png` 里白框正压在那扇窗上）。
3. **房间主体 `0x408d40..0x408eb8`**：清屏 → 停 BGM → 播 slot 0（リーフ）→ 淡入 → 画表单 → 进入**只读鼠标**的三按钮循环（`0x408e11`）。选择 0＝上一曲（0..23 环绕）、1＝演奏（`cl = playno[esi]`，表 `0x30f48`）、2＝下一曲、`0xffff`（右键）＝经 `0x408e9e` 退出。
4. **卡片主体 `0x408c70(esi=序号, edi=行)`**：把 `esi` 的两位十进制写进 `ＮＯ．００` 模板（串 `0x30c3c`，+9/+11 是两位字形叶码的低字节），曲名查指针表 `0x430e28[esi]`，作曲查索引表 `0x430e88[esi]` → 指针表 `0x430cac`。文字绘制是 `0x412350(x, y, str, ...)` —— 参数顺序由它序言把 arg2 写进画笔 Y 字 `0x43c406`（`Y` 控制码写的同一个字）钉死。
5. **24 曲名＋24 作曲名**用 `sizfont.tbl` 解码（`code = ((b0 & 0x7f) << 8) | b1`）。**踩坑记录**：串以 `73 30`（"s0"）开头、以 `0x24`（"$"）结尾，但 `0x24` 也会作为**第二个字节出现在合法叶码里**，用 `find(b'$')` 会在曲名中间截断（「叔父さん」只剩「叔」）——必须**按 2 字节步进**只认首字节为 `0x24` 的位置。
6. **槽号＝MUS 文件号**：slot 0＝リーフ＝`MUS00.OGG`（开机 jingle）、slot 14＝オープニング＝`MUS14.OGG`（OP），两头都对上；`playno` 表只是 CD-DA 轨号（跳过 14），对我们没用，所以 `ＮＯ．` 显示的是槽序号（与原版一致），代码里不留 `cdTrack` 这种死函数。
7. **交叉验证**：24 条作曲署名与仓库内《原声OST（无损）》比对，**22/24 完全一致**，只有 logo sting 与门铃两条不同 —— 说明解码没有系统性错位。

落地（`ShizukuRender/MusicRoom.swift` 新文件 200 行＋`MetalGameView.swift` 的 `.musicRoom` 模式）：`render(game:playing:selected:hovered:scale:)` 画黑底表单（标题 `音楽モード` 5 字居中于 260、两张卡 `演奏中の曲`/`選択中の曲` 在 y=100/200、`作曲・編曲` 在各自下方 30px、三按钮在 y=300 的 176/296/392），全部走 KNJ 点阵字库＋三遍叠印。交互：`mouseDown` 在 `.titleMenu` 分支里**先测入口命中框再测菜单行**（否则会被最近的菜单行吞掉），房间内只认三个按钮框、右键/`ESC` 退出、悬停高亮按钮。

两处**故意偏离原版**，都写进注释以免后人当还原度缺陷：①原版入口是隐形空格、没有任何提示，我们在**鼠标悬停到那一格时**才画出白框＋「音楽モード」标签（不悬停时标题画面与原版像素一致，见 `title.png` 与 `title_music_hint.png` 的对比），另外在 `ゲーム` 菜单加了一项「音楽モード（音乐播放器・仅标题画面）」，并用 `validateMenuItem` 限定只在标题画面可用；②原版只能右键退出，我们额外接受 `ESC`，并在画面底部画一行暗字提示「右クリックまたはＥＳＣで終了」。

### 30.4 转场「左一遍右另一遍」的观感：整屏几何修正 + 原版自带的 `enable_effect` 开关

- 用户观感：「从画面左侧播一次转场再把右边用另一种播放模式填满，很突兀很奇怪」。
- 结构上这**不是 bug**：一次切换＝ `LvnsClear`（擦除效）＋ `LvnsDisp`（显示效）**两段**，`B07 08 08` 就是 56+56+30＝142 次翻转，两段各扫一遍屏幕是原版本来的行为。
- 真正让它"看起来怪"的是 29.2 那条：mask 单位（32/16/4 px）是按原版 640×400 屏幕定义的，我们过去直接在 2x 画布上套同一批常量，块只剩一半大，扫过画面时碎成细密的马赛克，两段就明显读成"两次不同的填充"。`TransitionRenderer.render` 现在先把两层 `shrink` 回逻辑 640×400、在逻辑网格跑原几何、再 `grow` 整数倍还原（层图本身就是整数倍放大，**无损、不插值**），块尺寸回到画布的 1/20，整屏就是一个连贯的效果了。
- 同时把**参考引擎自己的开关**接进来给怕晕的人：mglvns `mgMain.c:76-79` 的 `-n e` → `lvns->enable_effect = False`，此时 `ClearEffect`/`DispEffect` 短路成 `drawWindow`+flush+return True（`LvnsEffect.c:741-745, 810-814`），也就是**两段都保留但各自塌成一次整屏 blit**（`B07 08 08` 变 1+1+30＝32 次翻转），DISP 后的停顿不变。我们照抄这条路径实现为 `engine.effectsEnabled`（`Engine.swift:91-99, 278-285`），入口在 `表示` 菜单「画面エフェクトを省く（关闭转场动画，直接切换）」，持久化进 `GlobalSystemData.effectsEnabled`。**这不是我们发明的模式，是原版发行行为**。
- 目检：`SHIZUKU_SHOT=trans` 现在跑 on/off 两遍（off 遍每 2 帧、on 遍每 6 帧导一张），`trans_on_*.png` / `trans_off_*.png` 逐张看过：on 遍能看到块状擦除→黑→块状显示→停住的完整弧，off 遍是整屏一步切换后进入同样的 30 帧停顿。

### 30.5 去掉标题菜单的「13中1」计数徽章

- 用户：「这个结局选单的13中1实在是太奇怪了，去掉吧」。它原本是贴在「エンディングリスト」行右边 `(428, 9*32+8)` 的一个 `UIText.endingsBadge` 串。
- 落地：`titleFrame()` 里整段徽章绘制删除，`UIText.endingsBadge` 连同它在 `allStaticStrings` 覆盖率表里的条目一起删掉（不留兼容壳）；`GlobalSystemData.clearedEndings` 本身保留，因为**通关解锁判定和画廊/结局列表都依赖它**，去掉的只是标题画面上那个数字。
- 目检：`title.png` 上「エンディングリスト」行右侧干净，无残留字形。

### 30.6 ★转场期点 ESC 卡死 + 之后"每页只出第一句就翻页、无等待光标"：一个守卫解决两半★

- 复现路径与两个症状同源。转场进行中按 ESC → `openEscMenu()` 把 `mode` 切走 → 60Hz ticker 不再驱动 `engine.tickReveal`，`engine.transition` 就**永远停在中间态**（症状一：卡住）。回到游戏后点推进 → `advance()` 照常调 `engine.advanceMessage()` 改了消息位置，但 `run()` 的循环条件是 `while ... transition == nil`，转场没结束它一步都不走 → **位置被吃掉、画面从没绘制**（症状二：只出第一句就翻页，而且因为从没进过 `.awaitingMessage` 的绘制路径，▼/翻页图标也不出现，直到背景切换把转场整个冲掉）。
- 原版语义：`LvnsClear`/`LvnsDisp` 的翻转循环**根本不轮询输入**（`LvnsEffect.c:906-908`、`LvnsDisp.c:200-213`），所以转场期间的点击就是被丢弃的。
- 落地两处：①`openEscMenu()` 加 `guard mode == .inGame, engine.transition == nil`（转场期不给开系统菜单）；②`advance()` 开头加 `guard engine.transition == nil else { startTicker(); return }`（转场期点击＝空操作，顺手把 ticker 拉回来，防止任何原因导致的停摆）。
- 取证探针：`SHIZUKU_SHOT=escfreeze` 现在跑三趟对照 —— `preguard`（旧行为：直接调 `advanceMessage()`+`run()`）、`old`、`fixed`，各自在转场中途灌 3 次点击，打印 `seg/lines` 的变化与耗尽后的状态。结果：`preguard: 3 mid-effect clicks moved seg/lines (0, 0) -> (0, 3)`（吃掉 3 个 segment），`old`/`fixed`: `(0, 0) -> (0, 0)`（输入被丢弃，位置不动）。
- 目检四帧（逐张看过）：`escfreeze_fixed_drained.png`＝转场结束后正常的第一屏 3 行；`escfreeze_preguard_drained.png`＝4 行（有一段被吃掉、从未绘制）；`escfreeze_fixed_click2.png`＝整页文字正常；`escfreeze_fixed_click3.png`＝消息结束后的清屏态。

### 30.7 回归、验证与遗留

- `swift test` **46/46**（§29 是 41/41）：新增 `TransitionTests` 5 例锁住第 4 项的两条形状 —— ①`beginTransition` 的 `clearing→displaying→hold` 相位边界正好落在 56/56 帧（`WIDTH/16 + 16` 状态）与 30 帧停顿上；②总翻转数＝56+56+30＝**142**，与 `SHIZUKU_SHOT=trans` 从真实 `B07 08 08` 脚本数出来的一致；③`effectsEnabled=false` 时两段都塌成 `.normal`、总数＝1+1+30；④`wipeMaskLtoR` 在 640×400 上最后一帧必须**覆盖满屏**（不许只扫掉左半边）；⑤同一效应在 1280×800 层上输出仍是 1280×800 且同样扫满 —— 防止有人再把 mask 常量按画布尺寸写死。
- `SHIZUKU_SHOT` token 新增 `music`（3 帧＋入口/按钮几何一行汇总），`trans` 改为 on/off 双跑，`escfreeze` 改为三趟对照。
- 命中框实测：`MUSIC entry=x=448 y=128 w=24 h=24 buttons=x=176 y=300 w=72 h=24 | x=296 y=300 w=48 h=24 | x=392 y=300 w=72 h=24`；对照 `hit` 打印的标题菜单行（y=232/264/296/328/360），入口在 y=128、x=448..472，**与任何菜单行都不重叠**，所以"先测入口"不会有歧义。
- 目检帧清单（本轮全部逐张看过）：`title.png`（无残留徽章/无白框）、`title_music_hint.png`（悬停白框正落在塔楼上排窗）、`music_room0.png`（slot 0＝リーフ／折戸伸治）、`music_room17.png`（演奏 14＝オープニング、选择 17＝バッドエンド，7 字曲名不越 640 边界，「演奏」按钮高亮）、`gallery_open.png`/`gallery_locked.png`/`gallery_vis.png`（61 张新索引）、`trans_on_*.png`/`trans_off_*.png`、`escfreeze_*` 四张。
- 音频部分**无法在导帧里验证**：`openMusicRoom` 播 slot 0、`演奏` 换曲、退出停曲，这些只做了代码路径核对，需要用户在打包版里实听。
- 遗留（承 §28/§29）：`0x01` 指令子类型未全解；credits 滚动字幕未做；画廊棕褐调口径未定；`bgmap()`/`palmap()`（地点 ID → 文件＋调色板替换）仍未实现，所以 `'B'41`/`'B'54` 这类地点号会解析错位 —— 这是**下一个真实的还原度缺口**，不要当成素材缺失。
- 故意偏差汇总（新增）：①音楽モード的悬停显形与菜单入口是我们加的可达性，原版只有一个隐形格；②房间内 `ESC` 与底部提示行同理；③音乐室不做原版的淡入动画（需要 ticker 驱动，收益低），进房即成图。

### 30.8 二次 debug＋视觉复核轮（2026-09-22；本节是 30.1–30.7 的验收，基线 46→**51/51**，构建 Ver.0.4）

> 用户要求：「在做完后详细debug确认行为符合预期而且没有导致新的bug，然后再次视觉验证，然后确认无误后更新handover并且打包一个新的dmg构建」。结论：**六项行为全部复核通过**，新发现并修掉 **2 个旧 bug**（30.8.3 结局列表残影、30.8.9 全屏项标题被 AppKit 改写），补强 **1 处证据**（30.8.4），纠正 **3 处注释里的取证依据**（30.8.6）。

1. **回归基线**：`swift build` 零警告；`swift test` **51/51**（46 旧例全绿＋`MusicRoomTests` 5 例）。`SHIZUKU_SHOT` 全 token 重跑一遍：`TRANS on flips=142` / `TRANS off flips=32`（与 30.4/30.7 锁死的数字一致）、`GALLERY items=61 pages=6`、`MUSIC entry=x=448 y=128 w=24 h=24`、`HIT` 三张表的行宽随字数走（title[3]＝9 字＝216px 居中于 212..428）、`BOOTCLICK` 19 段仍严格 jingle 系→`.jingleOut`／OP 系→`.titleIn`、`WAIT` 两态 `pause=waitKey|pageBreak` 正确。
2. **新增 `MusicRoomTests`（5 例）的动机是「静默失败」**：`MusicRoom.draw` 走 `if leaf != 0, let px = font.pixels(...)`，**字库缺字时直接跳过、不报错**，而 24 条曲名/作曲名全部来自 exe 串表、此前只实拍过 slot 0 与 17 两帧 → 两帧不能证明另外 22 条拼得出来。锁的五条：①24 曲名＋3 作曲名＋5 条固定文案＋24 种 `ＮＯ．%02d` 全部 `codec.uncovered == []`；②`titles.count == composerOfTrack.count == 24`、credit 索引合法，且 **24 个槽位逐个 `AudioController.bgmURL != nil`**（否则播放器一开就是哑的，而这正是导帧唯一验不到的东西）；③按钮宽度 `[72,48,72]`、中心＝320、左右对称 —— 把 30.3 的「X 以 8 像素为单位」从注释升级成断言；④入口 24×24 与五行标题菜单 `intersects == false` —— 「先测入口再测行」的顺序前提；⑤最长曲名「トゥルーエンド」（7 格）不越 640。
3. **修掉一个旧 bug（不是本轮引入）：结局列表中间透出标题菜单选中行**。`.endingsList` 帧用 `titleFrame()` 打底，而 `drawEndingListOverlay` 只做 `img.blendBlack(215)`，于是**当前高亮那一行（白 255）会以约 16% 亮度残影浮在 ED 表中间**（修前帧里能清楚看到「はじめから」）。改为 `composer.titleBackdrop()`（与 `.slotPicker`/`.escConfirm` 从标题进入时同源），残影消失、只剩 16% 的 TITLE 美术底。**教训：叠加式暗场不能拿「带文字的帧」打底，只能拿纯背景打底。**
4. **item 6 的证据补强**：`escfreeze` 探针的 `state()` 现在打印 `pause=`／`cursorShown=`，并新增 `blinkOn()`（头里环境没有 60 Hz ticker，先把闪烁相位钉到可见半周再导帧）。实测：`fixed` 三趟里中途 3 次点击 `seg/lines` 保持 `(0,0) -> (0,0)`，之后 6 次点击的每个停靠态都带 `waitingPause`（`waitKey`→`pageBreak`→`messageEnd` 轮转），`cursorShown=true`；`preguard` 则把 seg 0（3 行）整个吃掉（drained 帧 4 行、seg 从 1 起）。`escfreeze_fixed_click1.png` 上 ▶ 光标清晰可见。**教训：验证闪烁元素必须先固定相位，否则正确的状态也会拍出「没有光标」的假象。**
5. **菜单一致性**：`システムメニュー` 在转场期间改为**灰掉**（`validateMenuItem` 与 `openEscMenu` 的守卫同源），消除「看着能点、点了没反应」；`クイックセーブ/ロード` 不受该条件影响 —— 因为 `restoreSaveState`/`reset()` 本来就把 `transition = nil`，读档天然能打断转场，不需要额外禁。
6. **纠正 3 处注释的取证依据**（都犯了 §30.3 刚批评过的推理）：`GalleryView.swift` 文件头、`MenuStrings.recallMode`、`MetalGameView.openGallery` 原本写「原版有这个菜单项、只是 `#if 0` 没实现」—— mglvns 的 `#if 0` 只说明移植者没做。正确依据：**exe 的标题项指针表 `0x430ebc` 恰好 5 项，第 5 项已确认是 `X56Y128` 的隐形音楽モード格**，没有留给回想モード的第 6 项 → 画廊仍是设计项（结论不变，论据换掉）。
7. `music` 探针补第三帧 `music_room15.png`：上卡＝最长曲名「トゥルーエンド」／折戸伸治，下卡＝「叔父さん」／下川直哉（第三个署名），高亮在「次の曲」—— 覆盖 24 槽里最极端的文案长度与署名轮换。
8. **逐张看过的复核帧**：`title.png`（无徽章、无白框）、`title_music_hint.png`（白框落在塔楼上排窗）、`music_room0/15/17.png`、`gallery_open.png`（61 张／6 页，全是插画、无空镜头，第三行三张棕色是 HVS 原画自带色调）、`endings.png`（修前/修后对照）、`esc_menu.png`（6 项、首项白、其余灰）、`confirm_end.png`（はい/いいえ 黄白高亮、行宽 48/72）、`wait_key.png`（▶ 落在当前文字格）、`escfreeze_fixed_click1.png`、`trans_on_030_clearing.png`/`trans_on_066_displaying.png`（块＝画布 1/20，两相都扫满整屏、方向一致）。
9. **实机菜单栏审计（System Events 直读真实菜单，不是截图）**：顶层 `Apple / Shizuku_Restored / ゲーム / 設定 / 表示`，无 `NSMenuItem` 占位；标题画面下 `ゲーム` 的「はじめから／つづきから／**音楽モード**」enabled＝true，而「クイックセーブ／クイックロード／選択肢まで早送り／システムメニュー」全部 enabled＝**false**（30.1 的守卫与 `validateMenuItem` 都对上了）；`設定` 的两个开关＋`スキップキー` 六个子项、`表示` 的 `表示言語`（日本語／中文）均正常枚举。**审计中抓到一个真 bug 并已修**：`フルスクリーン（全屏）` 实际显示成 AppKit 自动改写的 **"Enter Full Screen"** —— 只要 item 的 action 直接指向 `NSWindow.toggleFullScreen(_:)`，AppKit 就会按窗口状态重命名标题，中文注释被吃掉。改为走我们自己的 `MetalGameView.toggleFullScreenFromMenu()`（`main.swift:194`），并用 `AXFullScreen` 属性做了往返点击测试：`before=false → after1=true → after2=false`，标题保持 `フルスクリーン（全屏）`。**教训：菜单栏的文案验收必须读真实菜单，代码里写的 title 不等于屏幕上显示的 title。**
10. 遗留不变：音频仍需用户实听；`bgmap()`/`palmap()`；`0x01` 子类型；credits 卷轴；画廊棕褐调口径。

## 31. 2026-09-22（★用户九项清单第二轮：`bgmap()`/`palmap()` 落地 / 只有 ▼ 的空白页 / 快进三档速度 / 音楽モード音乐盒淡入节拍 / ★通关 staff roll 全还原★）

> 本轮口径：九项清单里 **2／4／5／6／7／8／9 共七项**已落地并逐帧目检；**1（logo/OP/▼ 节奏）** 与 **3（CG→背景残留时序）** 仍待用户在 Ver.0.6 上实机判定，**未凭猜测改代码**。基线 51→**58/58**，构建 **Ver.0.6**。

### 31.1 项2：`ShizukuCore/BackgroundMap.swift` —— §30.7 点名的「真实还原度缺口」补上

- 依据：mglvns `sizuku_etc.c:206 bgmap()`、`:265 palmap()`、`:135 sizuku_haikei_palette[][4][3]`。此前我们把「地点号」直接当「文件号」用，所以 `'B'41`/`'B'44`/`'B'54` 这类会取错图甚至取不到（黑屏）。
- `fileNumber(forLocation:)` 是 23 条折叠（`4/5→2`、`6→3`、`32/33→31`、`35/36→34`、`38→11`、`41/42→15`、`43/44→10`、`45/46→30`、`47/48→22`、`49/50/53→12`、`51/52→24`、`54→18`、`55→19`），文件名规则 `MAX_S%02d`；**地点 0 → 空串＝纯黑**（`SizukuLoadBG` 的 `no==0` 分支是 `lvnsimage_clear` + `pal_default`，不是"没图"）。
- `palette(forLocation:)`：C 里返回 `-1` 的位置给 `nil`；`BackgroundPalette` 9 档（day…yuugata2），每档 4 组 RGB 三元组，**只替换调色板 0…3**（`paletteEntryStart = 0`）。所以"同图不同气氛"是换色不换图：`41`/`42` 都落到文件 15，而 `42` 的调色板是 0（昼）——这正是原版同一张底板的两种天气。
- `PaletteOverride`（`start` + 每色 3 字节的 `rgb`）是 `Hashable/Codable`，因此能塞进存档并由 `GameData.image(name:paletteOverride:)` 复现。
- 附带补一个孤儿：`vis21FileNumber = 2` + `vis21Override`（16 色紫调）。`VIS21.LFG` 从未随包发布，原版 `SizukuLoadVisual` 的 `no==21` 分支就是拿 02 号底板换色顶替，不是素材缺失。

### 31.2 项6：只有 ▼／翻页符的空白页 —— `Engine.skipInertSegments()`

- 位置 `Engine.swift:678`（`beginMessage` 尾部）＋ `:696-711`。判定：本段自身 `glyphCount(seg.lines) == 0`（`isInertSegment`，`:688-690`）**且**此前各段还没落下任何字（`glyphCount(screenLines) == 0`，`:700`）才继续吞下一段。
- 依据 `sizuku.c:240-242`：`'$'` 只是终止串，既不产生等待也不画光标 ⇒ 纯 `'B'/'S'` 指令段绝不该花掉玩家一次点击。探针 `SHIZUKU_SHOT=inert`。

### 31.3 项8：快进「跑到下一选择肢才停」＋三档速度

- 停止条件按 `LvnsSkipTillSelect` 语义：`toggleFastForward`（`MetalGameView.swift:717-735`）只在 `.awaitingChoice`／`.ended` 收手（`:745-747`，注释即「`LvnsWaitSelect` is what clears `skip`」）——落实用户口径「只要不动就不会停下，直到快进到下一个选择肢」。
- 三档 `fastForwardSpeedChoices`（`:85-87`）＝每次触发的定时器间隔 `遅い 0.08 s`／`普通 0.04 s`／`速い 1/60 s`，按 60 Hz 折成约 **4.8／2.4／1 翻转一步**；`速い` 就是参考引擎的一翻转一步。默认 `fastForwardSpeedTier = 1`（普通，即用户说的「当前速度是中」）。持久化键 `sys0.fastForwardSpeed`（`:242`、`:312`，`nil`→1）。快捷键默认 Tab（keycode 48）。

### 31.4 项5：音楽モード补完 —— 音乐盒底板与原版淡入节拍

- 底板 `MusicRoom.plateName = "VIS17"`（504×400，原生 (0,0) 处 blit）。取证：`0x408d45 push 0x11; call 0x405c20`（`0x11`＝17）——「进房先摆音乐盒这张图」，与用户在 Parallels 里实拍一致。
- 原版节拍（用户要求反汇编到的那三段）：`introHoldFlips = 18`（30×10 ms＝300 ms）让音乐盒**先全亮 standalone**，再 `LvnsDarken`（`LvnsEffect.c:966-976`）每翻转把 `latitude` 降 1，从 `latitudeNormal 16` 到 `latitudeDark 11`（`Lvns.c:71-72`、`LvnsMenu.c:57`）＝5 翻转，随后表单浮现。
- 入口格保持原版**完全隐形**的 24×24（`titleEntryX = 448`＝`X56×8`、`titleEntryY = 128`）；只有悬停显形白框与 `ゲーム` 菜单入口是我们的可达性偏离（§30.3 已记）。三按钮 `buttonX = [176, 296, 392]`、`buttonsY = 300`、高 24、宽＝label 格数×24；`trackCount = 24`。
- 用户定口径：入口「完全隐形（与原版一致）」、按钮「保留 hover」。

### 31.5 项7：转场「不管开不开都没有」的根因与量化

- 13 效全表在 `ShizukuCore/LvnsEffect.swift:13-27`（源 `sizuku.c:92-126` 的 `sizuku_effect[]` / `text_effect()` 映射），每效帧数见 `LvnsEffectTiming.frames`（`:45-62`）：`fadePalette 17`、`slantTile 13`、`fadeSquare 31`、`wipeSquareLtoR 32+31`、`fadeMask/fadeMask2 32`、`wipeTtoB 41`、`wipeLtoR 56`、`wipeMaskLtoR 56`、`vertComposition 25`、`slideLtoR 32`、`normal 1`、`guruguru (cols*rows+9)/10`。
- 一次 CG 切换＝`LvnsClear` 56 ＋ `LvnsDisp` 56 ＋ `ShizukuEngine.dispHoldFlips` 30 ＝ **142 翻转**（`LvnsEffect.c:906-908`、`LvnsDisp.c:200-213`、`INTERVAL 60`）；`表示` 菜单「画面エフェクトを省く」（参考引擎自带的 `-n e`，`mgMain.c:76-79`）→ `engine.effectsEnabled` 把两段都塌成 `.normal`＝1+1+30＝**32**。
- 之所以"开了也看不见"：mask 几何原先按窗口像素算，只扫了半屏（§29.2）。现在在逻辑 640×400 网格上算再整数倍放大（`TransitionRenderer` 的 `logicalWidth/Height`，`:186-187`），`TransitionTests` ④⑤ 两条断言把「640×400 与 1280×800 都必须扫满全屏」锁死。

### 31.6 ★项9：通关 staff roll（`0x7d END_BGM` → 阻塞式 `SizukuEnding`）—— 本轮主体

- **触发点**：事件流 `0x7d END_BGM bgm_no` → `sizuku.c:810-826`：`LvnsStartMusic(bgmmap(no))` → `SizukuEnding(lvns)` ＝ **阻塞式** `LvnsScriptRun(lvns, eddata)`（表在 `sizuku_ed.c`）；返回后才 `memcpy(flag_save, flag)`／`SizukuScenarioInit`／`SizukuSave`／`c += 2`，继续 `IF_NE`→`JUMP 195` 收尾链。发货脚本核对（`/tmp/scan_endbgm2.py` 走 `lzs_decode`＋`EVENT_OPS`）：**每个结局块都以 `MSG… → END_CHK n → ENDING → END_BGM bgm → IF_NE[0,1,3] JUMP[195,1] IF_NE[0,2,3] JUMP[195,2] IF_NE[0,3,3] JUMP[195,3]` 结尾**（SCN093/094/095/097/099/100/136/137/172/173/194，`END_BGM` 实见参数 16/17/18/1）。
- **引擎侧**：新增 `StepResult.waitingStaffRoll` ＋ `Phase.staffRoll`；`step()` 在非 running 相位时把 `.staffRoll` 映射回 `.waitingStaffRoll`，所以**翻多少步都越不过去**；只有 `finishStaffRoll()` 把 `phase` 放回 `.running`（`pc` 早已越过 0x7d，等价原版的 `c += 2`）。
- **为什么快进跳不掉它**（玩家要求，且是原版行为、不是巧合）：`ScriptStep`（`LvnsScript.c:46-65`）直接调 `LvnsClearLow`/`LvnsDispLow`，**绕开** `LvnsClear`/`LvnsDisp` 里 `if (lvns->skip)` 的快路径（`LvnsDisp.c:188-233`），而 `LvnsWait`（`Lvns.c:455-460`）是纯翻转循环、不轮询输入 ⇒ `skip` 打开时 6000 ms 停顿与 16 步调色板淡变照样全长跑完，只有 `LvnsWaitClick`（`LvnsControl.c:311-326`，select **或** cancel 都算）能收尾。App 侧因此 `openStaffRoll()` 第一件事就是 `stopFastForward()`，且 `mode == .staffRoll` 下鼠标左/右键、Enter、Space、ESC 全部只喂给 `Player.click()`，不再走 `advance()`。
- **逐卡节拍**（`eddata[]` 直读）：`BG(n)` 先备好下一张底板 → `WAIT 6000`＝360 翻转（当前卡连署名一起挂着）→ `CLEAR(FADE_PALETTE)`＝`latitude` 16→0（16 翻转；**署名与图一起暗**，因为 `tputs` 写进的是 vram）→ `DISP(FADE_PALETTE)`＝新底板 0→16 → `WAIT 1000`＝60 翻转（底板独亮）→ `tputs` 行＋`DispMoji`（署名一次落定）。末卡 `WAIT 0`→`WAIT_CLICK`→`CLICK_JUMP`→`CLEAR(FADE_PALETTE)`→`END`。合计 `16 + 13×436 + 76` ＝ **5760 翻转 ≈ 96 秒**（`SHIZUKU_SHOT=roll` 打印 `cardFlips=436`）。
- **字形几何与配色**：`tputs`（`sizuku_ed.c:26-36`）`x = (640 - 字节数×12)/2`，全部署名是 EUC-JP 全角（2 字节/格）⇒ 宽＝`格数×24`；`y = row × EDYOFF(30)`；`EDSHA`＝0 在 +1/+1、+2/+2 打两遍黑影，`EDCOL`＝4 打在正点。`sizuku_haikei_palette` 每行第 0 项是黑、而第 4 项是所有 `MAX_S` 底板自带的常量白（`palmap` 只换 0…3）⇒ **每张卡都是白字压黑双影**，与 31.1 的换色规则自洽。
- 14 张表按 `eddata[]` 原序抄死：地点号 `[2,44,11,12,13,15,20,22,24,26,27,31,35,5]`、行号 4/5/6/7/8/9/10、串保留全角原样（プログラム／ＨＡＪＩＭＥ　ＮＩＮＯＭＡＥ … 企画・開発／１９９６　ＬＥＡＦ）。
- **目检抓到的两个真 bug**（都是"看帧才看得见"）：① `Player.step()` 的 `.darkening(card)` 落成 `.lightening(card ?? 0)`——**同一张卡**，卡号永远停在 0，13 张卡的 PNG 除首帧外全是同一间教室（`md5` 撞车才暴露）；改为 `.lightening(card: (card ?? -1) + 1)`，并给探针的 `settle()` 加"走不到目标相位就打印 `settle FAILED`"，否则状态机空转只会拍出重复帧。② `click()` 里 `latitude = fadeStep == 1 ? 0 : latitudeMax` 把带特效时的收尾淡出**直接抹成 0**，等于点一下就瞬黑；原版收尾是一条 `CLEAR(FADE_PALETTE)`，故改成恒 `latitudeMax`（`fadeStep`＝16 时自然塌成一刀切）。**教训：时间驱动的状态机必须逐相位导帧，一张"看起来对"的卡证明不了 14 张卡都走得到。**
- 新增 `StaffRollTests` 7 例（51→**58**）：①14 卡全部署名 `codec.uncovered == []`（字库缺字是**静默跳过**、不报错）；②14 个地点号都要在 `BackgroundMap` 里解得出底板且 `GameData.image != nil`（错一个号就是整卡纯黑，同样不报错）；③最长署名 `格数×24 ≤ 640`；④状态机**恰好**按序经过 `creditHold 0…12` 并停在 `awaitingClick(13)`，再空转 100000 翻转仍不结束（把"快进跳不掉"钉成断言）；⑤中途点击无效、末卡点击后还要走完 `fadeSteps` 才 `finished`；⑥`effectsEnabled == false` 时一次翻转就跨过整段淡变；⑦真结局块 SCN094 blk1 跑到 `END_BGM` 返回 `.waitingStaffRoll`、反复 `step()` 越不过去、`finishStaffRoll()` 后回 `.running`（headless 无 ticker，要手动 `tickReveal(deltaTime: 1)` 抽干 `LvnsClear/Disp`，否则 `step()` 永远停在 `.rendered`）。

### 31.7 回归、验证与遗留

- `swift build` 零警告；`swift test` **58/58**；`SHIZUKU_SHOT` 全 27 个 token 重跑一遍无崩溃（`/tmp/shizuku_shots` 共 138 帧）。
- 本轮**逐张看过**的帧：`roll_00_dark_open`（结局画面 8/16 暗、正文与 ▼ 都在，证明确实是从游戏画面淡出）、`roll_00_black`（纯黑）、`roll_00_plate_fade`（底板半亮无字）、`roll_01_plate_in`（全亮无字＝`WAIT 1000` 段）、`roll_card00`…`roll_card12` 全 13 张（教室／夜廊／校舍外／中廊下／部室／校舎外／正門／階段／体育館／トレーニング室／ロッカー室／屋上ネット／夕暮ネット）、`roll_02_dark_card`（署名跟底板一起淡出）、`roll_card_last`（企画・開発／1996 LEAF）、`roll_90_close`（末卡半亮）、`roll_91_done`（纯黑，与 `roll_00_black` 同为 5702 字节）。
- **待用户实机判定，不给猜测改动**：项1（logo/OP/▼ 节奏——常量已按 `INTERVAL 60` 与 6 帧光标周期核过，用户仍反馈"太慢"，需要他在 Ver.0.6 上指认具体哪一段）；项3（CG→背景：`beginMessage` 的兜底 `flushStagedImage()`（`Engine.swift:659`）会把一条尚未被 `Disp` 认领的 `0x0a` 提前一拍显出——方向与用户报的"CG 赖在背景位上"**相反**，且删掉兜底有让画面停在未显影状态的风险，需先复现再动）。
- 验不到的仍是时间/音频类：staff roll 的 96 秒实际观感、`END_BGM` 的结局曲、音楽モード 24 槽播放，都要 Ver.0.6 实听实看。
- 打包：`build/Shizuku_Restored_Ver.0.6.app` / `.dmg`。

---

## 32 项1 深挖：▼ 闪烁与文字滚动「太慢」的两个真因（2026-09-22；基线 58→**59/59**，构建 **Ver.0.7**）

> 用户先报「三角闪烁太快」，修完又报「现在太慢了、文字滚动也过于慢」。本轮不再猜，先用三条硬数据把「常量错 / 交付慢 / 相位错」三种可能区分开，再动手。

1. **原版语义取证**（`LvnsControl.c` + `LvnsDisp.c`）：`LvnsWaitPage`/`LvnsWaitKey` 都是 `int flip_cnt = 0;` 起步，循环里 `if (flip_cnt == 0) LvnsDrawCursor(lvns, LVNS_CURSOR_PAGE|KEY); flip_cnt = ++flip_cnt % 6;`。关键在 `LvnsDisp.c:44-90`：`LvnsDrawCursor` 是**切换**（`cursor_state` 0→1 才画，1→0 走 `LvnsClearCursor`），不是每 6 帧重画一遍。所以原版＝**进入等待那一帧先亮，亮 6 帧、灭 6 帧，整周期 200 ms，相位以"进入等待"为原点**；退出循环时 `LvnsClearCursor` 收尾。
2. **排除法（release 构建实测，不是推理）**：
   - `SHIZUKU_SHOT=perf` → 单帧 CPU 合成 **4.52 ms**（1280×800 全屏 RGBA），余量 221 fps，`GameData.image` 本来就按文件名＋调色板缓存，不存在每帧解 LFG。合成不是瓶颈。
   - `SHIZUKU_SHOT=perfrun` 改成「总翻转 ÷ 总墙钟秒」直读 → **flips=362 / 6.05 s = 59.9/s，fires=362，zeroFlipFires=0，maxFlipsPerFire=1**；人为加并发负载时 `maxFlipsPerFire=3` 仍读 59.9/s。即 ticker 既没丢拍也没超发，墙钟锚定确实吸收了主线程停顿。
   - 顺带纠正一个**探针自身的假信号**：`reportPerf` 的 2 秒窗口把 `perfAnchor` 放在"第一次 fire"才置位，首窗混入了置位前的时间，曾报出 `77.5/s` 这种"超过 60"的荒谬值。`consumeElapsedFlips` 的数学里 `anchor + flips*interval ≤ now` 是硬不变量，速率不可能 >60 —— 凡是窗口化指标违背不变量，就该换成总量口径，而不是去改被测对象。
   - 文字速度复核：`Lvns.c:45` 默认 `char_wait_time = 1`、`LvnsText.c:81` 每字 `LvnsWait(lvns, char_wait_time)`、`LvnsText.c:163` `LvnsNewLineText` 每次换行重置为 1 → 我们的 `defaultTextSpeed = 1/60`、`speed(forHint:) = max(1,hint)/60`、`crossedLineBoundary` 后重置，三处逐条对齐，无需改动。
3. **定位到的两个真问题**：
   - **相位原点错**（`SceneComposer.drawContinueIndicator`）：用全局 `flipCount / 6 % 2` 决定亮灭，翻到新页时可能正好落在「灭」的半周期里，最多 6 帧没有光标 —— 观感就是"光标慢半拍、闪得不勤"。改为 `Engine.waitCursorEntryFlip` + `waitCursorVisible`，由 `trackWaitCursorPhase()` 在「(msg.index, seg) 变化」那一帧重置原点，等价于原版重新进入 wait 循环。key 用 `UInt64`（msg.index 左移 32 位拼 seg）而不是元组，因为 `Optional<(Int,Int)>` 在 Swift 里没有 `!=`。
   - **App Nap 把整进程节流到 ~1 Hz**：`Timer` 被节流后每秒只 fire 一次，而 `consumeElapsedFlips` 每次最多补 5 帧 → 呈现速度变成 **5 帧/秒＝1/12 速**：200 ms 的光标周期被拉成 1.2 s、一页 150 字要 30 s 才出完。这与"小三角太慢＋文字滚动过于慢"**完全同形**，而且是**间歇性**的（取决于焦点、遮挡、电源状态），所以离线测量全都复现不出来 —— 这也是为什么必须先做第 2 条的排除，否则一定会去改本来正确的常量。修法：`startTicker` 持有 `ProcessInfo.beginActivity(options: [.userInitiated, .latencyCritical], reason: "60 Hz reference flip loop (Lvns INTERVAL)")`，`stopTicker` 释放；只在 ticker 活着时声明，不阻止回桌面后休眠。
4. **验证**：
   - `swift test` 58 → **59/59**：新增 `EngineLogicTests.testWaitCursorBlinksSixOnSixOffFromTheFlipTheWaitBegan`，沿真实读者路径停在第一页后逐帧采样 24 次，断言「亮 6／灭 6／亮 6／灭 6」且停在同一段时 `waitCursorEntryFlip` 不漂移。踩坑记录：`skip = false` 时引擎会停在 `.rendered`（`'Mw'` 停拍与 `LvnsClear/LvnsDisp` 都只由 `tickReveal` 推进），headless 必须先 `bgmHoldSeconds = 0` 并把泵条件写成 `isRevealing || transition != nil`，否则 200 次步进全打在 `.running` 上（第一版就是这么把测试跑成 6,285,472 次自旋的）。
   - **逐张看过新导的帧**：`wait_page.png`／`wait_page_flip05.png`／`wait_page_flip12.png` 三张 **md5 完全相同**（`7b6e4ed2…`）＝亮半周期逐帧稳定，`wait_page_flip06.png`（`d2f356c9…`）＝翻页图标确实消失；`wait_key_flip05/06/12` 同理。图上 flip05 在「り と刺激した。」后面有翻页方框图标，flip06 同一格干净、无半亮残影。探针同步打印 `flip=5 visible=true / flip=6 visible=false / flip=12 visible=true`，与 `entry=1 flipCount=13` 的算术自洽。
   - `pmset -g assertions` 实读系统断言表：`pid …(ShizukuApp): PreventUserIdleSystemSleep named: "60 Hz reference flip loop (Lvns INTERVAL)"` —— 证明断言真的注册进了 IOKit，而不是只写在源码里。
   - 全量 `SHIZUKU_SHOT` 16 token 重跑无崩溃、141 帧；`TRANS on flips=142`／`off flips=32`、`GALLERY items=61 pages=6`、`MUSIC entry=x=448 y=128 w=24 h=24`、`ROLL cards=14 cardFlips=436`、`PERF compose 4.52 ms` 与 §31 锁死的数字逐条一致 → 本轮没有碰坏其它时序。
5. **遗留**：项1 的**观感**仍要用户在 Ver.0.7 上点头。若他机器上仍觉得节拍不对，直接让他量一次真机翻转率：`SHIZUKU_PERF=1 SHIZUKU_SHOT=perfrun "/Applications/Shizuku_Restored_Ver.0.7.app/Contents/MacOS/ShizukuApp" ...`（读 `PERF total:` 那行；<60 就是他的环境仍在丢拍，需要调的是 `consumeElapsedFlips` 的补拍上限而不是任何演出常量）。项3（CG→背景）依旧待复现，`Engine.swift` 的兜底 `flushStagedImage()` 未动。

## 33 项3／项4 排查轮：把「引擎卡死」证伪，并把量具装进产物（2026-09-22；基线 **60/60**，净新增＝翻转心跳看门狗）

> 上一轮把项3（CG 没切回背景）／项4（快进或点击突然要重按）都挂在「`engine.step()` 卡在 SCN004 blk01 pc=18 opcode `0x54`」上。本轮做两件事：①给项3 加一条**引擎级硬不变量测试**；②用 `sample` 逐帧取证那条「卡死」到底是产品缺陷还是探针假象。结论：**引擎侧无罪，那条卡死是我自己的量具坏了**。

1. **新增的回归锁**（`EngineLogicTests.testEveryClearDispPairHandsTheScreenBack`，58→59→**60/60**，0.138 s）：沿真实读者路径走 scn 1..<60，每遇到一个 `LvnsClear/LvnsDisp` 对就要求它**在 1200 帧内把屏幕交还**且**总时长 < 400 帧**，并断言这一轮确实驱动了 >100 个对、其中 >0 个以 CG 为 `from` 侧。这是 §28「转场」与 §32「App Nap」两条修法的引擎侧保险：任何一对不收敛＝翻转源停了，正是 §32 消灭的那类故障。CG 通常来自**上一个 scenario**，所以整轮共用一个 engine 实例，不能每个 scn 重建。

2. **证伪「`step()` 卡死」**：把 `SHIZUKU_SHOT=cgtobg` 里那条 while 循环 1:1 搬进无 AppKit 的 CLI（临时 `SHIZUKU_WALK_PROBE=1`，本轮结束已删除）跑同一个语料 —— `walk scn1 -> 802 iters phase=ended`，**最慢一次 `step()` 0.000 s**，包含 `op=0x54` 那一条。解释器根本不需要时间；所谓的 120 s 卡死发生在 App 侧探针里。

3. **三个探针自身的假信号（方法论，比结论更值钱）**：
   - **debug 构建不能用来判断"卡住"**：`sample` 显示主线程 2168/2170 个采样全在 `MTKView draw` → `currentFrame()` → `SceneComposer.render` → `RGBAImage.blitScaled`（`swift_getGenericMetadata` 打头），debug 软件合成把主线程吃满。release 同一负载是 `compose 4.44 ms/帧`、`flip rate 60.0/s`。凡是"看起来像死锁"的现场，先换 release 再下结论。
   - **看门狗误报**：我用 `kill -0 $(cat /tmp/cg_pid)` 轮询判断进程存活；shell 回收子进程后这条判断会**一直返回真**，于是把一次正常 69 s 完成的运行读成"120 s 还没退出"。判完成要用 `wait $p` 和退出码。顺带：`strings` 也**不能**用来判断某个字面量有没有编进产物（`SHOT SPEC DONE` 明明打印了，`strings` 里 0 命中）。
   - **`cgtobg` 不是可复现的量具**：它先 `enterGame()` → `engine.reset(keepPersistentFlags: true)`，起点 flags 取自**用户真实存档**，同一条 token 两次跑走出不同轨迹（一次 69 s 出 4 帧、一次 400 s 不出帧）。要度量就走 CLI 那条从零开始的 walk，别用 App 侧带存档态的 harness。
4. **`lvns->skip` 语义取证（排除项7 是 skip 泄漏所致）**：`LvnsDisp.c:190-225` = `copy(background→vram)` → `mergeCharacter` → `if (lvns->skip) LvnsDispWindow() else { LvnsDispLow(effect); LvnsWait(500*INTERVAL/1000) }`；`LvnsClear` 同构；而 `LvnsEffect.c` 全文 1059 行**0 处**引用 skip ⇒ 特效本身从不看 skip，只有 CLEAR/DISP 两层的调度塌成一次 blit。我们的 `beginTransition` 里 `guard !skip` 与 `effectsEnabled` 时把 clear/disp 各替换成 `.normal`，逐条对齐；`skip` 仅在 `startFastForward`/`stopFastForward` 之间为真，且原版 `:213-214` 在「選択肢まで進む」结束时显式 `force_skip = skip = False` —— 我们没有把 skip 泄漏进普通阅读路径，所以**项7「转场没有」不是这条**。
5. **本轮的运行时代码改动只有两处、且都不碰渲染**：`Engine` 加只读 `stagedImageName`（双缓冲里压着的图，项3 的正主必须在外部可见），`MetalGameView` 加下面第 6 条的看门狗。§32 的 Ver.0.7 视觉结论继续有效。剩余唯一离线测不到的嫌疑：他机器上主线程被外部停摆（窗口遮挡/节能/全屏切换），以及冷 plate 解码撞上合成尖峰 —— 两条都只在**他那次真实卡住**里才有证据，所以改成让产物自己去取证。
6. **落地的净新增：翻转心跳看门狗（`MetalGameView` 的 `startWatchdog`/`watchdogFire`/`noteAdvance`/`dumpAdvanceRing`）**。既然卡住只发生在**他机器上**，就把量具装进产物里：
   - 与 ticker 同跑在主线程 `.common` 模式、但**独立于 ticker 生命周期**的 1 s 定时器。理由：症状是"重按一次才继续"＝主线程活着而翻转源死了；真要是主线程被卡死，任务栏会显示"未响应"，任何主线程探针也跑不起来 —— 那是另一类问题，别混在这里。
   - 判据只在**引擎还持有活计时**成立（`transition != nil || isRevealing || isFastForward`），等读者的页不算卡。超过 2 s 无翻转记一条，持续卡住每 5 s 最多一条。
   - 记录内容就是项3/项4 需要的全部坐标：`scn/blk/pc/phase`、**当前显示的图 `shown`**、**双缓冲里压着的 `staged`**（为此在 `Engine` 上加了只读 `stagedImageName`）、`transition` 的 phase/state/clear/disp/`from`、`reveal/skip/ff/pump/ticker/wait`，外加最近 24 条 `advance()` 交接（含被 `guard engine.transition == nil` 吞掉的那次，标 `advance swallowed`）。写到 `~/Library/Logs/Shizuku_Restored/diagnostic.log` ＋ stderr。
   - **并且自愈**：判定为卡住后 `stopTicker(); startTicker()` 强制重启翻转源。依据是原版语义「flip loop never stops」（`mode didSet` 的注释就是这条），所以重启一个停掉的翻转循环是**修正**而不是掩盖；日志仍留一条，坏因不会被抹掉。
7. **看门狗自身的验收（`SHIZUKU_SHOT=watchdog`，不是"写了就算有"）**：探针走到一个真实 `LvnsClear/LvnsDisp` 对、`skip = false`，然后手动 `stopTicker()` 复刻故障，再让 run loop 空转 4 s ＋ 2.5 s。实测：
   - 2.3 s 时记到 `transition=clearing state=0 clear=normal disp=normal from=MAX_S01 shown=MAX_S07 staged=nil reveal=true ticker=false` —— 正是"画面停在一个没收尾的 CLEAR 上"的现场形态。
   - 自愈后 `stalledState=transition=hold state=18`、`recovered=true`、`shownAfter=MAX_S07`，日志里 `flip source silent` 恰好 **1 条**（不刷屏）。
   - **看过恢复帧** `watchdog_recovered.png`：笔记本＋铅笔底板完整、无半清屏/黑屏，文字停在「…青い罫線が刻まれた真新し」仍在逐字出，等待光标尚未出现（与 `reveal=true` 自洽）。
   - `swift test` **60/60** 不变；本轮没动 `SceneComposer`/渲染路径，只加了 App 侧定时器与一个只读属性。
8. **遗留（下一步该做的）**：
   - 请他在装了看门狗的构建上正常玩。**下次再卡住时不用描述，直接让他把 `~/Library/Logs/Shizuku_Restored/diagnostic.log` 发过来**；三条日志字段就能分诊：`ticker=false` ＝源被停（继续找是谁停的）、`ticker=true` 且 `pump=true` ＝源活着但没人泵（`consumeEventPumpRequest` 路径）、`staged != nil` 且 `shown` 是 CG ＝项3 的双缓冲没被 `LvnsDisp` 冲刷（`flushStagedImage` 调用缺点）。
   - 顺带记一个**未被触发的死循环**：`Scn.swift:563-578` `parseBlock` 对截断的 `0x05 SELECT` 会 `continue` 而不推进 `i`。真数据里没有这种块（§31 的全语料审计没报），但它一旦遇到损坏数据就是硬死机；要修只需把 `continue` 前补 `i += 1`。（已落地：`491cb22`，四种病态块 0.002 s 全过。）

## 34 M4.11b：`0x01` 过场子类型四式落地 ＋ ★真凶：单声道 WAV 的 NSException 把解释器静默击杀★（2026-09-23；基线 62→**71/71**）

> 本轮主线是 `0x01` SUB（`sizuku.c:580-612`）四种过场：kind1 正弦背景扭曲＋消息后 `LvnsClear(FADE_PALETTE)` 淡到黑、kind2 `LvnsDisp(FADE_PALETTE)` 淡入（解释器照常让位）＋正弦消息、kind3 阻塞式 `LvnsAnimation(sizuku01/02)` logo 插入、kind4 素消息。演出常量本身一天就写完；**卡住整轮的是 SCN051 的"引擎死循环"**——最后查出一个货真价实的产品级崩溃，任何带 SFX 的消息在 GUI 里都会把整个解释器栈掀掉。

1. **频次先行（不是猜优先级）**：给 CLI 加 `SHIZUKU_DUMP_SUBTYPES`（`main.swift` 的 `dumpSubtypeFrequency`）走全语料统计 `0x01`：kind1×10、kind2×2、kind3×6、kind4×5，共 23 处；kind3 六个落点全部确认参数只有 `00/01`（`SCN051 blk01 pc15/pc20`、`SCN082/083/085/087`），对应 `sizuku01`/`sizuku02` 两表。未知 kind 原版打印错误后 `return` 出主循环 ⇒ 我们 `phase = .ended`（`Engine.swift:588-591`）。
2. **正弦背景扭曲**（`sin_effect.c:17-20` 表、`:114-157` 驱动；`Lvns.c:308-320`）：`sintable[361]` 逐字抄进 `ShizukuCore/SinBackEffect.swift:23-52`（1° 采样、振幅 ±160 px、两端各带一个 0 ⇒ 表求和为 −1，**不许"修"**，测试①锁死）；每个翻转 `state += 8 mod 361`（`LvnsSetBackEffect` 上弦时清零 ⇒ 扭曲首帧 row 0 偏移为 0），第 `row` 行位移 `table[(state+row)%361]`。**关键相位：剪切发生在背景底板 blit 之后、`mergeCharacter` 之前**（`SceneComposer.swift:69/:120` `shearRowsForBackEffect`）⇒ 文字与立绘永不失真，只有背景在歪——这正是原版「ぐにゃりと世界が歪ん」的语义。踩坑：取样方向必须是 `vram[x] = bg[x+shift]`，写反会让黑带从右缘跑到左缘。
3. **logo 插入**（`LvnsAnim.c:43-111`，表 `sizuku.c:25-89`）：`ShizukuRender/LogoAnimation.swift` 把两张表按原序抄死——sizuku01＝38 条目/62 翻转（17 帧书法 OP_S00…16、第三帧后插 SOUND、整段再来一遍、尾部 `WAIT 200`＝12 翻转），sizuku02＝19 条目/19 翻转、末帧 `MAX_S37@(0,0)`。三条环路语义各钉一条断言：① **只有 IMAGE 条目动 vram**（`lvnsimage_clear`＋blit），WAIT/SOUND 继续显示上一块板 ⇒ 尾拍是 12 帧书法定格而不是切黑（第一版就切了黑，测试⑦锁死）；② `time*INTERVAL/1000` 整数除＝0 ⇒ 每帧恰 1 翻转，插入是纯 60 fps，明显快于 boot OP（其表 `time=50`＝3 翻转/帧）；③ SOUND 条目重触发的是"已装载的声音槽"，而原版全路径只有语音分支会 `LvnsLoadSound`（`sizuku.c:434`），这批脚本从不装载 ⇒ **原版在这里就是哑的**，我们也哑，只留 `wantsSound` 可观测钩子；快进只清零 WAIT 的剩余翻转（`LvnsAnim.c:108-109`）。引擎侧新增 `Phase.logoAnimation`/`StepResult.waitingLogoAnimation`/`finishLogoAnimation()`（`Engine.swift:579-582`），与 staff roll 同款"翻多少步都越不过去"。
4. **★SCN051"卡死"排查：三层判别把假象和真凶分开★**
   - 症状：`SHIZUKU_SHOT=sub` 停在 SCN051 pc=1 的 `engine.step()`，`sample` 显示主线程 100% 在 `MTKView draw → SceneComposer.render → blitScaled` —— **和 §33.3 记的 debug 绘制风暴一模一样**，本轮差点再次误判成量具假象。
   - 判别一（返回值而非耗时）：给 spec 循环加逐迭代 stderr print ⇒ 不是"慢"，是那次 `step()` **永远没返回**——栈被展开回了 run loop，`runShotSpec` 整体蒸发（末尾 `shots written` 从不打印）。
   - 判别二（现场残留）：`lsof -p <pid>` 显示进程唯一开着的 fd 是 `P017.WAV` —— 死亡现场停在音频加载上，而 P017 正是 SCN051 msg1 挂的音效。
   - 判别三（换环境逼它现形）：同一语料跑无 AppKit 的 CLI 加 `-audio` ⇒ **立刻崩溃并给出全栈**：`scheduleBuffer ← playSFX ← applyCurrentSegment ← skipInertSegments ← beginMessage ← step`。
   - 根因：1996 的 `P0xx.WAV` 是**单声道 11025 Hz**（`afinfo` 实测），而 `AVAudioPlayerNode.scheduleBuffer` 要求 buffer 格式与 node 输出格式（立体声 float）逐字段一致，否则 raise NSException `com.apple.coreaudio.avfaudio — required condition is false: _outputFormat.channelCount == buffer.format.channelCount`。CLI 里它 abort（看得见）；**AppKit GUI 里事件循环的顶层 @catch 把它静默吞掉**，Swift 帧全部展开、stderr 零输出（NSLog 进 os_log）⇒ 表现就是"引擎卡死"。这不是探针问题：**任何带 SFX 的消息在正常游玩里都会把解释器杀掉**，BGM 路径同病（`playBGM` 同样的裸 `scheduleBuffer`）。
   - 修复：`AudioController.convertedBuffer(from:to:)`——格式已匹配就直读透传，否则 `AVAudioConverter` 一次性换格式再 schedule；`playBGM`/`playSFX` 两条路径共用。回归锁：测试⑨ 用真实的 `P017.WAV` 断言 mono 11025→stereo 48k 转换成功、时长有限。
5. **方法论（本轮最值钱的一条）**：§33.3 的教训"绘制风暴 ≠ 卡死"**反过来也成立**——同一种风暴签名这次是真缺陷。三分法：**探针假象**在拆掉探针后 spec 能跑完并打印完成行；**被吞的 NSException** 完不成且 `lsof` 会留下最后一个业务动作的开放 fd；**真死循环**则逐迭代 print 能看到它还在推进。逼 NSException 现形的通用手段是把它搬回"顶层会 abort"的环境（CLI＋功能开关做有/无差分），而不是给 GUI 加更多日志。
6. **验证**：`swift test` 62 → **71/71**（新增 `SubType01Tests` 9 例：①sintable 逐字；②kind1 正弦→淡到黑；③kind2 淡入期间正常让位；④kind3 阻塞脚本；⑤两表翻转计数 62/19；⑥skip 只塌 WAIT；⑦WAIT/SOUND 续显上板；⑧sizuku02 收在 MAX_S37；⑨单声道 WAV 转换回归）。`sub` spec 端到端跑通并打印 `SUB sizuku01 flips=62 plate=OP_S06`、`SUB walkTo returned phase=logoAnimation pc=3`（与表自洽）；**6 帧逐张看过**：`sub_sine_mid`（走廊背景正弦扭曲、文字「ぐにゃりと世界が歪ん」笔直＝剪切先于 merge 的直接影像证据）、`sub_fade_to_black`（纯黑）、`sub_fade_in`（黑帧——正确：淡入发生在刚被抹黑的场景上，"淡入在跑"以 yield 点 `dispEffect == .fadePalette` 程序化断言）、`sub_sine_after_in`（背景归位＋再来一次正弦＋「また、世界が歪んだような気がした。▶」）、`sub_logo_s07`（黑底蓝色水纹小书法板）、`sub_logo_max`（MAX_S37 大纹章）。诊断期加的逐迭代 trace 已全部移除，只保留 `sub` 一条 token 的常驻打印。
7. **遗留**：kind1/2/3 的**观感**（60 fps 书法流动、扭曲幅度 ±160 是否刺眼）与"每次带音效的消息是否还杀进程"的最终确认，都要用户实机点头；SOUND 条目"原版哑⇒我们也哑"是保真决定，若用户想让它出声属于**超修正**，等他拍板；M4.11b 剩余＝§24.3 的其它固定效果号（`0x66` 与事件同表）仍随全量脚本回归补齐。

## 35 staff roll 可点击跳过 ＋ OP/jingle 节奏 ＋ ★开场螺旋转场几何★ ＋ 沙織正字 ＋ 转场开关语义（2026-09-23；基线 71→**74/74**）

> 本轮五件事，三件是用户实机反馈的行为不符，两件是他顺手指出的字面/开关错误。核心教训：**"完全跳不过"和"螺旋只画 2/3"都是我上一轮的误判**——前者漏读 `LvnsScript.c` 的 CLICK_JUMP 回绕，后者把 `GURUGURUDisp` 的 `#ifdef USE_MGL` 分支当成原版。两条都以 mglvns 行号取证后翻案。

1. **staff roll 可点击跳过（`LvnsScript.c:29-40` 回绕，纠正 §31.6 的"快进也跳不过"）**：`ScriptStep` 每次进入都先跑 `if (lvns->select) { 向前扫到下一个 `LVNS_SCRIPT_CLICK_JUMP`，`scr->cur = n` }` —— 这正是 staff roll / OP / jingle 的跳过机制。之前只看到 `LvnsWait`（`Lvns.c:455-460`）不轮询输入、`LvnsClearLow/DispLow` 绕过 `skip` 快路，就断言"翻多少步都越不过"，漏了 select 分支。落地（`StaffRoll.swift`）：`click()` 在非末拍时置 `selectPending`，`finishStage()` 在当前拍的边界（而非半 Hold 中）把状态改派到 `closingDark`（片尾 `CLEAR(FADE_PALETTE)`）；`cancel()` 只在 `awaitingClick` 生效（对齐 `LvnsWaitClick` 收 select‖cancel，但回绕只认 select）。**注意语义**：`LvnsWait` 不轮询 ⇒ 点击在**下一个拍边界**生效，不是当前 Hold 中途切走，这是原版行为不是 bug。测试：把旧的"只有末拍点击能退出"一拆三（①中途 select 回绕到片尾；②中途 cancel 被忽略；③末拍 select‖cancel 都退出），另保留"无点击则翻 100000 步仍停在 awaitingClick"。
2. **开场 LEAF jingle ＋ OP「过快」两处真实少算**：① `LvnsAnim.c:101-111` 每帧显示 `wait_time + 1` 个翻转，OP 表 `time=50` ⇒ `50*60/1000 + 1 = 4` 翻转/帧（不是 3）。新增 `MetalGameView.opAnimFlipsPerFrame = 4`，sizuku×3 与 ruriko 的时长和取帧下标（`t / 4`）统一走它。② `jingleHold` 原来每翻转重算 `max(0, 360 - bootElapsed)`，在 ~3.6 s 就跨界；改为**进入该拍时一次性捕获** `jingleHoldBudget = max(0, 360 - bootElapsed)`，凑满 `TIMER_WAIT 6000` 的 6 s。
3. **★开场螺旋转场几何（本轮最硬的一条，`LvnsEffect.c:319-395`）★**：症状是"左半屏约 2/3 走螺旋、右半约 1/3 从上往下填"。根因在 `TransitionRenderer.guruguruOrder`：上一轮按 `#ifdef USE_MGL` 分支（`BSIZE 8`、起点 `y = HEIGHT/16 = 25`）在 8px 网格上跑螺旋，而该分支的终止条件 `y < 0` 会在 `x` 只推到第 ~26 块（共 40 块）时触发 ⇒ 右 1/3 从没被螺旋走到，落到 `order.count < cols*rows` 的**行优先兜底**（`0..N` 递增追加＝从上往下）。**原版是 `#ifndef USE_MGL` 分支**（`BSIZE 16`、`FACTOR 32`、起点 `x=27, y=HEIGHT/32=12`），直接在 16px 瓦片网格上跑：每半圈 `lenx`/`leny` 各加一，`y<0` 收束时恰好 `x→40 / y→25` 扫满 40×25。重写 `guruguruOrder` 逐字对齐该分支，兜底路径保留但不再触发。取证兼可视化双锁：新增 `TransitionTests.testGuruguruSpiralReachesTheRightEdgeItself`（断言 order 是全瓦片置换、`max == cols*rows-1`、且**尾段非单调递增**＝排除行优先兜底）；`SHIZUKU_SHOT=spiral`（红底→蓝底跑 `guruguru`）逐张看过 `spiral_048`（中心向外矩形螺旋、右缘已被螺旋臂接近）、`spiral_080`（仅剩外圈＋右下螺旋臂缺口）、`spiral_099_last`（全蓝）——螺旋从中心扫到满屏，右缘由螺旋臂收尾，竖切症状消失。
4. **结局选单「佐織」→「沙織」正字（`sizfont.tbl` 为唯一裁判）**：用户把角色名写成「紗織」，但**先查字库再动手**：解码 `research/extracted/sizfont.tbl`（EUC-JP 对、entry index＝leaf code）——`佐`=leaf 1802 有、`沙`=leaf 556 有、`織`=leaf 722 有、**`紗` 根本不在字库里**。结局标题是用原版点阵字画的（`FontPipelineTests:117`），若照用户字面写「紗織」，`uncovered` 测试直接红（本轮先误改成紗、测试当场抓出）。而 MusicRoom 的名字表是从 exe 指针表 `0x430e28` 逐字提取的，写的是「沙織」。⇒ 原版角色名是**沙織**（我之前的「佐織」是同音别字）。改 `SaveManager.titleJP`＋注释＋`SaveLoadTests` 断言为沙織。MusicRoom 的「沙織」是 exe 提取、不动。
5. **表示菜单转场开关语义反了（`main.swift:212` 标签 vs `MetalGameView:2769` 勾选态）**：菜单项写「画面エフェクトを省く（关闭转场动画，直接切换）」——勾选应＝**省掉**转场。但 `validateMenuItem` 里 `state = effectsEnabled ? .on : .off`，即转场开着时反而打勾，与标签承诺相反，用户遂看到"只有勾上才有转场"。改成 `state = effectsEnabled ? .off : .on`（勾＝省＝转场关）。默认 `effectsEnabled = true`（`Engine.swift:102`、`sys0.effectsEnabled ?? true`）不变 ⇒ 默认不打勾＝转场开，正合用户"默认要有转场"。native 菜单不进 `SHIZUKU_SHOT` 光栅，按逻辑＋默认值核验。
6. **验证**：`swift test` 71 → **74/74**（净＋3：staff roll 一拆三、螺旋转场 1 例；沙織改字使 `FontPipelineTests`/`SaveLoadTests` 转绿）。`SHIZUKU_SHOT=spiral` 出 8 帧全看过。重新打包 **Ver.1.0**（含 §34 后全部未提交改动：staff roll 跳过、OP/jingle 节奏、螺旋几何、沙織、开关语义）并起窗（pid 70773）待用户实机点头：①开场螺旋满屏、②jingle 6 s / OP 4 帧每画、③staff roll 中点一下能否跳、④结局选单「沙織」、⑤表示菜单转场项默认不打勾且有转场。
7. **遗留**：螺旋转场**起始点**（`x=27` 偏右于中心）与块粒度（16px）观感、OP 4 帧/帧是否仍偏快，都待用户肉眼定；若用户认为原版是 `USE_MGL` 的 8px 细块，则需反汇编 `Sizuku.exe` 的 `GURUGURUDisp` 坐实分支归属（本轮以"满屏 vs 2/3"这一可观测差异判定为非 MGL，已足够解释症状）。

## 36 删除从未落盘的 autosave 空壳槽（2026-09-23；基线 **74/74** 不变）

> 用户问「游戏有 autosave 吗？不理解它的存在价值」。答：**原版没有，且我们的实现是个只读不写的死 UI**，遂按"忠实原版＋消除死界面"删除。

1. **原版取证（`sizuku_op.c:116-177`）**：mglvns 的存档/读档菜单 `siori_select_menu_line`／`siori_init_menu_line` **只有 しおり１/２/３ 三个手动书签槽**，既无 autosave 也无 quicksave 概念。quicksave（slot 0）和 autosave（slot -1）都是本移植自加的现代便利项（同理把 しおり 从 3 扩到 6）。
2. **autosave 的实际行为＝空壳**：`fileURL(slot<0)→autosave.json`（SaveManager）、载入选单 `pickerSlots=[-1,0]+1..6` 列出它、`getSaveState(-1)` 读它、`slotRows` 给它贴「オートセーブ」标签——但**全代码无任何 `save(slot:-1)` 写入点**（写入只有 quicksave slot 0、手动 しおり 1..6、测试 slot 3）。⇒ `autosave.json` 永不生成，该行恒显示"空"，选中弹「オートセーブは空です」。价值＝0。
3. **对照：原版真正"回到上次位置"的机制是内存 savepoint**（`lastSelectSavePoint`/`lastPageSavePoint`，slot -99/-98），支撑 ESC「一つ前の選択肢に戻る」，忠实且可用、不落盘。磁盘 autosave 槽是我另加且没接上的概念。
4. **删除落地**：载入选单收为 `[0]+1..6`（quicksave＋しおり1..6，共 7 行）；移除 `slotRows` 的 `case -1`、`chooseSlot` 空标签的 `オートセーブ` 分支、`MenuStrings.autoSaveLabel`（本就无引用）、`SaveManager.fileURL` 的 `slot<0` 分支；同步 4 处注释＋`SaveLoadTests.testSaveSlotListingAndDelete`（去 slot -1，计数 4→3）＋`FontPipelineTests` 空 toast 表（去「オートセーブは空です」）。quicksave 保留（它有真实写入点、可用）。
5. **验证**：`swift test` **74/74**；`SHIZUKU_SHOT=slotload` release 出图逐张看过 `slot_load.png`＝载入选单首行为「クイックセーブ」（带真实时间戳）、其后 しおり 1..6，**已无「オートセーブ」行**，表头「ロードするデータを選択してください」完好。commit `73884d3`。

## 37 载入/存档选单竖向排版 rebalance（2026-09-23；基线 **74/74** 不变，`33ea7c0`）

> 用户实机看各页 UI，点名 load 页「上面空了一大行、下面『クリック決定 ESCで戻る』贴边没缝隙」。先视觉研究再动手：`SHIZUKU_SHOT=slotload,slotsave,esc,title` 出图逐张看——**ESC 菜单是 `drawMenuLine` 走 line 3..8 居中、本就没这毛病**，问题只在 slot picker 一页（load/save/つづきから 共用 `drawSlotPicker`）。

1. **量出失衡（逻辑 640×400 画布）**：表头 `y=(2*32+4)=68` ⇒ 顶部留白 68px；行 `y=100+28i`（7 行到 268）；预览带 `panelY0..1=322..376`；底部提示 `y=376`、字高 24 ⇒ 376..400 **正好贴死下边（0 缝隙）**。即"顶 68 空、底 0 空"。
2. **方案二选一先问用户（§83 二次返工教训：视觉规格有两种合理解法必须先确认）**：AskUserQuestion 给了「整体上移（最稳，内部零重排）」vs「上移＋撑开行距（更填满但改命中框＋行距常量、bug 面大）」。**用户选『整体上移（最稳）』**（与其"以不会导致 bug 为优先"一致）。
3. **落地＝整块统一 −36px**：表头 `68→32`、行 `100→64`、预览带 `322..376→286..340`、预览文字 `328→292`、提示 `376→340`。内部间距（表头→行 8、行距 28、行→带 30、带→提示贴边）**逐条原样保留**，只平移。**命中框同步**：`slotPickerRowRects` 基址 `98→62`，与绘制基址 `64` 保持 `draw=base+2` 的既有 2px 容差 ⇒ 点击不脱靶（`slotRowFromPoint` 唯一消费点 MetalGameView:1315，比较逻辑坐标，未动换算）。
4. **验证**：`swift test` **74/74**；`SHIZUKU_SHOT=slotload,slotsave` release 出图逐张看过——load 页首行「クイックセーブ」紧贴表头、底部提示下留 ~36px 呼吸；save 页 しおり3 的两行预览「細いシャープペンシル…」落在暗化带内、与提示相接但不叠（该相接关系平移前就有、非本轮引入）。commit `33ea7c0`。
5. **遗留**：预览带第二行与底部提示"相接"（都落在 y=340 一线）在选中**有正文**的槽时略挤；若要再松，可把预览带整体下收 1 行或提示再下移 8px，但那会重新引入底部贴边，暂不动。画廊/音楽モード/staff roll 的排版另说。

## 38. 2026-09-24（★汉化分支开启：双版本 + 存档通用总制作方案，M5 解冻，可分工给多个子代理★）

> 本节是 `chinese_localization` 分支的起点文档。四项只读研究（框架审计 / 语料资产盘点 / JP-CN 六维对比 / 双版本+存档选型）已由并行子代理完成，全文归档于 **`research/localization_20260924/`**（`FRAMEWORK_AUDIT_M52.md`、`M51_ASSET_AUDIT.md`、`JP_VS_CN_SIX_DIM_REPORT.md`、`DUAL_VERSION_SAVE_REPORT.md`、`patch_installer_gbk_strings.txt`）——9/7「/tmp 全丢」教训，本轮产物**先入仓库**。本节与三份报告冲突时以本节为准。

### 38.0 决策记录（用户 2026-09-24 拍板）

- **D0 解冻**：§18 的「日文版完美之前完全不碰中文化」冻结由用户明示解除；分支 `chinese_localization` 自 main 切出（main 工作区未提交改动随分支带过来，属日文版在途工作，勿丢）。
- **D1 语言 = 构建属性**：**放弃运行时双语即时切换**。交付两个构建产物：`Shizuku_Restored_JP_Ver.X` 与 `Shizuku_Restored_ZH_Ver.X`。
- **D2 存档直接通用**：任一版本写的存档，另一版本必须能直接继续（含 system.json 全局档）。这是**硬验收项**，优先级高于任何汉化美化。
- **D3 里程碑映射**：WP-1..3 记为**新里程碑 M5.6（双版本架构 + 存档通用）**；WP-4/5 = 既有 M5.1a–e；WP-6 = M5.3；WP-7 = M5.4；WP-8 = M5.5。MILESTONES.md 待 M5.6 首子项落地时回填。

### 38.1 证据基线（方案赖以成立的已证事实）

1. **存档坐标系天然语言无关**：`SaveState` 核心是解释器游标快照 `scnIndex/blockIndex/pc/flags/scene/phase/currentMsgIndex/currentSegmentIndex`（SaveManager.swift:103-119），JSON、version=1；存档目录**硬编码** `~/Library/Application Support/Shizuku/saves/`（SaveManager.swift:172-175），与 bundle 位置/Bundle ID 无关 → **两个 .app 开箱即共享同一份存档**，这是 D2 的地基。
2. **耦合只有 4 处、收口只需 3 步**（详见 DUAL_VERSION_SAVE_REPORT §2）：A1 读档 `Engine.swift:1329` 用档内 `language` 反向覆盖引擎语言；A2 `GlobalSystemData.language`（system.json）跨 bundle 互串偏好；B1 `previewText` 快照——**且 `Engine.swift:1290` 不看 language、只要 store 命中就写中文**（JP 构建是现存 P0 bug 面：CJK 进点阵预览带会被 LeafCodec 丢弃成残缺）；B2 `backlog[].textPreview`（:1276）。`cnPages/cnPage` 未入档、载入时重算（:1361-1365）——现状即正确答案。
3. **锚点契约与存档同坐标系**：`zh_text.json` 键 `"scn:msg"`（TranslationStore.swift:47-56）查询自 `translatedText(scn: scnIndex, msg: msg.index)`（Engine.swift:207），与存档字段同源；实测两条真实存档（save_01: scn116/msg1；save_02: scn127/msg34）的 previewText 与 SCN 解码逐字吻合 → **无需映射层**。
4. **JP/CN 剧本逐字节同一**：CN 目录 MAX_DATA.PAK 解包 403 文件与 `research/extracted/` MD5 全等（含 197 个 SCN）；中文译文**不在盘上任何容器**，只存在于 `Sizuku_cn.exe` 尾部 1,123,231B MoleBox 加密 overlay（外层 T-CBC 已解、内层 193×64B per-file 记录待解）；汉化补丁 exe = NSIS 安装器，**不含语料捷径**（Sizuku_cn.exe 整文件嵌于 0xd0654）。
5. **中文字形资产已在手**：`research/extracted/cn_KNJ_ALL.KNJ`（1852 槽 24×24 1bpp，与 JP 字库等长、95.08% 字节不同）+ 运行时字库三区结构（0-681 静态/682-1229 场景/1230+ Unicode 码点序简体区）→ M5.3 点阵渲染不需再逆向。
6. **M5.1 唯一缺口 = catalog 密文在容器内的偏移+长度**；`pf_cipher` 今日复测往返 300/300 绿；「loader 卡 fail 分支 0x27aceed」**只是未实证的假设**（双探针从未写进 full_emu.py）；`chk_keys.stub` 快照已随 /tmp 丢失，第一步必须冷启动 `run_keys.py`（~20min）。已证伪路线十条黑名单见 M51_ASSET_AUDIT §三，**严禁重走**。
7. 框架现状纠偏：ESC 菜单没有「切换语言」行（已恢复原版六项），语言切换在 macOS 菜单栏（main.swift:215-225）——WP-2 要删的就是它。

### 38.2 工作包划分（每个包 = 一个可独立验收的子代理任务）

| 包 | 内容 | 依赖 | 里程碑 | 类型 | 子代理预算 |
|---|---|---|---|---|---|
| WP-1 | 存档-语言解耦（含 B1 的 P0 bug 修复） | 无 | M5.6 | 代码 | 常规 |
| WP-2 | 构建期语言常量、删运行时切换 | WP-1 | M5.6 | 代码 | 常规 |
| WP-3 | 双 bundle 打包（package.sh 参数化） | WP-2 | M5.6 | 代码 | 常规 |
| WP-4 | 语料脱壳主线：catalog 偏移捕获（R1，R2 兜底，R3 并行保险） | 无（与 WP-1..3 并行） | M5.1a–c | 取证 | 重，见 §38.4 |
| WP-5 | 逐记录解密 → 全量 `zh_text.json` 导出 | WP-4 | M5.1d–e | 取证+管线 | 重 |
| WP-6 | 中文点阵字库渲染（系统字体 → KNJ 风格） | WP-5（需知实际用字集） | M5.3 | 代码 | 常规 |
| WP-7a | ZH 版系统外壳 UI 中文化（不需语料） | WP-2 | M5.4 | 代码 | 常规 |
| WP-7b | 选项/回想文本中文化 | WP-5 | M5.4 | 代码 | 常规 |
| WP-8 | 跨版本存档互读终验 + 双版本发布回归 | WP-1..7 | M5.5 | 验证 | 常规 |

**WP-1 存档-语言解耦**（改动全在运行时，两版本共用）：
① `Engine.swift:1329` 删除「读档采纳 `state.language`」、`:1322` 停止写入——字段保留解码兼容，**不 bump version、零迁移**；② `:1290` capture 预览固定走 JP 叶码解码（去掉 CN 优先分支，顺带修 P0）；③ `:1276` backlog 停写译文快照（HistoryView 本就用语言无关的 `lines: [[Int]]` 叶码，显示无损）；④ `:1229-1231` `translatedText` 加 `language == .zh` 门；⑤ slot picker 预览改**渲染时按 (scn,msg) 现算**（MetalGameView.swift:1824-1842 + SceneComposer.swift:733-744，ZH 版预览带用 `drawNativeText`）。
**验收**：`SaveLoadTests` 新增两例——「JP 语言引擎 save → 强制 .zh 引擎 load：cnPages 重挂、currentSegmentIndex 不变」「store 空引擎 load ZH 档：走 JP 渲染不崩」；`swift test` 由 74/74 → 76/76 全绿；`SHIZUKU_SHOT=slotload,slotsave,history` 出帧逐张目检（Read 导出 PNG 才算验收）。

**WP-2 构建期语言**：新增 `buildLanguage`（读 Info.plist `SHIZUKU_LANGUAGE`，缺省 .jp；环境变量覆盖仅供测试/SHIZUKU_SHOT）；`GameData.swift:78-80` **JP 构建根本不 `loadDefault`**（store 恒空＝「JP 版零中文污染」的最后防线）；删 main.swift:215-225 语言子菜单、MetalGameView.swift:337-347 与 :2813-2815、:253-254 启动采 system.json.language；`Engine.setLanguage`（:213-217）保留为测试钩子；`GlobalSystemData.language` 不读不写（解码兼容保留）。
**验收**：ZH env 构建 `SHIZUKU_SHOT=cn` 挂中文出帧；**JP 构建全 spec 帧与 §37 基线逐帧一致**（主防回归判据）。

**WP-3 双 bundle**：`package.sh` 参数化 `APP_LANG=jp|zh`——产物名/`CFBundleName`/DMG 卷名分叉，Bundle ID `local.shizuku.macos.{jp,zh}`（现 :71 两版同 ID 会混淆 LaunchServices，但**不影响存档路径**）；仅 zh 版拷 `zh_text.json` 进 gamedata（:52-57 条件化）；Info.plist 注入 `SHIZUKU_LANGUAGE`；**存档目录一行不动**。
**验收**：两个 .app 并装，A 版新档在 B 版「つづきから/ロード/快读」立即可见可读可续玩。

**WP-4 语料脱壳主线**（取证；按 M51_ASSET_AUDIT §四 R1 执行）：
步 1 把 `0x27aceed`(fail)/`0x27aceef`(success) 双探针**真正写进** `research/recovery/stub/full_emu.py`（文档承诺过、代码里没有），并确认 `[SetFilePointer]` 日志（L1688）能印出 loader 入口前后的 seek 序列；步 2 冷启动 `run_keys.py`（~20min、~4.5 亿指令）重生成 `chk_keys.stub`——**这次把 49MB 快照归档进 `research/recovery/stub/`**（或 git-lfs/.gitignore+目录说明），不再只留 /tmp；步 3 RESUME 60s 取 verdict → catalog 密文偏移+长度 → `dec_cbc(ks68_sched(seed_hex))` 离线解出 table1(47 条,stride 8)/table2(146 条,stride 0x18)。若 verdict=fail → 转 R2（改 full_emu 虚拟文件层，让 `CreateFileW/ReadFile` 把 EXE 尾部真容器喂给 loader）。并行保险 R3：解读 `toc_2710000.bin` 未榨干长度字段（0x1556/0x2e66/(0x129397,0x5a)），C 化有界区间×8 相位 `dec_cbc` 扫描（数据区界 0x56ab0..0x129397 已知）。
**验收**：catalog 明文记录表自洽——记录数≈193、每条 offset/length 落在 overlay 内、SCN 候选记录长度落在 64–7,584B 分布带、两条大记录对上中文字库(340,272B)与 UNKNOWN_LEAFCODE(144,048B)。

**WP-5 解密导出管线**：table2 记录逐条解密（entry 前 15B + 重定位 `[entry+4]` buf 基址 → `ks68_mixer` → 737KB 记录流）→ 按 (scn,msg) 键抽取译文库（叶帧式 2B 码流，经 Unicode→GBK 20,953 项表/槽→GBK 表解码，六维报告 §3.3/§4）→ 生成全量 `research/recovery/text/zh_text.json`。**语料规范**：每 msg 译文用 `\n` 分自然段、段数对齐 JP 段数（分页锁步 Engine.swift:220-239，跨版本读档 clamp :1364 兜底）。
**验收**：锚点 `"1:5"` 与现有唯一实证条目逐字相等；覆盖统计 = 命中条数 / 全 197 SCN 消息总数（脚本枚举 Scn.swift:531-542 消息表）；schema 校验（键 `"scn:msg"` 且 msg < 该 SCN 消息数）；灌入后 ZH 构建 `SHIZUKU_SHOT=cn` 换非锚点消息出帧目检。

**WP-6 中文点阵字库（M5.3）**：不再依赖逆向——用已 dump 的 `cn_KNJ_ALL.KNJ` 1852 槽 + 运行时三区结构（1230+ 为 Unicode CJK 码点序简体区，锚点：不=1237、世=1242、中=1252），建我方 `CNGlyphTable`（汉字→槽位→72B 位图），把 `drawCNTextLayer`（SceneComposer.swift:232-245）从 `drawNativeText` 反锯齿切到 KNJ blit + 原版双阴影三连盖章（:211-221 同款）。缺字回退系统字体。
**验收**：`SHIZUKU_SHOT=cn` 点阵版出图目检：无缺字洞、阴影与 JP 版观感一致；两路径可开关共存（构建内常量即可，勿做运行时菜单）。

**WP-7a 外壳中文化（M5.4，零语料依赖）**：素材已齐——CN 引擎 dump 内整套 UTF-16LE 中文菜单（`full_latest/full_0042c000.bin` VA 0x44581e：画面尺寸/全屏/窗口/环境设定/快进至下一选项/版本情报/结束游戏/确定/取消/播放音乐/播放音效/已读文字自动略过/快进时跳过未读文字）+ GBK 对话框串 + 安装器 GBK 串（`patch_installer_gbk_strings.txt`）。改 `MenuStrings.swift`/`UIText.swift`/ESC 六项/标题菜单/shelf 文案按 `buildLanguage` 分流；字库经 WP-6 或暂用 native。
**WP-7b**：选项菜单 `drawChoiceMenu`（SceneComposer.swift:259-289 现恒 JP 叶码）与回想模式按 store (scn,msgIndex) 出中文（`Choice.label` 恒 ""、无存档耦合，Engine.swift:765）。

**WP-8 终验（M5.5）**：脚本化互读——ZH 版推进 ≥5 个代表性存档点（含结局屏/staff roll 后/含选项页）→ 退出 → JP 版逐个 load `SHIZUKU_SHOT` 出帧比对（BGM/立绘/消息号一致），反向同理；system.json 互通核验（clearedEndings/seenHighWater/persistentFlags）；JP 全 spec 帧对 §37 基线 diff 为零；双版本 DMG 产出。

### 38.3 调度与并行拓扑

```
轨道 A（架构，立即开工）：WP-1 → WP-2 → WP-3 ─────────────┐
轨道 B（语料，立即开工，与 A 全并行）：WP-4(R1∥R3) →(R2?)→ WP-5 ─┤→ WP-6、WP-7b → WP-8
轨道 C（外壳，WP-2 后开工）：WP-7a ─────────────────────────┘
```
分工纪律：① 轨道 A 每包一个 commit，**`swift test` 基线常绿是合入门槛**（74/74 起，WP-1 后 76/76）；② 轨道 B 是取证——对仓库只读、产物落 `research/recovery/` 新子目录（**不再只存 /tmp**），`shizuku_macos_emuplay/` 绝对只读，CN 目录名尾随空格必须精确引用，十条证伪黑名单勿重走；③ 任何 UI 改动验收一律**先 Read 导出 PNG 目检再汇报**；④ 子代理预算：取证类长任务（run_keys 冷启动等）用后台跑＋断点续，**接近 turn 上限必须交部分报告＋现场清单**（快照路径/下一步命令），吸取 M5.1 跨会话状态丢失教训。

### 38.4 风险与回滚

1. **WP-4 不保证单轮出结果**（历史上 M5.1 已跨多会话阻塞）；R1+R2+R3 全败则转 R4（复刻 NSIS 解压器抽《完全攻略.doc》做人对照参考语料，重成本）或 R5（寻译者），届时**回来改本节而非硬撞**。
2. 译文库内联控制码是否逐条保留【未知，待 WP-5】：若译文整条替换吞掉了段内 bg/BGM 指令位，锁步推进的落穿逻辑（Engine.swift:1113-1115）需按 WP-5 实测调整——**这正是语料规范「段数对齐 JP 段数」写进 WP-5 验收的原因**。
3. 两版本同时运行读写同一 saves：原子写已有（SaveManager.swift:205），无跨进程锁——发布说明加「勿双开」。
4. 老档已含中文 `previewText`/`language:"zh"` 残留：WP-1 收口后自然无害（忽略+现算），无需清洗。
5. `phase` 是字符串原始值 Codable（Engine.swift:458-460），重命名会破两版本互读——列为**长期冻结约束**。
6. WP-1/2 若意外破坏 JP 保真：逐条 revert（均为行为收口、不改格式，旧档无损）。

### 38.5 遗留开放问题（不阻塞开工）

- CN 侧 `sizfont.tbl` 是否被换/绕过【未知】；我方方案不依赖它（zh_text.json 存 Unicode 明文，WP-6 自建汉字→槽表）。
- ZH 版标题画面美术仍是日文立绘/标题图（TIT 图像未汉化）——原版补丁也没做，超出本计划范围，留 M5.5 后议。
- 结局名/staff roll 中文文案、《完全攻略》对照校核质量：待 WP-5 语料到手后另立节评估人工校对量。

## 39. 2026-09-24（M5.6 轨道 A 实录：WP-2 / WP-3 / WP-7a 全部落地，轨道 C 外壳中文化完成）

> 本节是 §38 计划中 **WP-2、WP-3、WP-7a** 三个包的交付实录（WP-1 见 `d063216`/§38.2 验收）。轨道 A 三包各一 commit，每步 `swift test` 全绿：**98 → 105（WP-2）→ 105（WP-3）→ 111（WP-7a）**。轨道 B 并行推进中（`1ffbc2c` 已破 Interlocked* 桩根因、解出 80B catalog 明文）。

### 39.1 WP-2 语言=构建期常量（`0152011`）

- **选型**：§38.2 指定 Info.plist 方案（SwiftPM `-DZH_BUILD` 会污染 `swift test`，弃）。新增 `ShizukuCore/BuildLanguage.swift`：`resolve(environment:infoPlist:)` 纯函数，优先级 **env `SHIZUKU_LANGUAGE` > Info.plist `SHIZUKU_LANGUAGE` > `.jp` 缺省**，非法值一律回落 `.jp`；`BuildLanguage.current` 为 `static let`。
- **删除（不留兼容壳）**：main.swift「表示言語」子菜单、MetalGameView 启动 `setLanguage(loadGlobalSystem().language)`、`setLanguageFromMenu`、`validateMenuItem` 勾选分支。`Engine.setLanguage` 保留为测试/`SHIZUKU_SHOT` 装配钩子，UI 不再暴露。
- **字段兼容**：`GlobalSystemData.language` 与 `SaveState.language` 均保留为 Optional Codable（旧 system.json/存档可解码，version 仍 1），只不读不写。`Engine.language` 初值 = `BuildLanguage.current`。
- **GameData 加载逻辑不动**（任务裁定覆盖 §38.2「JP 构建根本不 loadDefault」一条）：JP 构建的中文门控已由 WP-1 `translatedText == .zh` 保证；WP-3 进一步让 JP bundle 根本不打包 zh_text.json，双保险。
- 测试：`BuildLanguageTests` 6 例（缺省/plist/env 覆盖 plist/垃圾值回落/测试进程恒 .jp/新引擎种自构建常量）＋ `SaveLoadTests.testZHBuildSaveLoadsIntoJPBuildEngine`（验收⑤反方向：ZH 存档→JP 载入不崩、无 language 键、预览 JP 现算非空）。

### 39.2 WP-3 双 bundle（`ba13659`）

- `package.sh [jp|zh]`：**无参数＝旧产物逐字节零回归**（`Shizuku_Restored_Ver.X`、旧 Bundle ID、照挂 zh_text.json）；`jp` → `Shizuku_Restored_JP_Ver.X`（`local.shizuku.macos.jp`，plist `SHIZUKU_LANGUAGE=jp`，**zh_text.json 不入包**＝JP 零中文污染）；`zh` → `Shizuku_Restored_ZH_Ver.X`（`local.shizuku.macos.zh`，plist `zh`＋挂语料）。DMG 卷名随 APP_NAME 分叉。
- `ShizukuApp.name` 改读 `CFBundleName`（ZH bundle 菜单栏/窗口标题自动显 `_ZH`；dev `swift run` 无 plist 回落旧名）。**存档目录一行未动**（两版共享 `~/Library/Application Support/Shizuku/saves`）。
- 端到端：ZH `.app` 内二进制**不带 env** 跑 `SHIZUKU_SHOT=cn` 出中文帧（plist 驱动 `.zh`）；三 bundle plist/ID/语料就位逐项核验。

### 39.3 WP-7a 外壳中文化（`1ddae5f`，ZH 构建 only）

- **新档 `ShizukuRender/ShellText.swift`**：`MenuRow = .leaves([Int]) | .native(String)` 统一绘制与命中；每表面一张按 `buildLanguage` 分流的表——**JP 行＝旧 `MenuStrings` 叶码逐字引用**（防回归），ZH 行＝素材原文（cn_dump UTF-16LE：结束游戏/确定/取消；GBK：即将退出游戏。/确定吗？）＋HANDOVER 既定译名（しおり→书签、クイックセーブ→快速存档）。
- **SceneComposer**：init 增 `language`（缺省 `BuildLanguage.current`）；`drawMenuRow`/`menuRowRect`/`drawShellText`/`shellTextWidth`/`nativeTextWidth` 五件套；`drawEscMenu`/`drawConfirmMenu`/`drawSlotPicker` 的表头、行标签、日期列、（空）、底部提示、确认框全走分流。**JP 路径逐像素不变**（`testJPEscMenuPixelIdenticalToLegacyLoop` 锁死）。
- **ZH 落点**：ESC 六行（隐藏文字/载入游戏/存档游戏/场景回想/返回上一个选项/结束游戏）、标题五项（从头开始/继续游戏/回想模式/结局列表/结束游戏）、确认框（即将载入。/即将存档。/即将退出游戏。＋确定吗？＋确定/取消，（１）（２）徽标与 ▶ 光标保留叶码）、载入/存档选择器（请选择要载入的数据·请选择要存档的书签／书签 N／（空）／点击确定　ESC返回／日期 `MM月dd日 HH:mm`）。
- **范围收口**：选择支菜单（choices）与回想文本＝语料依赖，留 WP-7b；结局列表/画廊/音乐房文案留 M5.4 后续；中文点阵字库留 WP-6（现走 `drawNativeText` 反锯齿）。
- 测试：`ShellTextTests` 6 例（JP 表逐字＝旧、ZH 表内容锁、JP 像素一致、ZH 三框落墨、语言缺省、命中框居中）。

### 39.4 验收与量具注记

- **JP 零回归**：`SHIZUKU_SHOT=title,esc,slotload,confirm,continuelist` 与 `d063216` 基线（`build/jp_baseline_preWP2_d063216/`）**五帧逐字节一致**。插曲：WP-7a 轮 slot 帧曾报 DIFF——`save_03.json` 于 23:13 被**外部进程**覆写（时间戳列变化所致，非代码回归）；把档内 timestamp 临时改回基线值重跑即逐字节一致，验后已原样恢复。**教训：slotload/continuelist 帧与真实 saves 目录耦合，做字节级比对须先冻结/备份 saves 目录**（`slotsave` token 本身也写 slot 3）。
- **ZH 目检**：`SHIZUKU_LANGUAGE=zh` 出 `title/esc/slotload/confirm/cn` 五帧逐张 Read——中文行居中、选中白/未选灰层级正确、空格子（空）双处（明细列＋预览带）走原生字体、JP 叶码预览带在 ZH 构建照常。
- 帧路径：`/tmp/shizuku_shots/`（临时）；JP 基线永久档 `build/jp_baseline_preWP2_d063216/`（73 帧＋MANIFEST）。
- 遗留：①§38.2「JP 构建根本不 loadDefault」被任务裁定改为「不打包语料＋.zh 门控」双保险，如后续要硬防线可再收；②`SHIZUKU_SHOT=slotsave` 与真实存档耦合，MANIFEST 级复跑须备份 saves 目录；③ZH 窗口标题「雫～しずく～」未变（外壳文案 WP-7a 未含窗口标题，留 M5.4 后续一起收）。

## 40. 2026-09-25（★WP-4/5 语料收官 + WP-8 跨版本互读终验 + 双 DMG 产出：可用中文版达成★）

> 本节收口 §38 方案剩余三包：**WP-4（脱壳解密）**、**WP-5（字表还原→全量 zh_text）**、**WP-8（互读终验＋双版本发布）**。测试 **111/111** 全绿；JP 全 spec **70/73** 逐字节一致（3 帧差异全部限于预览带＝§39.4 已知 save_03 环境耦合，非回归）。

### 40.1 WP-4 脱壳解密实录（`1ffbc2c`→`bfcfbc9`）

- catalog 根因击穿（`1ffbc2c`）后，二程抢救解出 **199 条 CN 记录全量落盘** `research/recovery/text/cnrec/`（SCN 容器解析器 `wp5_parse.py`），并 dump 出 CN 端 **4726 槽字库** `cnfont_4726.bin`（72B/字形，列主序 1bpp：`g[(c//8)*24+r]` 的 `7-(c%8)` 位；叶码 1 基索引）。
- 语料侧共 **2868 个在用 CN 叶码**；字库 CN 区（1853..4726）经 34 对锚点验证为**严格 Unicode 码位序**（0 逆序），空槽仅 6 个。

### 40.2 WP-5 字表还原与全量导出（`bfcfbc9` 抢救→`0009336` 定稿，安装 `6d4312e`）

- **判分器 v2（决定性）**：旧 IoU+块余弦对真值仅 0.60、无区分度（误读根因）；改为**模糊平移 NCC**——槽 24×24 位图高斯模糊(σ=1)作模板，在 SimSun-24px 64×64 渲染图上 `cv2.matchTemplate(TM_CCOEFF_NORMED)` 取峰值：真值 0.73–0.93，易混字低 ≥0.15。叠加**外部字频先验** `+0.08·log1p(freq)/log1p(max)`（`hanzi_freq_jieba.json`，12010 字，取自 jieba dict.txt），破同形/近形平票。
- **求解**：候选池收为 **GB2312 可编码字**（GBK-only 生僻字即旧误读类）；锚点分段＋单调严格递增 Viterbi DP；运行时 37s。**结果：2868/2868 全映射、34/34 锚点逐字复现、0 序违例、0 重码**（两处已知字库倒排槽 4404/4405、4484/4485 定点豁免）。
- **JP 原文交叉验证**（`research/extracted/sizfont.tbl` 叶码→日文）：瑠璃子／雫（零落成雫）／弱点／第二体育館／長瀬祐介（祐介 74 现）／親父油 等全部对上；15 处定点修正入 `wp5_fixmap.py`（假/内/啰/弱/涕/瑠/祐/第/藏/覆/親/跑/遘/遗/雫 等），3 处一次性垃圾槽 rewindow（弲/涘/藍）。
- **导出**（`wp5_export.py`）：**3834 条 `(scn,msg)→中文`**（JP 4044 条消息的 94.8%），195/197 CN↔JP SCN 匹配；缺口全部定性：CN 侧无 scn17/20、JP 侧 [0,205] 无 CN 对应、empty_skip 170（原文即空）、unmapped_code 24（JP 区码）。"1:5" 锚点句逐字复现 True。
- **安装**（`6d4312e`）：全量语料替换运行时 `research/recovery/text/zh_text.json`（957888B）；旧单锚点版留档 `zh_text_1anchor.bak.json`。引擎经 `TranslationStore.loadDefault` 双路径（bundle gamedata 优先、dev 目录兜底）零改动生效。

### 40.3 WP-8 终验与双版本发布

- **互读（正反向）**：6 个代表存档点 fixture（`/tmp/wp5_saves/cn_*.json`，配方＝JP save_01 改 scnIndex/currentMsgIndex＋seenHighWater）——ZH 构建 6/6 `cnActive=true` 中文出帧（含 90:17「瑠璃子，凝视着月岛。」、95:21「炫目/倾泻」）；**同一批档喂 JP 构建**（`loadsave` token＋`SHIZUKU_LOAD_FILES`）6/6 正常恢复、行码数一致，90:17 渲染「瑠璃子さんは、月島さんを見つめていた。」。存档-语言解耦（WP-1）在**全量语料**下双向成立。
- **ZH 外壳目检**（全量语料下重渲）：title／esc_menu／confirm_end／continue_picker／slot_load 逐张 Read——五帧全中文、原版背景、光标与（１）（２）徽标保留。
- **JP 零回归**：HEAD 全 spec 73 帧对 `build/jp_baseline_preWP2_d063216/MANIFEST.sha256`：**70/73 逐字节一致**；3 个失败帧（slot_load/continue_picker/slot_save）numpy 行差全部限于预览带（y298–341/y242–285）＝save_03 被历史 `slotsave` 采样覆写的已知环境项（§39.4），非代码回归。
- **双 DMG**（`build/`）：`./package.sh jp` → `Shizuku_Restored_JP_Ver.0.1.dmg`（54,244,335B；包内 `zh_text*` 命中 **0**、plist `SHIZUKU_LANGUAGE=jp`）；`./package.sh zh` → `Shizuku_Restored_ZH_Ver.0.1.dmg`（55,516,331B；gamedata 399 文件、zh_text.json 957888B/3834 条、plist=zh）。**挂载冒烟**：ZH DMG `hdiutil attach` 后直接跑卷内二进制 `SHIZUKU_SHOT=cn` → 出帧「然后不知在某个不经意的瞬间…」目检通过，验毕 detach。
- **量具**：`loadsave` token（`018720f`）出帧＋diag（scn/msg/seg/cnActive/line0/jpLine0Codes）已脚本化互读，回归可复跑。

### 40.4 遗留（不阻塞「可用中文版」判定）

- ~~WP-7b：选择支选项文本/回想屏的中文走查~~ → **当日落地，见 §41**。
- WP-6（可选）：原版 CN 点阵字库挂载（现走原生反锯齿字体，WP-1 既定设计）。
- 外壳尾巴：ZH 窗口标题、结局列表/画廊/音乐房文案（§39.4 遗留③延续）。
- 语料尾差：7 处分段不一致、JP [0,205] 两 SCN 无 CN 原文（原版即缺，非丢失）。

## 41. 2026-09-25（WP-7b 收口：选择支＋SELECT 提示语＋回想屏中文化）

> §40.4 遗留的头号项（WP-7b）当日落地。两 commit：`3d23044`（选择支＋提示语）、`6021db5`（回想屏）。测试 111/111；JP 全 spec 重跑仍 **70/73**（同 3 帧＝save_03 环境项；`choice_menu/history_newest/history_older` 帧**逐字节一致**＝JP 分支零改动实锤）；双 DMG 已用最终二进制重打。

- **选择支选项**（`SceneComposer.drawChoiceMenu`）：选项文本本身就是消息记录（scn1 选项＝msg 8/9/10，与语料同坐标系），ZH 下 `engine.translatedText(scn:msg:)` 命中即走 `drawNativeText`（20px 反锯齿＋1px 阴影，选行/未选行双色阶保留），未命中回落叶码点阵——JP 构建语言门控恒 nil，像素不变。
- **★SELECT 提示语留屏修复★**（`Engine.cnActive`）：0x05 提示消息 `beginMessage→commit` 后置 `currentMsg = nil`（选项光标期无消息可推进的既有语义），但 `cnPages` 仍在屏——旧门控 `currentMsg != nil` 把提示语打回 JP 渲染。改为只认 `!cnPages.isEmpty`（`cnPages` 在消息终了/换消息/restore 三处已清零，生命周期自洽）。ZH `choice` 帧目检：提示语「然而即便如此，我依然无动于衷…」＋三行选项全中文，原版编号 1、2、3 保留。
- **回想屏**（`HistoryView`）：`Entry` 增 `scn/msg`（`BacklogEntry` 本就携带），`render` 增 `cnText` 参数——命中语料则按 22 字/行 `paginateChinese`（`ShizukuEngine.paginateChinese` 转 public）平铺前 `linesPerScreen` 行（原版无滚动、溢出裁掉的口径不动），↑↓ 灰箭头照常；`SceneComposer.drawNativeText` 提出静态孪生供 HistoryView 复用。ZH `history` 两帧目检通过；JP 分支逐像素不变（MANIFEST 锁）。
- **ZH 全表面清单**：正文/选项/提示语/回想/标题/ESC/确认/载入存档选单/预览带＝全中文；余外壳尾巴（结局列表/画廊/音乐房文案、窗口标题）为纯文案项，不阻阅读。

## 42. 2026-09-26（WP-9 实机三修：中文推进重做＋菜单文案收官）

> 用户实机试玩 ZH 版报三缺陷：①一页中文后露同内容日文页；②中文整页直出、无逐字显影/按拍手动推进；③结局列表/画廊/音乐房等菜单仍是日文。§41 的「WP-7b 收口」据此判 premature——lockstep 翻页设计（cnPages 页数≠JP 段数，末页落回 JP 推进）就是①的根因，②则是 `drawCNTextLayer` 绕开了显影时钟。本轮两 commit：`a35d3cc`（①②推进重做）、`bd7e9bf`（③菜单收官）。

### 42.1 ①② 中文推进重做：译文按 JP 拍切片、共用语义时钟

- **模型**：删掉 CN 独立翻页态（`cnPages/cnPage/cnOnLastPage` 全部退场），JP 段机器成为**唯一时钟**——`advanceMessage` 不再有 CN 分支，拍/停顿（waitKey/pageBreak）/内联动作（bg/立绘/BGM）跨语言逐拍一致。译文按各段 JP 字码数比例切成 `cnSlices`（`Engine.sliceChinese`：累计 floor 切点，命令段恒空片，余数归最后一个文本拍；`\n` 摊平），`cnCommitted` 镜像 `screenLines`（`commitActiveLines` 合入、pageBreak 清空、`finishMessage`/`start`/restore 清零）。
- **逐字**：屏上文本＝`cnDisplayedText`＝`cnCommitted + cnSlices[seg].prefix(revealedGlyphs)`——`tickReveal` 的 `textSpeed` 时钟天然逐字打中文；显影未完点击＝补全，拍尾点击＝推进（弟切草式）。CN 片长一般 <JP 字码数（中文更紧凑），显示更快收尾；若反超，拍尾 `revealedGlyphs>=activeGlyphCount` 时整片 snap 出全（不吞字）。超一页（22×11）时 `cnCurrentLines` 取**末窗**（滚动），不再截丢文本。
- **零泄漏**：`drawTextLayer` 在 `cnActive` 时整层交给 `drawCNTextLayer`，JP 叶码栅格在 ZH 命中消息上**永不绘制**（旧①＝末页后落回 JP 段渲染，同内容日文再现）。SELECT 提示语语义不变：`cnActive` 仍不绑 `currentMsg`，commit 后提示中文留屏。
- **等待光标**：`drawContinueIndicator` 增 CN 分支——`waitingPause` 驱动、6 亮 6 灭同拍，ZH 用原生字画 ▶（waitKey）/▼（pageBreak）于中文行尾（JP 叶码 102/103 分支逐像素不动）。
- **save/restore**：`rebuildCNPresentation` 内 `rebuildCNCommitted()` 按 `currentSegmentIndex` 之前的拍重放（pageBreak 清零），跨版本档恢复后中文层落在存档拍上（WP-1 解耦语义保持）。
- **量具**：新 `cnreveal` shot token（ZH 下 preview 1:5，24 拍 tick 出 mid 帧、显影满出 full 帧、再点推进）——`cnreveal_mid0` 半句「…的世」/`cnreveal_full0` 整句，逐字实锤；空 store 或译文为空自动回落 JP（170 条原文即空的消息不再出空白 CN 页）。

### 42.2 ③ 菜单文案收官（ShellText 扩容，JP 路径恒落回原叶码）

- **结局列表**（`drawEndingListOverlay`）：标题/状态/结局名走 `drawShellText`+`ShellText.endingsTitle/endingsStatus`；`ShizukuEnding.titleZH` 新增（瑞穗/沙织/琉璃子按汉化惯例，HAPPY/BAD→好/坏结局，True→真结局，トースター→烤面包机，太田さん→太田先生）。
- **回想画廊**：头部 `ShellText.galleryHeader`（MenuRow 分流，JP＝`MenuStrings.recallMode` 叶码原路）、提示语/页码 `galleryHint/galleryPageLabel`（ZH「第n页（共m页）」右对齐按 `nativeTextWidth` 量宽）；锁定格「？」不动（KNJ 全角问号双语通用）。
- **音楽モード**（`MusicRoom.render` 增 `lang` 参，默认 .jp）：`ShellText.musicStrings` 一次给全房文案（音乐模式/正在播放/选中曲目/作曲・编曲/上一首·播放·下一首/右键点击或按ESC退出）；ZH 分支走 `SceneComposer.drawNativeText` 静态孪生双联印；**曲名与作曲署名保持 `Sizuku.exe` 字符串表原文**（数据非 UI，逐表取证见 §30）。按钮 hit rect 仍按 JP 三串宽度（ZH 串等长 3 字，兼容）。
- **toast 横幅**：JP 串＝内部键，`ShellText.toastCN` 映射（`[SLOT n]`/`[ON]`/按键名等动态尾巴保留），`drawToastOverlay` ZH 按 `nativeTextWidth` 量盒宽＋原生字。
- **窗口标题/退出对话框**：`ShellText.windowGameTitle`（ZH「雫～shizuku～」）；`windowShouldClose` NSAlert ZH 化。菜单栏维持「日文（中文注）」双语制不动。

### 42.3 验收

- 测试 **113/113**（新增 `testSliceChineseProportional`＋`testCNBeatRevealAndFinish`：切片拼回恒等于完整译文、命令段空片、开拍零字、`revealGlyphs(5)`＝首拍前缀、收尾清 `cnSlices/cnCommitted`）。
- JP 全 spec 73 帧对 `build/jp_baseline_preWP2_d063216/MANIFEST.sha256` 两轮（推进重做后、菜单收官后）均 **70/73 逐字节一致**（3 失败帧＝slot_load/slot_save/continue_picker 已知 save_03 环境项，§39.4）。
- ZH 目检帧（`/tmp/shizuku_shots`，已拷 `build/zh_wp9/`）：`cnreveal_mid0/full0`（逐字）、`game`（拍尾＋原生 ▶）、`choice_menu/history_newest`（无泄漏）、`gallery_locked`（回想模式/点击放大 方向键移动/第1页（共6页））、`endings`（结局达成状况/○ 已达成/…）、`music_room17`（全房中文＋JP 曲名署名）。
- 双 DMG 用最终二进制重打（JP→`build/`，ZH→`release_zh/`）。
- 遗留：①②③待用户实机复验（尤其多页长文与 pageBreak 节奏）；WP-6 汉化点阵字库（M5.3）仍为可选项，用户明示排在三修之后。

## 43. 2026-09-26（WP-10：中文停顿点吸附句尾，修「Enter 卡半句」）

> 用户实机复验 §42 后报新缺陷：「带多次 enter 有大量内容的页，停顿点是不对的，会卡在半句中」。根因＝`sliceChinese` 纯按 JP 字码数比例硬切，切点落进 CN 句子内部；JP 原版每拍收尾于句读，中文须对齐这一阅读手感。

### 43.1 切点吸附算法（Engine.sliceChinese）

- 新增 `sentenceBoundaries`：扫描译文（`\n` 摊平后的字符阵），收集每个句读符（。．！？…!? 及独立收尾的 」』）紧邻其后的**闭符号游程**（」』）》"' …！并入同一切点）之后的下标为候选边界，末尾恒补 `chars.count`。
- 每个文本拍的切点＝**距比例目标 `T*cumJP/totalJP` 最近、且严格大于 `prevCut` 的边界**（等距取小者，边界单调不复用）；候选耗尽（前拍已吃到文末）退回原始目标值→自然出空片（＝JP 该拍无新文本）；命令段仍恒空片、余数仍归最后一个文本拍。
- 无任何句读的译文只剩文末边界→首拍吃全文、后拍空（可接受回落）；`testSliceChineseProportional`（50×「字」无标点）语义不变仍绿。

### 43.2 验收

- 测试 **115/115**：新 `testSliceChineseSnapsToSentenceEnders`（三句 40/40/40 拍目标 10/20/30 全落句尾＋引用尾「。」并入）；新**全语料扫描** `testSliceChineseCorpusPausesLandOnEnders`——对 zh_text.json 实载 3834 条逐消息切片，断言「后随仍有文本拍的切片必终于句读」，**零违例**（checked>2000）。
- ZH 目检（`build/zh_wp10/cn_snap/`）：1:5 单拍整句「…失去了色彩和声音。」；**2:4 长页（163 字 5 拍）** 逐拍 full0/1/2 帧分别收于「新型炸弹。▶」「它们引爆。 ▶」「烈火席卷覆盖。」——多 Enter 停顿点全部落句尾。
- JP 全 spec 73 帧对基线 MANIFEST 再跑仍 **70/73**（3 失败＝已知环境帧，§39.4）；`sliceChinese` 仅 CN 路径调用，JP 逐字节不受影响。
- 量具：`cnreveal` token 增 `SHIZUKU_CN_SCN/SHIZUKU_CN_MSG` 环境变量选消息（默认 1:5 不变）。
- 双包重打：ZH app+DMG → `release_zh/`（55546358B），JP DMG 维持 `build/`；ZH 应用已用新包重启待用户复验。归档帧 `build/zh_wp10/{cn_snap,jp_regression}/`。

## 44. 2026-09-26（WP-11/12：全中文切汉化点阵字库 ＋ 两缺陷「假名泄漏」「连点 Enter」）

> 用户先提需求：「所有中文字都用汉化版同款的点阵中文字，同页继续剧情的三角和翻页图标用日文同款的（原版汉化也这样）」；实机复验 WP-10 后再报两缺陷：①极个别句子出现日文假名 ②有时候要连续点很多下 Enter 才能正常继续剧情。本节三事一并收口。

### 44.1 WP-11 汉化点阵字库接入（M5.3 转正）

- **字库**：`research/recovery/text/cnfont_4726.bin`（4726 槽 × 72B＝340272B，24×24 1bpp 列主序，**1-based** 码索引：`bytes[(s-1)*72]`、`b=g[(c//8)*24+r]`、`bit=(b>>(7-(c%8)))&1`）。前 1852 槽与 JP `KNJ_ALL.KNJ` 逐字节相同（已验），1853..4726 为汉化区（符号/假名子集＋按 Unicode 升序的汉字子集）。
- **新模块** `ShizukuCore/CnDotFont.swift`：`KnjFont` 容器孪生＋`charToCode`（读 `cn_code2char.json`，现 2872 条）；`pixels(for:)` 走 `aliases`（`…`→`┅`）后查 CN 区；`candidateDirs` 与 `TranslationStore` 同构（ZH 包内 `Resources/gamedata`、dev 下 `research/recovery/text`，**两文件须同目录**）。`GameData.cnDotFont` 为 `lazy var`，JP 路径永不触发加载。
- **渲染**：`SceneComposer.cnMatrixGlyph`（CN 区优先，未命中回落 JP 叶码 fold——汉化补丁本身就是这么混排的）→ `drawCNMatrixText`（沿用原版 drawChar 三遍叠印：+1/+2px 双影＋本体）→ `drawZHText`/`zhTextWidth`（静态＋实例双孪生；字库缺失时降级原生字）。**绘制与命中同一量具**（`cnMatrixTextWidth`＝24px 等宽单元），点击不会落到没画出来的行上。
- **覆盖面**（凡原走 `drawNativeText` 的中文面全部改走点阵）：正文层 `drawCNTextLayer`、选择支选项（`translatedText` 命中即点阵）、`MenuRow.native` 行（标题五项/ESC 六项/确定·取消/回想模式头）、`drawShellText`/`shellTextWidth`（画廊提示与页码、选槽头/槽位行/空格子/时间戳/提示语）、toast 横幅、存档预览带（`previewIsCN` 两行自然段落）、回想 HistoryView、音乐房 UI 壳（曲名与署名仍 JP 原文）、结局列表。

### 44.2 ▶/▼ 用日文同款叶码

- `drawContinueIndicator` 的 CN 分支不再自绘三角，改为 `drawLeaves([pause == .pageBreak ? 103 : 102])`——**直接取原版 KNJ 叶码 102（同页待续 ▶）/103（页满 ▼）**，与原版汉化一致。
- 目检：`build/zh_wp11/menus/wait_key.png`（正文两拍收尾处白三角 ▶）、`wait_page.png`（第四行末原版点阵页满符）。选择支光标「❯」、回想 ▲▼ 同步保持叶码原样。

### 44.3 WP-12 码表符号/假名区重建（缺陷①根因）

- **根因**：`cn_code2char.json` 由 `wp5_fontmap.py` 产出——在**仅 GB2312** 的候选集上做单调 DP＋34 锚点＋SimSun 模糊 NCC。汉化字体只装 GB2312 假名的**子集**，连续性假设从 1869 起把每个标签整体错位；标签错位＝`charToCode` 反查落到真假名槽，于是正文里凭空多出日文假名。
- **修法**：`wp12_kanatable_fix.py` 以字形图逐格目检重建 1854..1912（`・―’“”┅●、。《》「」『』` ＋ 44 假名 ＋ `アイルワ ー`），约束＝GB2312 单调＋零重复，并用六处独立日文上下文交叉验证；1853 保持原 `空格`。备份 `cn_code2char.json.pre-wp12.bak`（表 2868→2872，改 39 码）。
- **重导**：`wp5_export.py` 重跑，225 条译文变化，`unmapped_code` 仍 24、`empty_skip` 170、1:5 锚点逐字一致；`zh_text_full.json`→`zh_text.json` 安装。
- **残留 12 条假名＝刻意保留**（逐条核对）：译者注里的 `さん/ちゃん` 敬称说明、`アルワイャー` 方言注、平假名长头衔梗「こっかいじげん…」、`「く」字形`（描述身体反弓形状，必须是く）、`どうしよう、怎么办。` 与 `今は、まだ┅。` 等原文夹叙。**不再有误标**。
- **汉字区**（暂缓，非可见缺陷）：`wp12_hanziglobal.py` 两段式（576 维去均值余弦→top-40 精确 NCC）出 84 条可疑，人工复核为**高假阳**（丸→九、口→目、明→朋、西→酉、雨→用 皆错）；且 WP-11 后游戏走 字→码→图 往返，标签错**仍画出正确点阵**（表内零重复已验），只影响文本真实性与降级原生字路径。故降级为数据洁癖项，`wp12_hanzi_flags.json` 留档待续。`wp12_fontaudit.py`（CN↔JP 位图精确比对）为负结果：`agree=0 novel=2873`，不能作为判据。

### 44.4 缺陷②：中文空拍自动跳过（Engine）

- **量化**：语料内「有 JP 字码拍但 CN 切片为空」的静默文本拍 **987** 个，另有静默命令拍 **2702** 个，波及 **2771/3755** 条消息，最长连击 **59** 下零反馈——正是「连点很多下 Enter」。JP 原版这些拍有字形，`cnActive` 下 JP 网格被隐藏，于是每拍白付一次点击。
- **修法**（`Engine.swift`，仅 CN 路径）：`isCNEmptyBeat(seg,index:)`＝非 pageBreak ＋ 无内联动作 ＋ 该拍切片为空；`skipCNEmptyBeats()` 只前移 `currentSegmentIndex`（**不在循环里 apply，避免重放动作/转场、卡内联命令**），落点变了才同步 `currentPage`＋`applyCurrentSegment()`，越界则 `finishMessage()`。接入两处：开消息路径（`skipInertSegments` 之后、写 backlog 之前）与 `advanceMessage` 递增段号之后。
- **回归**：`testCNAutoSkipsSilentBeats` 扫语料取「静默拍≥3 且非静默拍≥2」的消息（最多探 6 条），驱动 `previewMessage`＋`advanceMessage` 环，断言点击数**恰等于** `Σ stops (1 + (counts[i]>0 ? 1 : 0))`。

### 44.5 附带修复：toast 假名

`ShellText.toastCN` 的 `suffix` 只搬 JP 方括号尾巴，导致横幅印成「已保存（しおり 3）」。现尾巴内 `クイックセーブ`→`快速存档`、`しおり`→`书签`，出「已保存（书签 3）」。

### 44.6 验收

- 测试 **116/116**（新增 44.4 的空拍计数测试）。`swift build -c release` 绿。
- **JP 全 spec 73 帧**对 `build/jp_baseline_preWP2_d063216/MANIFEST.sha256`：**69/73 逐字节一致**，4 张失败帧逐张定位为动态数据（非代码回归）：`slot_load` 0.73%（行 130..341）、`slot_save` 0.26%（行 242..285）、`continue_picker` 4.50%（行 130..681）＝`save_03.json` 被 ZH 测试重写（§39.4 已知三帧）；新增第 4 张 `gallery_locked` 5.21%，差异**只落在第 2 行缩略图格（bbox 971,297..1269,483）**，文字行零变化，成因＝`~/Library/Application Support/Shizuku/saves/system.json` 于 21:58 被 ZH `endings` 帧写入多解一个 CG。结构判据：`cnDotFont` 仅 `SceneComposer:475/515/539` 读，`drawZHText` 全部调用点均在 `cnActive`／`MenuRow.native`／`language == .zh`／`translatedText` 命中／`previewIsCN` 之后——JP 分支按构造不可达。
- **ZH 目检帧**归档 `build/zh_wp11/`：`menus/`（30 张：title/esc_menu/gallery_{open,vis,zoom,fade,locked}/music_{room0,room15,room17,plate,fading}/endings/history_{newest,older}/choice_menu/continue_picker/slot_load/slot_save/confirm_end/game/wait_key/wait_page(+flip 帧)/toast）、`cnreveal/`（101:2 长页 13 拍，`mid1` 半显证逐字、`full0..2` 整页）、`jp_regression/`（73 张）。全部中文面确认走汉化点阵字，选中色/居中/提示语正确，曲名与署名保持 JP 原文。
- **打包**：`package.sh zh` 增段——`COPY_ZH_TEXT=1` 时把 `cnfont_4726.bin`＋`cn_code2char.json` 一并 rsync 进 `Contents/Resources/gamedata`（JP 包零中文、零字库不变）。ZH app+DMG 重打入 `release_zh/`（DMG 56285470B），并**用包内二进制**（非 dev 路径）复跑 `title,toast,choice` 证明字库从 bundle 内挂载成功。JP DMG 维持 `build/`。
- 遗留：①用户实机复验手感（逐字节奏、空拍跳过后是否仍有长连击、点阵字可读性）；②44.3 汉字区标签洁癖项；③M5.5 十三结局回归；④语料尾部 7 处段落错位（如 142:19 混排句，属对齐缺陷非码表缺陷）。

## 45. 2026-09-26（WP-13：macOS 菜单栏中文化 ＋ 中文版产物目录改 build_chs/）

> 用户：「修改中文版的 mac 设置菜单语言，然后打包在 build_chs 文件夹里」。范围经确认＝**整条菜单栏全中文化**（アプリ/ゲーム/設定/表示 四顶级菜单＋全部子项＋App 菜单的 About/Hide/Quit），日文版保持「日文（中文注）」逐字不变；`release_zh/` 作废。

### 45.1 菜单栏按构建语言分流

- `main.swift/setupMainMenu` 引入局部 `t(jp:zh:)`（读 `BuildLanguage.current`）——**JP 串原样留在原地**，逐字符未动，ZH 串＝把原本作注的中文提为唯一标签、去掉日文头词与括号。顶级菜单 `ゲーム→游戏`、`設定→设置`、`表示→显示`；`About/Hide/Hide Others/Show All/Quit → 关于/隐藏/隐藏其他/全部显示/退出`（产品名仍取 `CFBundleName`，未改）。
- 早送り三档标签在 `MetalGameView.fastForwardSpeedChoices` 元组里加 `zhLabel`（`遅い/普通/速い → 慢/标准/快`）；跳过按键子项（Tab/Z/X/C/Shift/Ctrl）语言中立，不分流。
- **连带修好一处假名泄漏**：`showToast("早送り速度 [\(sender.title)]")` 的 title 就是菜单项标题，ZH 构建下现在自然是「快进速度 [快]」，此前出「快进速度 [速い]」。
- 未做（用户未选）：ZH bundle 的 `zh-Hans.lproj`／`CFBundleLocalizations`／`AppleLanguages` 声明——即 macOS 系统设置 > 语言与地区 > 应用程序 里本 App 仍不可单独选简体中文，AppKit 自带 chrome（服务菜单、标准关于面板、右键菜单）仍跟随系统语言（当前系统首选 en-US）。若后续要，这是一步 Info.plist 改动。

### 45.2 产物目录

- `package.sh` 增 `OUT_DIR`：`jp`/legacy → `build/`（不变），`zh` → **`build_chs/`**；app、DMG、`dmg_stage` 全部随 `OUT_DIR`。`.gitignore` 增 `build_chs/`（`release_zh/` 条目保留为历史留档）。
- `release_zh/` 已删除（用户判作废），中文版唯一产物＝`build_chs/Shizuku_Restored_ZH_Ver.0.1.{app,dmg}`。

### 45.3 验收

- 新 shot token `menu`（不落 PNG，写 `/tmp/shizuku_shots/menu_dump.txt`）递归 dump `NSApp.mainMenu` 标题——菜单栏是 AppKit chrome、不在 73 帧截图面内，这是唯一可无头目检的路子。双语言 dump 归档 `build/zh_wp13/menu_dump_{zh,jp,zh_bundle}.txt`：ZH 全中文、JP 与改动前逐字一致。
- 包内二进制复跑 `menu` 确认走 bundle（App 菜单显示 `Shizuku_Restored_ZH`）。
- 测试 **116/116**；JP 全 spec 73 帧对基线 MANIFEST 再跑仍 **69/73**，失败帧＝§44.6 同一批 4 张动态数据帧（3 张 save_03 选单帧＋`gallery_locked` 缩略图格），渲染面零变化。
- 双包重打：`build_chs/`（ZH，含点阵字库三件套）＋`build/`（JP，`gamedata` 内 `zh_text/cnfont/cn_code` 命中数＝0，零中文污染判据继续成立）。ZH 应用已从新目录重启。
