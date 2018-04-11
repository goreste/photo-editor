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

extension FloatingPoint {
    var degreesToRadians: Self { return self * .pi / 180 }
    var radiansToDegrees: Self { return self * 180 / .pi }
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
//        let renderSize = CGSize(width: editorViewSize.width, height: editorViewSize.height)
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
            print(renderSize, editorViewSize, scaleWidth, scaleHeight)
            
            layerInstructions = assets.enumerated().flatMap { index, urlAsset -> AVMutableVideoCompositionLayerInstruction? in
                let gif = self.gifImageViews[index]
                
                let gifTransform = gif.transform
                var finalTransform = CGAffineTransform.identity
                
                let gifRotation = CGFloat(rotation(t: gifTransform))
                print(gifRotation.degreesToRadians, gifRotation.radiansToDegrees, gifRotation)

                //                let differenceWidth = (gif.transform.tx + (editorViewSize.width / 2 - gif.frame.width / 2)) * scaleWidth
                //                let differenceHeight = (gif.transform.ty + (editorViewSize.height / 2 - gif.frame.height / 2)) * scaleHeight
                //                let rotatedOriginXDiffCounterClockwise = differenceWidth * cos(gifRotation) - differenceHeight * sin(gifRotation)
                //                let rotatedOriginYDiffCounterClockwise = differenceWidth * sin(gifRotation) + differenceHeight * cos(gifRotation)
                //
                //                let rotatedOriginXDiffClockwise = differenceWidth * cos(gifRotation) + differenceHeight * sin(gifRotation)
                //                let rotatedOriginYDiffClockwise =  differenceHeight * cos(gifRotation) - differenceWidth * sin(gifRotation)
                
                //                let gifTranslationX = rotatedOriginXDiffClockwise + gifWidthScaled
                //                let gifTranslationY = rotatedOriginYDiffClockwise + gifHeightScaled

                let centerX = gif.transform.tx + (editorViewSize.width / 2)
                let centerY = gif.transform.ty + (editorViewSize.height / 2)

                
                let gifWidth = gif.intrinsicContentSize.width * xScale(t: gifTransform)
                let gifHeight = gif.intrinsicContentSize.height * yScale(t: gifTransform)

                
                let adjacent = gifWidth / 2
                let opposite = gifHeight / 2
                
                let hipotenuse = sqrt(pow(adjacent, 2) + pow(opposite, 2))
                let thetaRad = acos((pow(hipotenuse, 2) + pow(adjacent, 2) - pow(opposite, 2)) / (2 * hipotenuse * adjacent))
                
                let angleRad: CGFloat = gifRotation
                
                let widthOffset = cos(angleRad - thetaRad) * hipotenuse
                let heightOffset = sin(angleRad - thetaRad) * hipotenuse

                let offsetPointOrigin = CGPoint(x: centerX + heightOffset, y: centerY - widthOffset)
//                let offsetPointOriginOpposite = CGPoint(x: centerX - heightOffset, y: centerY + widthOffset)

                
                let gifSizeScaled = CGSize(width: xScale(t: gifTransform) * scaleWidth, height: yScale(t: gifTransform) * scaleHeight)

                finalTransform = finalTransform.concatenating(CGAffineTransform(scaleX: gifSizeScaled.width, y: gifSizeScaled.height))
                finalTransform = finalTransform.concatenating(CGAffineTransform(rotationAngle: gifRotation))
                finalTransform = finalTransform.concatenating(CGAffineTransform(translationX: offsetPointOrigin.x * scaleWidth, y: offsetPointOrigin.y * scaleHeight))


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
//        track.preferredTransform = transform
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
                    print("try catch removing error")
                    return Promise(error: Error.fileManagerRemovalError)
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

extension VideoExporter {
    func xScale(t: CGAffineTransform) -> CGFloat {
        return sqrt(t.a * t.a + t.c * t.c)
    }
    
    func yScale(t: CGAffineTransform) -> CGFloat {
        return sqrt(t.b * t.b + t.d * t.d)
    }
    
    func rotation(t: CGAffineTransform) -> CGFloat {
        return CGFloat(atan2f(Float(t.b), Float(t.a)))
    }
    
    func tx(t: CGAffineTransform) -> CGFloat {
        return t.tx
    }
    
    func ty(t: CGAffineTransform) -> CGFloat {
        return t.ty
    }
}
