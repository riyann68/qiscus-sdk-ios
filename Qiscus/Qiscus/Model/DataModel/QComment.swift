//
//  QComment.swift
//  Example
//
//  Created by Ahmad Athaullah on 7/5/17.
//  Copyright © 2017 Ahmad Athaullah. All rights reserved.
//

import Foundation
import RealmSwift
import SwiftyJSON

public enum QReplyType:Int{
    case text
    case image
    case video
    case audio
    case document
    case location
    case contact
    case file
    case other
}
@objc public enum QCellPosition:Int {
    case single,first,middle,last
}
@objc public enum QCommentType:Int {
    case text
    case image
    case video
    case audio
    case file
    case postback
    case account
    case reply
    case system
    case card
    case contact
    case location
    case custom
    case document
    
    static let all = [text.name(), image.name(), video.name(), audio.name(),file.name(),postback.name(),account.name(), reply.name(), system.name(), card.name(), contact.name(), location.name(), custom.name()]
    
    func name() -> String{
        switch self {
            case .text      : return "text"
            case .image     : return "image"
            case .video     : return "video"
            case .audio     : return "audio"
            case .file      : return "file"
            case .postback  : return "postback"
            case .account   : return "account"
            case .reply     : return "reply"
            case .system    : return "system"
            case .card      : return "card"
            case .contact   : return "contact_person"
            case .location  : return "location"
            case .custom    : return "custom"
            case .document  : return "document"
        }
    }
    init(name:String) {
        switch name {
            case "text","button_postback_response"     : self = .text ; break
            case "image"            : self = .image ; break
            case "video"            : self = .video ; break
            case "audio"            : self = .audio ; break
            case "file"             : self = .file ; break
            case "postback"         : self = .postback ; break
            case "account"          : self = .account ; break
            case "reply"            : self = .reply ; break
            case "system"           : self = .system ; break
            case "card"             : self = .card ; break
            case "contact_person"   : self = .contact ; break
            case "location"         : self = .location; break
            case "document"         : self = .document; break
            default                 : self = .custom ; break
        }
    }
}
@objc public enum QCommentStatus:Int{
    case sending
    case pending
    case sent
    case delivered
    case read
    case failed
}
@objc public protocol QCommentDelegate {
    func comment(didChangeStatus comment:QComment, status:QCommentStatus)
    func comment(didChangePosition comment:QComment, position:QCellPosition)
    
    // Audio comment delegate
    @objc optional func comment(didChangeDurationLabel comment:QComment, label:String)
    @objc optional func comment(didChangeCurrentTimeSlider comment:QComment, value:Float)
    @objc optional func comment(didChangeSeekTimeLabel comment:QComment, label:String)
    @objc optional func comment(didChangeAudioPlaying comment:QComment, playing:Bool)
    
    // File comment delegate
    @objc optional func comment(didDownload comment:QComment, downloading:Bool)
    @objc optional func comment(didUpload comment:QComment, uploading:Bool)
    @objc optional func comment(didChangeProgress comment:QComment, progress:CGFloat)
}
@objc public enum QCommentProperty:Int{
    case status
    case uploading
    case downloading
    case uploadProgress
    case downloadProgress
    case cellPosition
    case cellSize
}
public class QComment:Object {
    static var cache = [String: QComment]()
    
    public dynamic var uniqueId: String = ""
    public dynamic var id:Int = 0
    public dynamic var roomId:String = ""
    public dynamic var beforeId:Int = 0
    public dynamic var text:String = ""
    public dynamic var createdAt: Double = 0
    public dynamic var senderEmail:String = ""
    public dynamic var senderName:String = ""
    public dynamic var senderAvatarURL:String = ""
    public dynamic var statusRaw:Int = QCommentStatus.sending.rawValue
    public dynamic var typeRaw:String = QCommentType.text.name()
    public dynamic var data:String = ""
    public dynamic var cellPosRaw:Int = 0
    
    public dynamic var roomName:String = ""
    internal dynamic var roomTypeRaw:Int = 0
    public dynamic var roomAvatar:String = ""
    
    private dynamic var cellWidth:Float = 0
    private dynamic var cellHeight:Float = 0
    internal dynamic var textFontName:String = ""
    internal dynamic var textFontSize:Float = 0
    internal dynamic var rawExtra:String = ""
    // MARK : - Ignored Parameters
    var displayImage:UIImage?
    public var delegate:QCommentDelegate?
    
    // audio variable
    public dynamic var durationLabel = ""
    public dynamic var currentTimeSlider = Float(0)
    public dynamic var seekTimeLabel = "00:00"
    public dynamic var audioIsPlaying = false
    // file variable
    public var isDownloading = false
    public var isUploading = false
    public var progress = CGFloat(0)
    
    
    // read mark
    internal dynamic var isRead:Bool = false
    
    override public static func primaryKey() -> String? {
        return "uniqueId"
    }
    override public static func ignoredProperties() -> [String] {
        return ["displayImage","delegate", "isDownloading","isUploading","progress"]
    }
    
    //MARK : - Getter variable
    public var extras: [String:Any]? {
        get{
            if let data = self.rawExtra.data(using: .utf8) {
                do {
                    if let result = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                        if result.count > 0 {
                            return result
                        }
                    }
                } catch {
                    Qiscus.printLog(text:error.localizedDescription)
                }
            }
            return nil
        }
    }
    private var linkTextAttributes:[String: Any]{
        get{
            var foregroundColorAttributeName = QiscusColorConfiguration.sharedInstance.leftBaloonLinkColor
            var underlineColorAttributeName = QiscusColorConfiguration.sharedInstance.leftBaloonLinkColor
            if self.senderEmail == QiscusMe.shared.email{
                foregroundColorAttributeName = QiscusColorConfiguration.sharedInstance.rightBaloonLinkColor
                underlineColorAttributeName = QiscusColorConfiguration.sharedInstance.rightBaloonLinkColor
            }
            return [
                NSForegroundColorAttributeName: foregroundColorAttributeName,
                NSUnderlineColorAttributeName: underlineColorAttributeName,
                NSUnderlineStyleAttributeName: NSUnderlineStyle.styleSingle.rawValue,
                NSFontAttributeName: Qiscus.style.chatFont
            ]
        }
    }
    public var content:String?{
        if self.type == .custom {
            let contentData = JSON(parseJSON: self.data)
            return "\(contentData["content"].stringValue)"
        }
        return nil
    }
    public var messageId:String{
        get{
            return "\(self.id)"
        }
    }
    public var room:QRoom? {
        get{
            return QRoom.room(withId: self.roomId)
        }
    }
    public var file:QFile? {
        get{
            let realm = try! Realm(configuration: Qiscus.dbConfiguration)
            realm.refresh()
            let files = realm.objects(QFile.self).filter("id == '\(self.uniqueId)'")
            if files.count > 0 {
                return files.first!
            }
            return nil
        }
    }
    public var sender:QUser? {
        get{
            return QUser.user(withEmail: self.senderEmail)
        }
    }
    public var cellPos:QCellPosition {
        get{
            return QCellPosition(rawValue: self.cellPosRaw)!
        }
    }
    public var roomType:QRoomType {
        get{
            return QRoomType(rawValue: self.roomTypeRaw)!
        }
    }
    public var type:QCommentType {
        get{
            return QCommentType(name: self.typeRaw)
        }
    }
    public var status:QCommentStatus {
        get{
            return QCommentStatus(rawValue: self.statusRaw)!
        }
    }
    public var date: String {
        get {
            let date = Date(timeIntervalSince1970: self.createdAt)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "d MMMM yyyy"
            let dateString = dateFormatter.string(from: date)
            
            return dateString
        }
    }
    public var cellIdentifier:String{
        get{
            var position = "Left"
            if self.senderEmail == QiscusMe.shared.email {
                position = "Right"
            }
            switch self.type {
            case .system:
                return "cellSystem"
            case .card:
                return "cellCard\(position)"
            case .postback,.account:
                return "cellPostbackLeft"
            case .image, .video:
                return "cellMedia\(position)"
            case .audio:
                return "cellAudio\(position)"
            case .file:
                return "cellFile\(position)"
            case .contact:
                return "cellContact\(position)"
            case .location:
                return "cellLocation\(position)"
            case .document:
                return "cellDoc\(position)"
            default:
                return "cellText\(position)"
            }
        }
    }
    
    public var time: String {
        get {
            let date = Date(timeIntervalSince1970: self.createdAt)
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "h:mm a"
            let timeString = timeFormatter.string(from: date)
            
            return timeString
        }
    }
    public var textSize:CGSize {
        if !Thread.isMainThread { return CGSize() }
        var recalculate = false
        
        func recalculateSize()->CGSize{
            let textView = UITextView()
            textView.font = Qiscus.style.chatFont
            textView.dataDetectorTypes = .all
            textView.linkTextAttributes = self.linkTextAttributes
            
            var maxWidth:CGFloat = QiscusUIConfiguration.chatTextMaxWidth
            if self.type == .location {
                maxWidth = 204
            }
            textView.attributedText = attributedText
            
            var size = textView.sizeThatFits(CGSize(width: maxWidth, height: CGFloat.greatestFiniteMagnitude))
            
            switch self.type {
            case .postback:
                let payload = JSON(parseJSON: self.data)
                
                if let buttonsPayload = payload.array {
                    let heightAdd = CGFloat(35 * buttonsPayload.count)
                    size.height += heightAdd
                }else{
                    size.height += 35
                }
                break
            case .account:
                size.height += 35
                break
            case .card:
                let payload = JSON(parseJSON: self.data)
                let buttons = payload["buttons"].arrayValue
                size.height = CGFloat(240 + (buttons.count * 45)) + 5
                break
            case .contact:
                size.height = 115
                break
            case .location:
                size.height += 168
                break
            case .image, .video:
                let payload = JSON(parseJSON: self.data)
                var height:CGFloat = 0
                if payload != JSON.null {
                    if let caption = payload["caption"].string {
                        if caption != "" {
                            height = size.height
                        }
                    }
                }
                size.height = height
                break
            case .document :
                size.height = 200
                break
            default:
                break
            }
            return size
        }
        let realm = try! Realm(configuration: Qiscus.dbConfiguration)
        realm.refresh()
        if Float(Qiscus.style.chatFont.pointSize) != self.textFontSize || Qiscus.style.chatFont.familyName != self.textFontName{
            recalculate = true
            try! realm.write {
                self.textFontSize = Float(Qiscus.style.chatFont.pointSize)
                self.textFontName = Qiscus.style.chatFont.familyName
            }
        }else if self.cellWidth == 0 || self.cellHeight == 0 {
            recalculate = true
        }
        if recalculate {
            let newSize = recalculateSize()
            try! realm.write {
                self.cellHeight = Float(newSize.height)
                self.cellWidth = Float(newSize.width)
            }
            return newSize
        }else{
            return CGSize(width: CGFloat(self.cellWidth), height: CGFloat(self.cellHeight))
        }
    }
    
    var textAttribute:[String: Any]{
        get{
            if self.type == .location {
                let style = NSMutableParagraphStyle()
                style.alignment = NSTextAlignment.left
                let systemFont = UIFont.systemFont(ofSize: 14.0)
                var foregroundColorAttributeName = QiscusColorConfiguration.sharedInstance.leftBaloonTextColor
                if self.senderEmail == QiscusMe.shared.email{
                    foregroundColorAttributeName = QiscusColorConfiguration.sharedInstance.rightBaloonTextColor
                }
                
                return [
                    NSForegroundColorAttributeName: foregroundColorAttributeName,
                    NSFontAttributeName: systemFont,
                    NSParagraphStyleAttributeName: style
                ]
            }
            else if self.type == .system {
                let style = NSMutableParagraphStyle()
                style.alignment = NSTextAlignment.center
                let fontSize = Qiscus.style.chatFont.pointSize
                let systemFont = Qiscus.style.chatFont.withSize(fontSize - 4.0)
                let foregroundColorAttributeName = QiscusColorConfiguration.sharedInstance.systemBalloonTextColor
                
                return [
                    NSForegroundColorAttributeName: foregroundColorAttributeName,
                    NSFontAttributeName: systemFont,
                    NSParagraphStyleAttributeName: style
                ]
            }else{
                var foregroundColorAttributeName = QiscusColorConfiguration.sharedInstance.leftBaloonTextColor
                if self.senderEmail == QiscusMe.shared.email{
                    foregroundColorAttributeName = QiscusColorConfiguration.sharedInstance.rightBaloonTextColor
                }
                return [
                    NSForegroundColorAttributeName: foregroundColorAttributeName,
                    NSFontAttributeName: Qiscus.style.chatFont
                ]
            }
        }
    }
    
    var attributedText:NSMutableAttributedString {
        get{
            var attributedText = NSMutableAttributedString(string: self.text)
            switch self.type {
            case .location:
                let payload = JSON(parseJSON: self.data)
                let address = payload["address"].stringValue
                attributedText = NSMutableAttributedString(string: address)
                let allRange = (address as NSString).range(of: address)
                attributedText.addAttributes(self.textAttribute, range: allRange)
                break
            case .image, .video:
                if self.data != "" {
                    let payload = JSON(parseJSON: self.data)
                    if let caption = payload["caption"].string {
                        attributedText = NSMutableAttributedString(string: caption)
                        let allRange = (caption as NSString).range(of: caption)
                        attributedText.addAttributes(self.textAttribute, range: allRange)
                    }
                }
                break
            default:
                let allRange = (self.text as NSString).range(of: self.text)
                attributedText.addAttributes(self.textAttribute, range: allRange)
                break
            }
            
            return attributedText
        }
    }
    public var statusInfo:QCommentInfo? {
        get{
            if let room = QRoom.room(withId: self.roomId) {
                let commentInfo = QCommentInfo()
                commentInfo.comment = self
                commentInfo.deliveredUser = [QParticipant]()
                commentInfo.readUser = [QParticipant]()
                commentInfo.undeliveredUser = [QParticipant]()
                for participant in room.participants {
                    if participant.email != QiscusMe.shared.email{
                        if participant.lastReadCommentId >= self.id {
                            commentInfo.readUser.append(participant)
                        }else if participant.lastDeliveredCommentId >= self.id{
                            commentInfo.deliveredUser.append(participant)
                        }else{
                            commentInfo.undeliveredUser.append(participant)
                        }
                    }
                }
                return commentInfo
            }
            return nil
        }
    }
    public class func threadSaveComment(withUniqueId uniqueId:String)->QComment?{
        let realm = try! Realm(configuration: Qiscus.dbConfiguration)
        realm.refresh()
        let comments = realm.objects(QComment.self).filter("uniqueId == '\(uniqueId)'")
        if comments.count > 0 {
            let comment = comments.first!
            return comment
        }
        return nil
    }
    public class func comment(withUniqueId uniqueId:String)->QComment?{
        if Thread.isMainThread {
            let realm = try! Realm(configuration: Qiscus.dbConfiguration)
            realm.refresh()
            if let comment = QComment.cache[uniqueId] {
                if !comment.isInvalidated{
                    return comment
                }
            }
            let comments = realm.objects(QComment.self).filter("uniqueId == '\(uniqueId)'")
            if comments.count > 0 {
                let comment = comments.first!
                let _ = comment.textSize
                comment.cacheObject()
                return comment
            }
        }
        return nil
    }
    public class func comment(withId id:Int)->QComment?{
        if Thread.isMainThread {
            let realm = try! Realm(configuration: Qiscus.dbConfiguration)
            realm.refresh()
            let data =  realm.objects(QComment.self).filter("id == \(id) && id != 0")
            
            if data.count > 0 {
                let commentData = data.first!
                return QComment.comment(withUniqueId: commentData.uniqueId)
            }
        }
        return nil
    }
    public class func comment(withBeforeId id:Int)->QComment?{
        if Thread.isMainThread {
            let realm = try! Realm(configuration: Qiscus.dbConfiguration)
            realm.refresh()
            let data =  realm.objects(QComment.self).filter("beforeId == \(id) && id != 0")
            
            if data.count > 0 {
                let commentData = data.first!
                return QComment.comment(withUniqueId: commentData.uniqueId)
            }
        }
        return nil
    }
    internal class func countComments(afterId id:Int, roomId:String)->Int{
        let realm = try! Realm(configuration: Qiscus.dbConfiguration)
        realm.refresh()
        let data =  realm.objects(QComment.self).filter("id > \(id) AND roomId = \'(roomId)'").sorted(byKeyPath: "createdAt", ascending: true)
        
        return data.count
    }
    fileprivate func isAttachment(text:String) -> Bool {
        var check:Bool = false
        if(text.hasPrefix("[file]")){
            check = true
        }
        return check
    }
    public func getAttachmentURL(message: String) -> String {
        let component1 = message.components(separatedBy: "[file]")
        let component2 = component1.last!.components(separatedBy: "[/file]")
        let mediaUrlString = component2.first?.trimmingCharacters(in: CharacterSet.whitespaces).replacingOccurrences(of: " ", with: "%20")
        return mediaUrlString!
    }
    public func fileName(text:String) ->String{
        let url = getAttachmentURL(message: text)
        var fileName:String? = ""
        
        let remoteURL = url.replacingOccurrences(of: " ", with: "%20")
        let  mediaURL = URL(string: remoteURL)!
        fileName = mediaURL.lastPathComponent.replacingOccurrences(of: "%20", with: "_")
        
        return fileName!
    }
    private func fileExtension(fromURL url:String) -> String{
        var ext = ""
        if url.range(of: ".") != nil{
            let fileNameArr = url.split(separator: ".")
            ext = String(fileNameArr.last!).lowercased()
            if ext.contains("?"){
                let newArr = ext.split(separator: "?")
                ext = String(newArr.first!).lowercased()
            }
        }
        return ext
    }
    public func replyType(message:String)->QReplyType{
        if self.isAttachment(text: message){
            let url = getAttachmentURL(message: message)
            
            switch self.fileExtension(fromURL: url) {
            case "jpg","jpg_","png","png_","gif","gif_":
                return .image
            case "m4a","m4a_","aac","aac_","mp3","mp3_":
                return .audio
            case "mov","mov_","mp4","mp4_":
                return .video
            case "pdf","pdf_":
                return .document
            case "doc","docx","ppt","pptx","xls","xlsx","txt":
                return .file
            default:
                return .other
            }
        }else{
            return .text
        }
    }
    public func forward(toRoomWithId roomId: String){
        let comment = QComment()
        let time = Double(Date().timeIntervalSince1970)
        let timeToken = UInt64(time * 10000)
        let uniqueID = "ios-\(timeToken)"
        
        comment.uniqueId = uniqueID
        comment.roomId = roomId
        comment.text = self.text
        comment.createdAt = Double(Date().timeIntervalSince1970)
        comment.senderEmail = QiscusMe.shared.email
        comment.senderName = QiscusMe.shared.userName
        comment.statusRaw = QCommentStatus.sending.rawValue
        comment.data = self.data
        comment.typeRaw = self.type.name()
        comment.rawExtra = self.rawExtra
        
        if self.type == .reply {
            comment.typeRaw = QCommentType.text.name()
        }
        
        var file:QFile? = nil
        
        if let fileRef = self.file {
            file = QFile()
            file!.id = uniqueID
            file!.roomId = roomId
            file!.url = fileRef.url
            file!.filename = fileRef.filename
            file!.senderEmail = QiscusMe.shared.email
            file!.localPath = fileRef.localPath
            file!.mimeType = fileRef.mimeType
            file!.localThumbPath = fileRef.localThumbPath
            file!.localMiniThumbPath = fileRef.localMiniThumbPath
            file!.pages = fileRef.pages
            file!.size = fileRef.size
        }
        
        if let room = QRoom.room(withId: roomId){
            let realm = try! Realm(configuration: Qiscus.dbConfiguration)
            realm.refresh()
            if file != nil {
                try! realm.write {
                    realm.add(file!, update:true)
                }
            }
            room.addComment(newComment: comment)
            room.post(comment: comment)
        }
        
    }
    
    
    // MARK : updater method
    public func updateStatus(status:QCommentStatus){
        let uId = self.uniqueId
        QiscusDBThread.async {
            if let c = QComment.threadSaveComment(withUniqueId: uId){
                if c.status != status {
                    let realm = try! Realm(configuration: Qiscus.dbConfiguration)
                    realm.refresh()
                    try! realm.write {
                        c.statusRaw = status.rawValue
                    }
                    DispatchQueue.main.async {
                        if let cache = QComment.cache[uId]{
                            QiscusNotification.publish(messageStatus: cache, status: status)
                            cache.delegate?.comment(didChangeStatus: cache, status: status)
                        }
                    }
                }
            }
        }
    }
    public func updateCellPos(cellPos: QCellPosition){
        let uId = self.uniqueId
        if self.cellPos != cellPos {
            let realm = try! Realm(configuration: Qiscus.dbConfiguration)
            realm.refresh()
            try! realm.write {
                self.cellPosRaw = cellPos.rawValue
            }
            func execute(){
                if let cache = QComment.cache[uId] {
                    cache.delegate?.comment(didChangePosition: cache, position: cellPos)
                }
            }
            if Thread.isMainThread{
                execute()
            }else{
                DispatchQueue.main.sync {
                    execute()
                }
            }
        }
    }
    public func updateDurationLabel(label:String){
        let uId = self.uniqueId
        if self.durationLabel != label {
            let realm = try! Realm(configuration: Qiscus.dbConfiguration)
            realm.refresh()
            try! realm.write {
                self.durationLabel = label
            }
            func execute(){
                if let cache = QComment.cache[uId] {
                    cache.delegate?.comment?(didChangeDurationLabel: cache, label: label)
                }
            }
            if Thread.isMainThread{
                execute()
            }else{
                DispatchQueue.main.sync {
                    execute()
                }
            }
        }
    }
    public func updateTimeSlider(value:Float){
        let uId = self.uniqueId
        if self.currentTimeSlider != value {
            let realm = try! Realm(configuration: Qiscus.dbConfiguration)
            realm.refresh()
            try! realm.write {
                self.currentTimeSlider = value
            }
            func execute(){
                if let cache = QComment.cache[uId] {
                    cache.delegate?.comment?(didChangeCurrentTimeSlider: cache, value: value)
                }
            }
            if Thread.isMainThread{
                execute()
            }else{
                DispatchQueue.main.sync {
                    execute()
                }
            }
        }
    }
    public func updateSeekLabel(label:String){
        let uId = self.uniqueId
        if self.seekTimeLabel != label {
            let realm = try! Realm(configuration: Qiscus.dbConfiguration)
            realm.refresh()
            try! realm.write {
                self.seekTimeLabel = label
            }
            func execute(){
                if let cache = QComment.cache[uId] {
                    cache.delegate?.comment?(didChangeSeekTimeLabel: cache, label: label)
                }
            }
            if Thread.isMainThread{
                execute()
            }else{
                DispatchQueue.main.sync {
                    execute()
                }
            }
        }
    }
    public func updatePlaying(playing:Bool){
        let uId = self.uniqueId
        if self.audioIsPlaying != playing {
            let realm = try! Realm(configuration: Qiscus.dbConfiguration)
            realm.refresh()
            try! realm.write {
                self.audioIsPlaying = playing
            }
            func execute(){
                if let cache = QComment.cache[uId] {
                    cache.delegate?.comment?(didChangeAudioPlaying: cache, playing: playing)
                }
            }
            if Thread.isMainThread{
                execute()
            }else{
                DispatchQueue.main.sync {
                    execute()
                }
            }
        }
    }
    public func updateUploading(uploading:Bool){
        let uId = self.uniqueId
        DispatchQueue.main.async {
            if let comment = QComment.cache[uId] {
                if comment.isUploading != uploading {
                    comment.isUploading = uploading
                    comment.delegate?.comment?(didUpload: comment, uploading: uploading)
                }
            }
        }
    }
    public func updateDownloading(downloading:Bool){
        let uId = self.uniqueId
        DispatchQueue.main.async {
            if let comment = QComment.cache[uId] {
                if comment.isDownloading != downloading {
                    comment.isDownloading = downloading
                    if let delegate = comment.delegate {
                        delegate.comment?(didDownload: comment, downloading: downloading)
                    }
                }
            }
        }
    }
    public func updateProgress(progress:CGFloat){
        let uId = self.uniqueId
        DispatchQueue.main.async {
            if let comment = QComment.cache[uId] {
                if comment.progress != progress {
                    comment.progress = progress
                    comment.delegate?.comment?(didChangeProgress: comment, progress: progress)
                }
            }
        }
    }
    public class func decodeDictionary(data:[AnyHashable : Any]) -> QComment? {
        if let isQiscusdata = data["qiscus_commentdata"] as? Bool{
            if isQiscusdata {
                let temp = QComment()
                if let uniqueId = data["qiscus_uniqueId"] as? String{
                    temp.uniqueId = uniqueId
                }
                if let id = data["qiscus_id"] as? Int {
                    temp.id = id
                }
                if let roomId = data["qiscus_roomId"] as? String {
                    temp.roomId = roomId
                }
                if let beforeId = data["qiscus_beforeId"] as? Int {
                    temp.beforeId = beforeId
                }
                if let text = data["qiscus_text"] as? String {
                    temp.text = text
                }
                if let createdAt = data["qiscus_createdAt"] as? Double{
                    temp.createdAt = createdAt
                }
                if let email = data["qiscus_senderEmail"] as? String{
                    temp.senderEmail = email
                }
                if let name = data["qiscus_senderName"] as? String{
                    temp.senderName = name
                }
                if let statusRaw = data["qiscus_statusRaw"] as? Int {
                    temp.statusRaw = statusRaw
                }
                if let typeRaw = data["qiscus_typeRaw"] as? String {
                    temp.typeRaw = typeRaw
                }
                if let payload = data["qiscus_data"] as? String {
                    temp.data = payload
                }
                
                return temp
            }
        }
        return nil
    }
    public func read(check:Bool = true){
        let uniqueId = self.uniqueId
        if self.isRead {return}
        QiscusDBThread.async {
            if let comment = QComment.threadSaveComment(withUniqueId: uniqueId){
                let realm = try! Realm(configuration: Qiscus.dbConfiguration)
                realm.refresh()
                try! realm.write {
                    comment.isRead = true
                }
                if check {
                    let data = realm.objects(QComment.self).filter("isRead == false AND createdAt < \(comment.createdAt) AND roomId == '\(comment.roomId)'")
                    for olderComment in data {
                        try! realm.write {
                            olderComment.isRead = true
                        }
                    }
                }
                if let room = QRoom.threadSaveRoom(withId: comment.roomId) {
                    room.updateUnreadCommentCount()
                    if comment.id > 0 {
                        let roomId = room.id
                        let commentId = comment.id
                        QRoom.publishStatus(roomId: roomId, commentId: commentId, status: .read)
                    }
                }
            }
        }
    }
    public func receive(){
        let uniqueId = self.uniqueId
        QiscusDBThread.async {
            if let comment = QComment.threadSaveComment(withUniqueId: uniqueId){
                if let room = QRoom.threadSaveRoom(withId: comment.roomId) {
                    if room.lastDeliveredCommentId < comment.id {
                        QRoom.publishStatus(roomId: room.id, commentId: comment.id, status: .delivered)
                        let realm = try! Realm(configuration: Qiscus.dbConfiguration)
                        realm.refresh()
                        try! realm.write {
                            room.lastDeliveredCommentId = comment.id
                        }
                    }
                }
            }
        }
    }
    public func encodeDictionary()->[AnyHashable : Any]{
        var data = [AnyHashable : Any]()
        
        data["qiscus_commentdata"] = true
        data["qiscus_uniqueId"] = self.uniqueId
        data["qiscus_id"] = self.id
        data["qiscus_roomId"] = self.roomId
        data["qiscus_beforeId"] = self.beforeId
        data["qiscus_text"] = self.text
        data["qiscus_createdAt"] = self.createdAt
        data["qiscus_senderEmail"] = self.senderEmail
        data["qiscus_senderName"] = self.senderName
        data["qiscus_statusRaw"] = self.statusRaw
        data["qiscus_typeRaw"] = self.typeRaw
        data["qiscus_data"] = self.data
        
        return data
    }
    internal class func tempComment(fromJSON json:JSON)->QComment{
        let temp = QComment()
        
        let commentId = json["id"].intValue
        let commentUniqueId = json["unique_temp_id"].stringValue
        var commentText = json["message"].stringValue
        let commentSenderName = json["username"].stringValue
        let commentSenderAvatarURL = json["user_avatar_url"].stringValue
        let commentCreatedAt = json["unix_timestamp"].doubleValue
        let commentBeforeId = json["comment_before_id"].intValue
        let senderEmail = json["email"].stringValue
        let commentType = json["type"].stringValue
        let roomId = "\(json["room_id"])"
        let commentExtras = "\(json["extras"])"
        
        if commentType == "reply" || commentType == "buttons" {
            commentText = json["payload"]["text"].stringValue
        }
        
        let avatarURL = json["user_avatar_url"].stringValue
        
        let _ = QUser.saveUser(withEmail: senderEmail, fullname: commentSenderName, avatarURL: avatarURL)
        
        temp.uniqueId = commentUniqueId
        temp.id = commentId
        temp.roomId = roomId
        temp.text = commentText
        temp.senderName = commentSenderName
        temp.senderAvatarURL = commentSenderAvatarURL
        temp.createdAt = commentCreatedAt
        temp.beforeId = commentBeforeId
        temp.senderEmail = senderEmail
        temp.cellPosRaw = QCellPosition.single.rawValue
        temp.rawExtra = commentExtras
        temp.statusRaw = QCommentStatus.sent.rawValue
        
        if let roomName = json["room_name"].string {
            temp.roomName = roomName
        }
        if let chatType = json["chat_type"].string {
            if chatType == "group" {
                temp.roomTypeRaw = QRoomType.group.rawValue
            }else{
                temp.roomTypeRaw = QRoomType.single.rawValue
            }
        }
        if let roomAvatar = json["room_avatar"].string {
            temp.roomAvatar = roomAvatar
        }
        
        switch commentType {
        case "contact":
            temp.data = "\(json["payload"])"
            temp.typeRaw = QCommentType.contact.name()
            break
        case "buttons":
            temp.data = "\(json["payload"]["buttons"])"
            temp.typeRaw = QCommentType.postback.name()
            break
        case "account_linking":
            temp.data = "\(json["payload"])"
            temp.typeRaw = QCommentType.account.name()
            break
        case "reply":
            temp.data = "\(json["payload"])"
            temp.typeRaw = QCommentType.reply.name()
            break
        case "system_event":
            temp.data = "\(json["payload"])"
            temp.typeRaw = QCommentType.system.name()
            break
        case "card":
            temp.data = "\(json["payload"])"
            temp.typeRaw = QCommentType.card.name()
            break
        case "button_postback_response" :
            temp.data = "\(json["payload"])"
            temp.typeRaw = QCommentType.text.name()
            break
        case "location":
            temp.data = "\(json["payload"])"
            temp.typeRaw = QCommentType.location.name()
            break
        case "custom":
            temp.data = "\(json["payload"])"
            temp.typeRaw = json["payload"]["type"].stringValue
            break
        case "file_attachment":
            temp.data = "\(json["payload"])"
            var type = QiscusFileType.file
            let fileURL = json["payload"]["url"].stringValue
            var filename = temp.fileName(text: fileURL)
            
            if filename.contains("-"){
                let nameArr = filename.split(separator: "-")
                var i = 0
                for comp in nameArr {
                    switch i {
                    case 0 : filename = "" ; break
                    case 1 : filename = "\(String(comp))"
                    default: filename = "\(filename)-\(comp)"
                    }
                    i += 1
                }
            }
            if temp.file == nil {
                let file = QFile()
                file.id = temp.uniqueId
                file.url = fileURL
                file.filename = filename
                file.senderEmail = temp.senderEmail
                type = file.type
            }
            switch type {
            case .image:
                temp.typeRaw = QCommentType.image.name()
                break
            case .video:
                temp.typeRaw = QCommentType.video.name()
                break
            case .audio:
                temp.typeRaw = QCommentType.audio.name()
                break
            case .document:
                temp.typeRaw = QCommentType.document.name()
                break
            default:
                temp.typeRaw = QCommentType.file.name()
                break
            }
            break
        case "text":
            if temp.text.hasPrefix("[file]"){
                var type = QiscusFileType.file
                let fileURL = QFile.getURL(fromString: temp.text)
                var filename = temp.fileName(text: fileURL)
                
                if filename.contains("-"){
                    let nameArr = filename.split(separator: "-")
                    var i = 0
                    for comp in nameArr {
                        switch i {
                        case 0 : filename = "" ; break
                        case 1 : filename = "\(String(comp))"
                        default: filename = "\(filename)-\(comp)"
                        }
                        i += 1
                    }
                }
                if temp.file == nil {
                    let file = QFile()
                    file.id = temp.uniqueId
                    file.url = fileURL
                    file.senderEmail = temp.senderEmail
                    file.filename = filename
                    type = file.type
                }
                switch type {
                case .image:
                    temp.typeRaw = QCommentType.image.name()
                    break
                case .video:
                    temp.typeRaw = QCommentType.video.name()
                    break
                case .audio:
                    temp.typeRaw = QCommentType.audio.name()
                    break
                case .document:
                    temp.typeRaw = QCommentType.document.name()
                    break
                default:
                    temp.typeRaw = QCommentType.file.name()
                    break
                }
            }else{
                temp.typeRaw = QCommentType.text.name()
            }
            break
            default:
                temp.data = "\(json["payload"])"
                temp.typeRaw = commentType
            break
        }
        return temp
    }
    internal func update(commentId:Int, beforeId:Int){
        let realm = try! Realm(configuration: Qiscus.dbConfiguration)
        realm.refresh()
        try! realm.write {
            self.id = commentId
            self.beforeId = beforeId
        }
    }
    internal func update(text:String){
        if self.text != text {
            let realm = try! Realm(configuration: Qiscus.dbConfiguration)
            realm.refresh()
            try! realm.write {
                self.text = text
            }
        }
    }
    internal func update(data:String){
        if self.data != data {
            let realm = try! Realm(configuration: Qiscus.dbConfiguration)
            realm.refresh()
            try! realm.write {
                self.data = data
            }
        }
    }
    public class func all() -> [QComment]{
        let realm = try! Realm(configuration: Qiscus.dbConfiguration)
        realm.refresh()
        let data = realm.objects(QComment.self)
        
        if data.count > 0 {
            return Array(data)
        }else{
            return [QComment]()
        }
    }
    internal class func cacheAll(){
        let comments = QComment.all()
        for comment in comments{
            comment.cacheObject()
        }
    }
    internal class func resendPendingMessage(){
        QiscusDBThread.async {
            let realm = try! Realm(configuration: Qiscus.dbConfiguration)
            realm.refresh()
            let data = realm.objects(QComment.self).filter("statusRaw == 1")
            
            if data.count > 0 {
                for comment in data {
                    if Thread.isMainThread {
                        if let room = QRoom.room(withId: comment.roomId){
                            room.updateCommentStatus(inComment: comment, status: .sending)
                            room.post(comment: comment)
                        }
                    }else{
                        let commentTS = ThreadSafeReference(to: comment)
                        DispatchQueue.main.sync {
                            let realm = try! Realm(configuration: Qiscus.dbConfiguration)
                            realm.refresh()
                            guard let c = realm.resolve(commentTS) else { return }
                            if let room = QRoom.room(withId: c.roomId){
                                room.updateCommentStatus(inComment: c, status: .sending)
                                room.post(comment: c)
                            }
                        }
                    }
                }
            }
        }
    }
    internal func cacheObject(){
        if Thread.isMainThread {
            if QComment.cache[self.uniqueId] == nil {
                QComment.cache[self.uniqueId] = self
            }
        }
    }
    public func set(extras data:[String:Any], onSuccess: @escaping (QComment)->Void, onError: @escaping (QComment, String)->Void){
        let realm = try! Realm(configuration: Qiscus.dbConfiguration)
        realm.refresh()
        if let jsonData = try? JSONSerialization.data(withJSONObject: data as Any, options: []){
            if let jsonString = String(data: jsonData,
                                       encoding: .ascii){
                try! realm.write {
                    self.rawExtra = jsonString
                }
                onSuccess(self)
            }else{
                Qiscus.printLog(text: "cant parse object")
                onError(self, "cant parse object")
            }
        }else{
            Qiscus.printLog(text: "invalid json object")
            onError(self,"invalid json object")
        }
    }
    public func set(extras data:[String:Any])->QComment?{
        let realm = try! Realm(configuration: Qiscus.dbConfiguration)
        realm.refresh()
        if let jsonData = try? JSONSerialization.data(withJSONObject: data as Any, options: []){
            if let jsonString = String(data: jsonData,
                                       encoding: .ascii){
                try! realm.write {
                    self.rawExtra = jsonString
                }
                return self
            }else{
                Qiscus.printLog(text: "cant parse object")
                return nil
            }
        }else{
            Qiscus.printLog(text: "invalid json object")
            return nil
        }
    }
}
