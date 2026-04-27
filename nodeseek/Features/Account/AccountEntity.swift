//
//  AccountEntity.swift
//  nodeseek
//
//  Created by Codex on 2026/4/27.
//

import Foundation

struct AccountRequest {
    let refresh: Bool
}

struct AccountResponse {
    let displayName: String
    let isLoggedIn: Bool
}
