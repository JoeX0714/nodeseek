//
//  DetailImageLayout.swift
//  nodeseek
//
//  Created by Codex on 2026/4/28.
//

import CoreGraphics

enum DetailImageLayout {
    static let fixedStickerWidth: CGFloat = 65
    static let maxImageHeight: CGFloat = 420

    static func fixedNormalImageSize(maxWidth: CGFloat) -> CGSize {
        guard maxWidth > 0 else { return .zero }
        let side = max(1, floor(maxWidth / 2))
        return CGSize(width: side, height: side)
    }

    static func scaledSize(
        for size: CGSize,
        maxWidth: CGFloat,
        maxHeight: CGFloat?
    ) -> CGSize {
        guard size.width > 0, size.height > 0, maxWidth > 0 else { return size }

        var scale = min(1, maxWidth / size.width)
        if let maxHeight, maxHeight > 0 {
            scale = min(scale, maxHeight / size.height)
        }

        return CGSize(
            width: max(1, size.width * scale),
            height: max(1, size.height * scale)
        )
    }

    static func placeholderSize(
        maxWidth: CGFloat,
        maxHeight: CGFloat?,
        isSticker: Bool
    ) -> CGSize {
        guard maxWidth > 0 else { return .zero }

        if isSticker {
            let side = min(maxWidth, fixedStickerWidth)
            return CGSize(width: max(1, side), height: max(1, side))
        }

        return fixedNormalImageSize(maxWidth: maxWidth)
    }
}
