# 系统工程基线与快速技术参考手册
## ——Leaf LVNS 引擎核心常量、内存映射与架构接口速查 (Ver.1.5)

> 🌐 **Language / 多语言**: [🇨🇳 简体中文](RESUME_PROMPT.md) ｜ [🇺🇸 English](RESUME_PROMPT-en.md) ｜ [🇯🇵 日本語](RESUME_PROMPT-jp.md)

---

## 1. 核心常量与关键基准速查表

为方便开发者与逆向工程研究者快速查验，本节汇总了《雫～しずく～》macOS 原生重构版（Ver.1.5 双版本）全部实机已验证的基准常量：

| 参数类别 | 物理常量 / 键值 / 偏移 | 含义与工程约束 |
|---|---|---|
| **画布基础分辨率** | `640 × 400` | 原始 16:10 渲染目标，Metal 整数倍等比居中拉伸至视网膜屏幕 |
| **刷新率与同步** | `60.0 Hz` | `CVDisplayLink` 严格锁相，注入 `ProcessInfo.beginActivity` 规避 App Nap 节流 |
| **PAK 滚动加法密钥** | `71 48 6a 55 9f 13 58 f7 d1 7c 3e` | 11 字节加法循环密钥（对应 ASCII `"qHjU…"`） |
| **PAK 文件数识别** | `0x0193` (403 个文件) | LEAFPACK 头部 u16 声明，唯一锚定《雫》Windows 版资产 |
| **脚本解压环形缓冲** | `0x1011` | `lzs3` 倒排旗标（`~flag`）解压，输出严格按段头声明硬截断 |
| **日文点阵字库物理尺寸** | `133,344` 字节 | 1,852 字，每字 24×24 像素、1bpp、72 字节（3 列垂直扫描带） |
| **日文叶码寻址基准** | `1-based` 直接数组下标 | 字符物理地址偏移 = `(leaf_code - 1) * 72` |
| **中文点阵字库物理尺寸** | `340,272` 字节 | 4,726 槽（`cnfont_4726.bin`），前 1,852 槽同日文，后部为汉化扩充字模 |
| **中文码表映射规模** | `2,872` 字符 | 经模糊平移 NCC + 词频先验单调 DP 求解（`cn_code2char.json`） |
| **全量中文语料库** | `3,834` 译文条目 | 覆盖全剧本 195 个 SCN（`zh_text.json`），按 JP 节拍比例切片推进 |
| **PC-98 FM 音频包** | 24 首 OGG (43.3 MiB) | YM2608 (OPNA) 原机硬件内录，Ogg Vorbis q5 44.1kHz |
| **FM 无缝循环定位点** | `MUS11`: 8.750s / `MUS16`: 9.000s | 前奏播放一次，随后在循环点无缝进入硬件循环 |
| **FM 单次播放曲目** | 6 首曲目（MUS00/14/17/18/20/23） | 音楽モード 下播放一次后停止（间隙静音 $\le -91\text{ dB}$） |
| **选择肢文字网格排布** | 原生 tvram 网格 + `choiceRowGap = 1` | 选项按 `'X' * 8` 偏置定位，选项间添加 1 行垂直呼吸空行 |
| **局外成长共享旗标** | `[0x00, 0x01, 0x45, 0x46]` | 对齐 GBA SRAM `0x10` 4 旗标，读档重施与存档持久化，根治幽灵选择肢 |
| **文字打印与快进时钟** | 显影 30ms (2 flips) / 快进慢档 17/60s | 依据 `Sizuku.exe` 反汇编修正，慢档快进为 59.1 字/秒 |
| **确定性视觉回归基线** | `113 / 113` 确定帧 | 沙箱化 `SaveClock` 冻结时钟，严格比对 `MANIFEST.sha256` |
| **双版本正式分发物** | `build/` (JP) / `build_chs/` (ZH) | `Shizuku_Restored_Ver.1.5.dmg` 与 `Shizuku_Restored_CHS_Ver.1.5.dmg` |

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

## 3. Swift 现代重构核心模块定义 (Ver.1.5)

```swift
// ShizukuCore: 二进制流、汉化字模与数据模型
public struct LeafPackArchive { ... }
public final class CnDotFont {
    public static func glyphData(forLeafCode code: Int) -> Data?
    public static func unicode(forLeafCode code: Int) -> Character?
}

// ShizukuEngine: 双层虚拟机、双音源调度与跨语言存档
public final class Engine {
    public var bgmSource: Int // 0=Windows原声, 1=PC-98 FM音源
    public var language: GameLanguage // .jp 或 .zh (构建期常量)
    public func sliceChineseText(_ text: String, jpBeats: Int) -> [String]
    public func skipCNEmptyBeats()
}

// ShizukuRender: Metal 管线、原版文字网格与 13 种转场
public final class SceneComposer {
    public static let choiceRowGap: Int = 1 // 选择肢垂直呼吸空行
    public func drawCNMatrixText(...)
    public func choiceOptionRects(engine: Engine) -> [(option: Int, rect: CGRect)]
}

// ShizukuApp: AppKit 宿主、SwiftUI 关于窗口与 113 帧回归工装
public final class AppDelegate: NSObject, NSApplicationDelegate {
    public func showAbout(_ sender: Any?) // 原生 SwiftUI 关于窗口
}
```

---

## 4. 逆向分析与回归验证工具链速查

```bash
# 自动化 176 项单元与集成测试回归
swift test

# 无头全量 113 帧确定性视觉基线回归验证（JP / ZH）
SHIZUKU_SHOT=spec ./build/Shizuku_Restored_Ver.1.5.app/Contents/MacOS/ShizukuApp
SHIZUKU_SHOT=spec ./build_chs/Shizuku_Restored_CHS_Ver.1.5.app/Contents/MacOS/ShizukuApp

# 全 13 结局路径无头自动化扫描与回归
SHIZUKU_SHOT=endingscan ./build/Shizuku_Restored_Ver.1.5.app/Contents/MacOS/ShizukuApp

# 汉化感言 15 页全流程端到端检验
SHIZUKU_SHOT=afterword ./build_chs/Shizuku_Restored_CHS_Ver.1.5.app/Contents/MacOS/ShizukuApp

# 双版本原生 DMG 独立签名打包
./package.sh jp && ./package.sh zh
```
