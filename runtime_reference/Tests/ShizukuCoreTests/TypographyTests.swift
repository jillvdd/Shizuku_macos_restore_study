//
//  TypographyTests.swift
//  ShizukuCoreTests
//
//  Verification of Message leaf code parsing, control characters ('r', 'p', 'k'/'K'),
//  and pagination layout matching Akkera102 & Leaf script semantics.
//

import XCTest
@testable import ShizukuCore

final class TypographyTests: XCTestCase {

    func testControlByteTokens() {
        // Construct raw bytes with Leaf codes and controls:
        // Leaf(1), Leaf(2), 'r' (CR), Leaf(3), 'k' (WAIT), 'p' (PAGE), '$' (END)
        let bytes: [UInt8] = [
            0x80, 0x01,       // Leaf 1
            0x80, 0x02,       // Leaf 2
            0x72,             // 'r' (tokNewline)
            0x80, 0x03,       // Leaf 3
            0x6b,             // 'k' (tokWaitKey)
            0x70,             // 'p' (tokPageBreak)
            0x24              // '$' (MSG_END)
        ]
        let msg = Message(index: 0, offset: 0, leafStream: Scn.leafStream(bytes[...]))
        XCTAssertEqual(msg.leafStream, [
            1,
            2,
            Message.tokNewline,
            3,
            Message.tokWaitKey,
            Message.tokPageBreak
        ])
    }

    func testPaginationWithPageBreak() {
        // 2 lines on page 1, followed by 'p', then 1 line on page 2
        let stream: [Int] = [
            10, 11, Message.tokNewline,
            12, 13, Message.tokPageBreak,
            14, 15, Message.tokNewline
        ]
        let msg = Message(index: 0, offset: 0, leafStream: stream)
        let pages = msg.paginated(charsPerLine: 25, maxLines: 4)

        XCTAssertEqual(pages.count, 2, "Explicit 'p' must break into 2 pages")
        XCTAssertEqual(pages[0], [[10, 11], [12, 13]])
        XCTAssertEqual(pages[1], [[14, 15]])
    }

    func testLineWrappingAtCharsPerLine() {
        // Line with 6 characters wrapping at charsPerLine=4
        let stream: [Int] = [1, 2, 3, 4, 5, 6, Message.tokNewline]
        let msg = Message(index: 0, offset: 0, leafStream: stream)
        let pages = msg.paginated(charsPerLine: 4, maxLines: 4)

        XCTAssertEqual(pages.count, 1)
        XCTAssertEqual(pages[0].count, 2)
        XCTAssertEqual(pages[0][0], [1, 2, 3, 4])
        XCTAssertEqual(pages[0][1], [5, 6])
    }

    func testMultiPageOverflow() {
        // 5 lines with maxLines=4 should wrap to second page
        let stream: [Int] = [
            1, Message.tokNewline,
            2, Message.tokNewline,
            3, Message.tokNewline,
            4, Message.tokNewline,
            5, Message.tokNewline
        ]
        let msg = Message(index: 0, offset: 0, leafStream: stream)
        let pages = msg.paginated(charsPerLine: 25, maxLines: 4)

        XCTAssertEqual(pages.count, 2)
        XCTAssertEqual(pages[0].count, 4)
        XCTAssertEqual(pages[1].count, 1)
    }
}
