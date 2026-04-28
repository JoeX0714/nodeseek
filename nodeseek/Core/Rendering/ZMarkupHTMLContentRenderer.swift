//
//  ZMarkupHTMLContentRenderer.swift
//  nodeseek
//
//  Created by Codex on 2026/4/28.
//

import Foundation
import OSLog
import UIKit
import ZMarkupParser
import ZNSTextAttachment

struct ZMarkupHTMLContentRenderer {
    private enum Layout {
        static let defaultMaxImageWidth: CGFloat = 320
        static let maxLoggedAttachmentCount = 8
        static let fixedAttachmentWidth: CGFloat = 65
    }

    private static let imageSourceRegex = try! NSRegularExpression(
        pattern: "(<img\\b[^>]*\\bsrc\\s*=\\s*[\"'])([^\"']+)([\"'])",
        options: [.caseInsensitive]
    )
    private static let logger = Logger(subsystem: "com.nodeseek.app", category: "DetailHTMLRenderer")

    private static let parser = ZHTMLParserBuilder
        .initWithDefault()
        .build()

    func render(fragment: String, baseURL: URL) -> [RenderedContentBlock] {
        render(fragment: fragment, baseURL: baseURL, maxImageWidth: Layout.defaultMaxImageWidth)
    }

    func render(fragment: String, baseURL: URL, maxImageWidth: CGFloat) -> [RenderedContentBlock] {
        guard fragment.isEmpty == false else { return [] }

        let originalSources = imageSources(in: fragment)
        let normalizedFragment = normalizeImageSources(in: fragment, baseURL: baseURL)
        let normalizedSources = imageSources(in: normalizedFragment)
        if originalSources.isEmpty == false {
            Self.logger.debug(
                "HTML图片src统计 original=\(originalSources.count, privacy: .public), normalized=\(normalizedSources.count, privacy: .public)"
            )
            for (index, source) in normalizedSources.prefix(3).enumerated() {
                Self.logger.debug("HTML图片src[\(index, privacy: .public)] \(source, privacy: .public)")
            }
        }

        let rendered = Self.parser.render(normalizedFragment)
        let normalized = normalize(attributed: rendered, baseURL: baseURL, maxImageWidth: maxImageWidth)
        logAttachmentSummary(in: normalized)
        if normalized.length > 0 {
            return [.text(normalized)]
        }

        let fallback = plainText(from: normalizedFragment)
        return fallback.isEmpty ? [] : [.text(NSAttributedString(string: fallback))]
    }

    private func normalize(
        attributed: NSAttributedString,
        baseURL: URL,
        maxImageWidth: CGFloat
    ) -> NSMutableAttributedString {
        let mutable = NSMutableAttributedString(attributedString: attributed)
        if mutable.length == 0 {
            return mutable
        }

        mutable.addAttributes(
            [
                .font: UIFont.preferredFont(forTextStyle: .body),
                .foregroundColor: UIColor.label
            ],
            range: NSRange(location: 0, length: mutable.length)
        )
        normalizeLinks(in: mutable, baseURL: baseURL)
        stabilizeZNSTextAttachments(in: mutable, maxImageWidth: maxImageWidth)
        scaleImageAttachments(in: mutable, maxImageWidth: maxImageWidth)
        return mutable
    }

    private func normalizeLinks(in attributed: NSMutableAttributedString, baseURL: URL) {
        attributed.enumerateAttribute(
            .link,
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
        }
    }

    private func scaleImageAttachments(in attributed: NSMutableAttributedString, maxImageWidth: CGFloat) {
        guard maxImageWidth > 0 else { return }

        attributed.enumerateAttribute(
            .attachment,
            in: NSRange(location: 0, length: attributed.length)
        ) { value, _, _ in
            guard let attachment = value as? NSTextAttachment else { return }
            let original = attachment.image?.size ?? attachment.bounds.size
            guard original.width > maxImageWidth, original.width > 0 else { return }

            let scale = maxImageWidth / original.width
            attachment.bounds = CGRect(
                x: 0,
                y: 0,
                width: maxImageWidth,
                height: original.height * scale
            )
        }
    }

    private func plainText(from html: String) -> String {
        html
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
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

    private func stabilizeZNSTextAttachments(in attributed: NSMutableAttributedString, maxImageWidth: CGFloat) {
        guard maxImageWidth > 0 else { return }

        var replacementRanges: [(range: NSRange, attachment: ZNSTextAttachment)] = []
        attributed.enumerateAttribute(
            .attachment,
            in: NSRange(location: 0, length: attributed.length)
        ) { value, range, _ in
            guard let attachment = value as? ZNSTextAttachment else { return }
            replacementRanges.append((range, attachment))
        }

        guard replacementRanges.isEmpty == false else { return }
        var stickerFixedCount = 0
        for item in replacementRanges.reversed() {
            let previous = item.attachment
            let useStickerWidth = isStickerImageURL(previous.imageURL)
            let imageWidth = useStickerWidth ? min(maxImageWidth, Layout.fixedAttachmentWidth) : maxImageWidth
            if useStickerWidth {
                stickerFixedCount += 1
            }
            let replacement = ZNSTextAttachment(
                imageURL: previous.imageURL,
                imageWidth: imageWidth,
                imageHeight: nil,
                placeholderImage: previous.image
            )
            replacement.delegate = previous.delegate
            replacement.dataSource = previous.dataSource
            attributed.replaceCharacters(in: item.range, with: NSAttributedString(attachment: replacement))
        }

        Self.logger.debug(
            "已重建ZNSTextAttachment，count=\(replacementRanges.count, privacy: .public), stickerFixed=\(stickerFixedCount, privacy: .public), defaultWidth=\(maxImageWidth, privacy: .public), stickerWidth=\(Layout.fixedAttachmentWidth, privacy: .public)"
        )
    }

    private func isStickerImageURL(_ url: URL?) -> Bool {
        guard let absolute = url?.absoluteString.lowercased() else { return false }
        return absolute.contains("sticker")
    }

    private func logAttachmentSummary(in attributed: NSAttributedString) {
        guard attributed.length > 0 else { return }

        var attachmentCount = 0
        var znstextAttachmentCount = 0

        attributed.enumerateAttribute(
            .attachment,
            in: NSRange(location: 0, length: attributed.length)
        ) { value, range, _ in
            guard let attachment = value as? NSTextAttachment else { return }
            attachmentCount += 1
            let className = String(describing: type(of: attachment))
            if className.contains("ZNSTextAttachment") {
                znstextAttachmentCount += 1
            }

            guard attachmentCount <= Layout.maxLoggedAttachmentCount else { return }
            let bounds = NSCoder.string(for: attachment.bounds)
            let hasImage = attachment.image != nil
            Self.logger.debug(
                "attachment[\(attachmentCount, privacy: .public)] class=\(className, privacy: .public), hasImage=\(hasImage, privacy: .public), bounds=\(bounds, privacy: .public), range=\(range.location, privacy: .public)-\(range.length, privacy: .public)"
            )
        }

        if attachmentCount == 0 {
            Self.logger.debug("attributedText无attachment")
            return
        }

        Self.logger.debug(
            "attributedText attachment总数=\(attachmentCount, privacy: .public), znsAttachment=\(znstextAttachmentCount, privacy: .public)"
        )
        if znstextAttachmentCount > 0 {
            Self.logger.warning(
                "检测到ZNSTextAttachment，占位图可能显示为灰块；若未触发register/startDownlaod则不会替换为真实图片"
            )
        }
    }
}
