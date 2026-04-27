//
//  ReplyComposerPresenter.swift
//  nodeseek
//
//  Created by Codex on 2026/4/27.
//

import Foundation

class ReplyComposerPresenter: ReplyComposerPresenterProtocol {
    
    // MARK: - Properties
    private weak var view: ReplyComposerViewProtocol?
    private let interactor: ReplyComposerInteractorInput
    private let router: ReplyComposerRouterProtocol
    
    // MARK: - Initialization
    init(
        interactor: ReplyComposerInteractorInput,
        router: ReplyComposerRouterProtocol
    ) {
        self.interactor = interactor
        self.router = router
    }
    
    // MARK: - Setup
    func setView(_ view: ReplyComposerViewProtocol) {
        self.view = view
    }
    
    // MARK: - Methods
    func viewDidLoad() {
        view?.showLoading()
        interactor.prepareReply()
    }
}

// MARK: - Interactor Output
extension ReplyComposerPresenter: ReplyComposerInteractorOutput {
    
    func didPrepareReply(_ response: ReplyComposerResponse) {
        view?.hideLoading()
        view?.showPlaceholder(response.placeholder)
    }
    
    func didFailPrepareReply(error: String) {
        view?.hideLoading()
        view?.showError(message: error)
    }
}
