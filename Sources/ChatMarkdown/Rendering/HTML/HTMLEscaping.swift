import Foundation

enum HTMLEscaping {
    /// Escape characters that have special meaning in HTML text content
    /// and double-quoted attribute values.
    static func text(_ s: String) -> String {
        var out = ""
        out.reserveCapacity(s.count)
        for ch in s {
            switch ch {
            case "&": out.append("&amp;")
            case "<": out.append("&lt;")
            case ">": out.append("&gt;")
            case "\"": out.append("&quot;")
            case "'": out.append("&#39;")
            default: out.append(ch)
            }
        }
        return out
    }

    /// URL escape for use as the value of `href`. We percent-encode anything
    /// outside the URL-safe set, then HTML-escape the result so quotes inside
    /// don't break the attribute.
    static func href(_ url: String) -> String {
        let allowed = CharacterSet.urlFragmentAllowed.union(.urlQueryAllowed)
        let encoded = url.addingPercentEncoding(withAllowedCharacters: allowed) ?? url
        return text(encoded)
    }
}
