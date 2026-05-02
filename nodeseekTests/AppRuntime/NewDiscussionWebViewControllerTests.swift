//
//  NewDiscussionWebViewControllerTests.swift
//  nodeseekTests
//

import Foundation
import Testing
@testable import nodeseek

@MainActor
struct NewDiscussionWebViewControllerTests {
    @Test func usesDedicatedNewDiscussionURL() {
        #expect(NewDiscussionWebViewController.newDiscussionURL.absoluteString == "https://www.nodeseek.com/new-discussion")
    }
}
