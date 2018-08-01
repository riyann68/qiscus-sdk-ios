//
//  QRoom.swift
//  Example
//
//  Created by Ahmad Athaullah on 7/5/17.
//  Copyright © 2017 Ahmad Athaullah. All rights reserved.
//

import Foundation
import RealmSwift
import SwiftyJSON
import AVFoundation

@objc public enum QRoomType:Int{
    case single
    case group
}
@objc public enum QRoomProperty:Int{
    case name
    case avatar
    case participant
    case lastComment
    case unreadCount
    case data
}
@objc public protocol QRoomDelegate {
    @objc optional func room(didChangeName room:QRoom)
    @objc optional func room(didChangeAvatar room:QRoom)
    @objc optional func room(didChangeParticipant room:QRoom)
    @objc optional func room(didDeleteComment room:QRoom)
    
    @objc optional func room(didChangeUser room:QRoom, user:QUser)
    @objc optional func room(didFinishSync room:QRoom)
    @objc optional func room(gotNewGroupComment onIndex:Int)
    @objc optional func room(gotNewComment comment:QComment)
    
    @objc optional func room(didFinishLoadMore inRoom:QRoom, success:Bool, gotNewComment:Bool)
    @objc optional func room(didChangeUnread inRoom:QRoom)
    @objc optional func room(didClearMessages cleared:Bool)
}


/// Room of conversation (Realm object)
public class QRoom:Object {
    @objc public dynamic var id:String = ""
    @objc public dynamic var uniqueId:String = ""
    @objc internal dynamic var storedName:String = ""
    @objc internal dynamic var definedname:String = ""
    @objc public dynamic var storedAvatarURL:String = ""
    @objc public dynamic var definedAvatarURL:String = ""
    @objc internal dynamic var avatarData:Data?
    @objc public dynamic var isPublicChannel: Bool = false
    @objc public dynamic var roomTotalParticipant: Int = 0
    @objc public dynamic var data:String = ""
    @objc public dynamic var distinctId:String = ""
    @objc public dynamic var typeRaw:Int = QRoomType.single.rawValue
    @objc public dynamic var singleUser:String = ""
    @objc public dynamic var typingUser:String = ""
    @objc public dynamic var lastReadCommentId: Int = 0
    @objc public dynamic var lastDeliveredCommentId: Int = 0
    @objc public dynamic var isLocked:Bool = false
    
    @objc internal dynamic var unreadCommentCount:Int = 0
    @objc public dynamic var unreadCount:Int = 0
    @objc internal dynamic var pinned:Double = 0
    
    // MARK: - lastComment variable
    @objc internal dynamic var lastCommentId:Int = 0
    @objc internal dynamic var lastCommentText:String = ""
    @objc internal dynamic var lastCommentUniqueId: String = ""
    @objc internal dynamic var lastCommentBeforeId:Int = 0
    @objc internal dynamic var lastCommentCreatedAt: Double = 0
    @objc internal dynamic var lastCommentSenderEmail:String = ""
    @objc internal dynamic var lastCommentSenderName:String = ""
    @objc internal dynamic var lastCommentStatusRaw:Int = QCommentStatus.sending.rawValue
    @objc internal dynamic var lastCommentTypeRaw:String = QCommentType.text.name()
    @objc internal dynamic var lastCommentData:String = ""
    @objc internal dynamic var lastCommentRawExtras:String = ""
        
    // MARK: private method
    @objc internal dynamic var lastParticipantsReadId:Int = 0
    @objc internal dynamic var lastParticipantsDeliveredId:Int = 0
    @objc internal dynamic var roomVersion017:Bool = true
    
    internal let rawComments = List<QComment>()
    internal let service = QRoomService()
    
    public var comments:[QComment]{
        get{
            var comments = [QComment]()
            if self.rawComments.count > 0 {
                comments = Array(self.rawComments.sorted(byKeyPath: "createdAt", ascending: true))
            }
            return comments
        }
    }
    public func comments(withFilter query:NSPredicate?)->[QComment]{
        var comments = [QComment]()
        var results = self.rawComments.sorted(byKeyPath: "createdAt", ascending: true)

        if query != nil {
            results = results.filter(query!)
        }
        
        if results.count > 0 {
            comments = Array(results)
        }
        return comments
    }
    
    public let participants = List<QParticipant>()
    
    public var delegate:QRoomDelegate? {
        didSet {
            if Thread.isMainThread && !self.isInvalidated {
                Qiscus.chatRooms[id] = self
            }
        }
    }
    internal var typingTimer:Timer?
    internal var selfTypingTimer:Timer?
    
    
    override public static func primaryKey() -> String? {
        return "id"
    }
    // MARK: - Unstored properties
    override public static func ignoredProperties() -> [String] {
        return ["typingTimer","delegate","selfTypingTimer"]
    }
    
    public func newContactComment(name:String, value:String)->QComment{
        let comment = QComment()
        let payload = "{ \"name\": \"\(name)\", \"value\": \"\(value)\"}"
        let time = Double(Date().timeIntervalSince1970)
        let timeToken = UInt64(time * 10000)
        let uniqueID = "ios-\(timeToken)"
        
        comment.uniqueId = uniqueID
        comment.id = 0
        comment.roomId = self.id
        comment.text = "\(name) - \(value)"
        comment.createdAt = Double(Date().timeIntervalSince1970)
        comment.senderEmail = Qiscus.client.email
        comment.senderName = Qiscus.client.userName
        comment.statusRaw = QCommentStatus.sending.rawValue
        comment.typeRaw = "contact_person"
        comment.data = payload
        comment.roomAvatar = self.avatarURL
        comment.roomName = self.name
        comment.roomTypeRaw = self.typeRaw
        comment.isRead = true
        
        self.addComment(newComment: comment)
        return comment
    }
    public func newLocationComment(latitude:Double, longitude:Double, title:String?=nil, address:String?=nil)->QComment{
        let comment = QComment()
        var locTitle = title
        var locAddress = ""
        if address != nil {
            locAddress = address!
        }
        if title == nil {
            var newLat = latitude
            var newLong = longitude
            var latString = "N"
            var longString = "E"
            if latitude < 0 {
                latString = "S"
                newLat = 0 - latitude
            }
            if longitude < 0 {
                longString = "W"
                newLong = 0 - longitude
            }
            let intLat = Int(newLat)
            let intLong = Int(newLong)
            let subLat = Int((newLat - Double(intLat)) * 100)
            let subLong = Int((newLong - Double(intLong)) * 100)
            let subSubLat = Int((newLat - Double(intLat) - Double(Double(subLat)/100)) * 10000)
            let subSubLong = Int((newLong - Double(intLong) - Double(Double(subLong)/100)) * 10000)
            let pLat = Int((newLat - Double(intLat) - Double(Double(subLat)/100) - Double(Double(subSubLat)/10000)) * 100000)
            let pLong = Int((newLong - Double(intLong) - Double(Double(subLong)/100) - Double(Double(subSubLong)/10000)) * 100000)
            
            locTitle = "\(intLat)º\(subLat)\'\(subSubLat).\(pLat)\"\(latString) \(intLong)º\(subLong)\'\(subSubLong).\(pLong)\"\(longString)"
        }
        let url = "http://maps.google.com/maps?daddr=\(latitude),\(longitude)"
        
        let payload = "{ \"name\": \"\(locTitle!)\", \"address\": \"\(locAddress)\", \"latitude\": \(latitude), \"longitude\": \(longitude), \"map_url\": \"\(url)\"}"
        
        let time = Double(Date().timeIntervalSince1970)
        let timeToken = UInt64(time * 10000)
        let uniqueID = "ios-\(timeToken)"
        
        comment.uniqueId = uniqueID
        comment.id = 0
        comment.roomId = self.id
        comment.text = ""
        comment.createdAt = Double(Date().timeIntervalSince1970)
        comment.senderEmail = Qiscus.client.email
        comment.senderName = Qiscus.client.userName
        comment.statusRaw = QCommentStatus.sending.rawValue
        comment.typeRaw = "location"
        comment.data = payload
        comment.roomAvatar = self.avatarURL
        comment.roomName = self.name
        comment.roomTypeRaw = self.typeRaw
        comment.isRead = true
        self.addComment(newComment: comment)
        return comment
    }
    public func newCustomComment(type:String, payload:String, text:String? = nil )->QComment{
        let comment = QComment()
        let payloadData = JSON(parseJSON: payload)
        var contentString = "\"\""
        if payloadData == JSON.null{
            contentString = "\"\(payload)\""
        }else{
            contentString = "\(payloadData)"
        }
        let payload = "{ \"type\": \"\(type)\", \"content\": \(contentString)}"
        let time = Double(Date().timeIntervalSince1970)
        let timeToken = UInt64(time * 10000)
        let uniqueID = "ios-\(timeToken)"
        if text == nil {
            comment.text = "message type \(type)"
        }else{
            comment.text = text!
        }
        
        comment.uniqueId = uniqueID
        comment.id = 0
        comment.roomId = self.id
        
        comment.createdAt = Double(Date().timeIntervalSince1970)
        comment.senderEmail = Qiscus.client.email
        comment.senderName = Qiscus.client.userName
        comment.statusRaw = QCommentStatus.sending.rawValue
        comment.typeRaw = type
        comment.data = payload
        comment.roomAvatar = self.avatarURL
        comment.roomName = self.name
        comment.roomTypeRaw = self.typeRaw
        comment.isRead = true
        self.addComment(newComment: comment)
        return comment
    }
    
    public func prepareImageComment(filename: String = "", caption: String = "", data: Data? = nil, thumbImage: UIImage? = nil) -> QComment {

            let realm = try! Realm(configuration: Qiscus.dbConfiguration)
            realm.refresh()
            let comment = QComment()
            let time = Double(Date().timeIntervalSince1970)
            let timeToken = UInt64(time * 10000)
            let uniqueID = "ios-\(timeToken)"
            let fileNameArr = filename.split(separator: ".")
            let fileExt = String(fileNameArr.last!).lowercased()
            
            var fileName = filename.lowercased()
            if fileName == "asset.jpg" || fileName == "asset.png" {
                fileName = "\(uniqueID).\(fileExt)"
            }
            fileName = fileName.replacingOccurrences(of: "%", with: "")
            
            var payloadData:[AnyHashable : Any] = [
                "url" : fileName,
                "caption" : caption
            ]
            
            comment.uniqueId = uniqueID
            comment.id = 0
            comment.roomId = self.id
            
            comment.text = "[file]\(fileName) [/file]"
            comment.createdAt = Double(Date().timeIntervalSince1970)
            comment.senderEmail = Qiscus.client.email
            comment.senderName = Qiscus.client.userName
            comment.statusRaw = QCommentStatus.sending.rawValue
            comment.isUploading = true
            comment.progress = 0
            comment.roomAvatar = self.avatarURL
            comment.roomName = self.name
            comment.roomTypeRaw = self.typeRaw
            comment.isRead = true
            
            let file = QFile()
            file.id = uniqueID
            file.roomId = self.id
            file.url = fileName
            file.senderEmail = Qiscus.client.email
            file.filename = fileName
            
            if let fileData = data {
                let size = fileData.count
                file.size = Double(size)
                file.localPath = QFile.saveFile(data!, fileName: fileName)
                
                payloadData = [
                    "url" : fileName,
                    "caption" : caption,
                    "size" : file.size,
                    "pages" : 0,
                    "file_name": fileName
                ]
            }
            
            if let mime = QiscusFileHelper.mimeTypes["\(fileExt)"] {
                file.mimeType = mime
            }
            
            let image = UIImage(data: data!)
            let gif = (fileExt == "gif" || fileExt == "gif_")
            let jpeg = (fileExt == "jpg" || fileExt == "jpg_" || fileExt == "heic")
            let png = (fileExt == "png" || fileExt == "png_")
            
            var thumb = UIImage()
            var thumbData:Data?
            if !gif {
                thumb = QFile.createThumbImage(image!)
                if jpeg {
                    thumbData = UIImageJPEGRepresentation(thumb, 1)
                    file.localThumbPath = QFile.saveFile(thumbData!, fileName: "thumb-\(fileName)")
                }else if png {
                    thumbData = UIImagePNGRepresentation(thumb)
                    file.localThumbPath = QFile.saveFile(thumbData!, fileName: "thumb-\(fileName)")
                }
            }else{
                file.localThumbPath = QFile.saveFile(data!, fileName: "thumb-\(fileName)")
            }
            
            comment.typeRaw = QCommentType.image.name()
            let payloadJSON = JSON(payloadData)
            comment.data = "\(payloadJSON)"
            try! realm.write {
                realm.add(file, update:true)
            }
            
            return comment
    }
    
    public func newFileComment(type:QiscusFileType, filename:String = "", caption:String = "", data:Data? = nil, thumbImage:UIImage? = nil)->QComment{
        let realm = try! Realm(configuration: Qiscus.dbConfiguration)
        realm.refresh()
        let comment = QComment()
        let time = Double(Date().timeIntervalSince1970)
        let timeToken = UInt64(time * 10000)
        let uniqueID = "ios-\(timeToken)"
        let fileNameArr = filename.split(separator: ".")
        let fileExt = String(fileNameArr.last!).lowercased()
        
        var fileName = filename.lowercased()
        if fileName == "asset.jpg" || fileName == "asset.png" {
            fileName = "\(uniqueID).\(fileExt)"
        }
        fileName = fileName.replacingOccurrences(of: "%", with: "")

        var payloadData:[AnyHashable : Any] = [
            "url" : fileName,
            "caption" : caption
        ]
        
        comment.uniqueId = uniqueID
        comment.id = 0
        comment.roomId = self.id
        
        comment.text = "[file]\(fileName) [/file]"
        comment.createdAt = Double(Date().timeIntervalSince1970)
        comment.senderEmail = Qiscus.client.email
        comment.senderName = Qiscus.client.userName
        comment.statusRaw = QCommentStatus.sending.rawValue
        comment.isUploading = true
        comment.progress = 0
        comment.roomAvatar = self.avatarURL
        comment.roomName = self.name
        comment.roomTypeRaw = self.typeRaw
        comment.isRead = true
        
        let file = QFile()
        file.id = uniqueID
        file.roomId = self.id
        file.url = fileName
        file.senderEmail = Qiscus.client.email
        file.filename = fileName
        
        if let fileData = data {
            let size = fileData.count
            file.size = Double(size)
            file.localPath = QFile.saveFile(data!, fileName: fileName)

            payloadData = [
                "url" : fileName,
                "caption" : caption,
                "size" : file.size,
                "pages" : 0,
                "file_name": fileName
            ]
        }
        
        if let mime = QiscusFileHelper.mimeTypes["\(fileExt)"] {
            file.mimeType = mime
        }
        
        switch type {
        case .audio:
            comment.typeRaw = QCommentType.audio.name()
            break
        case .image:
            let image = UIImage(data: data!)
            let gif = (fileExt == "gif" || fileExt == "gif_")
            let jpeg = (fileExt == "jpg" || fileExt == "jpg_")
            let png = (fileExt == "png" || fileExt == "png_")
            
            var thumb = UIImage()
            var thumbData:Data?
            if !gif {
                thumb = QFile.createThumbImage(image!)
                if jpeg {
                    thumbData = UIImageJPEGRepresentation(thumb, 1)
                    file.localThumbPath = QFile.saveFile(thumbData!, fileName: "thumb-\(fileName)")
                }else if png {
                    thumbData = UIImagePNGRepresentation(thumb)
                    file.localThumbPath = QFile.saveFile(thumbData!, fileName: "thumb-\(fileName)")
                }
            }else{
                file.localThumbPath = QFile.saveFile(data!, fileName: "thumb-\(fileName)")
            }
            
            comment.typeRaw = QCommentType.image.name()
            break
        case .document:
            if let provider = CGDataProvider(data: data! as NSData) {
                if let pdfDoc = CGPDFDocument(provider) {
                    file.pages = pdfDoc.numberOfPages
                    
                    if let pdfImage = thumbImage {
                        let imageSize = pdfImage.size
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
                        
                        if let thumbData = UIImageJPEGRepresentation(pdfImage, compressVal) {
                            file.localThumbPath = QFile.saveFile(thumbData, fileName: "thumb-\(fileName).jpg")
                        }
                    }
                }
            }
            comment.typeRaw = QCommentType.document.name()
            break
        case .video:
            var fileNameOnly = String(fileNameArr.first!).lowercased()
            var i = 0
            for namePart in fileNameArr{
                if i > 0 && i < (fileNameArr.count - 1){
                    fileNameOnly += ".\(String(namePart).lowercased())"
                }
                i += 1
            }
            let thumbData = UIImagePNGRepresentation(thumbImage!)
            file.localThumbPath = QFile.saveFile(thumbData!, fileName: "thumb-\(fileNameOnly).png")
            comment.typeRaw = QCommentType.video.name()
            break
        default:
            comment.typeRaw = QCommentType.file.name()
            break
        }
        let payloadJSON = JSON(payloadData)
        comment.data = "\(payloadJSON)"
        try! realm.write {
            realm.add(file, update:true)
        }
        self.addComment(newComment: comment)
        realm.refresh()
        return comment
    }
    
    public func newComment(text:String, payload:JSON? = nil,type:QCommentType = .text, data:Data? = nil, image:UIImage? = nil, filename:String = "", filePath:URL? = nil )->QComment{
        let comment = QComment()
        let time = Double(Date().timeIntervalSince1970)
        let timeToken = UInt64(time * 10000)
        let uniqueID = "ios-\(timeToken)"
        
        comment.uniqueId = uniqueID
        comment.id = 0
        comment.roomId = self.id
        comment.text = text
        comment.createdAt = Double(Date().timeIntervalSince1970)
        comment.senderEmail = Qiscus.client.email
        comment.senderName = Qiscus.client.userName
        comment.statusRaw = QCommentStatus.sending.rawValue
        comment.typeRaw = type.name()
        comment.roomName = self.name
        comment.roomTypeRaw = self.typeRaw
        comment.roomAvatar = self.avatarURL
        comment.isRead = true
        
        if let data = payload {
            comment.data = "\(data)"
        }
        
        self.addComment(newComment: comment)
        return comment
    }
    public func postTextMessage(text:String){
        let comment = QComment()
        let time = Double(Date().timeIntervalSince1970)
        let timeToken = UInt64(time * 10000)
        let uniqueID = "ios-\(timeToken)"
        
        comment.uniqueId = uniqueID
        comment.id = 0
        comment.roomId = self.id
        comment.text = text
        comment.createdAt = Double(Date().timeIntervalSince1970)
        comment.senderEmail = Qiscus.client.email
        comment.senderName = Qiscus.client.userName
        comment.statusRaw = QCommentStatus.sending.rawValue
        comment.typeRaw = QCommentType.text.name()
        
        self.addComment(newComment: comment)
        self.post(comment: comment)
    }
    internal func resendPendingMessage(){
        QiscusDBThread.async {
            let realm = try! Realm(configuration: Qiscus.dbConfiguration)
            realm.refresh()
            var data = realm.objects(QComment.self).filter("statusRaw == 1")
            
            if let comment = data.first {
                if Thread.isMainThread {
                    if let room = QRoom.room(withId: comment.roomId){
                        room.updateCommentStatus(inComment: comment, status: .sending)
                        room.post(comment: comment) {
                            self.resendPendingMessage()
                        }
                    }
                }else{
                    let commentTS = ThreadSafeReference(to: comment)
                    DispatchQueue.main.sync {
                        let realm = try! Realm(configuration: Qiscus.dbConfiguration)
                        realm.refresh()
                        guard let c = realm.resolve(commentTS) else { return }
                        if let room = QRoom.room(withId: c.roomId){
                            room.updateCommentStatus(inComment: c, status: .sending)
                            room.post(comment: c) {
                                self.resendPendingMessage()
                            }
                        }
                    }
                }
            }
        }
    }
    
    internal func redeletePendingDeletedMessage() {
        let pendingDeletedMessages = self.rawComments.filter("statusRaw == %d", QCommentStatus.deletePending.rawValue)
        if pendingDeletedMessages.count > 0 {
            for pendingDeletedMessage in pendingDeletedMessages {
                pendingDeletedMessage.delete(forMeOnly: false, hardDelete: true, onSuccess: {
                    if !pendingDeletedMessage.isInvalidated {
                        self.deleteComment(comment: pendingDeletedMessage)
                    }
                }, onError: { (code) in
                    
                })
            }
        }
    }
    
    public func post(comment:QComment, type:String? = nil, payload:JSON? = nil, onSuccess: @escaping ()->Void = {}){
        let service = QRoomService()
        let id = self.id
//        self.resendPendingMessage()
        self.redeletePendingDeletedMessage()
        service.postComment(onRoom: id, comment: comment, type: type, payload:payload, onSuccess: onSuccess)
    }
    
    public func upload(comment:QComment, onSuccess:  @escaping (QRoom, QComment)->Void, onError:  @escaping (QRoom,QComment,String)->Void, onProgress:((Double)->Void)? = nil){
        self.updateCommentStatus(inComment: comment, status: .sending)
        let service = QRoomService()
        service.uploadCommentFile(inRoom: self, comment: comment, onSuccess: onSuccess, onError: onError, onProgress: onProgress)
    }
    
    public func downloadMedia(onComment comment:QComment, thumbImageRef: UIImage? = nil, isAudioFile: Bool = false, onSuccess: ((QComment)->Void)? = nil, onError:((String)->Void)? = nil, onProgress:((Double)->Void)? = nil){
        let service = QRoomService()
        service.downloadMedia(inRoom: self, comment: comment, thumbImageRef: thumbImageRef, isAudioFile: isAudioFile, onSuccess: onSuccess, onError: onError, onProgress: onProgress)
    }
//    public func getIndexPath(ofComment comment:QComment)->IndexPath?{
//        var section = self.comments.count - 1
//        var indexPath:IndexPath? = nil
//        var found = false
//        for commentGroup in self.comments.reversed() {
//            if commentGroup.date == comment.date && commentGroup.senderEmail == comment.senderEmail{
//                var row = 0
//                for commentTarget in commentGroup.comments {
//                    if commentTarget.uniqueId == comment.uniqueId{
//                        indexPath = IndexPath(item: row, section: section)
//                        found = true
//                        break
//                    }
//                    row += 1
//                }
//            }
//            if found {
//                break
//            }else{
//                section -= 1
//            }
//        }
//        return indexPath
//    }
    public func updateUserTyping(userEmail: String){
        if !self.isInvalidated {
            let realm = try! Realm(configuration: Qiscus.dbConfiguration)
            realm.refresh()
            if userEmail != self.typingUser {
                try! realm.write {
                    self.typingUser = userEmail
                }
                if userEmail != "" {
                    if self.typingTimer != nil {
                        self.typingTimer!.invalidate()
                    }
                    self.typingTimer = Timer.scheduledTimer(timeInterval: 3.0, target: self, selector: #selector(self.clearUserTyping), userInfo: nil, repeats: false)
                }
            }
        }
    }
    @objc public func clearUserTyping(){
        if !self.isInvalidated {
            self.updateUserTyping(userEmail: "")
        }
    }
    public func deleteComment(comment:QComment){
        let realm = try! Realm(configuration: Qiscus.dbConfiguration)
        realm.refresh()
        let id = self.id
        let cUid = comment.uniqueId
        func publishNotification(roomId:String){
            if let mainRoom = QRoom.room(withId: id){
                if let roomDelegate = mainRoom.delegate {
                    roomDelegate.room?(didDeleteComment: mainRoom)
                }
                QiscusNotification.publish(commentDeleteOnRoom: mainRoom)
            }
        }
        QiscusDBThread.sync {
            let realm = try! Realm(configuration: Qiscus.dbConfiguration)
            realm.refresh()
            if let r = QRoom.threadSaveRoom(withId: id){
                var i = r.rawComments.count - 1
                for c in r.rawComments.reversed() {
                    if c.uniqueId == cUid {
                        try! realm.write {
                            r.rawComments.remove(at: i)
                            realm.delete(c)
                        }
                        if cUid == r.lastCommentUniqueId {
                            r.recalculateLastComment()
                        }
                        if Thread.isMainThread {
                            publishNotification(roomId: id)
                        }else{
                            DispatchQueue.main.sync { autoreleasepool {
                                publishNotification(roomId: id)
                            }}
                        }
                        break
                    }
                    i -= 1
                }
            }
        }
    }
    public func participant(withEmail email:String)->QParticipant?{
        let savedParticipant = self.participants.filter("email == '\(email)'")
        if savedParticipant.count > 0{
            return savedParticipant.first!
        }else{
            return nil
        }
    }
    public func updateLastReadId(commentId:Int){
        let realm = try! Realm(configuration: Qiscus.dbConfiguration)
        realm.refresh()
        if self.lastReadCommentId < commentId {
            try! realm.write {
                self.lastReadCommentId = commentId
            }
            if self.lastDeliveredCommentId < commentId {
                try! realm.write {
                    self.lastDeliveredCommentId = commentId
                }
            }
//            self.updateUnreadCommentCount()
        }
    }
    internal func updateUnreadCommentCount(count:Int){
        let id = self.id
        QiscusDBThread.async {
            if let room = QRoom.threadSaveRoom(withId: id){
                if room.unreadCount != count {
                    let realm = try! Realm(configuration: Qiscus.dbConfiguration)
                    realm.refresh()
                    try! realm.write {
                        room.unreadCount = count
                    }
                    DispatchQueue.main.async {
                        if let cache = QRoom.room(withId: id){
                            QiscusNotification.publish(roomChange: cache, onProperty: .unreadCount)
                            cache.delegate?.room?(didChangeUnread: cache)
                        }
                    }
                }
            }
        }
    }
    
    internal func updateTotalParticipant(count:Int){
        let id = self.id
        QiscusDBThread.async {
            if let room = QRoom.threadSaveRoom(withId: id){
                if room.roomTotalParticipant != count {
                    let realm = try! Realm(configuration: Qiscus.dbConfiguration)
                    realm.refresh()
                    try! realm.write {
                        room.roomTotalParticipant = count
                    }
                }
            }
        }
    }
    
    public func readAll(){
        let id = self.id
        QiscusDBThread.async {
            let realm = try! Realm(configuration: Qiscus.dbConfiguration)
            realm.refresh()
            let unreadData =  realm.objects(QComment.self).filter("roomId == '\(id)' AND isRead ==  false").sorted(byKeyPath: "createdAt", ascending: true)
            
            if let last = unreadData.last {
                last.read()
            }
        }
    }
    public func updateUnreadCommentCount(){
        let id = self.id
        QiscusDBThread.async {
            if let room = QRoom.threadSaveRoom(withId: id){
                if room.rawComments.count > 0 {
                    let unreadComment = room.rawComments.filter("isRead == false")
                    let unread = unreadComment.count
                        
                    if room.unreadCount != unread {
                        room.updateUnreadCommentCount(count: unread)
                    }
                }
            }
        }
    }
    internal func updateCommentStatus(){
        if self.participants.count > 0 {
            var minDeliveredId = 0
            var minReadId = 0
            var first = true
            for participant in self.participants {
                if first && participant.email != Qiscus.client.email{
                    minDeliveredId = participant.lastDeliveredCommentId
                    minReadId = participant.lastReadCommentId
                    first = false
                }else if participant.email != Qiscus.client.email{
                    if participant.lastDeliveredCommentId < minDeliveredId {
                        minDeliveredId = participant.lastDeliveredCommentId
                    }
                    if participant.lastReadCommentId < minReadId {
                        minReadId = participant.lastReadCommentId
                    }
                }
            }
            if self.lastParticipantsReadId < minReadId {
                updateLastParticipantsReadId(readId: minReadId)
            }
            if self.lastParticipantsDeliveredId < minDeliveredId {
                updateLastParticipantsDeliveredId(deliveredId: minDeliveredId)
            }
        }
    }
    internal func updateLastParticipantsReadId(readId:Int){
        let roomId = self.id
        QiscusBackgroundThread.async {
            if let room = QRoom.threadSaveRoom(withId: roomId){
                if readId > room.lastParticipantsReadId {
                    for comment in room.rawComments{
                        if (comment.statusRaw < QCommentStatus.read.rawValue && comment.status != .failed && comment.status != .sending && comment.status != .pending && comment.id < readId) || comment.id == readId{
                            comment.updateStatus(status: .read)
                        }
                    }
                    let realm = try! Realm(configuration: Qiscus.dbConfiguration)
                    realm.refresh()
                    try! realm.write {
                        room.lastParticipantsReadId = readId
                        room.lastParticipantsDeliveredId = readId
                    }
                }
            }
        }
    }
    internal func updateLastParticipantsDeliveredId(deliveredId:Int){
        let roomId = self.id
        QiscusDBThread.async {
            if let room = QRoom.threadSaveRoom(withId: roomId){
                if deliveredId > room.lastParticipantsDeliveredId {                    
                    for comment in room.rawComments{
                        if (comment.statusRaw < QCommentStatus.delivered.rawValue && comment.status != .failed && comment.status != .sending && comment.id < deliveredId) || (comment.id == deliveredId && comment.status != .read){
                            if !comment.isInvalidated {
                                comment.updateStatus(status: .delivered)
                            }
                        }
                    }
                    
                    let realm = try! Realm(configuration: Qiscus.dbConfiguration)
                    realm.refresh()
                    try! realm.write {
                        room.lastParticipantsDeliveredId = deliveredId
                    }
                }
            }
        }
    }
    public class func publishStatus(roomId:String, commentId:Int, status:QCommentStatus){
        if let room = QRoom.room(withId: roomId) {
            if !room.isPublicChannel {
                QiscusBackgroundThread.async {
                    let service = QRoomService()
                    service.publishStatus(inRoom: roomId, commentId: commentId, commentStatus: status)
                }
            }
        } else {
            QiscusBackgroundThread.async {
                let service = QRoomService()
                service.publishStatus(inRoom: roomId, commentId: commentId, commentStatus: status)
            }
        }
    }
    
    internal func update(name:String){
        let id = self.id
        if self.storedName != name {
            let realm = try! Realm(configuration: Qiscus.dbConfiguration)
            realm.refresh()
            try! realm.write {
                self.storedName = name
            }
            DispatchQueue.main.async {
                if let room = QRoom.room(withId: id){
                    if room.definedname == "" {
                        QiscusNotification.publish(roomChange: room, onProperty: .name)
                        room.delegate?.room?(didChangeName: room)
                    }
                }
            }
        }
    }
    internal func update(avatarURL:String){
        if self.storedAvatarURL != avatarURL {
            let id = self.id
            QiscusDBThread.async {
                if let room = QRoom.threadSaveRoom(withId: id){
                    let realm = try! Realm(configuration: Qiscus.dbConfiguration)
                    realm.refresh()
                    try! realm.write {
                        room.storedAvatarURL = avatarURL
                    }
                    if room.definedAvatarURL == "" {
                        try! realm.write {
                            room.avatarData = nil
                        }
                        DispatchQueue.main.async { autoreleasepool {
                            if let cache = QRoom.room(withId: id){
                                QiscusNotification.publish(roomChange: cache, onProperty: .avatar)
                                cache.delegate?.room?(didChangeAvatar: cache)
                            }
                        }}
                    }
                }
            }
        }
    }
    internal func update(data:String){
        let roomTS = ThreadSafeReference(to: self)
        QiscusDBThread.sync { autoreleasepool {
            let realm = try! Realm(configuration: Qiscus.dbConfiguration)
            realm.refresh()
            guard let r = realm.resolve(roomTS) else { return }
            if r.data != data {
                try! realm.write {
                    r.data = data
                }
            }
        }}
    }
    public func setAvatar(url:String){
        if self.definedAvatarURL != url {
            let id = self.id
            QiscusDBThread.async {
                if let room = QRoom.threadSaveRoom(withId: id){
                    let realm = try! Realm(configuration: Qiscus.dbConfiguration)
                    realm.refresh()
                    try! realm.write {
                        room.definedAvatarURL = url
                        room.avatarData = nil
                    }
                    DispatchQueue.main.async {
                        if let cache = QRoom.room(withId: id) {
                            QiscusNotification.publish(roomChange: cache, onProperty: .avatar)
                            cache.delegate?.room?(didChangeName: cache)
                        }
                    }
                }
            }
        }
    }
    public func setName(name:String){
        if name != self.definedname {
            let id = self.id
            QiscusDBThread.async {
                if let room = QRoom.threadSaveRoom(withId: id) {
                    let realm = try! Realm(configuration: Qiscus.dbConfiguration)
                    realm.refresh()
                    try! realm.write {
                        room.definedname = name
                    }
                    if room.type == .single {
                        for participant in room.participants {
                            if participant.email != Qiscus.client.email {
                                if let user = QUser.getUser(email: participant.email) {
                                    user.setName(name: name)
                                }
                            }
                        }
                    }
                    DispatchQueue.main.async {
                        if let cache = QRoom.room(withId: id) {
                            QiscusNotification.publish(roomChange: cache, onProperty: .name)
                            cache.delegate?.room?(didChangeName: cache)
                        }
                    }
                }
            }
        }
    }

    internal func cache(){
        let roomTS = ThreadSafeReference(to:self)
        if Thread.isMainThread {
            if Qiscus.chatRooms[self.id] == nil {
                Qiscus.chatRooms[self.id] = self
            }
        }else{
            DispatchQueue.main.sync {
                let realm = try! Realm(configuration: Qiscus.dbConfiguration)
                realm.refresh()
                guard let room = realm.resolve(roomTS) else { return }
                if Qiscus.chatRooms[room.id] == nil {
                    Qiscus.chatRooms[room.id] = room
                }
            }
        }
    }
    
    internal func loadRoomData(limit:Int = 20, offset:String?, onSuccess:@escaping (QRoom)->Void, onError:@escaping (String)->Void){
        QRoomService.loadData(inRoom: self, limit: limit, offset: offset, onSuccess: onSuccess, onError: onError)
    }
    public func loadComments(limit:Int, offset:String, onSuccess:@escaping ([QComment])->Void, onError:@escaping (String)->Void){
        if let commentId = Int(offset) {
            if commentId == 0 {
                onError("invalid offset")
                return
            }
            let realm = try! Realm(configuration: Qiscus.dbConfiguration)
            realm.refresh()
            let data =  realm.objects(QComment.self).filter("roomId == '\(self.id)' AND id > \(commentId)").sorted(byKeyPath: "createdAt", ascending: true)
            if data.count >= limit {
                var comments = [QComment]()
                var i = 0
                for comment in data {
                    if i < limit {
                        comments.append(comment)
                    }else{
                        break
                    }
                    i += 1
                }
                onSuccess(comments)
            }else{
                QRoomService.loadComments(inRoom: self, limit: limit, offset: offset, onSuccess: onSuccess, onError: onError)
            }
        }else{
            onError("invalid offset")
        }
    }
    public func loadComments(onSuccess:@escaping ([QComment])->Void, onError:@escaping (String)->Void){
        QRoomService.loadComments(inRoom: self, onSuccess: onSuccess, onError: onError)
    }
    public func loadMore(limit:Int, offset:String, onSuccess:@escaping ([QComment],Bool)->Void, onError:@escaping (String)->Void){
        if let commentId = Int(offset) {
            if commentId == 0 {
                onError("invalid offset")
                return
            }
            let realm = try! Realm(configuration: Qiscus.dbConfiguration)
            realm.refresh()
            let data =  realm.objects(QComment.self).filter("roomId == '\(self.id)' AND id < \(commentId)").sorted(byKeyPath: "createdAt", ascending: true)
            if data.count >= limit {
                var comments = [QComment]()
                var i = 0
                for comment in data {
                    if i < limit {
                        comments.append(comment)
                    }else{
                        break
                    }
                    i += 1
                }
                let first = comments.first!
                let hasMoreMessages = first.id == 0 ? false : true
                onSuccess(comments, hasMoreMessages)
            }else{
                // CALL API Here
                QRoomService.loadMore(inRoom: self, limit: limit, offset: offset, onSuccess: onSuccess, onError: onError)
            }
        }else{
            onError("invalid offset")
        }
    }
    internal func downloadRoomAvatar(){
        let id = self.id
        let url = self.avatarURL.replacingOccurrences(of: "/upload/", with: "/upload/c_thumb,g_center,h_100,w_100/")
        if !QChatService.downloadTasks.contains(url){
            QChatService.downloadImage(url: url, onSuccess: { (data) in
                QiscusDBThread.async {
                    if let room = QRoom.threadSaveRoom(withId: id){
                        let realm = try! Realm(configuration: Qiscus.dbConfiguration)
                        realm.refresh()
                        try! realm.write {
                            room.avatarData = data
                        }
                        DispatchQueue.main.async { autoreleasepool {
                            if let cache = QRoom.room(withId: id){
                                QiscusNotification.publish(roomChange: cache, onProperty: .avatar)
                                cache.delegate?.room?(didChangeAvatar: cache)
                            }
                        }}
                    }
                }
            }, onFailed: { (error) in
                Qiscus.printLog(text: error)
            })
        }
    }
    internal func loadRoomAvatar(onSuccess:  @escaping (UIImage)->Void, onError:  @escaping (String)->Void){
        let id = self.id
        QiscusDBThread.async {
            if let room = QRoom.threadSaveRoom(withId: id){
                if let imageData = room.avatarData {
                    if let image = UIImage(data: imageData){
                        DispatchQueue.main.async {
                            onSuccess(image)
                        }
                    }else{
                        DispatchQueue.main.async {
                            onError("cant't render data to image")
                        }
                    }
                }else{
                    DispatchQueue.main.async {
                        onError("image not found")
                    }
                }
            }else{
                DispatchQueue.main.async {
                    onError("room not found")
                }
            }
        }
    }
    public func clearMessages(onSuccess:@escaping ()->Void, onError:@escaping (Int)->Void){
        let uid = self.uniqueId
        QRoomService.clearMessages(inRoomsChannel: [uid], onSuccess: { (_, _) in
            onSuccess()
        }) { (statusCode) in
            onError(statusCode)
        }
    }
    
    internal func clearRemain30() {
        if self.rawComments.count > 30 {
            let id = self.id
            let realm = try! Realm(configuration: Qiscus.dbConfiguration)
            
            let tempRawComment = List<QComment>()
            let commentToDelete = List<QComment>()
            
            var iteration = 0
            
            for rawComment in self.rawComments.sorted(by: { (q1, q2) -> Bool in
                return q1.createdAt < q2.createdAt
                }).reversed() {
                if iteration < 30 {
                    tempRawComment.insert(rawComment, at: 0)
                } else {
                    QComment.cache.removeValue(forKey: rawComment.uniqueId)
                    commentToDelete.insert(rawComment, at: 0)
                }
                
                iteration += 1
            }
            
            try! realm.write {
                realm.delete(commentToDelete)
                self.rawComments.removeAll()
                tempRawComment.last?.beforeId = 0
                realm.add(tempRawComment, update: true)
                self.rawComments.append(objectsIn: tempRawComment)
            }
        }
    }
    
    internal func clearMessage(){
        let id = self.id
        let realm = try! Realm(configuration: Qiscus.dbConfiguration)
        realm.refresh()
        
        try! realm.write {
            self.rawComments.removeAll()
        }
        DispatchQueue.main.async {
            if let room = QRoom.room(withId: id){
                room.delegate?.room?(didClearMessages: true)
                QiscusNotification.publish(roomCleared: room)
            }
        }
    }
    internal class func removeAllMessage(){
        let realm = try! Realm(configuration: Qiscus.dbConfiguration)
        realm.refresh()
        for room in QRoom.all() {
            room.clearMessage()
        }
        let comments = realm.objects(QComment.self)
        try! realm.write {
            realm.delete(comments)
        }
        QComment.cache = [String : QComment]()
    }
}

