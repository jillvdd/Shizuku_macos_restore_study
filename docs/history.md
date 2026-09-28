# 历史项目调研:XLVNS / MGLVNS / lfview / leafpak / PVNS / ZVNS

## 谱系(依据 mzp.hatenablog 考古文 + denpa.org 一手页面)

```
Leaf 雫/痕/To Heart 共享引擎 LVNS (c) 1996-1999 Leaf/AQUAPLUS
  ├─ lfview   (TF 氏,1997-)         图像解码器(LFG/LF2/grp/gad),可从 95 版 archive 直读
  ├─ leafpak  (TF 氏,~2000)          .PAK 解包工具(两种格式:leafpak/leafpak2)
  ├─ PVNS     (yossy 氏,1999)        Palm 移植(基于 SCN 分析与 lfview)
  ├─ XLVNS    (Go Watanabe 氏,1999-) X11 移植,基于 PVNS,吸收 XSystem3.5 声音例程
  │                                    多 OS(BSD 系/Linux/SunOS);denpa.org 托管 CVS/ML
  │                                    LeafBSD CD(Comiket57)含 XLVNS 源码,需 Win95/98 数据
  ├─ ZVNS     (S.TAKe 氏,2000-01)     Zaurus 移植,基于 XLVNS
  └─ MGLVNS   (TF 氏,~2001)          MGL2(NetBSD hpcmips)移植,基于 XLVNS,源码已并入 XLVNS
```

## XLVNS(最关键参考)

- 站点 `leafbsd.denpa.org` 现已失效;`mglvns-1.0.tar.gz` 内含 XLVNS 核心代码(`leafpack.c`、`lfg.c`、`Lvns*.c`、`sizuku*.c`,版权头 `(c) 1999-2001 Go Watanabe`)。
- Wayback 存有 `xlvns1-1.6b.tar.gz` 及补丁(`xlvns10.patch01.gz`、`xlvns20.patch01/02.gz`、`xlvns1-1.6a-1.6b.patch.gz`);**Internet Archive 当前(2026-08-17)整体临时离线**,待恢复后补抓。
- 行为参考:菜单/存档/回想/跳到下一选择等系统功能在 `sizuku_menu.c`/`LvnsHistory.c` 中有成熟实现。

## MGLVNS(mglvns-1.0,BSD 许可)

- 源码已完整下载:`research/thirdparty/mglvns/mglvns-1.0/`。
- 含 **LEAFPACK 读取器(`leafpack.c`)、LFG 解码器(`lfg.c`)、LF2 解码器(`lf2.c`)、字体转换(`mgConvert/pakconv.c`)**,以及三作差异模块(`sizuku_*.c`/`kizuato_*.c`/`toheart_*.c`)。
- 运行时读"转换后的 PAK":`pakconv` 把原版 LFG/KNJ 转成半分辨率 HSB 格式并 LZ77 压缩后重打包;非图像文件(SCN 等)原样透传 → **mglvns 的 SCN 解析即原版解析**。
- 许可:BSD 系(`(c) 2001 TF`/`(c) 1999-2001 Go Watanabe`),注明出处即可复用。

## lfview / leafpak(TF 氏)

- `lfview-1.1a.tgz` 已下载:`research/thirdparty/lfview/`。含 `plugins/lfgdec.c`(LFG 解码)、`leafpak.c`(archive 读)、`leafpak1.c`/`leafpak2.c`(两种 PAK)。
- **注意**:lfview 页面明确"98 版雫/痕的 archive 格式不同,无法显示"——95 版 CD archive ≠ 本项目的 LEAFPACK。故 lfview 的**容器**代码不可直接用(但 LFG 解码可用,与 mglvns lfg.c 同源)。
- `leafpak-1.1.1.tar.gz` 已下载,含 `leafpak.c`/`leafpak2.c` 两种 PAK 读取器,作交叉参考。
- 许可:Leaf 官方允许免费分发;文档建议个人使用、注明来源。

## PVNS / ZVNS

- 均为 XLVNS 系的前后辈,佐证"同一套数据被多个重实现运行时运行"的可行性;源码未直接获取(wayback 链接在考古文中)。本项目不需要单独获取。

## 对我们的直接价值

| 资产 | 位置 | 用途 |
|---|---|---|
| `leafpack.c` 读取器 | mglvns-1.0 | LEAFPACK 容器解析(已移植验证) |
| `lfg.c` / `lfgdec.c` | mglvns / lfview | LFG 图像解码 |
| `decscn.py` | akkera zip | SCN 容器 + LZS 解码 |
| `script.c` | akkera zip | 原版事件/文本 opcode 语义 |
| `sizuku_menu.c`/`LvnsHistory.c` 等 | mglvns | 菜单/存档/回想行为参考 |
