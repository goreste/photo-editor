//
//  ImageBlender.swift
//  editorTest
//
//  Created by Paolo Furlan on 06/04/18.
//  Copyright © 2018 Mohamed Hamed. All rights reserved.
//

import UIKit

public final class ImageUtil {
    func mergeImages(backgroundImage: UIImage?, overImage: UIImage?) -> UIImage? {
        guard let backgroundImage = backgroundImage else { return nil }
        guard let overImage = overImage else { return nil }
        
        let size = backgroundImage.size
        UIGraphicsBeginImageContext(size)
        
        let areaSize = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        backgroundImage.draw(in: areaSize)
        
        overImage.draw(in: areaSize, blendMode: CGBlendMode.normal, alpha: 1.0)
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return image
    }
}
