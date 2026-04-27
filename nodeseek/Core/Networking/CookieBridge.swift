//
//  CookieBridge.swift
//  nodeseek
//
//  Created by Codex on 2026/4/27.
//

import Foundation
import WebKit

@MainActor
protocol WebCookieStore: AnyObject {
    func allCookies() async -> [HTTPCookie]
    func setCookie(_ cookie: HTTPCookie) async
    func deleteCookie(_ cookie: HTTPCookie) async
}

@MainActor
final class WKWebCookieStoreAdapter: WebCookieStore {
    private let store: WKHTTPCookieStore

    init(store: WKHTTPCookieStore) {
        self.store = store
    }

    func allCookies() async -> [HTTPCookie] {
        await withCheckedContinuation { continuation in
            store.getAllCookies { cookies in
                continuation.resume(returning: cookies)
            }
        }
    }

    func setCookie(_ cookie: HTTPCookie) async {
        await withCheckedContinuation { continuation in
            store.setCookie(cookie) {
                continuation.resume()
            }
        }
    }

    func deleteCookie(_ cookie: HTTPCookie) async {
        await withCheckedContinuation { continuation in
            store.delete(cookie) {
                continuation.resume()
            }
        }
    }
}

@MainActor
final class CookieBridge {
    private let webCookieStore: WebCookieStore
    private let urlCookieStorage: HTTPCookieStorage
    private let allowedDomains: [String]

    init(
        webCookieStore: WebCookieStore? = nil,
        urlCookieStorage: HTTPCookieStorage = .shared,
        allowedDomains: [String] = ["nodeseek.com"]
    ) {
        self.webCookieStore = webCookieStore ?? WKWebCookieStoreAdapter(
            store: WKWebsiteDataStore.default().httpCookieStore
        )
        self.urlCookieStorage = urlCookieStorage
        self.allowedDomains = allowedDomains
    }

    func syncWebViewCookiesToURLSession() async {
        let cookies = await webCookieStore.allCookies()
        for cookie in cookies where isAllowed(cookie) {
            urlCookieStorage.setCookie(cookie)
        }
    }

    func syncURLSessionCookiesToWebView() async {
        let cookies = urlCookieStorage.cookies ?? []
        for cookie in cookies where isAllowed(cookie) {
            await webCookieStore.setCookie(cookie)
        }
    }

    func clearSession() async {
        let urlCookies = urlCookieStorage.cookies ?? []
        for cookie in urlCookies where isAllowed(cookie) {
            urlCookieStorage.deleteCookie(cookie)
        }

        let webCookies = await webCookieStore.allCookies()
        for cookie in webCookies where isAllowed(cookie) {
            await webCookieStore.deleteCookie(cookie)
        }
    }

    private func isAllowed(_ cookie: HTTPCookie) -> Bool {
        allowedDomains.contains { allowedDomain in
            let normalizedDomain = cookie.domain.trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased()
            return normalizedDomain == allowedDomain || normalizedDomain.hasSuffix(".\(allowedDomain)")
        }
    }
}
