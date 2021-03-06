//
//  PhotoEditor+Gestures.swift
//  Photo Editor
//
//  Created by Mohamed Hamed on 6/16/17.
//
//

import Foundation
import UIKit
import Gifu

extension PhotoEditorViewController : UIGestureRecognizerDelegate  {
    
    /**
     UIPanGestureRecognizer - Moving Objects
     Selecting transparent parts of the imageview won't move the object
     */
    @objc func panGesture(_ recognizer: UIPanGestureRecognizer) {
        if let view = recognizer.view {
            if view is UIImageView {
                //Tap only on visible parts on the image
                if recognizer.state == .began {
                    for imageView in subImageViews(view: canvasImageView) {
                        let location = recognizer.location(in: imageView)
                        let alpha = imageView.alphaAtPoint(location)
                        if alpha > 0 {
                            imageViewToPan = imageView
                            break
                        }
                    }
                }
                if imageViewToPan != nil {
                    moveView(view: imageViewToPan!, recognizer: recognizer)
                }
            } else {
                moveView(view: view, recognizer: recognizer)
            }
        }
    }
    
    /**
     UIPinchGestureRecognizer - Pinching Objects
     If it's a UITextView will make the font bigger so it doen't look pixlated
     */
    @objc func pinchGesture(_ recognizer: UIPinchGestureRecognizer) {
        if let view = recognizer.view {
            if view is UITextView, let textView = view as? UITextView, let textViewFont = textView.font {

                //                view.layer.transform = CATransform3DMakeRotation (angle, 0, 0, 1);
                
//                textView.transform = textView.transform.scaledBy(x: recognizer.scale, y: recognizer.scale)

                
//                if([(UIPinchGestureRecognizer*)sender state] == UIGestureRecognizerStateEnded) {
//
//                    lastScale = 1.0;
//                    return;
//                }
//                CGFloat scale = 1.0 - (lastScale - [(UIPinchGestureRecognizer*)sender scale]);
//
//                CGAffineTransform currentTransform = [(UIPinchGestureRecognizer*)sender view].transform;
//                CGAffineTransform newTransform = CGAffineTransformScale(currentTransform, scale, scale);
//
//                [[(UIPinchGestureRecognizer*)sender view] setTransform:newTransform];
//
//                lastScale = [(UIPinchGestureRecognizer*)sender scale];

                
                let scale = 1.0 - (lastScale - recognizer.scale)
                let currentTranform = textView.transform
                let newTransform = currentTranform.scaledBy(x: scale, y: scale)
                textView.transform = newTransform
                lastScale = recognizer.scale
                
                
                
//                if textViewFont.pointSize * recognizer.scale < 90 {
//                    let font = UIFont(name: textViewFont.fontName, size: textViewFont.pointSize * recognizer.scale)
//                    textView.font = font
//                    let sizeToFit = textView.sizeThatFits(CGSize(width: UIScreen.main.bounds.size.width,
//                                                                 height:CGFloat.greatestFiniteMagnitude))

//                    textView.bounds.size = CGSize(width: textView.intrinsicContentSize.width,
//                                                  height: sizeToFit.height)

                //                    print("up \(sizeToFit)")
//                    print("down \(textView.bounds.size) \(textView.frame.size)")
//                } else {
//                    let sizeToFit = textView.sizeThatFits(CGSize(width: UIScreen.main.bounds.size.width,
//                                                                 height:CGFloat.greatestFiniteMagnitude))
//                    textView.bounds.size = CGSize(width: textView.intrinsicContentSize.width,
//                                                  height: sizeToFit.height)
//                    print("down \(textView.bounds.size) \(textView.frame.size)")
//                }
            
//                textView.setNeedsDisplay()
            } else {
                view.transform = view.transform.scaledBy(x: recognizer.scale, y: recognizer.scale)
                recognizer.scale = 1
            }
        }
    }
    
    /**
     UIRotationGestureRecognizer - Rotating Objects
     */
    @objc func rotationGesture(_ recognizer: UIRotationGestureRecognizer) {
        if let view = recognizer.view {
            view.transform = view.transform.rotated(by: recognizer.rotation)
            recognizer.rotation = 0
        }
    }
    
    /**
     UITapGestureRecognizer - Taping on Objects
     Will make scale scale Effect
     Selecting transparent parts of the imageview won't move the object
     */
    @objc func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if let view = recognizer.view {
            if view is UIImageView {
                //Tap only on visible parts on the image
                for imageView in subImageViews(view: canvasImageView) {
                    let location = recognizer.location(in: imageView)
                    let alpha = imageView.alphaAtPoint(location)
                    if alpha > 0 {
                        scaleEffect(view: imageView)
                        break
                    }
                }
            } else {
                scaleEffect(view: view)
            }
        }
    }
    
    /*
     Support Multiple Gesture at the same time
     */
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }
    
    @objc func screenEdgeSwiped(_ recognizer: UIScreenEdgePanGestureRecognizer) {
        if recognizer.state == .recognized {
            if !stickersVCIsVisible {
                addStickersViewController()
            }
        }
    }
    
    // to Override Control Center screen edge pan from bottom
    override public var prefersStatusBarHidden: Bool {
        return true
    }
    
    /**
     Scale Effect
     */
    func scaleEffect(view: UIView) {
        view.superview?.bringSubview(toFront: view)
        
        if #available(iOS 10.0, *) {
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.impactOccurred()
        }
        let previouTransform =  view.transform
        UIView.animate(withDuration: 0.2,
                       animations: {
                        view.transform = view.transform.scaledBy(x: 1.2, y: 1.2)
        },
                       completion: { _ in
                        UIView.animate(withDuration: 0.2) {
                            view.transform  = previouTransform
                        }
        })
    }
    
    /**
     Moving Objects 
     delete the view if it's inside the delete view
     Snap the view back if it's out of the canvas
     */
    func xScale(t: CGAffineTransform) -> CGFloat {
        return sqrt(t.a * t.a + t.c * t.c)
    }
    
    func yScale(t: CGAffineTransform) -> CGFloat {
        return sqrt(t.b * t.b + t.d * t.d)
    }

    func moveView(view: UIView, recognizer: UIPanGestureRecognizer)  {
        
        hideToolbar(hide: true)
        deleteView.isHidden = false
        
        view.superview?.bringSubview(toFront: view)
        let pointToSuperView = recognizer.location(in: self.view)


//        if view is UITextView {
//        }
        if view is GIFImageView {
            view.transform.tx = pointToSuperView.x - canvasImageView.frame.width / 2 //+ view.frame.width / 2
            view.transform.ty = pointToSuperView.y - canvasImageView.frame.height / 2 //+ view.frame.height / 2
        }else{
            view.center = CGPoint(x: view.center.x + recognizer.translation(in: canvasImageView).x,
                                  y: view.center.y + recognizer.translation(in: canvasImageView).y)
            recognizer.setTranslation(CGPoint.zero, in: canvasImageView)
        }
        
        
//        print(view.transform.tx + (canvasImageView.frame.width / 2), view.transform.ty + (canvasImageView.frame.height / 2))
//        let hipotenuse = sqrt(pow(view.frame.width, 2) + pow(view.frame.height, 2))
//        print(hipotenuse, canvasImageView.frame.width, view.frame.width, view.frame.height)

        if let previousPoint = lastPanPoint {
            //View is going into deleteView
            if deleteView.frame.contains(pointToSuperView) && !deleteView.frame.contains(previousPoint) {
                if #available(iOS 10.0, *) {
                    let generator = UIImpactFeedbackGenerator(style: .heavy)
                    generator.impactOccurred()
                }
                UIView.animate(withDuration: 0.3, animations: {
                    view.transform = view.transform.scaledBy(x: 0.25, y: 0.25)
                    view.center = recognizer.location(in: self.canvasImageView)
                })
            }
                //View is going out of deleteView
            else if deleteView.frame.contains(previousPoint) && !deleteView.frame.contains(pointToSuperView) {
                //Scale to original Size
                UIView.animate(withDuration: 0.3, animations: {
                    view.transform = view.transform.scaledBy(x: 4, y: 4)
                    view.center = recognizer.location(in: self.canvasImageView)
                })
            }
        }
        lastPanPoint = pointToSuperView
        
        if recognizer.state == .ended {
            imageViewToPan = nil
            lastPanPoint = nil
            hideToolbar(hide: false)
            deleteView.isHidden = true
            let point = recognizer.location(in: self.view)
            
            if deleteView.frame.contains(point) { // Delete the view
                view.removeFromSuperview()
                if #available(iOS 10.0, *) {
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                }
            } else if !canvasImageView.bounds.contains(view.center) { //Snap the view back to canvasImageView
                UIView.animate(withDuration: 0.3, animations: {
                    view.center = self.canvasImageView.center
                })
            }
        }
    }
    
    func subImageViews(view: UIView) -> [UIImageView] {
        var imageviews: [UIImageView] = []
        for imageView in view.subviews {
            if imageView is UIImageView {
                imageviews.append(imageView as! UIImageView)
            }
        }
        return imageviews
    }
}
