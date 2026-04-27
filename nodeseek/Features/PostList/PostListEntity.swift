//
//  PostListEntity.swift
//  nodeseek
//
//  Created by Codex on 2026/4/27.
//

import Foundation

struct PostListRequest {
    let page: Int
}

struct PostListResponse {
    let posts: [PostSummary]
}
