//
//  PostListViewController.swift
//  nodeseek
//
//  Created by Codex on 2026/4/27.
//

import UIKit

class PostListViewController: UIViewController {
    
    // MARK: - Properties
    private let presenter: PostListPresenterProtocol
    private var categories: [PostListCategory] = []
    private var selectedCategory: PostListCategory = .all
    private var currentSortMode: PostListSortMode = .replyTime
    private var sortToggleWidthConstraint: NSLayoutConstraint?
    private var sortToggleTrailingConstraint: NSLayoutConstraint?
    private var sortToggleCollapseWorkItem: DispatchWorkItem?
    private var isSortToggleExpanded = false
    
    var hasCompactTopButton: Bool {
        compactTopButton.superview != nil
    }
    
    // MARK: - UI Components
    private let pageContainerView = PostTexturePageContainerView()
    private let compactTopButton: UIButton = {
        let button = UIButton(type: .system)
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        let image = UIImage(systemName: "line.3.horizontal.circle", withConfiguration: symbolConfig)
            ?? UIImage(systemName: "line.3.horizontal", withConfiguration: symbolConfig)
        button.setImage(image, for: .normal)
        button.tintColor = .label
        button.backgroundColor = .tertiarySystemBackground
        button.layer.cornerRadius = 10
        button.layer.borderWidth = 0.5
        button.layer.borderColor = UIColor.separator.cgColor
        button.adjustsImageWhenHighlighted = false
        button.configurationUpdateHandler = { updateButton in
            updateButton.alpha = updateButton.isHighlighted ? 0.72 : 1.0
        }
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let sortToggleButton: UIButton = {
        let button = UIButton(type: .system)
        var configuration = UIButton.Configuration.tinted()
        configuration.baseForegroundColor = .secondaryLabel
        configuration.baseBackgroundColor = .tertiarySystemFill
        configuration.cornerStyle = .capsule
        configuration.imagePadding = 0
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
        configuration.titleLineBreakMode = .byTruncatingTail
        button.configuration = configuration
        button.accessibilityIdentifier = "post-list-sort-toggle"
        button.titleLabel?.font = .systemFont(ofSize: 12, weight: .medium)
        button.titleLabel?.numberOfLines = 1
        button.titleLabel?.lineBreakMode = .byTruncatingTail
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.9
        button.backgroundColor = .clear
        button.layer.cornerRadius = 17
        button.layer.borderWidth = 0.5
        button.layer.borderColor = UIColor.separator.withAlphaComponent(0.55).cgColor
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.08
        button.layer.shadowRadius = 8
        button.layer.shadowOffset = CGSize(width: 0, height: 3)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    private let tabScrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()

    private let tabStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .fill
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private var tabButtons: [PostListCategory: CategoryTabButton] = [:]
    
    // MARK: - Initialization
    init(presenter: PostListPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        presenter.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    // MARK: - Setup UI
    private func setupUI() {
        navigationItem.title = nil
        navigationItem.leftBarButtonItem = nil
        
        view.backgroundColor = .systemBackground
        pageContainerView.translatesAutoresizingMaskIntoConstraints = false
        pageContainerView.delegate = self
        pageContainerView.attach(to: self)
        compactTopButton.addTarget(self, action: #selector(leftButtonTapped), for: .touchUpInside)
        sortToggleButton.addTarget(self, action: #selector(sortToggleButtonTapped), for: .touchUpInside)
        view.addSubview(pageContainerView)
        view.addSubview(compactTopButton)
        view.addSubview(sortToggleButton)
        view.addSubview(tabScrollView)
        view.addSubview(loadingIndicator)
        tabScrollView.addSubview(tabStackView)

        let sortToggleTrailingConstraint = sortToggleButton.trailingAnchor.constraint(
            equalTo: view.safeAreaLayoutGuide.trailingAnchor,
            constant: SortToggleLayout.collapsedTrailing
        )
        let sortToggleWidthConstraint = sortToggleButton.widthAnchor.constraint(
            equalToConstant: SortToggleLayout.collapsedWidth
        )
        self.sortToggleTrailingConstraint = sortToggleTrailingConstraint
        self.sortToggleWidthConstraint = sortToggleWidthConstraint

        NSLayoutConstraint.activate([
            pageContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pageContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pageContainerView.topAnchor.constraint(equalTo: tabScrollView.bottomAnchor, constant: 6),
            pageContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            compactTopButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 8),
            compactTopButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),
            compactTopButton.widthAnchor.constraint(equalToConstant: 36),
            compactTopButton.heightAnchor.constraint(equalToConstant: 36),

            sortToggleTrailingConstraint,
            sortToggleButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -18),
            sortToggleWidthConstraint,
            sortToggleButton.heightAnchor.constraint(equalToConstant: 34),

            tabScrollView.leadingAnchor.constraint(equalTo: compactTopButton.trailingAnchor, constant: 8),
            tabScrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -8),
            tabScrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),
            tabScrollView.heightAnchor.constraint(equalToConstant: 36),

            tabStackView.leadingAnchor.constraint(equalTo: tabScrollView.contentLayoutGuide.leadingAnchor),
            tabStackView.trailingAnchor.constraint(equalTo: tabScrollView.contentLayoutGuide.trailingAnchor),
            tabStackView.topAnchor.constraint(equalTo: tabScrollView.contentLayoutGuide.topAnchor),
            tabStackView.bottomAnchor.constraint(equalTo: tabScrollView.contentLayoutGuide.bottomAnchor),
            tabStackView.heightAnchor.constraint(equalTo: tabScrollView.frameLayoutGuide.heightAnchor),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        applySortTogglePresentation(expanded: false)
    }
    
    // MARK: - Actions
    @objc private func leftButtonTapped() {
        // 功能后续补齐。
    }

    @objc private func sortToggleButtonTapped() {
        setSortToggleExpanded(true, animated: true)
        presenter.didToggleSortMode()
        pageContainerView.scrollToTop(for: selectedCategory, animated: false)
        scheduleSortToggleCollapse()
    }

    @objc private func categoryButtonTapped(_ sender: CategoryTabButton) {
        guard let category = sender.category else { return }
        guard category != selectedCategory else { return }
        selectedCategory = category
        applySelectedCategory(category, syncPage: true, pageAnimated: true)
        presenter.didSelectCategory(category)
    }

    private func rebuildCategoryButtons() {
        tabButtons = [:]
        tabStackView.arrangedSubviews.forEach { subview in
            tabStackView.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }

        for category in categories {
            let button = CategoryTabButton()
            button.category = category
            button.setTitle(category.title, for: .normal)
            button.addTarget(self, action: #selector(categoryButtonTapped(_:)), for: .touchUpInside)
            tabStackView.addArrangedSubview(button)
            tabButtons[category] = button
        }
    }

    private func applySelectedCategory(_ selected: PostListCategory, syncPage: Bool, pageAnimated: Bool) {
        for (category, button) in tabButtons {
            button.applySelectedStyle(isSelected: category == selected)
        }

        if let selectedButton = tabButtons[selected] {
            let rect = selectedButton.convert(selectedButton.bounds, to: tabScrollView)
            tabScrollView.scrollRectToVisible(rect.insetBy(dx: -16, dy: 0), animated: true)
        }

        if syncPage {
            pageContainerView.setCurrentCategory(selected, animated: pageAnimated)
        }
    }

    private func scheduleSortToggleCollapse() {
        sortToggleCollapseWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.setSortToggleExpanded(false, animated: true)
        }
        sortToggleCollapseWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.35, execute: workItem)
    }

    private func setSortToggleExpanded(_ expanded: Bool, animated: Bool) {
        sortToggleCollapseWorkItem?.cancel()
        sortToggleCollapseWorkItem = nil
        isSortToggleExpanded = expanded
        applySortTogglePresentation(expanded: expanded)
        sortToggleWidthConstraint?.constant = expanded ? SortToggleLayout.expandedWidth : SortToggleLayout.collapsedWidth
        sortToggleTrailingConstraint?.constant = expanded ? SortToggleLayout.expandedTrailing : SortToggleLayout.collapsedTrailing

        let animations: () -> Void = { [weak self] in
            self?.view.layoutIfNeeded()
        }
        guard animated else {
            animations()
            return
        }
        UIView.animate(
            withDuration: 0.28,
            delay: 0,
            usingSpringWithDamping: 0.82,
            initialSpringVelocity: 0.35,
            options: [.allowUserInteraction, .beginFromCurrentState],
            animations: animations
        )
    }

    private func applySortTogglePresentation(expanded: Bool) {
        let symbolConfiguration = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        let image = UIImage(systemName: currentSortMode.symbolName, withConfiguration: symbolConfiguration)
        sortToggleButton.setImage(image, for: .normal)
        sortToggleButton.setTitle(expanded ? currentSortMode.buttonTitle : nil, for: .normal)
        sortToggleButton.titleLabel?.font = .systemFont(ofSize: 12, weight: .medium)
        sortToggleButton.titleLabel?.numberOfLines = 1
        sortToggleButton.titleLabel?.lineBreakMode = .byTruncatingTail
        sortToggleButton.titleLabel?.adjustsFontSizeToFitWidth = true
        sortToggleButton.titleLabel?.minimumScaleFactor = 0.9

        var configuration = sortToggleButton.configuration ?? UIButton.Configuration.tinted()
        configuration.image = image
        configuration.title = expanded ? currentSortMode.buttonTitle : nil
        configuration.imagePadding = expanded ? 3 : 0
        configuration.contentInsets = expanded
            ? NSDirectionalEdgeInsets(top: 6, leading: 9, bottom: 6, trailing: 10)
            : NSDirectionalEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
        configuration.titleLineBreakMode = .byTruncatingTail
        sortToggleButton.configuration = configuration
        sortToggleButton.accessibilityLabel = currentSortMode.accessibilityTitle
    }
}

// MARK: - View Protocol
extension PostListViewController: PostListViewProtocol {
    
    func showLoading() {
        pageContainerView.showLoadingSkeleton(for: selectedCategory)
        loadingIndicator.stopAnimating()
    }
    
    func hideLoading() {
        pageContainerView.hideLoadingSkeleton(for: selectedCategory)
        loadingIndicator.stopAnimating()
    }

    func showRefreshing() {
        pageContainerView.showRefreshing(for: selectedCategory)
    }

    func hideRefreshing() {
        pageContainerView.hideRefreshing(for: selectedCategory)
    }

    func showLoadingMore() {
        pageContainerView.showLoadingMore(for: selectedCategory)
    }

    func hideLoadingMore() {
        pageContainerView.hideLoadingMore(for: selectedCategory)
    }
    
    func showError(message: String) {
        let alert = UIAlertController(title: "错误", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }

    func renderCategories(_ categories: [PostListCategory], selected: PostListCategory) {
        let categoriesChanged = categories != self.categories
        if categoriesChanged {
            self.categories = categories
            rebuildCategoryButtons()
            pageContainerView.configure(categories: categories)
        }
        selectedCategory = selected
        applySelectedCategory(selected, syncPage: categoriesChanged, pageAnimated: false)
    }

    func renderSortMode(_ sortMode: PostListSortMode) {
        currentSortMode = sortMode
        applySortTogglePresentation(expanded: isSortToggleExpanded)
    }
    
    func render(posts: [PostSummary]) {
        pageContainerView.setPosts(posts, for: selectedCategory)
    }
}

private enum SortToggleLayout {
    static let collapsedWidth: CGFloat = 46
    static let expandedWidth: CGFloat = 126
    static let collapsedTrailing: CGFloat = 10
    static let expandedTrailing: CGFloat = -18
}

private extension PostListSortMode {
    var symbolName: String {
        switch self {
        case .postTime:
            return "clock.fill"
        case .replyTime:
            return "clock.arrow.trianglehead.counterclockwise.rotate.90"
        }
    }
}

private final class CategoryTabButton: UIButton {
    var category: PostListCategory?
    private let indicatorView: UIView = {
        let view = UIView()
        view.backgroundColor = .label
        view.layer.cornerRadius = 1
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        contentEdgeInsets = UIEdgeInsets(top: 0, left: 4, bottom: 0, right: 4)
        titleLabel?.font = .systemFont(ofSize: 16, weight: .regular)
        setTitleColor(.secondaryLabel, for: .normal)
        addSubview(indicatorView)
        NSLayoutConstraint.activate([
            indicatorView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            indicatorView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
            indicatorView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -1),
            indicatorView.heightAnchor.constraint(equalToConstant: 2)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func applySelectedStyle(isSelected: Bool) {
        titleLabel?.font = isSelected ? .systemFont(ofSize: 16, weight: .semibold) : .systemFont(ofSize: 16, weight: .regular)
        setTitleColor(isSelected ? .label : .secondaryLabel, for: .normal)
        indicatorView.isHidden = !isSelected
    }
}

extension PostListViewController: PostTexturePageContainerViewDelegate {
    func postTexturePageContainerView(
        _ containerView: PostTexturePageContainerView,
        didSelectPostAt index: Int,
        category: PostListCategory
    ) {
        if category != selectedCategory {
            selectedCategory = category
            applySelectedCategory(category, syncPage: false, pageAnimated: false)
            presenter.didSelectCategory(category)
        }
        presenter.didSelectPost(at: index)
    }

    func postTexturePageContainerView(
        _ containerView: PostTexturePageContainerView,
        didApproachBottomAt index: Int,
        totalCount: Int,
        category: PostListCategory
    ) {
        if category != selectedCategory {
            selectedCategory = category
            applySelectedCategory(category, syncPage: false, pageAnimated: false)
            presenter.didSelectCategory(category)
        }
        presenter.didApproachBottom(currentIndex: index, totalCount: totalCount)
    }

    func postTexturePageContainerViewDidRequestRefresh(
        _ containerView: PostTexturePageContainerView,
        category: PostListCategory
    ) {
        if category != selectedCategory {
            selectedCategory = category
            applySelectedCategory(category, syncPage: false, pageAnimated: false)
            presenter.didSelectCategory(category)
        }
        presenter.didPullToRefresh()
    }

    func postTexturePageContainerView(_ containerView: PostTexturePageContainerView, didScrollTo category: PostListCategory) {
        guard category != selectedCategory else { return }
        selectedCategory = category
        applySelectedCategory(category, syncPage: false, pageAnimated: false)
        presenter.didSelectCategory(category)
    }
}
