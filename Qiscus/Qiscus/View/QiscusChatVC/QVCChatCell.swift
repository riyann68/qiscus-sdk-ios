//
//  QVCChatCell.swift
//  Example
//
//  Created by Ahmad Athaullah on 5/16/17.
//  Copyright © 2017 Ahmad Athaullah. All rights reserved.
//

import UIKit
import ImageViewer
import AVFoundation
import SwiftyJSON
import ContactsUI

// MARK: - ChatCell Delegate
extension QiscusChatVC: QConversationViewCellDelegate{
    public func cellDelegate(didTapInfoOnComment comment:QComment){
        self.info(comment: comment)
    }
    public func cellDelegate(didTapForwardOnComment comment:QComment){
        self.forward(comment: comment)
    }
    public func cellDelegate(didTapReplyOnComment comment:QComment){
        self.replyData = comment
    }
    public func cellDelegate(didTapShareOnComment comment:QComment){
        switch comment.type {
        case .image, .video, .audio, .file:
            if let file = comment.file {
                if QFileManager.isFileExist(inLocalPath: file.localPath){
                    var items:[Any] = [Any]()
                    switch file.type {
                    case .image:
                        let image = UIImage(contentsOfFile: file.localPath)!
                        items.append(image)
                        break
                    default:
                        let localURL = NSURL(fileURLWithPath: file.localPath)
                        items.append(localURL)
                        break
                    }
                    let activityViewController = UIActivityViewController(activityItems: items, applicationActivities: nil)
                    
                    activityViewController.popoverPresentationController?.sourceView = self.view
                    self.present(activityViewController, animated: true, completion: nil)
                }else{
                    if let fileURL = NSURL(string: file.url) {
                        let items:[Any] = [fileURL]
                        let activityViewController = UIActivityViewController(activityItems: items, applicationActivities: nil)
                        
                        activityViewController.popoverPresentationController?.sourceView = self.view
                        self.present(activityViewController, animated: true, completion: nil)
                    }
                }
            }
            break
        case .text:
            let activityViewController = UIActivityViewController(activityItems: [comment.text], applicationActivities: nil)
            
            activityViewController.popoverPresentationController?.sourceView = self.view
            self.present(activityViewController, animated: true, completion: nil)
            break
        case .document:
            if let file = comment.file {
                if QFileManager.isFileExist(inLocalPath: file.localPath){
                    var items:[Any] = [Any]()
                    
                    let localURL = NSURL(fileURLWithPath: file.localPath)
                    items.append(localURL)
                    
                    let activityViewController = UIActivityViewController(activityItems: items, applicationActivities: nil)
                    
                    activityViewController.popoverPresentationController?.sourceView = self.view
                    self.present(activityViewController, animated: true, completion: nil)
                }
            }
            break
        default:
            break
        }
    }
    
    public func cellDelegate(didTapMediaCell comment:QComment){
        if (comment.type == .image || comment.type == .video) && comment.file != nil{
            self.galleryItems = [QiscusGalleryItem]()
            let currentFile = comment.file!
            var totalIndex = 0
            var currentIndex = 0
            for targetData in self.chatRoom!.comments {
                if let file = targetData.file {
                    if QFileManager.isFileExist(inLocalPath: file.localPath){
                        if file.localPath == currentFile.localPath {
                            currentIndex = totalIndex
                        }
                        let urlString = "file://\(file.localPath)"
                        
                        
                        let allowedChar = CharacterSet(bitmapRepresentation: CharacterSet.urlPathAllowed.bitmapRepresentation)
                        if let encoded = urlString.addingPercentEncoding(withAllowedCharacters: allowedChar),
                            let url = URL(string: encoded)
                        {
                            if let imageData = try? Data(contentsOf: url) {
                                if file.type == .image {
                                    if file.ext == "gif"{
                                        if let image = UIImage.qiscusGIF(data: imageData){
                                            let item = QiscusGalleryItem()
                                            item.image = image
                                            item.isVideo = false
                                            self.galleryItems.append(item)
                                            totalIndex += 1
                                        }
                                    }else{
                                        if let image = UIImage(data: imageData) {
                                            let item = QiscusGalleryItem()
                                            item.image = image
                                            item.isVideo = false
                                            self.galleryItems.append(item)
                                            totalIndex += 1
                                        }
                                    }
                                }else if file.type == .video{
                                    let urlString = "file://\(file.localPath)"
                                    let urlThumb = "file://\(file.localThumbPath)"
                                    if let url = URL(string: urlThumb) {
                                        if let data = try? Data(contentsOf: url) {
                                            if let image = UIImage(data: data){
                                                let item = QiscusGalleryItem()
                                                item.image = image
                                                item.isVideo = true
                                                item.url = urlString
                                                self.galleryItems.append(item)
                                                totalIndex += 1
                                            }
                                        }
                                    }
                                }
                            } else if let originalUrl = URL(string: urlString) {
                                guard let imageData = try? Data(contentsOf: originalUrl) else {return}
                                if file.type == .image {
                                    if file.ext == "gif"{
                                        if let image = UIImage.qiscusGIF(data: imageData){
                                            let item = QiscusGalleryItem()
                                            item.image = image
                                            item.isVideo = false
                                            self.galleryItems.append(item)
                                            totalIndex += 1
                                        }
                                    }else{
                                        if let image = UIImage(data: imageData) {
                                            let item = QiscusGalleryItem()
                                            item.image = image
                                            item.isVideo = false
                                            self.galleryItems.append(item)
                                            totalIndex += 1
                                        }
                                    }
                                }else if file.type == .video{
                                    let urlString = "file://\(file.localPath)"
                                    let urlThumb = "file://\(file.localThumbPath)"
                                    if let url = URL(string: urlThumb) {
                                        if let data = try? Data(contentsOf: url) {
                                            if let image = UIImage(data: data){
                                                let item = QiscusGalleryItem()
                                                item.image = image
                                                item.isVideo = true
                                                item.url = urlString
                                                self.galleryItems.append(item)
                                                totalIndex += 1
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            let closeButton = UIButton(frame: CGRect(origin: CGPoint.zero, size: CGSize(width: 20, height: 20)))
            closeButton.setImage(Qiscus.image(named: "close")?.withRenderingMode(.alwaysTemplate), for: UIControlState())
            closeButton.tintColor = UIColor.white
            closeButton.imageView?.contentMode = .scaleAspectFit
            
            let seeAllButton = UIButton(frame: CGRect(origin: CGPoint.zero, size: CGSize(width: 20, height: 20)))
            seeAllButton.setTitle("", for: UIControlState())
            seeAllButton.setImage(Qiscus.image(named: "viewmode")?.withRenderingMode(.alwaysTemplate), for: UIControlState())
            seeAllButton.tintColor = UIColor.white
            seeAllButton.imageView?.contentMode = .scaleAspectFit
            
            let gallery = GalleryViewController(startIndex: currentIndex, itemsDataSource: self, displacedViewsDataSource: nil, configuration: self.galleryConfiguration())
            self.presentImageGallery(gallery)
        }
    }
    public func cellDelegate(didTapAccountLinking comment:QComment){
        let data = JSON(parseJSON: comment.data)
        Qiscus.uiThread.async { autoreleasepool{
            let webView = ChatPreviewDocVC()
            webView.accountLinking = true
            webView.accountData = data
            
            self.navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
            self.navigationController?.pushViewController(webView, animated: true)
        }}
    }
    public func cellDelegate(didTapCardButton comment:QComment, buttonIndex index:Int){
        let commentData = comment.data
        let commentPayload = JSON(parseJSON: commentData)
        let buttonsData = commentPayload["buttons"].arrayValue
        let buttonData = buttonsData[index]
        self.didTapActionButton(withData: buttonData)
    }
    public func cellDelegate(didTapPostbackButton comment:QComment, buttonIndex index:Int){
        let allData = JSON(parseJSON: comment.data).arrayValue
        if allData.count > index {
            let data = allData[index]
            self.didTapActionButton(withData: data)
        }
    }
    public func cellDelegate(didTapCommentLink comment:QComment){
        
    }
    public func cellDelegate(didTapSaveContact comment:QComment){
        let payloadString = comment.data
        let payload = JSON(parseJSON: payloadString)
        let contactValue = payload["value"].stringValue
        
        let con = CNMutableContact()
        con.givenName = payload["name"].stringValue
        if contactValue.contains("@"){
            let email = CNLabeledValue(label: CNLabelHome, value: contactValue as NSString)
            con.emailAddresses.append(email)
        }else{
            let phone = CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: contactValue))
            con.phoneNumbers.append(phone)
        }
        
        let unkvc = CNContactViewController.init(forNewContact: con)
        unkvc.message = "Kiwari contact"
        unkvc.contactStore = CNContactStore()
        unkvc.delegate = self
        unkvc.allowsActions = false
        self.navigationController?.navigationBar.backgroundColor =  Qiscus.shared.styleConfiguration.color.topColor
        self.navigationController?.pushViewController(unkvc, animated: true)
    }
    
    public func cellDelegate(didTapDocumentFile comment:QComment, room:QRoom){
        if let file = comment.file {
            if file.ext == "pdf" || file.ext == "pdf_" {
                if QFileManager.isFileExist(inLocalPath: file.localPath){
                    let preview = ChatPreviewDocVC()
                    preview.file = file
                    preview.roomName = self.chatRoom!.name
                    let backButton = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
                    self.navigationItem.backBarButtonItem = backButton
                    self.navigationController?.pushViewController(preview, animated: true)
                }
            }
        }
    }
    public func cellDelegate(didTapKnownFile comment:QComment, room:QRoom){
        if let file = comment.file {
            if file.ext == "doc" || file.ext == "docx" || file.ext == "ppt" || file.ext == "pptx" || file.ext == "xls" || file.ext == "xlsx" || file.ext == "txt" {
                let url = file.url
                let filename = file.filename
                
                let preview = ChatPreviewDocVC()
                preview.file = file
                preview.fileName = filename
                preview.url = url
                preview.roomName = room.name
                let backButton = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
                self.navigationItem.backBarButtonItem = backButton
                self.navigationController?.pushViewController(preview, animated: true)
            }
        }
    }
    public func cellDelegate(didTapUnknownFile comment:QComment, room:QRoom){
        if let file = comment.file{
            if let url = URL(string: file.url){
                if #available(iOS 10.0, *) {
                    UIApplication.shared.open(url, completionHandler: { success in
                        if !success {
                            Qiscus.printLog(text: "fail to open file")
                        }
                    })
                } else {
                    UIApplication.shared.openURL(url)
                }
            }else{
                Qiscus.printLog(text: "cant open file url")
            }
        }
    }
    
    public func cellDelegate(didTapCard card: QCard) {
        let action = card.defaultAction
        self.cellDelegate(didTapCardAction: action!)
    }
    
    public func cellDelegate(didTapCardAction action: QCardAction) {
        if Qiscus.sharedInstance.connected{
            switch action.type {
            case .link:
                let urlString = action.payload!["url"].stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                let urlArray = urlString.components(separatedBy: "/")
                
                if let url = URL(string: urlString) {
                    if let overridedMethod = self.cellDelegate?.chatVC?(viewController: self, didTapLinkButtonWithURL: url){
                        overridedMethod
                    }else{
                        if urlArray.count > 2 {
                            if urlArray[2].lowercased().contains("instagram.com") {
                                var instagram = "instagram://app"
                                if urlArray.count == 4 || (urlArray.count == 5 && urlArray[4] == ""){
                                    let usernameIG = urlArray[3]
                                    instagram = "instagram://user?username=\(usernameIG)"
                                }
                                if let instagramURL =  URL(string: instagram) {
                                    if UIApplication.shared.canOpenURL(instagramURL) {
                                        UIApplication.shared.openURL(instagramURL)
                                    }else{
                                        UIApplication.shared.openURL(url)
                                    }
                                }
                            }else{
                                UIApplication.shared.openURL(url)
                            }
                        }else{
                            UIApplication.shared.openURL(url)
                        }
                    }
                }                
                break
            default:
                let text = action.postbackText
                let type = "button_postback_response"
                
                if let room = self.chatRoom {
                    let newComment = room.newComment(text: text)
                    room.post(comment: newComment, type: type, payload: action.payload!)
                }
                break
            }
            
        }else{
            Qiscus.uiThread.async { autoreleasepool{
                self.showNoConnectionToast()
            }}
        }
    }
}

extension QiscusChatVC: CNContactViewControllerDelegate{
    public func contactViewController(_ viewController: CNContactViewController, shouldPerformDefaultActionFor property: CNContactProperty) -> Bool {
        return true
    }
    
    public func contactViewController(_ viewController: CNContactViewController, didCompleteWith contact: CNContact?) {
        viewController.navigationController?.popViewController(animated: true)
    }
}

