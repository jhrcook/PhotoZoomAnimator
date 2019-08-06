//
//  PagingCollectionViewCell.swift
//  PhotoZoomAnimator
//
//  Created by Joshua on 8/6/19.
//  Copyright © 2019 JHC Dev. All rights reserved.
//

import UIKit
import SnapKit

class PagingCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet var scrollView: UIScrollView!
    @IBOutlet var imageView: UIImageView!
    
    var image: UIImage? {
        didSet {
            configureForNewImage(animated: false)
        }
    }
    
    var zoomFactor: CGFloat = 3.0
    
    override init(frame: CGRect) {
        
        super.init(frame: frame)
        
        setupScrollView()
        setupImageView()
        scrollView.contentSize = imageView.frame.size
        
        // double tap to zoom
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(doubleTapAction))
        doubleTap.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTap)
        
    }
    
    
    // inserted by compiler/autocomplete
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    func setupScrollView() {
        scrollView = UIScrollView()
        scrollView.frame = frame
        scrollView.delegate = self
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceVertical = false
        scrollView.alwaysBounceHorizontal = false
        scrollView.contentInsetAdjustmentBehavior = .never
        contentView.addSubview(scrollView)
        scrollView.snp.makeConstraints { make in make.edges.equalTo(contentView) }
    }
    func setupImageView() {
        imageView = UIImageView()
        imageView.image = image
        imageView.contentMode = .scaleAspectFit
        scrollView.addSubview(imageView)
        imageView.snp.makeConstraints { make in make.edges.equalTo(scrollView) }
        
    }
    
    @objc func doubleTapAction(_ gestureRecognizer: UIGestureRecognizer) {
        if scrollView.zoomScale > scrollView.minimumZoomScale {
            scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
        } else {
            let tapLocation = gestureRecognizer.location(in: imageView)
            guard let imageSize = imageView.image?.size else { return }
            let zoomWidth = imageSize.width  / zoomFactor
            let zoomHeight = imageSize.height / zoomFactor
            scrollView.zoom(to: CGRect(center: tapLocation, size: CGSize(width: zoomWidth, height: zoomHeight)), animated: true)
        }
    }
    
}



// set up the image for a cell
extension PagingCollectionViewCell {
    func configureForNewImage(animated: Bool = true) {
        imageView.image = image
        imageView.sizeToFit()
        
        setZoomScale()
        scrollViewDidZoom(scrollView)
        
        if animated {
            imageView.alpha = 0.0
            UIView.animate(withDuration: 0.5) { self.imageView.alpha = 1.0}
        }
    }
}



// extension to handle zooming
extension PagingCollectionViewCell: UIScrollViewDelegate {
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        let imageViewSize = imageView.frame.size
        let scrollViewSize = scrollView.bounds.size
        
        let verticalPadding = imageViewSize.height < scrollViewSize.height ? (scrollViewSize.height - imageViewSize.height) / 2.0 : 0
        let horizontalPadding = imageViewSize.width < scrollViewSize.width ? (scrollViewSize.width - imageViewSize.width) / 2.0 : 0
        
        if verticalPadding >= 0 {
            scrollView.contentInset = UIEdgeInsets(top: verticalPadding, left: horizontalPadding, bottom: verticalPadding, right: horizontalPadding)
        } else {
            scrollView.contentSize = imageViewSize
        }
    }
    
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    
    func setZoomScale() {
        let imageViewSize = imageView.bounds.size
        let scrollViewSize = scrollView.bounds.size
        let widthScale = scrollViewSize.width / imageViewSize.width
        let heightScale = scrollViewSize.height / imageViewSize.height
        
        scrollView.minimumZoomScale = min(widthScale, heightScale)
        scrollView.setZoomScale(scrollView.minimumZoomScale, animated: false)
    }
}
