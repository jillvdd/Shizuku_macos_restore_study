//
//  CnDotFont.swift
//  ShizukuCore
//
//  The original CN fan-patch dot-matrix font (HANDOVER §40 WP-4/5, M5.3/WP-11):
//  a 4726-slot KNJ container whose first 1852 slots are byte-identical to the
//  JP `KNJ_ALL.KNJ` (verified) and whose CN zone (codes 1853..4726) holds the
//  simplified glyphs, in strict Unicode codepoint order. `cn_code2char.json` is
//  the recovered code→char table (2868 entries, 34-anchor monotone DP).
//
//  This is a drop-in superset: CN chars resolve through charToCode to a CN-zone
//  slot; anything outside (ASCII/digits) falls back to the JP leaf zone — the
//  same composition the original patch used.
//

import Foundation

public struct CnDotFont: Sendable {
    /// code (1-based slot) -> glyph, via the shared KNJ 72B col-major container.
    public let font: KnjFont
    /// Unicode char -> CN font code (1-based slot index).
    public let charToCode: [Character: Int]

    public init(font: KnjFont, charToCode: [Character: Int]) {
        self.font = font
        self.charToCode = charToCode
    }

    public var isEmpty: Bool { charToCode.isEmpty }

    /// Chars the CN patch spelled with a different codepoint than modern text uses.
    public static let aliases: [Character: Character] = ["…": "┅"]

    /// 24x24 pixel matrix for a CN char, nil when the char is not in the CN zone.
    public func pixels(for char: Character) -> [[Int]]? {
        let ch = Self.aliases[char] ?? char
        guard let code = charToCode[ch], code >= 1 else { return nil }
        return font.pixels(code - 1)
    }

    /// Cell count a string occupies in this font (each CN char = one 24px cell).
    public func cellCount(of text: String) -> Int {
        text.filter { pixels(for: $0) != nil }.count
    }

    /// Hot-mount search, mirroring `TranslationStore.candidatePaths`: the ZH bundle
    /// ships both files next to the game data; dev keeps them under
    /// `research/recovery/text/`. Both files must exist in the same directory.
    public static func candidateDirs(extractedDir: String) -> [String] {
        let dir = (extractedDir as NSString).standardizingPath
        var dirs = [dir]
        let research = (dir as NSString).deletingLastPathComponent
        dirs.append((research as NSString).appendingPathComponent("recovery/text"))
        if let res = Bundle.main.resourcePath {
            dirs.append(res + "/gamedata")
            dirs.append(res)
        }
        return dirs
    }

    /// Load `cnfont_4726.bin` + `cn_code2char.json` from the first directory that
    /// has both. nil when absent (JP builds never call this path).
    public static func loadDefault(extractedDir: String) -> CnDotFont? {
        let fm = FileManager.default
        for d in candidateDirs(extractedDir: extractedDir) {
            let bin = d + "/cnfont_4726.bin"
            let map = d + "/cn_code2char.json"
            guard fm.fileExists(atPath: bin), fm.fileExists(atPath: map),
                  let data = try? Data(contentsOf: URL(fileURLWithPath: bin)),
                  let jsonData = try? Data(contentsOf: URL(fileURLWithPath: map)),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: String]
            else { continue }
            var charToCode: [Character: Int] = [:]
            charToCode.reserveCapacity(json.count)
            for (code, str) in json {
                guard let code = Int(code), str.count == 1, let ch = str.first else { continue }
                charToCode[ch] = code
            }
            guard !charToCode.isEmpty else { continue }
            return CnDotFont(font: KnjFont(data: [UInt8](data)), charToCode: charToCode)
        }
        return nil
    }
}
