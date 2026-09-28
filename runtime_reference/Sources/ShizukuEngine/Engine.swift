//
//  Engine.swift
//  ShizukuEngine
//
//  SCN event interpreter + message state machine. Models the opcode table from
//  docs/research/scripts.md (script.c). Yields on message display / choice so the
//  caller can render and accept input.
//

import Foundation
import ShizukuCore

public struct Portrait: Codable, Equatable {
    public var imgName: String
    public var x: Int
    public var y: Int
    public init(imgName: String, x: Int, y: Int) { self.imgName = imgName; self.x = x; self.y = y }
}

public struct Scene: Codable, Equatable {
    public var bgName: String?
    public var bgHName: String?
    /// Palette substitution to apply when decoding `bgName` (`bgmap`/`palmap`; the script
    /// location number selects it, so it cannot be recovered from the file name).
    public var bgOverride: PaletteOverride?
    public var portraits: [Portrait] = []
    public var bgm: Int?
    public var dark = false
    /// `'X'` horizontal text offset in pixels (used to position choice option strings).
    public var textOffset = 0

    public init() {}
}

public struct Choice: Codable, Equatable {
    public var msgIndex: Int
    public var jumpOffset: Int
    public var label: String
    public init(msgIndex: Int, jumpOffset: Int, label: String = "") {
        self.msgIndex = msgIndex
        self.jumpOffset = jumpOffset
        self.label = label
    }
}

public struct BacklogEntry: Codable, Equatable {
    public let scn: Int
    public let msg: Int
    public let lines: [[Int]]
    public let textPreview: String
    public init(scn: Int, msg: Int, lines: [[Int]], textPreview: String = "") {
        self.scn = scn
        self.msg = msg
        self.lines = lines
        self.textPreview = textPreview
    }
}

public enum StepResult {
    case rendered            // scene changed; redraw
    case waitingMessage      // a message is being shown; wait for input
    case waitingChoice       // a choice menu is up; wait for input
    case waitingStaffRoll    // `0x7d`: the ending credits own the screen, see StaffRoll
    case waitingLogoAnimation  // `0x01/03` insert (`LvnsAnimation(sizuku01/02)`), see LogoAnimation
    case ended               // reached end of block/script
}

public final class ShizukuEngine {
    public let game: GameData
    public var flags = [UInt8](repeating: 0, count: 256)

    // MARK: - Read-text memory & skip settings (item 8, original seen_flag[SCN])
    //
    // The original tracks already-read text with a per-scenario high-water counter
    // (`int seen_flag[SIZUKU_SCN_NO]`, `sizuku.h`): `seen_flag[scn]` is the number of
    // the *next unread* message in that scenario. A message `no` is new iff
    // `no >= seen_flag[scn]` (`SizukuSetTextScenarioState`, `sizuku_etc.c:406-423`).
    //
    // It lives in the *system* file (`sizuku_file.c:70,129`), so it is shared by every
    // slot, survives relaunch, and is not wiped by starting a new game — which is what
    // makes `LvnsSkipTillSelect` (gated on `lvns->seen`) usable on a replay. The App
    // loads and writes it through `GlobalSystemData.seenHighWater`; `reset`
    // deliberately leaves it alone.
    public var seenHighWater: [Int: Int] = [:]
    /// Whether the message currently on screen had been read before.
    public private(set) var isCurrentMessageSeen = false

    /// Skip-related user settings (original menu items). `fastWhenSeen` =
    /// 「既読テキスト自動略し」: previously-read text renders instantly (no per-glyph
    /// reveal) but still needs clicks to page. `forceSkip` = 「早送り未読スキップ」:
    /// fast-forward also runs through unread text instead of stopping at the first
    /// new message. Both default off to match the shipped original.
    public var fastWhenSeen = false
    public var forceSkip = false

    /// `lvns->enable_effect` (mglvns `mgMain.c:76-79`, the `-n e` switch). Turning it off
    /// does not remove the transition: `ClearEffect`/`DispEffect` short-circuit to
    /// `drawWindow`+flush+return-True (`LvnsEffect.c:741-745, 810-814`), i.e. each phase
    /// collapses to one full-screen blit while the post-DISP hold stays. That is the
    /// reference engine's own 「省いて全画面に切り替える」 path, so the reader who finds the
    /// wipes jarring gets the shipped behaviour rather than a made-up one.
    public var effectsEnabled = true

    public var scnIndex = 0
    public var blockIndex = 0
    public internal(set) var pc = 0

    public var scene = Scene()
    public var currentMsg: Message?
    public var choices: [Choice] = []
    public var currentEnding: Int? = nil
    public var backlog: [BacklogEntry] = []

    // MARK: - Message segmentation state (M4.4)

    /// Index into `currentMsg.segments` of the segment being displayed.
    public private(set) var currentSegmentIndex = 0
    /// Lines already committed to the screen by segments that ended in `.waitKey`
    /// (a wait-key pause continues on the same screen; a page break clears it).
    public private(set) var screenLines: [[Int]] = []
    /// Lines of the segment currently being revealed.
    public private(set) var activeLines: [[Int]] = []
    /// How many glyphs of `activeLines` have been revealed so far.
    public private(set) var revealedGlyphs = 0
    /// Total glyphs in `activeLines` (space counts as a cell, matching the layout grid).
    public var activeGlyphCount: Int { ShizukuEngine.glyphCount(activeLines) }

    /// Seconds between revealed glyphs. The original paces each glyph with
    /// `char_wait_time` *flips* (`LvnsPutChar` → `LvnsWait`), default 1, reset to 1 on
    /// every new line (`LvnsNewLineText`), so at the 60 Hz ticker 1 tick = 1/60 s.
    public var textSpeed: Double = ShizukuEngine.defaultTextSpeed
    public static let defaultTextSpeed: Double = 1.0 / 60.0

    // MARK: - Transient presentation effects (M4.10, frame counters)
    //
    // The original's `'F'` / `'Q'` commands are *timed* effects, not sticky flags:
    // WhiteOut+WhiteIn runs 16+16 flips (`LvnsWhiteFade` pair), and `Vibrato` jitters
    // the whole artwork by random ±16 px on both axes for 16 flips. They decay inside
    // the 60 Hz ticker, so the counters live on the engine, not in `Scene`.
    public private(set) var flashTicks = 0
    public private(set) var shakeTicks = 0
    public private(set) var shakeDX = 0
    public private(set) var shakeDY = 0
    /// Frame counter driving the ▼ blink.
    public private(set) var flipCount = 0
    /// Flip at which the *current* wait cursor appeared. `LvnsWaitKey`/`LvnsWaitPage`
    /// enter their loop with `flip_cnt = 0` and toggle the cursor there, so it lights on
    /// the first flip of the wait and blinks 6 on / 6 off from that instant. Phasing the
    /// blink off the global counter instead would leave a page that lands mid-cycle
    /// showing nothing for up to 6 flips — read on screen as a cursor that blinks late.
    public private(set) var waitCursorEntryFlip = 0
    /// The cursor's own 6-flip half-cycle, per `LvnsDisp.c:60-90` (`LvnsDrawCursor` is a
    /// toggle, not a repaint).
    public var waitCursorVisible: Bool { ((flipCount - waitCursorEntryFlip) / 6) % 2 == 0 }
    private var waitBlinkKey: UInt64?

    /// `waitingPause`'s identity: which message, which segment. A change means the reader
    /// turned onto a new page — the original re-entering its wait loop.
    private var currentWaitKey: UInt64? {
        guard waitingPause != nil, let msg = currentMsg else { return nil }
        return (UInt64(bitPattern: Int64(msg.index)) << 32) | UInt64(currentSegmentIndex)
    }

    /// Restart the blink clock whenever the reader lands on a *different* waiting segment,
    /// which is the original entering a fresh `LvnsWaitKey`/`LvnsWaitPage` loop.
    private func trackWaitCursorPhase() {
        let key = currentWaitKey
        if key == nil {
            waitBlinkKey = nil
        } else if waitBlinkKey != key {
            waitBlinkKey = key
            waitCursorEntryFlip = flipCount
        }
    }
    public var hasAnimatedEffects: Bool { flashTicks > 0 || shakeTicks > 0 }
    public static let flashTotalTicks = 32   // WhiteOut 16 + WhiteIn 16
    public static let shakeTotalTicks = 16
    public static let shakeAmplitude = 16

    // MARK: - Bilingual translation hot-mount (M5.2)

    /// Display language. `.zh` hot-mounts the Chinese translation over a message's
    /// text when `TranslationStore` has it; `.jp` renders native leaf codes unchanged.
    /// Seeded from the *build* language (M5.6 WP-2, HANDOVER §38.0 D1): the shipped
    /// JP/ZH bundles never switch at runtime; `setLanguage` remains for tests and
    /// the `SHIZUKU_SHOT` harness.
    public var language: GameLanguage = BuildLanguage.current

    /// Chinese presentation for the current message: the translation is sliced across
    /// the JP segments proportionally to each segment's glyph count, so every JP beat
    /// (`.waitKey` / `.pageBreak`) stays the click unit and the per-glyph reveal clock
    /// (`revealedGlyphs`) types the Chinese out character by character. One slice per
    /// segment; empty when the store has no text for the message (=> JP pathway).
    public private(set) var cnSlices: [String] = []
    /// Chinese text of the beats committed since the last page break — the CN-layer
    /// mirror of `screenLines`.
    public private(set) var cnCommitted: String = ""

    /// Layout for the mounted Chinese text (wide glyphs, so a tighter cell budget
    /// than the 25-column kana grid).
    public var cnCharsPerLine = 22
    public var cnLinesPerPage = 11

    /// True while a CN-translated message is on screen and the CN layer owns the
    /// text region. Deliberately not gated on `currentMsg`: the SELECT prompt commits
    /// its message but stays rendered behind the menu with `currentMsg == nil`.
    public var cnActive: Bool { language == .zh && !cnSlices.isEmpty }

    /// The Chinese text currently visible: committed beats plus the portion of the
    /// active beat's slice revealed so far. Mirrors `displayedLines`.
    public var cnDisplayedText: String {
        guard !activeLines.isEmpty else { return cnCommitted }
        let slice = currentSegmentIndex < cnSlices.count ? cnSlices[currentSegmentIndex] : ""
        // The JP glyph clock paces the reveal; when a CN slice is longer than its
        // beat's JP glyph count, the tail snaps in as the reveal completes.
        let shown = revealedGlyphs >= activeGlyphCount ? slice.count : min(revealedGlyphs, slice.count)
        return cnCommitted + String(slice.prefix(shown))
    }

    /// The visible Chinese lines wrapped from `cnDisplayedText`, capped at one page.
    public var cnCurrentLines: [String] {
        guard cnActive, !cnDisplayedText.isEmpty else { return [] }
        let lines = ShizukuEngine.paginateChinese(cnDisplayedText,
                                                  charsPerLine: cnCharsPerLine,
                                                  linesPerPage: cnLinesPerPage).flatMap { $0 }
        // Over-long pages scroll: the newest lines stay visible, like the JP grid
        // rolling committed text off the top.
        return Array(lines.suffix(cnLinesPerPage))
    }

    /// Build the per-segment Chinese slices for `msg` (empty => JP pathway).
    private func rebuildCNPresentation(_ msg: Message) {
        cnSlices = []
        cnCommitted = ""
        guard language == .zh, let text = translatedText(scn: scnIndex, msg: msg.index) else { return }
        cnSlices = Self.sliceChinese(text,
                                     perSegmentGlyphCounts: msg.segments.map { Self.glyphCount($0.lines) })
        rebuildCNCommitted()
    }

    /// Re-derive `cnCommitted` from the beats before `currentSegmentIndex` (page breaks
    /// clear, wait keys append) — exact mirror of `refreshScreenFromCurrentSegment`'s
    /// JP rebuild, so save-restore and mid-message language switches land correctly.
    private func rebuildCNCommitted() {
        cnCommitted = ""
        guard let msg = currentMsg, !cnSlices.isEmpty else { return }
        for i in 0..<min(currentSegmentIndex, msg.segments.count) {
            if msg.segments[i].pause == .pageBreak {
                cnCommitted = ""
            } else if i < cnSlices.count {
                cnCommitted += cnSlices[i]
            }
        }
    }

    /// Cut a Chinese translation into one slice per JP segment. The proportional
    /// split (by each segment's JP glyph count) keeps beat count identical across
    /// languages, but each cut snaps to the nearest CN sentence ender so a pause
    /// never lands mid-sentence. Newlines collapse; a message with no JP glyphs
    /// or no CN text gets no presentation at all.
    static func sliceChinese(_ text: String, perSegmentGlyphCounts counts: [Int]) -> [String] {
        let chars = Array(text.replacingOccurrences(of: "\n", with: ""))
        let totalJP = counts.reduce(0, +)
        guard !chars.isEmpty, totalJP > 0 else { return [] }
        let boundaries = sentenceBoundaries(chars)
        var slices: [String] = []
        var cumJP = 0
        var prevCut = 0
        for count in counts {
            cumJP += count
            var cut = prevCut
            if count > 0 {
                let target = chars.count * cumJP / totalJP
                let candidates = boundaries.filter { $0 > prevCut }
                if let snapped = candidates.min(by: {
                    abs($0 - target) != abs($1 - target)
                        ? abs($0 - target) < abs($1 - target)
                        : $0 < $1
                }) {
                    cut = snapped
                } else {
                    cut = target
                }
            }
            slices.append(String(chars[prevCut..<max(prevCut, cut)]))
            prevCut = max(prevCut, cut)
        }
        // Integer floors can strand a remainder; it rides the last *text* beat
        // (a trailing command-only segment never becomes the active display).
        if prevCut < chars.count, let lastText = counts.lastIndex(where: { $0 > 0 }) {
            slices[lastText] += String(chars[prevCut..<chars.count])
        }
        return slices
    }

    /// Indices just past each CN sentence ender (including trailing closers like
    /// 」 or ！ after 。), plus the text end so the final beat can reach it.
    private static func sentenceBoundaries(_ chars: [Character]) -> [Int] {
        let enders: Set<Character> = ["。", "．", "！", "？", "…", "!", "?", "」", "』"]
        let closers: Set<Character> = ["」", "』", "）", "》", "\"", "'", "…", "！"]
        var result: [Int] = []
        var i = 0
        while i < chars.count {
            if enders.contains(chars[i]) {
                var j = i + 1
                while j < chars.count && closers.contains(chars[j]) { j += 1 }
                if result.last != j { result.append(j) }
                i = j
            } else {
                i += 1
            }
        }
        if result.last != chars.count { result.append(chars.count) }
        return result
    }

    /// Switch display language, re-resolving the message currently on screen so a
    /// toggle inside a message takes effect immediately.
    public func setLanguage(_ lang: GameLanguage) {
        guard lang != language else { return }
        language = lang
        if let msg = currentMsg { rebuildCNPresentation(msg) }
    }

    /// Wrap a Chinese string into pages of `linesPerPage` lines of `charsPerLine` glyphs.
    public static func paginateChinese(_ text: String, charsPerLine: Int, linesPerPage: Int) -> [[String]] {
        var lines: [String] = []
        for para in text.split(separator: "\n", omittingEmptySubsequences: false) {
            var chunk = ""
            for ch in para {
                chunk.append(ch)
                if chunk.count >= charsPerLine { lines.append(chunk); chunk = "" }
            }
            lines.append(chunk)  // trailing partial (may be empty for exact-multiple para)
        }
        if lines.isEmpty { return [] }
        var pages: [[String]] = []
        var i = 0
        while i < lines.count {
            let end = min(i + linesPerPage, lines.count)
            pages.append(Array(lines[i..<end]))
            i = end
        }
        return pages
    }


    /// Everything currently visible, i.e. committed screen lines plus the portion of the
    /// active segment revealed so far. This is what the renderer draws.
    public var displayedLines: [[Int]] {
        guard !activeLines.isEmpty else { return screenLines }
        return screenLines + ShizukuEngine.prefix(activeLines, glyphs: revealedGlyphs)
    }

    /// True while glyphs are still appearing; a click then completes the segment instead of
    /// advancing past it.
    public var isRevealing: Bool { revealedGlyphs < activeGlyphCount }

    /// Pause the *finished* segment ended with — drives the original's two wait
    /// cursors (`LvnsControl.c`): `.waitKey` → flashing ▶, `.pageBreak` → flashing page.
    public var waitingPause: MessagePauseType? {
        guard phase == .awaitingMessage, !isRevealing,
              let msg = currentMsg, currentSegmentIndex < msg.segments.count
        else { return nil }
        return msg.segments[currentSegmentIndex].pause
    }

    // MARK: - LvnsClear / LvnsDisp image transitions (original `sizuku_effect[]`)

    public enum TransitionPhase: Equatable { case clearing, displaying, hold }

    public struct EngineTransition {
        public let id: Int
        public var phase: TransitionPhase
        public var clearEffect: LvnsEffect?
        public var dispEffect: LvnsEffect?
        /// Flip counter inside the current phase (composer derives its own steps).
        public var state: Int
        /// The image layer as shown when the transition began — the composer's `from` side.
        public let fromScene: Scene
    }

    public private(set) var transition: EngineTransition?

    /// `lvns->skip` — the original collapses CLEAR/DISP to an instant blit while skipping.
    public var skip = false

    /// `lvns->effect_back` — the sine distortion of the *background plate only*
    /// (`lvnsSinEffect`, armed by `0x01` kinds 01/02 at `sizuku.c:584/593`). Arming
    /// resets the phase to 0 (`LvnsBackEffect.c:55-59`); every flip advances it by 8
    /// (`sin_effect.c:114-126`). Portraits and text merge after the effect, so they
    /// never distort (`SinEffect` ends in `mergeCharacter`).
    public private(set) var backEffectActive = false
    public private(set) var backEffectState = 0
    func startBackEffect() { backEffectActive = true; backEffectState = 0 }
    func stopBackEffect() { backEffectActive = false }

    /// The tail an `0x01` sub-message owes the script when it ends: the original
    /// disarms the sine there, and kind 01 additionally runs `LvnsClear(FADE_PALETTE)`
    /// down to black (`sizuku.c:584-596`).
    private enum SubFollowUp { case stopBackEffect, stopBackEffectFadeClear }
    private var subFollowUp: SubFollowUp?

    /// `0x01/03` operand: 0 → `sizuku01`, anything else → `sizuku02` (`sizuku.c:600`).
    /// Only valid while `phase == .logoAnimation`.
    public private(set) var logoAnimationNumber = 0

    /// The App's `LogoAnimation.Player` reached `LVNS_ANIM_NONE`: hand the screen back
    /// (the original's `LvnsAnimation` loop simply exits and the cursor moved by `c += 3`).
    public func finishLogoAnimation() {
        guard phase == .logoAnimation else { return }
        logoAnimationNumber = -1
        phase = .running
    }

    /// Execute and clear the pending `0x01` follow-up. Called from `finishMessage`, and
    /// from the kind-01/02 arm if the referenced message shows nothing at all.
    private func runSubFollowUp() {
        guard let fu = subFollowUp else { return }
        subFollowUp = nil
        stopBackEffect()
        if fu == .stopBackEffectFadeClear {
            beginTransition(clear: .fadePalette, disp: nil) {
                self.scene.bgName = nil
                self.scene.bgHName = nil
                self.scene.bgOverride = nil
                self.scene.portraits.removeAll()
                self.pendingScene = nil
            }
        }
    }

    /// The canvas the effect geometry runs on (matches SceneComposer's 640x400).
    public static let canvasWidth = 640
    public static let canvasHeight = 400
    /// Post-DISP hold: the original blocks a beat after every `LvnsDisp` flush.
    public static let dispHoldFlips = 30

    /// The original double-buffers the artwork: an event load (0x0a) lands in tvram
    /// and is only shown by the next `LvnsDisp` (0x16/0x22/0x24/0x38). `scene` is what
    /// is *shown*; a staged load parks here until a flush copies it over.
    private var pendingScene: Scene?
    func flushStagedImage() {
        if let p = pendingScene { scene = p; pendingScene = nil }
    }

    /// The image waiting behind the double buffer, if any. Read-only and only used by the
    /// App's stall watchdog: "the CG stayed as the background" is exactly a staged load that
    /// never got its `LvnsDisp` flush, so the field has to be observable from outside.
    public var stagedImageName: String? {
        guard let p = pendingScene else { return nil }
        return p.bgName ?? p.bgHName
    }

    private var transitionIdSeq = 0
    private var advanceQueuedDuringTransition = false
    /// Set when a transition ends while the interpreter still had events pending —
    /// the App resumes its `while phase == .running` pump when it consumes this.
    public private(set) var eventPumpWanted = false
    public func consumeEventPumpRequest() -> Bool {
        defer { eventPumpWanted = false }
        return eventPumpWanted
    }

    /// Applies the scene mutation and starts the clear→disp animation pair, mirroring
    /// `LvnsClear(out)` → load image → `LvnsDisp(in)`. `nil` effects skip that pass.
    /// A second call while a transition runs (multi-action segment, 'B' + chr etc.)
    /// merges: the mutation lands, the running animation carries it.
    func beginTransition(clear: LvnsEffect?, disp: LvnsEffect?, apply: () -> Void) {
        if transition != nil {
            apply()
            return
        }
        // `enable_effect == False` keeps both phases but collapses each of them to
        // `LVNS_EFFECT_NORMAL` (one blit), exactly like the reference's short-circuit.
        let clear = effectsEnabled ? clear : clear.map { _ in LvnsEffect.normal }
        let disp = effectsEnabled ? disp : disp.map { _ in LvnsEffect.normal }
        let from = scene
        apply()
        guard !skip, clear != nil || disp != nil else {
            transition = nil
            return
        }
        transitionIdSeq &+= 1
        transition = EngineTransition(id: transitionIdSeq,
                                      phase: clear != nil ? .clearing : .displaying,
                                      clearEffect: clear, dispEffect: disp, state: 0,
                                      fromScene: from)
    }

    /// Pumps the transition one flip. Called from `tickReveal`, which is the 60 Hz
    /// flip source — the same loop the original drives its blocking effect cycles from.
    @discardableResult
    func tickTransition() -> Bool {
        guard var tr = transition else { return false }
        let frames: (LvnsEffect?) -> Int = { e in
            LvnsEffectTiming.frames(e ?? .normal,
                                     width: Self.canvasWidth, height: Self.canvasHeight)
        }
        switch tr.phase {
        case .clearing:
            tr.state += 1
            if tr.state >= frames(tr.clearEffect) {
                if tr.dispEffect == nil {
                    transition = nil
                    endTransitionBookkeeping()
                    return true
                }
                tr.phase = .displaying
                tr.state = 0
            }
        case .displaying:
            tr.state += 1
            if tr.state >= frames(tr.dispEffect) {
                tr.phase = .hold
                tr.state = 0
            }
        case .hold:
            tr.state += 1
            if tr.state >= Self.dispHoldFlips {
                transition = nil
                endTransitionBookkeeping()
                return true
            }
        }
        transition = tr
        return true
    }

    private func endTransitionBookkeeping() {
        // `phase == .running` *means* "the interpreter owns the screen", and the App only
        // re-enters `run()` through this request — so pumping must not depend on any second
        // condition. Requiring `currentMsg == nil` here stranded readers: a `.running` phase
        // with a message still parked (a scenario started over a live pair, inert tail
        // segments, …) left the text half-printed, with no ▼ and no pump, until the next click.
        if phase == .running { eventPumpWanted = true }
        drainQueuedAdvance()
    }

    private func drainQueuedAdvance() {
        guard advanceQueuedDuringTransition else { return }
        advanceQueuedDuringTransition = false
        advanceMessage()
    }

    /// Engine state captured immediately before a choice menu, so the ESC menu's
    /// 「一つ前の選択肢に戻る」 can rewind. Mirrors `lvns->selectpoint` / `flag_select`.
    public private(set) var lastSelectSavePoint: SaveState?
    /// Checkpoint captured after any message containing an explicit `'p'` page break
    /// (original `lvns->savepoint`). 「一つ前の選択肢に戻る」falls back to it when no
    /// SELECT has been passed yet — `sizuku.c:546` seeds `selectpoint = savepoint`.
    public private(set) var lastPageSavePoint: SaveState?
    private var messageHasSavePoint = false

    // Message text pagination (sized to the 640x400 text box).
    public var textCharsPerLine = 25
    public var textMaxLines = 4
    public private(set) var currentPages: [[[Int]]] = []
    public private(set) var currentPage = 0
    public var currentPageLines: [[Int]] {
        currentPage < currentPages.count ? currentPages[currentPage] : [[]]
    }

    public enum Phase: String, Codable, Equatable {
        case running, awaitingMessage, awaitingChoice, staffRoll, logoAnimation, ended
    }
    public private(set) var phase: Phase = .running
    public var audio: AudioController?
    public weak var saveManager: SaveManager?

    public init(game: GameData, audio: AudioController? = nil, saveManager: SaveManager? = nil) {
        self.game = game
        self.audio = audio
        self.saveManager = saveManager
    }

    /// Play a BGM track referenced by a *script* operand (event `0x6e` / inline `M`).
    /// In the original, track number 0 means silence (`bgm.c` `no==0 → AdStop`), NOT
    /// MUS00 (which is the boot jingle, only ever started by a direct call). This maps
    /// script-track-0 to a stop so scenes don't mis-trigger the 5.5s logo sting.
    func startScriptBGM(_ number: Int, loop: Bool) {
        if number == 0 {
            audio?.stopBGM()
            scene.bgm = nil
        } else {
            scene.bgm = number
            audio?.playBGM(number: Self.musicFileIndex(forScriptNo: number), loop: loop)
        }
    }

    /// `bgmmap()` from `sizuku.c:131-140`: the script operand is *not* a file index — it
    /// maps to a CD-DA track (`14→2`, `n<16→n+2`, else `n+1`), and our OGG assets are
    /// named by `track - 2` (jingle track 2 == MUS00.OGG, OP track 16 == MUS14.OGG).
    /// Net: 1..13→MUS01..13, 14→MUS00, 15/16→MUS15, 17..29→MUS16..24. Without this,
    /// every script number ≥14 played the wrong song.
    static func musicFileIndex(forScriptNo no: Int) -> Int {
        let track = (no == 14) ? 2 : (no < 16 ? no + 2 : no + 1)
        return track - 2
    }

    /// `'Mn'` queued track, started at the next image refresh (`BgmPlayNext` in the
    /// original fires on background/character changes), not when the command is read.
    private var pendingBgm: Int? = nil

    /// `'Mw'` hold (`LvnsWaitMusicFade`): seconds left before the interpreter may
    /// continue; input is swallowed while it runs, mirroring the original's blocking wait.
    public var bgmHoldSeconds: Double = 0
    func flushPendingBGM() {
        if let t = pendingBgm {
            pendingBgm = nil
            startScriptBGM(t, loop: true)
        }
    }

    /// Enter a script block. Reached from live play through `0x04 JUMP`, so the message
    /// state must be handed over, not inherited: the original's text commands block until
    /// the segment is fully printed, so a jump can never land mid-reveal. Committed
    /// `screenLines` deliberately survive — printed text is pixels in `vram_text` and keeps
    /// showing until the next message or an `LvnsUndispText` clears it.
    public func start(scn: Int, block: Int = 0) {
        scnIndex = scn; blockIndex = block; pc = 0; phase = .running
        currentMsg = nil
        currentSegmentIndex = 0
        activeLines = []
        revealedGlyphs = 0
        revealAccumulator = 0
        cnSlices = []
        cnCommitted = ""
    }

    private var currentBlock: ScnBlock? { game.scn(scnIndex)?.blocks.first { $0.index == blockIndex } }

    /// Advance non-yielding opcodes until a yield (message/choice) or end.
    @discardableResult
    public func step() -> StepResult {
        guard transition == nil else { return .rendered }
        guard phase == .running else {
            switch phase {
            case .ended: return .ended
            case .staffRoll: return .waitingStaffRoll
            case .logoAnimation: return .waitingLogoAnimation
            default: return .waitingMessage
            }
        }
        guard let blk = currentBlock else { phase = .ended; return .ended }
        guard pc < blk.events.count else { phase = .ended; return .ended }

        let ev = blk.events[pc]
        pc += 1

        switch ev.opcode {
        case 0x00: // END
            phase = .ended
            return .ended
        case 0x01: // SUB kind, msg_no/anim — the four 过场 sub-types at `sizuku.c:580-612`.
            // kind 01: sine-rippling background while the message prints, then
            //        `LvnsClear(FADE_PALETTE)` down to black.
            // kind 02: `LvnsDisp(FADE_PALETTE)` fade-in first, then the same sine message.
            // kind 03: blocking `LvnsAnimation(sizuku01/02)` logo insert.
            // kind 04: the message with no staging at all.
            if ev.args.count >= 2 {
                let kind = ev.args[0]
                let arg = Int(ev.args[1])
                switch kind {
                case 1:
                    startBackEffect()
                    subFollowUp = .stopBackEffectFadeClear
                    if let msg = game.scn(scnIndex)?.message(arg) {
                        return beginMessage(msg) ? .waitingMessage : .rendered
                    }
                    runSubFollowUp()
                    return .rendered
                case 2:
                    beginTransition(clear: nil, disp: .fadePalette) {
                        self.flushStagedImage()
                        self.flushPendingBGM()
                    }
                    startBackEffect()
                    subFollowUp = .stopBackEffect
                    if let msg = game.scn(scnIndex)?.message(arg) {
                        return beginMessage(msg) ? .waitingMessage : .rendered
                    }
                    runSubFollowUp()
                    return .rendered
                case 3:
                    logoAnimationNumber = arg
                    phase = .logoAnimation
                    return .waitingLogoAnimation
                case 4:
                    if let msg = game.scn(scnIndex)?.message(arg) {
                        return beginMessage(msg) ? .waitingMessage : .rendered
                    }
                    return .rendered
                default:
                    // The original prints an error and `return`s out of the main loop.
                    phase = .ended
                    return .ended
                }
            }
        case 0x04: // JUMP scn,blk
            if ev.args.count >= 2 {
                start(scn: Int(ev.args[0]), block: Int(ev.args[1]))
                return .rendered
            }
            phase = .ended
            return .ended
        case 0x0a: // BG MAX_S%02d — load into tvram only; the next Disp event shows it
            if let a = ev.args.first {
                var staged = pendingScene ?? scene
                staged.bgName = BackgroundMap.bgFileName(forLocation: Int(a))
                staged.bgHName = nil
                staged.bgOverride = BackgroundMap.paletteOverride(forLocation: Int(a))
                staged.portraits.removeAll()
                pendingScene = staged
                flushPendingBGM()
                return .rendered
            }
        case 0x16: // HBG HVS%02d + LvnsDisp(NORMAL) — instant flush
            if let a = ev.args.first {
                var staged = pendingScene ?? scene
                staged.bgHName = String(format: "HVS%02d", a)
                staged.bgName = nil
                staged.bgOverride = nil
                staged.portraits.removeAll()
                pendingScene = staged
                beginTransition(clear: nil, disp: .normal) {
                    self.flushStagedImage()
                    self.flushPendingBGM()
                }
                return .rendered
            }
        case 0x14: // CLEAR — original = UndispText + LvnsClear(sizuku_effect[c1]): wipe image
                   // *and* text layer behind the chosen clear effect.
            beginTransition(clear: LvnsEffectMap.fromEventArg(Int(ev.args.first ?? 99)), disp: nil) {
                self.scene.bgName = nil
                self.scene.bgHName = nil
                self.scene.bgOverride = nil
                self.scene.portraits.removeAll()
                self.pendingScene = nil
                self.screenLines = []
                self.activeLines = []
                self.revealedGlyphs = 0
            }
            return .rendered
        case 0x22: // CHR chr_no, pos — replaces only the named slot, then Disp(FADE_MASK)
            if ev.args.count >= 2 {
                let img = String(format: "MAX_C%02X", ev.args[0])
                let pos = ShizukuEngine.portraitLetter(forCode: ev.args[1])
                beginTransition(clear: nil, disp: .fadeMask) {
                    self.flushStagedImage()
                    self.setPortrait(pos: pos, name: img)
                    self.flushPendingBGM()
                }
                return .rendered
            }
        case 0x24: // CHR2 — loads the character but forces the centre slot, Disp(FADE_MASK)
            if ev.args.count >= 1 {
                let img = String(format: "MAX_C%02X", ev.args[0])
                beginTransition(clear: nil, disp: .fadeMask) {
                    self.flushStagedImage()
                    self.setPortrait(pos: "c", name: img)
                    self.flushPendingBGM()
                }
                return .rendered
            }
        case 0x28: // MARK2 — no visual effect
            return .rendered
        case 0x38: // EFFECT2 / screen update — original calls LvnsDisp(lvns, sizuku_effect[c[1]])
                   // (sizuku.c:702), flushing whatever tvram holds, and every LvnsDisp
                   // flushes the queued 'Mn' track.
            beginTransition(clear: nil,
                            disp: LvnsEffectMap.fromEventArg(Int(ev.args.first ?? 11))) {
                self.flushStagedImage()
                self.flushPendingBGM()
            }
            return .rendered
        case 0x3d, 0x3e: // IF_EQ / IF_NE flag,val,offset (byte offset jump)
            if ev.args.count >= 3 {
                let flag = Int(ev.args[0])
                let val = Int(ev.args[1])
                let off = Int(ev.args[2])
                let eq = flags[flag] == UInt8(val)
                let cond = ev.opcode == 0x3d ? eq : !eq
                if cond {
                    let targetByteOffset = ev.offset + 4 + off
                    if let targetIdx = blk.events.firstIndex(where: { $0.offset >= targetByteOffset }) {
                        pc = targetIdx
                    } else {
                        pc = blk.events.count
                    }
                }
                return .rendered
            }
        case 0x47: // FLAG_SET flag=val
            if ev.args.count >= 2 {
                flags[Int(ev.args[0])] = ev.args[1]
                return .rendered
            }
        case 0x48: // FLAG_ADD flag+=val
            if ev.args.count >= 2 {
                flags[Int(ev.args[0])] = UInt8(truncatingIfNeeded: Int(flags[Int(ev.args[0])]) + Int(ev.args[1]))
                return .rendered
            }
        case 0x54: // MSG msg_no
            if let a = ev.args.first, let msg = game.scn(scnIndex)?.message(Int(a)) {
                return beginMessage(msg) ? .waitingMessage : .rendered
            }
        case 0x6e: // BGM bgm_no
            if let a = ev.args.first {
                startScriptBGM(Int(a), loop: true)
                return .rendered
            }
        case 0x7d: // END_BGM bgm_no — starts the ending track, then `SizukuEnding` blocks
            // the interpreter on the 14-card staff roll (`sizuku.c:810-826`, `sizuku_ed.c`).
            // `pc` has already moved past it, so `finishStaffRoll()` resumes exactly where
            // the original's `c += 2` leaves off — the `IF_NE`/`JUMP 195` epilogue chain.
            if let a = ev.args.first {
                startScriptBGM(Int(a), loop: false)
                phase = .staffRoll
                return .waitingStaffRoll
            }
        case 0x7e: // END_CHK ending_no
            if let a = ev.args.first {
                let endNo = Int(a)
                currentEnding = endNo
                if endNo == 9 { // 瑠璃子 HAPPY
                    flags[0x46] = 1
                }
                if endNo == 8 { // True
                    flags[0x45] = 1
                }
                if flags[0x46] == 1 {
                    flags[0] = 3
                } else {
                    if flags[0] == 0 {
                        flags[0] = 2
                    } else {
                        flags[0] = 1
                    }
                }
                saveManager?.recordEnding(endNo, in: self)
            }
            return .rendered
        case 0x7c: // ENDING
            return .rendered
        case 0x05: // SELECT msg,count,(msg,offset)* — prompt line then choice menu
            // Capture the pre-choice state so the system menu can rewind to it
            // (`lvns->selectpoint` / `flag_select` in the original). `step()` already
            // advanced `pc`, so rewind it by one event: restoring must *re-run* the
            // SELECT opcode and re-present the menu, not resume after the pick.
            var selectpoint = captureSaveState(slot: -99)
            selectpoint.pc = pc - 1
            lastSelectSavePoint = selectpoint
            // The original renders SELECT's message number through the text parser
            // before the option cursor appears (`ScriptExec` case 0x05 →
            // `LvnsSetTextScenario` + `TextParser`), and the text stays on screen
            // while the choices are up.
            if let pm = ev.args.first, let msg = game.scn(scnIndex)?.message(Int(pm)) {
                if beginMessage(msg) {
                    revealAll()
                    commitActiveLines()
                }
                currentMsg = nil
            }
            choices = []
            let count = ev.args.count >= 2 ? Int(ev.args[1]) : 0
            var j = 2
            for _ in 0..<count where j + 2 <= ev.args.count {
                let m = Int(ev.args[j])
                let off = Int(ev.args[j + 1])
                choices.append(Choice(msgIndex: m, jumpOffset: off, label: ""))
                j += 2
            }
            guard !choices.isEmpty else {
                // Corrupt/truncated SELECT (count byte 0 or args cut short): the original
                // never presents an empty menu, and the composer would index choices[0].
                return .rendered
            }
            phase = .awaitingChoice
            return .waitingChoice
        default:
            // Unknown/skip opcodes — advance and keep going.
            return .rendered
        }
        return .rendered
    }

    /// Verification/dev hook: display a specific (scn,msg) message directly, honoring the
    /// active language. Used by the SHIZUKU_SHOT harness to prove the CN hot-mount path.
    public func previewMessage(scn: Int, msg: Int) {
        guard let m = game.scn(scn)?.message(msg) else { return }
        scnIndex = scn
        blockIndex = 0
        pc = 0
        beginMessage(m)
    }

    /// Start displaying a message from its first segment. Returns `false` when the message
    /// shows nothing at all, so the caller keeps running the event stream instead of waiting.
    @discardableResult
    private func beginMessage(_ msg: Message) -> Bool {
        // Safety flush: text always draws over the shown image, so anything still
        // staged in tvram becomes visible here (undispensed 0x0a loads included).
        flushStagedImage()
        currentMsg = msg
        messageHasSavePoint = msg.segments.contains { $0.pause == .pageBreak }
        // Resolve read-state against the per-scenario high-water counter (original
        // `SizukuSetTextScenarioState`). New text iff `no >= seen_flag[scn]`.
        let hw = seenHighWater[scnIndex] ?? 0
        isCurrentMessageSeen = msg.index < hw
        if msg.index >= hw { seenHighWater[scnIndex] = msg.index + 1 }
        currentSegmentIndex = 0
        screenLines = []
        activeLines = []
        revealedGlyphs = 0
        revealAccumulator = 0
        textSpeed = ShizukuEngine.defaultTextSpeed
        // Legacy page view, retained for the CLI dump and the choice-option renderer.
        currentPages = msg.paginated(charsPerLine: textCharsPerLine, maxLines: textMaxLines)
        currentPage = 0
        rebuildCNPresentation(msg)
        phase = .awaitingMessage
        if skipInertSegments() { return false }
        if skipCNEmptyBeats() { return false }
        recordCurrentMessageToBacklog()
        return true
    }

    /// A segment that puts nothing on the screen when it would pause: no glyphs of its own
    /// and no text committed by earlier segments. `sizuku.c:240-242` shows `'$'` merely
    /// ending the string — no wait, no cursor — so a command-only segment (`'B'`/`'S'` image
    /// swap) must never cost a click. Rendering these as pages is what produced the blank
    /// screens carrying only the ▼ or the page icon.
    static func isInertSegment(_ seg: MessageSegment) -> Bool {
        glyphCount(seg.lines) == 0
    }

    /// Walk forward past segments that would show nothing, applying their commands, and stop
    /// on the first one that carries text. Returns `true` when the message ran out and was
    /// finished.
    @discardableResult
    private func skipInertSegments() -> Bool {
        guard let msg = currentMsg else { return true }
        while currentSegmentIndex < msg.segments.count,
              Self.isInertSegment(msg.segments[currentSegmentIndex]),
              Self.glyphCount(screenLines) == 0 {
            applyCurrentSegment()
            currentSegmentIndex += 1
        }
        guard currentSegmentIndex < msg.segments.count else {
            finishMessage()
            return true
        }
        currentPage = min(currentSegmentIndex, max(0, currentPages.count - 1))
        applyCurrentSegment()
        return false
    }

    /// A CN beat that would leave the screen exactly as it is: its Chinese slice is empty
    /// (so nothing new is typed), it fires no inline action (so no image or BGM changes),
    /// and it is not a page break (which visibly clears the screen). The JP grid that
    /// normally fills such a beat is hidden while `cnActive`, so without this the user
    /// pays one click per beat for zero feedback — up to 59 in a row in the corpus.
    private func isCNEmptyBeat(_ seg: MessageSegment, index: Int) -> Bool {
        guard seg.pause != .pageBreak, seg.actions.isEmpty else { return false }
        return index >= cnSlices.count || cnSlices[index].isEmpty
    }

    /// Walk forward past CN-silent beats, applying their (empty) commands, and stop on the
    /// first beat that carries Chinese text or changes the picture. Returns `true` when the
    /// message ran out and was finished.
    @discardableResult
    private func skipCNEmptyBeats() -> Bool {
        guard cnActive, let msg = currentMsg else { return false }
        let from = currentSegmentIndex
        while currentSegmentIndex < msg.segments.count,
              isCNEmptyBeat(msg.segments[currentSegmentIndex], index: currentSegmentIndex) {
            currentSegmentIndex += 1
        }
        guard currentSegmentIndex < msg.segments.count else {
            finishMessage()
            return true
        }
        guard currentSegmentIndex != from else { return false }
        currentPage = min(currentSegmentIndex, max(0, currentPages.count - 1))
        applyCurrentSegment()
        return false
    }

    /// End-of-message housekeeping: clear the text layer, capture the 'p' savepoint, and hand
    /// control back to the event stream.
    private func finishMessage() {
        currentMsg = nil
        currentPages = []
        currentPage = 0
        screenLines = []
        activeLines = []
        revealedGlyphs = 0
        revealAccumulator = 0
        cnSlices = []
        cnCommitted = ""
        // 'p' savepoint: the original sets `savepoint_flag` at the 'p' command
        // (sizuku.c:252) and the main loop captures `LvnsSetSavePoint` once the
        // message has finished executing — i.e. at exactly this point.
        if messageHasSavePoint { lastPageSavePoint = captureSaveState(slot: -98) }
        phase = .running
        // `0x01` kind 01/02 tail: disarm the sine (and for kind 01 fade to black),
        // exactly between `TextParser` returning and `c += 3`.
        runSubFollowUp()
    }

    /// Execute the inline actions of the segment at `currentSegmentIndex` and make its text
    /// the active (revealing) body.
    ///
    /// Ported from `ScriptExecMsg*` in `research/gbalvns/core/script3.c`, which is the
    /// authoritative behaviour of the original message decoder. Note that background and
    /// character commands *clear* the character layer before loading (the original rebuilds
    /// `vram_char` from scratch), and that `'D'` clears then re-loads the named slot — with
    /// `0x99` meaning "clear only", which `GameData.image` resolves to nothing.
    public func applyCurrentSegment() {
        guard let msg = currentMsg, currentSegmentIndex < msg.segments.count else { return }
        let seg = msg.segments[currentSegmentIndex]

        for action in seg.actions {
            switch action {
            case .bg(let name, let eOut, let eIn, let location):
                beginTransition(clear: LvnsEffectMap.fromScriptCode(eOut),
                                disp: LvnsEffectMap.fromScriptCode(eIn)) {
                    self.pendingScene = nil
                    self.scene.bgName = name
                    self.scene.bgHName = nil
                    self.scene.bgOverride = BackgroundMap.paletteOverride(forLocation: location)
                    self.scene.portraits.removeAll()
                    self.flushPendingBGM()
                }
            case .visual(let name, let eOut, let eIn, let location):
                beginTransition(clear: LvnsEffectMap.fromScriptCode(eOut),
                                disp: LvnsEffectMap.fromScriptCode(eIn)) {
                    self.pendingScene = nil
                    self.scene.bgName = name
                    self.scene.bgHName = nil
                    self.scene.bgOverride = BackgroundMap.visual(number: location).override
                    self.scene.portraits.removeAll()
                    self.flushPendingBGM()
                }
            case .hVisual(let name, let eOut, let eIn):
                beginTransition(clear: LvnsEffectMap.fromScriptCode(eOut),
                                disp: LvnsEffectMap.fromScriptCode(eIn)) {
                    self.pendingScene = nil
                    self.scene.bgHName = name
                    self.scene.bgName = nil
                    self.scene.bgOverride = nil
                    self.scene.portraits.removeAll()
                    self.flushPendingBGM()
                }
            case .portrait(let pos, let name):
                // 'C' → UndispText + LvnsDisp(FADE_MASK); the rest of the image layer stays.
                beginTransition(clear: nil, disp: .fadeMask) {
                    self.flushStagedImage()
                    self.setPortrait(pos: pos, name: name)
                    self.flushPendingBGM()
                }
            case .clearPortrait(let pos):
                beginTransition(clear: nil, disp: .fadeMask) {
                    self.flushStagedImage()
                    self.clearPortraits(pos: pos)
                    self.flushPendingBGM()
                }
            case .bgAndPortrait(let pos, let chrName, let bgName, let eOut, let eIn, let location):
                beginTransition(clear: LvnsEffectMap.fromScriptCode(eOut),
                                disp: LvnsEffectMap.fromScriptCode(eIn)) {
                    self.pendingScene = nil
                    self.scene.bgName = bgName
                    self.scene.bgHName = nil
                    self.scene.bgOverride = BackgroundMap.paletteOverride(forLocation: location)
                    self.scene.portraits.removeAll()
                    self.setPortrait(pos: pos, name: chrName)
                    self.flushPendingBGM()
                }
            case .multiPortrait(let entries):
                beginTransition(clear: nil, disp: .fadeMask) {
                    self.flushStagedImage()
                    self.scene.portraits.removeAll()
                    for e in entries { self.setPortrait(pos: e.pos, name: e.name) }
                    self.flushPendingBGM()
                }
            case .bgm(let action, let track):
                switch action {
                case "play":
                    startScriptBGM(track, loop: true)
                case "next":
                    // 'Mn' only queues: the original starts it at the next image refresh
                    // (`BgmPlayNext` fires on B/V/H/C/S/A), so it does not cut in early.
                    pendingBgm = track
                case "fade":
                    // 'Mf' → LvnsFadeMusic: ramps the current track out but keeps the
                    // queued 'Mn' track — the original only clears it on start/pause.
                    audio?.fadeOutBGM()
                    scene.bgm = nil
                case "stop":
                    // 'Ms' → LvnsPauseMusic: `current_music = 0` yet `next_music` survives.
                    audio?.stopBGM()
                    scene.bgm = nil
                case "wait":
                    // 'Mw' → LvnsWaitMusicFade: *blocks* until an in-flight fade completes
                    // and marks the current track non-looping. It never stops music and
                    // never drops the queue — clearing here was a source of silent scenes.
                    if let player = audio {
                        bgmHoldSeconds = player.isBGMFading ? player.bgmFadeRemaining : 0
                    }
                default:
                    break
                }
            case .sfx(let name):
                audio?.playSFX(name: name)
            case .pcm(let action):
                if action == "stop" {
                    audio?.stopAllSFX()
                }
            case .flash:
                // 'F' → WhiteOut + WhiteIn, 16 flips each (`LvnsTextWhiteFade`).
                flashTicks = Self.flashTotalTicks
            case .shake:
                // 'Q' → Vibrato: random ±16 px jitter of the whole artwork for 16 flips.
                shakeTicks = Self.shakeTotalTicks
            case .offset(let x):
                // 'X' → SetTextOffset; under USE_MGL the value is halved (`LvnsText.c`).
                scene.textOffset = x / 2
            case .speed(let v):
                // 's' → char_wait_time = v flips per glyph; bigger is *slower*.
                textSpeed = Self.speed(forHint: v)
            }
        }

        activeLines = seg.lines
        revealedGlyphs = 0
        revealAccumulator = 0
    }

    /// Map an `'s'` command operand to a reveal interval: the original assigns it
    /// straight to `char_wait_time` (`sizuku.c:474`), i.e. flips per glyph at 60 Hz.
    /// A `0` operand would mean no wait at all; the original would burn frames anyway,
    /// so clamp to the 1-tick default.
    static func speed(forHint hint: Int) -> Double {
        Double(max(1, hint)) / 60.0
    }

    /// Reveal `count` more glyphs, clamped to the active segment length.
    public func revealGlyphs(_ count: Int) {
        revealedGlyphs = min(activeGlyphCount, revealedGlyphs + max(0, count))
    }

    /// Reveal the rest of the active segment immediately.
    public func revealAll() {
        revealedGlyphs = activeGlyphCount
    }

    /// Advance the per-character reveal by `dt` seconds. Returns true if anything changed, so
    /// the caller knows whether a redraw is needed. Mirrors the original's `char_wait_time`
    /// pacing (`LvnsPutChar` sleeps before each glyph unless skipping).
    @discardableResult
    public func tickReveal(deltaTime dt: Double) -> Bool {
        flipCount &+= 1
        trackWaitCursorPhase()
        // `Lvns.c:308-320`: every flip advances the armed background effect by 8 table
        // steps — including the flips spent waiting for the next click.
        if backEffectActive { backEffectState = SinBackEffect.nextState(backEffectState) }
        // The original's effect loops block the whole main loop, so no glyph prints
        // and no blink state advances while a transition owns the screen.
        if tickTransition() { return true }
        if flashTicks > 0 { flashTicks -= 1 }
        if shakeTicks > 0 {
            shakeTicks -= 1
            if shakeTicks > 0 {
                // Vibrato: fresh random offset every flip while the effect lasts.
                shakeDX = Int.random(in: -Self.shakeAmplitude...Self.shakeAmplitude)
                shakeDY = Int.random(in: -Self.shakeAmplitude...Self.shakeAmplitude)
            } else {
                shakeDX = 0
                shakeDY = 0
            }
        }
        if bgmHoldSeconds > 0 { bgmHoldSeconds = max(0, bgmHoldSeconds - dt) }
        guard phase == .awaitingMessage, isRevealing, dt > 0, textSpeed > 0 else { return false }
        revealAccumulator += dt / textSpeed
        let whole = Int(revealAccumulator)
        guard whole > 0 else { return false }
        revealAccumulator -= Double(whole)
        let before = revealedGlyphs
        revealGlyphs(whole)
        // LvnsNewLineText resets char_wait_time = 1 on every line break: the speed
        // set by 's' only lasts for the rest of its own line.
        if crossedLineBoundary(from: before, to: revealedGlyphs) {
            textSpeed = Self.defaultTextSpeed
        }
        return true
    }

    /// True when the glyph reveal advanced past the end of one of the active lines.
    private func crossedLineBoundary(from: Int, to: Int) -> Bool {
        var total = 0
        for line in activeLines {
            total += ShizukuEngine.glyphCount([line])
            if from < total && to >= total && to != activeGlyphCount { return true }
        }
        return false
    }

    /// Fractional glyph carry-over between ticks, so slow speeds still reveal smoothly
    /// instead of rounding every frame down to zero.
    private var revealAccumulator: Double = 0

    /// Commit the active segment's lines into the persistent screen body.
    private func commitActiveLines() {
        if !activeLines.isEmpty {
            screenLines.append(contentsOf: activeLines)
            if currentSegmentIndex < cnSlices.count { cnCommitted += cnSlices[currentSegmentIndex] }
        }
        activeLines = []
        revealedGlyphs = 0
    }

    /// User confirmed / advanced past the current message page.
    ///
    /// Segment semantics follow the original: a `.waitKey` pause commits the text and waits
    /// on the *same* screen (the next segment appends below), while `.pageBreak` clears the
    /// screen before the next segment. If text is still revealing, the first click completes
    /// it instead of advancing.
    public func advanceMessage() {
        if bgmHoldSeconds > 0 { return }   // 'Mw' blocking wait (LvnsWaitMusicFade)
        if transition != nil {             // LvnsClear/LvnsDisp block input while running
            advanceQueuedDuringTransition = true
            return
        }
        guard let msg = currentMsg else {
            phase = .running
            return
        }

        // No CN special-case here: in `.zh` the JP segment machine stays the single
        // clock — beats, pauses and inline actions fire exactly as in Japanese, while
        // the CN layer types out the proportional slice of the current beat. The JP
        // glyph grid is never drawn while `cnActive`, so nothing leaks.
        if isRevealing {
            revealAll()
            return
        }

        let seg = currentSegmentIndex < msg.segments.count ? msg.segments[currentSegmentIndex] : nil
        if seg?.pause == .pageBreak {
            screenLines = []
            activeLines = []
            revealedGlyphs = 0
            revealAccumulator = 0
            cnCommitted = ""
        } else {
            commitActiveLines()
        }

        if currentSegmentIndex + 1 < msg.segments.count {
            currentSegmentIndex += 1
            if skipInertSegments() { return }
            skipCNEmptyBeats()
            return
        }

        finishMessage()
    }

    /// Count glyph *cells* in lines, counting spaces (the layout grid advances on them).
    static func glyphCount(_ lines: [[Int]]) -> Int {
        var n = 0
        for line in lines {
            for t in line where t >= 0 && t <= 1851 { n += 1 }
        }
        return n
    }

    /// First `glyphs` cells of `lines`, preserving exact line membership so partially revealed
    /// lines still wrap the way the finished text will.
    static func prefix(_ lines: [[Int]], glyphs: Int) -> [[Int]] {
        guard glyphs > 0 else { return [] }
        var remaining = glyphs
        var out: [[Int]] = []
        for line in lines {
            if remaining <= 0 { break }
            let usable = line.filter { $0 >= 0 && $0 <= 1851 }
            if usable.count <= remaining {
                out.append(line)
                remaining -= usable.count
            } else {
                var taken = 0
                var partial: [Int] = []
                for t in line where t >= 0 && t <= 1851 {
                    if taken >= remaining { break }
                    partial.append(t)
                    taken += 1
                }
                out.append(partial)
                remaining = 0
            }
        }
        return out
    }

    /// Place a character portrait in one of the three native slots.
    /// Slot geometry from `SizukuLoadCharacter` (`research/thirdparty/mglvns/.../sizuku_etc.c`):
    /// left x=0, centre x=160, right x=320, all at y=0 — the character LFGs are 400px tall,
    /// i.e. full screen height, so no vertical offset is needed.
    private func setPortrait(pos: String, name: String) {
        // `SizukuLoadCharacter` maps an unrecognised slot to the left position rather than
        // refusing to draw.
        let x = ShizukuEngine.portraitX(for: pos) ?? 0
        let p = Portrait(imgName: name, x: x, y: 0)
        scene.portraits.removeAll { $0.x == x && $0.y == 0 }
        scene.portraits.append(p)
        // Keep slot order stable so overlapping draws composite left -> centre -> right,
        // as the original does when merging each slot into `vram_char` in turn.
        scene.portraits.sort { $0.x < $1.x }
    }

    /// Remove portraits. `"a"` (and any unrecognised slot) clears every slot
    /// (`IMG_CHR_TYPE_ALL`), otherwise the single named slot.
    private func clearPortraits(pos: String) {
        guard let x = ShizukuEngine.portraitX(for: pos) else {
            scene.portraits.removeAll()
            return
        }
        scene.portraits.removeAll { $0.x == x && $0.y == 0 }
    }

    /// Screen x for a slot letter; nil means "all slots" (the `'a'`/`'A'`/`'0'` forms).
    static func portraitX(for pos: String) -> Int? {
        switch pos.lowercased() {
        case "l": return 0
        case "c": return 160
        case "r": return 320
        default: return nil
        }
    }

    /// Event opcodes `0x22`/`0x24` carry the slot as a raw byte, unlike the message commands
    /// which carry it as ASCII. Observed values in the scripts are `'0'`, `'Z'` and `'8'`;
    /// the original's `ScriptGetMapChrPos` compares against `'l'/'r'/'c'/'a'` and falls
    /// through to the left slot for anything else. Accept both encodings so either source
    /// maps to a real slot instead of silently landing on the default.
    static func portraitLetter(forCode code: UInt8) -> String {
        let c = Character(UnicodeScalar(code))
        if c.isLetter { return String(c).lowercased() }
        return "l"
    }

    /// Resolve the display text for a (scn,msg) pair.
    /// Returns the CN translation if the engine is in `.zh` mode and the store has it;
    /// otherwise falls back to the JP pathway (nil — caller renders leaf codes via the
    /// existing JP font pipeline). This keeps behavior identical when the store is empty,
    /// and — since M5.6 WP-1 — when the language is `.jp` regardless of store contents:
    /// a translation only ever serves the `.zh` display language.
    public func translatedText(scn: Int, msg: Int) -> String? {
        guard language == .zh else { return nil }
        return game.translationStore.text(scn: scn, msg: msg)
    }

    /// User picked a choice (index into choices[]).
    public func selectChoice(_ index: Int) {
        guard index >= 0 && index < choices.count else { return }
        let c = choices[index]
        choices = []
        phase = .running

        // jumpOffset is a forward byte offset from the end of the 0x05 instruction.
        if let blk = currentBlock, pc > 0 && pc - 1 < blk.events.count {
            let selectEv = blk.events[pc - 1]
            let selectLen = 3 + (selectEv.args.count >= 2 ? Int(selectEv.args[1]) * 2 : 0)
            let targetByteOffset = selectEv.offset + selectLen + c.jumpOffset
            if let targetIdx = blk.events.firstIndex(where: { $0.offset >= targetByteOffset }) {
                pc = targetIdx
            } else {
                pc = blk.events.count
            }
        }
    }

    /// Stop all sound effects.
    /// The staff roll's `LVNS_SCRIPT_WAIT_CLICK` was satisfied and its trailing
    /// `CLEAR(FADE_PALETTE)` finished, so `SizukuEnding` has returned: hand the screen back
    /// to the script.
    public func finishStaffRoll() {
        guard phase == .staffRoll else { return }
        phase = .running
    }

    public func stopSFX() {
        audio?.stopAllSFX()
    }

    // MARK: - Backlog
    public func recordCurrentMessageToBacklog() {
        guard let msg = currentMsg else { return }
        if let last = backlog.last, last.scn == scnIndex && last.msg == msg.index {
            return
        }
        // Record the segmented lines: they are already stripped of the inline commands, so
        // the history panel shows prose rather than stray `C`/`B`/`M` argument text.
        var allLines: [[Int]] = []
        for seg in msg.segments { allLines.append(contentsOf: seg.lines) }
        // M5.6 WP-1: the entry snapshot is the language-agnostic JP leaf text (HistoryView
        // renders `lines` anyway), never the CN translation — a CN string baked into the
        // backlog would leak Chinese into a JP build that loads the save.
        let proseLines = allLines.filter { !$0.isEmpty }
        let preview: String
        if proseLines.isEmpty {
            preview = "SCN\(scnIndex) MSG\(msg.index)"
        } else {
            preview = String(game.leafCodec.decode(Array(proseLines.prefix(2).joined())).prefix(52))
        }
        backlog.append(BacklogEntry(scn: scnIndex, msg: msg.index, lines: allLines, textPreview: preview))
        if backlog.count > 100 {
            backlog.removeFirst()
        }
    }

    // MARK: - State Persistence

    /// JP-leaf-decoded slot-preview text for a (scn,msg) pair: the first two prose lines
    /// decoded through sizfont so the preview fills the picker's 2x26-cell band (§27.7).
    /// Deliberately language-independent (M5.6 WP-1): a CN string must never enter the
    /// save file or the JP dot matrix — LeafCodec drops most CJK codepoints and the band
    /// would render half-glyphed. A ZH build shows its own preview by querying the store
    /// at *render* time (slot picker), keyed by the same (scn,msg) anchors.
    /// Returns nil when the (scn,msg) pair cannot be resolved.
    public func jpPreviewText(scn: Int, msg msgIndex: Int) -> String? {
        guard let msg = game.scn(scn)?.message(msgIndex) else { return nil }
        let lines = msg.segments.flatMap(\.lines).filter { !$0.isEmpty }
        if lines.isEmpty { return "SCN\(scn)" }
        return String(game.leafCodec.decode(Array(lines.prefix(2).joined())).prefix(52))
    }

    /// Capture current engine state for saving.
    public func captureSaveState(slot: Int, previewText: String? = nil) -> SaveState {
        let preview: String
        if let pt = previewText {
            preview = pt
        } else if let msg = currentMsg, let jp = jpPreviewText(scn: scnIndex, msg: msg.index) {
            // M5.6 WP-1: fixed JP leaf decode — the old "store hit ⇒ write CN" branch
            // poisoned the slot preview with CJK the dot matrix cannot encode (§2-B1 P0).
            preview = jp
        } else {
            preview = "SCN\(scnIndex) BLK\(blockIndex)"
        }

        return SaveState(
            version: 1,
            slot: slot,
            timestamp: Date(),
            previewText: preview,
            scnIndex: scnIndex,
            blockIndex: blockIndex,
            pc: pc,
            flags: flags,
            scene: scene,
            phase: phase,
            currentMsgIndex: currentMsg?.index,
            currentSegmentIndex: currentSegmentIndex,
            currentPage: currentPage,
            choices: choices,
            currentEnding: currentEnding,
            backlog: backlog,
            // M5.6 WP-1: the `language` field is no longer written — display language is
            // a build property, not save state. The Optional field stays in SaveState so
            // older saves (which carry it) keep decoding; version remains 1, zero migration.
            seenHighWater: seenHighWater
        )
    }

    /// Restore engine state from a SaveState.
    public func restoreSaveState(_ state: SaveState) {
        // M5.6 WP-1: `state.language` is deliberately ignored — loading a JP bookmark
        // into the ZH build (or vice versa) must keep the *build's* language and simply
        // re-present the same language-independent (scn,msg,segment) anchors.
        // The read high-water is monotonic and lives in the *system* file; a bookmark
        // can only ever raise it (older saves recorded nothing), never lower it.
        for (scn, hw) in state.seenHighWater ?? [:] {
            seenHighWater[scn] = max(seenHighWater[scn] ?? 0, hw)
        }
        scnIndex = state.scnIndex
        blockIndex = state.blockIndex
        pc = state.pc
        if state.flags.count == flags.count {
            flags = state.flags
        } else {
            for i in 0..<min(flags.count, state.flags.count) {
                flags[i] = state.flags[i]
            }
        }
        scene = state.scene
        pendingScene = nil
        transition = nil
        advanceQueuedDuringTransition = false
        eventPumpWanted = false
        phase = state.phase
        choices = state.choices
        currentEnding = state.currentEnding
        backlog = state.backlog

        // Reconstruct message pagination if in awaitingMessage
        if let msgIdx = state.currentMsgIndex, let msg = game.scn(scnIndex)?.message(msgIdx) {
            currentMsg = msg
            currentPages = msg.paginated(charsPerLine: textCharsPerLine, maxLines: textMaxLines)
            currentSegmentIndex = min(state.currentSegmentIndex ?? 0, max(0, msg.segments.count - 1))
            currentPage = min(currentSegmentIndex, max(0, currentPages.count - 1))
            // rebuildCNPresentation re-derives `cnCommitted` for the beats the save
            // had already parked past, so the CN layer lands on the saved beat.
            rebuildCNPresentation(msg)
        } else {
            currentMsg = nil
            currentPages = []
            currentPage = 0
            currentSegmentIndex = 0
            cnSlices = []
            cnCommitted = ""
        }

        // Resume or stop BGM
        if let bgm = scene.bgm {
            startScriptBGM(bgm, loop: true)
        } else {
            audio?.stopBGM()
        }
        refreshScreenFromCurrentSegment()
    }

    /// Rebuild the visible text for a restored `currentMsg` without re-firing its inline
    /// actions (they already shaped the restored `scene`). Saves are taken at an input prompt,
    /// so every segment before the saved one is complete and the saved one is fully revealed.
    private func refreshScreenFromCurrentSegment() {
        screenLines = []
        activeLines = []
        revealedGlyphs = 0
        guard let msg = currentMsg, currentSegmentIndex < msg.segments.count else { return }
        for i in 0..<currentSegmentIndex {
            let seg = msg.segments[i]
            if seg.pause == .pageBreak { screenLines = [] } else { screenLines.append(contentsOf: seg.lines) }
        }
        activeLines = msg.segments[currentSegmentIndex].lines
        revealedGlyphs = activeGlyphCount
        revealAccumulator = 0
    }

    /// Reset game variables for a new game, optionally keeping persistent system flags.
    /// The original `SizukuScenarioInit` clears only flag indices 2-6/9-13 (script
    /// 0x40-0x44/0x47-0x4a); the jingle record (0), 雑シナリオ flag (1), TRUE (0x45) and
    /// HAPPY (0x46) survive every scenario start (`sizuku.c:176-195`, GBA SRAM @0x10).
    public func reset(scn: Int = 1, block: Int = 0, keepPersistentFlags: Bool = true) {
        let f0 = flags[0]
        let f1 = flags[1]
        let f45 = flags[0x45]
        let f46 = flags[0x46]
        flags = [UInt8](repeating: 0, count: 256)
        if keepPersistentFlags {
            flags[0] = f0
            flags[1] = f1
            flags[0x45] = f45
            flags[0x46] = f46
        }
        scene = Scene()
        currentMsg = nil
        pendingBgm = nil
        bgmHoldSeconds = 0
        transition = nil
        pendingScene = nil
        backEffectActive = false
        backEffectState = 0
        subFollowUp = nil
        logoAnimationNumber = 0
        advanceQueuedDuringTransition = false
        eventPumpWanted = false
        flashTicks = 0
        shakeTicks = 0
        shakeDX = 0
        shakeDY = 0
        isCurrentMessageSeen = false
        currentPages = []
        currentPage = 0
        currentSegmentIndex = 0
        screenLines = []
        activeLines = []
        revealedGlyphs = 0
        revealAccumulator = 0
        textSpeed = ShizukuEngine.defaultTextSpeed
        choices = []
        currentEnding = nil
        backlog = []
        lastSelectSavePoint = nil
        lastPageSavePoint = nil
        start(scn: scn, block: block)
    }
}

extension Message {
    /// Printable label (leaf codes joined) for debugging/CLI.
    public var debugText: String {
        glyphLeafCodes.map { String(format: "%d", $0) }.joined(separator: " ")
    }
}
