//
//  ZoomTransitionController.swift
//  PhotoZoomAnimator
//
//  Created by Joshua on 8/6/19.
//  Copyright © 2019 JHC Dev. All rights reserved.
//

import UIKit

class ZoomTransitionController: NSObject {
    
    weak var fromDelegate: ZoomAnimatorDelegate?
    weak var toDelegate: ZoomAnimatorDelegate?
    
    let animator: ZoomAnimator

    // for interactive transitions
     let interactionController: ZoomDismissalInteractionController
     var isInteractive: Bool = false
    
    override init() {
        animator = ZoomAnimator()
        interactionController = ZoomDismissalInteractionController()
        super.init()
    }
}


extension ZoomTransitionController: UIViewControllerTransitioningDelegate {
    
    // just swap the delegates depending on direction of animation
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        self.animator.isPresenting = true
        self.animator.fromDelegate = fromDelegate
        self.animator.toDelegate = toDelegate
        return self.animator
    }
    
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        self.animator.isPresenting = false
        let tmp = self.fromDelegate
        self.animator.fromDelegate = self.toDelegate
        self.animator.toDelegate = tmp
        return self.animator
    }
    
    // decide whether or not to use interactive controller
    // the interactive controller uses the same animator, though
    func interactionControllerForDismissal(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        if !self.isInteractive {
            return nil
        }
        
        self.interactionController.animator = animator
        return self.interactionController
    }
    
}



extension ZoomTransitionController: UINavigationControllerDelegate {
    
    func navigationController(_ navigationController: UINavigationController, animationControllerFor operation: UINavigationController.Operation, from fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        
        // tell the animation which way it is going and set some stored properties
        if operation == .push {
            self.animator.isPresenting = true
            self.animator.fromDelegate = fromDelegate
            self.animator.toDelegate = toDelegate
        } else {
            // is called with `operation == .pop`
            self.animator.isPresenting = false
            let tmp = self.fromDelegate
            self.animator.fromDelegate = self.toDelegate
            self.animator.toDelegate = tmp
        }
        
        return self.animator
    }
    
    
    // whether or not to use the interactive controller
    // the interactive controller uses the same animator, though
    func navigationController(_ navigationController: UINavigationController, interactionControllerFor animationController: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        
        if !self.isInteractive {
            return nil
        }
        
        self.interactionController.animator = animator
        return self.interactionController
    }
    
}


extension ZoomTransitionController {
    func didPanWith(gestureRecognizer: UIPanGestureRecognizer) {
        interactionController.didPanWith(gestureRecognizer: gestureRecognizer)
    }
}
