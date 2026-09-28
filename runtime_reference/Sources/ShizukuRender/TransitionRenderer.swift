//
//  TransitionRenderer.swift
//  ShizukuRender
//
//  Port of the Sizuku.exe screen-transition effects (dispatcher @0x404740):
//  FadePalette, Guruguru, SlantTile, FadeSquare, WipeSquareLtoR, FadeMask,
//  WipeTtoB, WipeLtoR, WipeMaskLtoR, VertComposition, SlideLtoR, Normal.
//  The geometry, phase tables and pacing below were read off the shipped
//  binary's disassembly, NOT the mglvns Linux port's LvnsEffect.c — that port
//  deviates from the EXE in several of these effects (see HANDOVER §35/§38).
//
//  The original pumps each animation inside one blocking call on a retained
//  framebuffer; every effect here is recomputed from `frame` alone, which
//  yields the same picture because the effects are monotonic repaints
//  (a revealed pixel is never painted back with old content).
//

import Foundation
import ShizukuCore

public enum TransitionRenderer {
    /// Render animation state of `effect` transitioning from image `from` to image `to`.
    /// frame is 0..<LvnsEffectTiming.frames(effect, width:, height:); frame >= total must return `to`.
    ///
    /// The original pumps these masks on its own 640×400 screen, where a mask unit is
    /// literally 32/16/4 px. Running that math on a 2x or 3x canvas would shrink every
    /// block to a fraction of its intended size, so the effect is computed on the
    /// logical 640×400 grid and re-upscaled with the same integer factor the canvas
    /// already uses — the layer images are themselves integer upscales, so this is exact.
    public static func render(effect: LvnsEffect, from: RGBAImage, to: RGBAImage, frame: Int) -> RGBAImage {
        let factor = max(1, from.width / logicalWidth)
        if factor > 1 {
            let out = render(effect: effect, from: shrink(from, factor), to: shrink(to, factor), frame: frame)
            return grow(out, factor, width: from.width, height: from.height)
        }
        return renderAtLogicalSize(effect: effect, from: from, to: to, frame: frame)
    }

    private static func renderAtLogicalSize(effect: LvnsEffect, from: RGBAImage, to: RGBAImage, frame: Int) -> RGBAImage {
        var to = to
        let w = from.width
        let h = from.height
        let total = LvnsEffectTiming.frames(effect, width: w, height: h)
        let f = max(frame, 0)
        if f >= total || effect == .normal {
            return to
        }
        if to.width != w || to.height != h {
            to = normalized(to, width: w, height: h)
        }

        switch effect {

        case .normal:
            return to

        case .fadePalette:
            // @0x404810: the old screen dies instantly (palette entries blacked), the
            // new pixels are blitted once and stay put, and only the palette then
            // ramps up monotonically over ~600 ms. So the screen is always `to`
            // scaled by the ramp — in the clearing phase (`to` = black) that means
            // the old scene is gone from frame 0, and in the displaying phase it is
            // a fade-in from black. The EXE ramps only its first 19 palette entries;
            // with a full-RGB pipeline that restriction has no analogue.
            let level = min(255, 256 * (f + 1) / max(total, 1))
            if level >= 255 { return to }
            var out = to
            for i in stride(from: 0, to: out.pixels.count, by: 4) {
                out.pixels[i]     = UInt8(Int(out.pixels[i])     * level / 255)
                out.pixels[i + 1] = UInt8(Int(out.pixels[i + 1]) * level / 255)
                out.pixels[i + 2] = UInt8(Int(out.pixels[i + 2]) * level / 255)
                out.pixels[i + 3] = 255
            }
            return out

        case .fadeMask, .fadeMask2:
            // lvnsimage_copy_mask_unit: state advances once per 2 flips (LvnsWait(1)).
            let phase = min(f / 2, 15)
            return compose(from: from, to: to) { x, y in
                Self.ditherThreshold[x % 4][y % 4] <= phase
            }

        case .fadeSquare:
            // @0x404e40: states 0...32, each held ~30 ms (2 flips).
            let state = min(f / 2, 32)
            return compose(from: from, to: to) { x, y in
                Self.squareThreshold(x, y) <= state
            }

        case .wipeSquareLtoR:
            // @0x405090: states 0...51 (2 flips each); a 32px column only starts
            // once state has passed its index, i.e. one column of lag per 32px.
            let state = min(f / 2, 51)
            return compose(from: from, to: to) { x, y in
                state >= x / 32 + Self.squareThreshold(x, y)
            }

        case .wipeTtoB:
            // @0x404370: 41 frames; frame f paints the 16 full-width rows
            // 16f - 17k (k=0...15), starting at the visual top row on frame 0.
            var out = from
            for y in 0..<h where f >= Self.ttoBFirstFrame(y) {
                Self.copyRow(to, srcY: y, into: &out, dstY: y)
            }
            return out

        case .wipeLtoR:
            // @0x4052e0: 56 frames; frame f paints the 16 full-height columns
            // 16f - 15k (k=0...15), starting at the left edge on frame 0.
            var out = from
            for x in 0..<w where f >= Self.ltoRFirstFrame(x) {
                Self.copyColumn(to, srcX: x, into: &out, dstX: x)
            }
            return out

        case .wipeMaskLtoR:
            return compose(from: from, to: to) { x, y in
                f >= x / 16 + Self.ditherThreshold[x % 4][y % 4]
            }

        case .vertComposition:
            // @0x405560: state s=1...16 (each ~30 ms); each state StretchDIBits-scales
            // the ENTIRE new image into a centred band of height h·s/16 — an expanding
            // miniaturised preview, not a zoom out of a cropped strip.
            let s = min(f / 2 + 1, 16)
            let h1 = h * s / 16
            guard h1 > 0 else { return from }
            var out = from
            let y0 = (h - h1) / 2
            for i in 0..<h1 {
                Self.copyRow(to, srcY: i * h / h1, into: &out, dstY: y0 + i)
            }
            return out

        case .slideLtoR:
            // @0x405680: not a slide. States d=0...15, one per frame; each state copies
            // the byte-columns ≡ d (mod 16), so after frame d the revealed set is the
            // column classes {0...d}.
            let state = min(f, 15)
            var out = from
            for x in 0..<w where x % 16 <= state {
                Self.copyColumn(to, srcX: x, into: &out, dstX: x)
            }
            return out

        case .guruguru:
            let cols = max(1, w / 16)
            let rows = max(1, h / 16)
            let order = guruguruOrder(cols: cols, rows: rows)
            var revealed = [Bool](repeating: false, count: cols * rows)
            // 8 tiles per present — `inc eax; test al,7; jne` @0x404b0c in GURUGURUDisp
            // (Sizuku.exe), i.e. 1000 tiles / 8 = 125 flips at 640x400.
            for k in 0..<min(order.count, 8 * (f + 1)) {
                revealed[order[k]] = true
            }
            return compose(from: from, to: to) { x, y in
                revealed[min(y * rows / h, rows - 1) * cols + min(x * cols / w, cols - 1)]
            }

        case .slantTile:
            // @0x404c50: a random dissolve, not slanted bands — tiles are drawn from
            // the mode-2 RNG two bytes at a time (col=(r·40)>>8, row=(r·25)>>8),
            // collisions resolved by linear probing with wraparound, and 32 tiles are
            // committed per present. The generation order is cached; a frame shows the
            // first 32·(f+1) tiles of that order.
            let cols = 40
            let rows = 25
            let order = Self.slantOrder
            let revealed = Set(order.prefix(min(order.count, 32 * (f + 1))))
            return compose(from: from, to: to) { x, y in
                revealed.contains(min(y * rows / h, rows - 1) * cols + min(x * cols / w, cols - 1))
            }
        }
    }

    /// The original screen the mask geometry is defined against.
    static let logicalWidth = 640
    static let logicalHeight = 400

    /// Sample one pixel per `factor`×`factor` block; the layers handed to us are exact
    /// integer upscales of a 640×400 image, so this loses nothing.
    private static func shrink(_ img: RGBAImage, _ factor: Int) -> RGBAImage {
        guard factor > 1, img.width % factor == 0, img.height % factor == 0 else { return img }
        let w = img.width / factor, h = img.height / factor
        var out = RGBAImage(width: w, height: h)
        for y in 0..<h {
            for x in 0..<w {
                let si = (y * factor * img.width + x * factor) * 4
                let di = (y * w + x) * 4
                for c in 0..<4 { out.pixels[di + c] = img.pixels[si + c] }
            }
        }
        return out
    }

    private static func grow(_ img: RGBAImage, _ factor: Int, width: Int, height: Int) -> RGBAImage {
        guard factor > 1, img.width * factor == width, img.height * factor == height else { return img }
        var out = RGBAImage(width: width, height: height)
        for y in 0..<height {
            let sy = y / factor
            for x in 0..<width {
                let si = (sy * img.width + x / factor) * 4
                let di = (y * width + x) * 4
                for c in 0..<4 { out.pixels[di + c] = img.pixels[si + c] }
            }
        }
        return out
    }

    /// 640×400 all-black opaque canvas, for clear→black transition phases.
    public static var blackCanvas: RGBAImage {
        var img = RGBAImage(width: 640, height: 400)
        img.fill(0, 0, 0, 255)
        return img
    }

    // MARK: - Geometry tables read off Sizuku.exe (cases 5/8 share the .data table)

    /// Phase order of the 4×4 ordered-dither mask, from the word table @0x430754
    /// shared by FADE_MASK (@0x4040c0) and WIPE_MASK_LTOR (@0x405400):
    /// (0,0)(2,2)(2,0)(0,2) | (1,1)(3,3)(3,1)(1,3) | (1,0)(3,2)(3,0)(1,2) | (0,1)(2,3)(2,1)(0,3),
    /// i.e. threshold[x%4][y%4] = x0:[0,12,3,15] x1:[8,4,11,7] x2:[2,14,1,13] x3:[10,6,9,5]
    /// in the EXE's buffer frame. The screen DIB is bottom-up (row 0 = visual bottom)
    /// and 400 % 4 == 0, so the visual top-down table is that table's rows reversed —
    /// this ordering matches neither mglvns' xoff/yoff derivation nor its group order.
    private static let ditherThreshold: [[Int]] = [
        [15,  3, 12,  0],
        [ 7, 11,  4,  8],
        [13,  1, 14,  2],
        [ 5,  9,  6, 10],
    ]

    /// lvnsimage_copy_squaremask_unit, whose corner-to-centre diamond rings the EXE's
    /// FADE_SQUARE (@0x404e40) four-arm walk also paints: a pixel inside its 32×32
    /// unit appears at state min(lx, 31-lx) + min(ly, 31-ly).
    private static func squareThreshold(_ x: Int, _ y: Int) -> Int {
        let lx = x % 32
        let ly = y % 32
        return min(lx, 31 - lx) + min(ly, 31 - ly)
    }

    /// WIPE_TTOB @0x404370: frame f paints visual rows 16f − 17k, k = 0...15
    /// (bottom-up buffer rows 399−t). A row's first painted frame is the smallest f
    /// with 0 ≤ (16f − row)/17 ≤ 15; 16 ≡ −1 (mod 17) fixes f's residue class.
    private static func ttoBFirstFrame(_ row: Int) -> Int {
        var f = (17 - row % 17) % 17
        while 16 * f - row < 0 || 16 * f - row > 15 * 17 { f += 17 }
        return f
    }

    /// WIPE_LTOR @0x4052e0: frame f paints columns 16f − 15k, k = 0...15;
    /// 16 ≡ 1 (mod 15), so f ≡ column (mod 15) and then grow f until the tooth exists.
    private static func ltoRFirstFrame(_ column: Int) -> Int {
        var f = column % 15
        while 16 * f - column < 0 || 16 * f - column > 15 * 15 { f += 15 }
        return f
    }

    /// Model of the mode-2 step of the EXE's RNG @0x414400 (a 16-bit LFSR:
    /// feedback = bit4 ^ bit15 of the state, the low byte shifts left and gets the
    /// feedback complement forced into bit 7, output = low byte ^ high byte).
    /// The original seeds it from GetTickCount (@0x41444b), so its exact per-play
    /// sequence is not statically recoverable; a fixed seed keeps our frames pure
    /// while the visible mechanism — a uniform random tile dissolve — is preserved.
    private struct TileRNG {
        private var state: UInt16
        init(seed: UInt16) { state = seed == 0 ? 0xACE1 : seed }
        mutating func next() -> UInt8 {
            let fb = ((state >> 4) ^ (state >> 15)) & 1
            let t = UInt32(state) &* 2 &+ UInt32(fb)
            let low = UInt8(truncatingIfNeeded: t) & 0x7f | (fb == 0 ? 0x80 : 0x00)
            let high = UInt8(truncatingIfNeeded: t >> 8)
            state = (UInt16(high) << 8) | UInt16(low)
            return UInt8(truncatingIfNeeded: UInt32(state & 0xff) ^ UInt32(state >> 8))
        }
    }

    /// SLANTTILE @0x404c50 generation order over the fixed 40×25 grid of 16px tiles:
    /// two draws give (col, row) = ((r·40)>>8, (r·25)>>8); an occupied slot probes
    /// forward with wraparound (exactly the `inc ecx / cmp cx,0x3e8` loop at
    /// 0x404d28). A free slot always exists while fewer than 1000 tiles are placed,
    /// so the loop terminates and the order is a permutation of 0..<1000.
    private static let slantOrder: [Int] = {
        let cols = 40, rows = 25, tiles = cols * rows
        var rng = TileRNG(seed: 0xACE1)
        var used = [Bool](repeating: false, count: tiles)
        var order: [Int] = []
        order.reserveCapacity(tiles)
        while order.count < tiles {
            let col = (Int(rng.next()) &* cols) >> 8
            let row = (Int(rng.next()) &* rows) >> 8
            var idx = row &* cols + col
            while used[idx] {
                idx += 1
                if idx == tiles { idx = 0 }
            }
            used[idx] = true
            order.append(idx)
        }
        return order
    }()

    /// GURUGURUDisp's expanding spiral, ported from `LvnsEffect.c:319-395` in the
    /// non-MGL build (`BSIZE` = 16, `FACTOR` = 32), so the walk runs directly on the
    /// 16px tile grid: it starts at `x = 27`, `y = HEIGHT / FACTOR` (= 12) with arms
    /// `lenx` = 16 / `leny` = 1 that each grow one cell per half-turn, moving
    /// left→down→right→up, and stops when the up-arm drives `y < 0`. On the 40×25 grid
    /// that reaches `x` = 40 / `y` = 25 exactly as it terminates, so the spiral sweeps
    /// every tile. (The `#ifdef USE_MGL` variant runs the same walk on an 8px grid from
    /// `y = HEIGHT / 16` = 25; there `y < 0` fires while `x` is only at tile ~26, which
    /// is why that geometry leaves the right third to a top-to-bottom fill — not what
    /// the shipped game does.)
    static func guruguruOrder(cols: Int, rows: Int) -> [Int] {
        var x = 27
        var y = logicalHeight / 32
        var lenx = 16
        var leny = 1
        var dir = 0
        var len = 0
        var seen = [Bool](repeating: false, count: cols * rows)
        var order: [Int] = []
        while y >= 0, order.count < cols * rows {
            if x >= 0, x < cols, y < rows {
                let idx = y * cols + x
                if !seen[idx] {
                    seen[idx] = true
                    order.append(idx)
                }
            }
            len += 1
            switch dir {
            case 0:
                x -= 1
                if len == lenx { lenx += 1; len = 0; dir = 1 }
            case 1:
                y += 1
                if len == leny { leny += 1; len = 0; dir = 2 }
            case 2:
                x += 1
                if len == lenx { lenx += 1; len = 0; dir = 3 }
            default:
                y -= 1
                if len == leny { leny += 1; len = 0; dir = 0 }
            }
        }
        if order.count < cols * rows {
            for idx in 0..<(cols * rows) where !seen[idx] {
                order.append(idx)
            }
        }
        return order
    }

    // MARK: - Compositing helpers

    private static func compose(from: RGBAImage, to: RGBAImage, _ useTo: (Int, Int) -> Bool) -> RGBAImage {
        let w = from.width
        let h = from.height
        var out = RGBAImage(width: w, height: h)
        for y in 0..<h {
            for x in 0..<w {
                let s = useTo(x, y) ? to : from
                let i = (y * w + x) * 4
                out.pixels[i] = s.pixels[i]
                out.pixels[i + 1] = s.pixels[i + 1]
                out.pixels[i + 2] = s.pixels[i + 2]
                out.pixels[i + 3] = s.pixels[i + 3]
            }
        }
        return out
    }

    private static func copyRow(_ src: RGBAImage, srcY: Int, into dst: inout RGBAImage, dstY: Int) {
        guard srcY >= 0, srcY < src.height, dstY >= 0, dstY < dst.height else { return }
        let w4 = src.width * 4
        guard w4 == dst.width * 4 else { return }
        let si = srcY * w4
        let di = dstY * w4
        dst.pixels.replaceSubrange(di..<(di + w4), with: src.pixels[si..<(si + w4)])
    }

    private static func copyColumn(_ src: RGBAImage, srcX: Int, into dst: inout RGBAImage, dstX: Int) {
        guard srcX >= 0, srcX < src.width, dstX >= 0, dstX < dst.width, src.height == dst.height else { return }
        for y in 0..<src.height {
            let si = (y * src.width + srcX) * 4
            let di = (y * dst.width + dstX) * 4
            dst.pixels[di] = src.pixels[si]
            dst.pixels[di + 1] = src.pixels[si + 1]
            dst.pixels[di + 2] = src.pixels[si + 2]
            dst.pixels[di + 3] = src.pixels[si + 3]
        }
    }

    /// Sample an image into the `from` canvas with clamped coordinates so the
    /// pixel-grid geometry above stays valid (the engine normally passes
    /// identically sized canvases).
    private static func normalized(_ img: RGBAImage, width w: Int, height h: Int) -> RGBAImage {
        guard w > 0, h > 0 else { return img }
        var out = RGBAImage(width: w, height: h)
        for y in 0..<h {
            let sy = Swift.min(y * img.height / h, img.height - 1)
            for x in 0..<w {
                let sx = Swift.min(x * img.width / w, img.width - 1)
                let si = (sy * img.width + sx) * 4
                let di = (y * w + x) * 4
                out.pixels[di] = img.pixels[si]
                out.pixels[di + 1] = img.pixels[si + 1]
                out.pixels[di + 2] = img.pixels[si + 2]
                out.pixels[di + 3] = img.pixels[si + 3]
            }
        }
        return out
    }
}
