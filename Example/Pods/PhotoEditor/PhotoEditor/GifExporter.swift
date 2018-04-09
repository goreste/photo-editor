//
//  GifExporter.swift
//  editorTest
//
//  Created by Paolo Furlan on 06/04/18.
//  Copyright © 2018 Mohamed Hamed. All rights reserved.
//

import UIKit
import ImageIO
import MobileCoreServices
import PromiseKit

public final class GifExporter {
    public init() {
        
    }
    
    public func exportAnimatedGif(image: UIImage?) -> Promise<URL> {
        return Promise(resolver: { seal in
            guard let image = image else {
                seal.reject(Error.urlIsNil)
                return
            }
            guard let imageData = UIImageJPEGRepresentation(image, 1.0) else {
                seal.reject(Error.urlIsNil)
                return
            }
            guard let compressedImage = UIImage(data: imageData) else {
                seal.reject(Error.urlIsNil)
                return
            }
            
            let nameGif = String(Date().timeIntervalSince1970).replacingOccurrences(of: ".", with: "")
            
            let path = URL(fileURLWithPath:NSTemporaryDirectory()).appendingPathComponent("\(nameGif).gif")
            
            let destination = CGImageDestinationCreateWithURL(path as CFURL, kUTTypeGIF, 2, nil)
            
            let frameProperties = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 0]]
            let gifProperties = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]]
            
            CGImageDestinationAddImage(destination!, compressedImage.cgImage!, frameProperties as CFDictionary)
            CGImageDestinationAddImage(destination!, compressedImage.cgImage!, frameProperties as CFDictionary)
            CGImageDestinationSetProperties(destination!, gifProperties as CFDictionary)
            CGImageDestinationFinalize(destination!)
            
            seal.fulfill(path)
        })
    }
    
    public func convertGifIntoVideo(remoteUrl: URL) -> Promise<URL> {
        return Promise(resolver: { seal in
            let nameGif = remoteUrl.lastPathComponent.replacingOccurrences(of: ".gif", with: "").replacingOccurrences(of: "gif", with: "")
            if let data = try? Data(contentsOf: remoteUrl) {
                let tempUrl = URL(fileURLWithPath:NSTemporaryDirectory()).appendingPathComponent("\(nameGif).mp4")
                GIF2MP4(data: data)?.convertAndExport(to: tempUrl, completion: {
                    seal.fulfill(tempUrl)
                })
            }else{
                seal.reject(Error.urlIsNil)
            }
        })
    }
}

extension GifExporter {
    enum Error: Swift.Error {
        case urlIsNil
    }
}
