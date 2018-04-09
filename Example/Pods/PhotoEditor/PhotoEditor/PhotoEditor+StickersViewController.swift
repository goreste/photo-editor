//
//  PhotoEditor+StickersViewController.swift
//  Pods
//
//  Created by Mohamed Hamed on 6/16/17.
//
//

import Foundation
import UIKit
import Gifu

extension PhotoEditorViewController {
    func addStickersViewController() {
        stickersVCIsVisible = true
        hideToolbar(hide: true)
        self.canvasImageView.isUserInteractionEnabled = false
        stickersViewController.stickersViewControllerDelegate = self
        
        for image in viewModel.stickers {
            stickersViewController.stickers.append(image)
        }
        for gifUrl in viewModel.gifUrls {
            stickersViewController.gifs.append(gifUrl)
        }

        self.addChildViewController(stickersViewController)
        self.view.addSubview(stickersViewController.view)
        stickersViewController.didMove(toParentViewController: self)
        let height = view.frame.height
        let width  = view.frame.width
        stickersViewController.view.frame = CGRect(x: 0, y: self.view.frame.maxY , width: width, height: height)
    }
    
    func removeStickersView() {
        stickersVCIsVisible = false
        self.canvasImageView.isUserInteractionEnabled = true
        UIView.animate(withDuration: 0.3,
                       delay: 0,
                       options: UIViewAnimationOptions.curveEaseIn,
                       animations: { () -> Void in
                        var frame = self.stickersViewController.view.frame
                        frame.origin.y = UIScreen.main.bounds.maxY
                        self.stickersViewController.view.frame = frame
                        
        }, completion: { (finished) -> Void in
            self.stickersViewController.view.removeFromSuperview()
            self.stickersViewController.removeFromParentViewController()
            self.hideToolbar(hide: false)
        })
    }    
}

extension PhotoEditorViewController: StickersViewControllerDelegate {
    func didSelectGif(gifUrl: URL, index: Int) {
        self.removeStickersView()
        
        let imageView = GIFImageView()
        imageView.tag = index
        imageView.clipsToBounds = true
        imageView.center = canvasImageView.center
        imageView.contentMode = .scaleAspectFill
        imageView.frame.size = CGSize.zero
        imageView.animate(withGIFURL: gifUrl, loopCount: 0) { [weak self] in
            guard let `self` = self else { return }
            DispatchQueue.main.async {
                self.canvasImageView.addSubview(imageView)
                self.addGestures(view: imageView)
            }
        }
    }
    
    public override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        if let avatarSize = viewModel.avatarImage.suitableSize(widthLimit: imageView.frame.width) {
            avatarImageView.frame = CGRect(x: imageView.frame.width / 2 - avatarSize.width / 2, y: imageView.frame.height / 2 - avatarSize.height / 2, width: avatarSize.width, height: avatarSize.height)
        }

        self.canvasImageView.subviews.forEach { imageView in
            if imageView.isKind(of: GIFImageView.classForCoder()) {
                if imageView.frame.size == CGSize.zero {
                    imageView.frame = CGRect(x: imageView.frame.origin.x, y: imageView.frame.origin.y, width: imageView.intrinsicContentSize.width, height: imageView.intrinsicContentSize.height)
                    imageView.center = canvasImageView.center
                }
            }
        }
    }
    
    func didSelectView(view: UIView) {
        self.removeStickersView()
        
        view.center = canvasImageView.center
        self.canvasImageView.addSubview(view)
        //Gestures
        addGestures(view: view)
    }
    
    func didSelectImage(image: UIImage) {
        self.removeStickersView()
        
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.frame.size = CGSize(width: 150, height: 150)
        imageView.center = canvasImageView.center
        
        self.canvasImageView.addSubview(imageView)
        //Gestures
        addGestures(view: imageView)
    }
    
    func stickersViewDidDisappear() {
        stickersVCIsVisible = false
        hideToolbar(hide: false)
    }
    
    func addGestures(view: UIView) {
        //Gestures
        view.isUserInteractionEnabled = true
        
        let panGesture = UIPanGestureRecognizer(target: self,
                                                action: #selector(PhotoEditorViewController.panGesture))
        panGesture.minimumNumberOfTouches = 1
        panGesture.maximumNumberOfTouches = 1
        panGesture.delegate = self
        view.addGestureRecognizer(panGesture)
        
        let pinchGesture = UIPinchGestureRecognizer(target: self,
                                                    action: #selector(PhotoEditorViewController.pinchGesture))
        pinchGesture.delegate = self
        view.addGestureRecognizer(pinchGesture)
        
        let rotationGestureRecognizer = UIRotationGestureRecognizer(target: self,
                                                                    action:#selector(PhotoEditorViewController.rotationGesture))
        rotationGestureRecognizer.delegate = self
        view.addGestureRecognizer(rotationGestureRecognizer)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(PhotoEditorViewController.tapGesture))
        view.addGestureRecognizer(tapGesture)
        
    }
}
