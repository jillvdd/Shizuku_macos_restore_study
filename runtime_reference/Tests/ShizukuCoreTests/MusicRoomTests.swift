//
//  MusicRoomTests.swift
//  ShizukuCoreTests
//
//  音楽モード (HANDOVER 30.3). The room is the one screen whose strings came straight out
//  of `Sizuku.exe`'s tables rather than a script, so nothing downstream would notice a
//  glyph the dot-matrix font lacks or a slot that names a missing OGG — `MusicRoom.draw`
//  silently skips an uncoverable leaf, and `AudioController` just fails to start playback.
//  These lock both, plus the two geometry facts the disassembly hinged on.
//

import XCTest
@testable import ShizukuCore
@testable import ShizukuEngine
@testable import ShizukuRender

final class MusicRoomTests: XCTestCase {

    private static let extractedDir: String = {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("research/extracted")
            .path
    }()

    private static let game: GameData = GameData(extractedDir: extractedDir)

    /// Everything the room can ever paint, including the 24 `ＮＯ．` renderings.
    private static var allStrings: [String] {
        var s = ["音楽モード", "演奏中の曲", "選択中の曲", "作曲・編曲",
                 "右クリックまたはＥＳＣで終了"]
        s += MusicRoom.titles
        s += MusicRoom.composers
        s += MusicRoom.buttonLabels
        s += (0..<MusicRoom.trackCount).map { String(format: "ＮＯ．%02d", $0) }
        return s
    }

    func testEveryRoomStringIsSpellableInTheDotMatrixFont() {
        let codec = Self.game.leafCodec
        for text in Self.allStrings {
            XCTAssertEqual(codec.uncovered(in: text), [], "\(text) has glyphs sizfont.tbl lacks")
        }
    }

    func testTrackTablesAlignAndEverySlotHasItsOwnOGG() {
        let audio = AudioController(baseDir: Self.extractedDir)
        XCTAssertEqual(MusicRoom.titles.count, MusicRoom.trackCount)
        XCTAssertEqual(MusicRoom.composerOfTrack.count, MusicRoom.trackCount)
        for i in 0..<MusicRoom.trackCount {
            XCTAssertTrue(MusicRoom.composerOfTrack[i] < MusicRoom.composers.count,
                          "slot \(i) credits a composer the table doesn't hold")
            XCTAssertNotNil(audio.bgmURL(for: MusicRoom.musicFileIndex(i)),
                            "slot \(i) (\(MusicRoom.titles[i])) would open a silent player")
        }
    }

    func testNoTrackNameRunsOffTheCard() {
        // The name column is fixed at 384, so the longest of the 24 decoded strings has to
        // fit before the 640-px edge — the original reserved the same right-hand column.
        let longest = MusicRoom.titles.max { Self.width($0) < Self.width($1) }!
        XCTAssertEqual(longest, "トゥルーエンド")
        XCTAssertLessThan(MusicRoom.Layout.nameColumnX + Self.width(longest), 640)
    }

    private static func width(_ text: String) -> Int { game.leafCodec.leaves(for: text).count * 24 }

    func testButtonGeometryKeepsTheXIn8PixelReading() {
        // `X22 / X37 / X49` -> 176/296/392 is what proves X counts 8-px cells (30.3); the
        // three labels must stay symmetric about the 640-px canvas centre.
        let widths = MusicRoom.buttonLabels.map { Self.game.leafCodec.leaves(for: $0).count * 24 }
        XCTAssertEqual(widths, [72, 48, 72])
        let centres = zip(MusicRoom.Layout.buttonX, widths).map { $0 + $1 / 2 }
        XCTAssertEqual(centres[1], 320, "「演奏」 must sit on the centre line")
        XCTAssertEqual(centres[0] + centres[2], 640, "the outer buttons mirror each other")
    }

    func testTitleEntrySharesNoPixelWithTheTitleRows() {
        // `mouseDown` tests the invisible 5th item *before* the rows; that ordering is only
        // safe while the two hit sets are disjoint.
        let entry = MusicRoom.entryHitRect(scale: 1)
        let rows = [MenuStrings.newGame, MenuStrings.continueGame, MenuStrings.recallMode,
                    MenuStrings.endingsList, MenuStrings.quit]
        for (i, leaves) in rows.enumerated() {
            let row = SceneComposer.menuLineRect(leaves: leaves, line: 7 + i)
            XCTAssertFalse(entry.intersects(row), "title row \(i) would swallow the music entry")
        }
        XCTAssertEqual(entry.minX, CGFloat(MusicRoom.titleEntryX))
        XCTAssertEqual(entry.minY, CGFloat(MusicRoom.titleEntryY))
    }
}
