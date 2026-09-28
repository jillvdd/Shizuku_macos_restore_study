//
//  AudioControllerTests.swift
//  ShizukuCoreTests
//
//  Verification of AudioController:
//   - Resolving BGM and SFX file paths
//   - Playing and stopping BGM
//   - Triggering SFX
//   - BGM opcode integration in ShizukuEngine
//

import XCTest
@testable import ShizukuCore
@testable import ShizukuEngine

final class AudioControllerTests: XCTestCase {

    let extractedDir = "/Users/abc/Documents/shizuku_macos_experience/research/extracted"

    func testAudioResolution() {
        let audio = AudioController(baseDir: extractedDir)
        let bgm1 = audio.bgmURL(for: 1)
        XCTAssertNotNil(bgm1, "BGM track 1 (MUS01.OGG) should resolve")
        XCTAssertTrue(bgm1?.path.hasSuffix("MUS01.OGG") == true)

        let sfx1 = audio.sfxURL(for: "P001")
        XCTAssertNotNil(sfx1, "SFX P001.WAV should resolve")
        XCTAssertTrue(sfx1?.path.hasSuffix("P001.WAV") == true)
    }

    func testBGMPlaybackAndStop() {
        let audio = AudioController(baseDir: extractedDir)
        XCTAssertNil(audio.currentBgm)

        audio.playBGM(number: 2)
        XCTAssertEqual(audio.currentBgm, 2)

        audio.stopBGM()
        XCTAssertNil(audio.currentBgm)
    }

    func testEngineBgmOpcodeIntegration() {
        let game = GameData(extractedDir: extractedDir)
        let audio = AudioController(baseDir: extractedDir)
        let engine = ShizukuEngine(game: game, audio: audio); engine.skip = true

        engine.start(scn: 1, block: 1)
        // Stepping block 1: first opcode is 0x6e 0x02 (BGM track 2)
        let res = engine.step()
        XCTAssertEqual(res, .rendered)
        XCTAssertEqual(engine.scene.bgm, 2)
        XCTAssertEqual(audio.currentBgm, 2, "Engine opcode 0x6e must command AudioController to play BGM track 2")

        audio.stopBGM()
    }
}
