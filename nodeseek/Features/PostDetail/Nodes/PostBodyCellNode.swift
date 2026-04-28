//
//  PostBodyCellNode.swift
//  nodeseek
//
//  Created by Codex on 2026/4/27.
//

import AsyncDisplayKit
import DTCoreText
import UIKit

final class PostBodyCellNode: ASCellNode {
    private enum Layout {
        static let contentInset = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        static let avatarSize: CGFloat = 40
        static let avatarCornerRadius: CGFloat = 8
        static let avatarSpacing: CGFloat = 12
        static let verticalSpacing: CGFloat = 14
        static let bodySpacing: CGFloat = 16
    }

    private let content: PostDetailHeaderContent
    private let onImageTapped: ([URL], Int) -> Void
    private let onTextLayoutInvalidated: () -> Void
    private let avatarLoader = AvatarImageLoader.shared
    private weak var avatarImageView: UIImageView?
    private var hasRequestedAvatar = false

    private let titleNode = ASTextNode()
    private let subtitleNode = ASTextNode()
    private let bodyNode: DetailRichTextNode?

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
        content: PostDetailHeaderContent,
        attributedContent: NSAttributedString?,
        onImageTapped: @escaping ([URL], Int) -> Void,
        onTextLayoutInvalidated: @escaping () -> Void
    ) {
        self.content = content
        self.onImageTapped = onImageTapped
        self.onTextLayoutInvalidated = onTextLayoutInvalidated
        self.bodyNode = attributedContent.map {
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
        titleNode.style.flexShrink = 1
        subtitleNode.style.flexShrink = 1

        let authorStack = ASStackLayoutSpec.horizontal()
        authorStack.spacing = Layout.avatarSpacing
        authorStack.alignItems = .center
        authorStack.children = [avatarNode, subtitleNode]

        let stack = ASStackLayoutSpec.vertical()
        stack.spacing = Layout.verticalSpacing
        stack.children = [titleNode, authorStack]

        if let bodyNode {
            bodyNode.style.spacingBefore = Layout.bodySpacing - Layout.verticalSpacing
            stack.children?.append(bodyNode)
        }

        return ASInsetLayoutSpec(insets: Layout.contentInset, child: stack)
    }

    private func configureText() {
        titleNode.maximumNumberOfLines = 0
        titleNode.attributedText = NSAttributedString(
            string: content.title,
            attributes: [
                .font: UIFont.preferredFont(forTextStyle: .title2),
                .foregroundColor: UIColor.label
            ]
        )

        subtitleNode.maximumNumberOfLines = 0
        subtitleNode.attributedText = NSAttributedString(
            string: [content.authorName, content.metadataText].compactMap(\.self).joined(separator: " · "),
            attributes: [
                .font: UIFont.preferredFont(forTextStyle: .subheadline),
                .foregroundColor: UIColor.secondaryLabel
            ]
        )
    }

    private func requestAvatarIfNeeded() {
        guard !hasRequestedAvatar else { return }
        guard let avatarImageView else { return }
        hasRequestedAvatar = true
        avatarLoader.loadAvatar(into: avatarImageView, postID: content.postID, avatarURL: content.avatarURL)
    }

    private func cancelAvatarLoad() {
        guard let avatarImageView else { return }
        avatarLoader.cancel(on: avatarImageView)
    }
}

final class DetailRichTextNode: ASDisplayNode {
    private let attributedText: NSAttributedString
    private let onImageTapped: ([URL], Int) -> Void
    private let onLayoutInvalidated: () -> Void

    init(
        attributedText: NSAttributedString,
        onImageTapped: @escaping ([URL], Int) -> Void,
        onLayoutInvalidated: @escaping () -> Void
    ) {
        self.attributedText = attributedText
        self.onImageTapped = onImageTapped
        self.onLayoutInvalidated = onLayoutInvalidated
        super.init()
        setViewBlock {
            DetailRichTextView()
        }
        style.flexShrink = 1
        style.flexGrow = 1
    }

    override func didLoad() {
        super.didLoad()
        guard let richTextView = view as? DetailRichTextView else { return }
        richTextView.configure(
            attributedText,
            onImageTapped: onImageTapped,
            onLayoutInvalidated: onLayoutInvalidated
        )
    }

    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        let width = constrainedSize.width
        guard width > 0, attributedText.length > 0 else {
            return .zero
        }

        let rect = attributedText.boundingRect(
            with: CGSize(width: width, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        return CGSize(width: width, height: ceil(max(rect.height, 1)))
    }
}
