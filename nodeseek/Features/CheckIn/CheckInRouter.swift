//
//  CheckInRouter.swift
//  nodeseek
//
//  Created by Codex on 2026/4/27.
//

import Foundation
import UIKit

class CheckInRouter: CheckInRouterProtocol {
    
    // MARK: - Properties
    weak var viewController: UIViewController?
    
    // MARK: - Static Methods
    static func createModule() -> UIViewController {
        let router = CheckInRouter()
        let interactor = CheckInInteractor()
        let presenter = CheckInPresenter(
            interactor: interactor,
            router: router
        )
        
        interactor.presenter = presenter
        
        let view = CheckInViewController(presenter: presenter)
        
        presenter.setView(view)
        router.viewController = view
        
        return view
    }
}
