//
//  PostSummaryCellNodeTests.swift
//  nodeseekTests
//
//  Created by Codex on 2026/4/28.
//

import Testing
import UIKit
@testable import nodeseek

struct PostSummaryCellNodeTests {
    @Test func metadataTextOmitsNodeNameAndWideSeparators() {
        let post = PostSummary(
            id: "1",
            title: "标题",
            url: URL(string: "https://www.nodeseek.com/post-1")!,
            authorName: "mist",
            nodeName: "NodeSeek",
            replyCount: 4,
            viewCount: 34,
            lastActivityText: "22s ago"
        )

        let text = PostSummaryCellNode.metadataAttributedText(for: post).string

        #expect(text.contains("mist"))
        #expect(text.contains("34"))
        #expect(text.contains("4"))
        #expect(text.contains("22s ago"))
        #expect(!text.contains("NodeSeek"))
        #expect(!text.contains(" · "))
    }
}
