//
//  ViewController.swift
//  PhotoEditor
//
//  Created by Paolo Furlan on 06/04/18.
//  Copyright © 2018 Paolo Furlan. All rights reserved.
//

import UIKit
import Foundation
import PhotoEditor
import Gifu
import PromiseKit

class ViewController: UIViewController {
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var saveVideoButton: UIButton!
    
    var videoPath = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        imageView.clipsToBounds = true
        //        imageView.contentMode = .scaleAspectFit
        saveVideoButton.isHidden = true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        //        if imageView.image == nil {
        //            presentPhotoEditor(image: UIImage(named: "img"))
        //        }
    }
    
    func presentPhotoEditor(image: UIImage?) {
        guard let image = image else { return }
        var stickers: [UIImage] = []
        for i in 0...10 {
            stickers.append(UIImage(named: i.description )!)
        }
        let gifUrls = FileUtils.scanGifFiles()
        
        let photoEditorViewModel = PhotoEditorViewModel(backgroundImage: image, avatarImage: UIImage(named: "avatar")!, stickers: stickers, gifUrls: gifUrls)
        let photoEditor = PhotoEditorViewController(nibName:"PhotoEditorViewController",bundle: Bundle(for: PhotoEditorViewController.self))
        photoEditor.photoEditorDelegate = self
        photoEditor.viewModel = photoEditorViewModel
        //Colors for drawing and Text, If not set default values will be used
        //        photoEditor.colors = [.red,.blue,.green]
        
        
        //        photoEditor.gifs = [
        //            URL(string: "https://media.giphy.com/media/7rOVZD6C733m8/200w.gif")!,
        //            URL(string: "https://media2.giphy.com/media/CkM2nigmbmgak/200w.gif")!,
        //            URL(string: "https://media3.giphy.com/media/1wlNzikoa94Yg/200w.gif")!,
        //            URL(string: "https://media1.giphy.com/media/FJKwXQH00CFMI/200w.gif")!,
        //            URL(string: "https://media2.giphy.com/media/q1kd8wGUtm7Go/200w.gif")!,
        //            URL(string: "https://media0.giphy.com/media/yTebcCKcBZxNS/200w.gif")!,
        //            URL(string: "https://media2.giphy.com/media/xewKHBooOiLpC/200w.gif")!,
        //
        //            URL(string: "https://media2.giphy.com/media/C3qpoW9ILbpu/200w.gif")!,
        //            URL(string: "https://media2.giphy.com/media/ohkdbwhfqQCFq/200w.gif")!,
        //            URL(string: "https://media3.giphy.com/media/xPQNQyIrqDX0c/200w.gif")!,
        //
        //            URL(string: "https://media3.giphy.com/media/26u4bkvatkyy7KEJW/200w.gif")!,
        //            URL(string: "https://media1.giphy.com/media/kvdqOYjFcDQJy/200w.gif")!,
        //            URL(string: "https://media2.giphy.com/media/L0aWDywDu1ziw/200w.gif")!
        //        ]
        
        //To hide controls - array of enum control
        //        photoEditor.hiddenControls = [.crop, .draw, .share]
        present(photoEditor, animated: true, completion: nil)
    }
    
    @IBAction func pickImageButtonTapped(_ sender: Any) {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .photoLibrary
        present(picker, animated: true, completion: nil)
    }
    
    @IBAction func saveVideoToCameraRoll(_ sender: Any) {
        if videoPath != "" {
            //            let isVideoCompatible = UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(videoPath)
            //            print("bool: \(isVideoCompatible)")
            //            let library = ALAssetsLibrary()
            //            library.writeVideoAtPath(toSavedPhotosAlbum: URL(string: videoPath)!) { (url, error) in
            //
            //            }
            UISaveVideoAtPathToSavedPhotosAlbum(videoPath, nil, nil, nil)
        }
    }
}

extension ViewController: PhotoEditorDelegate {
    func doneEditing(image: UIImage, gifImageViews: [GIFImageView], gifVideosUrl: [URL], backgroundVideoUrl: URL) {
        saveVideoButton.isHidden = true
        
        imageView.subviews.forEach { view in
            view.removeFromSuperview()
        }
        
        imageView.image = image
        gifImageViews.forEach { [weak self] gifImageView in
            //            gifImageView.frame = CGRect(x: gifImageView.frame.origin.x, y: gifImageView.frame.origin.y, width: gifImageView.intrinsicContentSize.width, height: gifImageView.intrinsicContentSize.height)
            self?.imageView.addSubview(gifImageView)
        }
        
        VideoExporter().createVideo(imageView: imageView, gifImageViews: gifImageViews, videoUrls: gifVideosUrl, backgroundVideoUrl: backgroundVideoUrl) { [weak self] videoPath in
            DispatchQueue.main.async {
                self?.videoPath = videoPath
                if videoPath == "" {
                    self?.saveVideoButton.isHidden = true
                }else{
                    self?.saveVideoButton.isHidden = false
                }
            }
        }
    }
    
    func canceledEditing() {
        print("Canceled")
    }
}

extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [String : Any]) {
        
        guard let image = info[UIImagePickerControllerOriginalImage] as? UIImage else {
            picker.dismiss(animated: true, completion: nil)
            return
        }
        picker.dismiss(animated: true, completion: nil)
        
        presentPhotoEditor(image: image)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
}


//MARK: - Utils
extension FileManager {
    func scanDirectory(directory: SearchPathDirectory, for fileExtension: String) -> [URL] {
        guard let dirPath = try? url(for: directory, in: .userDomainMask, appropriateFor: nil, create: false) else { return [] }
        guard let fileEnumerator = enumerator(at: dirPath, includingPropertiesForKeys: nil, options: DirectoryEnumerationOptions()) else { return [] }
        var files: [URL] = []
        while let url = fileEnumerator.nextObject() {
            guard let url = url as? URL else { continue }
            files.append(url)
        }
        return files.filter { $0.pathExtension == fileExtension }
    }
    
    func documentsUrl() -> URL? {
        return try? url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
    }
    
    func cachesUrl() -> URL? {
        return try? url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
    }
    
    func scanDocumentsFor(fileExtension: String) -> [URL] {
        return scanDirectory(directory: .documentDirectory, for: fileExtension)
    }
    
    func scanBundleFor(fileExtension: String) -> [URL] {
        guard let files = try? FileManager.default.contentsOfDirectory(at: Bundle.main.bundleURL, includingPropertiesForKeys: nil) else { return [] }
        return files.filter { $0.pathExtension == fileExtension }
    }
    
    func saveImageToDocuments(image: UIImage, fileExtension: String = "png") {
        guard let imageData = UIImagePNGRepresentation(image) else { return }
        guard let documentsUrl = documentsUrl() else { return }
        let path = documentsUrl.appendingPathComponent("\(Date().timeIntervalSince1970).\(fileExtension)").path
        print("image created: \(path)")
        FileManager.default.createFile(atPath: path, contents: imageData, attributes: nil)
    }
}


struct FileUtils {
    static func scanGifFiles() -> [URL] {
        return scanFilesFor(fileExtension: "gif")
    }
    
    static func scanFilesFor(fileExtension: String) -> [URL] {
        let filesInBundle = scanBundleFor(fileExtension: fileExtension)
        let filesInDocuments = scanDocumentsFor(fileExtension: fileExtension)
        let filesInCaches = scanCachesFor(fileExtension: fileExtension)
        return filesInDocuments + filesInCaches + filesInBundle
    }
    
    static func scanBundleFor(fileExtension: String) -> [URL] {
        guard let files = try? FileManager.default.contentsOfDirectory(at: Bundle.main.bundleURL, includingPropertiesForKeys: nil) else { return [] }
        return files.filter { $0.pathExtension == fileExtension }
    }
    
    static func scanDocumentsFor(fileExtension: String) -> [URL] {
        return FileManager.default.scanDirectory(directory: .documentDirectory, for: fileExtension)
    }
    
    static func scanCachesFor(fileExtension: String) -> [URL] {
        return FileManager.default.scanDirectory(directory: .cachesDirectory, for: fileExtension)
    }
}