//
//  WebChallengeInteractor.swift
//  nodeseek
//
//  Created by Codex on 2026/4/27.
//

import Foundation

class WebChallengeInteractor: WebChallengeInteractorInput {
    
    // MARK: - Properties
    weak var presenter: WebChallengeInteractorOutput?
    private let url: URL
    private let resolver: WebChallengeResolver
    
    // MARK: - Initialization
    init(
        url: URL = URL(string: "https://www.nodeseek.com")!,
        resolver: WebChallengeResolver? = nil
    ) {
        self.url = url
        self.resolver = resolver ?? WebChallengeResolver()
    }
    
    // MARK: - Methods
    func resolveChallengeURL() {
        Task { @MainActor in
            await resolver.syncBeforeWebFlow()
            presenter?.didResolveChallengeURL(WebChallengeResponse(url: url))
        }
    }

    func syncSolvedSession() {
        Task { @MainActor in
            await resolver.syncAfterWebFlow()
            presenter?.didSyncSolvedSession()
        }
    }
}
