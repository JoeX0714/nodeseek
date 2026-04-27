//
//  ChallengeDetectorTests.swift
//  nodeseekTests
//
//  Created by Codex on 2026/4/27.
//

import Foundation
import Testing
@testable import nodeseek

@MainActor
struct ChallengeDetectorTests {
    @Test func detectsCloudflareChallengeFromRealResponseShape() throws {
        let html = try FixtureLoader.html(named: "cloudflare-challenge")
        let url = URL(string: "https://www.nodeseek.com/")!
        let response = HTMLResponse(
            statusCode: 403,
            headers: [:],
            finalURL: url,
            html: html
        )

        let challenge = ChallengeDetector().detect(response: response)

        #expect(challenge == .cloudflare(url))
    }

    @Test func doesNotTreatNormalCloudflareServerHeaderAsChallenge() throws {
        let html = try FixtureLoader.html(named: "post-list-basic")
        let url = URL(string: "https://www.nodeseek.com/")!
        let response = HTMLResponse(
            statusCode: 200,
            headers: ["Server": "cloudflare"],
            finalURL: url,
            html: html
        )

        let challenge = ChallengeDetector().detect(response: response)

        #expect(challenge == nil)
    }
}
