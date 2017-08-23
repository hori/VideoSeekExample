//
//  ViewController.swift
//  VideoSeekExample
//
//  Created by Yuki Horiguchi on 2017/08/23.
//  Copyright © 2017年 Yuki Horiguchi. All rights reserved.
//

import UIKit
import AVFoundation
import AVKit
import AssetsLibrary
import Photos

class ViewController: UIViewController {

  @IBOutlet weak var playerView: PlayerView!
  @IBOutlet weak var reelCollectionView: UICollectionView!
  
  fileprivate var player: AVPlayer?
  fileprivate var generator: AVAssetImageGenerator?
  fileprivate var thumbnails: [UIImage?] = []
  fileprivate var times:[NSValue] = [NSValue(time: kCMTimeZero)]
  
  fileprivate var playerSeekTimeObserver: Any?
  fileprivate var playerLoopTimeObserver: Any?
  
  fileprivate var prevScrolledX: CGFloat = 0
  
  let pxPerSec: CGFloat = 4 / 1
  let secPerPx: CGFloat = 1 / 4
  let thumbCellMaxWidth: CGFloat = 100
  
  var asset: AVAsset? {
    willSet {
      player?.pause()
      player = nil
      generator?.cancelAllCGImageGeneration()
      generator = nil
      thumbnails = []
      times = [NSValue(time: kCMTimeZero)]
    }
    didSet{
      guard let asset = asset else { return }
      player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
      generator = AVAssetImageGenerator(asset: asset)

      prepareReelCollectionView()
      preparePlayer()
    }
  }
  

  override func viewDidLoad() {
    super.viewDidLoad()
    
    PHPhotoLibrary.requestAuthorization { PHAuthorizationStatus in
    }
    
    reelCollectionView.register(ThumbnailCell.self, forCellWithReuseIdentifier: "ThumbnailCell")
    reelCollectionView.register(UINib(nibName: "ThumbnailCell", bundle: Bundle.main), forCellWithReuseIdentifier: "ThumbnailCell")
    reelCollectionView.dataSource = self
    reelCollectionView.delegate = self
    
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    
    let manager = FileManager.default
    if let url = URL(string: "file:///var/mobile/Media/DCIM/114APPLE/IMG_4324.MOV") ,false {
      //URL(string: "file:///var/mobile/Media/DCIM/113APPLE/IMG_3930.MOV")
      asset = AVAsset(url: url)
    } else if let url = URL(string: "file:///var/mobile/Media/DCIM/100APPLE/IMG_0085.MOV") {
      //URL(string: "file:///var/mobile/Media/DCIM/100APPLE/IMG_0042.MOV")
      asset = AVAsset(url: url)
    }
  }
  
  fileprivate func preparePlayer() {
    guard let player = player else { return }
    
    playerView.playerLayer.player = player
    player.play()
    
    let time : CMTime = CMTimeMakeWithSeconds(0.03, Int32(NSEC_PER_SEC))
    playerSeekTimeObserver = player.addPeriodicTimeObserver(forInterval: time, queue: nil) { [weak self] (time) -> Void in
      guard let weakself = self else { return }
      guard let player = weakself.player else { return }
      guard player.rate != 0 else { return }
      weakself.syncScrollView(currenTime: player.currentTime())
    }
    
    playerLoopTimeObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: nil, using: { (_) in
      DispatchQueue.main.async { [weak self] in
        guard let weakself = self else { return }
        weakself.player?.seek(to: kCMTimeZero)
        weakself.player?.play()
      }
    })
  }
  
  fileprivate func prepareReelCollectionView() {
    guard let asset = asset else { return }
    guard let generator = generator else { return }
    
    // prepare times
    times = [NSValue(time: kCMTimeZero)]
    let unitTime = asset.duration.seconds / Double(numOfCells())
    for i in 1..<numOfCells() {
      times.append(NSValue(time: CMTimeMakeWithSeconds(unitTime * Double(i), Int32(NSEC_PER_SEC))))
    }

    // prepare thumbnails
    thumbnails = Array.init(repeating: nil, count: numOfCells())
    
    generator.generateCGImagesAsynchronously(forTimes: times) { [weak self] (requestedTime, thumbnail, actualTime, result, error) in
      guard let weakself = self else { return }
      guard result == .succeeded else {
        // TODO: failover
        print("failed")
        print(error?.localizedDescription)
        return
      }
      guard let index = weakself.times.index(of: NSValue(time: requestedTime)) else { return }
      guard weakself.thumbnails.indices.contains(index) else { return }
      guard let cgThumbnail = thumbnail else { return }
      weakself.thumbnails[index] = UIImage.init(cgImage: cgThumbnail)
      if index == 5 || index + 1 == weakself.numOfCells() {
        DispatchQueue.main.async { [weak self] in
          self?.reelCollectionView.reloadData()
        }
      }
    }
  }

  fileprivate func reelWidth() -> CGFloat {
    guard let asset = asset else { return 0 }
    return CGFloat(asset.duration.seconds) * pxPerSec
  }
  
  fileprivate func numOfCells() -> Int {
    guard let _ = asset else { return 0 }
    return Int((reelWidth() / thumbCellMaxWidth).rounded(.up))
  }

  fileprivate func cmTime(with x: CGFloat) -> CMTime {
    return CMTimeMakeWithSeconds(Double(x * secPerPx), Int32(NSEC_PER_SEC))
  }
  
  fileprivate func x(with time: CMTime) -> CGFloat {
    return CGFloat(time.seconds) * pxPerSec
  
  }

  fileprivate func seek(_ time:CMTime?, velocity: CGFloat) {
    guard let time = time else { return }
    guard let _ = asset else { return }
    let deltaSec = Double(velocity * secPerPx)
    let tolerance = deltaSec <= 0.2 && false ? kCMTimeZero : CMTimeMakeWithSeconds(deltaSec, Int32(NSEC_PER_SEC))
    print(velocity,deltaSec)
    player?.seek(to: time, toleranceBefore: tolerance, toleranceAfter: tolerance, completionHandler: { [weak self] _ in
      guard let currentTime = self?.player?.currentTime() else { return }
      if deltaSec <= 0.2 && CMTimeCompare(currentTime, time) != 0 {
        self?.player?.seek(to: time, toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero)
        print("sensitive seek")
      }
    })
  }
  
  fileprivate func syncScrollView(currenTime: CMTime) {
    reelCollectionView.contentOffset.x = self.x(with: currenTime) - reelCollectionView.contentInset.left
  }
}

// MARK: - CollectionView DataSource

extension ViewController:  UICollectionViewDelegate, UICollectionViewDataSource {
  
  func numberOfSections(in collectionView: UICollectionView) -> Int {
    return 1
  }
  
  func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return numOfCells()
  }
  
  func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ThumbnailCell", for: indexPath) as? ThumbnailCell else {
      return UICollectionViewCell.init()
    }
    let index = indexPath.row
    if thumbnails.indices.contains(index) {
      cell.setImage(thumbnails[index])
    }
    return cell
  }
  
  func scrollViewDidScroll(_ scrollView: UIScrollView) {
    guard player?.rate == 0 else { return }
    var x = scrollView.contentOffset.x + scrollView.contentInset.left
    x = x < 0 ? 0 : x
    let v = fabs(x - prevScrolledX)
    prevScrolledX = x
    seek(cmTime(with: x), velocity: v)
  }
  
  func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
    player?.play()
  }
  
  func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
    player?.pause()
  }
  
  func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
    if !decelerate {
      player?.play()
    }
  }
}

// MARK: - CollectionView FlowLayout

extension ViewController:  UICollectionViewDelegateFlowLayout {
  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
    let width = reelWidth() / CGFloat(numOfCells())
    return CGSize.init(width: width, height: collectionView.bounds.height)
  }
  
  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
    let w = collectionView.bounds.width / 2
    return UIEdgeInsetsMake(0,w,0,w)
  }
  
  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
    return 0
  }
  
  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
    return 0
  }
  
  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
    return .zero
  }
  
}
