//
//  GalleryView.swift
//  ShizukuRender
//
//  「回想モード」 — the title-menu CG viewer.
//
//  Our design, not a reconstruction: `Sizuku.exe`'s title item pointer table (`0x430ebc`)
//  has exactly five entries and the fifth is the invisible 音楽モード cell, so the 1996
//  title menu carried no recall entry. (The mglvns port lists the label behind `#if 0` in
//  `sizuku_op.c:182-191` and never draws it — that says nothing about the original either
//  way, see HANDOVER 30.3; `ChangeLog.mglvns:22` does record a sepia tone the porter
//  intended.) So the layout here is ours: a thumbnail grid, click a cell to enlarge,
//  Esc back to the title.
//
//  Unlock rule is per-scenario read state (the reader's choice): a CG is revealed once
//  any scenario that shows it has had text read, i.e. `seenHighWater[scn] > 0`. Cells
//  still locked render as black with a 「？」, so progress is visible without spoiling.
//
//  Geometry is native (640x400) and every public rect is in that space, matching the
//  hit-testing convention the App uses (`viewToNative` then `contains`).
//

import CoreGraphics
import Foundation
import ShizukuCore
import ShizukuEngine

public enum GalleryView {

    public static let cols = 4
    public static let rows = 3
    public static var perPage: Int { cols * rows }

    /// Grid cell size and origin in native px. Four columns of 150 px with 10 px gaps
    /// span 630 of the 640; three rows of 94 px end at y=346, leaving line 11 free for
    /// the hint.
    public static let cellW = 150
    public static let cellH = 94
    public static let originX = 5
    public static let originY = 44
    public static let gapX = 10
    public static let gapY = 10

    /// Native rect of grid cell `i` (index within the page, row-major).
    public static func cellRect(_ i: Int) -> CGRect {
        CGRect(x: originX + (i % cols) * (cellW + gapX),
               y: originY + (i / cols) * (cellH + gapY),
               width: cellW, height: cellH)
    }

    public static func pageCellRects() -> [CGRect] { (0..<perPage).map(cellRect) }

    /// One page: the slice of the index plus which of its cells the reader has earned.
    public struct Page {
        public let items: [EventImage]
        public let unlocked: [Bool]
        /// 1-based page number, and how many pages the whole index needs.
        public let number: Int
        public let total: Int
    }

    public static func pageCount(_ items: [EventImage]) -> Int {
        max(1, (items.count + perPage - 1) / perPage)
    }

    public static func page(items: [EventImage], seenHighWater: [Int: Int], number: Int) -> Page {
        let total = pageCount(items)
        let page = min(max(0, number), total - 1)
        let start = page * perPage
        let slice = Array(items[start..<min(start + perPage, items.count)])
        let unlocked = slice.map { item in
            item.scns.contains { (seenHighWater[$0] ?? 0) > 0 }
        }
        return Page(items: slice, unlocked: unlocked, number: page + 1, total: total)
    }

    /// The grid: black frame, one thumbnail per item (locked cells left empty), and a
    /// border marking the cursor. Text — header, 「？」 marks, hint — is drawn by the
    /// caller through `SceneComposer`, which owns the dot-matrix text path.
    public static func renderGrid(game: GameData, page: Page, selected: Int, scale s: Int) -> RGBAImage {
        var img = RGBAImage(width: 640 * s, height: 400 * s)
        img.fill(0, 0, 0, 255)
        for (i, item) in page.items.enumerated() {
            guard page.unlocked[i] else { continue }
            drawFitted(game.image(name: item.name), into: &img, cell: cellRect(i), s: s)
        }
        // Borders after the art: a full-bleed thumbnail would otherwise paint over them
        // and the grid would lose its cell separators.
        for i in 0..<page.items.count {
            stroke(into: &img, cellRect(i), color: (96, 96, 96), s: s)
        }
        if selected >= 0, selected < page.items.count {
            stroke(into: &img, cellRect(selected).insetBy(dx: -2, dy: -2), color: (240, 240, 240), s: s)
        }
        return img
    }

    /// One CG blown up to fill the frame, aspect-fit and centred on black. Most event
    /// images are exactly 640x400 and so land 1:1; the smaller ones (VIS is a mixed bag)
    /// must not be stretched.
    public static func renderZoom(game: GameData, item: EventImage, scale s: Int) -> RGBAImage {
        var img = RGBAImage(width: 640 * s, height: 400 * s)
        img.fill(0, 0, 0, 255)
        drawFitted(game.image(name: item.name), into: &img,
                   cell: CGRect(x: 0, y: 0, width: 640, height: 400), s: s)
        return img
    }

    // MARK: - Internals

    /// Decode an LFG and box-resample it into `cell`, preserving its aspect ratio.
    private static func drawFitted(_ raw: (RGBA: [UInt8], w: Int, h: Int)?,
                                   into img: inout RGBAImage, cell: CGRect, s: Int) {
        guard let raw = raw else { return }
        var src = RGBAImage(width: raw.w, height: raw.h)
        src.blit(raw.RGBA, sw: raw.w, sh: raw.h, dx: 0, dy: 0, alpha: false)
        let k = min(Double(cell.width) / Double(raw.w), Double(cell.height) / Double(raw.h))
        let dw = max(1, Int(Double(raw.w) * k)), dh = max(1, Int(Double(raw.h) * k))
        let thumb = src.resized(to: dw * s, dh * s)
        let dx = Int((cell.minX + (Double(cell.width) - Double(dw)) / 2) * Double(s))
        let dy = Int((cell.minY + (Double(cell.height) - Double(dh)) / 2) * Double(s))
        img.blit(thumb.pixels, sw: thumb.width, sh: thumb.height, dx: dx, dy: dy, alpha: false)
    }

    private static func stroke(into img: inout RGBAImage, _ r: CGRect,
                               color: (UInt8, UInt8, UInt8), s: Int) {
        let x0 = Int(r.minX) * s, y0 = Int(r.minY) * s
        let x1 = Int(r.maxX) * s - 1, y1 = Int(r.maxY) * s - 1
        for x in x0...max(x0, x1) {
            img.setPixel(x, y0, color.0, color.1, color.2)
            img.setPixel(x, y1, color.0, color.1, color.2)
        }
        for y in y0...max(y0, y1) {
            img.setPixel(x0, y, color.0, color.1, color.2)
            img.setPixel(x1, y, color.0, color.1, color.2)
        }
    }
}
