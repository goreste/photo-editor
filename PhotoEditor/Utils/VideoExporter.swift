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

class VideoExporter {
    func createVideo(imageView: UIImageView, gifImageViews: [GIFImageView], videoUrls: [URL]) {
        guard let backgroundImage = imageView.image else { return }
        guard gifImageViews.count == videoUrls.count else { return }
        let mixComposition = AVMutableComposition()

        
        let assets = videoUrls.map({ AVURLAsset(url: $0 )})
        guard let maxDuration = assets.sorted(by: { $0.duration > $1.duration }).map({ $0.duration }).first else { return }
        
        let layerInstructions = assets.enumerated().flatMap { index, urlAsset -> AVMutableVideoCompositionLayerInstruction? in
            guard let track = createTrack(asset: urlAsset, composition: mixComposition, maxDuration: Float(maxDuration.value)) else { return nil }
            let gif = gifImageViews[index]
            let gifTransform = gif.transform.translatedBy(x: gif.frame.origin.x * UIScreen.main.scale, y: gif.frame.origin.y * UIScreen.main.scale)
            return createLayerInstruction(track: track, transform: gifTransform)
        }
        
        let mainInstruction = AVMutableVideoCompositionInstruction()
        mainInstruction.layerInstructions = layerInstructions
        mainInstruction.timeRange = CMTimeRange(start: kCMTimeZero, duration: maxDuration)
        
        let mainComposition = AVMutableVideoComposition()
        mainComposition.instructions = [mainInstruction]
        mainComposition.frameDuration = CMTime(value: 1, timescale: 30)
        mainComposition.renderSize = CGSize(width: backgroundImage.size.width * UIScreen.main.scale, height: backgroundImage.size.height * UIScreen.main.scale)

//        addOverlayImage(image: backgroundImage, composition: mainComposition)
        exportVideo(composition: mixComposition, videoComposition: mainComposition)
    }
    
    func addOverlayImage(image: UIImage, composition: AVMutableVideoComposition) {
        let overlayLayer = CALayer()
        overlayLayer.contents = image.cgImage
        overlayLayer.frame = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
        overlayLayer.masksToBounds = true
        
        let parentLayer = CALayer()
        let videoLayer = CALayer()
        parentLayer.frame = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
        videoLayer.frame = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
        parentLayer.addSublayer(videoLayer)
        parentLayer.addSublayer(overlayLayer)
        
        composition.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: parentLayer)
    }
}

extension VideoExporter {
    func createTrack(asset: AVURLAsset, composition: AVMutableComposition, maxDuration: Float) -> AVMutableCompositionTrack? {
        let track = composition.addMutableTrack(withMediaType: AVMediaTypeVideo, preferredTrackID: kCMPersistentTrackID_Invalid)
        do {
            if let firstAsset = asset.tracks(withMediaType: AVMediaTypeVideo).first {
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
    
    func exportVideo(composition: AVMutableComposition, videoComposition: AVMutableVideoComposition) {
        if let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first {
            /// create a path to the video file
            let completeMoviePath = URL(fileURLWithPath: documentsPath).appendingPathComponent("videoMerged.m4v")
            
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
            exporter.outputFileType = AVFileTypeQuickTimeMovie
            
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
                    
                default:
                    print("finished \(completeMoviePath)")
                }
            })
        }
    }
}
