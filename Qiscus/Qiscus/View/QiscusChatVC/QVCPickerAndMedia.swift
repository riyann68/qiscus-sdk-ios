//
//  QVCPickerAndMedia.swift
//  Example
//
//  Created by Ahmad Athaullah on 5/16/17.
//  Copyright © 2017 Ahmad Athaullah. All rights reserved.
//

import UIKit
import ImageViewer
import AVFoundation
import Photos

// MARK: - GaleryItemDataSource
extension QiscusChatVC:GalleryItemsDataSource{
    
    // MARK: - Galery Function
    public func galleryConfiguration()-> GalleryConfiguration{
        let closeButton = UIButton(frame: CGRect(origin: CGPoint.zero, size: CGSize(width: 20, height: 20)))
        closeButton.setImage(Qiscus.image(named: "close")?.withRenderingMode(.alwaysTemplate), for: UIControlState())
        closeButton.tintColor = UIColor.white
        closeButton.imageView?.contentMode = .scaleAspectFit
        
        let seeAllButton = UIButton(frame: CGRect(origin: CGPoint.zero, size: CGSize(width: 20, height: 20)))
        seeAllButton.setTitle("", for: UIControlState())
        seeAllButton.setImage(Qiscus.image(named: "viewmode")?.withRenderingMode(.alwaysTemplate), for: UIControlState())
        seeAllButton.tintColor = UIColor.white
        seeAllButton.imageView?.contentMode = .scaleAspectFit
        
        return [
            GalleryConfigurationItem.closeButtonMode(.custom(closeButton)),
            GalleryConfigurationItem.thumbnailsButtonMode(.custom(seeAllButton)),
            GalleryConfigurationItem.deleteButtonMode(.none)
        ]
    }
    
    public func itemCount() -> Int{
        return self.galleryItems.count
    }
    public func provideGalleryItem(_ index: Int) -> GalleryItem{
        let item = self.galleryItems[index]
        if item.isVideo{
            return GalleryItem.video(fetchPreviewImageBlock: { $0(item.image)}, videoURL: URL(string: item.url)! )
        }else{
            return GalleryItem.image { $0(item.image) }
        }
    }
}
// MARK: - UIImagePickerDelegate
extension QiscusChatVC:UIImagePickerControllerDelegate, UINavigationControllerDelegate{
    func showFileTooBigAlert(){
        let alertController = UIAlertController(title: "Fail to upload", message: "File too big", preferredStyle: .alert)
        let galeryActionButton = UIAlertAction(title: "Cancel", style: .cancel) { _ -> Void in }
        alertController.addAction(galeryActionButton)
        self.present(alertController, animated: true, completion: nil)
    }
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]){
        if !self.processingFile {
            self.processingFile = true
            let time = Double(Date().timeIntervalSince1970)
            let timeToken = UInt64(time * 10000)
            let fileType:String = info[UIImagePickerControllerMediaType] as! String
            //picker.dismiss(animated: true, completion: nil)
            
            if fileType == "public.image"{
                var imageName:String = ""
                let image = info[UIImagePickerControllerOriginalImage] as! UIImage
                var data = UIImagePNGRepresentation(image)
                
                if let imageURL = info[UIImagePickerControllerReferenceURL] as? URL{
                    imageName = imageURL.lastPathComponent
                    
                    let imageNameArr = imageName.split(separator: ".")
                        let imageExt:String = String(imageNameArr.last!).lowercased()
                    
                    let gif:Bool = (imageExt == "gif" || imageExt == "gif_")
                    let png:Bool = (imageExt == "png" || imageExt == "png_")
                    
                    if png{
                        data = UIImagePNGRepresentation(image)!
                    }else if gif{
                        let asset = PHAsset.fetchAssets(withALAssetURLs: [imageURL], options: nil)
                        if let phAsset = asset.firstObject {
                            let option = PHImageRequestOptions()
                            option.isSynchronous = true
                            option.isNetworkAccessAllowed = true
                            PHImageManager.default().requestImageData(for: phAsset, options: option) {
                                (gifData, dataURI, orientation, info) -> Void in
                                data = gifData
                            }
                        }
                    }else{
                        let result = PHAsset.fetchAssets(withALAssetURLs: [imageURL], options: nil)
                        let asset = result.firstObject
                        imageName = "\((asset?.value(forKey: "filename"))!)"
                        imageName = imageName.replacingOccurrences(of: "HEIC", with: "jpg")
                        let imageSize = image.size
                        var bigPart = CGFloat(0)
                        if(imageSize.width > imageSize.height){
                            bigPart = imageSize.width
                        }else{
                            bigPart = imageSize.height
                        }
                        
                        var compressVal = CGFloat(1)
                        if(bigPart > 2000){
                            compressVal = 2000 / bigPart
                        }
                        
                        data = UIImageJPEGRepresentation(image, compressVal)!
                    }
                }else{
                    let mediaSize = Double(data!.count) / 1024.0
                    if mediaSize > Qiscus.maxUploadSizeInKB {
                        picker.dismiss(animated: true, completion: {
                            self.processingFile = false
                            self.showFileTooBigAlert()
                        })
                        return
                    }
                    
                    UIImageWriteToSavedPhotosAlbum(image, self, #selector(QiscusChatVC.image(_:didFinishSavingWithError:contextInfo:)), nil)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
                        picker.dismiss(animated: true, completion: {
                            self.processingFile = false
                        })
                    })
                    
                    return
                }
                
                if data != nil {
                    let mediaSize = Double(data!.count) / 1024.0
                    if mediaSize > Qiscus.maxUploadSizeInKB {
                        picker.dismiss(animated: true, completion: {
                            self.processingFile = false
                            self.showFileTooBigAlert()
                        })
                        return
                    }
                    let uploader = QiscusUploaderVC(nibName: "QiscusUploaderVC", bundle: Qiscus.bundle)
                    uploader.chatView = self
                    uploader.data = data
                    uploader.fileName = imageName
                    uploader.room = self.chatRoom
                    self.navigationController?.pushViewController(uploader, animated: true)
                    picker.dismiss(animated: true, completion: {
                        self.processingFile = false
                    })
                }
            }else if fileType == "public.movie" {
                let mediaURL = info[UIImagePickerControllerMediaURL] as! URL
                let fileName = mediaURL.lastPathComponent
                
                let mediaData = try? Data(contentsOf: mediaURL)
                let mediaSize = Double(mediaData!.count) / 1024.0
                if mediaSize > Qiscus.maxUploadSizeInKB {
                    picker.dismiss(animated: true, completion: {
                        self.processingFile = false
                        self.showFileTooBigAlert()
                    })
                    return
                }
                //create thumb image
                let assetMedia = AVURLAsset(url: mediaURL)
                let thumbGenerator = AVAssetImageGenerator(asset: assetMedia)
                thumbGenerator.appliesPreferredTrackTransform = true
                
                let thumbTime = CMTimeMakeWithSeconds(0, 30)
                let maxSize = CGSize(width: QiscusHelper.screenWidth(), height: QiscusHelper.screenWidth())
                thumbGenerator.maximumSize = maxSize
                
                picker.dismiss(animated: true, completion: {
                    self.processingFile = false
                })
                do{
                    let thumbRef = try thumbGenerator.copyCGImage(at: thumbTime, actualTime: nil)
                    let thumbImage = UIImage(cgImage: thumbRef)
                    
                    QPopUpView.showAlert(withTarget: self, image: thumbImage, message:"Are you sure to send this video?", isVideoImage: true,
                    doneAction: {
                        self.postFile(filename: fileName, data: mediaData!, type: .video, thumbImage: thumbImage)
                    },
                    cancelAction: {
                        Qiscus.printLog(text: "cancel upload")
                        QFileManager.clearTempDirectory()
                    }
                    )
                }catch{
                    Qiscus.printLog(text: "error creating thumb image")
                }
            }
        }
    }
    
    @objc func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        let requestOptions = PHImageRequestOptions()
        requestOptions.isSynchronous = true
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key:"creationDate", ascending: false)]
        fetchOptions.fetchLimit = 1
        
        let fetchResult: PHFetchResult = PHAsset.fetchAssets(with: PHAssetMediaType.image, options: fetchOptions)
        // Perform the image request
        
        var imageName = ""
        PHImageManager.default().requestImage(for: fetchResult.object(at: 0) as PHAsset, targetSize: view.frame.size, contentMode: PHImageContentMode.aspectFill, options: requestOptions, resultHandler: { (image, info) in
            if let info = info {
                if info.keys.contains(NSString(string: "PHImageFileURLKey")) {
                    if let path = info[NSString(string: "PHImageFileURLKey")] as? NSURL {
                        imageName = path.lastPathComponent!
                    }
                }
            }
        })
        
        let imageSize = image.size
        var bigPart = CGFloat(0)
        if(imageSize.width > imageSize.height){
            bigPart = imageSize.width
        }else{
            bigPart = imageSize.height
        }
        
        var compressVal = CGFloat(1)
        if(bigPart > 2000){
            compressVal = 2000 / bigPart
        }
        
        let data = UIImageJPEGRepresentation(image, compressVal)!
        
        
        if data != nil {
            let uploader = QiscusUploaderVC(nibName: "QiscusUploaderVC", bundle: Qiscus.bundle)
            uploader.chatView = self
            uploader.data = data
            uploader.fileName = imageName
            uploader.room = self.chatRoom
            self.navigationController?.pushViewController(uploader, animated: true)
        }
    }
    
    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
}

// MARK: - UIDocumentPickerDelegate
extension QiscusChatVC: UIDocumentPickerDelegate{
    public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        self.postReceivedFile(fileUrl: url)
    }
}
// MARK: - AudioPlayer
extension QiscusChatVC:AVAudioPlayerDelegate{
    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        do {
            try AVAudioSession.sharedInstance().setActive(false)
            if let activeCell = activeAudioCell {
                activeCell.comment!.updatePlaying(playing: false)
            }
            stopTimer()
            updateAudioDisplay()
        } catch _ as NSError {}
    }
    
    public func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        if let activeCell = activeAudioCell as? QCellAudioLeft{
            activeCell.comment!.updatePlaying(playing: false)
        }
        stopTimer()
        updateAudioDisplay()
    }
    
    // MARK: - Audio Methods
    func audioTimerFired(_ timer: Timer) {
        self.updateAudioDisplay()
    }
    
    func stopTimer() {
        audioTimer?.invalidate()
        audioTimer = nil
    }
    
    func updateAudioDisplay() {
        if let cell = activeAudioCell{
            if let currentTime = audioPlayer?.currentTime {
                cell.updateAudioDisplay(withTimeInterval: currentTime)
            }
        }
    }
}
