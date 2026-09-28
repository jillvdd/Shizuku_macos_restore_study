//
//  RobustnessTests.swift
//  ShizukuCoreTests
//
//  Release-audit regression locks: every case below is a crash or misbehaviour
//  reproduced from corrupt/truncated external data (or a missing file) during the
//  pre-1.0 audit. Each must now degrade gracefully — nil / rejection / no-op —
//  instead of trapping.
//

import XCTest
@testable import ShizukuCore
@testable import ShizukuEngine
@testable import ShizukuRender

final class RobustnessTests: XCTestCase {

    // MARK: helpers — craft decoder streams (same encodings as the audit probes)

    /// decodeInv literal-only stream: flag byte 0x00 -> 8 inverted literals.
    private func litInv(_ bytes: [UInt8]) -> [UInt8] {
        var out: [UInt8] = []
        var i = 0
        while i < bytes.count {
            out.append(0x00)
            for _ in 0..<8 {
                out.append(i < bytes.count ? ~bytes[i] : 0x00)
                i += 1
            }
        }
        return out
    }

    /// LZS.lzs literal-only stream: flag byte 0xFF -> 8 plain literals.
    private func litPlain(_ bytes: [UInt8]) -> [UInt8] {
        var out: [UInt8] = []
        var i = 0
        while i < bytes.count {
            out.append(0xFF)
            for _ in 0..<8 {
                out.append(i < bytes.count ? bytes[i] : 0x00)
                i += 1
            }
        }
        return out
    }

    private func u16le(_ v: Int) -> [UInt8] { [UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF)] }
    private func u32le(_ v: Int) -> [UInt8] { u16le(v & 0xFFFF) + u16le((v >> 16) & 0xFFFF) }

    private func emptyTempDir() -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: P0-1 — empty sizfont.tbl must build an identity-less codec, not trap

    func testEmptyLeafCodecDoesNotTrap() {
        let codec = LeafCodec(table: Data())
        XCTAssertEqual(codec.leaf(for: "あ"), nil)
        XCTAssertEqual(codec.decode([0]), "\u{3000}")
        _ = LeafCodec(table: Data([0x00]))   // odd single byte: count 0
    }

    // MARK: P0-2/3 — SCN offset tables that claim more entries than the segment holds

    func testTruncatedScnOffsetTableIsBoundedNotFatal() {
        // Event segment: lastBlk = 1000 but only 10 decompressed bytes exist.
        let ev = litInv([0xE8, 0x03] + [UInt8](repeating: 0, count: 8))
        let msg = litInv([UInt8](repeating: 0, count: 10))
        var d: [UInt8] = u16le(1) + u16le(3) + [UInt8](repeating: 0, count: 12)
        d += u32le(10) + ev
        d += [UInt8](repeating: 0, count: 48 - d.count)
        d += u32le(10) + msg
        let s = Scn.parse(d)
        XCTAssertLessThan(s.blocks.count, 1001, "table must clamp to bytes actually present")
    }

    func testTruncatedScnMessageTableIsBoundedNotFatal() {
        let ev = litInv([UInt8](repeating: 0, count: 10))
        let msg = litInv([0xE8, 0x03] + [UInt8](repeating: 0, count: 8))
        var d: [UInt8] = u16le(1) + u16le(3) + [UInt8](repeating: 0, count: 12)
        d += u32le(10) + ev
        d += [UInt8](repeating: 0, count: 48 - d.count)
        d += u32le(10) + msg
        let s = Scn.parse(d)
        XCTAssertLessThan(s.messages.count, 1001)
    }

    // MARK: P0-4 — LFG headers too short / negative canvas / body overflow / inflated size

    private func lfgHeaderBytes() -> [UInt8] {
        [UInt8]("LEAFCODE".utf8) + [UInt8](repeating: 0, count: 48 - 8)
    }

    func testShortLfgIsRejected() {
        XCTAssertNil(Lfg.decode([UInt8]("LEAFCO".utf8)))
        XCTAssertNil(Lfg.decode([]))
    }

    func testNegativeCanvasLfgIsRejected() {
        var d = lfgHeaderBytes()
        d.replaceSubrange(32..<34, with: u16le(65535))   // xoffset*8 far beyond width
        d.replaceSubrange(36..<38, with: u16le(0))       // width = 8
        d.replaceSubrange(38..<40, with: u16le(0))       // height = 1
        XCTAssertNil(Lfg.decode(d))
    }

    func testOverlongHorizontalBodyIsClipped() {
        var d = lfgHeaderBytes()
        d.replaceSubrange(36..<38, with: u16le(0))       // width = 8 -> cw 8
        d.replaceSubrange(38..<40, with: u16le(0))       // height = 1 -> ch 1
        d.replaceSubrange(40..<41, with: [1])            // HORIZONTAL
        d.replaceSubrange(41..<42, with: [0xFF])         // transparent = none
        d.replaceSubrange(44..<48, with: u32le(10))      // 10 body bytes for 8 px
        d += litPlain([UInt8](repeating: 0x00, count: 10))
        let r = Lfg.decode(d)                             // must not walk idx past cw*ch
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.1, 8)
        XCTAssertEqual(r?.2, 1)
    }

    func testGiganticDeclaredLfgSizeIsRejected() {
        var d = lfgHeaderBytes()
        d.replaceSubrange(36..<38, with: u16le(79))      // width 640
        d.replaceSubrange(38..<40, with: u16le(399))     // height 400
        d.replaceSubrange(44..<48, with: u32le(0xFFFFFFF0))  // ~4 GiB body
        d += [UInt8](repeating: 0, count: 64)
        XCTAssertNil(Lfg.decode(d), "LZS must never be asked to preallocate a corrupt size")
    }

    // MARK: P0-5 — missing font file degrades to an empty font, not a startup trap

    func testMissingKnjFileReturnsNil() {
        XCTAssertNil(KnjFont(path: "/nonexistent_dir_zzz/KNJ_ALL.KNJ"))
    }

    func testGameDataWithEmptyDirDegradesGracefully() {
        let dir = emptyTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let game = GameData(extractedDir: dir.path)
        XCTAssertEqual(game.font.glyphCount, 0)
        XCTAssertNil(game.font.pixels(0))
        XCTAssertNil(game.leafCodec.leaf(for: "あ"))
    }

    // MARK: P0-7 — corrupt LEAFPACK containers rejected, not precondition-killed

    func testCorruptLeafpackIsRejected() {
        let short = [UInt8](repeating: 0, count: 20)
        XCTAssertNil(Leafpack.guessKey(short))

        var hdr = [UInt8]("LEAFPACK".utf8) + u16le(65535) + [UInt8](repeating: 0, count: 30)
        XCTAssertNil(Leafpack.guessKey(hdr), "n=65535 makes the table start negative")
        XCTAssertNil(Leafpack.open(archiveBytes: hdr))

        // A well-shaped 4-record frame (the original key recovery needs 96 table bytes)
        // must parse without trapping even though the record values are junk.
        hdr = [UInt8]("LEAFPACK".utf8) + u16le(4) + [UInt8](repeating: 0, count: 30)
            + [UInt8](repeating: 0, count: 96)
        XCTAssertNotNil(Leafpack.open(archiveBytes: hdr))

        let key = [UInt8](repeating: 0, count: Leafpack.keyLen)
        let oob = LeafpackEntry(name: "X.LFG", offset: 999_999, size: 999_999, nextOffset: 0)
        XCTAssertTrue(Leafpack.fileBytes(hdr, key, oob).isEmpty,
                      "entry pointing outside the archive yields empty bytes")
    }

    // MARK: P1-1 — palette override from a hand-edited save

    func testRaggedPaletteOverrideDropsPartialTriple() {
        let o = PaletteOverride(start: 0, rgb: [1, 2, 3, 4])
        XCTAssertEqual(o.colors.count, 1)
        XCTAssertEqual(o.colors[0].0, 1)
    }

    func testNegativeStartPaletteOverrideIsIgnored() {
        var d = lfgHeaderBytes()
        d.replaceSubrange(36..<38, with: u16le(1))       // width = 16
        d.replaceSubrange(38..<40, with: u16le(0))       // height = 1
        d.replaceSubrange(41..<42, with: [0xFF])         // transparent = none
        d.replaceSubrange(44..<48, with: u32le(8))       // 8 body bytes = 16 px
        d += litPlain([UInt8](repeating: 0, count: 8))
        let r = Lfg.decode(d, paletteOverride: PaletteOverride(start: -5, rgb: [9, 9, 9]))
        XCTAssertNotNil(r)
    }

    // MARK: LZS — negative outSize guard

    func testLzsNegativeOutSizeReturnsEmpty() {
        XCTAssertTrue(LZS.lzs([1, 2, 3], outSize: -1).isEmpty)
        XCTAssertTrue(LZS.leafLzs([1, 2, 3], outSize: -1).isEmpty)
        XCTAssertTrue(LZS.leafLzs3([1, 2, 3], outSize: -1).isEmpty)
    }

    // MARK: P0-6 — SELECT with zero parsed options never arms the choice menu

    func testEmptySelectDoesNotEnterAwaitingChoice() throws {
        let dir = emptyTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        // evRaw = lastBlk 0 | table [4] | 05 00 00 (prompt 0, count 0)
        let evRaw: [UInt8] = [0x00, 0x00, 0x04, 0x00, 0x05, 0x00, 0x00]
        let msgRaw: [UInt8] = [0x00, 0x00]
        var d: [UInt8] = u16le(1) + u16le(3) + [UInt8](repeating: 0, count: 12)
        let evComp = litInv(evRaw)
        d += u32le(evRaw.count) + evComp
        d += [UInt8](repeating: 0, count: 48 - d.count)
        let msgComp = litInv(msgRaw)
        d += u32le(msgRaw.count) + msgComp
        try Data(d).write(to: dir.appendingPathComponent("SCN000.DAT"))

        let game = GameData(extractedDir: dir.path, scnCount: 1)
        XCTAssertEqual(game.scn(0)?.blocks.first?.events.first?.name, "SELECT",
                       "fixture must actually carry the malformed SELECT")
        let engine = ShizukuEngine(game: game)
        engine.start(scn: 0, block: 0)
        _ = engine.step()
        XCTAssertNotEqual(engine.phase, .awaitingChoice, "empty menu must not be presented")
        XCTAssertTrue(engine.choices.isEmpty)

        // The composer's own guard, too: a restored state can claim an open choice menu
        // with no options (hand-edited save); rendering it must return, not index choices[0].
        let composer = SceneComposer(game: game, scale: 1)
        var state = engine.captureSaveState(slot: 0)
        state.phase = .awaitingChoice
        state.choices = []
        engine.restoreSaveState(state)
        var img = RGBAImage(width: 640, height: 400)
        composer.drawChoiceMenu(&img, engine: engine)   // must not trap
    }

    // MARK: P1-4 — save files from a newer format are refused explicitly

    func testSaveVersionGate() throws {
        let dir = emptyTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let mgr = SaveManager(saveDirectory: dir)
        let engine = ShizukuEngine(game: GameData(extractedDir: dir.path), saveManager: mgr)

        let real = engine.captureSaveState(slot: 1, previewText: "probe")
        try mgr.save(slot: 1, engine: engine, previewText: "probe")
        XCTAssertNotNil(mgr.getSaveState(slot: 1), "current-version saves keep loading")

        var json = (try JSONSerialization.jsonObject(with: JSONEncoder().encode(real))) as! [String: Any]
        json["version"] = 99
        try JSONSerialization.data(withJSONObject: json)
            .write(to: mgr.fileURL(for: 1))
        XCTAssertNil(mgr.getSaveState(slot: 1))
        XCTAssertTrue(mgr.listSaves().isEmpty, "listing applies the same gate")
        XCTAssertThrowsError(try mgr.load(slot: 1, into: engine)) { error in
            XCTAssertEqual(error as? SaveState.VersionTooNew, SaveState.VersionTooNew(version: 99))
        }
    }
}
