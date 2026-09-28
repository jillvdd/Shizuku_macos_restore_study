//
//  SaveLoadTests.swift
//  ShizukuCoreTests
//
//  Tests for SaveManager (M3.3) and ShizukuEnding / GlobalSystemData (M3.4).
//

import XCTest
@testable import ShizukuCore
@testable import ShizukuEngine
@testable import ShizukuRender

final class SaveLoadTests: XCTestCase {
    var game: GameData!
    var extractedDir: String!
    var tempDir: URL!

    override func setUpWithError() throws {
        let extracted = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("research/extracted")
        extractedDir = extracted.path
        game = try XCTUnwrap(GameData(extractedDir: extracted.path))

        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir = tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
    }

    func testSaveStateEncodingAndDecoding() throws {
        var scene = Scene()
        scene.bgName = "MAX_S01"
        scene.bgm = 2
        scene.portraits = [Portrait(imgName: "MAX_C01", x: 160, y: 200)]

        var flags = [UInt8](repeating: 0, count: 256)
        flags[0x46] = 1
        flags[5] = 42

        let state = SaveState(
            version: 1,
            slot: 1,
            timestamp: Date(),
            previewText: "テストセーブ",
            scnIndex: 1,
            blockIndex: 1,
            pc: 15,
            flags: flags,
            scene: scene,
            phase: .awaitingMessage,
            currentMsgIndex: 3,
            currentPage: 0,
            choices: [Choice(msgIndex: 8, jumpOffset: 12, label: "選択肢1")],
            currentEnding: nil
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(state)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(SaveState.self, from: data)

        XCTAssertEqual(decoded.slot, 1)
        XCTAssertEqual(decoded.previewText, "テストセーブ")
        XCTAssertEqual(decoded.scnIndex, 1)
        XCTAssertEqual(decoded.blockIndex, 1)
        XCTAssertEqual(decoded.pc, 15)
        XCTAssertEqual(decoded.flags[0x46], 1)
        XCTAssertEqual(decoded.flags[5], 42)
        XCTAssertEqual(decoded.scene.bgName, "MAX_S01")
        XCTAssertEqual(decoded.scene.bgm, 2)
        XCTAssertEqual(decoded.scene.portraits.count, 1)
        XCTAssertEqual(decoded.scene.portraits[0].imgName, "MAX_C01")
        XCTAssertEqual(decoded.phase, .awaitingMessage)
        XCTAssertEqual(decoded.currentMsgIndex, 3)
        XCTAssertEqual(decoded.choices.count, 1)
        XCTAssertEqual(decoded.choices[0].label, "選択肢1")
    }

    func testEngineSaveAndRestoreMidMessage() throws {
        let saveMgr = SaveManager(saveDirectory: tempDir)
        let engine = ShizukuEngine(game: game, saveManager: saveMgr); engine.skip = true
        engine.start(scn: 1, block: 1)

        // Advance until first message (MSG 0)
        while engine.phase == .running {
            _ = engine.step()
        }

        XCTAssertEqual(engine.phase, .awaitingMessage)
        XCTAssertEqual(engine.currentMsg?.index, 0)
        XCTAssertEqual(engine.scene.bgName, "MAX_S01")
        XCTAssertEqual(engine.scene.bgm, 2)

        // Modify a custom flag to verify persistence
        engine.flags[10] = 77

        // Save to slot 1
        let savedState = try saveMgr.save(slot: 1, engine: engine, previewText: "第1シーン")
        XCTAssertEqual(savedState.slot, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: saveMgr.fileURL(for: 1).path))

        // Create a completely new engine instance and restore
        let engine2 = ShizukuEngine(game: game, saveManager: saveMgr); engine2.skip = true
        XCTAssertEqual(engine2.phase, .running)
        XCTAssertNil(engine2.currentMsg)
        XCTAssertEqual(engine2.flags[10], 0)

        let loadedState = try saveMgr.load(slot: 1, into: engine2)
        XCTAssertEqual(loadedState.slot, 1)

        // Verify that state restored exactly
        XCTAssertEqual(engine2.scnIndex, 1)
        XCTAssertEqual(engine2.blockIndex, 1)
        XCTAssertEqual(engine2.pc, engine.pc)
        XCTAssertEqual(engine2.phase, .awaitingMessage)
        XCTAssertEqual(engine2.currentMsg?.index, 0)
        XCTAssertEqual(engine2.scene.bgName, "MAX_S01")
        XCTAssertEqual(engine2.scene.bgm, 2)
        XCTAssertEqual(engine2.flags[10], 77)

        // Confirm the restored message, then keep confirming messages and assert the engine
        // crosses into SCN002 on its own. SCN001 block 1 branches on flag 0x46: with it clear
        // (the default here) the script runs MSG 0..6 and jumps to SCN002; the 3-way choice
        // is only offered when the flag is set (see testChoiceBranchFlowWhenFlag46IsSet).
        // This is the end-to-end check that a restored save continues the *scripted* flow
        // rather than stalling or wandering.
        advanceThroughMessage(engine2)
        var visited: [Int] = [engine2.scnIndex]
        var steps = 0
        while engine2.phase != .ended && steps < 50 {
            _ = engine2.step()
            if engine2.scnIndex != visited.last { visited.append(engine2.scnIndex) }
            if engine2.phase == .awaitingMessage { advanceThroughMessage(engine2) }
            steps += 1
        }
        XCTAssertTrue(visited.contains(2), "restored engine must follow SCN001 -> SCN002 (visited \(visited))")
    }

    /// Confirm the current message all the way through, segment by segment.
    ///
    /// `advanceMessage()` is a *user click*: the first click during reveal completes the
    /// glyph animation rather than advancing, and a message with several `k`/`p` pauses
    /// needs one click per segment. Loop until the engine actually leaves the segment.
    private func advanceThroughMessage(_ engine: ShizukuEngine, limit: Int = 100) {
        var n = 0
        while engine.phase == .awaitingMessage && n < limit {
            engine.advanceMessage()
            n += 1
        }
    }

    func testChoiceStateSaveAndResume() throws {
        let saveMgr = SaveManager(saveDirectory: tempDir)
        let engine = ShizukuEngine(game: game, saveManager: saveMgr); engine.skip = true
        engine.flags[0x46] = 1 // Unlock branching choices
        engine.start(scn: 1, block: 1)

        while engine.phase != .ended && engine.phase != .awaitingChoice {
            let res = engine.step()
            if res == .waitingMessage {
                advanceThroughMessage(engine)
            }
        }

        XCTAssertEqual(engine.phase, .awaitingChoice)
        XCTAssertEqual(engine.choices.count, 3)

        // Save at choice selection point
        try saveMgr.save(slot: 2, engine: engine, previewText: "3択分岐")

        // Load into fresh engine
        let engine2 = ShizukuEngine(game: game, saveManager: saveMgr); engine2.skip = true
        try saveMgr.load(slot: 2, into: engine2)

        XCTAssertEqual(engine2.phase, .awaitingChoice)
        XCTAssertEqual(engine2.choices.count, 3)
        XCTAssertEqual(engine2.choices[0].msgIndex, 8)
        XCTAssertEqual(engine2.choices[1].msgIndex, 9)
        XCTAssertEqual(engine2.choices[2].msgIndex, 10)

        // Make choice on loaded engine
        engine2.selectChoice(0)
        XCTAssertEqual(engine2.phase, .running)

        var steps = 0
        while engine2.phase == .running && steps < 20 {
            _ = engine2.step()
            steps += 1
        }
        XCTAssertTrue(engine2.phase == .awaitingMessage || engine2.phase == .running)
    }

    func testGlobalSystemAndAll13Endings() throws {
        let saveMgr = SaveManager(saveDirectory: tempDir)
        let engine = ShizukuEngine(game: game, saveManager: saveMgr); engine.skip = true

        // Test ShizukuEnding enum coverage
        XCTAssertEqual(ShizukuEnding.allCases.count, 13)
        XCTAssertEqual(ShizukuEnding(rawValue: 0)?.titleJP, "卒業式")
        XCTAssertEqual(ShizukuEnding(rawValue: 1)?.titleJP, "瑞穂 BAD 1")
        XCTAssertEqual(ShizukuEnding(rawValue: 2)?.titleJP, "破壊")
        XCTAssertEqual(ShizukuEnding(rawValue: 3)?.titleJP, "トースター")
        XCTAssertEqual(ShizukuEnding(rawValue: 4)?.titleJP, "沙織 HAPPY")
        XCTAssertEqual(ShizukuEnding(rawValue: 5)?.titleJP, "沙織 BAD")
        XCTAssertEqual(ShizukuEnding(rawValue: 6)?.titleJP, "瑞穂 HAPPY")
        XCTAssertEqual(ShizukuEnding(rawValue: 7)?.titleJP, "瑞穂 BAD 2")
        XCTAssertEqual(ShizukuEnding(rawValue: 8)?.titleJP, "True")
        XCTAssertEqual(ShizukuEnding(rawValue: 9)?.titleJP, "瑠璃子 HAPPY")
        XCTAssertEqual(ShizukuEnding(rawValue: 10)?.titleJP, "太田さん")
        XCTAssertEqual(ShizukuEnding(rawValue: 11)?.titleJP, "異次元")
        XCTAssertEqual(ShizukuEnding(rawValue: 12)?.titleJP, "異次元 BAD")

        // Good endings check
        XCTAssertTrue(ShizukuEnding.rurikoHappy.isGoodEnding)
        XCTAssertTrue(ShizukuEnding.trueEnding.isGoodEnding)
        XCTAssertTrue(ShizukuEnding.saoriHappy.isGoodEnding)
        XCTAssertTrue(ShizukuEnding.mizuhoHappy.isGoodEnding)
        XCTAssertFalse(ShizukuEnding.destruction.isGoodEnding)

        // SCN095 block 1 has the 0x7e 0x09 instruction (瑠璃子 HAPPY)
        XCTAssertNotNil(game.scn(95))
        engine.start(scn: 95, block: 1)
        var steps = 0
        while engine.phase != .ended && engine.currentEnding == nil && steps < 500 {
            _ = engine.step()
            if engine.phase == .awaitingMessage {
                advanceThroughMessage(engine)
            }
            steps += 1
        }

        XCTAssertEqual(engine.currentEnding, 9)
        XCTAssertEqual(engine.flags[0x46], 1, "Ruriko Happy unlocks flag 0x46")
        XCTAssertEqual(engine.flags[0], 3, "Persistent flag 0 is set to 3 when flag 0x46 == 1")

        // Verify saved to global system data
        let globalSys = saveMgr.loadGlobalSystem()
        XCTAssertTrue(globalSys.clearedEndings.contains(9))
        XCTAssertEqual(globalSys.persistentFlags[0x46], 1)
        XCTAssertEqual(globalSys.persistentFlags[0], 3)

        // Verify resetting engine for new game keeps persistent flags
        engine.reset(scn: 1, block: 1, keepPersistentFlags: true)
        XCTAssertEqual(engine.flags[0x46], 1, "Persistent flag 0x46 retained across reset")
        XCTAssertEqual(engine.flags[0], 3, "Persistent flag 0 retained across reset")
        XCTAssertNil(engine.currentEnding)

        // Verify fresh engine inherits global system data
        let freshEngine = ShizukuEngine(game: game, saveManager: saveMgr); freshEngine.skip = true
        saveMgr.applyGlobalSystem(to: freshEngine)
        XCTAssertEqual(freshEngine.flags[0x46], 1)
        XCTAssertEqual(freshEngine.flags[0], 3)
    }

    func testSaveSlotListingAndDelete() throws {
        let saveMgr = SaveManager(saveDirectory: tempDir)
        let engine = ShizukuEngine(game: game, saveManager: saveMgr); engine.skip = true
        engine.start(scn: 1, block: 1)

        // Save to slot 0 (quicksave), slot 1, slot 2
        try saveMgr.save(slot: 0, engine: engine, previewText: "Quick")
        try saveMgr.save(slot: 1, engine: engine, previewText: "Slot 1")
        try saveMgr.save(slot: 2, engine: engine, previewText: "Slot 2")

        let saves = saveMgr.listSaves()
        XCTAssertEqual(saves.count, 3)
        XCTAssertEqual(saves[0]?.previewText, "Quick")
        XCTAssertEqual(saves[1]?.previewText, "Slot 1")
        XCTAssertEqual(saves[2]?.previewText, "Slot 2")

        // Delete slot 1
        try saveMgr.delete(slot: 1)
        let savesAfter = saveMgr.listSaves()
        XCTAssertEqual(savesAfter.count, 2)
        XCTAssertNil(savesAfter[1])
        XCTAssertFalse(FileManager.default.fileExists(atPath: saveMgr.fileURL(for: 1).path))
    }

    func testBacklogRecordingAndPersistence() throws {
        let saveMgr = SaveManager(saveDirectory: tempDir)
        let engine = ShizukuEngine(game: game, saveManager: saveMgr); engine.skip = true
        engine.start(scn: 1, block: 1)

        // Advance through first 3 messages
        var msgsSeen = 0
        while engine.phase != .ended && msgsSeen < 3 {
            _ = engine.step()
            if engine.phase == .awaitingMessage {
                msgsSeen += 1
                advanceThroughMessage(engine)
            }
        }

        XCTAssertEqual(engine.backlog.count, 3)
        XCTAssertEqual(engine.backlog[0].msg, 0)
        XCTAssertEqual(engine.backlog[1].msg, 1)
        XCTAssertEqual(engine.backlog[2].msg, 2)
        XCTAssertFalse(engine.backlog[0].lines.isEmpty)

        // Save to slot 5
        try saveMgr.save(slot: 5, engine: engine)

        // Restore into new engine
        let engine2 = ShizukuEngine(game: game, saveManager: saveMgr); engine2.skip = true
        try saveMgr.load(slot: 5, into: engine2)
        XCTAssertEqual(engine2.backlog.count, 3)
        XCTAssertEqual(engine2.backlog[1].msg, 1)

        // Reset clears backlog
        engine.reset(scn: 1, block: 1)
        XCTAssertTrue(engine.backlog.isEmpty)
    }

    func testVisualOverlaysRendering() throws {
        let composer = SceneComposer(game: game, scale: 2)
        let engine = ShizukuEngine(game: game); engine.skip = true
        engine.scene.bgName = "MAX_S01"

        // 1. Render Title screen (live path: dimmed backdrop + dot-matrix menu lines)
        var titleImg = composer.titleBackdropDimmed()
        composer.drawMenuLine(into: &titleImg, leaves: MenuStrings.newGame, line: 7, selected: true)
        composer.drawMenuLine(into: &titleImg, leaves: MenuStrings.continueGame, line: 8, selected: false)
        composer.drawMenuLine(into: &titleImg, leaves: MenuStrings.endingsList, line: 9, selected: false)
        composer.drawMenuLine(into: &titleImg, leaves: MenuStrings.quit, line: 10, selected: false)
        XCTAssertEqual(titleImg.width, 1280)
        XCTAssertEqual(titleImg.height, 800)
        let titlePNG = titleImg.encodePNG()
        XCTAssertGreaterThan(titlePNG.count, 10000)

        // 2. Render Ending List Overlay
        var endingsImg = composer.render(engine)
        let cleared: Set<Int> = [0, 4, 6, 8, 9]
        composer.drawEndingListOverlay(into: &endingsImg, clearedEndings: cleared)
        let endingsPNG = endingsImg.encodePNG()
        try endingsPNG.write(to: URL(fileURLWithPath: "/tmp/shizuku_endings_test.png"))
        XCTAssertGreaterThan(endingsPNG.count, 10000)

        // 3. Render the シナリオ回想 fullscreen history page (LvnsHistoryMode)
        engine.start(scn: 1, block: 1)
        var msgCount = 0
        while engine.phase != .ended && msgCount < 3 {
            _ = engine.step()
            if engine.phase == .awaitingMessage {
                msgCount += 1
                advanceThroughMessage(engine)
            }
        }
        XCTAssertEqual(engine.backlog.count, 3)
        let backdrop = composer.render(engine, hideText: true)
        let entry = HistoryView.entry(from: engine.backlog, pos: engine.backlog.count - 1)
        XCTAssertNotNil(entry)
        let historyImg = HistoryView.render(game: game, backdrop: backdrop,
                                            entry: entry!, scale: 2)
        let historyPNG = historyImg.encodePNG()
        try historyPNG.write(to: URL(fileURLWithPath: "/tmp/shizuku_history_test.png"))
        XCTAssertGreaterThan(historyPNG.count, 10000)
        // The nav glyphs must land inside the frame at the right edge (XPOS(25)+offset).
        let arrow = HistoryView.upArrowRect(scale: 1)
        XCTAssertEqual(arrow.maxX, CGFloat(composer.nativeWidth))

        // 4. Render Toast Overlay
        var toastImg = composer.render(engine)
        composer.drawToastOverlay(into: &toastImg, message: "クイックセーブ完了 [SLOT 0]")
        let toastPNG = toastImg.encodePNG()
        XCTAssertGreaterThan(toastPNG.count, 10000)
    }

    /// Run the engine from (scn,blk) until the first SELECT menu appears or the flow
    /// leaves the scenario. Returns (choiceCount or -1, scenario we stopped in).
    private func runUntilFirstChoice(_ engine: ShizukuEngine, scn: Int, blk: Int) -> (Int, Int) {
        engine.start(scn: scn, block: blk)
        var guardCount = 0
        while engine.phase != .ended && guardCount < 8000 {
            guardCount += 1
            _ = engine.step()
            if engine.phase == .awaitingChoice { return (engine.choices.count, engine.scnIndex) }
            if engine.scnIndex != scn { return (-1, engine.scnIndex) }   // fell through, no gate met
            if engine.phase == .awaitingMessage {
                while engine.phase == .awaitingMessage && guardCount < 9000 {
                    engine.advanceMessage(); guardCount += 1
                }
                if engine.scnIndex != scn { return (-1, engine.scnIndex) }
            }
        }
        return (-1, engine.scnIndex)
    }

    /// Item 9: the 瑠璃子/アキラ route choices in SCN001 are gated by `0x3d IF_EQ flag0x46==1`
    /// (`3d 46 01 05` at blk1 offset 0x22). Achieving the 瑠璃子 HAPPY ending sets flag 0x46,
    /// which the original inherits across playthroughs; before that the script falls straight
    /// through to SCN002 with no choice menu.
    func testEndingGatedChoiceUnlock() throws {
        // Positive: flag 0x46 set → the 3-option SELECT is reached in SCN001.
        let unlocked = ShizukuEngine(game: game); unlocked.skip = true
        unlocked.flags[0x46] = 1
        let (count, scn) = runUntilFirstChoice(unlocked, scn: 1, blk: 1)
        XCTAssertEqual(scn, 1, "解锁后应停在 SCN001 的选择肢处")
        XCTAssertEqual(count, 3, "瑠璃子HAPPY(0x46)达成后 SCN001 应出现 3 选项解锁选择肢")

        // Negative control: flag clear → no choice menu, flow leaves to SCN002.
        let locked = ShizukuEngine(game: game); locked.skip = true
        let (count2, scn2) = runUntilFirstChoice(locked, scn: 1, blk: 1)
        XCTAssertEqual(count2, -1, "未达成结局时 SCN001 不应出现该选择肢")
        XCTAssertNotEqual(scn2, 1, "未解锁时应直接跳转到后续场景")

        // Persistence chain: achieving ending 9 records flag 0x46 to system.json; a brand
        // new playthrough inherits it and the SCN001 gate opens on its own.
        let mgr = SaveManager(saveDirectory: tempDir)
        let cleared = ShizukuEngine(game: game, saveManager: mgr); cleared.skip = true
        cleared.flags[0x46] = 1
        cleared.currentEnding = 9
        mgr.recordEnding(9, in: cleared)

        let nextRun = ShizukuEngine(game: game, saveManager: mgr); nextRun.skip = true
        mgr.applyGlobalSystem(to: nextRun)
        XCTAssertEqual(nextRun.flags[0x46], 1, "新周目应从 system.json 继承 0x46")
        let (count3, _) = runUntilFirstChoice(nextRun, scn: 1, blk: 1)
        XCTAssertEqual(count3, 3, "继承后新周目的 SCN001 解锁选择肢应自动出现")
    }

    // MARK: - bgmmap 曲号映射 + 雑シナリオ flag(1) 持久化

    func testBgmScriptNumberToFileIndex() {
        // 原版 sizuku.c:131-140 bgmmap(): 脚本号→CD轨号(14→2, n<16→n+2, 否则 n+1);
        // MUS 文件名 = 轨号-2 (jingle 轨2==MUS00, OP 轨16==MUS14 双重指纹验证)。
        XCTAssertEqual(ShizukuEngine.musicFileIndex(forScriptNo: 1), 1)
        XCTAssertEqual(ShizukuEngine.musicFileIndex(forScriptNo: 13), 13)
        XCTAssertEqual(ShizukuEngine.musicFileIndex(forScriptNo: 14), 0)
        XCTAssertEqual(ShizukuEngine.musicFileIndex(forScriptNo: 15), 15)
        XCTAssertEqual(ShizukuEngine.musicFileIndex(forScriptNo: 16), 15)
        XCTAssertEqual(ShizukuEngine.musicFileIndex(forScriptNo: 17), 16)
        XCTAssertEqual(ShizukuEngine.musicFileIndex(forScriptNo: 25), 24)
    }

    func testMiscScenarioFlag1Persistence() throws {
        let mgr = SaveManager(saveDirectory: tempDir)
        let engine = ShizukuEngine(game: game, saveManager: mgr); engine.skip = true
        engine.flags[1] = 5      // 雑シナリオ flag — SizukuScenarioInit 不清、随结局存档持久
        engine.flags[0x43] = 9   // 可清除的场景 flag (恋するヒロイン)
        engine.currentEnding = 3
        mgr.recordEnding(3, in: engine)
        XCTAssertEqual(mgr.loadGlobalSystem().persistentFlags[1], 5)

        let nextRun = ShizukuEngine(game: game, saveManager: mgr); nextRun.skip = true
        mgr.applyGlobalSystem(to: nextRun)
        XCTAssertEqual(nextRun.flags[1], 5)
        nextRun.flags[0x43] = 7
        nextRun.reset(scn: 1, block: 0, keepPersistentFlags: true)
        XCTAssertEqual(nextRun.flags[1], 5, "原版 ScenarioInit 保留 flag 1(雑)")
        XCTAssertEqual(nextRun.flags[0x43], 0, "场景 flag 0x43 应被新一轮游戏清零")
    }

    // MARK: - M4.10 演出台词回归

    func testTextSpeedIsCharWaitTimeFlips() {
        // 原版 's' 直接赋值 char_wait_time = c[1] (sizuku.c:474)，单位是 LvnsWait 的
        // flip 数(60Hz)，数值越大越慢；默认 1 flip (Lvns.c:45)，换行重置。
        XCTAssertEqual(ShizukuEngine.speed(forHint: 3), 3.0 / 60.0, accuracy: 1e-9)
        XCTAssertEqual(ShizukuEngine.speed(forHint: 0), 1.0 / 60.0, "0 视为 1，不允许每字符零等待")
        XCTAssertEqual(ShizukuEngine.speed(forHint: 2), 2.0 / 60.0, "映射必须单调递增(越大越慢)")
        let engine = ShizukuEngine(game: game); engine.skip = true
        XCTAssertEqual(engine.textSpeed, ShizukuEngine.defaultTextSpeed, accuracy: 1e-9)
    }

    func testSelectPromptTextStaysOnScreenWithChoices() {
        // 原版 0x05 SELECT 先把提示语走文本解析器画上屏，再出选择框。
        // SCN001 的 SELECT 受 flag 0x46 门控 (见 testEndingGatedChoiceUnlock)，需先解锁。
        let engine = ShizukuEngine(game: game); engine.skip = true
        engine.flags[0x46] = 1
        let (count, scn) = runUntilFirstChoice(engine, scn: 1, blk: 1)
        XCTAssertEqual(scn, 1)
        XCTAssertGreaterThan(count, 0)
        XCTAssertEqual(engine.phase, .awaitingChoice)
        XCTAssertFalse(engine.displayedLines.isEmpty, "选择肢出现时提示文本应仍在屏上")
    }

    func testRewindToPrevChoiceReplaysTheMenu() throws {
        // 「一つ前の選択肢に戻る」必须回到 SELECT 指令*之前*：恢复后重新出选择框、
        // 选择后写入的 flag 回滚，而不是落在选完之后的剧情线上。
        let engine = ShizukuEngine(game: game); engine.skip = true
        engine.flags[0x46] = 1
        let (count, _) = runUntilFirstChoice(engine, scn: 1, blk: 1)
        XCTAssertEqual(count, 3)
        guard let sp = engine.lastSelectSavePoint else {
            return XCTFail("进入 0x05 时应记录 selectpoint")
        }
        XCTAssertEqual(sp.pc, engine.pc - 1, "selectpoint.pc 应指向 0x05 事件本身以便重放")
        let flagsAtSelect = engine.flags
        engine.selectChoice(0)
        var g = 0
        while g < 200, engine.phase != .ended, engine.phase != .awaitingChoice {
            _ = engine.step(); g += 1
            if engine.phase == .awaitingMessage { engine.advanceMessage() }
        }
        engine.restoreSaveState(sp)
        var g2 = 0
        while engine.phase == .running, g2 < 20 { _ = engine.step(); g2 += 1 }
        XCTAssertEqual(engine.phase, .awaitingChoice, "恢复后应重新停在选择肢")
        XCTAssertEqual(engine.choices.count, count)
        XCTAssertEqual(engine.flags, flagsAtSelect, "选完后写入的 flag 应随恢复回滚")
    }

    func testFlashAndShakeAreTransient() throws {
        // 'F' = WhiteOut+WhiteIn 16+16 flips, 'Q' = Vibrato 16 flips of random ±16 px —
        // both decay through the 60 Hz ticker instead of sticking until the next message.
        func firstMessage(with action: InlineAction) -> (Int, Int)? {
            for scnIdx in 0..<197 {
                guard let scn = game.scn(scnIdx) else { continue }
                for (msgIdx, m) in scn.messages.enumerated() {
                    for seg in m.segments {
                        for a in seg.actions where a == action { return (scnIdx, msgIdx) }
                    }
                }
            }
            return nil
        }
        let engine = ShizukuEngine(game: game); engine.skip = true
        if let (scnIdx, msgIdx) = firstMessage(with: .flash) {
            engine.previewMessage(scn: scnIdx, msg: msgIdx)
            XCTAssertEqual(engine.flashTicks, ShizukuEngine.flashTotalTicks, "'F' 必须启动 32 flip 白闪")
            for _ in 0..<ShizukuEngine.flashTotalTicks { engine.tickReveal(deltaTime: 1.0 / 60.0) }
            XCTAssertEqual(engine.flashTicks, 0, "白闪必须随 ticker 消退")
        } else {
            throw XCTSkip("全部 SCN 无 'F' 命令")
        }
        if let (scnIdx, msgIdx) = firstMessage(with: .shake) {
            engine.previewMessage(scn: scnIdx, msg: msgIdx)
            XCTAssertEqual(engine.shakeTicks, ShizukuEngine.shakeTotalTicks)
            for _ in 0..<ShizukuEngine.shakeTotalTicks { engine.tickReveal(deltaTime: 1.0 / 60.0) }
            XCTAssertEqual(engine.shakeTicks, 0)
            XCTAssertEqual(engine.shakeDX, 0, "震动结束后偏移必须归零")
            XCTAssertEqual(engine.shakeDY, 0)
        } else {
            throw XCTSkip("全部 SCN 无 'Q' 命令")
        }
    }

    // MARK: - M5.6 WP-1 存档-语言解耦

    /// (a)「JP 语言引擎 save → 切 .zh 引擎 load：cnPages 重挂、currentSegmentIndex 不变」
    /// capture 不再写 language / 中文预览，restore 不再采纳档内语言：ZH 引擎读 JP 档后
    /// 保持 .zh，并按当前 store 重建 cnPages，消息内段号原样保留。
    func testCrossLanguageSaveLoadKeepsBuildLanguageAndRemountsCN() throws {
        // Pick the first SCN001 message that really has ≥2 JP segments, so the saved
        // segment index is >0 and proves the anchor cannot drift across languages.
        let scn1 = try XCTUnwrap(GameData(extractedDir: extractedDir).scn(1))
        let segMsg = try XCTUnwrap(
            scn1.messages.first { $0.segments.count >= 2 && $0.segments.contains { !$0.lines.isEmpty } },
            "SCN001 应存在 ≥2 个 JP 段的消息")
        let cnText = "铅笔芯咔咔地伸出，无意义地在笔记本上滑动。\n这是注入的第二段中文译文。"
        let zhGame = GameData(extractedDir: extractedDir,
                              translationStore: TranslationStore(map: ["1:\(segMsg.index)": cnText]))
        let saveMgr = SaveManager(saveDirectory: tempDir)

        // JP engine parks mid-message (≥ second segment) and saves.
        let jpEngine = ShizukuEngine(game: zhGame, saveManager: saveMgr); jpEngine.skip = true
        jpEngine.previewMessage(scn: 1, msg: segMsg.index)
        XCTAssertEqual(jpEngine.phase, .awaitingMessage)
        jpEngine.revealAll()          // finish the typewriter reveal, then one real click
        jpEngine.advanceMessage()      // seg 0 -> seg 1 (JP segments are the anchor)
        XCTAssertEqual(jpEngine.currentMsg?.index, segMsg.index)
        XCTAssertGreaterThan(jpEngine.currentSegmentIndex, 0,
                             "确认后应停在消息内第二段（JP 段是语言无关坐标系）")

        let saved = try saveMgr.save(slot: 1, engine: jpEngine)
        // ① capture 停写 language 字段（字段保留解码兼容，version 仍为 1）。
        XCTAssertNil(saved.language, "存档不应再写入语言字段")
        let raw = try Data(contentsOf: saveMgr.fileURL(for: 1))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: raw) as? [String: Any])
        XCTAssertNil(json["language"], "JSON 里不得出现 language 键")
        // ② capture 预览固定 JP 叶码解码：中文不得进快照。
        XCTAssertFalse(saved.previewText.contains("铅笔"), "previewText 必须走 JP 叶码解码")
        XCTAssertEqual(saved.previewText,
                       jpEngine.jpPreviewText(scn: 1, msg: segMsg.index),
                       "预览应与渲染期现算的 JP 叶码文本一致")

        // .zh engine loads the JP bookmark.
        let zhEngine = ShizukuEngine(game: zhGame, saveManager: saveMgr); zhEngine.skip = true
        zhEngine.setLanguage(.zh)
        try saveMgr.load(slot: 1, into: zhEngine)
        XCTAssertEqual(zhEngine.language, .zh, "restore 不得采纳 state.language")
        XCTAssertEqual(zhEngine.currentSegmentIndex, jpEngine.currentSegmentIndex,
                       "currentSegmentIndex 必须跨版本原样恢复")
        XCTAssertTrue(zhEngine.cnActive, "ZH 引擎载入后应重挂 cnSlices")
        XCTAssertFalse(zhEngine.cnSlices.isEmpty, "cnSlices 必须按当前 store 重建")
        XCTAssertEqual(zhEngine.cnSlices.count, segMsg.segments.count,
                       "每段 JP 节拍一片中文切片")
        let fullCN = cnText.replacingOccurrences(of: "\n", with: "")
        XCTAssertTrue(fullCN.hasPrefix(zhEngine.cnCommitted),
                      "恢复后已提交拍的中文正文必须是完整译文的前缀")
    }

    /// (b)「store 为空的引擎 load ZH 档：走 JP 渲染不崩」
    /// 老 ZH 档带 language:"zh" 与中文 previewText/backlog 快照残留；空库（JP 构建）引擎
    /// 载入后语言保持 .jp、cnPages 恒空，照常走 JP 点阵路径继续推进。
    func testEmptyStoreEngineLoadsLegacyZHSaveAsJP() throws {
        let saveMgr = SaveManager(saveDirectory: tempDir)
        let jpGame = GameData(extractedDir: extractedDir,
                              translationStore: TranslationStore())

        // Forge a legacy ZH save: real anchors + old-format language residue.
        let author = ShizukuEngine(game: jpGame, saveManager: saveMgr); author.skip = true
        author.start(scn: 1, block: 1)
        while author.phase == .running { _ = author.step() }
        var legacy = author.captureSaveState(slot: 2)
        legacy.language = .zh
        legacy.previewText = "这是老 ZH 档烘入的中文预览快照"
        legacy.backlog = [BacklogEntry(scn: 1, msg: legacy.currentMsgIndex ?? 0,
                                       lines: [[1]], textPreview: "老档中文回想快照")]
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(legacy).write(to: saveMgr.fileURL(for: 2))

        // Empty-store engine loads it.
        let engine = ShizukuEngine(game: jpGame, saveManager: saveMgr); engine.skip = true
        try saveMgr.load(slot: 2, into: engine)
        XCTAssertEqual(engine.language, .jp, "构建语言不得被档内 language:\"zh\" 覆盖")
        XCTAssertTrue(engine.cnSlices.isEmpty, "空库必须保持 cnSlices 恒空")
        XCTAssertFalse(engine.cnActive, "应当走 JP 渲染路径")
        XCTAssertEqual(engine.currentMsg?.index, legacy.currentMsgIndex)
        XCTAssertEqual(engine.phase, .awaitingMessage)
        // JP 渲染路径可继续推进，不崩溃、不卡死。
        advanceThroughMessage(engine)
        XCTAssertNotEqual(engine.phase, .awaitingMessage, "JP 路径应能正常确认消息")
    }

    /// M5.6 WP-2 验收⑤（互读冒烟，反方向）：ZH 构建存档 → JP 构建载入。
    /// .zh 引擎（挂中文 store）save 出的档：无 language 键、previewText 为 JP 叶码解码；
    /// 空库（JP 构建）引擎 load 后保持 .jp、cnPages 恒空、预览带现算可用，可继续推进。
    func testZHBuildSaveLoadsIntoJPBuildEngine() throws {
        let scn1 = try XCTUnwrap(GameData(extractedDir: extractedDir).scn(1))
        let msg = try XCTUnwrap(scn1.messages.first { !$0.segments.isEmpty && !$0.segments[0].lines.isEmpty })
        let cnText = "无意义的中文译文句子，用来验证 ZH 档在 JP 构建里不会漏字。"
        let zhGame = GameData(extractedDir: extractedDir,
                              translationStore: TranslationStore(map: ["1:\(msg.index)": cnText]))
        let jpGame = GameData(extractedDir: extractedDir,
                              translationStore: TranslationStore())
        let saveMgr = SaveManager(saveDirectory: tempDir)

        // ZH 构建（语言由 BuildLanguage.current 种为 .zh；测试进程用 setLanguage 等效装配）。
        let zhEngine = ShizukuEngine(game: zhGame, saveManager: saveMgr); zhEngine.skip = true
        zhEngine.setLanguage(.zh)
        zhEngine.previewMessage(scn: 1, msg: msg.index)
        XCTAssertEqual(zhEngine.phase, .awaitingMessage)
        XCTAssertTrue(zhEngine.cnActive, "ZH 引擎应挂上 cnSlices")

        let saved = try saveMgr.save(slot: 5, engine: zhEngine)
        XCTAssertNil(saved.language, "ZH 构建的档同样不得写 language 键")
        XCTAssertFalse(saved.previewText.contains("无意义"), "预览带必须走 JP 叶码解码")

        // JP 构建载入：保持 .jp、空 cnPages，不崩溃。
        let jpEngine = ShizukuEngine(game: jpGame, saveManager: saveMgr); jpEngine.skip = true
        XCTAssertEqual(jpEngine.language, BuildLanguage.current,
                       "引擎语言必须由构建期常量种入（测试进程即 .jp）")
        try saveMgr.load(slot: 5, into: jpEngine)
        XCTAssertEqual(jpEngine.language, .jp, "JP 构建不被 ZH 档动摇")
        XCTAssertTrue(jpEngine.cnSlices.isEmpty)
        XCTAssertFalse(jpEngine.cnActive)
        XCTAssertEqual(jpEngine.currentMsg?.index, msg.index)
        // 预览带（渲染期现算）走 JP 路径且有字。
        let preview = try XCTUnwrap(jpEngine.jpPreviewText(scn: 1, msg: msg.index))
        XCTAssertFalse(preview.isEmpty, "JP 现算预览带应非空")
        advanceThroughMessage(jpEngine)
        XCTAssertNotEqual(jpEngine.phase, .awaitingMessage, "JP 载入 ZH 档后应能正常推进")
    }
}

