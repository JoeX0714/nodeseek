//
//  WebChallengePresenterTests.swift
//  nodeseekTests
//
//  Created by Codex on 2026/4/27.
//

import Foundation
import Testing
@testable import nodeseek

@MainActor
struct WebChallengePresenterTests {
    @Test func finishingNonChallengePageSyncsSessionAndDismisses() {
        let interactor = SpyWebChallengeInteractor()
        let router = SpyWebChallengeRouter()
        let view = SpyWebChallengeView()
        let presenter = WebChallengePresenter(interactor: interactor, router: router)
        presenter.setView(view)
        interactor.presenter = presenter

        presenter.webViewDidFinishNavigation(
            pageTitle: "NodeSeek",
            html: "<html><body>NodeSeek 首页</body></html>",
            url: URL(string: "https://www.nodeseek.com/")!
        )

        #expect(interactor.didSyncSolvedSession)
        #expect(router.didDismissChallenge)
        #expect(view.didShowLoading)
        #expect(view.didHideLoading)
    }

    @Test func finishingCloudflareChallengePageWaitsForUser() throws {
        let interactor = SpyWebChallengeInteractor()
        let router = SpyWebChallengeRouter()
        let view = SpyWebChallengeView()
        let presenter = WebChallengePresenter(interactor: interactor, router: router)
        presenter.setView(view)
        interactor.presenter = presenter
        let html = try FixtureLoader.html(named: "cloudflare-challenge")

        presenter.webViewDidFinishNavigation(
            pageTitle: "Just a moment...",
            html: html,
            url: URL(string: "https://www.nodeseek.com/")!
        )

        #expect(!interactor.didSyncSolvedSession)
        #expect(!router.didDismissChallenge)
    }
}

@MainActor
private final class SpyWebChallengeView: WebChallengeViewProtocol {
    var didShowLoading = false
    var didHideLoading = false

    func showLoading() {
        didShowLoading = true
    }

    func hideLoading() {
        didHideLoading = true
    }

    func showError(message: String) {}

    func load(url: URL) {}
}

@MainActor
private final class SpyWebChallengeInteractor: WebChallengeInteractorInput {
    weak var presenter: WebChallengeInteractorOutput?
    var didSyncSolvedSession = false

    func resolveChallengeURL() {}

    func syncSolvedSession() {
        didSyncSolvedSession = true
        presenter?.didSyncSolvedSession()
    }
}

@MainActor
private final class SpyWebChallengeRouter: WebChallengeRouterProtocol {
    var didDismissChallenge = false

    func dismissChallenge() {
        didDismissChallenge = true
    }
}
