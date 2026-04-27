//
//  NodeSeekService.swift
//  nodeseek
//
//  Created by Codex on 2026/4/27.
//

import Foundation
import OSLog

struct NodeSeekService: Sendable {
    let baseURL: URL
    private let htmlClient: any HTMLClient
    private let parser: any NodeSeekParser
    private let challengeDetector: ChallengeDetector
    private let logger = Logger(subsystem: "com.nodeseek.app", category: "NodeSeekService")

    init(
        baseURL: URL = URL(string: "https://www.nodeseek.com")!,
        htmlClient: any HTMLClient = HiddenWebViewHTMLClient(),
        parser: (any NodeSeekParser)? = nil,
        challengeDetector: ChallengeDetector = ChallengeDetector()
    ) {
        self.baseURL = baseURL
        self.htmlClient = htmlClient
        self.parser = parser ?? KannaNodeSeekParser(baseURL: baseURL)
        self.challengeDetector = challengeDetector
    }

    func loadPostList(page: Int = 1) async throws -> NodeSeekResult<[PostSummary]> {
        let targetURL = postListURL(page: page)
        logger.info("开始抓取 NodeSeek 列表，page=\(page): \(targetURL.absoluteString)")
        let response = try await htmlClient.get(targetURL)
        logger.info("抓取返回 page=\(page), status=\(response.statusCode), htmlLength=\(response.html.count), finalURL=\(response.finalURL.absoluteString)")

        if let challenge = challengeDetector.detect(response: response) {
            logger.warning("检测到 challenge: \(Self.describeChallenge(challenge))")
            return .challenge(challenge)
        }

        let posts = try parser.parsePostList(html: response.html)
        logger.info("列表解析完成，帖子数量: \(posts.count)")
        return .value(posts)
    }

    private func postListURL(page: Int) -> URL {
        let normalized = max(1, page)
        return baseURL.appendingPathComponent("page-\(normalized)")
    }

    private static func describeChallenge(_ challenge: ChallengeKind) -> String {
        switch challenge {
        case .loginRequired(let url):
            return "loginRequired(\(url.absoluteString))"
        case .cloudflare(let url):
            return "cloudflare(\(url.absoluteString))"
        case .blocked(let url):
            return "blocked(\(url.absoluteString))"
        case .unsupported(let url):
            return "unsupported(\(url.absoluteString))"
        }
    }
}
