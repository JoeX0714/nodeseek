//
//  ReplyComposerContract.swift
//  nodeseek
//
//  Created by Codex on 2026/4/27.
//

import Foundation
import UIKit

// MARK: - View Protocol (Presenter -> View)
protocol ReplyComposerViewProtocol: AnyObject {
    func showLoading()
    func hideLoading()
    func showError(message: String)
    func showPlaceholder(_ text: String)
}

// MARK: - Presenter Protocol (View -> Presenter)
protocol ReplyComposerPresenterProtocol: AnyObject {
    func viewDidLoad()
}

// MARK: - Interactor Input (Presenter -> Interactor)
protocol ReplyComposerInteractorInput: AnyObject {
    func prepareReply()
}

// MARK: - Interactor Output (Interactor -> Presenter)
protocol ReplyComposerInteractorOutput: AnyObject {
    func didPrepareReply(_ response: ReplyComposerResponse)
    func didFailPrepareReply(error: String)
}

// MARK: - Router Protocol (Presenter -> Router)
protocol ReplyComposerRouterProtocol: AnyObject {
}
