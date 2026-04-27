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
    private var posts: [PostSummary] = []
    
    var hasCompactTopButton: Bool {
        compactTopButton.superview != nil
    }
    
    // MARK: - UI Components
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let compactTopButton: UIButton = {
        let button = UIButton(type: .system)
        let image = UIImage(systemName: "line.3.horizontal")
        button.setImage(image, for: .normal)
        button.tintColor = .label
        button.backgroundColor = .secondarySystemBackground
        button.layer.cornerRadius = 16
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()

    private let loadMoreIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()

    private lazy var loadMoreContainer: UIView = {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 56))
        container.addSubview(loadMoreIndicator)
        NSLayoutConstraint.activate([
            loadMoreIndicator.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            loadMoreIndicator.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        return container
    }()
    
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
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(PostListTableViewCell.self, forCellReuseIdentifier: PostListTableViewCell.reuseIdentifier)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 84
        compactTopButton.addTarget(self, action: #selector(leftButtonTapped), for: .touchUpInside)
        view.addSubview(tableView)
        view.addSubview(compactTopButton)
        view.addSubview(loadingIndicator)

        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            compactTopButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 8),
            compactTopButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),
            compactTopButton.widthAnchor.constraint(equalToConstant: 32),
            compactTopButton.heightAnchor.constraint(equalToConstant: 32),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    // MARK: - Actions
    @objc private func leftButtonTapped() {
        // 功能后续补齐。
    }
}

// MARK: - View Protocol
extension PostListViewController: PostListViewProtocol {
    
    func showLoading() {
        loadingIndicator.startAnimating()
    }
    
    func hideLoading() {
        loadingIndicator.stopAnimating()
    }

    func showLoadingMore() {
        tableView.tableFooterView = loadMoreContainer
        loadMoreIndicator.startAnimating()
    }

    func hideLoadingMore() {
        loadMoreIndicator.stopAnimating()
        tableView.tableFooterView = UIView(frame: .zero)
    }
    
    func showError(message: String) {
        let alert = UIAlertController(title: "错误", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
    
    func render(posts: [PostSummary]) {
        self.posts = posts
        tableView.reloadData()
    }
}

extension PostListViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        posts.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: PostListTableViewCell.reuseIdentifier,
            for: indexPath
        ) as? PostListTableViewCell else {
            return UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        }
        let post = posts[indexPath.row]
        cell.configure(with: post)
        return cell
    }
}

extension PostListViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        presenter.didSelectPost(at: indexPath.row)
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        presenter.didApproachBottom(currentIndex: indexPath.row, totalCount: posts.count)
    }
}
