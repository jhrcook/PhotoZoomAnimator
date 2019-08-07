//
//  BaseCollectionViewController.swift
//  PhotoZoomAnimator
//
//  Created by Joshua on 8/6/19.
//  Copyright © 2019 JHC Dev. All rights reserved.
//

import UIKit

private let reuseIdentifier = "baseCollectionCell"

class BaseCollectionViewController: UICollectionViewController {
    
    let imagesNames = ["IMG_8365", "IMG_8366", "IMG_8367", "IMG_8368", "IMG_8380", "IMG_8390"]
    var images = [UIImage]()
    
    let numberOfImagesPerRow: CGFloat = 4.0
    let spacingBetweenCells: CGFloat = 0.1
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Register cell classes
        // self.collectionView!.register(UICollectionViewCell.self, forCellWithReuseIdentifier: reuseIdentifier)

        // Do any additional setup after loading the view.
        
        title = "Image Collection"
        collectionView.alwaysBounceVertical = true
        collectionView.delegate = self
        
        for imageName in imagesNames {
            if let image = UIImage(named: imageName) { images.append(image) }
        }
    }

    // MARK: UICollectionViewDataSource

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }


    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return images.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! BaseCollectionViewCell
        
        cell.imageView.image = images[indexPath.item]
        cell.imageView.contentMode = .scaleAspectFill
    
        return cell
    }

}


// sizing of collection view cells
extension BaseCollectionViewController: UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = view.frame.width / numberOfImagesPerRow - (spacingBetweenCells * numberOfImagesPerRow)
        return CGSize(width: width, height: width)
    }
    
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return spacingBetweenCells
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return spacingBetweenCells
    }
}


// segues
extension BaseCollectionViewController {
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let destinationViewController = segue.destination as? PagingCollectionViewController {
            // set stored properties of the destination `PagingCollectionViewController`
            destinationViewController.images = images
            if let indexPath = collectionView.indexPathsForSelectedItems?.first {
                destinationViewController.startingIndex = indexPath.item
            }
            
            // set the navigation controller delegate as the `ZoomTransitionController
            // of the destination `PagingCollectionViewController`
            self.navigationController?.delegate = destinationViewController.transitionController
            
            // set source and destination delegates for the transition controller
            destinationViewController.transitionController.fromDelegate = self
            destinationViewController.transitionController.toDelegate = destinationViewController
        }
    }
}


// ZoomAnimatorDelegate
extension BaseCollectionViewController: ZoomAnimatorDelegate {
    func transitionWillStartWith(zoomAnimator: ZoomAnimator) {
        // add code here to be run just before the transition animation
    }
    
    func transitionDidEndWith(zoomAnimator: ZoomAnimator) {
        // add code here to be run just after the transition animation
    }
    
    func referenceImageView(for zoomAnimator: ZoomAnimator) -> UIImageView? {
        if let indexPath = collectionView.indexPathsForSelectedItems?.first {
            return UIImageView(image: images[indexPath.item])
        }
        return nil
    }
    
    func referenceImageViewFrameInTransitioningView(for zoomAnimator: ZoomAnimator) -> CGRect? {
        if let indexPath = collectionView.indexPathsForSelectedItems?.first {
            if let cell = collectionView.cellForItem(at: indexPath) as? BaseCollectionViewCell {
                return collectionView.convert(cell.frame, to: view)
            }
        }
        return nil
    }
    
    
}
