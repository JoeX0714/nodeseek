//
//  PostDetailPresenterTests.swift
//  nodeseekTests
//

import Testing
@testable import nodeseek

@MainActor
struct PostDetailPresenterTests {
    @Test func loginCloseReloadsPostDetail() {
        let interactor = SpyPostDetailInteractor()
        let router = SpyPostDetailRouter()
        let presenter = PostDetailPresenter(interactor: interactor, router: router, initialPage: 3)

        presenter.didTapLogin()

        #expect(router.navigateToLoginCount == 1)
        #expect(interactor.loadedPages.isEmpty)

        router.capturedOnClose?()

        #expect(interactor.loadedPages == [3])
    }

    @Test func selectingOtherPageReloadsThatPage() {
        let interactor = SpyPostDetailInteractor()
        let router = SpyPostDetailRouter()
        let view = SpyPostDetailView()
        let presenter = PostDetailPresenter(interactor: interactor, router: router, initialPage: 1)
        presenter.setView(view)

        presenter.didSelectPage(2)

        #expect(interactor.loadedPages == [2])
        #expect(view.pageLoadingCount == 1)
        #expect(view.loadingCount == 0)
    }

    @Test func selectingCurrentPageDoesNotReload() {
        let interactor = SpyPostDetailInteractor()
        let router = SpyPostDetailRouter()
        let presenter = PostDetailPresenter(interactor: interactor, router: router, initialPage: 2)

        presenter.didSelectPage(2)

        #expect(interactor.loadedPages.isEmpty)
    }

    @Test func selectingPageInFlightDoesNotDuplicateRequest() {
        let interactor = SpyPostDetailInteractor()
        let router = SpyPostDetailRouter()
        let presenter = PostDetailPresenter(interactor: interactor, router: router, initialPage: 1)

        presenter.didSelectPage(2)
        presenter.didSelectPage(2)

        #expect(interactor.loadedPages == [2])
    }

    @Test func selectingFailedPageCanRetry() {
        let interactor = SpyPostDetailInteractor()
        let router = SpyPostDetailRouter()
        let presenter = PostDetailPresenter(interactor: interactor, router: router, initialPage: 1)

        presenter.didSelectPage(2)
        presenter.didFailLoadPostDetail(error: "网络错误")
        presenter.didSelectPage(2)

        #expect(interactor.loadedPages == [2, 2])
    }
}

private final class SpyPostDetailInteractor: PostDetailInteractorInput {
    private(set) var loadedPages: [Int] = []

    func loadPostDetail() {
        loadPostDetail(page: 1)
    }

    func loadPostDetail(page: Int) {
        loadedPages.append(page)
    }
}

private final class SpyPostDetailRouter: PostDetailRouterProtocol {
    private(set) var navigateToLoginCount = 0
    private(set) var capturedOnClose: (@MainActor () -> Void)?

    func navigateToLogin(onClose: @escaping @MainActor () -> Void) {
        navigateToLoginCount += 1
        capturedOnClose = onClose
    }
}

private final class SpyPostDetailView: PostDetailViewProtocol {
    private(set) var loadingCount = 0
    private(set) var pageLoadingCount = 0

    func showLoading() {
        loadingCount += 1
    }

    func showPageLoading() {
        pageLoadingCount += 1
    }

    func hideLoading() {}

    func showError(message: String) {}

    func render(detail: PostDetail) {}

    func renderLoginRequired(message: String) {}
}
