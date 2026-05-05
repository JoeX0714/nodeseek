//
//  WebPageMoreMenuFactory.swift
//  nodeseek
//

import UIKit

enum WebPageMoreMenuFactory {
    static func makeMoreButton(
        accessibilityLabel: String,
        onRefresh: @escaping @MainActor () -> Void,
        onCopyLink: @escaping @MainActor () -> Void,
        onOpenInSystemBrowser: @escaping @MainActor () -> Void
    ) -> UIBarButtonItem {
        let refreshAction = UIAction(
            title: "刷新",
            image: UIImage(systemName: "arrow.clockwise")
        ) { _ in
            onRefresh()
        }
        let copyAction = UIAction(
            title: "复制链接",
            image: UIImage(systemName: "doc.on.doc")
        ) { _ in
            onCopyLink()
        }
        let openAction = UIAction(
            title: "系统浏览器打开",
            image: UIImage(systemName: "safari")
        ) { _ in
            onOpenInSystemBrowser()
        }

        let button = UIBarButtonItem(
            image: UIImage(systemName: "ellipsis.circle"),
            primaryAction: nil,
            menu: UIMenu(children: [refreshAction, copyAction, openAction])
        )
        button.accessibilityLabel = accessibilityLabel
        return button
    }
}
