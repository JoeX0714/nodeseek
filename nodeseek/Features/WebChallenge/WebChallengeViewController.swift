//
//  WebChallengeViewController.swift
//  nodeseek
//
//  Created by Codex on 2026/4/27.
//

import UIKit
import WebKit

class WebChallengeViewController: UIViewController {
    
    // MARK: - Properties
    private let presenter: WebChallengePresenterProtocol
    
    // MARK: - UI Components
    private let webView = WKWebView(frame: .zero)
    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    // MARK: - Initialization
    init(presenter: WebChallengePresenterProtocol) {
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
    
    // MARK: - Setup UI
    private func setupUI() {
        title = "网页验证"
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "完成",
            style: .prominent,
            target: self,
            action: #selector(didTapDone)
        )
        view.backgroundColor = .systemBackground
        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        view.addSubview(loadingIndicator)
        
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    @objc private func didTapDone() {
        presenter.didTapDone()
    }
}

// MARK: - View Protocol
extension WebChallengeViewController: WebChallengeViewProtocol {
    
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
    
    func load(url: URL) {
        webView.load(URLRequest(url: url))
    }
}

// MARK: - WKNavigationDelegate
extension WebChallengeViewController: WKNavigationDelegate {

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        showLoading()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        hideLoading()
        webView.evaluateJavaScript("document.documentElement.outerHTML") { [weak self, weak webView] result, _ in
            let html = result as? String ?? ""
            self?.presenter.webViewDidFinishNavigation(
                pageTitle: webView?.title,
                html: html,
                url: webView?.url
            )
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        hideLoading()
        showError(message: error.localizedDescription)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        hideLoading()
        showError(message: error.localizedDescription)
    }
}
