//
//  ThumbnailCell.swift
//  VideoSeekExample
//
//  Created by Yuki Horiguchi on 2017/08/23.
//  Copyright © 2017年 Yuki Horiguchi. All rights reserved.
//

import Foundation
import UIKit

class ThumbnailCell: UICollectionViewCell {

  @IBOutlet weak var imageView: UIImageView!
  
  override func prepareForReuse() {
    imageView.image = nil
  }
  
  func setImage(_ image: UIImage?) {
    guard  let image = image else {
      print("nil image")
      return
    }
    imageView.image = image
  }

}
