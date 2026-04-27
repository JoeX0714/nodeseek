//
//  WebChallengePresenter.swift
//  nodeseek
//
//  Created by Codex on 2026/4/27.
//

import Foundation

class WebChallengePresenter: WebChallengePresenterProtocol {
    
    // MARK: - Properties
    private weak var view: WebChallengeViewProtocol?
    private let interactor: WebChallengeInteractorInput
    private let router: WebChallengeRouterProtocol
    
    // MARK: - Initialization
    init(
        interactor: WebChallengeInteractorInput,
        router: WebChallengeRouterProtocol
    ) {
        self.interactor = interactor
        self.router = router
    }
    
    // MARK: - Setup
    func setView(_ view: WebChallengeViewProtocol) {
        self.view = view
    }
    
    // MARK: - Methods
    func viewDidLoad() {
        view?.showLoading()
        interactor.resolveChallengeURL()
    }

    func webViewDidFinishNavigation(pageTitle: String?, html: String, url: URL?) {
        guard !Self.isChallengePage(pageTitle: pageTitle, html: html) else {
            return
        }

        view?.showLoading()
        interactor.syncSolvedSession()
    }

    func didTapDone() {
        view?.showLoading()
        interactor.syncSolvedSession()
    }

    private static func isChallengePage(pageTitle: String?, html: String) -> Bool {
        if pageTitle?.localizedCaseInsensitiveContains("Just a moment") == true {
            return true
        }

        return html.contains("window._cf_chl_opt")
            || html.contains("/cdn-cgi/challenge-platform/")
            || html.contains("Enable JavaScript and cookies to continue")
    }
}

// MARK: - Interactor Output
extension WebChallengePresenter: WebChallengeInteractorOutput {
    
    func didResolveChallengeURL(_ response: WebChallengeResponse) {
        view?.hideLoading()
        view?.load(url: response.url)
    }
    
    func didFailResolveChallengeURL(error: String) {
        view?.hideLoading()
        view?.showError(message: error)
    }

    func didSyncSolvedSession() {
        view?.hideLoading()
        router.dismissChallenge()
    }

    func didFailSyncSolvedSession(error: String) {
        view?.hideLoading()
        view?.showError(message: error)
    }
}
