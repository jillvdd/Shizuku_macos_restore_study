//
//  MetalGameView.swift — Metal-backed game view (the "Swift+Metal" render path).
//
//  Composes the engine Scene via SceneComposer into an RGBAImage, uploads it as a
//  texture, and draws a fullscreen quad with passthrough sampling.
//  Supports:
//    - Boot sequence: Leaf jingle → OP animation → title (sizuku_jingle.c / sizuku_op.c)
//    - Title Menu (New game, Continue, Endings gallery, Quit) on the original TITLE0+TITLE art
//    - In-Game dialog + Choice branch navigation with Up/Down arrow selection
//    - シナリオ回想 fullscreen history mode (scroll up / ESC menu item 4)
//    - Fast-Forward skip mode (Tab / Z)
//    - Quick Save (S / F5) and Quick Load (L / F9)
//    - Fullscreen toggle (Cmd-Ctrl-F)
//

import AppKit
import Metal
import MetalKit
import ShizukuCore
import ShizukuEngine
import ShizukuRender

enum GameMode {
    case booting
    case titleMenu
    case inGame
    case history
    case endingsList
    case escMenu
    case slotPicker
    case escConfirm
    case gallery
    case galleryZoom
    case musicRoom
    case staffRoll
    case logoAnimation
}

final class MetalGameView: MTKView, MTKViewDelegate {
    let engine: ShizukuEngine
    let composer: SceneComposer
    let saveManager: SaveManager
    let scale: Int
    let nativeWidth = 640
    let nativeHeight = 400

    var mode: GameMode = .titleMenu {
        didSet {
            // Invariant: the original's flip loop never stops, and a running
            // `LvnsClear`/`LvnsDisp` only finishes because that loop keeps ticking it.
            // Our mode machine can strand that loop (the ticker only pumps effects for
            // `.inGame`), so any return to the game screen must restore the flip source.
            // It stays up for the whole game screen, not just while an effect or a reveal
            // is in flight: the ▼ blink is flip-driven, so a ticker that only runs during
            // reveals leaves the cursor frozen on a settled page.
            if mode == .inGame { startTicker(); startWatchdog() }
            else { stopWatchdog() }
        }
    }
    var titleSelectionIndex: Int = 0
    /// -1 = "no option highlighted": the original never pre-selects a choice; only
    /// mouse hover (or a 1..9 jump press) sets a real index.
    var selectedChoiceIndex: Int = -1
    /// Browsing position in シナリオ回想 (`lvns->history` index); App-owned like the
    /// original's local `pos` in `LvnsHistoryMode`.
    var historyPos: Int = 0

    var toastMessage: String? = nil
    var toastTimer: Timer? = nil

    var isFastForward: Bool = false
    var fastForwardTimer: Timer? = nil
    /// Throttles writes of the read high-water into the system file (2 s at 60 Hz).
    var seenPersistTick = 0

    /// Configurable fast-forward hotkey (item 8). Default Tab (48). Also always Z (6)
    /// as a convenience secondary binding.
    var skipKeyCode: UInt16 = 48
    static let skipHotkeyChoices: [(label: String, code: UInt16)] = [
        ("Tab", 48), ("Z", 6), ("X", 7), ("C", 8), ("Shift", 56), ("Ctrl", 59),
    ]

    /// 早送り speed tiers (item 8). The original never waits for a click while `skip` is
    /// set (`LvnsWaitKey`/`LvnsWaitPage` return immediately, `LvnsText` skips
    /// `char_wait_time`), so its ceiling is one step per flip — 快 is exactly that
    /// 60 Hz pace; 中 is the pace we shipped before this setting existed. `zhLabel` is the
    /// menu-bar variant (WP-13); the tier the toast reports is whatever title the item has.
    static let fastForwardSpeedChoices: [(label: String, zhLabel: String, interval: TimeInterval)] = [
        ("遅い", "慢", 0.08), ("普通", "标准", 0.04), ("速い", "快", 1.0 / 60.0),
    ]
    var fastForwardSpeedTier: Int = 1
    var fastForwardInterval: TimeInterval { Self.fastForwardSpeedChoices[fastForwardSpeedTier].interval }

    // MARK: ESC system menu / しおり state (M4.7, sizuku_menu.c)
    enum SlotPurpose { case save, load }
    enum ConfirmKind { case loadSlot(Int), saveSlot(Int), end }
    var escSelectionIndex = 0
    var slotPurpose: SlotPurpose = .load
    var slotSelection = 0
    /// Real slot numbers behind the picker rows (load also lists quicksave/0).
    var pickerSlots: [Int] = Array(1...MetalGameView.slotCount)
    /// Where ESC/cancel inside the picker returns to (in-game flow: esc menu; title flow: title).
    var pickerReturnMode: GameMode = .escMenu
    var pendingConfirm: ConfirmKind? = nil
    var confirmSelection = 1          // 0 = はい, 1 = いいえ (default to いいえ)
    /// Mode the 「いいえ」/ESC path of the confirm dialog returns to.
    var confirmCancelMode: GameMode = .inGame
    var hideTextNow = false
    static let slotCount = 6

    // MARK: - 回想モード (title-menu CG gallery) state
    /// Full index of event images, built on first entry (`GameData.eventImages()`).
    var galleryItems: [EventImage] = []
    var galleryPage = 0
    var gallerySelection = 0
    /// Cell index enlarged in `.galleryZoom`.
    var galleryZoomIndex = 0
    /// Dissolve between grid and zoom views: `galleryFadeTick` counts up to
    /// `galleryFadeTicks`, then the target frame is shown as-is.
    var galleryFadeTick = 0
    var galleryFadeFrom: RGBAImage? = nil
    var galleryFadeTo: RGBAImage? = nil
    static let galleryFadeTicks = 16

    // MARK: 音楽モード (title-screen BGM room) state
    /// Slot shown in the upper card (演奏中の曲) — what the audio is actually doing.
    var musicPlaying = 0
    /// Slot shown in the lower card (選択中の曲) — what 「演奏」 will start.
    var musicSelected = 0
    /// Hovered button index, -1 for none (the original highlights under the cursor).
    var musicHovered = -1
    /// Screen palette multiplier in 16ths while the room fades in (16 -> `latitudeDark`).
    var musicLatitude = MusicRoom.latitudeDark
    /// Flips left of the 300 ms hold at full brightness, and whether the form is drawn yet.
    var musicIntroHold = 0
    var musicFormShown = true

    // MARK: エンディング staff roll state
    /// The 14-card credit sequence `0x7d` blocks the script on, and the game screen it
    /// fades out from (`CLEAR(FADE_PALETTE)` darkens what was already up).
    var staffPlayer: StaffRoll.Player?
    var staffOpeningFrame: RGBAImage?

    /// `0x01` kind-03 (`LvnsAnimation`): like the roll this blocks the interpreter, so it
    /// gets its own mode; the ticker owns the player end to end.
    var logoPlayer: LogoAnimation.Player?

    // MARK: Boot sequence state (60Hz ticks — original INTERVAL=60, Lvns.h:70)
    private enum BootStage: Int {
        case jingleFadeIn, jingleLeafIn, jingleWait, jingleSlide, jingleHold, jingleOut
        case opSizuku1, opV0In, opV0Hold, opV0Out
        case opSizuku2, opV1In, opV1Hold, opV1Out
        case opSizuku3, ruriko
        case titleIn, titleHold, titleMask
    }
    private var bootStage: BootStage = .jingleFadeIn
    private var bootTick = 0
    private var bootElapsed = 0
    /// `TIMER_WAIT 6000` budget captured when the hold is entered: the fixed number of
    /// flips that take the jingle from `TIMER_INIT` (its first flip) to 6000 ms. Recomputing
    /// `360 - bootElapsed` inside `bootStageDuration` every flip is wrong — `bootTick` climbs
    /// while the budget shrinks, so the two cross at the midpoint (~3.6 s) and cut the hold
    /// in half.
    private var jingleHoldBudget = 0
    private var ticker: Timer?
    private var cachedLeafCanvas: RGBAImage?
    private var cachedWindowCanvas: RGBAImage?
    private var cachedTitleArt: RGBAImage?
    private var cachedTitle0: RGBAImage?
    private var cachedOpLayers: [String: RGBAImage] = [:]

    private static let sizukuFrames = (0...16).map { String(format: "OP_S%02d.LFG", $0) }
    /// `LvnsAnimation` (`LvnsAnim.c:104-110`) holds each frame for `wait_time + 1` flips:
    /// the iteration that calls `Animation` displays the frame and sets
    /// `wait_time = time * INTERVAL / 1000`, then `wait_time-- > 0` burns that many more
    /// flips before the next frame. The `sizuku[]`/`ruriko[]` OP tables carry `time = 50`
    /// (`sizuku_op.c:22-96`), so `50 * 60 / 1000 = 3` pending + 1 display = 4 flips/frame
    /// (≈ 66.7 ms), not 3.
    static let opAnimFlipsPerFrame = 50 * 60 / 1000 + 1
    private static let rurikoSequence: [Int] = {
        var f: [Int] = []
        for _ in 0..<6 { f += [0, 1, 2, 1] }   // L0,L1,L2,L1 blink x6
        f += [0, 3, 4, 5]
        for _ in 0..<3 { f += [6, 7, 8, 7] }   // L6,L7,L8,L7 x3
        return f
    }()

    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState
    private let quadVertexBuffer: MTLBuffer
    private var frameTexture: MTLTexture?
    private var frameSize = (w: 0, h: 0)

    init(extractedDir: String, scale: Int) {
        let game = GameData(extractedDir: extractedDir)
        let audio = AudioController(baseDir: extractedDir)
        let saveMgr = SaveManager()
        self.saveManager = saveMgr
        self.engine = ShizukuEngine(game: game, audio: audio, saveManager: saveMgr)
        self.composer = SceneComposer(game: game, scale: scale)
        self.scale = scale

        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal 设备不可用")
        }
        let queue = device.makeCommandQueue()!
        self.commandQueue = queue

        let shaders = """
        #include <metal_stdlib>
        using namespace metal;
        struct VOut { float4 pos [[position]]; float2 uv; };
        vertex VOut vs_quad(uint vid [[vertex_id]], constant float4* verts [[buffer(0)]]) {
            VOut o;
            float4 p = verts[vid];
            o.pos = float4(p.x, p.y, 0, 1);
            o.uv = float2(p.z, p.w);
            return o;
        }
        fragment float4 fs_passthrough(VOut in [[stage_in]], texture2d<float> tex [[texture(0)]]) {
            constexpr sampler s(mag_filter::nearest, min_filter::nearest, address::clamp_to_edge);
            return tex.sample(s, in.uv);
        }
        """
        let lib = try! device.makeLibrary(source: shaders, options: nil)
        let vfn = lib.makeFunction(name: "vs_quad")!
        let ffn = lib.makeFunction(name: "fs_passthrough")!
        let pso = try! device.makeRenderPipelineState(descriptor: {
            let d = MTLRenderPipelineDescriptor()
            d.vertexFunction = vfn
            d.fragmentFunction = ffn
            d.colorAttachments[0].pixelFormat = .bgra8Unorm
            return d
        }())
        self.pipelineState = pso

        let quad: [Float] = [
            -1, -1, 0, 1,
             1, -1, 1, 1,
            -1,  1, 0, 0,
             1,  1, 1, 0,
        ]
        self.quadVertexBuffer = device.makeBuffer(bytes: quad, length: quad.count * 4, options: [])!

        super.init(frame: .zero, device: device)
        self.delegate = self
        self.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        self.colorPixelFormat = .bgra8Unorm
        self.enableSetNeedsDisplay = true
        self.framebufferOnly = true

        // Apply persistent global system data (e.g. unlocked endings, flag 0x46)
        saveManager.applyGlobalSystem(to: engine)
        // Display language is a build-time constant (M5.6 WP-2): the engine seeds
        // itself from `BuildLanguage.current`; system.json never reads or writes it.
        // Apply persisted skip settings (item 8).
        let sys0 = saveManager.loadGlobalSystem()
        engine.fastWhenSeen = sys0.fastWhenSeen ?? false
        engine.forceSkip = sys0.forceSkip ?? false
        engine.effectsEnabled = sys0.effectsEnabled ?? true
        skipKeyCode = sys0.skipHotkey ?? 48
        fastForwardSpeedTier = min(max(sys0.fastForwardSpeed ?? 1, 0), Self.fastForwardSpeedChoices.count - 1)

        if ProcessInfo.processInfo.environment["SHIZUKU_SKIP_BOOT"] != nil ||
           ProcessInfo.processInfo.environment["SHIZUKU_DUMP_FRAME"] != nil ||
           ProcessInfo.processInfo.environment["SHIZUKU_SHOT"] != nil {
            startTitleMenu()
        } else {
            // Jingle -> OP -> Title, as `LvnsMain` does when start_scn_num < 0.
            startBoot()
        }

        if let p = ProcessInfo.processInfo.environment["SHIZUKU_DUMP_FRAME"] {
            needsDisplay = true
            var img: RGBAImage
            switch mode {
            case .titleMenu: img = titleFrame()
            case .booting: img = bootFrame()
            default: img = composer.render(engine)
            }
            try? img.encodePNG().write(to: URL(fileURLWithPath: p))
        }
    }

    required init(coder: NSCoder) { fatalError("not supported") }

    // MARK: - Settings (item 8) — original menu semantics, exposed via the Mac menu bar

    private func persistSystem(_ mutate: (inout GlobalSystemData) -> Void) {
        var sys = saveManager.loadGlobalSystem()
        mutate(&sys)
        try? saveManager.saveGlobalSystem(sys)
    }

    @objc func toggleFastWhenSeen() {
        engine.fastWhenSeen.toggle()
        persistSystem { $0.fastWhenSeen = engine.fastWhenSeen }
        showToast("既読テキスト自動スキップ [\(engine.fastWhenSeen ? "ON" : "OFF")]")
    }

    @objc func toggleForceSkip() {
        engine.forceSkip.toggle()
        persistSystem { $0.forceSkip = engine.forceSkip }
        showToast("早送り未読スキップ [\(engine.forceSkip ? "ON" : "OFF")]")
    }

    /// The reference engine's own `-n e` switch (`mgMain.c:76-79`): effects stay wired up
    /// but every animated wipe collapses to a single full-screen blit.
    @objc func toggleEffectsEnabled() {
        engine.effectsEnabled.toggle()
        persistSystem { $0.effectsEnabled = engine.effectsEnabled }
        showToast("画面エフェクト [\(engine.effectsEnabled ? "ON" : "OFF")]")
    }

    /// AppKit renames an item wired straight to `NSWindow.toggleFullScreen(_:)` to its own
    /// "Enter/Exit Full Screen" string, which drops the Chinese gloss the rest of the menu
    /// carries. Routing through our own selector keeps the label; the key equivalent lives
    /// on the item, so ⌃F is unaffected.
    @objc func toggleFullScreenFromMenu() {
        window?.toggleFullScreen(nil)
    }

    @objc func setSkipHotkeyFromMenu(_ sender: NSMenuItem) {
        let code = UInt16(sender.tag)
        skipKeyCode = code
        persistSystem { $0.skipHotkey = code }
        showToast("スキップキーを \(sender.title) に変更")
    }

    @objc func setFastForwardSpeedFromMenu(_ sender: NSMenuItem) {
        fastForwardSpeedTier = sender.tag
        persistSystem { $0.fastForwardSpeed = sender.tag }
        showToast("早送り速度 [\(sender.title)]")
        // Changing pace mid-run takes effect on the next message.
        if isFastForward { startFastForward() }
    }

    // MARK: - Boot sequence (M4.6)

    func startBoot() {
        mode = .booting
        bootStage = .jingleFadeIn
        bootTick = 0
        bootElapsed = 0
        // Jingle = MUS00.OGG, 5.5s, single-shot (LvnsStartMusic never loops).
        engine.audio?.playBGM(number: 0, loop: false)
        startTicker()
        needsDisplay = true
    }

    /// Stage durations in 60Hz ticks, from the original tables:
    /// palette fade = 16 steps + 1, WHITEIN = 17 + 1, WAIT ms -> ms*60/1000 truncated.
    private func bootStageDuration(_ stage: BootStage) -> Int {
        switch stage {
        case .jingleFadeIn: return 17
        case .jingleLeafIn: return 18
        case .jingleWait: return 7            // WAIT 120ms
        case .jingleSlide: return 32          // LOOP_FUNC Slide, 20px/tick over 640
        case .jingleHold: return jingleHoldBudget   // TIMER_WAIT 6000ms total (captured at entry)
        case .jingleOut: return 17
        case .opSizuku1, .opSizuku2, .opSizuku3: return MetalGameView.sizukuFrames.count * MetalGameView.opAnimFlipsPerFrame
        case .ruriko: return MetalGameView.rurikoSequence.count * MetalGameView.opAnimFlipsPerFrame
        case .opV0In, .opV1In, .titleIn: return 17      // DISP_VRAM FADE_PALETTE
        case .opV0Hold, .opV1Hold: return 120           // WAIT 2000ms
        case .opV0Out, .opV1Out: return 17              // CLEAR FADE_PALETTE
        case .titleHold: return 60                      // WAIT 1000ms
        case .titleMask: return 32                      // DISP_VRAM FADE_MASK
        }
    }

    private func advanceBoot() {
        bootTick += 1
        bootElapsed += 1
        if bootTick >= bootStageDuration(bootStage) {
            guard let next = BootStage(rawValue: bootStage.rawValue + 1) else {
                enterTitleMenu()
                return
            }
            bootStage = next
            bootTick = 0
            if next == .jingleHold {
                // `TIMER_WAIT 6000` counts from `TIMER_INIT` (the jingle's first flip), so
                // the hold fills the remainder of the 360-flip budget.
                jingleHoldBudget = max(0, 360 - bootElapsed)
            }
            if next == .opSizuku1 {
                // OP music = CD track 16 -> MUS14.OGG ("オープニング"), one-shot, no loop.
                // It is never stopped; it simply ends under the title, as in the original.
                engine.audio?.playBGM(number: 14, loop: false)
            }
        }
    }

    private func enterTitleMenu() {
        stopTicker()
        mode = .titleMenu
        titleSelectionIndex = 0
        needsDisplay = true
    }

    /// `LvnsScript.c:29-40` CLICK_JUMP: a click rewinds the script PC to the *next*
    /// CLICK_JUMP marker, so it skips only the current stage — never the whole boot.
    /// The jingle and the OP each carry one marker (sizuku_jingle.c:88-111,
    /// sizuku_op.c:255-291); the OP's tail is a WAIT_CLICK that opens the title menu.
    private func skipBoot() {
        switch bootStage {
        case .jingleFadeIn, .jingleLeafIn, .jingleWait, .jingleSlide, .jingleHold:
            bootStage = .jingleOut
            bootTick = 0
        case .jingleOut, .opSizuku1, .opV0In, .opV0Hold, .opV0Out, .opSizuku2,
             .opV1In, .opV1Hold, .opV1Out, .opSizuku3, .ruriko:
            bootStage = .titleIn
            bootTick = 0
        case .titleIn, .titleHold, .titleMask:
            enterTitleMenu()
        }
    }

    private func leafCanvas() -> RGBAImage {
        if let c = cachedLeafCanvas { return c }
        let c = composer.bootCanvas(layers: [("LEAF.LFG", 80, 144)])
        cachedLeafCanvas = c
        return c
    }

    private func windowCanvas() -> RGBAImage {
        if let c = cachedWindowCanvas { return c }
        let c = composer.jingleWindowCanvas()
        cachedWindowCanvas = c
        return c
    }

    private func title0Canvas() -> RGBAImage {
        if let c = cachedTitle0 { return c }
        let c = composer.bootCanvas(layers: [("TITLE0.LFG", 0, 0)])
        cachedTitle0 = c
        return c
    }

    private func opLayerCanvas(_ name: String) -> RGBAImage {
        if let c = cachedOpLayers[name] { return c }
        let c = composer.bootCanvas(layers: [(name, 0, 0)])
        cachedOpLayers[name] = c
        return c
    }

    func bootFrame() -> RGBAImage {
        let black = composer.solidCanvas(r: 0, g: 0, b: 0)
        let white = composer.solidCanvas(r: 255, g: 255, b: 255)
        let t = bootTick
        switch bootStage {
        case .jingleFadeIn:   // ClearWhite + FADE_PALETTE: black -> white
            return SceneComposer.blend(black, white, num: t, den: 17)
        case .jingleLeafIn:   // WHITEIN: white screen dissolves to LEAF logo on black
            return SceneComposer.blend(white, leafCanvas(), num: t, den: 18)
        case .jingleWait:
            return leafCanvas()
        case .jingleSlide:    // LoadTitle2 + Slide: new frame wipes in from both edges
            return composer.slideReveal(base: windowCanvas(), hidden: leafCanvas(), state: t)
        case .jingleHold:
            return windowCanvas()
        case .jingleOut:      // CLEAR FADE_PALETTE -> black
            return SceneComposer.blend(windowCanvas(), black, num: t, den: 17)
        case .opSizuku1, .opSizuku2, .opSizuku3:  // ANIM sizuku[] — 涙の雫 frames at (0,160)
            let i = min(MetalGameView.sizukuFrames.count - 1, t / MetalGameView.opAnimFlipsPerFrame)
            return composer.bootCanvas(layers: [(MetalGameView.sizukuFrames[i], 0, 160)])
        case .opV0In:
            return SceneComposer.blend(black, opLayerCanvas("OP_V0.LFG"), num: t, den: 17)
        case .opV0Hold:
            return opLayerCanvas("OP_V0.LFG")
        case .opV0Out:
            return SceneComposer.blend(opLayerCanvas("OP_V0.LFG"), black, num: t, den: 17)
        case .opV1In:
            return SceneComposer.blend(black, opLayerCanvas("OP_V1.LFG"), num: t, den: 17)
        case .opV1Hold:
            return opLayerCanvas("OP_V1.LFG")
        case .opV1Out:
            return SceneComposer.blend(opLayerCanvas("OP_V1.LFG"), black, num: t, den: 17)
        case .ruriko:         // ANIM ruriko[] — 40 LFG frames at (0,0)
            let i = min(MetalGameView.rurikoSequence.count - 1, t / MetalGameView.opAnimFlipsPerFrame)
            return composer.bootCanvas(layers: [(String(format: "OP_L%d.LFG", MetalGameView.rurikoSequence[i]), 0, 0)])
        case .titleIn:        // TITLE0 fades up from black
            return SceneComposer.blend(black, title0Canvas(), num: t, den: 17)
        case .titleHold:
            return title0Canvas()
        case .titleMask:      // TITLE overlaid via FADE_MASK (linear dissolve)
            return SceneComposer.blend(title0Canvas(), composer.titleBackdrop(), num: t, den: 32)
        }
    }

    /// Title menu table + its first text line. Drawing and hit-testing read the same
    /// table so a click can only land on a row that was actually painted. The rows sit
    /// on lines 7..11, i.e. below the red 「雫」 logo, ending 16 px above the frame edge.
    /// M5.6 WP-7a: the table is the build language's — JP rows are the original leaf
    /// codes verbatim, ZH rows are native-font strings (`ShellText`).
    static let titleMenuFirstLine = 7
    var titleMenuRows: [MenuRow] { ShellText.titleRows(composer.language) }
    /// The yes/no pair, drawn by `SceneComposer.drawConfirm` on lines 6..7.
    var confirmRows: [MenuRow] { ShellText.confirmRows(composer.language) }
    /// The six-item system menu, lines 3..8.
    var escMenuRows: [MenuRow] { ShellText.escRows(composer.language) }

    /// Title screen: TITLE0+TITLE art dimmed to latitude_dark (11/16, LvnsMenu lowers
    /// palette brightness while a menu is up) with the dot-matrix items over it.
    func titleFrame() -> RGBAImage {
        var img: RGBAImage
        if let c = cachedTitleArt {
            img = c
        } else {
            img = composer.titleBackdropDimmed()
            cachedTitleArt = img
        }
        for (i, row) in titleMenuRows.enumerated() {
            composer.drawMenuRow(into: &img, row: row, line: MetalGameView.titleMenuFirstLine + i,
                                 selected: i == titleSelectionIndex)
        }
        // The 5th title item stays invisible, exactly as `0x30f0c` defines it: an `X56Y128`
        // cell whose only content is a space glyph. It is still hit-tested on click below.
        return img
    }

    // MARK: - 60Hz ticker (boot animation + text reveal)

    /// One reference flip (`#define INTERVAL 60`).
    static let tickerInterval = 1.0 / 60.0
    /// Monotonic seconds, unaffected by wall-clock adjustments and NTP slewing.
    static func now() -> TimeInterval { ProcessInfo.processInfo.systemUptime }
    /// Wall-clock anchor of the previous ticker fire.
    private var tickerAnchor: TimeInterval = 0

    private func startTicker() {
        guard ticker == nil else { return }
        // App Nap throttles a backgrounded process's timers to roughly one fire per second,
        // and `consumeElapsedFlips` caps catch-up at 5 flips — so a napped window presents
        // at 1/12 speed: the ▼ blinks once per 1.2 s and a page crawls in ~30 s. That is the
        // reported "everything became too slow", and it is intermittent because it depends
        // on focus and occlusion, not on any constant. The assertion is held only while the
        // ticker is live, so a closed game screen lets the system nap again.
        activityAssertion = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .latencyCritical],
            reason: "60 Hz reference flip loop (Lvns INTERVAL)")
        tickerAnchor = Self.now()
        ticker = scheduleTimer(Self.tickerInterval, repeats: true) { [weak self] _ in
            self?.tickerFire()
        }
    }

    /// `Timer.scheduledTimer` attaches to the run loop in `.default` mode only, so a timer
    /// created from `mouseDown` stalls for as long as the button is held or a menu is open —
    /// which is why transitions never animated and the frame froze until another click.
    /// `.common` covers the event-tracking modes.
    private func scheduleTimer(_ interval: TimeInterval, repeats: Bool,
                               _ action: @escaping (Timer) -> Void) -> Timer {
        let t = Timer(timeInterval: interval, repeats: repeats, block: action)
        t.tolerance = interval / 2   // lets the run loop coalesce wakes without losing beats
        RunLoop.main.add(t, forMode: .common)
        return t
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
        if let assertion = activityAssertion {
            ProcessInfo.processInfo.endActivity(assertion)
            activityAssertion = nil
        }
    }

    /// Keeps App Nap from throttling the flip loop; see `startTicker`.
    private var activityAssertion: NSObjectProtocol?

    // MARK: - Flip-stall watchdog (项3/项4 field evidence)

    /// Wall clock of the last ticker fire that actually produced flips.
    private var lastFlipStamp: TimeInterval = 0
    private var watchdogTimer: Timer?
    private var watchdogLastLog: TimeInterval = 0
    /// Recent advances with the engine state each one met — a swallowed click is only
    /// provable against that state.
    private var advanceRing: [String] = []
    private static let watchdogRingMax = 24

    /// Lives on the main run loop like the ticker, but on its own: the reported symptom is
    /// "I had to press again before it moved", i.e. the main thread is *alive* and the flip
    /// source is not. A blocked main thread would show as "not responding" instead, and no
    /// main-thread probe would run anyway.
    private func startWatchdog() {
        guard watchdogTimer == nil else { return }
        lastFlipStamp = Self.now()
        watchdogTimer = scheduleTimer(1.0, repeats: true) { [weak self] _ in
            self?.watchdogFire()
        }
    }

    private func stopWatchdog() {
        watchdogTimer?.invalidate()
        watchdogTimer = nil
    }

    /// Only a stall *while the engine still owns work* is a defect: a page waiting for the
    /// reader has no reason to flip. Logged once, then at most every 5 s while it persists.
    private func watchdogFire() {
        guard mode == .inGame else { return }
        let now = Self.now()
        let busy = engine.transition != nil || engine.isRevealing || isFastForward
        if !busy {
            lastFlipStamp = now
            return
        }
        let stalled = now - lastFlipStamp
        guard stalled > 2.0, now - watchdogLastLog > 5.0 else { return }
        watchdogLastLog = now
        noteAdvance("WATCHDOG stalled=\(String(format: "%.1f", stalled))s")
        dumpAdvanceRing(stalled: stalled)
        // The reference flip loop never stops, so a stalled one is a defect to correct rather
        // than a state to preserve: the reader should not have to press twice to be heard.
        // Restart unconditionally — `ticker != nil` in the log line above is what tells the
        // two cases apart (timer gone vs. timer alive but not firing).
        stopTicker()
        startTicker()
        needsDisplay = true
    }

    /// Records the screen-owning state plus the recent advance history and appends it to
    /// `~/Library/Logs/Shizuku_Restored/diagnostic.log`, so a player only has to say "it
    /// froze" — the evidence is already on disk when we ask.
    private func noteAdvance(_ tag: String) {
        let tr = engine.transition.map {
            "transition=\($0.phase) state=\($0.state) clear=\($0.clearEffect.map { String(describing: $0) } ?? "-") " +
            "disp=\($0.dispEffect.map { String(describing: $0) } ?? "-") " +
            "from=\($0.fromScene.bgName ?? $0.fromScene.bgHName ?? "nil")"
        } ?? "transition=nil"
        let line = "\(tag) scn=\(engine.scnIndex) blk=\(engine.blockIndex) pc=\(engine.pc) " +
            "phase=\(engine.phase) shown=\(engine.scene.bgName ?? engine.scene.bgHName ?? "nil") " +
            "staged=\(engine.stagedImageName ?? "nil") \(tr) " +
            "reveal=\(engine.isRevealing) skip=\(engine.skip) ff=\(isFastForward) " +
            "pump=\(engine.eventPumpWanted) ticker=\(ticker != nil) wait=\(engine.waitingPause.map { String(describing: $0) } ?? "-")"
        advanceRing.append(line)
        if advanceRing.count > Self.watchdogRingMax { advanceRing.removeFirst() }
    }

    /// On a real stall the whole ring goes to `~/Library/Logs/Shizuku_Restored/diagnostic.log`
    /// (and stderr), so a player only has to say "it froze" — the evidence is on disk by then.
    private func dumpAdvanceRing(stalled: TimeInterval) {
        let body = "\n[\(Date().description(with: .current))] flip source silent " +
            "\(String(format: "%.1f", stalled))s; last \(advanceRing.count) engine hand-offs:\n" +
            advanceRing.joined(separator: "\n") + "\n"
        FileHandle.standardError.write(Data("DIAG \(body)".utf8))
        guard let url = Self.diagnosticURL() else { return }
        let data = Data(body.utf8)
        if let h = try? FileHandle(forWritingTo: url) {
            h.seekToEndOfFile()
            h.write(data)
            try? h.close()
        } else {
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                     withIntermediateDirectories: true)
            try? data.write(to: url)
        }
    }

    private static func diagnosticURL() -> URL? {
        guard let lib = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first
        else { return nil }
        return lib.appendingPathComponent("Logs/Shizuku_Restored/diagnostic.log")
    }

    /// `SHIZUKU_PERF=1`: report the achieved flip rate. Every timed value on screen (▼
    /// blink, glyph reveal, effect decay) is flip-driven, so a "too slow" complaint is
    /// either a wrong constant or a starved run loop — this tells the two apart.
    static let perfEnabled = ProcessInfo.processInfo.environment["SHIZUKU_PERF"] != nil
    private var perfFlips = 0
    private var perfAnchor: TimeInterval = 0
    /// Set by the `perfrun` probe so the fire-level counters below only accumulate when
    /// someone is actually reading them.
    var perfRuns = false
    private var perfFires = 0
    private var perfZeroFires = 0
    private var perfMaxFlips = 0

    private func reportPerf(flips: Int) {
        guard Self.perfEnabled else { return }
        let t = Self.now()
        if perfAnchor == 0 { perfAnchor = t }
        perfFlips += flips
        guard t - perfAnchor >= 2 else { return }
        let rate = Double(perfFlips) / (t - perfAnchor)
        FileHandle.standardError.write(Data("PERF flip rate \(String(format: "%.1f", rate)) /s (target 60.0)\n".utf8))
        perfAnchor = t
        perfFlips = 0
    }

    /// Flips elapsed since the last fire. A `Timer` on a busy main thread fires *late*, never
    /// early, and macOS coalesces those wakes: counting one flip per fire made the whole
    /// presentation drift below the reference 60 Hz, so the ▼ blink and the glyph reveal ran
    /// at whatever frame rate AppKit happened to give us (the reported "too slow" symptom).
    /// Anchoring on the monotonic clock keeps every timed value on wall-clock time instead.
    /// Capped so a long stall (menu, app nap) does not burst-catch-up.
    private func consumeElapsedFlips() -> Int {
        let now = Self.now()
        let elapsed = now - tickerAnchor
        let flips = min(Int(elapsed / Self.tickerInterval), 5)
        if perfRuns {
            perfFires += 1
            if flips == 0 { perfZeroFires += 1 }
            perfMaxFlips = max(perfMaxFlips, flips)
        }
        guard flips > 0 else { return 0 }
        tickerAnchor += Double(flips) * Self.tickerInterval
        return flips
    }

    private func tickerFire() {
        let flips = consumeElapsedFlips()
        reportPerf(flips: flips)
        guard flips > 0 else { return }
        lastFlipStamp = Self.now()
        if mode == .booting {
            for _ in 0..<flips { advanceBoot() }
            needsDisplay = true
            return
        }
        if mode == .inGame {
            // The ticker drives every timed piece of the presentation: glyph reveal,
            // 'F'/'Q' effect decay, 'Mw' music hold and the ▼ blink — so it keeps
            // running for the whole time the game screen is up, like the original's
            // main flip loop.
            for _ in 0..<flips { engine.tickReveal(deltaTime: Self.tickerInterval) }
            if engine.consumeEventPumpRequest() { run() }
            seenPersistTick += flips
            if seenPersistTick >= 120 {
                seenPersistTick = 0
                saveManager.persistSeenHighWater(engine.seenHighWater)
            }
            needsDisplay = true
            return
        }
        if mode == .staffRoll {
            // The roll is a blocking flip loop in the original, so the ticker is its clock
            // for the whole ~105 s: no mode change, no input, nothing shortens a hold.
            guard var p = staffPlayer else { stopTicker(); return }
            p.tick(flips: flips)
            staffPlayer = p
            needsDisplay = true
            if p.isFinished { closeStaffRoll() }
            return
        }
        if mode == .logoAnimation {
            // `LvnsAnimation` is the same kind of blocking flip loop (`LvnsAnim.c:43-111`):
            // it polls no input, and `skip` only zeroes pending waits.
            guard var p = logoPlayer else { stopTicker(); return }
            p.tick(flips: flips, skip: engine.skip)
            logoPlayer = p
            needsDisplay = true
            if p.isFinished { closeLogoAnimation() }
            return
        }
        if mode == .musicRoom {
            // The room is a still after its fade-in, so pump only the intro and let the
            // ticker go — a 60 Hz re-blit of a 504x400 plate for a static form is waste.
            for _ in 0..<flips where !musicFormShown { stepMusicIntro() }
            needsDisplay = true
            if musicFormShown { stopTicker() }
            return
        }
        if mode == .gallery || mode == .galleryZoom {
            // The gallery is static art: pump only its grid<->zoom dissolve, then let
            // the ticker go so 12 resampled thumbnails don't redraw at 60 Hz.
            galleryFadeTick += flips
            guard galleryFadeTick < Self.galleryFadeTicks else {
                stopTicker()
                needsDisplay = true
                return
            }
            needsDisplay = true
            return
        }
        stopTicker()
    }

    func startTitleMenu() {
        mode = .titleMenu
        titleSelectionIndex = 0
        isFastForward = false
        hideTextNow = false
        pendingConfirm = nil
        stopFastForward()
        stopTicker()
        engine.scene.portraits.removeAll()
        engine.currentMsg = nil
        // The original title screen starts no music (OP track simply ends under it).
        engine.audio?.stopBGM()
        needsDisplay = true
    }

    @objc func startNewGame() {
        mode = .inGame
        titleSelectionIndex = 0
        selectedChoiceIndex = -1
        hideTextNow = false
        engine.reset(scn: 1, block: 1, keepPersistentFlags: true)
        run()
    }

    func loadSave(slot: Int = 0) {
        do {
            try saveManager.load(slot: slot, into: engine)
            mode = .inGame
            selectedChoiceIndex = -1
            hideTextNow = false
            showToast("セーブデータをロードしました [SLOT \(slot)]")
            run()
        } catch {
            showToast("セーブデータが見つかりません")
            needsDisplay = true
        }
    }

    /// つづきから: open a load picker covering every save kind (quicksave,
    /// しおり 1..6) so the reader chooses which save to resume instead of having the
    /// newest one force-loaded. Shows a toast when no save exists yet.
    @objc func chooseSaveToContinue() {
        guard mode == .titleMenu || mode == .inGame else { return }
        guard !saveManager.listSaves().isEmpty else {
            showToast("セーブデータがありません")
            needsDisplay = true
            return
        }
        openSlotPicker(purpose: .load, returnTo: mode)
    }

    private func openSlotPicker(purpose: SlotPurpose, returnTo: GameMode) {
        slotPurpose = purpose
        pickerSlots = purpose == .load
            ? [0] + Array(1...MetalGameView.slotCount)
            : Array(1...MetalGameView.slotCount)
        slotSelection = 0
        pickerReturnMode = returnTo
        mode = .slotPicker
        needsDisplay = true
    }

    @objc func quickSave() {
        do {
            try saveManager.save(slot: 0, engine: engine)
            showToast("クイックセーブ完了 [SLOT 0]")
        } catch {
            showToast("セーブに失敗しました")
        }
    }

    @objc func quickLoad() { loadSave(slot: 0) }

    func showToast(_ message: String) {
        toastMessage = message
        toastTimer?.invalidate()
        toastTimer = scheduleTimer(2.0, repeats: false) { [weak self] _ in
            self?.toastMessage = nil
            self?.needsDisplay = true
        }
        needsDisplay = true
    }

    @objc func toggleFastForward() {
        if isFastForward {
            showToast("スキップモード [OFF]")
            stopFastForward()
            return
        }
        // Engagement gate, verbatim from `LvnsSkipTillSelect`: refuses unless the current
        // message is already read — unless 「早送り未読スキップ」(forceSkip) is enabled.
        // Once engaged the run does not stop for unread pages; it carries on to the next
        // 選択肢 (`LvnsWaitSelect` is what clears `skip`), per the author's ruling.
        if !engine.forceSkip && !engine.isCurrentMessageSeen {
            showToast("未読です。設定で未読スキップを有効に")
            return
        }
        isFastForward = true
        engine.skip = true   // `lvns->skip`: engine/render fast path while skipping
        showToast("スキップモード [ON]")
        startFastForward()
    }

    private func startFastForward() {
        fastForwardTimer?.invalidate()
        fastForwardTimer = scheduleTimer(fastForwardInterval, repeats: true) { [weak self] _ in
            guard let self = self, self.isFastForward else { return }
            if self.mode != .inGame {
                self.stopFastForward()
                return
            }
            if self.engine.phase == .awaitingChoice || self.engine.phase == .ended {
                self.stopFastForward()
                return
            }
            if self.engine.isRevealing {
                self.engine.revealAll()
                self.needsDisplay = true
            }
            self.advance()
        }
    }

    private func stopFastForward() {
        isFastForward = false
        engine.skip = false
        fastForwardTimer?.invalidate()
        fastForwardTimer = nil
        needsDisplay = true
    }

    /// Run opcodes until a yield (message/choice/end) or until an image transition
    /// owns the screen (the original blocks its interpreter inside LvnsClear/LvnsDisp).
    func run() {
        var guardCount = 0
        while engine.phase == .running && engine.transition == nil && guardCount < 20000 {
            _ = engine.step()
            guardCount += 1
        }
        if engine.transition != nil {
            // The 60 Hz ticker pumps the effect; run() resumes via eventPumpWanted.
            startTicker()
        }
        if engine.phase == .staffRoll {
            // `0x7d`: `SizukuEnding` blocks the original's interpreter, so nothing after it
            // runs until the roll's `WAIT_CLICK` press and trailing fade are done.
            openStaffRoll()
            return
        }
        if engine.phase == .logoAnimation {
            // `0x01` kind-03: same blocking shape, one insert table.
            openLogoAnimation()
            return
        }
        if engine.phase == .awaitingChoice {
            // Original fidelity: a fresh choice shows NO highlighted option until the
            // mouse hovers one (or a number key jumps). -1 = none.
            selectedChoiceIndex = -1
            stopFastForward()
        }
        if engine.isRevealing {
            if engine.fastWhenSeen && engine.isCurrentMessageSeen && !isFastForward {
                // 既読テキスト自動略し: previously-read text appears instantly, but the
                // reader still pages through it with clicks.
                engine.revealAll()
            } else {
                startTicker()   // drive per-glyph reveal at 60Hz like the original char_wait_time
            }
        }
        needsDisplay = true
    }

    // MARK: - MTKViewDelegate

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    /// The composed frame for the current mode (shared by Metal draw and PNG export).
    func currentFrame() -> RGBAImage {
        var rgba: RGBAImage
        switch mode {
        case .booting:
            rgba = bootFrame()
        case .titleMenu:
            rgba = titleFrame()
        case .escMenu:
            rgba = composer.render(engine, hideText: true)
            composer.drawEscMenu(into: &rgba, selectedIndex: escSelectionIndex)
        case .slotPicker:
            // Opened from the title flow the picker must sit on the title art,
            // not on the stale engine state left behind from a previous play.
            rgba = pickerReturnMode == .titleMenu ? composer.titleBackdrop()
                                                  : composer.render(engine, hideText: true)
            composer.drawSlotPicker(into: &rgba,
                                    header: ShellText.slotHeader(save: slotPurpose == .save, composer.language),
                                    rows: slotRows(),
                                    selectedIndex: slotSelection)
        case .escConfirm:
            rgba = pickerReturnMode == .titleMenu ? composer.titleBackdrop()
                                                  : composer.render(engine, hideText: true)
            let headerKind: ShellConfirmKind
            switch pendingConfirm {
            case .loadSlot: headerKind = .load
            case .saveSlot: headerKind = .save
            case .end, .none: headerKind = .end
            }
            composer.drawConfirmMenu(into: &rgba, header: ShellText.confirmHeader(headerKind, composer.language),
                                     selectedIndex: confirmSelection)
        case .endingsList:
            // Backdrop only — `titleFrame()` paints the menu rows, and the overlay's
            // `blendBlack(215)` leaves the white *selected* row faintly showing through
            // the middle of the list.
            rgba = composer.titleBackdrop()
            let sys = saveManager.loadGlobalSystem()
            composer.drawEndingListOverlay(into: &rgba, clearedEndings: sys.clearedEndings)
        case .inGame:
            if let trs = engine.transition {
                // LvnsClear/LvnsDisp own the screen: image layer only, no text.
                rgba = composer.renderTransitionFrame(trs, engine: engine)
            } else {
                rgba = composer.render(engine, selectedChoice: selectedChoiceIndex, hideText: hideTextNow)
            }
        case .gallery, .galleryZoom:
            if let from = galleryFadeFrom, let to = galleryFadeTo, galleryFadeTick < Self.galleryFadeTicks {
                rgba = SceneComposer.blend(from, to, num: galleryFadeTick, den: Self.galleryFadeTicks)
            } else {
                galleryFadeFrom = nil
                galleryFadeTo = nil
                rgba = gallerySettledFrame()
            }
        case .history:
            // LvnsHistoryMode: the image layer stays, the text vram is cleared
            // (`LvnsClearText`) and refilled with the one browsed message. With an
            // empty history the original still draws the two nav glyphs.
            let backdrop = composer.render(engine, hideText: true)
            let entry = HistoryView.entry(from: engine.backlog, pos: historyPos)
                ?? HistoryView.Entry(lines: [], isFirst: true, isLast: true)
            rgba = HistoryView.render(game: engine.game, backdrop: backdrop,
                                      entry: entry, scale: scale,
                                      cnText: engine.translatedText(scn: entry.scn, msg: entry.msg))
        case .musicRoom:
            rgba = MusicRoom.render(game: engine.game, playing: musicPlaying,
                                    selected: musicSelected, hovered: musicHovered,
                                    latitude: musicLatitude, formShown: musicFormShown,
                                    scale: scale, lang: composer.language)
        case .staffRoll:
            rgba = StaffRoll.render(game: engine.game,
                                    player: staffPlayer ?? StaffRoll.Player(effectsEnabled: engine.effectsEnabled),
                                    openingFrame: staffOpeningFrame, scale: scale)
        case .logoAnimation:
            rgba = LogoAnimation.render(game: engine.game,
                                        player: logoPlayer ?? LogoAnimation.Player(number: engine.logoAnimationNumber),
                                        scale: scale)
        }

        if let toast = toastMessage {
            composer.drawToastOverlay(into: &rgba, message: toast)
        }
        return rgba
    }

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let rpd = view.currentRenderPassDescriptor,
              let cmd = commandQueue.makeCommandBuffer(),
              let enc = cmd.makeRenderCommandEncoder(descriptor: rpd) else { return }

        let rgba = currentFrame()
        uploadIfNeeded(rgba: rgba)

        if let tex = frameTexture {
            enc.setRenderPipelineState(pipelineState)
            enc.setVertexBuffer(quadVertexBuffer, offset: 0, index: 0)
            enc.setFragmentTexture(tex, index: 0)
            enc.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        }

        enc.endEncoding()
        cmd.present(drawable)
        cmd.commit()
    }

    private func uploadIfNeeded(rgba: RGBAImage) {
        if frameTexture == nil || frameSize.w != rgba.width || frameSize.h != rgba.height {
            let desc = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .rgba8Unorm, width: rgba.width, height: rgba.height, mipmapped: false)
            desc.usage = [.shaderRead]
            frameTexture = device!.makeTexture(descriptor: desc)
            frameSize = (rgba.width, rgba.height)
        }
        guard let tex = frameTexture else { return }
        let region = MTLRegionMake2D(0, 0, rgba.width, rgba.height)
        tex.replace(region: region, mipmapLevel: 0, withBytes: rgba.pixels, bytesPerRow: rgba.width * 4)
        tex.label = "frame"
    }

    // MARK: - Input

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // Needed so AppKit delivers mouseMoved events (hover highlighting).
        window?.acceptsMouseMovedEvents = true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        let area = NSTrackingArea(rect: bounds,
                                  options: [.mouseMoved, .activeAlways, .inVisibleRect],
                                  owner: self, userInfo: nil)
        addTrackingArea(area)
    }

    /// Hover highlighting for the pointing device — mirrors the keyboard selection so
    /// choices and every menu row light up under the cursor like the original cursor keys.
    override func mouseMoved(with event: NSEvent) {
        let nativePt = viewToNative(convert(event.locationInWindow, from: nil))
        switch mode {
        case .inGame where engine.phase == .awaitingChoice:
            let rects = composer.choiceOptionRects(count: engine.choices.count)
            if let i = rects.firstIndex(where: { $0.contains(nativePt) }), i != selectedChoiceIndex {
                selectedChoiceIndex = i
                needsDisplay = true
            }
        case .titleMenu:
            if let i = menuRowFromPoint(nativePt, items: titleMenuRows,
                                        firstLine: Self.titleMenuFirstLine),
               i != titleSelectionIndex {
                titleSelectionIndex = i
                needsDisplay = true
            }
        case .musicRoom:
            // The original's room loop highlights the button under the cursor.
            let rects = MusicRoom.buttonRects(scale: 1)
            let idx = rects.firstIndex(where: { $0.contains(nativePt) }) ?? -1
            if idx != musicHovered {
                musicHovered = idx
                needsDisplay = true
            }
        case .escMenu:
            if let idx = menuRowFromPoint(nativePt, items: escMenuRows, firstLine: 3),
               idx != escSelectionIndex {
                escSelectionIndex = idx
                needsDisplay = true
            }
        case .slotPicker:
            if let idx = slotRowFromPoint(nativePt), idx != slotSelection {
                slotSelection = idx
                needsDisplay = true
            }
        case .escConfirm:
            if let idx = menuRowFromPoint(nativePt, items: confirmRows, firstLine: 6),
               idx != confirmSelection {
                confirmSelection = idx
                needsDisplay = true
            }
        case .gallery:
            let page = galleryPageNow()
            if let i = GalleryView.pageCellRects().firstIndex(where: { $0.contains(nativePt) }),
               i < page.items.count, i != gallerySelection {
                gallerySelection = i
                needsDisplay = true
            }
        default:
            break
        }
    }

    override func scrollWheel(with event: NSEvent) {
        if event.scrollingDeltaY > 0 {
            // Wheel up == the original's `cursor_up`, which during a text wait jumps
            // straight into LvnsHistoryMode (LvnsControl.c:142-144 / 190-192).
            if mode == .inGame {
                openHistory()
            } else if mode == .history {
                historyUp()
            }
        } else if event.scrollingDeltaY < 0, mode == .history {
            historyDown()
        }
    }

    override func mouseDown(with event: NSEvent) {
        switch mode {
        case .booting:
            skipBoot()
        case .titleMenu:
            // Unlike the original (whose menu had no mouse), a click that lands on no
            // row must do nothing — activating the stale highlight from across the
            // screen was reported as a misfire.
            let nativePt = viewToNative(convert(event.locationInWindow, from: nil))
            // The 5th menu item is first: it is not one of the drawn rows, so the row
            // test would otherwise swallow the click into the nearest item.
            if MusicRoom.entryHitRect(scale: 1).contains(nativePt) {
                openMusicRoom()
                return
            }
            guard let i = menuRowFromPoint(nativePt, items: titleMenuRows,
                                           firstLine: Self.titleMenuFirstLine) else { return }
            titleSelectionIndex = i
            activateTitleSelection()
        case .musicRoom:
            // `0x408e11`: only the three buttons respond; anywhere else is a no-op and
            // the right button (`0xffff`) is the exit. During the plate's hold and fade
            // the original has not entered that loop yet, so nothing is live.
            guard musicFormShown else { return }
            let nativePt = viewToNative(convert(event.locationInWindow, from: nil))
            let rects = MusicRoom.buttonRects(scale: 1)
            for (i, r) in rects.enumerated() where r.contains(nativePt) {
                musicHovered = i
                activateMusicButton(i)
                return
            }
        case .history:
            // Only the two nav glyphs are clickable; like the original, a click that
            // lands on no arrow does nothing (cancel exits).
            let nativePt = viewToNative(convert(event.locationInWindow, from: nil))
            if HistoryView.upArrowRect(scale: 1).contains(nativePt) {
                historyUp()
            } else if HistoryView.downArrowRect(scale: 1).contains(nativePt) {
                historyDown()
            }
        case .endingsList:
            mode = .titleMenu
            needsDisplay = true
        case .inGame:
            // A click is a `LvnsSelect`: it clears `lvns->skip`, ending fast-forward.
            if isFastForward { stopFastForward() }
            if hideTextNow {
                hideTextNow = false
                needsDisplay = true
                return
            }
            if engine.phase == .awaitingChoice {
                let p = convert(event.locationInWindow, from: nil)
                let rects = composer.choiceOptionRects(count: engine.choices.count)
                let nativePt = viewToNative(p)
                for (i, r) in rects.enumerated() where r.contains(nativePt) {
                    selectedChoiceIndex = i
                    engine.selectChoice(i)
                    run()
                    return
                }
                return
            }
            advance()
        case .escMenu:
            let nativePt = viewToNative(convert(event.locationInWindow, from: nil))
            let idx = menuRowFromPoint(nativePt, items: escMenuRows, firstLine: 3)
            if let idx = idx {
                escSelectionIndex = idx
                activateEscItem(idx)
            }
        case .slotPicker:
            let nativePt = viewToNative(convert(event.locationInWindow, from: nil))
            if let idx = slotRowFromPoint(nativePt) {
                slotSelection = idx
                chooseSlot(pickerSlots[idx])
            }
        case .escConfirm:
            let nativePt = viewToNative(convert(event.locationInWindow, from: nil))
            if let idx = menuRowFromPoint(nativePt, items: confirmRows, firstLine: 6) {
                confirmSelection = idx
                resolveConfirm(accepted: idx == 0)
            }
        case .gallery:
            let nativePt = viewToNative(convert(event.locationInWindow, from: nil))
            let page = galleryPageNow()
            for (i, r) in GalleryView.pageCellRects().enumerated() where i < page.items.count {
                guard r.contains(nativePt) else { continue }
                gallerySelection = i
                activateGalleryCell()
                return
            }
        case .galleryZoom:
            closeGalleryZoom()
        case .staffRoll:
            // `select`: at the last card it starts the closing fade; anywhere earlier it
            // rewinds the script to the `CLICK_JUMP` tail (`LvnsScript.c:29-40`), so one
            // click ends the roll after the current hold.
            staffRollPress()
        case .logoAnimation:
            // `LvnsAnimation` polls no input (`LvnsAnim.c`): presses during the insert
            // are dropped, exactly as the original drops them.
            break
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        // Original: right-click opens the system menu from the game screen.
        switch mode {
        case .inGame:
            openEscMenu()
        case .slotPicker:
            // Same return contract as the picker's Esc key (`case 53: mode = pickerReturnMode`) —
            // a picker opened from the title menu must land back on the title, not the
            // in-game system menu.
            mode = pickerReturnMode
            pendingConfirm = nil
            needsDisplay = true
        case .escMenu, .escConfirm:
            mode = .escMenu
            pendingConfirm = nil
            needsDisplay = true
        case .history:
            closeHistory()
        case .musicRoom:
            // `0xffff` is the room loop's only exit: right-click.
            closeMusicRoom()
        case .staffRoll:
            // `LvnsWaitClick` breaks on select *or* cancel, but mid-roll only `select`
            // rewinds the script (`LvnsScript.c:29-40`); a cancel is ignored until the last
            // card, so right-click is `cancel` here rather than the system menu.
            staffRollCancel()
        default:
            break
        }
    }

    /// Map a native point onto menu rows. Hit geometry comes from the same
    /// `SceneComposer.menuRowRect` the renderer centres its glyphs with, so a click
    /// only registers on the painted text — never on empty space beside it.
    private func menuRowFromPoint(_ p: NSPoint, items: [MenuRow], firstLine: Int) -> Int? {
        for (i, row) in items.enumerated()
        where composer.menuRowRect(row, line: firstLine + i).contains(p) {
            return i
        }
        return nil
    }

    private func slotRowFromPoint(_ p: NSPoint) -> Int? {
        let rects = SceneComposer.slotPickerRowRects(count: pickerSlots.count)
        return rects.firstIndex(where: { $0.contains(p) })
    }

    override func keyDown(with event: NSEvent) {
        // Fullscreen toggle (Cmd-Ctrl-F)
        if event.modifierFlags.contains(.command) && event.modifierFlags.contains(.control) {
            if event.charactersIgnoringModifiers == "f" || event.keyCode == 3 {
                window?.toggleFullScreen(nil)
                return
            }
        }

        switch mode {
        case .booting:
            // Any key acts like the original `select`/CLICK_JUMP.
            skipBoot()
        case .titleMenu:
            handleTitleKeyDown(event)
        case .history:
            handleHistoryKeyDown(event)
        case .endingsList:
            if event.keyCode == 53 || event.keyCode == 36 || event.keyCode == 49 { // Esc, Enter, Space
                mode = .titleMenu
                needsDisplay = true
            }
        case .escMenu:
            handleEscMenuKeyDown(event)
        case .slotPicker:
            handleSlotPickerKeyDown(event)
        case .escConfirm:
            handleConfirmKeyDown(event)
        case .gallery:
            handleGalleryKeyDown(event)
        case .galleryZoom:
            // The enlargement is a viewer: any discrete press returns to the grid.
            if !event.isARepeat { closeGalleryZoom() }
        case .musicRoom:
            // The original polled the mouse only; Esc is the same exit as right-click.
            if event.keyCode == 53 { closeMusicRoom() }
        case .staffRoll:
            // Enter/Space are `select` (rewinds to the `CLICK_JUMP` tail from any stage);
            // Esc is `cancel` (only exits the last card's `WAIT_CLICK`).
            if event.keyCode == 53 {
                staffRollCancel()
            } else if event.keyCode == 36 || event.keyCode == 49 {
                staffRollPress()
            }
        case .logoAnimation:
            // Same as the mid-roll case of `LvnsAnimation`: no key is polled.
            break
        case .inGame:
            handleInGameKeyDown(event)
        }
    }

    private func handleTitleKeyDown(_ event: NSEvent) {
        let count = titleMenuRows.count
        switch event.keyCode {
        case 126: // Up arrow
            titleSelectionIndex = (titleSelectionIndex + count - 1) % count
            needsDisplay = true
        case 125: // Down arrow
            titleSelectionIndex = (titleSelectionIndex + 1) % count
            needsDisplay = true
        case 36, 76, 49: // Enter, Space
            activateTitleSelection()
        case 18, 19, 20, 21, 23: // 1..5 (keycode order: 1,2,3,4,5)
            let n = [18: 0, 19: 1, 20: 2, 21: 3, 23: 4][event.keyCode] ?? 0
            titleSelectionIndex = n
            activateTitleSelection()
        case 53: // Esc — quit intent on the title screen asks for confirmation
                 // rather than exiting abruptly (the in-game Esc menu is untouched).
            confirmQuit()
        default:
            break
        }
    }

    private func activateTitleSelection() {
        switch titleSelectionIndex {
        case 0: // はじめから
            startNewGame()
        case 1: // つづきから — pick which save (quicksave / しおり) to resume
            chooseSaveToContinue()
        case 2: // 回想モード
            openGallery()
        case 3: // エンディング一覧
            mode = .endingsList
            needsDisplay = true
        case 4: // 終了
            confirmQuit()
        default:
            break
        }
    }

    /// The one native "really quit?" dialog shared by every quit-intent path
    /// (title 終了, title Esc, window close button).
    func confirmQuit() {
        let alert = NSAlert()
        alert.messageText = "ゲームを終了しますか？"
        alert.informativeText = "終了するとこのウィンドウは閉じられます。"
        alert.addButton(withTitle: "終了")
        alert.addButton(withTitle: "キャンセル")
        if alert.runModal() == .alertFirstButtonReturn {
            NSApp.terminate(nil)
        }
    }

    // MARK: - シナリオ回想 (LvnsHistoryMode)

    /// Enter fullscreen history mode: starts at the newest recorded message
    /// (`pos = lvns->history_pos - 1`, LvnsHistory.c:64).
    private func openHistory() {
        guard mode == .inGame || mode == .escMenu, engine.transition == nil else { return }
        stopFastForward()
        historyPos = max(0, engine.backlog.count - 1)
        mode = .history
        needsDisplay = true
    }

    private func closeHistory() {
        mode = .inGame
        needsDisplay = true
    }

    /// Up at the oldest message is a no-op (`if (pos > 0)`, LvnsHistory.c:105-112).
    private func historyUp() {
        guard historyPos > 0 else { return }
        historyPos -= 1
        needsDisplay = true
    }

    /// Down past the newest message cancels out of history (LvnsHistory.c:115-124).
    private func historyDown() {
        if historyPos < engine.backlog.count - 1 {
            historyPos += 1
            needsDisplay = true
        } else {
            closeHistory()
        }
    }

    private func handleHistoryKeyDown(_ event: NSEvent) {
        if event.isARepeat { return }
        switch event.keyCode {
        case 126, 116: historyUp()              // Up, PageUp
        case 125, 121: historyDown()            // Down, PageDown
        case 53, 36, 76, 49: closeHistory()     // Esc, Enter, Space
        default: break
        }
    }

    private func handleInGameKeyDown(_ event: NSEvent) {
        // Original fidelity (user-tested): holding Enter/Space does NOTHING — advancing
        // is strictly per discrete key press. Auto-repeat must never advance text or
        // silently confirm a choice the moment a branch appears.
        if event.isARepeat { return }
        // Original `LvnsSelect`/`LvnsCancel` clear `lvns->skip` on every discrete press,
        // so any key except the skip hotkey itself drops out of fast-forward.
        if isFastForward, event.keyCode != skipKeyCode, event.keyCode != 6 {
            stopFastForward()
        }
        if hideTextNow && engine.phase != .awaitingChoice {  // any press re-shows hidden text first
            hideTextNow = false
            needsDisplay = true
            return
        }
        // Choice selection: the original has no keyboard cursor — options are picked by
        // mouse hover (see mouseMoved) or a 1..9 number jump. Enter/click only confirm
        // a hovered choice; with no hover (selectedChoiceIndex == -1) they do nothing.
        if engine.phase == .awaitingChoice {
            let count = max(1, engine.choices.count)
            switch event.keyCode {
            case 36, 76, 49: // Enter, Space
                if selectedChoiceIndex >= 0 {
                    engine.selectChoice(selectedChoiceIndex)
                    run()
                }
                return
            default:
                if let ch = event.charactersIgnoringModifiers?.first, let n = Int(String(ch)), n >= 1, n <= count {
                    selectedChoiceIndex = n - 1
                    engine.selectChoice(selectedChoiceIndex)
                    run()
                    return
                }
            }
        }

        switch event.keyCode {
        case 36, 76, 49: // return, enter, space
            advance()
        case 123, 124, 125, 126: // arrow keys — NO function during gameplay (original)
            return
        case 11: // 'B' -> シナリオ回想 (convenience; the wheel-up / ESC menu are the original paths)
            openHistory()
        case 1: // 'S' key -> Quick Save
            quickSave()
        case 37: // 'L' key -> Quick Load
            loadSave(slot: 0)
        case skipKeyCode, 6: // configured skip hotkey (default Tab), or Z -> Toggle Skip
            toggleFastForward()
        case 96: // F5 -> Quick Save
            quickSave()
        case 101: // F9 -> Quick Load
            loadSave(slot: 0)
        case 53: // Esc -> system menu (original: ESC or right-click opens the 6-item menu)
            openEscMenu()
        default:
            if engine.phase != .awaitingChoice {
                advance()
            }
        }
    }

    // MARK: - 音楽モード (title-screen BGM room)

    /// `0x408d40`: show VIS17 at full brightness, stop whatever is playing, start slot 0
    /// (リーフ), then fade the screen down to `latitude_dark` and draw the form over it.
    /// The room's own loop polls the mouse only.
    @objc func openMusicRoom() {
        musicPlaying = 0
        musicSelected = 0
        musicHovered = -1
        musicLatitude = MusicRoom.latitudeNormal
        musicIntroHold = MusicRoom.introHoldFlips
        musicFormShown = false
        mode = .musicRoom
        startTicker()
        engine.audio?.playBGM(number: MusicRoom.musicFileIndex(0), loop: true)
        needsDisplay = true
    }

    /// `LvnsDarken` (`LvnsEffect.c:966-976`): one 16th of palette brightness per flip until
    /// the menu level is reached, and the form appears only once the walk is over.
    private func stepMusicIntro() {
        if musicIntroHold > 0 {
            musicIntroHold -= 1
            return
        }
        if musicLatitude > MusicRoom.latitudeDark {
            musicLatitude -= 1
            if musicLatitude == MusicRoom.latitudeDark { musicFormShown = true }
        }
    }

    /// `0x408e9e`: stop the room's music and hand back to the title screen.
    func closeMusicRoom() {
        guard mode == .musicRoom else { return }
        engine.audio?.stopBGM()
        musicHovered = -1
        musicLatitude = MusicRoom.latitudeDark
        musicIntroHold = 0
        musicFormShown = true
        stopTicker()
        mode = .titleMenu
        needsDisplay = true
    }

    // MARK: - エンディング staff roll (`0x7d` / `sizuku_ed.c`)

    /// `SizukuEnding` blocks the script, so the roll gets its own presentation mode and the
    /// 60 Hz ticker owns it end to end. The frame captured here is the one the opening
    /// `CLEAR(FADE_PALETTE)` walks down to black.
    func openStaffRoll() {
        guard mode == .inGame else { return }
        // Fast-forward cannot carry through the roll: `ScriptStep` calls `LvnsClearLow` and
        // `LvnsDispLow` directly and `LvnsWait` polls no input, so `skip` changes nothing
        // here — and the press that ends `WAIT_CLICK` clears it in the original anyway.
        stopFastForward()
        staffOpeningFrame = currentFrame()
        staffPlayer = StaffRoll.Player(effectsEnabled: engine.effectsEnabled)
        mode = .staffRoll
        startTicker()
        needsDisplay = true
    }

    /// The roll's trailing `CLEAR(FADE_PALETTE)` has reached black: hand the screen back and
    /// let the script run its epilogue chain (`IF_NE` / `JUMP 195`).
    private func closeStaffRoll() {
        staffPlayer = nil
        staffOpeningFrame = nil
        engine.finishStaffRoll()
        mode = .inGame
        run()
    }

    /// The press `LvnsWaitClick` waits for — select or cancel, like the original's loop.
    private func staffRollPress() {
        guard var p = staffPlayer else { return }
        p.click()
        staffPlayer = p
        needsDisplay = true
    }

    /// `LvnsCancel`: a right-click / Esc. Mid-roll it is ignored (only `select` rewinds the
    /// script); at the last card's `WAIT_CLICK` it exits like a press.
    private func staffRollCancel() {
        guard var p = staffPlayer else { return }
        p.cancel()
        staffPlayer = p
        needsDisplay = true
    }

    // MARK: - `0x01` kind-03 logo insert (`LvnsAnimation` / `sizuku.c:25-89`)

    /// `LvnsAnimation` blocks the script the same way `SizukuEnding` does, so the insert
    /// gets its own mode. Fast-forward deliberately survives: the original's loop reads
    /// `lvns->skip` per flip and zeroes pending waits (`LvnsAnim.c:108-109`).
    func openLogoAnimation() {
        guard mode == .inGame else { return }
        logoPlayer = LogoAnimation.Player(number: engine.logoAnimationNumber)
        mode = .logoAnimation
        startTicker()
        needsDisplay = true
    }

    /// Table exhausted: hand the screen back and let the interpreter take the next opcode.
    private func closeLogoAnimation() {
        logoPlayer = nil
        engine.finishLogoAnimation()
        mode = .inGame
        run()
    }

    /// The three branches of the room's dispatch at `0x408e2d`. Only 「演奏」 moves the
    /// upper card; 前/次 just walk the lower (selection) card, wrap included.
    private func activateMusicButton(_ i: Int) {
        switch i {
        case MusicRoom.previousButton:
            musicSelected = (musicSelected + MusicRoom.trackCount - 1) % MusicRoom.trackCount
        case MusicRoom.nextButton:
            musicSelected = (musicSelected + 1) % MusicRoom.trackCount
        case MusicRoom.playButton:
            musicPlaying = musicSelected
            engine.audio?.playBGM(number: MusicRoom.musicFileIndex(musicSelected), loop: true)
        default:
            break
        }
        needsDisplay = true
    }

    // MARK: - 回想モード (title-menu CG gallery)

    /// Our design, not a restoration: `Sizuku.exe`'s title item pointer table (`0x430ebc`)
    /// holds exactly five entries and the fifth is the invisible 音楽モード cell, so the
    /// 1996 title menu had no recall entry at all. (mglvns lists the label inside an
    /// `#if 0` in `sizuku_op.c:182-191`, but that port is not evidence either way — see
    /// 30.3.) The grid follows the reader's spec: every event image the scripts show,
    /// unlocked by the system-level read state, click a cell to enlarge.
    private func openGallery() {
        if galleryItems.isEmpty { galleryItems = engine.game.eventImages() }
        galleryPage = 0
        gallerySelection = firstUnlockedCell() ?? 0
        galleryFadeFrom = nil
        galleryFadeTo = nil
        galleryFadeTick = Self.galleryFadeTicks
        mode = .gallery
        needsDisplay = true
    }

    /// Land the cursor on something viewable rather than on a wall of 「？」.
    private func firstUnlockedCell() -> Int? {
        galleryPageNow().unlocked.firstIndex(where: { $0 })
    }

    private func galleryPageNow() -> GalleryView.Page {
        GalleryView.page(items: galleryItems, seenHighWater: engine.seenHighWater,
                         number: galleryPage)
    }

    private func galleryFrame() -> RGBAImage {
        let page = galleryPageNow()
        var img = GalleryView.renderGrid(game: engine.game, page: page,
                                         selected: gallerySelection, scale: scale)
        let s = scale
        // WP-9: header/hint/page-label route through ShellText — JP rows are the
        // same leaf strings through the same dot-matrix path, ZH rows the native font.
        composer.drawMenuRow(into: &img, row: ShellText.galleryHeader(composer.language),
                             line: 0, selected: false)
        for (i, cell) in GalleryView.pageCellRects().enumerated() where i < page.items.count {
            guard !page.unlocked[i] else { continue }
            composer.drawLeafText(into: &img, text: UIText.galleryLockedMark,
                                  x: Int(cell.midX - 12) * s, y: Int(cell.midY - 12) * s,
                                  ink: (150, 150, 150))
        }
        composer.drawShellText(into: &img, text: ShellText.galleryHint(composer.language),
                               x: 8 * s, y: (11 * 32 + 8) * s, ink: (204, 204, 204))
        let label = ShellText.galleryPageLabel(page.number, total: page.total, composer.language)
        let labelW = composer.language == .zh
            ? composer.zhTextWidth(label) / scale
            : label.count * 24
        composer.drawShellText(into: &img, text: label,
                               x: (632 - labelW) * s, y: (11 * 32 + 8) * s,
                               ink: (204, 204, 204))
        return img
    }

    private func galleryZoomFrame() -> RGBAImage {
        let page = galleryPageNow()
        guard galleryZoomIndex < page.items.count else { return galleryFrame() }
        return GalleryView.renderZoom(game: engine.game, item: page.items[galleryZoomIndex],
                                      scale: scale)
    }

    /// The frame a mode should settle on once its dissolve finishes.
    private func gallerySettledFrame() -> RGBAImage {
        mode == .galleryZoom ? galleryZoomFrame() : galleryFrame()
    }

    /// Start the grid <-> zoom dissolve. `SceneComposer.blend` is the same linear mix the
    /// title mask uses; the CG-change effects in the original all run on the image layer,
    /// which this replaces wholesale here.
    private func beginGalleryFade(to next: GameMode) {
        galleryFadeFrom = gallerySettledFrame()
        mode = next
        galleryFadeTo = gallerySettledFrame()
        galleryFadeTick = 0
        startTicker()
        needsDisplay = true
    }

    private func moveGallerySelection(_ next: Int, page delta: Int = 0) {
        if delta != 0 {
            galleryPage = min(GalleryView.pageCount(galleryItems) - 1,
                              max(0, galleryPage + delta))
        }
        let count = max(1, galleryPageNow().items.count)
        gallerySelection = min(count - 1, max(0, next))
        needsDisplay = true
    }

    /// Any press in the enlargement view dissolves back to the grid it came from.
    private func closeGalleryZoom() {
        guard mode == .galleryZoom else { return }
        beginGalleryFade(to: .gallery)
    }

    private func activateGalleryCell() {
        let page = galleryPageNow()
        guard gallerySelection < page.items.count, page.unlocked[gallerySelection] else { return }
        galleryZoomIndex = gallerySelection
        beginGalleryFade(to: .galleryZoom)
    }

    /// Up/down walk a column and roll over into the neighbouring page, which a
    /// four-by-three grid of a ~90-image index needs.
    private func moveGalleryRow(_ delta: Int) {
        let col = gallerySelection % GalleryView.cols
        var row = gallerySelection / GalleryView.cols + delta
        var page = galleryPage
        if row < 0 { page -= 1; row += GalleryView.rows }
        else if row >= GalleryView.rows { page += 1; row -= GalleryView.rows }
        galleryPage = min(max(0, page), GalleryView.pageCount(galleryItems) - 1)
        gallerySelection = min(max(1, galleryPageNow().items.count) - 1,
                               row * GalleryView.cols + col)
        needsDisplay = true
    }

    private func handleGalleryKeyDown(_ event: NSEvent) {
        switch event.keyCode {
        case 53: // Esc -> back to the title
            stopTicker()
            galleryFadeFrom = nil
            galleryFadeTo = nil
            mode = .titleMenu
            needsDisplay = true
        case 126: moveGalleryRow(-1)   // Up
        case 125: moveGalleryRow(1)    // Down
        case 123:                                                            // Left
            if gallerySelection % GalleryView.cols == 0 {
                moveGallerySelection(GalleryView.perPage - 1, page: -1)
            } else {
                moveGallerySelection(gallerySelection - 1)
            }
        case 124:                                                            // Right
            if gallerySelection % GalleryView.cols == GalleryView.cols - 1 {
                moveGallerySelection(0, page: 1)
            } else {
                moveGallerySelection(gallerySelection + 1)
            }
        case 36, 76, 49: activateGalleryCell()                               // Enter, Space
        default: break
        }
    }

    // MARK: - ESC menu / しおり slot picker / confirm (M4.7)

    /// The original only ever shows the 6-item system menu over the game screen
    /// (SizukuMenuInit is called from the flip loop, not the title), so opening it
    /// from title/boot would strand the mode stack over stale engine state.
    ///
    /// It is likewise unreachable mid-effect: `LvnsClear`/`LvnsDisp` run their own
    /// blocking flip loop, and the menu is only polled once that loop returns. Going
    /// behind a transition here used to freeze it — `tickerFire` pumps the effect only
    /// for `.inGame`, so leaving the mode stopped the flip source with
    /// `engine.transition` still set.
    @objc func openEscMenu() {
        guard mode == .inGame, engine.transition == nil else { return }
        stopFastForward()
        escSelectionIndex = 0
        pickerReturnMode = .escMenu
        mode = .escMenu
        needsDisplay = true
    }

    private func slotRows() -> [SceneComposer.SlotRow] {
        let lang = composer.language
        let fmt = DateFormatter()
        fmt.dateFormat = ShellText.slotDateFormat(lang)
        return pickerSlots.map { slot in
            let label = ShellText.slotLabel(slot: slot, lang)
            guard let st = saveManager.getSaveState(slot: slot) else {
                return SceneComposer.SlotRow(labelText: label, detail: ShellText.slotEmpty(lang),
                                             preview: "", hasData: false)
            }
            let preview = slotPreview(for: st)
            return SceneComposer.SlotRow(labelText: label,
                                         detail: fmt.string(from: st.timestamp),
                                         preview: preview.text,
                                         previewIsCN: preview.isCN,
                                         hasData: true)
        }
    }

    /// M5.6 WP-1: the preview band is recomputed at render time from the save's
    /// language-independent anchors (scnIndex, currentMsgIndex) instead of trusting the
    /// stored snapshot — old saves may carry a CN string the JP dot matrix renders as
    ///残缺, and a ZH build must be able to preview JP bookmarks in Chinese and vice
    /// versa. The stored `previewText` remains only the fallback when the anchors do
    /// not resolve (deletes, exotic states).
    private func slotPreview(for st: SaveState) -> (text: String, isCN: Bool) {
        if let msgIdx = st.currentMsgIndex {
            if engine.language == .zh,
               let cn = engine.game.translationStore.text(scn: st.scnIndex, msg: msgIdx),
               !cn.isEmpty {
                // 中文预览带：取前两个自然段（drawSlotPicker 用 drawNativeText 渲染）。
                let paras = cn.split(separator: "\n", omittingEmptySubsequences: true).prefix(2)
                let text = paras.map { String($0.prefix(26)) }.joined(separator: "\n")
                return (text, true)
            }
            if let jp = engine.jpPreviewText(scn: st.scnIndex, msg: msgIdx) {
                return (jp, false)
            }
        }
        return (st.previewText, false)
    }

    private func handleEscMenuKeyDown(_ event: NSEvent) {
        let count = SceneComposer.escMenuRowCount
        switch event.keyCode {
        case 126: escSelectionIndex = (escSelectionIndex + count - 1) % count
        case 125: escSelectionIndex = (escSelectionIndex + 1) % count
        case 36, 76, 49: activateEscItem(escSelectionIndex)
        case 53:
            mode = .inGame
        case 18, 19, 20, 21, 23, 22: // 1..6 (keys 1,2,3,4,6,5 in that keycode order)
            let n = [18: 0, 19: 1, 20: 2, 21: 3, 23: 4, 22: 5][event.keyCode] ?? 0
            escSelectionIndex = n
            activateEscItem(n)
        default: break
        }
        needsDisplay = true
    }

    private func activateEscItem(_ i: Int) {
        switch i {
        case 0: // 文字を消す
            hideTextNow = true
            mode = .inGame
        case 1: // ロードする
            openSlotPicker(purpose: .load, returnTo: .escMenu)
        case 2: // セーブする
            openSlotPicker(purpose: .save, returnTo: .escMenu)
        case 3: // シナリオ回想
            openHistory()
        case 4: // 一つ前の選択肢に戻る
            // Original rewinds to `selectpoint`, which `SizukuStartScenario` seeds from
            // the last 'p' `savepoint` (sizuku.c:546) — so the page checkpoint is the
            // fallback before any SELECT has been passed.
            if let sp = engine.lastSelectSavePoint ?? engine.lastPageSavePoint {
                engine.restoreSaveState(sp)
                mode = .inGame
                run()
                showToast("一つ前の選択肢に戻りました")
            } else {
                mode = .inGame
                showToast("選択肢の保存点はありません")
            }
        case 5: // ゲーム終了
            pendingConfirm = .end
            confirmSelection = 1
            confirmCancelMode = .inGame
            mode = .escConfirm
        default: break
        }
        needsDisplay = true
    }

    private func handleSlotPickerKeyDown(_ event: NSEvent) {
        let count = pickerSlots.count
        switch event.keyCode {
        case 126: slotSelection = (slotSelection + count - 1) % count
        case 125: slotSelection = (slotSelection + 1) % count
        case 36, 76, 49: chooseSlot(pickerSlots[slotSelection])
        case 53: mode = pickerReturnMode
        default:
            if let ch = event.charactersIgnoringModifiers?.first, let n = Int(String(ch)),
               n >= 1, n <= count {
                chooseSlot(pickerSlots[n - 1])
            }
        }
        needsDisplay = true
    }

    private func chooseSlot(_ slot: Int) {
        switch slotPurpose {
        case .load:
            guard saveManager.getSaveState(slot: slot) != nil else {
                let label = slot == 0 ? "クイックセーブ" : "しおり \(slot)"
                showToast("\(label)は空です")
                return
            }
            pendingConfirm = .loadSlot(slot)
        case .save:
            pendingConfirm = .saveSlot(slot)
        }
        confirmSelection = 1
        confirmCancelMode = .slotPicker
        mode = .escConfirm
        needsDisplay = true
    }

    private func handleConfirmKeyDown(_ event: NSEvent) {
        switch event.keyCode {
        case 126, 125:
            confirmSelection = 1 - confirmSelection
        case 36, 76, 49:
            resolveConfirm(accepted: confirmSelection == 0)
        case 53:
            mode = confirmCancelMode   // ESC = cancel back to where the dialog was opened
        case 18, 19: // 1=yes 2=no
            resolveConfirm(accepted: event.keyCode == 18)
        default: break
        }
        needsDisplay = true
    }

    private func resolveConfirm(accepted: Bool) {
        guard accepted, let kind = pendingConfirm else {
            mode = confirmCancelMode   // いいえ -> back to the opener (in-game sizuku_menu.c)
            pendingConfirm = nil
            return
        }
        switch kind {
        case .loadSlot(let slot):
            do {
                try saveManager.load(slot: slot, into: engine)
                mode = .inGame
                selectedChoiceIndex = -1
                showToast("セーブデータをロードしました [SLOT \(slot)]")
                run()
            } catch {
                showToast("ロードに失敗しました")
                mode = pickerReturnMode
            }
        case .saveSlot(let slot):
            do {
                try saveManager.save(slot: slot, engine: engine)
                showToast("セーブしました [しおり \(slot)]")
                mode = .inGame
            } catch {
                showToast("セーブに失敗しました")
                mode = .escMenu
            }
        case .end:
            startTitleMenu()
        }
        pendingConfirm = nil
    }

    private func advance() {
        // `LvnsClear`/`LvnsDisp` run their own blocking flip loop and poll no input
        // (`LvnsEffect.c:906-908`, `LvnsDisp.c:200-213`), so a click during an effect is
        // simply lost in the original. Without this guard the click still reached
        // `advanceMessage()` while `run()`'s loop was dead (`while ... transition == nil`),
        // which consumed a message page without ever drawing it — the reported
        // "only the first line shows, then the page turns, no wait cursor".
        guard engine.transition == nil else {
            noteAdvance("advance swallowed")
            startTicker(); return
        }
        noteAdvance("advance")
        switch engine.phase {
        case .awaitingMessage:
            engine.advanceMessage()
            run()
        case .awaitingChoice:
            // "None" selection (-1): clicking outside an option confirms nothing.
            guard selectedChoiceIndex >= 0 else { return }
            engine.selectChoice(selectedChoiceIndex)
            run()
        case .ended:
            startTitleMenu()
        case .staffRoll:
            // A press queued on the same beat as `0x7d`: the roll takes it, not the script.
            openStaffRoll()
        case .logoAnimation:
            // A press queued on the same beat as a kind-03 `0x01`: the insert takes the
            // screen; its own flip loop then polls nothing until the table is exhausted.
            openLogoAnimation()
        case .running:
            run()
        }
    }

    // MARK: - Screenshot verification harness (SHIZUKU_SHOT, headless dev tool)

    /// Renders the requested screens to /tmp/shizuku_shots/*.png and quits. The token list
    /// is long and grows every review round; `roll` alone is ~20 frames, so ask for the
    /// groups you need, e.g.
    /// `SHIZUKU_SHOT=boot,title,game,esc,trans,gallery,music,roll`.
    /// `menu` writes no PNG — it dumps the AppKit menu-bar titles to `menu_dump.txt`.
    func runShotSpec(_ spec: String, completion: @escaping () -> Void) {
        let outDir = "/tmp/shizuku_shots"
        try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
        func write(_ img: RGBAImage, _ name: String) {
            try? img.encodePNG().write(to: URL(fileURLWithPath: "\(outDir)/\(name).png"))
        }
        func enterGame() {
            engine.reset(scn: 1, block: 1, keepPersistentFlags: true)
            // Headless harness has no 60 Hz ticker: `lvns->skip` keeps LvnsClear/LvnsDisp
            // transitions from blocking the synchronous step/advance loops.
            engine.skip = true
            run()
            engine.revealAll()
            mode = .inGame
        }
        for token in spec.split(separator: ",") {
            switch token.trimmingCharacters(in: .whitespaces) {
            case "boot":
                for stage in BootStage.jingleFadeIn.rawValue...BootStage.titleMask.rawValue {
                    guard let s = BootStage(rawValue: stage) else { continue }
                    bootStage = s
                    bootTick = min(8, max(1, bootStageDuration(s) / 2))
                    write(bootFrame(), String(format: "boot_%02d_%@", stage, "\(s)"))
                }
            case "title":
                mode = .titleMenu
                write(titleFrame(), "title")
            case "game":
                enterGame()
                write(currentFrame(), "game")
            case "choice":
                // Run to the first SELECT (0x46 gate in SCN001) and prove the prompt
                // message renders on screen together with the option boxes.
                engine.flags[0x46] = 1
                enterGame()
                var guardCount = 0
                while engine.phase != .ended, engine.phase != .awaitingChoice, guardCount < 8000 {
                    guardCount += 1
                    engine.bgmHoldSeconds = 0
                    _ = engine.step()
                    while engine.phase == .awaitingMessage, guardCount < 9000 {
                        engine.bgmHoldSeconds = 0
                        engine.revealAll()
                        engine.advanceMessage()
                        guardCount += 1
                    }
                }
                mode = .inGame
                selectedChoiceIndex = 0  // shot harness: force a visible highlight
                write(currentFrame(), "choice_menu")
            case "cn":
                // Force `.zh` and mount the anchor message (SCN001 msg 5) directly.
                engine.setLanguage(.zh)
                engine.previewMessage(scn: 1, msg: 5)
                mode = .inGame
                write(currentFrame(), "cn_game")
                let diag = engine.cnActive
                    ? "CN msg=\(engine.currentMsg?.index ?? -1) slices=\(engine.cnSlices.count) line0=\(engine.cnCurrentLines.first ?? "-")"
                    : "NOT-CN (store hits=\(engine.game.translationStore.count)) msg=\(engine.currentMsg?.index ?? -1)"
                try? diag.write(toFile: "\(outDir)/cn_diag.txt", atomically: true, encoding: .utf8)
                print("CN shot: \(diag)")
            case "cnreveal":
                // WP-9 regression: the CN layer must type out character by character on
                // the JP beat clock, advance one beat per click, and never draw JP glyphs.
                engine.setLanguage(.zh)
                engine.skip = false
                let env = ProcessInfo.processInfo.environment
                let cnScn = Int(env["SHIZUKU_CN_SCN"] ?? "") ?? 1
                let cnMsg = Int(env["SHIZUKU_CN_MSG"] ?? "") ?? 5
                engine.previewMessage(scn: cnScn, msg: cnMsg)
                mode = .inGame
                var cnBeats = 0
                var cnGuard = 0
                while cnBeats < 3, cnGuard < 40, engine.phase == .awaitingMessage {
                    cnGuard += 1
                    for _ in 0..<24 { engine.tickReveal(deltaTime: 1.0 / 60.0) }
                    if engine.isRevealing { write(currentFrame(), "cnreveal_mid\(cnBeats)") }
                    var tickGuard = 0
                    while engine.isRevealing, tickGuard < 4000 {
                        engine.tickReveal(deltaTime: 1.0 / 60.0)
                        tickGuard += 1
                    }
                    write(currentFrame(), "cnreveal_full\(cnBeats)")
                    engine.advanceMessage()
                    cnBeats += 1
                }
                let cnDiag = "beats=\(cnBeats) cnActive=\(engine.cnActive) " +
                             "displayed=\(engine.cnDisplayedText.count)"
                try? cnDiag.write(toFile: "\(outDir)/cnreveal_diag.txt", atomically: true, encoding: .utf8)
            case "esc":
                enterGame()
                openEscMenu()
                write(currentFrame(), "esc_menu")
            case "continuelist":
                // Title-screen flow: つづきから must open the picker over the title backdrop.
                mode = .titleMenu
                chooseSaveToContinue()
                write(currentFrame(), "continue_picker")
            case "slotload":
                enterGame()
                openSlotPicker(purpose: .load, returnTo: .escMenu)
                slotSelection = 4   // land on しおり 3 so the preview band has content
                write(currentFrame(), "slot_load")
            case "slotsave":
                enterGame()
                // Persist a fresh save so the picker shows the leaf-decoded JP preview.
                _ = try? saveManager.save(slot: 3, engine: engine)
                openSlotPicker(purpose: .save, returnTo: .escMenu)
                slotSelection = 2   // しおり 3 in the save-only list: fresh 52-char preview wraps to 2 band lines
                write(currentFrame(), "slot_save")
            case "loadsave":
                // WP-8 interop: restore explicit save files and render the landed state.
                // `SHIZUKU_LOAD_FILES=name:/abs/path.json,name2:/abs/path2.json`
                let envList = (ProcessInfo.processInfo.environment["SHIZUKU_LOAD_FILES"] ?? "")
                    .split(separator: ",")
                var diagLines: [String] = []
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                for entry in envList {
                    let parts = entry.split(separator: ":", maxSplits: 1)
                    guard parts.count == 2,
                          let data = try? Data(contentsOf: URL(fileURLWithPath: String(parts[1]))),
                          let st = try? decoder.decode(SaveState.self, from: data)
                    else { diagLines.append("\(entry): LOAD-FAIL"); continue }
                    engine.restoreSaveState(st)
                    mode = .inGame
                    engine.revealAll()
                    write(currentFrame(), "loadsave_\(parts[0])")
                    diagLines.append("\(parts[0]): scn=\(st.scnIndex) msg=\(st.currentMsgIndex ?? -1) " +
                                     "seg=\(st.currentSegmentIndex ?? -1) phase=\(String(describing: engine.phase)) " +
                                     "cnActive=\(engine.cnActive) line0=\(engine.cnCurrentLines.first ?? "-") " +
                                     "jpLine0Codes=\(engine.currentPageLines.first?.count ?? -1)")
                }
                let diag = diagLines.joined(separator: "\n")
                try? diag.write(toFile: "\(outDir)/loadsave_diag.txt", atomically: true, encoding: .utf8)
                print("LOADSAVE shots:\n\(diag)")
            case "confirm":
                enterGame()
                pendingConfirm = .end
                mode = .escConfirm
                write(currentFrame(), "confirm_end")
            case "history":
                enterGame()
                for _ in 0..<8 {
                    engine.revealAll()
                    if engine.phase == .awaitingChoice { selectedChoiceIndex = 0 }
                    advance()                      // the real reader path: run to the next msg
                }
                openHistory()                       // newest message, like LvnsHistory.c:64
                write(currentFrame(), "history_newest")
                print("HISTORY shots: backlog=\(engine.backlog.count) pos=\(historyPos) " +
                      "msgs=\(engine.backlog.map { $0.msg })")
                historyUp()
                historyUp()
                write(currentFrame(), "history_older")
                print("HISTORY older: pos=\(historyPos) lines=\(engine.backlog[historyPos].lines.count)")
            case "waitkey", "waitpage":
                let wantPage = token == "waitpage"
                enterGame()
                // Walk to the next segment that ends with the pause whose cursor we want:
                // .pageBreak ('p') flashes the page icon, .waitKey ('k')/messageEnd the ▶.
                var guardCount = 0
                while guardCount < 400 {
                    guardCount += 1
                    engine.revealAll()
                    if let pause = engine.waitingPause,
                       (pause == .pageBreak) == wantPage { break }
                    engine.advanceMessage()
                    engine.revealAll()
                }
                // Only the "on" half of the 6-flip blink shows a cursor.
                var blinkGuard = 0
                while !engine.waitCursorVisible, blinkGuard < 24 {
                    engine.tickReveal(deltaTime: 1.0 / 60.0)
                    blinkGuard += 1
                }
                mode = .inGame
                let waitTag = wantPage ? "wait_page" : "wait_key"
                write(currentFrame(), waitTag)
                // Both halves of the cycle counted from the flip the wait began on: flip 5
                // is still lit, flip 6 dark, flip 12 lit again. Without these a cursor that
                // never blanks would look the same as a correct one in the arrival frame.
                for flip in [5, 6, 12] {
                    var pumpGuard = 0
                    while engine.flipCount - engine.waitCursorEntryFlip < flip, pumpGuard < 60 {
                        engine.tickReveal(deltaTime: 1.0 / 60.0)
                        pumpGuard += 1
                    }
                    write(currentFrame(), "\(waitTag)_flip\(String(format: "%02d", flip))")
                    print("WAIT \(waitTag) flip=\(flip) visible=\(engine.waitCursorVisible) " +
                          "entry=\(engine.waitCursorEntryFlip) flipCount=\(engine.flipCount) " +
                          "phase=\(engine.phase) seg=\(engine.currentSegmentIndex) " +
                          "msg=\(engine.currentMsg?.index ?? -1) pause=\(String(describing: engine.waitingPause))")
                }
                print("WAIT shot \(token): pause=\(String(describing: engine.waitingPause)) " +
                      "lines=\(engine.displayedLines.count) flip=\(engine.flipCount)")
            case "perfrun":
                // Drive the real run loop for 6 s on the game screen so `SHIZUKU_PERF`
                // can report the flip rate the ticker actually achieves.
                enterGame()
                engine.skip = false
                // The 2 s window in `reportPerf` divides by a clock that restarts on the
                // first flip, so a burst-catch-up after a stall can print >60 without the
                // steady rate being wrong. Total flips over total wall seconds cannot lie:
                // <60 means beats are being dropped (the reported "too slow"), >60 means
                // something double-drives the flip counter (the original "too fast").
                perfRuns = true
                let flip0 = engine.flipCount
                let wall0 = Self.now()
                startTicker()
                let deadline = wall0 + 6
                while Self.now() < deadline {
                    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
                }
                stopTicker()
                let seconds = Self.now() - wall0
                let flips = engine.flipCount - flip0
                print(String(format:
                    "PERF total: flips=%d seconds=%.2f rate=%.1f/s (target 60.0) fires=%d zeroFlipFires=%d maxFlipsPerFire=%d",
                    flips, seconds, Double(flips) / max(seconds, 0.001),
                    perfFires, perfZeroFires, perfMaxFlips))
            case "perf":
                // Frame-budget probe: the ticker's timed values (▼ blink, glyph reveal)
                // are wall-clock driven, so the visible rate now depends on how long one
                // composed frame costs. Print ms/frame for the steady in-game screen.
                enterGame()
                engine.skip = false
                mode = .inGame
                for _ in 0..<10 { _ = currentFrame() }        // warm the caches
                let t0 = Self.now()
                let frames = 120
                for _ in 0..<frames { _ = currentFrame() }
                let ms = (Self.now() - t0) * 1000.0 / Double(frames)
                print(String(format: "PERF compose: %.2f ms/frame (%.0f fps headroom vs 60)",
                             ms, 1000.0 / max(ms, 0.001)))
            case "inert":
                // 項6: walk the real reader path (advance + click choices) over a long
                // stretch of the scenario and report every page that pauses with no glyph
                // on screen — the blank ▼/翻页 pages. Exports the first offender, if any.
                enterGame()
                engine.skip = false
                engine.fastWhenSeen = false
                var pages = 0, blanks = 0, choices = 0
                var walkGuard = 0
                while walkGuard < 900, pages < 150 {
                    walkGuard += 1
                    engine.bgmHoldSeconds = 0
                    if engine.phase == .ended || mode != .inGame { break }
                    if engine.transition != nil {
                        var flip = 0
                        while engine.transition != nil, flip < 400 {
                            engine.tickReveal(deltaTime: 1.0 / 60.0)
                            flip += 1
                        }
                        continue
                    }
                    if engine.phase == .awaitingChoice {
                        choices += 1
                        selectedChoiceIndex = 0
                    }
                    if engine.phase == .awaitingMessage {
                        engine.revealAll()
                        let shown = (engine.screenLines + engine.activeLines)
                            .flatMap { $0 }.filter { $0 != Message.tokSpace }
                        pages += 1
                        if pages % 25 == 0 { print("INERT progress: pages=\(pages) blanks=\(blanks)") }
                        if shown.isEmpty {
                            blanks += 1
                            print("BLANK page \(blanks): scn=\(engine.scnIndex) " +
                                  "msg=\(engine.currentMsg?.index ?? -1) " +
                                  "seg=\(engine.currentSegmentIndex) " +
                                  "pause=\(String(describing: engine.waitingPause))")
                            if blanks == 1 {
                                mode = .inGame
                                write(currentFrame(), "inert_blank_first")
                            }
                        }
                    }
                    advance()
                }
                print("INERT walk: pages=\(pages) blanks=\(blanks) choices=\(choices) " +
                      "walk=\(walkGuard) phase=\(engine.phase)")
            case "trans":
                // Real engine path: walk the script the way a reader does (advance at
                // each wait) until LvnsClear/LvnsDisp fire, then pump the effect flip by
                // flip and export a sampled strip of frames per transition. Run twice so
                // the `enable_effect` off path (`-n e`) is inspected against the on path.
                for fxOn in [true, false] {
                    enterGame()
                    engine.effectsEnabled = fxOn
                    engine.skip = false
                    let strideFlip = fxOn ? 6 : 2
                    var started = 0
                    var guardCount = 0
                    while started < 1, guardCount < 60000 {
                        guardCount += 1
                        _ = engine.step()
                        if engine.transition == nil, engine.phase == .awaitingMessage {
                            engine.revealAll()
                            engine.advanceMessage()
                            continue
                        }
                        guard engine.transition != nil else { continue }
                        var flip = 0
                        while engine.transition != nil, flip < 400 {
                            if flip % strideFlip == 0, let tr = engine.transition {
                                write(currentFrame(), String(format: "trans_%@_%03d_%@",
                                                             fxOn ? "on" : "off", flip, "\(tr.phase)"))
                            }
                            if flip == 0, let tr = engine.transition {
                                print("TRANS \(fxOn ? "on" : "off"): clear=\(String(describing: tr.clearEffect)) " +
                                      "disp=\(String(describing: tr.dispEffect))")
                            }
                            engine.tickReveal(deltaTime: 1.0 / 60.0)
                            flip += 1
                        }
                        started += 1
                        print("TRANS \(fxOn ? "on" : "off") flips=\(flip)")
                    }
                }
                engine.effectsEnabled = true
                engine.skip = true
            case "spiral":
                // Directly exercise the GURUGURU wipe over two flat colours so the reveal
                // boundary is readable: `from` is red, `to` is blue. A correct spiral sweeps
                // the whole 40×25 tile grid; the old MGL-grid geometry left the right third to
                // a row-major top-to-bottom fill (blue blocks marching down the right edge).
                var red = RGBAImage(width: 640, height: 400); red.fill(200, 40, 40, 255)
                var blue = RGBAImage(width: 640, height: 400); blue.fill(40, 60, 200, 255)
                let total = LvnsEffectTiming.frames(.guruguru, width: 640, height: 400)
                for f in stride(from: 0, to: total, by: total / 6) {
                    write(TransitionRenderer.render(effect: .guruguru, from: red, to: blue, frame: f),
                          String(format: "spiral_%03d", f))
                }
                write(TransitionRenderer.render(effect: .guruguru, from: red, to: blue, frame: total - 1),
                      String(format: "spiral_%03d_last", total - 1))
            case "effects":
                // Sample every EXE-aligned transition (HANDOVER §38) between flat red/blue
                // so the reveal geometry is legible frame by frame.
                var red = RGBAImage(width: 640, height: 400); red.fill(200, 40, 40, 255)
                var blue = RGBAImage(width: 640, height: 400); blue.fill(40, 60, 200, 255)
                let fx: [LvnsEffect] = [.fadePalette, .slantTile, .fadeSquare, .wipeSquareLtoR,
                                        .fadeMask, .wipeTtoB, .wipeLtoR, .wipeMaskLtoR,
                                        .vertComposition, .slideLtoR]
                for effect in fx {
                    let total = LvnsEffectTiming.frames(effect, width: 640, height: 400)
                    for f in stride(from: 0, to: total, by: max(1, total / 4)) {
                        write(TransitionRenderer.render(effect: effect, from: red, to: blue, frame: f),
                              String(format: "fx_%@_%03d", "\(effect)", f))
                    }
                    write(TransitionRenderer.render(effect: effect, from: red, to: blue, frame: total - 1),
                          String(format: "fx_%@_last", "\(effect)"))
                }
            case "watchdog":
                // Proves the stall watchdog is live rather than decorative: drive to a real
                // `LvnsClear`/`LvnsDisp` pair with `skip = false`, then kill the flip source
                // the way the reported freeze does, and let the run loop spin. The watchdog
                // runs on its own timer, so it must survive its own subject being stopped and
                // write the ring to ~/Library/Logs/Shizuku_Restored/diagnostic.log.
                enterGame()
                engine.skip = false
                var walked = 0
                while engine.transition == nil, walked < 3000, engine.phase != .ended {
                    walked += 1
                    engine.bgmHoldSeconds = 0
                    if engine.phase == .awaitingMessage { engine.revealAll(); engine.advanceMessage() }
                    switch engine.step() {
                    case .waitingChoice: engine.selectChoice(0)
                    case .waitingStaffRoll: engine.finishStaffRoll()
                    case .waitingLogoAnimation: engine.finishLogoAnimation()
                    case .ended: break
                    case .rendered, .waitingMessage: break
                    }
                }
                noteAdvance("WATCHDOG probe (flip source about to be killed)")
                stopTicker()
                let until = Date().addingTimeInterval(4)
                while Date() < until { RunLoop.main.run(until: until) }
                let stalled = engine.transition.map { "transition=\($0.phase) state=\($0.state)" } ?? "drained"
                // Recovery has to be judged on the screen, not on the log: give the restarted
                // source two more seconds and require the pair to finish and flush.
                let until2 = Date().addingTimeInterval(2.5)
                while Date() < until2 { RunLoop.main.run(until: until2) }
                let log = Self.diagnosticURL()
                let text = log.flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
                print("WATCHDOG transitionWasLive=\(walked < 3000) stalledState=\(stalled) " +
                      "recovered=\(engine.transition == nil) shownAfter=\(engine.scene.bgName ?? engine.scene.bgHName ?? "nil") " +
                      "log=\(log?.path ?? "nil") " +
                      "stallLines=\(text.split(separator: "\n").filter { $0.contains("flip source silent") }.count)")
                write(currentFrame(), "watchdog_recovered")
                print(text.split(separator: "\n").suffix(6).joined(separator: "\n"))
            case "cgtobg":
                // 项3 verification. The corpus-wide worst "CG → background" switch is 230
                // flips (3.8 s), and the CG is normally the *previous* scenario's, so walk
                // scenarios in order on one engine until a pair carries CG → MAX_S. Export the
                // frame the pair opens on, the halfway frame, and the frame after the
                // interpreter lets go, so "the CG is stuck as the background" is judged on
                // pixels instead of asserted.
                enterGame()
                engine.effectsEnabled = true
                engine.skip = false
                var found = false
                for scn in 1..<12 where !found {
                    engine.start(scn: scn, block: 1)
                    var walked = 0
                    while walked < 3000, !found, engine.phase != .ended {
                        walked += 1
                        engine.bgmHoldSeconds = 0
                        if engine.transition == nil, engine.phase == .awaitingMessage {
                            engine.revealAll()
                            engine.advanceMessage()
                        }
                        switch engine.step() {
                        case .waitingChoice: engine.selectChoice(0)
                        case .waitingStaffRoll: engine.finishStaffRoll()
                        case .waitingLogoAnimation: engine.finishLogoAnimation()
                        case .ended: found = true
                        case .rendered, .waitingMessage: break
                        }
                        guard let tr = engine.transition else { continue }
                        let from = tr.fromScene.bgName ?? tr.fromScene.bgHName ?? "-"
                        var flip = 0
                        while engine.transition != nil, flip < 600 {
                            let to = engine.scene.bgName ?? engine.scene.bgHName ?? "-"
                            if (from.hasPrefix("VIS") || from.hasPrefix("HVS")),
                               to.hasPrefix("MAX_S"),
                               flip == 0 || flip == 115 || flip == 229 {
                                write(currentFrame(), String(format: "cgtobg_%03d", flip))
                            }
                            engine.tickReveal(deltaTime: 1.0 / 60.0)
                            flip += 1
                        }
                        let to = engine.scene.bgName ?? engine.scene.bgHName ?? "-"
                        guard (from.hasPrefix("VIS") || from.hasPrefix("HVS")), to.hasPrefix("MAX_S") else {
                            continue
                        }
                        write(currentFrame(), "cgtobg_end")
                        print("CGTOBG SCN\(engine.scnIndex) \(from) → \(to) flips=\(flip) " +
                              "drained=\(engine.transition == nil)")
                        found = true
                    }
                }
                if !found { print("CGTOBG: no CG → background pair in scn 1..<12") }
                engine.effectsEnabled = true
                engine.skip = true
            case "escfreeze":
                // Regression for the reported freeze: ESC pressed while LvnsClear/LvnsDisp
                // owns the screen used to switch mode, which killed the flip source with
                // `engine.transition` still set. The interpreter then stayed half-applied.
                func state(_ tag: String) {
                    print("ESCBUG \(tag): mode=\(mode) phase=\(engine.phase) " +
                          "tr=\(engine.transition != nil) page=\(engine.currentPage)/" +
                          "\(engine.currentPages.count) seg=\(engine.currentSegmentIndex) " +
                          "lines=\(engine.displayedLines.count) " +
                          "reveal=\(engine.isRevealing) " +
                          "pause=\(engine.waitingPause.map { String(describing: $0) } ?? "nil") " +
                          "cursorShown=\(engine.waitingPause != nil && engine.waitCursorVisible) " +
                          "scn=\(engine.scnIndex) pc=\(engine.pc)")
                }
                /// The headless harness has no 60 Hz blink, so park the cursor in its
                /// visible half before exporting — otherwise a correct state photographs
                /// as "no wait cursor" and the probe proves nothing.
                func blinkOn() {
                    var n = 0
                    while !engine.waitCursorVisible, n < 12 {
                        engine.tickReveal(deltaTime: 1.0 / 60.0); n += 1
                    }
                }
                func pump() {
                    var n = 0
                    while engine.transition != nil, n < 400 {
                        engine.tickReveal(deltaTime: 1.0 / 60.0); n += 1
                    }
                    run()
                }
                enterGame()
                engine.skip = false
                for tag in ["preguard", "old", "fixed"] {
                    enterGame()
                    engine.skip = false
                    var flips = 0
                    while engine.transition == nil, flips < 60000 {
                        _ = engine.step()
                        if engine.phase == .awaitingMessage, engine.transition == nil {
                            engine.revealAll(); engine.advanceMessage()
                        }
                        flips += 1
                    }
                    guard engine.transition != nil else {
                        print("ESCBUG \(tag): no transition reached"); continue
                    }
                    for _ in 0..<6 { engine.tickReveal(deltaTime: 1.0 / 60.0) }
                    switch tag {
                    case "old":
                        // Pre-fix path: enter the menu and let `tickerFire` fall through
                        // to stopTicker(), i.e. exactly what `openEscMenu` used to do.
                        escSelectionIndex = 0
                        mode = .escMenu
                        stopTicker()
                    case "fixed":
                        openEscMenu()
                    default:
                        break   // "preguard": no menu at all, only the mid-effect clicks
                    }
                    state("\(tag): esc pressed mid-effect")
                    mode = .inGame
                    // Second half of the report: clicks that land *while* the effect still
                    // owns the screen. The original polls no input there, so they must be
                    // swallowed; pre-fix each one moved the interpreter a page without
                    // drawing anything (the "only the first line, then page over" symptom).
                    // The "preguard" tag replays that old `advance()` body verbatim so the
                    // damage is on screen rather than argued about.
                    let segBeforeClicks = (engine.currentSegmentIndex, engine.displayedLines.count)
                    for _ in 0..<3 {
                        if tag == "preguard" {
                            if engine.phase == .awaitingMessage { engine.advanceMessage() }
                            run()
                        } else {
                            advance()
                        }
                    }
                    print("ESCBUG \(tag): 3 mid-effect clicks moved seg/lines " +
                          "\(segBeforeClicks) -> (\(engine.currentSegmentIndex), " +
                          "\(engine.displayedLines.count))")
                    // What the restored ticker then does: keep flipping until the effect
                    // ends — which is also where a latched `advanceQueuedDuringTransition`
                    // gets drained behind the reader's back.
                    pump()
                    state("\(tag): effect drained")
                    blinkOn()
                    write(currentFrame(), "escfreeze_\(tag)_drained")
                    for i in 0..<6 {
                        advance()
                        pump()
                        state("\(tag): click \(i + 1)")
                        blinkOn()
                        write(currentFrame(), String(format: "escfreeze_%@_click%d", tag, i + 1))
                    }
                    write(currentFrame(), "escfreeze_\(tag)")
                }
            case "endings":
                mode = .endingsList
                write(currentFrame(), "endings")
            case "bootclick":
                // `LvnsScript.c:29-40`: a CLICK_JUMP rewinds the PC to the *next* jump
                // marker, so one click only ever finishes the current stage. Prove the
                // state machine honours that — a jingle click must land in the OP, not
                // at the title menu.
                for stage in BootStage.jingleFadeIn.rawValue...BootStage.titleMask.rawValue {
                    guard let s = BootStage(rawValue: stage) else { continue }
                    bootStage = s
                    bootTick = 0
                    skipBoot()
                    print("BOOTCLICK \(s) -> \(bootStage)")
                }
                bootStage = .jingleFadeIn
            case "hit":
                mode = .titleMenu
                write(titleFrame(), "title")
                for (i, row) in titleMenuRows.enumerated() {
                    print("HIT title[\(i)] " + describe(composer.menuRowRect(row, line: Self.titleMenuFirstLine + i)))
                }
                for (i, row) in escMenuRows.enumerated() {
                    print("HIT esc[\(i)] " + describe(composer.menuRowRect(row, line: 3 + i)))
                }
                for (i, row) in confirmRows.enumerated() {
                    print("HIT confirm[\(i)] " + describe(composer.menuRowRect(row, line: 6 + i)))
                }
            case "gallery":
                // Both branches of the unlock rule, plus the enlargement view.
                mode = .titleMenu
                openGallery()
                write(galleryFrame(), "gallery_locked")
                for scn in 0..<205 { engine.seenHighWater[scn] = 999 }
                gallerySelection = 2
                write(galleryFrame(), "gallery_open")
                activateGalleryCell()
                galleryFadeTick = Self.galleryFadeTicks / 2
                write(currentFrame(), "gallery_fade")
                galleryFadeTick = Self.galleryFadeTicks
                write(galleryZoomFrame(), "gallery_zoom")
                // A page of the VIS family: several of those LFGs are smaller than
                // 640x400, so this checks the aspect-fit letterboxing.
                galleryPage = 3
                gallerySelection = 0
                write(galleryFrame(), "gallery_vis")
                print("GALLERY items=\(galleryItems.count) pages=\(GalleryView.pageCount(galleryItems))")
            case "music":
                // The room's two cards with the longest strings it can show (name 7 cells,
                // composer 5 cells). The title entry itself is invisible by design, so the
                // `title` token is what shows that screen.
                //
                // The fade-in is time-driven, so its three states are pinned by hand here:
                // letting the export read whatever the ticker had reached would not repeat.
                openMusicRoom()
                stopTicker()
                write(currentFrame(), "music_plate")
                musicIntroHold = 0
                musicLatitude = 13
                write(currentFrame(), "music_fading")
                musicLatitude = MusicRoom.latitudeDark
                musicFormShown = true
                write(currentFrame(), "music_room0")
                musicPlaying = 14
                musicSelected = 17
                musicHovered = MusicRoom.playButton
                write(currentFrame(), "music_room17")
                // Longest name on the upper card, and the third composer on the lower one.
                musicPlaying = 15
                musicSelected = 4
                musicHovered = MusicRoom.nextButton
                write(currentFrame(), "music_room15")
                print("MUSIC entry=\(describe(MusicRoom.entryHitRect(scale: 1))) " +
                      "buttons=" + MusicRoom.buttonRects(scale: 1).map { describe($0) }
                          .joined(separator: " | "))
            case "roll":
                // §32 the ending staff roll. Every phase is flip-driven, so pin each one by
                // hand — reading whatever the ticker had reached would not repeat.
                func advance(_ p: inout StaffRoll.Player, _ flips: Int) {
                    p.tick(flips: flips)
                    staffPlayer = p
                    needsDisplay = true
                }
                func settle(_ p: inout StaffRoll.Player, _ stage: StaffRoll.Stage) {
                    for _ in 0..<10000 {
                        if p.stage == stage { return }
                        advance(&p, 1)
                    }
                    print("ROLL settle FAILED want=\(stage) got=\(p.stage)")
                }
                enterGame()
                engine.effectsEnabled = true
                openStaffRoll()
                stopTicker()
                var p = staffPlayer ?? StaffRoll.Player(effectsEnabled: true)
                // The ending screen walks down to black...
                advance(&p, StaffRoll.fadeSteps / 2)
                write(currentFrame(), "roll_00_dark_open")
                advance(&p, StaffRoll.fadeSteps / 2)
                write(currentFrame(), "roll_00_black")
                // ...then the first plate lightens up, still without its credits.
                advance(&p, StaffRoll.fadeSteps / 2)
                write(currentFrame(), "roll_00_plate_fade")
                advance(&p, StaffRoll.fadeSteps / 2)
                write(currentFrame(), "roll_01_plate_in")
                for i in 0..<(StaffRoll.cards.count - 1) {
                    settle(&p, .creditHold(card: i))
                    write(currentFrame(), String(format: "roll_card%02d", i))
                    if i == 0 {
                        // The credits ride the palette fade down with the plate: `tputs`
                        // wrote them into vram, so `CLEAR` dims text and art together.
                        advance(&p, StaffRoll.cardHoldFlips + StaffRoll.fadeSteps / 2)
                        write(currentFrame(), "roll_02_dark_card")
                    }
                }
                // The last card holds for a `LvnsWaitClick`; a press is the only way out.
                settle(&p, .awaitingClick(card: StaffRoll.cards.count - 1))
                write(currentFrame(), "roll_card_last")
                p.click()
                advance(&p, StaffRoll.fadeSteps / 2)
                write(currentFrame(), "roll_90_close")
                advance(&p, StaffRoll.fadeSteps)
                write(currentFrame(), "roll_91_done")
                print("ROLL cards=\(StaffRoll.cards.count) " +
                      "cardFlips=\(StaffRoll.fadeSteps + StaffRoll.plateHoldFlips + StaffRoll.cardHoldFlips) " +
                      "awaiting=\(p.isAwaitingClick) finished=\(p.isFinished)")
                engine.finishStaffRoll()
                mode = .inGame
            case "sub":
                // §34 M4.11b — the four `0x01` sub-types. SCN024 blk01 carries the kind-01
                // (pc 19) and the kind-02 (pc 54); SCN051 blk01 the kind-03 insert.
                enterGame()
                engine.effectsEnabled = true
                engine.skip = false
                engine.start(scn: 24, block: 1)
                mode = .inGame
                // Headless stand-ins for the two App pumps.
                func drain(_ cap: Int = 3000) {
                    var n = 0
                    while engine.transition != nil, n < cap {
                        engine.bgmHoldSeconds = 0
                        engine.tickReveal(deltaTime: Self.tickerInterval)
                        n += 1
                    }
                }
                func clickOut(_ cap: Int = 3000) {
                    var n = 0
                    while engine.phase == .awaitingMessage, engine.transition == nil, n < cap {
                        n += 1
                        if n % 1000 == 0 { subTrace("clickOut n=\(n) msg=\(engine.currentMsg?.index ?? -1) reveal=\(engine.isRevealing) pause=\(engine.waitingPause.map(String.init(describing:)) ?? "nil")") }
                        engine.bgmHoldSeconds = 0
                        if engine.waitingPause == nil { engine.revealAll() }
                        while engine.isRevealing, n < cap {
                            engine.tickReveal(deltaTime: Self.tickerInterval)
                            n += 1
                        }
                        engine.advanceMessage()
                    }
                }
                func subTrace(_ s: String) {
                    FileHandle.standardError.write(("SUB " + s + "\n").data(using: .utf8)!)
                }
                func walkTo(_ cap: Int = 8000, _ stop: (ShizukuEngine) -> Bool) {
                    var n = 0
                    while !stop(engine) {
                        n += 1
                        if n > cap { subTrace("walk cap scn=\(engine.scnIndex) pc=\(engine.pc) phase=\(engine.phase)"); return }
                        if n % 500 == 0 { subTrace("walk n=\(n) scn=\(engine.scnIndex) pc=\(engine.pc) phase=\(engine.phase) reveal=\(engine.isRevealing) tr=\(engine.transition != nil)") }
                        drain(1)
                        if stop(engine) { return }
                        engine.bgmHoldSeconds = 0
                        if engine.phase == .awaitingMessage { clickOut(3000) }
                        if engine.phase == .awaitingChoice { engine.selectChoice(0) }
                        if engine.phase == .logoAnimation || engine.phase == .staffRoll { return }
                        if engine.phase == .ended {
                            subTrace("walk hit END scn=\(engine.scnIndex) pc=\(engine.pc)")
                            return
                        }
                        _ = engine.step()
                    }
                }
                // Kind-01: the sine is armed at the yield, message prints over it.
                walkTo { $0.backEffectActive && $0.phase == .awaitingMessage && $0.transition == nil }
                // Row i reads `sintable[(state + i) % 361]`; at state 88 the first row
                // sits near the +160 peak and the rows below sweep the whole curve.
                while engine.backEffectState < 88 { engine.tickReveal(deltaTime: Self.tickerInterval) }
                write(currentFrame(), "sub_sine_mid")
                // The kind-01 tail must be a live `CLEAR(FADE_PALETTE)` to black.
                clickOut()
                print("SUB kind01 tail sine=\(engine.backEffectActive) " +
                      "clear=\(String(describing: engine.transition?.clearEffect))")
                for _ in 0..<8 { engine.tickReveal(deltaTime: Self.tickerInterval) }
                write(currentFrame(), "sub_fade_to_black")
                drain()
                print("SUB kind01 wiped bg=\(engine.scene.bgName ?? "nil") " +
                      "portraits=\(engine.scene.portraits.count)")
                // Kind-02: yields *behind* its `DISP(FADE_PALETTE)` fade-in, sine already armed.
                walkTo { $0.backEffectActive && $0.phase == .awaitingMessage
                         && $0.transition?.dispEffect == .fadePalette }
                for _ in 0..<8 { engine.tickReveal(deltaTime: Self.tickerInterval) }
                write(currentFrame(), "sub_fade_in")
                drain()
                var sinePump = 0
                while (engine.backEffectState < 88 || engine.isRevealing), sinePump < 20000 {
                    engine.bgmHoldSeconds = 0
                    engine.tickReveal(deltaTime: Self.tickerInterval)
                    sinePump += 1
                }
                write(currentFrame(), "sub_sine_after_in")
                clickOut()
                print("SUB kind02 tail sine=\(engine.backEffectActive) " +
                      "transition=\(engine.transition != nil)")
                drain()
                // The kind-03 insert: sizuku01 mid-run and the sizuku02 closing plate.
                subTrace("pre-start 51")
                engine.start(scn: 51, block: 1)
                subTrace("SCN051 started phase=\(engine.phase)")
                walkTo { $0.phase == .logoAnimation }
                subTrace("walkTo returned phase=\(engine.phase) pc=\(engine.pc)")

                openLogoAnimation()
                subTrace("opened mode=\(mode) player=\(logoPlayer != nil)")
                if var lp = logoPlayer {
                    for _ in 0..<8 { lp.tick(flips: 1, skip: false) }
                    logoPlayer = lp
                    write(currentFrame(), "sub_logo_s07")
                    print("SUB sizuku01 flips=\(LogoAnimation.sizuku01.reduce(0) { $0 + 1 + $1.waitFlips }) " +
                          "plate=\(lp.frame?.name ?? "nil")")
                }
                logoPlayer = LogoAnimation.Player(number: 1)
                while logoPlayer?.frame?.name != "MAX_S37", !(logoPlayer?.isFinished ?? true) {
                    guard var q = logoPlayer else { break }
                    q.tick(flips: 1, skip: false)
                    logoPlayer = q
                }
                write(currentFrame(), "sub_logo_max")
                logoPlayer = nil
                engine.finishLogoAnimation()
                mode = .inGame
            case "toast":
                enterGame()
                showToast("セーブしました [しおり 3]")
                write(currentFrame(), "toast")
            case "menu":
                // The AppKit menu bar is chrome, not a game frame — dump its titles so the
                // ZH/JP label split (WP-13) is checkable headlessly.
                var lines: [String] = ["language=\(BuildLanguage.current)"]
                func walk(_ menu: NSMenu, _ depth: Int) {
                    for item in menu.items {
                        if item.isSeparatorItem { lines.append("\(String(repeating: "  ", count: depth + 1))---"); continue }
                        lines.append(String(repeating: "  ", count: depth + 1) + item.title)
                        if let sub = item.submenu { walk(sub, depth + 1) }
                    }
                }
                if let main = NSApp.mainMenu { walk(main, -1) }
                try? lines.joined(separator: "\n").write(toFile: "\(outDir)/menu_dump.txt",
                                                        atomically: true, encoding: .utf8)
            default:
                break
            }
        }
        completion()
    }

    /// Compact rect log for the `hit` verification token.
    private func describe(_ r: CGRect) -> String {
        String(format: "x=%.0f y=%.0f w=%.0f h=%.0f", r.minX, r.minY, r.width, r.height)
    }

    private func viewToNative(_ p: NSPoint) -> NSPoint {
        let r = fitRect()
        guard r.width > 0, r.height > 0 else { return NSPoint(x: 0, y: 0) }
        let sx = CGFloat(nativeWidth) / r.width
        let sy = CGFloat(nativeHeight) / r.height
        let nx = (p.x - r.origin.x) * sx
        let ny = (bounds.height - p.y - r.origin.y) * sy
        return NSPoint(x: nx, y: ny)
    }

    private func fitRect() -> NSRect {
        let ar = CGFloat(nativeWidth) / CGFloat(nativeHeight)
        var w = bounds.width
        var h = w / ar
        if h > bounds.height {
            h = bounds.height
            w = h * ar
        }
        return NSRect(x: (bounds.width - w) / 2, y: (bounds.height - h) / 2, width: w, height: h)
    }
}

extension MetalGameView: NSMenuItemValidation {
    /// Reflect current settings as checkmarks in the Mac menu bar.
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(openEscMenu), #selector(quickSave), #selector(quickLoad):
            // In-game only, like the original: the system menu lives over the game screen.
            // The transition test mirrors `openEscMenu`'s own guard, so the item never
            // looks clickable and then silently does nothing mid-effect.
            return mode == .inGame && (menuItem.action != #selector(openEscMenu)
                                        || engine.transition == nil)
        case #selector(openMusicRoom):
            // The room is reached from the title screen in the original, so the menu
            // item keeps that availability rather than interrupting a scene.
            return mode == .titleMenu
        case #selector(toggleFastForward):
            // 「選択肢まで早送り」 is a window-menu command (original: LvnsSkipTillSelect),
            // checkmark-driven so one item serves as both start and cancel.
            menuItem.state = isFastForward ? .on : .off
            return mode == .inGame
        case #selector(toggleFastWhenSeen):
            menuItem.state = engine.fastWhenSeen ? .on : .off
        case #selector(toggleForceSkip):
            menuItem.state = engine.forceSkip ? .on : .off
        case #selector(toggleEffectsEnabled):
            // The item reads 「画面エフェクトを省く」 ("omit screen effects"), so the
            // checkmark marks the *omitting* state: it is on exactly when effects are off.
            menuItem.state = engine.effectsEnabled ? .off : .on
        case #selector(setSkipHotkeyFromMenu(_:)):
            menuItem.state = (UInt16(menuItem.tag) == skipKeyCode) ? .on : .off
        case #selector(setFastForwardSpeedFromMenu(_:)):
            menuItem.state = (menuItem.tag == fastForwardSpeedTier) ? .on : .off
        default:
            break
        }
        return true
    }
}
