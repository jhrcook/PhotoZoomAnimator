//
//  ZoomAnimator.swift
//  PhotoZoomAnimator
//
//  Created by Joshua on 8/6/19.
//  Copyright © 2019 JHC Dev. All rights reserved.
//

import UIKit


protocol ZoomAnimatorDelegate: class {
    func transitionWillStartWith(zoomAnimator: ZoomAnimator)
    func transitionDidEndWith(zoomAnimator: ZoomAnimator)
    func referenceImageView(for zoomAnimator: ZoomAnimator) -> UIImageView?
    func referenceImageViewFrameInTransitioningView(for zoomAnimator: ZoomAnimator) -> CGRect?
}


class ZoomAnimator: NSObject {

    weak var fromDelegate: ZoomAnimatorDelegate?
    weak var toDelegate: ZoomAnimatorDelegate?
    
    var isPresenting = true
    
    var transitionImageView: UIImageView?
    
    
    fileprivate func animateZoomInTransition(using transitionContext: UIViewControllerContextTransitioning) {
        
        // container view of the animation
        let containerView = transitionContext.containerView
        
        // get view controllers and image views
        guard
            let toVC = transitionContext.viewController(forKey: .to),
            let fromVC = transitionContext.viewController(forKey: .from),
            let fromReferenceImageView = self.fromDelegate?.referenceImageView(for: self),  // source image view
            let toReferenceImageView = self.toDelegate?.referenceImageView(for: self),      // destination image view
            let fromReferenceImageViewFrame = self.fromDelegate?.referenceImageViewFrameInTransitioningView(for: self)
            else {
                return
        }
        
        //
        self.fromDelegate?.transitionWillStartWith(zoomAnimator: self)
        self.toDelegate?.transitionWillStartWith(zoomAnimator: self)
        
        // STEP 1 //
        // start the destination as transparent and hidden
        toVC.view.alpha = 0
        toReferenceImageView.isHidden = true
        containerView.addSubview(toVC.view)  // add to transition container view
        
        // STEP 2
        let referenceImage = fromReferenceImageView.image!
        if self.transitionImageView == nil {
            let transitionImageView = UIImageView(image: referenceImage)
            transitionImageView.contentMode = .scaleAspectFill
            transitionImageView.clipsToBounds = true
            transitionImageView.frame = fromReferenceImageViewFrame
            
            self.transitionImageView = transitionImageView
            containerView.addSubview(transitionImageView)
        }
        
        // STEP 3
        // hide the source image view
        fromReferenceImageView.isHidden = true
        
        // STEP 4 //
        let finalTransitionSize = calculateZoomInImageFrame(image: referenceImage, forView: toVC.view)
        
        // animation
        UIView.animate(
            withDuration: transitionDuration(using: transitionContext),
            delay: 0,
            usingSpringWithDamping: 0.8,
            initialSpringVelocity: 0,
            options: [.transitionCrossDissolve],
            animations: {
                toVC.view.alpha = 1.0                                  // animate transparency of destination view in
                self.transitionImageView?.frame = finalTransitionSize  // animate size of image view
                fromVC.tabBarController?.tabBar.alpha = 0              // animate transparency of tab bar out
        },
            completion: { _ in
                // remove transition image view and show both view controllers, again
                self.transitionImageView?.removeFromSuperview()
                self.transitionImageView = nil
                toReferenceImageView.isHidden = false
                fromReferenceImageView.isHidden = false
                
                // end the transition (unless was cancelled)
                transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
                self.toDelegate?.transitionDidEndWith(zoomAnimator: self)
                self.fromDelegate?.transitionDidEndWith(zoomAnimator: self)
        })
        
    }
    
    
    fileprivate func animateZoomOutTransition(using transitionContext: UIViewControllerContextTransitioning) {
        // TODO
    }
    
    
    
    
    
    
    private func calculateZoomInImageFrame(image: UIImage, forView view: UIView) -> CGRect {
        
        let viewRatio = view.frame.size.width / view.frame.size.height
        let imageRatio = image.size.width / image.size.height
        let touchesSides = (imageRatio > viewRatio)
        
        if touchesSides {
            let height = view.frame.width / imageRatio
            let yPoint = view.frame.minY + (view.frame.height - height) / 2
            return CGRect(x: 0, y: yPoint, width: view.frame.width, height: height)
        } else {
            let width = view.frame.height * imageRatio
            let xPoint = view.frame.minX + (view.frame.width - width) / 2
            return CGRect(x: xPoint, y: 0, width: width, height: view.frame.height)
        }
    }
    
}


extension ZoomAnimator: UIViewControllerAnimatedTransitioning {
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return isPresenting ? 0.5 : 0.25
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        if isPresenting {
            animateZoomInTransition(using: transitionContext)
        } else {
            animateZoomOutTransition(using: transitionContext)
        }
    }
    
    
}
