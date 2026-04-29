//
//  NodeSeekSplashAnimatorTests.swift
//  nodeseekTests
//

import Testing
import UIKit
@testable import nodeseek

@MainActor
struct NodeSeekSplashAnimatorTests {
    @Test func animatorInstallsExpectedLogoLayers() {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let animator = NodeSeekSplashAnimator(reduceMotion: false)

        animator.install(in: container)

        let layerNames = container.layer.sublayers?.compactMap(\.name) ?? []
        #expect(layerNames.contains("splash.background"))
        #expect(layerNames.contains("splash.n.leftStroke"))
        #expect(layerNames.contains("splash.n.diagonalStroke"))
        #expect(layerNames.contains("splash.n.finalStroke"))
        #expect(layerNames.contains("splash.s"))
        #expect(layerNames.contains("splash.dot"))
        #expect(layerNames.contains("splash.lightSweep"))
        #expect(layerNames.contains("splash.finalLogo"))
    }

    @Test func animatorUsesStrokeMasksForHandwrittenReveal() {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let animator = NodeSeekSplashAnimator(reduceMotion: false)

        animator.install(in: container)

        let layers = container.layer.sublayers ?? []
        let nLeftStrokeLayer = layers.first { $0.name == "splash.n.leftStroke" }
        let nDiagonalStrokeLayer = layers.first { $0.name == "splash.n.diagonalStroke" }
        let nFinalStrokeLayer = layers.first { $0.name == "splash.n.finalStroke" }
        let sLayer = layers.first { $0.name == "splash.s" }

        #expect(nLeftStrokeLayer?.mask is CAShapeLayer)
        #expect(nDiagonalStrokeLayer?.mask is CAShapeLayer)
        #expect(nFinalStrokeLayer?.mask is CAShapeLayer)
        #expect(sLayer?.mask is CAShapeLayer)
        #expect(nLeftStrokeLayer?.mask?.name == "splash.n.leftStrokeMask")
        #expect(nDiagonalStrokeLayer?.mask?.name == "splash.n.diagonalStrokeMask")
        #expect(nFinalStrokeLayer?.mask?.name == "splash.n.finalStrokeMask")
        #expect(sLayer?.mask?.name == "splash.s.strokeMask")
    }

    @Test func nRevealsInSequentialSegmentsBeforeSStarts() {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let animator = NodeSeekSplashAnimator(reduceMotion: false)

        animator.install(in: container)
        animator.play {}

        let layers = container.layer.sublayers ?? []
        let nLeftMask = layers.first { $0.name == "splash.n.leftStroke" }?.mask as? CAShapeLayer
        let nDiagonalMask = layers.first { $0.name == "splash.n.diagonalStroke" }?.mask as? CAShapeLayer
        let nFinalMask = layers.first { $0.name == "splash.n.finalStroke" }?.mask as? CAShapeLayer
        let sMask = layers.first { $0.name == "splash.s" }?.mask as? CAShapeLayer

        let nLeftAnimation = nLeftMask?.animation(forKey: "strokeReveal") as? CABasicAnimation
        let nDiagonalAnimation = nDiagonalMask?.animation(forKey: "strokeReveal") as? CABasicAnimation
        let nFinalAnimation = nFinalMask?.animation(forKey: "strokeReveal") as? CABasicAnimation
        let sAnimation = sMask?.animation(forKey: "strokeReveal") as? CABasicAnimation

        #expect(nLeftAnimation != nil)
        #expect(nDiagonalAnimation != nil)
        #expect(nFinalAnimation != nil)
        #expect(sAnimation != nil)
        #expect((nDiagonalAnimation?.beginTime ?? 0) >= (nLeftAnimation?.beginTime ?? 0) + (nLeftAnimation?.duration ?? 0))
        #expect((nFinalAnimation?.beginTime ?? 0) >= (nDiagonalAnimation?.beginTime ?? 0) + (nDiagonalAnimation?.duration ?? 0))
        #expect((sAnimation?.beginTime ?? 0) >= (nFinalAnimation?.beginTime ?? 0) + (nFinalAnimation?.duration ?? 0))
    }

    @Test func strokeMasksStayHiddenInModelLayerWhenTimelineStarts() {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let animator = NodeSeekSplashAnimator(reduceMotion: false)

        animator.install(in: container)
        animator.play {}

        let layers = container.layer.sublayers ?? []
        let masks = [
            layers.first { $0.name == "splash.n.leftStroke" }?.mask as? CAShapeLayer,
            layers.first { $0.name == "splash.n.diagonalStroke" }?.mask as? CAShapeLayer,
            layers.first { $0.name == "splash.n.finalStroke" }?.mask as? CAShapeLayer,
            layers.first { $0.name == "splash.s" }?.mask as? CAShapeLayer
        ]

        for mask in masks {
            #expect(mask?.strokeEnd == 0)
        }
    }

    @Test func reduceMotionCompletesWithoutLongAnimation() async {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let animator = NodeSeekSplashAnimator(reduceMotion: true)
        var completed = false

        animator.install(in: container)
        animator.play {
            completed = true
        }

        try? await Task.sleep(nanoseconds: 300_000_000)
        #expect(completed)
    }

    @Test func animatorKeepsVectorLayersAsFinalFrameBeforeCompletion() async {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let animator = NodeSeekSplashAnimator(reduceMotion: false, animationDuration: 0.01)
        var completed = false

        animator.install(in: container)
        animator.play {
            completed = true
        }

        try? await Task.sleep(nanoseconds: 50_000_000)

        let layers = container.layer.sublayers ?? []
        #expect(completed)
        #expect(layers.first { $0.name == "splash.n.leftStroke" }?.opacity == 1)
        #expect(layers.first { $0.name == "splash.n.diagonalStroke" }?.opacity == 1)
        #expect(layers.first { $0.name == "splash.n.finalStroke" }?.opacity == 1)
        #expect(layers.first { $0.name == "splash.s" }?.opacity == 1)
        #expect(layers.first { $0.name == "splash.dot" }?.opacity == 1)
        #expect(layers.first { $0.name == "splash.lightSweep" }?.opacity == 0)
        #expect(layers.first { $0.name == "splash.finalLogo" }?.opacity == 0)

        let masks = [
            layers.first { $0.name == "splash.n.leftStroke" }?.mask as? CAShapeLayer,
            layers.first { $0.name == "splash.n.diagonalStroke" }?.mask as? CAShapeLayer,
            layers.first { $0.name == "splash.n.finalStroke" }?.mask as? CAShapeLayer,
            layers.first { $0.name == "splash.s" }?.mask as? CAShapeLayer
        ]

        for mask in masks {
            #expect(mask?.strokeEnd == 1)
        }
    }
}
