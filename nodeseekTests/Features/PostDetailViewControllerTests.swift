//
//  PostDetailViewControllerTests.swift
//  nodeseekTests
//
//  Created by Codex on 2026/4/27.
//

import Foundation
import AsyncDisplayKit
import Testing
import UIKit
@testable import nodeseek

@MainActor
struct PostDetailViewControllerTests {
    @Test func usesTableViewWithPostSummaryHeaderAndCommentCells() throws {
        let post = PostSummary(
            id: "703863",
            title: "列表标题",
            url: URL(string: "https://www.nodeseek.com/post-703863-1")!,
            authorName: "ipv4",
            nodeName: "日常",
            replyCount: 2,
            lastActivityText: "刚刚",
            avatarURL: URL(string: "https://www.nodeseek.com/avatar/34378.png")
        )
        let presenter = SpyPostDetailPresenter()
        let viewController = PostDetailViewController(
            presenter: presenter,
            initialHeader: PostDetailHeaderContent(post: post)
        )

        viewController.loadViewIfNeeded()

        let tableView = try #require(viewController.view.firstSubview(of: UITableView.self))
        #expect(tableView.tableHeaderView != nil)
        #expect(tableView.numberOfRows(inSection: 0) == 0)

        viewController.render(detail: PostDetail(
            id: "703863",
            title: "详情标题",
            authorName: "ipv4",
            avatarURL: URL(string: "https://www.nodeseek.com/avatar/34378.png"),
            metadataText: "36min ago · 日常",
            contentHTML: "<p>正文</p>",
            comments: [
                Comment(id: "1", authorName: "a", avatarURL: nil, floorText: "#1", createdAtText: "1min ago", contentHTML: "<p>评论一</p>"),
                Comment(id: "2", authorName: "b", avatarURL: nil, floorText: "#2", createdAtText: "2min ago", contentHTML: "<p>评论二</p>")
            ],
            replyForm: nil
        ))

        #expect(tableView.numberOfRows(inSection: 0) == 2)
    }

    @Test func addsRefreshButtonAndCanTriggerReload() throws {
        let presenter = SpyPostDetailPresenter()
        let viewController = PostDetailViewController(presenter: presenter)

        viewController.loadViewIfNeeded()

        let items = try #require(viewController.navigationItem.rightBarButtonItems)
        #expect(items.count == 2)
        let refreshButton = try #require(items.first { $0.accessibilityLabel == "刷新" })
        let action = try #require(refreshButton.action)
        _ = (refreshButton.target as AnyObject).perform(action)
        #expect(presenter.loadCount == 2)
    }

    @Test func detailTextureCellsCanBeConstructedOffMainThread() async throws {
        let attributedText = NSAttributedString(string: "正文")
        let header = PostDetailHeaderContent(
            postID: "703863",
            title: "标题",
            authorName: "ipv4",
            avatarURL: URL(string: "https://www.nodeseek.com/avatar/34378.png"),
            metadataText: "刚刚",
            contentHTML: "<p>正文</p>"
        )
        let comment = Comment(
            id: "1",
            authorName: "a",
            avatarURL: URL(string: "https://www.nodeseek.com/avatar/1.png"),
            floorText: "#1",
            createdAtText: "1min ago",
            contentHTML: "<p>评论</p>"
        )

        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                _ = PostBodyCellNode(
                    content: header,
                    attributedContent: attributedText,
                    onImageTapped: { _, _ in },
                    onTextLayoutInvalidated: {}
                ).layoutThatFits(ASSizeRange(
                    min: .zero,
                    max: CGSize(width: 320, height: CGFloat.greatestFiniteMagnitude)
                ))
                _ = CommentCellNode(
                    comment: comment,
                    attributedBody: attributedText,
                    onImageTapped: { _, _ in },
                    onTextLayoutInvalidated: {}
                ).layoutThatFits(ASSizeRange(
                    min: .zero,
                    max: CGSize(width: 320, height: CGFloat.greatestFiniteMagnitude)
                ))
                continuation.resume()
            }
        }
    }
}

private final class SpyPostDetailPresenter: PostDetailPresenterProtocol {
    private(set) var loadCount = 0

    func viewDidLoad() {
        loadCount += 1
    }
}

private extension UIView {
    func firstSubview<T: UIView>(of type: T.Type) -> T? {
        if let matched = self as? T {
            return matched
        }

        for subview in subviews {
            if let matched = subview.firstSubview(of: type) {
                return matched
            }
        }

        return nil
    }
}
