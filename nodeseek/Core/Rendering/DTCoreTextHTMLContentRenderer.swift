//
//  DTCoreTextHTMLContentRenderer.swift
//  nodeseek
//
//  Created by Codex on 2026/4/28.
//

import DTCoreText
import Foundation
import OSLog
import UIKit

struct DTCoreTextHTMLContentRenderer {
    private enum Layout {
        static let defaultMaxImageWidth: CGFloat = 320
        static let fixedAttachmentWidth: CGFloat = 65
    }

    private static let imageSourceRegex = try! NSRegularExpression(
        pattern: "(<img\\b[^>]*\\bsrc\\s*=\\s*[\"'])([^\"']+)([\"'])",
        options: [.caseInsensitive]
    )
    private static let listMarkerRegex = try! NSRegularExpression(
        pattern: "\\t((?:\\d+[.)])|[•◦▪])\\t",
        options: []
    )
    private static let logger = Logger(subsystem: "com.nodeseek.app", category: "DetailDTCoreTextRenderer")

    func render(fragment: String, baseURL: URL) -> [RenderedContentBlock] {
        render(fragment: fragment, baseURL: baseURL, maxImageWidth: Layout.defaultMaxImageWidth)
    }

    func render(fragment: String, baseURL: URL, maxImageWidth: CGFloat) -> [RenderedContentBlock] {
        guard fragment.isEmpty == false else { return [] }

        let normalizedFragment = normalizeImageSources(in: fragment, baseURL: baseURL)
        let normalizedSources = imageSources(in: normalizedFragment)
        let html = wrapHTML(fragment: normalizedFragment, baseURL: baseURL)
        guard let data = html.data(using: .utf8) else {
            return fallbackBlocks(from: fragment)
        }

        let options: [String: Any] = [
            NSBaseURLDocumentOption: baseURL,
            DTDefaultFontSize: UIFont.preferredFont(forTextStyle: .body).pointSize,
            DTDefaultTextColor: UIColor.label,
            DTDefaultLinkColor: UIColor.systemBlue,
            DTMaxImageSize: NSValue(cgSize: CGSize(width: maxImageWidth, height: CGFloat.greatestFiniteMagnitude)),
            DTUseiOS6Attributes: true
        ]
        let builder = DTHTMLAttributedStringBuilder(
            html: data,
            options: options,
            documentAttributes: nil
        )
        guard let rendered = builder?.generatedAttributedString(), rendered.length > 0 else {
            return fallbackBlocks(from: normalizedFragment)
        }

        let normalized = normalize(
            attributed: rendered,
            baseURL: baseURL,
            imageSources: normalizedSources,
            maxImageWidth: maxImageWidth
        )
        return normalized.length > 0 ? [.text(normalized)] : fallbackBlocks(from: normalizedFragment)
    }

    private func wrapHTML(fragment: String, baseURL: URL) -> String {
        """
        <html>
        <head>
        <base href="\(baseURL.absoluteString)">
        <style>
        body { font: -apple-system-body; color: #111; }
        img { max-width: 100%; height: auto; }
        blockquote { border-left: 3px solid #d0d0d0; margin-left: 0; padding-left: 10px; color: #555; }
        </style>
        </head>
        <body>\(fragment)</body>
        </html>
        """
    }

    private func normalize(
        attributed: NSAttributedString,
        baseURL: URL,
        imageSources: [String],
        maxImageWidth: CGFloat
    ) -> NSMutableAttributedString {
        let mutable = NSMutableAttributedString(attributedString: attributed)
        guard mutable.length > 0 else { return mutable }

        mutable.addAttributes(
            [
                .font: UIFont.preferredFont(forTextStyle: .body),
                .foregroundColor: UIColor.label
            ],
            range: NSRange(location: 0, length: mutable.length)
        )
        normalizeLinks(in: mutable, baseURL: baseURL)
        normalizeVisibleListMarkers(in: mutable)
        normalizeImageAttachments(in: mutable, imageSources: imageSources, maxImageWidth: maxImageWidth)
        return mutable
    }

    private func normalizeLinks(in attributed: NSMutableAttributedString, baseURL: URL) {
        let dtLinkKey = NSAttributedString.Key(DTLinkAttribute)
        attributed.enumerateAttribute(
            dtLinkKey,
            in: NSRange(location: 0, length: attributed.length)
        ) { value, range, _ in
            guard let value else { return }
            let raw: String?
            if let url = value as? URL {
                raw = url.absoluteString
            } else if let string = value as? String {
                raw = string
            } else {
                raw = nil
            }
            guard let raw, let resolved = URL(string: raw, relativeTo: baseURL)?.absoluteURL else { return }
            attributed.addAttribute(.link, value: resolved, range: range)
            attributed.addAttribute(.foregroundColor, value: UIColor.systemBlue, range: range)
            if dtLinkKey != .link {
                attributed.removeAttribute(dtLinkKey, range: range)
            }
        }
    }

    private func normalizeVisibleListMarkers(in attributed: NSMutableAttributedString) {
        let source = attributed.string as NSString
        let fullRange = NSRange(location: 0, length: source.length)
        let matches = Self.listMarkerRegex.matches(in: attributed.string, options: [], range: fullRange)
        guard matches.isEmpty == false else { return }

        for match in matches.reversed() {
            guard match.numberOfRanges >= 2 else { continue }
            let markerRange = match.range(at: 1)
            guard markerRange.location != NSNotFound else { continue }
            let marker = source.substring(with: markerRange)
            let attributes = attributed.attributes(at: match.range.location, effectiveRange: nil)
            attributed.replaceCharacters(
                in: match.range,
                with: NSAttributedString(string: "\(marker) ", attributes: attributes)
            )
        }
    }

    private func normalizeImageAttachments(
        in attributed: NSMutableAttributedString,
        imageSources: [String],
        maxImageWidth: CGFloat
    ) {
        guard maxImageWidth > 0 else { return }

        var normalizedCount = 0
        var stickerFixedCount = 0
        var imageIndex = 0
        attributed.enumerateAttribute(
            .attachment,
            in: NSRange(location: 0, length: attributed.length)
        ) { value, range, _ in
            guard let attachment = value as? DTTextAttachment else { return }
            let contentURL = attachment.contentURL
            let mappedURL = imageIndex < imageSources.count ? URL(string: imageSources[imageIndex]) : nil
            guard let imageURL = contentURL ?? mappedURL else { return }

            if attachment.contentURL == nil {
                attachment.contentURL = imageURL
            }

            let maxWidth = isStickerImageURL(imageURL)
                ? min(maxImageWidth, Layout.fixedAttachmentWidth)
                : maxImageWidth
            if isStickerImageURL(imageURL) {
                stickerFixedCount += 1
            }

            let originalSize = attachment.originalSize
            if originalSize.width > 0, originalSize.height > 0 {
                attachment.displaySize = Self.scaledSize(for: originalSize, maxWidth: maxWidth)
            } else if attachment.displaySize.width > 0, attachment.displaySize.height > 0 {
                attachment.displaySize = Self.scaledSize(for: attachment.displaySize, maxWidth: maxWidth)
            }

            normalizedCount += 1
            imageIndex += 1
        }

        Self.logger.debug(
            "已保留DTCoreText图片附件，count=\(normalizedCount, privacy: .public), stickerFixed=\(stickerFixedCount, privacy: .public)"
        )
    }

    private static func scaledSize(for size: CGSize, maxWidth: CGFloat) -> CGSize {
        guard size.width > 0, size.height > 0, maxWidth > 0 else { return size }
        guard size.width > maxWidth else { return size }
        let scale = maxWidth / size.width
        return CGSize(width: maxWidth, height: max(1, size.height * scale))
    }

    private func normalizeImageSources(in fragment: String, baseURL: URL) -> String {
        let source = fragment as NSString
        let fullRange = NSRange(location: 0, length: source.length)
        let matches = Self.imageSourceRegex.matches(in: fragment, options: [], range: fullRange)
        guard matches.isEmpty == false else { return fragment }

        let mutable = NSMutableString(string: fragment)
        for match in matches.reversed() {
            guard match.numberOfRanges >= 3 else { continue }
            let srcRange = match.range(at: 2)
            guard srcRange.location != NSNotFound else { continue }
            let rawSource = source.substring(with: srcRange)
            guard let resolved = AvatarImageLoader.resolveImageURL(rawSource, baseURL: baseURL) else { continue }
            mutable.replaceCharacters(in: srcRange, with: resolved.absoluteString)
        }

        return mutable as String
    }

    private func imageSources(in fragment: String) -> [String] {
        let source = fragment as NSString
        let fullRange = NSRange(location: 0, length: source.length)
        let matches = Self.imageSourceRegex.matches(in: fragment, options: [], range: fullRange)
        guard matches.isEmpty == false else { return [] }
        return matches.compactMap { match in
            guard match.numberOfRanges >= 3 else { return nil }
            let srcRange = match.range(at: 2)
            guard srcRange.location != NSNotFound else { return nil }
            return source.substring(with: srcRange)
        }
    }

    private func isStickerImageURL(_ url: URL?) -> Bool {
        guard let absolute = url?.absoluteString.lowercased() else { return false }
        return absolute.contains("sticker")
    }

    private func fallbackBlocks(from html: String) -> [RenderedContentBlock] {
        let fallback = html
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return fallback.isEmpty ? [] : [.text(NSAttributedString(string: fallback))]
    }
}
