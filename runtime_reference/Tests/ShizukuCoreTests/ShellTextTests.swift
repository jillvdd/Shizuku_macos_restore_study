//
//  ShellTextTests.swift
//  ShizukuCoreTests
//
//  M5.6 WP-7a: the shell string table is routed by build language. These tests
//  pin both halves of the contract — the JP tables must be the exact legacy
//  leaf codes / strings (防回归), and the ZH composer must actually render the
//  Chinese shell through the native font path.
//

import XCTest
@testable import ShizukuCore
@testable import ShizukuEngine
@testable import ShizukuRender

final class ShellTextTests: XCTestCase {
    var game: GameData!
    var tempDir: URL!

    override func setUpWithError() throws {
        let extracted = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("research/extracted")
        game = try XCTUnwrap(GameData(extractedDir: extracted.path))
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDir = tempDir { try? FileManager.default.removeItem(at: tempDir) }
    }

    private func hasCJK(_ s: String) -> Bool {
        s.unicodeScalars.contains { $0.value >= 0x4E00 && $0.value <= 0x9FFF }
    }

    // MARK: - JP 表 = 旧叶码逐字不变

    func testJPTablesAreTheLegacyLeafCodes() {
        XCTAssertEqual(ShellText.titleRows(.jp).map(\.leafCodes),
                       [MenuStrings.newGame, MenuStrings.continueGame, MenuStrings.recallMode,
                        MenuStrings.endingsList, MenuStrings.quit])
        XCTAssertEqual(ShellText.escRows(.jp).map(\.leafCodes), SceneComposer.escMenuItems)
        XCTAssertEqual(ShellText.confirmRows(.jp).map(\.leafCodes), [MenuStrings.yes, MenuStrings.no])
        XCTAssertEqual(ShellText.confirmQuestion(.jp).leafCodes, MenuStrings.confirmQuestion)
        XCTAssertEqual(ShellText.confirmHeader(.load, .jp).leafCodes, MenuStrings.confirmLoad)
        XCTAssertEqual(ShellText.confirmHeader(.save, .jp).leafCodes, MenuStrings.confirmSave)
        XCTAssertEqual(ShellText.confirmHeader(.end, .jp).leafCodes, MenuStrings.confirmEnd)
        XCTAssertEqual(ShellText.slotHeader(save: true, .jp), "セーブするしおりを選択してください")
        XCTAssertEqual(ShellText.slotHeader(save: false, .jp), "ロードするデータを選択してください")
        XCTAssertEqual(ShellText.slotLabel(slot: 0, .jp), "クイックセーブ")
        XCTAssertEqual(ShellText.slotLabel(slot: 3, .jp), "しおり　3")
        XCTAssertEqual(ShellText.slotEmpty(.jp), UIText.slotEmpty)
        XCTAssertEqual(ShellText.slotHint(.jp), UIText.slotHint)
        XCTAssertEqual(ShellText.slotDateFormat(.jp), "MM月dd日 HH時mm")
    }

    // MARK: - ZH 表 = 原生中文字符串

    func testZHTablesAreChineseNativeRows() {
        let esc = ShellText.escRows(.zh)
        XCTAssertEqual(esc.count, SceneComposer.escMenuRowCount)
        XCTAssertTrue(esc.allSatisfy { $0.nativeText.map(hasCJK) == true })
        XCTAssertEqual(esc.map(\.nativeText),
                       ["隐藏文字", "载入游戏", "存档游戏", "场景回想", "返回上一个选项", "结束游戏"])
        XCTAssertEqual(ShellText.titleRows(.zh).map(\.nativeText),
                       ["从头开始", "继续游戏", "回想模式", "结局列表", "结束游戏"])
        XCTAssertEqual(ShellText.confirmRows(.zh).map(\.nativeText), ["确定", "取消"])
        XCTAssertEqual(ShellText.confirmQuestion(.zh).nativeText, "确定吗？")
        XCTAssertEqual(ShellText.confirmHeader(.end, .zh).nativeText, "即将退出游戏。")
        XCTAssertEqual(ShellText.slotHeader(save: true, .zh), "请选择要存档的书签")
        XCTAssertEqual(ShellText.slotHeader(save: false, .zh), "请选择要载入的数据")
        XCTAssertEqual(ShellText.slotLabel(slot: 0, .zh), "快速存档")
        XCTAssertEqual(ShellText.slotLabel(slot: 4, .zh), "书签 4")
        XCTAssertEqual(ShellText.slotEmpty(.zh), "（空）")
        XCTAssertEqual(ShellText.slotDateFormat(.zh), "MM月dd日 HH:mm")
        XCTAssertTrue(ShellText.slotHint(.zh).contains("ESC"))
    }

    // MARK: - 渲染分流

    /// JP 的 drawEscMenu 必须与逐行 drawMenuLine 的旧画法逐像素一致（分流不引入回归）。
    func testJPEscMenuPixelIdenticalToLegacyLoop() {
        let composer = SceneComposer(game: game, scale: 2, language: .jp)
        var viaRows = composer.solidCanvas(r: 40, g: 60, b: 40)
        composer.drawEscMenu(into: &viaRows, selectedIndex: 2)
        var viaLoop = composer.solidCanvas(r: 40, g: 60, b: 40)
        viaLoop.scaleRGB(by: 11, of: 16)
        for (i, leaves) in SceneComposer.escMenuItems.enumerated() {
            composer.drawMenuLine(into: &viaLoop, leaves: leaves, line: 3 + i, selected: i == 2)
        }
        XCTAssertEqual(viaRows.pixels, viaLoop.pixels, "JP ESC 菜单必须逐像素不变")
    }

    /// ZH composer 渲染六行中文外壳 + 确认框 + 选择器：不崩、确有文字像素落墨。
    func testZHComposerRendersChineseShell() throws {
        let composer = SceneComposer(game: game, scale: 2, language: .zh)
        var esc = composer.solidCanvas(r: 40, g: 60, b: 40)
        composer.drawEscMenu(into: &esc, selectedIndex: 0)
        XCTAssertNotEqual(esc.pixels, composer.solidCanvas(r: 40, g: 60, b: 40).pixels,
                          "ZH ESC 菜单应落墨")

        var confirm = composer.solidCanvas(r: 20, g: 20, b: 20)
        composer.drawConfirmMenu(into: &confirm,
                                 header: ShellText.confirmHeader(.end, .zh), selectedIndex: 1)
        XCTAssertNotEqual(confirm.pixels, composer.solidCanvas(r: 20, g: 20, b: 20).pixels)

        let rows = [
            SceneComposer.SlotRow(labelText: ShellText.slotLabel(slot: 1, .zh),
                                  detail: "09月24日 22:45", preview: "铅笔芯咔咔地伸出，无意义地在笔记本上滑动。",
                                  previewIsCN: true, hasData: true),
            SceneComposer.SlotRow(labelText: ShellText.slotLabel(slot: 2, .zh),
                                  detail: ShellText.slotEmpty(.zh), preview: "", hasData: false),
        ]
        var picker = composer.solidCanvas(r: 30, g: 40, b: 30)
        composer.drawSlotPicker(into: &picker, header: ShellText.slotHeader(save: false, .zh),
                                rows: rows, selectedIndex: 0)
        XCTAssertNotEqual(picker.pixels, composer.solidCanvas(r: 30, g: 40, b: 30).pixels)
    }

    /// JP composer 默认语言 = 构建期常量（测试进程 .jp）；ZH 显式注入。
    func testComposerLanguageDefaultsToBuildLanguage() {
        XCTAssertEqual(SceneComposer(game: game, scale: 1).language, BuildLanguage.current)
        XCTAssertEqual(SceneComposer(game: game, scale: 1, language: .zh).language, .zh)
    }

    // MARK: - 命中框

    func testMenuRowRects() {
        let composer = SceneComposer(game: game, scale: 2, language: .zh)
        // JP 行：与旧 menuLineRect 完全一致。
        let jpRow = MenuRow.leaves(MenuStrings.newGame)
        XCTAssertEqual(composer.menuRowRect(jpRow, line: 7),
                       SceneComposer.menuLineRect(leaves: MenuStrings.newGame, line: 7))
        // ZH 行：宽度按字体测量、水平居中、同一行网格。
        let zhRow = MenuRow.native("结束游戏")
        let r = composer.menuRowRect(zhRow, line: 7)
        XCTAssertGreaterThan(r.width, 0)
        XCTAssertEqual(r.minY, CGFloat(7 * 32 + 8))
        XCTAssertEqual(r.height, 24)
        XCTAssertEqual(r.midX, 320, accuracy: 1, "原生行必须居中于 640 画布")
    }
}
