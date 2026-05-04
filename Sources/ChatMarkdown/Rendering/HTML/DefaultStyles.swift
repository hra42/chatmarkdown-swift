import Foundation

enum HTMLDefaultStyles {
    static let css: String = """
    <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif; line-height: 1.5; }
    h1, h2, h3, h4, h5, h6 { margin: 1em 0 0.5em; line-height: 1.25; }
    p { margin: 0.5em 0; }
    pre { background: #f5f5f5; padding: 12px; border-radius: 6px; overflow-x: auto; }
    pre code { font-family: Menlo, Consolas, monospace; font-size: 0.9em; }
    code { font-family: Menlo, Consolas, monospace; background: #f0f0f0; padding: 1px 4px; border-radius: 3px; font-size: 0.9em; }
    blockquote { border-left: 3px solid #ccc; padding: 0 12px; margin: 0.5em 0; color: #555; }
    table { border-collapse: collapse; margin: 0.5em 0; }
    th, td { border: 1px solid #ccc; padding: 4px 8px; text-align: left; }
    th { background: #f5f5f5; }
    hr { border: none; border-top: 1px solid #ccc; margin: 1em 0; }
    a { color: #0a84ff; }
    </style>
    """
}
