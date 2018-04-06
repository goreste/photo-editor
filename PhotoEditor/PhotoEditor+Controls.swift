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
    
    @IBAction func cancelButtonTapped(_ sender: Any) {
        photoEditorDelegate?.canceledEditing()
        self.dismiss(animated: true, completion: nil)
    }

    @IBAction func cropButtonTapped(_ sender: UIButton) {
        let controller = CropViewController()
        controller.delegate = self
        controller.image = viewModel.backgroundImage
        let navController = UINavigationController(rootViewController: controller)
        present(navController, animated: true, completion: nil)
    }

    @IBAction func stickersButtonTapped(_ sender: Any) {
        addStickersViewController()
    }

    @IBAction func drawButtonTapped(_ sender: Any) {
        isDrawing = true
        canvasImageView.isUserInteractionEnabled = false
        doneButton.isHidden = false
        colorPickerView.isHidden = false
        hideToolbar(hide: true)
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
        textView.layer.backgroundColor = UIColor.clear.cgColor
        textView.autocorrectionType = .no
        textView.isScrollEnabled = false
        textView.delegate = self
        self.canvasImageView.addSubview(textView)
        addGestures(view: textView)
        textView.becomeFirstResponder()
    }    
    
    @IBAction func doneButtonTapped(_ sender: Any) {
        view.endEditing(true)
        doneButton.isHidden = true
        colorPickerView.isHidden = true
        canvasImageView.isUserInteractionEnabled = true
        hideToolbar(hide: false)
        isDrawing = false
    }
    
    //MARK: Bottom Toolbar
    
    @IBAction func saveButtonTapped(_ sender: AnyObject) {
        UIImageWriteToSavedPhotosAlbum(canvasView.toImage(),self, #selector(PhotoEditorViewController.image(_:withPotentialError:contextInfo:)), nil)
    }
    
    @IBAction func shareButtonTapped(_ sender: UIButton) {
        let activity = UIActivityViewController(activityItems: [canvasView.toImage()], applicationActivities: nil)
        present(activity, animated: true, completion: nil)
        
    }
    
    @IBAction func clearButtonTapped(_ sender: AnyObject) {
        //clear drawing
        canvasImageView.image = nil
        //clear stickers and textviews
        for subview in canvasImageView.subviews {
            subview.removeFromSuperview()
        }
    }
    
    @IBAction func continueButtonPressed(_ sender: Any) {
        let gifImageViews = self.canvasImageView.subviews.filter({ $0.isKind(of: GIFImageView.classForCoder()) }) as? [GIFImageView] ?? []
        var gifRemoteUrls: [URL] = []
        self.canvasImageView.subviews.forEach { view in
            if view.isKind(of: GIFImageView.classForCoder()) {
                if view.tag < viewModel.gifUrls.count {
                    gifRemoteUrls.append(viewModel.gifUrls[view.tag])
                }
                view.removeFromSuperview()
            }
        }
        
        guard var imageWithItems = ImageUtil().mergeImages(backgroundImage: viewModel.backgroundImage, overImage: viewModel.avatarImage) else { return }
        if let itemsImage = self.canvasImageView.image, let imageItems = ImageUtil().mergeImages(backgroundImage: imageWithItems, overImage: itemsImage){
            imageWithItems = imageItems
        }
        
        GifExporter().exportAnimatedGif(image: imageWithItems)
            .then { backgroundGifUrl -> Promise<URL> in
                return GifExporter().convertGifIntoVideo(remoteUrl: backgroundGifUrl)
            }.then { [weak self] backgroundUrl -> Promise<[URL]> in
                guard let `self` = self else { return Promise(error: Error.returnIsNil)}
                self.backgroundVideoUrl = backgroundUrl
                return self.viewModel.getVideoTempUrls(remoteUrls: gifRemoteUrls)
            }.done { [weak self] gifTempVideoUrls -> Void in
                guard let `self` = self else { return }
                let image = self.canvasView.toImage()
                self.photoEditorDelegate?.doneEditing(image: image, gifImageViews: gifImageViews, gifVideosUrl: gifTempVideoUrls, backgroundVideoUrl: self.backgroundVideoUrl)
                self.dismiss(animated: true, completion: nil)
            }.catch { error in
                print("error while creating temp videos: \(error)")
        }
    }
    
    
    //MARK: helper methods
    
    @objc func image(_ image: UIImage, withPotentialError error: NSErrorPointer, contextInfo: UnsafeRawPointer) {
        let alert = UIAlertController(title: "Image Saved", message: "Image successfully saved to Photos library", preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    @objc func hideControls() {
        for control in hiddenControls {
            switch control {
                
            case .clear:
                clearButton.isHidden = true
            case .crop:
                cropButton.isHidden = true
            case .draw:
                drawButton.isHidden = true
            case .save:
                saveButton.isHidden = true
            case .share:
                shareButton.isHidden = true
            case .sticker:
                stickerButton.isHidden = true
            case .text:
                stickerButton.isHidden = true
            }
        }
    }
    
}

extension PhotoEditorViewController {
    enum Error: Swift.Error {
        case returnIsNil
    }
}
