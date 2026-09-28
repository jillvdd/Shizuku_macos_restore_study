# -*- coding: utf-8 -*-
import os
import json

ROOT = "/Users/abc/Documents/Shizuku_macos_restore_study"

files_to_pack = {
    "/": "README.md",
    "/readme": "README.md",
    "/articles/leaf-galgame-port-zh": "articles/leaf-galgame-port-zh.md",
    "/articles/leaf-galgame-port-en": "articles/leaf-galgame-port-en.md",
    "/articles/leaf-galgame-port-jp": "articles/leaf-galgame-port-jp.md",
    "/docs/containers": "docs/containers.md",
    "/docs/lfg": "docs/lfg.md",
    "/docs/scripts": "docs/scripts.md",
    "/docs/audio": "docs/audio.md",
    "/docs/history": "docs/history.md",
    "/docs/original-files": "docs/original-files.md",
    "/docs/unknown-opcodes": "docs/unknown-opcodes.md",
    "/docs/gbalvns": "docs/gbalvns.md",
    "/docs/sizuku-gba": "docs/sizuku-gba.md",
    "/reports/SHIZUKU_PORT_RESEARCH_REPORT": "reports/SHIZUKU_PORT_RESEARCH_REPORT.md",
    "/reports/HANDOVER": "reports/HANDOVER.md",
    "/reports/MILESTONES": "reports/MILESTONES.md",
    "/reports/RESUME_PROMPT": "reports/RESUME_PROMPT.md"
}

# Create tools overview markdown
tools_md = """# 逆向分析工具链与反编译工程基建
## Reverse Engineering Tooling & Python CLI Suite

本目录整理了本项目逆向工程所开发的 Python 模块化 CLI 工具包及独立研究脚本。

---

## 🧰 1. 模块化命令行工具包 (`tools/shizuku_cli`)

`shizuku_cli` 按照现代 CLI 标准设计，提供了一站式的探查、解密、提取、渲染与反编译命令。

### 核心模块一览

- `leafpack.py`：LEAFPACK 归档容器解密与解包核心算法（含 11 字节累加异或流解密）；
- `lfg.py`：LFG 图像解码、4 位调色板高低位翻倍展开（`(c << 4) | c`）与列主序位交织解析；
- `knj.py`：KNJ 点阵字库（24×24 1bpp，72 字节/字）3 列垂直扫描带解码器；
- `scn.py`：SCN 脚本反编译器，支持事件段 Block 结构化拆解与内联宏指令识别；
- `shizuku-lfg.py`：LFG 图像转换低级实用例程。

### 命令行常用子命令

```bash
# 查看 MAX_DATA.PAK 头部与目录信息
python3 -m tools.shizuku_cli inspect MAX_DATA.PAK

# 全量解包并解密 403 个游戏资产
python3 -m tools.shizuku_cli extract MAX_DATA.PAK -o output_dir/

# 导出并渲染 24x24 KNJ 点阵字库全景图
python3 -m tools.shizuku_cli font KNJ_ALL.KNJ --atlas preview/knj_atlas.png

# 解码单张 LFG 图像并导出为 PNG
python3 -m tools.shizuku_cli image HVS01.LFG -o hvs01.png

# 反编译单个 SCN 脚本为可读汇编文本
python3 -m tools.shizuku_cli disasm SCN001.DAT -o SCN001.txt
```

---

## 🐍 2. 独立研究与验证脚本 (`tools/scripts`)

用于底层算法原型验证与离线校验的独立脚本：

1. **`unpack_leafpack.py`**：独立 LEAFPACK 归档解包工具；
2. **`shizuku-lfg-image.py`**：独立 LFG 图像查看器与格式转换脚本；
3. **`shizuku-knj-font.py`**：独立 KNJ 24×24 点阵字库解析与字形导出脚本；
4. **`shizuku-scn-disasm.py`**：批量反编译 197 个 SCN 脚本生成基准汇编的驱动脚本；
5. **`verify_font_layout.py`**：验证字库物理排布与 Shift-JIS / EUC-JP 对照表一致性的单元测试脚本；
6. **`render_leaf_test.py`**：测试字形排版网格与三 Pass 叠印阴影渲染效果的仿真脚本。
"""

# Create previews gallery markdown
gallery_md = """# 逆向与渲染验证图像产物画廊
## Visual Verification Artifacts & Render Previews

本页面展示逆向推导与格式验证过程中生成的实际渲染与解码产物。

---

## 🔤 1. KNJ 24×24 1bpp 点阵字库全景图 (`preview/knj_atlas.png`)

全字库 133,344 字节解码后得到的 1,852 字完整点阵图集。每个字形采用 3 个垂直 24 字节列块存储，MSB 居左。

![KNJ 24x24 点阵字库图谱](preview/knj_atlas.png)

---

## 👧 2. 立绘资产解码产物 (`preview/hvs01_decoded.png`)

从 `HVS01.LFG` 解压并利用 16 色调色板半字节翻倍展开（`(c << 4) | c`）还原的高保真立绘（女主角月岛琉璃子）。图像高度固定为 400px，全高覆盖游戏视口。

![月岛琉璃子立绘解码](preview/hvs01_decoded.png)

---

## 🖼 3. 背景与测试帧

- **`preview/preview_bg01.png`**：解码出的场景背景原图；
- **`preview/hvs01_from_tool.png`**：由 `shizuku_cli` 工具链端到端渲染的独立角色测试帧；
- **`preview/preview_leaf.png`**：早期调色板与位交织解码测试帧。
"""

docs_bundle = {}

for route, rel_path in files_to_pack.items():
    abs_path = os.path.join(ROOT, rel_path)
    if os.path.exists(abs_path):
        with open(abs_path, "r", encoding="utf-8") as f:
            docs_bundle[route] = f.read()
    else:
        print(f"Warning: {rel_path} does not exist!")

docs_bundle["/tools/overview"] = tools_md
docs_bundle["/preview/gallery"] = gallery_md

out_file = os.path.join(ROOT, "assets/js/docs_data.js")
with open(out_file, "w", encoding="utf-8") as f:
    f.write("window.DOCS_DATA = " + json.dumps(docs_bundle, ensure_ascii=False, indent=None) + ";\n")

print(f"Packed {len(docs_bundle)} documents into {out_file} ({os.path.getsize(out_file)} bytes)")
