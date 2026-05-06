//
//  DetailImageURLRules.swift
//  nodeseek
//
//  Created by Codex on 2026/5/6.
//

import Foundation

enum DetailImageURLRules {
    static func isCheckPlaceReportSVG(_ url: URL) -> Bool {
        guard ["http", "https"].contains(url.scheme?.lowercased()),
              url.pathExtension.lowercased() == "svg",
              url.host?.lowercased() == "report.check.place" else {
            return false
        }

        let components = url.pathComponents.filter { $0 != "/" }
        guard components.count == 2,
              ["ip", "hardware"].contains(components[0]),
              components[1].isEmpty == false else {
            return false
        }

        return true
    }

    static func containsCheckPlaceReportSVGURL(in text: String) -> Bool {
        let range = NSRange(location: 0, length: (text as NSString).length)
        return checkPlaceReportSVGURLRegex.firstMatch(in: text, options: [], range: range) != nil
    }

    static func checkPlaceReportSVGURLs(in text: String) -> [URL] {
        let source = text as NSString
        let fullRange = NSRange(location: 0, length: source.length)
        var seen = Set<String>()
        var urls: [URL] = []

        for match in checkPlaceReportSVGURLRegex.matches(in: text, options: [], range: fullRange) {
            let rawURL = source.substring(with: match.range)
            guard let url = URL(string: rawURL), isCheckPlaceReportSVG(url) else { continue }
            let key = url.absoluteString.lowercased()
            guard seen.insert(key).inserted else { continue }
            urls.append(url)
        }

        return urls
    }

    private static let checkPlaceReportSVGURLRegex = try! NSRegularExpression(
        pattern: #"https?://report\.check\.place/(?:ip|hardware)/[A-Za-z0-9_-]+\.svg\b"#,
        options: [.caseInsensitive]
    )
}

extension DetailImageKind {
    static func resolved(isSticker: Bool, imageURL: URL?) -> DetailImageKind {
        if isSticker {
            return .sticker
        }
        if let imageURL, DetailImageURLRules.isCheckPlaceReportSVG(imageURL) {
            return .report
        }
        return .normal
    }
}
