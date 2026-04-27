//
//  ReplyComposerInteractor.swift
//  nodeseek
//
//  Created by Codex on 2026/4/27.
//

import Foundation

class ReplyComposerInteractor: ReplyComposerInteractorInput {
    
    // MARK: - Properties
    weak var presenter: ReplyComposerInteractorOutput?
    
    // MARK: - Initialization
    init() {}
    
    // MARK: - Methods
    func prepareReply() {
        presenter?.didPrepareReply(ReplyComposerResponse(placeholder: "写下你的回复..."))
    }
}
