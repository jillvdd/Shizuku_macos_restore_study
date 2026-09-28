//
//  SubType01Tests.swift
//  ShizukuCoreTests
//
//  M4.11b: the four `0x01` SUB 过场 sub-types of `sizuku.c:580-612`.
//   * kind 01 — sine background while the message prints, then `LvnsClear(FADE_PALETTE)`
//     to black (`LvnsSetBackEffect` + tail `LvnsClearLow`).
//   * kind 02 — `LvnsDisp(FADE_PALETTE)` fade-in first, then the sine message, no tail.
//   * kind 03 — blocking `LvnsAnimation(sizuku01/02)` logo insert (`LvnsAnim.c:43-111`).
//   * kind 04 — plain message, no staging.
//  Corpus sites (SHIZUKU_DUMP_SUBTYPES): kind 1 ×10 (e.g. SCN024 blk01), kind 2 ×2
//  (SCN024 blk01 after the kind-01), kind 3 ×6 (SCN051 blk01, all sizuku01), kind 4 ×5.
//

import AVFoundation
import XCTest
@testable import ShizukuCore
@testable import ShizukuEngine
@testable import ShizukuRender

final class SubType01Tests: XCTestCase {

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

    /// Drive the interpreter the way the App's pump + 60 Hz ticker do: drain any
    /// transition one flip at a time, click through messages, auto-pick choices, and stop
    /// as soon as `stop` holds (checked before every step and after every yield).
    private func walk(_ engine: ShizukuEngine, maxSteps: Int = 20000,
                      until stop: (ShizukuEngine) -> Bool) {
        var guardCount = 0
        while !stop(engine) {
            guard guardCount < maxSteps else {
                XCTFail("walk cap reached scn=\(engine.scnIndex) blk=\(engine.blockIndex) pc=\(engine.pc)")
                return
            }
            guardCount += 1
            if engine.transition != nil {
                engine.tickReveal(deltaTime: 1.0 / 60.0)
                continue
            }
            switch engine.phase {
            case .awaitingMessage:
                if engine.waitingPause == nil { engine.revealAll() } else { engine.advanceMessage() }
                continue
            case .awaitingChoice:
                engine.selectChoice(0)
                continue
            default:
                break
            }
            if case .ended = engine.phase { return }
            _ = engine.step()
        }
    }

    // MARK: - sine table gold (verbatim port of `sintable` in `sin_effect.c:17-20`)

    func testSineTableMatchesReferenceVerbatim() {
        XCTAssertEqual(SinBackEffect.table.count, 361)
        XCTAssertEqual(SinBackEffect.table.reduce(0, +), -1)   // both 0° endpoints carry 0
        XCTAssertEqual(SinBackEffect.table[0], 0)
        XCTAssertEqual(SinBackEffect.table[90], 160)
        XCTAssertEqual(SinBackEffect.table[180], 0)
        XCTAssertEqual(SinBackEffect.table[270], -160)
        XCTAssertEqual(SinBackEffect.table[360], 0)
        // `SinEffectSetState`: +8 per flip, wrapping by subtracting the table size.
        XCTAssertEqual(SinBackEffect.stateStep, 8)
        XCTAssertEqual(SinBackEffect.nextState(0), 8)
        XCTAssertEqual(SinBackEffect.nextState(356), 3)
        // Row i of a flip uses `sintable[(state + i) % 361]` (`SinEffect`'s p-carry).
        XCTAssertEqual(SinBackEffect.rowShift(state: 355, row: 10), SinBackEffect.table[4])
    }

    // MARK: - kind 01 (SCN024 blk01)

    func testKind01SineMessageThenFadeToBlack() {
        let engine = ShizukuEngine(game: Self.game)
        engine.skip = false
        engine.start(scn: 24, block: 1)
        walk(engine, until: { $0.backEffectActive && $0.phase == .awaitingMessage })
        XCTAssertTrue(engine.backEffectActive)
        XCTAssertNil(engine.transition, "kind 01 arms the sine but stages no fade yet")
        XCTAssertEqual(engine.backEffectState, 0, "LvnsSetBackEffect resets the phase")

        // Every flip advances the sine by 8° (`Lvns.Interval` → `SinEffectSetState`).
        engine.tickReveal(deltaTime: 1.0 / 60.0)
        XCTAssertEqual(engine.backEffectState, 8)
        for _ in 0..<45 { engine.tickReveal(deltaTime: 1.0 / 60.0) }
        XCTAssertEqual(engine.backEffectState, 8 * 46 % 361)

        // Finish the message: the tail is `stopBackEffect` + `LvnsClear(FADE_PALETTE)`.
        while engine.phase == .awaitingMessage, engine.transition == nil {
            if engine.waitingPause == nil { engine.revealAll() } else { engine.advanceMessage() }
        }
        XCTAssertFalse(engine.backEffectActive, "the tail disarms the sine")
        XCTAssertEqual(engine.transition?.clearEffect, .fadePalette)
        XCTAssertEqual(engine.transition?.dispEffect, nil)
        var flips = 0
        while engine.transition != nil, flips < 600 {
            engine.tickReveal(deltaTime: 1.0 / 60.0)
            flips += 1
        }
        XCTAssertGreaterThan(flips, 16, "the palette ramp is 17 flips, not a straight cut")
        XCTAssertNil(engine.scene.bgName)
        XCTAssertNil(engine.scene.bgHName)
        XCTAssertNil(engine.scene.bgOverride)
        XCTAssertTrue(engine.scene.portraits.isEmpty)
    }

    // MARK: - kind 02 (SCN024 blk01, after the kind-01)

    func testKind02YieldsWithLiveFadeIn() {
        let engine = ShizukuEngine(game: Self.game)
        engine.skip = false
        engine.effectsEnabled = true
        engine.start(scn: 24, block: 1)
        var sawKind2 = false
        var guardCount = 0
        while !sawKind2 && guardCount < 20000 {
            guardCount += 1
            if engine.transition != nil {
                // Reaching a kind-02 mid its own fade-in: sine is already armed.
                if engine.backEffectActive, engine.phase == .awaitingMessage {
                    XCTAssertEqual(engine.transition?.clearEffect, nil)
                    XCTAssertEqual(engine.transition?.dispEffect, .fadePalette)
                    sawKind2 = true
                }
                engine.tickReveal(deltaTime: 1.0 / 60.0)
                continue
            }
            switch engine.phase {
            case .awaitingMessage:
                if engine.waitingPause == nil { engine.revealAll() } else { engine.advanceMessage() }
            case .awaitingChoice:
                engine.selectChoice(0)
            case .logoAnimation:
                engine.finishLogoAnimation()
            case .staffRoll:
                engine.finishStaffRoll()
            case .ended:
                return
            case .running:
                _ = engine.step()
            }
        }
        XCTAssertTrue(sawKind2, "SCN024 blk01 pc54 must yield a message behind a FADE_PALETTE disp")
        // Drain the fade-in: the sine survives it (its tail only stops the effect).
        while engine.transition != nil { engine.tickReveal(deltaTime: 1.0 / 60.0) }
        XCTAssertTrue(engine.backEffectActive, "kind 02 keeps rippling while the message prints")
        while engine.phase == .awaitingMessage, engine.transition == nil {
            if engine.waitingPause == nil { engine.revealAll() } else { engine.advanceMessage() }
        }
        XCTAssertFalse(engine.backEffectActive)
        XCTAssertNil(engine.transition, "kind 02 has no trailing CLEAR — `sizuku.c:593-597`")
    }

    // MARK: - kind 03 (SCN051 blk01)

    func testKind03BlocksScriptUntilFinished() {
        let engine = ShizukuEngine(game: Self.game)
        engine.skip = false
        engine.start(scn: 51, block: 1)
        walk(engine, until: { $0.phase == .logoAnimation })
        XCTAssertEqual(engine.phase, .logoAnimation)
        XCTAssertEqual(engine.logoAnimationNumber, 0, "SCN051's first insert is sizuku01")
        let pc = engine.pc
        XCTAssertEqual(engine.step(), .waitingLogoAnimation)
        XCTAssertEqual(engine.pc, pc, "stepping must not resume past the insert")
        engine.finishLogoAnimation()
        XCTAssertEqual(engine.phase, .running)
    }

    // MARK: - insert player (`LvnsAnim.c` loop)

    func testSizukuTablesFlipCounts() {
        // sizuku01: 2 runs of (17 plates + SOUND) + 2×WAIT(200) = 38 entries, each one
        // display flip, each wait 12 more → 62 flips ≈ 1.03 s at 60 Hz.
        XCTAssertEqual(LogoAnimation.sizuku01.count, 38)
        XCTAssertEqual(LogoAnimation.sizuku02.count, 19)
        for number in [0, 1] {
            let expected = LogoAnimation.table(number: number)
                .reduce(0) { $0 + 1 + $1.waitFlips }
            var p = LogoAnimation.Player(number: number)
            // The last entry's own advance flip shows its plate; `isFinished` lands on the
            // next (hand-off) flip, which is the one the App never draws.
            var flips = 0
            while !p.isFinished, flips <= expected + 2 {
                p.tick(flips: 1, skip: false)
                flips += 1
            }
            XCTAssertTrue(p.isFinished)
            XCTAssertEqual(flips, expected + 1)
        }
        XCTAssertEqual(LogoAnimation.sizuku01.reduce(0) { $0 + 1 + $1.waitFlips }, 62)
        XCTAssertEqual(LogoAnimation.sizuku02.reduce(0) { $0 + 1 + $1.waitFlips }, 19)
    }

    func testSkipOnlyCollapsesWaits() {
        // `LvnsAnim.c:108-109`: skip zeroes pending waits entry by entry; the 1-flip
        // frames keep their cadence, so the floor is one flip per entry.
        var p = LogoAnimation.Player(number: 0)
        var flips = 0
        while !p.isFinished, flips < 1000 {
            p.tick(flips: 1, skip: true)
            flips += 1
        }
        // One flip per entry plus the same never-drawn hand-off tick.
        XCTAssertEqual(flips, LogoAnimation.sizuku01.count + 1)
    }

    func testWaitAndSoundEntriesKeepShowingLastPlate() {
        var p = LogoAnimation.Player(number: 0)
        p.tick(flips: 3, skip: false)
        XCTAssertEqual(p.frame?.name, "OP_S02")
        p.tick(flips: 1, skip: false)            // the SOUND entry
        XCTAssertTrue(p.wantsSound)
        XCTAssertEqual(p.frame?.name, "OP_S02",   // SOUND draws nothing: previous plate stays
                       "SOUND entries must not cut the screen to black")
        p.tick(flips: 10000, skip: false)        // run the whole table out
        XCTAssertNil(p.frame, "finished player holds nothing")
    }

    func testSizuku02EndsOnMaxPlate() {
        var p = LogoAnimation.Player(number: 1)
        while p.frame?.name != "MAX_S37", !p.isFinished {
            p.tick(flips: 1, skip: false)
        }
        XCTAssertEqual(p.frame?.name, "MAX_S37")
        XCTAssertEqual(p.frame?.y, 0, "MAX_S37 is a full-screen plate at (0,0)")
    }

    /// §34 regression. `P017.WAV` — the mono 11025 Hz plate SCN051 msg 1 plays —
    /// reached `AVAudioPlayerNode.scheduleBuffer` in its raw format and raised an
    /// uncaught `NSException` ("required condition is false:
    /// _outputFormat.channelCount == buffer.format.channelCount"), which AppKit's
    /// event-loop handler swallowed while silently unwinding the interpreter.
    /// Buffers must be converted to the node's output format before scheduling.
    func testMonoSFXBufferIsConvertedForStereoNode() throws {
        let url = URL(fileURLWithPath: Self.extractedDir + "/sound/P017.WAV")
        let file = try AVAudioFile(forReading: url)
        XCTAssertEqual(file.processingFormat.channelCount, 1)
        XCTAssertEqual(file.processingFormat.sampleRate, 11_025)
        let dst = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2))
        let buffer = try XCTUnwrap(AudioController.convertedBuffer(from: file, to: dst))
        XCTAssertEqual(buffer.format.channelCount, 2)
        XCTAssertEqual(buffer.format.sampleRate, 48_000)
        XCTAssertGreaterThan(buffer.frameLength, 0)
        // ~3.7 s of audio at the target rate.
        XCTAssertLessThan(Double(buffer.frameLength) / 48_000, 5)
    }
}
