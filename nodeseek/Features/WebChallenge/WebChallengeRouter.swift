//
//  WebChallengeRouter.swift
//  nodeseek
//
//  Created by Codex on 2026/4/27.
//

import Foundation
import UIKit

class WebChallengeRouter: WebChallengeRouterProtocol {
    
    // MARK: - Properties
    weak var viewController: UIViewController?
    private let onResolved: (@MainActor () -> Void)?

    init(onResolved: (@MainActor () -> Void)? = nil) {
        self.onResolved = onResolved
    }
    
    // MARK: - Static Methods
    static func createModule(
        url: URL = URL(string: "https://www.nodeseek.com")!,
        onResolved: (@MainActor () -> Void)? = nil
    ) -> UIViewController {
        let router = WebChallengeRouter(onResolved: onResolved)
        let interactor = WebChallengeInteractor(url: url)
        let presenter = WebChallengePresenter(
            interactor: interactor,
            router: router
        )
        
        interactor.presenter = presenter
        
        let view = WebChallengeViewController(presenter: presenter)
        
        presenter.setView(view)
        router.viewController = view
        
        return view
    }

    func dismissChallenge() {
        onResolved?()

        if let navigationController = viewController?.navigationController {
            navigationController.popViewController(animated: true)
            return
        }

        viewController?.dismiss(animated: true)
    }
}
