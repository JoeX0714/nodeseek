//
//  VisitedPostStore.swift
//  nodeseek
//
//  Created by Codex on 2026/5/1.
//

import Foundation

struct VisitedPostRecord: Equatable, Sendable {
    let postID: String
    let title: String
    let url: URL
    let visitedAt: Date
}

struct PostListItem: Equatable, Sendable {
    let post: PostSummary
    let isVisited: Bool
}

protocol VisitedPostStoreProtocol: AnyObject {
    func isVisited(postID: String) -> Bool
    func markVisited(post: PostSummary, visitedAt: Date)
    func recentRecords(limit: Int) -> [VisitedPostRecord]
}

final class EmptyVisitedPostStore: VisitedPostStoreProtocol {
    func isVisited(postID: String) -> Bool {
        false
    }

    func markVisited(post: PostSummary, visitedAt: Date) {
    }

    func recentRecords(limit: Int) -> [VisitedPostRecord] {
        []
    }
}
