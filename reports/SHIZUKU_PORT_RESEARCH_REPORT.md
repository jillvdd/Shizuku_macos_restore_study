# Phase 0/1 架构逆向与跨平台可行性调研报告
## ——Leaf LVNS 引擎（《雫》1996）现代 macOS 原生重构前期论证

> 🌐 **Language / 多语言**: [🇨🇳 简体中文](SHIZUKU_PORT_RESEARCH_REPORT.md) ｜ [🇺🇸 English](SHIZUKU_PORT_RESEARCH_REPORT-en.md) ｜ [🇯🇵 日本語](SHIZUKU_PORT_RESEARCH_REPORT-jp.md)

---

## 1. 执行摘要与可行性矩阵

本报告汇总了对 Leaf（现 AQUAPLUS）经典视觉小说《雫～しずく～》（1996 年发布，基于 LVNS 引擎）进行数据格式逆向与现代跨平台原生重构的前期技术调研成果。

经由对前人历史开源成果（XLVNS、MGLVNS、lfview、akkera 氏 sizuku 工具链、GBALVNS）的代码审计、字段提取及实机原始资产交叉比对，**证实该老旧引擎的二进制数据结构具有高度自洽性，跨平台原生重写完全可行**。

| 模块 | 涉及原版文件 | 逆向突破点 | 现代 macOS 原生实现方案 |
|---|---|---|---|
| **资产归档容器** | `MAX_DATA.PAK` | 11 字节加法滚动异或加密；目录区 24 字节槽位差分恢复 | `ShizukuCore` 纯 Swift 流式解包与校验 |
| **音频归档容器** | `bgmfile.PAK`, `soundds.PAK` | LAC 格式解析；BGM 编号映射公式与声纹比对 | `AVAudioEngine` + `AVAudioPlayerNode` 硬件混音 |
| **图像渲染解码** | `*.LFG` (LEAFCODE) | 16 色 4-bit 调色板半字节扩展；垂直列优先位交织展开 | Metal 纹理管线 + Compute Shader / CPU 展开 |
| **脚本执行虚拟机** | `SCN*.DAT` (全 197 本) | SCN 双段 LZS3 变体解压；外层 Block 与内层行内宏解耦 | 双层虚拟机架构（Event VM + Inline VM） |
| **字体渲染排版** | `KNJ_ALL.KNJ` | 24×24 1bpp 垂直扫描三带排布；叶码直接寻址 | 1,852 字纹理图集（Glyph Atlas）+ 三 Pass 阴影字绘 |

---

## 2. LVNS 引擎架构全景

《雫》、《痕》与《To Heart》共同奠定了 Leaf 早期视觉小说系列（LVNS: Leaf Visual Novel System）的技术底座。

```text
                     ┌────────────────────────┐
                     │ Windows 95 Sizuku.exe  │
                     └───────────┬────────────┘
                                 │
        ┌────────────────────────┼────────────────────────┐
        ▼                        ▼                        ▼
 ┌─────────────┐          ┌─────────────┐          ┌─────────────┐
 │ MAX_DATA    │          │ bgmfile.PAK │          │ soundds.PAK │
 │ (LEAFPACK)  │          │ (LAC / Ogg) │          │ (LAC / WAV) │
 └──────┬──────┘          └─────────────┘          └─────────────┘
        │
   ┌────┴───────────────────────────┬──────────────────────┐
   ▼                                ▼                      ▼
197 SCN Scripts               195 LFG Images         1 KNJ Font
(Bytecode & Dialogue)         (16-color CGs/BGs)     (24x24 1bpp Bitmap)
```

1. **执行流驱动**：引擎初始化后挂载 `MAX_DATA.PAK` 目录索引，按需装载 `SCN%03d.DAT` 脚本。
2. **事件与文本解耦**：SCN 内部物理切分为「事件指令段」与「对话演出段」，分别由外层状态机与内层行内解释器驱动。
3. **视觉合成**：原始画布基准为 640×400，立绘与背景独立加载并通过 16 色调色板映射合成。

---

## 3. 二进制资产容器与格式识别验证

### 3.1 LEAFPACK 容器解密与目录恢复
`MAX_DATA.PAK`（5,756,792 字节）采用专有 LEAFPACK 结构。头部以 8 字节字符串 `"LEAFPACK"` 标识，其后为 16 位小端整数声明内部文件总数（`0x0193` = 403 个文件）。

数据区与文件目录均受到 11 字节加法滚动密钥混淆：
$$\text{StoredByte} = (\text{PlainByte} + \text{Key}[k \bmod 11]) \bmod 256$$
默认密钥序列为 `71 48 6a 55 9f 13 58 f7 d1 7c 3e`（ASCII 表现为 `qHjU…`）。利用目录区 24 字节记录中文件名末尾以空格填充的统计特征，无需反汇编 EXE 即可通过差分分析恢复出完整密钥。403 个文件已全部实现端到端无损解包。

### 3.2 LFG 图像解码（LEAFCODE）
195 张 `*.LFG` 图像采用 16 色 4 位索引调色板。解码关键在于：
- **半字节翻倍扩展**：调色板每个通道占 4-bit，需经 `(nibble << 4) | nibble` 映射为标准 8-bit RGB 阶调。
- **垂直列优先位交织**：在 `direction == 0`（垂直模式）下，解压得到的像素字节以纵向双列交错排列，需重新组织为标准的线性行优先像素矩阵。

### 3.3 SCN 脚本解压与 LZS 变体
原版 197 个剧情脚本（`SCN000.DAT` - `SCN196.DAT`）各自包含两个独立的 LZS 压缩段。
- **算法变体**：采用倒排旗标逻辑（`lzs3`），环形缓冲区大小为 `0x1011`。
- **严格截断边界**：解压过程必须严格按段头声明的解压大小截断输出，避免历史开源工具中常见的尾部垃圾字节污染问题。

---

## 4. 虚拟机设计与现代技术栈选型

### 4.1 弃用模拟器/兼容层方案
在初期调研中，曾评估 Wine / 虚拟机打包方案。实测表明：
1. **音频延迟与抖动**：老旧 DirectSound API 在模拟层中存在明显的时钟不同步与循环杂音。
2. **显示模糊与高刷失步**：无法原生利用 macOS Metal 进行整数倍 Crisp 像素缩放与 60Hz ProMotion 动态对齐。
3. **沙盒与系统融合度低**：无法提供符合 macOS 人机交互指南（HIG）的菜单栏、快捷键、触控板手势与现代化 JSON 存档管理。

因此，确定采用 **Swift + Metal 原生架构重写**。

### 4.2 模块化分层设计

```text
┌─────────────────────────────────────────────────────────┐
│               ShizukuApp (AppKit / HIG)                 │
│      Native Window, Menu Bar, Save/Load, Sound Room     │
├──────────────────────────┬──────────────────────────────┤
│ ShizukuEngine (Core VM)  │   ShizukuRender (Metal 3D)   │
│  Event VM + Inline VM    │  640x400 Target, Transitions │
├──────────────────────────┴──────────────────────────────┤
│               ShizukuCore (Foundation)                  │
│   Binary Stream, Crypto, LZS3, LFG Decoders, Font Atlas │
└─────────────────────────────────────────────────────────┘
```

---

## 5. 结论

本调研确认《雫》原版 Windows 95 数据完整可用，无不可克服的加密障碍。技术路线清晰，模块边界明确，为全量工程落地提供了坚实的理论基准与事实支撑。
