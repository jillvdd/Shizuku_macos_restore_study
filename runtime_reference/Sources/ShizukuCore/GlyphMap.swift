//
//  GlyphMap.swift
//  ShizukuCore
//
//  Maps a SCN leaf code to a KNJ font slot.
//
//  JP engine: slot = leaf (the JP font is indexed directly by the leaf code).
//  CN engine: slot = table[leaf] — the CN font is NOT in leaf order (verified
//  empirically: cn_font[leaf] and cn_font[firstUseRank(leaf)] both render garbage,
//  while the JP font renders coherent kana/kanji). A leaf→slot table is required;
//  it is loaded at runtime. Until a table is attached, this falls back to identity
//  (JP) so the pipeline stays runnable.
//

import Foundation

public struct GlyphMap: Sendable {
    /// Leaf→slot table as little-endian UInt16 entries, indexed by leaf code.
    /// `nil` means identity (slot = leaf), the JP behavior.
    private let table: [UInt8]?

    public init(table: [UInt8]? = nil) {
        self.table = table
    }

    public var isIdentity: Bool { table == nil }

    /// Slot for a leaf code. Out-of-range leaf/table indices fall back to 1-based identity (leaf - 1).
    /// Leaf code 0 = full-width space.
    /// Leaf code 1..1851 = slot 0..1850 (Akkera Ex.22 / KNJ_ALL.KNJ).
    public func slot(forLeaf leaf: Int) -> Int {
        if let t = table {
            let idx = leaf &* 2
            if idx >= 0, idx + 1 < t.count {
                return Int(t[idx]) | (Int(t[idx + 1]) << 8)
            }
        }
        // Native Japanese Leaf codes are 1-based:
        // leaf 0 -> space (advance only)
        // leaf 1 (■) -> slot 0
        // leaf 2 (あ) -> slot 1
        // leaf 3 (い) -> slot 2
        // leaf 565 (細) -> slot 564
        return leaf > 0 ? leaf - 1 : 0
    }

    /// Load a raw table blob of `0x8000` little-endian UInt16 slots.
    public static func from(raw: Data) -> GlyphMap {
        let bytes = [UInt8](raw.prefix(0x8000 * 2))
        return GlyphMap(table: bytes)
    }
}
