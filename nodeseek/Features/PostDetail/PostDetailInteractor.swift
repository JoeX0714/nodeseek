//
//  PostDetailInteractor.swift
//  nodeseek
//
//  Created by Codex on 2026/4/27.
//

import Foundation

class PostDetailInteractor: PostDetailInteractorInput {
    
    // MARK: - Properties
    weak var presenter: PostDetailInteractorOutput?
    private let post: PostSummary?
    
    // MARK: - Initialization
    init(post: PostSummary? = nil) {
        self.post = post
    }
    
    // MARK: - Methods
    func loadPostDetail() {
        let title = post?.title ?? "帖子详情"
        let author = post?.authorName ?? "NodeSeek"
        let nodeName = post?.nodeName ?? "默认节点"
        let subtitle = "\(author) · \(nodeName)"
        presenter?.didLoadPostDetail(PostDetailResponse(title: title, subtitle: subtitle))
    }
}
