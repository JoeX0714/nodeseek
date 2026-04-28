//
//  ZMarkupHTMLContentRendererTests.swift
//  nodeseekTests
//
//  Created by Codex on 2026/4/28.
//

import Foundation
import Testing
import UIKit
@testable import nodeseek

struct ZMarkupHTMLContentRendererTests {
    @Test func rendersLinkAsAbsoluteURL() throws {
        let renderer = ZMarkupHTMLContentRenderer()
        let baseURL = try #require(URL(string: "https://www.nodeseek.com"))
        let blocks = renderer.render(
            fragment: "<p><a href=\"/post-123\">Open</a></p>",
            baseURL: baseURL,
            maxImageWidth: 320
        )
        let attributed = try #require(
            blocks.compactMap { block -> NSAttributedString? in
                guard case .text(let text) = block else { return nil }
                return text
            }.first
        )

        let range = (attributed.string as NSString).range(of: "Open")
        #expect(range.location != NSNotFound)
        let link = attributed.attribute(.link, at: range.location, effectiveRange: nil) as? URL
        #expect(link?.absoluteString == "https://www.nodeseek.com/post-123")
    }

    @Test func fallsBackToPlainTextWhenParserCannotProduceAttributedText() throws {
        let renderer = ZMarkupHTMLContentRenderer()
        let baseURL = try #require(URL(string: "https://www.nodeseek.com"))
        let blocks = renderer.render(
            fragment: "<unknown><nested>fallback</nested></unknown>",
            baseURL: baseURL,
            maxImageWidth: 320
        )
        let text = blocks.compactMap { block -> String? in
            guard case .text(let attributed) = block else { return nil }
            return attributed.string
        }.joined(separator: "\n")

        #expect(text.contains("fallback"))
    }

    @MainActor
    @Test func resolvesRelativeImagePathToNodeSeekHost() throws {
        let baseURL = try #require(URL(string: "https://www.nodeseek.com"))
        let resolved = AvatarImageLoader.resolveImageURL(
            "/static/image/sticker/xhj/003.png",
            baseURL: baseURL
        )
        #expect(resolved?.absoluteString == "https://www.nodeseek.com/static/image/sticker/xhj/003.png")
    }

    @MainActor
    @Test func keepsAbsoluteImageURLUnchanged() throws {
        let baseURL = try #require(URL(string: "https://www.nodeseek.com"))
        let resolved = AvatarImageLoader.resolveImageURL(
            "https://cdn.example.com/asset.png",
            baseURL: baseURL
        )
        #expect(resolved?.absoluteString == "https://cdn.example.com/asset.png")
    }
}
