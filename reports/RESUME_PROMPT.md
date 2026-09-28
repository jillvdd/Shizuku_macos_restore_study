# 系统工程基线与快速技术参考手册
## ——Leaf LVNS 引擎核心常量、内存映射与架构接口速查

> 🌐 **Language / 多语言**: [🇨🇳 简体中文](RESUME_PROMPT.md) ｜ [🇺🇸 English](RESUME_PROMPT-en.md) ｜ [🇯🇵 日本語](RESUME_PROMPT-jp.md)

---

## 1. 核心常量与关键基准速查表

为方便开发者与逆向工程研究者快速查验，本节汇总了《雫～しずく～》（Windows 95 版 / LVNS 引擎）全部实机已验证的基准常量：

| 参数类别 | 物理常量 / 键值 / 偏移 | 含义与工程约束 |
|---|---|---|
| **画布基础分辨率** | `640 × 400` | 原始 16:10 渲染目标，整数倍等比缩放至现代化显示屏 |
| **刷新率与同步** | `60.0 Hz` | `CVDisplayLink` / `CAMetalDisplayLink` 严格锁相刷新 |
| **PAK 滚动异或密钥** | `71 48 6a 55 9f 13 58 f7 d1 7c 3e` | 11 字节加法循环密钥（对应 ASCII `"qHjU…"`） |
| **PAK 文件数识别** | `0x0193` (403 个文件) | LEAFPACK 头部 u16 声明，唯一锚定《雫》Windows 版 |
| **脚本解压环形缓冲** | `0x1011` | `lzs3` 倒排旗标（`~flag`）解压，输出严格按段头截断 |
| **点阵字库物理尺寸** | `133,344` 字节 | 1,852 字，每字 24×24 像素、1bpp、72 字节（3 列垂直扫描带） |
| **叶码寻址基准** | `1-based` 直接数组下标 | 字符物理地址偏移 = `(leaf_code - 1) * 72` |
| **Sound Novel 文本网格** | `25 列 × 13 行` | 24px 单字间距，字距 1px、行距 6px，边缘安全内边距 20px |
| **隐藏音乐室入口坐标** | `(X=448, Y=128)` | 校舍钟楼右上窗格，对应原版 EXE VA `0x430ebc` 处第 5 不可视指针 |
| **音频重采样基准** | `11,025 Hz 单声道 → 44,100 Hz 立体声` | 规避 CoreAudio 立体声节点静默抛出 `NSException` 的致命崩溃 |

---

## 2. 核心二进制数据结构图解

### 2.1 LEAFPACK 归档结构 (`MAX_DATA.PAK`)

```text
+-------------------+--------------------+------------------------+---------------------+
| "LEAFPACK" (8B)   | FileCount (2B LE)  | Payload Data Stream    | Directory Table     |
| Magic Identifier  | Total = 403 Files  | Cumulative Additive    | 24B * 403 Entries   |
| 0x00 - 0x07       | 0x08 - 0x09        | 0x0A ... End-9672      | End-9672 ... EOF    |
+-------------------+--------------------+------------------------+---------------------+
```

### 2.2 SCN 剧情脚本物理结构 (`SCN%03d.DAT`)

```text
+---------------------+---------------------+---------------------+---------------------+
| EventOffset (2B LE) | MsgOffset (2B LE)   | Event Block Data    | Message Stream Data |
| Offset = Val * 0x10 | Offset = Val * 0x10 | u32 UncompressedSz  | u32 UncompressedSz  |
| 0x00 - 0x01         | 0x02 - 0x03         | + Inverted LZS3     | + Inverted LZS3     |
+---------------------+---------------------+---------------------+---------------------+
```

---

## 3. Swift 现代重构核心模块定义

```swift
// ShizukuCore: 二进制流与格式解码
public struct LeafPackArchive {
    public let entries: [LeafPackEntry]
    public func extract(entry: LeafPackEntry) -> Data
}

// ShizukuEngine: 双层虚拟机协同
public final class ScenarioEngine {
    public func advanceEvent() -> EngineStepResult
    public func stepInlineMacro() -> InlineToken?
}

// ShizukuRender: Metal 管线与 13 种转场
public final class MetalGameRenderer: MTKViewDelegate {
    public func setTransition(type: TransitionType, duration: TimeInterval)
    public func renderFrame(into view: MTKView)
}
```

---

## 4. 逆向分析工具链命令速查

```bash
# 解包全量 PAK 文件至目录
python3 tools/scripts/shizuku-unpack.py path/to/MAX_DATA.PAK -o output/

# 生成 24x24 点阵字库全图纹理（1,852 字）
python3 tools/scripts/shizuku-knj-font.py path/to/KNJ_ALL.KNJ --atlas preview/knj_atlas.png

# 解码指定 LFG 图像（输出 PNG）
python3 tools/scripts/shizuku-lfg-image.py path/to/HVS01.LFG -o preview/hvs01.png

# 反汇编特定 SCN 脚本为人类可读汇编文本
python3 tools/scripts/shizuku-scn-disasm.py path/to/SCN001.DAT -o SCN001.txt
```
