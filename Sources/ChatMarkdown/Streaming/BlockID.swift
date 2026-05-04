import Foundation

public struct BlockID: Hashable, Sendable {
    public let contentHash: UInt64
    public let occurrenceIndex: Int
    public let fingerprint: UInt64

    public init(contentHash: UInt64, occurrenceIndex: Int) {
        self.contentHash = contentHash
        self.occurrenceIndex = occurrenceIndex
        var h = StableHash()
        var v = contentHash
        for _ in 0..<8 {
            h.combine(UInt8(truncatingIfNeeded: v))
            v >>= 8
        }
        h.combine(occurrenceIndex)
        self.fingerprint = h.value
    }
}
