//
//  RenderedContentBlock.swift
//  nodeseek
//
//  Created by Codex on 2026/4/27.
//

import Foundation

enum RenderedContentBlock {
    case text(NSAttributedString)
    case imagePlaceholder(URL?)
    case unsupported(reason: String)
}
