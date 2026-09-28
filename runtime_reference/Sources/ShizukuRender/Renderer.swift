//
//  Renderer.swift
//  ShizukuRender
//
//  Headless RGBA frame buffer + text rasterization + pure-Swift PNG encoder.
//  Uses the Compression framework (COMPRESSION_ZLIB) for PNG deflate.
//

import Foundation
import Compression

public struct RGBAImage {
    public var width: Int
    public var height: Int
    public var pixels: [UInt8]  // w*h*4, (r,g,b,a)

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
        self.pixels = [UInt8](repeating: 0, count: width * height * 4)
    }

    public mutating func setPixel(_ x: Int, _ y: Int, _ r: UInt8, _ g: UInt8, _ b: UInt8, _ a: UInt8 = 255) {
        guard x >= 0, x < width, y >= 0, y < height else { return }
        let i = (y * width + x) * 4
        pixels[i] = r; pixels[i + 1] = g; pixels[i + 2] = b; pixels[i + 3] = a
    }

    // Blit a w*h RGBA buffer with optional per-pixel alpha at (dx,dy).
    // 'alpha' selects whether to alpha-blend (true = source-over) or overwrite.
    public mutating func blit(_ src: [UInt8], sw: Int, sh: Int, dx: Int, dy: Int, alpha: Bool) {
        for sy in 0..<sh {
            let ty = dy + sy
            guard ty >= 0, ty < height else { continue }
            for sx in 0..<sw {
                let tx = dx + sx
                guard tx >= 0, tx < width else { continue }
                let si = (sy * sw + sx) * 4
                let a = src[si + 3]
                if !alpha || a == 255 {
                    let di = (ty * width + tx) * 4
                    pixels[di] = src[si]; pixels[di + 1] = src[si + 1]
                    pixels[di + 2] = src[si + 2]; pixels[di + 3] = 255
                } else if a == 0 {
                    continue
                } else {
                    let di = (ty * width + tx) * 4
                    let ai = Int(a)
                    let inv = 255 - ai  // dst is opaque
                    pixels[di] = UInt8((Int(src[si]) * ai + Int(pixels[di]) * inv) / 255)
                    pixels[di + 1] = UInt8((Int(src[si + 1]) * ai + Int(pixels[di + 1]) * inv) / 255)
                    pixels[di + 2] = UInt8((Int(src[si + 2]) * ai + Int(pixels[di + 2]) * inv) / 255)
                    pixels[di + 3] = 255
                }
            }
        }
    }

    /// Box-filtered resample to `w`x`h` (thumbnailing). Averaging rather than point
    /// sampling matters here: the 1996 art is heavily ordered-dithered, and picking one
    /// source pixel per cell breaks the dither up into noise.
    public func resized(to w: Int, _ h: Int) -> RGBAImage {
        guard w > 0, h > 0 else { return RGBAImage(width: 1, height: 1) }
        var out = RGBAImage(width: w, height: h)
        for y in 0..<h {
            let y0 = y * height / h, y1 = max(y0 + 1, (y + 1) * height / h)
            for x in 0..<w {
                let x0 = x * width / w, x1 = max(x0 + 1, (x + 1) * width / w)
                var sr = 0, sg = 0, sb = 0, n = 0
                for sy in y0..<y1 {
                    for sx in x0..<x1 {
                        let i = (sy * width + sx) * 4
                        sr += Int(pixels[i]); sg += Int(pixels[i + 1]); sb += Int(pixels[i + 2])
                        n += 1
                    }
                }
                out.setPixel(x, y, UInt8(sr / n), UInt8(sg / n), UInt8(sb / n))
            }
        }
        return out
    }

    public mutating func fill(_ r: UInt8, _ g: UInt8, _ b: UInt8, _ a: UInt8 = 255) {
        for i in stride(from: 0, to: pixels.count, by: 4) {
            pixels[i] = r; pixels[i + 1] = g; pixels[i + 2] = b; pixels[i + 3] = a
        }
    }

    public func encodePNG() -> Data {
        let sig: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        var ihdr: [UInt8] = []
        func be(_ v: Int, _ n: Int) {
            for k in stride(from: n - 1, through: 0, by: -1) { ihdr.append(UInt8((v >> (k * 8)) & 0xff)) }
        }
        be(width, 4); be(height, 4); ihdr.append(8); ihdr.append(6); ihdr.append(0); ihdr.append(0); ihdr.append(0)

        // Build raw scanlines with filter byte 0
        var raw = [UInt8](repeating: 0, count: height * (width * 4 + 1))
        for y in 0..<height {
            let rowStart = y * (width * 4 + 1)
            raw[rowStart] = 0
            for x in 0..<width {
                let pi = (y * width + x) * 4
                let ri = rowStart + 1 + x * 4
                let a = pixels[pi + 3]
                // Straight alpha, not premultiplied
                raw[ri] = pixels[pi]; raw[ri + 1] = pixels[pi + 1]
                raw[ri + 2] = pixels[pi + 2]; raw[ri + 3] = a
            }
        }

        let compressed = zlibCompress(raw)
        var out = Data(sig)
        out.append(chunk("IHDR", Data(ihdr)))
        out.append(chunk("IDAT", compressed))
        out.append(chunk("IEND", Data()))
        return out
    }

    private func chunk(_ tag: String, _ data: Data) -> Data {
        var d = Data()
        let len = UInt32(data.count)
        d.append(UInt8((len >> 24) & 0xff)); d.append(UInt8((len >> 16) & 0xff))
        d.append(UInt8((len >> 8) & 0xff)); d.append(UInt8(len & 0xff))
        d.append(Data(tag.utf8))
        d.append(data)
        let crc = crc32(Data(tag.utf8) + data)
        d.append(UInt8((crc >> 24) & 0xff)); d.append(UInt8((crc >> 16) & 0xff))
        d.append(UInt8((crc >> 8) & 0xff)); d.append(UInt8(crc & 0xff))
        return d
    }

    private func zlibCompress(_ input: [UInt8]) -> Data {
        // compression_encode_buffer(COMPRESSION_ZLIB) yields RAW deflate (RFC 1951),
        // so we must wrap it in a zlib stream (RFC 1950): 2-byte header + Adler-32.
        let dstCap = input.count + input.count / 2 + 256
        var dst = [UInt8](repeating: 0, count: dstCap)
        let written = input.withUnsafeBytes { srcBuf in
            dst.withUnsafeMutableBytes { dstBuf in
                compression_encode_buffer(dstBuf.bindMemory(to: UInt8.self).baseAddress!, dstCap,
                                          srcBuf.bindMemory(to: UInt8.self).baseAddress!, input.count,
                                          nil, COMPRESSION_ZLIB)
            }
        }
        guard written > 0 else {
            // Raw-store fallback (deflate stored block)
            var s = [UInt8]()
            s.append(0x78); s.append(0x9C)
            s += deflateStore(input)
            s += adler32(input)
            return Data(s)
        }
        var out = [UInt8]()
        out.append(0x78); out.append(0x9C)
        out += dst[0..<written]
        out += adler32(input)
        return Data(out)
    }

    private func deflateStore(_ input: [UInt8]) -> [UInt8] {
        // Uncompressed deflate blocks (BTYPE=00). Max 65535 bytes per block.
        var s: [UInt8] = []
        var i = 0
        var first = true
        while i < input.count {
            let n = min(65535, input.count - i)
            if first { s.append(0x01); first = false } else { s.append(0x00) }
            let l = n, nl = l ^ 0xffff
            s.append(UInt8(l & 0xff)); s.append(UInt8((l >> 8) & 0xff))
            s.append(UInt8(nl & 0xff)); s.append(UInt8((nl >> 8) & 0xff))
            s += input[i..<i + n]
            i += n
        }
        if input.isEmpty {
            s = [0x01, 0x00, 0x00, 0xff, 0xff]
        }
        return s
    }

    private func adler32(_ data: [UInt8]) -> [UInt8] {
        var a: UInt32 = 1, b: UInt32 = 0
        for d in data {
            a = (a + UInt32(d)) % 65521
            b = (b + a) % 65521
        }
        let v = (b << 16) | a
        return [UInt8((v >> 24) & 0xff), UInt8((v >> 16) & 0xff), UInt8((v >> 8) & 0xff), UInt8(v & 0xff)]
    }

    private func crc32(_ bytes: Data) -> UInt32 {
        var crc: UInt32 = 0xffffffff
        var table = [UInt32](repeating: 0, count: 256)
        for i in 0..<256 {
            var c = UInt32(i)
            for _ in 0..<8 {
                c = (c & 1) != 0 ? (0xedb88320 ^ (c >> 1)) : (c >> 1)
            }
            table[i] = c
        }
        for b in bytes {
            crc = table[Int((crc ^ UInt32(b)) & 0xff)] ^ (crc >> 8)
        }
        return crc ^ 0xffffffff
    }
}
