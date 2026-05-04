import Foundation

enum BlockIDSequence {
    static func make(_ blocks: [ChatMarkdownBlock]) -> [BlockID] {
        var counters: [UInt64: Int] = [:]
        var out: [BlockID] = []
        out.reserveCapacity(blocks.count)
        for block in blocks {
            let hash = block.contentHash
            let occurrence = counters[hash, default: 0]
            counters[hash] = occurrence + 1
            out.append(BlockID(contentHash: hash, occurrenceIndex: occurrence))
        }
        return out
    }
}
