//
//  HTTPHTMLClient.swift
//  nodeseek
//
//  Created by Codex on 2026/4/27.
//

import Foundation

struct HTTPHTMLClient: HTMLClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func get(_ url: URL) async throws -> HTMLResponse {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        applyDefaultHeaders(to: &request)
        return try await perform(request)
    }

    private func perform(_ request: URLRequest) async throws -> HTMLResponse {
        let (data, response) = try await session.data(for: request)
        let httpResponse = response as? HTTPURLResponse
        let headers = httpResponse?.allHeaderFields.reduce(into: [String: String]()) { result, item in
            guard let key = item.key as? String else { return }
            result[key] = String(describing: item.value)
        } ?? [:]
        let html = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)

        return HTMLResponse(
            statusCode: httpResponse?.statusCode ?? 0,
            headers: headers,
            finalURL: httpResponse?.url ?? request.url!,
            html: html
        )
    }

    private func applyDefaultHeaders(to request: inout URLRequest) {
        WebRequestFingerprint.applyHTMLHeaders(to: &request)
    }
}
