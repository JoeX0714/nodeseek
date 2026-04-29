//
//  AccountViewControllerTests.swift
//  nodeseekTests
//

import Testing
import UIKit
@testable import nodeseek

@MainActor
struct AccountViewControllerTests {
    @Test func loginButtonHiddenBeforeAccountStateLoads() throws {
        let presenter = SpyAccountPresenter()
        let viewController = AccountViewController(presenter: presenter)

        viewController.loadViewIfNeeded()

        let button = try #require(viewController.view.firstButton(accessibilityIdentifier: "account-login-button"))
        #expect(button.isHidden)
    }

    @Test func showsLoginButtonAndSendsTapToPresenter() throws {
        let presenter = SpyAccountPresenter()
        let viewController = AccountViewController(presenter: presenter)

        viewController.loadViewIfNeeded()
        viewController.render(displayName: "游客", isLoggedIn: false)

        let button = try #require(viewController.view.firstButton(accessibilityIdentifier: "account-login-button"))
        #expect(button.configuration?.title == "登录")

        button.sendActions(for: .touchUpInside)

        #expect(presenter.didTapLoginCount == 1)
    }

    @Test func renderLoggedInHidesLoginButton() throws {
        let presenter = SpyAccountPresenter()
        let viewController = AccountViewController(presenter: presenter)

        viewController.loadViewIfNeeded()
        viewController.render(displayName: "mistj", isLoggedIn: true)

        let button = try #require(viewController.view.firstButton(accessibilityIdentifier: "account-login-button"))
        #expect(button.isHidden)
    }
}

private final class SpyAccountPresenter: AccountPresenterProtocol {
    private(set) var viewDidLoadCount = 0
    private(set) var didTapLoginCount = 0

    func viewDidLoad() {
        viewDidLoadCount += 1
    }

    func didTapLogin() {
        didTapLoginCount += 1
    }
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
