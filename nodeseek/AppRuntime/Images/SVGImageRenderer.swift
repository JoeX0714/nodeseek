//
//  SVGImageRenderer.swift
//  nodeseek
//
//  Created by Codex on 2026/5/6.
//

import SVGKit
import UIKit

enum SVGImageRenderer {
    enum RenderError: LocalizedError {
        case unsupportedData

        var errorDescription: String? {
            switch self {
            case .unsupportedData:
                return "SVG/位图数据均无法解析"
            }
        }
    }

    static func image(from data: Data, size: CGSize) -> UIImage? {
        withSVGImage(from: data) { svgImage in
            svgImage.size = size
            return svgImage.uiImage
        }
    }

    static func imageSize(from data: Data, fallbackSize: CGSize, maxPixelSide: CGFloat) -> CGSize? {
        withSVGImage(from: data) { svgImage in
            let sourceSize = svgImage.hasSize() ? svgImage.size : fallbackSize
            return normalizedSize(sourceSize, fallbackSize: fallbackSize, maxPixelSide: maxPixelSide)
        }
    }

    static func renderAsync(data: Data, targetSize: CGSize) async throws -> UIImage {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let image = image(from: data, size: targetSize) else {
                    continuation.resume(throwing: RenderError.unsupportedData)
                    return
                }
                continuation.resume(returning: image)
            }
        }
    }

    private static func withSVGImage<Result>(
        from data: Data,
        _ body: (SVGKImage) -> Result?
    ) -> Result? {
        renderQueue.sync {
            guard let svgImage = SVGKImage(data: normalizedData(from: data)) else {
                return nil
            }
            return body(svgImage)
        }
    }

    private static func normalizedData(from data: Data) -> Data {
        guard var svgText = String(data: data, encoding: .utf8) else {
            return data
        }

        svgText = replacingTemplateNumericExpressions(in: svgText)
        svgText = replacingQuotedCSSLengths(in: svgText)

        let fontSize = baseFontSize(in: svgText)
        let chWidth = fontSize * 0.6
        let fullRange = NSRange(svgText.startIndex..<svgText.endIndex, in: svgText)
        let matches = fontRelativeLengthRegex.matches(in: svgText, options: [], range: fullRange)

        for match in matches.reversed() {
            guard let valueRange = Range(match.range(at: 1), in: svgText),
                  let unitRange = Range(match.range(at: 2), in: svgText),
                  let value = Double(svgText[valueRange]),
                  let replaceRange = Range(match.range, in: svgText) else {
                continue
            }

            let factor = svgText[unitRange].lowercased() == "ch" ? chWidth : fontSize
            svgText.replaceSubrange(replaceRange, with: "\(numberString(value * factor))px")
        }

        return Data(svgText.utf8)
    }

    private static func replacingTemplateNumericExpressions(in svgText: String) -> String {
        var normalizedText = svgText
        let fullRange = NSRange(normalizedText.startIndex..<normalizedText.endIndex, in: normalizedText)
        let matches = templateNumericExpressionRegex.matches(in: normalizedText, options: [], range: fullRange)

        for match in matches.reversed() {
            guard let lhsRange = Range(match.range(at: 1), in: normalizedText),
                  let operatorRange = Range(match.range(at: 2), in: normalizedText),
                  let rhsRange = Range(match.range(at: 3), in: normalizedText),
                  let replaceRange = Range(match.range, in: normalizedText),
                  let lhs = Double(normalizedText[lhsRange]),
                  let rhs = Double(normalizedText[rhsRange]) else {
                continue
            }

            let value: Double?
            switch normalizedText[operatorRange] {
            case "+":
                value = lhs + rhs
            case "-":
                value = lhs - rhs
            case "*":
                value = lhs * rhs
            case "/":
                value = rhs == 0 ? nil : lhs / rhs
            default:
                value = nil
            }

            guard let value, value.isFinite else { continue }
            normalizedText.replaceSubrange(replaceRange, with: numberString(value))
        }

        return normalizedText
    }

    private static func replacingQuotedCSSLengths(in svgText: String) -> String {
        var normalizedText = svgText
        let fullRange = NSRange(normalizedText.startIndex..<normalizedText.endIndex, in: normalizedText)
        let matches = quotedCSSLengthRegex.matches(in: normalizedText, options: [], range: fullRange)

        for match in matches.reversed() {
            guard let prefixRange = Range(match.range(at: 1), in: normalizedText),
                  let valueRange = Range(match.range(at: 2), in: normalizedText),
                  let replaceRange = Range(match.range, in: normalizedText) else {
                continue
            }
            normalizedText.replaceSubrange(
                replaceRange,
                with: "\(normalizedText[prefixRange])\(normalizedText[valueRange])"
            )
        }

        return normalizedText
    }

    private static func baseFontSize(in svgText: String) -> Double {
        let fullRange = NSRange(svgText.startIndex..<svgText.endIndex, in: svgText)
        guard let match = fontSizeRegex.firstMatch(in: svgText, options: [], range: fullRange),
              let valueRange = Range(match.range(at: 1), in: svgText),
              let fontSize = Double(svgText[valueRange]),
              fontSize.isFinite,
              fontSize > 0 else {
            return 14
        }
        return fontSize
    }

    private static func numberString(_ value: Double) -> String {
        let rounded = (value * 1_000).rounded() / 1_000
        if rounded.rounded() == rounded {
            return String(Int(rounded))
        }
        return String(rounded)
    }

    private static let fontRelativeLengthRegex = try! NSRegularExpression(
        pattern: #"(?<![A-Za-z])(-?\d+(?:\.\d+)?)(ch|em)\b"#,
        options: [.caseInsensitive]
    )

    private static let fontSizeRegex = try! NSRegularExpression(
        pattern: #"font-size\s*:\s*(\d+(?:\.\d+)?)px\b"#,
        options: [.caseInsensitive]
    )

    private static let templateNumericExpressionRegex = try! NSRegularExpression(
        pattern: #"\{\s*(-?\d+(?:\.\d+)?)\s*([+\-*/])\s*(-?\d+(?:\.\d+)?)\s*\}"#,
        options: []
    )

    private static let quotedCSSLengthRegex = try! NSRegularExpression(
        pattern: #"(:\s*)"(-?\d+(?:\.\d+)?(?:px|pt|em|ch|%)?)""#,
        options: [.caseInsensitive]
    )

    private static let renderQueue = DispatchQueue(label: "com.nodeseek.app.svgkit.render")

    private static func normalizedSize(
        _ size: CGSize,
        fallbackSize: CGSize,
        maxPixelSide: CGFloat
    ) -> CGSize {
        let sourceWidth = size.width.isFinite && size.width > 0 ? size.width : fallbackSize.width
        let sourceHeight = size.height.isFinite && size.height > 0 ? size.height : fallbackSize.height

        guard max(sourceWidth, sourceHeight) > maxPixelSide else {
            return CGSize(width: sourceWidth, height: sourceHeight)
        }

        let scale = maxPixelSide / max(sourceWidth, sourceHeight)
        return CGSize(width: sourceWidth * scale, height: sourceHeight * scale)
    }
}
