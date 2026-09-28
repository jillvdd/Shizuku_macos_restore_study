//
//  FontPipelineTests.swift
//  ShizukuCoreTests
//
//  Locks the KNJ glyph pipeline invariants established against the original
//  engine (XLVNS sizuku_etc.c drawChar / LvnsText.c PutChar): col-major 1bpp
//  bit layout, 1-based leaf codes (slot = leaf - 1), and the leaf codes baked
//  into MenuStrings.
//

import XCTest
@testable import ShizukuCore
@testable import ShizukuEngine
@testable import ShizukuRender

final class FontPipelineTests: XCTestCase {
    var game: GameData!

    override func setUpWithError() throws {
        let extracted = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("research/extracted")
        game = try XCTUnwrap(GameData(extractedDir: extracted.path))
    }

    /// KNJ_ALL.KNJ is 133,344 B of pure 72-byte glyphs, no header: 1852 slots.
    func testGlyphCount() throws {
        XCTAssertEqual(game.cnFont.glyphCount, 1852)
    }

    /// Col-major decode golden: leaf 1 (■, sizfont a2a3) is slot 0 and is a
    /// fully-inked 24x24 block; leaf 2 (あ) is slot 1 with ink 173. A row-major
    /// decode (glyph[row*3+col]) would produce different totals.
    func testColMajorLayoutGolden() throws {
        let block = try XCTUnwrap(game.cnFont.pixels(game.textSlot(forLeaf: 1)))
        XCTAssertEqual(block.map { $0.reduce(0, +) }.reduce(0, +), 576)

        let a = try XCTUnwrap(game.cnFont.pixels(game.textSlot(forLeaf: 2)))
        let widths = a.map { $0.reduce(0, +) }
        XCTAssertEqual(widths.reduce(0, +), 173)
        XCTAssertEqual(widths, [0, 3, 5, 6, 11, 10, 5, 4, 7, 12, 11, 10,
                                10, 9, 11, 10, 10, 10, 13, 8, 4, 4, 0, 0])
    }

    /// Leaf 102 (XLVNS cursor_key, sizfont a1e4) renders as a solid right-pointing
    /// triangle: widest at mid-height (13 px on row 11), tapering to 2 px.
    func testCursorKeyGlyphShape() throws {
        let tri = try XCTUnwrap(game.cnFont.pixels(game.textSlot(forLeaf: 102)))
        let widths = tri.map { $0.reduce(0, +) }
        XCTAssertEqual(widths[3], 2)
        XCTAssertEqual(widths[11], 13)
        XCTAssertEqual(widths[19], 2)
        // Left edge is a vertical bar: every inked row starts at the same column.
        let lefts = widths.enumerated().filter { $0.element > 0 }.map { tri[$0.offset].firstIndex(of: 1)! }
        XCTAssertEqual(Set(lefts).count, 1)
    }

    func testGlyphMapIdentityFallback() throws {
        let map = GlyphMap()
        XCTAssertEqual(map.slot(forLeaf: 0), 0)   // space cell, advance only
        XCTAssertEqual(map.slot(forLeaf: 1), 0)   // leaf codes are 1-based
        XCTAssertEqual(map.slot(forLeaf: 1851), 1850)
    }

    /// Out-of-range slots decode to nil so renderers advance without drawing
    /// (matches PutChar's `if (code)` skip, LvnsText.c:51).
    func testOutOfRangeSlotIsNil() throws {
        XCTAssertNil(game.cnFont.pixels(game.cnFont.glyphCount))
        XCTAssertNil(game.cnFont.pixels(-1))
    }

    /// MenuStrings leaf codes must resolve against sizfont.tbl (EUC-JP pairs,
    /// entry index == leaf code). Guards the hand-transcribed UI constants.
    func testMenuStringsAgainstSizfontTbl() throws {
        let tblPath = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("research/thirdparty/mglvns/mglvns-1.0/sizfont.tbl")
        let tbl = try XCTUnwrap(Data(contentsOf: tblPath))
        let decode: (Int) -> String = { leaf in
            var bytes = [tbl[leaf * 2], tbl[leaf * 2 + 1]]
            bytes[0] |= 0x80
            bytes[1] |= 0x80
            return String(data: Data(bytes), encoding: .japaneseEUC) ?? "?"
        }
        XCTAssertEqual(MenuStrings.newGame.map(decode).joined(), "はじめから")
        XCTAssertEqual((78...83).map(decode).joined(), "１２３４５６")
    }

    /// Phase-2: every string the UI draws through LeafCodec must encode with
    /// zero uncovered characters, otherwise the dot-matrix renderer silently
    /// drops glyphs. Covers UIText constants, the slot-picker headers and all
    /// MetalGameView toast texts (kept in sync by hand).
    func testUITextStringsFullyCoveredByFont() throws {
        let codec = game.leafCodec
        var toasts = [
            "既読テキスト自動スキップ [ON]", "早送り未読スキップ [OFF]",
            "中文データがないため日本語のまま", "言語を 日本語 に変更", "言語を 中文 に変更",
            "セーブデータをロードしました [SLOT 1]", "セーブデータが見つかりません",
            "セーブデータがありません", "クイックセーブ完了 [SLOT 0]", "セーブに失敗しました",
            "スキップモード [ON]", "未読のためスキップできません",
            "一つ前の選択肢に戻りました", "選択肢の保存点はありません",
            "しおり 6は空です", "クイックセーブは空です",
            "ロードに失敗しました", "セーブしました [しおり 2]",
            "セーブするしおりを選択してください", "ロードするデータを選択してください",
            "09月21日 10時33",
        ]
        toasts += Self.skipHotkeyLabels.map { "スキップキーを \($0) に変更" }
        for s in UIText.allStaticStrings + toasts {
            XCTAssertEqual(codec.uncovered(in: s), [], "uncovered glyphs in: \(s)")
        }
        // Ending titles render in the endings overlay; all 13 must be in-font.
        for ending in ShizukuEnding.allCases {
            XCTAssertEqual(codec.uncovered(in: ending.titleJP), [], "uncovered in title: \(ending.titleJP)")
        }
    }

    private static let skipHotkeyLabels = ["Tab", "Z", "X", "C", "Shift", "Ctrl"]

    /// Fold rules: ASCII digits/letters to full-width, ':' to '・', '[' to '（'.
    func testLeafCodecFoldRules() throws {
        let codec = game.leafCodec
        XCTAssertEqual(codec.leaves(for: "SCN001"), codec.leaves(for: "ＳＣＮ００１"))
        XCTAssertEqual(codec.leaves(for: "Tab"), codec.leaves(for: "ＴＡＢ"))
        XCTAssertEqual(codec.leaves(for: ":"), codec.leaves(for: "・"))
        XCTAssertEqual(codec.leaves(for: "["), codec.leaves(for: "（"))
        XCTAssertEqual(codec.leaves(for: " "), [0])   // halfwidth space -> blank cell
        XCTAssertEqual(codec.leaf(for: "歴"), nil)    // documented gap: font lacks 歴
    }

    /// Round-trip through the sizfont reverse map: encoding then decoding the
    /// menu label must return the original text (save-slot previews rely on it).
    func testLeafCodecDecodeRoundTrip() throws {
        let codec = game.leafCodec
        for s in ["はじめから", "クイックセーブ", "しおり　１"] {
            XCTAssertEqual(codec.decode(codec.leaves(for: s)), s)
        }
    }
}
