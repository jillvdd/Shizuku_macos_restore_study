//
//  Lfg.swift
//  ShizukuCore
//
//  LEAFCODE (LFG) image format. Ported 1:1 from mglvns `lfg.c` / lfview `lfgdec.c`.
//
//  Palette: 24 bytes -> 48 nibbles -> 16 RGB colors (color-major: color k = nibbles
//  3k, 3k+1, 3k+2, each nibble expanded to 8-bit via `(n << 4) | n`). Do NOT force
//  grayscale — that drops the low nibble and renders monochrome.
//
//  Body: `leafpack_lzs` (LZS.lzs) decompresses to `size` bytes, each holding two
//  4-bit palette indices (pix1 = high nibble, pix2 = low nibble). VERTICAL fills
//  column-pair-major (pix1/pix2 side-by-side, then the y advances); HORIZONTAL
//  fills row-major.
//

import Foundation

public struct LfgHeader {
    public let palette: [(Int, Int, Int)]   // 16 RGB
    public let xoffset: Int                  // pixels (x8)
    public let yoffset: Int
    public let width: Int                    // canvas px
    public let height: Int
    public let direction: Int                // 0 = VERTICAL, else HORIZONTAL
    public let transparent: Int              // 0xff = none
    public let contentWidth: Int
    public let contentHeight: Int
    public let size: Int                     // decompressed pixel-body byte count
}

public enum Lfg {
    public static let magic = "LEAFCODE"

    public static func parseHeader(_ data: [UInt8]) -> LfgHeader {
        // 24 bytes -> 48 nibbles, high nibble first per byte.
        var nib: [Int] = []
        for b in data[8..<32] {
            nib.append(Int(b) >> 4)
            nib.append(Int(b) & 0xF)
        }
        var palette: [(Int, Int, Int)] = []
        for k in stride(from: 0, to: 48, by: 3) {
            palette.append((nib[k] * 17, nib[k + 1] * 17, nib[k + 2] * 17))
        }
        func u16(_ o: Int) -> Int { Int(data[o]) | (Int(data[o + 1]) << 8) }
        let xoffset = u16(32) * 8
        let yoffset = u16(34)
        let width = (u16(36) + 1) * 8
        let height = u16(38) + 1
        let direction = Int(data[40])
        let transparent = Int(data[41])
        let size = Int(data[44]) | (Int(data[45]) << 8) | (Int(data[46]) << 16) | (Int(data[47]) << 24)
        return LfgHeader(palette: palette, xoffset: xoffset, yoffset: yoffset, width: width,
                         height: height, direction: direction, transparent: transparent,
                         contentWidth: width - xoffset, contentHeight: height - yoffset,
                         size: size)
    }

    /// Decode to flat RGBA (w*h*4) on the full canvas, content blitted at its offset.
    /// `paletteOverride` repaints the plate's palette from `start` on — the original's
    /// `SizukuLoadBG` colour substitution (day/dusk/night variants of one drawing).
    public static func decode(_ data: [UInt8], paletteOverride: PaletteOverride? = nil) -> ([UInt8], Int, Int)? {
        guard data.count >= 48 else { return nil }
        guard String(bytes: data[0..<8], encoding: .ascii) == magic else { return nil }
        var h = parseHeader(data)
        guard h.contentWidth > 0, h.contentHeight > 0, h.width > 0, h.height > 0,
              h.xoffset < h.width, h.yoffset < h.height,
              // u16 header fields can declare ~500k px plates; real ones top out at 640x400.
              h.width <= 2048, h.height <= 2048 else { return nil }
        // Each body byte carries two 4bpp pixels, so a well-formed stream never
        // needs more than ceil(cw*ch/2) of them; reject inflated `size` before
        // LZS allocates it (corrupt files declare up to 4 GiB).
        let pixelBytes = (h.contentWidth * h.contentHeight + 1) / 2
        guard h.size >= 0, h.size <= pixelBytes + 64 else { return nil }
        if let o = paletteOverride {
            var pal = h.palette
            for (i, c) in o.colors.enumerated() where (0..<pal.count).contains(o.start + i) { pal[o.start + i] = c }
            h = LfgHeader(palette: pal, xoffset: h.xoffset, yoffset: h.yoffset, width: h.width,
                          height: h.height, direction: h.direction, transparent: h.transparent,
                          contentWidth: h.contentWidth, contentHeight: h.contentHeight, size: h.size)
        }
        let body = LZS.lzs(Array(data[48...]), outSize: h.size)

        let cw = h.contentWidth, ch = h.contentHeight, ox = h.xoffset, oy = h.yoffset
        var idx = [Int](repeating: 0, count: cw * ch)

        let direction = h.direction
        if direction == 0 {
            // VERTICAL: column-pair-major. Each byte -> (x,y) and (x+1,y); y advances.
            var x = 0, y = 0
            for p in body {
                guard y < ch, x + 1 < cw else { break }
                idx[cw * y + x] = (Int(p) & 0x80) >> 4 | (Int(p) & 0x20) >> 3 | (Int(p) & 0x08) >> 2 | (Int(p) & 0x02) >> 1
                idx[cw * y + x + 1] = (Int(p) & 0x40) >> 3 | (Int(p) & 0x10) >> 2 | (Int(p) & 0x04) >> 1 | (Int(p) & 0x01)
                y += 1
                if y >= ch { y = 0; x += 2 }
            }
        } else {
            // HORIZONTAL: row-major, two pixels per row step.
            var pos = 0
            for p in body {
                guard pos + 1 < idx.count else { break }
                idx[pos] = (Int(p) & 0x80) >> 4 | (Int(p) & 0x20) >> 3 | (Int(p) & 0x08) >> 2 | (Int(p) & 0x02) >> 1
                idx[pos + 1] = (Int(p) & 0x40) >> 3 | (Int(p) & 0x10) >> 2 | (Int(p) & 0x04) >> 1 | (Int(p) & 0x01)
                pos += 2
            }
        }

        let trans = h.transparent
        var canvas = [UInt8](repeating: 0, count: h.width * h.height * 4)
        for cy in 0..<ch {
            for cx in 0..<cw {
                let p = idx[cy * cw + cx]
                if p == trans { continue }
                let col = h.palette[p]
                let dst = ((oy + cy) * h.width + (ox + cx)) * 4
                canvas[dst] = UInt8(col.0)
                canvas[dst + 1] = UInt8(col.1)
                canvas[dst + 2] = UInt8(col.2)
                canvas[dst + 3] = 255
            }
        }
        return (canvas, h.width, h.height)
    }
}
