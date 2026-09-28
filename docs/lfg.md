# LFG 图像格式(`LEAFCODE`)

参考实现:lfview `plugins/lfgdec.c`、mglvns `lfg.c`(Go Watanabe)。
已用真实文件验证:HVS01.LFG = 640×400,像素字节数 128,000 = 640×400/2。

## 布局

```
0..7     "LEAFCODE" (8 B magic)
8..31    24 B 调色板(16 色 × 3 通道,4-bit 打包,即 6 B/色)
32..33   u16 BE xoffset
34..35   u16 BE yoffset
36..37   u16 BE width  = (值+1) * 8
38..39   u16 BE height = 值 + 1
40       方向标志(0=VERTICAL 列优先,非 0=HORIZONTAL 行优先)
41       透明色索引 transparent
42..43   保留(实测 00 00)
44..47   u32 LE 解压后像素字节数 size(=width*height/2,每字节存 2 个 4-bit 像素)
48..     LZS 压缩的像素数据(用 leafpack_lzs 解压出 size 字节)
```

调色板字节序:`RG BR GB RG BR …`——每字节高低半字节拆成两个通道,半字节翻倍扩展(`nibble | nibble<<4`)得到 8-bit R/G/B。

像素:解压后每个字节含两个 4-bit 像素(高位先);VERTICAL 模式下按"列内逐行、两列一组"摆放,见 lfg.c 位运算。

## 实测样例(HVS01.LFG)

```
LEAFCODE 00 07 43 a6 ...(palette)... 00 00 00 00 4f 00 8f 01 00 ff 00 00 00 f4 01 00 ...
```
- width=(0x004f+1)*8=640,height=0x018f+1=400,size=0x0001f400=128000,direction=0(垂直),transparent=0xff。

## 已确认属性

- 分辨率 640×400(即"640×400 时代"的原始画布)。
- 16 色调色板(这是雫 95/98 版立绘/背景的典型规格)。
- 立绘带 xoffset/yoffset,用于屏幕定位(背景的偏移为 0)。
- 透明色索引可针对每张图设置。

## 下一步(Phase 2)

- 把 `lfgdec.c` 移植为 Swift/C 解码器,输出 RGBA 到 Metal 纹理。
- 注意 mglvns 曾对特定图做过颜色修正(OP2_MN_W.LFG 白→黑)与 ToHeart 标题透明色修正,雫主流程一般不需要。
