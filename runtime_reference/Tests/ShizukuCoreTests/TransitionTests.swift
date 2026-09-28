//
//  TransitionTests.swift
//  ShizukuCoreTests
//
//  Item 4 evidence: `LvnsClear(out)` → load → `LvnsDisp(in)` is a *pair* of full-screen
//  sweeps plus the 500 ms post-DISP hold (`LvnsEffect.c:906-908`, `LvnsDisp.c:200-213`,
//  `INTERVAL 60`), and the reference's own `-n e` switch (`mgMain.c:76-79`) collapses each
//  phase to a single blit instead of animating it. These lock both shapes.
//

import XCTest
@testable import ShizukuCore
@testable import ShizukuEngine
@testable import ShizukuRender

final class TransitionTests: XCTestCase {

    let extractedDir = "/Users/abc/Documents/shizuku_macos_experience/research/extracted"

    private func makeEngine() -> ShizukuEngine {
        let e = ShizukuEngine(game: GameData(extractedDir: extractedDir))
        e.skip = true
        e.start(scn: 1, block: 1)
        e.skip = false
        return e
    }

    /// Flips until the transition clears itself; the cap keeps a stuck pump from hanging.
    private func drain(_ e: ShizukuEngine) -> Int {
        var n = 0
        while e.transition != nil, n < 2000 { _ = e.tickTransition(); n += 1 }
        return n
    }

    private func flat(_ v: UInt8) -> RGBAImage {
        var img = RGBAImage(width: 640, height: 400)
        img.fill(v, v, v, 255)
        return img
    }

    /// Whether any *colour* channel (alpha is opaque everywhere) still reads `v`.
    private func hasColor(_ img: RGBAImage, _ v: UInt8) -> Bool {
        img.pixels.enumerated().contains { offset, byte in offset % 4 != 3 && byte == v }
    }

    func testScriptWipePairRunsBothSweepsAndTheHold() {
        let e = makeEngine()
        e.beginTransition(clear: .wipeMaskLtoR, disp: .wipeMaskLtoR) {}
        XCTAssertEqual(e.transition?.phase, .clearing)
        let sweep = LvnsEffectTiming.frames(.wipeMaskLtoR, width: 640, height: 400)
        XCTAssertEqual(sweep, 56, "WIDTH/16 + 16 states on the 640-px canvas")

        // Phase boundaries land exactly on the reference's termination conditions.
        for _ in 0..<sweep { _ = e.tickTransition() }
        XCTAssertEqual(e.transition?.phase, .displaying)
        for _ in 0..<sweep { _ = e.tickTransition() }
        XCTAssertEqual(e.transition?.phase, .hold)
        XCTAssertEqual(drain(e), ShizukuEngine.dispHoldFlips)
    }

    func testTotalFlipsMatchTheReferenceLoop() {
        let e = makeEngine()
        e.beginTransition(clear: .wipeMaskLtoR, disp: .wipeMaskLtoR) {}
        // 56 erase + 56 reveal + 30-flip (500 ms) hold — the same 142 flips the live
        // `SHIZUKU_SHOT=trans` harness counts off the real `B07 08 08` script command.
        XCTAssertEqual(drain(e), 56 + 56 + ShizukuEngine.dispHoldFlips)
    }

    func testEffectsOffCollapsesEachPhaseToOneBlitAndKeepsTheHold() {
        let e = makeEngine()
        e.effectsEnabled = false
        e.beginTransition(clear: .wipeMaskLtoR, disp: .wipeMaskLtoR) {}
        let tr = e.transition
        XCTAssertEqual(tr?.clearEffect, .normal, "-n e maps the animated wipe to NORMAL")
        XCTAssertEqual(tr?.dispEffect, .normal)
        XCTAssertEqual(drain(e), 1 + 1 + ShizukuEngine.dispHoldFlips)
    }

    func testWipeSweepsTheWholeCanvas() {
        let from = flat(255)
        let to = flat(0)
        let total = LvnsEffectTiming.frames(.wipeMaskLtoR, width: 640, height: 400)

        let mid = TransitionRenderer.render(effect: .wipeMaskLtoR, from: from, to: to,
                                            frame: total / 2)
        XCTAssertTrue(hasColor(mid, 0), "the reveal has started")
        XCTAssertTrue(hasColor(mid, 255), "the sweep has not swallowed the screen yet")

        let last = TransitionRenderer.render(effect: .wipeMaskLtoR, from: from, to: to,
                                            frame: total - 1)
        XCTAssertFalse(hasColor(last, 255),
                       "the sweep must have covered every pixel, not just part of the screen")
    }

    func testScaledCanvasKeepsTheSameSweepShape() {
        // The window runs at scale 2, so the layers handed to the renderer are 1280×800.
        // Upscaling must not shrink the geometry into the left half of the screen.
        var big = RGBAImage(width: 1280, height: 800)
        big.fill(0, 0, 0, 255)
        var white = big
        white.fill(255, 255, 255, 255)
        let total = LvnsEffectTiming.frames(.wipeMaskLtoR, width: 640, height: 400)
        let last = TransitionRenderer.render(effect: .wipeMaskLtoR, from: white, to: big,
                                            frame: total - 1)
        XCTAssertEqual(last.width, 1280)
        XCTAssertEqual(last.height, 800)
        XCTAssertFalse(hasColor(last, 255), "the 2x canvas is swept edge to edge too")
    }

    /// The opening's spiral wipe (`GURUGURU`). The earlier port ran the walk on the
    /// `#ifdef USE_MGL` 8px grid (start `y = HEIGHT/16`), where `y < 0` fires while `x`
    /// is only at tile ~26 — the right third then fell to the row-major fallback, i.e.
    /// a top-to-bottom fill. The non-MGL geometry (`BSIZE 16`, start `y = HEIGHT/32`)
    /// covers the screen with the spiral itself. `Sizuku.exe` forensics (2026-09-23)
    /// confirmed the branch: dispatch case 1 -> 0x404850, 16px tiles (`shl 4`), start
    /// (27,12) stored in .data @0x4307ea, arm table @0x430788 walked in reverse, and
    /// 8 tiles per present (`test al,7` @0x404b0c) -> 125 flips for the 40x25 grid.
    func testGuruguruSpiralReachesTheRightEdgeItself() {
        let cols = 40, rows = 25
        let order = TransitionRenderer.guruguruOrder(cols: cols, rows: rows)
        XCTAssertEqual(Set(order).count, cols * rows, "every tile revealed exactly once")
        XCTAssertEqual(order.max(), cols * rows - 1, "the walk reaches the far corner")
        // A row-major fallback tail is strictly increasing; the spiral's perimeter is not.
        let tail = order.suffix(cols * rows / 3)
        XCTAssertFalse(zip(tail, tail.dropFirst()).allSatisfy(<),
                       "the right third must spiral in, not fill top-to-bottom")
        XCTAssertEqual(LvnsEffectTiming.frames(.guruguru, width: 640, height: 400), 125,
                       "EXE presents every 8 tiles: 1000/8 = 125 flips, not 100")
    }

    // MARK: - EXE-alignment locks (2026-09-23 handler forensics, dispatcher @0x404740)

    private func red(_ img: RGBAImage, _ x: Int, _ y: Int) -> UInt8 { img.pixels[(y * img.width + x) * 4] }

    /// The @0x430754 phase table's first revealed 4×4 class is top-down (x%4=0, y%4=3);
    /// mglvns' xoff/yoff ordering disagrees in 28676/28676 sampled pixels.
    func testFadeMaskPhaseZeroFollowsTheExeTable() {
        let from = flat(255), to = flat(0)
        let f0 = TransitionRenderer.render(effect: .fadeMask, from: from, to: to, frame: 0)
        XCTAssertEqual(red(f0, 0, 3), 0, "class (0,3) is the EXE table's phase 0")
        XCTAssertEqual(red(f0, 0, 0), 255, "class (0,0) is phase 15, the last, not 0")
        XCTAssertEqual(red(f0, 1, 3), 255, "x%4=1 never reveals at phase 0 in the EXE table")
        // And a white→black wipeMask sweep on the same table: column 0, row y%4=3 at f=0.
        let w = TransitionRenderer.render(effect: .wipeMaskLtoR, from: from, to: to, frame: 0)
        XCTAssertEqual(red(w, 0, 3), 0)
        XCTAssertEqual(red(w, 0, 0), 255)
    }

    /// EXE enumerations: frame f paints rows 16f−17k (k=0..15) / columns 16f−15k.
    /// Cross-checked against every one of the 400 rows and 640 columns in Python.
    func testCombWipesFollowTheExeToothLaws() {
        let from = flat(255), to = flat(0)
        XCTAssertEqual(LvnsEffectTiming.frames(.wipeTtoB, width: 640, height: 400), 41)
        XCTAssertEqual(LvnsEffectTiming.frames(.wipeLtoR, width: 640, height: 400), 56)
        let t1 = TransitionRenderer.render(effect: .wipeTtoB, from: from, to: to, frame: 1)
        XCTAssertEqual(red(t1, 320, 0), 0)
        XCTAssertEqual(red(t1, 320, 16), 0, "v=16 = 16·1−17·0")
        XCTAssertEqual(red(t1, 320, 1), 255, "v=1 waits until f=16 (16·16−17·15)")
        let t15 = TransitionRenderer.render(effect: .wipeTtoB, from: from, to: to, frame: 15)
        XCTAssertEqual(red(t15, 320, 1), 255)
        let t16 = TransitionRenderer.render(effect: .wipeTtoB, from: from, to: to, frame: 16)
        XCTAssertEqual(red(t16, 320, 1), 0, "row 1 first painted at f=16")
        let l1 = TransitionRenderer.render(effect: .wipeLtoR, from: from, to: to, frame: 1)
        XCTAssertEqual(red(l1, 0, 200), 0)
        XCTAssertEqual(red(l1, 16, 200), 0, "x=16 = 16·1−15·0")
        XCTAssertEqual(red(l1, 15, 200), 255, "x=15 has to wait for f=15 (k=15 is the tooth cap)")
        let l16 = TransitionRenderer.render(effect: .wipeLtoR, from: from, to: to, frame: 16)
        XCTAssertEqual(red(l16, 31, 200), 0, "x=31 = 16·16−15·15")
        let last = TransitionRenderer.render(effect: .wipeTtoB, from: from, to: to, frame: 40)
        XCTAssertFalse(hasColor(last, 255), "41 frames cover all 400 rows")
    }

    /// @0x405560 StretchDIBits-scales the whole new image into a growing centred band —
    /// the opposite of the old cropped-strip zoom-out model.
    func testVertCompositionGrowsACentredMiniatureBand() {
        let from = flat(255), to = flat(0)
        XCTAssertEqual(LvnsEffectTiming.frames(.vertComposition, width: 640, height: 400), 32)
        let f0 = TransitionRenderer.render(effect: .vertComposition, from: from, to: to, frame: 0)
        XCTAssertEqual(red(f0, 320, 187), 0, "state 1 band = 25 rows centred at y=187..<212")
        XCTAssertEqual(red(f0, 320, 211), 0)
        XCTAssertEqual(red(f0, 320, 186), 255, "outside the band stays the old scene")
        XCTAssertEqual(red(f0, 320, 0), 255)
        let f2 = TransitionRenderer.render(effect: .vertComposition, from: from, to: to, frame: 4)
        XCTAssertEqual(red(f2, 320, 162), 0, "state 3 band = 75 rows")
        XCTAssertEqual(red(f2, 320, 150), 255)
        let last = TransitionRenderer.render(effect: .vertComposition, from: from, to: to, frame: 31)
        XCTAssertFalse(hasColor(last, 255))
    }

    /// @0x405680: one state per frame (16 total), not mglvns' LvnsWait(1) half speed.
    func testSlideLtoRRunsOneStatePerFrame() {
        let from = flat(255), to = flat(0)
        XCTAssertEqual(LvnsEffectTiming.frames(.slideLtoR, width: 640, height: 400), 16)
        let f0 = TransitionRenderer.render(effect: .slideLtoR, from: from, to: to, frame: 0)
        XCTAssertEqual(red(f0, 0, 100), 0, "column class 0 in the first frame")
        XCTAssertEqual(red(f0, 1, 100), 255)
        let f1 = TransitionRenderer.render(effect: .slideLtoR, from: from, to: to, frame: 1)
        XCTAssertEqual(red(f1, 17, 100), 0, "class 1 joins on frame 1, not frame 2")
        let last = TransitionRenderer.render(effect: .slideLtoR, from: from, to: to, frame: 15)
        XCTAssertFalse(hasColor(last, 255))
    }

    /// @0x404e40 states 0...32 and @0x405090 states 0...51, each held ~30 ms (2 flips).
    func testSquareMaskEffectsUseTheExeStateBudgets() {
        let from = flat(255), to = flat(0)
        XCTAssertEqual(LvnsEffectTiming.frames(.fadeSquare, width: 640, height: 400), 66)
        XCTAssertEqual(LvnsEffectTiming.frames(.wipeSquareLtoR, width: 640, height: 400), 104)
        let mid = TransitionRenderer.render(effect: .fadeSquare, from: from, to: to, frame: 32)
        XCTAssertTrue(hasColor(mid, 0) && hasColor(mid, 255), "state 16 of 32 is mid-sweep")
        let wMid = TransitionRenderer.render(effect: .wipeSquareLtoR, from: from, to: to, frame: 50)
        XCTAssertEqual(red(wMid, 630, 200), 255, "the right edge lags one column-state per 32px")
        let fsLast = TransitionRenderer.render(effect: .fadeSquare, from: from, to: to, frame: 65)
        XCTAssertFalse(hasColor(fsLast, 255))
        let wsLast = TransitionRenderer.render(effect: .wipeSquareLtoR, from: from, to: to, frame: 103)
        XCTAssertFalse(hasColor(wsLast, 255))
    }

    /// @0x404c50: xorshift draw + probe-dedup dissolve, 32 tiles per frame. The head of
    /// the sequence is byte-verified against the Python model of the handler
    /// (first tile = index 204 → centre (72,88)); a matching first batch proves the
    /// LFSR step and the (r·40)>>8 / (r·25)>>8 scaling ported faithfully.
    func testSlantTileDissolvesRandomlyNotInSlantedBands() {
        let from = flat(255), to = flat(0)
        XCTAssertEqual(LvnsEffectTiming.frames(.slantTile, width: 640, height: 400), 32)
        let f0 = TransitionRenderer.render(effect: .slantTile, from: from, to: to, frame: 0)
        XCTAssertEqual(red(f0, 72, 88), 0, "tile 204 is the first draw of the seeded LFSR")
        XCTAssertEqual(red(f0, 0, 0), 255, "ordered band starts would always reveal the top row")
        let black = f0.pixels.enumerated().filter { $0.offset % 4 == 0 && $0.element == 0 }.count
        XCTAssertEqual(black, 32 * 16 * 16, "frame 0 reveals exactly 32 tiles")
        let last = TransitionRenderer.render(effect: .slantTile, from: from, to: to, frame: 31)
        XCTAssertFalse(hasColor(last, 255), "1000/32 = 32 presents cover the grid")
    }

    /// @0x404810: old screen dies instantly, then a monotonic ~600 ms (36 flips) ramp.
    func testFadePaletteIsInstantBlackThenSmoothFadeIn() {
        let from = flat(255)
        let to = flat(200)
        let total = LvnsEffectTiming.frames(.fadePalette, width: 640, height: 400)
        XCTAssertEqual(total, 36)
        // Clearing phase: to = black ⇒ frame 0 already shows no old-scene colour at all.
        let clear = TransitionRenderer.render(effect: .fadePalette, from: from, to: flat(0), frame: 0)
        XCTAssertFalse(hasColor(clear, 255), "the old scene is gone on the first frame")
        var previous = -1
        for f in 0..<total {
            let img = TransitionRenderer.render(effect: .fadePalette, from: from, to: to, frame: f)
            let v = Int(red(img, 320, 200))
            XCTAssertGreaterThan(v, previous, "ramp strictly increases at f=\(f)")
            XCTAssertLessThanOrEqual(v, 200)
            previous = v
        }
        let done = TransitionRenderer.render(effect: .fadePalette, from: from, to: to, frame: total - 1)
        XCTAssertEqual(red(done, 320, 200), 200, "the ramp lands exactly on the target")
    }
}
