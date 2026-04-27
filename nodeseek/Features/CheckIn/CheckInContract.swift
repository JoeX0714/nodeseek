//
//  CheckInContract.swift
//  nodeseek
//
//  Created by Codex on 2026/4/27.
//

import Foundation
import UIKit

// MARK: - View Protocol (Presenter -> View)
protocol CheckInViewProtocol: AnyObject {
    func showLoading()
    func hideLoading()
    func showError(message: String)
    func render(message: String)
}

// MARK: - Presenter Protocol (View -> Presenter)
protocol CheckInPresenterProtocol: AnyObject {
    func viewDidLoad()
}

// MARK: - Interactor Input (Presenter -> Interactor)
protocol CheckInInteractorInput: AnyObject {
    func loadCheckInState()
}

// MARK: - Interactor Output (Interactor -> Presenter)
protocol CheckInInteractorOutput: AnyObject {
    func didLoadCheckInState(_ response: CheckInResponse)
    func didFailLoadCheckInState(error: String)
}

// MARK: - Router Protocol (Presenter -> Router)
protocol CheckInRouterProtocol: AnyObject {
}
