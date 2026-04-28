//
//  CommentCellNode.swift
//  nodeseek
//
//  Created by Codex on 2026/4/27.
//

import AsyncDisplayKit
import UIKit

final class CommentCellNode: ASCellNode {
    private enum Layout {
        static let horizontalInset: CGFloat = 12
        static let verticalInset: CGFloat = 6
        static let cardInset: CGFloat = 12
        static let avatarSize: CGFloat = 40
        static let avatarCornerRadius: CGFloat = 8
        static let avatarSpacing: CGFloat = 12
        static let bodySpacing: CGFloat = 8
    }

    private let comment: Comment
    private let onImageTapped: ([URL], Int) -> Void
    private let onTextLayoutInvalidated: () -> Void
    private let avatarLoader = AvatarImageLoader.shared
    private weak var avatarImageView: UIImageView?
    private var hasRequestedAvatar = false

    private let metaNode = ASTextNode()
    private let bodyNode: DetailRichTextNode?
    private let cardNode: ASDisplayNode = {
        let node = ASDisplayNode()
        node.backgroundColor = .secondarySystemBackground
        node.cornerRadius = 8
        return node
    }()

    private lazy var avatarNode: ASDisplayNode = {
        let node = ASDisplayNode(viewBlock: { [weak self] in
            let imageView = UIImageView()
            imageView.contentMode = .scaleAspectFill
            imageView.backgroundColor = .systemGray5
            imageView.layer.cornerRadius = Layout.avatarCornerRadius
            imageView.layer.masksToBounds = true
            self?.avatarImageView = imageView
            return imageView
        })
        node.style.preferredSize = CGSize(width: Layout.avatarSize, height: Layout.avatarSize)
        return node
    }()

    init(
        comment: Comment,
        attributedBody: NSAttributedString?,
        onImageTapped: @escaping ([URL], Int) -> Void,
        onTextLayoutInvalidated: @escaping () -> Void
    ) {
        self.comment = comment
        self.onImageTapped = onImageTapped
        self.onTextLayoutInvalidated = onTextLayoutInvalidated
        self.bodyNode = attributedBody.map {
            DetailRichTextNode(
                attributedText: $0,
                onImageTapped: onImageTapped,
                onLayoutInvalidated: onTextLayoutInvalidated
            )
        }
        super.init()
        automaticallyManagesSubnodes = true
        selectionStyle = .none
        backgroundColor = .systemBackground
        configureText()
    }

    override func didLoad() {
        super.didLoad()
        requestAvatarIfNeeded()
    }

    override func didEnterDisplayState() {
        super.didEnterDisplayState()
        requestAvatarIfNeeded()
    }

    override func didExitDisplayState() {
        super.didExitDisplayState()
        cancelAvatarLoad()
        hasRequestedAvatar = false
    }

    override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
        metaNode.style.flexShrink = 1

        var textChildren: [ASLayoutElement] = [metaNode]
        if let bodyNode {
            bodyNode.style.spacingBefore = Layout.bodySpacing
            textChildren.append(bodyNode)
        }

        let textStack = ASStackLayoutSpec.vertical()
        textStack.children = textChildren
        textStack.style.flexGrow = 1
        textStack.style.flexShrink = 1

        let contentStack = ASStackLayoutSpec.horizontal()
        contentStack.spacing = Layout.avatarSpacing
        contentStack.alignItems = .start
        contentStack.children = [avatarNode, textStack]

        let cardContent = ASInsetLayoutSpec(
            insets: UIEdgeInsets(
                top: Layout.cardInset,
                left: Layout.cardInset,
                bottom: Layout.cardInset,
                right: Layout.cardInset
            ),
            child: contentStack
        )
        let background = ASBackgroundLayoutSpec(child: cardContent, background: cardNode)
        return ASInsetLayoutSpec(
            insets: UIEdgeInsets(
                top: Layout.verticalInset,
                left: Layout.horizontalInset,
                bottom: Layout.verticalInset,
                right: Layout.horizontalInset
            ),
            child: background
        )
    }

    private func configureText() {
        metaNode.maximumNumberOfLines = 0
        metaNode.attributedText = NSAttributedString(
            string: [
                comment.floorText,
                comment.authorName,
                comment.createdAtText
            ].compactMap(\.self).joined(separator: " · "),
            attributes: [
                .font: UIFont.preferredFont(forTextStyle: .footnote),
                .foregroundColor: UIColor.secondaryLabel
            ]
        )
    }

    private func requestAvatarIfNeeded() {
        guard !hasRequestedAvatar else { return }
        guard let avatarImageView else { return }
        hasRequestedAvatar = true
        avatarLoader.loadAvatar(into: avatarImageView, postID: comment.id, avatarURL: comment.avatarURL)
    }

    private func cancelAvatarLoad() {
        guard let avatarImageView else { return }
        avatarLoader.cancel(on: avatarImageView)
    }
}
