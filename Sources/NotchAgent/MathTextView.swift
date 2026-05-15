import SwiftUI
import WebKit

struct MathTextView: NSViewRepresentable {
    let text: String
    let fontSize: CGFloat
    let textColor: String

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        webView.isHidden = true
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.lastText != text else { return }
        context.coordinator.lastText = text
        webView.loadHTMLString(buildHTML(), baseURL: nil)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, WKNavigationDelegate {
        var lastText: String?

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript("document.body.scrollHeight") { result, _ in
                if let height = result as? CGFloat {
                    webView.frame.size.height = height
                }
            }
            webView.isHidden = false
        }
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.loadHTMLString("", baseURL: nil)
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
            body {
                font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                font-size: \(fontSize)px;
                color: \(textColor);
                background: transparent;
                margin: 0; padding: 0;
                line-height: 1.6;
                -webkit-font-smoothing: antialiased;
            }
            .katex { font-size: 1.05em; }
            .katex-display { margin: 8px 0; overflow-x: auto; }
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
