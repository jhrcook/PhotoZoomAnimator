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

There are two `UICollectionViewControllers`{:.swift}, `BaseCollectionViewController` and `PagingCollectionViewController`:

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

Below is the code, followed by the explanation, for the **zoom in** animation logic.

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
        
        // these functions are run and can optionally do some process before the animation begins
        self.fromDelegate?.transitionWillStartWith(zoomAnimator: self)
        self.toDelegate?.transitionWillStartWith(zoomAnimator: self)
        
        // start the destination as transparent and hidden
        toVC.view.alpha = 0
        toReferenceImageView.isHidden = true
        containerView.addSubview(toVC.view)  // add to transition container view
        
        let referenceImage = fromReferenceImageView.image!
        
        if self.transitionImageView == nil {
            let transitionImageView = UIImageView(image: referenceImage)
            transitionImageView.contentMode = .scaleAspectFill
            transitionImageView.clipsToBounds = true
            transitionImageView.frame = fromReferenceImageViewFrame
            self.transitionImageView = transitionImageView
            containerView.addSubview(transitionImageView)
        }
        
        // hide the source image view
        fromReferenceImageView.isHidden = true
        
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
```

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

## TODO




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