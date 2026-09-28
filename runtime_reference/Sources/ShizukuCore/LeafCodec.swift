//
//  LeafCodec.swift
//  ShizukuCore
//
//  Encodes Unicode strings into original-engine Leaf glyph codes (1-based,
//  slot = leaf - 1) by looking them up in sizfont.tbl — the same table the
//  original LVNS loads at startup to build `jis_to_leaf` (Lvns.c:144-183).
//  Entry index == leaf code; each entry is one EUC-JP pair (high bit may be
//  stored either way, so we OR 0x80 defensively).
//
//  The original KNJ font has no half-width ASCII cells, so `foldASCIIToLeaf`
//  maps ASCII digits/letters/punctuation onto their full-width counterparts
//  (e.g. "SCN001" -> ＳＣＮ００１) for UI strings that mirror the original's
//  own dot-matrix look.
//

import Foundation

public struct LeafCodec {
    /// Unicode character -> leaf code (1-based, as stored in sizfont.tbl).
    private let charToLeaf: [Character: Int]
    /// Reverse map for decoding original leaf streams back to text (previews).
    private let leafToChar: [Int: Character]

    /// Full-width fold for characters that have no direct sizfont entry.
    private static let fold: [Character: Character] = {
        var f: [Character: Character] = [:]
        for i in 0...9 {
            f[Character(String(i))] = Character(String(UnicodeScalar(0xFF10 + UInt32(i))!))
        }
        for i in 0..<26 {
            let up = Character(UnicodeScalar(UInt32(65 + i))!)          // A
            let low = Character(UnicodeScalar(UInt32(97 + i))!)          // a
            let fwUp = Character(UnicodeScalar(0xFF21 + UInt32(i))!)     // Ａ
            f[up] = fwUp
            f[low] = fwUp                                                // lowercase folds to uppercase
        }
        f[" "] = "\u{3000}"
        f["("] = "（"; f[")"] = "）"
        f["["] = "（"; f["]"] = "）"
        // No solidus cell exists in KNJ: entry 99 is the !? ligature.
        f["-"] = "−"
        f["."] = "．"
        f["!"] = "！"; f["?"] = "？"
        f[":"] = "・"
        return f
    }()

    public init(table data: Data) {
        var map: [Character: Int] = [:]
        var rev: [Int: Character] = [:]
        let bytes = [UInt8](data)
        let count = bytes.count / 2
        // `stride` (not `1..<count`) so an empty/truncated table decodes to an
        // identity-less codec instead of trapping on a reversed Range.
        for leaf in stride(from: 1, to: count, by: 1) {   // entry 0 is the U+3000 space (leaf code 0/skip)
            let b0 = bytes[leaf * 2] | 0x80
            let b1 = bytes[leaf * 2 + 1] | 0x80
            guard let ch = String(data: Data([b0, b1]), encoding: .japaneseEUC)?.first else { continue }
            if map[ch] == nil { map[ch] = leaf }
            if rev[leaf] == nil { rev[leaf] = ch }
        }
        map["\u{3000}"] = 0
        self.charToLeaf = map
        self.leafToChar = rev
    }

    public static let empty = LeafCodec(table: Data())

    /// Leaf code for one character after ASCII fold; nil if the font lacks it.
    public func leaf(for ch: Character) -> Int? {
        if let l = charToLeaf[ch] { return l }
        if let alt = LeafCodec.fold[ch], let l = charToLeaf[alt] { return l }
        return nil
    }

    /// Encode a string; characters absent from the font are dropped.
    public func leaves(for text: String) -> [Int] {
        text.compactMap { leaf(for: $0) }
    }

    /// Characters that could not be encoded (for regression tests).
    public func uncovered(in text: String) -> [Character] {
        var seen = Set<Character>()
        return text.filter { leaf(for: $0) == nil && seen.insert($0).inserted }
    }

    /// Decode original-engine leaf codes back to Unicode (leaf 0 -> fullwidth
    /// space; unknown leaves are dropped). Used for save-slot previews.
    public func decode(_ leaves: [Int]) -> String {
        String(leaves.map { leaf -> Character? in
            if leaf == 0 { return "\u{3000}" }
            return leafToChar[leaf]
        }.compactMap { $0 })
    }
}
