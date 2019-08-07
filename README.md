# PhotoZoomAnimator

**author: Josh Cook**  
**date: 2019-08-06**

![100DaysOfCodeSwift](https://img.shields.io/badge/Swift-PhotoZoomAnimator-FA7343.svg?style=flat&logo=swift)
![ios](https://img.shields.io/badge/iOS-PhotoZoomAnimator-999999.svg?style=flat&logo=apple)  
[![jhc github](https://img.shields.io/badge/GitHub-jhrcook-181717.svg?style=flat&logo=github)](https://github.com/jhrcook)
[![jhc twitter](https://img.shields.io/badge/Twitter-JoshDoesaThing-00aced.svg?style=flat&logo=twitter)](https://twitter.com/JoshDoesa)
[![jhc website](https://img.shields.io/badge/Website-JoshDoesaThing-5087B2.svg?style=flat&logo=telegram)](https://www.joshdoesathing.com)

This is an experimental iOS app as I try to figure out how to make a custom interactive transition (to use in my [PlantTracker app](https://github.com/jhrcook/PlantTracker)). The goal is to replicate the transition used in the native phone app. I will do my best to document the process here.

### Resources

I used the [SnapKit library]((http://snapkit.io)) to make the contraints on my views.

This [GitHub repository](https://github.com/masamichiueta/FluidPhoto) (and my [fork](https://github.com/jhrcook/FluidPhoto)) and its paired [Medium article](https://medium.com/@masamichiueta/create-transition-and-interaction-like-ios-photos-app-2b9f16313d3) will provide a lot of assitance. It has the final transition that I want to replicate, but also a lot of other stuff. Also, the accompanying article is not too helpful.

---

## Framework

Below, I provide an overview of how the app's framework was created originally. The rest of the app will build (and experiment) from here.

There are two `UICollectionViewControllers`, `BaseCollectionViewController` and `PagingCollectionViewController`:

* `BaseCollectionViewController` has cells of class `BaseCollectionViewCell` which simply hold a single `UIImageView` [snapped](http://snapkit.io) to the edges of the cell's `contentView`.
* `PagingCollectionViewController` is a bit more complicated. It holds cells of class `PagingCollectionViewCell` which contain a `UIScrollView` which, in turn, holds a `UIImageView`. The scroll view handles zooming and panning around the image. The collection view is pretty standard save for scrolling horizontally (set using the IB) and each cell is the same size as the `view`

The `BaseCollectionViewController` is the initial view upon entering the app (embedded in a navigation controller). Taping on a cell opens `PagingCollectionViewController` to the index of the taped cell. There is a segue from `BaseCollectionViewController` to `PagingCollectionViewController` to pass the images (random images I took of my succulent seedlings) and `startingIndex` forward.

---

## Zoom Animation

**`ZoomTransitionController`** - implements `UIViewControllerTransitioningDelegate` and `UINavigationControllerDelegate` to manage the transitions.

**`ZoomAnimator`** - implements `UIViewControllerAnimatedTransitioning` and the zoom animation logic.

Splitting up these processes into two classes will make it easier to have an interactive and non-interactive transition. The non-interactive transition will go from `BaseCollectionViewController` to `PagingCollectionViewController`, and it will be an interactive transition on the way back, following a swipe gesture.

### ZoomAnimator

This handles the non-interactive portion of the transition.

It aquires the `UIImageView` to be zoomed from and animates the transition from the source frame to the destination frame.

#### ZoomAnimatorDelegate protocol

I began by creating a protocol to define a delegate that my view controllers will conform to.

```swift
protocol ZoomAnimatorDelegate: class {
    func transitionWillStartWith(zoomAnimator: ZoomAnimator)
    func transitionDidEndWith(zoomAnimator: ZoomAnimator)
    func referenceImageView(for zoomAnimator: ZoomAnimator) -> UIImageView?
    func referenceImageViewFrameInTransitioningView(for zoomAnimator: ZoomAnimator) -> CGRect?
}
```

#### ZoomAnimator class

The `ZoomAnimator` class has four properties:

1. `fromDelegate: ZoomAnimatorDelegate`{:.swift} and `toDelegate: ZoomAnimatorDelegate` are the source and destination objects that conform to the `ZoomAnimatorDelegate` protocol.
2. `isPresenting: Bool` answers the question: "Is the transition from the base collection view to the paging collection view?"
3. `transitionImageView	: UIImageView` is the image view that will be animated during the transition. 

The first step in creating this animator is to have it conform to `UIViewControllerAnimatedTransitioning`. This requires two methods, `transitionDuration(using:)` and `animateTransition(using:)`. The first returns the length (in seconds) of the animation. The second method returns a `UIViewControllerContextTransitioning` object that handles the animation. There are two animation functions, one for zooming in and the other for zooming out; the first is run if `isPresenting`, otherwise the latter is run.

Below is the code, followed by the explanation, for the **zoom in** animation logic. The zoom out logic is very simillar (i.e. almost identical), so I will not cover it in-depth here.

```swift
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
        
        // these are optional functions in the delegates that get called before the animation runs
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
        
        // STEP 5 //
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
                
                // these are optional functions in the delegates that get called after the animation runs
                self.toDelegate?.transitionDidEndWith(zoomAnimator: self)
                self.fromDelegate?.transitionDidEndWith(zoomAnimator: self)
        })
        
    }
```

The preparation for the animation is to first gather the image view controllers and image views from the source and destination. Also, the source image view's frame in the transition view is requested.

Before the animation runs, the `transitionWillStart(zoomAnimator:)` methods are run for both delegates. This is just a helper function and need not do anything.

**Step 1: Hide the destination image view.**

To being, the destination view controller is set to fully transparent and its image view is hidden. *Then* (sequence is important), the destination view controller *view* (not the view controller, itself) is added to the `containerView` of the transition.

**Step 2: Create an image view to animate during the transition.**

A reference image is obtained from the source image view and made the image for `transitionImageView` if it is `nil` (which is usually will be). The image view is prepared in standard ways, and then the image view's frame is set to `fromReferenceImageViewFrame` such that it is now exactly overlapping the source image view. (The authors of this code use a stand-in object *also* named `transitionImageView`, though I do not think it is necessary.)

**Step 3: Hide the source image view.**

Finally, once the `transitionImageView` is added to the `containerView`, the source image view can be hidden, too.

**Step 4: Calculate the final size of the destination image view**

[Question: Can the size of the destination image view frame be used here?]

The function `calculateZoomInImageFrame(image:forView:)` returns a `CGRect` with the demonsions of the frame to fit the reference image in the destination view controller view. This function is explained further down below.

**Step 5: Animate the image zooming from the source frame to the destination frame.**

The `UIView.animate()` method is passed vlalues for its appropriately-named arguments. For options, it is passed `UIView.AnimationOptions.transitionCrossDissolve` - this provides the "fading" animation. The `animations` closure changes the destination view controller transparency back to 1, scales the `transitionImageView` frame to the final size calculated in Step 4, and the source tab bar (if available) is made transparent.

When the animation is complete, the transition image view is removed and made `nil` and the source and destination image views are shown (i.e. not hidden; only the destination view image will be visible, though, because the source is behind it). The final touch is to only complete the transition if it was not cancelled: `transitionContext.completeTransition(!transitionContext.transitionWasCancelled)`. Therefore, when a gesture is used to control the animation, if the gesture is undone (e.g. panning back to the original location), the transition will not continue.

Once all of the transition stuff has been dealt with, the `transitionDidEndWith(zoomAnimator:)` methods for both the source and destination view controllers are run. These return `Void` so do not have to do anything.


**The `calculateZoomInImageFrame(image:forView:)` function**

Below is the function.

```swift
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
``` 

It first calculates the width:height ratio of the `view` and `image`. If `image`'s ratio is larger than that of `view` (for our uses it is a view controller's view), then the image is touching the sides of the view. Based on this, the if-else statement determines how to send back a `CGRect` scaled to fit `image` in `view`.

### ZoomTransitionController

**The point of the `ZoomTransitionController` class is to oragnize the `ZoomAnimatorDelegate`s for the `ZoomAnimator` animation.**

Like `ZoomAnimator`, it has stored properties for the source and destination view controllers. It also has a `ZoomAnimator` called `animator` to handle the animations (explained above).

### UIViewControllerTransitioningDelegate

The first extension to `ZoomAnimatorController` is to be the `UIViewControllerTransitioningDelegate`. Here, there are two methods: `animationController(forPresented:presenting:source:) -> UIViewControllerAnimatedTransitioning?` and `animationController(forDismissed:) -> UIViewControllerAnimatedTransitioning?`. The first is called upon presentation and the latter upon dismissal. Here is how they are implemented in `ZoomTransitionController`.

**For Presentation**

```swift
func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
	self.animator.isPresenting = true
	self.animator.fromDelegate = fromDelegate
	self.animator.toDelegate = toDelegate
	return self.animator
}
```

**For Dismissal**

```swift
func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
	self.animator.isPresenting = false
	let tmp = self.fromDelegate
	self.animator.fromDelegate = self.toDelegate
	self.animator.toDelegate = tmp
	return self.animator
}

```

The `isPresenting` property of the `ZoomAnimator` is set logically for each method. For the presentation, the `ZoomTransitionController` and `ZoomAnimator` have the same source and destination `ZoomAnimatorDelegate`s, but the dismissal swaps them. This is necessary for how to `ZoomAnimtor.animateZoomOutTransition()` method treats the source and destination view controllers: the source delegate is the zoomed in image (`PagingCollectionViewController`, in this case) and the destination is the zoomed out image (`PagingCollectionViewController `, in this case).

### UINavigationControllerDelegate

The second extension on `ZoomAnimatorController` is `UINavigationControllerDelegate`. It implements the method `navigationController(_:animationControllerFor:from:to:) -> UIViewControllerAnimatedTransitioning?` as shown below. It again just swaps the source and destination delegates for the animator object depending on which way the navigation is going.

```swift
func navigationController(_ navigationController: UINavigationController, animationControllerFor operation: UINavigationController.Operation, from fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
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
```

## Setting up `BaseCollectionViewController` for animation

