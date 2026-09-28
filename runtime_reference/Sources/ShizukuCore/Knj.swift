//
//  Knj.swift
//  ShizukuCore
//
//  KNJ font (24x24 1bpp, column-major, 3 columns of 24 contiguous bytes).
//  - Each glyph = 72 bytes = 3 columns x 24 rows; bit7 = topmost pixel of the column.
//  - glyph[col*24 + row]; used by both JP and CN fonts (container identical, content differs).
//
//  VERIFIED correct layout: col-major. decode_col_major reproduces the coherent-Chinese
//  reference (research/cn_dump/confirm/visual_cn_0_60.png: 徐除僊勝唱將小少床掌...) EXACTLY.
//  The earlier "row-major glyph[row*3+col]" claim was WRONG — it produced fragmented glyphs.
//  The verify_font_layout.py --check metric (empty-row/transition) is a false positive.
//
//  CN汉化 ≠ 纯字库内容替换: slot N ≠ leaf N for the CN font. Empirically, cn_font[leaf]
//  and cn_font[firstUseRank(leaf)] both render garbage, while the JP font renders coherent
//  kana/kanji for the same leaves. The CN engine resolves leaf → slot via a runtime table
//  (see GlyphMap). Text renderers must route leaf codes through GlyphMap.slot(forLeaf:).
//

import Foundation

public struct KnjFont {
    public let data: [UInt8]
    public static let glyphSize = 72
    public let glyphCount: Int

    public init(data: [UInt8]) {
        self.data = data
        self.glyphCount = data.count / KnjFont.glyphSize
    }

    /// nil when the file is missing/unreadable — callers decide the fallback;
    /// a missing font must not take down app startup.
    public init?(path: String) {
        guard let d = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }
        self.init(data: [UInt8](d))
    }

    public func isValidSlot(_ slot: Int) -> Bool {
        return slot >= 0 && slot < glyphCount
    }

    /// Raw 72-byte glyph for a slot, nil if out of range.
    public func glyph(_ slot: Int) -> [UInt8]? {
        guard isValidSlot(slot) else { return nil }
        let base = slot * KnjFont.glyphSize
        return Array(data[base..<base + KnjFont.glyphSize])
    }

    /// 24x24 pixel matrix (1 = ink), column-major layout, bit7 = topmost of each column.
    public func pixels(_ slot: Int) -> [[Int]]? {
        guard let g = glyph(slot) else { return nil }
        var out = [[Int]](repeating: [Int](repeating: 0, count: 24), count: 24)
        for col in 0..<3 {
            for row in 0..<24 {
                let b = g[col * 24 + row]
                out[row][col * 8 + 0] = Int((b >> 7) & 1)
                out[row][col * 8 + 1] = Int((b >> 6) & 1)
                out[row][col * 8 + 2] = Int((b >> 5) & 1)
                out[row][col * 8 + 3] = Int((b >> 4) & 1)
                out[row][col * 8 + 4] = Int((b >> 3) & 1)
                out[row][col * 8 + 5] = Int((b >> 2) & 1)
                out[row][col * 8 + 6] = Int((b >> 1) & 1)
                out[row][col * 8 + 7] = Int((b >> 0) & 1)
            }
        }
        return out
    }
}
