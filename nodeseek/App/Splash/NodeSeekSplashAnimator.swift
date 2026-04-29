//
//  NodeSeekSplashAnimator.swift
//  nodeseek
//

import UIKit

@MainActor
final class NodeSeekSplashAnimator: NSObject {
    private static let debugAnimationTimeScale: CFTimeInterval = 2.4

    private weak var containerView: UIView?
    private let reduceMotion: Bool
    private let animationDuration: CFTimeInterval

    private let backgroundLayer = CALayer()
    private let nLeftStrokeLayer = CAShapeLayer()
    private let nDiagonalStrokeLayer = CAShapeLayer()
    private let nFinalStrokeLayer = CAShapeLayer()
    private let sLayer = CAShapeLayer()
    private let dotLayer = CAShapeLayer()
    private let lightSweepLayer = CAGradientLayer()
    private let finalLogoLayer = CALayer()
    private var completion: (() -> Void)?

    init(
        reduceMotion: Bool = UIAccessibility.isReduceMotionEnabled,
        animationDuration: CFTimeInterval = 1.35
    ) {
        self.reduceMotion = reduceMotion
        self.animationDuration = animationDuration
        super.init()
    }

    func install(in view: UIView) {
        containerView = view
        configureLayerNames()
        layoutLayers(in: view.bounds)
        view.layer.addSublayer(backgroundLayer)
        view.layer.addSublayer(nLeftStrokeLayer)
        view.layer.addSublayer(nDiagonalStrokeLayer)
        view.layer.addSublayer(nFinalStrokeLayer)
        view.layer.addSublayer(sLayer)
        view.layer.addSublayer(dotLayer)
        view.layer.addSublayer(lightSweepLayer)
        view.layer.addSublayer(finalLogoLayer)
    }

    func play(completion: @escaping () -> Void) {
        self.completion = completion

        guard !reduceMotion else {
            finalLogoLayer.opacity = 1
            nLeftStrokeLayer.opacity = 0
            nDiagonalStrokeLayer.opacity = 0
            nFinalStrokeLayer.opacity = 0
            sLayer.opacity = 0
            dotLayer.opacity = 0
            lightSweepLayer.opacity = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                completion()
            }
            return
        }

        startAnimationTimeline()
    }

    func relayout() {
        guard let containerView else { return }
        layoutLayers(in: containerView.bounds)
    }
}

private extension NodeSeekSplashAnimator {
    func configureLayerNames() {
        backgroundLayer.name = "splash.background"
        nLeftStrokeLayer.name = "splash.n.leftStroke"
        nDiagonalStrokeLayer.name = "splash.n.diagonalStroke"
        nFinalStrokeLayer.name = "splash.n.finalStroke"
        sLayer.name = "splash.s"
        dotLayer.name = "splash.dot"
        lightSweepLayer.name = "splash.lightSweep"
        finalLogoLayer.name = "splash.finalLogo"
    }

    func layoutLayers(in bounds: CGRect) {
        backgroundLayer.frame = bounds
        backgroundLayer.backgroundColor = UIColor.white.cgColor

        let logoFrame = aspectFitFrame(for: NodeSeekSplashVector.canvasSize, in: bounds)
        configureShapeLayer(nLeftStrokeLayer, frame: logoFrame, path: NodeSeekSplashVector.wordmarkPath(), color: NodeSeekSplashVector.wordmarkColor)
        configureShapeLayer(nDiagonalStrokeLayer, frame: logoFrame, path: NodeSeekSplashVector.wordmarkPath(), color: NodeSeekSplashVector.wordmarkColor)
        configureShapeLayer(nFinalStrokeLayer, frame: logoFrame, path: NodeSeekSplashVector.wordmarkPath(), color: NodeSeekSplashVector.wordmarkColor)
        configureShapeLayer(sLayer, frame: logoFrame, path: NodeSeekSplashVector.wordmarkPath(), color: NodeSeekSplashVector.wordmarkColor)
        configureDotLayer(in: logoFrame)

        nLeftStrokeLayer.mask = strokeRevealMask(
            name: "splash.n.leftStrokeMask",
            path: NodeSeekSplashVector.nLeftStrokeRevealPath(),
            lineWidth: 104,
            in: logoFrame
        )
        nDiagonalStrokeLayer.mask = strokeRevealMask(
            name: "splash.n.diagonalStrokeMask",
            path: NodeSeekSplashVector.nDiagonalStrokeRevealPath(),
            lineWidth: 128,
            in: logoFrame
        )
        nFinalStrokeLayer.mask = strokeRevealMask(
            name: "splash.n.finalStrokeMask",
            path: NodeSeekSplashVector.nFinalStrokeRevealPath(),
            lineWidth: 104,
            in: logoFrame
        )
        sLayer.mask = strokeRevealMask(
            name: "splash.s.strokeMask",
            path: NodeSeekSplashVector.sStrokeRevealPath(),
            lineWidth: 128,
            in: logoFrame
        )

        configureLightSweep(in: logoFrame)

        finalLogoLayer.frame = logoFrame
        finalLogoLayer.contentsGravity = .resizeAspect
        finalLogoLayer.contentsScale = UIScreen.main.scale
        finalLogoLayer.opacity = 0
        finalLogoLayer.contents = UIImage(named: "SplashFinalLogo")?.cgImage
    }

    func configureShapeLayer(_ layer: CAShapeLayer, frame: CGRect, path: CGPath, color: UIColor) {
        layer.frame = frame
        let scale = frame.width / NodeSeekSplashVector.canvasSize.width
        var transform = CGAffineTransform(scaleX: scale, y: scale)
        layer.path = path.copy(using: &transform)
        layer.fillColor = color.cgColor
        layer.fillRule = .evenOdd
        layer.contentsScale = UIScreen.main.scale
    }

    func configureDotLayer(in logoFrame: CGRect) {
        let scale = logoFrame.width / NodeSeekSplashVector.canvasSize.width
        let bounds = NodeSeekSplashVector.dotBounds
        let dotFrame = CGRect(
            x: logoFrame.minX + bounds.minX * scale,
            y: logoFrame.minY + bounds.minY * scale,
            width: bounds.width * scale,
            height: bounds.height * scale
        )
        dotLayer.frame = dotFrame

        var transform = CGAffineTransform(scaleX: scale, y: scale)
            .translatedBy(x: -bounds.minX, y: -bounds.minY)
        dotLayer.path = NodeSeekSplashVector.accentPath().copy(using: &transform)
        dotLayer.fillColor = NodeSeekSplashVector.accentColor.cgColor
        dotLayer.fillRule = .evenOdd
        dotLayer.contentsScale = UIScreen.main.scale
    }

    func configureLightSweep(in logoFrame: CGRect) {
        let scale = logoFrame.width / NodeSeekSplashVector.canvasSize.width
        let bounds = NodeSeekSplashVector.logoBounds
        lightSweepLayer.frame = CGRect(
            x: logoFrame.minX + bounds.minX * scale,
            y: logoFrame.minY + bounds.minY * scale,
            width: bounds.width * scale,
            height: bounds.height * scale
        )
        lightSweepLayer.colors = [
            UIColor.white.withAlphaComponent(0).cgColor,
            UIColor.white.withAlphaComponent(0.62).cgColor,
            UIColor.white.withAlphaComponent(0).cgColor
        ]
        lightSweepLayer.locations = [0, 0.5, 1]
        lightSweepLayer.startPoint = CGPoint(x: 0, y: 0.5)
        lightSweepLayer.endPoint = CGPoint(x: 1, y: 0.5)
        lightSweepLayer.opacity = 0
    }

    func strokeRevealMask(name: String, path: CGPath, lineWidth: CGFloat, in logoFrame: CGRect) -> CAShapeLayer {
        let scale = logoFrame.width / NodeSeekSplashVector.canvasSize.width
        let mask = CAShapeLayer()
        mask.name = name
        mask.frame = CGRect(origin: .zero, size: logoFrame.size)
        var transform = CGAffineTransform(scaleX: scale, y: scale)
        mask.path = path.copy(using: &transform)
        mask.fillColor = UIColor.clear.cgColor
        mask.strokeColor = UIColor.black.cgColor
        mask.lineWidth = lineWidth * scale
        mask.lineCap = .round
        mask.lineJoin = .round
        mask.strokeStart = 0
        mask.strokeEnd = 0
        return mask
    }

    func aspectFitFrame(for sourceSize: CGSize, in bounds: CGRect) -> CGRect {
        let scale = min(bounds.width / sourceSize.width, bounds.height / sourceSize.height)
        let size = CGSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
        return CGRect(
            x: bounds.midX - size.width / 2,
            y: bounds.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }
}

private extension NodeSeekSplashAnimator {
    func startAnimationTimeline() {
        dotLayer.opacity = 0
        lightSweepLayer.opacity = 1
        finalLogoLayer.opacity = 0

        let nDuration = scaledTime(0.58)
        let nLeftDuration = nDuration * 0.31
        let nDiagonalDuration = nDuration * 0.39
        let nFinalDuration = nDuration - nLeftDuration - nDiagonalDuration

        animateStrokeReveal(mask: nLeftStrokeLayer.mask, beginTime: scaledTime(0.00), duration: nLeftDuration)
        animateStrokeReveal(mask: nDiagonalStrokeLayer.mask, beginTime: nLeftDuration, duration: nDiagonalDuration)
        animateStrokeReveal(mask: nFinalStrokeLayer.mask, beginTime: nLeftDuration + nDiagonalDuration, duration: nFinalDuration)
        animateStrokeReveal(mask: sLayer.mask, beginTime: nDuration, duration: scaledTime(0.47))
        animateLightSweep(beginTime: scaledTime(0.28), duration: scaledTime(0.57))
        animateDotPop(beginTime: scaledTime(1.02), duration: scaledTime(0.26))

        DispatchQueue.main.asyncAfter(deadline: .now() + scaledTime(animationDuration)) { [weak self] in
            guard let self else { return }
            self.pinModelLayersToFinalFrame()
            self.completion?()
            self.completion = nil
        }
    }

    func scaledTime(_ time: CFTimeInterval) -> CFTimeInterval {
        time * Self.debugAnimationTimeScale
    }

    func pinModelLayersToFinalFrame() {
        nLeftStrokeLayer.opacity = 1
        nDiagonalStrokeLayer.opacity = 1
        nFinalStrokeLayer.opacity = 1
        sLayer.opacity = 1
        dotLayer.opacity = 1
        lightSweepLayer.opacity = 0
        finalLogoLayer.opacity = 0
        revealStrokeMask(nLeftStrokeLayer.mask)
        revealStrokeMask(nDiagonalStrokeLayer.mask)
        revealStrokeMask(nFinalStrokeLayer.mask)
        revealStrokeMask(sLayer.mask)
    }

    func animateStrokeReveal(mask: CALayer?, beginTime: CFTimeInterval, duration: CFTimeInterval) {
        guard let mask = mask as? CAShapeLayer else { return }
        mask.strokeEnd = 0

        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.fromValue = 0
        animation.toValue = 1
        animation.beginTime = CACurrentMediaTime() + beginTime
        animation.duration = duration
        animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        animation.fillMode = .both
        animation.isRemovedOnCompletion = false
        mask.add(animation, forKey: "strokeReveal")
    }

    func revealStrokeMask(_ mask: CALayer?) {
        guard let mask = mask as? CAShapeLayer else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        mask.strokeEnd = 1
        mask.removeAnimation(forKey: "strokeReveal")
        CATransaction.commit()
    }

    func animateLightSweep(beginTime: CFTimeInterval, duration: CFTimeInterval) {
        let travel = lightSweepLayer.bounds.width
        let animation = CABasicAnimation(keyPath: "transform.translation.x")
        animation.fromValue = -travel
        animation.toValue = travel
        animation.beginTime = CACurrentMediaTime() + beginTime
        animation.duration = duration
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        animation.fillMode = .backwards
        animation.isRemovedOnCompletion = true
        lightSweepLayer.add(animation, forKey: "lightSweep")

        let opacity = CAKeyframeAnimation(keyPath: "opacity")
        opacity.values = [0, 1, 0]
        opacity.keyTimes = [0, 0.45, 1]
        opacity.beginTime = CACurrentMediaTime() + beginTime
        opacity.duration = duration
        opacity.fillMode = .forwards
        opacity.isRemovedOnCompletion = false
        lightSweepLayer.add(opacity, forKey: "lightSweepOpacity")
    }

    func animateDotPop(beginTime: CFTimeInterval, duration: CFTimeInterval) {
        dotLayer.opacity = 1

        let opacity = CAKeyframeAnimation(keyPath: "opacity")
        opacity.values = [0, 1, 1]
        opacity.keyTimes = [0, 0.25, 1]
        opacity.beginTime = CACurrentMediaTime() + beginTime
        opacity.duration = duration
        opacity.fillMode = .backwards
        opacity.isRemovedOnCompletion = true
        dotLayer.add(opacity, forKey: "dotOpacity")

        let scale = CAKeyframeAnimation(keyPath: "transform.scale")
        scale.values = [0.72, 1.12, 1.0]
        scale.keyTimes = [0, 0.62, 1]
        scale.beginTime = CACurrentMediaTime() + beginTime
        scale.duration = duration
        scale.timingFunctions = [
            CAMediaTimingFunction(name: .easeOut),
            CAMediaTimingFunction(name: .easeInEaseOut)
        ]
        dotLayer.add(scale, forKey: "dotPop")
    }

}
