//
//  GifCollectionViewCell.swift
//  editorTest
//
//  Created by Paolo Furlan on 04/04/18.
//  Copyright © 2018 Mohamed Hamed. All rights reserved.
//

import UIKit
import Gifu

class GifCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var gifImageView: GIFImageView!
    @IBOutlet weak var loadingView: UIActivityIndicatorView!

    override func awakeFromNib() {
        super.awakeFromNib()
        
        gifImageView.contentMode = .scaleAspectFill
    }
    
    func setup(url: URL) {
        loadingView.startAnimating()
        gifImageView.animate(withGIFURL: url, loopCount: 0) { [weak self] in
            DispatchQueue.main.async {
                self?.loadingView.stopAnimating()
            }
        }
    }
}
