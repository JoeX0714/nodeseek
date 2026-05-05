//
//  PostDetailPresenter.swift
//  nodeseek
//
//  Created by Codex on 2026/4/27.
//

import Foundation

class PostDetailPresenter: PostDetailPresenterProtocol {
    private enum ReactionKind {
        case like
        case oppose

        var successToast: String {
            switch self {
            case .like:
                return "已点赞"
            case .oppose:
                return "已反对"
            }
        }

        var pendingToast: String {
            switch self {
            case .like:
                return "正在点赞"
            case .oppose:
                return "正在反对"
            }
        }

        var alreadyActionSuffix: String {
            switch self {
            case .like:
                return "已点赞"
            case .oppose:
                return "已反对"
            }
        }

        var postAlreadyToast: String {
            "该帖子\(alreadyActionSuffix)"
        }

        var commentAlreadyToast: String {
            "该评论\(alreadyActionSuffix)"
        }
    }
    
    // MARK: - Properties
    private weak var view: PostDetailViewProtocol?
    private let interactor: PostDetailInteractorInput
    private let router: PostDetailRouterProtocol
    private let visitedStore: VisitedPostStoreProtocol
    private var currentPage: Int
    private var loadingPage: Int?
    private var currentDetail: PostDetail?
    private var fallbackFavoriteCollectedState = false
    private var isSubmittingReply = false
    private var isSubmittingFavorite = false
    private var isSubmittingPostLike = false
    private var isSubmittingPostOppose = false
    private var submittingCommentLikeIDs = Set<String>()
    private var submittingCommentOpposeIDs = Set<String>()
    private var favoriteRollbackDetail: PostDetail?
    private var favoriteRollbackCollectedState: Bool?
    private var isRefreshingAfterReplySubmission = false
    
    // MARK: - Initialization
    init(
        interactor: PostDetailInteractorInput,
        router: PostDetailRouterProtocol,
        initialPage: Int = 1,
        visitedStore: VisitedPostStoreProtocol = EmptyVisitedPostStore()
    ) {
        self.interactor = interactor
        self.router = router
        self.visitedStore = visitedStore
        self.currentPage = max(1, initialPage)
    }
    
    // MARK: - Setup
    func setView(_ view: PostDetailViewProtocol) {
        self.view = view
    }
    
    // MARK: - Methods
    func viewDidLoad() {
        view?.showLoading()
        interactor.loadPostDetail(page: currentPage)
    }

    func didTapLogin() {
        router.navigateToLogin { [weak self] in
            self?.view?.showLoading()
            guard let self else { return }
            self.interactor.loadPostDetail(page: self.currentPage)
        }
    }

    func didSelectPage(_ page: Int) {
        let normalizedPage = max(1, page)
        guard normalizedPage != currentPage else { return }
        guard normalizedPage != loadingPage else { return }
        loadingPage = normalizedPage
        view?.showPageLoading()
        interactor.loadPostDetail(page: normalizedPage)
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

    func didTapFavorite() {
        guard isSubmittingFavorite == false else { return }
        isSubmittingFavorite = true
        view?.setFavoriteSubmitting(true)
        let isCollecting = currentFavoriteCollectedState == false
        favoriteRollbackDetail = currentDetail
        favoriteRollbackCollectedState = currentFavoriteCollectedState
        applyOptimisticFavoriteState(isCollected: isCollecting)
        if isCollecting {
            interactor.addFavorite()
        } else {
            interactor.removeFavorite()
        }
    }

    func didTapCommentLike(_ comment: Comment) {
        guard comment.isLikeClicked == false else {
            view?.showToast(message: ReactionKind.like.commentAlreadyToast)
            return
        }
        guard submittingCommentLikeIDs.contains(comment.id) == false else { return }
        submittingCommentLikeIDs.insert(comment.id)
        view?.showToast(message: ReactionKind.like.pendingToast)
        interactor.addCommentLike(commentID: comment.id)
    }

    func didTapCommentOppose(_ comment: Comment) {
        guard comment.isOpposeClicked == false else {
            view?.showToast(message: ReactionKind.oppose.commentAlreadyToast)
            return
        }
        guard submittingCommentOpposeIDs.contains(comment.id) == false else { return }
        submittingCommentOpposeIDs.insert(comment.id)
        view?.showToast(message: ReactionKind.oppose.pendingToast)
        interactor.addCommentOppose(commentID: comment.id)
    }

    func didTapPostLike() {
        guard currentDetail?.isLikeClicked != true else {
            view?.showToast(message: ReactionKind.like.postAlreadyToast)
            return
        }
        guard isSubmittingPostLike == false else { return }
        isSubmittingPostLike = true
        view?.showToast(message: ReactionKind.like.pendingToast)
        interactor.addPostLike()
    }

    func didTapPostOppose() {
        guard currentDetail?.isOpposeClicked != true else {
            view?.showToast(message: ReactionKind.oppose.postAlreadyToast)
            return
        }
        guard isSubmittingPostOppose == false else { return }
        isSubmittingPostOppose = true
        view?.showToast(message: ReactionKind.oppose.pendingToast)
        interactor.addPostOppose()
    }

    private var currentFavoriteCollectedState: Bool {
        currentDetail?.isFavoriteCollected ?? fallbackFavoriteCollectedState
    }

    private func markDetailVisited(_ detail: PostDetail) {
        let page = max(1, detail.page)
        let url = NodeSeekSite.postURL(id: detail.id, page: page)

        let post = PostSummary(
            id: detail.id,
            title: detail.title,
            url: url,
            authorName: detail.authorName,
            nodeName: nil,
            replyCount: detail.comments.count,
            viewCount: 0,
            lastActivityText: detail.metadataText,
            avatarURL: detail.avatarURL
        )
        visitedStore.markVisited(post: post, visitedAt: Date())
    }

    private func applyFavoriteState(isCollected: Bool, response: PostCollectionResponse) {
        fallbackFavoriteCollectedState = isCollected
        guard let currentDetail else { return }
        let nextDetail = currentDetail.updatingFavoriteState(
            count: response.postCollectionCount ?? currentDetail.favoriteCount,
            isCollected: isCollected
        )

        guard nextDetail != currentDetail else { return }
        self.currentDetail = nextDetail
        view?.updatePostBody(detail: nextDetail)
    }

    private func applyOptimisticFavoriteState(isCollected: Bool) {
        fallbackFavoriteCollectedState = isCollected
        guard let currentDetail else { return }
        let baseCount = currentDetail.favoriteCount ?? 0
        let optimisticCount = isCollected ? baseCount + 1 : max(0, baseCount - 1)
        let nextDetail = currentDetail.updatingFavoriteState(
            count: optimisticCount,
            isCollected: isCollected
        )
        guard nextDetail != currentDetail else { return }
        self.currentDetail = nextDetail
        view?.updatePostBody(detail: nextDetail)
    }

    private func restoreFavoriteStateFromRollback() {
        if let rollbackCollectedState = favoriteRollbackCollectedState {
            fallbackFavoriteCollectedState = rollbackCollectedState
        }
        guard let rollback = favoriteRollbackDetail else { return }
        guard currentDetail != rollback else { return }
        currentDetail = rollback
        view?.updatePostBody(detail: rollback)
    }

    private func normalizedReactionToast(message: String?, kind: ReactionKind) -> String {
        let trimmed = message?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmed, trimmed.isEmpty == false, trimmed != "added" else {
            return kind.successToast
        }
        return trimmed
    }

    private func reactionNextCount(current: Int?, serverCount: Int?) -> Int {
        serverCount ?? max(1, (current ?? 0) + 1)
    }

    private func applyPostReactionSuccess(response: CommentUpvoteResponse, kind: ReactionKind) {
        if let currentDetail {
            let currentCount: Int?
            let nextDetail: PostDetail
            switch kind {
            case .like:
                currentCount = currentDetail.likeCount
                nextDetail = currentDetail.updatingPostLikeState(
                    count: reactionNextCount(current: currentCount, serverCount: response.current),
                    isClicked: true
                )
            case .oppose:
                currentCount = currentDetail.opposeCount
                nextDetail = currentDetail.updatingPostOpposeState(
                    count: reactionNextCount(current: currentCount, serverCount: response.current),
                    isClicked: true
                )
            }
            self.currentDetail = nextDetail
            view?.updatePostBody(detail: nextDetail)
        }
        view?.showToast(message: normalizedReactionToast(message: response.message, kind: kind))
    }

    private func applyCommentReactionSuccess(
        commentID: String,
        response: CommentUpvoteResponse,
        kind: ReactionKind
    ) {
        if let currentDetail,
           let comment = currentDetail.comments.first(where: { $0.id == commentID }) {
            let currentCount: Int?
            let nextDetail: PostDetail
            let nextCount: Int
            switch kind {
            case .like:
                currentCount = comment.likeCount
                nextCount = reactionNextCount(current: currentCount, serverCount: response.current)
                nextDetail = currentDetail.updatingCommentLikeState(
                    commentID: commentID,
                    count: nextCount,
                    isClicked: true
                )
                view?.updateCommentLike(commentID: commentID, count: nextCount, isClicked: true)
            case .oppose:
                currentCount = comment.opposeCount
                nextCount = reactionNextCount(current: currentCount, serverCount: response.current)
                nextDetail = currentDetail.updatingCommentOpposeState(
                    commentID: commentID,
                    count: nextCount,
                    isClicked: true
                )
                view?.updateCommentOppose(commentID: commentID, count: nextCount, isClicked: true)
            }
            self.currentDetail = nextDetail
        }
        view?.showToast(message: normalizedReactionToast(message: response.message, kind: kind))
    }

    private func handleReactionFailure(error: String, kind: ReactionKind) {
        if error.contains(kind.alreadyActionSuffix) {
            view?.showToast(message: error)
            return
        }
        view?.showError(message: error)
    }
}

// MARK: - Interactor Output
extension PostDetailPresenter: PostDetailInteractorOutput {
    
    func didLoadPostDetail(_ response: PostDetailResponse) {
        loadingPage = nil
        isRefreshingAfterReplySubmission = false
        favoriteRollbackDetail = nil
        favoriteRollbackCollectedState = nil
        currentPage = max(1, response.detail.page)
        currentDetail = response.detail
        fallbackFavoriteCollectedState = response.detail.isFavoriteCollected
        markDetailVisited(response.detail)
        view?.hideLoading()
        view?.render(detail: response.detail)
    }

    func didRequireLogin(message: String) {
        loadingPage = nil
        isRefreshingAfterReplySubmission = false
        view?.hideLoading()
        view?.renderLoginRequired(message: message)
    }
    
    func didFailLoadPostDetail(error: String) {
        let isReplyRefresh = isRefreshingAfterReplySubmission
        loadingPage = nil
        isRefreshingAfterReplySubmission = false
        view?.hideLoading()
        if isReplyRefresh == false {
            view?.showError(message: error)
        }
    }

    func didCancelLoadPostDetail() {
        loadingPage = nil
        isRefreshingAfterReplySubmission = false
        view?.hideLoading()
    }

    func didSubmitReply(_ response: PostDetailSubmitReplyResponse) {
        isSubmittingReply = false
        view?.setReplySubmitting(false)
        view?.finishReplySubmission()

        let responseMessage = response.message?.trimmingCharacters(in: .whitespacesAndNewlines)
        if currentDetail?.isLastPage == true {
            let toastMessage: String
            if let responseMessage, responseMessage.isEmpty == false {
                toastMessage = responseMessage
            } else {
                toastMessage = "评论已发布"
            }
            view?.showToast(message: toastMessage)
            isRefreshingAfterReplySubmission = true
            interactor.loadPostDetail(page: currentPage)
        } else {
            view?.showToast(message: "评论已发布，可到最后一页查看")
        }
    }

    func didFailSubmitReply(error: String) {
        isSubmittingReply = false
        view?.setReplySubmitting(false)
        view?.showError(message: error)
    }

    func didAddFavorite(_ response: PostCollectionResponse) {
        isSubmittingFavorite = false
        applyFavoriteState(isCollected: true, response: response)
        favoriteRollbackDetail = nil
        favoriteRollbackCollectedState = nil
        view?.setFavoriteSubmitting(false)
        view?.showToast(message: "已收藏")
    }

    func didFailAddFavorite(error: String) {
        isSubmittingFavorite = false
        restoreFavoriteStateFromRollback()
        favoriteRollbackDetail = nil
        favoriteRollbackCollectedState = nil
        view?.setFavoriteSubmitting(false)
        view?.showError(message: error)
    }

    func didRemoveFavorite(_ response: PostCollectionResponse) {
        isSubmittingFavorite = false
        applyFavoriteState(isCollected: false, response: response)
        favoriteRollbackDetail = nil
        favoriteRollbackCollectedState = nil
        view?.setFavoriteSubmitting(false)
        view?.showToast(message: "已取消收藏")
    }

    func didFailRemoveFavorite(error: String) {
        isSubmittingFavorite = false
        restoreFavoriteStateFromRollback()
        favoriteRollbackDetail = nil
        favoriteRollbackCollectedState = nil
        view?.setFavoriteSubmitting(false)
        view?.showError(message: error)
    }

    func didAddPostLike(_ response: PostUpvoteResponse) {
        isSubmittingPostLike = false
        applyPostReactionSuccess(response: response, kind: .like)
    }

    func didFailAddPostLike(error: String) {
        isSubmittingPostLike = false
        handleReactionFailure(error: error, kind: .like)
    }

    func didAddCommentLike(commentID: String, response: CommentUpvoteResponse) {
        submittingCommentLikeIDs.remove(commentID)
        applyCommentReactionSuccess(commentID: commentID, response: response, kind: .like)
    }

    func didFailAddCommentLike(commentID: String, error: String) {
        submittingCommentLikeIDs.remove(commentID)
        handleReactionFailure(error: error, kind: .like)
    }

    func didAddPostOppose(_ response: PostDislikeResponse) {
        isSubmittingPostOppose = false
        applyPostReactionSuccess(response: response, kind: .oppose)
    }

    func didFailAddPostOppose(error: String) {
        isSubmittingPostOppose = false
        handleReactionFailure(error: error, kind: .oppose)
    }

    func didAddCommentOppose(commentID: String, response: CommentDislikeResponse) {
        submittingCommentOpposeIDs.remove(commentID)
        applyCommentReactionSuccess(commentID: commentID, response: response, kind: .oppose)
    }

    func didFailAddCommentOppose(commentID: String, error: String) {
        submittingCommentOpposeIDs.remove(commentID)
        handleReactionFailure(error: error, kind: .oppose)
    }
}
