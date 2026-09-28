//
//  GameData.swift
//  ShizukuEngine
//
//  Loads the extracted game resources needed by the runtime:
//   - SCN scripts (parsed)
//   - CN KNJ font
//   - LFG images (lazy-decoded, keyed by filename)
//
//  CN汉化 ≠ 纯字库内容替换: SCN scripts are JP byte-identical; the CN engine resolves
//  leaf → slot via a runtime table (GlyphMap). We load cn_KNJ_ALL.KNJ for the glyphs and
//  optionally a leaf→slot table (cn_table.bin, 0x8000 UInt16 LE). Without the table the
//  map is identity (JP), so the pipeline stays runnable with the JP font.
//
//  Translation (HANDOVER §13.1): the CN engine replaces whole messages by (scn,msg).
//  An optional TranslationStore can be attached; when it has a translation for a given
//  (scn,msg) the engine uses it, otherwise the existing JP pathway is unchanged.
//

import Foundation
import ShizukuCore

public final class GameData {
    public let scns: [ScnScript]          // index 0 -> SCN000, index 1 -> SCN001, ...
    public let font: KnjFont
    public var cnFont: KnjFont { font }   // backwards-compatible alias
    public let cnMap: GlyphMap
    public let leafCodec: LeafCodec       // Unicode -> Leaf codes for UI dot-matrix text
    public let assetDir: String           // extracted dir; LFG resolved here
    public let translationStore: TranslationStore  // optional (scn,msg)->CN text; nil = JP fallback

    /// WP-11: the original CN patch dot-matrix font, hot-mounted lazily. Only ZH
    /// render paths touch it, so a JP build never pays the load (and never ships
    /// the files — package.sh keeps them out of the JP bundle).
    public lazy var cnDotFont: CnDotFont? = CnDotFont.loadDefault(extractedDir: assetDir)

    private var imageCache: [String: (RGBA: [UInt8], w: Int, h: Int)] = [:]

    public init(extractedDir: String, scnCount: Int = 197, translationStore: TranslationStore? = nil) {
        self.assetDir = extractedDir
        self.translationStore = translationStore ?? GameData.loadTranslationStore(extractedDir: extractedDir)
        var arr: [ScnScript] = []
        for i in 0..<scnCount {
            let p = String(format: "%@/SCN%03d.DAT", extractedDir, i)
            if let d = try? Data(contentsOf: URL(fileURLWithPath: p)) {
                arr.append(Scn.parse([UInt8](d), fileIndex: i))
            } else {
                arr.append(Scn.parse([], fileIndex: i))
            }
        }
        self.scns = arr
        let jpFontPath = extractedDir + "/KNJ_ALL.KNJ"
        let fontPath = FileManager.default.fileExists(atPath: jpFontPath) ? jpFontPath : (extractedDir + "/cn_KNJ_ALL.KNJ")
        // A missing font degrades to zero glyphs (renderer draws nothing); the app
        // layer's missing-data NSAlert is the intended exit path, so never trap here.
        self.font = KnjFont(path: fontPath) ?? KnjFont(data: [])
        self.cnMap = GameData.loadGlyphMap(extractedDir: extractedDir)
        // sizfont.tbl (EUC-JP pairs, entry index == leaf code) drives the
        // Unicode -> Leaf encoder used by all dot-matrix UI text.
        let tblPath = extractedDir + "/sizfont.tbl"
        if let tbl = try? Data(contentsOf: URL(fileURLWithPath: tblPath)) {
            self.leafCodec = LeafCodec(table: tbl)
        } else {
            self.leafCodec = .empty
        }
    }

    /// Load the leaf→slot table (cn_table.bin, 0x8000 UInt16 LE) if present, else identity.
    private static func loadGlyphMap(extractedDir: String) -> GlyphMap {
        let candidates = ["cn_table.bin", "leaf_table.bin", "cn_map.bin"]
        for c in candidates {
            let p = extractedDir + "/" + c
            if let d = try? Data(contentsOf: URL(fileURLWithPath: p)), d.count >= 2 {
                return GlyphMap.from(raw: d)
            }
        }
        return GlyphMap()
    }

    /// Load the (scn,msg)->CN translation store from the hot-mount candidate paths
    /// (app-bundle gamedata first, then the dev `research/recovery/text/` layout).
    /// Absent file => empty store => JP fallback, no behavior change.
    private static func loadTranslationStore(extractedDir: String) -> TranslationStore {
        return TranslationStore.loadDefault(extractedDir: extractedDir)
    }

    /// Slot for an SCN leaf code, routed through the CN leaf→slot map (identity if none).
    public func textSlot(forLeaf leaf: Int) -> Int {
        return cnMap.slot(forLeaf: leaf)
    }

    public func scn(_ index: Int) -> ScnScript? {
        return index >= 0 && index < scns.count ? scns[index] : nil
    }

    /// Resolve a raw LFG filename (e.g. "MAX_S01.LFG") to RGBA; nil if absent/bad.
    /// Names in the LEAFPACK table are padded with spaces (e.g. "MAX_S01  LFG"); normalize.
    /// Tolerates callers that omit the extension ("MAX_S01") by trying ".LFG".
    ///
    /// `paletteOverride` is the original's `SizukuLoadBG` colour substitution, so one plate
    /// can serve its day / dusk / night variants — it is part of the cache key.
    public func image(name rawName: String,
                      paletteOverride: PaletteOverride? = nil) -> (RGBA: [UInt8], w: Int, h: Int)? {
        let norm = GameData.normalizeName(rawName)
        let key = norm + (paletteOverride.map { "|pal\($0.start)-\($0.rgb)" } ?? "")
        if let c = imageCache[key] { return c }
        let candidates = norm.contains(".") ? [norm] : [norm, norm + ".LFG"]
        for cand in candidates {
            let path = assetDir + "/" + cand
            if let d = try? Data(contentsOf: URL(fileURLWithPath: path)),
               let (rgba, w, h) = Lfg.decode([UInt8](d), paletteOverride: paletteOverride) {
                let result = (rgba, w, h)
                imageCache[key] = result
                if paletteOverride == nil { imageCache[cand] = result }
                return result
            }
        }
        return nil
    }

    /// Normalize an 8.3 LEAFPACK name (may have interior spaces, e.g. "MAX_S01  LFG")
    /// into "MAX_S01.LFG". Also accepts already-normalized "MAX_S01.LFG".
    static func normalizeName(_ raw: String) -> String {
        // Strip spaces before the extension, collapse any spaces.
        var s = raw.trimmingCharacters(in: .whitespaces)
        if !s.contains(".") {
            // Form "MAX_S01  LFG" -> take up to first run of spaces as stem, rest as ext.
            if let dotSpace = s.range(of: "  ") {
                let stem = String(s[..<dotSpace.lowerBound])
                let ext = s[dotSpace.lowerBound...].trimmingCharacters(in: .whitespaces)
                s = stem + "." + ext
            }
        }
        return s
    }

    /// BG background from opcode 0x0a arg (decimal %02d).
    public func bgImage(num: Int) -> (RGBA: [UInt8], w: Int, h: Int)? {
        return image(name: String(format: "MAX_S%02d", num))
    }

    /// HBG from opcode 0x16 arg (decimal %02d).
    public func hbgImage(num: Int) -> (RGBA: [UInt8], w: Int, h: Int)? {
        return image(name: String(format: "HVS%02d", num))
    }

    /// Portrait from opcode 0x22/0x24 arg (hex %02x).
    public func chrImage(num: Int) -> (RGBA: [UInt8], w: Int, h: Int)? {
        return image(name: String(format: "MAX_C%02X", num))
    }
}

/// One event image (CG) the scripts put on screen, with every scenario that shows it.
public struct EventImage {
    public let name: String
    public let scns: [Int]
}

extension GameData {
    /// Family order the 回想モード gallery lists images in. Only illustration CGs:
    /// `'V'`→VIS and `'H'`→HVS (the script opcode comment calls it "h-scene CG").
    /// MAX_S is *not* here — `'B'`/`'E'`/`'S'` and event `0x0a` all write `MAX_S%02d`
    /// into the background slot, i.e. they are scene plates, not drawings. A CG may
    /// legitimately appear in several scenarios (branches reuse them), so reuse is not
    /// a criterion; only the opcode that loads the image is.
    private static let eventImageFamilies = ["VIS", "HVS"]

    /// Every VIS / HVS illustration an actual scenario script displays, ordered by
    /// family then number, and restricted to files that exist on disk. The gallery
    /// unlocks per scenario, so each entry keeps the scenarios referencing it — which is
    /// also why this walks the parsed scripts rather than the asset directory.
    public func eventImages() -> [EventImage] {
        var owners: [String: Set<Int>] = [:]
        for scn in 0..<scns.count {
            guard let s = self.scn(scn) else { continue }
            for m in s.messages {
                for seg in m.segments {
                    for act in seg.actions {
                        switch act {
                        case .visual(let name, _, _, _), .hVisual(let name, _, _):
                            owners[name, default: []].insert(scn)
                        default:
                            break
                        }
                    }
                }
            }
            for blk in s.blocks {
                for ev in blk.events {
                    // 0x16 = HBG HVS%02d, the event-form of `'H'`. `0x0a` is the
                    // event-form of `'B'` (MAX_S background) and stays out.
                    guard ev.opcode == 0x16, let a = ev.args.first else { continue }
                    owners[String(format: "HVS%02d", a), default: []].insert(scn)
                }
            }
        }
        let present = owners.keys.filter { hasImage(named: $0) }
        return present.sorted { a, b in
            let (ka, kb) = (Self.familyOrder(a), Self.familyOrder(b))
            return ka == kb ? a.localizedStandardCompare(b) == .orderedAscending : ka < kb
        }.map { EventImage(name: $0, scns: (owners[$0] ?? []).sorted()) }
    }

    private static func familyOrder(_ name: String) -> Int {
        eventImageFamilies.firstIndex(where: { name.hasPrefix($0) }) ?? eventImageFamilies.count
    }

    /// Whether an LFG for this name was unpacked into the asset dir (no decode).
    public func hasImage(named rawName: String) -> Bool {
        let norm = GameData.normalizeName(rawName)
        for cand in norm.contains(".") ? [norm] : [norm, norm + ".LFG"] {
            if FileManager.default.fileExists(atPath: assetDir + "/" + cand) { return true }
        }
        return false
    }
}
