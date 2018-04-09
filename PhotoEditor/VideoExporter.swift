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
import PromiseKit

extension VideoExporter {
    enum Error: Swift.Error {
        case backgroundVideoUrlNil
        case gifImagesCount
        case exporterIsNil
        case fileManagerRemovalError
        case cancelled
        case defaultCase
    }
}

public final class VideoExporter {
    static let shared = VideoExporter()
    
    var gifImageViews: [GIFImageView] = []
    var videoUrls: [URL] = []

    public init() {
    }
    
    public func createVideo(avatarImage: UIImage, editorViewSize: CGSize, onlyWithAvatar: Bool, gifImageViews: [GIFImageView] = [], videoUrls: [URL] = [], backgroundVideoUrl: URL) -> Promise<URL> {
        if videoUrls.isEmpty == false {
            self.videoUrls = videoUrls
        }
        if gifImageViews.isEmpty == false {
            self.gifImageViews = gifImageViews
        }

        guard self.gifImageViews.count == self.videoUrls.count else { return Promise(error: Error.gifImagesCount) }
        let mixComposition = AVMutableComposition()

        let backgroundUrlAsset = AVURLAsset(url: backgroundVideoUrl)
        guard let backgroundAsset = backgroundUrlAsset.tracks(withMediaType: AVMediaType.video).first else { return Promise(error: Error.backgroundVideoUrlNil) }
        let renderSize = CGSize(width: backgroundAsset.naturalSize.width, height: backgroundAsset.naturalSize.height)
        var maxDuration: CMTime = kCMTimeZero
        if backgroundUrlAsset.duration > maxDuration {
            maxDuration = backgroundUrlAsset.duration
        }

        let assets = self.videoUrls.map({ AVURLAsset(url: $0 )})
        if let maxDurationAssets = assets.sorted(by: { $0.duration > $1.duration }).map({ $0.duration }).first, maxDurationAssets > maxDuration  {
            maxDuration = maxDurationAssets
        }
        
        var layerInstructions: [AVMutableVideoCompositionLayerInstruction] = []
        if onlyWithAvatar == false {

            let scaleWidth = renderSize.width / editorViewSize.width
            let scaleHeight = renderSize.height / editorViewSize.height
            
            layerInstructions = assets.enumerated().flatMap { index, urlAsset -> AVMutableVideoCompositionLayerInstruction? in
                let gif = self.gifImageViews[index]
                
                let gifTransform = gif.transform
                let anchorPoint = gif.layer.anchorPoint
                let scaleByTransform = CGAffineTransform(scaleX: scaleWidth, y: scaleHeight)
                var translatedBy = CGAffineTransform(translationX: gif.frame.origin.x * scaleWidth, y: gif.frame.origin.y * scaleHeight)
                
                if gifTransform.b != 0.0 || gifTransform.c != 0.0 {
                    let b = translatedBy.b
                    let c = translatedBy.c
                    translatedBy = translatedBy.concatenating(CGAffineTransform(translationX: -(gif.frame.width / 2 * scaleWidth), y: -(gif.frame.height / 2 * scaleHeight)))
                    translatedBy.b = 0.0
                    translatedBy.c = 0.0
                    translatedBy = translatedBy.concatenating(CGAffineTransform(translationX: (gif.frame.width / 2 * scaleWidth), y: (gif.frame.height * scaleHeight)))
                    translatedBy.b = b
                    translatedBy.c = c
                }

                let finalTransform = gifTransform.concatenating(scaleByTransform).concatenating(translatedBy)
                
                guard let track = createTrack(asset: urlAsset, composition: mixComposition, maxDuration: Float(maxDuration.value), transform: finalTransform) else { return nil }
                return createLayerInstruction(track: track, transform: finalTransform)
            }
        }
        
        guard let backgroundTrack = createTrack(asset: backgroundUrlAsset, composition: mixComposition, maxDuration: Float(maxDuration.value), transform: CGAffineTransform(scaleX: 1, y: 1)) else { return Promise(error: Error.backgroundVideoUrlNil) }
        let backgroundInstruction = createLayerInstruction(track: backgroundTrack, transform: CGAffineTransform(scaleX: 1, y: 1))
        layerInstructions.append(backgroundInstruction)

        let mainInstruction = AVMutableVideoCompositionInstruction()
        mainInstruction.layerInstructions = layerInstructions
        mainInstruction.timeRange = CMTimeRange(start: kCMTimeZero, duration: maxDuration)
        
        let mainComposition = AVMutableVideoComposition()
        mainComposition.instructions = [mainInstruction]
        mainComposition.frameDuration = CMTime(value: 1, timescale: 30)
        mainComposition.renderSize = renderSize

        if onlyWithAvatar {
            addOverlayImage(avatarImage: avatarImage, composition: mainComposition, size: renderSize)
        }
        return exportVideo(composition: mixComposition, onlyWithAvatar: onlyWithAvatar, videoComposition: mainComposition)
    }
    
    func addOverlayImage(avatarImage: UIImage, composition: AVMutableVideoComposition, size: CGSize) {
        guard let avatarSize = avatarImage.suitableSize(widthLimit: size.width) else { return }
        let avatarLayer = CALayer()
        avatarLayer.contents = avatarImage.cgImage
        avatarLayer.frame = CGRect(x: size.width / 2 - avatarSize.width / 2, y: size.height / 2 - avatarSize.height / 2, width: avatarSize.width, height: avatarSize.height)
        avatarLayer.masksToBounds = true
        avatarLayer.zPosition = 0
        avatarLayer.contentsGravity = kCAGravityResizeAspectFill
        
        let parentLayer = CALayer()
        let videoLayer = CALayer()
        parentLayer.frame = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        videoLayer.frame = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        parentLayer.addSublayer(videoLayer)
        parentLayer.addSublayer(avatarLayer)
        
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
    
    func exportVideo(composition: AVMutableComposition, onlyWithAvatar: Bool, videoComposition: AVMutableVideoComposition) -> Promise<URL> {
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
                    return Promise(error: Error.fileManagerRemovalError)
                    print("try catch removing error")
                }
            }
            
            guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else { return Promise(error: Error.exporterIsNil) }
            exporter.outputURL = completeMoviePath
            exporter.videoComposition = videoComposition
            exporter.outputFileType = AVFileType.mov
            
            return Promise(resolver: { seal in
                exporter.exportAsynchronously(completionHandler: {
                    switch exporter.status {
                    case .failed:
                        if let error = exporter.error {
                            print("failure \(error)")
                            seal.reject(Error.exporterIsNil)
                        }
                        
                    case .cancelled:
                        if let error = exporter.error {
                            print("failure \(error)")
                            seal.reject(Error.cancelled)
                        }
                        
                    case .completed:
                        print("finished \(completeMoviePath.lastPathComponent)")
                        DispatchQueue.main.async {
                            seal.fulfill(completeMoviePath)
                        }
                    default:
                        seal.reject(Error.defaultCase)
                        print("finished \(completeMoviePath)")
                    }
                })
            })
        }else{
            return Promise(error: Error.fileManagerRemovalError)
        }
    }
}
