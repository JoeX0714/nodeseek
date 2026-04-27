//
//  CheckInPresenter.swift
//  nodeseek
//
//  Created by Codex on 2026/4/27.
//

import Foundation

class CheckInPresenter: CheckInPresenterProtocol {
    
    // MARK: - Properties
    private weak var view: CheckInViewProtocol?
    private let interactor: CheckInInteractorInput
    private let router: CheckInRouterProtocol
    
    // MARK: - Initialization
    init(
        interactor: CheckInInteractorInput,
        router: CheckInRouterProtocol
    ) {
        self.interactor = interactor
        self.router = router
    }
    
    // MARK: - Setup
    func setView(_ view: CheckInViewProtocol) {
        self.view = view
    }
    
    // MARK: - Methods
    func viewDidLoad() {
        view?.showLoading()
        interactor.loadCheckInState()
    }
}

// MARK: - Interactor Output
extension CheckInPresenter: CheckInInteractorOutput {
    
    func didLoadCheckInState(_ response: CheckInResponse) {
        view?.hideLoading()
        view?.render(message: response.message)
    }
    
    func didFailLoadCheckInState(error: String) {
        view?.hideLoading()
        view?.showError(message: error)
    }
}
