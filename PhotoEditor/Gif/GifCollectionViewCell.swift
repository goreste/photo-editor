//
//  GifCollectionViewCell.swift
//  editorTest
//
//  Created by Paolo Furlan on 04/04/18.
//  Copyright © 2018 Mohamed Hamed. All rights reserved.
//

import UIKit
import SwiftGifOrigin

class GifCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var gifImageView: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        gifImageView.contentMode = .scaleAspectFill
    }
}
