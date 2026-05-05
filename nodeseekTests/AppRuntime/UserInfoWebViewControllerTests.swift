//
//  UserInfoWebViewControllerTests.swift
//  nodeseekTests
//

import Testing
import Foundation
import UIKit
@testable import nodeseek

@MainActor
struct UserInfoWebViewControllerTests {
    @Test func normalizesSpaceURLToGeneralTab() throws {
        let url = try #require(URL(string: "https://www.nodeseek.com/space/1541"))

        let normalizedURL = UserInfoWebViewController.normalizedProfileURL(url)

        #expect(normalizedURL.absoluteString == "https://www.nodeseek.com/space/1541#/general")
    }

    @Test func preservesExistingGeneralFragment() throws {
        let url = try #require(URL(string: "https://www.nodeseek.com/space/1541#/general"))

        let normalizedURL = UserInfoWebViewController.normalizedProfileURL(url)

        #expect(normalizedURL.absoluteString == "https://www.nodeseek.com/space/1541#/general")
    }

    @Test func normalizesRelativeSpaceURLToAbsoluteGeneralTab() throws {
        let url = try #require(URL(string: "/space/1541"))

        let normalizedURL = UserInfoWebViewController.normalizedProfileURL(url)

        #expect(normalizedURL.absoluteString == "https://www.nodeseek.com/space/1541#/general")
    }

    @Test func moreMenuIncludesWebRefreshAction() throws {
        let url = try #require(URL(string: "https://www.nodeseek.com/space/1541"))
        let viewController = UserInfoWebViewController(profileURL: url, automaticallyLoadsPage: false)

        viewController.loadViewIfNeeded()

        let moreButton = try #require(viewController.navigationItem.rightBarButtonItem)
        _ = try #require(moreButton.menu?.children.first { $0.title == "刷新" } as? UIAction)
    }
}
