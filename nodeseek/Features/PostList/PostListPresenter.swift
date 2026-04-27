//
//  PostListPresenter.swift
//  nodeseek
//
//  Created by Codex on 2026/4/27.
//

import Foundation

class PostListPresenter: PostListPresenterProtocol {
    
    // MARK: - Properties
    private weak var view: PostListViewProtocol?
    private let interactor: PostListInteractorInput
    private let router: PostListRouterProtocol
    private var posts: [PostSummary] = []
    private var loadedIDs = Set<String>()
    private var nextPage = 2
    private var isLoadingMore = false
    private var hasMorePages = true
    
    // MARK: - Initialization
    init(
        interactor: PostListInteractorInput,
        router: PostListRouterProtocol
    ) {
        self.interactor = interactor
        self.router = router
    }
    
    // MARK: - Setup
    func setView(_ view: PostListViewProtocol) {
        self.view = view
    }
    
    // MARK: - Methods
    func viewDidLoad() {
        nextPage = 2
        isLoadingMore = false
        hasMorePages = true
        loadedIDs.removeAll()
        view?.showLoading()
        interactor.loadPosts()
    }
    
    func didSelectPost(at index: Int) {
        guard posts.indices.contains(index) else { return }
        router.navigateToPostDetail(post: posts[index])
    }

    func didApproachBottom(currentIndex: Int, totalCount: Int) {
        guard totalCount > 0 else { return }
        guard hasMorePages else { return }
        guard !isLoadingMore else { return }
        guard currentIndex >= max(totalCount - 3, 0) else { return }

        isLoadingMore = true
        view?.showLoadingMore()
        interactor.loadMorePosts(page: nextPage)
    }
}

// MARK: - Interactor Output
extension PostListPresenter: PostListInteractorOutput {
    
    func didLoadPosts(_ posts: [PostSummary]) {
        loadedIDs = Set(posts.map(\.id))
        self.posts = posts
        hasMorePages = !posts.isEmpty
        nextPage = 2
        isLoadingMore = false
        view?.hideLoading()
        view?.hideLoadingMore()
        view?.render(posts: posts)
    }

    func didLoadMorePosts(_ posts: [PostSummary], page: Int) {
        isLoadingMore = false
        view?.hideLoadingMore()

        guard !posts.isEmpty else {
            hasMorePages = false
            return
        }

        nextPage = page + 1
        var appended = false
        for post in posts where loadedIDs.insert(post.id).inserted {
            self.posts.append(post)
            appended = true
        }

        if appended {
            view?.render(posts: self.posts)
        }
    }
    
    func didFailLoadPosts(error: String) {
        isLoadingMore = false
        view?.hideLoading()
        view?.hideLoadingMore()
        view?.showError(message: error)
    }

    func didFailLoadMorePosts(error: String, page: Int) {
        isLoadingMore = false
        view?.hideLoadingMore()
        view?.showError(message: "第 \(page) 页加载失败：\(error)")
    }
}
