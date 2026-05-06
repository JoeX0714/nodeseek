import Foundation

nonisolated struct NodeSeekPostRoute: Equatable, Sendable {
    let postID: String
    let page: Int
    let anchorID: String?
    let url: URL
}

nonisolated enum NodeSeekPostRouteResolver {
    private static let postPathRegex = try! NSRegularExpression(
        pattern: "^/post-([0-9]+)(?:-([0-9]+))?/?$",
        options: []
    )

    static func route(for url: URL, baseURL: URL) -> NodeSeekPostRoute? {
        guard let resolvedURL = URL(string: url.relativeString, relativeTo: baseURL)?.absoluteURL,
              NodeSeekSite.isNodeSeekHost(resolvedURL),
              resolvedURL.path != "/jump" else {
            return nil
        }

        let path = resolvedURL.path
        let range = NSRange(path.startIndex..<path.endIndex, in: path)
        guard let match = postPathRegex.firstMatch(in: path, options: [], range: range),
              match.numberOfRanges >= 3,
              let postIDRange = Range(match.range(at: 1), in: path) else {
            return nil
        }

        let page: Int
        if match.range(at: 2).location != NSNotFound,
           let pageRange = Range(match.range(at: 2), in: path) {
            page = max(Int(path[pageRange]) ?? 1, 1)
        } else {
            page = 1
        }

        return NodeSeekPostRoute(
            postID: String(path[postIDRange]),
            page: page,
            anchorID: normalizedAnchorID(from: resolvedURL),
            url: resolvedURL
        )
    }

    private static func normalizedAnchorID(from url: URL) -> String? {
        guard let fragment = url.fragment?.removingPercentEncoding?.trimmingCharacters(in: .whitespacesAndNewlines),
              fragment.isEmpty == false else {
            return nil
        }
        return fragment.hasPrefix("#") ? String(fragment.dropFirst()) : fragment
    }
}
