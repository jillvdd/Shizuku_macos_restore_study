//
//  TranslationStoreTests.swift
//  ShizukuCore
//
//  Minimal verification that TranslationStore:
//   - loads from JSON and serves (scn,msg)->CN lookups (hit path)
//   - returns nil for missing keys (fallback path = JP unchanged)
//   - returns empty store when file is absent (default behavior unchanged)
//   - integrates with GameData + Engine (CN hit / JP fallback both work end-to-end)
//

import XCTest
@testable import ShizukuCore
@testable import ShizukuEngine

final class TranslationStoreTests: XCTestCase {

    func testHitAndFallback() {
        let store = TranslationStore(map: ["1:5": "然后不知在某个不经意的瞬间，我察觉到这个无聊的世界已经失去了色彩和声音。"])
        // Hit: (1,5) is in the store -> returns CN text
        XCTAssertEqual(store.text(scn: 1, msg: 5), "然后不知在某个不经意的瞬间，我察觉到这个无聊的世界已经失去了色彩和声音。")
        // Fallback: (1,0) not in store -> nil (caller falls through to JP pathway)
        XCTAssertNil(store.text(scn: 1, msg: 0))
        XCTAssertNil(store.text(scn: 0, msg: 0))
    }

    func testLoadFromJSON() {
        let tmpDir = NSTemporaryDirectory()
        let path = tmpDir + "test_zh_text.json"
        let json = """
        {"1:5": "然后不知在某个不经意的瞬间，我察觉到这个无聊的世界已经失去了色彩和声音。", "1:0": "测试"}
        """
        try? json.write(toFile: path, atomically: true, encoding: .utf8)

        let store = TranslationStore.load(from: path)
        XCTAssertEqual(store.count, 2)
        XCTAssertEqual(store.text(scn: 1, msg: 5), "然后不知在某个不经意的瞬间，我察觉到这个无聊的世界已经失去了色彩和声音。")
        XCTAssertEqual(store.text(scn: 1, msg: 0), "测试")
        XCTAssertNil(store.text(scn: 2, msg: 0))
    }

    func testMissingFileReturnsEmptyStore() {
        let store = TranslationStore.load(from: "/tmp/__nonexistent_zh_text.json")
        XCTAssertEqual(store.count, 0)
        XCTAssertNil(store.text(scn: 1, msg: 5))
    }

    func testIntegrationWithGameDataAndEngine() {
        let extracted = "/Users/abc/Documents/shizuku_macos_experience/research/extracted"
        let anchor = "然后不知在某个不经意的瞬间，我察觉到这个无聊的世界已经失去了色彩和声音。"

        // --- Explicit empty store: nil -> JP fallback (behavior unchanged) ---
        let game1 = GameData(extractedDir: extracted, translationStore: TranslationStore())
        let engine1 = ShizukuEngine(game: game1); engine1.skip = true
        engine1.setLanguage(.zh)
        XCTAssertNil(engine1.translatedText(scn: 1, msg: 5), "empty store -> nil (JP fallback)")

        // --- With store containing anchor: CN hit for msg5, fallback for msg0 ---
        let store = TranslationStore(map: ["1:5": anchor])
        let game2 = GameData(extractedDir: extracted, translationStore: store)
        let engine2 = ShizukuEngine(game: game2); engine2.skip = true
        // M5.6 WP-1: `.jp` never sees the store, no matter what it contains…
        XCTAssertNil(engine2.translatedText(scn: 1, msg: 5), "jp language gates the store out")
        engine2.setLanguage(.zh)
        // --- …and in `.zh` a hit serves msg5, a miss falls back for msg0 ---
        XCTAssertEqual(engine2.translatedText(scn: 1, msg: 5), anchor, "msg5 should hit CN translation")
        XCTAssertNil(engine2.translatedText(scn: 1, msg: 0), "msg0 not in store -> nil (JP fallback)")

        // --- Default init auto-loads from research/recovery/text/zh_text.json ---
        let game3 = GameData(extractedDir: extracted)
        let engine3 = ShizukuEngine(game: game3); engine3.skip = true
        engine3.setLanguage(.zh)
        XCTAssertEqual(engine3.translatedText(scn: 1, msg: 5), anchor, "default init should auto-load zh_text.json")
    }

    // MARK: - WP-9: CN slices ride the JP beat clock (no whole-page, no JP leak)

    func testSliceChineseProportional() {
        let text = String(repeating: "字", count: 50)
        let slices = ShizukuEngine.sliceChinese(text, perSegmentGlyphCounts: [40, 0, 60])
        XCTAssertEqual(slices.count, 3)
        XCTAssertEqual(slices[1], "", "command-only beats carry no text")
        XCTAssertEqual(slices.joined(), text, "切片拼回必须等于完整译文")
        XCTAssertEqual(ShizukuEngine.sliceChinese("多行\n译文", perSegmentGlyphCounts: [10]), ["多行译文"])
        XCTAssertTrue(ShizukuEngine.sliceChinese("", perSegmentGlyphCounts: [10]).isEmpty,
                      "空译文不挂 CN，走 JP 路径")
        XCTAssertTrue(ShizukuEngine.sliceChinese("译文", perSegmentGlyphCounts: [0, 0]).isEmpty)
    }

    func testSliceChineseSnapsToSentenceEnders() {
        // 每句 10 字；日文三拍比例切点会落在 8/16/24 字（半句中），必须吸附到句尾。
        let text = "第一句话十个字。第二句话十个字！第三句话十个字？"
        let slices = ShizukuEngine.sliceChinese(text, perSegmentGlyphCounts: [40, 40, 40])
        XCTAssertEqual(slices.count, 3)
        XCTAssertEqual(slices.joined(), text)
        for s in slices.dropLast() {
            let last = s.last!
            XCTAssertTrue("。！？".contains(last), "停顿点必须落在句尾，实际切出：“\(s)”")
        }
        // 引用尾符号并入句尾：「……」整体算一句的结束。
        let quoted = "她说「早上好。」然后走了。后面还有很长的一段话。"
        let q = ShizukuEngine.sliceChinese(quoted, perSegmentGlyphCounts: [30, 70])
        XCTAssertEqual(q.joined(), quoted)
        XCTAssertTrue("。」".contains(q[0].last!), "切点应停在句子（含尾括号）结束处：\(q[0])")
        // 无标点时退回整段（后续拍无新文本），不崩溃、拼接完整。
        let noPunct = ShizukuEngine.sliceChinese(String(repeating: "字", count: 30),
                                                 perSegmentGlyphCounts: [10, 10, 10])
        XCTAssertEqual(noPunct.joined(), String(repeating: "字", count: 30))
    }

    func testSliceChineseCorpusPausesLandOnEnders() throws {
        let extracted = "/Users/abc/Documents/shizuku_macos_experience/research/extracted"
        let game = GameData(extractedDir: extracted)
        XCTAssertGreaterThan(game.translationStore.count, 3000, "zh_text.json 应已挂载全量语料")
        let enders: Set<Character> = ["。", "．", "！", "？", "…", "!", "?",
                                      "」", "』", "）", "》", "\"", "'"]
        var violations: [String] = []
        var checked = 0
        for (scnIdx, scn) in game.scns.enumerated() {
            for msg in scn.messages {
                guard let text = game.translationStore.text(scn: scnIdx, msg: msg.index),
                      !text.isEmpty else { continue }
                let counts = msg.segments.map { ShizukuEngine.glyphCount($0.lines) }
                let slices = ShizukuEngine.sliceChinese(text, perSegmentGlyphCounts: counts)
                guard slices.count >= 2 else { continue }
                checked += 1
                for (i, s) in slices.enumerated() where !s.isEmpty {
                    // 后面还有文本拍时，本拍停顿点必须落在句读上
                    guard slices[(i + 1)...].contains(where: { !$0.isEmpty }) else { break }
                    if !enders.contains(s.last!) {
                        if violations.count < 8 {
                            violations.append("\(scnIdx):\(msg.index) → “\(s.suffix(6))”")
                        }
                    }
                }
            }
        }
        XCTAssertGreaterThan(checked, 2000)
        XCTAssertTrue(violations.isEmpty, "半句停顿泄漏：\(violations)")
    }

    func testCNAutoSkipsSilentBeats() throws {
        let extracted = "/Users/abc/Documents/shizuku_macos_experience/research/extracted"
        let game = GameData(extractedDir: extracted)
        var probed = 0
        outer: for (scnIdx, scn) in game.scns.enumerated() {
            for msg in scn.messages {
                // Action-free segments keep the click accounting exact (no transition
                // can swallow a click), so the beat count is directly observable.
                guard !msg.segments.isEmpty,
                      msg.segments.allSatisfy({ $0.actions.isEmpty }),
                      let text = game.translationStore.text(scn: scnIdx, msg: msg.index),
                      !text.isEmpty else { continue }
                let counts = msg.segments.map { ShizukuEngine.glyphCount($0.lines) }
                let slices = ShizukuEngine.sliceChinese(text, perSegmentGlyphCounts: counts)
                let stops = msg.segments.enumerated().filter { i, seg in
                    seg.pause == .pageBreak || (i < slices.count && !slices[i].isEmpty)
                }.count
                let silent = msg.segments.count - stops
                guard silent >= 3, stops >= 2 else { continue }
                probed += 1
                // A stop beat costs one click to finish its JP-paced reveal (when the beat
                // has glyphs) plus one to advance past it.
                let expected = msg.segments.enumerated().reduce(0) { acc, pair in
                    let (i, seg) = pair
                    guard seg.pause == .pageBreak || (i < slices.count && !slices[i].isEmpty) else { return acc }
                    return acc + 1 + (counts[i] > 0 ? 1 : 0)
                }
                let engine = ShizukuEngine(game: game)
                engine.setLanguage(.zh)
                engine.skip = false
                engine.previewMessage(scn: scnIdx, msg: msg.index)
                var clicks = 0
                while engine.phase == .awaitingMessage, clicks < 400 {
                    clicks += 1
                    engine.advanceMessage()
                }
                XCTAssertEqual(clicks, expected,
                               "\(scnIdx):\(msg.index) 应只在有可见变化的拍上等待（静默拍 \(silent)）")
                if probed >= 6 { break outer }
            }
        }
        XCTAssertGreaterThan(probed, 0, "语料里应能找到含静默拍的无动作消息")
    }

    func testCNBeatRevealAndFinish() throws {
        let extracted = "/Users/abc/Documents/shizuku_macos_experience/research/extracted"
        let cnText = String(repeating: "中", count: 60)
        let scn1 = try XCTUnwrap(GameData(extractedDir: extracted).scn(1))
        let msg = try XCTUnwrap(scn1.messages.first { m in
            m.segments.filter { ShizukuEngine.glyphCount($0.lines) > 0 }.count >= 2
        }, "SCN001 应有 ≥2 个文本拍的消息")
        let game = GameData(extractedDir: extracted,
                            translationStore: TranslationStore(map: ["1:\(msg.index)": cnText]))
        let engine = ShizukuEngine(game: game)
        engine.setLanguage(.zh)
        engine.skip = false
        engine.previewMessage(scn: 1, msg: msg.index)
        XCTAssertTrue(engine.cnActive)
        XCTAssertEqual(engine.cnSlices.count, msg.segments.count)
        let firstBeat = engine.currentSegmentIndex
        XCTAssertTrue(engine.cnDisplayedText.isEmpty, "开拍瞬间一个字都不该有")

        // 逐字：显影时钟走几步，CN 屏上文本应恰好是首拍切片的前缀。
        engine.revealGlyphs(5)
        XCTAssertEqual(engine.cnDisplayedText, String(engine.cnSlices[firstBeat].prefix(5)))

        engine.revealAll()
        XCTAssertEqual(engine.cnDisplayedText, engine.cnSlices[firstBeat])

        // 按拍推进：点一次合入一拍，直到消息收尾；收尾后 CN 层必须清空（不留残屏、不露日文）。
        var guardCount = 0
        var sawCommit = false
        while engine.phase == .awaitingMessage, guardCount < 200 {
            guardCount += 1
            let before = engine.cnCommitted
            engine.advanceMessage()
            if engine.cnCommitted.count > before.count { sawCommit = true }
            engine.revealAll()
        }
        XCTAssertFalse(engine.cnActive, "消息结束后 cnSlices 必须清空")
        XCTAssertTrue(engine.cnCommitted.isEmpty)
        XCTAssertTrue(sawCommit || guardCount <= 1, "waitKey 拍应把中文合入正文")
    }
}
