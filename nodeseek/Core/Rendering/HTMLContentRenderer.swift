//
//  HTMLContentRenderer.swift
//  nodeseek
//
//  Created by Codex on 2026/4/27.
//

import Foundation

struct HTMLContentRenderer {

    func render(fragment: String, baseURL: URL) -> [RenderedContentBlock] {
        guard fragment.isEmpty == false else { return [] }
        return [.text(NSAttributedString(string: fragment))]
    }
}
