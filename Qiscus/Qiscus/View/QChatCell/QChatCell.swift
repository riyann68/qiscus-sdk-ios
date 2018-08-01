//
//  QChatCell.swift
//  QiscusSDK
//
//  Created by Ahmad Athaullah on 1/6/17.
//  Copyright © 2017 Ahmad Athaullah. All rights reserved.
//

import UIKit
import SwiftyJSON

@objc public protocol ChatCellDelegate {
    func didTapCell(onComment comment: QComment)
    func didTouchLink(onComment comment: QComment)
    func didTapPostbackButton(onComment comment: QComment, index:Int)
    func didTapAccountLinking(onComment comment: QComment)
    func didTapSaveContact(onComment comment: QComment)
    func didTapCardButton(onComment comment:QComment, index:Int)
    func didShare(comment: QComment)
    func didForward(comment: QComment)
    func didReply(comment:QComment)
    func getInfo(comment:QComment)
    func didTapFile(comment:QComment)
    func useSoftDelete()->Bool
    func willDeleteComment(onIndexPath indexPath:IndexPath)
    func didDeleteComment(onIndexPath indexPath:IndexPath)
    @objc optional func deletedMessageText(selfMessage isSelf:Bool)->String
    @objc optional func enableReplyMenuItem(onCell cell:QChatCell)->Bool
    @objc optional func enableForwardMenuItem(onCell cell:QChatCell)->Bool
    @objc optional func enableResendMenuItem(onCell cell:QChatCell)->Bool
    @objc optional func enableDeleteMenuItem(onCell cell:QChatCell)->Bool
    @objc optional func enableDeleteForMeMenuItem(onCell cell:QChatCell)->Bool
    @objc optional func enableShareMenuItem(onCell cell:QChatCell)->Bool
    @objc optional func enableInfoMenuItem(onCell cell:QChatCell)->Bool
}

open class QChatCell: UICollectionViewCell, QCommentDelegate {
    
    var delegate: ChatCellDelegate?
    var showUserName:Bool = false
    var userNameColor:UIColor?
    var hideAvatar:Bool = false
    var indexPath:IndexPath?
    
    private var commentRaw:QComment?
        
    public var comment:QComment?{
        get{
            return self.commentRaw
        }
    }
    var linkTextAttributes:[String: Any]{
        get{
            var foregroundColorAttributeName = QiscusColorConfiguration.sharedInstance.leftBaloonLinkColor
            var underlineColorAttributeName = QiscusColorConfiguration.sharedInstance.leftBaloonLinkColor
            if self.comment?.senderEmail == Qiscus.client.email{
                foregroundColorAttributeName = QiscusColorConfiguration.sharedInstance.rightBaloonLinkColor
                underlineColorAttributeName = QiscusColorConfiguration.sharedInstance.rightBaloonLinkColor
            }
            return [
                NSAttributedStringKey.foregroundColor.rawValue: foregroundColorAttributeName,
                NSAttributedStringKey.underlineColor.rawValue: underlineColorAttributeName,
                NSAttributedStringKey.underlineStyle.rawValue: NSUnderlineStyle.styleSingle.rawValue,
                NSAttributedStringKey.font.rawValue: Qiscus.style.chatFont
            ]
        }
    }
    
    override open func awakeFromNib() {
        super.awakeFromNib()
        
        NotificationCenter.default.addObserver(self, selector: #selector(QChatCell.userNameChanged(_:)), name: QiscusNotification.USER_NAME_CHANGE, object: nil)
    }
    
    open func setupCell(){
        // implementation will be overrided on child class
    }
    
    public class func defaultDeletedText(selfMessage isSelf:Bool = false)->String{
        if isSelf {
            return "🚫 You deleted this message."
        }else{
            return "🚫 This message was deleted."
        }
    }
    // MARK: - userAvatarChange Handler
    @objc private func userNameChanged(_ notification: Notification) {
        if let userInfo = notification.userInfo {
            if let c = self.comment {
                if c.isInvalidated {
                    return
                }
                let userData = userInfo["user"] as! QUser
                if c.senderEmail == userData.email {
                    self.updateUserName()
                }
            }
        }
    }
    
    open func updateStatus(toStatus status:QCommentStatus){
        if status == .deleted {
            if let index = self.indexPath {
                self.delegate?.didDeleteComment(onIndexPath: index)
            }
        }
        // other implementation will be overrided on child class
    }
    @objc open func resend(){
        let roomId = self.comment!.roomId
        let cUid = self.comment!.uniqueId
        QiscusBackgroundThread.async {
            if let room = QRoom.threadSaveRoom(withId: roomId){
                if let c = QComment.threadSaveComment(withUniqueId: cUid){
                    switch c.type{
                    case .text,.contact:
                        c.updateStatus(status: .sending)
                        room.post(comment: c)
                        break
                    case .video,.image,.audio,.file,.document:
                        if let file = c.file {
                            if file.url.contains("http") {
                                c.updateStatus(status: .sending)
                                room.post(comment: c)
                            }else{
                                if QFileManager.isFileExist(inLocalPath: file.localPath) {
                                    room.upload(comment: c, onSuccess: { (r, message) in
                                        r.post(comment: message)
                                    }, onError: { (_, _, error) in
                                        Qiscus.printLog(text: "error reupload file")
                                    })
                                }
                            }
                        }
                        break
                    default:
                        break
                    }
                }
            }
        }
    }
    @objc open func reply(){
        self.delegate?.didReply(comment: self.comment!)
    }
    @objc open func forward(){
        self.delegate?.didForward(comment: self.comment!)
    }
    @objc open func deleteComment(){        
        if let comment = self.comment {
            let uid = comment.uniqueId
            let roomId = comment.roomId
            QiscusBackgroundThread.async {
                if let c = QComment.threadSaveComment(withUniqueId: uid){
                    guard let r = QRoom.threadSaveRoom(withId: roomId) else {return}
                    if c.status == .failed || c.status == .pending || c.status == .sending {
                        r.deleteComment(comment: c)
                    }else{
                        var hardDelete = false
                        if let softDelete = self.delegate?.useSoftDelete(){
                            hardDelete = !softDelete
                        }
                        c.updateStatus(status: .deleting)
                        if let index = self.indexPath {
                            DispatchQueue.main.async {
                                self.delegate?.willDeleteComment(onIndexPath: index)
                            }
                        }
                        c.delete(forMeOnly: false, hardDelete: hardDelete, onSuccess: {
                            QiscusBackgroundThread.async {
                                if hardDelete {
                                    if let room = QRoom.threadSaveRoom(withId: roomId){
                                        if let comment = QComment.threadSaveComment(withUniqueId: uid){
                                            room.deleteComment(comment: comment)
                                        }
                                    }
                                }
                                if let index = self.indexPath {
                                    DispatchQueue.main.async {
                                        self.delegate?.didDeleteComment(onIndexPath: index)
                                    }
                                }
                            }
                        }, onError: { (statusCode) in
                            Qiscus.printLog(text: "delete error: status code \(String(describing: statusCode))")
                        })
                    }
                }
            }
        }
    }
    @objc open func deleteForMe(){
        if let comment = self.comment {
            let uid = comment.uniqueId
            let roomId = comment.roomId
            QiscusBackgroundThread.async {
                if let c = QComment.threadSaveComment(withUniqueId: uid){
                    guard let r = QRoom.threadSaveRoom(withId: roomId) else {return}
                    if c.status == .failed || c.status == .pending || c.status == .sending {
                        r.deleteComment(comment: c)
                    }else{
                        var hardDelete = false
                        if let softDelete = self.delegate?.useSoftDelete(){
                            hardDelete = !softDelete
                        }
                        c.updateStatus(status: .deleting)
                        if let index = self.indexPath {
                            DispatchQueue.main.async {
                                self.delegate?.willDeleteComment(onIndexPath: index)
                            }
                        }
                        c.delete(forMeOnly: true, hardDelete: hardDelete, onSuccess: {
                            QiscusBackgroundThread.async {
                                if hardDelete {
                                    if let room = QRoom.threadSaveRoom(withId: roomId){
                                        if let comment = QComment.threadSaveComment(withUniqueId: uid){
                                            room.deleteComment(comment: comment)
                                        }
                                    }
                                }
                                if let index = self.indexPath {
                                    DispatchQueue.main.async {
                                        self.delegate?.didDeleteComment(onIndexPath: index)
                                    }
                                }
                            }
                        }, onError: { (statusCode) in
                            Qiscus.printLog(text: "delete error: status code \(statusCode)")
                        })
                    }
                }
            }
        }
    }
    @objc open func info(){
        self.delegate?.getInfo(comment: self.comment!)
    }
    @objc open func share(){
        if let comment = self.comment {
            self.delegate?.didShare(comment: comment)
        }
    }
    @objc open func showFile(){
        if let c = self.comment {
            self.delegate?.didTapFile(comment: c)
        }
    }
    
    func clearContext(){
        
    }
    
    open func commentChanged(){
        
    }

    open func getBallon()->UIImage?{
        var balloonImage:UIImage? = nil
        var edgeInset = UIEdgeInsetsMake(13, 13, 13, 28)
        
        if !(self.comment?.isInvalidated)! {
            switch self.comment!.cellPos {
            case .single, .last:
                if self.comment?.senderEmail == Qiscus.client.email {
                    balloonImage = Qiscus.style.assets.rightBallonLast
                }else{
                    edgeInset = UIEdgeInsetsMake(13, 28, 13, 13)
                    balloonImage = Qiscus.style.assets.leftBallonLast
                }
                break
            default:
                if self.comment?.senderEmail == Qiscus.client.email {
                    balloonImage = Qiscus.style.assets.rightBallonNormal
                }else{
                    edgeInset = UIEdgeInsetsMake(13, 28, 13, 13)
                    balloonImage = Qiscus.style.assets.leftBallonNormal
                }
                break
            }
        }
        
        return balloonImage?.resizableImage(withCapInsets: edgeInset, resizingMode: .stretch).withRenderingMode(.alwaysTemplate)
    }
    open func willDisplayCell(){
        
    }
    open func endDisplayingCell(){
    
    }
    open func cellWidthChanged(){
    
    }
    open func downloadingMedia(){
        // implementation will be overrided on child class
    }
    open func downloadFinished(){
    
    }
    open func uploadingMedia(){
    
    }
    open func uploadFinished(){
        
    }
    open func positionChanged(){
    
    }
    open func updateUserName(){
    
    }
    internal func unbindData(){
        if let data = self.comment {
            data.delegate = nil
        }
    }
    public func setData(onIndexPath indexPath:IndexPath, comment:QComment, showUserName:Bool, userNameColor:UIColor?, hideAvatar:Bool, delegate:ChatCellDelegate? = nil){
        var oldUniqueId:String?
        if delegate != nil {
            self.delegate = delegate!
        }
        self.showUserName = showUserName
        self.hideAvatar = hideAvatar
        self.indexPath = indexPath
        
        if let color = userNameColor {
            self.userNameColor = color
        }else{
            self.userNameColor = UIColor(red: 85/255, green: 85/255, blue: 85/255, alpha: 1)
        }
        self.clipsToBounds = true
        if let oldComment = self.comment {
            if !oldComment.isInvalidated {
                oldComment.delegate = nil
                oldUniqueId = oldComment.uniqueId
            }
        }
        
        if !comment.isInvalidated {
            if let cache = QComment.cache[comment.uniqueId]{
                self.commentRaw = cache
            }else{
                QComment.cache[comment.uniqueId] = comment
                self.commentRaw = comment
            }
        }
        
        if let selfComment = self.comment {
            selfComment.delegate = self
        }
        
        if let uId = oldUniqueId {
            if uId != comment.uniqueId {
                self.commentChanged()
            }
        }else{
            self.commentChanged()
        }
        var menuItems: [UIMenuItem] = [UIMenuItem]()
        
        let resendMenuItem: UIMenuItem = UIMenuItem(title: "RESEND".getLocalize(), action: #selector(QChatCell.resend))
        let deleteMenuItem: UIMenuItem = UIMenuItem(title: "DELETE".getLocalize(), action: #selector(QChatCell.deleteComment))
        let deleteForMeMenuItem: UIMenuItem = UIMenuItem(title: "DELETE_FOR_ME".getLocalize(), action: #selector(QChatCell.deleteForMe))
        let replyMenuItem: UIMenuItem = UIMenuItem(title: "REPLY".getLocalize(), action: #selector(QChatCell.reply))
        let forwardMenuItem: UIMenuItem = UIMenuItem(title: "FORWARD".getLocalize(), action: #selector(QChatCell.forward))
        let shareMenuItem: UIMenuItem = UIMenuItem(title: "SHARE".getLocalize(), action: #selector(QChatCell.share))
        let infoMenuItem: UIMenuItem = UIMenuItem(title: "INFO".getLocalize(), action: #selector(QChatCell.info))
        
        if let isEnable = delegate?.enableReplyMenuItem?(onCell: self) {
            if isEnable {
                menuItems.append(replyMenuItem)
            }
        } else {
            menuItems.append(replyMenuItem)
        }
        
        if let isEnable = delegate?.enableForwardMenuItem?(onCell: self) {
            if isEnable {
                menuItems.append(forwardMenuItem)
            }
        } else {
            menuItems.append(forwardMenuItem)
        }

        if let isEnable = delegate?.enableResendMenuItem?(onCell: self) {
            if isEnable {
                menuItems.append(resendMenuItem)
            }
        } else {
            menuItems.append(resendMenuItem)
        }
        
        if let isEnable = delegate?.enableDeleteMenuItem?(onCell: self) {
            if isEnable {
                menuItems.append(deleteMenuItem)
            }
        } else {
            menuItems.append(deleteMenuItem)
        }
        
        if let isEnable = delegate?.enableDeleteForMeMenuItem?(onCell: self) {
            if isEnable {
                if let room = comment.room {
                    if !room.isPublicChannel {
                        menuItems.append(deleteForMeMenuItem)
                    }
                } else {
                    menuItems.append(deleteForMeMenuItem)
                }
            }
        } else {
            if let room = comment.room {
                if !room.isPublicChannel {
                    menuItems.append(deleteForMeMenuItem)
                }
            } else {
                menuItems.append(deleteForMeMenuItem)
            }
        }
        
        
        if let isEnable = delegate?.enableShareMenuItem?(onCell: self) {
            if isEnable {
                menuItems.append(shareMenuItem)
            }
        } else {
            menuItems.append(shareMenuItem)
        }
        
        if let isEnable = delegate?.enableInfoMenuItem?(onCell: self) {
            if isEnable {
                if let room = comment.room {
                    if !room.isPublicChannel {
                        menuItems.append(infoMenuItem)
                    }
                } else {
                    menuItems.append(infoMenuItem)
                }
            }
        } else {
            if let room = comment.room {
                if !room.isPublicChannel {
                    menuItems.append(infoMenuItem)
                }
            } else {
                menuItems.append(infoMenuItem)
            }
        }
        
        UIMenuController.shared.menuItems = menuItems
    }
    
    // MARK: - commentDelegate
    open func comment(didChangeStatus comment:QComment, status:QCommentStatus){
        if let c = self.comment {
            if comment.isInvalidated || c.isInvalidated {
                if let delegate = self.delegate {
                    if let index = self.indexPath {
                        delegate.didDeleteComment(onIndexPath: index)
                    }
                }
            }else{
                if comment.uniqueId == c.uniqueId{
                    self.updateStatus(toStatus: status)
                }
            }
        }
    }
    open func comment(didChangePosition comment:QComment, position:QCellPosition){}
    
    // Audio comment delegate
    open func comment(didChangeDurationLabel comment:QComment, label:String){}
    open func comment(didChangeCurrentTimeSlider comment:QComment, value:Float){}
    open func comment(didChangeSeekTimeLabel comment:QComment, label:String){}
    open func comment(didChangeAudioPlaying comment:QComment, playing:Bool){}
    
    // File comment delegate
    open func comment(didDownload comment:QComment, downloading:Bool){
        
    }
    open func comment(didUpload comment:QComment, uploading:Bool){}
    open func comment(didChangeProgress comment:QComment, progress:CGFloat){}
    
    
}
