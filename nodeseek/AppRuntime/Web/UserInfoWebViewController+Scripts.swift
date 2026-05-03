//
//  UserInfoWebViewController+Scripts.swift
//  nodeseek
//
//  Created by Codex on 2026/4/30.
//

import Foundation
import WebKit

extension UserInfoWebViewController {
    static func makeUserScripts() -> [WKUserScript] {
        let css = injectedUserInfoCSS.trimmingCharacters(in: .whitespacesAndNewlines)
        guard css.isEmpty == false else { return [] }

        let source = """
        (() => {
          const style = document.createElement('style');
          style.setAttribute('data-nodeseek-user-info-style', 'true');
          style.textContent = \(javaScriptStringLiteral(css));
          document.documentElement.appendChild(style);
        })();
        """
        return [
            WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        ]
    }

    private static var injectedUserInfoCSS: String {
        """
        body > header {
            display: none !important;
        }
        """
    }

    private static func javaScriptStringLiteral(_ string: String) -> String {
        var escaped = string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
        escaped = escaped
            .replacingOccurrences(of: "\u{2028}", with: "\\u2028")
            .replacingOccurrences(of: "\u{2029}", with: "\\u2029")
        return "\"\(escaped)\""
    }
}
