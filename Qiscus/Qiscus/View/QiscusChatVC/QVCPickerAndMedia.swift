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
            GalleryConfigurationItem.thumbnailsButtonMode(.custom(seeAllButton))
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
                        imageName = "\(timeToken).jpg"
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
                    imageName = "\(timeToken).jpg"
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
    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
}

// MARK: - UIDocumentPickerDelegate
extension QiscusChatVC: UIDocumentPickerDelegate{
    public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        self.showLoading("Processing File")
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(readingItemAt: url, options: NSFileCoordinator.ReadingOptions.forUploading, error: nil) { (dataURL) in
            do{
                var data:Data = try Data(contentsOf: dataURL, options: NSData.ReadingOptions.mappedIfSafe)
                let mediaSize = Double(data.count) / 1024.0
                
                if mediaSize > Qiscus.maxUploadSizeInKB {
                    self.processingFile = false
                    self.dismissLoading()
                    self.showFileTooBigAlert()
                    return
                }
                
                var fileName = dataURL.lastPathComponent.replacingOccurrences(of: "%20", with: "_")
                fileName = fileName.replacingOccurrences(of: " ", with: "_")
                
                var popupText = QiscusTextConfiguration.sharedInstance.confirmationImageUploadText
                var fileType = QiscusFileType.image
                var thumb:UIImage? = nil
                let fileNameArr = (fileName as String).split(separator: ".")
                let ext = String(fileNameArr.last!).lowercased()
                
                let gif = (ext == "gif" || ext == "gif_")
                let video = (ext == "mp4" || ext == "mp4_" || ext == "mov" || ext == "mov_")
                let isImage = (ext == "jpg" || ext == "jpg_" || ext == "tif" || ext == "heic" || ext == "png" || ext == "png_")
                let isPDF = (ext == "pdf" || ext == "pdf_")
                var usePopup = false
                
                if isImage{
                    var i = 0
                    for n in fileNameArr{
                        if i == 0 {
                            fileName = String(n)
                        }else if i == fileNameArr.count - 1 {
                            fileName = "\(fileName).jpg"
                        }else{
                            fileName = "\(fileName).\(String(n))"
                        }
                        i += 1
                    }
                    let image = UIImage(data: data)!
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
                    thumb = UIImage(data: data)
                }else if isPDF{
                    usePopup = true
                    popupText = "Are you sure to send this document?"
                    fileType = QiscusFileType.document
                    if let provider = CGDataProvider(data: data as NSData) {
                        if let pdfDoc = CGPDFDocument(provider) {
                            if let pdfPage:CGPDFPage = pdfDoc.page(at: 1) {
                                var pageRect:CGRect = pdfPage.getBoxRect(.mediaBox)
                                pageRect.size = CGSize(width:pageRect.size.width, height:pageRect.size.height)
                                UIGraphicsBeginImageContext(pageRect.size)
                                if let context:CGContext = UIGraphicsGetCurrentContext(){
                                    context.saveGState()
                                    context.translateBy(x: 0.0, y: pageRect.size.height)
                                    context.scaleBy(x: 1.0, y: -1.0)
                                    context.concatenate(pdfPage.getDrawingTransform(.mediaBox, rect: pageRect, rotate: 0, preserveAspectRatio: true))
                                    context.drawPDFPage(pdfPage)
                                    context.restoreGState()
                                    if let pdfImage:UIImage = UIGraphicsGetImageFromCurrentImageContext() {
                                        thumb = pdfImage
                                    }
                                }
                                UIGraphicsEndImageContext()
                            }
                        }
                    }
                }
                else if gif{
                    let image = UIImage(data: data)!
                    thumb = image
                    let asset = PHAsset.fetchAssets(withALAssetURLs: [dataURL], options: nil)
                    if let phAsset = asset.firstObject {
                        let option = PHImageRequestOptions()
                        option.isSynchronous = true
                        option.isNetworkAccessAllowed = true
                        PHImageManager.default().requestImageData(for: phAsset, options: option) {
                            (gifData, dataURI, orientation, info) -> Void in
                            data = gifData!
                        }
                    }
                    popupText = "Are you sure to send this image?"
                    usePopup = true
                }else if video {
                    fileType = .video
                    
                    let assetMedia = AVURLAsset(url: dataURL)
                    let thumbGenerator = AVAssetImageGenerator(asset: assetMedia)
                    thumbGenerator.appliesPreferredTrackTransform = true
                    
                    let thumbTime = CMTimeMakeWithSeconds(0, 30)
                    let maxSize = CGSize(width: QiscusHelper.screenWidth(), height: QiscusHelper.screenWidth())
                    thumbGenerator.maximumSize = maxSize
                    
                    do{
                        let thumbRef = try thumbGenerator.copyCGImage(at: thumbTime, actualTime: nil)
                        thumb = UIImage(cgImage: thumbRef)
                        popupText = "Are you sure to send this video?"
                    }catch{
                        Qiscus.printLog(text: "error creating thumb image")
                    }
                    usePopup = true
                }else{
                    usePopup = true
                    let textFirst = QiscusTextConfiguration.sharedInstance.confirmationFileUploadText
                    let textMiddle = "\(fileName as String)"
                    let textLast = QiscusTextConfiguration.sharedInstance.questionMark
                    popupText = "\(textFirst) \(textMiddle) \(textLast)"
                    fileType = QiscusFileType.file
                }
                self.dismissLoading()
//                UINavigationBar.appearance().tintColor = self.currentNavbarTint
                if usePopup {
                    QPopUpView.showAlert(withTarget: self, image: thumb, message:popupText, isVideoImage: video,
                                         doneAction: {
                                            self.postFile(filename: fileName, data: data, type: fileType, thumbImage: thumb)
                    },
                                         cancelAction: {
                                            Qiscus.printLog(text: "cancel upload")
                                            QFileManager.clearTempDirectory()
                    }
                    )
                }else{
                    let uploader = QiscusUploaderVC(nibName: "QiscusUploaderVC", bundle: Qiscus.bundle)
                    uploader.chatView = self
                    uploader.data = data
                    uploader.fileName = fileName
                    uploader.room = self.chatRoom
                    self.navigationController?.pushViewController(uploader, animated: true)
                }
            }catch _{
                self.dismissLoading()
            }
        }
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
