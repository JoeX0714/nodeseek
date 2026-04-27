//
//  AccountInteractor.swift
//  nodeseek
//
//  Created by Codex on 2026/4/27.
//

import Foundation

class AccountInteractor: AccountInteractorInput {
    
    // MARK: - Properties
    weak var presenter: AccountInteractorOutput?
    
    // MARK: - Initialization
    init() {}
    
    // MARK: - Methods
    func loadAccount() {
        presenter?.didLoadAccount(AccountResponse(displayName: "游客", isLoggedIn: false))
    }
}
