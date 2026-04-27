//
//  PostListPresenterTests.swift
//  nodeseekTests
//
//  Created by Codex on 2026/4/27.
//

import Foundation
import Testing
@testable import nodeseek

@MainActor
struct PostListPresenterTests {
    @Test func selectingPostNavigatesToDetail() {
        let view = SpyPostListView()
        let interactor = SpyPostListInteractor()
        let router = SpyPostListRouter()
        let presenter = PostListPresenter(interactor: interactor, router: router)
        presenter.setView(view)
        let post = PostSummary(
            id: "1",
            title: "标题",
            url: URL(string: "https://www.nodeseek.com/post-1")!,
            authorName: "mist",
            nodeName: "开发",
            replyCount: 3,
            lastActivityText: "刚刚"
        )

        presenter.didLoadPosts([post])
        presenter.didSelectPost(at: 0)

        #expect(router.selectedPost?.id == "1")
    }

    @Test func approachingBottomTriggersLoadMoreForNextPage() {
        let view = SpyPostListView()
        let interactor = SpyPostListInteractor()
        let router = SpyPostListRouter()
        let presenter = PostListPresenter(interactor: interactor, router: router)
        presenter.setView(view)
        let post = PostSummary(
            id: "1",
            title: "标题",
            url: URL(string: "https://www.nodeseek.com/post-1")!,
            authorName: "mist",
            nodeName: "开发",
            replyCount: 3,
            lastActivityText: "刚刚"
        )

        presenter.didLoadPosts([post])
        presenter.didApproachBottom(currentIndex: 0, totalCount: 1)

        #expect(interactor.loadMorePages == [2])
        #expect(view.showLoadingMoreCount == 1)
    }

    @Test func loadMoreAppendsUniquePosts() {
        let view = SpyPostListView()
        let interactor = SpyPostListInteractor()
        let router = SpyPostListRouter()
        let presenter = PostListPresenter(interactor: interactor, router: router)
        presenter.setView(view)
        let first = PostSummary(
            id: "1",
            title: "标题1",
            url: URL(string: "https://www.nodeseek.com/post-1")!,
            authorName: "mist",
            nodeName: "开发",
            replyCount: 3,
            lastActivityText: "刚刚"
        )
        let duplicate = PostSummary(
            id: "1",
            title: "标题1",
            url: URL(string: "https://www.nodeseek.com/post-1")!,
            authorName: "mist",
            nodeName: "开发",
            replyCount: 3,
            lastActivityText: "刚刚"
        )
        let second = PostSummary(
            id: "2",
            title: "标题2",
            url: URL(string: "https://www.nodeseek.com/post-2")!,
            authorName: "mist",
            nodeName: "开发",
            replyCount: 4,
            lastActivityText: "1 分钟前"
        )

        presenter.didLoadPosts([first])
        presenter.didApproachBottom(currentIndex: 0, totalCount: 1)
        presenter.didLoadMorePosts([duplicate, second], page: 2)
        presenter.didSelectPost(at: 1)

        #expect(view.renderCallCount == 2)
        #expect(view.lastRenderedPostsCount == 2)
        #expect(router.selectedPost?.id == "2")
    }
}

@MainActor
private final class SpyPostListView: PostListViewProtocol {
    var showLoadingCount = 0
    var hideLoadingCount = 0
    var showLoadingMoreCount = 0
    var hideLoadingMoreCount = 0
    var renderCallCount = 0
    var lastRenderedPostsCount = 0
    var lastErrorMessage: String?

    func showLoading() {
        showLoadingCount += 1
    }

    func hideLoading() {
        hideLoadingCount += 1
    }

    func showLoadingMore() {
        showLoadingMoreCount += 1
    }

    func hideLoadingMore() {
        hideLoadingMoreCount += 1
    }

    func showError(message: String) {
        lastErrorMessage = message
    }

    func render(posts: [PostSummary]) {
        renderCallCount += 1
        lastRenderedPostsCount = posts.count
    }
}

@MainActor
private final class SpyPostListInteractor: PostListInteractorInput {
    var loadPostsCallCount = 0
    var loadMorePages: [Int] = []

    func loadPosts() {
        loadPostsCallCount += 1
    }

    func loadMorePosts(page: Int) {
        loadMorePages.append(page)
    }
}

@MainActor
private final class SpyPostListRouter: PostListRouterProtocol {
    var selectedPost: PostSummary?

    func navigateToPostDetail(post: PostSummary) {
        selectedPost = post
    }
}
