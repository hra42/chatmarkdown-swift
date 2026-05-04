import SwiftUI

#if DEBUG
public enum ChatMarkdownDebug {
    nonisolated(unsafe) public static var blockBodyEvaluations: [UInt64: Int] = [:]

    public static func reset() {
        blockBodyEvaluations = [:]
    }
}

struct _DebugCountingWrapper<Content: View>: View {
    let fingerprint: UInt64
    let content: () -> Content

    var body: some View {
        ChatMarkdownDebug.blockBodyEvaluations[fingerprint, default: 0] += 1
        return content()
    }
}
#else
struct _DebugCountingWrapper<Content: View>: View {
    let fingerprint: UInt64
    let content: () -> Content

    var body: some View { content() }
}
#endif
