//
//  DetailInlineVideoStickerView.swift
//  nodeseek
//
//  Created by Codex on 2026/4/30.
//

import AVFoundation
import UIKit

final class DetailInlineVideoStickerView: UIView {
    private let videoURL: URL
    private let thumbnailView = UIImageView()
    private let playButton = UIButton(type: .system)
    private let playerLayer = AVPlayerLayer()
    private var thumbnailToken: UUID?
    private var thumbnailGenerator: AVAssetImageGenerator?
    private var isPlaying = false

    init(frame: CGRect, videoURL: URL) {
        self.videoURL = videoURL
        super.init(frame: frame)

        backgroundColor = .secondarySystemFill
        clipsToBounds = true
        isUserInteractionEnabled = true

        thumbnailView.contentMode = .scaleAspectFill
        thumbnailView.clipsToBounds = true
        addSubview(thumbnailView)

        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.isHidden = true
        layer.addSublayer(playerLayer)

        playButton.tintColor = .white
        playButton.backgroundColor = UIColor.black.withAlphaComponent(0.38)
        playButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
        playButton.accessibilityLabel = "播放贴纸"
        playButton.isUserInteractionEnabled = false
        addSubview(playButton)

        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        thumbnailView.frame = bounds
        playerLayer.frame = bounds
        let side = min(bounds.width, bounds.height, 30)
        playButton.frame = CGRect(
            x: (bounds.width - side) / 2,
            y: (bounds.height - side) / 2,
            width: side,
            height: side
        )
        playButton.layer.cornerRadius = side / 2
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()

        guard superview != nil else {
            StickerVideoPlaybackCoordinator.shared.stop(owner: self)
            thumbnailToken = nil
            thumbnailGenerator?.cancelAllCGImageGeneration()
            thumbnailGenerator = nil
            return
        }

        loadThumbnailIfNeeded()
    }

    func playbackCoordinatorDidStop() {
        isPlaying = false
        playerLayer.player = nil
        playerLayer.isHidden = true
        thumbnailView.isHidden = false
        playButton.isHidden = false
    }

    private func loadThumbnailIfNeeded() {
        guard thumbnailToken == nil,
              thumbnailView.image == nil,
              let resolvedURL = AvatarImageLoader.resolveImageURL(videoURL) else { return }

        let token = UUID()
        thumbnailToken = token
        let asset = AVURLAsset(url: resolvedURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 180, height: 180)
        thumbnailGenerator = generator
        generator.generateCGImageAsynchronously(for: .zero) { [weak self] cgImage, _, _ in
            DispatchQueue.main.async {
                guard let self, self.thumbnailToken == token else { return }
                self.thumbnailGenerator = nil
                self.thumbnailView.image = cgImage.map(UIImage.init(cgImage:))
            }
        }
    }

    @objc
    private func handleTap() {
        if isPlaying {
            StickerVideoPlaybackCoordinator.shared.stop(owner: self)
            return
        }

        guard let resolvedURL = AvatarImageLoader.resolveImageURL(videoURL) else { return }
        isPlaying = true
        playerLayer.isHidden = false
        thumbnailView.isHidden = true
        playButton.isHidden = true
        StickerVideoPlaybackCoordinator.shared.play(resolvedURL, in: playerLayer, owner: self)
    }
}

private final class StickerVideoPlaybackCoordinator {
    static let shared = StickerVideoPlaybackCoordinator()

    private let player = AVPlayer()
    private weak var activeView: DetailInlineVideoStickerView?
    private weak var activeLayer: AVPlayerLayer?
    private var endObserver: NSObjectProtocol?

    private init() {
        player.isMuted = true
    }

    func play(_ url: URL, in layer: AVPlayerLayer, owner: DetailInlineVideoStickerView) {
        if activeView !== owner {
            activeView?.playbackCoordinatorDidStop()
            activeLayer?.player = nil
        }

        removeEndObserver()
        let item = AVPlayerItem(url: url)
        activeView = owner
        activeLayer = layer
        layer.player = player
        player.replaceCurrentItem(with: item)
        player.isMuted = true
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.player.seek(to: .zero)
            self?.player.play()
        }
        player.play()
    }

    func stop(owner: DetailInlineVideoStickerView) {
        guard activeView === owner else { return }
        stopCurrent()
    }

    private func stopCurrent() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        removeEndObserver()
        let view = activeView
        activeView = nil
        activeLayer?.player = nil
        activeLayer = nil
        view?.playbackCoordinatorDidStop()
    }

    private func removeEndObserver() {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
    }
}
