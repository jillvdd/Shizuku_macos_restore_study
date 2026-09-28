//
//  MusicRoom.swift
//  ShizukuRender
//
//  The original title-screen 「音楽モード」 BGM player (雫～しずく～, 1996).
//
//  Evidence (all offsets are file offsets into 《雫～しずく～1996》 /Sizuku.exe, i.e.
//  VA - 0x400000; read-only inspection, nothing was written to the game directory):
//
//   * Trigger: the title menu's item pointer table (VA 0x430ebc, file 0x30ebc) holds FIVE
//     strings, not the four that are visible. Items 1-4 (file 0x30ebc/ed0/ee4/ef8) carry no
//     placement code — the generic menu engine stacks them — while item 5 (file 0x30f0c) is
//     `s0 X56Y128 ff ff r $`: literal ASCII placement codes followed by an empty cell, i.e.
//     an invisible item pen-placed at X=56*8=448, Y=128 — the top window of the tower block
//     at the right of the building on TITLE0. Its dispatch entry (table 0x409558, case 4 ->
//     0x409537) calls 0x408d40. The same X-in-8px reading is confirmed by the room's own
//     buttons below: X22/X37/X49 -> 176/296/392 lays the three labels out symmetrically
//     about the 320px centre.
//   * Room body `0x408d40..0x408eb8`: `0x408d45` = `push 0x11; call 0x405c20`, and
//     `0x405c20` is the CG-display routine, so the room opens on plate **VIS17** (the music
//     box) at native (0,0). Then stop BGM, start track 0 (リーフ), hold the plate at full
//     brightness for `0x414af0(30)` = 300 ms, walk the screen palette down to
//     `latitude_dark` (see below), and only then draw the form (see `Layout`) and enter a
//     3-button menu loop (items at file 0x30ce8: `X22Y300前の曲`, `X37Y300演奏`,
//     `X49Y300次の曲`).
//     Selection 0 = previous track with 0..23 wrap, 1 = play the selected track
//     (`cl = playno[esi]`, table 0x30f48), 2 = next track, 0xffff (right click) = exit.
//   * Card body `0x408c70(esi = index, edi = row)`: writes the two decimal digits of
//     `esi` into the `ＮＯ．００` template (file 0x30c3c, +9/+11 = the low byte of each
//     digit leaf), draws the track name from the pointer table 0x430e28[esi], then the
//     composer from the credit index table 0x430e88[esi] -> pointer table 0x430cac.
//   * Text draw is `0x412350(x, y, str, ...)`; its prologue stores arg2 into the pen-Y
//     word 0x43c406 that the `Y` control code also writes, which is how the argument
//     order was pinned down.
//
//  The 24 names and 24 composer credits below were decoded from those tables with
//  `sizfont.tbl` (leaf code = (b0 & 0x7f) << 8 | b1). They cross-check against the
//  bundled commercial OST in 原声OST（无损）: 22 of 24 composer attributions match
//  exactly (the two that differ are the logo sting and the chime).
//
//  Track order also settles the file mapping: slot 0 = リーフ == MUS00.OGG (the boot
//  jingle) and slot 14 = オープニング == MUS14.OGG (the OP), so the room's index IS the
//  MUS file index; `playno` is only the CD-DA track number, which skips 14.
//

import Foundation
import CoreGraphics
import AppKit
import ShizukuCore
import ShizukuEngine

public enum MusicRoom {

    public static let trackCount = 24

    /// Name pointer table `0x430e28`, in the order the room lists them.
    public static let titles = [
        "リーフ", "精神世界", "授業中", "学園生活", "叔父さん", "推理・憶測",
        "瑞穂", "沙織", "瑠璃子", "調査", "回想", "捜索",
        "Ｈシーン１", "Ｈシーン２", "オープニング", "トゥルーエンド", "ハッピーエンド", "バッドエンド",
        "敵", "バトル", "狂気", "オルゴール１", "オルゴール２", "チャイム",
    ]

    /// Composer pointer table `0x430cac`; the room prints the credit with a full-width
    /// space between surname and given name, exactly as the string table stores it.
    public static let composers = ["折戸　伸治", "石川　真也", "下川　直哉"]

    /// Credit index table `0x430e88` (one word per track).
    static let composerOfTrack = [
        0, 1, 0, 1, 2, 0, 2, 1, 0, 2, 0, 0,
        0, 0, 2, 0, 2, 2, 0, 0, 0, 0, 0, 1,
    ]

    /// The MUS file index of a room slot — identical, see the header note. The
    /// original's `playno` table (`0x430f48`) held the CD-DA track number the driver
    /// wanted, which skips 14; our OGGs are named by slot, so it never enters here.
    public static func musicFileIndex(_ index: Int) -> Int { index }

    // MARK: - Layout (native px; the original's pen coordinates from 0x408d40/0x408c70)

    public enum Layout {
        public static let title = (x: 260, y: 32)          // 音楽モード (5 cells -> centred)
        public static let labelColumnX = 96                // 4 cells from the left
        public static let numberColumnX = 240              // ＮＯ．ｎｎ
        public static let nameColumnX = 384                // 曲名
        public static let playingRowY = 100
        public static let selectedRowY = 200
        public static let creditRowOffset = 30             // 作曲・編曲 sits under its card
        public static let buttonsY = 300
        public static let buttonX = [176, 296, 392]        // X22 / X37 / X49
        /// Exit hint under the buttons (see `render`).
        public static let exitHint = (x: 152, y: 352)
    }

    // MARK: - Backdrop plate and its two brightness levels

    /// The room's backdrop. `0x408d45` is `push 0x11; call 0x405c20`, and `0x405c20` is
    /// the CG-display routine, so the argument is plate number 17 — the music box. It is
    /// blitted at native (0, 0): the plate is 504x400 with its art in x 112..503, which is
    /// exactly where the original's silhouette lands on a 640px screen.
    public static let plateName = "VIS17"

    /// `lvns->latitude` — the palette multiplier in 16ths. Normal screen is 16 (`Lvns.c:71`);
    /// a menu screen drops it to `latitude_dark` = 11 (`Lvns.c:72`, `LvnsMenu.c:57`), and
    /// `LvnsDarken` walks the value down one step per flip (`LvnsEffect.c:973`). The multiply
    /// is integer and per palette entry: `cmap_m[i][j] = j * i / 16` (`NSLvnsImage.m:20`).
    public static let latitudeNormal = 16
    public static let latitudeDark = 11

    /// `0x408d5d` is `push 0x1e; call 0x414af0` — 30 x 10 ms the plate is held at full
    /// brightness before the darken starts, i.e. 18 flips of the 60 Hz ticker.
    public static let introHoldFlips = 18

    /// Top-left of the invisible 5th title item (`X56 Y128`, i.e. 56*8 = 448).
    public static let titleEntryX = 448
    public static let titleEntryY = 128

    public static let buttonLabels = ["前の曲", "演奏", "次の曲"]
    public static let previousButton = 0
    public static let playButton = 1
    public static let nextButton = 2

    /// The invisible 5th title-menu item: one glyph cell at native (448, 128). The
    /// original's cell is 16px wide; this port's UI font runs on the 24px KNJ cell, so the
    /// hit box is one of *our* cells wide from the same top-left corner. Nothing is drawn
    /// for it — `0x30f0c` stores a bare space glyph, and the user confirmed the entry is
    /// meant to stay unfound-looking.
    public static func entryHitRect(scale: Int) -> CGRect {
        CGRect(x: titleEntryX * scale, y: titleEntryY * scale,
               width: SceneComposer.glyphAdvance * scale,
               height: SceneComposer.glyphAdvance * scale)
    }

    /// Hit box of each of the three buttons: its label's glyph run.
    public static func buttonRects(scale: Int) -> [CGRect] {
        buttonLabels.enumerated().map { i, label in
            CGRect(x: Layout.buttonX[i] * scale, y: Layout.buttonsY * scale,
                   width: label.count * SceneComposer.glyphAdvance * scale,
                   height: SceneComposer.glyphAdvance * scale)
        }
    }

    // MARK: - Rendering

    /// The whole room: `playing` fills the upper card (演奏中の曲), `selected` the lower
    /// one (選択中の曲), and `hovered` is the button index or -1 for none — the original
    /// highlights the row under the cursor the same way the title menu does.
    ///
    /// `latitude` is the screen's palette multiplier in 16ths and `formShown` gates the
    /// text: the original presents the plate at latitude 16, waits 300 ms, walks the
    /// palette down to 11, and only then draws the form over it.
    public static func render(game: GameData, playing: Int, selected: Int, hovered: Int,
                              latitude: Int = latitudeDark, formShown: Bool = true,
                              scale: Int, lang: GameLanguage = .jp) -> RGBAImage {
        var img = RGBAImage(width: 640 * scale, height: 400 * scale)
        if let plate = game.image(name: plateName) {
            img.blitScaled(plate, dx: 0, dy: 0, factor: scale)
        }
        if latitude < latitudeNormal {
            applyLatitude(&img, latitude)
        }
        guard formShown else {
            for p in stride(from: 3, to: img.pixels.count, by: 4) { img.pixels[p] = 255 }
            return img
        }

        let tr = TextRenderer(font: game.cnFont, scale: scale)
        // WP-9: the room's UI chrome is language-routed; track titles and composer
        // credits stay JP verbatim (they are `Sizuku.exe` string-table data, not UI).
        let strings = ShellText.musicStrings(lang)

        draw(game, tr, &img, strings.title, Layout.title.x, Layout.title.y,
             SceneComposer.inkText, scale, lang)
        drawCard(game, tr, &img, label: strings.playingLabel, index: playing,
                 rowY: Layout.playingRowY, scale: scale, lang: lang)
        drawCard(game, tr, &img, label: strings.selectedLabel, index: selected,
                 rowY: Layout.selectedRowY, scale: scale, lang: lang)

        for (i, label) in strings.buttons.enumerated() {
            let ink = i == hovered ? SceneComposer.inkText : (150, 150, 150)
            draw(game, tr, &img, label, Layout.buttonX[i], Layout.buttonsY, ink, scale, lang)
        }

        // The original's loop polls the mouse only (`0x408e11`), so right-click is its
        // one exit. Ours also takes Esc, and the room is a dead end without a hint.
        draw(game, tr, &img, strings.exitHint,
             Layout.exitHint.x, Layout.exitHint.y, (120, 120, 120), scale, lang)

        for p in stride(from: 3, to: img.pixels.count, by: 4) { img.pixels[p] = 255 }
        return img
    }

    /// `cmap_m[latitude][c] == c * latitude / 16`. Applied to the composited plate rather
    /// than to the palette because this port decodes to RGBA up front; the result is the
    /// same integer map, and the text drawn afterwards stays at full brightness — as it
    /// does in the original, where 「音楽モード」 measures 255,255,255 over a dimmed plate.
    static func applyLatitude(_ img: inout RGBAImage, _ latitude: Int) {
        let k = max(0, min(latitudeNormal, latitude))
        for p in stride(from: 0, to: img.pixels.count, by: 4) {
            for c in 0..<3 {
                img.pixels[p + c] = UInt8(Int(img.pixels[p + c]) * k / latitudeNormal)
            }
        }
    }

    private static func drawCard(_ game: GameData, _ tr: TextRenderer, _ img: inout RGBAImage,
                                 label: String, index: Int, rowY: Int, scale: Int,
                                 lang: GameLanguage = .jp) {
        let i = max(0, min(trackCount - 1, index))
        draw(game, tr, &img, label, Layout.labelColumnX, rowY, SceneComposer.inkText, scale, lang)
        let strings = ShellText.musicStrings(lang)
        draw(game, tr, &img, strings.creditLabel, Layout.labelColumnX,
             rowY + Layout.creditRowOffset, SceneComposer.inkText, scale, lang)
        draw(game, tr, &img, String(format: "ＮＯ．%02d", i),
             Layout.numberColumnX, rowY, SceneComposer.inkText, scale, lang)
        draw(game, tr, &img, titles[i], Layout.nameColumnX, rowY, SceneComposer.inkText, scale)
        draw(game, tr, &img, composers[composerOfTrack[i]], Layout.numberColumnX,
             rowY + Layout.creditRowOffset, SceneComposer.inkText, scale)
    }

    /// One dot-matrix string; with `lang == .zh` the UI chrome instead goes through the
    /// native CJK font (same 1px-shadow double stamp as the rest of the shell). Track
    /// names and composer credits never take this branch — they stay JP.
    private static func draw(_ game: GameData, _ tr: TextRenderer, _ img: inout RGBAImage,
                             _ text: String, _ x: Int, _ y: Int,
                             _ ink: (UInt8, UInt8, UInt8), _ scale: Int = 1,
                             _ lang: GameLanguage = .jp) {
        if lang == .zh {
            let s = scale
            let body = (UInt8(ink.0), UInt8(ink.1), UInt8(ink.2))
            SceneComposer.drawZHText(into: &img, text: text, x: x * s, y: y * s,
                                     ink: body, shadow: SceneComposer.inkShadow,
                                     scale: s, game: game,
                                     fontSize: ShellText.nativeMenuFontSize)
            return
        }
        let s = scale
        let cy = y * s
        var cx = x * s
        for leaf in game.leafCodec.leaves(for: text) {
            if leaf != 0, let px = game.cnFont.pixels(game.textSlot(forLeaf: leaf)) {
                tr.drawGlyphMatrixPublic(px, into: &img, x: cx + 2 * s, y: cy + s,
                                         glyphPx: 24, scale: s, ink: SceneComposer.inkShadow)
                tr.drawGlyphMatrixPublic(px, into: &img, x: cx + s, y: cy + s,
                                         glyphPx: 24, scale: s, ink: SceneComposer.inkShadow)
                tr.drawGlyphMatrixPublic(px, into: &img, x: cx, y: cy,
                                         glyphPx: 24, scale: s, ink: ink)
            }
            cx += SceneComposer.glyphAdvance * s
        }
    }
}
