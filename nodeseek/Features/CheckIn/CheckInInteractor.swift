//
//  CheckInInteractor.swift
//  nodeseek
//
//  Created by Codex on 2026/4/27.
//

import Foundation

class CheckInInteractor: CheckInInteractorInput {
    
    // MARK: - Properties
    weak var presenter: CheckInInteractorOutput?
    
    // MARK: - Initialization
    init() {}
    
    // MARK: - Methods
    func loadCheckInState() {
        presenter?.didLoadCheckInState(CheckInResponse(message: "今日还未签到，后续会接入真实任务页面。"))
    }
}
