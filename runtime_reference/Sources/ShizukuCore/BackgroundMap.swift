//
//  BackgroundMap.swift
//  ShizukuCore
//
//  Port of the original's location-number → file / → palette tables, `bgmap()` and
//  `palmap()` (mglvns `sizuku_etc.c:206` and `:265`), plus the two hard-coded palette
//  substitution tables in that file.
//
//  Why this exists: the script's inline 'B'/'E'/'S' commands carry a *location* number,
//  not a file number. 23 of the location numbers the scripts actually use have no
//  `MAX_S##.LFG` on disk (`bgmap` folds them onto a shared plate: 廊下/図書室/保健室 etc.
//  day-dusk-night variants of one drawing), so asking for the raw number yields a missing
//  file — a black screen — or, when a file does exist under that number, the wrong room.
//
//  'B'0 is not a missing file: `SizukuLoadBG` special-cases `no == 0` into
//  `lvnsimage_clear` + `pal_default`, i.e. an intentional black plate.
//

import Foundation

/// A palette substitution: `count` colours replacing the plate's palette from `start` on.
/// `Hashable`/`Codable` so it can ride along in a save state's `Scene`.
public struct PaletteOverride: Hashable, Codable {
    public let start: Int
    public let rgb: [UInt8]          // 3 bytes per colour

    public init(start: Int, rgb: [UInt8]) {
        self.start = start
        self.rgb = rgb
    }

    public var colors: [(Int, Int, Int)] {
        // Round down to whole RGB triples — a hand-edited save can carry a ragged array.
        let full = rgb.count - rgb.count % 3
        return stride(from: 0, to: full, by: 3).map { (Int(rgb[$0]), Int(rgb[$0 + 1]), Int(rgb[$0 + 2])) }
    }

    init(start: Int, entries: [(Int, Int, Int)]) {
        self.start = start
        self.rgb = entries.flatMap { [UInt8($0.0), UInt8($0.1), UInt8($0.2)] }
    }
}

public enum BackgroundPalette: Int, CaseIterable {
    case day = 0          // 昼        01, 03, 13, 22, 24
    case yuugata = 1      // 夕方（外）
    case night = 2        // 夜        11, 14, 15, 18, 19
    case midnight2 = 3    // 深夜      39
    case midnight = 4     // 深夜の教室用
    case yuuyake = 5      // 赤い屋上
    case dark = 6         // まっくらな廊下
    case night2 = 7       // 夜の屋上
    case yuugata2 = 8     // 夕方の教室
}

public enum BackgroundMap {
    /// `bgmap(no)`: script location number → `MAX_S%02d` file number. The comments are the
    /// original's own labels for the *location*, i.e. the room and time of day the script
    /// meant; the file it lands on is that room's shared plate under its day variant.
    public static func fileNumber(forLocation no: Int) -> Int {
        switch no {
        case 4: return 2         // 教室(夕方)      → MAX_S02
        case 5: return 2         // 教室(深夜)      → MAX_S02
        case 6: return 3         // 休み時間(夕方)   → MAX_S03
        case 32: return 31       // 屋上(夕方)      → MAX_S31
        case 33: return 31       // 屋上(夜)        → MAX_S31
        case 35: return 34       // 屋上(網)夕方    → MAX_S34
        case 36: return 34       // 屋上(網)夜      → MAX_S34
        case 38: return 11       // 体育館(夕方)    → MAX_S11
        case 41: return 15       // 中庭(夕方)      → MAX_S15
        case 42: return 15       // 中庭(昼)        → MAX_S15
        case 43: return 10       // ろうか(夕方)    → MAX_S10
        case 44: return 10       // ろうか(深夜)    → MAX_S10
        case 45: return 30       // 職員室(夕方)    → MAX_S30
        case 46: return 30       // 職員室(深夜)    → MAX_S30
        case 47: return 22       // 階段(夕方)      → MAX_S22
        case 48: return 22       // 階段(深夜)      → MAX_S22
        case 49: return 12       // 生徒会廊下(夕方)→ MAX_S12
        case 50: return 12       // 生徒会廊下(深夜)→ MAX_S12
        case 51: return 24       // 体育館の中(夕方)→ MAX_S24
        case 52: return 24       // 体育館の中(夜)  → MAX_S24
        case 53: return 12       // 部活廊下(真っ暗)→ MAX_S12
        case 54: return 18       // 鉄のとびら閉(夕方)→ MAX_S18
        case 55: return 19       // 鉄のとびら開(夕方)→ MAX_S19
        default: return no
        }
    }

    /// `palmap(no)`: script location number → palette substitution id, or `nil` when the
    /// original leaves the plate's own palette alone (`return -1`). Note 42 (中庭昼) maps to
    /// palette 0 = 昼, which is *not* `nil` — it deliberately re-tints the shared plate.
    public static func palette(forLocation no: Int) -> BackgroundPalette? {
        switch no {
        case 4, 6: return .yuugata2
        case 5: return .midnight
        case 32: return .yuuyake
        case 33: return .night2
        case 35: return .yuuyake
        case 36: return .night2
        case 38: return .yuugata
        case 41: return .yuugata
        case 42: return .day
        case 43: return .yuugata
        case 44: return .midnight
        case 45: return .yuugata
        case 46: return .midnight2
        case 47: return .yuugata
        case 48: return .midnight
        case 49: return .yuugata
        case 50: return .midnight
        case 51: return .yuugata
        case 52: return .night
        case 53: return .dark
        case 54, 55: return .yuugata
        default: return nil
        }
    }

    /// `sizuku_haikei_palette[][4][3]` (`sizuku_etc.c:135`) — the atmosphere colours of a
    /// background plate. `SizukuLoadBG` calls `lvnsimage_set_palette2(image, pal, 4)`, and
    /// the four triples replace palette entries **0…3**: every `MAX_S` plate on disk carries
    /// the same constant block at 4…14 (`ff ff ff / 33 44 44 / 22 77 77 / aa bb ff / …`),
    /// while 0 is black and 1…3 are the room's light ramp — and `MAX_S15`'s live 1…3 are
    /// byte-identical to the 夜 row, `MAX_S12`'s to the 昼 row. (`lvnsimage_set_palette2` is
    /// only declared in the port, never defined, so this was confirmed from the asset data.)
    public static func paletteEntries(_ p: BackgroundPalette) -> [(Int, Int, Int)] {
        switch p {
        case .day:       return [(0x00,0x00,0x00), (0x66,0x55,0x22), (0x88,0x88,0x44), (0xbb,0xcc,0x88)]
        case .yuugata:   return [(0x00,0x00,0x00), (0x77,0x44,0x33), (0xcc,0x88,0x44), (0xee,0xcc,0x55)]
        case .night:     return [(0x00,0x00,0x00), (0x22,0x44,0x66), (0x55,0x88,0xbb), (0xbb,0xcc,0xff)]
        case .midnight2: return [(0x00,0x00,0x00), (0x00,0x22,0x33), (0x00,0x44,0x55), (0x00,0x88,0x99)]
        case .midnight:  return [(0x00,0x00,0x00), (0x33,0x33,0x55), (0x30,0x50,0x88), (0x77,0x88,0xbb)]
        case .yuuyake:   return [(0x00,0x00,0x00), (0xbb,0x00,0x00), (0xff,0x55,0x00), (0xff,0x77,0x00)]
        case .dark:      return [(0x00,0x00,0x00), (0x00,0x00,0x11), (0x00,0x00,0x44), (0x11,0x22,0x66)]
        case .night2:    return [(0x00,0x00,0x00), (0x22,0x22,0x77), (0x44,0x55,0xbb), (0x77,0x77,0xff)]
        case .yuugata2:  return [(0x00,0x00,0x00), (0x77,0x33,0x33), (0xaa,0x66,0x33), (0xff,0xbb,0x66)]
        }
    }

    /// Index of the first replaced palette entry — see `paletteEntries` for the evidence.
    public static let paletteEntryStart = 0

    /// The atmosphere substitution for a script location number: `bgmap` picks the plate,
    /// `palmap` picks the colours. `nil` means `palmap` returns -1, i.e. leave the plate's
    /// own palette alone.
    public static func paletteOverride(forLocation no: Int) -> PaletteOverride? {
        guard let p = palette(forLocation: no) else { return nil }
        return PaletteOverride(start: paletteEntryStart, entries: paletteEntries(p))
    }

    /// `SizukuLoadBG`'s `no == 0` branch: `lvnsimage_clear` — an intentional black plate.
    public static func isBlackLocation(_ no: Int) -> Bool { no == 0 }

    /// `MAX_S%02d` for a script location number, applying `bgmap()`. Location 0 is not a
    /// file: the original clears the background image instead, so this returns "" and the
    /// composer falls through to its black base.
    public static func bgFileName(forLocation no: Int) -> String {
        if no == 0 { return "" }
        return String(format: "MAX_S%02d", fileNumber(forLocation: no))
    }

    /// `SizukuLoadVisual`'s `no == 21` branch: `VIS21.LFG` was never shipped — the original
    /// loads VIS02 and repaints it with a purple palette of its own.
    public static let vis21FileNumber = 2
    public static let vis21Override = PaletteOverride(start: 0, entries: [
        (0x00,0x00,0x00), (0x66,0x44,0x99), (0xaa,0x66,0xaa), (0xcc,0xaa,0xee),
        (0xff,0xff,0xff), (0xff,0xdd,0xee), (0x11,0x00,0x11), (0xee,0xbb,0x88),
        (0x11,0x00,0x33), (0x66,0x88,0xbb), (0x77,0x66,0xcc), (0xaa,0x99,0xff),
        (0xdd,0xdd,0xff), (0x11,0x00,0x55), (0xff,0xcc,0xdd), (0xff,0x00,0x00),
    ])

    /// Resolved draw target for a 'V' visual-scene (illustration CG) number.
    public static func visual(number: Int) -> (fileName: String, override: PaletteOverride?) {
        if number == 21 { return (String(format: "VIS%02d", vis21FileNumber), vis21Override) }
        return (String(format: "VIS%02d", number), nil)
    }
}
