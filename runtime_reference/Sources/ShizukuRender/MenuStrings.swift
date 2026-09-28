//
//  MenuStrings.swift
//
//  Leaf 24x24 dot-matrix leaf codes for every hardcoded UI string, resolved offline
//  against `sizfont.tbl` (EUC-JP, leaf-indexed). Kept as leaf codes — not Unicode —
//  so the menus render with the same KNJ glyphs as the scenario text.
//  A `0` is the full-width space (sizfont index 0 = U+3000).
//

import Foundation

public enum MenuStrings {
    // Title menu
    public static let gameStart: [Int]   = [158, 101, 137, 46, 590, 35, 42]   // ゲームを始める
    public static let newGame: [Int]     = [27, 58, 35, 7, 40]                // はじめから
    public static let continueGame: [Int] = [19, 64, 8, 7, 40]                // つづきから
    public static let endingsList: [Int] = [108, 150, 168, 1264, 150, 157, 144, 117, 124] // エンディングリスト
    public static let quit: [Int]        = [655, 1268]                        // 終了
    /// Label for our own title-menu entry: the exe's five-item table (30.3) has no recall
    /// slot, so this string exists only in the mglvns port's `#if 0` block (sizuku_op.c:182).
    public static let recallMode: [Int]  = [304, 814, 139, 101, 169]          // 回想モード

    // ESC system menu (sizuku_menu.c order)
    public static let escHideText: [Int]  = [1082, 607, 46, 696, 14]          // 文字を消す
    public static let escLoad: [Int]      = [147, 101, 169, 14, 42]           // ロードする
    public static let escSave: [Int]      = [118, 101, 172, 14, 42]           // セーブする
    public static let escRecall: [Int]    = [116, 125, 144, 109, 304, 814]    // シナリオ回想
    public static let escPrevChoice: [Int] = [235, 19, 806, 26, 804, 864, 1410, 23, 1156, 42] // 一つ前の選択肢に戻る
    public static let escEnd: [Int]       = [158, 101, 137, 655, 1268]        // ゲーム終了

    // Confirm dialogs
    public static let confirmLoad: [Int]  = [147, 101, 169, 13, 32, 14, 87]   // ロードします。
    public static let confirmSave: [Int]  = [118, 101, 172, 13, 32, 14, 87]   // セーブします。
    public static let confirmEnd: [Int]   = [655, 1268, 13, 32, 14, 87]       // 終了します。
    public static let confirmQuestion: [Int] = [39, 44, 13, 3, 65, 14, 7, 97] // よろしいですか？
    public static let yes: [Int]          = [27, 3]                           // はい
    public static let no: [Int]           = [3, 3, 5]                         // いいえ

    // しおり (save slots). Full-width digits １..６ = 78..83.
    public static let shiori: [Int] = [13, 6, 41]                             // しおり
    public static func shioriSlot(_ i: Int) -> [Int] { shiori + [0, 78 + i] } // しおり　N

    // Extra save kinds listed in the load picker.
    public static let quickSaveLabel: [Int] = [112, 106, 154, 112, 118, 101, 172] // クイックセーブ
}
