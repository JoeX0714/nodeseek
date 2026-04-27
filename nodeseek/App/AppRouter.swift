//
//  AppRouter.swift
//  nodeseek
//
//  Created by Codex on 2026/4/27.
//

import UIKit

final class AppRouter {

    func makeRootViewController() -> UIViewController {
        UINavigationController(rootViewController: PostListRouter.createModule())
    }
}
