//
//  CookieSharedWebViewControllerTests.swift
//  nodeseekTests
//

import Foundation
import Testing
import UIKit
@testable import nodeseek

@MainActor
struct CookieSharedWebViewControllerTests {
    @Test func moreMenuIncludesWebRefreshAction() throws {
        let url = try #require(URL(string: "https://www.nodeseek.com/post-1-1"))
        let viewController = CookieSharedWebViewController(url: url, automaticallyLoadsPage: false)

        viewController.loadViewIfNeeded()

        let moreButton = try #require(viewController.navigationItem.rightBarButtonItem)
        _ = try #require(moreButton.menu?.children.first { $0.title == "刷新" } as? UIAction)
    }
}
