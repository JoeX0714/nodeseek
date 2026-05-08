import Foundation

@MainActor
final class NodeSeekDirectActionClient {

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
        cookieBridge: CookieSynchronizing? = nil
    ) {
        self.session = session
        self.cookieBridge = cookieBridge ?? CookieBridge()
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

        let baseURL = URL(
            string: "\(referer.scheme ?? "https")://\(referer.host ?? "www.nodeseek.com")"
        )!

        let url = URL(string: path, relativeTo: baseURL)!
        var request = URLRequest(url: url)

        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        WebRequestFingerprint.applyHTMLHeaders(to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(referer.absoluteString, forHTTPHeaderField: "Referer")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        let body = String(data: data, encoding: .utf8)

        return HTTPJSONResult(
            data: data,
            statusCode: httpResponse.statusCode,
            body: body
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
        WebRequestFingerprint.applyHTMLHeaders(to: &request)
        request.setValue(referer.absoluteString, forHTTPHeaderField: "Referer")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode),
              let html = String(data: data, encoding: .utf8)
        else {
            throw URLError(.badServerResponse)
        }

        guard let commentID = Self.extractFirstDataCommentID(from: html) else {
            throw URLError(.cannotParseResponse)
        }

        postCommentIDCache[postID] = commentID
        return commentID
    }

    private static func extractFirstDataCommentID(from html: String) -> Int? {
        let pattern = #"data-comment-id\s*=\s*["'](\d+)["']"#

        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let nsRange = NSRange(html.startIndex..<html.endIndex, in: html)

        guard let match = regex.firstMatch(in: html, range: nsRange),
              match.numberOfRanges >= 2,
              let range = Range(match.range(at: 1), in: html)
        else {
            return nil
        }

        return Int(html[range])
    }

    private static func reactionResponse(from data: Data) -> CommentUpvoteResponse {
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let json = object as? [String: Any]
        else {
            return CommentUpvoteResponse(
                success: false,
                message: "无法解析服务器响应",
                current: nil
            )
        }

        let success = json["success"] as? Bool
        let message = json["message"] as? String
        let current = json["current"] as? Int

        return CommentUpvoteResponse(
            success: success,
            message: message,
            current: current
        )
    }
}

@MainActor
final class DirectPostCollectionAutomator: PostCollectionAutomating {

    private let client: NodeSeekDirectActionClient
    private let fallback: PostCollectionAutomating

    init(
        client: NodeSeekDirectActionClient? = nil,
        fallback: PostCollectionAutomating? = nil
    ) {
        self.client = client ?? .shared
        self.fallback = fallback ?? WebViewPostCollectionAutomator()
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

            return try await fallback.submitCollection(
                postID: postID,
                action: action,
                referer: referer
            )
        } catch {
            return try await fallback.submitCollection(
                postID: postID,
                action: action,
                referer: referer
            )
        }
    }
}

@MainActor
final class DirectCommentUpvoteAutomator: CommentUpvoteAutomating {

    private let client: NodeSeekDirectActionClient
    private let fallback: CommentUpvoteAutomating

    init(
        client: NodeSeekDirectActionClient? = nil,
        fallback: CommentUpvoteAutomating? = nil
    ) {
        self.client = client ?? .shared
        self.fallback = fallback ?? WebViewCommentUpvoteAutomator()
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

            return try await fallback.submitUpvote(
                commentID: commentID,
                action: action,
                referer: referer
            )
        } catch {
            return try await fallback.submitUpvote(
                commentID: commentID,
                action: action,
                referer: referer
            )
        }
    }
}

@MainActor
final class DirectPostUpvoteAutomator: PostUpvoteAutomating {

    private let client: NodeSeekDirectActionClient
    private let fallback: PostUpvoteAutomating

    init(
        client: NodeSeekDirectActionClient? = nil,
        fallback: PostUpvoteAutomating? = nil
    ) {
        self.client = client ?? .shared
        self.fallback = fallback ?? WebViewPostUpvoteAutomator()
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

            return try await fallback.submitUpvote(
                postID: postID,
                action: action,
                referer: referer
            )
        } catch {
            return try await fallback.submitUpvote(
                postID: postID,
                action: action,
                referer: referer
            )
        }
    }
}

@MainActor
final class DirectCommentChickenLegAutomator: CommentChickenLegAutomating {

    private let client: NodeSeekDirectActionClient
    private let fallback: CommentChickenLegAutomating

    init(
        client: NodeSeekDirectActionClient? = nil,
        fallback: CommentChickenLegAutomating? = nil
    ) {
        self.client = client ?? .shared
        self.fallback = fallback ?? WebViewCommentChickenLegAutomator()
    }

    func submitChickenLeg(
        commentID: Int,
        action: String,
        referer: URL
    ) async throws -> CommentUpvoteAutomationResponse {
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

            return try await fallback.submitChickenLeg(
                commentID: commentID,
                action: action,
                referer: referer
            )
        } catch {
            return try await fallback.submitChickenLeg(
                commentID: commentID,
                action: action,
                referer: referer
            )
        }
    }
}

@MainActor
final class DirectPostChickenLegAutomator: PostChickenLegAutomating {

    private let client: NodeSeekDirectActionClient
    private let fallback: PostChickenLegAutomating

    init(
        client: NodeSeekDirectActionClient? = nil,
        fallback: PostChickenLegAutomating? = nil
    ) {
        self.client = client ?? .shared
        self.fallback = fallback ?? WebViewPostChickenLegAutomator()
    }

    func submitChickenLeg(
        postID: Int,
        action: String,
        referer: URL
    ) async throws -> PostUpvoteAutomationResponse {
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

            return try await fallback.submitChickenLeg(
                postID: postID,
                action: action,
                referer: referer
            )
        } catch {
            return try await fallback.submitChickenLeg(
                postID: postID,
                action: action,
                referer: referer
            )
        }
    }
}

@MainActor
final class DirectCommentDislikeAutomator: CommentDislikeAutomating {

    private let client: NodeSeekDirectActionClient
    private let fallback: CommentDislikeAutomating

    init(
        client: NodeSeekDirectActionClient? = nil,
        fallback: CommentDislikeAutomating? = nil
    ) {
        self.client = client ?? .shared
        self.fallback = fallback ?? WebViewCommentDislikeAutomator()
    }

    func submitDislike(
        commentID: Int,
        action: String,
        referer: URL
    ) async throws -> CommentUpvoteAutomationResponse {
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

            return try await fallback.submitDislike(
                commentID: commentID,
                action: action,
                referer: referer
            )
        } catch {
            return try await fallback.submitDislike(
                commentID: commentID,
                action: action,
                referer: referer
            )
        }
    }
}

@MainActor
final class DirectPostDislikeAutomator: PostDislikeAutomating {

    private let client: NodeSeekDirectActionClient
    private let fallback: PostDislikeAutomating

    init(
        client: NodeSeekDirectActionClient? = nil,
        fallback: PostDislikeAutomating? = nil
    ) {
        self.client = client ?? .shared
        self.fallback = fallback ?? WebViewPostDislikeAutomator()
    }

    func submitDislike(
        postID: Int,
        action: String,
        referer: URL
    ) async throws -> PostUpvoteAutomationResponse {
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

            return try await fallback.submitDislike(
                postID: postID,
                action: action,
                referer: referer
            )
        } catch {
            return try await fallback.submitDislike(
                postID: postID,
                action: action,
                referer: referer
            )
        }
    }
}
