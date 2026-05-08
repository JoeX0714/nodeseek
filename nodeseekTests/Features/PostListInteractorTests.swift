//
//  PostListInteractorTests.swift
//  nodeseekTests
//
//  Created by Codex on 2026/4/27.
//

import Foundation
import Testing
@testable import nodeseek

@MainActor
struct PostListInteractorTests {
    @Test func syncsWebViewCookiesBeforeLoadingFirstPage() async throws {
        let html = try FixtureLoader.html(named: "post-list-basic")
        let url = URL(string: "https://www.nodeseek.com/")!
        let events = EventRecorder()
        let htmlClient = EventRecordingHTMLClient(
            response: HTMLResponse(
                statusCode: 200,
                headers: [:],
                finalURL: url,
                html: html
            ),
            events: events
        )
        let service = NodeSeekService(
            baseURL: url,
            htmlClient: htmlClient,
            parser: KannaNodeSeekParser(baseURL: url)
        )
        let presenter = SpyPostListInteractorOutput()
        let interactor = PostListInteractor(
            service: service,
            sessionStore: NodeSeekSessionStore(),
            cookieSynchronizer: SpyCookieSynchronizer(events: events)
        )
        interactor.presenter = presenter

        interactor.loadPosts(category: .all, sortMode: .replyTime)
        await waitForInteractorCallbacks()

        let recordedEvents = await events.recordedEvents()
        #expect(recordedEvents.prefix(2) == ["sync", "get"])
        #expect(presenter.loadedPosts?.count == 1)
        #expect(presenter.errorMessage == nil)
    }

    @Test func stopsAfterFirstChallengeAndUpdatesSharedSessionState() async throws {
        let html = try FixtureLoader.html(named: "cloudflare-challenge")
        let url = URL(string: "https://www.nodeseek.com/")!
        let htmlClient = URLCapturingHTMLClient(response: HTMLResponse(
            statusCode: 403,
            headers: [:],
            finalURL: url,
            html: html
        ))
        let service = NodeSeekService(
            baseURL: url,
            htmlClient: htmlClient,
            parser: KannaNodeSeekParser(baseURL: url)
        )
        let sessionStore = NodeSeekSessionStore()
        let presenter = SpyPostListInteractorOutput()
        let interactor = PostListInteractor(service: service, sessionStore: sessionStore)
        interactor.presenter = presenter

        interactor.loadPosts(category: .all, sortMode: .replyTime)
        await waitForInteractorCallbacks()

        let requestedURLs = await htmlClient.requestedURLs()
        let state = await sessionStore.currentState()

        #expect(requestedURLs.count == 1)
        #expect(presenter.loadedPosts == nil)
        #expect(presenter.errorMessage == "站点当前需要 Cloudflare 验证，请稍后重试。")
        guard case .challengeRequired(.cloudflare, _) = state else {
            Issue.record("列表命中 challenge 后应写入统一 session 状态")
            return
        }
    }
}

private actor EventRecorder {
    private var events: [String] = []

    func record(_ event: String) {
        events.append(event)
    }

    func recordedEvents() -> [String] {
        events
    }
}

@MainActor
private final class SpyCookieSynchronizer: CookieSynchronizing {
    private let events: EventRecorder

    init(events: EventRecorder) {
        self.events = events
    }

    func syncWebViewCookiesToURLSession() async {
        await events.record("sync")
    }
}

private actor EventRecordingHTMLClient: HTMLClient {
    private let response: HTMLResponse
    private let events: EventRecorder

    init(response: HTMLResponse, events: EventRecorder) {
        self.response = response
        self.events = events
    }

    func get(_ url: URL) async throws -> HTMLResponse {
        await events.record("get")
        return response
    }

    func post(_ url: URL, formFields: [String: String]) async throws -> HTMLResponse {
        await events.record("post")
        return response
    }
}

@MainActor
private final class SpyPostListInteractorOutput: PostListInteractorOutput {
    var loadedPosts: [PostSummary]?
    var errorMessage: String?

    func didLoadPosts(_ posts: [PostSummary], category: PostListCategory, sortMode: PostListSortMode) {
        loadedPosts = posts
    }

    func didLoadMorePosts(_ posts: [PostSummary], page: Int, category: PostListCategory, sortMode: PostListSortMode) {
    }

    func didFailLoadPosts(error: String, category: PostListCategory, sortMode: PostListSortMode) {
        errorMessage = error
    }

    func didFailLoadMorePosts(error: String, page: Int, category: PostListCategory, sortMode: PostListSortMode) {
        errorMessage = error
    }
}

@MainActor
private func waitForInteractorCallbacks() async {
    for _ in 0..<50 {
        await Task.yield()
        try? await Task.sleep(nanoseconds: 20_000_000)
    }
}

private actor URLCapturingHTMLClient: HTMLClient {
    private var urls: [URL] = []
    private let response: HTMLResponse

    init(response: HTMLResponse) {
        self.response = response
    }

    func get(_ url: URL) async throws -> HTMLResponse {
        urls.append(url)
        return response
    }

    func post(_ url: URL, formFields: [String: String]) async throws -> HTMLResponse {
        urls.append(url)
        return response
    }

    func requestedURLs() -> [URL] {
        urls
    }
}
