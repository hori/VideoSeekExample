//
//  PlayerView.swift
//  VideoSeekExample
//
//  Created by Yuki Horiguchi on 2017/08/23.
//  Copyright © 2017年 Yuki Horiguchi. All rights reserved.
//

import Foundation
import UIKit
import AVKit
import AVFoundation

class PlayerView: UIView {
  var player: AVPlayer? {
    get {
      return playerLayer.player
    }
    set {
      playerLayer.player = newValue
    }
  }
  
  var playerLayer: AVPlayerLayer {
    return layer as! AVPlayerLayer
  }
  
  override static var layerClass: AnyClass {
    return AVPlayerLayer.self
  }
}
