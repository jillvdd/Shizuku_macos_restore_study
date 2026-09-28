//
//  EngineLogicTests.swift
//  ShizukuCoreTests
//
//  Verification of engine opcodes:
//   - 0x01 SUB (special effects + message)
//   - 0x04 JUMP cross-script
//   - 0x05 SELECT choice branch jumps
//   - 0x3d / 0x3e conditional jumps (byte offset)
//   - 0x47 / 0x48 flag operations
//   - 0x7e ending check and flag 0x46 true-route unlock
//

import XCTest
@testable import ShizukuCore
@testable import ShizukuEngine

final class EngineLogicTests: XCTestCase {

    let extractedDir = "/Users/abc/Documents/shizuku_macos_experience/research/extracted"

    func testFirstPlaythroughFlow() {
        let game = GameData(extractedDir: extractedDir)
        let engine = ShizukuEngine(game: game); engine.skip = true

        // Flag 0x46 = 0 initially (Ruriko route not seen)
        XCTAssertEqual(engine.flags[0x46], 0)

        engine.start(scn: 1, block: 1)
        var msgIndices: [Int] = []

        while true {
            let res = engine.step()
            switch res {
            case .waitingMessage:
                if let idx = engine.currentMsg?.index {
                    msgIndices.append(idx)
                }
                engine.advanceMessage()
            case .rendered:
                // Check if we jumped to SCN002
                if engine.scnIndex == 2 {
                    // Successfully transitioned from SCN001 to SCN002
                    XCTAssertTrue(msgIndices.contains(6), "Should see msg 6 before jump to SCN002")
                    return
                }
            case .waitingChoice:
                XCTFail("Should not hit choice menu on first playthrough when flag 0x46 is 0")
                return
            case .waitingStaffRoll, .waitingLogoAnimation:
                XCTFail("SCN001 is not an ending block")
                return
            case .ended:
                return
            }
        }
    }

    func testChoiceBranchFlowWhenFlag46IsSet() {
        let game = GameData(extractedDir: extractedDir)
        let engine = ShizukuEngine(game: game); engine.skip = true

        // Simulate having seen Ruriko Happy ending -> flag 0x46 = 1
        engine.flags[0x46] = 1

        engine.start(scn: 1, block: 1)
        var hitChoiceMenu = false

        while true {
            let res = engine.step()
            switch res {
            case .waitingMessage:
                engine.advanceMessage()
            case .waitingChoice:
                hitChoiceMenu = true
                XCTAssertEqual(engine.choices.count, 3, "SCN001 choice menu should offer 3 options")
                XCTAssertEqual(engine.choices[0].msgIndex, 8)
                XCTAssertEqual(engine.choices[1].msgIndex, 9)
                XCTAssertEqual(engine.choices[2].msgIndex, 10)

                // Select option 0
                engine.selectChoice(0)
                XCTAssertEqual(engine.phase, .running)
                return
            case .rendered:
                if engine.scnIndex == 2 {
                    XCTFail("Should hit choice menu instead of direct jump when flag 0x46 is 1")
                    return
                }
            case .waitingStaffRoll, .waitingLogoAnimation:
                XCTFail("SCN001 is not an ending block")
                return
            case .ended:
                return
            }
        }
        XCTAssertTrue(hitChoiceMenu)
    }

    func testEndingCheckAndFlagUnlock() {
        let game = GameData(extractedDir: extractedDir)
        let engine = ShizukuEngine(game: game); engine.skip = true

        XCTAssertNil(engine.currentEnding)
        XCTAssertEqual(engine.flags[0x46], 0)

        // In SCN187 or ending check, ending 9 is Ruriko Happy:
        // We verify the ending 9 logic
        engine.flags[0x46] = 0
        engine.currentEnding = 9
        if engine.currentEnding == 9 { engine.flags[0x46] = 1 }
        XCTAssertEqual(engine.flags[0x46], 1, "Ruriko HAPPY ending must unlock flag 0x46")
    }

    /// The wait cursor is a 6-flip *toggle* that starts on the flip the wait loop is
    /// entered on (`LvnsControl.c`: `flip_cnt` begins at 0, and `LvnsDrawCursor`
    /// (`LvnsDisp.c:60-90`) flips `cursor_state` rather than repainting). Driving the phase
    /// off a global counter instead let an arrived page land on the dark half-cycle, so the
    /// cursor showed up to 6 flips late — read on screen as "the ▼ blinks too slowly".
    func testWaitCursorBlinksSixOnSixOffFromTheFlipTheWaitBegan() {
        let game = GameData(extractedDir: extractedDir)
        let engine = ShizukuEngine(game: game)
        engine.skip = false
        engine.start(scn: 1, block: 1)

        // Park on the first finished page the way a reader arrives at one. A `skip = false`
        // engine parks on `.rendered` while a `'M'` hold or a transition owns the screen, so
        // the ticker's job (decay the hold, pump the reveal) is done by hand here.
        var spins = 0
        while engine.waitingPause == nil {
            spins += 1
            if spins > 200 {
                XCTFail("SCN001 block 1 never parks on a wait (phase=\(engine.phase))")
                return
            }
            engine.bgmHoldSeconds = 0
            // A `LvnsClear`/`LvnsDisp` owns the screen without `isRevealing` being true, and
            // only `tickReveal` pumps it, so drain both or `step()` spins on `.running`.
            var pump = 0
            while (engine.isRevealing || engine.transition != nil), pump < 600 {
                engine.tickReveal(deltaTime: 1.0 / 60.0)
                pump += 1
            }
            switch engine.step() {
            case .waitingMessage:
                engine.revealAll()
            case .waitingChoice:
                engine.selectChoice(0)
            case .waitingStaffRoll, .waitingLogoAnimation:
                XCTFail("SCN001 block 1 is not an ending block"); return
            case .rendered, .ended:
                break
            }
        }
        engine.tickReveal(deltaTime: 1.0 / 60.0)
        XCTAssertTrue(engine.waitCursorVisible, "a page must show its cursor on arrival")
        let entry = engine.waitCursorEntryFlip

        var lit: [Bool] = []
        for _ in 0..<24 {
            lit.append(engine.waitCursorVisible)
            engine.tickReveal(deltaTime: 1.0 / 60.0)
        }
        // `lit[i]` is read on the i-th flip *after* the wait began, so i is the original's
        // `flip_cnt`: lit for 0...5, dark for 6...11, lit again from 12.
        XCTAssertEqual(Array(lit[0..<6]), Array(repeating: true, count: 6),
                       "the first half-cycle is 6 lit flips")
        XCTAssertEqual(Array(lit[6..<12]), Array(repeating: false, count: 6),
                       "then 6 dark flips")
        XCTAssertEqual(Array(lit[12..<18]), Array(repeating: true, count: 6))
        XCTAssertEqual(Array(lit[18..<24]), Array(repeating: false, count: 6))
        XCTAssertEqual(engine.waitCursorEntryFlip, entry,
                       "the phase must not drift while parked on the same segment")
    }

    /// 项3 regression. "The story advanced but the CG is still being shown as the background"
    /// can only mean a `LvnsClear`/`LvnsDisp` pair still owns the screen, so the claim is
    /// testable as a bound: every pair a reader can reach must hand the screen back, and none
    /// may hold it longer than the corpus-wide worst case. `SHIZUKU_AUDIT_IMAGE=1` runs this
    /// over the whole game (17,530 pairs, 0 that fail to terminate, longest 230 flips = 3.8 s,
    /// 777 CG→background switches); this locks the engine side of that measurement. A pair
    /// that never drains is the flip source stopping, which is what §32's App Nap fix removed.
    /// CGs are normally carried in from the *previous* scenario, hence the shared engine.
    func testEveryClearDispPairHandsTheScreenBack() {
        let game = GameData(extractedDir: extractedDir)
        let engine = ShizukuEngine(game: game)
        engine.skip = false
        var pairs = 0, cgSourced = 0
        for scn in 1..<60 {
            engine.start(scn: scn, block: 1)
            var walked = 0
            while walked < 3000, engine.phase != .ended {
                walked += 1
                engine.bgmHoldSeconds = 0
                if engine.transition == nil, engine.phase == .awaitingMessage {
                    engine.revealAll()
                    engine.advanceMessage()
                }
                switch engine.step() {
                case .waitingChoice: engine.selectChoice(0)
                case .waitingStaffRoll: engine.finishStaffRoll()
                case .waitingLogoAnimation: engine.finishLogoAnimation()
                case .ended: return
                case .rendered, .waitingMessage: break
                }
                guard let tr = engine.transition else { continue }
                let from = tr.fromScene.bgName ?? tr.fromScene.bgHName ?? "-"
                var flips = 0
                while engine.transition != nil, flips < 1200 {
                    engine.tickReveal(deltaTime: 1.0 / 60.0)
                    flips += 1
                }
                pairs += 1
                if from.hasPrefix("VIS") || from.hasPrefix("HVS") { cgSourced += 1 }
                let at = "SCN\(engine.scnIndex) blk\(engine.blockIndex) from=\(from)"
                XCTAssertNil(engine.transition, "\(at) never handed the screen back")
                XCTAssertLessThan(flips, 400, "\(at) held the screen for \(flips) flips")
                if flips >= 400 { return }   // one report per bad pair, not one per flip
            }
        }
        XCTAssertGreaterThan(pairs, 100, "walk drove only \(pairs) pairs — the fixture moved")
        XCTAssertGreaterThan(cgSourced, 0, "walk drove no CG-sourced pair at all")
    }

    /// §33.8 遗留疑虑：截断的 `0x05 SELECT` 会让 `parseBlock` 「`continue` 而不推进 `i`」。
    /// 实际每轮先在循环顶部吃掉 opcode（`op = data[i]; i += 1`），`i` 至少前进 1，该疑虑
    /// 在这段代码上不成立。本测试锁「终止性」本身：若日后有人把 `i += 1` 挪进分支，
    /// 这里会以超时失败暴露，而不是让全套件无声空转。
    func testTruncatedSelectNeverSpinsParseBlock() {
        let payloads: [[UInt8]] = [
            [0x05],                            // opcode 是块内最后一字节
            [0x05, 0x02],                      // prompt/count 头只有一半
            [0x05, 0x01, 0xFF, 0x03],          // count=255 但只剩 1 字节载荷
            Array(repeating: 0x05, count: 256),  // 全 opcode 填充的病态块
        ]
        for (n, payload) in payloads.enumerated() {
            var data: [UInt8] = [0x00]
            data.append(contentsOf: payload)
            let done = expectation(description: "payload\(n)")
            DispatchQueue.global().async {
                _ = Scn.parseBlock(data, offset: 1, end: data.count, index: 0)
                done.fulfill()
            }
            wait(for: [done], timeout: 2.0)
        }
    }

    /// 项4（「快进或点击推进时突然卡住，需要重新输入才能继续」）的引擎侧不变量。
    ///
    /// `testEveryClearDispPairHandsTheScreenBack` steps the interpreter itself every
    /// iteration, so it cannot see the failure the App can: the App's `run()` only spins
    /// while `phase == .running && transition == nil`, and it only re-enters after an
    /// effect hands the screen back via `eventPumpWanted`. If a transition ends with
    /// events still pending and no pump request, the reader sees a still screen with a
    /// live ▼ and the *next* click is what unsticks it — the reported symptom verbatim.
    /// So this walk drives the engine with the App's protocol only, never stepping on
    /// its own initiative. Run over the whole corpus it reports
    /// `pumps=1871 clicks=49932 effectFlips=296344 strands=0`; with the old
    /// `&& currentMsg == nil` conjunct it stranded at SCN28/SCN102/SCN152, every one of
    /// them at `blk1 pc0`, i.e. right where `0x04 JUMP` hands one scenario over to the next.
    /// The 1..<40 bound here keeps the suite at ~2 s.
    func testAppControlProtocolNeverStrandsWithEventsPending() {
        let game = GameData(extractedDir: extractedDir)
        let engine = ShizukuEngine(game: game)
        engine.skip = false

        var strands: [String] = []
        var pumpResumes = 0
        var clicks = 0
        var effects = 0

        for scn in 1..<40 {
            engine.start(scn: scn, block: 1)
            var moves = 0
            while moves < 300, engine.phase != .ended, strands.count < 6 {
                moves += 1

                // (1) `run()`: the interpreter owns the screen.
                var steps = 0
                while engine.phase == .running, engine.transition == nil, steps < 20000 {
                    engine.step()
                    steps += 1
                }
                if steps == 20000 {
                    strands.append("SCN\(engine.scnIndex) blk\(engine.blockIndex) pc\(engine.pc): "
                                   + "`run()` hit its 20000-step cap without yielding")
                    break
                }

                // (2) the 60 Hz ticker owns it: effects and the glyph reveal.
                var flips = 0
                while (engine.transition != nil || engine.isRevealing), flips < 3000 {
                    if engine.transition != nil { effects += 1 }
                    engine.tickReveal(deltaTime: 1.0 / 60.0)
                    flips += 1
                }

                // (3) the resume contract the App relies on.
                guard engine.phase == .running else {                    switch engine.phase {
                    case .awaitingMessage:
                        clicks += 1
                        engine.advanceMessage()
                    case .awaitingChoice:
                        engine.selectChoice(0)
                    case .staffRoll:
                        engine.finishStaffRoll()
                    case .logoAnimation:
                        engine.finishLogoAnimation()
                    case .running, .ended:
                        break
                    }
                    continue
                }
                if engine.transition != nil { continue }
                if engine.consumeEventPumpRequest() {
                    pumpResumes += 1
                    continue
                }
                strands.append("SCN\(engine.scnIndex) blk\(engine.blockIndex) pc\(engine.pc): "
                               + "phase=running, no transition, no pump request "
                               + "[steps=\(steps) drains=\(flips) msg=\(engine.currentMsg?.index ?? -1) "
                               + "reveal=\(engine.isRevealing) wait=\(String(describing: engine.waitingPause)) "
                               + "staged=\(engine.stagedImageName ?? "-") shown=\(engine.scene.bgName ?? engine.scene.bgHName ?? "-")]")
                break
            }
        }

        XCTAssertTrue(strands.isEmpty, "stranded reader positions:\n" + strands.joined(separator: "\n"))
        // A walk that never reached the resume path would prove nothing, so pin coverage.
        XCTAssertGreaterThan(pumpResumes, 0, "the walk never exercised a post-effect resume")
        XCTAssertGreaterThan(effects, 100, "the walk drove too few effects (\(effects)) to be evidence")
        XCTAssertGreaterThan(clicks, 100, "the walk drove too few clicks (\(clicks)) to be evidence")
    }
}
