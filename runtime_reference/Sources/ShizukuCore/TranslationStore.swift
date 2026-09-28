//
//  TranslationStore.swift
//  ShizukuCore
//
//  (scn,msg) -> Chinese text lookup table.
//
//  The CN engine replaces whole messages by (scn,msg) index at render time
//  (HANDOVER §13.1): translation is free-rewriting (45 JP chars -> 36 CN chars,
//  reordered), NOT a per-leaf glyph substitution. GlyphMap's "leaf->slot" interface
//  is therefore obsolete for translation; this store supersedes it.
//
//  The store is loaded from a JSON file (default: research/recovery/text/zh_text.json).
//  If the file is absent, the store is empty and all lookups fall back to the
//  existing JP pathway — i.e. default behavior is unchanged.
//

import Foundation

/// Display language for the text layer. `.jp` renders the native SCN leaf codes
/// through the bitmap font; `.zh` hot-mounts Chinese strings from the
/// `TranslationStore` over the message text when a translation exists.
public enum GameLanguage: String, Codable, CaseIterable, Sendable {
    case jp
    case zh

    public var displayName: String {
        switch self {
        case .jp: return "日本語"
        case .zh: return "中文"
        }
    }
}

/// Maps "scn:msg" keys to Chinese translation strings.
/// Loaded from JSON; absent file => empty store => JP fallback.
public struct TranslationStore: Sendable {
    private let map: [String: String]

    public init(map: [String: String] = [:]) {
        self.map = map
    }

    /// Number of entries loaded.
    public var count: Int { map.count }

    /// True when the store has usable text for a (scn,msg) pair.
    public func contains(scn: Int, msg: Int) -> Bool {
        guard let s = map["\(scn):\(msg)"] else { return false }
        return !s.isEmpty
    }

    /// Look up the Chinese text for a (scn,msg) pair. nil if absent.
    public func text(scn: Int, msg: Int) -> String? {
        let key = "\(scn):\(msg)"
        return map[key]
    }

    /// Load a TranslationStore from a JSON file of {"scn:msg": "中文", ...}.
    /// If the file doesn't exist or can't be parsed, returns an empty store.
    public static func load(from path: String) -> TranslationStore {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            return TranslationStore()
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
            return TranslationStore()
        }
        return TranslationStore(map: json)
    }

    /// Hot-mount search order for `zh_text.json`. The app bundle copies the file
    /// next to the game data (`<gamedata>/zh_text.json`); dev builds keep it under
    /// `research/recovery/text/`. First existing candidate wins.
    public static func candidatePaths(extractedDir: String) -> [String] {
        let dir = (extractedDir as NSString).standardizingPath
        var paths = [dir + "/zh_text.json"]
        // research/extracted -> research/recovery/text/zh_text.json (dev layout)
        let research = (dir as NSString).deletingLastPathComponent
        paths.append((research as NSString).appendingPathComponent("recovery/text/zh_text.json"))
        if let res = Bundle.main.resourcePath {
            paths.append(res + "/gamedata/zh_text.json")
            paths.append(res + "/zh_text.json")
        }
        return paths
    }

    /// Load the first existing `zh_text.json` from the candidate paths.
    /// Returns an empty store when none is present (JP fallback, no behavior change).
    public static func loadDefault(extractedDir: String) -> TranslationStore {
        let fm = FileManager.default
        for p in candidatePaths(extractedDir: extractedDir) where fm.fileExists(atPath: p) {
            let store = TranslationStore.load(from: p)
            if store.count > 0 { return store }
        }
        return TranslationStore()
    }
}
