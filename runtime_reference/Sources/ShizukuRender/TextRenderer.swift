//
//  TextRenderer.swift
//  ShizukuRender
//
//  Rasterizes SCN message glyph leaf codes with the CN KNJ font (identity:
//  slot = leaf code). Draws a 24x24 0/1 pixel matrix (row-major, from KnjFont.pixels).
//

import Foundation
import ShizukuCore

public struct TextRenderer {
    let font: KnjFont
    let map: GlyphMap
    let scale: Int

    public init(font: KnjFont, map: GlyphMap = GlyphMap(), scale: Int = 4) {
        self.font = font
        self.map = map
        self.scale = scale
    }

    public let glyphWidth = 24
    public let glyphHeight = 24

    /// Render a list of leaf codes into a target at (originX, originY), wrapping
    /// at `charsPerLine`. Returns the index of the next line origin.
    @discardableResult
    public func draw(_ leaves: [Int], into img: inout RGBAImage,
                     x: Int, y: Int, charsPerLine: Int = 26,
                     ink: (UInt8, UInt8, UInt8) = (0, 0, 0)) -> Int {
        var cx = x
        var cy = y
        var count = 0
        for leaf in leaves {
            if count > 0 && count % charsPerLine == 0 {
                cx = x; cy += glyphHeight * scale + 6; count = 0
            }
            if leaf == 0 {
                cx += glyphWidth * scale + 2
                count += 1
                continue
            }
            if let px = font.pixels(map.slot(forLeaf: leaf)) {
                drawGlyphMatrix(px, into: &img, x: cx, y: cy, ink: ink)
            }
            cx += glyphWidth * scale + 2
            count += 1
        }
        return cy + glyphHeight * scale
    }

    func drawGlyphMatrix(_ matrix: [[Int]], into img: inout RGBAImage,
                         x: Int, y: Int, ink: (UInt8, UInt8, UInt8)) {
        drawGlyphMatrixPublic(matrix, into: &img, x: x, y: y, glyphPx: glyphWidth, scale: scale, ink: ink)
    }

    /// Draw a glyph pixel matrix (glyphPx x glyphPx, 0/1) at (x,y) scaled by `scale`.
    public func drawGlyphMatrixPublic(_ matrix: [[Int]], into img: inout RGBAImage,
                                      x: Int, y: Int, glyphPx: Int, scale: Int,
                                      ink: (UInt8, UInt8, UInt8)) {
        for row in 0..<glyphPx {
            for col in 0..<glyphPx where matrix[row][col] == 1 {
                for sy in 0..<scale {
                    for sx in 0..<scale {
                        img.setPixel(x + col * scale + sx, y + row * scale + sy, ink.0, ink.1, ink.2, 255)
                    }
                }
            }
        }
    }

    /// Estimated message glyph count (packed into lines) — for layout tuning.
    public static func measureLines(_ leaves: [Int], charsPerLine: Int = 26) -> Int {
        let g = leaves.filter { $0 != 0 }.count
        return max(1, (g + charsPerLine - 1) / charsPerLine)
    }
}
