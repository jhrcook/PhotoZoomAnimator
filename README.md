#PhotoZoomAnimator

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


