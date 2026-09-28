//
//  StaffRoll.swift
//  ShizukuRender
//
//  The ending staff roll (雫～しずく～, 1996) — the 14 credit cards the original plays
//  between the last message of an ending and the jump back to the title.
//
//  Where it sits in the original: opcode `0x7d` (`END_BGM bgm_no`) in the scenario command
//  stream is handled by `sizuku.c:810-826`, which starts the ending track and then calls
//  `SizukuEnding(lvns)` — a *blocking* `LvnsScriptRun(lvns, eddata)` over the table in
//  `sizuku_ed.c`. Only after it returns does the interpreter carry on with the
//  `IF_NE`/`JUMP 195` epilogue chain, so the roll owns the screen end-to-end. Every ending
//  block in the shipped scripts reaches it: they all end `END_CHK` → `ENDING` → `END_BGM`
//  (SCN093/094/095/097/099/100/136/137/172/173/194).
//
//  Why fast-forward cannot skip it — but a click can: the roll drives the screen through
//  `ScriptStep`'s script-level cases, which call `LvnsClearLow` and `LvnsDispLow` directly
//  (`LvnsScript.c:46-65`) and so bypass the `if (lvns->skip)` fast path that
//  `LvnsClear`/`LvnsDisp` offer the normal game screen (`LvnsDisp.c:188-233`); and
//  `LvnsWait` (`Lvns.c:455-460`) is a plain flip loop that polls no input. With `skip` set,
//  every 6000 ms hold and every 16-step palette fade still runs at full length. But a click
//  sets `lvns->select`, and `ScriptStep` opens with `if (lvns->select) { … rewind scr->cur
//  to the next LVNS_SCRIPT_CLICK_JUMP … }` (`LvnsScript.c:29-40`). `eddata[]` carries exactly
//  one `CLICK_JUMP` (right before the trailing `CLEAR(FADE_PALETTE)` + `END`), so a single
//  click lets the *current* table entry finish (the hold is not cut short) and then jumps
//  straight to the closing fade — the whole roll ends.
//
//  Per-card rhythm, read off `eddata[]`: the next plate is staged by `BG` while the current
//  card is still up, `WAIT 6000` holds it, `CLEAR(FADE_PALETTE)` walks `latitude` 16→0 one
//  step per flip (16 flips ≈ 267 ms) with the credits baked into the same image, then
//  `DISP(FADE_PALETTE)` lightens the new plate 0→16, `WAIT 1000` shows it alone, and the
//  card's `tputs` lines land in one flip. The last card holds until a click, then a final
//  `CLEAR(FADE_PALETTE)` takes the screen to black.
//
//  `tputs` (`sizuku_ed.c:26-36`) centres each line — `x = (WIDTH2 - strlen*CHARSIZE/2)/2`,
//  i.e. `(640 - bytes*12)/2`, and every credit here is EUC-JP full-width (2 bytes/cell), so
//  the width is `cells * 24` — and stacks it at `y = row * EDYOFF` (30). It overprints the
//  glyph three times: shadow (palette entry `EDSHA` = 0) at +1/+1 and +2/+2, colour
//  (`EDCOL` = 4) on the dot. Entry 0 is black in every `sizuku_haikei_palette` row and
//  entry 4 is the constant white block the `MAX_S` plates all carry (`palmap` replaces
//  entries 0…3 only), so the credits are white on a black double shadow on every card.
//

import Foundation
import ShizukuCore
import ShizukuEngine

public enum StaffRoll {

    // MARK: - The table (`eddata[]`, verbatim order)

    public struct CreditLine {
        public let row: Int      // `y = row * EDYOFF`
        public let text: String
        public init(row: Int, text: String) { self.row = row; self.text = text }
    }

    /// `location` is the number the `LVNS_SCRIPT_BG` entry carried, so the plate goes
    /// through `bgmap`/`palmap` exactly like an in-game background change.
    public struct Card {
        public let location: Int
        public let credits: [CreditLine]
        public init(location: Int, credits: [CreditLine]) {
            self.location = location
            self.credits = credits
        }
    }

    public static let cards: [Card] = [
        Card(location: 2, credits: [.init(row: 5, text: "プログラム"),
                                    .init(row: 7, text: "ＨＡＪＩＭＥ　ＮＩＮＯＭＡＥ")]),
        Card(location: 44, credits: [.init(row: 5, text: "キャラクター原案"),
                                     .init(row: 7, text: "高彦　龍哉")]),
        Card(location: 11, credits: [.init(row: 5, text: "原画"),
                                     .init(row: 7, text: "水無月　徹")]),
        Card(location: 12, credits: [.init(row: 5, text: "脚本"),
                                     .init(row: 7, text: "高橋　龍也")]),
        Card(location: 13, credits: [.init(row: 4, text: "ビジュアルグラフィックス"),
                                     .init(row: 6, text: "鳥野　正信"),
                                     .init(row: 7, text: "ＨＡＭＭＥＲ"),
                                     .init(row: 8, text: "親父油"),
                                     .init(row: 9, text: "生波夢"),
                                     .init(row: 10, text: "ＤＯＺＡ")]),
        Card(location: 15, credits: [.init(row: 5, text: "キャラクターグラフィックス"),
                                     .init(row: 7, text: "ＨＡＭＭＥＲ"),
                                     .init(row: 8, text: "鳥野　正信")]),
        Card(location: 20, credits: [.init(row: 5, text: "背景グラフィックス"),
                                     .init(row: 7, text: "鳥野　正信"),
                                     .init(row: 8, text: "親父油"),
                                     .init(row: 9, text: "生波夢")]),
        Card(location: 22, credits: [.init(row: 5, text: "オリジナルフォント"),
                                     .init(row: 7, text: "ＨＡＭＭＥＲ"),
                                     .init(row: 8, text: "爆裂煙々黒頭巾"),
                                     .init(row: 9, text: "水無月　徹")]),
        Card(location: 24, credits: [.init(row: 5, text: "シーン構成"),
                                     .init(row: 7, text: "ＯＲＩＢＡＳＳ"),
                                     .init(row: 8, text: "葉月　優一"),
                                     .init(row: 9, text: "水無月　徹"),
                                     .init(row: 10, text: "初号機")]),
        Card(location: 26, credits: [.init(row: 5, text: "音楽"),
                                     .init(row: 7, text: "折戸　伸治"),
                                     .init(row: 8, text: "下川　直哉"),
                                     .init(row: 9, text: "石川　真也")]),
        Card(location: 27, credits: [.init(row: 5, text: "ＴＥＳＴ　ＰＬＡＹ"),
                                     .init(row: 7, text: "ＡＬＬ　ＬＥＡＦ　ＳＴＡＦＦ")]),
        Card(location: 31, credits: [.init(row: 5, text: "ＳＰＥＣＩＡＬ　ＴＨＡＮＸ"),
                                     .init(row: 7, text: "ＫＥＮ　ＫＥＮ")]),
        Card(location: 35, credits: [.init(row: 6, text: "ＡＮＤ　ＹＯＵ")]),
        Card(location: 5, credits: [.init(row: 5, text: "企画・開発"),
                                   .init(row: 7, text: "１９９６　ＬＥＡＦ")]),
    ]

    // MARK: - Native geometry and colours

    public static let nativeWidth = 640
    public static let nativeHeight = 400
    /// `EDYOFF` (`Lvns.h:84`).
    public static let rowOffset = 30
    /// `CHARSIZE` (`Lvns.h:83`); a full-width glyph is one cell wide.
    public static let cellWidth = 24
    /// `EDCOL` = palette entry 4 = the plates' constant white; `EDSHA` = entry 0 = black.
    static let inkCredit: (UInt8, UInt8, UInt8) = (255, 255, 255)
    static let inkShadow: (UInt8, UInt8, UInt8) = (0, 0, 0)

    // MARK: - Timing (`LvnsWait(ms * INTERVAL / 1000)`, `INTERVAL` = 60 flips/s)

    /// `LVNS_SCRIPT_WAIT 6000` — how long a card holds before the next one takes over.
    public static let cardHoldFlips = 360
    /// `LVNS_SCRIPT_WAIT 1000` — the new plate alone, before its credits land.
    public static let plateHoldFlips = 60
    /// `Darken`/`Lighten` move `latitude` by 1 per flip between 16 and 0
    /// (`LvnsEffect.c:696-740`), so a palette fade is 16 flips ≈ 267 ms.
    public static let fadeSteps = 16
    public static let latitudeMax = 16

    // MARK: - Player

    public enum Stage: Equatable {
        /// `CLEAR(FADE_PALETTE)`: what is on screen walks down to black. `card == nil` while
        /// it is the ending's game screen (the roll's opening), otherwise a credit card.
        case darkening(card: Int?)
        /// `DISP(FADE_PALETTE)`: plate `card` lightens up from black, credits not yet drawn.
        case lightening(card: Int)
        /// The 1000 ms a new plate holds on its own.
        case plateHold(card: Int)
        /// Plate + credits — this is the 6000 ms hold, i.e. what a card looks like.
        case creditHold(card: Int)
        /// `LVNS_SCRIPT_WAIT_CLICK` on the last card: only a press leaves it.
        case awaitingClick(card: Int)
        /// The roll's trailing `CLEAR(FADE_PALETTE)`; the script resumes once it is black.
        case closingDark(card: Int)
        /// `LVNS_SCRIPT_END` — `SizukuEnding` has returned.
        case finished
    }

    /// Flip-driven state machine over `eddata[]`. The view ticks it at 60 Hz. Fast-forward
    /// cannot shorten it (see the header), but a *click* ends it — `lvns->select` rewinds
    /// the script to the table's sole `CLICK_JUMP`, exactly as `LvnsScript.c:29-40` does.
    public struct Player {
        public private(set) var stage: Stage = .darkening(card: nil)
        public private(set) var latitude = StaffRoll.latitudeMax

        /// `lvns->select`: set by a click, consumed at the next stage boundary.
        private var selectPending = false

        /// `lvns->enable_effect`: with the 画面エフェクト setting off, `ClearEffect` and
        /// `DispEffect` return True on their first call, so the whole 16-step ramp collapses
        /// into one flip and each card change becomes a straight cut.
        private let fadeStep: Int
        private var holdTicks = 0

        public init(effectsEnabled: Bool) {
            fadeStep = effectsEnabled ? 1 : StaffRoll.fadeSteps
        }

        public var isFinished: Bool { stage == .finished }

        /// Whether the roll is parked on `LVNS_SCRIPT_WAIT_CLICK`.
        public var isAwaitingClick: Bool {
            if case .awaitingClick = stage { return true }
            return false
        }

        /// The plate of the current card, or nil while the game-screen frame is still up.
        var cardIndex: Int? {
            switch stage {
            case .darkening(let c): return c
            case .lightening(let c), .plateHold(let c), .creditHold(let c),
                 .awaitingClick(let c), .closingDark(let c): return c
            case .finished: return nil
            }
        }

        /// Whether this stage bakes the card's `tputs` lines into the image.
        var showsCredits: Bool {
            switch stage {
            case .creditHold, .awaitingClick, .closingDark: return true
            case .darkening(let c): return c != nil
            default: return false
            }
        }

        /// A click. In `LVNS_SCRIPT_WAIT_CLICK` (the last card) it starts the closing fade
        /// immediately. Anywhere else it sets `lvns->select`: the *current* stage runs to its
        /// end (`LvnsWait` is not cut short) and the next boundary rewinds to the `CLICK_JUMP`
        /// tail — the trailing `CLEAR(FADE_PALETTE)` + `END` (`LvnsScript.c:29-40`).
        public mutating func click() {
            guard stage != .finished else { return }
            if case .awaitingClick(let card) = stage {
                stage = .closingDark(card: card)
                latitude = StaffRoll.latitudeMax
                return
            }
            selectPending = true
        }

        /// A cancel (`LvnsCancel`: right-click / Esc). `ScriptStep` only rewinds on
        /// `lvns->select`, never on `cancel`, so mid-roll a cancel is ignored. It exits the
        /// roll only at the final `LVNS_SCRIPT_WAIT_CLICK`, which `LvnsWaitClick`
        /// (`LvnsControl.c:311-326`) breaks on for select *or* cancel.
        public mutating func cancel() {
            guard case .awaitingClick(let card) = stage else { return }
            stage = .closingDark(card: card)
            latitude = StaffRoll.latitudeMax
        }

        /// Consume a completed stage: honour a pending `select` by jumping to the closing
        /// fade (or straight to `finished` when nothing but the opening black is up), else
        /// fall through to the stage the table dictates.
        private mutating func finishStage(_ next: Stage) {
            guard selectPending else { stage = next; return }
            selectPending = false
            if let card = cardIndex {
                stage = .closingDark(card: card)
            } else {
                stage = .finished
            }
        }

        public mutating func tick(flips: Int = 1) {
            for _ in 0..<flips {
                if stage == .finished { return }
                step()
            }
        }

        private mutating func step() {
            switch stage {
            case .darkening(let card):
                guard advanceFade(down: true) else { return }
                // The table's `BG` staged the next plate before the hold, so the picture
                // that comes up out of the black is already the following card's.
                finishStage(.lightening(card: (card ?? -1) + 1))
            case .lightening(let card):
                guard advanceFade(down: false) else { return }
                holdTicks = 0
                finishStage(.plateHold(card: card))
            case .plateHold(let card):
                holdTicks += 1
                guard holdTicks >= StaffRoll.plateHoldFlips else { return }
                holdTicks = 0
                finishStage(card == StaffRoll.cards.count - 1
                    ? .awaitingClick(card: card) : .creditHold(card: card))
            case .creditHold(let card):
                holdTicks += 1
                guard holdTicks >= StaffRoll.cardHoldFlips else { return }
                holdTicks = 0
                finishStage(.darkening(card: card))
            case .awaitingClick, .finished:
                break
            case .closingDark:
                if advanceFade(down: true) { stage = .finished }
            }
        }

        /// One step of the palette ramp; True once the target latitude is reached.
        mutating func advanceFade(down: Bool) -> Bool {
            latitude = down ? max(0, latitude - fadeStep)
                            : min(StaffRoll.latitudeMax, latitude + fadeStep)
            return latitude == (down ? 0 : StaffRoll.latitudeMax)
        }
    }

    // MARK: - Rendering

    /// `openingFrame` is the game screen the roll starts from — only drawn during the first
    /// `darkening`, and already at `width x height` device pixels.
    public static func render(game: GameData, player: Player,
                              openingFrame: RGBAImage?, scale: Int) -> RGBAImage {
        var img: RGBAImage
        switch player.stage {
        case .darkening(let card) where card == nil && openingFrame != nil:
            img = openingFrame!
        default:
            if let card = player.cardIndex {
                img = cardImage(game: game, card: card, credits: player.showsCredits, scale: scale)
            } else {
                img = RGBAImage(width: nativeWidth * scale, height: nativeHeight * scale)
                img.fill(0, 0, 0, 255)
            }
        }
        // The credits are baked into the same image as the plate (`SizukuPutsVRAM` writes to
        // vram), so a palette fade takes the text down with the artwork.
        if player.latitude < latitudeMax { img.scaleRGB(by: player.latitude, of: latitudeMax) }
        for p in stride(from: 3, to: img.pixels.count, by: 4) { img.pixels[p] = 255 }
        return img
    }

    static func cardImage(game: GameData, card: Int, credits: Bool, scale: Int) -> RGBAImage {
        let entry = cards[max(0, min(cards.count - 1, card))]
        var img = RGBAImage(width: nativeWidth * scale, height: nativeHeight * scale)
        img.fill(0, 0, 0, 255)
        // `SizukuLoadBG(lvns, no)`: `bgmap` picks the file, `palmap` the atmosphere.
        let name = BackgroundMap.bgFileName(forLocation: entry.location)
        let override = BackgroundMap.paletteOverride(forLocation: entry.location)
        if !name.isEmpty, let plate = game.image(name: name, paletteOverride: override) {
            img.blitScaled(plate, dx: 0, dy: 0, factor: scale)
        }
        if credits {
            let tr = TextRenderer(font: game.cnFont, scale: scale)
            for line in entry.credits { draw(game, tr, &img, line, scale: scale) }
        }
        return img
    }

    /// `tputs`: `(640 - cells*24)/2`, `row * 30`, shadow at +1/+1 and +2/+2, colour on top.
    static func draw(_ game: GameData, _ tr: TextRenderer, _ img: inout RGBAImage,
                     _ line: CreditLine, scale: Int) {
        let leaves = game.leafCodec.leaves(for: line.text)
        let x = (nativeWidth - leaves.count * cellWidth) / 2
        var cx = x * scale
        let cy = line.row * rowOffset * scale
        for leaf in leaves {
            if leaf != 0, let px = game.cnFont.pixels(game.textSlot(forLeaf: leaf)) {
                for o in [scale, 2 * scale] {
                    tr.drawGlyphMatrixPublic(px, into: &img, x: cx + o, y: cy + o,
                                             glyphPx: 24, scale: scale, ink: inkShadow)
                }
                tr.drawGlyphMatrixPublic(px, into: &img, x: cx, y: cy,
                                         glyphPx: 24, scale: scale, ink: inkCredit)
            }
            cx += cellWidth * scale
        }
    }
}
