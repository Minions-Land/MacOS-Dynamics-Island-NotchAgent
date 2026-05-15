import SwiftUI
import WebKit

struct MathTextView: NSViewRepresentable {
    let text: String
    let fontSize: CGFloat
    let textColor: String
    @Binding var measuredHeight: CGFloat

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = context.coordinator
        context.coordinator.parent = self
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
        let key = "\(text)|\(fontSize)"
        guard context.coordinator.lastKey != key else { return }
        context.coordinator.lastKey = key
        webView.loadHTMLString(buildHTML(), baseURL: nil)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, WKNavigationDelegate {
        var lastKey: String?
        var parent: MathTextView?

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self, weak webView] in
                webView?.evaluateJavaScript("document.body.scrollHeight") { result, _ in
                    guard let self, let height = result as? CGFloat else { return }
                    DispatchQueue.main.async {
                        self.parent?.measuredHeight = height + 12
                    }
                }
            }
        }
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.stopLoading()
        webView.navigationDelegate = nil
        coordinator.parent = nil
    }

    private func formattedText() -> String {
        // Convert single newlines AND "。1."/"。2." patterns into paragraph breaks
        // Promote standalone display math to its own line
        var result = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\n\n", with: "<PARA>")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "<PARA>", with: "\n\n")

        // If text is one big blob, split on Chinese sentence terminators followed by digits or capitals
        if !result.contains("\n\n") && result.count > 200 {
            // Insert paragraph break after "。" if followed by a likely new-sentence marker
            let sentences = result.components(separatedBy: "。")
            if sentences.count > 3 {
                // Group every ~2 sentences as a paragraph
                var paragraphs: [String] = []
                var current = ""
                for (i, s) in sentences.enumerated() {
                    let trimmed = s.trimmingCharacters(in: .whitespaces)
                    if trimmed.isEmpty { continue }
                    current += trimmed + (i < sentences.count - 1 ? "。" : "")
                    if current.count > 80 || i == sentences.count - 1 {
                        paragraphs.append(current)
                        current = ""
                    }
                }
                if !current.isEmpty { paragraphs.append(current) }
                result = paragraphs.joined(separator: "\n\n")
            }
        }

        // Wrap in <p> tags
        let paragraphs = result.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { "<p>\($0)</p>" }
            .joined(separator: "\n")

        return paragraphs.isEmpty ? "<p>\(text)</p>" : paragraphs
    }

    private func buildHTML() -> String {
        let body = formattedText()
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.css">
        <script src="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.js"></script>
        <script src="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/contrib/auto-render.min.js"></script>
        <style>
            html, body {
                font-family: -apple-system, BlinkMacSystemFont, "PingFang SC", sans-serif;
                font-size: \(fontSize)px;
                color: \(textColor);
                background: transparent;
                margin: 0; padding: 0;
                line-height: 1.7;
                -webkit-font-smoothing: antialiased;
                overflow: hidden;
                word-break: break-word;
            }
            p {
                margin: 0 0 0.8em 0;
                text-align: justify;
            }
            p:last-child { margin-bottom: 0; }
            .katex { font-size: 1.05em; }
            .katex-display {
                margin: 0.8em 0 !important;
                padding: 0.4em 0;
                overflow-x: auto;
                overflow-y: hidden;
                text-align: center;
            }
            .katex-display > .katex {
                font-size: 1.1em;
                white-space: nowrap;
            }
        </style>
        </head>
        <body>
        <div id="content">\(body)</div>
        <script>
            renderMathInElement(document.getElementById('content'), {
                delimiters: [
                    {left: '$$', right: '$$', display: true},
                    {left: '$', right: '$', display: false},
                    {left: '\\\\(', right: '\\\\)', display: false},
                    {left: '\\\\[', right: '\\\\]', display: true}
                ],
                throwOnError: false
            });
        </script>
        </body>
        </html>
        """
    }
}
