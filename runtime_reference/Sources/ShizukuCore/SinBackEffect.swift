//
//  SinBackEffect.swift
//  ShizukuCore
//
//  Port of the original's sine background distortion, `lvnsSinEffect`
//  (mglvns `sin_effect.c:17-20` table, `:114-157` driver). The 1996 engine drives it
//  from `0x01` sub-types 01/02 (`sizuku.c:580-597`): the *background plate only* is
//  sheared row-by-row by `sintable[state + row]` while the message prints over it —
//  characters and text merge AFTER the effect (`SinEffect` ends with `mergeCharacter`),
//  so sprites and glyphs never distort.
//
//  Timing (`Lvns.c:308-320` + `LvnsBackEffect.c`): one `LvnsFlip` advances
//  `effect_back_state += 8` mod 361 and redraws; `LvnsSetBackEffect` resets the state
//  to 0 when the effect is armed (`LvnsBackEffect.c:55-59`), i.e. row 0 starts at
//  sine 0 on the first rippling frame.
//

import Foundation

public enum SinBackEffect {
    /// `sintable[361]` verbatim — degrees 0..360 sampled at 1° steps, amplitude 160 px
    /// on the 640-px screen. Sum is -1 (both endpoints carry 0); do not "fix" it.
    public static let table: [Int] = [
        0,2,5,8,11,13,16,19,22,25,27,30,33,
        35,38,41,44,46,49,52,54,57,59,62,65,67,
        70,72,75,77,79,82,84,87,89,91,94,96,98,
        100,102,104,107,109,111,113,115,117,118,120,122,124,
        126,127,129,131,132,134,135,137,138,139,141,142,143,
        145,146,147,148,149,150,151,152,153,153,154,155,155,
        156,157,157,158,158,158,159,159,159,159,159,159,160,
        159,159,159,159,159,159,158,158,158,157,157,156,155,
        155,154,153,153,152,151,150,149,148,147,146,145,143,
        142,141,139,138,137,135,134,132,131,129,127,126,124,
        122,120,118,117,115,113,111,109,107,104,102,100,98,
        96,94,91,89,87,84,82,80,77,75,72,70,67,
        65,62,59,57,54,52,49,46,44,41,38,35,33,
        30,27,25,22,19,16,13,11,8,5,2,0,-2,
        -5,-8,-11,-13,-16,-19,-22,-25,-27,-30,-33,-35,-38,
        -41,-44,-46,-49,-52,-54,-57,-59,-62,-65,-67,-70,-72,
        -75,-77,-80,-82,-84,-87,-89,-91,-94,-96,-98,-100,-102,
        -104,-107,-109,-111,-113,-115,-117,-118,-120,-122,-124,-126,-127,
        -129,-131,-132,-134,-135,-137,-138,-139,-141,-142,-143,-145,-146,
        -147,-148,-149,-150,-151,-152,-153,-153,-154,-155,-155,-156,-157,
        -157,-158,-158,-158,-159,-159,-159,-159,-159,-159,-160,-159,-159,
        -159,-159,-159,-159,-158,-158,-158,-157,-157,-156,-155,-155,-154,
        -153,-153,-152,-151,-150,-149,-148,-147,-146,-145,-143,-142,-141,
        -139,-138,-137,-135,-134,-132,-131,-129,-127,-126,-124,-122,-120,
        -118,-117,-115,-113,-111,-109,-107,-104,-102,-100,-98,-96,-94,
        -91,-89,-87,-84,-82,-80,-77,-75,-72,-70,-67,-65,-62,
        -59,-57,-54,-52,-49,-46,-44,-41,-38,-35,-33,-30,-27,
        -25,-22,-19,-16,-13,-11,-8,-5,-2,0
    ]

    /// `SinEffectSetState` (`sin_effect.c:118`): `effect_back_state += 8`.
    public static let stateStep = 8

    /// Table size — `SINTABLESIZE` (`sin_effect.c:21`).
    public static var size: Int { table.count }

    /// Row `row` of a flip whose state is `state` shifts by this many logical px.
    /// `SinEffect` (`sin_effect.c:139-154`): `p` starts at the state and walks the
    /// table one entry per row, wrapping at the table size. Positive shifts slide the
    /// plate left (black band trails on the right); negative slide it right.
    public static func rowShift(state: Int, row: Int) -> Int {
        table[(state + row) % size]
    }

    /// One flip of the state machine.
    public static func nextState(_ state: Int) -> Int {
        (state + stateStep) % size
    }
}
