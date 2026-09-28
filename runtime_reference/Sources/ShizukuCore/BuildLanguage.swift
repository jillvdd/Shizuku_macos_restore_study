//
//  BuildLanguage.swift
//  ShizukuCore
//
//  The display language is a *build property*, not runtime state (M5.6 D1,
//  HANDOVER §38.0): the JP and ZH products ship as two separate bundles and
//  neither can switch language while running. This resolves the language baked
//  into the current build:
//
//    1. `$SHIZUKU_LANGUAGE` — test / `SHIZUKU_SHOT` harness override only.
//    2. Info.plist `SHIZUKU_LANGUAGE` — injected by package.sh for the ZH bundle.
//    3. `.jp` — the default; a bare `swift build`/`swift test`/`swift run` with
//       no plist key is always the Japanese product.
//
//  Deliberately no `system.json` read: the old runtime toggle persisted a user
//  preference that leaked across bundles (HANDOVER §38.1 A2). The
//  `GlobalSystemData.language` field stays Codable-only so older system files
//  keep decoding; nothing reads or writes it any more.
//

import Foundation

public enum BuildLanguage {
    /// The language this process was built/configured for.
    public static let current: GameLanguage = resolve(environment: ProcessInfo.processInfo.environment,
                                                      infoPlist: Bundle.main.infoDictionary)

    /// Pure resolution used by `current` — separated so tests can feed inputs.
    public static func resolve(environment: [String: String], infoPlist: [String: Any]?) -> GameLanguage {
        if let raw = environment["SHIZUKU_LANGUAGE"], let lang = GameLanguage(rawValue: raw.lowercased()) {
            return lang
        }
        if let raw = infoPlist?["SHIZUKU_LANGUAGE"] as? String,
           let lang = GameLanguage(rawValue: raw.lowercased()) {
            return lang
        }
        return .jp
    }
}
