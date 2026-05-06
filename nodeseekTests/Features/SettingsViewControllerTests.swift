//
//  SettingsViewControllerTests.swift
//  nodeseekTests
//
//  Created by Codex on 2026/5/2.
//

import Testing
import UIKit
@testable import nodeseek

@MainActor
struct SettingsViewControllerTests {
    @Test func settingsPageShowsCacheActionAndLogoutAtBottomWhenLoggedIn() async throws {
        let previousFileLogging = NodeSeekDebugConfig.enableFileLogging
        defer { NodeSeekDebugConfig.enableFileLogging = previousFileLogging }
        NodeSeekDebugConfig.enableFileLogging = false
        let defaults = try #require(UserDefaults(suiteName: "settings-account-\(UUID().uuidString)"))
        let accountStore = CurrentAccountStore(userDefaults: defaults, storageKey: "account")
        await accountStore.save(AccountResponse(displayName: "mistj", isLoggedIn: true))
        let viewController = SettingsViewController(
            cacheManager: FakeSettingsCacheManager(cacheByteSize: 4_096),
            sessionManager: FakeSettingsSessionManager(),
            currentAccountStore: accountStore,
            buildInfo: .testFlightFixture
        )
        viewController.loadViewIfNeeded()
        viewController.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        viewController.view.layoutIfNeeded()
        try await waitUntil { viewController.tableView.numberOfRows(inSection: 3) == 1 }

        let tableView = try #require(viewController.tableView)
        #expect(viewController.title == "设置")
        #expect(tableView.numberOfSections == 4)
        #expect(tableView.numberOfRows(inSection: 0) == 1)
        #expect(tableView.numberOfRows(inSection: 1) == 3)
        #expect(tableView.numberOfRows(inSection: 2) == 5)
        #expect(tableView.numberOfRows(inSection: 3) == 1)
        #expect(tableView.dataSource?.tableView?(tableView, titleForHeaderInSection: 1) == "调试")
        #expect(tableView.dataSource?.tableView?(tableView, titleForHeaderInSection: 2) == "版本")

        let cacheCell = try #require(tableView.dataSource?.tableView(
            tableView,
            cellForRowAt: IndexPath(row: 0, section: 0)
        ))
        let logCell = try #require(tableView.dataSource?.tableView(
            tableView,
            cellForRowAt: IndexPath(row: 0, section: 1)
        ))
        let logFileCell = try #require(tableView.dataSource?.tableView(
            tableView,
            cellForRowAt: IndexPath(row: 1, section: 1)
        ))
        let detailTestCell = try #require(tableView.dataSource?.tableView(
            tableView,
            cellForRowAt: IndexPath(row: 2, section: 1)
        ))
        let appVersionCell = try #require(tableView.dataSource?.tableView(
            tableView,
            cellForRowAt: IndexPath(row: 0, section: 2)
        ))
        let buildNumberCell = try #require(tableView.dataSource?.tableView(
            tableView,
            cellForRowAt: IndexPath(row: 1, section: 2)
        ))
        let gitCell = try #require(tableView.dataSource?.tableView(
            tableView,
            cellForRowAt: IndexPath(row: 2, section: 2)
        ))
        let workflowCell = try #require(tableView.dataSource?.tableView(
            tableView,
            cellForRowAt: IndexPath(row: 3, section: 2)
        ))
        let githubCell = try #require(tableView.dataSource?.tableView(
            tableView,
            cellForRowAt: IndexPath(row: 4, section: 2)
        ))
        let logoutCell = try #require(tableView.dataSource?.tableView(
            tableView,
            cellForRowAt: IndexPath(row: 0, section: 3)
        ))

        #expect(cacheCell.textLabel?.text == "清除缓存")
        #expect(cacheCell.detailTextLabel?.text == "4 KB")
        #expect(logCell.textLabel?.text == "记录日志")
        let loggingSwitch = try #require(logCell.accessoryView as? UISwitch)
        #expect(loggingSwitch.isOn == false)
        #expect(logFileCell.textLabel?.text == "日志文件")
        #expect(detailTestCell.textLabel?.text == "详情测试")
        #expect(appVersionCell.textLabel?.text == "版本")
        #expect(appVersionCell.detailTextLabel?.text == "1.0.1")
        #expect(buildNumberCell.textLabel?.text == "Build")
        #expect(buildNumberCell.detailTextLabel?.text == "42")
        #expect(gitCell.textLabel?.text == "Git")
        #expect(gitCell.detailTextLabel?.text == "abcdef1")
        #expect(workflowCell.textLabel?.text == "Workflow")
        #expect(workflowCell.detailTextLabel?.text == "TestFlight #25443881348")
        #expect(githubCell.textLabel?.text == "GitHub")
        #expect(githubCell.detailTextLabel?.text == "https://github.com/tyrad/nodeseek/actions/runs/25443881348")
        #expect(logoutCell.textLabel?.text == "退出登录")
        #expect(logoutCell.textLabel?.textColor == .systemRed)
    }

    @Test func settingsPageHidesLogoutWhenNotLoggedIn() async throws {
        let defaults = try #require(UserDefaults(suiteName: "settings-account-\(UUID().uuidString)"))
        let accountStore = CurrentAccountStore(userDefaults: defaults, storageKey: "account")
        let viewController = SettingsViewController(
            cacheManager: FakeSettingsCacheManager(cacheByteSize: 4_096),
            sessionManager: FakeSettingsSessionManager(),
            currentAccountStore: accountStore
        )

        viewController.loadViewIfNeeded()
        try await waitUntil { viewController.tableView.numberOfRows(inSection: 3) == 0 }

        #expect(viewController.tableView.numberOfRows(inSection: 3) == 0)
    }

    @Test func selectingClearCacheClearsCacheWithoutLoggingOut() async throws {
        let cacheManager = FakeSettingsCacheManager(cacheByteSize: 4_096)
        let sessionManager = FakeSettingsSessionManager()
        let viewController = SettingsViewController(
            cacheManager: cacheManager,
            sessionManager: sessionManager,
            confirmsActionsImmediately: true
        )
        viewController.loadViewIfNeeded()

        viewController.tableView.delegate?.tableView?(
            viewController.tableView,
            didSelectRowAt: IndexPath(row: 0, section: 0)
        )
        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(cacheManager.clearCount == 1)
        #expect(sessionManager.logoutCount == 0)
    }

    @Test func selectingLogoutLogsOutAndRunsCallback() async throws {
        let cacheManager = FakeSettingsCacheManager(cacheByteSize: 4_096)
        let sessionManager = FakeSettingsSessionManager()
        let defaults = try #require(UserDefaults(suiteName: "settings-account-\(UUID().uuidString)"))
        let accountStore = CurrentAccountStore(userDefaults: defaults, storageKey: "account")
        await accountStore.save(AccountResponse(displayName: "mistj", isLoggedIn: true))
        var logoutCallbackCount = 0
        let viewController = SettingsViewController(
            cacheManager: cacheManager,
            sessionManager: sessionManager,
            currentAccountStore: accountStore,
            confirmsActionsImmediately: true,
            onLogout: {
                logoutCallbackCount += 1
            }
        )
        viewController.loadViewIfNeeded()
        try await waitUntil { viewController.tableView.numberOfRows(inSection: 3) == 1 }

        viewController.tableView.delegate?.tableView?(
            viewController.tableView,
            didSelectRowAt: IndexPath(row: 0, section: 3)
        )
        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(cacheManager.clearCount == 0)
        #expect(sessionManager.logoutCount == 1)
        #expect(logoutCallbackCount == 1)
    }

    @Test func selectingDebugRowsRunsDebugCallbacks() throws {
        var logFileTapCount = 0
        var detailTestTapCount = 0
        let viewController = SettingsViewController(
            cacheManager: FakeSettingsCacheManager(cacheByteSize: 0),
            sessionManager: FakeSettingsSessionManager(),
            onLogFile: {
                logFileTapCount += 1
            },
            onDetailTest: {
                detailTestTapCount += 1
            }
        )
        viewController.loadViewIfNeeded()

        viewController.tableView.delegate?.tableView?(
            viewController.tableView,
            didSelectRowAt: IndexPath(row: 1, section: 1)
        )
        viewController.tableView.delegate?.tableView?(
            viewController.tableView,
            didSelectRowAt: IndexPath(row: 2, section: 1)
        )

        #expect(logFileTapCount == 1)
        #expect(detailTestTapCount == 1)
    }

    @Test func togglingFileLoggingSwitchUpdatesRuntimeConfig() throws {
        let previousFileLogging = NodeSeekDebugConfig.enableFileLogging
        defer { NodeSeekDebugConfig.enableFileLogging = previousFileLogging }
        NodeSeekDebugConfig.enableFileLogging = false
        let viewController = SettingsViewController(
            cacheManager: FakeSettingsCacheManager(cacheByteSize: 0),
            sessionManager: FakeSettingsSessionManager()
        )
        viewController.loadViewIfNeeded()

        let cell = try #require(viewController.tableView.dataSource?.tableView(
            viewController.tableView,
            cellForRowAt: IndexPath(row: 0, section: 1)
        ))
        let loggingSwitch = try #require(cell.accessoryView as? UISwitch)
        loggingSwitch.isOn = true
        loggingSwitch.sendActions(for: .valueChanged)

        #expect(NodeSeekDebugConfig.enableFileLogging == true)
    }
}

private extension SettingsBuildInfo {
    static let testFlightFixture = SettingsBuildInfo(
        appVersion: "1.0.1",
        buildNumber: "42",
        gitSHA: "abcdef1234567890",
        workflowName: "TestFlight",
        githubRunID: "25443881348",
        githubRunURL: URL(string: "https://github.com/tyrad/nodeseek/actions/runs/25443881348")
    )
}

@MainActor
private final class FakeSettingsCacheManager: SettingsCacheManaging {
    private(set) var clearCount = 0
    private var byteSize: UInt64

    init(cacheByteSize: UInt64) {
        self.byteSize = cacheByteSize
    }

    func cacheByteSize() async -> UInt64 {
        byteSize
    }

    func clearPreservingCookies() async throws {
        clearCount += 1
        byteSize = 0
    }
}

@MainActor
private final class FakeSettingsSessionManager: SettingsSessionManaging {
    private(set) var logoutCount = 0

    func logout() async {
        logoutCount += 1
    }
}

@MainActor
private func waitUntil(
    timeoutNanoseconds: UInt64 = 1_000_000_000,
    condition: @escaping @MainActor () -> Bool
) async throws {
    let step: UInt64 = 25_000_000
    var waited: UInt64 = 0
    while waited < timeoutNanoseconds {
        if condition() {
            return
        }
        try await Task.sleep(nanoseconds: step)
        waited += step
    }
}
