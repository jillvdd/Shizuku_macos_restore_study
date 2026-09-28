# Shizuku_macos_restore_study
## Leaf LVNS 视觉小说引擎逆向与 macOS 原生重构研究工程资料库
### Reverse Engineering & Native macOS (Swift + Metal) Restoration Study for Leaf's *《雫～しずく～》* (1996)

---

## 📖 仓库简介 / Overview

本仓库是针对 Leaf（现 AQUAPLUS）于 1996 年发布的经典视觉小说《雫～しずく～》（以及同架构的 LVNS 引擎家族）的**完整逆向工程、数据格式规范、历史研究文献、分析工具链与原生重构技术资料库**。

仓库系统性地整合了从 Windows 95 老旧二进制资产到 macOS（Apple Silicon, Swift + Metal）现代原生重构全过程的全部研究成果，为经典老游戏在现代操作系统的原生高保真复刻提供了完整、务实的技术支撑。

---

## 📑 核心技术工程指南与文章互引 / Flagship Articles & Cross-Indexing

本项目历经完整逆向推导与实机排错，总结撰写了详尽的工程技术复盘长文。三篇文档内容互相锚定、结构严密对齐，并在文首均提供语言一键互换跳转：

| 语言版本 / Edition | Markdown 源文档 | 静态网页端 / Web View (GitHub Pages) | 核心定位与特色 |
|---|---|---|---|
| 🇨🇳 **简体中文** | [`articles/leaf-galgame-port-zh.md`](articles/leaf-galgame-port-zh.md) | [**进入中文版网页 →**](article-zh.html) | 面向现代软件工程师的务实技术文档，系统阐释二进制解密、双层虚拟机、渲染管线、音频异常与向《痕》《To Heart》复用的 9 步工单。 |
| 🇺🇸 **English** | [`articles/leaf-galgame-port-en.md`](articles/leaf-galgame-port-en.md) | [**View English Article →**](article-en.html) | A pragmatic systems engineering postmortem covering proprietary PAK cryptanalysis, dual-layer VM coroutine design, 24x24 1bpp vertical font decoding, CoreAudio exception swallowing, and Apple Silicon adaptations. |
| 🇯🇵 **日本語** | [`articles/leaf-galgame-port-jp.md`](leaf-galgame-port-jp.md) | [**技術仕様書を見る →**](article-jp.html) | LVNS エンジンのバイナリ解析、2 層仮想マシン設計、描画および CoreAudio 障害追究、タイトル画面 VA 0x430ebc の第 5 不可視ポインタから導く隠し音楽室の復元など、全工程を実務的に解説した技術仕様書。 |

> 💡 **文章互引说明**：
> - 每篇 Markdown 文档顶部均配有统一语言导航条：`> 🌐 语言 / Language: [🇨🇳 简体中文](leaf-galgame-port-zh.md) ｜ [🇺🇸 English](leaf-galgame-port-en.md) ｜ [🇯🇵 日本語](leaf-galgame-port-jp.md)`；
> - 静态网页端右上角设有常驻语言切换按钮（`[Home]` `[🇨🇳 简体中文]` `[🇺🇸 English]` `[🇯🇵 日本語]`），支持平滑跨语种对照阅读。

---

## 🌐 静态 HTML 网页门户 / GitHub Pages Ready

本仓库根目录已内置开箱即用的轻量级响应式静态站点，无需额外构建流水线即可直接托管于 **GitHub Pages**：

- **[index.html](index.html)**：项目技术门户主页，包含架构可视化图解、核心格式卡片、工具链速查与产物直达；
- **[article-zh.html](article-zh.html)**：中文工程技术指南完整排版页，带左侧悬浮目录（TOC）与代码语法高亮；
- **[article-en.html](article-en.html)**：English Technical Guide 完整排版页；
- **[article-jp.html](article-jp.html)**：日本語技術仕様書 完整排版页；
- **[style.css](style.css)**：纯原生 CSS，支持系统级浅色/深色主题自适应，零外部网络 CDN 依赖。

---

## 🗂 目录结构与内容说明 / Directory Structure

```text
Shizuku_macos_restore_study/
├── README.md                      # 本文档：仓库索引、文章互引与导航
├── .gitignore                     # Git 忽略规则（排除编译缓存与系统元数据）
├── index.html                     # 静态网页门户主页（GitHub Pages 就绪）
├── article-zh.html                # 中文版静态排版页面
├── article-en.html                # 英文版静态排版页面
├── article-jp.html                # 日文版静态排版页面
├── style.css                      # 静态网页轻量级响应式主题样式表
│
├── articles/                      # 核心工程技术复盘长文（中／英／日三语对齐）
│   ├── leaf-galgame-port-zh.md    # 中文工程技术指南
│   ├── leaf-galgame-port-en.md    # English Engineering Guide
│   └── leaf-galgame-port-jp.md    # 日本語技術仕様書
│
├── docs/                          # 基础格式字段级规范与逆向分析文档（9 份）
│   ├── containers.md              # LEAFPACK 容器格式与 11 字节异或解密规范
│   ├── lfg.md                     # LFG 图像格式、4 位调色板高低位复制与垂直列交织
│   ├── scripts.md                 # SCN 脚本结构、Block 执行模型与行内宏指令
│   ├── audio.md                   # LAC 音频容器、CD-DA 偏移与 BGM 编号映射
│   ├── history.md                 # LVNS 引擎家族演进历史（PC-98 到 Win95）
│   ├── original-files.md          # Windows 95 原版文件清单与职能说明
│   ├── unknown-opcodes.md         # 未知指令与 13 个带操作数 Skip Opcode 分析
│   ├── gbalvns.md                 # GBALVNS 开源架构与指令集参考
│   └── sizuku-gba.md              # GBA 移植版实现对比分析
│
├── reports/                       # 全量研究报告与工程交接研发日志（4 份）
│   ├── SHIZUKU_PORT_RESEARCH_REPORT.md  # Phase 0/1 初始研究报告（数据验证与可行性）
│   ├── HANDOVER.md                # 完整研发交接日志（340KB，包含 M4.10/M4.11 所有攻坚细节）
│   ├── MILESTONES.md              # 里程碑计划与验收标准记录
│   └── RESUME_PROMPT.md           # 上下文恢复与研发提示词基线
│
├── tools/                         # 逆向分析工具链与解包/反汇编脚本
│   ├── shizuku_cli/               # 模块化 Python 逆向命令行工具包
│   │   ├── leafpack.py            # LEAFPACK 归档解密与提取模块
│   │   ├── lfg.py                 # LFG 图像解码与 16 色调色板处理模块
│   │   ├── knj.py                 # KNJ 点阵字库（24x24 1bpp）解析模块
│   │   ├── scn.py                 # SCN 脚本字节码反编译与行内宏提取模块
│   │   ├── shizuku-lfg.py         # LFG 格式底层实用工具
│   │   ├── cmd_disasm.py          # 脚本批量反汇编子命令
│   │   ├── cmd_extract.py         # 归档解包子命令
│   │   ├── cmd_font.py            # 字库导出与字图渲染子命令
│   │   ├── cmd_image.py           # 图像解码子命令
│   │   ├── cmd_inspect.py         # 文件头与段信息探针子命令
│   │   └── cmd_text.py            # 纯文本抽取子命令
│   └── scripts/                   # 独立功能验证脚本
│       ├── unpack_leafpack.py     # 独立 LEAFPACK 归档解包脚本
│       ├── shizuku-lfg-image.py   # 独立 LFG 图像查看与转码脚本
│       ├── shizuku-knj-font.py    # 独立 KNJ 字库导出与字表校验脚本
│       ├── shizuku-scn-disasm.py  # 独立 SCN 脚本反汇编脚本
│       ├── verify_font_layout.py  # 字库物理排布与 SJIS 对照验证脚本
│       └── render_leaf_test.py    # 文本字形排版渲染测试脚本
│
├── disasm/                        # 全量剧情脚本反汇编基准文本
│   └── SCN000.txt ... SCN196.txt  # 197 个 SCN 脚本的反汇编明文（作为虚拟机实现基准）
│
├── preview/                       # 逆向与渲染验证图像产物
│   ├── knj_atlas.png              # 1,852 字完整点阵字库渲染全图
│   ├── hvs01_decoded.png          # 解码出的高保真立绘资产（月岛琉璃子）
│   ├── hvs01_from_tool.png        # 命令行工具渲染的立绘测试帧
│   ├── preview_bg01.png           # 解码的背景资产预览
│   └── preview_leaf.png           # 调色板与像素测试帧
│
├── references/                    # 历史开源资产与参考实现
│   ├── thirdparty/                # 早期开源 LVNS 引擎项目代码与归档
│   │   ├── leafpak/               # Yumegawa 开源的 leafpak 工具（C 语言）
│   │   ├── lfview/                # 早期 LFG 图像查看器（X11）
│   │   ├── mglvns/                # MGLVNS 引擎源码（X11/Linux）
│   │   ├── xlvns/                 # XLVNS 项目记录
│   │   └── akkera/                # Akkera 早期逆向测试包与工具源码
│   ├── pages/                     # 历史技术网页存档（1999-2002 年早期逆向资料）
│   └── gbalvns/                   # Game Boy Advance 平台 LVNS 引擎实现参考
│
└── runtime_reference/             # 现代 Swift + Metal 原生重构代码参考
    ├── Package.swift              # Swift Package Manager 工程定义
    ├── Sources/
    │   ├── ShizukuCore/           # 二进制读取、解密、字库与格式解码器
    │   ├── ShizukuEngine/         # 外层事件虚拟机（Event VM）与内层行内演出虚拟机
    │   ├── ShizukuRender/         # Metal 渲染管线、调色板暗化、13 种转场与背景正弦扭曲
    │   └── ShizukuApp/            # macOS 原生窗口、全屏回想系统与标题画面视图控制器
    └── Tests/
        └── ShizukuCoreTests/      # 单元测试集（字库物理排布、转场几何、宏解析等）
```

---

## 🛠 关键逆向工程成果概览 / Key Reverse Engineering Breakthroughs

1. **LEAFPACK 归档与 11 字节滚动异或密钥**：
   - 密钥序列：`71 48 6a 55 9f 13 58 f7 d1 7c 3e`
   - 利用目录区 24 字节文件名槽位尾部填充的大写 ASCII 与空格特性，实现了无源码条件下的差分盲破还原。
2. **LZS 解压变体与 173/197 文本截断难题**：
   - 区分了 LFG 的正逻辑 LZS（环形缓冲区 `0x1000`，初值 `0xFEE`）与 SCN 脚本的反逻辑 `lzs3`（标志位取反 `~flag`，环形缓冲区 `0x1011`）。
   - 确认了解压必须严格按段头声明大小截断输出流，彻底解决了此前 173 个脚本末尾文本被尾部垃圾字节污染的历史 Bug。
3. **KNJ 点阵字库物理排布与 1-based 叶码直接寻址**：
   - 确认 `KNJ_ALL.KNJ`（133,344 字节）包含 1,852 字，每字 24×24 像素、1bpp、72 字节，采用 3 列垂直扫描带排布（MSB 居左）。
   - 澄清了叶码是 1-based 直接数组下标（`code - 1`），`sizfont.tbl` 仅为外部逆向对照表。
4. **双层嵌套虚拟机架构（Event VM + Inline VM）**：
   - 识别了外层事件虚拟机中 13 个带操作数却无操作的 Skip Opcode（如 `0x03`, `0x06`, `0x5a`, `0x5c`, `0x60-0x66`, `0x6f`, `0x73`）。
   - 揭示 90% 的立绘、背景、音乐、音效、震屏、闪白演出均以内联 ASCII 宏（`B/E`, `C`, `D`, `S`, `A`, `V/H`, `M`, `P`, `F`, `Q`, `X`, `s`, `k`, `p`, `$`）直接嵌入对话文本中。
5. **视觉与渲染高保真还原**：
   - 25×13 Sound Novel 文本网格，三 Pass 硬阴影字绘，全局调色板 `11/16` 暗化。
   - 修复螺旋转场（GURUGURU）：还原以 `(27, 12)` 为圆心的 16px 瓷砖向外螺旋展开算法。
   - Opcode `0x01` 过场四式与正弦背景剪切扭曲（`sintable[361]`）。
6. **隐藏音乐室反汇编取证**：
   - 从原版 EXE 虚拟地址 `0x430ebc` 处逆向出标题画面第 5 个隐藏菜单指针，坐标换算锁定校舍钟楼右上角窗格 `(448, 128)`。
   - 逆向 `0x408d40` 音乐室主循环，并在 `VIS17.LFG` 上完整复原。
7. **macOS 底层系统排错**：
   - 排查单声道 11025Hz WAV 在 CoreAudio 立体声节点上抛出 `NSException` 被 AppKit 静默吞噬的致命崩溃，使用 `AVAudioConverter` 重采样解决。
   - 引入 `ProcessInfo.beginActivity([.userInitiated, .latencyCritical])` 彻底根治 macOS App Nap 对 60Hz 刷新循环降频至 5 FPS 的性能问题。

---

## 🚀 逆向工具使用示例 / Tooling Usage

### 1. 批量反汇编全量脚本为可读文本
```bash
python3 tools/scripts/shizuku-scn-disasm.py /path/to/SCN001.DAT -o SCN001.txt
```

### 2. 导出与验证 24×24 KNJ 点阵字库
```bash
python3 tools/scripts/shizuku-knj-font.py /path/to/KNJ_ALL.KNJ --atlas preview/knj_atlas.png
```

### 3. 解码 LFG 图像资产
```bash
python3 tools/scripts/shizuku-lfg-image.py /path/to/HVS01.LFG -o preview/hvs01.png
```

### 4. 使用模块化 CLI 进行全面探查
```bash
python3 -m tools.shizuku_cli inspect /path/to/MAX_DATA.PAK
python3 -m tools.shizuku_cli extract /path/to/MAX_DATA.PAK -o output_dir/
```

---

## 📜 版权与免责声明 / Copyright & Disclaimer

- 本仓库所载的研究文档、逆向分析工具、反汇编说明与现代架构代码仅供计算机软件工程、老旧系统兼容性研究与数字化文化资产保护参考学习之用。
- 《雫～しずく～》及其角色、剧本、音乐与美术资产版权归 Leaf / AQUAPLUS 所有。
- 本仓库不分发任何原版商业游戏的受版权保护的原始资源文件（如原始 CD 镜像、PAK 归档）。

---

jill 推特[@jill05617147](https://x.com/jill05617147) 微博[@jill_mk3](https://weibo.com/n/jill_mk3)
