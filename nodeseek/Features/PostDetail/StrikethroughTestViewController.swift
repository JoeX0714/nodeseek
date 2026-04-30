//
//  StrikethroughTestViewController.swift
//  nodeseek
//
//  Created by Codex on 2026/4/30.
//

import DTCoreText
import UIKit

final class StrikethroughTestViewController: UIViewController {
    private static let html = """
    <article class="post-content"><p><s>期待那天</s></p>
    <p>不用梯子那天</p>
    </article>
    """

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let richTextContainer = UIView()
    private let richTextTitleLabel = UILabel()
    private let richTextView = DetailRichTextView()
    private let comparisonTitleLabel = UILabel()
    private let comparisonLabel = UILabel()
    private var richTextHeightConstraint: NSLayoutConstraint?

    var renderedAttributedText: NSAttributedString? {
        richTextView.attributedString
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "删除线测试"
        view.backgroundColor = .systemBackground
        configureViews()
        installViews()
        renderHardcodedHTML()
        renderUIKitComparison()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateRichTextHeight()
    }

    private func configureViews() {
        scrollView.alwaysBounceVertical = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        contentView.translatesAutoresizingMaskIntoConstraints = false

        richTextContainer.backgroundColor = .secondarySystemBackground
        richTextContainer.layer.cornerRadius = 8
        richTextContainer.translatesAutoresizingMaskIntoConstraints = false

        richTextTitleLabel.text = "DTCoreText"
        richTextTitleLabel.font = .preferredFont(forTextStyle: .footnote)
        richTextTitleLabel.textColor = .secondaryLabel
        richTextTitleLabel.translatesAutoresizingMaskIntoConstraints = false

        richTextView.backgroundColor = .clear
        richTextView.accessibilityIdentifier = "strikethrough-test-rich-text"
        richTextView.translatesAutoresizingMaskIntoConstraints = false

        comparisonTitleLabel.text = "UILabel"
        comparisonTitleLabel.font = .preferredFont(forTextStyle: .footnote)
        comparisonTitleLabel.textColor = .secondaryLabel
        comparisonTitleLabel.translatesAutoresizingMaskIntoConstraints = false

        comparisonLabel.numberOfLines = 0
        comparisonLabel.font = .preferredFont(forTextStyle: .body)
        comparisonLabel.textColor = .label
        comparisonLabel.translatesAutoresizingMaskIntoConstraints = false
    }

    private func installViews() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(richTextContainer)
        richTextContainer.addSubview(richTextTitleLabel)
        richTextContainer.addSubview(richTextView)
        contentView.addSubview(comparisonTitleLabel)
        contentView.addSubview(comparisonLabel)

        let richTextHeightConstraint = richTextView.heightAnchor.constraint(equalToConstant: 80)
        self.richTextHeightConstraint = richTextHeightConstraint

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            richTextContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            richTextContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            richTextContainer.topAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.topAnchor, constant: 20),

            richTextTitleLabel.leadingAnchor.constraint(equalTo: richTextContainer.leadingAnchor, constant: 14),
            richTextTitleLabel.trailingAnchor.constraint(equalTo: richTextContainer.trailingAnchor, constant: -14),
            richTextTitleLabel.topAnchor.constraint(equalTo: richTextContainer.topAnchor, constant: 12),

            richTextView.leadingAnchor.constraint(equalTo: richTextContainer.leadingAnchor, constant: 14),
            richTextView.trailingAnchor.constraint(equalTo: richTextContainer.trailingAnchor, constant: -14),
            richTextView.topAnchor.constraint(equalTo: richTextTitleLabel.bottomAnchor, constant: 10),
            richTextView.bottomAnchor.constraint(equalTo: richTextContainer.bottomAnchor, constant: -14),
            richTextHeightConstraint,

            comparisonTitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 30),
            comparisonTitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -30),
            comparisonTitleLabel.topAnchor.constraint(equalTo: richTextContainer.bottomAnchor, constant: 24),

            comparisonLabel.leadingAnchor.constraint(equalTo: comparisonTitleLabel.leadingAnchor),
            comparisonLabel.trailingAnchor.constraint(equalTo: comparisonTitleLabel.trailingAnchor),
            comparisonLabel.topAnchor.constraint(equalTo: comparisonTitleLabel.bottomAnchor, constant: 10),
            comparisonLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -28)
        ])
    }

    private func renderHardcodedHTML() {
        let blocks = DTCoreTextHTMLContentRenderer().render(
            fragment: Self.html,
            baseURL: URL(string: "https://www.nodeseek.com")!,
            maxImageWidth: 320
        )
        let attributedText = blocks.compactMap { block -> NSAttributedString? in
            guard case .text(let text) = block else { return nil }
            return text
        }.first
        richTextView.configure(
            attributedText,
            onImageTapped: nil,
            onLayoutInvalidated: { [weak self] in
                self?.updateRichTextHeight()
            }
        )
    }

    private func renderUIKitComparison() {
        let text = NSMutableAttributedString(
            string: "期待那天\n不用梯子那天",
            attributes: [
                .font: UIFont.preferredFont(forTextStyle: .body),
                .foregroundColor: UIColor.label
            ]
        )
        let range = (text.string as NSString).range(of: "期待那天")
        text.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
        comparisonLabel.attributedText = text
    }

    private func updateRichTextHeight() {
        let width = richTextView.bounds.width
        guard width > 0 else { return }
        let fittingSize = richTextView.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height)
        )
        let height = max(80, ceil(fittingSize.height))
        guard abs((richTextHeightConstraint?.constant ?? 0) - height) > 0.5 else { return }
        richTextHeightConstraint?.constant = height
        view.layoutIfNeeded()
    }
}
