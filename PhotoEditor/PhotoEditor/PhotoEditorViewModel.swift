//
//  PhotoEditorViewModel.swift
//  editorTest
//
//  Created by Paolo Furlan on 05/04/18.
//  Copyright © 2018 Mohamed Hamed. All rights reserved.
//

import UIKit
import PromiseKit

class PhotoEditorViewModel {
    var image: UIImage
    var stickers : [UIImage] = []
    var gifUrls : [URL] = []

    init(image: UIImage, stickers: [UIImage], gifUrls: [URL]) {
        self.image = image
        self.stickers = stickers
        self.gifUrls = gifUrls
    }
}

extension PhotoEditorViewModel {
    func getVideoTempUrls(remoteUrls: [URL]) -> Promise<[URL]> {
        return when(resolved: urlPromises(remoteUrls: remoteUrls)).map { urlResults in
            urlResults.flatMap({ result in
                switch result {
                case let .fulfilled(url):
                    print("success: \(url)")
                    return url
                case let .rejected(error):
                    print("promise error: \(error)")
                    return nil
                }
            })
        }
    }
    
    func urlPromises(remoteUrls: [URL]) -> [Promise<URL>] {
        return remoteUrls.map { remoteUrl -> Promise<URL> in
            return Promise(resolver: { seal in
                let nameGif = remoteUrl.lastPathComponent.replacingOccurrences(of: ".gif", with: "").replacingOccurrences(of: "gif", with: "")
                if let data = try? Data(contentsOf: remoteUrl) {
                    let tempUrl = URL(fileURLWithPath:NSTemporaryDirectory()).appendingPathComponent("\(nameGif).mp4")
                    GIF2MP4(data: data)?.convertAndExport(to: tempUrl, completion: {
                        NSLog("finished converting")
                        seal.fulfill(tempUrl)
                    })
                }else{
                    seal.reject(Error.urlIsNil)
                }
            })
        }
    }
}

extension PhotoEditorViewModel {
    enum Error: Swift.Error {
        case urlIsNil
    }
}
