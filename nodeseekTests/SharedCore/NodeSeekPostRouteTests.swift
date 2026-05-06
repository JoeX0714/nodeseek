import Foundation
import Testing

#if SWIFT_PACKAGE
@testable import NodeSeekCore
#else
@testable import nodeseek
#endif

struct NodeSeekPostRouteTests {
    @Test func parsesPostPathWithoutPageAsPageOne() throws {
        let baseURL = try #require(URL(string: "https://www.nodeseek.com/space/1541"))
        let url = try #require(URL(string: "/post-704174", relativeTo: baseURL))

        let route = try #require(NodeSeekPostRouteResolver.route(for: url, baseURL: baseURL))

        #expect(route.postID == "704174")
        #expect(route.page == 1)
        #expect(route.anchorID == nil)
        #expect(route.url.absoluteString == "https://www.nodeseek.com/post-704174")
    }

    @Test func parsesPostPathWithPageAndAnchor() throws {
        let baseURL = try #require(URL(string: "https://www.nodeseek.com/space/1541"))
        let url = try #require(URL(string: "/post-704174-2#8", relativeTo: baseURL))

        let route = try #require(NodeSeekPostRouteResolver.route(for: url, baseURL: baseURL))

        #expect(route.postID == "704174")
        #expect(route.page == 2)
        #expect(route.anchorID == "8")
        #expect(route.url.absoluteString == "https://www.nodeseek.com/post-704174-2#8")
    }

    @Test func ignoresExternalPostLikePath() throws {
        let baseURL = try #require(URL(string: "https://www.nodeseek.com/space/1541"))
        let url = try #require(URL(string: "https://example.com/post-704174-1"))

        #expect(NodeSeekPostRouteResolver.route(for: url, baseURL: baseURL) == nil)
    }

    @Test func ignoresJumpRedirectorEvenWhenTargetIsPost() throws {
        let baseURL = try #require(URL(string: "https://www.nodeseek.com/space/1541"))
        let url = try #require(URL(
            string: "/jump?to=https%3A%2F%2Fwww.nodeseek.com%2Fpost-704174-1",
            relativeTo: baseURL
        ))

        #expect(NodeSeekPostRouteResolver.route(for: url, baseURL: baseURL) == nil)
    }
}
