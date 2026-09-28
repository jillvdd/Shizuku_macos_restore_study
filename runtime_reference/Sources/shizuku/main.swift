//
//  main.swift — shizuku (headless CLI + engine driver)
//
//  Loads resources, runs the engine over a script, and exports rendered frames to
//  PNG. Run from the repo root:
//      swift run --package-path ShizukuRuntime shizuku [extractedDir] [-scn N] [-blk N] [-max N]
//
//  Env knobs:
//      SHIZUKU_DUMP_SEGMENTS=1   dump parsed inline actions + decoded text
//      SHIZUKU_DUMP_GLYPH=1      dump raw 24x24 glyph bitmaps
//      SHIZUKU_DUMP_LEAF=1       dump leaf codes of each displayed message
//      SHIZUKU_DUMP_TRANSITIONS=1  4-frame sheet per LvnsClear/LvnsDisp effect -> /tmp/shizuku_shots
//      SHIZUKU_DUMP_VIS=1      decode every VIS plate + print its content bounding box
//

import Foundation
import ShizukuCore
import ShizukuEngine
import ShizukuRender

@main
struct ShizukuCLI {
    static func main() {
        let args = CommandLine.arguments
        var root = "."
        var scnStart = 1
        var blkStart = 1
        var maxFrames = 60
        var scale = 1
        var enableAudio = false
        var traceFlow = false
        var i = 1
        while i < args.count {
            switch args[i] {
            case "-scn": i += 1; scnStart = Int(args[i]) ?? 1
            case "-blk": i += 1; blkStart = Int(args[i]) ?? 1
            case "-max": i += 1; maxFrames = Int(args[i]) ?? 60
            case "-scale": i += 1; scale = Int(args[i]) ?? 1
            case "-audio": enableAudio = true
            case "-trace": traceFlow = true
            default:
                if root == "." { root = args[i] }
            }
            i += 1
        }
        let extracted = root + "/research/extracted"
        let game = GameData(extractedDir: extracted)
        let audio = enableAudio ? AudioController(baseDir: extracted) : nil
        let engine = ShizukuEngine(game: game, audio: audio)

        if let s1 = game.scn(1) {
            print("SCN001: \(s1.blocks.count) blocks, \(s1.messages.count) messages, font glyphs=\(game.cnFont.glyphCount)")
        }
        if ProcessInfo.processInfo.environment["SHIZUKU_DUMP_SEGMENTS"] != nil {
            dumpSegments(game: game)
        }
        if ProcessInfo.processInfo.environment["SHIZUKU_DUMP_BGM"] != nil {
            dumpBGMReferences(game: game)
        }
        if ProcessInfo.processInfo.environment["SHIZUKU_DUMP_EVENTS"] != nil {
            dumpEvents(game: game, scn: scnStart, blk: blkStart)
        }
        if ProcessInfo.processInfo.environment["SHIZUKU_AUDIT"] != nil {
            auditCorpus(game: game, extracted: extracted)
        }
        if ProcessInfo.processInfo.environment["SHIZUKU_AUDIT_IMAGE"] != nil {
            auditImageFlow(game: game)
        }
        if ProcessInfo.processInfo.environment["SHIZUKU_DUMP_TRANSITIONS"] != nil {
            dumpTransitionSheets(game: game)
        }
        if ProcessInfo.processInfo.environment["SHIZUKU_DUMP_SUBTYPES"] != nil {
            dumpSubtypeFrequency(game: game)
        }
        if ProcessInfo.processInfo.environment["SHIZUKU_PALSHEET"] != nil {
            dumpPaletteSheet(game: game)
        }
        if ProcessInfo.processInfo.environment["SHIZUKU_DUMP_VIS"] != nil {
            dumpVisualPlates(game: game)
        }
        if ProcessInfo.processInfo.environment["SHIZUKU_DUMP_GLYPH"] != nil {
            for slot in [565, 3, 116, 151, 101, 177, 178] {
                if let px = game.cnFont.pixels(slot) {
                    print("=== pixels(\(slot)) ===")
                    for r in 0..<24 { print(px[r].map { $0 == 1 ? "#" : "." }.joined()) }
                }
            }
        }

        engine.start(scn: scnStart, block: blkStart)
        let composer = SceneComposer(game: game, scale: scale)

        var frameNo = 0
        var steps = 0
        var wroteAny = false

        while frameNo < maxFrames {
            let r = engine.step()
            switch r {
            case .ended:
                print("engine ended at step \(steps)")
                dumpSceneInfo(engine)
                return
            case .waitingMessage:
                if ProcessInfo.processInfo.environment["SHIZUKU_DUMP_LEAF"] != nil {
                    print("msg \(engine.currentMsg?.index ?? -1) leafcodes: \(engine.displayedLines.map { $0.map(String.init).joined(separator: " ") }.joined(separator: " | "))")
                }
                if traceFlow {
                    let ports = engine.scene.portraits.map { "\($0.imgName)@\($0.x)" }.joined(separator: ",")
                    print(String(format: "  MSG SCN%03d blk%02d MSG%03d seg=%d/%d bg=%@ ports=[%@] bgm=%@",
                                 engine.scnIndex, engine.blockIndex, engine.currentMsg?.index ?? -1,
                                 engine.currentSegmentIndex + 1, engine.currentMsg?.segments.count ?? 0,
                                 engine.scene.bgName ?? engine.scene.bgHName ?? "-",
                                 ports,
                                 engine.scene.bgm.map(String.init) ?? "-"))
                }
                // Headless has no run loop, so drive the glyph reveal to completion first;
                // the frame we export is the fully-revealed segment.
                while engine.isRevealing { engine.tickReveal(deltaTime: 1.0) }
                let img = composer.render(engine)
                let png = img.encodePNG()
                let path = String(format: "/tmp/shizuku_frame_%03d.png", frameNo)
                try? png.write(to: URL(fileURLWithPath: path))
                wroteAny = true
                print("frame \(frameNo): msg \(engine.currentMsg?.index ?? -1) -> \(path) (\(png.count)B)")
                frameNo += 1
                var clicks = 0
                while engine.phase == .awaitingMessage && clicks < 100 {
                    engine.advanceMessage()
                    while engine.isRevealing { engine.tickReveal(deltaTime: 1.0) }
                    clicks += 1
                }
            case .waitingChoice:
                print("choice menu (auto-pick 0 in CLI): \(engine.choices.count) options")
                if traceFlow {
                    print("  CHOICE SCN\(engine.scnIndex) BLK\(engine.blockIndex) pc=\(engine.pc) msgs=\(engine.choices.map { $0.msgIndex })")
                }
                engine.selectChoice(0)
            case .waitingStaffRoll:
                // Same policy as the choice menu above: the headless CLI has no 60 Hz ticker
                // to run a ~105 s credit roll on, so it steps over it and keeps walking.
                print("staff roll (auto-finish in CLI)")
                engine.finishStaffRoll()
            case .waitingLogoAnimation:
                // Same as the staff roll above: the insert is ticker-driven presentation.
                print("logo animation sizuku0\(engine.logoAnimationNumber + 1) (auto-finish in CLI)")
                engine.finishLogoAnimation()
            case .rendered:
                break
            }
            steps += 1
            if steps > 20000 { print("step cap reached"); break }
        }

        if traceFlow {
            print("phase=\(engine.phase) steps=\(steps) scn=\(engine.scnIndex) blk=\(engine.blockIndex) pc=\(engine.pc)")
        }

        if !wroteAny {
            let img = composer.render(engine)
            let png = img.encodePNG()
            try? png.write(to: URL(fileURLWithPath: "/tmp/shizuku_frame_000.png"))
            print("wrote /tmp/shizuku_frame_000.png (\(png.count)B) [no messages yielded]")
        }
    }

    /// `SHIZUKU_DUMP_EVENTS=1` with `-scn`/`-blk` — print the event stream the interpreter
    /// walks, indexed by the same `pc` the engine reports, so a stall or a wrong-branch report
    /// ("it froze at pc=18") maps to a concrete opcode instead of a guess.
    static func dumpEvents(game: GameData, scn: Int, blk: Int) {
        guard let s = game.scn(scn) else { print("no SCN\(scn)"); return }
        guard let b = s.blocks.first(where: { $0.index == blk }) ?? (blk < s.blocks.count ? s.blocks[blk - 1] : nil) else {
            print("no block \(blk) in SCN\(scn) (\(s.blocks.count) blocks)")
            return
        }
        for (pc, ev) in b.events.enumerated() {
            print(String(format: "pc=%3d off=0x%04x op=0x%02x args=%@", pc, ev.offset, ev.opcode,
                         ev.args.map(String.init).joined(separator: ",")))
        }
    }

    /// `SHIZUKU_AUDIT_IMAGE=1` — walk every scenario at the real 60 Hz flip rate and measure
    /// every `LvnsClear`/`LvnsDisp` pair the corpus contains. The item-3 report ("the story
    /// advanced but the CG is still being shown as the background") can only mean the screen is
    /// owned by a transition whose `fromScene` is that CG, so the question is whether any pair
    /// can outlast a reader's patience: this prints the longest ones and flags any that never
    /// terminate. Reads `engine.scene` too, to report which layer the screen carries per scene.
    static func auditImageFlow(game: GameData) {
        let engine = ShizukuEngine(game: game)
        engine.skip = false
        var pairs = 0
        var longest: [(flips: Int, scn: Int, blk: Int, pc: Int, clear: String, disp: String)] = []
        var stuck: [String] = []
        var layerByScn: [Int: String] = [:]
        var cgCarryingMessages = 0, messages = 0
        // The item-3 claim in its own words: after a CG the story moves on but the CG keeps
        // being shown. Every pair that carries the change records how long the screen was
        // still showing the CG, so the worst case in the whole corpus is measurable.
        var cgToBg = 0
        var cgToBgObserved = 0
        var worstCgToBg = (flips: 0, scn: 0, blk: 0, from: "-", to: "-")

        func layer(_ scene: Scene) -> String { scene.bgName ?? scene.bgHName ?? "-" }
        func isCG(_ name: String) -> Bool { name.hasPrefix("HVS") || name.hasPrefix("VIS") }

        for scn in 1..<512 {
            guard let s = game.scn(scn), !s.blocks.isEmpty else { continue }
            engine.start(scn: scn, block: 1)
            var iterations = 0
            var lastLayer = "-"
            while engine.phase != .ended && iterations < 6000 {
                iterations += 1
                // Drain reveals and effect pairs at the presentation rate the App uses.
                var pump = 0
                while (engine.isRevealing || engine.transition != nil), pump < 4000 {
                    pump += 1
                    guard let tr = engine.transition else {
                        engine.tickReveal(deltaTime: 1.0 / 60.0)
                        continue
                    }
                    let clear = tr.clearEffect.map { "\($0)" } ?? "-"
                    let disp = tr.dispEffect.map { "\($0)" } ?? "-"
                    let fromLayer = layer(tr.fromScene)
                    var flips = 0
                    let id = tr.id
                    while engine.transition?.id == id, flips < 12000 {
                        engine.tickReveal(deltaTime: 1.0 / 60.0)
                        flips += 1
                    }
                    pairs += 1
                    if flips >= 12000 {
                        stuck.append(String(format: "STUCK SCN%03d blk%02d pc=%d clear=%@ disp=%@",
                                             engine.scnIndex, engine.blockIndex, engine.pc, clear, disp))
                    }
                    longest.append((flips, engine.scnIndex, engine.blockIndex, engine.pc, clear, disp))
                    let toLayer = layer(engine.scene)
                    if isCG(fromLayer), toLayer.hasPrefix("MAX_S") {
                        cgToBg += 1
                        if flips > worstCgToBg.flips {
                            worstCgToBg = (flips, engine.scnIndex, engine.blockIndex, fromLayer, toLayer)
                        }
                    }
                }
                if pump >= 4000 {
                    stuck.append(String(format: "NO-DRAIN SCN%03d blk%02d pc=%d transition=%@",
                                        engine.scnIndex, engine.blockIndex, engine.pc,
                                        engine.transition == nil ? "nil" : "live"))
                    break
                }
                let shown = engine.scene.bgName ?? engine.scene.bgHName ?? "-"
                if isCG(lastLayer), shown.hasPrefix("MAX_S") { cgToBgObserved += 1 }
                lastLayer = shown
                layerByScn[engine.scnIndex] = shown
                if shown.hasPrefix("HVS") || shown.hasPrefix("VIS") { cgCarryingMessages += 1 }
                messages += 1
                switch engine.step() {
                case .waitingMessage:
                    if engine.waitingPause == nil { engine.revealAll() } else { engine.advanceMessage() }
                case .waitingChoice: engine.selectChoice(0)
                case .waitingStaffRoll: engine.finishStaffRoll()
                case .waitingLogoAnimation: engine.finishLogoAnimation()
                case .rendered, .ended: break
                }
            }
        }
        print("-- LvnsClear/LvnsDisp pairs driven at 1 flip = 1/60 s --")
        print("pairs=\(pairs)  messages=\(messages)  layers-carrying-a-CG=\(cgCarryingMessages)")
        print(String(format: "CG→背景 切换: 观测到 %d 次, 其中经转场 %d 次, 瞬切 %d 次",
                     cgToBgObserved, cgToBg, cgToBgObserved - cgToBg))
        print(String(format: "最久的 CG→背景 转场: %d 翻转 (%.1f s) SCN%03d blk%02d %@ → %@",
                     worstCgToBg.flips, Double(worstCgToBg.flips) / 60.0,
                     worstCgToBg.scn, worstCgToBg.blk, worstCgToBg.from, worstCgToBg.to))
        print("top 12 longest pairs (flips; 1 flip = 16.7 ms):")
        var seen = Set<String>()
        var shownEntries = 0
        for e in longest.sorted(by: { $0.flips > $1.flips }) where shownEntries < 12 {
            let key = "\(e.scn)/\(e.blk)/\(e.pc)/\(e.clear)/\(e.disp)"
            if seen.contains(key) { continue }
            seen.insert(key)
            shownEntries += 1
            print(String(format: "  %5d flips (%.1f s)  SCN%03d blk%02d pc=%d clear=%@ disp=%@",
                         e.flips, Double(e.flips) / 60.0, e.scn, e.blk, e.pc, e.clear, e.disp))
        }
        print(stuck.isEmpty ? "no stuck transition found" : "STUCK:\n" + stuck.joined(separator: "\n"))
    }

    static func dumpSceneInfo(_ engine: ShizukuEngine) {
        print("scene bg=\(engine.scene.bgName ?? "nil") bgH=\(engine.scene.bgHName ?? "nil") portraits=\(engine.scene.portraits.count) bgm=\(engine.scene.bgm.map(String.init) ?? "nil")")
    }

    /// `SHIZUKU_DUMP_TRANSITIONS=1` — one 4-frame sheet per LvnsClear/LvnsDisp effect,
    /// composited from two real game images, for visual verification of all 13 renderers.
    static func dumpTransitionSheets(game: GameData) {
        let outDir = "/tmp/shizuku_shots"
        try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

        func image(_ name: String) -> RGBAImage? {
            guard let (rgba, w, h) = game.image(name: name), w == 640, h == 400 else { return nil }
            var img = RGBAImage(width: w, height: h)
            img.blit(rgba, sw: w, sh: h, dx: 0, dy: 0, alpha: false)
            return img
        }
        // Two visually distinct originals so the reveal geometry is readable by eye.
        guard let from = image("MAX_S01"), let to = image("TITLE0") else {
            print("TRANS: reference images unavailable")
            return
        }

        for effect in LvnsEffect.allCases {
            let total = LvnsEffectTiming.frames(effect, width: 640, height: 400)
            let samples = [0, max(1, total / 4), max(2, total / 2), max(3, total * 3 / 4)]
            var sheet = RGBAImage(width: 640 * samples.count, height: 400)
            for (i, frame) in samples.enumerated() {
                let tile = TransitionRenderer.render(effect: effect, from: from, to: to, frame: frame)
                sheet.blit(tile.pixels, sw: tile.width, sh: tile.height, dx: i * 640, dy: 0, alpha: false)
            }
            let name = String(format: "trans_%02d_%@.png", effect.rawValue, "\(effect)")
            try? sheet.encodePNG().write(to: URL(fileURLWithPath: "\(outDir)/\(name)"))
            let fractions = samples.map { frame -> String in
                let tile = TransitionRenderer.render(effect: effect, from: from, to: to, frame: frame)
                var eqFrom = 0, eqTo = 0
                for i in stride(from: 0, to: tile.pixels.count, by: 4) {
                    var same = true
                    for c in 0..<3 where tile.pixels[i + c] != from.pixels[i + c] { same = false; break }
                    if same { eqFrom += 1 }
                    same = true
                    for c in 0..<3 where tile.pixels[i + c] != to.pixels[i + c] { same = false; break }
                    if same { eqTo += 1 }
                }
                return String(format: "f=%.3f t=%.3f", Double(eqFrom) / Double(640 * 400),
                              Double(eqTo) / Double(640 * 400))
            }
            print("TRANS \(name): frames=\(total) samples=\(samples) toFraction=\(fractions.joined(separator: ","))")
        }
    }

    /// Visual check for the `bgmap`/`palmap` port: the same shared plate drawn once per
    /// script location number that folds onto it, so the atmosphere re-tint is comparable
    /// by eye. `SHIZUKU_PALSHEET=1`; the cell → location table goes to stdout.
    static func dumpPaletteSheet(game: GameData) {
        let outDir = "/tmp/shizuku_shots"
        try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
        let cells: [(String, Int)] = [
            ("MAX_S02 plain (loc 2)", 2), ("loc 4 教室 夕方", 4), ("loc 5 教室 深夜", 5),
            ("MAX_S10 plain (loc 10)", 10), ("loc 43 ろうか 夕方", 43), ("loc 44 ろうか 深夜", 44),
            ("MAX_S12 plain (loc 12)", 12), ("loc 49 廊下 夕方", 49), ("loc 50 廊下 深夜", 50),
            ("loc 53 まっくら廊下", 53), ("MAX_S31 plain (loc 31)", 31), ("loc 32 屋上 夕焼け", 32),
            ("loc 33 屋上 夜", 33), ("MAX_S15 plain (loc 15)", 15), ("loc 41 中庭 夕方", 41),
            ("loc 42 中庭 昼", 42), ("VIS02 plain", -1), ("VIS21 = VIS02 + pal21", -2),
        ]
        let cw = 320, ch = 200, cols = 3
        let rows = (cells.count + cols - 1) / cols
        var sheet = RGBAImage(width: cw * cols, height: ch * rows)
        sheet.fill(0, 0, 0, 255)
        for (i, (label, loc)) in cells.enumerated() {
            let (name, override): (String, PaletteOverride?)
            switch loc {
            case -1: (name, override) = ("VIS02", nil)
            case -2: (name, override) = BackgroundMap.visual(number: 21)
            default:
                (name, override) = (BackgroundMap.bgFileName(forLocation: loc),
                                    BackgroundMap.paletteOverride(forLocation: loc))
            }
            print("PALSHEET cell \(i): \(label) -> \(name.isEmpty ? "(black)" : name) override=\(override != nil)")
            guard let (rgba, w, h) = game.image(name: name, paletteOverride: override) else { continue }
            let ox = (i % cols) * cw, oy = (i / cols) * ch
            for y in 0..<ch {
                for x in 0..<cw {
                    let s = ((y * h / ch) * w + (x * w / cw)) * 4
                    let d = ((oy + y) * sheet.width + ox + x) * 4
                    // Composite over black so the LFG's transparent index does not read as white.
                    let a = Int(rgba[s + 3])
                    sheet.pixels[d]     = UInt8(Int(rgba[s]) * a / 255)
                    sheet.pixels[d + 1] = UInt8(Int(rgba[s + 1]) * a / 255)
                    sheet.pixels[d + 2] = UInt8(Int(rgba[s + 2]) * a / 255)
                    sheet.pixels[d + 3] = 255
                }
            }
        }
        let path = "\(outDir)/palsheet.png"
        try? sheet.encodePNG().write(to: URL(fileURLWithPath: path))
        print("wrote \(path) (\(cells.count) cells)")
    }

    /// `SHIZUKU_DUMP_VIS=1` — decode every VIS plate to /tmp/shizuku_shots/vis/, printing
    /// each plate's size, the bounding box of its non-transparent pixels, and which
    /// scenarios reference it. A plate with `scn=-` is orphaned from the script data, so it
    /// can only be drawn by engine-side code (the music-room question).
    static func dumpVisualPlates(game: GameData) {
        let outDir = "/tmp/shizuku_shots/vis"
        try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
        let owners = Dictionary(uniqueKeysWithValues: game.eventImages().map { ($0.name, $0.scns) })
        for number in 1...40 {
            let name = String(format: "VIS%02d", number)
            guard let (rgba, w, h) = game.image(name: name) else { continue }
            var minX = w, minY = h, maxX = -1, maxY = -1
            for y in 0..<h {
                for x in 0..<w where rgba[(y * w + x) * 4 + 3] != 0 {
                    if x < minX { minX = x }
                    if x > maxX { maxX = x }
                    if y < minY { minY = y }
                    if y > maxY { maxY = y }
                }
            }
            let box = maxX < 0 ? "empty" : "content \(maxX - minX + 1)x\(maxY - minY + 1) at (\(minX),\(minY))"
            let scns = (owners[name] ?? []).isEmpty ? "-" : owners[name]!.map(String.init).joined(separator: ",")
            print("VIS \(name): \(w)x\(h) \(box) scn=\(scns)")
            var flat = RGBAImage(width: w, height: h)
            flat.fill(0, 0, 0, 255)
            for i in 0..<(w * h) {
                let a = Int(rgba[i * 4 + 3])
                flat.pixels[i * 4]     = UInt8(Int(rgba[i * 4]) * a / 255)
                flat.pixels[i * 4 + 1] = UInt8(Int(rgba[i * 4 + 1]) * a / 255)
                flat.pixels[i * 4 + 2] = UInt8(Int(rgba[i * 4 + 2]) * a / 255)
                flat.pixels[i * 4 + 3] = 255
            }
            try? flat.encodePNG().write(to: URL(fileURLWithPath: "\(outDir)/\(name).png"))
        }
        print("wrote \(outDir)")
    }

    /// Dump parsed inline actions + decoded text for a few representative scripts.    /// `SHIZUKU_DUMP_SEGMENTS=1` — sanity check that the message parser stays byte-aligned.
    /// Audit helper: every BGM reference in the whole game (event `0x6e`/`0x7d` operands
    /// and inline `M` actions), so the `bgmmap` script-number→file remap can be verified
    /// against real script data.
    static func dumpBGMReferences(game: GameData) {
        for scn in 0..<game.scns.count {
            guard let s = game.scn(scn) else { continue }
            for blk in s.blocks {
                for ev in blk.events where ev.opcode == 0x6e || ev.opcode == 0x7d {
                    if let a = ev.args.first {
                        print(String(format: "SCN%03d blk%02d EV(%02x,%d)", scn, blk.index, ev.opcode, a))
                    }
                }
            }
            for m in s.messages {
                for seg in m.segments {
                    for case let .bgm(act, t) in seg.actions where t > 0 {
                        print(String(format: "SCN%03d msg%03d M(%@,%d)", scn, m.index, act, t))
                    }
                }
            }
        }
    }

    /// M4.11b audit: event `0x01` sub-type frequency over the whole corpus, so the
    /// `sizuku.c:580-612` implementation priority (01/02 sine+fades, 03 logo animation,
    /// 04 plain text) is set by real script data rather than by guesswork.
    static func dumpSubtypeFrequency(game: GameData) {
        var counts: [Int: Int] = [:]
        var sites: [Int: [String]] = [:]
        for scn in 0..<game.scns.count {
            guard let s = game.scn(scn) else { continue }
            for blk in s.blocks {
                for ev in blk.events where ev.opcode == 0x01 {
                    let kind = ev.args.first.map(Int.init) ?? -1
                    counts[kind, default: 0] += 1
                    if sites[kind, default: []].count < 6 {
                        sites[kind, default: []].append(
                            String(format: "SCN%03d blk%02d pc%02d args=%@", scn, blk.index, ev.offset, ev.args.map { String(format: "%02x", $0) }.joined(separator: ",")))
                    }
                }
            }
        }
        for kind in counts.keys.sorted() {
            print(String(format: "SUB kind=%3d  count=%d", kind, counts[kind]!))
            for site in sites[kind] ?? [] { print("    " + site) }
        }
    }

    static func dumpSegments(game: GameData) {
        let tbl: Data
        do {
            tbl = try Data(contentsOf: URL(fileURLWithPath:
                "research/thirdparty/mglvns/mglvns-1.0/sizfont.tbl"))
        } catch { return }

        func sjis(_ leaf: Int) -> String {
            guard leaf > 0 && leaf < 1851 else { return leaf == 0 ? "　" : "□" }
            // sizfont.tbl is EUC-JP, indexed by leaf code (0 = U+3000, 1 = ■, 2 = あ, ...).
            return String(data: tbl[leaf * 2..<leaf * 2 + 2], encoding: .japaneseEUC) ?? "?"
        }
        func describe(_ a: InlineAction) -> String {
            switch a {
            case .portrait(let p, let n): return "C(\(p),\(n))"
            case .clearPortrait(let p): return "D(\(p))"
            case .bg(let n, let o, let i, let l): return "B(\(n),\(o),\(i),loc\(l))"
            case .visual(let n, let o, let i, let l): return "V(\(n),\(o),\(i),loc\(l))"
            case .hVisual(let n, let o, let i): return "H(\(n),\(o),\(i))"
            case .bgAndPortrait(let p, let c, let b, let o, let i, let l): return "S(\(p),\(c),\(b),\(o),\(i),loc\(l))"
            case .multiPortrait(let ps): return "A(\(ps.map { $0.pos + ":" + $0.name }.joined(separator: ",")))"
            case .bgm(let act, let t): return "M(\(act),\(t))"
            case .sfx(let n): return "P(\(n))"
            case .pcm(let act): return "PCM(\(act))"
            case .flash: return "F"
            case .shake: return "Q"
            case .offset(let x): return "X(\(x))"
            case .speed(let v): return "s(\(v))"
            }
        }

        for scn in [1, 2, 7, 73] {
            guard let s = game.scn(scn) else { continue }
            print("=== SCN\(String(format: "%03d", scn)): \(s.blocks.count) blocks / \(s.messages.count) msgs ===")
            for mi in 0..<min(s.messages.count, 6) {
                guard let m = s.message(mi) else { continue }
                print(" msg\(mi) [\(m.segments.count) seg]")
                for (si, seg) in m.segments.enumerated() {
                    let acts = seg.actions.map(describe).joined(separator: " ")
                    let text = seg.lines.map { line in
                        line.map { sjis($0) }.joined()
                    }.joined(separator: " ⁄ ")
                    print("   seg\(si) \(seg.pause) \(acts) | \(text)")
                }
            }
        }
    }

    /// Corpus-wide statistics: which background numbers the script actually asks for
    /// (and which of those have no file), the distribution of `'B'/'V'/'H'` effect pairs,
    /// the `'s'` reveal speeds, and segments that wait for input while showing no text.
    static func auditCorpus(game: GameData, extracted: String) {
        var effects: [String: Int] = [:]
        var bgNames: [String: Int] = [:]
        var speeds: [Int: Int] = [:]
        var blank: [String: Int] = [:]
        var msgs = 0, segs = 0
        let present = Set((try? FileManager.default.contentsOfDirectory(atPath: extracted)) ?? [])
        for scn in 0..<512 {
            guard let s = game.scn(scn) else { continue }
            for mi in 0..<s.messages.count {
                guard let m = s.message(mi) else { continue }
                msgs += 1
                for seg in m.segments {
                    segs += 1
                    if seg.lines.isEmpty { blank["\(seg.pause)"] = (blank["\(seg.pause)"] ?? 0) + 1 }
                    for a in seg.actions {
                        switch a {
                        case .bg(let n, let o, let i, _):
                            effects["B \(o)/\(i)"] = (effects["B \(o)/\(i)"] ?? 0) + 1
                            bgNames[n, default: 0] += 1
                        case .visual(let n, let o, let i, _):
                            effects["V \(o)/\(i)"] = (effects["V \(o)/\(i)"] ?? 0) + 1
                            bgNames[n, default: 0] += 1
                        case .hVisual(let n, let o, let i):
                            effects["H \(o)/\(i)"] = (effects["H \(o)/\(i)"] ?? 0) + 1
                            bgNames[n, default: 0] += 1
                        case .bgAndPortrait(_, _, let n, let o, let i, _):
                            effects["S \(o)/\(i)"] = (effects["S \(o)/\(i)"] ?? 0) + 1
                            bgNames[n, default: 0] += 1
                        case .speed(let v): speeds[v, default: 0] += 1
                        default: break
                        }
                    }
                }
                for blk in s.blocks {
                    for ev in blk.events {
                        // The event forms of 'B' / 'H'; both go through the same loader.
                        guard let a = ev.args.first else { continue }
                        switch ev.opcode {
                        case 0x0a: bgNames[BackgroundMap.bgFileName(forLocation: Int(a)), default: 0] += 1
                        case 0x16: bgNames[String(format: "HVS%02d", a), default: 0] += 1
                        default: break
                        }
                    }
                }
            }
        }
        print("AUDIT msgs=\(msgs) segs=\(segs)")
        print("-- segments with no text lines, by pause --")
        for (k, v) in blank.sorted(by: { $0.value > $1.value }) { print("  \(k): \(v)") }
        print("-- 's' speed operands --")
        for (k, v) in speeds.sorted(by: { $0.value > $1.value }) { print("  s(\(k)): \(v)") }
        print("-- effect pairs (out/in), top 25 --")
        for (k, v) in effects.sorted(by: { $0.value > $1.value }).prefix(25) { print("  \(k): \(v)") }
        print("-- image names requested that have NO file --")
        for (n, c) in bgNames.filter({ !$0.key.isEmpty && !present.contains("\($0.key).LFG") }).sorted(by: { $0.key < $1.key }) {
            print("  \(n).LFG used \(c)x")
        }
        print("-- MAX_S numbers used, sorted --")
        let nums = bgNames.keys.filter { $0.hasPrefix("MAX_S") }.compactMap { Int($0.dropFirst(5)) }.sorted()
        print("  \(nums)")
    }
}
