//
//  PostDetailViewController.swift
//  nodeseek
//
//  Created by Codex on 2026/4/27.
//

import UIKit
import OSLog
import ZNSTextAttachment
import SafariServices
import WebKit
import JXPhotoBrowser
import ObjectiveC

class PostDetailViewController: UIViewController {
    private enum Layout {
        static let horizontalInset: CGFloat = 20
        static let commentHorizontalInset: CGFloat = 12
        static let commentCardInset: CGFloat = 12
        static let avatarSize: CGFloat = 40
        static let avatarSpacing: CGFloat = 12
    }

    private let presenter: PostDetailPresenterProtocol
    private let baseURL = URL(string: "https://www.nodeseek.com")!
    private let headerView = PostDetailHeaderView()
    private var currentHeaderContent: PostDetailHeaderContent?
    private var headerAttributedContent: NSAttributedString?
    private var comments: [Comment] = []
    private var commentAttributedCache: [String: NSAttributedString] = [:]
    private var renderedCommentIDs: Set<String> = []
    private var commentRenderInFlight: Set<String> = []
    private var renderGeneration: Int = 0
    private let sourcePostURL: URL?
    private var photoBrowserPresenter: DetailPhotoBrowserPresenter?
    private let renderQueue = DispatchQueue(
        label: "com.nodeseek.app.postdetail.render",
        qos: .userInitiated
    )

    private let tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.backgroundColor = .systemBackground
        tableView.separatorStyle = .none
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 120
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()

    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()

    init(
        presenter: PostDetailPresenterProtocol,
        initialHeader: PostDetailHeaderContent? = nil,
        sourcePostURL: URL? = nil
    ) {
        self.presenter = presenter
        self.sourcePostURL = sourcePostURL
        super.init(nibName: nil, bundle: nil)
        headerView.onImageTapped = { [weak self] imageURLs, initialIndex in
            self?.presentPhotoBrowser(imageURLs: imageURLs, initialIndex: initialIndex)
        }

        if let initialHeader {
            configureHeader(initialHeader, attributedContent: nil)
            scheduleHeaderRender(for: initialHeader)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAttachmentDidLoad),
            name: DetailAttachmentDataSource.didLoadNotification,
            object: nil
        )
        configureNavigationItems()
        setupUI()
        presenter.viewDidLoad()
    }

    private func configureNavigationItems() {
        let refreshButton = UIBarButtonItem(
            image: UIImage(systemName: "arrow.clockwise"),
            style: .plain,
            target: self,
            action: #selector(refreshTapped)
        )
        refreshButton.accessibilityLabel = "刷新"

        let browserButton = UIBarButtonItem(
            image: UIImage(systemName: "safari"),
            style: .plain,
            target: self,
            action: #selector(openInBrowserTapped)
        )
        browserButton.accessibilityLabel = "在浏览器打开"
        navigationItem.rightBarButtonItems = [refreshButton, browserButton]
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        resizeTableHeaderView()
    }

    private func setupUI() {
        view.backgroundColor = .systemBackground
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(PostDetailCommentCell.self, forCellReuseIdentifier: PostDetailCommentCell.reuseIdentifier)

        view.addSubview(tableView)
        view.addSubview(loadingIndicator)
        tableView.tableHeaderView = headerView

        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func configureHeader(_ content: PostDetailHeaderContent, attributedContent: NSAttributedString?) {
        currentHeaderContent = content
        headerView.configure(content, attributedContent: attributedContent)
        resizeTableHeaderView()
    }

    private func scheduleHeaderRender(for content: PostDetailHeaderContent) {
        let generation = renderGeneration
        let html = content.contentHTML
        let width = availableHeaderContentWidth
        let baseURL = baseURL
        renderQueue.async { [weak self] in
            let attributed = Self.makeAttributedText(
                html: html,
                baseURL: baseURL,
                maxImageWidth: width
            )
            DispatchQueue.main.async {
                guard let self else { return }
                guard self.renderGeneration == generation else { return }
                guard self.currentHeaderContent?.postID == content.postID else { return }
                self.headerAttributedContent = attributed
                self.configureHeader(content, attributedContent: attributed)
            }
        }
    }

    private static func makeAttributedText(
        html: String,
        baseURL: URL,
        maxImageWidth: CGFloat
    ) -> NSAttributedString? {
        let blocks = ZMarkupHTMLContentRenderer().render(fragment: html, baseURL: baseURL, maxImageWidth: maxImageWidth)
        guard blocks.isEmpty == false else { return nil }

        let result = NSMutableAttributedString()
        for block in blocks {
            switch block {
            case .text(let attributedText):
                result.append(attributedText)
            case .imagePlaceholder(let url):
                result.append(NSAttributedString(string: url?.absoluteString ?? "[图片]"))
            case .unsupported(let reason):
                result.append(NSAttributedString(string: reason))
            }
        }

        return result.length > 0 ? result : nil
    }

    private func resizeTableHeaderView() {
        guard let tableHeaderView = tableView.tableHeaderView else { return }

        let width = tableView.bounds.width > 0 ? tableView.bounds.width : view.bounds.width
        guard width > 0 else { return }

        tableHeaderView.frame.size.width = width
        let targetSize = CGSize(width: width, height: UIView.layoutFittingCompressedSize.height)
        let height = tableHeaderView.systemLayoutSizeFitting(
            targetSize,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height

        guard abs(tableHeaderView.frame.height - height) > 0.5 else { return }
        tableHeaderView.frame.size.height = height
        tableView.tableHeaderView = tableHeaderView
    }

    private var availableHeaderContentWidth: CGFloat {
        let width = tableView.bounds.width > 0 ? tableView.bounds.width : view.bounds.width
        return max((width > 0 ? width : 320) - Layout.horizontalInset * 2, 1)
    }

    private var availableCommentContentWidth: CGFloat {
        let width = tableView.bounds.width > 0 ? tableView.bounds.width : view.bounds.width
        let contentWidth = (width > 0 ? width : 320)
            - Layout.commentHorizontalInset * 2
            - Layout.commentCardInset * 2
            - Layout.avatarSize
            - Layout.avatarSpacing
        return max(contentWidth, 1)
    }

    @objc
    private func handleAttachmentDidLoad() {
        resizeTableHeaderView()
        tableView.beginUpdates()
        tableView.endUpdates()
    }

    @objc
    private func refreshTapped() {
        presenter.viewDidLoad()
    }

    @objc
    private func openInBrowserTapped() {
        guard let targetURL = resolvedDetailURL() else {
            showError(message: "当前帖子链接无效，暂时无法打开。")
            return
        }

        if isNodeSeekHost(targetURL) {
            let webViewController = CookieSharedWebViewController(url: targetURL)
            if let navigationController {
                navigationController.pushViewController(webViewController, animated: true)
            } else {
                let navigationWrapper = UINavigationController(rootViewController: webViewController)
                present(navigationWrapper, animated: true)
            }
            return
        }

        let safariViewController = SFSafariViewController(url: targetURL)
        present(safariViewController, animated: true)
    }

    private func resolvedDetailURL() -> URL? {
        if let sourcePostURL {
            return sourcePostURL
        }

        guard let postID = currentHeaderContent?.postID, postID.isEmpty == false else { return nil }
        return URL(string: "https://www.nodeseek.com/post-\(postID)-1")
    }

    private func isNodeSeekHost(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host == "nodeseek.com" || host.hasSuffix(".nodeseek.com")
    }

    private func presentPhotoBrowser(imageURLs: [URL], initialIndex: Int) {
        guard imageURLs.isEmpty == false else { return }
        let presenter = DetailPhotoBrowserPresenter(imageURLs: imageURLs)
        photoBrowserPresenter = presenter
        presenter.present(from: self, initialIndex: initialIndex)
    }

    private func preheatCommentRender(for comments: [Comment]) {
        for comment in comments {
            scheduleCommentRenderIfNeeded(for: comment)
        }
    }

    private func scheduleCommentRenderIfNeeded(for comment: Comment) {
        let commentID = comment.id
        guard renderedCommentIDs.contains(commentID) == false else { return }
        guard commentRenderInFlight.insert(commentID).inserted else { return }

        let generation = renderGeneration
        let html = comment.contentHTML
        let width = availableCommentContentWidth
        let baseURL = baseURL
        renderQueue.async { [weak self] in
            let attributed = Self.makeAttributedText(
                html: html,
                baseURL: baseURL,
                maxImageWidth: width
            )
            DispatchQueue.main.async {
                guard let self else { return }
                guard self.renderGeneration == generation else { return }
                self.commentRenderInFlight.remove(commentID)
                self.renderedCommentIDs.insert(commentID)
                if let attributed {
                    self.commentAttributedCache[commentID] = attributed
                } else {
                    self.commentAttributedCache.removeValue(forKey: commentID)
                }
                guard let row = self.comments.firstIndex(where: { $0.id == commentID }) else { return }
                let indexPath = IndexPath(row: row, section: 0)
                guard self.tableView.indexPathsForVisibleRows?.contains(indexPath) == true else { return }
                self.tableView.reloadRows(at: [indexPath], with: .none)
            }
        }
    }
}

extension PostDetailViewController: PostDetailViewProtocol {
    func showLoading() {
        loadingIndicator.startAnimating()
    }

    func hideLoading() {
        loadingIndicator.stopAnimating()
    }

    func showError(message: String) {
        let alert = UIAlertController(title: "错误", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }

    func render(detail: PostDetail) {
        title = "详情"
        renderGeneration += 1
        headerAttributedContent = nil
        let headerContent = PostDetailHeaderContent(detail: detail)
        configureHeader(headerContent, attributedContent: nil)
        scheduleHeaderRender(for: headerContent)
        comments = detail.comments
        commentAttributedCache.removeAll(keepingCapacity: true)
        renderedCommentIDs.removeAll(keepingCapacity: true)
        commentRenderInFlight.removeAll(keepingCapacity: true)
        preheatCommentRender(for: comments)
        tableView.reloadData()
    }

    func renderLoginRequired(message: String) {
        title = "详情"
        renderGeneration += 1
        let existing = currentHeaderContent
        headerAttributedContent = nil
        let headerContent = PostDetailHeaderContent(
            postID: existing?.postID ?? "login-required",
            title: existing?.title ?? "需要登录",
            authorName: existing?.authorName ?? "NodeSeek",
            avatarURL: existing?.avatarURL,
            metadataText: existing?.metadataText,
            contentHTML: message
        )
        configureHeader(headerContent, attributedContent: nil)
        scheduleHeaderRender(for: headerContent)
        comments = []
        commentAttributedCache.removeAll(keepingCapacity: true)
        renderedCommentIDs.removeAll(keepingCapacity: true)
        commentRenderInFlight.removeAll(keepingCapacity: true)
        tableView.reloadData()
    }
}

private final class CookieSharedWebViewController: UIViewController, WKNavigationDelegate {
    private let url: URL
    private let webView: WKWebView
    private let cookieBridge: CookieBridge
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)

    init(url: URL) {
        self.url = url
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        self.webView = WKWebView(frame: .zero, configuration: configuration)
        self.cookieBridge = CookieBridge(
            webCookieStore: WKWebCookieStoreAdapter(
                store: configuration.websiteDataStore.httpCookieStore
            )
        )
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "网页"
        configureNavigationItems()

        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)

        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loadingIndicator)
        loadingIndicator.startAnimating()

        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        Task { @MainActor [weak self] in
            guard let self else { return }
            await cookieBridge.syncURLSessionCookiesToWebView()

            var request = URLRequest(url: url)
            request.timeoutInterval = 20
            request.cachePolicy = .reloadRevalidatingCacheData
            WebRequestFingerprint.applyHTMLHeaders(to: &request)
            webView.load(request)
        }
    }

    private func configureNavigationItems() {
        let copyAction = UIAction(
            title: "复制链接",
            image: UIImage(systemName: "doc.on.doc")
        ) { [weak self] _ in
            self?.copyCurrentPageURL()
        }
        let openAction = UIAction(
            title: "系统浏览器打开",
            image: UIImage(systemName: "safari")
        ) { [weak self] _ in
            self?.openInSystemBrowser()
        }

        let menu = UIMenu(children: [copyAction, openAction])
        let moreButton = UIBarButtonItem(
            image: UIImage(systemName: "ellipsis.circle"),
            primaryAction: nil,
            menu: menu
        )
        moreButton.accessibilityLabel = "网页更多操作"
        navigationItem.rightBarButtonItem = moreButton
    }

    private func currentPageURL() -> URL {
        webView.url ?? url
    }

    private func copyCurrentPageURL() {
        UIPasteboard.general.url = currentPageURL()
    }

    private func openInSystemBrowser() {
        UIApplication.shared.open(currentPageURL(), options: [:], completionHandler: nil)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loadingIndicator.stopAnimating()
    }

    func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation!,
        withError error: Error
    ) {
        loadingIndicator.stopAnimating()
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        loadingIndicator.stopAnimating()
    }
}

extension PostDetailViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        comments.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: PostDetailCommentCell.reuseIdentifier,
            for: indexPath
        ) as? PostDetailCommentCell else {
            return UITableViewCell()
        }

        let comment = comments[indexPath.row]
        cell.onImageTapped = { [weak self] imageURLs, initialIndex in
            self?.presentPhotoBrowser(imageURLs: imageURLs, initialIndex: initialIndex)
        }
        cell.configure(
            comment: comment,
            attributedBody: commentAttributedCache[comment.id]
        )
        scheduleCommentRenderIfNeeded(for: comment)
        return cell
    }
}

private final class PostDetailHeaderView: UIView {
    private enum Layout {
        static let horizontalInset: CGFloat = 20
        static let topInset: CGFloat = 20
        static let bottomInset: CGFloat = 20
        static let avatarSize: CGFloat = 40
        static let avatarCornerRadius: CGFloat = 8
        static let avatarSpacing: CGFloat = 12
    }

    private let avatarLoader = AvatarImageLoader.shared

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .title2)
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let authorRowView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let avatarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.backgroundColor = .systemGray5
        imageView.layer.cornerRadius = Layout.avatarCornerRadius
        imageView.layer.masksToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let contentLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    private var contentTopConstraint: NSLayoutConstraint?
    var onImageTapped: (([URL], Int) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(_ content: PostDetailHeaderContent, attributedContent: NSAttributedString?) {
        titleLabel.text = content.title
        subtitleLabel.text = [content.authorName, content.metadataText].compactMap(\.self).joined(separator: " · ")
        contentLabel.attributedText = attributedContent
        DetailAttachmentActivator.bindAndStartIfNeeded(
            in: contentLabel,
            context: "header-\(content.postID)",
            onImageTapped: onImageTapped
        )
        contentLabel.isHidden = attributedContent == nil
        contentTopConstraint?.constant = attributedContent == nil ? 0 : 16
        avatarLoader.loadAvatar(into: avatarImageView, postID: content.postID, avatarURL: content.avatarURL)
    }

    private func setupUI() {
        backgroundColor = .systemBackground
        addSubview(titleLabel)
        addSubview(authorRowView)
        addSubview(contentLabel)
        authorRowView.addSubview(avatarImageView)
        authorRowView.addSubview(subtitleLabel)

        let contentTopConstraint = contentLabel.topAnchor.constraint(equalTo: authorRowView.bottomAnchor, constant: 16)
        self.contentTopConstraint = contentTopConstraint

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Layout.horizontalInset),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Layout.horizontalInset),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: Layout.topInset),

            authorRowView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Layout.horizontalInset),
            authorRowView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Layout.horizontalInset),
            authorRowView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 14),

            avatarImageView.leadingAnchor.constraint(equalTo: authorRowView.leadingAnchor),
            avatarImageView.topAnchor.constraint(equalTo: authorRowView.topAnchor),
            avatarImageView.bottomAnchor.constraint(equalTo: authorRowView.bottomAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: Layout.avatarSize),
            avatarImageView.heightAnchor.constraint(equalToConstant: Layout.avatarSize),

            subtitleLabel.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: Layout.avatarSpacing),
            subtitleLabel.trailingAnchor.constraint(equalTo: authorRowView.trailingAnchor),
            subtitleLabel.centerYAnchor.constraint(equalTo: authorRowView.centerYAnchor),
            subtitleLabel.topAnchor.constraint(greaterThanOrEqualTo: authorRowView.topAnchor),
            subtitleLabel.bottomAnchor.constraint(lessThanOrEqualTo: authorRowView.bottomAnchor),

            contentLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Layout.horizontalInset),
            contentLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Layout.horizontalInset),
            contentTopConstraint,
            contentLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Layout.bottomInset)
        ])
    }
}

private final class PostDetailCommentCell: UITableViewCell {
    static let reuseIdentifier = "PostDetailCommentCell"

    private enum Layout {
        static let horizontalInset: CGFloat = 12
        static let verticalInset: CGFloat = 6
        static let cardInset: CGFloat = 12
        static let avatarSize: CGFloat = 40
        static let avatarCornerRadius: CGFloat = 8
        static let avatarSpacing: CGFloat = 12
    }

    private let avatarLoader = AvatarImageLoader.shared

    private let cardView: UIView = {
        let view = UIView()
        view.backgroundColor = .secondarySystemBackground
        view.layer.cornerRadius = 8
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let avatarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.backgroundColor = .systemGray5
        imageView.layer.cornerRadius = Layout.avatarCornerRadius
        imageView.layer.masksToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let metaLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .footnote)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let bodyLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    var onImageTapped: (([URL], Int) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        avatarLoader.cancel(on: avatarImageView)
        avatarImageView.image = nil
        metaLabel.text = nil
        bodyLabel.attributedText = nil
        onImageTapped = nil
    }

    func configure(comment: Comment, attributedBody: NSAttributedString?) {
        metaLabel.text = [
            comment.floorText,
            comment.authorName,
            comment.createdAtText
        ].compactMap(\.self).joined(separator: " · ")
        bodyLabel.attributedText = attributedBody
        DetailAttachmentActivator.bindAndStartIfNeeded(
            in: bodyLabel,
            context: "comment-\(comment.id)",
            onImageTapped: onImageTapped
        )
        avatarLoader.loadAvatar(into: avatarImageView, postID: comment.id, avatarURL: comment.avatarURL)
    }

    private func setupUI() {
        selectionStyle = .none
        backgroundColor = .systemBackground
        contentView.backgroundColor = .systemBackground
        contentView.addSubview(cardView)
        cardView.addSubview(avatarImageView)
        cardView.addSubview(metaLabel)
        cardView.addSubview(bodyLabel)

        NSLayoutConstraint.activate([
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Layout.horizontalInset),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Layout.horizontalInset),
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Layout.verticalInset),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Layout.verticalInset),

            avatarImageView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: Layout.cardInset),
            avatarImageView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: Layout.cardInset),
            avatarImageView.widthAnchor.constraint(equalToConstant: Layout.avatarSize),
            avatarImageView.heightAnchor.constraint(equalToConstant: Layout.avatarSize),

            metaLabel.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: Layout.avatarSpacing),
            metaLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -Layout.cardInset),
            metaLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: Layout.cardInset),

            bodyLabel.leadingAnchor.constraint(equalTo: metaLabel.leadingAnchor),
            bodyLabel.trailingAnchor.constraint(equalTo: metaLabel.trailingAnchor),
            bodyLabel.topAnchor.constraint(equalTo: metaLabel.bottomAnchor, constant: 8),
            bodyLabel.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -Layout.cardInset),
            bodyLabel.bottomAnchor.constraint(greaterThanOrEqualTo: avatarImageView.bottomAnchor)
        ])
    }

}

private enum DetailAttachmentActivator {
    private static let logger = Logger(subsystem: "com.nodeseek.app", category: "DetailAttachment")

    static func bindAndStartIfNeeded(
        in label: UILabel,
        context: String,
        onImageTapped: (([URL], Int) -> Void)? = nil
    ) {
        guard let attributedText = label.attributedText, attributedText.length > 0 else {
            DetailImageTapCoordinator.shared.clear(label: label)
            return
        }

        var activatedCount = 0
        attributedText.enumerateAttribute(
            .attachment,
            in: NSRange(location: 0, length: attributedText.length)
        ) { value, _, _ in
            guard let attachment = value as? ZNSTextAttachment else { return }
            attachment.dataSource = DetailAttachmentDataSource.shared
            attachment.register(label)
            attachment.startDownlaod()
            activatedCount += 1
        }

        if activatedCount > 0 {
            logger.debug(
                "已触发ZNSTextAttachment下载 context=\(context, privacy: .public), count=\(activatedCount, privacy: .public)"
            )
        }

        DetailImageTapCoordinator.shared.bind(
            label: label,
            attributedText: attributedText,
            onImageTapped: onImageTapped
        )
    }
}

private final class DetailImageTapCoordinator: NSObject {
    static let shared = DetailImageTapCoordinator()

    private enum AssociatedKeys {
        static var context: UInt8 = 0
        static var gesture: UInt8 = 0
    }

    private struct PreviewItem {
        let range: NSRange
        let imageURL: URL
    }

    private final class TapContext: NSObject {
        let items: [PreviewItem]
        let onImageTapped: ([URL], Int) -> Void

        init(items: [PreviewItem], onImageTapped: @escaping ([URL], Int) -> Void) {
            self.items = items
            self.onImageTapped = onImageTapped
        }
    }

    func bind(
        label: UILabel,
        attributedText: NSAttributedString,
        onImageTapped: (([URL], Int) -> Void)?
    ) {
        guard let onImageTapped else {
            objc_setAssociatedObject(label, &AssociatedKeys.context, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            return
        }

        let items = collectPreviewItems(from: attributedText)
        guard items.isEmpty == false else {
            objc_setAssociatedObject(label, &AssociatedKeys.context, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            return
        }

        let context = TapContext(items: items, onImageTapped: onImageTapped)
        objc_setAssociatedObject(
            label,
            &AssociatedKeys.context,
            context,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )

        label.isUserInteractionEnabled = true
        if objc_getAssociatedObject(label, &AssociatedKeys.gesture) as? UITapGestureRecognizer == nil {
            let gesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            label.addGestureRecognizer(gesture)
            objc_setAssociatedObject(
                label,
                &AssociatedKeys.gesture,
                gesture,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }

    func clear(label: UILabel) {
        objc_setAssociatedObject(label, &AssociatedKeys.context, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    @objc
    private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let label = gesture.view as? UILabel,
              let context = objc_getAssociatedObject(label, &AssociatedKeys.context) as? TapContext,
              let index = characterIndex(in: label, tapPoint: gesture.location(in: label)),
              let tappedItemIndex = context.items.firstIndex(where: { NSLocationInRange(index, $0.range) }) else {
            return
        }

        context.onImageTapped(context.items.map(\.imageURL), tappedItemIndex)
    }

    private func collectPreviewItems(from attributedText: NSAttributedString) -> [PreviewItem] {
        var results: [PreviewItem] = []
        attributedText.enumerateAttribute(
            .attachment,
            in: NSRange(location: 0, length: attributedText.length)
        ) { value, range, _ in
            guard let attachment = value as? ZNSTextAttachment,
                  let resolvedURL = AvatarImageLoader.resolveImageURL(attachment.imageURL),
                  resolvedURL.absoluteString.lowercased().contains("sticker") == false else {
                return
            }
            results.append(PreviewItem(range: range, imageURL: resolvedURL))
        }
        return results
    }

    private func characterIndex(in label: UILabel, tapPoint: CGPoint) -> Int? {
        guard let attributedText = label.attributedText, attributedText.length > 0 else { return nil }

        let textStorage = NSTextStorage(attributedString: attributedText)
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        let textRect = label.textRect(forBounds: label.bounds, limitedToNumberOfLines: label.numberOfLines)
        let textContainer = NSTextContainer(size: textRect.size)
        textContainer.lineFragmentPadding = 0
        textContainer.maximumNumberOfLines = label.numberOfLines
        textContainer.lineBreakMode = label.lineBreakMode
        layoutManager.addTextContainer(textContainer)

        let point = CGPoint(
            x: tapPoint.x - textRect.origin.x,
            y: tapPoint.y - textRect.origin.y
        )
        guard point.x >= 0,
              point.y >= 0,
              point.x <= textRect.width,
              point.y <= textRect.height,
              layoutManager.numberOfGlyphs > 0 else {
            return nil
        }

        let glyphIndex = layoutManager.glyphIndex(for: point, in: textContainer)
        guard glyphIndex < layoutManager.numberOfGlyphs else { return nil }

        let glyphRect = layoutManager.boundingRect(
            forGlyphRange: NSRange(location: glyphIndex, length: 1),
            in: textContainer
        )
        guard glyphRect.contains(point) else { return nil }

        let characterIndex = layoutManager.characterIndex(
            for: point,
            in: textContainer,
            fractionOfDistanceBetweenInsertionPoints: nil
        )
        guard characterIndex < attributedText.length else { return nil }
        return characterIndex
    }
}

private final class DetailPhotoBrowserPresenter: NSObject, JXPhotoBrowserDelegate {
    private let imageURLs: [URL]

    init(imageURLs: [URL]) {
        self.imageURLs = imageURLs
        super.init()
    }

    func present(from viewController: UIViewController, initialIndex: Int) {
        guard imageURLs.isEmpty == false else { return }

        let browser = JXPhotoBrowserViewController()
        browser.delegate = self
        browser.initialIndex = min(max(initialIndex, 0), imageURLs.count - 1)
        browser.transitionType = .fade
        browser.addOverlay(JXPageIndicatorOverlay())
        browser.present(from: viewController)
    }

    func numberOfItems(in browser: JXPhotoBrowserViewController) -> Int {
        imageURLs.count
    }

    func photoBrowser(
        _ browser: JXPhotoBrowserViewController,
        cellForItemAt index: Int,
        at indexPath: IndexPath
    ) -> JXPhotoBrowserAnyCell {
        browser.dequeueReusableCell(
            withReuseIdentifier: JXZoomImageCell.reuseIdentifier,
            for: indexPath
        ) as! JXZoomImageCell
    }

    func photoBrowser(_ browser: JXPhotoBrowserViewController, willDisplay cell: JXPhotoBrowserAnyCell, at index: Int) {
        guard let photoCell = cell as? JXZoomImageCell else { return }
        let imageURL = imageURLs[index]
        let requestKey = imageURL.absoluteString
        photoCell.imageView.image = nil
        photoCell.imageView.accessibilityIdentifier = requestKey
        DetailAttachmentDataSource.shared.loadImageForPreview(imageURL) { [weak photoCell] image in
            DispatchQueue.main.async {
                guard let photoCell else { return }
                guard photoCell.imageView.accessibilityIdentifier == requestKey else { return }
                photoCell.imageView.image = image
                photoCell.setNeedsLayout()
            }
        }
    }

    func photoBrowser(_ browser: JXPhotoBrowserViewController, didEndDisplaying cell: JXPhotoBrowserAnyCell, at index: Int) {
        guard let photoCell = cell as? JXZoomImageCell else { return }
        photoCell.imageView.accessibilityIdentifier = nil
        photoCell.imageView.image = nil
    }
}

private final class DetailAttachmentDataSource: NSObject, ZNSTextAttachmentDataSource {
    private struct ImagePayload {
        let data: Data
        let mimeType: String?
        let image: UIImage
        let isFallback: Bool
    }

    private typealias PayloadCompletion = (ImagePayload) -> Void

    static let shared = DetailAttachmentDataSource()
    static let didLoadNotification = Notification.Name("DetailAttachmentDataSource.didLoad")

    private enum Limits {
        static let maxPixelSide: CGFloat = 16_384
        static let fallbackSize = CGSize(width: 8, height: 8)
    }

    private let logger = Logger(subsystem: "com.nodeseek.app", category: "DetailAttachment")
    private let session: URLSession
    private let stateQueue = DispatchQueue(label: "com.nodeseek.app.detailattachment.state")
    private var payloadCache: [URL: ImagePayload] = [:]
    private var inFlightCallbacks: [URL: [PayloadCompletion]] = [:]

    private override init() {
        let configuration = URLSessionConfiguration.default
        configuration.httpCookieStorage = .shared
        configuration.httpShouldSetCookies = true
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 20
        self.session = URLSession(configuration: configuration)
        super.init()
    }

    func zNSTextAttachment(
        _ textAttachment: ZNSTextAttachment,
        loadImageURL imageURL: URL,
        completion: @escaping (Data, ZNSTextAttachmentDownloadedDataMIMEType?) -> Void
    ) {
        fetchPayload(for: imageURL) { payload in
            completion(payload.data, payload.mimeType)
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Self.didLoadNotification, object: nil)
            }
        }
    }

    func loadImageForPreview(_ imageURL: URL, completion: @escaping (UIImage?) -> Void) {
        fetchPayload(for: imageURL) { payload in
            completion(payload.image)
        }
    }

    private func fetchPayload(for imageURL: URL, completion: @escaping PayloadCompletion) {
        if let dataURLPayload = decodeDataURL(imageURL) {
            let image = UIImage(data: dataURLPayload.data) ?? Self.fallbackImage
            completion(ImagePayload(
                data: dataURLPayload.data,
                mimeType: dataURLPayload.mimeType,
                image: image,
                isFallback: image === Self.fallbackImage
            ))
            return
        }

        guard let resolvedURL = AvatarImageLoader.resolveImageURL(imageURL) else {
            logger.error("attachment URL 非法，使用兜底图 url=\(imageURL.absoluteString, privacy: .public)")
            completion(Self.fallbackPayload)
            return
        }

        if let cachedPayload = stateQueue.sync(execute: { payloadCache[resolvedURL] }) {
            completion(cachedPayload)
            return
        }

        let shouldStartRequest = stateQueue.sync { () -> Bool in
            if var callbacks = inFlightCallbacks[resolvedURL] {
                callbacks.append(completion)
                inFlightCallbacks[resolvedURL] = callbacks
                return false
            }
            inFlightCallbacks[resolvedURL] = [completion]
            return true
        }
        guard shouldStartRequest else { return }

        var request = URLRequest(url: resolvedURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.cachePolicy = .returnCacheDataElseLoad
        WebRequestFingerprint.applyImageHeaders(to: &request)

        session.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }
            let payload = self.validatePayload(
                resolvedURL: resolvedURL,
                data: data,
                mimeType: response?.mimeType,
                error: error
            )
            self.completePayload(for: resolvedURL, payload: payload)
        }.resume()
    }

    private func completePayload(for url: URL, payload: ImagePayload) {
        let callbacks: [PayloadCompletion] = stateQueue.sync {
            if payload.isFallback == false {
                payloadCache[url] = payload
            }
            return inFlightCallbacks.removeValue(forKey: url) ?? []
        }
        callbacks.forEach { $0(payload) }
    }

    private func validatePayload(
        resolvedURL: URL,
        data: Data?,
        mimeType: String?,
        error: Error?
    ) -> ImagePayload {
        guard let data else {
            logger.error(
                "attachment 下载失败，使用兜底图 url=\(resolvedURL.absoluteString, privacy: .public), error=\(error?.localizedDescription ?? "unknown", privacy: .public)"
            )
            return Self.fallbackPayload
        }

        if dataLooksLikeHTML(data) {
            logger.error(
                "attachment 返回HTML内容，使用兜底图 url=\(resolvedURL.absoluteString, privacy: .public), bytes=\(data.count, privacy: .public), snippet=\(self.snippet(from: data), privacy: .public)"
            )
            return Self.fallbackPayload
        }

        guard let image = UIImage(data: data) else {
            logger.error(
                "attachment 图片解码失败，使用兜底图 url=\(resolvedURL.absoluteString, privacy: .public), bytes=\(data.count, privacy: .public), mime=\(mimeType ?? "unknown", privacy: .public)"
            )
            return Self.fallbackPayload
        }

        let imageSize = image.size
        guard imageSize.width.isFinite,
              imageSize.height.isFinite,
              imageSize.width > 0,
              imageSize.height > 0,
              imageSize.width <= Limits.maxPixelSide,
              imageSize.height <= Limits.maxPixelSide else {
            logger.error(
                "attachment 图片尺寸异常，使用兜底图 url=\(resolvedURL.absoluteString, privacy: .public), size=\(NSCoder.string(for: imageSize), privacy: .public), bytes=\(data.count, privacy: .public), mime=\(mimeType ?? "unknown", privacy: .public)"
            )
            return Self.fallbackPayload
        }

        if let mimeType, mimeType.lowercased().hasPrefix("image/") == false {
            logger.warning(
                "attachment MIME非image但已解码成功，继续展示 url=\(resolvedURL.absoluteString, privacy: .public), mime=\(mimeType, privacy: .public)"
            )
        }

        logger.debug(
            "attachment 下载并校验通过 url=\(resolvedURL.absoluteString, privacy: .public), size=\(NSCoder.string(for: imageSize), privacy: .public), bytes=\(data.count, privacy: .public), mime=\(mimeType ?? "unknown", privacy: .public)"
        )
        return ImagePayload(
            data: data,
            mimeType: mimeType,
            image: image,
            isFallback: false
        )
    }

    private static let fallbackPNGData: Data = {
        let renderer = UIGraphicsImageRenderer(size: Limits.fallbackSize)
        let image = renderer.image { context in
            UIColor(white: 0.88, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: Limits.fallbackSize))
        }
        return image.pngData() ?? Data()
    }()

    private static let fallbackImage: UIImage = UIImage(data: fallbackPNGData) ?? UIImage()

    private static let fallbackPayload = ImagePayload(
        data: fallbackPNGData,
        mimeType: "image/png",
        image: fallbackImage,
        isFallback: true
    )

    private func dataLooksLikeHTML(_ data: Data) -> Bool {
        guard let prefix = String(data: data.prefix(256), encoding: .utf8)?
            .lowercased()
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ") else {
            return false
        }
        return prefix.contains("<html")
            || prefix.contains("<!doctype html")
            || prefix.contains("<body")
            || prefix.contains("challenge-platform")
            || prefix.contains("cf_chl")
    }

    private func snippet(from data: Data) -> String {
        String(data: data.prefix(120), encoding: .utf8)?
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            ?? ""
    }

    private func decodeDataURL(_ url: URL) -> (data: Data, mimeType: String?)? {
        let raw = url.absoluteString
        guard raw.lowercased().hasPrefix("data:"),
              let commaIndex = raw.firstIndex(of: ",") else {
            return nil
        }

        let header = String(raw[raw.startIndex..<commaIndex]).lowercased()
        let payloadStart = raw.index(after: commaIndex)
        let payload = String(raw[payloadStart...])

        guard header.contains(";base64"),
              let data = Data(base64Encoded: payload, options: .ignoreUnknownCharacters) else {
            return nil
        }

        let mimeType = header
            .replacingOccurrences(of: "data:", with: "")
            .components(separatedBy: ";")
            .first
        return (data, mimeType)
    }
}
