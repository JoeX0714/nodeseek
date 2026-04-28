//
//  DTCoreTextHTMLContentRendererTests.swift
//  nodeseekTests
//
//  Created by Codex on 2026/4/28.
//

import Foundation
import DTCoreText
import Testing
import UIKit
@testable import nodeseek

struct DTCoreTextHTMLContentRendererTests {
    @Test func rendersLinkAsAbsoluteURL() throws {
        let renderer = DTCoreTextHTMLContentRenderer()
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

    @Test func rendersRelativeImageAsAttachmentWithResolvedURL() throws {
        let renderer = DTCoreTextHTMLContentRenderer()
        let baseURL = try #require(URL(string: "https://www.nodeseek.com"))
        let blocks = renderer.render(
            fragment: "<p>before<img src=\"/static/image/sticker/xhj/003.png\">after</p>",
            baseURL: baseURL,
            maxImageWidth: 240
        )
        let attributed = try #require(
            blocks.compactMap { block -> NSAttributedString? in
                guard case .text(let text) = block else { return nil }
                return text
            }.first
        )

        var attachmentURL: URL?
        attributed.enumerateAttribute(
            .attachment,
            in: NSRange(location: 0, length: attributed.length)
        ) { value, _, stop in
            guard let attachment = value as? DTTextAttachment else { return }
            attachmentURL = attachment.contentURL
            stop.pointee = true
        }

        #expect(attachmentURL?.absoluteString == "https://www.nodeseek.com/static/image/sticker/xhj/003.png")
    }

    @Test func keepsDTCoreTextImageAttachmentForDataURL() throws {
        let renderer = DTCoreTextHTMLContentRenderer()
        let baseURL = try #require(URL(string: "https://www.nodeseek.com"))
        let pngDataURL = """
        data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=
        """
        let blocks = renderer.render(
            fragment: "<p><img src=\"\(pngDataURL)\"></p>",
            baseURL: baseURL,
            maxImageWidth: 240
        )
        let attributed = try #require(
            blocks.compactMap { block -> NSAttributedString? in
                guard case .text(let text) = block else { return nil }
                return text
            }.first
        )

        var attachment: DTTextAttachment?
        attributed.enumerateAttribute(
            .attachment,
            in: NSRange(location: 0, length: attributed.length)
        ) { value, _, stop in
            guard let value = value as? DTTextAttachment else { return }
            attachment = value
            stop.pointee = true
        }

        #expect(attachment?.contentURL.absoluteString == pngDataURL)
        #expect(attachment is DTImageTextAttachment)
    }

    @Test func rendersNodeSeekMagicTabsAfterLongCodeBlock() throws {
        let renderer = DTCoreTextHTMLContentRenderer()
        let baseURL = try #require(URL(string: "https://www.nodeseek.com"))
        let separator = String(repeating: "+", count: 80)
        let blocks = renderer.render(
            fragment: """
            <div class="nsk-magic-tabs">
            <div class="nsk-magic-tab-title">💻基本信息</div>
            <div class="nsk-magic-tab-body"><pre><code>\(separator)
            一、操作系统信息
            \(separator)</code></pre></div>
            <div class="nsk-magic-tab-title">🎬IP质量</div>
            <div class="nsk-magic-tab-body"><pre><code>IP质量内容</code></pre></div>
            <div class="nsk-magic-tab-title">🌐网络质量</div>
            <div class="nsk-magic-tab-body"><p><img src="https://i.111666.best/image/network.webp" alt="image"></p></div>
            </div>
            """,
            baseURL: baseURL,
            maxImageWidth: 240
        )
        let attributed = try #require(
            blocks.compactMap { block -> NSAttributedString? in
                guard case .text(let text) = block else { return nil }
                return text
            }.first
        )

        #expect(attributed.string.contains("💻基本信息"))
        #expect(attributed.string.contains("一、操作系统信息"))
        #expect(attributed.string.contains("🎬IP质量"))
        #expect(attributed.string.contains("IP质量内容"))
        #expect(attributed.string.contains("🌐网络质量"))

        var attachmentURL: URL?
        attributed.enumerateAttribute(
            .attachment,
            in: NSRange(location: 0, length: attributed.length)
        ) { value, _, stop in
            guard let attachment = value as? DTTextAttachment else { return }
            attachmentURL = attachment.contentURL
            stop.pointee = true
        }
        #expect(attachmentURL?.absoluteString == "https://i.111666.best/image/network.webp")
    }

    @MainActor
    @Test func wrapsLongPreformattedLinesToAvailableWidth() throws {
        let renderer = DTCoreTextHTMLContentRenderer()
        let baseURL = try #require(URL(string: "https://www.nodeseek.com"))
        let blocks = renderer.render(
            fragment: "<pre><code>\(String(repeating: "+", count: 120))</code></pre>",
            baseURL: baseURL,
            maxImageWidth: 160
        )
        let attributed = try #require(
            blocks.compactMap { block -> NSAttributedString? in
                guard case .text(let text) = block else { return nil }
                return text
            }.first
        )

        let label = UILabel()
        label.numberOfLines = 0
        label.attributedText = attributed
        let fittingSize = label.systemLayoutSizeFitting(
            CGSize(width: 160, height: CGFloat.greatestFiniteMagnitude),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )

        #expect(fittingSize.height > UIFont.preferredFont(forTextStyle: .body).lineHeight * 2)
    }

    @Test func rendersHTMLListsWithVisibleMarkers() throws {
        let renderer = DTCoreTextHTMLContentRenderer()
        let baseURL = try #require(URL(string: "https://www.nodeseek.com"))
        let blocks = renderer.render(
            fragment: """
            <ul><li>first</li><li>second</li></ul>
            <ol><li>alpha</li><li>beta</li></ol>
            """,
            baseURL: baseURL,
            maxImageWidth: 320
        )
        let attributed = try #require(
            blocks.compactMap { block -> NSAttributedString? in
                guard case .text(let text) = block else { return nil }
                return text
            }.first
        )

        #expect(attributed.string.contains("• first"))
        #expect(attributed.string.contains("• second"))
        #expect(attributed.string.contains("1. alpha"))
        #expect(attributed.string.contains("2. beta"))
    }
}
