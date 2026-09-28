//
//  Scn.swift
//  ShizukuCore
//
//  SCN script parser. Event/message data decoded with LZS.decodeInv (the
//  cmd_disasm variant — this is what cmd_text/cmd_cntext import).
//
//  Headers: u16 ev_off_raw*0x10 @0, u16 msg_off_raw*0x10 @2,
//           u32 ev_size @ev_off, u32 msg_size @msg_off.
//

import Foundation

public struct ScnCommand {
    public let opcode: UInt8
    public let name: String
    public let args: [UInt8]
    public let offset: Int
    public init(opcode: UInt8, name: String, args: [UInt8], offset: Int) {
        self.opcode = opcode; self.name = name; self.args = args; self.offset = offset
    }
}

public struct ScnBlock {
    public let index: Int
    public let offset: Int
    public let events: [ScnCommand]
    public init(index: Int, offset: Int, events: [ScnCommand]) {
        self.index = index; self.offset = offset; self.events = events
    }
}

public enum InlineAction: Codable, Equatable {
    /// `location` is the *script* number the command carried (before `bgmap()` folded it
    /// onto a shared plate), which is what selects the atmosphere palette — two locations can
    /// share one drawing with different palettes, so the file name alone is not enough.
    case bg(name: String, effectOut: Int = 99, effectIn: Int = 99, location: Int = 0)
    case visual(name: String, effectOut: Int = 99, effectIn: Int = 99, location: Int = 0)
    /// `'H'` has no `bgmap`/`palmap` stage (`SizukuLoadHVisual` loads `HVS%02d` directly),
    /// so it carries no location.
    case hVisual(name: String, effectOut: Int = 99, effectIn: Int = 99)
    case portrait(pos: String, name: String)
    case clearPortrait(pos: String)
    case bgAndPortrait(pos: String, chrName: String, bgName: String, effectOut: Int = 99, effectIn: Int = 99, location: Int = 0)
    case multiPortrait(portraits: [PortraitEntry])
    case bgm(action: String, track: Int)
    case sfx(name: String)
    /// PCM transport control: `"fade"` (`Pf`), `"stop"` (`Ps`), `"wait"` (`Pw`).
    case pcm(action: String)
    case flash
    case shake
    /// `X` — horizontal display offset for the text that follows (used to position choice
    /// option strings, which are ordinary messages carrying a leading `<X..>`).
    case offset(x: Int)
    /// `s` — per-character text display speed hint.
    case speed(v: Int)

    public struct PortraitEntry: Codable, Equatable {
        public let pos: String
        public let name: String
        public init(pos: String, name: String) { self.pos = pos; self.name = name }
    }
}

public enum MessagePauseType: Codable, Equatable {
    case waitKey
    case pageBreak
    case messageEnd
}

public struct MessageSegment: Codable, Equatable {
    public let actions: [InlineAction]
    public let lines: [[Int]]
    public let pause: MessagePauseType
    public init(actions: [InlineAction], lines: [[Int]], pause: MessagePauseType) {
        self.actions = actions
        self.lines = lines
        self.pause = pause
    }
}

public struct Message: Codable, Equatable {
    public let index: Int
    public let offset: Int
    /// Raw leaf stream (naive extraction: any high-bit lead byte -> 2-byte code).
    public let leafStream: [Int]
    /// Segmented stream with inline visual/audio actions and text lines.
    public let segments: [MessageSegment]

    /// Text glyph leaf codes that index the 1852-glyph font (valid slots 0..1851).
    /// Codes >1851 are opcode/parameter strays (lead byte 0x88-0xFF) and can't render.
    public var glyphLeafCodes: [Int] {
        leafStream.filter { $0 >= 0 && $0 <= 1851 }
    }

    public init(index: Int, offset: Int, leafStream: [Int], segments: [MessageSegment] = []) {
        self.index = index; self.offset = offset; self.leafStream = leafStream
        if segments.isEmpty {
            var segLines: [[Int]] = []
            var curLine: [Int] = []
            for t in leafStream {
                if t == Message.tokNewline {
                    segLines.append(curLine)
                    curLine = []
                } else if t == Message.tokPageBreak || t == Message.tokWaitKey {
                    // skip sentinel
                } else {
                    curLine.append(t)
                }
            }
            if !curLine.isEmpty { segLines.append(curLine) }
            self.segments = [MessageSegment(actions: [], lines: segLines, pause: .messageEnd)]
        } else {
            self.segments = segments
        }
    }

    /// Sentinel token values in the leaf stream.
    public static let tokPageBreak = -3 // 'p' (PAGE): explicit page break
    public static let tokWaitKey   = -2 // 'k'/'K' (WAIT_KEY): pause / wait for key press
    public static let tokNewline   = -1 // 'r' (CR): carriage return / line break
    public static let tokSpace     = 0  // full-width space

    /// Split the message into pages of visual lines for the on-screen text box.
    /// Control markers (CR 'r', PAGE 'p', WAIT_KEY 'k'/'K') are handled according to
    /// Leaf script semantics: 'p' forces a page break; 'r' starts a new line; 'k' pauses.
    /// Lines auto-wrap at `charsPerLine` and pages hold at most `maxLines` lines.
    public func paginated(charsPerLine: Int, maxLines: Int) -> [[[Int]]] {
        var pages: [[[Int]]] = []
        var curPage: [[Int]] = []
        var curLine: [Int] = []
        var n = 0

        func flushLine() {
            curPage.append(curLine)
            curLine = []
            n = 0
            if curPage.count >= maxLines {
                pages.append(curPage)
                curPage = []
            }
        }

        func flushPage() {
            if !curLine.isEmpty {
                curPage.append(curLine)
                curLine = []
                n = 0
            }
            if !curPage.isEmpty {
                pages.append(curPage)
                curPage = []
            }
        }

        for t in leafStream {
            if t == Message.tokPageBreak {
                flushPage()
            } else if t == Message.tokNewline {
                flushLine()
            } else if t == Message.tokWaitKey {
                // Wait-key sentinel: preserves dialogue flow (usually preceding 'r')
            } else if t == Message.tokSpace {
                curLine.append(0)
                n += 1
                if n >= charsPerLine { flushLine() }
            } else if t > 0 && t <= 1851 {
                curLine.append(t)
                n += 1
                if n >= charsPerLine { flushLine() }
            }
        }
        if !curLine.isEmpty { curPage.append(curLine) }
        if !curPage.isEmpty { pages.append(curPage) }
        if pages.isEmpty { pages = [[[]]] }
        return pages
    }
}

public struct ScnScript {
    public let fileIndex: Int
    public let blocks: [ScnBlock]
    public let messages: [Message]
    public let rawEvents: [UInt8]
    public let rawMessages: [UInt8]

    public func block(_ i: Int) -> ScnBlock? {
        return i >= 0 && i < blocks.count ? blocks[i] : nil
    }
    public func message(_ i: Int) -> Message? {
        return i >= 0 && i < messages.count ? messages[i] : nil
    }
    public init(fileIndex: Int, blocks: [ScnBlock], messages: [Message],
                rawEvents: [UInt8], rawMessages: [UInt8]) {
        self.fileIndex = fileIndex; self.blocks = blocks; self.messages = messages
        self.rawEvents = rawEvents; self.rawMessages = rawMessages
    }
}

public enum Scn {

    /// Event opcodes -> (name, argument byte count).
    ///
    /// The set and the argument counts come from `ScriptEventTable` in
    /// `research/gbalvns/core/script2.c`, whose handlers each show exactly how many bytes
    /// they consume. A missing entry is not harmless: `parseBlock` treats an unknown opcode
    /// as a zero-argument instruction and advances one byte, so it then reads the operand as
    /// a fresh opcode and the whole block decodes misaligned. `0x03`/`0x06`/`0x5a`/`0x5c`/
    /// `0x60`-`0x66`/`0x6f`/`0x73` are "skip N" placeholders in the original (their handlers
    /// are named `ScriptExecEventSkip1/2/3` and only advance the cursor) but they still have
    /// real widths, so they must be listed.
    public static let eventOps: [UInt8: (String, Int)] = [
        0x00: ("END", 0), 0x01: ("EFFECT", 2), 0x03: ("SKIP2", 1), 0x04: ("JUMP", 2),
        0x05: ("SELECT", 0), 0x06: ("SKIP1", 0), 0x07: ("SEL_BACK", 0),
        0x0a: ("BG", 1), 0x14: ("CLEAR", 1), 0x16: ("HBG", 1),
        0x22: ("CHR", 2), 0x24: ("CHR2", 2), 0x28: ("MARK2", 0), 0x38: ("EFFECT2", 1),
        0x3d: ("IF_EQ", 3), 0x3e: ("IF_NE", 3), 0x47: ("FLAG_SET", 2), 0x48: ("FLAG_ADD", 2),
        0x54: ("MSG", 1),
        0x5a: ("SKIP1", 0), 0x5c: ("SKIP2", 1), 0x60: ("SKIP1", 0), 0x61: ("SKIP3", 2),
        0x62: ("SKIP2", 1), 0x63: ("SKIP1", 0), 0x64: ("SKIP1", 0), 0x65: ("SKIP1", 0),
        0x66: ("SKIP1", 0), 0x6e: ("BGM", 1), 0x6f: ("SKIP1", 0), 0x73: ("SKIP1", 0),
        0x7c: ("ENDING", 0), 0x7d: ("END_BGM", 1), 0x7e: ("END_CHK", 1),
        0xff: ("UNREACHABLE", 0),
    ]

    static func u16(_ d: [UInt8], _ off: Int) -> Int {
        return Int(d[off]) | (Int(d[off + 1]) << 8)
    }
    static func u32(_ d: [UInt8], _ off: Int) -> Int {
        return Int(d[off]) | (Int(d[off + 1]) << 8) | (Int(d[off + 2]) << 16) | (Int(d[off + 3]) << 24)
    }

    /// Two ASCII digits -> value, tolerant of out-of-range bytes (`ScriptGetMapDig` in
    /// gbalvns `script.c` performs the same unchecked `(c1-'0')*10 + (c2-'0')`).
    private static func digits(_ c1: UInt8, _ c2: UInt8) -> Int {
        let a = Int(c1) - 48
        let b = Int(c2) - 48
        return (a >= 0 && a <= 9 ? a : 0) * 10 + (b >= 0 && b <= 9 ? b : 0)
    }

    private static func parseDig2(_ d: [UInt8], _ off: Int) -> Int {
        guard off + 1 < d.count else { return 0 }
        return digits(d[off], d[off + 1])
    }

    /// Explicit-range variant: `parseDig2(d, i + 1, i + 2)` reads exactly the two requested
    /// bytes. Callers that already know the field layout should use this rather than relying
    /// on `off + 1` falling inside the buffer.
    private static func parseDig2(_ d: [UInt8], _ a: Int, _ b: Int) -> Int {
        guard b < d.count else { return 0 }
        return digits(d[a], d[b])
    }

    private static func hexVal(_ c: UInt8) -> Int {
        if c >= 48 && c <= 57 { return Int(c - 48) }
        if c >= 65 && c <= 70 { return Int(c - 55) }
        if c >= 97 && c <= 102 { return Int(c - 87) }
        return 0
    }

    private static func parseHex2(_ d: [UInt8], _ off: Int) -> Int {
        guard off + 1 < d.count else { return 0 }
        return (hexVal(d[off]) << 4) | hexVal(d[off + 1])
    }

    private static func isHex(_ c: UInt8) -> Bool {
        return (c >= 48 && c <= 57) || (c >= 65 && c <= 70) || (c >= 97 && c <= 102)
    }

    /// Full parser converting raw message bytes into ordered segments with inline actions.
    ///
    /// Byte lengths are taken verbatim from `ScriptMsgTable` / the `ScriptExecMsg*` handlers in
    /// `research/gbalvns/core/script3.c`, which is the authoritative port of the original
    /// `LvnsText.c` message decoder. Two things are easy to get wrong here and both were:
    ///
    ///  * **The argument bytes count toward the instruction.** `'C'` consumes `pos` + two hex
    ///    digits and then advances a further 3 bytes (4 total), not 4 including them. Every
    ///    off-by-one shifts the cursor into the glyph stream, where a low byte is then
    ///    misread as another command and a glyph lead byte is consumed as its argument —
    ///    producing both phantom actions and dropped text.
    ///  * **The hex payload is two ASCII *bytes*, not one.** `Cr51` is `C`+`r`+`'5'`+`'1'`,
    ///    so a `UInt8` value of 0x51 never appears in the stream.
    ///
    /// `'O'` (skip), `'X'` (offset) and `'s'` (speed) take a byte-argument each; `'Q'`/`'F'`
    /// are bare. `'M'`/`'P'` are variable-length and their sub-command byte decides the width.
    public static func parseMessageSegments(_ data: ArraySlice<UInt8>) -> ([MessageSegment], [Int]) {
        var segments: [MessageSegment] = []
        var allLeafStream: [Int] = []
        var curActions: [InlineAction] = []
        var curLines: [[Int]] = []
        var curLine: [Int] = []
        let d = Array(data)
        var i = 0

        func flushLine() {
            curLines.append(curLine)
            curLine = []
        }

        func flushSegment(pause: MessagePauseType) {
            if !curLine.isEmpty {
                curLines.append(curLine)
                curLine = []
            }
            segments.append(MessageSegment(actions: curActions, lines: curLines, pause: pause))
            curActions = []
            curLines = []
        }

        while i < d.count {
            let c = d[i]
            if (c & 0x80) != 0 {
                if i + 1 >= d.count { break }
                let code = ((Int(c) & 0x7f) << 8) | Int(d[i + 1])
                curLine.append(code)
                allLeafStream.append(code)
                i += 2
                continue
            }
            switch c {
            case 0x00:
                curLine.append(Message.tokSpace)
                allLeafStream.append(Message.tokSpace)
                i += 1
            case 0x24: // '$' MSG_END
                flushSegment(pause: .messageEnd)
                i = d.count
            case 0x72: // 'r' newline
                allLeafStream.append(Message.tokNewline)
                flushLine()
                i += 1
            case 0x70: // 'p' page break
                allLeafStream.append(Message.tokPageBreak)
                flushSegment(pause: .pageBreak)
                i += 1
            case 0x6b, 0x4b: // 'k'/'K' wait key
                allLeafStream.append(Message.tokWaitKey)
                flushSegment(pause: .waitKey)
                i += 1
            case 0x4f: // 'O' skip
                i += 2
            case 0x51: // 'Q' shake
                curActions.append(.shake)
                i += 1
            case 0x46: // 'F' flash white
                curActions.append(.flash)
                i += 1
            case 0x58: // 'X' text display offset
                if i + 1 < d.count { curActions.append(.offset(x: Int(d[i + 1]))) }
                i += 2
            case 0x73: // 's' text speed
                if i + 1 < d.count { curActions.append(.speed(v: Int(d[i + 1]))) }
                i += 2
            case 0x43: // 'C' pos, hex2 — load one character
                if i + 3 < d.count {
                    let pos = String(UnicodeScalar(d[i + 1]))
                    let hex = parseHex2(d, i + 2)
                    curActions.append(.portrait(pos: normalizedPos(pos), name: String(format: "MAX_C%02X", hex)))
                }
                i += 4
            case 0x44: // 'D' pos, hex2 — original clears *all* character slots, then loads one
                if i + 3 < d.count {
                    let pos = normalizedPos(String(UnicodeScalar(d[i + 1])))
                    let hex = parseHex2(d, i + 2)
                    curActions.append(.clearPortrait(pos: "a"))
                    curActions.append(.portrait(pos: pos, name: String(format: "MAX_C%02X", hex)))
                }
                i += 4
            case 0x42, 0x45: // 'B' / 'E' bg, eff-out, eff-in (2 decimal digits each)
                if i + 6 < d.count {
                    let bgNo = parseDig2(d, i + 1)
                    let eOut = parseDig2(d, i + 3, i + 4)
                    let eIn = parseDig2(d, i + 5, i + 6)
                    curActions.append(.bg(name: BackgroundMap.bgFileName(forLocation: bgNo),
                                          effectOut: eOut, effectIn: eIn, location: bgNo))
                    curActions.append(.clearPortrait(pos: "a"))
                }
                i += 7
            case 0x56: // 'V' visual, eff, eff
                if i + 6 < d.count {
                    let visNo = parseDig2(d, i + 1)
                    let eOut = parseDig2(d, i + 3, i + 4)
                    let eIn = parseDig2(d, i + 5, i + 6)
                    curActions.append(.visual(name: BackgroundMap.visual(number: visNo).fileName,
                                              effectOut: eOut, effectIn: eIn, location: visNo))
                    curActions.append(.clearPortrait(pos: "a"))
                }
                i += 7
            case 0x48: // 'H' h-scene CG, eff, eff
                if i + 6 < d.count {
                    let hNo = parseDig2(d, i + 1)
                    let eOut = parseDig2(d, i + 3, i + 4)
                    let eIn = parseDig2(d, i + 5, i + 6)
                    curActions.append(.hVisual(name: String(format: "HVS%02d", hNo), effectOut: eOut, effectIn: eIn))
                    curActions.append(.clearPortrait(pos: "a"))
                }
                i += 7
            case 0x53: // 'S' pos, chr-hex2, bg-no2, eff, eff
                if i + 9 < d.count {
                    let pos = normalizedPos(String(UnicodeScalar(d[i + 1])))
                    let chrHex = parseHex2(d, i + 2)
                    let bgNo = parseDig2(d, i + 4)
                    let eOut = parseDig2(d, i + 6, i + 7)
                    let eIn = parseDig2(d, i + 8, i + 9)
                    curActions.append(.bgAndPortrait(pos: pos,
                                                     chrName: String(format: "MAX_C%02X", chrHex),
                                                     bgName: BackgroundMap.bgFileName(forLocation: bgNo),
                                                     effectOut: eOut, effectIn: eIn, location: bgNo))
                }
                i += 10
            case 0x41, 0x61: // 'A' / 'a' three characters
                if i + 9 < d.count {
                    let p1 = normalizedPos(String(UnicodeScalar(d[i + 1])))
                    let c1 = parseHex2(d, i + 2)
                    let p2 = normalizedPos(String(UnicodeScalar(d[i + 4])))
                    let c2 = parseHex2(d, i + 5)
                    let p3 = normalizedPos(String(UnicodeScalar(d[i + 7])))
                    let c3 = parseHex2(d, i + 8)
                    let list = [
                        InlineAction.PortraitEntry(pos: p1, name: String(format: "MAX_C%02X", c1)),
                        InlineAction.PortraitEntry(pos: p2, name: String(format: "MAX_C%02X", c2)),
                        InlineAction.PortraitEntry(pos: p3, name: String(format: "MAX_C%02X", c3))
                    ]
                    curActions.append(.multiPortrait(portraits: list))
                }
                i += 10
            case 0x4d: // 'M' BGM control
                guard i + 1 < d.count else { i += 1; break }
                let c1 = d[i + 1]
                if c1 == 0x66 { // 'f' fade out
                    curActions.append(.bgm(action: "fade", track: 0))
                    i += 2
                } else if c1 == 0x73 { // 's' stop
                    curActions.append(.bgm(action: "stop", track: 0))
                    i += 2
                } else if c1 == 0x77 { // 'w' wait for fade/next
                    curActions.append(.bgm(action: "wait", track: 0))
                    i += 2
                } else if c1 == 0x6e { // 'n' queue track (plays at the next image change)
                    let tr = parseDig2(d, i + 2, i + 3)
                    curActions.append(.bgm(action: "next", track: tr))
                    i += 4
                } else if c1 >= 0x30 && c1 <= 0x32 { // 'M03' play immediately
                    let tr = parseDig2(d, i + 1, i + 2)
                    curActions.append(.bgm(action: "play", track: tr))
                    i += 3
                } else {
                    i += 2
                }
            case 0x50: // 'P' PCM
                guard i + 1 < d.count else { i += 1; break }
                let c1 = d[i + 1]
                if c1 == 0x6c { // 'l' load/prepare sample
                    curActions.append(.sfx(name: String(format: "P%03d", parseDig2(d, i + 2, i + 3))))
                    i += 4
                } else if c1 >= 0x30 && c1 <= 0x39 { // 'P0100' = sample 01, params 00
                    curActions.append(.sfx(name: String(format: "P%03d", parseDig2(d, i + 1, i + 2))))
                    i += 5
                } else if c1 == 0x66 {
                    curActions.append(.pcm(action: "fade"))
                    i += 2
                } else if c1 == 0x73 {
                    curActions.append(.pcm(action: "stop"))
                    i += 2
                } else if c1 == 0x77 {
                    curActions.append(.pcm(action: "wait"))
                    i += 2
                } else {
                    i += 2
                }
            default:
                i += 1
            }
        }

        if !curActions.isEmpty || !curLines.isEmpty || !curLine.isEmpty {
            flushSegment(pause: .messageEnd)
        }
        return (segments, allLeafStream)
    }

    /// Character slot letters are uppercased; `'0'` is an alias for the centre slot
    /// (`ScriptGetMapChrPos` in gbalvns `script.c`).
    private static func normalizedPos(_ raw: String) -> String {
        guard let ch = raw.first else { return raw }
        if ch == "0" { return "c" }
        if ch.isLetter { return ch.lowercased() }
        return raw
    }

    /// Extract leaf codes and text controls for backward compatibility.
    public static func leafStream(_ data: ArraySlice<UInt8>) -> [Int] {
        return parseMessageSegments(data).1
    }

    public static func parse(_ data: [UInt8], fileIndex: Int = 0) -> ScnScript {
        guard data.count >= 4 else { return ScnScript(fileIndex: fileIndex, blocks: [], messages: [], rawEvents: [], rawMessages: []) }
        let evOff = u16(data, 0) * 0x10
        let msgOff = u16(data, 2) * 0x10
        guard evOff + 4 <= msgOff, msgOff + 4 <= data.count else {
            return ScnScript(fileIndex: fileIndex, blocks: [], messages: [], rawEvents: [], rawMessages: [])
        }

        // Each segment carries its decompressed size in the u32 that follows the offset field.
        // Feeding the decoder the rest of the file instead yields the declared region plus
        // whatever trailing junk the compressed stream happens to produce, which the message
        // offset table does not cover — see `LZS.decodeInv`.
        let evLo = evOff + 4
        let evLzLen = msgOff - evLo
        let evSize = u32(data, evOff)
        let evRaw = LZS.decodeInv(Array(data[evLo..<evLo + evLzLen]), outSize: evSize)

        let msgLo = msgOff + 4
        let msgLzLen = data.count - msgLo
        let msgSize = u32(data, msgOff)
        let msgRaw = LZS.decodeInv(Array(data[msgLo..<msgLo + msgLzLen]), outSize: msgSize)

        var blocks: [ScnBlock] = []
        if evRaw.count >= 4 {
            let lastBlk = u16(evRaw, 0)
            // A corrupt lastBlk must not walk the u16 reader past the segment end.
            let blkEntries = min(Int(lastBlk) + 1, (evRaw.count - 2) / 2)
            var blkTbl: [Int] = []
            for k in 0..<blkEntries { blkTbl.append(u16(evRaw, 2 + k * 2)) }
            for (i, off) in blkTbl.enumerated() where off < evRaw.count {
                let end = (i + 1 < blkTbl.count) ? blkTbl[i + 1] : evRaw.count
                blocks.append(parseBlock(evRaw, offset: off, end: end, index: i))
            }
        }

        var messages: [Message] = []
        if msgRaw.count >= 4 {
            let lastMsg = u16(msgRaw, 0)
            let msgEntries = min(Int(lastMsg) + 1, (msgRaw.count - 2) / 2)
            for i in 0..<msgEntries {
                let off = u16(msgRaw, 2 + i * 2)
                if off < msgRaw.count {
                    let (segs, stream) = parseMessageSegments(msgRaw[off...])
                    messages.append(Message(index: i, offset: off, leafStream: stream, segments: segs))
                }
            }
        }

        return ScnScript(fileIndex: fileIndex, blocks: blocks, messages: messages,
                         rawEvents: evRaw, rawMessages: msgRaw)
    }

    /// Decode one event block, bounded by `end` — the next block's offset, or the end of the
    /// event stream.
    ///
    /// The bound matters: 434 of the 790 blocks in the retail scripts never reach an `END`
    /// inside their own span (many end by jumping elsewhere), so an unbounded reader walks
    /// straight into the following block and reports its events as part of this one.
    static func parseBlock(_ data: [UInt8], offset: Int, end: Int, index: Int) -> ScnBlock {
        let limit = min(max(end, offset), data.count)
        var events: [ScnCommand] = []
        var i = offset
        while i < limit {
            let cmdOffset = i
            let op = data[i]
            i += 1
            if op == 0x00 {
                events.append(ScnCommand(opcode: 0x00, name: "END", args: [], offset: cmdOffset))
                break
            }
            if op == 0x05 {
                // SELECT prompt_msg, count, (msg, offset)*
                if i + 2 <= limit {
                    let prompt = data[i]; i += 1
                    let count = data[i]; i += 1
                    var args = [prompt, count]
                    for _ in 0..<Int(count) {
                        if i + 2 <= limit {
                            args.append(data[i]); i += 1
                            args.append(data[i]); i += 1
                        }
                    }
                    events.append(ScnCommand(opcode: 0x05, name: "SELECT", args: args, offset: cmdOffset))
                }
                continue
            }
            if let (name, argc) = eventOps[op] {
                var args: [UInt8] = []
                for _ in 0..<argc {
                    if i < limit { args.append(data[i]); i += 1 }
                }
                events.append(ScnCommand(opcode: op, name: name, args: args, offset: cmdOffset))
            } else {
                events.append(ScnCommand(opcode: op, name: String(format: "UNK_%02X", op), args: [], offset: cmdOffset))
            }
        }
        return ScnBlock(index: index, offset: offset, events: events)
    }
}
