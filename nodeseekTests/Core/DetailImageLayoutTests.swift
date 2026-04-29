//
//  DetailImageLayoutTests.swift
//  nodeseekTests
//
//  Created by Codex on 2026/4/28.
//

import CoreGraphics
import Testing
@testable import nodeseek

struct DetailImageLayoutTests {
    @Test func placeholderUsesFixedStickerSquare() {
        let size = DetailImageLayout.placeholderSize(
            maxWidth: 320,
            maxHeight: nil,
            isSticker: true
        )

        #expect(size.width == 65)
        #expect(size.height == 65)
    }

    @Test func placeholderUsesHalfWidthSquareForNormalImage() {
        let size = DetailImageLayout.placeholderSize(
            maxWidth: 320,
            maxHeight: 420,
            isSticker: false
        )

        #expect(size.width == 160)
        #expect(size.height == 160)
    }

    @Test func fixedNormalImageUsesHalfAvailableWidth() {
        let size = DetailImageLayout.fixedNormalImageSize(maxWidth: 375)

        #expect(size.width == 187)
        #expect(size.height == 187)
    }
}
