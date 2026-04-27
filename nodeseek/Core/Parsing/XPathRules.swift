//
//  XPathRules.swift
//  nodeseek
//
//  Created by Codex on 2026/4/27.
//

enum XPathRules {
    static let postListItems = "//article[contains(@class, 'post-item')] | //li[contains(@class, 'post-list-item')]"
    static let postTitle = ".//*[contains(@class, 'post-title') and self::a] | .//*[contains(@class, 'post-title')]//a[contains(@href, '/post-') or contains(@href, '/post/')]"
    static let postAvatar = ".//img[contains(@class, 'avatar') or contains(@src, '/avatar/')]"
    static let postAuthor = ".//*[contains(@class, 'post-author')] | .//*[contains(@class, 'info-author')]//a"
    static let postNode = ".//*[contains(@class, 'post-node')] | .//*[contains(@class, 'post-category')]"
    static let replyCount = ".//*[contains(@class, 'reply-count')] | .//*[contains(@class, 'info-comments-count')]//span[last()]"
    static let lastActive = ".//*[contains(@class, 'last-active')] | .//*[contains(@class, 'info-last-comment-time')]//time"
    static let fallbackPostLinks = "//a[contains(@href, '/post-') or contains(@href, '/post/')]"
    static let fallbackPostContainer = "./ancestor::*[self::article or self::li or self::tr or self::div][1]"
    static let fallbackAvatar = ".//img[contains(@src, '/avatar/')]"
    static let fallbackAuthor = ".//a[contains(@href, '/space/') or contains(@href, '/user/')]"
    static let fallbackNode = ".//a[contains(@href, '/go/') or contains(@href, '/categories/')]"
    static let fallbackLastActive = ".//time"
}
