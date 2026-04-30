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
        let presenter = PostDetailPresenter(interactor: interactor, router: router)

        presenter.didTapLogin()

        #expect(router.navigateToLoginCount == 1)
        #expect(interactor.loadPostDetailCount == 0)

        router.capturedOnClose?()

        #expect(interactor.loadPostDetailCount == 1)
    }

    @Test func sendReplySubmitsTrimmedContentAndDisablesSubmittingState() {
        let interactor = SpyPostDetailInteractor()
        let router = SpyPostDetailRouter()
        let view = SpyPostDetailView()
        let presenter = PostDetailPresenter(interactor: interactor, router: router)
        presenter.setView(view)

        presenter.didTapSendReply(content: "  测试回复  ")

        #expect(interactor.submittedReplyContent == "测试回复")
        #expect(view.submittingStates == [true])
    }

    @Test func sendReplySuccessReloadsWhenCurrentDetailIsLastPage() {
        let interactor = SpyPostDetailInteractor()
        let router = SpyPostDetailRouter()
        let view = SpyPostDetailView()
        let presenter = PostDetailPresenter(interactor: interactor, router: router)
        presenter.setView(view)
        presenter.didLoadPostDetail(PostDetailResponse(detail: PostDetail(
            id: "706958",
            title: "标题",
            authorName: "mist",
            avatarURL: nil,
            metadataText: nil,
            contentHTML: "<p>正文</p>",
            comments: [],
            isLastPage: true
        )))

        presenter.didTapSendReply(content: "测试回复")
        presenter.didSubmitReply(PostDetailSubmitReplyResponse(message: "已发布"))

        #expect(interactor.loadPostDetailCount == 1)
        #expect(view.finishReplySubmissionCount == 1)
        #expect(view.submittingStates == [true, false])
        #expect(view.toasts == ["已发布"])
    }

    @Test func sendReplySuccessShowsDefaultToastWhenLastPageResponseHasNoMessage() {
        let interactor = SpyPostDetailInteractor()
        let router = SpyPostDetailRouter()
        let view = SpyPostDetailView()
        let presenter = PostDetailPresenter(interactor: interactor, router: router)
        presenter.setView(view)
        presenter.didLoadPostDetail(PostDetailResponse(detail: PostDetail(
            id: "706958",
            title: "标题",
            authorName: "mist",
            avatarURL: nil,
            metadataText: nil,
            contentHTML: "<p>正文</p>",
            comments: [],
            isLastPage: true
        )))

        presenter.didTapSendReply(content: "测试回复")
        presenter.didSubmitReply(PostDetailSubmitReplyResponse(message: nil))

        #expect(interactor.loadPostDetailCount == 1)
        #expect(view.toasts == ["评论已发布"])
    }

    @Test func sendReplySuccessShowsLastPageHintWhenCurrentDetailIsNotLastPage() {
        let interactor = SpyPostDetailInteractor()
        let router = SpyPostDetailRouter()
        let view = SpyPostDetailView()
        let presenter = PostDetailPresenter(interactor: interactor, router: router)
        presenter.setView(view)
        presenter.didLoadPostDetail(PostDetailResponse(detail: PostDetail(
            id: "706958",
            title: "标题",
            authorName: "mist",
            avatarURL: nil,
            metadataText: nil,
            contentHTML: "<p>正文</p>",
            comments: [],
            isLastPage: false
        )))

        presenter.didTapSendReply(content: "测试回复")
        presenter.didSubmitReply(PostDetailSubmitReplyResponse(message: "已发布"))

        #expect(interactor.loadPostDetailCount == 0)
        #expect(view.finishReplySubmissionCount == 1)
        #expect(view.toasts == ["评论已发布，可到最后一页查看"])
    }

    @Test func emptyReplyShowsErrorWithoutSubmitting() {
        let interactor = SpyPostDetailInteractor()
        let router = SpyPostDetailRouter()
        let view = SpyPostDetailView()
        let presenter = PostDetailPresenter(interactor: interactor, router: router)
        presenter.setView(view)

        presenter.didTapSendReply(content: " \n ")

        #expect(interactor.submittedReplyContent == nil)
        #expect(view.errors == ["回复内容不能为空。"])
    }

    @Test func duplicateSendReplyTapIsIgnoredWhileSubmitting() {
        let interactor = SpyPostDetailInteractor()
        let router = SpyPostDetailRouter()
        let view = SpyPostDetailView()
        let presenter = PostDetailPresenter(interactor: interactor, router: router)
        presenter.setView(view)

        presenter.didTapSendReply(content: "第一条")
        presenter.didTapSendReply(content: "第二条")

        #expect(interactor.submittedReplyContents == ["第一条"])
    }
}

private final class SpyPostDetailInteractor: PostDetailInteractorInput {
    private(set) var loadPostDetailCount = 0
    private(set) var submittedReplyContent: String?
    private(set) var submittedReplyContents: [String] = []

    func loadPostDetail() {
        loadPostDetailCount += 1
    }

    func submitReply(content: String) {
        submittedReplyContent = content
        submittedReplyContents.append(content)
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
    private(set) var submittingStates: [Bool] = []
    private(set) var errors: [String] = []
    private(set) var toasts: [String] = []
    private(set) var finishReplySubmissionCount = 0

    func showLoading() {}
    func hideLoading() {}

    func showError(message: String) {
        errors.append(message)
    }

    func showToast(message: String) {
        toasts.append(message)
    }

    func setReplySubmitting(_ isSubmitting: Bool) {
        submittingStates.append(isSubmitting)
    }

    func finishReplySubmission() {
        finishReplySubmissionCount += 1
    }
    func render(detail: PostDetail) {}
    func renderLoginRequired(message: String) {}
}
