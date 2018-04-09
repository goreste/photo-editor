//
//  VideoExporter.swift
//  editorTest
//
//  Created by Paolo Furlan on 05/04/18.
//  Copyright © 2018 Mohamed Hamed. All rights reserved.
//

import Foundation
import AVFoundation
import Gifu

public final class VideoExporter {
    public init() {
    }
    
    public func createVideo(avatarImage: UIImage, onlyWithAvatar: Bool, gifImageViews: [GIFImageView], videoUrls: [URL], backgroundVideoUrl: URL, completion: @escaping (URL) -> Void) {
//        guard let backgroundImage = imageView.image else { return }
        
        print("Video URL: \(backgroundVideoUrl)")
        guard gifImageViews.count == videoUrls.count else { return }
        let mixComposition = AVMutableComposition()

        let backgroundUrlAsset = AVURLAsset(url: backgroundVideoUrl)
        guard let backgroundAsset = backgroundUrlAsset.tracks(withMediaType: AVMediaType.video).first else { return }
        let renderSize = CGSize(width: backgroundAsset.naturalSize.width, height: backgroundAsset.naturalSize.height)
        var maxDuration: CMTime = kCMTimeZero
        if backgroundUrlAsset.duration > maxDuration {
            maxDuration = backgroundUrlAsset.duration
        }

        let assets = videoUrls.map({ AVURLAsset(url: $0 )})
        if let maxDurationAssets = assets.sorted(by: { $0.duration > $1.duration }).map({ $0.duration }).first, maxDurationAssets > maxDuration  {
            maxDuration = maxDurationAssets
        }
        
        
        var layerInstructions: [AVMutableVideoCompositionLayerInstruction] = []
        if onlyWithAvatar == false {
            let backgroundScaleWidth = renderSize.width / avatarImage.size.width
            let backgroundScaleHeight = renderSize.height / avatarImage.size.height
            
            print("avatarImageSize: \(avatarImage.size)  ---  bgSize: \(renderSize) -- \(backgroundScaleWidth)  \(backgroundScaleHeight)")
            layerInstructions = assets.enumerated().flatMap { index, urlAsset -> AVMutableVideoCompositionLayerInstruction? in
                let gif = gifImageViews[index]
                
                let scaledByX = gif.frame.width / gif.intrinsicContentSize.width
                let scaledByY = gif.frame.height / gif.intrinsicContentSize.height
                
                print("\n\ngif: \(gif.frame) \(gif.intrinsicContentSize) \(scaledByX) \(scaledByY)")
                
                let gifTransform = gif.transform
                let scaleByTransform = CGAffineTransform(scaleX: scaledByX, y: scaledByY)
//                let translatedBy = CGAffineTransform(translationX: gif.frame.origin.x * backgroundScaleWidth, y: gif.frame.origin.y * backgroundScaleHeight)
                let translatedBy = CGAffineTransform(translationX: gif.frame.origin.x * backgroundScaleWidth, y: gif.frame.origin.y * backgroundScaleHeight)

                let finalTransform = gifTransform.concatenating(scaleByTransform).concatenating(translatedBy)
                print("gifTransform: \(gifTransform)")
                print("scaleByTransform: \(scaleByTransform)")
                print("scaleByTransform: \(translatedBy)")
                print("translatedBy: \(finalTransform)\n\n")
                
                guard let track = createTrack(asset: urlAsset, composition: mixComposition, maxDuration: Float(maxDuration.value), transform: finalTransform) else { return nil }
                return createLayerInstruction(track: track, transform: finalTransform)
            }
        }
        
        guard let backgroundTrack = createTrack(asset: backgroundUrlAsset, composition: mixComposition, maxDuration: Float(maxDuration.value), transform: CGAffineTransform(scaleX: 1, y: 1)) else { return }
        let backgroundInstruction = createLayerInstruction(track: backgroundTrack, transform: CGAffineTransform(scaleX: 1, y: 1))
        layerInstructions.append(backgroundInstruction)

//        let renderSize = CGSize(width: backgroundImage.size.width * UIScreen.main.scale, height: backgroundImage.size.height * UIScreen.main.scale)

        let mainInstruction = AVMutableVideoCompositionInstruction()
        mainInstruction.layerInstructions = layerInstructions
        mainInstruction.timeRange = CMTimeRange(start: kCMTimeZero, duration: maxDuration)
        
        let mainComposition = AVMutableVideoComposition()
        mainComposition.instructions = [mainInstruction]
        mainComposition.frameDuration = CMTime(value: 1, timescale: 30)
        mainComposition.renderSize = renderSize

        if onlyWithAvatar {
            addOverlayImage(image: avatarImage, composition: mainComposition, size: renderSize)
        }
        exportVideo(composition: mixComposition, onlyWithAvatar: onlyWithAvatar, videoComposition: mainComposition, completion: completion)
    }
    
    func addOverlayImage(image: UIImage, composition: AVMutableVideoComposition, size: CGSize) {
        let overlayLayer = CALayer()
        overlayLayer.contents = image.cgImage
        overlayLayer.frame = CGRect(x: size.width / 2 - image.size.width / 2, y: size.height / 2 - image.size.height / 2, width: image.size.width, height: image.size.height)
        overlayLayer.masksToBounds = true
        overlayLayer.zPosition = 0
        overlayLayer.contentsGravity = kCAGravityResizeAspectFill
        
        let parentLayer = CALayer()
        let videoLayer = CALayer()
        parentLayer.frame = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        videoLayer.frame = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        parentLayer.addSublayer(videoLayer)
        parentLayer.addSublayer(overlayLayer)
        
        composition.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: parentLayer)
    }
}

extension VideoExporter {
    func createTrack(asset: AVURLAsset, composition: AVMutableComposition, maxDuration: Float, transform: CGAffineTransform) -> AVMutableCompositionTrack? {
        guard let track = composition.addMutableTrack(withMediaType: AVMediaType.video, preferredTrackID: kCMPersistentTrackID_Invalid) else { return nil }
        track.preferredTransform = transform
        do {
            if let firstAsset = asset.tracks(withMediaType: AVMediaType.video).first {
                if maxDuration > Float(asset.duration.value) {
                    var atTime = kCMTimeZero
                    var remainingDuration = maxDuration
                    while remainingDuration > 0 { // create a loop video
                        var assetDuration = asset.duration
                        if remainingDuration < Float(assetDuration.value) {
                            assetDuration = CMTime(value: CMTimeValue(remainingDuration), timescale: 600)
                        }
                        try track.insertTimeRange(CMTimeRange(start: kCMTimeZero, duration: assetDuration), of: firstAsset, at: atTime)
                        atTime = assetDuration
                        remainingDuration -= Float(assetDuration.value)
                    }
                }else{
                    try track.insertTimeRange(CMTimeRange(start: kCMTimeZero, duration: asset.duration), of: firstAsset, at: kCMTimeZero)
                }
            }
        } catch {
            print("try catch error: \(error)")
            return nil
        }
        return track
    }
    
    func createLayerInstruction(track: AVMutableCompositionTrack, transform: CGAffineTransform) -> AVMutableVideoCompositionLayerInstruction {
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
        layerInstruction.setTransform(transform, at: kCMTimeZero)
        return layerInstruction
    }
    
    func exportVideo(composition: AVMutableComposition, onlyWithAvatar: Bool, videoComposition: AVMutableVideoComposition, completion: @escaping (URL) -> Void) {
        if let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first {
            /// create a path to the video file
            var nameVideo = "videoWithAvatar.mp4"
            if onlyWithAvatar ==  false {
                nameVideo = "finalVideo.mp4"
            }
            let completeMoviePath = URL(fileURLWithPath: documentsPath).appendingPathComponent(nameVideo)
            
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: completeMoviePath.path) {
                do {
                    try fileManager.removeItem(atPath: completeMoviePath.path)
                } catch {
                    print("try catch removing error")
                }
            }
            
            guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else { return }
            exporter.outputURL = completeMoviePath
            exporter.videoComposition = videoComposition
            exporter.outputFileType = AVFileType.mov
            
            exporter.exportAsynchronously(completionHandler: {
                switch exporter.status {
                case .failed:
                    if let error = exporter.error {
                        print("failure \(error)")
                    }
                    
                case .cancelled:
                    if let error = exporter.error {
                        print("failure \(error)")
                    }
                    
                case .completed:
                    print("finished \(completeMoviePath.lastPathComponent)")
                    DispatchQueue.main.async {
                        completion(completeMoviePath)
                    }
                default:
                    print("finished \(completeMoviePath)")
                }
            })
        }
    }
}
//
//class ImageConverter {
//
//    var image:UIImage!
//
//    convenience init(image: UIImage) {
//        self.init()
//        self.image = image
//    }
//
//    var outputURL: NSURL {
//        let documentDirectory = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0]
//        let savePath = (documentDirectory as NSString).stringByAppendingPathComponent("mergeVideo-pic.mov")
//        return getURL(savePath)
//    }
//
//    func getURL(path:String) -> NSURL {
//        let movieDestinationUrl = NSURL(fileURLWithPath: path)
//        _ = try? NSFileManager().removeItemAtURL(movieDestinationUrl)
//        let url = NSURL(fileURLWithPath: path)
//        return url
//    }
//
//    func build(completion:() -> Void) {
//        guard let videoWriter = try? AVAssetWriter(URL: outputURL, fileType: AVFileTypeQuickTimeMovie) else {
//            fatalError("AVAssetWriter error")
//        }
//
//        // This might not be a problem for you but width HAS to be divisible by 16 or the movie will come out distorted... don't ask me why. So this is a safeguard
//        let pixelsToRemove: Double = fmod(image.size.width, 16)
//        let pixelsToAdd: Double = 16 - pixelsToRemove
//        let size: CGSize = CGSizeMake(image.size.width + pixelsToAdd, image.size.height)
//
//        let outputSettings = [AVVideoCodecKey : AVVideoCodecH264, AVVideoWidthKey : NSNumber(float: Float(size.width)), AVVideoHeightKey : NSNumber(float: Float(size.height))]
//
//        guard videoWriter.canApplyOutputSettings(outputSettings, forMediaType: AVMediaTypeVideo) else {
//            fatalError("Negative : Can't apply the Output settings...")
//        }
//
//        let videoWriterInput = AVAssetWriterInput(mediaType: AVMediaTypeVideo, outputSettings: outputSettings)
//        let sourcePixelBufferAttributesDictionary = [kCVPixelBufferPixelFormatTypeKey as String : NSNumber(unsignedInt: kCVPixelFormatType_32ARGB), kCVPixelBufferWidthKey as String: NSNumber(float: Float(size.width)), kCVPixelBufferHeightKey as String: NSNumber(float: Float(size.height))]
//        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoWriterInput, sourcePixelBufferAttributes: sourcePixelBufferAttributesDictionary)
//
//        if videoWriter.canAddInput(videoWriterInput) {
//            videoWriter.addInput(videoWriterInput)
//        }
//
//        if videoWriter.startWriting() {
//            videoWriter.startSessionAtSourceTime(kCMTimeZero)
//            assert(pixelBufferAdaptor.pixelBufferPool != nil)
//        }
//
//        // For simplicity, I'm going to remove the media queue you created and instead explicitly wait until I can append since i am only writing one pixel buffer at two different times
//
//        var pixelBufferCreated = true
//        var pixelBuffer: CVPixelBuffer? = nil
//        let status: CVReturn = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pixelBufferAdaptor.pixelBufferPool!, &pixelBuffer)
//
//        if let pixelBuffer = pixelBuffer where status == 0 {
//            let managedPixelBuffer = pixelBuffer
//            CVPixelBufferLockBaseAddress(managedPixelBuffer, 0)
//
//            let data = CVPixelBufferGetBaseAddress(managedPixelBuffer)
//            let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
//            let context = CGBitmapContextCreate(data, Int(size.width), Int(size.height), 8, CVPixelBufferGetBytesPerRow(managedPixelBuffer), rgbColorSpace, CGImageAlphaInfo.PremultipliedFirst.rawValue)
//
//            CGContextClearRect(context, CGRectMake(0, 0, CGFloat(size.width), CGFloat(size.height)))
//
//            CGContextDrawImage(context, CGRectMake(0, 0, size.width, size.height), self.image.CGImage)
//
//            CVPixelBufferUnlockBaseAddress(managedPixelBuffer, 0)
//        } else {
//            print("Failed to allocate pixel buffer")
//            pixelBufferCreated = false
//        }
//
//        if (pixelBufferCreated) {
//            // Here is where the magic happens, we have our pixelBuffer it's time to start writing
//
//            // FIRST - add at time zero
//            var appendSucceeded = pixelBufferAdaptor.appendPixelBuffer(pixelBuffer, withPresentationTime: kCMTimeZero];
//                if (!appendSucceeded) {
//                // something went wrong, up to you to handle. Should probably return so the rest of the code is not executed though
//                }
//                // SECOND - wait until the writer is ready for more data with an empty while
//                while !writerInput.readyForMoreMediaData {}
//
//            // THIRD - make a CMTime with the desired length of your picture-video. I am going to arbitrarily make it 5 seconds here
//            let frameTime: CMTime = CMTimeMake(5, 1) // 5 seconds
//
//            // FOURTH - add the same exact pixel to the end of the video you are creating
//            appendSucceeded = pixelBufferAdaptor.appendPixelBuffer(pixelBuffer, withPresentationTime: frameTime];
//                if (!appendSucceeded) {
//                // something went wrong, up to you to handle. Should probably return so the rest of the code is not executed though
//                }
//
//                videoWriterInput.markAsFinished() {
//                videoWriter.endSessionAtSourceTime(frameTime)
//                }
//                videoWriter.finishWritingWithCompletionHandler { () -> Void in
//                if videoWriter.status != .Completed {
//                // Error writing the video... handle appropriately
//                } else {
//                print("FINISHED!!!!!")
//                completion()
//                }
//            }
//        }
//    }
//}
