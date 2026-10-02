# Shizuku_macos_restore_study
## Leaf LVNS 视觉小说引擎逆向与 macOS 原生重构研究工程资料库
### Reverse Engineering & Native macOS (Swift + Metal) Restoration Study for Leaf's *《雫～しずく～》* (1996)

> 🌐 **Language / 多语言**: [🇨🇳 简体中文](README.md) ｜ [🇺🇸 English](README-en.md) ｜ [🇯🇵 日本語](README-jp.md)

---

## 📖 仓库简介

本仓库是针对 Leaf（现 AQUAPLUS）于 1996 年发布的经典视觉小说《雫～しずく～》（以及同架构的 LVNS 引擎家族）的**完整逆向工程、数据格式规范、历史研究文献、分析工具链与原生重构技术资料库**。

仓库系统性地整合了从 Windows 95 老旧二进制资产到 macOS（Apple Silicon, Swift + Metal）现代原生重构全过程的全部研究成果，为经典老游戏在现代操作系统的原生高保真复刻提供了完整、务实的技术支撑。

---

## 📑 核心技术工程指南

本项目历经完整逆向推导与实机排错，总结撰写了详尽的工程技术复盘长文。三篇文档内容互相锚定、结构严密对齐：

- 🇨🇳 **[中文工程技术指南](articles/leaf-galgame-port-zh.md)**：面向现代软件工程师的务实技术文档。深入二进制加法滚动解密、LZS3 截断守卫、24×24 点阵字库列优先解码、双层虚拟机（Event VM + Inline VM）、13 种转场几何算法、钟楼隐藏音乐室反汇编、2014 汉化包逆向与字库重构、PC-9801 OPNA FM 原生音源双架构及全结局确定性回归实录。
- 🇺🇸 **[English Technical Guide](articles/leaf-galgame-port-en.md)**：A rigorous, pragmatic systems engineering postmortem covering proprietary PAK cryptanalysis, dual-layer VM coroutine design, 24x24 1bpp vertical font decoding, 2014 Chinese patch reverse engineering, PC-9801 OPNA FM audio bit-perfect recording, and headless deterministic regression.
- 🇯🇵 **[日本語技術仕様書](articles/leaf-galgame-port-jp.md)**：LVNS エンジンのバイナリ解析、2 層仮想マシン設計、描画および CoreAudio 障害追究、隠し音楽室の復元、2014 年有志中国語パッチの暗号解読とフォント再構築、PC-9801 OPNA FM 実機音源二重アーキテクチャまでを実務的に解説した技術仕様書。

---

## 📐 逆向格式规范文档

对 Windows 95 原版所用专有二进制格式的字段级解析规范：

1. [**LEAFPACK 容器格式与 11 字节异或解密规范**](docs/containers.md)：8 字节头部、uint16 文件数、累加滚动异或流与目录区差分盲破算法。
2. [**LFG 图像格式与解码规范**](docs/lfg.md)：16 色 4 位调色板半字节翻倍展开（`(c << 4) | c`）、垂直列优先位交织与立绘 400px 视口排版。
3. [**SCN 脚本结构与双层虚拟机**](docs/scripts.md)：外层 Block 跳转模型、13 个 Skip 占位指令与内联 ASCII 宏（B/E, C, S, D, M, P, F, Q）调度。
4. [**LAC 音频容器与 BGM 编号映射**](docs/audio.md)：`bgmmap` 转换公式、CD-DA 偏移校正与原声 OST 声纹比对。
5. [**LVNS 引擎家族演进历史**](docs/history.md)：PC-98 到 Windows 95 版本变迁与技术演变。
6. [**Windows 95 原版文件清单**](docs/original-files.md)：原版盘内各文件职能与格式归类。
7. [**未知指令与 13 个 Skip Opcode 分析**](docs/unknown-opcodes.md)：未公开指令的操作数宽度测量与安全跳步。
8. [**GBALVNS 开源架构参考**](docs/gbalvns.md)：GBA 移植版状态机与参考实现分析。
9. [**GBA 移植对比分析**](docs/sizuku-gba.md)：PC 原版与掌机版数据结构异同。

---

## 📋 研发报告与工程技术复盘

完整的系统工程历程、底层排错手记与验证规范：

- [**Phase 0/1 架构逆向与可行性报告**](reports/SHIZUKU_PORT_RESEARCH_REPORT.md)：立项初期的格式识别、工具链验证与数据可行性评估报告。
- [**研发工程日志与技术复盘 (HANDOVER)**](reports/HANDOVER.md)：详尽的系统工程手记，深度复盘了视觉保真度排错、13 种转场与钟楼隐藏音乐室反汇编、单声道 11025Hz CoreAudio 异常排查、macOS App Nap 锁频攻坚、2014 汉化字模重构、PC-9801 OPNA FM 硬件内录及 Ver.1.5 双版本交付等关键技术突破。
- [**里程碑计划与交付验收规范**](reports/MILESTONES.md)：六大阶段敏捷迭代工单与多维度技术验收标准（M1~M6 全量验收）。
- [**系统工程基线与技术速查**](reports/RESUME_PROMPT.md)：底层十六进制偏移、内存映射图解、OPNA FM 循环点、Meta-Save 结构及核心架构接口速查手册。

---

## 🗂 仓库完整目录结构

```text
Shizuku_macos_restore_study/
├── README.md                      # 本文档：资料库索引与主控导航
├── _config.yml                    # GitHub Pages (Jekyll) 配置文件
├── _layouts/                      # GitHub Pages 页面母版（包含顶栏导航与页脚）
│   └── default.html
├── assets/                        # 站点样式与静态资源
│   └── css/
│       └── style.css
│
├── articles/                      # 核心工程技术复盘长文（中／英／日三语对齐）
│   ├── leaf-galgame-port-zh.md    # 中文工程技术指南
│   ├── leaf-galgame-port-en.md    # English Engineering Guide
│   └── leaf-galgame-port-jp.md    # 日本語技術仕様書
│
├── docs/                          # 基础格式字段级规范与逆向分析文档（9 份）
│   ├── containers.md              # LEAFPACK 容器格式与解密规范
│   ├── lfg.md                     # LFG 图像格式与解码规范
│   ├── scripts.md                 # SCN 脚本结构与双层虚拟机
│   ├── audio.md                   # LAC 音频容器与 BGM 编号映射
│   ├── history.md                 # LVNS 引擎家族演进历史
│   ├── original-files.md          # Windows 95 原版文件清单
│   ├── unknown-opcodes.md         # 未知指令与 Skip Opcode 分析
│   ├── gbalvns.md                 # GBALVNS 开源架构参考
│   └── sizuku-gba.md              # GBA 移植对比分析
│
├── reports/                       # 全量研究报告与工程交接研发日志（4 份）
│   ├── SHIZUKU_PORT_RESEARCH_REPORT.md  # Phase 0/1 初始研究报告
│   ├── HANDOVER.md                # 完整研发交接日志（340KB）
│   ├── MILESTONES.md              # 里程碑计划与验收标准
│   └── RESUME_PROMPT.md           # 上下文恢复基线
│
├── tools/                         # 逆向分析工具链与解包/反汇编脚本
│   ├── shizuku_cli/               # 模块化 Python 逆向命令行工具包
│   └── scripts/                   # 独立功能验证脚本（unpack, font, image, disasm 等）
│
├── disasm/                        # 全量剧情脚本反汇编基准文本
│   └── SCN000.txt ... SCN196.txt  # 197 个 SCN 脚本的反汇编明文
│
├── preview/                       # 逆向与渲染验证图像产物
│   ├── knj_atlas.png              # 1,852 字完整点阵字库渲染全图
│   ├── hvs01_decoded.png          # 解码出的高保真立绘资产（月岛琉璃子）
│   ├── hvs01_from_tool.png        # 命令行工具渲染的立绘测试帧
│   ├── preview_bg01.png           # 解码的背景资产预览
│   └── preview_leaf.png           # 调色板与像素测试帧
│
├── references/                    # 历史开源资产与参考实现
│   ├── thirdparty/                # 早期开源 LVNS 引擎项目代码（mglvns, lfview, leafpak, akkera）
│   ├── pages/                     # 历史技术网页存档（1999-2002 年早期逆向资料）
│   └── gbalvns/                   # Game Boy Advance 平台 LVNS 引擎实现参考
│
└── runtime_reference/             # 现代 Swift + Metal 原生重构代码参考
    ├── Package.swift              # Swift Package Manager 工程定义
    ├── Sources/
    │   ├── ShizukuCore/           # 二进制读取、解密、字库与格式解码器
    │   ├── ShizukuEngine/         # 外层事件虚拟机（Event VM）与内层行内演出虚拟机
    │   ├── ShizukuRender/         # Metal 渲染管线、调色板暗化与 13 种转场
    │   └── ShizukuApp/            # macOS 原生窗口、全屏回想系统与标题画面控制器
    └── Tests/
        └── ShizukuCoreTests/      # 单元测试集
```

---

## 🛠 关键逆向工程成果概览

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
8. **2014 汉化逆向、4,726 槽 24×24 点阵字模与单调 DP 映射 (Ver.1.2)**：
   - 逆向分析 2014 年汉化补丁 `data.bin` 4 字节 XOR 加密，解出包含 199 个 SCN 的汉化剧本流；
   - 从补丁 DLL 资源区转储提取 4,726 槽位 24×24 二值化中文字模库 `cnfont_4726.bin`（340,272 字节）；
   - 设计单调递增最小编辑距离 DP 算法，重构出包含 2,872 字的叶码-GBK 单调映射表 `cn_code2char.json`。
9. **剧本节拍切片 (Beat Slices) 动态推进与 15 页后记还原**：
   - 解决汉化字数不对称导致的音画失步，引入 `cnSlices` 与 `cnCommitted` 动态切片算法，实现中文等比节拍展开与标点吸附；
   - 完整复原汉化组追加的 15 页感言剧本（`SCN233` -> `SCN234`），并设计 `SaveError.missingScenario` 跨版本存档崩溃防御。
10. **PC-9801/9821 OPNA (YM2608) FM 原生音源内录与双音频架构 (Ver.1.5)**：
    - 采用专业录音设备对 1996 年 PC-9801 原版硬件进行 bit-perfect 纯内录，采集全量 24 首 OPNA FM 音轨（43.3MB）；
    - 实现 Win95 CD-DA 与 PC-9801 FM 双音频后端热切换，标定微秒级精确循环点，对 6 首单次曲目施加生命周期保护。
11. **确定性快照回归体系 (113/113) 与 13 大全结局自动化回归**：
    - 引入 `SaveClock` 冻结物理时钟与伪随机数种子，对 `/tmp/shizuku_shot_saves/` 全量 113 个快照存档实现 100% 确定性回放；
    - 编写 `EndingPathTests.swift` 自动化遍历测试套件，实现全 13 种结局路径无死锁自动化全覆盖。
12. **Meta-Save 跨周目全局持久化与 Ver.1.5 双版本 DMG 交付**：
    - 参照 GBA SRAM `0x10` 架构设计，将 4 个跨周目全局标志位持久化至 `meta_save.dat`；
    - 全自动打包日文原版（`Shizuku_Restored_Ver.1.5.dmg`）与简中完全汉化版（`Shizuku_Restored_CHS_Ver.1.5.dmg`）双独立镜像。

---

## 🚀 逆向工具使用示例

```bash
# 批量反编译全量脚本为可读汇编
python3 tools/scripts/shizuku-scn-disasm.py /path/to/SCN001.DAT -o SCN001.txt

# 导出并验证 24×24 KNJ 点阵字库
python3 tools/scripts/shizuku-knj-font.py /path/to/KNJ_ALL.KNJ --atlas preview/knj_atlas.png

# 解码 LFG 图像资产
python3 tools/scripts/shizuku-lfg-image.py /path/to/HVS01.LFG -o preview/hvs01.png

# 模块化 CLI 探查与解包
python3 -m tools.shizuku_cli inspect /path/to/MAX_DATA.PAK
python3 -m tools.shizuku_cli extract /path/to/MAX_DATA.PAK -o output_dir/
```

---

## 📜 版权与免责声明

- 本仓库所载的研究文档、逆向分析工具、反汇编说明与现代架构代码仅供计算机软件工程、老旧系统兼容性研究与数字化文化资产保护参考学习之用。
- 《雫～しずく～》及其角色、剧本、音乐与美术资产版权归 Leaf / AQUAPLUS 所有。
- 本仓库不分发任何原版商业游戏的受版权保护的原始资源文件（如原始 CD 镜像、PAK 归档）。
