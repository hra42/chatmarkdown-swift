import Foundation

final class RegexCache: @unchecked Sendable {
    static let shared = RegexCache()

    private var cache: [String: NSRegularExpression] = [:]
    private let lock = NSLock()

    func regex(_ pattern: String, options: NSRegularExpression.Options = []) -> NSRegularExpression? {
        let key = "\(options.rawValue)|\(pattern)"
        lock.lock()
        defer { lock.unlock() }
        if let cached = cache[key] {
            return cached
        }
        guard let compiled = try? NSRegularExpression(pattern: pattern, options: options) else {
            return nil
        }
        cache[key] = compiled
        return compiled
    }
}
