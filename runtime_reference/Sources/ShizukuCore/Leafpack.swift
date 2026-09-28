//
//  Leafpack.swift
//  ShizukuCore
//
//  LEAFPACK archive container. Socket: data XOR-keyed? NO — file data is
//  SUBTRACT-keyed (dekey), file table SUBTRACT-keyed, per unpack_leafpack.py
//  (the verified 403/403 extractor). cmd_extract.py's XOR is a latent bug.
//
//  Reference: XLVNS/mglvns leafpack.c by Go Watanabe (BSD).
//

import Foundation

public struct LeafpackEntry {
    public let name: String
    public let offset: Int
    public let size: Int
    public let nextOffset: Int
    public init(name: String, offset: Int, size: Int, nextOffset: Int) {
        self.name = name; self.offset = offset; self.size = size; self.nextOffset = nextOffset
    }
}

public enum Leafpack {
    public static let magic = "LEAFPACK"
    public static let keyLen = 11

    /// Recover the 11-byte rolling key from the archive's own file table (needs >= 3 files).
    /// nil for truncated/corrupt archives.
    public static func guessKey(_ data: [UInt8]) -> [UInt8]? {
        guard data.count >= 10 else { return nil }
        let n = Int(data[8]) | (Int(data[9]) << 8)
        guard n >= 3 else { return nil }
        let start = data.count - 24 * n
        guard start >= 0, data.count - start >= 24 * 4 else { return nil }
        let p = Array(data[start..<start + 24 * 4])
        var key = [UInt8](repeating: 0, count: keyLen)
        key[0] = p[11]
        key[1] = UInt8(truncatingIfNeeded: Int(p[12]) - 0x0a)
        key[2] = p[13]
        key[3] = p[14]
        key[4] = p[15]
        key[5] = UInt8(truncatingIfNeeded: Int(p[38]) - Int(p[22]) + Int(key[0]))
        key[6] = UInt8(truncatingIfNeeded: Int(p[39]) - Int(p[23]) + Int(key[1]))
        key[7] = UInt8(truncatingIfNeeded: Int(p[62]) - Int(p[46]) + Int(key[2]))
        key[8] = UInt8(truncatingIfNeeded: Int(p[63]) - Int(p[47]) + Int(key[3]))
        key[9] = UInt8(truncatingIfNeeded: Int(p[20]) - Int(p[36]) + Int(key[3]))
        key[10] = UInt8(truncatingIfNeeded: Int(p[21]) - Int(p[37]) + Int(key[4]))
        return key
    }

    /// (b - key[i%11]) & 0xff  — authoritative decryption for both file data and table.
    public static func dekey(_ buf: ArraySlice<UInt8>, _ key: [UInt8]) -> [UInt8] {
        var out = [UInt8](repeating: 0, count: buf.count)
        for (i, b) in buf.enumerated() {
            out[i] = UInt8(truncatingIfNeeded: Int(b) - Int(key[i % keyLen]))
        }
        return out
    }

    public static func parseTable(_ data: [UInt8], _ key: [UInt8]) -> [LeafpackEntry] {
        guard data.count >= 10, key.count >= keyLen else { return [] }
        let n = Int(data[8]) | (Int(data[9]) << 8)
        var start = data.count - 24 * n
        guard start >= 0, data.count - start >= 24 * n else { return [] }
        var entries: [LeafpackEntry] = []
        var k = 0
        for _ in 0..<n {
            var raw = [UInt8](repeating: 0, count: 24)
            for j in 0..<24 {
                raw[j] = UInt8(truncatingIfNeeded: Int(data[start + j]) - Int(key[(k + j) % keyLen]))
            }
            k = (k + 24) % keyLen
            start += 24
            var name = ""
            var i = 0
            while i < 8 && raw[i] != 0x20 {
                name.append(Character(UnicodeScalar(raw[i])))
                i += 1
            }
            let ext = String(bytes: raw[8..<11], encoding: .isoLatin1) ?? ""
            let trimmed = name.trimmingCharacters(in: .whitespaces)
            let pos = Int(raw[12]) | (Int(raw[13]) << 8) | (Int(raw[14]) << 16) | (Int(raw[15]) << 24)
            let ln = Int(raw[16]) | (Int(raw[17]) << 8) | (Int(raw[18]) << 16) | (Int(raw[19]) << 24)
            let nxt = Int(raw[20]) | (Int(raw[21]) << 8) | (Int(raw[22]) << 16) | (Int(raw[23]) << 24)
            entries.append(LeafpackEntry(name: trimmed + "." + ext, offset: pos, size: ln, nextOffset: nxt))
        }
        return entries
    }

    /// Open + parse archive. Returns (key, entries, rawData); nil if the container
    /// is truncated or its table is corrupt.
    public static func open(archiveBytes: [UInt8]) -> ([UInt8], [LeafpackEntry], [UInt8])? {
        guard archiveBytes.count >= 10,
              String(bytes: archiveBytes[0..<8], encoding: .ascii) == magic else { return nil }
        guard let key = guessKey(archiveBytes) else { return nil }
        let files = parseTable(archiveBytes, key)
        guard !files.isEmpty else { return nil }
        return (key, files, archiveBytes)
    }

    public static func open(path: String) -> ([UInt8], [LeafpackEntry], [UInt8])? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }
        return open(archiveBytes: [UInt8](data))
    }

    /// Decrypt (and optionally LZ-decompress) a single entry's raw bytes.
    /// Empty for an entry whose table record points outside the archive.
    public static func fileBytes(_ archive: [UInt8], _ key: [UInt8], _ entry: LeafpackEntry,
                                 decompress: Bool = false) -> [UInt8] {
        guard entry.offset >= 0, entry.size >= 0,
              entry.offset + entry.size <= archive.count else { return [] }
        let raw = dekey(archive[entry.offset..<entry.offset + entry.size], key)
        guard decompress, entry.name.hasSuffix(".LFG") else { return raw }
        // Compressed size is stored at offset 44 as LE u32; used as output size upper bound.
        if raw.count > 48 {
            let compSize = Int(raw[44]) | (Int(raw[45]) << 8) | (Int(raw[46]) << 16) | (Int(raw[47]) << 24)
            // A corrupt u32 here could ask LZS for gigabytes; real LFG bodies are ≤128 KB.
            if compSize >= 0 && compSize <= 4_000_000 {
                let dec = LZS.lzs(raw[...].dropFirst(48).map { $0 }, outSize: compSize)
                if !dec.isEmpty { return dec }
            }
        }
        return raw
    }
}
