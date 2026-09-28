//
//  SceneComposer.swift
//  ShizukuRender
//
//  Composes the current engine Scene (background + portraits + message text)
//  into an RGBAImage at 640x400 (optionally integer-scaled). Text uses the CN font
//  with the leaf→slot map; falls back to identity (JP) when no table is attached.
//
//  Typography is the Sound-Novel full-screen layout of the original, NOT a bottom
//  dialogue box: the whole 640x400 frame is the text canvas, the background is dimmed
//  while text is up, and glyphs carry a 1px hard shadow. Constants come from
//  `research/thirdparty/mglvns/mglvns-1.0/LvnsInfo.h` (XPOS/YPOS) and the GBA port's
//  `text.c`/`img.c`.
//

import Foundation
import CoreGraphics
import AppKit
import ShizukuCore
import ShizukuEngine

public struct SceneComposer {
    public let game: GameData
    public let scale: Int
    public let nativeWidth = 640
    public let nativeHeight = 400

    /// M5.6 WP-7a: which shell string table the menus draw from — a *build*
    /// property (`BuildLanguage.current`), not runtime state. `.jp` keeps the
    /// original leaf dot matrix verbatim; `.zh` routes shell text through the
    /// native CJK font. Story text is unaffected (that is `engine.language`).
    public let language: GameLanguage

    /// Text grid, native pixels. `XPOS(x,y) = x*24 + row_offset`, `YPOS(y) = y*28 + 8`.
    public static let textOriginX = 20
    public static let textOriginY = 18
    public static let glyphAdvance = 24
    public static let lineAdvance = 28
    /// Cells per line / lines per screen. 25x13 leaves a margin inside 640x400 at 24x28.
    public static let charsPerLine = 25
    public static let linesPerScreen = 13

    /// Ink colors. The original draws a black shadow one pixel down-right of a near-white
    /// glyph so text stays legible over any background.
    static let inkText: (UInt8, UInt8, UInt8) = (240, 240, 240)
    public static let inkShadow: (UInt8, UInt8, UInt8) = (10, 10, 10)

    public init(game: GameData, scale: Int = 1, language: GameLanguage = BuildLanguage.current) {
        self.game = game
        self.scale = scale
        self.language = language
    }

    /// Render the scene into a fresh RGBAImage at native*scale.
    public func render(_ engine: ShizukuEngine, selectedChoice: Int = 0, hideText: Bool = false) -> RGBAImage {
        let w = nativeWidth * scale
        let h = nativeHeight * scale
        var img = RGBAImage(width: w, height: h)
        img.fill(0, 0, 0, 255)

        // 'Q' Vibrato shifts the whole artwork by a fresh random ±16 px each flip; the
        // text layer is *not* shifted (it lives in `tvram`, drawn after the flip wait).
        let sx = engine.shakeTicks > 0 ? engine.shakeDX : 0
        let sy = engine.shakeTicks > 0 ? engine.shakeDY : 0

        // Background
        if let bg = sceneImage(image: game.image(name: engine.scene.bgName ?? engine.scene.bgHName ?? "",
                                                paletteOverride: engine.scene.bgOverride)) {
            img.blitScaled(bg, dx: sx * scale, dy: sy * scale, factor: scale)
        }

        // `lvnsSinEffect` (`0x01` kinds 01/02): shear the background plate row-by-row by
        // `sintable[state + row]` *before* `mergeCharacter`, so portraits and text drawn
        // afterwards never distort. Each device row shares one native row index.
        if engine.backEffectActive {
            shearRowsForBackEffect(&img, state: engine.backEffectState)
        }

        // Portraits (bottom-aligned full-height character art at y = 0)
        for p in engine.scene.portraits {
            if let im = sceneImage(image: game.image(name: p.imgName)) {
                img.blitScaled(im, dx: (p.x + sx) * scale, dy: (p.y + sy) * scale, factor: scale)
            }
        }

        // Text mode dims the artwork so the glyphs read. `latitude_dark = 11` out of 16
        // (`Lvns.c`), i.e. brightness scaled by 11/16 ≈ 0.6875 — a ~31% dim, applied to the
        // whole frame before the text layer is drawn over it.
        let hasText = !hideText && (engine.phase == .awaitingMessage || !engine.displayedLines.isEmpty)
        if hasText {
            img.scaleRGB(by: 11, of: 16)
        }

        // Flash / dark effects. 'F' is WhiteOut (16 flips up) then WhiteIn (16 flips
        // down), not a sticky flag — the engine counts the ticks down in the ticker.
        if engine.flashTicks > 0 {
            let progress = ShizukuEngine.flashTotalTicks - engine.flashTicks
            let intensity = progress < 16 ? progress : ShizukuEngine.flashTotalTicks - 1 - progress
            img.blendWhite(Int(255 * max(0, intensity) / 16))
        } else if engine.scene.dark && !hasText {
            img.blendBlack(96)
        }

        // Choice menu: the box sits over the dimmed artwork, and the SELECT prompt
        // text stays visible under it (original renders the prompt before the cursor).
        if engine.phase == .awaitingChoice && !hideText {
            drawChoiceMenu(&img, engine: engine, selectedIndex: selectedChoice)
        }

        // Message text layer
        if !hideText, engine.phase == .awaitingMessage || engine.phase == .awaitingChoice {
            drawTextLayer(&img, engine: engine)
        }

        if engine.phase == .awaitingMessage && !hideText {
            drawContinueIndicator(&img, engine: engine)
        }

        // Flatten to fully opaque so the frame composites cleanly to a window/screen.
        for i in stride(from: 3, to: img.pixels.count, by: 4) { img.pixels[i] = 255 }

        return img
    }

    /// `SinEffect` (`sin_effect.c:131-156`): row `y` shows `background` starting at
    /// `x + shift`; the band left at the far edge keeps the cleared (black) color.
    private func shearRowsForBackEffect(_ img: inout RGBAImage, state: Int) {
        let rowWidth = img.width * 4
        for y in 0..<img.height {
            let shift = SinBackEffect.rowShift(state: state, row: y / scale) * scale
            guard shift != 0 else { continue }
            let rowStart = y * rowWidth
            // Positive shift: `copy_area(background, vram, shift, row, 640-shift, 1, 0, row)`
            // — content slides left and the *right* band is cleared.
            let src = rowStart + max(shift, 0) * 4
            let dst = rowStart + max(-shift, 0) * 4
            let len = (img.width - abs(shift)) * 4
            let moved = Array(img.pixels[src ..< src + len])
            img.pixels.replaceSubrange(dst ..< dst + len, with: moved)
            let bandStart = shift > 0 ? dst + len : rowStart
            for p in stride(from: bandStart, to: bandStart + abs(shift) * 4, by: 4) {
                img.pixels[p] = 0; img.pixels[p + 1] = 0; img.pixels[p + 2] = 0
            }
        }
    }

    /// The image layer (background + portraits) alone — no text, dim, flash or
    /// choices. These are the frames the original keeps in tvram and feeds to
    /// `LvnsClear`/`LvnsDisp`; the text layer is undispensed for the whole effect.
    func renderImageOnly(_ scene: Scene) -> RGBAImage {
        let w = nativeWidth * scale
        let h = nativeHeight * scale
        var img = RGBAImage(width: w, height: h)
        img.fill(0, 0, 0, 255)
        if let bg = sceneImage(image: game.image(name: scene.bgName ?? scene.bgHName ?? "",
                                                paletteOverride: scene.bgOverride)) {
            img.blitScaled(bg, dx: 0, dy: 0, factor: scale)
        }
        for p in scene.portraits {
            if let im = sceneImage(image: game.image(name: p.imgName)) {
                img.blitScaled(im, dx: p.x * scale, dy: p.y * scale, factor: scale)
            }
        }
        for i in stride(from: 3, to: img.pixels.count, by: 4) { img.pixels[i] = 255 }
        return img
    }

    /// Compose one flip of a running LvnsClear→LvnsDisp transition (M4.11):
    /// clearing morphs the shown artwork into black, displaying morphs black (or the
    /// old artwork for disp-only events) into the new one, hold shows the result.
    public func renderTransitionFrame(_ tr: ShizukuEngine.EngineTransition,
                                      engine: ShizukuEngine) -> RGBAImage {
        var img: RGBAImage
        switch tr.phase {
        case .hold:
            return renderImageOnly(engine.scene)
        case .clearing:
            var black = RGBAImage(width: nativeWidth * scale, height: nativeHeight * scale)
            black.fill(0, 0, 0, 255)
            let from = renderImageOnly(tr.fromScene)
            img = TransitionRenderer.render(effect: tr.clearEffect ?? .normal,
                                            from: from, to: black, frame: tr.state)
        case .displaying:
            var black = RGBAImage(width: nativeWidth * scale, height: nativeHeight * scale)
            black.fill(0, 0, 0, 255)
            let to = renderImageOnly(engine.scene)
            let from = tr.clearEffect != nil ? black : renderImageOnly(tr.fromScene)
            img = TransitionRenderer.render(effect: tr.dispEffect ?? .normal,
                                            from: from, to: to, frame: tr.state)
        }
        for i in stride(from: 3, to: img.pixels.count, by: 4) { img.pixels[i] = 255 }
        return img
    }

    /// Draw the full-screen text layer: 25 columns x 13 rows at (20, 18), each glyph
    /// preceded by its 1px hard shadow. In `.zh` mode with a mounted translation, the
    /// Chinese page replaces this grid.
    func drawTextLayer(_ img: inout RGBAImage, engine: ShizukuEngine) {
        if engine.cnActive {
            drawCNTextLayer(&img, engine: engine)
            return
        }
        let s = self.scale
        let lines = Array(engine.displayedLines.prefix(SceneComposer.linesPerScreen))
        let tr = TextRenderer(font: engine.game.cnFont, scale: s)
        let offset = engine.scene.textOffset * s

        for (row, line) in lines.enumerated() {
            let y = (SceneComposer.textOriginY + row * SceneComposer.lineAdvance) * s
            var x = SceneComposer.textOriginX * s + offset
            for cell in line.prefix(SceneComposer.charsPerLine) {
                // Cell 0 is the full-width space: advance without drawing.
                if cell == Message.tokSpace {
                    x += SceneComposer.glyphAdvance * s
                    continue
                }
                if let px = engine.game.cnFont.pixels(engine.game.textSlot(forLeaf: cell)) {
                    // Original drawChar (sizuku_etc.c:531-539) stamps the 1bpp mask three
                    // times: black at (x+1,y+1) and (x+2,y+1), then the body at (x,y).
                    tr.drawGlyphMatrixPublic(px, into: &img,
                                             x: x + 2 * s, y: y + s,
                                             glyphPx: 24, scale: s, ink: SceneComposer.inkShadow)
                    tr.drawGlyphMatrixPublic(px, into: &img,
                                             x: x + s, y: y + s,
                                             glyphPx: 24, scale: s, ink: SceneComposer.inkShadow)
                    tr.drawGlyphMatrixPublic(px, into: &img,
                                             x: x, y: y,
                                             glyphPx: 24, scale: s, ink: SceneComposer.inkText)
                }
                x += SceneComposer.glyphAdvance * s
            }
        }
    }

    /// Render the mounted Chinese translation with the native anti-aliased CJK font
    /// (a 1px hard shadow behind near-white ink), mirroring the original's full-screen
    /// text grid geometry. The string comes from `cnDisplayedText`: the JP segment
    /// clock types it out beat by beat, so this layer shows exactly what the reveal
    /// has reached — the hot-mount equivalent of `displayedLines`.
    func drawCNTextLayer(_ img: inout RGBAImage, engine: ShizukuEngine) {
        let s = self.scale
        let lines = engine.cnCurrentLines
        let offset = engine.scene.textOffset * s
        for (row, line) in lines.enumerated() {
            let x = SceneComposer.textOriginX * s + offset
            let y = (SceneComposer.textOriginY + row * SceneComposer.lineAdvance) * s
            drawZHText(into: &img, text: line, x: x, y: y,
                       ink: SceneComposer.inkText, fontSize: 20)
        }
    }

    /// Option rectangles (native 640x400 coords, top-down) for the choice menu.
    public func choiceOptionRects(count: Int) -> [CGRect] {
        let boxW: Double = 560
        let rowH: Double = 34
        let boxH = Double(count) * rowH
        let x0 = (640 - boxW) / 2
        let y0 = (400 - boxH) / 2
        return (0..<count).map { i in
            CGRect(x: x0, y: y0 + Double(i) * rowH, width: boxW, height: rowH)
        }
    }

    private func optionText(_ engine: ShizukuEngine, msgIndex: Int) -> [Int] {
        guard let msg = game.scn(engine.scnIndex)?.message(msgIndex) else { return [] }
        // Choice option messages carry a leading `<X..>` offset command; the segmented lines
        // are already free of it, so use those rather than re-paginating the raw leaf stream.
        var out: [[Int]] = []
        for seg in msg.segments { out.append(contentsOf: seg.lines) }
        return out.first ?? []
    }

    public func drawChoiceMenu(_ img: inout RGBAImage, engine: ShizukuEngine, selectedIndex: Int = 0) {
        let s = self.scale
        guard !engine.choices.isEmpty else { return }
        let count = engine.choices.count
        let rects = choiceOptionRects(count: count)
        let tr = TextRenderer(font: engine.game.cnFont, scale: s)

        // Dim background.
        for i in stride(from: 0, to: img.pixels.count, by: 4) {
            img.pixels[i] = UInt8(Int(img.pixels[i]) * 50 / 100)
            img.pixels[i + 1] = UInt8(Int(img.pixels[i + 1]) * 50 / 100)
            img.pixels[i + 2] = UInt8(Int(img.pixels[i + 2]) * 50 / 100)
        }

        for (i, r) in rects.enumerated() {
            let isSel = (i == selectedIndex)
            // A corrupt SELECT may report hundreds of options; boxes past the canvas
            // clamp to nothing instead of underflowing the pixel loop bounds.
            let x0 = max(0, Int(r.origin.x) * s), y0 = max(0, Int(r.origin.y) * s)
            let x1 = min(img.width, Int(r.maxX) * s), y1 = min(img.height, Int(r.maxY) * s)
            if x0 >= x1 || y0 >= y1 { continue }   // box entirely off-canvas
            let borderThickness = isSel ? 2 * s : 1 * s

            // Dark translucent bars so the dimmed artwork still reads through,
            // matching the dot-matrix text aesthetic of the rest of the UI.
            let borderColor: (UInt8, UInt8, UInt8) = isSel ? (120, 160, 220) : (85, 90, 102)
            let fillColor: (UInt8, UInt8, UInt8) = isSel ? (28, 38, 62) : (12, 14, 20)
            let fillAlpha = isSel ? 235 : 200
            for y in y0..<y1 {
                for x in x0..<x1 {
                    let isBorder = (y < y0 + borderThickness || y >= y1 - borderThickness ||
                                    x < x0 + borderThickness || x >= x1 - borderThickness)
                    let di = (y * img.width + x) * 4
                    if isBorder {
                        img.pixels[di]     = borderColor.0
                        img.pixels[di + 1] = borderColor.1
                        img.pixels[di + 2] = borderColor.2
                    } else {
                        img.pixels[di]     = UInt8((Int(img.pixels[di])     * (255 - fillAlpha) + Int(fillColor.0) * fillAlpha) / 255)
                        img.pixels[di + 1] = UInt8((Int(img.pixels[di + 1]) * (255 - fillAlpha) + Int(fillColor.1) * fillAlpha) / 255)
                        img.pixels[di + 2] = UInt8((Int(img.pixels[di + 2]) * (255 - fillAlpha) + Int(fillColor.2) * fillAlpha) / 255)
                    }
                    img.pixels[di + 3] = 255
                }
            }
            // Selection cursor. The option strings already carry their own "1、2、3、"
            // numbering in the scripts, so re-prefixing a digit double-numbers them.
            let cx = x0 + 10 * s
            let cy = y0 + (Int(r.height) - 24) / 2 * s
            if isSel {
                drawASCII(&img, ">", x: cx, y: cy, scale: s * 2, ink: (235, 240, 250))
            }

            let textColor: (UInt8, UInt8, UInt8) = isSel ? (245, 248, 255) : (185, 192, 205)
            let tx = cx + 20 * s
            // A choice option's label is itself a message record, so the corpus keys it
            // under (scn, msgIndex) like any other line.
            if let cn = engine.translatedText(scn: engine.scnIndex, msg: engine.choices[i].msgIndex) {
                let line = cn.replacingOccurrences(of: "\n", with: "")
                let ink = (UInt8(textColor.0), UInt8(textColor.1), UInt8(textColor.2))
                drawZHText(into: &img, text: line, x: tx, y: cy,
                           ink: ink, fontSize: 20)
                continue
            }
            var x = tx
            for leaf in optionText(engine, msgIndex: engine.choices[i].msgIndex) {
                if leaf == Message.tokSpace { x += 24 * s; continue }
                if let px = engine.game.cnFont.pixels(engine.game.textSlot(forLeaf: leaf)) {
                    tr.drawGlyphMatrixPublic(px, into: &img, x: x, y: cy, glyphPx: 24, scale: s, ink: textColor)
                }
                x += 24 * s
            }
        }
    }

    /// The original's two-state blinking wait cursor (`LvnsControl.c`): a mid-page
    /// 'k' pause flashes the solid ▶ (KNJ leaf 102), a page-break 'p' flashes the
    /// page icon (leaf 103). Like `LvnsDisp.c:44-90` it sits at the *current text
    /// cell* — the last displayed line's row, next column — not below the line,
    /// and goes through the same drawChar 3-pass overprint as the message glyphs.
    func drawContinueIndicator(_ img: inout RGBAImage, engine: ShizukuEngine) {
        // `waitingPause` is non-nil only while parked on a finished segment
        // (phase == .awaitingMessage and !isRevealing); nil → no cursor.
        guard let pause = engine.waitingPause else { return }
        // 6 flips lit, 6 flips dark, counted from the flip the wait began on.
        guard engine.waitCursorVisible else { return }
        let s = self.scale

        if engine.cnActive {
            // CN mode: the wait cursor rides the Chinese layer but uses the JP
            // originals (leaf 102 ▶ / 103 page icon) — the CN patch kept them.
            let lines = engine.cnCurrentLines
            guard !lines.isEmpty else { return }
            let row = min(lines.count, SceneComposer.linesPerScreen) - 1
            let x = (SceneComposer.textOriginX + lines[row].count * SceneComposer.glyphAdvance) * s
            let y = (SceneComposer.textOriginY + row * SceneComposer.lineAdvance) * s
            let leaf = (pause == .pageBreak) ? 103 : 102
            drawLeaves(into: &img, leaves: [leaf], x: x, y: y, ink: SceneComposer.inkText)
            return
        }

        // .pageBreak → page icon (leaf 103); .waitKey/.messageEnd → solid ▶ (leaf 102).
        let leaf = (pause == .pageBreak) ? 103 : 102

        let rows = min(engine.displayedLines.count, SceneComposer.linesPerScreen)
        let lastLineCells = rows > 0 ? min(engine.displayedLines[rows - 1].count, SceneComposer.charsPerLine) : 0
        let x = (SceneComposer.textOriginX + lastLineCells * SceneComposer.glyphAdvance) * s
        let y = (SceneComposer.textOriginY + max(0, rows - 1) * SceneComposer.lineAdvance) * s

        // Same leaf→slot glyph path as the main text, including the two shadow
        // stamps at +1/+2 px before the body (drawChar, sizuku_etc.c:531-539).
        drawLeaves(into: &img, leaves: [leaf], x: x, y: y, ink: SceneComposer.inkText)
    }

    /// Draw a small ASCII string (digits like "1.") into the image.
    private func drawASCII(_ img: inout RGBAImage, _ text: String, x: Int, y: Int, scale: Int, ink: (UInt8, UInt8, UInt8)) {
        var cx = x
        for ch in text.utf8 {
            let c = Int(ch)
            // 5x7 dot-matrix digits/letters approximation for 0-9 and '.'.
            let pattern = dotMatrix(c)
            for r in 0..<7 {
                for col in 0..<5 where pattern[r] & (0x10 >> col) != 0 {
                    for sy in 0..<scale {
                        for sx in 0..<scale {
                            img.setPixel(cx + col * scale + sx, y + r * scale + sy, ink.0, ink.1, ink.2, 255)
                        }
                    }
                }
            }
            cx += 6 * scale
        }
    }

    private func dotMatrix(_ c: Int) -> [Int] {
        // 5x7 glyphs for digits and '.'.
        let glyphs: [Int: [Int]] = [
            48: [0x0E,0x11,0x13,0x15,0x19,0x11,0x0E], // 0
            49: [0x04,0x0C,0x04,0x04,0x04,0x04,0x0E], // 1
            50: [0x0E,0x11,0x01,0x02,0x04,0x08,0x1F], // 2
            51: [0x1F,0x02,0x04,0x02,0x01,0x11,0x0E], // 3
            52: [0x02,0x06,0x0A,0x12,0x1F,0x02,0x02], // 4
            53: [0x1F,0x10,0x1E,0x01,0x01,0x11,0x0E], // 5
            54: [0x06,0x08,0x10,0x1E,0x11,0x11,0x0E], // 6
            55: [0x1F,0x01,0x02,0x04,0x08,0x08,0x08], // 7
            56: [0x0E,0x11,0x11,0x0E,0x11,0x11,0x0E], // 8
            57: [0x0E,0x11,0x11,0x0F,0x01,0x02,0x0C], // 9
            46: [0x00,0x00,0x00,0x00,0x00,0x0C,0x0C], // .
            62: [0x10,0x08,0x04,0x02,0x04,0x08,0x10], // >
        ]
        return glyphs[c] ?? [0,0,0,0,0,0,0]
    }

    func sceneImage(image: (RGBA: [UInt8], w: Int, h: Int)?) -> (RGBA: [UInt8], w: Int, h: Int)? {
        return image
    }

    // MARK: - Native Typography & Overlays

    /// Draw a Unicode UI string with the original KNJ dot-matrix font via
    /// LeafCodec, using the same three-pass overprint as drawChar (§26).
    /// Returns the x coordinate just after the last cell (native px * scale).
    @discardableResult
    public func drawLeafText(into img: inout RGBAImage, text: String, x: Int, y: Int,
                             ink: (UInt8, UInt8, UInt8),
                             shadow: (UInt8, UInt8, UInt8) = SceneComposer.inkShadow) -> Int {
        drawLeaves(into: &img, leaves: game.leafCodec.leaves(for: text), x: x, y: y, ink: ink, shadow: shadow)
    }

    /// Draw already-encoded leaf codes (used by the slot-picker preview band,
    /// which wraps a long preview at fixed cell counts).
    @discardableResult
    public func drawLeaves(into img: inout RGBAImage, leaves: [Int], x: Int, y: Int,
                           ink: (UInt8, UInt8, UInt8),
                           shadow: (UInt8, UInt8, UInt8) = SceneComposer.inkShadow) -> Int {
        let s = scale
        let tr = TextRenderer(font: game.cnFont, scale: s)
        var cx = x
        for leaf in leaves {
            if leaf != 0, let px = game.cnFont.pixels(game.textSlot(forLeaf: leaf)) {
                tr.drawGlyphMatrixPublic(px, into: &img, x: cx + 2 * s, y: y + s, glyphPx: 24, scale: s, ink: shadow)
                tr.drawGlyphMatrixPublic(px, into: &img, x: cx + s, y: y + s, glyphPx: 24, scale: s, ink: shadow)
                tr.drawGlyphMatrixPublic(px, into: &img, x: cx, y: y, glyphPx: 24, scale: s, ink: ink)
            }
            cx += 24 * s
        }
        return cx
    }

    /// Width in device px of a leaf-encoded UI string (for centering).
    public func leafTextWidth(_ text: String) -> Int {
        game.leafCodec.leaves(for: text).count * 24 * scale
    }

    // MARK: - WP-11 CN patch dot-matrix text

    /// Resolve one char to a 24x24 glyph from the CN patch font: CN-zone slot when
    /// the char is in `cn_code2char`, else the JP leaf fold (the CN font's first
    /// 1852 slots are byte-identical to the JP font, so both zones may come from
    /// either container; we read CN-zone glyphs from cnDotFont and JP-zone glyphs
    /// from the shipped sizfont).
    private static func cnMatrixGlyph(_ char: Character, game: GameData) -> [[Int]]? {
        if let cn = game.cnDotFont, let px = cn.pixels(for: char) { return px }
        for leaf in game.leafCodec.leaves(for: String(char)) where leaf != 0 {
            return game.cnFont.pixels(game.textSlot(forLeaf: leaf))
        }
        return nil
    }

    /// Draw a Unicode string with the CN patch 24x24 dot font, one cell per char,
    /// using the original drawChar three-pass overprint (two shadow stamps +1/+2px
    /// down-right, then the body). Returns the x just past the last cell.
    @discardableResult
    public static func drawCNMatrixText(into img: inout RGBAImage, text: String, x: Int, y: Int,
                                        ink: (UInt8, UInt8, UInt8),
                                        shadow: (UInt8, UInt8, UInt8),
                                        scale s: Int, game: GameData) -> Int {
        let tr = TextRenderer(font: game.cnFont, scale: s)
        var cx = x
        for ch in text {
            if let px = cnMatrixGlyph(ch, game: game) {
                tr.drawGlyphMatrixPublic(px, into: &img, x: cx + 2 * s, y: y + s, glyphPx: 24, scale: s, ink: shadow)
                tr.drawGlyphMatrixPublic(px, into: &img, x: cx + s, y: y + s, glyphPx: 24, scale: s, ink: shadow)
                tr.drawGlyphMatrixPublic(px, into: &img, x: cx, y: y, glyphPx: 24, scale: s, ink: ink)
            }
            cx += 24 * s
        }
        return cx
    }

    /// Device-px width of a string drawn by `drawCNMatrixText` (uniform 24px cells).
    public static func cnMatrixTextWidth(_ text: String, scale: Int) -> Int {
        text.count * 24 * scale
    }

    /// ZH surface text: CN patch dot matrix when the font is mounted, native font
    /// as the degraded fallback (file missing). Never touches the JP path.
    @discardableResult
    public static func drawZHText(into img: inout RGBAImage, text: String, x: Int, y: Int,
                                  ink: (UInt8, UInt8, UInt8),
                                  shadow: (UInt8, UInt8, UInt8),
                                  scale s: Int, game: GameData, fontSize: CGFloat) -> Int {
        guard game.cnDotFont != nil else {
            let nsInk = NSColor(calibratedRed: CGFloat(ink.0) / 255, green: CGFloat(ink.1) / 255,
                                blue: CGFloat(ink.2) / 255, alpha: 1)
            let nsShadow = NSColor(calibratedRed: CGFloat(shadow.0) / 255, green: CGFloat(shadow.1) / 255,
                                   blue: CGFloat(shadow.2) / 255, alpha: 1)
            drawNativeText(into: &img, text: text, x: x + s, y: y + s, fontSize: fontSize, scale: s, color: nsShadow)
            drawNativeText(into: &img, text: text, x: x, y: y, fontSize: fontSize, scale: s, color: nsInk)
            return x + nativeTextWidth(text, fontSize: fontSize, scale: s) * s
        }
        return drawCNMatrixText(into: &img, text: text, x: x, y: y, ink: ink, shadow: shadow, scale: s, game: game)
    }

    @discardableResult
    public func drawZHText(into img: inout RGBAImage, text: String, x: Int, y: Int,
                           ink: (UInt8, UInt8, UInt8),
                           shadow: (UInt8, UInt8, UInt8) = SceneComposer.inkShadow,
                           fontSize: CGFloat = ShellText.nativeMenuFontSize) -> Int {
        Self.drawZHText(into: &img, text: text, x: x, y: y, ink: ink, shadow: shadow,
                        scale: scale, game: game, fontSize: fontSize)
    }

    /// Device-px width of `drawZHText` output — drawing and hit-testing agree.
    public static func zhTextWidth(_ text: String, scale: Int, game: GameData,
                                   fontSize: CGFloat = ShellText.nativeMenuFontSize) -> Int {
        game.cnDotFont != nil
            ? cnMatrixTextWidth(text, scale: scale)
            : nativeTextWidth(text, fontSize: fontSize, scale: scale) * scale
    }

    public func zhTextWidth(_ text: String, fontSize: CGFloat = ShellText.nativeMenuFontSize) -> Int {
        Self.zhTextWidth(text, scale: scale, game: game, fontSize: fontSize)
    }

    /// Render native macOS anti-aliased font into pixel buffer via CGContext.
    public func drawNativeText(
        into img: inout RGBAImage,
        text: String,
        x: Int,
        y: Int,
        fontSize: CGFloat = 16,
        color: NSColor = .white
    ) {
        SceneComposer.drawNativeText(into: &img, text: text, x: x, y: y,
                                     fontSize: fontSize, scale: scale, color: color)
    }

    /// Scale-parameterized static twin for renderers outside a composer instance.
    public static func drawNativeText(
        into img: inout RGBAImage,
        text: String,
        x: Int,
        y: Int,
        fontSize: CGFloat,
        scale: Int,
        color: NSColor
    ) {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: &img.pixels,
            width: img.width,
            height: img.height,
            bitsPerComponent: 8,
            bytesPerRow: img.width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ) else { return }

        ctx.translateBy(x: 0, y: CGFloat(img.height))
        ctx.scaleBy(x: 1.0, y: -1.0)

        let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: true)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsCtx

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize * CGFloat(scale), weight: .bold),
            .foregroundColor: color
        ]
        let attrStr = NSAttributedString(string: text, attributes: attrs)
        let pt = NSPoint(x: CGFloat(x), y: CGFloat(y))
        attrStr.draw(at: pt)

        NSGraphicsContext.restoreGraphicsState()
    }

    /// Endings status list overlay. JP rows are the exact leaf-code strings that
    /// always rendered; ZH rows (WP-9) resolve through `ShellText` and draw with the
    /// native CJK font via `drawShellText` (which is `drawLeafText` verbatim for `.jp`).
    public func drawEndingListOverlay(into img: inout RGBAImage, clearedEndings: Set<Int>) {
        let s = self.scale
        img.blendBlack(215)

        drawShellText(into: &img, text: ShellText.endingsTitle(language), x: 30 * s, y: 12 * s,
                      ink: (243, 217, 115), shadow: (60, 45, 10))

        // Single column: at 24px full-width cells the longest row
        // (ED + ○ ＣＬＥＡＲ + 9-char title) is 25 cells = 600px, so the old
        // two-column CoreText layout would collide.
        let rowX = 16 * s
        let startY = 44 * s
        let rowH = 26 * s

        for ending in ShizukuEnding.allCases {
            let idx = ending.rawValue
            let isCleared = clearedEndings.contains(idx)
            let rowY = startY + idx * rowH

            let status = ShellText.endingsStatus(cleared: isCleared, language)
            let title: String
            switch (language, isCleared) {
            case (.zh, true): title = ending.titleZH
            case (.zh, false): title = "？？？？？"
            case (_, true): title = ending.titleJP
            case (_, false): title = UIText.endingsLockedTitle
            }
            let displayText = String(format: "ED%02d  %@  %@", idx, status, title)
            drawShellText(into: &img, text: displayText, x: rowX, y: rowY,
                          ink: isCleared ? (110, 230, 120) : (150, 150, 150),
                          shadow: (5, 20, 8))
        }
    }

    /// Toast notification banner, original KNJ dot-matrix text sized to fit.
    /// ZH (WP-9): the JP string is the internal key — it is mapped through
    /// `ShellText.toastCN` and drawn with the native font; the JP path is unchanged.
    public func drawToastOverlay(into img: inout RGBAImage, message: String) {        let s = self.scale
        let display = language == .zh ? ShellText.toastCN(message) : message
        let padX = 10 * s
        let textW = shellTextWidth(display)
        let boxW = min(img.width - 16 * s, textW + 2 * padX)
        let boxH = 34 * s
        let x0 = 16 * s
        let y0 = 16 * s

        for y in y0..<(y0 + boxH) {
            for x in x0..<(x0 + boxW) {
                if y < img.height && x < img.width {
                    let di = (y * img.width + x) * 4
                    img.pixels[di]     = 20
                    img.pixels[di + 1] = 25
                    img.pixels[di + 2] = 40
                    img.pixels[di + 3] = 230
                }
            }
        }
        drawShellText(into: &img, text: display, x: x0 + padX, y: y0 + 5 * s,
                      ink: (255, 230, 102), shadow: (60, 45, 10))
    }

    // MARK: - Boot sequence (jingle / OP / title) canvases

    /// Fresh 640x400 canvas filled with a solid color.
    public func solidCanvas(r: Int, g: Int, b: Int) -> RGBAImage {
        var img = RGBAImage(width: nativeWidth * scale, height: nativeHeight * scale)
        img.fill(UInt8(clamping: r), UInt8(clamping: g), UInt8(clamping: b), 255)
        return img
    }

    /// Black canvas with the given LFG assets blitted at their table coordinates.
    /// Mirrors `mglimage_add`: the LFG header offset is already baked into the canvas
    /// by `Lfg.decode`, and `lvnsimage_add` adds (x, y) on top — so `(x + xoffset, y + yoffset)`
    /// is where the art lands, exactly as the original `sizuku_op.c` tables expect.
    public func bootCanvas(layers: [(name: String, x: Int, y: Int)]) -> RGBAImage {
        var img = solidCanvas(r: 0, g: 0, b: 0)
        for layer in layers {
            if let im = game.image(name: layer.name) {
                img.blitScaled(im, dx: layer.x * scale, dy: layer.y * scale, factor: scale)
            }
        }
        return img
    }

    /// Per-pixel linear blend `a + (b - a) * num / den` — the palette fade (Lighten/Darken)
    /// and FadeMask cross-dissolve of the original effect engine.
    public static func blend(_ a: RGBAImage, _ b: RGBAImage, num: Int, den: Int) -> RGBAImage {
        guard a.pixels.count == b.pixels.count, den > 0 else { return b }
        var out = a
        let t = max(0, min(den, num))
        if t == 0 { return a }
        if t == den { return b }
        for i in stride(from: 0, to: out.pixels.count, by: 4) {
            for c in 0..<3 {
                let x = Int(a.pixels[i + c]), y = Int(b.pixels[i + c])
                out.pixels[i + c] = UInt8(x + (y - x) * t / den)
            }
        }
        return out
    }

    /// Jingle stage-2 canvas: black field, white window box (0,80)-(639,319), LEAF logo
    /// at (80,144) (`sizuku_jingle.c` LoadTitle2: clear_index(0); boxfill; add2).
    public func jingleWindowCanvas() -> RGBAImage {
        var img = bootCanvas(layers: [("LEAF.LFG", 80, 144)])
        let s = scale
        for y in (80 * s)..<(320 * s) {
            for x in 0..<(640 * s) {
                let di = (y * img.width + x) * 4
                img.pixels[di] = 255; img.pixels[di + 1] = 255; img.pixels[di + 2] = 255
            }
        }
        if let im = game.image(name: "LEAF.LFG") {
            img.blitScaled(im, dx: 80 * s, dy: 144 * s, factor: s)
        }
        return img
    }

    /// Reveal `base` over `hidden` from the frame edges toward the center — the slide wipe
    /// of `sizuku_jingle.c` (`LOOP_FUNC Slide`, 20px per tick, 32 ticks).
    public func slideReveal(base: RGBAImage, hidden: RGBAImage, state: Int) -> RGBAImage {
        var out = hidden
        guard base.pixels.count == hidden.pixels.count else { return base }
        let open = min(320 * scale, state * 20 * scale)
        for y in 0..<base.height {
            for x in 0..<base.width where x < open || x >= base.width - open {
                let di = (y * base.width + x) * 4
                for c in 0..<4 { out.pixels[di + c] = base.pixels[di + c] }
            }
        }
        return out
    }

    /// Native-coord hit rect of a centred menu line, derived from the same geometry
    /// `drawMenuLine` paints with. Rows are centred, so their x extent follows the text
    /// length — a fixed full-width band would let a click far from the glyphs select it.
    public static func menuLineRect(leaves: [Int], line: Int, canvasWidth: Int = 640) -> CGRect {
        CGRect(x: (canvasWidth - leaves.count * 24) / 2, y: line * 32 + 8,
               width: leaves.count * 24, height: 24)
    }

    /// Slot-picker rows are full-width list rows, not centred menu lines.
    /// Base Y is kept in lock-step with `drawSlotPicker`'s row loop (draw = base+2).
    public static func slotPickerRowRects(count: Int) -> [CGRect] {
        (0..<count).map { i in CGRect(x: 8, y: 62 + 28 * i, width: 624, height: 28) }
    }

    // MARK: - Shell menu rows (M5.6 WP-7a, build-language routed)

    /// Width in *native* px of a string rendered by `drawNativeText` at the given
    /// native font size. Measured with the actual device font size and divided by
    /// scale, so drawing (device px) and hit-testing (native px) agree.
    public static func nativeTextWidth(_ text: String, fontSize: CGFloat, scale: Int) -> Int {
        let attrs: [NSAttributedString.Key: Any] =
            [.font: NSFont.systemFont(ofSize: fontSize * CGFloat(scale), weight: .bold)]
        let w = ((text as NSString).size(withAttributes: attrs).width / CGFloat(scale)).rounded(.up)
        return max(1, Int(w))
    }

    /// Native-coord hit rect of a shell menu row, derived from the same geometry
    /// `drawMenuRow` paints with — leaf rows reuse `menuLineRect` verbatim so the
    /// JP hit table is unchanged; native rows centre by measured font width.
    public func menuRowRect(_ row: MenuRow, line: Int) -> CGRect {
        switch row {
        case .leaves(let leaves):
            return SceneComposer.menuLineRect(leaves: leaves, line: line)
        case .native(let text):
            let w = zhTextWidth(text) / scale
            return CGRect(x: (nativeWidth - w) / 2, y: line * 32 + 8, width: w, height: 24)
        }
    }

    /// Draw one shell menu row centred on `line`: JP rows go through the dot-matrix
    /// `drawMenuLine` path byte-identically; ZH rows use the native CJK font with the
    /// same 1px-shadow double stamp as `drawCNTextLayer`.
    /// Returns the device x just past the last glyph (for suffix badges).
    @discardableResult
    public func drawMenuRow(into img: inout RGBAImage, row: MenuRow, line: Int, selected: Bool) -> Int {
        switch row {
        case .leaves(let leaves):
            return drawMenuLine(into: &img, leaves: leaves, line: line, selected: selected)
        case .native(let text):
            let s = scale
            let w = zhTextWidth(text) / s
            let x = (img.width / s - w) / 2 * s
            let y = (line * 32 + 8) * s
            let ink: (UInt8, UInt8, UInt8) = selected ? (240, 240, 240) : (150, 150, 150)
            let shadow: (UInt8, UInt8, UInt8) = selected ? (10, 10, 10) : (5, 5, 5)
            drawZHText(into: &img, text: text, x: x, y: y, ink: ink, shadow: shadow)
            return x + w * s
        }
    }

    /// Width in device px of a shell string under this composer's language —
    /// leaf cells for JP, CN patch dot-matrix cells for ZH.
    public func shellTextWidth(_ text: String) -> Int {
        language == .zh ? zhTextWidth(text) : leafTextWidth(text)
    }

    /// Draw a shell string left-aligned at device (x, y): the JP path is exactly
    /// `drawLeafText` (byte-identical), the ZH path the CN patch dot matrix.
    public func drawShellText(into img: inout RGBAImage, text: String, x: Int, y: Int,
                              ink: (UInt8, UInt8, UInt8),
                              shadow: (UInt8, UInt8, UInt8) = SceneComposer.inkShadow) {
        if language == .zh {
            drawZHText(into: &img, text: text, x: x, y: y, ink: ink, shadow: shadow)
        } else {
            drawLeafText(into: &img, text: text, x: x, y: y, ink: ink, shadow: shadow)
        }
    }

    /// Draw a dot-matrix menu line centered horizontally, `LvnsMenu.h` style:
    /// Y = line*32 + 8, selected = white with black shadow, unselected = gray.
    /// Returns the native x coordinate just past the last cell (for suffixes).
    @discardableResult
    public func drawMenuLine(into img: inout RGBAImage, leaves: [Int], line: Int, selected: Bool) -> Int {
        let s = scale
        let tr = TextRenderer(font: game.cnFont, scale: s)
        let xStart = Int(SceneComposer.menuLineRect(leaves: leaves, line: line,
                                                    canvasWidth: img.width / s).minX) * s
        var x = xStart
        let y = (line * 32 + 8) * s
        for leaf in leaves {
            if leaf == 0 { x += 24 * s; continue }
            if let px = game.cnFont.pixels(game.textSlot(forLeaf: leaf)) {
                if selected {
                    tr.drawGlyphMatrixPublic(px, into: &img, x: x + 2 * s, y: y + s, glyphPx: 24, scale: s, ink: SceneComposer.inkShadow)
                    tr.drawGlyphMatrixPublic(px, into: &img, x: x + s, y: y + s, glyphPx: 24, scale: s, ink: SceneComposer.inkShadow)
                    tr.drawGlyphMatrixPublic(px, into: &img, x: x, y: y, glyphPx: 24, scale: s, ink: SceneComposer.inkText)
                } else {
                    tr.drawGlyphMatrixPublic(px, into: &img, x: x + 2 * s, y: y + s, glyphPx: 24, scale: s, ink: (5, 5, 5))
                    tr.drawGlyphMatrixPublic(px, into: &img, x: x + s, y: y + s, glyphPx: 24, scale: s, ink: (5, 5, 5))
                    tr.drawGlyphMatrixPublic(px, into: &img, x: x, y: y, glyphPx: 24, scale: s, ink: (150, 150, 150))
                }
            }
            x += 24 * s
        }
        return xStart + leaves.count * 24 * s
    }

    // MARK: - ESC system menu (M4.7), per sizuku_menu.c:75-83

    /// The six menu lines, verbatim original order and text.
    public static let escMenuItems: [[Int]] = [
        MenuStrings.escHideText, MenuStrings.escLoad, MenuStrings.escSave,
        MenuStrings.escRecall, MenuStrings.escPrevChoice, MenuStrings.escEnd,
    ]

    /// The authentic six-item system menu. Language switching lives in the Mac menu
    /// bar (item 6/8), not as a non-original 7th row here.
    public static let escMenuRowCount: Int = escMenuItems.count

    /// Dim the scene to latitude_dark and draw the six menu lines on text lines 3..8.
    /// The table is the build language's (WP-7a): JP leaf rows paint exactly the
    /// previous pixels; ZH rows come out in the native CJK font.
    public func drawEscMenu(into img: inout RGBAImage, selectedIndex: Int) {
        img.scaleRGB(by: 11, of: 16)
        for (i, row) in ShellText.escRows(language).enumerated() {
            drawMenuRow(into: &img, row: row, line: 3 + i, selected: i == selectedIndex)
        }
    }

    /// Native-font confirmation submenu (header line, question, then the two options).
    /// The yes/no pair and the （１）（２） badges stay on the leaf path in JP builds —
    /// byte-identical to the previous `drawMenuLine`-based implementation.
    public func drawConfirmMenu(into img: inout RGBAImage, header: MenuRow, selectedIndex: Int) {
        img.scaleRGB(by: 11, of: 16)
        let s = scale
        drawMenuRow(into: &img, row: header, line: 4, selected: false)
        drawMenuRow(into: &img, row: ShellText.confirmQuestion(language), line: 5, selected: false)
        let rows = ShellText.confirmRows(language)
        let yesEnd = drawMenuRow(into: &img, row: rows[0], line: 6, selected: selectedIndex == 0)
        let noEnd = drawMenuRow(into: &img, row: rows[1], line: 7, selected: selectedIndex == 1)
        // "(1)" / "(2)" hints — original literals, native font (sizfont has no ASCII cells).
        composerBadge(UIText.confirmOne, afterX: yesEnd, line: 6, s: s, img: &img)
        composerBadge(UIText.confirmTwo, afterX: noEnd, line: 7, s: s, img: &img)
    }

    private func composerBadge(_ text: String, afterX x: Int, line: Int, s: Int, img: inout RGBAImage) {
        drawLeafText(into: &img, text: text, x: x + 6 * s, y: (line * 32 + 8) * s,
                     ink: (191, 179, 102), shadow: (5, 5, 5))
    }

    /// Slot picker: six しおり rows with per-slot detail lines from SaveManager.
    public struct SlotRow {
        public let labelText: String  // KNJ dot-matrix "しおり　N" / "クイックセーブ"
        public let detail: String    // "MM/dd HH時mm" fold or "（から）"
        public let preview: String   // first line of stored text
        /// True when `preview` carries Chinese prose: the band then renders with the
        /// native anti-aliased CJK font instead of the sizfont dot matrix, which has
        /// no simplified glyphs (M5.6 WP-1). JP previews keep `false` and stay on the
        /// original leaf-code path.
        public let previewIsCN: Bool
        public let hasData: Bool
        public init(labelText: String, detail: String, preview: String,
                    previewIsCN: Bool = false, hasData: Bool) {
            self.labelText = labelText; self.detail = detail; self.preview = preview
            self.previewIsCN = previewIsCN; self.hasData = hasData
        }
    }

    public func drawSlotPicker(into img: inout RGBAImage, header: String, rows: [SlotRow], selectedIndex: Int) {
        img.scaleRGB(by: 11, of: 16)
        let s = scale
        drawShellText(into: &img, text: header,
                      x: (img.width - shellTextWidth(header)) / 2, y: 32 * s,
                      ink: (243, 217, 115), shadow: (60, 45, 10))
        // Row = ▶ cursor cell + label(<=8 cells) + date(12) at 28px pitch.
        // The cursor is the original font's own glyph (leaf 102 = solid ▶,
        // XLVNS cursor_key), so the selection reads without leaving the
        // dot-matrix aesthetic — in both languages.
        for (i, row) in rows.enumerated() {
            let y = (64 + 28 * i) * s
            let selected = i == selectedIndex
            let ink = selected ? SceneComposer.inkText : (150, 150, 150)
            let shadow = selected ? SceneComposer.inkShadow : (5, 5, 5)
            if selected {
                drawLeaves(into: &img, leaves: [102], x: 12 * s, y: y,
                           ink: (243, 217, 115), shadow: (60, 45, 10))
            }
            drawShellText(into: &img, text: row.labelText, x: 44 * s, y: y, ink: ink, shadow: shadow)
            if row.hasData {
                drawShellText(into: &img, text: row.detail, x: 252 * s, y: y, ink: ink, shadow: shadow)
            } else {
                drawShellText(into: &img, text: row.detail, x: 252 * s, y: y,
                              ink: (115, 115, 115), shadow: (5, 5, 5))
            }
        }
        // Selected-slot preview band: 2 lines x 26 cells on a translucent
        // panel (same treatment as the choice panel) so it reads as a
        // distinct zone rather than stray text over the artwork.
        let panelY0 = 286 * s, panelY1 = 340 * s
        for y in panelY0..<min(panelY1, img.height) {
            for x in (8 * s)..<min(632 * s, img.width) {
                let di = (y * img.width + x) * 4
                img.pixels[di]     = UInt8(Int(img.pixels[di]) * 40 / 100)
                img.pixels[di + 1] = UInt8(Int(img.pixels[di + 1]) * 40 / 100)
                img.pixels[di + 2] = UInt8(Int(img.pixels[di + 2]) * 40 / 100)
            }
        }
        if rows.indices.contains(selectedIndex) {
            let sel = rows[selectedIndex]
            if sel.hasData && sel.previewIsCN {
                // ZH preview band: up to two natural paragraphs drawn with the CN
                // patch dot matrix, at the same band rows as the leaf path (WP-11).
                let cnLines = sel.preview.components(separatedBy: "\n")
                    .filter { !$0.isEmpty }.prefix(2)
                for (line, text) in cnLines.enumerated() {
                    let y = (292 + line * 24) * s
                    drawZHText(into: &img, text: text, x: 12 * s, y: y,
                               ink: (230, 230, 230), shadow: (5, 5, 5), fontSize: 16)
                }
            } else if !sel.hasData && language == .zh {
                // ZH 空格子：（空）走原生字体，点阵路径只留给有 JP 叶码可解的文本。
                drawShellText(into: &img, text: sel.detail.isEmpty ? ShellText.slotEmpty(language) : sel.detail,
                              x: 12 * s, y: 292 * s,
                              ink: (115, 115, 115), shadow: (5, 5, 5))
            } else {
                let leaves = game.leafCodec.leaves(for: sel.hasData ? sel.preview : UIText.slotEmpty)
                let ink: (UInt8, UInt8, UInt8) = sel.hasData ? (230, 230, 230) : (115, 115, 115)
                for line in 0..<2 {
                    let start = line * 26
                    guard start < leaves.count else { break }
                    let slice = Array(leaves[start..<min(start + 26, leaves.count)])
                    drawLeaves(into: &img, leaves: slice, x: 12 * s, y: (292 + line * 24) * s,
                               ink: ink, shadow: (5, 5, 5))
                }
            }
        }
        drawShellText(into: &img, text: ShellText.slotHint(language),
                      x: (img.width - shellTextWidth(ShellText.slotHint(language))) / 2, y: 340 * s,
                      ink: (178, 178, 178), shadow: (5, 5, 5))
    }

    /// Title backdrop = TITLE0.LFG + TITLE.LFG (both blit at 0,0; offsets baked in header).
    public func titleBackdrop() -> RGBAImage {
        return bootCanvas(layers: [("TITLE0.LFG", 0, 0), ("TITLE.LFG", 0, 0)])
    }

    /// Title art pre-dimmed to `latitude_dark` (11/16) while a menu is up, per LvnsMenu.
    public func titleBackdropDimmed() -> RGBAImage {
        var img = titleBackdrop()
        img.scaleRGB(by: 11, of: 16)
        return img
    }
}

extension RGBAImage {
    /// Integer-factor blit of a source (RGBA, w, h) onto self.
    mutating func blitScaled(_ src: (RGBA: [UInt8], w: Int, h: Int), dx: Int, dy: Int, factor: Int) {
        for sy in 0..<src.h {
            for sx in 0..<src.w {
                let si = (sy * src.w + sx) * 4
                let a = src.RGBA[si + 3]
                if a == 0 { continue }
                for oy in 0..<factor {
                    for ox in 0..<factor {
                        let tx = dx + sx * factor + ox
                        let ty = dy + sy * factor + oy
                        guard tx >= 0, tx < width, ty >= 0, ty < height else { continue }
                        let di = (ty * width + tx) * 4
                        pixels[di] = src.RGBA[si]
                        pixels[di + 1] = src.RGBA[si + 1]
                        pixels[di + 2] = src.RGBA[si + 2]
                        pixels[di + 3] = 255
                    }
                }
            }
        }
    }

    mutating func blendWhite(_ amount: Int) {
        for i in stride(from: 0, to: pixels.count, by: 4) {
            pixels[i] = UInt8(min(255, Int(pixels[i]) + amount))
            pixels[i + 1] = UInt8(min(255, Int(pixels[i + 1]) + amount))
            pixels[i + 2] = UInt8(min(255, Int(pixels[i + 2]) + amount))
        }
    }

    /// Multiply every channel by `num/den`. This is the palette-fade used by the original
    /// (`mgImage.c` `cmap_m[i][j] = j * i / 16` applied to palette brightness), and it is how
    /// `latitude_dark = 11` dims the artwork behind the text.
    mutating func scaleRGB(by num: Int, of den: Int) {
        guard den > 0 else { return }
        for i in stride(from: 0, to: pixels.count, by: 4) {
            pixels[i] = UInt8(Int(pixels[i]) * num / den)
            pixels[i + 1] = UInt8(Int(pixels[i + 1]) * num / den)
            pixels[i + 2] = UInt8(Int(pixels[i + 2]) * num / den)
        }
    }

    mutating func blendBlack(_ amount: Int) {
        for i in stride(from: 0, to: pixels.count, by: 4) {
            pixels[i] = UInt8(max(0, Int(pixels[i]) - amount))
            pixels[i + 1] = UInt8(max(0, Int(pixels[i + 1]) - amount))
            pixels[i + 2] = UInt8(max(0, Int(pixels[i + 2]) - amount))
        }
    }
}
