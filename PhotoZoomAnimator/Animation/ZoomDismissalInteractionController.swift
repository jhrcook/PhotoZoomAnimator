//
//  ZoomDismissalInteractionController.swift
//  PhotoZoomAnimator
//
//  Created by Joshua on 8/8/19.
//  Copyright © 2019 JHC Dev. All rights reserved.
//

import UIKit

class ZoomDismissalInteractionController: NSObject {
    
    var transitionContext: UIViewControllerContextTransitioning?
    var animator: UIViewControllerAnimatedTransitioning?
    
    var fromReferenceImageViewFrame: CGRect?
    var toReferenceImageViewFrame: CGRect?
    
    func didPanWith(gestureRecognizer: UIPanGestureRecognizer) {
        
        guard
            let transitionContext = self.transitionContext,
            let animator = self.animator as? ZoomAnimator,
            let transitionImageView = animator.transitionImageView,
            let fromVC = transitionContext.viewController(forKey: .from),
            let fromReferenceImageView = animator.fromDelegate?.referenceImageView(for: animator),
            let fromReferenceImageViewFrame = animator.fromDelegate?.referenceImageViewFrameInTransitioningView(for: animator),
            let toVC = transitionContext.viewController(forKey: .to),
            let toReferenceImageView = animator.toDelegate?.referenceImageView(for: animator),
            let toReferenceImageViewFrame = animator.toDelegate?.referenceImageViewFrameInTransitioningView(for: animator) else {
            return
        }
        
        // STEP 1 //
        // hide from reference image
        fromReferenceImageView.isHidden = true
        toReferenceImageView.isHidden = true
        
        // STEP 2 //
        // center of the image
        let anchorPoint = CGPoint(x: fromReferenceImageViewFrame.midX, y: fromReferenceImageViewFrame.midY)
        let translatedPoint = gestureRecognizer.translation(in: fromVC.view)
        
        // STEP 3 //
        var verticalDelta: CGFloat = 0.0
        if UIDevice.current.orientation.isLandscape {
            verticalDelta = max(translatedPoint.x, 0.0)
        } else {
            verticalDelta = max(translatedPoint.y, 0.0)
        }
        
        //STEP 4 //
        let fromVCBackgroundAlpha = calculateBrackgroundAlphaFor(fromVC.view, atDelta: verticalDelta)
        let scale = calculateScaleIn(fromVC.view, atDelta: verticalDelta)
        
        fromVC.view.alpha = fromVCBackgroundAlpha
        toVC.tabBarController?.tabBar.alpha = 1 - fromVCBackgroundAlpha
        
        transitionImageView.transform = CGAffineTransform(scaleX: scale, y: scale)
        let newCenterX = anchorPoint.x + translatedPoint.x
        let newCenterY = anchorPoint.y + translatedPoint.y - transitionImageView.frame.height * (1 - scale) / 2.0
        let newCenter = CGPoint(x: newCenterX, y: newCenterY)
        transitionImageView.center = newCenter
        
        
        // STEP 5 //
        transitionContext.updateInteractiveTransition(1 - scale)
        
        // STEP 6//
        // user released the image
        if gestureRecognizer.state == .ended {
            
            // STEP 7 //
            let velocity = gestureRecognizer.velocity(in: fromVC.view)
            
            var velocityCheck = false
            
            if UIDevice.current.orientation.isLandscape {
                velocityCheck = velocity.x < 0 || newCenter.x < anchorPoint.x
            } else {
                velocityCheck = velocity.y < 0 || newCenter.y < anchorPoint.y
            }
            
            // STEP 8 //
            if velocityCheck {
                // cancel transition
                UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0, options: [], animations: {
                    transitionImageView.frame = fromReferenceImageViewFrame
                    fromVC.view.alpha = 1.0
                    toVC.tabBarController?.tabBar.alpha = 0.0
                }, completion: { _ in
                    transitionImageView.removeFromSuperview()
                    
                    toReferenceImageView.isHidden = false
                    fromReferenceImageView.isHidden = false
                    
                    transitionContext.cancelInteractiveTransition()
                    transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
                    
                    animator.toDelegate?.transitionDidEndWith(zoomAnimator: animator)
                    animator.fromDelegate?.transitionDidEndWith(zoomAnimator: animator)
                    
                    animator.transitionImageView = nil
                    self.transitionContext = nil
                })
                return
            }
            
            
            // STEP 9 //
            UIView.animateKeyframes(withDuration: 0.25, delay: 0, options: [], animations: {
                fromVC.view.alpha = 0.0
                transitionImageView.frame = toReferenceImageViewFrame
                toVC.tabBarController?.tabBar.alpha = 1.0
            }, completion: { _ in
                transitionImageView.removeFromSuperview()
                
                toReferenceImageView.isHidden = false
                fromReferenceImageView.isHidden = false
                
                self.transitionContext?.finishInteractiveTransition()
                transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
                
                animator.toDelegate?.transitionDidEndWith(zoomAnimator: animator)
                animator.fromDelegate?.transitionDidEndWith(zoomAnimator: animator)
                
                self.transitionContext = nil
            })
        }
        
        
    }
    
    
    
    
    func calculateBrackgroundAlphaFor(_ view: UIView, atDelta delta: CGFloat) -> CGFloat {
        let startingAlpha: CGFloat = 1.0
        let finalAlpha: CGFloat = 0.0
        let totalAvailableAlpha = startingAlpha - finalAlpha
        
        let maximumDelta = view.bounds.height / 4.0
        let deltaAsPercentageOfMaximun = min(abs(delta) / maximumDelta, 1.0)
        
        return startingAlpha - (deltaAsPercentageOfMaximun * totalAvailableAlpha)
    }
    
    
    func calculateScaleIn(_ view: UIView, atDelta delta: CGFloat) -> CGFloat {
        let startingScale: CGFloat = 1.0
        let finalScale: CGFloat = 0.5
        let totalAvailableScale = startingScale - finalScale
        
        let maximumDelta = view.bounds.height / 2.0
        let deltaAsPercentageOfMaximun = min(abs(delta) / maximumDelta, 1.0)
        
        return startingScale - (deltaAsPercentageOfMaximun * totalAvailableScale)
    }
}



extension ZoomDismissalInteractionController: UIViewControllerInteractiveTransitioning {
    
    func startInteractiveTransition(_ transitionContext: UIViewControllerContextTransitioning) {
        
        self.transitionContext = transitionContext
        
        let containerView = transitionContext.containerView
        
        guard
            let animator = self.animator as? ZoomAnimator,
            let fromVC = transitionContext.viewController(forKey: .from),
            let fromReferenceImageView = animator.fromDelegate?.referenceImageView(for: animator),
            let fromReferenceImageViewFrame = animator.fromDelegate?.referenceImageViewFrameInTransitioningView(for: animator),
            let toVC = transitionContext.viewController(forKey: .to),
            let toReferenceImageViewFrame = animator.toDelegate?.referenceImageViewFrameInTransitioningView(for: animator) else {
                return
        }
        
        animator.fromDelegate?.transitionWillStartWith(zoomAnimator: animator)
        animator.toDelegate?.transitionWillStartWith(zoomAnimator: animator)
        
        self.fromReferenceImageViewFrame = fromReferenceImageViewFrame
        self.toReferenceImageViewFrame = toReferenceImageViewFrame
        
        let referenceImage = fromReferenceImageView.image!
        
        containerView.addSubview(toVC.view)
        containerView.addSubview(fromVC.view)
        
        if animator.transitionImageView == nil {
            let transitionImageView = UIImageView(image: referenceImage)
            transitionImageView.contentMode = .scaleAspectFill
            transitionImageView.clipsToBounds = true
            transitionImageView.frame = fromReferenceImageViewFrame
            animator.transitionImageView = transitionImageView
            containerView.addSubview(transitionImageView)
        }
    }
    
}
