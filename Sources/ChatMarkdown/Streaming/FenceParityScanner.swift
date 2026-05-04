import Foundation

enum FenceParityScanner {
    /// Returns true when the input ends inside an unclosed fenced code region.
    /// CommonMark fences: a line whose first non-whitespace run (≤3 leading spaces)
    /// is `` ``` `` or `~~~` of length ≥3 opens a fence; the matching close uses the
    /// same character and a length ≥ the opener's.
    static func endsInsideOpenFence(_ markdown: String) -> Bool {
        let normalized = markdown
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        var inFence = false
        var fenceChar: Character = "`"
        var fenceLen = 0
        for line in normalized.split(separator: "\n", omittingEmptySubsequences: false) {
            guard let info = fenceInfo(line) else { continue }
            if !inFence {
                inFence = true
                fenceChar = info.char
                fenceLen = info.length
            } else if info.char == fenceChar && info.length >= fenceLen {
                inFence = false
            }
        }
        return inFence
    }

    private static func fenceInfo<S: StringProtocol>(_ line: S) -> (char: Character, length: Int)? {
        var leadingSpaces = 0
        var idx = line.startIndex
        while idx < line.endIndex && line[idx] == " " && leadingSpaces < 4 {
            leadingSpaces += 1
            idx = line.index(after: idx)
        }
        if leadingSpaces >= 4 || idx == line.endIndex {
            return nil
        }
        let ch = line[idx]
        guard ch == "`" || ch == "~" else { return nil }
        var run = 0
        while idx < line.endIndex && line[idx] == ch {
            run += 1
            idx = line.index(after: idx)
        }
        guard run >= 3 else { return nil }
        // For backtick fences, the info string must not contain another backtick.
        if ch == "`" {
            var rest = idx
            while rest < line.endIndex {
                if line[rest] == "`" { return nil }
                rest = line.index(after: rest)
            }
        }
        return (ch, run)
    }
}
