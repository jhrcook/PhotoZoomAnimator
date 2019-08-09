# PhotoZoomAnimator

**author: Josh Cook**  
**date: 2019-08-06**

![100DaysOfCodeSwift](https://img.shields.io/badge/Swift-PhotoZoomAnimator-FA7343.svg?style=flat&logo=swift)
![ios](https://img.shields.io/badge/iOS-PhotoZoomAnimator-999999.svg?style=flat&logo=apple)  
[![jhc github](https://img.shields.io/badge/GitHub-jhrcook-181717.svg?style=flat&logo=github)](https://github.com/jhrcook)
[![jhc twitter](https://img.shields.io/badge/Twitter-JoshDoesaThing-00aced.svg?style=flat&logo=twitter)](https://twitter.com/JoshDoesa)
[![jhc website](https://img.shields.io/badge/Website-JoshDoesaThing-5087B2.svg?style=flat&logo=telegram)](https://www.joshdoesathing.com)

This was an experimental iOS app explaining how to make a custom interactive transition (to use in my [PlantTracker app](https://github.com/jhrcook/PlantTracker)). The goal was to replicate the transition used in the native phone app. I did my best to document the process here.


### Final Result

<img src="progress_screenshots/zoom_animation_interactive_HD.gif" width="300"/>


### Resources

I used the [SnapKit library]((http://snapkit.io)) to make the contraints on my views.

This [GitHub repository](https://github.com/masamichiueta/FluidPhoto) (and my [fork](https://github.com/jhrcook/FluidPhoto)) and its paired [Medium article](https://medium.com/@masamichiueta/create-transition-and-interaction-like-ios-photos-app-2b9f16313d3) were used as a guide. It has the transition that I wanted to replicate, but also a lot of other stuff in-between. Unfortunately, the accompanying article was not too helpful, so I tried to be more comprehensive and explanatory, here.

---

## Framework

Below is an overview of the app's framework. The rest of the app was built (and experimented on) from here.

There are two `UICollectionViewControllers`, `BaseCollectionViewController` and `PagingCollectionViewController`:

* `BaseCollectionViewController` has cells of class `BaseCollectionViewCell` which simply hold a single `UIImageView` [snapped](http://snapkit.io) to the edges of the cell's `contentView`.
* `PagingCollectionViewController` is a bit more complicated. It holds cells of class `PagingCollectionViewCell` which contain a `UIScrollView` which, in turn, hold a `UIImageView`. The scroll view handles zooming and panning around the image. The collection view is pretty standard save for scrolling horizontally (set using the IB) and each cell is the same size as the `view`

The `BaseCollectionViewController` is the initial view upon entering the app (embedded in a navigation controller). Taping on a cell opens `PagingCollectionViewController` to the index of the taped cell. There is a segue from `BaseCollectionViewController` to `PagingCollectionViewController` to pass the images (random images I took of my succulent seedlings) and `startingIndex` forward.

```swift
override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
	if let destinationViewController = segue.destination as? PagingCollectionViewController {
		destinationViewController.images = images
		if let indexPath = collectionView.indexPathsForSelectedItems?.first {
		    destinationViewController.startingIndex = indexPath.item
		}
	}
}
```

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

1. `fromDelegate: ZoomAnimatorDelegate` and `toDelegate: ZoomAnimatorDelegate` are the source and destination objects that conform to the `ZoomAnimatorDelegate` protocol.
2. `isPresenting: Bool` answers the question: "Is the transition from the base collection view to the paging collection view?"
3. `transitionImageView	: UIImageView` is the image view that will be animated during the transition. 

The first step in creating this animator is to have it conform to `UIViewControllerAnimatedTransitioning`. This requires two methods, `transitionDuration(using:)` and `animateTransition(using:)`. The first returns the length (in seconds) of the animation. The second method returns a `UIViewControllerContextTransitioning` object that handles the animation. There are two animation functions, one for zooming in and the other for zooming out; the first is run if `isPresenting`, otherwise the latter is run.

```swift
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
```

Below is the code, followed by the explanation, for the **zoom in** animation logic. The zoom out logic is very simillar (i.e. almost identical), so I will not cover it in-depth here. The only difference to keep in mind is that both the source and destination view controller's cells have been created, so the image views of the cells can be handled specifically by the animation (this will be relevant later when we run into a problem with the zoom in animation getting the destination's cell's image view during presentation).

**Preparation: collect necessary view controllers, views, and frames.**

The preparation for the animation is to first gather the image view controllers and image views from the source and destination. Also, the *source* image view's frame in the transition view is requested.

Before the animation runs, the `transitionWillStart(zoomAnimator:)` methods are run for both delegates. This is just a helper function and need not do anything. It is used by the `PagingCollectionViewController`, explained later.

```swift
// container view of the animation
let containerView = transitionContext.containerView

// get view controllers and image views
guard
	let fromVC = transitionContext.viewController(forKey: .from),
	let fromReferenceImageView = self.fromDelegate?.referenceImageView(for: self),
	let fromReferenceImageViewFrame = self.fromDelegate?.referenceImageViewFrameInTransitioningView(for: self),
	let toVC = transitionContext.viewController(forKey: .to),
	let toView = transitionContext.view(forKey: .to)
	else {
		return
}

// these are optional functions in the delegates that get called before the animation runs
self.fromDelegate?.transitionWillStartWith(zoomAnimator: self)
self.toDelegate?.transitionWillStartWith(zoomAnimator: self)
```

**Step 1: Hide the destination image view.**

To begin, the destination view controller is set to fully transparent, then added to the `containerView`. It is now ready to be animated in.

```swift
toVC.view.alpha = 0.0
containerView.addSubview(toVC.view)
```

**Step 2: Create an image view to animate during the transition.**

A reference image is obtained from the source image view and made the image for `transitionImageView` if it is `nil` (which is usually will be). The image view is prepared in standard ways, and then the image view's frame is set to `fromReferenceImageViewFrame` such that it is now exactly overlapping the source image view. At the end, the `transitionImageView` is added to the transition's `containerView` so it can be animated to move from the *source* cell's frame to the *destination* cell image's frame.

```swift
let referenceImage = fromReferenceImageView.image!
if self.transitionImageView == nil {
	let transitionImageView = UIImageView(image: referenceImage)
	transitionImageView.contentMode = .scaleAspectFill
	transitionImageView.clipsToBounds = true
	transitionImageView.frame = fromReferenceImageViewFrame
	
	self.transitionImageView = transitionImageView
	containerView.addSubview(transitionImageView)
}
```

**Step 3: Hide the source image view.**

The source image view is hidden so that the `transitionImageView` appears to be the same image during the animation. (This is a bit difficult to explain, but just look for it in the animation and it will make sense.)

```swift
fromReferenceImageView.isHidden = true
```

**Step 4: Calculate the final size of the destination image view**

The function `calculateZoomInImageFrame(image:forView:)` returns a `CGRect` with the dimensions of the frame to fit the reference image in the destination view controller's view. This function is explained further down below, but here it just provides the target location of for `transitionImageview`.

```swift
let finalTransitionSize = calculateZoomInImageFrame(image: referenceImage, forView: toView)
```

**Step 5: Animate the image zooming from the source frame to the destination frame.**

The `UIView.animate()` method is passed values for its appropriately-named arguments. For options, it is passed `UIView.AnimationOptions.transitionCrossDissolve` (the "fading" animation) and `curveEaseOut`. The `animations` closure changes the destination view controller's view transparency back to 1, scales the `transitionImageView` frame to the final size calculated in Step 4, and the source tab bar (if available) is made transparent.

When the animation is complete, the transition image view is removed and made `nil` and the source image view is un-hidden (though it will still not be visible because the source view controller is now behind the destination view controller). The final touch is to only complete the transition if it was not cancelled: `transitionContext.completeTransition(!transitionContext.transitionWasCancelled)`. Therefore, when a gesture is used to control the animation, if the gesture is undone (e.g. panning back to the original location), the transition will not continue.

Once all of the transition stuff has been dealt with, the `transitionDidEndWith(zoomAnimator:)` methods for both the source and destination view controllers are run. These are just helper functions for the view controllers.

```swift
UIView.animate(
	withDuration: transitionDuration(using: transitionContext),
	delay: 0,
	usingSpringWithDamping: 0.8,
	initialSpringVelocity: 0,
	options: [.transitionCrossDissolve, .curveEaseOut],
	animations: {
		toVC.view.alpha = 1.0
		self.transitionImageView?.frame = finalTransitionSize  // animate size of image view
		fromVC.tabBarController?.tabBar.alpha = 0              // animate transparency of tab bar out
},
	completion: { _ in
		// remove transition image view and show both view controllers, again
		self.transitionImageView?.removeFromSuperview()
		self.transitionImageView = nil
		
		fromReferenceImageView.isHidden = false
		
		// end the transition (unless was cancelled)
		transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
		
		// these are optional functions in the delegates that get called after the animation runs
		self.toDelegate?.transitionDidEndWith(zoomAnimator: self)
		self.fromDelegate?.transitionDidEndWith(zoomAnimator: self)
})
```

**The `calculateZoomInImageFrame(image:forView:)` function**

Below is the function. It first calculates the width:height ratio of the `view` and `image`. If `image`'s ratio is larger than that of `view` (for our uses it is a view controller's view), then the image is touching the sides of the view. Based on this, the if-else statement determines how to send back a `CGRect` scaled to fit `image` in `view`.

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

### ZoomTransitionController

**The point of the `ZoomTransitionController` class is to oragnize the `ZoomAnimatorDelegate`s for the `ZoomAnimator` animation.**

Like `ZoomAnimator`, it has stored properties for the source and destination view controllers. It also has a `ZoomAnimator` called `animator` to handle the animations (explained above).

### UIViewControllerTransitioningDelegate

The first extension to `ZoomAnimatorController` is the `UIViewControllerTransitioningDelegate` which requires two methods: `animationController(forPresented:presenting:source:) -> UIViewControllerAnimatedTransitioning?` and `animationController(forDismissed:) -> UIViewControllerAnimatedTransitioning?`. The first is called upon presentation and the latter upon dismissal.

```swift
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

## Setting up `BaseCollectionViewController` and `PagingCollectionViewController` for animation

### Adding a transition controller

A transition controller is added as a stored property to **`PagingCollectionViewController`**, the *destination* view controller. This location is chosen (over `BaseCollectionViewController`) because this is where the dismissing gesture will eventually be added. 

```swift
class PagingCollectionViewController: UICollectionViewController {
	...
	var transitionController = ZoomTransitionController()
	...
```

### Setting delegates during segue

The next change is in the `prepare(for:sender:)` method of `BaseCollectionViewController`. Currently, this type casts the destination view controller as `PagingCollectionViewController` then sets its `images` and `startingIndex` properties with the images and index of the selected cell in `BaseCollectionViewController`.

The first addition is to set the navigation controller delegate of the *current* view controller to the `ZoomTransitionController` of the destination view controller.

```swift
self.navigationController?.delegate = destinationViewController.transitionController
```

Then the source and destination `ZoomAnimatorDelegate`s are set for the `ZoomTransitionController` of the destination view controller.

```swift
destinationViewController.transitionController.fromDelegate = self
destinationViewController.transitionController.toDelegate = destinationViewController
```

### The `PagingCollectionViewControllerDelegate` protocol

If the user selects image at index 0 from the base view, then swipes over to index 1 in the paging view, and then returns to the base view, we need to tell the `BaseCollectionViewController` that the new index is 1, not still 0. Therefore, I created a protocol called `PagingCollectionViewControllerDelegate` with a single function `containerViewController(_:indexDidChangeTo:)`. To use this protocol, a new stored property of `PagingCollectionViewController` was created and the method was called on the delegate after each paging swipe finished:

```swift
var containerDelegate: PagingCollectionViewControllerDelegate?
...
// change the base view controller's index, too
override func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
	containerDelegate?.containerViewController(self, indexDidChangeTo: currentIndex)
}
```

The `BaseCollectionViewController` was set to the delegate during the segue:

```swift
destinationViewController.containerDelegate = self
```

To conform to this protocol, a stored property was added, the `collectionView(_:didSelectItemAt:)` method was implemented, and the following extension was appended to `BaseCollectionViewController`.

```swift
class BaseCollectionViewController: UICollectionViewController {
	...
	var currentIndex = 0
	...
	override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
		currentIndex = indexPath.item
	}
```

```swift
extension BaseCollectionViewController: PagingCollectionViewControllerDelegate {
	func containerViewController(_ containerViewController: PagingCollectionViewController, indexDidChangeTo currentIndex: Int) {
		self.currentIndex = currentIndex
		collectionView.scrollToItem(at: IndexPath(item: currentIndex, section: 0), at: .centeredVertically, animated: false)
	}
}
```

### Conforming to the `ZoomAnimatorDelegate` protocol

The last step was to have both `BaseCollectionViewController` and `PagingCollectionViewController` conform to `ZoomAnimatorDelegate`.

#### `BaseCollectionViewController`

Nothing needs to be done specifically right before or after the transition animation, so the `transitionWillStartWith(zoomAnimator:)` and `transitionDidEndWith(zoomAnimator:)` methods are left empty.

Both the `referenceImageView(for:) -> UIImageView?` and `referenceImageViewFrameInTransitioningView(for:) -> CGRect?` methods first must retrieve the correct cell to return. Therefore, I created the `getCell(for:)` method. If the animation `isPresenting`, then the index of the correct cell to use must be obtained using `collectionView.indexPathsForSelectedItems?.first`. If the zoom animation is *not* presenting, then the index of the cell to use is the `currentIndex` which is updated by the `PagingCollectionViewController` using the `PagingCollectionViewControllerDelegate` protocol. Once the correct index has been found, the cell is retrieved.

```swift
func getCell(for zoomAnimator: ZoomAnimator) -> BaseCollectionViewCell? {
	let indexPath = zoomAnimator.isPresenting ? collectionView.indexPathsForSelectedItems?.first : IndexPath(item: currentIndex, section: 0)
        
	if let cell = collectionView.cellForItem(at: indexPath!) as? BaseCollectionViewCell {
		return cell
	} else {
		return nil
	}
}
```

The `referenceImageView(for:)` method returns an image view with the image of the selected cell image view. Therefore, it uses `getCell(for:)` and returns the cell's `imageView` property.
```swift
func referenceImageView(for zoomAnimator: ZoomAnimator) -> UIImageView? {
	if let cell = getCell(for: zoomAnimator) { return cell.imageView }
	return nil
}
```

The `referenceImageViewFrameInTransitioningView(for:)` method needs to return the frame of the image view from the perspective of the cell's content view with regards to the entire view. To translate the `CGRect` of the cell's image view frame to the entire view, the `UIView.convert(_:to)` method was used.

```swift
func referenceImageViewFrameInTransitioningView(for zoomAnimator: ZoomAnimator) -> CGRect? {
	if let cell = getCell(for: zoomAnimator) {
		return cell.contentView.convert(cell.imageView.frame, to: view)
	}
	return nil
}
    
```

#### `PagingCollectionViewController`

The `PagingCollectionViewController` was a bit more complicated. The major hurdle was to get around the fact that the cell being transitioned to is created *after* the animation begin, but *before* the animation ends. Therefore, the image view of the destination cell could not be accessed by `ZoomAnimator`, but would appear during the transition. To see what I mean, I point out a change you can experiment with to make the problem (but not the solution) very obvious. 

Let's begin with the `referenceImageView(for:)->UIImageView?` and `referenceImageViewFrameInTransitioningView(for:)->CGRect?` methods as they are very straight forward. Both retrieve the cell at `currentIndex` (which is set to `startingIndex` beforehand in`viewDidLoad()`) and either return the image view or converted image view frame, respectively.

```swift
func referenceImageView(for zoomAnimator: ZoomAnimator) -> UIImageView? {
	if let cell = collectionView.cellForItem(at: IndexPath(item: currentIndex, section: 0)) as? PagingCollectionViewCell {
		return cell.imageView
	}
	return nil
}
    
func referenceImageViewFrameInTransitioningView(for zoomAnimator: ZoomAnimator) -> CGRect? {
	if let cell = collectionView.cellForItem(at: IndexPath(item: currentIndex, section: 0)) as? PagingCollectionViewCell {
		return cell.scrollView.convert(cell.imageView.frame, to: view)
	}
	return nil
}
```

The fix to the "phantom image view" problem described previously is handled in `transitionWillStartWith(zoomAnimator:)` and `transitionDidEndWith(zoomAnimator:)`. Basically, during presentation, the cell's image is hidden, and then it is un-hidden afterwards.

As mentioned briefly above, you can change `zoomAnimator.isPresenting` to `false` (such that the destination image view is never hidden) to show why this is necessary.

```swift
func transitionWillStartWith(zoomAnimator: ZoomAnimator) {
	// add code here to be run just before the transition animation
	hideCellImageViews = zoomAnimator.isPresenting
}
    
func transitionDidEndWith(zoomAnimator: ZoomAnimator) {
	// add code here to be run just after the transition animation
	hideCellImageViews = false
	collectionView.reloadItems(at: [IndexPath(item: currentIndex, section: 0)])
}
```

The final line in `transitionDidEndWith(zoomAnimator:)` just reloads the current cell with `hideCellImageViews` set to `false`. The new stored property of `PagingCollectionViewController`, `hideCellImageViews: Bool`, takes effect during the creation of the collection view's cells.

```swift
override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
	let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! PagingCollectionViewCell
    
	cell.image = images[indexPath.item]
        
	cell.imageView.isHidden = hideCellImageViews  // hide the image during presentation
        
	return cell
}
```

### Animated transition

Below is a screen recording of the non-interactive zoom transition!

<img src="progress_screenshots/zoom_animation_noninteractive_HD.gif" width="300"/>

Everything up to this point is available in the branch [`zoom-animation`](https://github.com/jhrcook/PhotoZoomAnimator/tree/zoom-animation).

## Interactive transition

From here, I will make the dismissal react to gestures. The goal is to have the user be able to pan the image up or down to induce the transition, and have the image "dragged" by the pan as long as the user hold on.

### ZoomDismissalInteractionController

I began by making a new class `ZoomDismissalInteractionController` which is responsible for handling the logic of interactive transitions. It has a stored property `transitionContext` of type `UIViewControllerContextTransitioning`. This will be accessed to get all of the information about the source and destination views.

Another stored property, `animator`, will be typecast to `ZoomAnimator` and provide access to all of the objects being animated above.

#### Responding to pan gesture

To respond to the pan gesture, the method `didPanWith(gestureRecognizer:)` was created. It begins by collecting all of the neccesary image views, view controllers, and frames (not shown here).

**Step 1: Hide source and destination image views.**

Hide the source and destination image views, replacing them with the transition view. We will have to manually move this around as the user pans.

```swift
fromReferenceImageView.isHidden = true
toReferenceImageView.isHidden = true
```

**Step 2: Capture the starting and current positions.**

A constant `anchorPoint` is created and holds the center of the original/source image view frame. In addition, `translatedPoint` captures the movement of the pan within this view.

```swift
let anchorPoint = CGPoint(x: fromReferenceImageViewFrame.midX, y: fromReferenceImageViewFrame.midY)
let translatedPoint = gestureRecognizer.translation(in: fromVC.view)
```

**Step 3: Adjust the change in vertical displacemet according to the device's orientation.**

This step adjusts the change in vertical displacement according to the orientation of the device. Further, it only takes *positive* (i.e. down) vertical changes.

```swift
var verticalDelta: CGFloat = 0.0
if UIDevice.current.orientation.isLandscape {
	verticalDelta = max(translatedPoint.x, 0.0)
} else {
	verticalDelta = max(translatedPoint.y, 0.0)
}
```

**Step 4: Calculate the level of transparency and scaling according to the progress of the pan.**

The transparency that the background should have and the scales of the transition image is calculated from the displacement. I will not go into detail about how each of the functions that perform these calculations operate because they are actually rather simple. In escence, they each have a cut-off for where the maximum displacement should be and find where the current displacement is, accordingly.

The new transparency is set as the alpha of the source view contraoller and the destination tab controller.

The calculated scale is used to transform the size of the transition image view and also, in conjunction with `anchorPoint` and `translatedPoint`, to redefine the center of the image view.

```swift
let fromVCBackgroundAlpha = calculateBrackgroundAlphaFor(fromVC.view, atDelta: verticalDelta)
let scale = calculateScaleIn(fromVC.view, atDelta: verticalDelta)

fromVC.view.alpha = fromVCBackgroundAlpha
toVC.tabBarController?.tabBar.alpha = 1 - fromVCBackgroundAlpha

transitionImageView.transform = CGAffineTransform(scaleX: scale, y: scale)
let newCenterX = anchorPoint.x + translatedPoint.x
let newCenterY = anchorPoint.y + translatedPoint.y - transitionImageView.frame.height * (1 - scale) / 2.0
let newCenter = CGPoint(x: newCenterX, y: newCenterY)
transitionImageView.center = newCenter
```


**Step 5: Update the transition.**

Using the method `transitionContext.updateInteractiveTransition(1 - scale)`, the transition is incremented depending on where the pan gesture is. The scale will get smaller as the gesture progresses, therefore, this method call will move the transition forward as the user pans.

```swift
transitionContext.updateInteractiveTransition(1 - scale)
```

**Step 6: Recognize of the pan gesture has ended.**

If the pan gesture finishes (the user releases the image), then the animation must continue similarly to how the zoom animation was created. If the pan gesture has not ended, then this is the end of the function (until the pan moves again).

```swift
if gestureRecognizer.state == .ended {
	...
```

**Step 7: Register and assess the velocity of the pan.**

If the user did finish their pan gesture, then the velocity of the gesture is collected from `gestureRecognizer` and the decision of whether to cancel or finish the transition is made. If there is upward velocity of the gesture or the transition image is above the original image view (taking into account the device's orientation), then the transition needs to cancel.

```swift
let velocity = gestureRecognizer.velocity(in: fromVC.view)

var velocityCheck = false

if UIDevice.current.orientation.isLandscape {
	velocityCheck = velocity.x < 0 || newCenter.x < anchorPoint.x
} else {
	velocityCheck = velocity.y < 0 || newCenter.y < anchorPoint.y
}
```

**Step 8: Finish the animation and *cancel* the transition.**

If there is an upward velocity or the transition image view is above the source image view, the animation returns the transtion image view back to the source image view's frame, and the transtion is *canceled* using `transitionContext.cancelInteractiveTransition()`.

```swift
if velocityCheck {
	print("cancelling interactive transition")
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
```

**Step 9: Finish the animation and transition.**

If the above conditions were not met, then the animation for the transition is completed and the transition is *finished* using `self.transitionContext?.finishInteractiveTransition()`.

```swift
print("finishing interactive transition")
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
```

#### Confroming to `UIViewControllerInteractiveTransitioning`

The `ZoomDismissalInteractionController` must conform to `UIViewControllerInteractiveTransitioning` in order to respond to interactive transition gestures. It requires just one method, `startInteractiveTransition(transitionContext:)`, which is called first during the transition and used to set up the custom transition. Apple's documentation of the method is as follows:

> Your implementation of this method should use the data in the `transitionContext` parameter to configure user interactivity for the transition and then start the animations.

```swift
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
```

### Add option of interactive transition to `ZoomTransitionController`

An interactive controller object and a boolean for whether the transition is interactive are added as stored properties to `ZoomTransitionController`. The intiailization of the interaction controller is also added to the `init()` method.

```swift
// for interactive transitions
let interactionController: ZoomDismissalInteractionController
var isInteractive: Bool = false
```

To make responding the gestures a bit easier (and better adhere to MVC), a wrapper was added in `ZoomTransitionController`.

```swift
func didPanWith(gestureRecognizer: UIPanGestureRecognizer) {
	interactionController.didPanWith(gestureRecognizer: gestureRecognizer)
}
```
The next two methods added to the transition and navigation delegate extensions of `ZoomTransitionController` indicate whether the interactive transition should be used or not.

To make the transition interactive, one method must be included for the `UIViewControllerTransitioningDelegate`.

```swift
func interactionControllerForDismissal(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
	if !self.isInteractive {
		return nil
	}
	self.interactionController.animator = animator
	return self.interactionController
}
```

Also, a method must be added for `UINavigationControllerDelegate`.

```swift
func navigationController(_ navigationController: UINavigationController, interactionControllerFor animationController: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
	if !self.isInteractive {
		return nil
	}
	self.interactionController.animator = animator
	return self.interactionController
}
```

### Recognizing the pan gesture in `PagingCollectionViewController`

A pan gesture recognizer was added to `PagingCollectionViewController` in `viewDidLoad()`.

```swift
let panGesture = UIPanGestureRecognizer(target: self, action: #selector(userDidPanWith(gestureRecognizer:)))
view.addGestureRecognizer(panGesture)
```
The `userDidPanWith(gestureRecognizer:)` method was fairly simple, just responding to the start and end of the gesure by switching on or off the interactive transition. Otherwise (in `default`), the pan gesture was just passed to the transition controller.

```swift
@objc func userDidPanWith(gestureRecognizer: UIPanGestureRecognizer) {
	switch gestureRecognizer.state {
	case .began:
		transitionController.isInteractive = true
		let _ = navigationController?.popViewController(animated: true)
	case .ended:
		if transitionController.isInteractive {
			transitionController.isInteractive = false
			transitionController.didPanWith(gestureRecognizer: gestureRecognizer)
		}
	default:
		if transitionController.isInteractive {
			transitionController.didPanWith(gestureRecognizer: gestureRecognizer)
		}
	}
}
```

### Finished!

<img src="progress_screenshots/zoom_animation_interactive_HD.gif" width="300"/>
<img src="progress_screenshots/zoom_animation_interactive_short.gif" width="300"/>