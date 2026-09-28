//
//  Lzs.swift
//  ShizukuCore
//
//  Three LZS/LZSS variants used by the game data.
//  - decodeInv: SCN event/message data (cmd_disasm.lzs_decode_inv — the one cmd_disasm,
//    cmd_text, cmd_cntext all import). Ring 0x1011, inverted flags, idx=0xFEE.
//    NOTE: this is DIFFERENT from scn.py's same-named function; the CLI uses cmd_disasm's.
//  - lzs:      LEAFPACK image data (lfg.py::lzs_decode). Ring 0x1000, non-inverted, m=0xFEE.
//  - leafLzs / leafLzs3: LEAFPACK container variants (unpack_leafpack.py), kept for completeness.
//

import Foundation

public enum LZS {

    /// SCN messages/events: inverted flag bits. Ported 1:1 from cmd_disasm.py::lzs_decode_inv.
    /// NOTE: uses buf size 0x1000 and initial index 0 (this DIFFERS from scn.py's same-named
    /// function which uses 0x1011/0xFEE). cmd_disasm is the one cmd_text/cmd_cntext import.
    ///
    /// `outSize` is the segment's declared size (`d1Size`/`d2Size`, the u32 at the segment
    /// header). The decoder has no internal end-of-stream marker: fed the whole remaining file
    /// it keeps emitting until the compressed bytes run out, producing hundreds of junk bytes
    /// past the real data (the tail of almost every SCN file decodes to a run of 0x00/0xFF).
    /// The message-offset table only covers the declared region, so those extra bytes were
    /// being attributed to the *last* message of each script and parsed as text/spurious
    /// inline commands. Truncating here is what keeps message parsing deterministic.
    public static func decodeInv(_ src: [UInt8], outSize: Int? = nil) -> [UInt8] {
        var buf = [UInt8](repeating: 0, count: 0x1000)
        var dst: [UInt8] = []
        var index = 0xFEE
        var i = 0
        var flag: UInt8 = 0
        var flagCount = 0
        let limit = outSize ?? Int.max
        while i < src.count && dst.count < limit {
            if flagCount > 0 {
                flagCount -= 1
                flag = flag << 1
            } else {
                flag = ~src[i]
                i += 1
                flagCount = 7
            }
            if i >= src.count { break }
            if (flag & 0x80) != 0 {
                let b = ~src[i]
                i += 1
                dst.append(b)
                buf[index] = b
                index = (index + 1) & 0xfff
            } else {
                if i + 1 >= src.count { break }
                let lf = ~(UInt16(src[i]) + (UInt16(src[i + 1]) << 8))
                i += 2
                let llen = Int(lf & 0xf) + 3
                var lidx = Int((lf >> 4) & 0xfff)
                for _ in 0..<llen {
                    let b = buf[lidx]
                    lidx = (lidx + 1) & 0xfff
                    dst.append(b)
                    buf[index] = b
                    index = (index + 1) & 0xfff
                }
            }
        }
        // An LZ match may overshoot `limit` by up to 17 bytes; the message-offset table is
        // sized against the declared region, so clip to it exactly.
        return outSize == nil ? dst : Array(dst.prefix(outSize!))
    }

    /// LEAFCODE (LFG) images: `leafpack_lzs`, ring 0x1000, non-inverted flags,
    /// left-shift flag bits, m=0xFEE. Ported 1:1 from mglvns leafpack.c.
    /// This is the ONLY variant that decodes LFG correctly (lfgdec.c/lfg.c agree).
    public static func lzs(_ src: [UInt8], outSize: Int) -> [UInt8] {
        guard outSize >= 0 else { return [] }   // a corrupt u32 header must not trap Array(count:)
        var out = [UInt8](repeating: 0, count: outSize)
        var ring = [UInt8](repeating: 0, count: 0x1000)
        var i = 0
        var c = 0
        var m = 0xFEE
        var s = 0
        var flag = 0
        while i < outSize {
            c -= 1
            if c < 0 {
                if s >= src.count { break }
                flag = Int(src[s]); s += 1
                c = 7
            }
            if (flag & 0x80) != 0 {
                if s >= src.count { break }
                let b = src[s]; s += 1
                out[i] = b; ring[m] = b
                m += 1; m &= 0xFFF
                i += 1
            } else {
                if s + 1 >= src.count { break }
                let d = Int(src[s]) | (Int(src[s + 1]) << 8)
                s += 2
                let ln = (d & 0x0F) + 3
                var pos = d >> 4
                for _ in 0..<ln {
                    let b = ring[pos]
                    out[i] = b; ring[m] = b
                    m += 1; m &= 0xFFF
                    pos += 1; pos &= 0xFFF
                    i += 1
                    if i >= outSize { break }
                }
            }
            flag = (flag << 1) & 0xFF
        }
        return out
    }

    /// leafpack_lzs: non-inverted flags, ring 0x1000 (unpack_leafpack.py).
    public static func leafLzs(_ src: [UInt8], outSize: Int) -> [UInt8] {
        guard outSize >= 0 else { return [] }
        var out = [UInt8](repeating: 0, count: outSize)
        var ring = [UInt8](repeating: 0, count: 0x1000)
        var m = 0xFEE
        var c = 0
        var flag: UInt8 = 0
        var i = 0
        var s = 0
        while i < outSize {
            c -= 1
            if c < 0 {
                if s >= src.count { break }
                flag = src[s]; s += 1
                c = 7
            }
            if (flag & 0x80) != 0 {
                if s >= src.count { break }
                let b = src[s]; s += 1
                out[i] = b; ring[m] = b
                m &= 0xFFF
                i += 1
            } else {
                if s + 1 >= src.count { break }
                let d = UInt16(src[s]) | (UInt16(src[s + 1]) << 8)
                s += 2
                let ln = Int(d & 0x0F) + 3
                var pos = Int(d >> 4)
                for _ in 0..<ln {
                    out[i] = ring[pos]
                    ring[m] = ring[pos]
                    m &= 0xFFF
                    pos &= 0xFFF
                    i += 1
                    if i >= outSize { break }
                }
            }
            flag = flag << 1
        }
        return out
    }

    /// leafpack_lzs3: inverted flags, ring 0x1011, idx=0xFEE (unpack_leafpack.py).
    public static func leafLzs3(_ src: [UInt8], outSize: Int) -> [UInt8] {
        guard outSize >= 0 else { return [] }
        var out = [UInt8](repeating: 0, count: outSize)
        var tb = [UInt8](repeating: 0, count: 0x1011)
        var idx = 0xFEE
        var srcI = 0
        var flag: UInt8 = 0
        var flagCount = 0
        var wrote = 0
        while wrote < outSize {
            if flagCount > 0 {
                flagCount -= 1
                flag = flag << 1
            } else {
                if srcI >= src.count { break }
                flag = ~src[srcI]; srcI += 1
                flagCount = 7
            }
            if (flag & 0x80) != 0 {
                if srcI >= src.count { break }
                let b = ~src[srcI]; srcI += 1
                tb[idx] = b
                idx = (idx + 1) & 0xFFF
                out[wrote] = b; wrote += 1
            } else {
                if srcI + 1 >= src.count { break }
                let lflag = ~(UInt16(src[srcI]) + (UInt16(src[srcI + 1]) << 8))
                srcI += 2
                let ln = Int(lflag & 0xF) + 3
                var lindex = Int((lflag >> 4) & 0xFFF)
                for _ in 0..<ln {
                    let b = tb[lindex]
                    lindex = (lindex + 1) & 0xFFF
                    tb[idx] = b
                    idx = (idx + 1) & 0xFFF
                    out[wrote] = b; wrote += 1
                    if wrote >= outSize { break }
                }
            }
        }
        return out
    }
}
