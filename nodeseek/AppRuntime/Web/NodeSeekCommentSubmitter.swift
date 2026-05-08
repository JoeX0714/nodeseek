//
//  NodeSeekCommentSubmitter.swift
//  nodeseek
//

import Foundation

struct CommentSubmitResponse: Equatable, Sendable {
    let message: String?
}

struct CommentAutomationResponse: Equatable, Sendable {
    let ok: Bool
    let statusCode: Int?
    let message: String?
    let reason: String
    let body: String?

    init(ok: Bool, statusCode: Int? = nil, message: String? = nil, reason: String, body: String? = nil) {
        self.ok = ok
        self.statusCode = statusCode
        self.message = message
        self.reason = reason
        self.body = body
    }
}

protocol CommentSubmissionAutomating: AnyObject {
    func submitComment(postID: Int, content: String, referer: URL) async throws -> CommentAutomationResponse
}

enum NodeSeekCommentSubmitterError: LocalizedError, Equatable {
    case invalidPostID
    case serverMessage(String)
    case httpStatus(Int)
    case challengeRequired(String)
    case pageAutomationFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidPostID:
            return "帖子 ID 无效，无法发表评论。"
        case .serverMessage(let message):
            return message
        case .httpStatus(let statusCode):
            return "评论发送失败，状态码 \(statusCode)。"
        case .challengeRequired(let message):
            return message
        case .pageAutomationFailed(let message):
            return message
        }
    }
}

final class NodeSeekCommentSubmitter {
    private let automation: CommentSubmissionAutomating

    init(
        automation: CommentSubmissionAutomating = WebViewCommentSubmissionAutomator()
    ) {
        self.automation = automation
    }

    func submitComment(postID: String, content: String, referer: URL) async throws -> CommentSubmitResponse {
        guard let numericPostID = Int(postID) else {
            throw NodeSeekCommentSubmitterError.invalidPostID
        }

        let response = try await automation.submitComment(
            postID: numericPostID,
            content: content,
            referer: referer
        )

        if response.reason == "challenge" {
            throw NodeSeekCommentSubmitterError.challengeRequired(
                response.message ?? "站点当前返回了拦截页面，请稍后重试。"
            )
        }

        if let statusCode = response.statusCode, !(200..<300).contains(statusCode) {
            if let message = response.message?.trimmingCharacters(in: .whitespacesAndNewlines), !message.isEmpty {
                throw NodeSeekCommentSubmitterError.serverMessage(message)
            }
            throw NodeSeekCommentSubmitterError.httpStatus(statusCode)
        }

        guard response.ok else {
            if let message = response.message?.trimmingCharacters(in: .whitespacesAndNewlines), !message.isEmpty {
                throw NodeSeekCommentSubmitterError.serverMessage(message)
            }
            throw NodeSeekCommentSubmitterError.pageAutomationFailed(Self.message(forAutomationReason: response.reason))
        }

        return CommentSubmitResponse(message: response.message)
    }

    private static func message(forAutomationReason reason: String) -> String {
        switch reason {
        case "editor_not_found":
            return "网页评论编辑器未找到，请稍后重试。"
        case "fill_failed":
            return "评论内容未能填入网页编辑器，请稍后重试。"
        case "submit_button_not_found":
            return "网页评论提交按钮未找到，请稍后重试。"
        case "submit_timeout":
            return "已点击网页提交按钮，但未等到站点响应。"
        case "javascript_exception":
            return "网页脚本执行失败，请稍后重试。"
        default:
            return "网页模拟提交失败，请稍后重试。"
        }
    }
}

final class WebViewCommentSubmissionAutomator: CommentSubmissionAutomating {
    private let client: HiddenWebViewCommentSubmissionClient

    init(client: HiddenWebViewCommentSubmissionClient = HiddenWebViewCommentSubmissionClient()) {
        self.client = client
    }

    func submitComment(postID: Int, content: String, referer: URL) async throws -> CommentAutomationResponse {
        try await client.submitComment(postID: postID, content: content, referer: referer)
    }
}

struct PostCollectionResponse: Equatable, Sendable {
    let success: Bool?
    let message: String?
    let postCollectionCount: Int?
    let userCollectionCount: Int?

    init(
        success: Bool? = nil,
        message: String? = nil,
        postCollectionCount: Int? = nil,
        userCollectionCount: Int? = nil
    ) {
        self.success = success
        self.message = message
        self.postCollectionCount = postCollectionCount
        self.userCollectionCount = userCollectionCount
    }
}

struct CommentUpvoteResponse: Equatable, Sendable {
    let success: Bool?
    let message: String?
    let current: Int?

    init(
        success: Bool? = nil,
        message: String? = nil,
        current: Int? = nil
    ) {
        self.success = success
        self.message = message
        self.current = current
    }
}

typealias PostUpvoteResponse = CommentUpvoteResponse
typealias CommentChickenLegResponse = CommentUpvoteResponse
typealias PostChickenLegResponse = CommentUpvoteResponse
typealias CommentDislikeResponse = CommentUpvoteResponse
typealias PostDislikeResponse = CommentUpvoteResponse

struct PostCollectionAutomationResponse: Equatable, Sendable {
    let ok: Bool
    let statusCode: Int?
    let response: PostCollectionResponse
    let reason: String
    let body: String?

    init(
        ok: Bool,
        statusCode: Int? = nil,
        response: PostCollectionResponse,
        reason: String,
        body: String? = nil
    ) {
        self.ok = ok
        self.statusCode = statusCode
        self.response = response
        self.reason = reason
        self.body = body
    }
}

struct CommentUpvoteAutomationResponse: Equatable, Sendable {
    let ok: Bool
    let statusCode: Int?
    let response: CommentUpvoteResponse
    let reason: String
    let body: String?

    init(
        ok: Bool,
        statusCode: Int? = nil,
        response: CommentUpvoteResponse,
        reason: String,
        body: String? = nil
    ) {
        self.ok = ok
        self.statusCode = statusCode
        self.response = response
        self.reason = reason
        self.body = body
    }
}

typealias PostUpvoteAutomationResponse = CommentUpvoteAutomationResponse
typealias CommentChickenLegAutomationResponse = CommentUpvoteAutomationResponse
typealias PostChickenLegAutomationResponse = CommentUpvoteAutomationResponse
typealias CommentDislikeAutomationResponse = CommentUpvoteAutomationResponse
typealias PostDislikeAutomationResponse = CommentUpvoteAutomationResponse

@MainActor
protocol PostCollectionAutomating: AnyObject {
    func submitCollection(postID: Int, action: String, referer: URL) async throws -> PostCollectionAutomationResponse
}

@MainActor
protocol CommentUpvoteAutomating: AnyObject {
    func submitUpvote(commentID: Int, action: String, referer: URL) async throws -> CommentUpvoteAutomationResponse
}

@MainActor
protocol PostUpvoteAutomating: AnyObject {
    func submitUpvote(postID: Int, action: String, referer: URL) async throws -> PostUpvoteAutomationResponse
}

@MainActor
protocol CommentChickenLegAutomating: AnyObject {
    func submitChickenLeg(commentID: Int, action: String, referer: URL) async throws -> CommentChickenLegAutomationResponse
}

@MainActor
protocol PostChickenLegAutomating: AnyObject {
    func submitChickenLeg(postID: Int, action: String, referer: URL) async throws -> PostChickenLegAutomationResponse
}

@MainActor
protocol CommentDislikeAutomating: AnyObject {
    func submitDislike(commentID: Int, action: String, referer: URL) async throws -> CommentDislikeAutomationResponse
}

@MainActor
protocol PostDislikeAutomating: AnyObject {
    func submitDislike(postID: Int, action: String, referer: URL) async throws -> PostDislikeAutomationResponse
}

final class WebViewPostCollectionAutomator: PostCollectionAutomating {
    private let client: HiddenWebViewPostCollectionClient

    init(client: HiddenWebViewPostCollectionClient = HiddenWebViewPostCollectionClient()) {
        self.client = client
    }

    func submitCollection(postID: Int, action: String, referer: URL) async throws -> PostCollectionAutomationResponse {
        try await client.submitCollection(postID: postID, action: action, referer: referer)
    }
}

final class WebViewCommentUpvoteAutomator: CommentUpvoteAutomating {
    private let client: HiddenWebViewCommentUpvoteClient

    init(client: HiddenWebViewCommentUpvoteClient = HiddenWebViewCommentUpvoteClient()) {
        self.client = client
    }

    func submitUpvote(commentID: Int, action: String, referer: URL) async throws -> CommentUpvoteAutomationResponse {
        try await client.submitUpvote(commentID: commentID, action: action, referer: referer)
    }
}

final class WebViewPostUpvoteAutomator: PostUpvoteAutomating {
    private let client: HiddenWebViewPostUpvoteClient

    init(client: HiddenWebViewPostUpvoteClient = HiddenWebViewPostUpvoteClient()) {
        self.client = client
    }

    func submitUpvote(postID: Int, action: String, referer: URL) async throws -> PostUpvoteAutomationResponse {
        try await client.submitUpvote(postID: postID, action: action, referer: referer)
    }
}

final class WebViewCommentChickenLegAutomator: CommentChickenLegAutomating {
    private let client: HiddenWebViewCommentChickenLegClient

    init(client: HiddenWebViewCommentChickenLegClient = HiddenWebViewCommentChickenLegClient()) {
        self.client = client
    }

    func submitChickenLeg(commentID: Int, action: String, referer: URL) async throws -> CommentChickenLegAutomationResponse {
        try await client.submitChickenLeg(commentID: commentID, action: action, referer: referer)
    }
}

final class WebViewPostChickenLegAutomator: PostChickenLegAutomating {
    private let client: HiddenWebViewPostChickenLegClient

    init(client: HiddenWebViewPostChickenLegClient = HiddenWebViewPostChickenLegClient()) {
        self.client = client
    }

    func submitChickenLeg(postID: Int, action: String, referer: URL) async throws -> PostChickenLegAutomationResponse {
        try await client.submitChickenLeg(postID: postID, action: action, referer: referer)
    }
}

final class WebViewCommentDislikeAutomator: CommentDislikeAutomating {
    private let client: HiddenWebViewCommentDislikeClient

    init(client: HiddenWebViewCommentDislikeClient = HiddenWebViewCommentDislikeClient()) {
        self.client = client
    }

    func submitDislike(commentID: Int, action: String, referer: URL) async throws -> CommentDislikeAutomationResponse {
        try await client.submitDislike(commentID: commentID, action: action, referer: referer)
    }
}

final class WebViewPostDislikeAutomator: PostDislikeAutomating {
    private let client: HiddenWebViewPostDislikeClient

    init(client: HiddenWebViewPostDislikeClient = HiddenWebViewPostDislikeClient()) {
        self.client = client
    }

    func submitDislike(postID: Int, action: String, referer: URL) async throws -> PostDislikeAutomationResponse {
        try await client.submitDislike(postID: postID, action: action, referer: referer)
    }
}


@MainActor
private final class NodeSeekDirectActionClient {
    static let shared = NodeSeekDirectActionClient()

    enum ReactionKind {
        case upvote
        case chickenLeg
        case dislike

        var path: String {
            switch self {
            case .upvote:
                return "/api/statistics/upvote"
            case .chickenLeg:
                return "/api/statistics/like"
            case .dislike:
                return "/api/statistics/dislike"
            }
        }
    }

    private struct HTTPJSONResult {
        let data: Data
        let statusCode: Int
        let body: String?

        var isHTTP2xx: Bool {
            (200..<300).contains(statusCode)
        }
    }

    private let session: URLSession
    private let cookieBridge: CookieSynchronizing
    private var postCommentIDCache: [Int: Int] = [:]

    init(
        session: URLSession = .shared,
        cookieBridge: CookieSynchronizing = CookieBridge()
    ) {
        self.session = session
        self.cookieBridge = cookieBridge
    }

    func submitCollection(
        postID: Int,
        action: String,
        referer: URL
    ) async throws -> PostCollectionAutomationResponse {
        let result = try await postJSON(
            path: "/api/statistics/collection",
            referer: referer,
            payload: [
                "postId": postID,
                "action": action
            ]
        )

        let response = NodeSeekPostCollectionSubmitter.collectionResponse(from: result.data)
        let ok = result.isHTTP2xx && response.success != false

        return PostCollectionAutomationResponse(
            ok: ok,
            statusCode: result.statusCode,
            response: response,
            reason: ok ? "direct_http_success" : "direct_http_failed",
            body: result.body
        )
    }

    func submitCommentReaction(
        commentID: Int,
        kind: ReactionKind,
        action: String,
        referer: URL
    ) async throws -> CommentUpvoteAutomationResponse {
        let result = try await postJSON(
            path: kind.path,
            referer: referer,
            payload: [
                "commentId": commentID,
                "action": action
            ]
        )

        let response = Self.reactionResponse(from: result.data)
        let ok = result.isHTTP2xx && response.success != false

        return CommentUpvoteAutomationResponse(
            ok: ok,
            statusCode: result.statusCode,
            response: response,
            reason: ok ? "direct_http_success" : "direct_http_failed",
            body: result.body
        )
    }

    func submitPostReaction(
        postID: Int,
        kind: ReactionKind,
        action: String,
        referer: URL
    ) async throws -> CommentUpvoteAutomationResponse {
        let commentID = try await resolveMainPostCommentID(
            postID: postID,
            referer: referer
        )

        return try await submitCommentReaction(
            commentID: commentID,
            kind: kind,
            action: action,
            referer: referer
        )
    }

    private func postJSON(
        path: String,
        referer: URL,
        payload: [String: Any]
    ) async throws -> HTTPJSONResult {
        await cookieBridge.syncWebViewCookiesToURLSession()

        let url = try actionURL(path: path, referer: referer)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        WebRequestFingerprint.applyHTMLHeaders(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(referer.absoluteString, forHTTPHeaderField: "Referer")
        request.setValue(origin(from: referer), forHTTPHeaderField: "Origin")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        return HTTPJSONResult(
            data: data,
            statusCode: httpResponse.statusCode,
            body: String(data: data, encoding: .utf8)
        )
    }

    private func resolveMainPostCommentID(
        postID: Int,
        referer: URL
    ) async throws -> Int {
        if let cached = postCommentIDCache[postID] {
            return cached
        }

        await cookieBridge.syncWebViewCookiesToURLSession()

        var request = URLRequest(url: referer)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        WebRequestFingerprint.applyHTMLHeaders(to: &request)
        request.setValue(referer.absoluteString, forHTTPHeaderField: "Referer")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode),
              let html = String(data: data, encoding: .utf8)
        else {
            throw URLError(.badServerResponse)
        }

        guard let commentID = Self.extractMainPostCommentID(from: html) else {
            throw URLError(.cannotParseResponse)
        }

        postCommentIDCache[postID] = commentID
        return commentID
    }

    private func actionURL(path: String, referer: URL) throws -> URL {
        var components = URLComponents()
        components.scheme = referer.scheme ?? "https"
        components.host = referer.host ?? "www.nodeseek.com"
        components.port = referer.port
        components.path = path

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        return url
    }

    private func origin(from referer: URL) -> String {
        var components = URLComponents()
        components.scheme = referer.scheme ?? "https"
        components.host = referer.host ?? "www.nodeseek.com"
        components.port = referer.port

        return components.url?.absoluteString ?? "https://www.nodeseek.com"
    }

    private static func extractMainPostCommentID(from html: String) -> Int? {
        let patterns = [
            #"<[^>]*class=["'][^"']*\bcontent-item\b[^"']*["'][^>]*data-comment-id=["'](\d+)["'][^>]*>"#,
            #"<[^>]*data-comment-id=["'](\d+)["'][^>]*class=["'][^"']*\bcontent-item\b[^"']*["'][^>]*>"#,
            #"data-comment-id\s*=\s*["'](\d+)["']"#
        ]

        for pattern in patterns {
            guard let value = firstIntegerMatch(in: html, pattern: pattern) else {
                continue
            }
            return value
        }

        return nil
    }

    private static func firstIntegerMatch(in text: String, pattern: String) -> Int? {
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else {
            return nil
        }

        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)

        guard let match = regex.firstMatch(in: text, range: nsRange),
              match.numberOfRanges >= 2,
              let range = Range(match.range(at: 1), in: text)
        else {
            return nil
        }

        return Int(text[range])
    }

    private static func reactionResponse(from data: Data) -> CommentUpvoteResponse {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            let text = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

            return CommentUpvoteResponse(
                success: false,
                message: trimmed.isEmpty ? "无法解析服务器响应" : trimmed,
                current: nil
            )
        }

        return CommentUpvoteResponse(
            success: boolValue(json["success"]),
            message: firstMessage(in: json),
            current: intValue(json["current"])
        )
    }

    private static func firstMessage(in json: [String: Any]) -> String? {
        for key in ["message", "msg", "error"] {
            guard let value = json[key] as? String else { continue }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty == false {
                return trimmed
            }
        }

        return nil
    }

    private static func boolValue(_ value: Any?) -> Bool? {
        if let bool = value as? Bool {
            return bool
        }

        if let number = value as? NSNumber {
            return number.boolValue
        }

        if let string = value as? String {
            switch string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "true", "1":
                return true
            case "false", "0":
                return false
            default:
                return nil
            }
        }

        return nil
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let int = value as? Int {
            return int
        }

        if let number = value as? NSNumber {
            return number.intValue
        }

        if let string = value as? String {
            return Int(string.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return nil
    }
}

@MainActor
final class DirectPostCollectionAutomator: PostCollectionAutomating {
    private let client: NodeSeekDirectActionClient
    private let fallback: PostCollectionAutomating

    init(
        client: NodeSeekDirectActionClient = .shared,
        fallback: PostCollectionAutomating = WebViewPostCollectionAutomator()
    ) {
        self.client = client
        self.fallback = fallback
    }

    func submitCollection(
        postID: Int,
        action: String,
        referer: URL
    ) async throws -> PostCollectionAutomationResponse {
        do {
            let response = try await client.submitCollection(
                postID: postID,
                action: action,
                referer: referer
            )

            if response.ok {
                return response
            }
        } catch {
            // 直连失败时走原来的隐藏 WebView，保证兼容 Cloudflare / 页面结构变化 / 登录态异常。
        }

        return try await fallback.submitCollection(
            postID: postID,
            action: action,
            referer: referer
        )
    }
}

@MainActor
final class DirectCommentUpvoteAutomator: CommentUpvoteAutomating {
    private let client: NodeSeekDirectActionClient
    private let fallback: CommentUpvoteAutomating

    init(
        client: NodeSeekDirectActionClient = .shared,
        fallback: CommentUpvoteAutomating = WebViewCommentUpvoteAutomator()
    ) {
        self.client = client
        self.fallback = fallback
    }

    func submitUpvote(
        commentID: Int,
        action: String,
        referer: URL
    ) async throws -> CommentUpvoteAutomationResponse {
        do {
            let response = try await client.submitCommentReaction(
                commentID: commentID,
                kind: .upvote,
                action: action,
                referer: referer
            )

            if response.ok {
                return response
            }
        } catch {
            // 直连失败时走原来的隐藏 WebView。
        }

        return try await fallback.submitUpvote(
            commentID: commentID,
            action: action,
            referer: referer
        )
    }
}

@MainActor
final class DirectPostUpvoteAutomator: PostUpvoteAutomating {
    private let client: NodeSeekDirectActionClient
    private let fallback: PostUpvoteAutomating

    init(
        client: NodeSeekDirectActionClient = .shared,
        fallback: PostUpvoteAutomating = WebViewPostUpvoteAutomator()
    ) {
        self.client = client
        self.fallback = fallback
    }

    func submitUpvote(
        postID: Int,
        action: String,
        referer: URL
    ) async throws -> PostUpvoteAutomationResponse {
        do {
            let response = try await client.submitPostReaction(
                postID: postID,
                kind: .upvote,
                action: action,
                referer: referer
            )

            if response.ok {
                return response
            }
        } catch {
            // 直连失败时走原来的隐藏 WebView。
        }

        return try await fallback.submitUpvote(
            postID: postID,
            action: action,
            referer: referer
        )
    }
}

@MainActor
final class DirectCommentChickenLegAutomator: CommentChickenLegAutomating {
    private let client: NodeSeekDirectActionClient
    private let fallback: CommentChickenLegAutomating

    init(
        client: NodeSeekDirectActionClient = .shared,
        fallback: CommentChickenLegAutomating = WebViewCommentChickenLegAutomator()
    ) {
        self.client = client
        self.fallback = fallback
    }

    func submitChickenLeg(
        commentID: Int,
        action: String,
        referer: URL
    ) async throws -> CommentChickenLegAutomationResponse {
        do {
            let response = try await client.submitCommentReaction(
                commentID: commentID,
                kind: .chickenLeg,
                action: action,
                referer: referer
            )

            if response.ok {
                return response
            }
        } catch {
            // 直连失败时走原来的隐藏 WebView。
        }

        return try await fallback.submitChickenLeg(
            commentID: commentID,
            action: action,
            referer: referer
        )
    }
}

@MainActor
final class DirectPostChickenLegAutomator: PostChickenLegAutomating {
    private let client: NodeSeekDirectActionClient
    private let fallback: PostChickenLegAutomating

    init(
        client: NodeSeekDirectActionClient = .shared,
        fallback: PostChickenLegAutomating = WebViewPostChickenLegAutomator()
    ) {
        self.client = client
        self.fallback = fallback
    }

    func submitChickenLeg(
        postID: Int,
        action: String,
        referer: URL
    ) async throws -> PostChickenLegAutomationResponse {
        do {
            let response = try await client.submitPostReaction(
                postID: postID,
                kind: .chickenLeg,
                action: action,
                referer: referer
            )

            if response.ok {
                return response
            }
        } catch {
            // 直连失败时走原来的隐藏 WebView。
        }

        return try await fallback.submitChickenLeg(
            postID: postID,
            action: action,
            referer: referer
        )
    }
}

@MainActor
final class DirectCommentDislikeAutomator: CommentDislikeAutomating {
    private let client: NodeSeekDirectActionClient
    private let fallback: CommentDislikeAutomating

    init(
        client: NodeSeekDirectActionClient = .shared,
        fallback: CommentDislikeAutomating = WebViewCommentDislikeAutomator()
    ) {
        self.client = client
        self.fallback = fallback
    }

    func submitDislike(
        commentID: Int,
        action: String,
        referer: URL
    ) async throws -> CommentDislikeAutomationResponse {
        do {
            let response = try await client.submitCommentReaction(
                commentID: commentID,
                kind: .dislike,
                action: action,
                referer: referer
            )

            if response.ok {
                return response
            }
        } catch {
            // 直连失败时走原来的隐藏 WebView。
        }

        return try await fallback.submitDislike(
            commentID: commentID,
            action: action,
            referer: referer
        )
    }
}

@MainActor
final class DirectPostDislikeAutomator: PostDislikeAutomating {
    private let client: NodeSeekDirectActionClient
    private let fallback: PostDislikeAutomating

    init(
        client: NodeSeekDirectActionClient = .shared,
        fallback: PostDislikeAutomating = WebViewPostDislikeAutomator()
    ) {
        self.client = client
        self.fallback = fallback
    }

    func submitDislike(
        postID: Int,
        action: String,
        referer: URL
    ) async throws -> PostDislikeAutomationResponse {
        do {
            let response = try await client.submitPostReaction(
                postID: postID,
                kind: .dislike,
                action: action,
                referer: referer
            )

            if response.ok {
                return response
            }
        } catch {
            // 直连失败时走原来的隐藏 WebView。
        }

        return try await fallback.submitDislike(
            postID: postID,
            action: action,
            referer: referer
        )
    }
}

@MainActor
protocol PostCollectionSubmitting: AnyObject {
    func addFavorite(postID: String, referer: URL) async throws -> PostCollectionResponse
    func removeFavorite(postID: String, referer: URL) async throws -> PostCollectionResponse
}

@MainActor
protocol CommentUpvoteSubmitting: AnyObject {
    func addUpvote(commentID: String, referer: URL) async throws -> CommentUpvoteResponse
}

@MainActor
protocol PostUpvoteSubmitting: AnyObject {
    func addUpvote(postID: String, referer: URL) async throws -> PostUpvoteResponse
}

@MainActor
protocol CommentChickenLegSubmitting: AnyObject {
    func addChickenLeg(commentID: String, referer: URL) async throws -> CommentChickenLegResponse
}

@MainActor
protocol PostChickenLegSubmitting: AnyObject {
    func addChickenLeg(postID: String, referer: URL) async throws -> PostChickenLegResponse
}

@MainActor
protocol CommentDislikeSubmitting: AnyObject {
    func addDislike(commentID: String, referer: URL) async throws -> CommentDislikeResponse
}

@MainActor
protocol PostDislikeSubmitting: AnyObject {
    func addDislike(postID: String, referer: URL) async throws -> PostDislikeResponse
}

enum NodeSeekPostCollectionSubmitterError: LocalizedError, Equatable {
    case invalidPostID
    case serverMessage(String)
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidPostID:
            return "帖子 ID 无效，无法收藏。"
        case .serverMessage(let message):
            return message
        case .httpStatus(let statusCode):
            return "收藏失败，状态码 \(statusCode)。"
        }
    }
}

enum NodeSeekCommentUpvoteSubmitterError: LocalizedError, Equatable {
    case invalidCommentID
    case serverMessage(String)
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidCommentID:
            return "评论 ID 无效，无法点赞。"
        case .serverMessage(let message):
            return message
        case .httpStatus(let statusCode):
            return "点赞失败，状态码 \(statusCode)。"
        }
    }
}

enum NodeSeekPostUpvoteSubmitterError: LocalizedError, Equatable {
    case invalidPostID
    case serverMessage(String)
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidPostID:
            return "帖子 ID 无效，无法点赞。"
        case .serverMessage(let message):
            return message
        case .httpStatus(let statusCode):
            return "点赞失败，状态码 \(statusCode)。"
        }
    }
}

enum NodeSeekCommentChickenLegSubmitterError: LocalizedError, Equatable {
    case invalidCommentID
    case serverMessage(String)
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidCommentID:
            return "评论 ID 无效，无法投放鸡腿。"
        case .serverMessage(let message):
            return message
        case .httpStatus(let statusCode):
            return "投放鸡腿失败，状态码 \(statusCode)。"
        }
    }
}

enum NodeSeekPostChickenLegSubmitterError: LocalizedError, Equatable {
    case invalidPostID
    case serverMessage(String)
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidPostID:
            return "帖子 ID 无效，无法投放鸡腿。"
        case .serverMessage(let message):
            return message
        case .httpStatus(let statusCode):
            return "投放鸡腿失败，状态码 \(statusCode)。"
        }
    }
}

enum NodeSeekCommentDislikeSubmitterError: LocalizedError, Equatable {
    case invalidCommentID
    case serverMessage(String)
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidCommentID:
            return "评论 ID 无效，无法反对。"
        case .serverMessage(let message):
            return message
        case .httpStatus(let statusCode):
            return "反对失败，状态码 \(statusCode)。"
        }
    }
}

enum NodeSeekPostDislikeSubmitterError: LocalizedError, Equatable {
    case invalidPostID
    case serverMessage(String)
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidPostID:
            return "帖子 ID 无效，无法反对。"
        case .serverMessage(let message):
            return message
        case .httpStatus(let statusCode):
            return "反对失败，状态码 \(statusCode)。"
        }
    }
}

private struct ReactionSubmitterErrors {
    let invalidID: Error
    let serverMessage: (String) -> Error
    let httpStatus: (Int) -> Error
    let fallbackMessage: String
}

@MainActor
private func submitReaction(
    targetID: String,
    action: String,
    referer: URL,
    errors: ReactionSubmitterErrors,
    automation: (Int, String, URL) async throws -> CommentUpvoteAutomationResponse
) async throws -> CommentUpvoteResponse {
    guard let numericTargetID = Int(targetID) else {
        throw errors.invalidID
    }

    let automationResponse = try await automation(numericTargetID, action, referer)
    let response = automationResponse.response

    if let statusCode = automationResponse.statusCode, !(200..<300).contains(statusCode) {
        if let message = response.message {
            throw errors.serverMessage(message)
        }
        throw errors.httpStatus(statusCode)
    }

    guard automationResponse.ok, response.success != false else {
        if let message = response.message {
            throw errors.serverMessage(message)
        }
        throw errors.serverMessage(errors.fallbackMessage)
    }

    return response
}

@MainActor
final class NodeSeekPostCollectionSubmitter: PostCollectionSubmitting {
    private let automation: PostCollectionAutomating

    init(
        automation: PostCollectionAutomating? = nil
    ) {
        self.automation = automation ?? DirectPostCollectionAutomator()
    }

    func addFavorite(postID: String, referer: URL) async throws -> PostCollectionResponse {
        try await submit(postID: postID, action: "add", referer: referer)
    }

    func removeFavorite(postID: String, referer: URL) async throws -> PostCollectionResponse {
        try await submit(postID: postID, action: "remove", referer: referer)
    }

    private func submit(postID: String, action: String, referer: URL) async throws -> PostCollectionResponse {
        guard let numericPostID = Int(postID) else {
            throw NodeSeekPostCollectionSubmitterError.invalidPostID
        }

        let automationResponse = try await automation.submitCollection(
            postID: numericPostID,
            action: action,
            referer: referer
        )
        let collectionResponse = automationResponse.response

        if let statusCode = automationResponse.statusCode, !(200..<300).contains(statusCode) {
            if let message = collectionResponse.message {
                throw NodeSeekPostCollectionSubmitterError.serverMessage(message)
            }
            throw NodeSeekPostCollectionSubmitterError.httpStatus(statusCode)
        }

        guard automationResponse.ok, collectionResponse.success != false else {
            if let message = collectionResponse.message {
                throw NodeSeekPostCollectionSubmitterError.serverMessage(message)
            }
            throw NodeSeekPostCollectionSubmitterError.serverMessage("收藏失败，请稍后重试。")
        }

        return collectionResponse
    }

    static func collectionResponse(from data: Data) -> PostCollectionResponse {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            var message: String?
            for key in ["message", "msg", "error"] {
                guard let value = json[key] as? String else { continue }
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty == false {
                    message = trimmed
                    break
                }
            }

            return PostCollectionResponse(
                success: json["success"] as? Bool,
                message: message,
                postCollectionCount: json["postCollectionCount"] as? Int,
                userCollectionCount: json["userCollectionCount"] as? Int
            )
        }

        let text = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return PostCollectionResponse(message: trimmed.isEmpty ? nil : trimmed)
    }
}

@MainActor
final class NodeSeekCommentUpvoteSubmitter: CommentUpvoteSubmitting {
    private let automation: CommentUpvoteAutomating

    init(automation: CommentUpvoteAutomating? = nil) {
        self.automation = automation ?? DirectCommentUpvoteAutomator()
    }

    func addUpvote(commentID: String, referer: URL) async throws -> CommentUpvoteResponse {
        try await submit(commentID: commentID, action: "add", referer: referer)
    }

    private func submit(commentID: String, action: String, referer: URL) async throws -> CommentUpvoteResponse {
        try await submitReaction(
            targetID: commentID,
            action: action,
            referer: referer,
            errors: ReactionSubmitterErrors(
                invalidID: NodeSeekCommentUpvoteSubmitterError.invalidCommentID,
                serverMessage: NodeSeekCommentUpvoteSubmitterError.serverMessage,
                httpStatus: NodeSeekCommentUpvoteSubmitterError.httpStatus,
                fallbackMessage: "点赞失败，请稍后重试。"
            )
        ) { [automation] commentID, action, referer in
            try await automation.submitUpvote(commentID: commentID, action: action, referer: referer)
        }
    }
}

@MainActor
final class NodeSeekPostUpvoteSubmitter: PostUpvoteSubmitting {
    private let automation: PostUpvoteAutomating

    init(automation: PostUpvoteAutomating? = nil) {
        self.automation = automation ?? DirectPostUpvoteAutomator()
    }

    func addUpvote(postID: String, referer: URL) async throws -> PostUpvoteResponse {
        try await submit(postID: postID, action: "add", referer: referer)
    }

    private func submit(postID: String, action: String, referer: URL) async throws -> PostUpvoteResponse {
        try await submitReaction(
            targetID: postID,
            action: action,
            referer: referer,
            errors: ReactionSubmitterErrors(
                invalidID: NodeSeekPostUpvoteSubmitterError.invalidPostID,
                serverMessage: NodeSeekPostUpvoteSubmitterError.serverMessage,
                httpStatus: NodeSeekPostUpvoteSubmitterError.httpStatus,
                fallbackMessage: "点赞失败，请稍后重试。"
            )
        ) { [automation] postID, action, referer in
            try await automation.submitUpvote(postID: postID, action: action, referer: referer)
        }
    }
}

@MainActor
final class NodeSeekCommentChickenLegSubmitter: CommentChickenLegSubmitting {
    private let automation: CommentChickenLegAutomating

    init(automation: CommentChickenLegAutomating? = nil) {
        self.automation = automation ?? DirectCommentChickenLegAutomator()
    }

    func addChickenLeg(commentID: String, referer: URL) async throws -> CommentChickenLegResponse {
        try await submit(commentID: commentID, action: "add", referer: referer)
    }

    private func submit(commentID: String, action: String, referer: URL) async throws -> CommentChickenLegResponse {
        try await submitReaction(
            targetID: commentID,
            action: action,
            referer: referer,
            errors: ReactionSubmitterErrors(
                invalidID: NodeSeekCommentChickenLegSubmitterError.invalidCommentID,
                serverMessage: NodeSeekCommentChickenLegSubmitterError.serverMessage,
                httpStatus: NodeSeekCommentChickenLegSubmitterError.httpStatus,
                fallbackMessage: "投放鸡腿失败，请稍后重试。"
            )
        ) { [automation] commentID, action, referer in
            try await automation.submitChickenLeg(commentID: commentID, action: action, referer: referer)
        }
    }
}

@MainActor
final class NodeSeekPostChickenLegSubmitter: PostChickenLegSubmitting {
    private let automation: PostChickenLegAutomating

    init(automation: PostChickenLegAutomating? = nil) {
        self.automation = automation ?? DirectPostChickenLegAutomator()
    }

    func addChickenLeg(postID: String, referer: URL) async throws -> PostChickenLegResponse {
        try await submit(postID: postID, action: "add", referer: referer)
    }

    private func submit(postID: String, action: String, referer: URL) async throws -> PostChickenLegResponse {
        try await submitReaction(
            targetID: postID,
            action: action,
            referer: referer,
            errors: ReactionSubmitterErrors(
                invalidID: NodeSeekPostChickenLegSubmitterError.invalidPostID,
                serverMessage: NodeSeekPostChickenLegSubmitterError.serverMessage,
                httpStatus: NodeSeekPostChickenLegSubmitterError.httpStatus,
                fallbackMessage: "投放鸡腿失败，请稍后重试。"
            )
        ) { [automation] postID, action, referer in
            try await automation.submitChickenLeg(postID: postID, action: action, referer: referer)
        }
    }
}

@MainActor
final class NodeSeekCommentDislikeSubmitter: CommentDislikeSubmitting {
    private let automation: CommentDislikeAutomating

    init(automation: CommentDislikeAutomating? = nil) {
        self.automation = automation ?? DirectCommentDislikeAutomator()
    }

    func addDislike(commentID: String, referer: URL) async throws -> CommentDislikeResponse {
        try await submit(commentID: commentID, action: "add", referer: referer)
    }

    private func submit(commentID: String, action: String, referer: URL) async throws -> CommentDislikeResponse {
        try await submitReaction(
            targetID: commentID,
            action: action,
            referer: referer,
            errors: ReactionSubmitterErrors(
                invalidID: NodeSeekCommentDislikeSubmitterError.invalidCommentID,
                serverMessage: NodeSeekCommentDislikeSubmitterError.serverMessage,
                httpStatus: NodeSeekCommentDislikeSubmitterError.httpStatus,
                fallbackMessage: "反对失败，请稍后重试。"
            )
        ) { [automation] commentID, action, referer in
            try await automation.submitDislike(commentID: commentID, action: action, referer: referer)
        }
    }
}

@MainActor
final class NodeSeekPostDislikeSubmitter: PostDislikeSubmitting {
    private let automation: PostDislikeAutomating

    init(automation: PostDislikeAutomating? = nil) {
        self.automation = automation ?? DirectPostDislikeAutomator()
    }

    func addDislike(postID: String, referer: URL) async throws -> PostDislikeResponse {
        try await submit(postID: postID, action: "add", referer: referer)
    }

    private func submit(postID: String, action: String, referer: URL) async throws -> PostDislikeResponse {
        try await submitReaction(
            targetID: postID,
            action: action,
            referer: referer,
            errors: ReactionSubmitterErrors(
                invalidID: NodeSeekPostDislikeSubmitterError.invalidPostID,
                serverMessage: NodeSeekPostDislikeSubmitterError.serverMessage,
                httpStatus: NodeSeekPostDislikeSubmitterError.httpStatus,
                fallbackMessage: "反对失败，请稍后重试。"
            )
        ) { [automation] postID, action, referer in
            try await automation.submitDislike(postID: postID, action: action, referer: referer)
        }
    }
}
