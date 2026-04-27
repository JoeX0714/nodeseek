//
//  WebChallengeContract.swift
//  nodeseek
//
//  Created by Codex on 2026/4/27.
//

import Foundation
import UIKit

// MARK: - View Protocol (Presenter -> View)
protocol WebChallengeViewProtocol: AnyObject {
    func showLoading()
    func hideLoading()
    func showError(message: String)
    func load(url: URL)
}

// MARK: - Presenter Protocol (View -> Presenter)
protocol WebChallengePresenterProtocol: AnyObject {
    func viewDidLoad()
    func webViewDidFinishNavigation(pageTitle: String?, html: String, url: URL?)
    func didTapDone()
}

// MARK: - Interactor Input (Presenter -> Interactor)
protocol WebChallengeInteractorInput: AnyObject {
    func resolveChallengeURL()
    func syncSolvedSession()
}

// MARK: - Interactor Output (Interactor -> Presenter)
protocol WebChallengeInteractorOutput: AnyObject {
    func didResolveChallengeURL(_ response: WebChallengeResponse)
    func didFailResolveChallengeURL(error: String)
    func didSyncSolvedSession()
    func didFailSyncSolvedSession(error: String)
}

// MARK: - Router Protocol (Presenter -> Router)
protocol WebChallengeRouterProtocol: AnyObject {
    func dismissChallenge()
}
