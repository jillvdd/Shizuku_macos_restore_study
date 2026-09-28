//
//  LvnsEffect.swift
//  ShizukuCore
//
//  Port of the original `sizuku_effect[]` table and `text_effect()` mapper
//  (sizuku.c:92-126). Inline 'B'/'E'/'S'/'V'/'H' commands carry two 2-digit
//  *decimal* codes (out/in); "99" means NORMAL; event opcodes 0x14/0x38 carry
//  a raw binary index into the same table.
//

import Foundation

public enum LvnsEffect: Int, Codable, CaseIterable {
    case fadePalette = 0      // 00 — instant black-out, one-shot blit, ~600 ms palette fade-in ramp
    case guruguru             // 01 — 16px-block spiral, 8 tiles per present
    case slantTile            // 02 — random dissolve of 16px tiles (xorshift + probe dedup), 32/frame
    case fadeSquare           // 03 — 32px squares, corner-to-centre diamond rings, 33 states
    case wipeSquareLtoR       // 04 — 32px square-mask wave, one column lag per 32px, 52 states
    case fadeMask             // 05/0C — 4x4 ordered-dither develop, 16 phases
    case wipeTtoB             // 06 — full-row comb, baseline +16/frame, tooth spacing 17
    case wipeLtoR             // 07 — full-column comb, baseline +16/frame, tooth spacing 15
    case wipeMaskLtoR         // 08 — 16px dither-mask wave moving right
    case vertComposition      // 09 — whole new image compressed into growing centre band
    case slideLtoR            // 0A — columns x ≡ d (mod 16) revealed, one state per frame
    case normal               // 0B/99 — single full-frame flip
    case fadeMask2            // 0C — same as fadeMask (original table quirk)
}

public enum LvnsEffectMap {
    /// `text_effect(c1, c2)` + `sizuku_effect[no]`: script decimal code 00...12 or 99.
    /// Out-of-range values were an OOB read in the original; map them to `.normal`.
    public static func fromScriptCode(_ code: Int) -> LvnsEffect {
        if code == 99 { return .normal }
        return LvnsEffect(rawValue: code) ?? .normal
    }
    /// Event dispatch (`0x14`/`0x38`): raw byte index into the table.
    public static func fromEventArg(_ arg: Int) -> LvnsEffect {
        fromScriptCode(arg)
    }
}

public enum LvnsEffectTiming {
    /// Flips (1/60 s ticks) each effect needs, measured from the Sizuku.exe handlers
    /// (dispatcher @0x404740). The EXE paces itself with busy-waits of n×10 ms; at
    /// 60 Hz a ≥10/20 ms wait is ~1 flip per state and a ≥30 ms wait ~2 flips
    /// (same convention as the GURUGURU 125-flip closure).
    public static func frames(_ effect: LvnsEffect, width: Int, height: Int) -> Int {
        let cols16 = width / 16
        let rows16 = height / 16
        switch effect {
        case .fadePalette:      return 36            // @0x404810: 600 ms palette ramp
        case .guruguru:         return max(1, (cols16 * rows16 + 7) / 8)  // @0x404850: 8 tiles/present
        case .slantTile:        return 32            // @0x404c50: 1000 tiles / 32 per present
        case .fadeSquare:       return 66            // @0x404e40: 33 states x 2 flips
        case .wipeSquareLtoR:   return 104           // @0x405090: 52 states x 2 flips
        case .fadeMask, .fadeMask2: return 32        // @0x4040c0: 16 phases x 2 flips
        case .wipeTtoB:         return rows16 + 16   // @0x404370: `cmp si,0x290`
        case .wipeLtoR:         return cols16 + 16   // @0x4052e0: `cmp si,0x380`
        case .wipeMaskLtoR:     return cols16 + 16   // @0x405400: same 56-frame bound
        case .vertComposition:  return 32            // @0x405560: 16 states x 2 flips
        case .slideLtoR:        return 16            // @0x405680: 16 states x 1 flip
        case .normal:           return 1
        }
    }
}
