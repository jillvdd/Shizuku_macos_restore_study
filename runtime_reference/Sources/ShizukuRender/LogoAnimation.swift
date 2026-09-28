//
//  LogoAnimation.swift
//  ShizukuRender
//
//  Port of the `0x01` kind-03 insert: `LvnsAnimation(lvns, (c[2] == 0) ? sizuku01 :
//  sizuku02)` (`sizuku.c:598-602`), the tables at `sizuku.c:25-89`, and the player loop
//  in `LvnsAnim.c:43-111`.
//
//  Loop semantics worth the comments below, all from `LvnsAnim.c`:
//   * every image entry is `lvnsimage_clear(vram)` + blit at its (x, y) — black, then
//     one plate, nothing composited over it; `latitude = 11 → 16` no dim (`:105`).
//   * an entry holds `time * INTERVAL / 1000` *additional* flips on top of its own
//     display flip (`:106`'s `while (wait_time-- > 0 || !Animation(...))`). With
//     `time = 10` and `INTERVAL = 60` that integer division is 0: each frame gets
//     exactly one flip — this insert runs at full 60 fps, far faster than the boot OP
//     (whose table carries `time = 50` → 3 flips per frame).
//   * `LVNS_ANIM_SOUND` re-triggers the *loaded* sound slot once (`LvnsSound.c:55-62`).
//     Shizuku never loads that slot on any path (`LvnsLoadSound` only appears in the
//     voice-data branch `sizuku.c:434`, unused by these scripts), so the original is
//     silently inert here and so are we — see `wantsSound` for the observable hook.
//   * `LvnsFlip` polls no input: clicks are lost; `lvns->skip` only zeroes the
//     remaining wait (`LvnsAnim.c:108-109`), which for these tables means WAIT 200's
//     12 flips collapse but the 1-flip frames keep their cadence.
//

import Foundation
import ShizukuEngine

public enum LogoAnimation {
    public static let nativeWidth = 640
    public static let nativeHeight = 400

    /// One table row. `waitFlips` = `time * 60 / 1000` extra flips after the display
    /// flip; `x`/`y` are logical px.
    public struct Entry {
        public enum Kind { case image, sound, wait }
        public let kind: Kind
        public let name: String?
        public let x: Int
        public let y: Int
        public let waitFlips: Int
    }

    private static func plate(_ n: Int) -> Entry {
        Entry(kind: .image, name: String(format: "OP_S%02d", n), x: 0, y: 160, waitFlips: 0)
    }
    private static let sound = Entry(kind: .sound, name: nil, x: 0, y: 0, waitFlips: 0)
    /// `LVNS_ANIM_WAIT, 200` → 200*60/1000 = 12 extra flips.
    private static let wait200 = Entry(kind: .wait, name: nil, x: 0, y: 0, waitFlips: 12)

    /// `sizuku01` (`sizuku.c:25-65`): 17 calligraphy frames (SOUND after the third),
    /// hold, then the same run again, hold.
    public static let sizuku01: [Entry] = [
        plate(0), plate(1), plate(2), sound,
        plate(3), plate(4), plate(5), plate(6), plate(7), plate(8), plate(9),
        plate(10), plate(11), plate(12), plate(13), plate(14), plate(15), plate(16),
        wait200,
        plate(0), plate(1), plate(2), sound,
        plate(3), plate(4), plate(5), plate(6), plate(7), plate(8), plate(9),
        plate(10), plate(11), plate(12), plate(13), plate(14), plate(15), plate(16),
        wait200,
    ]

    /// `sizuku02` (`sizuku.c:68-89`): one calligraphy run, then the `MAX_S37` plate.
    public static let sizuku02: [Entry] = [
        plate(0), plate(1), plate(2), sound,
        plate(3), plate(4), plate(5), plate(6), plate(7), plate(8), plate(9),
        plate(10), plate(11), plate(12), plate(13), plate(14), plate(15), plate(16),
        Entry(kind: .image, name: "MAX_S37", x: 0, y: 0, waitFlips: 0),
    ]

    public static func table(number: Int) -> [Entry] {
        number == 0 ? sizuku01 : sizuku02
    }

    /// Flip-accurate player. The App pumps `tick(flips:skip:)` from its 60 Hz ticker,
    /// draws `frame` per flip, and hands the screen back at `isFinished`.
    public struct Player {
        public private(set) var entryIndex = -1
        private var remaining = 0
        private(set) var current: Entry?

        /// Set when a SOUND entry fires, for the App to surface (and reset) — see the
        /// header note about the inert original.
        public private(set) var wantsSound = false

        public let entries: [Entry]

        public init(number: Int) {
            entries = LogoAnimation.table(number: number)
        }

        public var isFinished: Bool { entryIndex >= entries.count }

        /// The plate on screen this flip. Only IMAGE entries touch vram
        /// (`lvnsimage_clear` + blit + display, `LvnsAnim.c`), so WAIT and SOUND entries
        /// keep showing the previous plate — the trailing `WAIT(200)` is 12 flips of the
        /// last calligraphy frame, not a cut to black.
        public var frame: (name: String, x: Int, y: Int)? {
            guard !isFinished else { return nil }
            if let e = current, e.kind == .image, let name = e.name { return (name, e.x, e.y) }
            for i in stride(from: entryIndex - 1, through: 0, by: -1) {
                let e = entries[i]
                if e.kind == .image, let name = e.name { return (name, e.x, e.y) }
            }
            return nil
        }

        public mutating func tick(flips: Int, skip: Bool) {
            for _ in 0..<flips {
                if isFinished { return }
                // `LvnsAnim.c:108-109`: skip zeroes the pending wait, entry by entry.
                if skip { remaining = 0 }
                if remaining > 0 {
                    remaining -= 1
                    continue
                }
                advance()
            }
        }

        private mutating func advance() {
            entryIndex += 1
            guard entryIndex < entries.count else { current = nil; return }
            let e = entries[entryIndex]
            current = e
            remaining = e.waitFlips
            if e.kind == .sound { wantsSound = true }
        }
    }

    // MARK: - Rendering

    /// `lvnsimage_clear(vram)` then the plate at (x, y): black canvas, undimmed.
    public static func render(game: GameData, player: Player, scale: Int) -> RGBAImage {
        var img = RGBAImage(width: nativeWidth * scale, height: nativeHeight * scale)
        img.fill(0, 0, 0, 255)
        if let f = player.frame, let plate = game.image(name: f.name) {
            img.blitScaled(plate, dx: f.x * scale, dy: f.y * scale, factor: scale)
        }
        for p in stride(from: 3, to: img.pixels.count, by: 4) { img.pixels[p] = 255 }
        return img
    }
}
