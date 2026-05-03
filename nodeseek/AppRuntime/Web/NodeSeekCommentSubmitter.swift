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

@MainActor
final class NodeSeekPostCollectionSubmitter: PostCollectionSubmitting {
    private let automation: PostCollectionAutomating

    init(
        automation: PostCollectionAutomating? = nil
    ) {
        self.automation = automation ?? WebViewPostCollectionAutomator()
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
        self.automation = automation ?? WebViewCommentUpvoteAutomator()
    }

    func addUpvote(commentID: String, referer: URL) async throws -> CommentUpvoteResponse {
        try await submit(commentID: commentID, action: "add", referer: referer)
    }

    private func submit(commentID: String, action: String, referer: URL) async throws -> CommentUpvoteResponse {
        guard let numericCommentID = Int(commentID) else {
            throw NodeSeekCommentUpvoteSubmitterError.invalidCommentID
        }

        let automationResponse = try await automation.submitUpvote(
            commentID: numericCommentID,
            action: action,
            referer: referer
        )
        let upvoteResponse = automationResponse.response

        if let statusCode = automationResponse.statusCode, !(200..<300).contains(statusCode) {
            if let message = upvoteResponse.message {
                throw NodeSeekCommentUpvoteSubmitterError.serverMessage(message)
            }
            throw NodeSeekCommentUpvoteSubmitterError.httpStatus(statusCode)
        }

        guard automationResponse.ok, upvoteResponse.success != false else {
            if let message = upvoteResponse.message {
                throw NodeSeekCommentUpvoteSubmitterError.serverMessage(message)
            }
            throw NodeSeekCommentUpvoteSubmitterError.serverMessage("点赞失败，请稍后重试。")
        }

        return upvoteResponse
    }
}

@MainActor
final class NodeSeekPostUpvoteSubmitter: PostUpvoteSubmitting {
    private let automation: PostUpvoteAutomating

    init(automation: PostUpvoteAutomating? = nil) {
        self.automation = automation ?? WebViewPostUpvoteAutomator()
    }

    func addUpvote(postID: String, referer: URL) async throws -> PostUpvoteResponse {
        try await submit(postID: postID, action: "add", referer: referer)
    }

    private func submit(postID: String, action: String, referer: URL) async throws -> PostUpvoteResponse {
        guard let numericPostID = Int(postID) else {
            throw NodeSeekPostUpvoteSubmitterError.invalidPostID
        }

        let automationResponse = try await automation.submitUpvote(
            postID: numericPostID,
            action: action,
            referer: referer
        )
        let upvoteResponse = automationResponse.response

        if let statusCode = automationResponse.statusCode, !(200..<300).contains(statusCode) {
            if let message = upvoteResponse.message {
                throw NodeSeekPostUpvoteSubmitterError.serverMessage(message)
            }
            throw NodeSeekPostUpvoteSubmitterError.httpStatus(statusCode)
        }

        guard automationResponse.ok, upvoteResponse.success != false else {
            if let message = upvoteResponse.message {
                throw NodeSeekPostUpvoteSubmitterError.serverMessage(message)
            }
            throw NodeSeekPostUpvoteSubmitterError.serverMessage("点赞失败，请稍后重试。")
        }

        return upvoteResponse
    }
}

@MainActor
final class NodeSeekCommentDislikeSubmitter: CommentDislikeSubmitting {
    private let automation: CommentDislikeAutomating

    init(automation: CommentDislikeAutomating? = nil) {
        self.automation = automation ?? WebViewCommentDislikeAutomator()
    }

    func addDislike(commentID: String, referer: URL) async throws -> CommentDislikeResponse {
        try await submit(commentID: commentID, action: "add", referer: referer)
    }

    private func submit(commentID: String, action: String, referer: URL) async throws -> CommentDislikeResponse {
        guard let numericCommentID = Int(commentID) else {
            throw NodeSeekCommentDislikeSubmitterError.invalidCommentID
        }

        let automationResponse = try await automation.submitDislike(
            commentID: numericCommentID,
            action: action,
            referer: referer
        )
        let dislikeResponse = automationResponse.response

        if let statusCode = automationResponse.statusCode, !(200..<300).contains(statusCode) {
            if let message = dislikeResponse.message {
                throw NodeSeekCommentDislikeSubmitterError.serverMessage(message)
            }
            throw NodeSeekCommentDislikeSubmitterError.httpStatus(statusCode)
        }

        guard automationResponse.ok, dislikeResponse.success != false else {
            if let message = dislikeResponse.message {
                throw NodeSeekCommentDislikeSubmitterError.serverMessage(message)
            }
            throw NodeSeekCommentDislikeSubmitterError.serverMessage("反对失败，请稍后重试。")
        }

        return dislikeResponse
    }
}

@MainActor
final class NodeSeekPostDislikeSubmitter: PostDislikeSubmitting {
    private let automation: PostDislikeAutomating

    init(automation: PostDislikeAutomating? = nil) {
        self.automation = automation ?? WebViewPostDislikeAutomator()
    }

    func addDislike(postID: String, referer: URL) async throws -> PostDislikeResponse {
        try await submit(postID: postID, action: "add", referer: referer)
    }

    private func submit(postID: String, action: String, referer: URL) async throws -> PostDislikeResponse {
        guard let numericPostID = Int(postID) else {
            throw NodeSeekPostDislikeSubmitterError.invalidPostID
        }

        let automationResponse = try await automation.submitDislike(
            postID: numericPostID,
            action: action,
            referer: referer
        )
        let dislikeResponse = automationResponse.response

        if let statusCode = automationResponse.statusCode, !(200..<300).contains(statusCode) {
            if let message = dislikeResponse.message {
                throw NodeSeekPostDislikeSubmitterError.serverMessage(message)
            }
            throw NodeSeekPostDislikeSubmitterError.httpStatus(statusCode)
        }

        guard automationResponse.ok, dislikeResponse.success != false else {
            if let message = dislikeResponse.message {
                throw NodeSeekPostDislikeSubmitterError.serverMessage(message)
            }
            throw NodeSeekPostDislikeSubmitterError.serverMessage("反对失败，请稍后重试。")
        }

        return dislikeResponse
    }
}
