//
//  PhotoEditor+Controls.swift
//  Pods
//
//  Created by Mohamed Hamed on 6/16/17.
//
//

import Foundation
import UIKit
import Gifu
import PromiseKit
import CoreImage

// MARK: - Control
public enum control {
    case crop
    case sticker
    case draw
    case text
    case save
    case share
    case clear
}

extension PhotoEditorViewController {

     //MARK: Top Toolbar
    @IBAction func closeButtonTapped(_ sender: Any) {
        photoEditorDelegate?.canceledEditing()
    }

    func cropButtonTapped(_ sender: UIButton) {
//        let controller = CropViewController()
//        controller.delegate = self
//        controller.image = viewModel.backgroundImage
//        let navController = UINavigationController(rootViewController: controller)
//        present(navController, animated: true, completion: nil)
    }

    @IBAction func gifButtonTapped(_ sender: Any) {
        addStickersViewController()
        doneButton.isHidden = true
    }

    @IBAction func drawButtonTapped(_ sender: Any) {
        isDrawing = true
        canvasImageView.isUserInteractionEnabled = false
        shareButton.isHidden = false
        colorPickerView.isHidden = false
        hideToolbar(hide: true)
        doneButton.isHidden = false
    }

    @IBAction func textButtonTapped(_ sender: Any) {
        isTyping = true
        let textView = UITextView(frame: CGRect(x: 0, y: canvasImageView.center.y,
                                                width: UIScreen.main.bounds.width, height: 30))
        
        textView.textAlignment = .center
        textView.font = UIFont(name: "Helvetica", size: 30)
        textView.textColor = textColor
        textView.layer.shadowColor = UIColor.black.cgColor
        textView.layer.shadowOffset = CGSize(width: 1.0, height: 0.0)
        textView.layer.shadowOpacity = 0.2
        textView.layer.shadowRadius = 1.0
        textView.autocorrectionType = .no
        textView.isScrollEnabled = false
        textView.delegate = self
        textView.layer.backgroundColor = UIColor.clear.cgColor
        textView.backgroundColor = .clear
//        #if DEBUG
//            textView.layer.backgroundColor = UIColor.red.cgColor
//            textView.backgroundColor = .red
//        #endif
        textView.clipsToBounds = false
        textView.layer.masksToBounds = false
        textView.adjustsFontForContentSizeCategory = true
        self.canvasImageView.addSubview(textView)
        addGestures(view: textView)
        textView.becomeFirstResponder()
        doneButton.isHidden = false
    }    
    
    @IBAction func doneButtonTapped(_ sender: Any) {
        view.endEditing(true)
        shareButton.isHidden = false
        colorPickerView.isHidden = true
        canvasImageView.isUserInteractionEnabled = true
        hideToolbar(hide: false)
        isDrawing = false
        doneButton.isHidden = true
    }
    
    //MARK: Bottom Toolbar
    
    func saveButtonTapped(_ sender: AnyObject) {
        UIImageWriteToSavedPhotosAlbum(canvasView.toImage(),self, #selector(PhotoEditorViewController.image(_:withPotentialError:contextInfo:)), nil)
    }
    
    @IBAction func shareButtonTapped(_ sender: UIButton) {
        startExportingVideo()
        doneButton.isHidden = true
    }
    
    func presentShare(videoURL: URL) {
        let activity = UIActivityViewController(activityItems: [videoURL], applicationActivities: nil)
        present(activity, animated: true, completion: nil)
    }
    
    func clearButtonTapped(_ sender: AnyObject) {
//        //clear drawing
//        canvasImageView.image = nil
//        //clear stickers and textviews
//        for subview in canvasImageView.subviews {
//            subview.removeFromSuperview()
//        }
    }
    
    func startExportingVideo() {
        self.photoEditorDelegate?.photoEditorStarCreatingVideo()
        let gifImageViews = self.canvasImageView.subviews.filter({ $0.isKind(of: GIFImageView.classForCoder()) }) as? [GIFImageView] ?? []
        var gifRemoteUrls: [URL] = []
        self.canvasImageView.subviews.forEach { view in
            if view.isKind(of: GIFImageView.classForCoder()) {
                if view.tag < viewModel.gifUrls.count {
                    gifRemoteUrls.append(viewModel.gifUrls[view.tag])
                }
            }
        }
        
        
        
        
        var avatarImage = viewModel.avatarImage
        if let itemsImage = self.canvasImageView.image, let imageItems = ImageUtil().mergeImages(backgroundImage: avatarImage, overImage: itemsImage){
            avatarImage = imageItems
        }
        self.canvasImageView.subviews.forEach { view in
            if view.isKind(of: GIFImageView.classForCoder()) == false {
                guard let tempImage = self.canvasImageView.screenshot(view: view) else { return }
                guard let cgImage = tempImage.cgImage else { return }
                
                
                let txtRotation = VideoExporter.shared.rotation(t: view.transform)
                let xScale = VideoExporter.shared.xScale(t: view.transform)
                let yScale = VideoExporter.shared.yScale(t: view.transform)
                
                let txtWidth = view.bounds.width * xScale
                let txtHeight = view.bounds.height * yScale

                var identity = CGAffineTransform.identity

                
                
                let adjacent = txtWidth / 2
                let opposite = txtHeight / 2
                let hipotenuse = sqrt(pow(adjacent, 2) + pow(opposite, 2))
                let thetaRad = acos((pow(hipotenuse, 2) + pow(adjacent, 2) - pow(opposite, 2)) / (2 * hipotenuse * adjacent))
                let angleRad: CGFloat = txtRotation
                
                let widthOffset = cos(angleRad - thetaRad) * hipotenuse
                let heightOffset = sin(angleRad - thetaRad) * hipotenuse
                let offsetPointOrigin = CGPoint(x: view.center.x + heightOffset, y: view.center.y - widthOffset)
                
                let txtSizeScaled = CGSize(width: xScale, height: yScale)
                
                identity = identity.concatenating(CGAffineTransform(scaleX: txtSizeScaled.width, y: txtSizeScaled.height))
                identity = identity.concatenating(CGAffineTransform(rotationAngle: -txtRotation))
                identity = identity.concatenating(CGAffineTransform(translationX: offsetPointOrigin.x, y: offsetPointOrigin.y))

                
                
                let ciImage = CIImage(cgImage: cgImage)
                let coreImage = ciImage.transformed(by: identity)
                let imageFromCIImage = UIImage(ciImage: coreImage)
                
                let customScalewidth = avatarImage.size.width / canvasImageView.frame.size.width
                let customScaleHeight = avatarImage.size.height / canvasImageView.frame.size.height
                guard let imageItems = ImageUtil().mergeImages(backgroundImage: avatarImage, overImage: imageFromCIImage, overImageSize: CGRect(x: view.frame.origin.x * customScalewidth, y: view.frame.origin.y * customScaleHeight, width: view.frame.size.width * customScalewidth, height: view.frame.size.height * customScaleHeight)) else { return }
                avatarImage = imageItems
            } 
        }

        if let backgroundVideoUrl = viewModel.backgroundVideoUrl {// there is already a video as background
            exportVideo(avatarImage: avatarImage, editorViewSize: self.canvasImageView.frame.size, gifImageViews: gifImageViews, gifRemoteUrls: gifRemoteUrls, backgroundVideoUrl: backgroundVideoUrl)
                .done { [weak self] finalVideoUrl in
                    guard let `self` = self else { return }
                    self.photoEditorDelegate?.photoEditor(videoCreatedAt: finalVideoUrl)
                    self.presentShare(videoURL: finalVideoUrl)
                }.catch { error in
//                    guard let `self` = self else { return }
//                    self.photoEditorDelegate?.photoEditorError(finishedWith: error)
                    print("Error exporting video: \(error)")
            }
        }else if let backgroundImage = viewModel.backgroundImage {// create a video with background static image
            
            GifExporter().exportAnimatedGif(image: backgroundImage)
                .then { backgroundGifUrl -> Promise<URL> in
                    return GifExporter().convertGifIntoVideo(remoteUrl: backgroundGifUrl)
                }.then { [weak self] backgroundUrl -> Promise<URL> in
                    guard let `self` = self else { return Promise(error: Error.returnIsNil)}
                    return self.exportVideo(avatarImage: avatarImage, editorViewSize: self.canvasImageView.frame.size, gifImageViews: gifImageViews, gifRemoteUrls: gifRemoteUrls, backgroundVideoUrl: backgroundUrl)
                }.done { [weak self] finalVideoUrl -> Void in
                    guard let `self` = self else { return }
                    self.photoEditorDelegate?.photoEditor(videoCreatedAt: finalVideoUrl)
                    
                    self.presentShare(videoURL: finalVideoUrl)
                }.catch { error in
//                    guard let `self` = self else { return }
//                    self.photoEditorDelegate?.photoEditorError(finishedWith: error)
                    print("error while creating temp videos: \(error)")
            }
        }
    }
    
    func exportVideo(avatarImage: UIImage, editorViewSize: CGSize, gifImageViews: [GIFImageView], gifRemoteUrls: [URL], backgroundVideoUrl: URL) -> Promise<URL> {
        return self.viewModel.getVideoTempUrls(remoteUrls: gifRemoteUrls)
            .then { gifTempVideoUrls -> Promise<URL> in
                VideoExporter.shared.createVideo(avatarImage: avatarImage, editorViewSize: editorViewSize, onlyWithAvatar: true, gifImageViews: gifImageViews, videoUrls: gifTempVideoUrls, backgroundVideoUrl: backgroundVideoUrl)
            }
            .then { videoWithAvatarURL -> Promise<URL> in
                VideoExporter.shared.createVideo(avatarImage: avatarImage, editorViewSize: editorViewSize, onlyWithAvatar: false, backgroundVideoUrl: videoWithAvatarURL)
            }
//            .done { finalVideoURL -> Promise<URL> in
//                return Promise.value(finalVideoURL)
//            }
    }
    
    
    //MARK: helper methods
    
    @objc func image(_ image: UIImage, withPotentialError error: NSErrorPointer, contextInfo: UnsafeRawPointer) {
        let alert = UIAlertController(title: "Image Saved", message: "Image successfully saved to Photos library", preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    @objc func hideControls() {
//        for control in hiddenControls {
//            switch control {
            
//            case .clear:
//                clearButton.isHidden = true
//            case .crop:
//                cropButton.isHidden = true
//            case .draw:
//                drawButton.isHidden = true
//            case .save:
//                saveButton.isHidden = true
//            case .share:
//                shareButton.isHidden = true
//            case .sticker:
//                gifButton.isHidden = true
//            case .text:
//                gifButton.isHidden = true
//            }
//        }
    }
    
}

extension PhotoEditorViewController {
    enum Error: Swift.Error {
        case selfIsNil
        case returnIsNil
    }
}
