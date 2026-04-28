//
//  PostListViewControllerTests.swift
//  nodeseekTests
//
//  Created by Codex on 2026/4/28.
//

import Testing
import UIKit
@testable import nodeseek

@MainActor
struct PostListViewControllerTests {
    @Test func sortToggleButtonPeeksFromRightAndExpandsOnTap() throws {
        let presenter = SpyPostListPresenter()
        let viewController = PostListViewController(presenter: presenter)
        viewController.loadViewIfNeeded()
        viewController.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)

        viewController.renderSortMode(.replyTime)
        viewController.view.layoutIfNeeded()

        let button = try #require(viewController.view.firstButton(accessibilityIdentifier: "post-list-sort-toggle"))
        #expect(button.title(for: .normal) == nil)
        #expect(button.image(for: .normal) != nil)
        #expect(button.bounds.height <= 40)
        #expect(button.bounds.width <= 48)
        #expect(button.frame.maxX > viewController.view.bounds.maxX)
        #expect(button.titleLabel?.font.pointSize ?? 99 <= 12)
        #expect(button.titleLabel?.numberOfLines == 1)
        #expect(button.titleLabel?.lineBreakMode == .byTruncatingTail)
        #expect(button.configuration?.titleLineBreakMode == .byTruncatingTail)

        let animationsWereEnabled = UIView.areAnimationsEnabled
        UIView.setAnimationsEnabled(false)
        button.sendActions(for: .touchUpInside)
        viewController.view.layoutIfNeeded()
        UIView.setAnimationsEnabled(animationsWereEnabled)

        #expect(presenter.toggleSortCount == 1)
        #expect(button.title(for: .normal) == "回复优先")
        #expect(button.bounds.width >= 124)
        #expect(button.frame.maxX < viewController.view.bounds.maxX)

        viewController.renderSortMode(.postTime)
        #expect(button.title(for: .normal) == "发帖优先")
    }
}

private final class SpyPostListPresenter: PostListPresenterProtocol {
    private(set) var viewDidLoadCount = 0
    private(set) var toggleSortCount = 0

    func viewDidLoad() {
        viewDidLoadCount += 1
    }

    func didSelectCategory(_ category: PostListCategory) {}

    func didToggleSortMode() {
        toggleSortCount += 1
    }

    func didPullToRefresh() {}

    func didSelectPost(at index: Int) {}

    func didApproachBottom(currentIndex: Int, totalCount: Int) {}
}

private extension UIView {
    func firstButton(accessibilityIdentifier: String) -> UIButton? {
        if let button = self as? UIButton, button.accessibilityIdentifier == accessibilityIdentifier {
            return button
        }

        for subview in subviews {
            if let matched = subview.firstButton(accessibilityIdentifier: accessibilityIdentifier) {
                return matched
            }
        }

        return nil
    }
}
