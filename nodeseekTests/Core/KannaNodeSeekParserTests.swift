//
//  KannaNodeSeekParserTests.swift
//  nodeseekTests
//
//  Created by Codex on 2026/4/27.
//

import Foundation
import Testing
@testable import nodeseek

private final class FixtureToken {}

enum FixtureLoader {
    static func html(named name: String) throws -> String {
        let bundle = Bundle(for: FixtureToken.self)
        let url = try #require(bundle.url(forResource: name, withExtension: "html"))
        return try String(contentsOf: url, encoding: .utf8)
    }
}

struct KannaNodeSeekParserTests {
    @Test func parsesPostListFixture() throws {
        let html = try FixtureLoader.html(named: "post-list-basic")
        let parser = KannaNodeSeekParser(baseURL: URL(string: "https://www.nodeseek.com")!)

        let posts = try parser.parsePostList(html: html)

        let post = try #require(posts.first)
        #expect(posts.count == 1)
        #expect(post.id == "123")
        #expect(post.title == "测试帖子")
        #expect(post.url.absoluteString == "https://www.nodeseek.com/post-123")
        #expect(post.authorName == "mist")
        #expect(post.nodeName == "VPS")
        #expect(post.replyCount == 2)
        #expect(post.lastActivityText == "1 分钟前")
        #expect(post.avatarURL == nil)
    }

    @Test func parsesPostListFromPostLinksWhenClassNamesChange() throws {
        let html = try FixtureLoader.html(named: "post-list-link-fallback")
        let parser = KannaNodeSeekParser(baseURL: URL(string: "https://www.nodeseek.com")!)

        let posts = try parser.parsePostList(html: html)

        let post = try #require(posts.first)
        #expect(posts.count == 1)
        #expect(post.id == "456")
        #expect(post.title == "没有标准 class 的标题")
        #expect(post.url.absoluteString == "https://www.nodeseek.com/post-456")
        #expect(post.authorName == "alice")
        #expect(post.nodeName == "日常")
        #expect(post.replyCount == 12)
        #expect(post.lastActivityText == "2 小时前")
        #expect(post.avatarURL == nil)
    }

    @Test func parsesRealPageOneFixture() throws {
        let html = try FixtureLoader.html(named: "page-1")
        let parser = KannaNodeSeekParser(baseURL: URL(string: "https://www.nodeseek.com")!)

        let posts = try parser.parsePostList(html: html)

        let first = try #require(posts.first)
        #expect(posts.count > 20)
        #expect(first.id == "703692")
        #expect(first.title.contains("115非VIP账号海外上传速度如何"))
        #expect(first.authorName == "橘子海")
        #expect(first.nodeName == "日常")
        #expect(first.replyCount == 4)
        #expect(first.lastActivityText == "24s ago")
        #expect(first.avatarURL?.path == "/avatar/17843.png")
    }
}
