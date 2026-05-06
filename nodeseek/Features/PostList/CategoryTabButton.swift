//
//  CategoryTabButton.swift
//  nodeseek
//

import UIKit

final class CategoryTabButton: UIButton {
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
        var buttonConfiguration = UIButton.Configuration.plain()
        buttonConfiguration.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 3, bottom: 0, trailing: 3)
        buttonConfiguration.baseForegroundColor = .secondaryLabel
        configuration = buttonConfiguration
        applySelectedStyle(isSelected: false)
        addSubview(indicatorView)
        NSLayoutConstraint.activate([
            indicatorView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 1),
            indicatorView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -1),
            indicatorView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -1),
            indicatorView.heightAnchor.constraint(equalToConstant: 3)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func applySelectedStyle(isSelected: Bool) {
        let font = isSelected ? UIFont.systemFont(ofSize: 17, weight: .semibold) : .systemFont(ofSize: 17, weight: .regular)
        var buttonConfiguration = configuration ?? UIButton.Configuration.plain()
        buttonConfiguration.baseForegroundColor = isSelected ? .label : .secondaryLabel
        buttonConfiguration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = font
            return outgoing
        }
        configuration = buttonConfiguration
        indicatorView.isHidden = !isSelected
    }
}
