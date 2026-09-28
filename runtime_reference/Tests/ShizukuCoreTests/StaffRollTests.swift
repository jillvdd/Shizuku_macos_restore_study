//
//  StaffRollTests.swift
//  ShizukuCoreTests
//
//  The ending staff roll (HANDOVER §32). Two properties matter more than looks here: the
//  roll must walk all 14 `eddata[]` cards exactly once and then stop dead until a press
//  (`LvnsWaitClick` — fast-forward cannot skip it), and every card must actually paint,
//  which needs both a plate the `bgmap` number resolves to and glyphs the 1996 dot-matrix
//  font owns. A wrong `location` silently renders black and an uncoverable leaf silently
//  drops a letter, so neither failure would show up anywhere else.
//

import XCTest
@testable import ShizukuCore
@testable import ShizukuEngine
@testable import ShizukuRender

final class StaffRollTests: XCTestCase {

    private static let extractedDir: String = {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("research/extracted")
            .path
    }()

    private static let game: GameData = GameData(extractedDir: extractedDir)

    func testEveryCreditIsSpellableInTheDotMatrixFont() {
        let codec = Self.game.leafCodec
        for (i, card) in StaffRoll.cards.enumerated() {
            for line in card.credits {
                XCTAssertEqual(codec.uncovered(in: line.text), [], "card \(i) row \(line.row)")
            }
        }
    }

    func testEveryCardPlateResolvesToAnImage() {
        for (i, card) in StaffRoll.cards.enumerated() {
            let name = BackgroundMap.bgFileName(forLocation: card.location)
            XCTAssertFalse(name.isEmpty, "card \(i): location \(card.location) has no plate")
            let img = Self.game.image(name: name,
                                      paletteOverride: BackgroundMap.paletteOverride(forLocation: card.location))
            XCTAssertNotNil(img, "card \(i): plate \(name) is missing from the archive")
        }
    }

    /// `tputs` centres on `cells * 24`, so the longest line must still fit the 640 px canvas.
    func testNoCreditLineRunsOffScreen() {
        let codec = Self.game.leafCodec
        for card in StaffRoll.cards {
            for line in card.credits {
                let width = codec.leaves(for: line.text).count * StaffRoll.cellWidth
                XCTAssertLessThanOrEqual(width, StaffRoll.nativeWidth, line.text)
            }
        }
    }

    func testRollWalksEveryCardOnceAndThenStopsForAPress() {
        var player = StaffRoll.Player(effectsEnabled: true)
        var entered: [Int] = []
        var previous = player.stage
        for _ in 0..<20000 {
            player.tick()
            if case .creditHold(let card) = player.stage, player.stage != previous {
                entered.append(card)
            }
            previous = player.stage
            if player.isAwaitingClick { break }
        }
        XCTAssertEqual(entered, Array(0..<StaffRoll.cards.count - 1), "a card was skipped or repeated")
        XCTAssertTrue(player.isAwaitingClick)

        // The author's requirement: `ScriptStep` drives the fades through the `*Low` entry
        // points and `LvnsWait` polls no input, so no amount of ticking leaves the last card.
        player.tick(flips: 100000)
        XCTAssertTrue(player.isAwaitingClick)
        XCTAssertFalse(player.isFinished)
    }

    /// `LvnsScript.c:29-40`: a click sets `lvns->select`, and the *next* `ScriptStep`
    /// rewinds `scr->cur` to the sole `CLICK_JUMP`. So one mid-roll click lets the current
    /// entry finish and then runs the trailing `CLEAR(FADE_PALETTE)` + `END` — the roll is
    /// skippable, exactly as the user reported the original behaves.
    func testSelectMidRollRewindsToTheEnd() {
        var player = StaffRoll.Player(effectsEnabled: true)
        player.tick(flips: 500)            // deep in the early cards, not the last
        XCTAssertFalse(player.isAwaitingClick)
        player.click()
        // Worst case the click lands just after a `WAIT 6000` began: it runs out (360 flips),
        // then the closing fade (16) finishes the roll — far short of the ~5760 full walk.
        player.tick(flips: StaffRoll.cardHoldFlips + StaffRoll.fadeSteps + 50)
        XCTAssertTrue(player.isFinished, "one click must end the roll at the next stage boundary")
    }

    /// A cancel is NOT `select`: `ScriptStep` only rewinds on `lvns->select`, so a mid-roll
    /// right-click / Esc is ignored and the roll keeps walking.
    func testCancelMidRollIsIgnored() {
        var player = StaffRoll.Player(effectsEnabled: true)
        player.tick(flips: 500)
        let before = player.stage
        player.cancel()
        player.tick()
        XCTAssertEqual(player.stage, before, "cancel must not rewind the script mid-roll")
        player.tick(flips: StaffRoll.cardHoldFlips + StaffRoll.fadeSteps + 50)
        XCTAssertFalse(player.isFinished, "cancel does not skip the roll")
    }

    /// The last card's `LVNS_SCRIPT_WAIT_CLICK` (`LvnsWaitClick`, `LvnsControl.c:311-326`)
    /// breaks on select *or* cancel; either then runs the trailing `CLEAR(FADE_PALETTE)`.
    func testLastCardSelectAndCancelBothExit() {
        var player = StaffRoll.Player(effectsEnabled: true)
        while !player.isAwaitingClick { player.tick() }
        player.cancel()
        XCTAssertFalse(player.isFinished, "the trailing `CLEAR(FADE_PALETTE)` still runs")
        player.tick(flips: StaffRoll.fadeSteps)
        XCTAssertTrue(player.isFinished)
    }

    /// 画面エフェクト off: `ClearEffect`/`DispEffect` return on their first call, so each
    /// 16-step ramp collapses into one flip — a straight cut, never a half-lit frame.
    func testFadeOffCollapsesEachPaletteRampIntoOneFlip() {
        var on = StaffRoll.Player(effectsEnabled: true)
        var off = StaffRoll.Player(effectsEnabled: false)
        on.tick()
        off.tick()
        XCTAssertEqual(on.stage, .darkening(card: nil))
        XCTAssertEqual(off.stage, .lightening(card: 0))
    }

    /// `sizuku.c:810-826`: `END_BGM` starts the ending track and then *blocks* the
    /// interpreter on `SizukuEnding`, so the roll owns the screen until it is dismissed.
    func testEndingBlockHandsTheScreenToTheRoll() {
        let engine = ShizukuEngine(game: Self.game)
        engine.skip = true
        engine.start(scn: 94, block: 1) // 瑠璃子 BAD: MSG ×3 → END_CHK → ENDING → END_BGM 18
        // A headless test has no 60 Hz ticker, so pump `LvnsClear`/`LvnsDisp` by hand —
        // `step()` parks on `.rendered` while one owns the screen.
        func drain() { while engine.isRevealing { engine.tickReveal(deltaTime: 1.0) } }
        drain()
        var result = engine.step()
        var spins = 0
        while result != .waitingStaffRoll {
            spins += 1
            XCTAssertLessThan(spins, 100, "SCN094 block 1 never reaches END_BGM")
            switch result {
            case .waitingMessage: engine.advanceMessage()
            case .waitingChoice: engine.selectChoice(0)
            default: break
            }
            drain()
            result = engine.step()
        }
        XCTAssertEqual(engine.phase, .staffRoll)
        XCTAssertEqual(engine.step(), .waitingStaffRoll, "stepping must not resume past the roll")
        engine.finishStaffRoll()
        XCTAssertEqual(engine.phase, .running)
    }
}
