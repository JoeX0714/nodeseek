//
//  DetailImageLayoutTests.swift
//  nodeseekTests
//
//  Created by Codex on 2026/4/28.
//

import CoreGraphics
import Foundation
import Testing
#if SWIFT_PACKAGE
@testable import NodeSeekCore
#else
@testable import nodeseek
#endif

struct DetailImageLayoutTests {
    @Test func placeholderUsesFixedStickerSquare() {
        let size = DetailImageLayout.placeholderSize(
            maxWidth: 320,
            maxHeight: nil,
            kind: .sticker
        )

        #expect(size.width == 65)
        #expect(size.height == 65)
    }

    @Test func placeholderUsesHalfWidthSquareForNormalImage() {
        let size = DetailImageLayout.placeholderSize(
            maxWidth: 320,
            maxHeight: 420,
            kind: .normal
        )

        #expect(size.width == 160)
        #expect(size.height == 160)
    }

    @Test func reportImagePlaceholderUsesFullWidth() {
        let presentation = DetailImageLayout.presentation(
            for: .zero,
            maxWidth: 320,
            kind: .report
        )

        #expect(presentation.size.width == 320)
        #expect(presentation.size.height > 320)
        #expect(presentation.mode == .aspectFit)
    }

    @Test func fixedNormalImageUsesHalfAvailableWidth() {
        let size = DetailImageLayout.fixedNormalImageSize(maxWidth: 375)

        #expect(size.width == 187)
        #expect(size.height == 187)
    }

    @Test func normalPhotoUsesAspectFitPresentation() {
        let presentation = DetailImageLayout.presentation(
            for: CGSize(width: 1200, height: 800),
            maxWidth: 320,
            kind: .normal
        )

        #expect(presentation.size.width == 320)
        #expect(abs(presentation.size.height - 213.333) < 0.01)
        #expect(presentation.mode == .aspectFit)
        #expect(presentation.targetPointSide == 320)
    }

    @Test func tallScreenshotUsesContainedPresentation() {
        let presentation = DetailImageLayout.presentation(
            for: CGSize(width: 800, height: 2000),
            maxWidth: 320,
            kind: .normal
        )

        #expect(presentation.size == CGSize(width: 168, height: 420))
        #expect(presentation.mode == .aspectFit)
        #expect(presentation.targetPointSide == 420)
    }

    @Test func tallReportImageKeepsFullWidthInsteadOfHeightConstrainedThumbnail() {
        let presentation = DetailImageLayout.presentation(
            for: CGSize(width: 800, height: 2000),
            maxWidth: 320,
            kind: .report
        )

        #expect(presentation.size == CGSize(width: 320, height: 800))
        #expect(presentation.mode == .aspectFit)
        #expect(presentation.targetPointSide == 800)
    }

    @Test func checkPlaceReportURLIsRecognized() throws {
        let reportURL = try #require(URL(string: "https://report.check.place/ip/NPR7IUKQC.svg"))
        let hardwareURL = try #require(URL(string: "https://report.check.place/hardware/abc_123.svg"))
        let otherURL = try #require(URL(string: "https://report.check.place/other/NPR7IUKQC.svg"))
        let unsupportedSchemeURL = try #require(URL(string: "ftp://report.check.place/ip/NPR7IUKQC.svg"))

        #expect(DetailImageURLRules.isCheckPlaceReportSVG(reportURL))
        #expect(DetailImageURLRules.isCheckPlaceReportSVG(hardwareURL))
        #expect(DetailImageURLRules.isCheckPlaceReportSVG(otherURL) == false)
        #expect(DetailImageURLRules.isCheckPlaceReportSVG(unsupportedSchemeURL) == false)
    }

    @Test func veryWideScreenshotUsesContainedPresentation() {
        let presentation = DetailImageLayout.presentation(
            for: CGSize(width: 2000, height: 800),
            maxWidth: 320,
            kind: .normal
        )

        #expect(presentation.size == CGSize(width: 320, height: 128))
        #expect(presentation.mode == .aspectFit)
        #expect(presentation.targetPointSide == 320)
    }

    @Test func fixedNormalImageAllowsInlineAnimation() {
        #expect(DetailImageLayout.allowsInlineAnimation(
            for: CGSize(width: 1200, height: 800),
            maxWidth: 320,
            kind: .normal
        ))
    }

    @Test func containedImageDoesNotAllowInlineAnimation() {
        #expect(DetailImageLayout.allowsInlineAnimation(
            for: CGSize(width: 800, height: 2000),
            maxWidth: 320,
            kind: .normal
        ) == false)
    }

    @Test func stickerAllowsInlineAnimation() {
        #expect(DetailImageLayout.allowsInlineAnimation(
            for: CGSize(width: 65, height: 65),
            maxWidth: 320,
            kind: .sticker
        ))
    }

    @Test func stickerAllowsInlineAnimationBeforeOriginalSizeIsKnown() {
        #expect(DetailImageLayout.allowsInlineAnimation(
            for: .zero,
            maxWidth: 320,
            kind: .sticker
        ))
    }
}
