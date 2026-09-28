//
//  main.swift — ShizukuApp (macOS windowed runtime)
//
//  Hosts the SCN engine + LFG/CN-font renderer in a Metal-backed window. Click / space /
//  enter advances messages; number keys (or click) select choices. Fullscreen with Cmd-Ctrl-F.
//
//  Locates the extracted game data directory via (in order):
//    1. $SHIZUKU_DATA
//    2. ./research/extracted (from the working directory)
//    3. a fixed default under the user's Documents
//

import AppKit
import ShizukuCore
import ShizukuEngine
import ShizukuRender

enum ShizukuApp {
    /// Bundle name drives the menu bar + window title so the ZH bundle (WP-3) shows
    /// `Shizuku_Restored_ZH`; dev `swift run` has no plist and keeps the legacy name.
    static let name = (Bundle.main.infoDictionary?["CFBundleName"] as? String) ?? "Shizuku_Restored"
    static let version = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.1"
}

func findExtractedDir() -> String? {
    let fm = FileManager.default
    // Bundled app: data lives in <app>/Contents/Resources/gamedata.
    if let bundleData = Bundle.main.resourceURL?.appendingPathComponent("gamedata").path,
       fm.fileExists(atPath: bundleData) {
        return bundleData
    }
    if let env = ProcessInfo.processInfo.environment["SHIZUKU_DATA"], fm.fileExists(atPath: env) {
        return env
    }
    for cand in ["./research/extracted", "research/extracted"] {
        if let abs = URL(string: cand)?.standardizedFileURL.path, fm.fileExists(atPath: abs) {
            return abs
        }
        if fm.fileExists(atPath: cand) {
            return cand
        }
    }
    let fallback = "/Users/abc/Documents/shizuku_macos_experience/research/extracted"
    return fm.fileExists(atPath: fallback) ? fallback : nil
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var window: NSWindow!
    var gameView: MetalGameView!

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let dir = findExtractedDir() else {
            let alert = NSAlert()
            alert.messageText = "找不到游戏数据目录"
            alert.informativeText = "请设置 $SHIZUKU_DATA 指向已解包的 research/extracted 目录。"
            alert.runModal()
            NSApp.terminate(nil)
            return
        }
        let gameView = MetalGameView(extractedDir: dir, scale: 2)
        self.gameView = gameView

        let rect = NSRect(x: 0, y: 0, width: CGFloat(gameView.nativeWidth * gameView.scale),
                          height: CGFloat(gameView.nativeHeight * gameView.scale))
        let window = NSWindow(contentRect: rect, styleMask: [.titled, .closable, .resizable, .miniaturizable],
                              backing: .buffered, defer: false)
        window.title = "\(ShizukuApp.name) Ver.\(ShizukuApp.version) — " +
                       ShellText.windowGameTitle(BuildLanguage.current)
        window.collectionBehavior = [.fullScreenPrimary]
        window.contentAspectRatio = NSSize(width: 640, height: 400)
        window.contentView = gameView
        window.minSize = NSSize(width: 640, height: 400)
        window.delegate = self
        window.makeFirstResponder(gameView)
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window

        NSApp.activate(ignoringOtherApps: true)
        setupMainMenu()

        if let spec = ProcessInfo.processInfo.environment["SHIZUKU_SHOT"] {
            gameView.runShotSpec(spec) {
                print("shots written to /tmp/shizuku_shots for spec: \(spec)")
                NSApp.terminate(nil)
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    /// The red close button is a quit-intent path too — ask before closing
    /// (same dialog as the title menu's 終了 / Esc).
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if ProcessInfo.processInfo.environment["SHIZUKU_SHOT"] != nil { return true }
        let zh = BuildLanguage.current == .zh
        let alert = NSAlert()
        alert.messageText = zh ? "要退出游戏吗？" : "ゲームを終了しますか？"
        alert.informativeText = zh ? "退出后此窗口将被关闭。" : "終了するとこのウィンドウは閉じられます。"
        alert.addButton(withTitle: zh ? "退出" : "終了")
        alert.addButton(withTitle: zh ? "取消" : "キャンセル")
        return alert.runModal() == .alertFirstButtonReturn
    }

    /// The original had no in-game settings screen, so the remaster's only non-original
    /// affordances (skip-read toggles, configurable skip hotkey) live
    /// here in the Mac menu bar rather than as jarring in-game buttons (items 6/8).
    /// Display language is not among them: it is a build-time constant (M5.6 WP-2,
    /// HANDOVER §38.0 D1) resolved from Info.plist / environment, never a runtime toggle.
    ///
    /// Layout (item 1): three intent-named menus instead of a settings submenu buried under
    /// the app menu next to Quit. 「ゲーム」 = what you do (flow + saves), 「設定」 = how text
    /// advances, 「表示」 = screen. In the JP build every item carries a Chinese gloss because
    /// the bare Japanese labels read as cryptic, and shortcuts are printed by AppKit so they
    /// are discoverable rather than folklore. The ZH build routes every label through
    /// `t(jp:zh:)` and prints only the Chinese half — the JP strings stay verbatim.
    private func setupMainMenu() {
        let game: AnyObject? = gameView
        let zh = BuildLanguage.current == .zh
        /// Menu-bar label pair: JP keeps the remaster's 「日文（中文注）」 double-label
        /// format verbatim; ZH drops the Japanese head word and its parenthetical gloss,
        /// leaving the Chinese that was already the readable half.
        func t(_ jp: String, _ zhs: String) -> String { zh ? zhs : jp }
        let mainMenu = NSMenu()

        /// Adds a top-level menu and returns its submenu. Top-level items need an explicit
        /// title: an untitled NSMenuItem makes the menu bar show the placeholder class name.
        func topMenu(_ title: String) -> NSMenu {
            let item = NSMenuItem()
            item.title = title
            mainMenu.addItem(item)
            let menu = NSMenu(title: title)
            item.submenu = menu
            return menu
        }
        /// `key` defaults to "" (no shortcut). Items whose action lives on the view get an
        /// explicit target so validation reaches `MetalGameView.validateMenuItem`; passing
        /// nil routes through the responder chain, which is what AppKit's own commands want.
        @discardableResult
        func add(_ menu: NSMenu, _ title: String, _ action: Selector?, _ target: AnyObject?,
                 key: String = "", mask: NSEvent.ModifierFlags = .command) -> NSMenuItem {
            let it = menu.addItem(withTitle: title, action: action, keyEquivalent: key)
            if !key.isEmpty { it.keyEquivalentModifierMask = mask }
            it.target = target
            return it
        }

        // ── アプリメニュー ─────────────────────────────────────────────
        let appMenu = topMenu(ShizukuApp.name)
        add(appMenu, t("About \(ShizukuApp.name)", "关于 \(ShizukuApp.name)"),
            #selector(NSApplication.orderFrontStandardAboutPanel(_:)), nil)
        appMenu.addItem(.separator())
        add(appMenu, t("Hide \(ShizukuApp.name)", "隐藏 \(ShizukuApp.name)"),
            #selector(NSApplication.hide(_:)), nil, key: "h")
        add(appMenu, t("Hide Others", "隐藏其他"),
            #selector(NSApplication.hideOtherApplications(_:)), nil,
            key: "h", mask: [.command, .option])
        add(appMenu, t("Show All", "全部显示"),
            #selector(NSApplication.unhideAllApplications(_:)), nil)
        appMenu.addItem(.separator())
        add(appMenu, t("Quit \(ShizukuApp.name)", "退出 \(ShizukuApp.name)"),
            #selector(NSApplication.terminate(_:)), nil, key: "q")

        // ── ゲーム: 流程 + 存档 ─────────────────────────────────────────
        let gameMenu = topMenu(t("ゲーム", "游戏"))
        // No ⌘N: 「はじめから」 discards the running scenario outright.
        add(gameMenu, t("はじめから（重新剧情）", "重新剧情"),
            #selector(MetalGameView.startNewGame), game)
        add(gameMenu, t("つづきから（读取存档继续）", "读取存档继续"),
            #selector(MetalGameView.chooseSaveToContinue), game)
        // The original hides this behind an invisible 5th title-menu item; the menu item
        // is the discoverable route and stays disabled off the title screen.
        add(gameMenu, t("音楽モード（音乐播放器・仅标题画面）", "音乐播放器（仅标题画面）"),
            #selector(MetalGameView.openMusicRoom), game)
        gameMenu.addItem(.separator())
        add(gameMenu, t("クイックセーブ（快速存档）", "快速存档"),
            #selector(MetalGameView.quickSave), game, key: "s")
        add(gameMenu, t("クイックロード（快速读档）", "快速读档"),
            #selector(MetalGameView.quickLoad), game, key: "l")
        gameMenu.addItem(.separator())
        // Original fidelity: fast-forward is a window-menu command (「選択肢まで早送り」 =
        // LvnsSkipTillSelect, skip until next choice), not a held key. Checkmark-driven
        // toggle — the same item cancels back to normal speed; Tab/Z hotkeys stay as a
        // convenience and route to this same toggleFastForward selector.
        add(gameMenu, t("選択肢まで早送り（快进，再点取消）", "快进（再点取消）"),
            #selector(MetalGameView.toggleFastForward), game, key: "t")
        add(gameMenu, t("システムメニュー（系统菜单）", "系统菜单"),
            #selector(MetalGameView.openEscMenu), game, key: "e")

        // ── 設定: 文本推进 + 按键 ───────────────────────────────────────
        let settingsMenu = topMenu(t("設定", "设置"))
        add(settingsMenu, t("既読テキストを自動略し（已读自动跳过）", "已读文本自动跳过"),
            #selector(MetalGameView.toggleFastWhenSeen), game)
        add(settingsMenu, t("早送りで未読もスキップ（快进时连未读一并跳过）", "快进时连未读一并跳过"),
            #selector(MetalGameView.toggleForceSkip), game)
        settingsMenu.addItem(.separator())
        let hotkeyItem = settingsMenu.addItem(withTitle: t("スキップキー（跳过按键）", "跳过按键"),
                                             action: nil, keyEquivalent: "")
        let hotkeyMenu = NSMenu(title: t("スキップキー", "跳过按键"))
        hotkeyItem.submenu = hotkeyMenu
        for choice in MetalGameView.skipHotkeyChoices {
            let it = hotkeyMenu.addItem(withTitle: choice.label,
                                        action: #selector(MetalGameView.setSkipHotkeyFromMenu(_:)),
                                        keyEquivalent: "")
            it.target = game
            it.tag = Int(choice.code)
        }

        // 快进速度三档（项8）: 遅い/普通/速い — 速い is the reference's one-step-per-flip
        // ceiling, 普通 keeps the pace we shipped before the option existed.
        let ffSpeedItem = settingsMenu.addItem(withTitle: t("早送り速度（快进速度）", "快进速度"),
                                               action: nil, keyEquivalent: "")
        let ffSpeedMenu = NSMenu(title: t("早送り速度", "快进速度"))
        ffSpeedItem.submenu = ffSpeedMenu
        for (tier, choice) in MetalGameView.fastForwardSpeedChoices.enumerated() {
            let it = ffSpeedMenu.addItem(withTitle: zh ? choice.zhLabel : choice.label,
                                         action: #selector(MetalGameView.setFastForwardSpeedFromMenu(_:)),
                                         keyEquivalent: "")
            it.target = game
            it.tag = tier
        }

        // ── 表示: 画面 ──────────────────────────────────────────────────
        let viewMenu = topMenu(t("表示", "显示"))
        add(viewMenu, t("フルスクリーン（全屏）", "全屏"),
            #selector(MetalGameView.toggleFullScreenFromMenu), game,
            key: "f", mask: [.command, .control])
        // The reference engine's own `-n e` switch: wipes collapse to a single blit.
        add(viewMenu, t("画面エフェクトを省く（关闭转场动画，直接切换）", "关闭转场动画（直接切换）"),
            #selector(MetalGameView.toggleEffectsEnabled), game)

        NSApp.mainMenu = mainMenu
    }
}

// The headless verification harness prints its diagnostics; unbuffered stdout means a run
// that is killed or hangs still shows what it got to.
setbuf(stdout, nil)

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
