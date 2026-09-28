//
//  HistoryView.swift
//  ShizukuRender
//
//  The ORIGINAL 「シナリオ回想」 fullscreen history mode (雫～しずく～, 1996),
//  replacing the translucent backlog overlay.
//
//  Authoritative behavior:
//   * LvnsHistory.c `LvnsHistoryMode` (mglvns-1.0:56-143): history runs on the SECOND
//     text vram (`current_tvram = 1`), shows ONE recorded message per browsing
//     position, walks positions message-by-message (up = pos-1, down = pos+1; down at
//     the newest position sets cancel → exit; cancel exits; on exit tvram 0 is restored
//     via LvnsDispWindow).
//   * sizuku.c `SizukuDispHistory` (~862-881): per position — LvnsClearText;
//     LvnsDispWindow; re-dispense the whole message via
//     SizukuDispText(..., history_mode=True) (all 'p'/'k' waits skipped), then the nav
//     glyphs: LvnsLocate(CUR_X=25, 0) + LvnsPuts("↑", attr=1) and
//     LvnsLocate(25, 11) + LvnsPuts("↓", attr=2).
//
//  Nav-glyph leaf codes (evidence):
//   * The raw bytes sizuku.c emits are 0xA2 0xAC and 0xA2 0xAD (od-verified; EUC-JP
//     for ↑ U+2191 and ↓ U+2193 — note NOT 0xA1DE/0xA1DF, which are ± and ×).
//   * LvnsPuts (LvnsText.c:109-118) indexes `jis_to_leaf`, built from the font table
//     `sizfont.tbl` where entry index == leaf code (Lvns.c:144-183). Decoding
//     research/extracted/sizfont.tbl: entry 1269 = 0xA2AC (↑), entry 1270 = 0xA2AD (↓).
//   * JP draw is slot = leaf - 1 (sizuku_etc.c drawChar `data + (code-1)*24*3`);
//     dumping KNJ_ALL.KNJ slots 1268/1269 yields clean up/down arrow bitmaps.
//
//  Attr semantics (sizuku_etc.c `drawChar`, Windows non-MGL path): the shadow passes
//  at (x+1,y+1)/(x+2,y+1) are always black; the BODY is SIZUKU_COL_WHITE only when
//  attr == 0 — attr != 0 (our arrows use 1/2) draws the body in SIZUKU_COL_GRAY,
//  which SizukuStart defines as (127,127,127). So nav glyphs render gray-on-black,
//  message text keeps the normal near-white ink.
//
//  Geometry: the original computes XPOS(x,y) = x*24 + row.offset (LvnsInfo.h:57) and
//  LvnsClearText resets every row offset to 16, so the CUR_X=25 glyph lands at
//  25*24+16 = 616 — flush against the 640px right edge, no clip, clear of the 25
//  message columns. Rows follow this port's own text grid (SceneComposer.textOriginY,
//  lineAdvance) so the arrows align with the drawn text rows: up = row 0, down = row 11.
//

import Foundation
import CoreGraphics
import AppKit
import ShizukuCore
import ShizukuEngine

public enum HistoryView {

    /// One browsing position: the FULL text of one recorded message, as JP leaf-code
    /// lines in the same shape as `engine.displayedLines` / `BacklogEntry.lines`
    /// (leaf 0 / `Message.tokSpace` = full-width space cell).
    public struct Entry {
        public let lines: [[Int]]
        /// pos == 0: up-navigation is a no-op in the original (LvnsHistory.c:106).
        public let isFirst: Bool
        /// pos == history_pos-1: down-navigation EXITS history mode (LvnsHistory.c:121-123).
        public let isLast: Bool
        /// Source coordinates in the translation store (-1 = none).
        public let scn: Int
        public let msg: Int

        public init(lines: [[Int]], isFirst: Bool, isLast: Bool, scn: Int = -1, msg: Int = -1) {
            self.lines = lines
            self.isFirst = isFirst
            self.isLast = isLast
            self.scn = scn
            self.msg = msg
        }
    }

    // MARK: - Leaf codes & layout constants

    /// sizfont.tbl entry for EUC-JP 0xA2AC '↑' (sizuku.c:878 emits it with attr=1).
    public static let upArrowLeaf = 1269
    /// sizfont.tbl entry for EUC-JP 0xA2AD '↓' (sizuku.c:880 emits it with attr=2).
    public static let downArrowLeaf = 1270

    /// Non-MGL CUR_X from sizuku.c SizukuDispHistory (`#define CUR_X 25`).
    public static let curXColumn = 25

    /// Native x of the arrow column: XPOS(25, y) = 25*24 + row.offset(16 after
    /// LvnsClearText) = 616; the 24px cell ends exactly at the 640px frame edge.
    public static let arrowOriginX = 616

    /// Rows the two glyphs occupy (LvnsLocate(CUR_X, 0) / (CUR_X, 11)).
    public static let upArrowRow = 0
    public static let downArrowRow = 11

    /// sizuku.c SizukuStart: SIZUKU_COL_GRAY = (127,127,127) — drawChar uses it for
    /// every glyph whose attr != 0, i.e. both nav arrows.
    static let inkNavGlyph: (UInt8, UInt8, UInt8) = (127, 127, 127)

    /// Convenience: build the Entry for one position of an engine backlog array.
    /// The App owns the browsing position; this just maps it onto `BacklogEntry`s.
    public static func entry(from backlog: [BacklogEntry], pos: Int) -> Entry? {
        guard pos >= 0, pos < backlog.count else { return nil }
        return Entry(lines: backlog[pos].lines,
                     isFirst: pos == 0,
                     isLast: pos == backlog.count - 1,
                     scn: backlog[pos].scn,
                     msg: backlog[pos].msg)
    }

    // MARK: - Rendering

    /// One screen of the original fullscreen history mode onto a copy of `backdrop`
    /// (the *image layer only* — background and portraits, as the original keeps them
    /// while `LvnsClearText` empties the text vram). History runs in text mode, so
    /// `LvnsDispWindow` shows the artwork at `latitude_dark = 11/16`; that dimming is
    /// applied here rather than by the caller.
    ///
    /// Signature note vs. the original sketch: takes `game: GameData` — glyph
    /// rasterization needs the KNJ font + leaf→slot routing (`game.textSlot(forLeaf:)`)
    /// exactly as SceneComposer's text path does, and those live on GameData.
    ///
    /// Line budget (long messages): the original has NO scroll — `LvnsNewLineText`
    /// just increments cur_y and the overflow rows draw below the visible frame
    /// (TEXT_HEIGHT=16 vs. ~13 visible rows at 28px pitch). We mirror that: draw the
    /// FIRST `SceneComposer.linesPerScreen` lines, each clipped to
    /// `SceneComposer.charsPerLine` cells; the remainder is simply not shown.
    public static func render(game: GameData, backdrop: RGBAImage, entry: Entry, scale: Int,
                              cnText: String? = nil) -> RGBAImage {
        var img = backdrop
        img.scaleRGB(by: 11, of: 16)   // latitude_dark, as LvnsDispWindow does in text mode
        let s = scale
        let tr = TextRenderer(font: game.cnFont, scale: s)

        if let cnText {
            // ZH history: same 22-col wrap as the message layer, drawn with the
            // CN patch dot matrix; overflow clipping mirrors the JP path.
            let lines = ShizukuEngine.paginateChinese(cnText, charsPerLine: 22, linesPerPage: 99)
                .flatMap { $0 }
            for (row, line) in lines.prefix(SceneComposer.linesPerScreen).enumerated() {
                let y = (SceneComposer.textOriginY + row * SceneComposer.lineAdvance) * s
                let x = SceneComposer.textOriginX * s
                SceneComposer.drawZHText(into: &img, text: line, x: x, y: y,
                                         ink: (240, 240, 240), shadow: SceneComposer.inkShadow,
                                         scale: s, game: game, fontSize: 20)
            }
        } else {
            // Message body: identical grid + 3-pass overprint as drawTextLayer
            // (shadow at +1/+2 px, body at 0; drawChar sizuku_etc.c:531-539).
            for (row, line) in entry.lines.prefix(SceneComposer.linesPerScreen).enumerated() {
                let y = (SceneComposer.textOriginY + row * SceneComposer.lineAdvance) * s
                var x = SceneComposer.textOriginX * s
                for cell in line.prefix(SceneComposer.charsPerLine) {
                    if cell == Message.tokSpace {   // leaf 0: advance one cell, draw nothing
                        x += SceneComposer.glyphAdvance * s
                        continue
                    }
                    if let px = game.cnFont.pixels(game.textSlot(forLeaf: cell)) {
                        drawGlyph3Pass(px, into: &img, tr: tr, x: x, y: y, s: s,
                                       ink: SceneComposer.inkText, shadow: SceneComposer.inkShadow)
                    }
                    x += SceneComposer.glyphAdvance * s
                }
            }
        }

        // Nav glyphs, attr=1/2 → gray body under the same black shadow passes.
        // The original always draws BOTH arrows regardless of position
        // (SizukuDispHistory has no bounds test around the LvnsPuts calls);
        // isFirst/isLast exist for the caller's navigation (up@first = no-op,
        // down@last = exit, LvnsHistory.c:105-125).
        drawArrow(game: game, tr: tr, into: &img, leaf: upArrowLeaf,
                  row: upArrowRow, s: s)
        drawArrow(game: game, tr: tr, into: &img, leaf: downArrowLeaf,
                  row: downArrowRow, s: s)

        // Flatten to fully opaque, as the normal render path does.
        for i in stride(from: 3, to: img.pixels.count, by: 4) { img.pixels[i] = 255 }
        return img
    }

    // MARK: - Hit rects

    /// ↑ hit rect, in the same device-pixel space `render` draws into
    /// (native cell (616, 18) at 24x24, times scale).
    public static func upArrowRect(scale: Int) -> CGRect {
        arrowRect(row: upArrowRow, scale: scale)
    }

    /// ↓ hit rect, same space (native cell (616, 326) at 24x24, times scale).
    public static func downArrowRect(scale: Int) -> CGRect {
        arrowRect(row: downArrowRow, scale: scale)
    }

    private static func arrowRect(row: Int, scale: Int) -> CGRect {
        CGRect(x: CGFloat(arrowOriginX * scale),
               y: CGFloat((SceneComposer.textOriginY + row * SceneComposer.lineAdvance) * scale),
               width: CGFloat(SceneComposer.glyphAdvance * scale),
               height: CGFloat(SceneComposer.glyphAdvance * scale))
    }

    // MARK: - Internals

    private static func drawArrow(game: GameData, tr: TextRenderer, into img: inout RGBAImage,
                                  leaf: Int, row: Int, s: Int) {
        guard let px = game.cnFont.pixels(game.textSlot(forLeaf: leaf)) else { return }
        drawGlyph3Pass(px, into: &img, tr: tr,
                       x: arrowOriginX * s,
                       y: (SceneComposer.textOriginY + row * SceneComposer.lineAdvance) * s,
                       s: s, ink: inkNavGlyph, shadow: SceneComposer.inkShadow)
    }

    /// The drawChar triple-stamp: black at (x+1,y+1) and (x+2,y+1), body at (x,y).
    private static func drawGlyph3Pass(_ px: [[Int]], into img: inout RGBAImage, tr: TextRenderer,
                                       x: Int, y: Int, s: Int,
                                       ink: (UInt8, UInt8, UInt8),
                                       shadow: (UInt8, UInt8, UInt8)) {
        tr.drawGlyphMatrixPublic(px, into: &img, x: x + 2 * s, y: y + s,
                                 glyphPx: 24, scale: s, ink: shadow)
        tr.drawGlyphMatrixPublic(px, into: &img, x: x + s, y: y + s,
                                 glyphPx: 24, scale: s, ink: shadow)
        tr.drawGlyphMatrixPublic(px, into: &img, x: x, y: y,
                                 glyphPx: 24, scale: s, ink: ink)
    }
}
