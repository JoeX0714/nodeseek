//
//  ReplyComposerRouter.swift
//  nodeseek
//
//  Created by Codex on 2026/4/27.
//

import Foundation
import UIKit

class ReplyComposerRouter: ReplyComposerRouterProtocol {
    
    // MARK: - Properties
    weak var viewController: UIViewController?
    
    // MARK: - Static Methods
    static func createModule() -> UIViewController {
        let router = ReplyComposerRouter()
        let interactor = ReplyComposerInteractor()
        let presenter = ReplyComposerPresenter(
            interactor: interactor,
            router: router
        )
        
        interactor.presenter = presenter
        
        let view = ReplyComposerViewController(presenter: presenter)
        
        presenter.setView(view)
        router.viewController = view
        
        return view
    }
}
