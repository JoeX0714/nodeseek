//
//  PostDetailPresenter.swift
//  nodeseek
//
//  Created by Codex on 2026/4/27.
//

import Foundation

class PostDetailPresenter: PostDetailPresenterProtocol {
    
    // MARK: - Properties
    private weak var view: PostDetailViewProtocol?
    private let interactor: PostDetailInteractorInput
    private let router: PostDetailRouterProtocol
    private var currentDetail: PostDetail?
    private var isSubmittingReply = false
    
    // MARK: - Initialization
    init(
        interactor: PostDetailInteractorInput,
        router: PostDetailRouterProtocol
    ) {
        self.interactor = interactor
        self.router = router
    }
    
    // MARK: - Setup
    func setView(_ view: PostDetailViewProtocol) {
        self.view = view
    }
    
    // MARK: - Methods
    func viewDidLoad() {
        view?.showLoading()
        interactor.loadPostDetail()
    }

    func didTapLogin() {
        router.navigateToLogin { [weak self] in
            self?.view?.showLoading()
            self?.interactor.loadPostDetail()
        }
    }

    func didTapSendReply(content: String) {
        guard isSubmittingReply == false else { return }

        let normalizedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedContent.isEmpty == false else {
            view?.showError(message: "回复内容不能为空。")
            return
        }

        isSubmittingReply = true
        view?.setReplySubmitting(true)
        interactor.submitReply(content: normalizedContent)
    }
}

// MARK: - Interactor Output
extension PostDetailPresenter: PostDetailInteractorOutput {
    
    func didLoadPostDetail(_ response: PostDetailResponse) {
        currentDetail = response.detail
        view?.hideLoading()
        view?.render(detail: response.detail)
    }

    func didRequireLogin(message: String) {
        view?.hideLoading()
        view?.renderLoginRequired(message: message)
    }
    
    func didFailLoadPostDetail(error: String) {
        view?.hideLoading()
        view?.showError(message: error)
    }

    func didSubmitReply() {
        isSubmittingReply = false
        view?.setReplySubmitting(false)
        view?.finishReplySubmission()
        if currentDetail?.isLastPage == true {
            view?.showLoading()
            interactor.loadPostDetail()
        }
    }

    func didFailSubmitReply(error: String) {
        isSubmittingReply = false
        view?.setReplySubmitting(false)
        view?.showError(message: error)
    }
}
