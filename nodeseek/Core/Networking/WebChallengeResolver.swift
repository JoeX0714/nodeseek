//
//  WebChallengeResolver.swift
//  nodeseek
//
//  Created by Codex on 2026/4/27.
//

import Foundation

@MainActor
final class WebChallengeResolver {

    private let cookieBridge: CookieBridge

    init() {
        self.cookieBridge = CookieBridge()
    }

    init(cookieBridge: CookieBridge) {
        self.cookieBridge = cookieBridge
    }

    func syncBeforeWebFlow() async {
        await cookieBridge.syncURLSessionCookiesToWebView()
    }

    func syncAfterWebFlow() async {
        await cookieBridge.syncWebViewCookiesToURLSession()
    }
}
