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
        guard context.coordinator.lastText != text else { return }
        context.coordinator.lastText = text
        webView.loadHTMLString(buildHTML(), baseURL: nil)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, WKNavigationDelegate {
        var lastText: String?
        var parent: MathTextView?

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Wait briefly for KaTeX to finish rendering, then measure
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self, weak webView] in
                webView?.evaluateJavaScript("document.body.scrollHeight") { result, _ in
                    guard let self, let height = result as? CGFloat else { return }
                    DispatchQueue.main.async {
                        self.parent?.measuredHeight = height + 8
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

    private func buildHTML() -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.css">
        <script src="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.js"></script>
        <script src="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/contrib/auto-render.min.js"></script>
        <style>
            html, body {
                font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                font-size: \(fontSize)px;
                color: \(textColor);
                background: transparent;
                margin: 0; padding: 0;
                line-height: 1.6;
                -webkit-font-smoothing: antialiased;
                overflow: hidden;
            }
            .katex { font-size: 1.05em; }
            .katex-display { margin: 8px 0; overflow-x: auto; overflow-y: hidden; }
        </style>
        </head>
        <body>
        <div id="content">\(text)</div>
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
