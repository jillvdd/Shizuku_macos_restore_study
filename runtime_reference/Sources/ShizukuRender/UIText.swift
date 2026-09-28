//
//  UIText.swift
//  ShizukuRender
//
//  All non-script UI strings that must render in the original KNJ dot-matrix
//  font. Wording is constrained to the sizfont.tbl glyph set (no half-width
//  ASCII, no 【】★☆:／ — see HANDOVER §27); ASCII digits/letters fold to
//  full-width via LeafCodec. FontPipelineTests asserts every string here
//  encodes with zero uncovered characters.
//

import Foundation

public enum UIText {
    public static let endingsTitle = "エンディング達成状況　クリックで戻る"
    public static let endingsCleared = "○ ＣＬＥＡＲ"
    public static let endingsLocked = "− −−−−"
    public static let endingsLockedTitle = "？？？？？"

    public static let slotHint = "クリック決定　ＥＳＣで戻る"
    public static let slotEmpty = "（から）"

    public static let confirmOne = "（１）"
    public static let confirmTwo = "（２）"

    // 回想モード (title-menu CG gallery).
    public static let galleryHint = "クリックで拡大　矢印で移動"
    public static let galleryLockedMark = "？"
    public static func galleryPageLabel(_ n: Int, _ total: Int) -> String { "\(n)ページ目（全\(total)）" }

    /// All static strings the renderer draws through LeafCodec, for coverage tests.
    public static let allStaticStrings: [String] = [
        endingsTitle, endingsCleared, endingsLocked,
        endingsLockedTitle, slotHint, slotEmpty, confirmOne, confirmTwo,
        galleryHint, galleryLockedMark, galleryPageLabel(1, 8),
    ]
}
