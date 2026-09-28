//
//  GalleryTests.swift
//  ShizukuCoreTests
//
//  回想モード data layer: the event-image index must contain only images that really
//  unpack, in a stable order, and the unlock rule must follow the system-level per-
//  scenario read high-water (`seen_flag[scn]`, sizuku.h) rather than slot state.
//

import XCTest
@testable import ShizukuCore
@testable import ShizukuEngine
@testable import ShizukuRender

final class GalleryTests: XCTestCase {
    /// Parsing all 197 scripts and decoding the index costs seconds per pass, so the
    /// fixture is shared across the suite rather than rebuilt in `setUpWithError`.
    private static let game: GameData = {
        let extracted = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("research/extracted")
        return GameData(extractedDir: extracted.path)
    }()
    private static let items = game.eventImages()

    func testEventImagesResolveAndStayInFamilyOrder() throws {
        let items = Self.items
        XCTAssertEqual(items.count, 61, "the gallery is VIS + HVS, i.e. 26 + 35 illustration CGs")
        let fams = ["VIS", "HVS"]
        var lastFam = -1
        for item in items {
            // `'B'`/`'E'`/`'S'` and event `0x0a` all load MAX_S through the original's
            // `SizukuLoadBG` path — those are scene plates, and MAX_C is a standing
            // sprite. A reused CG is fine (branches share them); the *opcode* decides.
            XCTAssertFalse(item.name.hasPrefix("MAX_"), "\(item.name) is a background or sprite, not a CG")
            XCTAssertTrue(Self.game.hasImage(named: item.name), "\(item.name) is listed but not unpacked")
            XCTAssertEqual(item.scns, item.scns.sorted(), "\(item.name) scenario list must be sorted")
            XCTAssertEqual(Set(item.scns).count, item.scns.count, "\(item.name) lists a scenario twice")
            guard let f = fams.firstIndex(where: { item.name.hasPrefix($0) }) else { continue }
            XCTAssertGreaterThanOrEqual(f, lastFam, "\(item.name) breaks the family ordering")
            lastFam = max(lastFam, f)
        }
        XCTAssertEqual(Set(items.map { $0.name.prefix(3) }), Set(fams.map { $0.prefix(3) }),
                       "both CG families must be represented")
        // Decoding every LFG here would dominate the suite, so spot-check the pipeline
        // across both families instead.
        for fam in fams {
            for item in items.filter { $0.name.hasPrefix(fam) }.prefix(3) {
                XCTAssertNotNil(Self.game.image(name: item.name), "\(item.name) fails to decode")
            }
        }
    }

    func testUnlockFollowsScenarioReadHighWater() throws {
        let item = try XCTUnwrap(Self.items.first { !$0.scns.isEmpty })
        let page = GalleryView.page(items: [item], seenHighWater: [:], number: 0)
        XCTAssertEqual(page.unlocked, [false], "an unread scenario must leave its CG as 「？」")

        var read: [Int: Int] = [:]
        read[item.scns[0]] = 1
        XCTAssertEqual(GalleryView.page(items: [item], seenHighWater: read, number: 0).unlocked, [true])
    }

    func testPageCountAndClamping() throws {
        let items = Self.items
        let total = GalleryView.pageCount(items)
        XCTAssertEqual(total, (items.count + GalleryView.perPage - 1) / GalleryView.perPage)
        // Out-of-range page numbers clamp instead of trapping the reader on a blank page.
        let clamped = GalleryView.page(items: items, seenHighWater: [:], number: total + 40)
        XCTAssertEqual(clamped.number, total)
        XCTAssertFalse(clamped.items.isEmpty)
    }

    func testGridCellsStayInsideTheNativeFrame() throws {
        for rect in GalleryView.pageCellRects() {
            XCTAssertGreaterThanOrEqual(rect.minX, 0)
            XCTAssertGreaterThanOrEqual(rect.minY, 44, "cells must clear the header line")
            XCTAssertLessThanOrEqual(rect.maxX, 640)
            XCTAssertLessThanOrEqual(rect.maxY, 360, "cells must clear the hint line")
        }
    }
}
