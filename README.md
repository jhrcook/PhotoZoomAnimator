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

	// STEP 1 //
	// start the destination as transparent and hidden
	let toSnapshot = toVC.view.snapshotView(afterScreenUpdates: true)!
	toSnapshot.alpha = 0.0
	toVC.view.alpha = 0.0
	containerView.addSubview(toVC.view)
	containerView.addSubview(toSnapshot)

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
	let finalTransitionSize = calculateZoomInImageFrame(image: referenceImage, forView: toView)

	// STEP 5 //
	// animation
	UIView.animate(
		withDuration: transitionDuration(using: transitionContext),
		delay: 0,
		usingSpringWithDamping: 0.8,
		initialSpringVelocity: 0,
		options: [.transitionCrossDissolve, .curveEaseOut],
		animations: {
			toSnapshot.alpha = 1.0
			toVC.view.alpha = 1.0
			self.transitionImageView?.frame = finalTransitionSize  // animate size of image view
			fromVC.tabBarController?.tabBar.alpha = 0              // animate transparency of tab bar out
		},
		completion: { _ in
			// remove transition image view and show both view controllers, again
			self.transitionImageView?.removeFromSuperview()
			self.transitionImageView = nil
			toSnapshot.removeFromSuperview()
			
			fromReferenceImageView.isHidden = false
			
			// end the transition (unless was cancelled)
			transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
			
			// these are optional functions in the delegates that get called after the animation runs
			self.toDelegate?.transitionDidEndWith(zoomAnimator: self)
			self.fromDelegate?.transitionDidEndWith(zoomAnimator: self)
		})
}
```

The preparation for the animation is to first gather the image view controllers and image views from the source and destination. Also, the *source* image view's frame in the transition view is requested.

Before the animation runs, the `transitionWillStart(zoomAnimator:)` methods are run for both delegates. This is just a helper function and need not do anything. It is used by the `PagingCollectionViewController`, explained later.

**Step 1: Hide the destination image view.**

To begin, the destination view controller is set to fully transparent, then added to the `containerView`. It is now ready to be animated in.

**Step 2: Create an image view to animate during the transition.**

A reference image is obtained from the source image view and made the image for `transitionImageView` if it is `nil` (which is usually will be). The image view is prepared in standard ways, and then the image view's frame is set to `fromReferenceImageViewFrame` such that it is now exactly overlapping the source image view. (The authors of this code use a stand-in object *also* named `transitionImageView`, though I do not think it is necessary.) At the end, the `transitionImageView` is added to the transition's `containerView` so it can be animated to move from the source cell's frame to the destination cell image's frame.

**Step 3: Hide the source image view.**

The source image view is hidden so that the `transitionImageView` appears to be the same image during the animation. (This is a bit difficult to explain, but just look for it in the animation and it will make sense.)

**Step 4: Calculate the final size of the destination image view**

The function `calculateZoomInImageFrame(image:forView:)` returns a `CGRect` with the dimensions of the frame to fit the reference image in the destination view controller's view. This function is explained further down below, but here it just provides the target location of for `transitionImageview`.

**Step 5: Animate the image zooming from the source frame to the destination frame.**

The `UIView.animate()` method is passed vlalues for its appropriately-named arguments. For options, it is passed `UIView.AnimationOptions.transitionCrossDissolve` (the "fading" animation) and `curveEaseOut`. The `animations` closure changes the destination view controller's view transparency back to 1, scales the `transitionImageView` frame to the final size calculated in Step 4, and the source tab bar (if available) is made transparent.

When the animation is complete, the transition image view is removed and made `nil` and the source image view is un-hidden (though it will still not be visible because the source view controller is now behind the destination view controller). The final touch is to only complete the transition if it was not cancelled: `transitionContext.completeTransition(!transitionContext.transitionWasCancelled)`. Therefore, when a gesture is used to control the animation, if the gesture is undone (e.g. panning back to the original location), the transition will not continue.

Once all of the transition stuff has been dealt with, the `transitionDidEndWith(zoomAnimator:)` methods for both the source and destination view controllers are run. These are just helper functions for the view controllers.


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

## Setting up `BaseCollectionViewController` and `PagingCollectionViewController` for animation

### Adding a transition controller

A transition controller is added as a stored property to **`PagingCollectionViewController`**, the *destination* view controller. This location is chosen (over `BaseCollectionViewController`) because this is where the dismissing gesture will eventually be added. 

```swift
class PagingCollectionViewController: UICollectionViewController {
    var startingIndex: Int = 0
    var images = [UIImage]()
    var currentIndex = 0
    
    var transitionController = ZoomTransitionController()
    
    override func viewDidLoad() {
    	...
```

### Setting delegates during segue

The next change is in the `prepare(for:sender:)` method of `BaseCollectionViewController`. Currently, this type casts the destination view controller as `PagingCollectionViewController` then sets its `images` and `startingIndex` properties with the images and index of the selected cell in `BaseCollectionViewController`.

The first addition is to set the navigation controller delegate of the *current* view controller to the `ZoomTransitionController` of the destination view controller.

```swift
self.navigationController?.delegate = destinationViewController.transitionController
```

Then the source and destination `ZoomAnimatorDelegate`s are set for the `ZoomTransitionController` of the destination view controller.

### The `PagingCollectionViewControllerDelegate` protocol

If the user selects image at index 0 from the base view, then swipes over to index 1 in the paging view, and then returns to the base view, we need to tell the `BaseCollectionViewController` that the new index is 1, not 0 like it originally thought. Therefore, I created a protocol called `PagingCollectionViewControllerDelegate` with a single function `containerViewController(_:indexDidChangeTo:)`. To use this protocol, a new stored property of `PagingCollectionViewController` was created and a the method was called on the delegate after each paging swipe finished:

```swift
var containerDelegate: PagingCollectionViewControllerDelegate?
...
// change the base view controller's index, too
override func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
	containerDelegate?.containerViewController(self, indexDidChangeTo: currentIndex)
}
```

and the `BaseCollectionViewController` was set to the delegate during the segue:

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

The last step is to have both `BaseCollectionViewController` and `PagingCollectionViewController` conform to `ZoomAnimatorDelegate`.

#### `BaseCollectionViewController`

Nothing is to be done specifically right before or after the transition animation, so the `transitionWillStartWith(zoomAnimator:)` and `transitionDidEndWith(zoomAnimator:)` methods are left empty.

Both the `referenceImageView(for:) -> UIImageView?` and `referenceImageViewFrameInTransitioningView(for:) -> CGRect?` methods first need to get the correct cell to return. Therefore, I created the `getCell(for:)` method. If the animation `isPresenting`, then the index of the correct cell to use must be obtained using `collectionView.indexPathsForSelectedItems?.first`. If the zoom animation is not presenting, then the index of the cell to use is the `currentIndex` which is updated by the `PagingCollectionViewController` using the `PagingCollectionViewControllerDelegate` protocol. Once the correct index has been found, the cell is retrieved.

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

The `referenceImageView(for:)` method needs to return an image view with the image of the selected cell image view. Therefore, it uses `getCell(for:)` and returns the cell's `imageView` property.
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

The `PagingCollectionViewController` was a bit more complicated. The major hurdle was to get around the fact that the cell being transitioned to is created after the animation begins and before the animation ends. Therefore, the image view of the destination cell could not be accessed by `ZoomAnimator`, but would appear during the transition. To see what I mean, I point out a change you can make to make the problem (but not the solution) very obvious. 

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

The final line in `transitionDidEndWith(zoomAnimator:)` just reloads the current cell with `hideCellImageViews` set to `false`. The new stored property of `PagingCollectionViewController`, `hideCellImageViews: Bool` takes effect during the creation of the collection view's cells.

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


## Interactive transition

From here, I will make the dismissal react to gestures. The goal is to have the user be able to pan the image up or down to induce the transition, and have the image "dragged" by the pan as long as the user hold on.
