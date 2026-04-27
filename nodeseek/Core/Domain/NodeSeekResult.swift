//
//  NodeSeekResult.swift
//  nodeseek
//
//  Created by Codex on 2026/4/27.
//

import Foundation

enum ChallengeKind: Equatable, Sendable {
    case loginRequired(URL)
    case cloudflare(URL)
    case blocked(URL)
    case unsupported(URL)
}

enum NodeSeekResult<Value: Sendable>: Sendable {
    case value(Value)
    case challenge(ChallengeKind)
}
