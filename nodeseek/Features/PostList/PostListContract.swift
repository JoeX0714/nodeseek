//
//  PostListContract.swift
//  nodeseek
//
//  Created by Codex on 2026/4/27.
//

import Foundation

// MARK: - View Protocol (Presenter -> View)
protocol PostListViewProtocol: AnyObject {
    func showLoading()
    func hideLoading()
    func showLoadingMore()
    func hideLoadingMore()
    func showError(message: String)
    func render(posts: [PostSummary])
}

// MARK: - Presenter Protocol (View -> Presenter)
protocol PostListPresenterProtocol: AnyObject {
    func viewDidLoad()
    func didSelectPost(at index: Int)
    func didApproachBottom(currentIndex: Int, totalCount: Int)
}

// MARK: - Interactor Input (Presenter -> Interactor)
protocol PostListInteractorInput: AnyObject {
    func loadPosts()
    func loadMorePosts(page: Int)
}

// MARK: - Interactor Output (Interactor -> Presenter)
protocol PostListInteractorOutput: AnyObject {
    func didLoadPosts(_ posts: [PostSummary])
    func didLoadMorePosts(_ posts: [PostSummary], page: Int)
    func didFailLoadPosts(error: String)
    func didFailLoadMorePosts(error: String, page: Int)
}

// MARK: - Router Protocol (Presenter -> Router)
protocol PostListRouterProtocol: AnyObject {
    func navigateToPostDetail(post: PostSummary)
}
