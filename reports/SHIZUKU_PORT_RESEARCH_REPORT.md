# SHIZUKU PORT RESEARCH REPORT

《雫》(Leaf 1996 / 2007 再版硬盤版·AUGUST 漢化) → macOS 26 原生運行 — Phase 0 研究報告
日期:2026-08-17  ·  狀態:Phase 0(資料調查)+ Phase 1(格式識別)完成,已用真實遊戲數據驗證

---

## 0. 執行摘要

**可行性結論:完全可行,且難度比預想低一個量級。**

歷史項目(XLVNS/MGLVNS/lfview/akkera sizuku 系/GBALVNS)已把雫引擎的**容器、圖像、腳本、字體、opcode 全部逆向完畢**,全部以 BSD 許可開源。我們已把它們下載到本地,並對用戶的真實 `MAX_DATA.PAK` 做了**端到端解包驗證**:403 個文件全部解出、SCN 腳本解壓成功、消息文本經 `sizfont.tbl` 還原為通順日文、LFG 幾何信息逐字節吻合(640×400 / 128000 像素)。

**本階段最重大發現(需用戶知悉):這份"漢化硬盤版"的劇情文本依然是日文。** 漢化層位於 `Sizuku_cn.exe` 內部(.data 段比原版大 ~336KB,應為中文字體/界面資源),SCN 故事文本未漢化。若目標是"顯示漢化文本",需進一步核實漢化組的真實工作方式(見 §16 與 §3)。

---

## 1. 原版引擎結構推測

雫/痕/To Heart 共用 Leaf 內部引擎 **LVNS**(Leaf Visual Novel System,copyright 1996-1999 Leaf/AQUAPLUS)。

- **檔案**:`MAX_DATA.PAK`(LEAFPACK 容器,403 文件)、`bgmfile.PAK`/`soundds.PAK`(LAC 容器)、`OPTSET.DAT`(運行期存檔,格式未明)、`Sizuku.exe`。
- **數據流**:引擎啟動 → 打開 max_data.pak → 按需取 `SCN%03d.DAT`(LZS 解壓)→ 事件段驅動場景,消息段驅動文字/演出 → 調用 `MAX_*.LFG`/`HVS*.LFG`/`VIS*.LFG`(LFG 解碼)、`KNJ_ALL.KNJ`(24×24 字形,顯示時縮到 12×12)、P16(效果音)、bgmfile/soundds(Ogg/WAV)。
- **分辨率**:640×400(已由 LFG 幾何字段實證)。
- **字體**:劇情文字用 K12x10 血統的點陣(經 24×24 KNJ 縮放或直用 12×12);字形按"Leaf 字形碼"索引,`sizfont.tbl`(1851 條)→ SJIS 對照。
- **場景**:197 個 SCN 文件,每個含多個 block(塊),塊為跳轉/存檔粒度。

## 2. 文件格式(已確認)

| 文件 | 格式 | 證據 | 解析器 |
|---|---|---|---|
| `MAX_DATA.PAK` | LEAFPACK(magic + u16 文件數 + XOR 11 字節滾動密鑰 + 尾部目錄) | 解包 403/403 成功,file_num==0x193 即雫 | `leafpack.c` / 自寫 `unpack_leafpack.py` |
| `bgmfile.PAK` | LAC(magic + u32 數 + 42B 條目:偏移+36/長度+40) | hexdump + OggS 對齊,23/25 命中 | 自寫解析 |
| `soundds.PAK` | LAC(同上) | 13/13 命中 | 自寫解析 |
| `*.LFG` | LEAFCODE(見 §4) | 逐字節吻合 | `lfg.c`/`lfgdec.c` |
| `SCN*.DAT` | SCN(見 §5) | decscn.py 驗證 + 解壓 | `decscn.py`/`script.c` |
| `KNJ_ALL.KNJ` | 24×24 點陣字形 1852 個(=133344B) | 字節數精確吻合 | 無需解析,直接位圖 |
| `SZ_VD*.P16` | 16-bit PCM(4B 頭+數據) | 波形統計 | 無需解析 |
| `OPTSET.DAT` | 存檔,格式未明 | — | 待逆向 |

## 3. 腳本格式(已確認)

見 `docs/research/scripts.md`。要點:

- SCN = `[u16 事件段偏移(×16)][u16 消息段偏移(×16)] + 事件段(u32 大小 + LZS3) + 消息段(u32 大小 + LZS3)`。
- 事件段 = `[u16 末塊號][塊 0..N 偏移表][塊事件流]`;塊為跳轉/存檔粒度。
- 事件 opcode(0x00 End/0x04 Jump/0x05 Select/0x0a 背景/0x16 H場景/0x22 立繪/0x3d-3e 條件/0x47-48 旗標/0x54 消息/0x6e BGM/0x7c-7e 結局/…)與 sizuku_gba2、GBALVNS `EVTDef.s` 完全一致(置信度:高)。
- 消息段 = `[u16 末條號][每條偏移表][消息流]`;文本命令:`$` 結束、`p` 翻頁、`k` 鍵等、`r` 換行、`B`/`C`/`S`/`A`/`D`/`E`/`V`/`H` 畫面、`M`/`P` 音頻、`Q`/`F` 效果等。
- **文本編碼 = Leaf 字形碼**(2 字節,高位為標誌),經 `sizfont.tbl` 對映 SJIS。
- **實證:SCN001/100/125/173/174 消息經還原全部為通順日文**。漢化組未改 SCN 故事文本(置信度:高);漢化在 EXE 內。

## 4. 圖像格式(已確認)

見 `docs/research/lfg.md`。`LEAFCODE` 頭:8B magic + 16 色 4-bit 調色板 + 幾何(u16 BE,寬/高/偏移)+ 方向/透明 + u32 像素字節數 + **LZS 壓縮位圖**(leafpack_lzs)。實測 640×400、size=128000。立繪帶 x/y offset 用於定位;透明色索引按圖設置。

## 5. 音頻格式(已確認)

見 `docs/research/audio.md`。BGM=Ogg Vorbis(25 曲,LAC 容器)、SE=RIFF/WAV(13 條)、效果音=P16(16-bit PCM)。macOS 直接解包後餵給 AVAudioEngine,無需任何轉碼(8AD 是 GBA 特化,不採用)。

## 6. Save 格式(未確認)

- 原版運行期寫 `OPTSET.DAT`(EXE 字符串實證),可能配合註冊表 `Software\Leaf\`。
- 內容推測 = `(scnNo, blkNo, 塊內偏移, 旗標[0..], BGM, …)`(存檔/回溯粒度與 block 機制吻合)。
- **下一步**:Wine/VM 運行原版生成存檔樣本 → 逆向;或逆向 EXE。若非易兼容則自建 JSON/二進制存檔(項目需求已允許)。

## 7. GBA 項目分析(sizuku advance / sizuku_gba2)

見 `docs/research/sizuku-gba.md`。akkera102 四個 zip 已下載(76-79),含 **`decscn.py`(SCN 解包)、`script.c`(原版 opcode 解釋器)、`anime.c`(特效引擎)**、字體工具。確認工具鏈直接解析原版數據。

## 8. XLVNS/MGLVNS 分析

見 `docs/research/history.md`。mglvns-1.0(BSD)完整下載並解包,含 LEAFPACK 讀取器、LFG 解碼器、三作差異模塊與整套 VN 運行時(Lvns*)。XLVNS 獨立 1.6b 包存於 Wayback(當前 IA 整體離線,待補抓);其核心已由 mglvns 覆蓋。

## 9. GBALVNS 分析

見 `docs/research/gbalvns.md`。**明確結論:GBALVNS 是自帶資產管線的 GBA 引擎,不直接讀 Windows 原版數據**;其價值 = opcode 交叉驗證 + 運行時狀態機藍本 + 12×10 字體渲染參考。BSD-3 許可。

## 10. 已知 opcode

事件:0x00/0x01(子1/2/3/4)/0x04/0x05/0x07/0x0a/0x14/0x16/0x22/0x24/0x28/0x38/0x3d/0x3e/0x47/0x48/0x54/0x6e/0x7c/0x7d/0x7e/0xff(見 §3,全部有 script.c 出處)。文本:`$`/`p`/`k`/`K`/`r`/`B`/`C`/`D`/`S`/`A`/`a`/`E`/`V`/`H`/`M`/`P`/`Q`/`F`/`X`/`s`。

## 11. 未知 opcode

見 `docs/research/unknown-opcodes.md`:0x02/0x03/0x06/0x08/0x09/0x0b/0x5a/0x5c/0x60-0x66/0x6f/0x73 等(多數位於非順序執行區,未必是 opcode);文本 `0`、`X`/`s` 參數細節。OPTSET.DAT、P16 頭、塊表精確語義待 Phase 3/6 用原版 Wine 為 oracle 驗證。

## 12. 可復用代碼(許可已核)

| 代碼 | 許可 | 位置 |
|---|---|---|
| `leafpack.c`(LEAFPACK 讀) | BSD(Go Watanabe) | research/thirdparty/mglvns |
| `lfg.c` / `lfgdec.c`(LFG 解碼) | BSD / Leaf 許可(free) | mglvns / lfview |
| `decscn.py`(SCN 解包) | 個人用(akkera102) | research/thirdparty/akkera |
| `script.c`(opcode 語義) | 個人用 | 同上 |
| GBALVNS(狀態機/字體) | BSD-3 | research/gbalvns |
| `unpack_leafpack.py`(本項目移植) | BSD 衍生 | research/tools |

> 轉載注意:akkera 工具與 lfview 為"個人使用/免費分發"許可,移植/複用時保留出處;勿把遊戲數據提交進 Git。

## 13. 建議技術棧

- **核心解析器**:Swift(直接把上述 C/Python 邏輯移植為 Swift,或保留 C 核心 + Swift 前端)。歷史代碼邏輯簡單(位運算/LZSS),Swift 移植成本低。
- **圖形**:Metal(640×400 整數倍縮放:1280×800/1920×1200/2560×1600;nearest/bilinear 可選)。
- **文字**:CoreText 作 glyph atlas → Metal 紋理;中/日文標點、斷行以 CoreText 斷行保證。注意原版是點陣 12×12 語境,精確還原需用 KNJ/sizfont 的位圖方案(兩者皆可做,先 CoreText 保正確性,再可選位圖模式)。
- **音頻**:AVAudioEngine(Ogg/WAV/PCM 直接播放,循環/淡出由引擎控制)。
- **輸入**:鍵盤(Enter/Space/Esc/↑↓/Ctrl/Alt+F4/PageUp-Down)+ 鼠標(左鍵推進、右鍵菜單)。
- **存檔**:先嘗試解析 OPTSET.DAT;否則自建。
- **CLI 先行**:`shizuku-cli`(inspect/extract/disassemble/run)→ `Shizuku.app`。

## 14. 項目架構(建議)

```
ShizukuCore   — LEAFPACK/LAC 容器、LFS 解壓、SCN 解析、IR
ShizukuParser — SCN 反彙編、opcode 表、未知 opcode 日誌
ShizukuImage  — LFG 解碼 → RGBA;12×10/KNJ 字體
ShizukuAudio  — Ogg/WAV/PCM 播放(AVAudioEngine)
ShizukuEngine — 事件/消息/選擇/旗標/歷史/存檔 狀態機(借鑑 Lvns*/script.c)
ShizukuCLI    — inspect / extract / disassemble / run
ShizukuApp    — Metal 窗口、縮放、全屏、偏好
```

中間表示(IR)按原版 opcode 直接建模(不必另造抽象):事件節點 → 表現層(BG/CHR/MSG/BGM/效果/等待/跳轉/選擇/旗標)。

## 15. 風險

| 風險 | 等級 | 緩解 |
|---|---|---|
| 漢化文本不在 SCN 中(日文原文) | 高(需求層) | 先向用戶確認漢化版實際效果(§16 步驟 1) |
| 低使用率 opcode 語義不明 | 中 | Wine 運行原版為 oracle;未知即 IR 保留 + 兼容模式 fallback |
| OPTSET.DAT 存檔格式未知 | 中 | 自建存檔,不阻塞 |
| 選擇/塊表控制流細節 | 中 | 反彙編器統計 + 原版比對 |
| LAC/P16 細節 | 低 | 已可解包,播放即可 |
| 2007 版 vs 1996 初版差異 | 低 | 本拷貝即 2007 數據,格式一致 |
| 字形碼→顯示 的精確還原 | 低-中 | CoreText 保正確;位圖模式作選項 |

## 16. 下一步(需要用戶的輸入)

### 現在就需要用戶做

1. **確認漢化版實際畫面**:請在 Windows/Wine 下運行一次 `Sizuku_cn.exe`,截圖開場文字。目的是確認"漢化到底漢化了什麼"(我的實證傾向:故事仍為日文,漢化在界面層)。這直接決定"漢化文本"是否為本項目標。
2. **(可選)提供原版日文 `Sizuku.exe` 對照運行**:用於 opcode 行為 oracle(不強制,可之後再做)。
3. **確認目標平台**:Apple Silicon 的 macOS 26(默認)。

### 我已完成的交付物

- `docs/research/original-files.md`(§37 step 8 的文件清單)
- `docs/research/containers.md` / `lfg.md` / `scripts.md` / `audio.md` / `history.md` / `sizuku-gba.md` / `gbalvns.md` / `unknown-opcodes.md`
- `research/tools/unpack_leafpack.py`(LEAFPACK 解包器,已對真實數據驗證)
- `research/extracted/`(403 個文件已解包,供後續解析開發;不進 Git)

### 下一步工程(Phase 2)

待你確認第 1 點後啟動:先做 `shizuku-cli inspect/extract/disassemble`,把 197 個 SCN 全部反彙編、把 195 張 LFG 全部解出 PNG 供人工比對,再進入最小 Runtime。
