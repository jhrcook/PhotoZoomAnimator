//
//  PagingCollectionViewController.swift
//  PhotoZoomAnimator
//
//  Created by Joshua on 8/6/19.
//  Copyright © 2019 JHC Dev. All rights reserved.
//

import UIKit

private let reuseIdentifier = "pagingImageCell"

class PagingCollectionViewController: UICollectionViewController {

    var startingIndex: Int = 0
    var images = [UIImage]()
    
    var currentIndex = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Register cell classes
        self.collectionView!.register(PagingCollectionViewCell.self, forCellWithReuseIdentifier: reuseIdentifier)
        
        // Do any additional setup after loading the view.
        setupCollectionView()
        currentIndex = startingIndex
    }
    
    func setupCollectionView() {
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.showsVerticalScrollIndicator = false
        collectionView.isPagingEnabled = true
        collectionView.alwaysBounceHorizontal = true
        collectionView.alwaysBounceVertical = true
        
        collectionView.contentSize = CGSize(width: view.frame.width * CGFloat(images.count), height: 0.0)
        
        // collectionView.delegate = self
        collectionView.dataSource = self
        
        // set initial index at `startingIndex`
        collectionView.scrollToItem(at: IndexPath(item: startingIndex, section: 0), at: .right, animated: false)
    }

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }


    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return images.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! PagingCollectionViewCell
    
        cell.image = images[indexPath.item]
    
        return cell
    }
    
    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        var imageNumber = Float((scrollView.contentOffset.x - 0.5 * view.frame.width) / view.frame.width)
        imageNumber.round(.up)
        currentIndex = Int(imageNumber)
    }

}



// sizing of collection view cells
extension PagingCollectionViewController: UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return view.frame.size
    }
    
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 0.0
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 0.0
    }
}
