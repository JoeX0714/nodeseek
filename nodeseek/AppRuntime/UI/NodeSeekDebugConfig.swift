//
//  NodeSeekDebugConfig.swift
//  nodeseek
//
//  Created by Codex on 2026/4/27.
//

import UIKit

struct NodeSeekDebugConfig {
    #if DEBUG
    private nonisolated static let storage = NodeSeekDebugConfigStorage(fileLoggingEnabled: true)

    static let enablePostDetailTestEntry = true
    static let enableWebViewDebugOverlay = false
    static let enableDetailRenderDiagnostics = false
    nonisolated static var enableFileLogging: Bool {
        get { storage.fileLoggingEnabled }
        set { storage.fileLoggingEnabled = newValue }
    }
    #else
    static let enablePostDetailTestEntry = false
    static let enableWebViewDebugOverlay = false
    static let enableDetailRenderDiagnostics = false
    static let enableFileLogging = false
    #endif

    static let webViewDebugOverlaySize = CGSize(width: 180, height: 120)
    static let webViewDebugOverlayBottomInset: CGFloat = 8
    static let webViewDebugOverlayLeadingInset: CGFloat = 8
}

#if DEBUG
private final class NodeSeekDebugConfigStorage: @unchecked Sendable {
    private let lock = NSLock()
    // 只允许通过 fileLoggingEnabled 访问，NSLock 负责同步测试和后台日志线程。
    nonisolated(unsafe) private var _fileLoggingEnabled: Bool

    init(fileLoggingEnabled: Bool) {
        _fileLoggingEnabled = fileLoggingEnabled
    }

    nonisolated var fileLoggingEnabled: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _fileLoggingEnabled
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _fileLoggingEnabled = newValue
        }
    }
}
#endif
