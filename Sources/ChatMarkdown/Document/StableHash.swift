import Foundation

// FNV-1a 64-bit. Process-stable so block fingerprints survive restarts —
// Swift's Hasher randomizes its seed per process, which would defeat
// streaming reuse across launches.
struct StableHash {
    private static let offsetBasis: UInt64 = 0xcbf29ce484222325
    private static let prime: UInt64 = 0x100000001b3

    private(set) var value: UInt64 = StableHash.offsetBasis

    mutating func combine(_ byte: UInt8) {
        value ^= UInt64(byte)
        value &*= StableHash.prime
    }

    mutating func combine(_ int: Int) {
        var v = UInt64(bitPattern: Int64(int))
        for _ in 0..<8 {
            combine(UInt8(truncatingIfNeeded: v))
            v >>= 8
        }
    }

    mutating func combine(_ uint: UInt) {
        var v = UInt64(uint)
        for _ in 0..<8 {
            combine(UInt8(truncatingIfNeeded: v))
            v >>= 8
        }
    }

    mutating func combine(_ bool: Bool) {
        combine(UInt8(bool ? 1 : 0))
    }

    mutating func combine(_ string: String) {
        for byte in string.utf8 {
            combine(byte)
        }
        combine(UInt8(0))
    }

    mutating func combine(tag: UInt8) {
        combine(tag)
    }
}
