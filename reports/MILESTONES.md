# Shizuku_Restored — 《雫～しずく～》macOS 原生移植 项目敏捷小里程碑 (MILESTONES.md)

> 🌐 **Language / 多语言**: [🇨🇳 简体中文](MILESTONES.md) ｜ [🇺🇸 English](MILESTONES-en.md) ｜ [🇯🇵 日本語](MILESTONES-jp.md)


> 最后更新：2026-09-26（**WP-13 macOS 菜单栏中文化＋中文版产物目录 ✅（HANDOVER §45）**：整条 AppKit 菜单栏（アプリ/ゲーム/設定/表示 四顶级菜单＋全部子项＋App 菜单的 关于/隐藏/退出）按构建语言分流——ZH 构建纯中文、JP 构建「日文（中文注）」逐字不变；早送り三档加 `zhLabel`（慢/标准/快），连带修好 toast「快进速度 [速い]」→「[快]」；**中文版唯一产物目录改为 `build_chs/`**（`package.sh zh` 的 `OUT_DIR`，app＋DMG；`release_zh/` 作废删除，jp/legacy 仍走 `build/`）；新增无头量具 `SHIZUKU_SHOT=menu`（递归 dump 菜单栏标题，菜单栏不在 73 帧截图面内）；116/116、JP 全 spec 仍 69/73（同 4 张动态数据帧）。上一轮：**WP-11/12 汉化点阵字库全量接入＋两缺陷 ✅（HANDOVER §44）**：全中文面（正文/选择支/标题·ESC·确认菜单/选槽含预览带/toast/回想/音乐房/结局列表）改走原版汉化 4726 槽 24×24 点阵字库（`CnDotFont`＋`drawCNMatrixText` 三遍叠印），▶/▼ 直接画原版叶码 102/103；①「极个别句子出现日文假名」＝`cn_code2char.json` 符号/假名区在 GB2312-only 候选池上从 1869 起整体错位，逐格目检重建 1854..1912（改 39 码→225 条译文），残留 12 条假名核对为刻意保留；②「连点很多下 Enter」＝987 个「JP 有字码、CN 切片空」静默拍（2771/3755 条消息，最长 59 连击），`Engine.skipCNEmptyBeats()` 仅 CN 路径自动跨过；附带 toast「（しおり 3）」→「（书签 3）」。116/116、JP 全 spec 69/73（4 张失败帧逐张证为动态存档/CG 解锁数据，文字行零变化）、`release_zh/` 重打包并以包内二进制复验。上一轮：WP-10 停顿点句尾吸附 ✅（HANDOVER §43）：用户复验 §42 报「多次 Enter 的长页停顿点卡半句中」→ `sliceChinese` 切点由纯比例改为**就近吸附 CN 句读边界**（。．！？…」』等，命令段/余数规则不变）；全语料 3834 条扫描零违例、115/115、JP 73 帧仍 70/73、2:4 长页（163 字 5 拍）逐拍帧收于「。」、`release_zh/` 重打包重启。上一轮：WP-9 实机三修（§42）：中文正文推进重做＝译文按 JP 拍比例切片、逐字显影＋手动按拍推进（弟切草式）、JP 同内容页零泄漏；结局列表/画廊/音乐房/toast/退出对话框/窗口标题全中文；113/113、JP 73 帧双轮 70/73 逐字节、双 DMG 重打＋`release_zh/` 换装，`a35d3cc`+`bd7e9bf`）。上一轮：2026-09-25（**WP-7b 收口 ✅（HANDOVER §41）**：选择支选项/SELECT 提示语/回想屏中文化（`3d23044`+`6021db5`，JP choice/history 帧逐字节不变，双 DMG 重打）；同日 **M5.1 语料收官 ✅＋M5.5 双 DMG 产出 ✅：可用中文版达成**（HANDOVER §40，111/111）：WP-4 脱壳＝199 条 CN 记录全量落盘 `bfcfbc9`＋CN 4726 槽字库 dump；WP-5 字表还原＝模糊平移 NCC＋jieba 字频先验＋GB2312 候选池单调 DP，**2868/2868 全映射、34/34 锚点逐字复现、0 序违例**，JP 原文（sizfont.tbl）交叉验证瑠璃子/雫/祐介等，15 处定点修正，导出 **3834 条 `(scn,msg)→中文`**（JP 4044 条的 94.8%，缺口全部定性）`0009336`，安装 `6d4312e`；WP-8 终验＝6 存档点双向互读（ZH↔JP 同档同状态出帧）、ZH 外壳五帧目检、JP 全 spec 70/73 逐字节一致（3 帧差异限预览带＝save_03 已知环境项）、`package.sh jp|zh` 双 DMG 产出＋ZH 卷挂载冒烟出中文帧。上一轮：2026-09-24 **M5.6 双版本架构＋存档通用 ✅**（HANDOVER §39）：WP-1 存档-语言解耦 `d063216`／WP-2 语言=构建期常量 `0152011`（BuildLanguage：env>Info.plist>.jp，删运行时切换）／WP-3 双 bundle `ba13659`（`package.sh [jp|zh]`→`Shizuku_Restored_{JP,ZH}`，JP 版不打包语料）／WP-7a 外壳中文化 `1ddae5f`（ShellText/MenuRow 分流，JP 逐像素不变、ZH 五帧目检）；JP 五帧与 `build/jp_baseline_preWP2_d063216/` 逐字节一致。再上一轮：M4.11e 实机五项修复 ✅（HANDOVER §35，74/74，Ver.1.0）：①**staff roll 可点击跳过**——纠正 §31.6「快进也跳不过」的误判，真机制是 `LvnsScript.c:29-40` 的 CLICK_JUMP 回绕（select→扫到下一 `LVNS_SCRIPT_CLICK_JUMP`），点击在下一拍边界切到片尾 `CLEAR`；②**OP/jingle 节奏**——`LvnsAnim.c` 每帧 `wait_time+1` 翻转 ⇒ OP `time=50`＝4 翻转/帧（非 3），jingle `TIMER_WAIT 6000` 进入拍时一次性捕获 6 s；③★**开场螺旋转场几何**★——`guruguruOrder` 上一轮错按 `#ifdef USE_MGL`（8px、`y=HEIGHT/16`）跑，`y<0` 时 `x` 才到 ~26/40 ⇒ 右 1/3 落到行优先兜底＝"从上往下"症状；改回原版 `#ifndef USE_MGL`（`BSIZE 16`、起点 `x=27,y=HEIGHT/32=12`）螺旋满屏，测试＋`SHIZUKU_SHOT=spiral` 双锁；④**结局选单「佐織」→「沙織」**——`sizfont.tbl` 里 `紗` 根本不存在（`佐`1802/`沙`556/`織`722 有），exe MusicRoom 表亦为「沙織」，点阵字库为唯一裁判；⑤**表示菜单转场项语义反了**——标签「省く」应＝勾上关转场，原 `state=effectsEnabled?.on:.off` 恰好相反，改 `?.off:.on`，默认 `effectsEnabled=true` 不变＝默认有转场。基线 71→**74/74**）
>
> 上一轮：M4.11b1 `0x01` 过场子类型四式 ✅（`ad7a111`，HANDOVER §34）：正弦背景扭曲（sintable[361] 逐字、±160px、每翻转 state+=8、剪切先于 mergeCharacter ⇒ 文字永不失真）／kind2 淡入照常让位／kind3 阻塞式 `LvnsAnimation(sizuku01=38条目/62翻转, sizuku02=19/19 收 MAX_S37)`／kind4 素消息；全语料频次 kind1×10・2×2・3×6・4×5。★顺带根除「SCN051 引擎卡死」＝P0xx.WAV 单声道 11025Hz 裸 `scheduleBuffer` raise NSException 被 AppKit 事件循环**静默吞掉**、整条解释器栈被掀——真·产品级崩溃★，`convertedBuffer`(AVAudioConverter) 修复＋真 P017.WAV 回归锁。基线 62→**71/71**，`SHIZUKU_SHOT=sub` 六帧逐张目检）

本文档将项目拆解为细粒度、低风险、敏捷可验证的小里程碑（Milestones）。每个小里程碑应在 1~2 个 commit 内完成并具备自动化或视觉验证指标。

## 状态总览 (Status Snapshot)

| 阶段 | 范围 | 状态 | 交付 |
|---|---|---|---|
| 一 排版 | 日文字库/文本管线 | ✅ 完成 | — |
| 二 音频 | BGM/SFX 子系统 | ✅ 完成 | — |
| 三 引擎 | 虚拟机/存读档/13 结局 | ✅ 完成 | — |
| 四 App | GUI/启动序列/ESC/しおり/实机九项修复/演出保真/实机四项修复 | ✅ 完成 | **M1 原生日文版** |
| 五 双语 | 脱壳取语料 + 双语交付 | ✅ 可用中文版达成（M5.1/M5.2/M5.6 全绿；M2 发布待全结局回归） | **M2 双语版**（双 DMG 已产出） |

**关键路径**：`M5.1 脱壳取全量中文语料` ✅ →（`M5.2` 灌入即生效 ✅ / `M5.3` 点阵字库 ✅ WP-11 / `M5.4` UI 中文化 🔶外壳完成）→ `M5.5` M2 发布 🔶双 DMG 已产出。
**已完成**：M1.1–M4.10 全 ✅（含 M4.9 九项清单 `a2fa5d7`…`bd5cb48`、M4.10 演出保真度 14 项 `b0e1e13`+`eab3fda`、M4.10b 实机四项修复 `ec19c91`）；M4.10c 字库管线与全点阵 UI（HANDOVER §26/§27，`9151891`+`c8f76c2`）；**M4.11a 实机五项清单：全屏回想 mode／快进菜单化／十字键无效／双等待光标／CG 转场 13 效（HANDOVER §28，`c8f76c2`）**；**M4.11a2 实机六项修复＋主菜单回想モード CG 画廊（HANDOVER §29，41/41，未提交）**；**M4.11c 实机六项清单＋★原版音楽モード反汇编取证落地★＋二次 debug 复核（HANDOVER §30/§30.8，51/51，未提交）**；**M4.11d 实机九项第二轮：`bgmap()`/`palmap()`／空白 ▼ 页／快进三档／音楽モード音乐盒淡入／转场量化／★通关 staff roll 14 卡全还原★（HANDOVER §31，58/58，Ver.0.6，未提交）**；**M4.11b1 `0x01` 过场子类型四式＋★P017 单声道 WAV NSException 静默击杀修复★（HANDOVER §34，`ad7a111`，71/71）**；**M4.11e 实机五项修复：staff roll 可点击跳（CLICK_JUMP 回绕）／OP·jingle 节奏（4 翻转/帧＋6s hold）／★螺旋转场几何满屏★／沙織正字（sizfont 无紗）／转场开关语义（HANDOVER §35，74/74，Ver.1.0）**；M5.2 双语热挂载框架 ✅（`b0ccd34`）；**M5.6 双版本架构＋存档通用（WP-1/2/3/7a，HANDOVER §39，111/111，JP 帧字节级零回归）** ✅；**M5.1/M5.2 语料收官（WP-4/5，HANDOVER §40：199 记录全解＋NCC+字频单调 DP 字表 2868/2868＋3834 条 zh_text 安装 `6d4312e`）** ✅；**M5.5 双 DMG 产出＋WP-8 互读终验（同一批档 ZH↔JP 双向出帧、ZH 外壳五帧目检、JP 70/73 逐字节一致，HANDOVER §40）** ✅。
**待办**：M5.5 剩余（中/日两模式全 13 结局路径实机回归＋M2 正式发布）、~~M5.4 尾巴~~ ✅ 全清（WP-7b §41＋WP-9 §42）、~~ZH 窗口标题/结局列表/画廊/音乐房文案~~ ✅（§42.2）、语料尾差 7 处分段不一致（HANDOVER §40.4）；M4.11b 只剩其它固定效果号（`0x66` 与事件同表，随全量脚本回归补齐，HANDOVER §34.7）；`0x01` 四式的**观感**与「带音效消息是否仍杀进程」待实机确认；回想モード画廊的棕褐色调口径待定（HANDOVER §29.7，原版只留 `ChangeLog.mglvns:22` 一句意图、无代码）；九项清单里**项1 的两个真因（闪烁相位原点＋App Nap）已在 M4.11d2 落地，待用户在 Ver.0.7 上确认观感**（若仍偏慢，让他读一次 `PERF total:` 真机翻转率，见 §32.5）；**项3（CG→背景残留）与项4（推进突然卡住）已用离线测量逐条排除引擎／ticker／skip 三种成因，只剩「等他实机指认坐标」＋「给 release 加翻转心跳看门狗」两条路**（HANDOVER §31.7、§32.5、**§33**，基线 **60/60**）；音楽モード与 staff roll 的音频/时长只能实机验收，**待实听**。

---

## 一、Git 工作流与提交规范 (Git Workflow)

1. **主干分支**：`main`
   - 保持随时可编译、可运行、测试通过。
2. **提交信息规范 (Conventional Commits)**：
   - `feat(font): ...`：功能实现（字库、排版、音频、虚拟机等）
   - `fix(engine): ...`：修复虚拟机或渲染 bug
   - `test(core): ...`：测试用例添加或更新
   - `docs(handover): ...`：文档与交接记录更新
   - `refactor(render): ...`：代码结构重构
3. **闭环原则**：每个小里程碑完成后必须附带对应的验证手段（测试通过 / CLI 导出截屏目检 / App 实机运行），确认无误后立即执行 git commit。

---

## 二、小里程碑列表与执行状态 (Milestone Checklist)

### 阶段一：日文原版文本与字库管线闭环 (Stage 1: Typography)
- [x] **M1.1: 原版日文字库加载与 1-based 槽位校准**
  - 加载原版 `KNJ_ALL.KNJ`（133,344B），兼容 `cn_KNJ_ALL.KNJ` 回退。
  - 修正日文直连映射：`leaf == 0` 为空格，`leaf > 0` 映射到 `slot = leaf - 1`。
  - 验证：CLI 导出 SCN001 消息，目检首句日文（*“細いシャープペンの芯をかちーっと伸ばし...”*）连贯正确。
- [x] **M1.2: 文本排版完善与内嵌控制符初步支持**
  - 修复 `LZS.decodeInv` 初始滑动窗口索引（`0xFEE`），精准解压全部原版 SCN 消息与事件段。
  - 支持换行（`r`）、等待按键（`k/K`）、翻页（`p`）控制符与多字节内嵌命令。
  - 调优 640x400 下文字框半透明毛玻璃底板、行高（28px）、字间距（24px 等宽网格），确保每行 25 字无溢出。
  - 验证：SCN001 前 11 条消息连续推进，排版整齐并平滑 JUMP 至 SCN002。

---

### 阶段二：原生音频子系统集成 (Stage 2: Audio)
- [x] **M2.1: AVAudioEngine 基础架构搭建**
  - 在 `ShizukuEngine` 中创建 `AudioController`。
  - 从 LAC 格式 PAK（`bgmfile.PAK` 与 `soundds.PAK`）解包全部 25 首 OGG BGM 与 13 首 WAV SFX。
  - 验证：`AudioControllerTests` 自动化测试通过，支持播放 Ogg/WAV。
- [x] **M2.2: BGM 脚本指令绑定与无缝循环**
  - 响应事件 `0x6e [bgm_no]` 以及 `0x7d [end_bgm]`，接入 `AudioController.playBGM`。
  - 实现基于 `AVAudioPCMBuffer` 与 `.loops` 的无缝循环与跨场景延续。
  - 验证：SCN001 启动首个事件自动触发 Track 2 循环播放。
- [x] **M2.3: SFX 音效接入与混音**
  - 在 `AudioController` 中实现独立 `sfxPlayer` 声道，支持 `playSFX(name:)` 实时混音。
  - 支持 `P001.WAV` 等全部 13 首音效解析与快速响应。
  - 验证：单元测试与音频解包覆盖率 100%。

---

### 阶段三：虚拟机核心与游戏闭环 (Stage 3: Engine & Logic)
- [x] **M3.1: 虚拟机核心 Opcode 完备化 (对齐 Akkera Ex.22)**
  - 补全 `0x01`（特效暗化/显示文字）、`0x04`（JUMP 跨脚本跳转）、`0x3d/0x3e`（条件判断字节跳转）、`0x47/0x48`（Flag 加减）。
  - 验证：SCN001 到 SCN002 自动跨脚本 JUMP 成功。
- [x] **M3.2: 选择支 (0x05 SELECT) 跳转校准**
  - 正确解析不定长选项文本与指令末端相对字节跳转偏移。
  - 验证：SCN001 中的首个分支选择，点击后正确跳转到对应分支 Block。
- [x] **M3.3: 原生持久化存读档系统 (Save/Load)**
  - 实现基于 JSON 的存档管理器（SaveManager），保存 SCN、Block、PC、Flag 数组、当前 BG、立绘、BGM、对话分页。
  - 支持普通槽位（1..99）、快速存档（0）、自动存档（-1）与系统数据（system.json）。
  - 验证：`SaveLoadTests` 覆盖中途保存、全新引擎实例读取恢复与现场继续步进。
- [x] **M3.4: 全 13 个结局逻辑判定与通关记录 (0x7e)**
  - 接入 Ex.22 记载与 SCN 字节抽样验证的 13 个结局编号（0x00~0x0c）与 `ShizukuEnding` 枚举。
  - 实现 `0x7e` 触发、全局系统通关标记、Flag `0x46`（瑠璃子 HAPPY）跨周目继承与 Flag 0 状态演变。
  - 验证：自动化单元测试实机跑通 SCN095 触发 Ending 9 并验证新周目继承。

---

### 阶段四：macOS 原生交互打磨与日文版正式发布 (Stage 4: App & M1 Release)
- [x] **M4.1: 原生 GUI 窗口与交互体验 (ShizukuApp)**
  - 键盘（Space/Enter/上下键/数字键1..9）与鼠标推进对话、选择选项。
  - 完整保持 640x400 原生等比拉伸与全屏无缝切换（Cmd-Ctrl-F、窗口全屏按钮）。
  - 支持快捷键：S / F5 快速存档，L / F9 快速读档。
- [x] **M4.2: 标题主菜单与 Backlog 历史对话回放**
  - 原生标题主菜单（はじめから、つづきから、エンディング一覧、終了）与开场 MUS00.OGG。
  - 滚轮向上 / Left Arrow / B 呼出半透明 Backlog 历史对话面板，使用原版 24x24 点阵字形复现历史文本；支持 Tab / Z 键快速快进 (Skip)。
  - 全 13 个结局图鉴列表与通关星标实时查看。
- [x] **M4.3: 日文原版全通回归测试与 M1 打包发布**
  - 完善 `package.sh`，打包完整独立、自签名 `build/Shizuku.app`（内置 397 个全量资产，包含 25 首 OGG BGM 与 13 首 WAV SFX）及 `build/Shizuku.dmg`。
  - 自动化 21 项全测试回归 100% 通过，实机截屏目检排版。
  - **交付里程碑 M1**：《雫～しずく～》macOS 原生日文版发布完成！
- [x] **M4.4: SCN 剧本行内指令引擎（全 64 立绘 / 56 背景CG / 24 BGM 驱动）**
  - [x] 在 `Scn.swift` 中解析 `C`, `B`, `S`, `D`, `A`, `V`, `H`, `M`, `P`, `Q`, `F` 内嵌指令（commit `b449e76`；截断修复后准确统计：C 671 / B·E 335 / V+H 120 / A 78 / BGM 类 752 / SFX 类 428 / D 208 / F 223 / Q 129 / X·s 216，见 HANDOVER §21.2）。
  - [x] 在 `Engine.swift` 中接入立绘、CG、BGM 与音效实时响应（commit `6ff45f4`：分段推进状态机、`k` 追加/`p` 清屏、`Mn` 排队切曲、立绘 l0/c160/r320 y=0、SELECT 自动存档点）。
  - [x] **收尾**：eventOps 补 13 个 skip 类 opcode + `parseBlock` 块边界截断（434/790 块无 END 防越界），CLI 抽查通过，commit `7e5c0fd`（HANDOVER §21.2-2）。
- [x] **M4.5: 弟切草式 Sound Novel 全屏文字滚动排版**
  - 废除底部小框，640×400 全屏 25列×13行（起点 (20,18)、列 24px、行 28px，`LvnsInfo.h` 原值）；背景暗化按原版调色板亮度缩放 **`latitude_dark=11/16`（≈31%，非 §20 误记的 35%）**；1px 纯黑硬阴影 + (240,240,240) 白字；▼ 光标跟随末行文字末尾。
  - 验证：导出帧目检 SCN001 msg0 两行排版/阴影/光标正确、SCN007 立绘落槽（commit `95173de`）。
- [x] **M4.6: Leaf Jingle、完整 OP 开场动画与原版 TITLE 双层标题重构**（时序数据已全部采集，见 HANDOVER §21.4-1）
  - 启动阶段：`LEAF.LFG` 于 (80,144) 淡入 + 5.5s `MUS00.OGG` 开屏音效（单次，`sizuku_jingle.c` 时序：起播→淡入→等待→滑动特效→6000 计时后等点击）。
  - 开场动画阶段：**OP 曲 = `MUS14.OGG`（78.2s，官方 OST「オープニング」指纹比对锁定；§20 误记的 MUS16 实为ハッピーエンド曲）** + `OP_S00`~`OP_S16`（**17 帧**，time=50、x=160）+ `OP_V0`/`OP_V1` 各停 2s + `ruriko[]` **40 帧**序列（前 24 帧 L0/L1/L2/L1 眨眼循环、后 16 帧 L3~L8 往返，time=50、x=0），支持按键跳过。
  - 标题画面阶段：`TITLE0.LFG` 底板 + `TITLE.LFG` 叠加，原版 24×24 点阵字形菜单。
  - 验证：`SHIZUKU_SHOT=boot` 导出 19 个阶段帧目检——LEAF 社标白窗/边缘滑入、`OP_S` 紫色滴泪书法、`OP_V0`（眼镜少女持录像带）/`OP_V1`（红发少女）/`ruriko`（蓝发侧脸闭眼）落位、TITLE0 淡入 + TITLE 红「雫」FadeMask 均正确；1 tick=1/60s 由 60Hz 定时器驱动，点击快进（commit `9d781cd`）。
- [x] **M4.7: ESC 游戏内系统菜单与可视化「しおり (存档/读档)」系统**（用户已拍板：6 格しおり + 沿用 JSON SaveManager）
  - 按 `ESC` / 鼠标右键呼出原版六项菜单，**正确顺序**（`sizuku_menu.c:75-83` MENULINE 行 3-8）：`文字を消す、ロードする、セーブする、シナリオ回想、一つ前の選択肢に戻る、ゲーム終了`（先读后存；「一つ前に…」用 `lastSelectSavePoint`，不占しおり槽）。
  - 可视化「しおり」**6 槽**卡片式存读档管理与覆盖确认对话框（架于 JSON 层之上，展示槽号/时间/剧本位置/首句预览）。
  - 菜单以 `latitude_dark=11/16` 暗化 + 点阵居中文本行还原原版观感；确认子菜单「はい/いいえ」附原生 `(1)/(2)` 提示。
  - 验证：`SHIZUKU_SHOT=esc,slotload,slotsave,confirm` 目检六项顺序/选中反白、しおり 6 格「（から）」空槽、はい/いいえ 确认均正确；修正 `drawMenuLine` 返回值缩放/原生坐标混用致徽标压字（commit `9d781cd`）。
- [x] **M4.8: 阶段四改动后的全量回归与 DMG 重新打包**
  - `swift test` 21/21 通过；`./package.sh` 生成 `build/Shizuku.dmg`（51M，bundle 内含 397 gamedata 文件）；挂载后从卷内直接运行 app 重导 boot/title/game/esc 帧目检一致。
- [x] **M4.9: 用户实机九项清单全量修复（交互/菜单/设置/BGM 曲号/结局解锁选择肢）**（详见 HANDOVER §23）
  - [x] 交互层（`a2fa5d7`）：按住 Enter 跳选择肢→`isARepeat` 守卫；选项/标题/ESC/しおり/确认鼠标 hover；标题 ESC 不再直退；「つづきから」载入时间戳最新槽位；删违和 branding 死代码。
  - [x] 已读记忆+快进设置（`922d1e1`）：`seenHighWater[scn]` 高水位对齐原版 `seen_flag[]`/`SizukuSetTextScenarioState`；未读拒绝 skip、skip 遇未读/SELECT 自动停；macOS 菜单栏设置（既読自動略し/未読スキップ/skip 热键可配置/言語）持久化进 `system.json`；ESC 恢复原版六项、语言按钮移入菜单栏。
  - [x] BGM 语义（`653e474`+`bd5cb48`）：曲号 0=静音；`Mn` 排队到图像刷新起播；**`bgmmap` 脚本号→MUS 文件全量还原**（全剧本 286 处引用 87 处曾放错曲）；`Mw`=0.5s 淡出阻塞等待不停曲；`Mf/Ms` 不清排队曲；读档恢复统一走映射；`SHIZUKU_DUMP_BGM` 审计口。
  - [x] 结局解锁选择肢（`4e4d5ce`+`bd5cb48`）：实证 0x46→SCN001 三选项解锁链（含负对照+跨周目继承）；补 flag 1（雑シナリオ）持久化，对齐 `SizukuScenarioInit` 仅清 2-6/9-13 语义。
  - 验证：`swift test` 24/24 绿（含 bgmmap 映射表/flag1 持久化 3 项新测试）；`SHIZUKU_SHOT=boot,title,game,esc` 目检无回归、ESC 恰为原版六项。
- [x] **M4.10: 原版演出保真度提升（深度逆向审视 → 14 项差距全量落地，详见 HANDOVER §24）**
  - [x] 文字层：`'s'`=char_wait_time v/60s 每字符（越大越慢、换行复位、默认 1 flip）；`'X'` 偏移折半；▼ 光标仅本段走完后出现且 6-flip 周期闪烁（`b0e1e13`）。
  - [x] 瞬态演出：`'F'` 白闪改 16+16 flip 渐变、`'Q'` Vibrato 16 flip 随机 ±16px 只抖画面层——均为 ticker 递减的引擎计数器，替代原粘滞布尔/未渲染死代码。
  - [x] 图像语义：`0x14` 全清画面+文本层；`0x22` 单槽替换；`0x24` 强制居中槽并删除自创 frontPortrait 通道；`'D'` 先清全部槽再装载。
  - [x] 选择肢：`0x05` 提示语先经解析器画上屏且选择期间保持可见；选择框加宽 560 去重复编号；游戏内 ticker 常驻与原版 flip 主循环同构。
  - [x] `'p'` 存档点：消息末捕获 `lastPageSavePoint`，ESC「一つ前の選択肢に戻る」回退链对齐原版 `selectpoint=savepoint` 播种（`eab3fda`）。
  - 验证：`swift test` 27/27 绿（新增速度映射/SELECT 提示/瞬态效果 3 项，全 197 SCN 实扫驱动）；`SHIZUKU_SHOT=game,choice,esc,title` 目检——choice 帧提示语+三选项完整无溢出、ESC 恰六项、▼ 正确落位。
- [x] **M4.10b: 用户实机四项修复（ESC菜单守卫/标题读档列表/选择肢暗色化/BGM无声根因，详见 HANDOVER §25）**（`ec19c91`）
  - [x] `openEscMenu` 加 `.inGame` 守卫 + 菜单栏 `validateMenuItem` 灰置游戏内专属项（修复标题页进系统菜单落入陈旧引擎状态，观感"误入早期存档"）。
  - [x] つづきから 弹出 8 行读档列表（オート/クイック/しおり1-6），标题底图渲染、`pickerSlots`/`confirmCancelMode` 回退链修正；`MenuStrings` 补点阵码（sizfont.txt 实为 Shift_JIS 索引）。
  - [x] 选择肢白色底板重做暗色半透明面板；补 `dotMatrix` '>' 字形（选中光标此前从未渲染）。
  - [x] BGM 无声两真因：`fadeOutBGM` Timer 竞态杀死新曲（`cancelFade` 对齐 `LvnsStartMusic*` 清 fade_mode）；`0x38` 漏刷排队曲（原版 `LvnsDisp` 必调 `StartNextMusic`）。
  - 验证：`swift test` 27/27 绿；`SHIZUKU_SHOT=choice,slotload,slotsave,confirm,continuelist` 全画目检通过。
- [x] **M4.11a: 用户实机五项清单（全屏回想 mode／快进菜单化／十字键无效／双等待光标／CG 转场，详见 HANDOVER §28）**（`c8f76c2`，与 §27 全点阵 UI 同笔提交）
  - [x] **全屏 シナリオ回想 mode**：`HistoryView.swift` 新档 + `GameMode.history`，逐条对齐 `LvnsHistory.c`（第二文字 vram／`pos` 从最新起／最旧不越界／最新按「下」即退出／Esc-右键取消）与 `SizukuDispHistory`（`CUR_X=25` 的 ▲▼ 文字格命中、attr≠0 走 `SIZUKU_COL_GRAY`、`history_mode=True` 跳过全部 14 处等待与演出）。**删除非原版**的半透明 `drawBacklogOverlay`/`GameMode.backlog`/`UIText.backlog*`。
  - [x] **快进＝窗口菜单单独命令**：「選択肢まで早送り」→ `toggleFastForward`（对齐 `LvnsSkipTillSelect` 的 `seen` 守卫与 `force_skip`）；`if event.isARepeat { return }` → 长按 Enter 完全无效，单按才推进。
  - [x] **十字键游戏内无功能**：`case 123,124,125,126: return`；↑↓ 仅在回想内充当 `cursor_up/down`。
  - [x] **两种闪烁等待光标**：`'k'`→leaf 102 实心右向 ▶、`'p'`（页尾）→leaf 103 纸张图标，`(flipCount/6)%2` 与原 `flip_cnt % 6` 同周期，落在当前文字格。
  - [x] **CG 转场 13 效全表**：`LvnsEffect.swift`（含 `LvnsEffectTiming.frames`）+ `TransitionRenderer` + `engine.transition` 阻塞解释器；几何源自 `LvnsEffect.c`/`lvnsimage_sximage.c`。
  - 验证：`swift test` **37/37** 绿（`SaveLoadTests` 覆盖层用例改为断言回想页 ▲ 贴 640px 右缘）；`SHIZUKU_SHOT=history,waitkey,waitpage,trans` + `SHIZUKU_DUMP_TRANSITIONS=1` 共 **17 张帧逐张目检**（13 效 4 联帧方向全对、`trans_05`/`trans_12` 同为 FADE_MASK 故 md5 相同）。
- [x] **M4.11a2: 用户实机六项修复（快进真正生效／转场适配大窗／主菜单回想モード CG 画廊／开机 CLICK_JUMP／菜单隔空命中／菜单栏命名，详见 HANDOVER §29）**（未提交）
  - [x] **快进「无效」根因不在快进**：§28 的状态机正确，但 `seen_flag[205]` 被我们存进了**书签**而非**系统文件**（原版 `sizuku_file.c:70,129`），且读档 `=` 覆盖、`reset()` 清空 → `isCurrentMessageSeen` 永假、守卫永远拒绝进入。现 `GlobalSystemData.seenHighWater` + `persistSeenHighWater`（App 侧 2 秒节流）+ `restoreSaveState` 取 `max` + `reset` 不清；点击与非-skip 按键按 `LvnsSelect`/`LvnsCancel` 语义清 `skip`。
  - [x] **转场按窗口尺寸适配**：mask 几何在逻辑 640×400 上算，按 `factor = width/640` 先 `shrink` 后 `grow`（层本身是整数倍放大，故无损），大窗下块尺寸恢复成画布的 1/20。
  - [x] **主菜单「回想モード」CG 画廊（新设计项，原版 `sizuku_op.c:182-191` 整块 `#if 0`、mglvns 无任何实现可逆向）**：`GameData.eventImages()` 索引 90 张／8 页；`GalleryView.swift` 4×3 网格（150×94、fit＋黑边、盒均值降采样保抖动）；解锁口径＝`seenHighWater[scn]>0`，未解锁黑底「？」；点选放大＋16 tick 溶解；↑↓ 跨页、←→ 换页、Esc 回标题。标题菜单 3→5 项，行号与角标全部由表推导。
  - [x] **开机一次点击直落主菜单**：`skipBoot()` 原把 jingle 与 OP 列同一分支；改为 jingle→`.jingleOut`、OP→`.titleIn`，逐字对应 `LvnsScript.c:29-40` 的「回卷到下一个 CLICK_JUMP 标记＝只跳当前段」。
  - [x] **鼠标隔空命中**：删全宽 `titleMenuRows()`，新增 `SceneComposer.menuLineRect(leaves:line:)` 并让 `drawMenuLine` 自己用它算 `xStart`（几何与像素同源）；`menuRowFromPoint` 统一标题/ESC/确认三处，**命中不到即不响应**。
  - [x] **菜单栏显示 `NSMenuItem`**：顶层 item 与 `NSMenu` 未给 title，AppKit 印类名占位；现给 `ShizukuApp.name` 与「ゲーム」。
  - 验证：`swift test` **41/41** 绿（新增 `GalleryTests` 4 例，共享 static fixture 使全套从 49 秒降到 8.3 秒）；画廊 5 帧（`gallery_locked/open/vis/zoom/fade`）、`title.png`、1280×800 转场联帧、`BOOTCLICK` 19 行逐一目检/核对；菜单栏用 System Events 实读三个菜单，无 `NSMenuItem` 残留。`package.sh` → `.app`+`.dmg` exit=0（首轮 `hdiutil Resource busy` 系旧实例占用，非脚本缺陷）。
  - 注：本节推翻 §28.2 的一个隐含假设 —— 该节声称快进已对齐 `seen` 守卫，但因 `seen` 本身没落盘而不成立；以 §29.1 为准。
- [x] **M4.11c: 用户实机六项清单（HANDOVER §30，全部落地）**
  - [x] **macOS 菜单栏按意图重排**：`ゲーム`（流程＋存档＋音楽モード）／`設定`（文本推进＋跳过按键）／`表示`（全屏＋转场特效＋语言）三个顶层菜单；每项带中文注释、快捷键全部交给 AppKit 打印。
  - [x] **画廊只收绘画 CG**：分类唯一依据是"哪条指令装进哪个槽"——`'B'/'E'/'S'`/事件 `0x0a` 写 `MAX_S`＝背景板，`'V'`→VIS、`'H'`/事件 `0x16`→HVS 才是插画。**用户否决"按复用次数判定"**（CG 会因分支被多次复用）。索引 90 张／8 页 → **61 张／6 页**。
  - [x] ★**原版「音楽モード」取证并落地（净新增逆向成果）**★：**推翻 §29「音乐播放器不存在」的结论** —— mglvns 是 Linux 移植没实现它，但 `Sizuku.exe` 有完整实现，入口是标题菜单**第 5 个隐形项**（指针表 VA `0x430ebc` 有 5 个指针；串 `s0 X56Y128 <空> r$`）。`X` 单位 8px、`Y` 单位 1px（由房间三按钮 `X22/X37/X49`→176/296/392 以 320 完美对称反证）→ 入口＝原生 (448,128) 即塔楼上排窗右上角，与用户描述吻合。房间 `0x408d40`：清屏→停曲→播 slot 0→画表单→**只读鼠标**三键循环（上一曲/演奏/下一曲，右键 `0xffff` 退出）；卡片 `0x408c70` 查曲名表 `0x430e28`、作曲索引 `0x430e88`→指针 `0x430cac`；24 曲名＋作曲署名用 `sizfont.tbl` 解码，与仓库 OST **22/24 一致**；slot 号＝MUS 文件号（0=リーフ、14=オープニング 两头对齐）。新增 `MusicRoom.swift`＋`.musicRoom` 模式；两处刻意偏离（悬停才显形＋`ゲーム` 菜单入口、额外接受 ESC 并画提示行）已记录。
  - [x] **转场「左一遍右另一遍」观感**：结构上两段（`LvnsClear`+`LvnsDisp`）是原版行为、非 bug；观感来自 §29.2 的半尺寸块，逻辑网格修复后整屏连贯。同时接入**参考引擎自带的 `-n e`**（`mgMain.c:76-79` → `LvnsEffect.c:741-745` 短路为整屏 blit）＝`engine.effectsEnabled`，`表示` 菜单「画面エフェクトを省く」，142→32 翻转，持久化进系统文件。
  - [x] **去掉标题「13中1」徽章**：`titleFrame()` 的 `UIText.endingsBadge` 整段删除（含覆盖率表条目），`clearedEndings` 数据本身保留（解锁判定依赖）。
  - [x] **转场期点 ESC 卡死＋之后吞页**：两症状同源（ticker 停摆使 `transition` 永挂，`advance()` 却仍改消息位置而 `run()` 一步不走）。按原版「翻转循环不轮询输入」补 `advance()` 守卫＋`openEscMenu()` 守卫；`SHIZUKU_SHOT=escfreeze` 三趟对照：`preguard` 3 次点击吃掉 seg 0→3，修复后 `(0,0)→(0,0)`。
  - 验证：`swift test` **46/46 → 二次复核后 51/51**（新增 `TransitionTests` 5 例：相位边界、142 总翻转、`-n e` 塌成 1+1+30、640×400 与 1280×800 均须扫满全屏；新增 `MusicRoomTests` 5 例：24 曲名＋3 署名＋全部固定文案字库可拼、24 槽 MUS 逐个存在、按钮几何锁 X×8 取证、入口与菜单行零重叠、最长曲名不越界）；目检 `title`／`title_music_hint`／`music_room0/15/17`／`gallery_*`／`endings`／`esc_menu`／`confirm_end`／`wait_key`／`trans_on_*`／`trans_off_*`／`escfreeze_*` 共 25+ 帧；`MUSIC entry=x=448 y=128 w=24 h=24` 与菜单行 y=232..360 无重叠。**音频播放路径未做听测**，需打包版实听。
  - [x] **二次 debug＋视觉复核（HANDOVER §30.8，Ver.0.4）**：全 token 重跑（142/32 翻转、61 张画廊、19 段开机、命中表）＋逐张看帧；**修掉一个旧 bug**——`.endingsList` 用 `titleFrame()` 打底而 overlay 只 `blendBlack(215)`，标题选中行会以 16% 亮度残影浮在结局表中间，改用 `titleBackdrop()`；`escfreeze` 探针补 `pause=`/`cursorShown=` 并加 `blinkOn()` 固定闪烁相位（否则正确的状态也会拍出「没有光标」）；`システムメニュー` 转场期改灰掉以与守卫同源；**System Events 实读菜单栏审计**抓到 `フルスクリーン（全屏）` 被 AppKit 改名成 "Enter Full Screen"（action 直指 `NSWindow.toggleFullScreen(_:)` 就会被接管标题），改走自有 selector 并用 `AXFullScreen` 做往返点击测试（false→true→false）；纠正 `GalleryView`/`MenuStrings.recallMode`/`openGallery` 三处「拿 mglvns 缺失当原版没有」的注释论据。
- [x] **M4.11d: 用户九项清单第二轮（HANDOVER §31，七项落地＋staff roll 全还原）**
  - [x] **项2 `bgmap()`/`palmap()` 移植**（`ShizukuCore/BackgroundMap.swift`，新增）：`sizuku_etc.c:206/:265/:135` 三张表照搬——23 条地点折叠、`MAX_S%02d` 命名、地点 0＝纯黑（`lvnsimage_clear`+`pal_default`）、9 档气氛调色板**只换 0…3**（所以 `41`/`42` 同图不同天气）。`PaletteOverride` 可 Codable，随存档走。附带补孤儿 `VIS21`（原版拿 02 号底板换 16 色紫顶替，非素材缺失）。**§30.7 点名的还原度缺口就此关闭。**
  - [x] **项6 只有 ▼ 的空白页**：`Engine.skipInertSegments()`——本段无字**且**前面各段也没落字才继续吞（`sizuku.c:240-242`：`'$'` 只终止串、不等待不画光标）。
  - [x] **项8 快进**：停止条件改按 `LvnsSkipTillSelect`（只在 `.awaitingChoice`/`.ended` 收手）；三档 `遅い 0.08 / 普通 0.04 / 速い 1/60` 秒每触发＝约 4.8／2.4／**1 翻转一步**，默认「普通」，持久化 `sys0.fastForwardSpeed`。
  - [x] **项5 音楽モード补完**：反汇编到用户要的效果——`0x408d45 push 0x11; call 0x405c20` ⇒ 底板是 **VIS17 音乐盒**；节拍＝先全亮挂 `introHoldFlips 18`（300 ms）→ `LvnsDarken` 把 `latitude` 16→11（5 翻转）→ 表单浮现。入口保持原版**完全隐形** 24×24（`X56×8`＝448,128），按钮 `[176,296,392]`／y300／高 24。
  - [x] **项7 转场量化**：13 效全表＋每效帧数（`LvnsEffect.swift:13-27`、`LvnsEffectTiming.frames :45-62`），一次 CG 切换＝56+56+30＝**142 翻转**，`-n e`（`effectsEnabled`）塌成 1+1+30＝**32**；根因是 mask 几何按窗口像素算（§29.2），现按逻辑 640×400 算再整数倍放大。
  - [x] ★**项9 通关 staff roll（M4.11b 的 credits 卷轴，本轮最大净新增）**★：触发＝`0x7d END_BGM` → `sizuku.c:810-826` 的**阻塞式** `SizukuEnding(lvns, eddata)`；`ScriptStep` 走 `LvnsClearLow`/`LvnsDispLow` 绕开 `skip` 快路径、`LvnsWait` 不轮询输入 ⇒ **快进天然跳不掉**，只有 `LvnsWaitClick`（select 或 cancel）收尾。14 张卡按 `eddata[]` 原序抄死（地点 `[2,44,11,12,13,15,20,22,24,26,27,31,35,5]`），节拍 `WAIT 6000`/`CLEAR`/`DISP`/`WAIT 1000`＝每卡 436 翻转、全程 **5760 翻转 ≈ 96 秒**；`tputs` 居中 `(640-格数×24)/2`、`y=row×30`、`EDSHA 0` 双黑影＋`EDCOL 4` 常量白。**目检抓到两个只有看帧才看得见的 bug**：卡号永远停在 0（`.darkening(card)` 落成 `.lightening(card ?? 0)`）与收尾淡出被抹成瞬黑（`click()` 的 `latitude` 赋值反了）——详见 HANDOVER §31.6。
  - 验证：`swift build` 零警告；`swift test` **51/51 → 58/58**（新增 `StaffRollTests` 7 例：14 卡署名全可拼、14 个地点号都能解出底板、最长署名不越 640、状态机按序走 13 卡并**空转 10 万翻转也不结束**、中途点击无效、`-n e` 一刀切、真结局块 SCN094 blk1 返回 `.waitingStaffRoll`）；`SHIZUKU_SHOT` 新增 `roll`（21 帧）＋探针 `settle FAILED` 自检；全 27 token 重跑 138 帧无崩溃；**roll 的 21 帧逐张看过**。
  - 仍待用户实机判定（未凭猜测改代码）：**项1** logo/OP/▼ 节奏（常量已按 `INTERVAL 60`/6 帧周期核过）、**项3** CG→背景残留（`beginMessage` 兜底 `flushStagedImage()` 的偏差方向与报告相反，需先复现）。打包 **Ver.0.6**。

- [x] **M4.11d2: 项1「▼ 与文字太慢」深挖——两个真因落地（HANDOVER §32，59/59，Ver.0.7）**
  - [x] **先用三条硬数据做排除，再动手**：`SHIZUKU_SHOT=perf` 单帧合成 **4.52 ms**（余量 221 fps，且 `GameData.image` 本就按名＋调色板缓存）；`perfrun` 改「总翻转 ÷ 总墙钟秒」→ **362 翻转 / 6.05 s = 59.9/s，zeroFlipFires=0，maxFlipsPerFire=1**（加负载后 `maxFlipsPerFire=3` 仍 59.9）；`char_wait_time`（`Lvns.c:45`＝1 tick、`LvnsText.c:81` 每字等待、`LvnsText.c:163` 换行重置）与我们三处逐条对齐。**结论：合成、ticker、文字常量全部正确**，若直接照观感改常量就会改错。
  - [x] **顺带修掉探针自身的假信号**：`reportPerf` 首窗曾报 `77.5/s`。`consumeElapsedFlips` 里 `anchor + flips*interval ≤ now` 是硬不变量 ⇒ 速率不可能 >60，超值是「`perfAnchor` 到第一次 fire 才置位」造成的分母伪影 ⇒ 窗口化指标一旦违背不变量，该换指标口径而不是改被测对象。
  - [x] **真因 A：闪烁相位原点错**（取证 `LvnsControl.c:117-200`＋`LvnsDisp.c:44-90`）。`LvnsDrawCursor` 是**切换**（`cursor_state` 0↔1）而非重画，且 `flip_cnt` 从进循环的 0 起算 ⇒ 原版＝到页先亮、亮 6 灭 6、周期 200 ms、**原点＝进入等待那一帧**。我们原先用全局 `flipCount/6%2`，新页可能落在「灭」的半周期（最多 6 帧无光标）。新增 `Engine.waitCursorEntryFlip`/`waitCursorVisible`＋`trackWaitCursorPhase()`（以 `(msg.index, seg)` 变化为原点，key 用 `UInt64` 拼位而非元组，因 `Optional<(Int,Int)>` 无 `!=`）。
  - [x] **真因 B：App Nap 把整进程节流到 ~1 Hz**。`Timer` 被节流后每次 fire 最多补 5 帧 ⇒ 呈现 **5 帧/秒＝1/12 速**：200 ms 光标周期拉成 1.2 s、一页 150 字要 30 s —— 与用户描述完全同形且**间歇**（焦点/遮挡/电源相关），所以离线测量全复现不出。修法：`startTicker` 持 `beginActivity([.userInitiated, .latencyCritical], reason: "60 Hz reference flip loop (Lvns INTERVAL)")`，`stopTicker` 释放。
  - [x] 验证：`swift test` 58 → **59/59**（新增 `testWaitCursorBlinksSixOnSixOffFromTheFlipTheWaitBegan`：真实读者路径停在第一页后逐帧采样 24 次，锁「亮6/灭6/亮6/灭6」与停段期间原点不漂移。踩坑：`skip=false` 时引擎停在 `.rendered`，headless 泵条件必须是 `isRevealing || transition != nil` 且先清 `bgmHoldSeconds`）；**逐张看图**：`wait_page.png`/`flip05`/`flip12` 三张 **md5 相同**（`7b6e4ed2…`）＝亮半周期逐帧稳定，`flip06`（`d2f356c9…`）＝翻页图标确实消失、无残影；`pmset -g assertions` 实读到 `pid …(ShizukuApp): PreventUserIdleSystemSleep named: "60 Hz reference flip loop (Lvns INTERVAL)"`；全 16 token 重跑 141 帧，`TRANS 142/32`、`GALLERY 61/6`、`MUSIC entry 448,128`、`ROLL cards=14 cardFlips=436` 与 §31 逐条一致。打包 **Ver.0.7**。

- [x] **M4.11d3: 项3／项4 排查轮——把「引擎卡死」证伪并补一条引擎级回归锁（HANDOVER §33，60/60，无产物改动）**
  - [x] 新增 `EngineLogicTests.testEveryClearDispPairHandsTheScreenBack`：沿真实读者路径走 scn 1..<60，每个 `LvnsClear/LvnsDisp` 对必须交还屏幕且 <400 翻转，并断言本轮真的驱动了 >100 对、其中 >0 对以 CG 为 `from` 侧（CG 通常来自上一个 scenario ⇒ 整轮共用一个 engine）。59 → **60/60**。
  - [x] **证伪「`engine.step()` 卡在 `0x54`」**：把 App 侧那条 walk 1:1 搬进无 AppKit 的 CLI 临时探针跑同一语料 → 802 次迭代、最慢一次 `step()` **0.000 s**（含 `op=0x54`）⇒ 解释器不需要时间，卡死在探针里。探针用完已删除。
  - [x] **记下三个量具自身的假信号**：① debug 构建主线程 2168/2170 采样都在 `MTKView draw → currentFrame → RGBAImage.blitScaled`（release 同一负载 4.44 ms/帧、60.0 翻转/秒）⇒ 判断"卡住"必须先换 release；② `kill -0 $(cat pid)` 轮询在子进程被回收后仍返回真 ⇒ 误把一次 69 s 正常完成的运行读成 120 s 死锁；判完成用 `wait`+退出码（另：`strings` 也不能用来判断字面量是否进了产物）；③ `SHIZUKU_SHOT=cgtobg` 走 `enterGame()` → `engine.reset(keepPersistentFlags: true)`，起点 flags 取自**用户真实存档** ⇒ 同一 token 两次跑出不同轨迹，它不是可复现量具。
  - [x] `lvns->skip` 取证（排除项7 由 skip 泄漏造成）：`LvnsDisp.c:190-225`／`LvnsClear` 只在**调度层**塌成一次 blit，`LvnsEffect.c` 全文 1059 行 **0 处** skip；`LvnsControl.c:213-214` 在「選択肢まで進む」收尾显式清 `force_skip/skip` ⇒ 我们的 `guard !skip` 与 `effectsEnabled` 替换为 `.normal` 逐条对齐，无泄漏。
  - [x] ★**净新增：翻转心跳看门狗（把量具装进产物）**★。与 ticker 独立、同跑主线程 `.common` 的 1 s 定时器，只在**引擎还持有活计**（`transition != nil || isRevealing || isFastForward`）时判 stall>2 s；一条 `~/Library/Logs/Shizuku_Restored/diagnostic.log` 记录含 `scn/blk/pc/phase`、**`shown`（当前显示图）**、**`staged`（双缓冲压着的图，为此在 `Engine` 上加只读 `stagedImageName`）**、`transition` 的 phase/state/clear/disp/from、`reveal/skip/ff/pump/ticker/wait` ＋最近 24 条 `advance()` 交接（被 `guard transition == nil` 吞掉的那次标 `advance swallowed`）。**并按原版「flip loop never stops」自愈**（`stopTicker(); startTicker()`），日志照留、坏因不被抹掉。
  - [x] **看门狗自己的验收**（`SHIZUKU_SHOT=watchdog`：走到真实 CLEAR/DISP 对 → 手动 `stopTicker()` 复刻故障 → 空转 4 s ＋ 2.5 s）：2.3 s 抓到 `transition=clearing state=0 from=MAX_S01 shown=MAX_S07 staged=nil reveal=true ticker=false`，自愈后 `transition=hold state=18 → recovered=true shownAfter=MAX_S07`、日志恰好 1 条不刷屏；**逐张看过恢复帧** `watchdog_recovered.png`＝底板完整无半清屏/黑屏、文字仍在逐字出、等待光标尚未出现（与 `reveal=true` 自洽）。`swift test` **60/60** 不变。
  - [ ] **项3／项4 转为「等一次真机日志」**：他下次卡住时不必描述，直接把 `~/Library/Logs/Shizuku_Restored/diagnostic.log` 发来；三条字段即可分诊 —— `ticker=false`＝源被谁停了（继续查调用点）／`ticker=true && pump=true`＝源活着没人泵（`consumeEventPumpRequest` 路径）／`staged != nil && shown` 是 CG＝项3 的双缓冲没被 `LvnsDisp` 冲刷（`flushStagedImage` 调用缺点）。
  - [x] 顺手记一个未触发的死循环：`Scn.swift:563-578` `parseBlock` 对截断的 `0x05 SELECT` 会 `continue` 而不推进 `i`（全语料审计没报；要修只需 `continue` 前补 `i += 1`）→ **已修＋锁终止性（`491cb22`）**。

- [x] **M4.11e: 用户实机五项修复——staff roll 可跳／OP·jingle 节奏／★螺旋转场几何★／沙織正字／转场开关语义（HANDOVER §35，71→74/74，Ver.1.0）**
  - [x] **staff roll 可点击跳过**：纠正 §31.6「快进也跳不过」误判——真机制是 `LvnsScript.c:29-40` 每次 `ScriptStep` 先跑的 CLICK_JUMP 回绕（`select` ⇒ 扫到下一 `LVNS_SCRIPT_CLICK_JUMP`）。`StaffRoll.Player` 加 `selectPending`，`click()` 非末拍置位、`finishStage()` 在拍边界改派 `closingDark`；`cancel()` 仅末拍生效（对齐 `LvnsWaitClick`）。`LvnsWait` 不轮询 ⇒ 下一拍边界才切，是原版语义。测试一拆三（中途 select 回绕／中途 cancel 忽略／末拍双出）。
  - [x] **OP/jingle 节奏**：`opAnimFlipsPerFrame = 50*60/1000+1 = 4`（`LvnsAnim.c` 每帧 `wait_time+1` 翻转，非 3）驱动 sizuku×3＋ruriko 时长与取帧；`jingleHold` 进入拍一次性捕获 `jingleHoldBudget`（凑满 `TIMER_WAIT 6000`＝6 s，不再每翻转重算致 3.6 s 早退）。
  - [x] ★**开场螺旋转场几何**★：`TransitionRenderer.guruguruOrder` 上一轮按 `#ifdef USE_MGL`（8px 网格、起点 `y=HEIGHT/16=25`）跑，`y<0` 收束时 `x` 才到 ~26/40 ⇒ 右 1/3 落到 `order.count<cols*rows` 的**行优先兜底**＝"从上往下填"症状。改回原版 `#ifndef USE_MGL`（`BSIZE 16`、`FACTOR 32`、起点 `x=27, y=HEIGHT/32=12`），螺旋在 16px 瓦片网格上扫满 40×25。双锁：`testGuruguruSpiralReachesTheRightEdgeItself`（全瓦片置换＋尾段非单调＝排除行优先）＋`SHIZUKU_SHOT=spiral` 逐张目检（`spiral_048/080/099_last` 从中心矩形螺旋扫到满屏、右缘由螺旋臂收尾）。
  - [x] **结局选单「佐織」→「沙織」**：`sizfont.tbl`（EUC-JP、entry＝leaf code）解码实测 `佐`1802／`沙`556／`織`722 有、**`紗` 不存在** ⇒ 用户字面「紗織」点阵字画不出（`FontPipelineTests:117` 结局标题走原版字库）；exe MusicRoom 名表 `0x430e28` 亦为「沙織」。定案原版角色名＝沙織，旧「佐織」是同音别字。改 `SaveManager`＋`SaveLoadTests`；MusicRoom 提取值不动。
  - [x] **表示菜单转场项语义反了**：标签「画面エフェクトを省く」＝勾上应关转场，但 `validateMenuItem` 原 `state = effectsEnabled ? .on : .off` 恰相反 ⇒ 用户看到"只有勾上才有转场"。改 `state = effectsEnabled ? .off : .on`；默认 `effectsEnabled=true`（`Engine.swift:102`／`?? true`）不变 ⇒ 默认不打勾且有转场。native 菜单不进气闸，按逻辑＋默认值核验。
  - [x] 验证：`swift test` 71 → **74/74**；打包 **Ver.1.0**（含 §34 后全部未提交改动）起窗待用户实机点头（螺旋满屏／jingle 6s／OP 4帧每画／staff roll 点击跳／沙織／转场项默认有）。

- [x] **M4.11f: 删除从未落盘的 autosave 空壳槽（HANDOVER §36，74/74 不变，`73884d3`）**
  - [x] **原版取证**：`sizuku_op.c:116-177` 的 `siori_select_menu_line`／`siori_init_menu_line` **只有 しおり１/２/３ 手动槽**，无 autosave/quicksave 概念（两者皆本移植自加）。对照：原版"回到上次位置"＝内存 savepoint（`lastSelectSavePoint`/`lastPageSavePoint`，slot -99/-98，支撑 ESC「一つ前の選択肢に戻る」），忠实可用、不落盘。
  - [x] **确认死 UI**：autosave（slot -1 → `autosave.json`）在载入选单被列出、`getSaveState(-1)` 被读取、贴「オートセーブ」标签，但**全代码无 `save(slot:-1)` 写入点** ⇒ 恒空、选中只弹「オートセーブは空です」，价值＝0。
  - [x] **删除**：载入选单收为 `[0]+1..6`（quicksave＋しおり1..6）；移除 `slotRows` 的 `case -1`、`chooseSlot` 空标签的 `オートセーブ` 分支、`MenuStrings.autoSaveLabel`（无引用）、`SaveManager.fileURL` 的 `slot<0` 分支；同步注释＋`SaveLoadTests`（去 slot -1，4→3）＋`FontPipelineTests` toast 表。quicksave 保留（有真实写入点）。
  - [x] 验证：`swift test` **74/74**；`SHIZUKU_SHOT=slotload` 目检 `slot_load.png`＝首行「クイックセーブ」、其后 しおり1..6、**已无「オートセーブ」行**。

- [x] **M4.11g: 载入/存档选单竖向排版 rebalance——整块上移 36px（HANDOVER §37，74/74 不变，`33ea7c0`）**
  - [x] **视觉研究定位**：`SHIZUKU_SHOT=slotload,slotsave,esc,title` 出图逐张看——失衡只在 slot picker 一页（ESC 菜单 `drawMenuLine` line 3..8 本就居中无此病）。量出逻辑 640×400 画布顶留白 68px（表头 y=68）、底提示 y=376 贴死 400 边（0 缝隙）。
  - [x] **方案先问用户**（§83 视觉二解先确认）：「整块上移（最稳，内部零重排）」vs「上移＋撑开行距（更填满但改命中框）」→ 用户选**最稳的整块上移**（契合"以不导致 bug 为优先"）。
  - [x] **落地＝统一 −36px**：表头 68→32、行 100→64、预览带 322..376→286..340、预览文字 328→292、提示 376→340；内部间距逐条不变。命中框 `slotPickerRowRects` 基址 98→62 与绘制基址 64 保持 `draw=base+2` 容差 ⇒ 点击不脱靶。
  - [x] 验证：`swift test` **74/74**；`slotload/slotsave` 目检＝顶留白 32、底部提示下留 ~36 呼吸、预览落暗化带内与提示相接不叠。

- [ ] **M4.11b: 剩余大型演出件（HANDOVER §24.3 取证已齐）**
  - [x] `0x01` 过场子类型：`01/02` 正弦背景扭曲+调色板淡出/淡入、`03` `LvnsAnimation(sizuku01/02)`（`sizuku.c:580-602`）→ **已四式落地（HANDOVER §34，`ad7a111`，71/71，含 P017 NSException 静默击杀修复）**。
  - [x] 结局 credits 卷轴（`0x7d` 一次性曲配套）→ **已在 M4.11d／HANDOVER §31.6 落地**。
  - [ ] 脚本内其余固定效果号（`0x66` 事件同表）随全量脚本回归补齐。
  - 建议起步：照 §34.1 的 `SHIZUKU_DUMP_SUBTYPES` 先统计 `0x66` 全语料频次，按频次定实现优先级。

---

### 阶段五：汉化数据提取与双语版终极交付 (Stage 5: Bilingual M2 Release)

> 战略：日文原生版（阶段一~四）已 100% 交付。双语版走「框架先行、语料即插即用」——M5.2 热挂载框架与 M5.1 脱壳取语料**均已完成**（HANDOVER §40），3834 条中文全量灌入即生效，「可用中文版」达成；剩余为可选视觉升级与 M2 正式发布的实机全结局回归。

- [x] **M5.6: 双版本架构 + 存档通用（HANDOVER §38 方案 / §39 实录，98→111/111，2026-09-24）**
  - [x] **WP-1 存档-语言解耦**（`d063216`）：capture 停写 language＋中文预览、restore 忽略档内语言、slot 预览带渲染期按 (scn,msg) 现算＋CN 原生字体分流、`translatedText` 门控 `.zh`。D2「存档直接通用」的运行时地基，两版本读写同一 `~/Library/Application Support/Shizuku/saves`。
  - [x] **WP-2 语言=构建期常量**（`0152011`）：`BuildLanguage`（env `SHIZUKU_LANGUAGE` > Info.plist > `.jp`），删「表示言語」菜单/启动切换/`system.json` 读写（字段留作解码兼容）；`Engine.language` 种自构建常量。
  - [x] **WP-3 双 bundle**（`ba13659`）：`package.sh [jp|zh]` → `Shizuku_Restored_{JP,ZH}_Ver.X`＋Bundle ID 分叉＋ZH plist 注入 `SHIZUKU_LANGUAGE`＋仅 ZH 打包 `zh_text.json`（JP 零中文污染）；无参数旧路径逐字节零回归。ZH `.app` 端到端 `SHIZUKU_SHOT=cn` 出中文帧。
  - [x] **WP-7a 外壳中文化**（`1ddae5f`，M5.4 的零语料部分）：`ShellText`/`MenuRow` 按构建语言分流——JP 叶码路径逐像素不变（回归锁＋五帧字节级比对），ZH 构建 ESC 六项/标题五项/确认框/载入存档选择器全中文（素材原文＋既定译名）。
  - 验收：`swift test` 111/111；JP `title,esc,slotload,confirm,continuelist` 帧与 `build/jp_baseline_preWP2_d063216/` 逐字节一致；ZH 五帧目检；互读冒烟进 `SaveLoadTests`（双向）。注：slot 帧与真实 saves 目录耦合，字节级复跑须冻结存档目录（§39.4）。

- [x] **M5.2: TranslationStore 热加载与双语无缝切换（框架＋全量语料均已完成 ✅）**
  - ✅ `GameLanguage(.jp/.zh)` + `Engine` 中文分页态（`cnPages/cnPage`，与 JP segment 锁步以保留内联动作）+ `SceneComposer.drawCNTextLayer`（原生反锯齿 CJK）+ ESC 第 7 行「言語を切り替える 切换语言」+ 语言持久化（`system.json`/`SaveState`）。
  - ✅ `zh_text.json` 自动打包进 `Resources/gamedata`，`TranslationStore.loadDefault` 优先读 bundle → shipped app 零外部文件即切中文。
  - ✅ 验证：`SHIZUKU_SHOT=cn` 直挂 SCN001 msg5 锚点句中文正确渲染；全画无回归；bundle 内热挂载实测通过（commit `b0ccd34`）。
  - ✅ 全量语料灌入完成（`6d4312e`，3834 条）：dev 路径与 ZH bundle 双验证，`cn`/`loadsave` 出帧目检通过。

- [x] **M5.1: 汉化脱壳密文流解密与 zh_text.json 导出（✅ 2026-09-25 收官，HANDOVER §40.1–40.2）**
  - ✅ **M5.1a–c**：catalog 偏移捕获根因击穿（`1ffbc2c`，Interlocked* 桩）；dec_cbc 解出 catalog → table1/table2。
  - ✅ **M5.1d**：199 条 CN 记录全量解密落盘 `research/recovery/text/cnrec/`（`bfcfbc9`）＋ SCN 容器解析 ＋ CN 4726 槽字库 dump `cnfont_4726.bin`。
  - ✅ **M5.1e**：字表还原＝**模糊平移 NCC＋jieba 字频先验＋GB2312 候选池锚点分段单调 DP**（旧 IoU 判分无区分度系误读根因）——2868/2868 全映射、34/34 锚点逐字复现、0 序违例 0 重码；JP 原文 `sizfont.tbl` 交叉验证＋15 处定点修正（`0009336`）；导出 **3834 条 `(scn,msg)→中文`**（JP 4044 条的 94.8%，缺口全部定性：CN 无 scn17/20、JP [0,205] 原版即无 CN 对应、empty_skip 170、unmapped_code 24）；安装 `6d4312e`。

- [x] **M5.3: 原版中文点阵字库挂载（视觉统一升级，WP-11，2026-09-26）**
  - ✅ 码表路线替代「另取 overlay 字库」：`cnfont_4726.bin`（4726×72B，前 1852 槽与 JP `KNJ_ALL.KNJ` 逐字节相同）＋ `cn_code2char.json`（2872 条）挂进 `ShizukuCore/CnDotFont.swift`，`SceneComposer.drawCNMatrixText` 沿用原版 drawChar 三遍叠印（1px/2px 双影＋本体）。
  - ✅ 覆盖面＝凡中文面全走点阵：正文/选择支/标题·ESC·确认菜单/选槽（含（空）·日期·提示·预览带）/toast/回想/音乐房/结局列表。未命中 CN 区的字符回落 JP 叶码 fold（与原版汉化混排同法）。
  - ✅ ▶（同页待续）与 ▼（页满）改画**原版叶码 102/103**，与原版汉化一致。
  - ✅ 验证：`build/zh_wp11/{menus,cnreveal}/` 30＋4 帧目检；包内二进制（非 dev 路径）复跑证明字库从 bundle 内挂载。详见 HANDOVER §44。
  - ⏳ 遗留洁癖项：汉字区 84 条 NCC 可疑标签（人工复核多为假阳；点阵往返下不影响出字），`wp12_hanzi_flags.json` 留档。

- [x] **M5.4: UI 外壳中文本地化（标题/ESC/しおり/选项/回想，WP-7a+7b，2026-09-25）**
  - ✅ 标题五项、ESC 六项、确认框、しおり→书签选择器（含（空）/日期/底部提示）已由 **M5.6 WP-7a** 落地（`1ddae5f`，`ShellText` 按构建语言分流，ZH 构建原生字体渲染）；全量语料下五帧重渲目检再过（§40.3）。
  - ✅ 选择支选项/SELECT 提示语/回想屏中文＝**WP-7b** 已落地（`3d23044`+`6021db5`，HANDOVER §41：选项与回想走 `translatedText` 原生字、`cnActive` 解绑 `currentMsg`；JP `choice/history` 帧逐字节不变）。
  - ✅ **WP-9（2026-09-26，HANDOVER §42）**：①②正文推进重做＝译文按 JP 拍比例切片（`cnSlices/cnCommitted`），JP 段机器为唯一时钟，中文逐字显影＋手动按拍推进、JP 零泄漏；③结局列表/画廊/音乐房/toast/退出对话框/窗口标题全中文（JP 路径恒落回原叶码，73 帧双轮 70/73）。
  - ✅ **WP-10（2026-09-26，HANDOVER §43）**：④长页停顿点卡半句＝`sliceChinese` 切点吸附句读边界（就近于比例目标、单调不复用、命令段/余数规则不变）；全语料 3834 条零违例、115/115、JP 仍 70/73、2:4 五拍长页逐拍收于「。」。
  - ✅ **WP-12（2026-09-26，HANDOVER §44.3/§44.5）**：⑤「极个别句子出现日文假名」根因＝`cn_code2char.json` 符号/假名区在 GB2312-only 候选池上整体错位（从 1869 起）；逐格目检重建 1854..1912（改 39 码→225 条译文变化），残留 12 条假名逐条核对**均为刻意保留**（译者注/「く」字形/平假名长头衔梗）；附带修 toast「已保存（しおり 3）」→「（书签 3）」。
  - ✅ **空拍跳过修复（2026-09-26，HANDOVER §44.4）**：⑥「连点很多下 Enter」＝语料 987 个「JP 有字码、CN 切片空」静默文本拍（波及 2771/3755 条消息，最长连击 59 下零反馈）；`Engine.skipCNEmptyBeats()` 仅 CN 路径前移段号（不在循环里 apply，避免重放动作/卡内联命令），`testCNAutoSkipsSilentBeats` 断言点击数恰等于应有拍数。116/116。
  - ✅ **WP-13（2026-09-26，HANDOVER §45）**：macOS 菜单栏（`setupMainMenu` 四顶级菜单＋全部子项＋App 菜单 关于/隐藏/退出）按构建语言分流＝ZH 纯中文、JP「日文（中文注）」逐字不变；早送り三档 `zhLabel`（慢/标准/快），连带修 toast「快进速度 [速い]」→「[快]」。中文版产物目录 `package.sh zh` → **`build_chs/`**（`release_zh/` 作废）。无头量具 `SHIZUKU_SHOT=menu`（菜单栏不在 73 帧截图面内，靠标题 dump 验收）。
  - 验证：`SHIZUKU_SHOT=title,esc,slotload,confirm` 在 ZH 构建下目检中文菜单（已过）；WP-11/12 全面目检帧归档 `build/zh_wp11/`；WP-13 双语言菜单栏 dump 归档 `build/zh_wp13/`。

- [~] **M5.5: 双语版全量回归 + M2 正式打包发布（双 DMG 已产出 ✅，全结局实机回归待用户）**
  - ✅ `swift test` 111/111；✅ 双 DMG：`Shizuku_Restored_JP_Ver.0.1.dmg`（零中文污染）＋`Shizuku_Restored_ZH_Ver.0.1.dmg`（全量 3834 条语料，卷内二进制挂载冒烟出中文帧）；✅ WP-8 互读终验双向 6 存档点（HANDOVER §40.3）。
  - ⏳ 中/日两模式全 13 结局路径**实机**回归＋M2 正式发布。
  - **交付里程碑 M2**：《雫～しずく～》macOS 原生双语正式版发布！

---

## 三、当前优先级与建议下一步 (Next Actions)

1. **已收官 = M5.1/M5.2/M5.6/WP-8**（全量中文语料 + 双版本架构 + 双 DMG）；「可用中文版」判据达成。
2. ~~下一手 = M5.4 尾巴 WP-7b~~ ✅ 已落地（§41）；~~文案尾巴（结局列表/画廊/音乐房/窗口标题）~~ ✅ **WP-9 落地（§42.2，`bd7e9bf`）**。用户实机三修（①CN 后露 JP、②无逐字/按拍推进、③菜单日文）已于 2026-09-26 全部修复（§42，`a35d3cc`+`bd7e9bf`，113/113，JP 70/73 双轮，双 DMG 重打），**待用户实机复验手感**（尤其多页长文与 pageBreak 节奏）；复验中已报出第④项「长页停顿点卡半句中」，**WP-10 修复落地（§43）**，待再验。
3. **发布前 = M5.5**（中/日两模式全 13 结局路径实机回归 → M2 正式版）。
4. ~~锦上添花 = M5.3~~ ✅ **WP-11 落地（§44.1/44.2）**：全中文面切汉化点阵字库（`CnDotFont`＋`drawCNMatrixText` 三遍叠印），▶/▼ 用原版叶码 102/103；同轮收两缺陷（§44.3 码表假名区错位、§44.4 中文空拍连点），116/116、JP 69/73（4 张失败帧逐张定位为动态存档/画廊解锁数据，文字行零变化）、重打包并用包内二进制复验。**待用户实机复验手感**。
