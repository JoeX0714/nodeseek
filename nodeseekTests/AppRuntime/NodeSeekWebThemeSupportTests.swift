//
//  NodeSeekWebThemeSupportTests.swift
//  nodeseekTests
//

import Foundation
import Testing
import UIKit
import WebKit
@testable import nodeseek

@MainActor
struct NodeSeekWebThemeSupportTests {
    @Test func darkInterfaceStyleCreatesDarkColorSchemeCookie() throws {
        let cookie = try #require(NodeSeekWebThemeSupport.makeColorSchemeCookie(userInterfaceStyle: .dark))

        #expect(cookie.name == "colorscheme")
        #expect(cookie.value == "dark")
        #expect(cookie.domain == ".nodeseek.com")
        #expect(cookie.path == "/")
        #expect(cookie.isSecure)
    }

    @Test func lightInterfaceStyleCreatesLightColorSchemeCookie() throws {
        let cookie = try #require(NodeSeekWebThemeSupport.makeColorSchemeCookie(userInterfaceStyle: .light))

        #expect(cookie.name == "colorscheme")
        #expect(cookie.value == "light")
    }

    @Test func themeUserScriptUsesNodeSeekNativeThemeClassesAndSystemPreference() {
        let source = NodeSeekWebThemeSupport.makeUserScript().source

        #expect(source.contains("prefers-color-scheme: dark"))
        #expect(source.contains("dark-layout"))
        #expect(source.contains("light-layout"))
        #expect(source.contains("colorscheme"))
        #expect(source.contains("nodeseek.com"))
    }
}
