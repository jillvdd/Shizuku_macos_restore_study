//
//  SaveManager.swift
//  ShizukuEngine
//
//  Native persistent save/load system (SaveManager) and ending system (ShizukuEnding).
//  Serializes engine state to JSON files in ~/Library/Application Support/Shizuku/saves/
//  or a custom directory for testing.
//

import Foundation
import ShizukuCore

public enum ShizukuEnding: Int, CaseIterable, Codable, CustomStringConvertible {
    case graduation = 0       // 卒業式
    case mizuhoBad1 = 1       // 瑞穂 BAD 1
    case destruction = 2      // 破壊
    case toaster = 3          // トースター
    case saoriHappy = 4       // 沙織 HAPPY
    case saoriBad = 5         // 沙織 BAD
    case mizuhoHappy = 6      // 瑞穂 HAPPY
    case mizuhoBad2 = 7       // 瑞穂 BAD 2
    case trueEnding = 8       // True
    case rurikoHappy = 9      // 瑠璃子 HAPPY
    case ohtaSan = 10         // 太田さん
    case ijigen = 11          // 異次元
    case ijigenBad = 12       // 異次元 BAD

    public var description: String { titleJP }

    public var titleJP: String {
        switch self {
        case .graduation: return "卒業式"
        case .mizuhoBad1: return "瑞穂 BAD 1"
        case .destruction: return "破壊"
        case .toaster: return "トースター"
        case .saoriHappy: return "沙織 HAPPY"
        case .saoriBad: return "沙織 BAD"
        case .mizuhoHappy: return "瑞穂 HAPPY"
        case .mizuhoBad2: return "瑞穂 BAD 2"
        case .trueEnding: return "True"
        case .rurikoHappy: return "瑠璃子 HAPPY"
        case .ohtaSan: return "太田さん"
        case .ijigen: return "異次元"
        case .ijigenBad: return "異次元 BAD"
        }
    }

    /// ZH build title for the endings list (WP-9). Character names follow the
    /// 汉化版 conventions (瑞穂→瑞穗, 沙織→沙织, 瑠璃子→琉璃子); HAPPY/BAD are
    /// rendered as the native Chinese reading rather than kept as English tokens.
    public var titleZH: String {
        switch self {
        case .graduation: return "毕业典礼"
        case .mizuhoBad1: return "瑞穗 坏结局 1"
        case .destruction: return "破坏"
        case .toaster: return "烤面包机"
        case .saoriHappy: return "沙织 好结局"
        case .saoriBad: return "沙织 坏结局"
        case .mizuhoHappy: return "瑞穗 好结局"
        case .mizuhoBad2: return "瑞穗 坏结局 2"
        case .trueEnding: return "真结局"
        case .rurikoHappy: return "琉璃子 好结局"
        case .ohtaSan: return "太田先生"
        case .ijigen: return "异次元"
        case .ijigenBad: return "异次元 坏结局"
        }
    }

    public var isGoodEnding: Bool {
        return self == .saoriHappy || self == .mizuhoHappy || self == .trueEnding || self == .rurikoHappy
    }
}

public struct GlobalSystemData: Codable, Equatable {
    public var clearedEndings: Set<Int> = []
    public var persistentFlags: [Int: UInt8] = [:]
    /// Legacy display-language preference. M5.6 WP-2 turned language into a build-time
    /// constant (`BuildLanguage.current`), so nothing reads or writes this anymore; the
    /// field stays as an `Optional` Codable slot purely so pre-existing `system.json`
    /// files decode, and old values are ignored on load. `nil` => never set.
    public var language: GameLanguage?
    /// Skip settings (item 8), persisted across sessions. `nil` => default (both off).
    public var fastWhenSeen: Bool?
    public var forceSkip: Bool?
    /// Key code of the fast-forward/skip hotkey (item 8). `nil` => Tab (48).
    public var skipHotkey: UInt16?
    /// 早送り speed tier — 0 慢 / 1 中 / 2 快. `nil` => 1 (中, the pace we shipped).
    public var fastForwardSpeed: Int?
    /// `lvns->enable_effect`. `nil` => effects on, matching the shipped original.
    public var effectsEnabled: Bool?
    /// Per-scenario read high-water — the original's `seen_flag[205]`, which lives in
    /// the **system** file (`sizuku_file.c:70,129`) and is therefore shared by every
    /// save slot and survives relaunches. `nil` => nothing read yet.
    public var seenHighWater: [Int: Int]?

    public init(clearedEndings: Set<Int> = [], persistentFlags: [Int: UInt8] = [:], language: GameLanguage? = nil,
                fastWhenSeen: Bool? = nil, forceSkip: Bool? = nil, skipHotkey: UInt16? = nil,
                seenHighWater: [Int: Int]? = nil, effectsEnabled: Bool? = nil, fastForwardSpeed: Int? = nil) {
        self.clearedEndings = clearedEndings
        self.persistentFlags = persistentFlags
        self.language = language
        self.fastWhenSeen = fastWhenSeen
        self.forceSkip = forceSkip
        self.skipHotkey = skipHotkey
        self.seenHighWater = seenHighWater
        self.effectsEnabled = effectsEnabled
        self.fastForwardSpeed = fastForwardSpeed
    }
}

public struct SaveState: Codable, Equatable {
    public var version: Int = 1

    /// The save format this build writes.
    public static let currentVersion = 1
    /// Raised for a save claiming a newer format than this build understands;
    /// older drafts simply fail field decoding, which is already handled.
    public struct VersionTooNew: Error, Equatable { public let version: Int }

    static func checkVersion(_ data: Data, decoder: JSONDecoder) throws {
        struct Envelope: Decodable { let version: Int }
        if let env = try? decoder.decode(Envelope.self, from: data), env.version > currentVersion {
            throw VersionTooNew(version: env.version)
        }
    }

    public var slot: Int
    public var timestamp: Date
    public var previewText: String

    public var scnIndex: Int
    public var blockIndex: Int
    public var pc: Int
    public var flags: [UInt8]
    public var scene: Scene
    public var phase: ShizukuEngine.Phase
    public var currentMsgIndex: Int?
    /// Index of the displayed message segment (M4.4). Optional so saves written before
    /// message segmentation existed still decode; `nil` means "first segment".
    public var currentSegmentIndex: Int?
    public var currentPage: Int
    public var choices: [Choice]
    public var currentEnding: Int?
    public var backlog: [BacklogEntry] = []
    /// Legacy display-language-at-save-time field. Kept as `Optional` so older saves
    /// decode; `captureSaveState` no longer writes it and `restoreSaveState` ignores it
    /// (M5.6 WP-1 decoupling + WP-2 build-time language).
    public var language: GameLanguage?
    /// Per-scenario read-text high-water (item 8). Optional so older saves decode.
    public var seenHighWater: [Int: Int]?

    public init(
        version: Int = 1,
        slot: Int,
        timestamp: Date = Date(),
        previewText: String,
        scnIndex: Int,
        blockIndex: Int,
        pc: Int,
        flags: [UInt8],
        scene: Scene,
        phase: ShizukuEngine.Phase,
        currentMsgIndex: Int?,
        currentSegmentIndex: Int? = nil,
        currentPage: Int,
        choices: [Choice],
        currentEnding: Int?,
        backlog: [BacklogEntry] = [],
        language: GameLanguage? = nil,
        seenHighWater: [Int: Int]? = nil
    ) {
        self.version = version
        self.slot = slot
        self.timestamp = timestamp
        self.previewText = previewText
        self.scnIndex = scnIndex
        self.blockIndex = blockIndex
        self.pc = pc
        self.flags = flags
        self.scene = scene
        self.phase = phase
        self.currentMsgIndex = currentMsgIndex
        self.currentSegmentIndex = currentSegmentIndex
        self.currentPage = currentPage
        self.choices = choices
        self.currentEnding = currentEnding
        self.backlog = backlog
        self.language = language
        self.seenHighWater = seenHighWater
    }
}

public final class SaveManager {
    public let saveDirectory: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public static var defaultDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Shizuku/saves", isDirectory: true)
    }

    public init(saveDirectory: URL? = nil) {
        let dir = saveDirectory ?? SaveManager.defaultDirectory
        self.saveDirectory = dir
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601

        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
    }

    public func fileURL(for slot: Int) -> URL {
        if slot == 0 {
            return saveDirectory.appendingPathComponent("quicksave.json")
        } else {
            return saveDirectory.appendingPathComponent(String(format: "save_%02d.json", slot))
        }
    }

    public var systemFileURL: URL {
        saveDirectory.appendingPathComponent("system.json")
    }

    @discardableResult
    public func save(slot: Int, engine: ShizukuEngine, previewText: String? = nil) throws -> SaveState {
        let state = engine.captureSaveState(slot: slot, previewText: previewText)
        let data = try encoder.encode(state)
        try data.write(to: fileURL(for: slot), options: .atomic)
        return state
    }

    @discardableResult
    public func load(slot: Int, into engine: ShizukuEngine) throws -> SaveState {
        let url = fileURL(for: slot)
        let data = try Data(contentsOf: url)
        try SaveState.checkVersion(data, decoder: decoder)
        let state = try decoder.decode(SaveState.self, from: data)
        engine.restoreSaveState(state)
        return state
    }

    public func getSaveState(slot: Int) -> SaveState? {
        let url = fileURL(for: slot)
        guard let data = try? Data(contentsOf: url) else { return nil }
        guard (try? SaveState.checkVersion(data, decoder: decoder)) != nil else { return nil }
        return try? decoder.decode(SaveState.self, from: data)
    }

    public func listSaves() -> [Int: SaveState] {
        var result: [Int: SaveState] = [:]
        guard let files = try? FileManager.default.contentsOfDirectory(at: saveDirectory, includingPropertiesForKeys: nil) else {
            return [:]
        }
        for file in files {
            if file.pathExtension == "json" && file.lastPathComponent != "system.json" {
                if let data = try? Data(contentsOf: file),
                   (try? SaveState.checkVersion(data, decoder: decoder)) != nil,
                   let state = try? decoder.decode(SaveState.self, from: data) {
                    result[state.slot] = state
                }
            }
        }
        return result
    }

    public func delete(slot: Int) throws {
        let url = fileURL(for: slot)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    public func loadGlobalSystem() -> GlobalSystemData {
        guard let data = try? Data(contentsOf: systemFileURL),
              let sys = try? decoder.decode(GlobalSystemData.self, from: data) else {
            return GlobalSystemData()
        }
        return sys
    }

    public func saveGlobalSystem(_ data: GlobalSystemData) throws {
        let raw = try encoder.encode(data)
        try raw.write(to: systemFileURL, options: .atomic)
    }

    public func recordEnding(_ endingNo: Int, in engine: ShizukuEngine) {
        var sys = loadGlobalSystem()
        sys.clearedEndings.insert(endingNo)
        // Persist non-volatile system flags: 0 (ending record), 1 (雑シナリオ), 0x45, 0x46
        // — exactly the GBA port's SRAM set (`siori.c:50-87` persists flags[0],[1],[7],[8]).
        if engine.flags.count > 0 { sys.persistentFlags[0] = engine.flags[0] }
        if engine.flags.count > 1 { sys.persistentFlags[1] = engine.flags[1] }
        if engine.flags.count > 0x45 { sys.persistentFlags[0x45] = engine.flags[0x45] }
        if engine.flags.count > 0x46 { sys.persistentFlags[0x46] = engine.flags[0x46] }
        try? saveGlobalSystem(sys)
    }

    public func applyGlobalSystem(to engine: ShizukuEngine) {
        let sys = loadGlobalSystem()
        for (flagIdx, val) in sys.persistentFlags {
            if flagIdx < engine.flags.count {
                engine.flags[flagIdx] = val
            }
        }
        engine.seenHighWater = sys.seenHighWater ?? [:]
    }

    /// Write the read high-water back to the system file (original `seen_flag[]`).
    public func persistSeenHighWater(_ seenHighWater: [Int: Int]) {
        var sys = loadGlobalSystem()
        guard sys.seenHighWater != seenHighWater else { return }
        sys.seenHighWater = seenHighWater
        try? saveGlobalSystem(sys)
    }
}
