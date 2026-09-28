//
//  BuildLanguageTests.swift
//  ShizukuCoreTests
//
//  M5.6 WP-2: display language is a build-time constant. Verify the
//  resolution precedence (env > Info.plist > .jp default) and that a fresh
//  engine seeds itself from it instead of system.json.
//

import XCTest
@testable import ShizukuCore
@testable import ShizukuEngine

final class BuildLanguageTests: XCTestCase {

    func testResolveDefaultsToJP() {
        XCTAssertEqual(BuildLanguage.resolve(environment: [:], infoPlist: nil), .jp)
        XCTAssertEqual(BuildLanguage.resolve(environment: [:], infoPlist: ["CFBundleName": "Shizuku"]), .jp)
    }

    func testResolveFromInfoPlist() {
        XCTAssertEqual(BuildLanguage.resolve(environment: [:], infoPlist: ["SHIZUKU_LANGUAGE": "zh"]), .zh)
        XCTAssertEqual(BuildLanguage.resolve(environment: [:], infoPlist: ["SHIZUKU_LANGUAGE": "ZH"]), .zh,
                       "plist 值大小写不敏感")
        XCTAssertEqual(BuildLanguage.resolve(environment: [:], infoPlist: ["SHIZUKU_LANGUAGE": "jp"]), .jp)
    }

    func testEnvironmentOverridesInfoPlist() {
        // package.sh 的 ZH bundle 注入 plist zh；测试/SHIZUKU_SHOT 用环境变量覆盖。
        XCTAssertEqual(BuildLanguage.resolve(environment: ["SHIZUKU_LANGUAGE": "jp"],
                                            infoPlist: ["SHIZUKU_LANGUAGE": "zh"]), .jp)
        XCTAssertEqual(BuildLanguage.resolve(environment: ["SHIZUKU_LANGUAGE": "zh"],
                                            infoPlist: ["SHIZUKU_LANGUAGE": "jp"]), .zh)
    }

    func testGarbageValuesFallBackToJP() {
        for raw in ["", "en", "Chinese", "日本語", "zh_CN"] {
            XCTAssertEqual(BuildLanguage.resolve(environment: ["SHIZUKU_LANGUAGE": raw], infoPlist: nil), .jp,
                             "非法值 \(raw) 必须回落 .jp")
        }
        XCTAssertEqual(BuildLanguage.resolve(environment: [:],
                                            infoPlist: ["SHIZUKU_LANGUAGE": 42]), .jp,
                       "非字符串 plist 值必须回落 .jp")
    }

    func testCurrentResolvesToJPUnderTestProcess() {
        // swift test 进程既无 SHIZUKU_LANGUAGE 环境变量也无对应 plist 键。
        XCTAssertNil(ProcessInfo.processInfo.environment["SHIZUKU_LANGUAGE"])
        XCTAssertEqual(BuildLanguage.current, .jp)
    }

    func testNewEngineSeedsFromBuildLanguage() throws {
        let extracted = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("research/extracted")
        let game: GameData
        do {
            game = try GameData(extractedDir: extracted.path)
        } catch {
            throw XCTSkip("research/extracted 不可用: \(error)")
        }
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let engine = ShizukuEngine(game: game, saveManager: SaveManager(saveDirectory: tempDir))
        XCTAssertEqual(engine.language, BuildLanguage.current,
                       "引擎启动语言 = 构建期常量，不再读 system.json")
    }
}
