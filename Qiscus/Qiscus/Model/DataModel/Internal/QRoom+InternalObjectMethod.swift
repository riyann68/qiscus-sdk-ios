//
//  QRoom+InternalObjectMethod.swift
//  Qiscus
//
//  Created by Ahmad Athaullah on 21/11/17.
//  Copyright © 2017 Ahmad Athaullah. All rights reserved.
//

import UIKit
import RealmSwift
import SwiftyJSON

internal extension QRoom {
    internal func pinRoom(){
        let id = self.id
        QiscusDBThread.async {
            if let r = QRoom.threadSaveRoom(withId: id) {
                let realm = try! Realm(configuration: Qiscus.dbConfiguration)
                realm.refresh()
                try! realm.write {
                    r.pinned = Double(Date().timeIntervalSince1970)
                }
            }
        }
    }
    internal func unpinRoom(){
        let id = self.id
        QiscusDBThread.async {
            if let r = QRoom.threadSaveRoom(withId: id) {
                if r.pinned != 0 {
                    let realm = try! Realm(configuration: Qiscus.dbConfiguration)
                    realm.refresh()
                    try! realm.write {
                        r.pinned = 0
                    }
                }
            }
        }
    }
    internal func updateRoom(roomName:String? = nil, roomAvatarURL:String? = nil, roomOptions:String? = nil, onSuccess:@escaping ((_ room: QRoom)->Void),onError:@escaping ((_ error: String)->Void)){
        let service = QRoomService()
        service.updateRoom(onRoom: self, roomName: roomName, roomAvatarURL: roomAvatarURL, roomOptions: roomOptions, onSuccess: onSuccess, onError: onError)
    }
    internal func publishStopTypingRoom(){
        let roomId = self.id
        QiscusBackgroundThread.async { autoreleasepool{
            let message: String = "0";
            let channel = "r/\(roomId)/\(roomId)/\(Qiscus.client.email)/t"
            
            Qiscus.shared.mqtt?.publish(channel, withString: message, qos: .qos1, retained: false)
            }}
        if self.selfTypingTimer != nil {
            if self.typingTimer!.isValid {
                self.typingTimer!.invalidate()
            }
            self.typingTimer = nil
        }
    }
    internal func publishStartTypingRoom(){
        let roomId = self.id
        QiscusBackgroundThread.async { autoreleasepool{
            let message: String = "1";
            let channel = "r/\(roomId)/\(roomId)/\(Qiscus.client.email)/t"
            Qiscus.shared.mqtt?.publish(channel, withString: message, qos: .qos1, retained: false)
            }}
        if self.typingTimer != nil {
            if self.typingTimer!.isValid {
                self.typingTimer!.invalidate()
            }
        }
        
        DispatchQueue.main.async {
            self.typingTimer = Timer.scheduledTimer(timeInterval: 3.0, target: self, selector: #selector(self.publishStopTyping), userInfo: nil, repeats: false)
        }
    }
    internal func checkCommentStatus(){
        let id = self.id
        QiscusDBThread.async {
            let realm = try! Realm(configuration: Qiscus.dbConfiguration)
            realm.refresh()
            if let room = QRoom.threadSaveRoom(withId: id){
                var lastReadId = 0
                var lastDeliveredId = 0
                for participant in room.participants {
                    if lastReadId == 0 || lastReadId > participant.lastReadCommentId{
                        lastReadId = participant.lastReadCommentId
                    }
                    if lastDeliveredId == 0 || lastDeliveredId > participant.lastDeliveredCommentId{
                        lastDeliveredId = participant.lastDeliveredCommentId
                    }
                }
                if lastReadId > 0 && lastDeliveredId > 0 {
                    if lastReadId != room.lastReadCommentId {
                        try! realm.write {
                            room.lastReadCommentId = lastReadId
                        }
                    }
                    if lastDeliveredId != room.lastDeliveredCommentId {
                        try! realm.write {
                            room.lastDeliveredCommentId = lastDeliveredId
                        }
                    }
                    let deliveredData = room.rawComments.filter("id != 0 AND id <= \(room.lastDeliveredCommentId) AND statusRaw < \(QCommentStatus.delivered.rawValue) ")
                    let readData = room.rawComments.filter("id != 0 AND id <= \(room.lastReadCommentId) AND statusRaw < \(QCommentStatus.read.rawValue) ")
                    
                    for c in deliveredData {
                        c.updateStatus(status: .delivered)
                        if c.id == room.lastCommentId {
                            if room.lastCommentStatusRaw != QCommentStatus.delivered.rawValue{
                                try! realm.write {
                                    room.lastCommentStatusRaw = QCommentStatus.delivered.rawValue
                                }
                                let rId = room.id
                                let rts = ThreadSafeReference(to: room)
                                DispatchQueue.main.async {
                                    let mainRealm = try! Realm(configuration: Qiscus.dbConfiguration)
                                    mainRealm.refresh()
                                    if Qiscus.chatRooms[rId] == nil {
                                        if let r = mainRealm.resolve(rts) {
                                            Qiscus.chatRooms[rId] = r
                                        }
                                    }
                                    if let r = QRoom.room(withId: rId){
                                        QiscusNotification.publish(roomChange: r, onProperty: .lastComment)
                                    }
                                }
                            }
                        }
                    }
                    for c in readData {
                        c.updateStatus(status: .read)
                        if c.id == room.lastCommentId {
                            if room.lastCommentStatusRaw != QCommentStatus.read.rawValue{
                                try! realm.write {
                                    room.lastCommentStatusRaw = QCommentStatus.read.rawValue
                                }
                                let rId = room.id
                                let rts = ThreadSafeReference(to:room)
                                DispatchQueue.main.async {
                                    let mainRealm = try! Realm(configuration: Qiscus.dbConfiguration)
                                    mainRealm.refresh()
                                    if Qiscus.chatRooms[rId] == nil {
                                        if let r = mainRealm.resolve(rts) {
                                            Qiscus.chatRooms[rId] = r
                                        }
                                    }
                                    if let r = QRoom.getRoom(withId: rId){
                                        QiscusNotification.publish(roomChange: r, onProperty: .lastComment)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    internal func subscribeRoomChannel(){
        let id = self.id
        QiscusBackgroundThread.async {
            if let room = QRoom.threadSaveRoom(withId: id) {
                var channels = [String]()
                
                if !room.isPublicChannel {
                    channels.append("r/\(room.id)/\(room.id)/+/d")
                    channels.append("r/\(room.id)/\(room.id)/+/r")
                }
                
                if room.type == .single {
                    for participant in room.participants{
                        if participant.email != Qiscus.client.email {
                            channels.append("u/\(participant.email)/s")
                        }
                    }
                }
                
                DispatchQueue.main.async {
                    for channel in channels{
                        if Qiscus.realtimeConnected {
                            Qiscus.shared.mqtt?.subscribe(channel)
                        }else{
                            if !Qiscus.realtimeChannel.contains(channel) {
                                Qiscus.realtimeChannel.append(channel)
                            }
                        }
                    }
                }
            }
        }
    }
    internal func unsubscribeRoomChannel(){
        let id = self.id
        QiscusBackgroundThread.async {
            if let room = QRoom.threadSaveRoom(withId: id) {
                var channels = [String]()
                
                if !room.isPublicChannel {
                    channels.append("r/\(room.id)/\(room.id)/+/d")
                    channels.append("r/\(room.id)/\(room.id)/+/r")
                }
                
                if room.type == .single {
                    for participant in room.participants{
                        if participant.email != Qiscus.client.email {
                            channels.append("u/\(participant.email)/s")
                        }
                    }
                }
                
                DispatchQueue.global().async {autoreleasepool{
                    for channel in channels{
                        Qiscus.shared.mqtt?.unsubscribe(channel)
                    }
                }}
            }
        }
        
    }
    
    internal func addComment(newComment:QComment, onTop:Bool = false){
        let id = self.id
        let cUniqueId = newComment.uniqueId
        
        QiscusDBThread.sync {
            if let room = QRoom.threadSaveRoom(withId: id) {
                let predicate = NSPredicate(format: "uniqueId = %@", cUniqueId)
                if room.rawComments.filter(predicate).count > 0 {
                    Qiscus.printLog(text: "fail to add newComment, comment with same uniqueId already exist")
                    return
                }
                
                let senderEmail = newComment.senderEmail
                let senderName = newComment.senderName
                let avatarURL = newComment.senderAvatarURL
                
                let realm = try! Realm(configuration: Qiscus.dbConfiguration)
                realm.refresh()
                
                if QUser.getUser(email: senderEmail) == nil {
                    let _ = QUser.saveUser(withEmail: senderEmail, fullname: senderName, avatarURL: avatarURL)
                }
                
                if room.comments.count == 0 {
                    newComment.cellPosRaw = QCellPosition.single.rawValue
                }
                
                if onTop{
                    try! realm.write {
                        realm.add(newComment, update: true)
                        room.rawComments.insert(newComment, at: 0)
                    }
                    if room.lastComment == nil {
                        room.updateLastComentInfo(comment: newComment)
                    }
                }
                else{
                    try! realm.write {
                        realm.add(newComment, update: true)
                        room.rawComments.append(newComment)
                    }
                    room.updateLastComentInfo(comment: newComment)
                }
                let textMessage = newComment.text
                DispatchQueue.main.async{
                    if UIApplication.shared.applicationState != .active {
                        Qiscus.printLog(text: "sync qiscus added new message on background: \(textMessage)")
                    }
                }
                if !onTop {
                    if Thread.isMainThread {
                        if let r = QRoom.getRoom(withId: id){
                            if let c = QComment.comment(withUniqueId: cUniqueId){
                                QiscusNotification.publish(gotNewComment: c, room: r)
                            }
                        }
                    }else{
                        DispatchQueue.main.sync {
                            if let r = QRoom.getRoom(withId: id){
                                if let c = QComment.comment(withUniqueId: cUniqueId){
                                    QiscusNotification.publish(gotNewComment: c, room: r)
                                }
                            }
                        }
                    }
                }
            }else{
                Qiscus.printLog(text: "fail to add newComment, room not exist")
                return
            }
        }
    }
    internal func clearLastComment(){
        let id = self.id
        QiscusDBThread.async {
            if let room = QRoom.threadSaveRoom(withId: id){
                if !room.isInvalidated {
                    
                    let realm = try! Realm(configuration: Qiscus.dbConfiguration)
                    realm.refresh()
                    try! realm.write {
                        room.lastCommentId = 0
                        room.lastCommentText = ""
                        room.lastCommentUniqueId = ""
                        room.lastCommentBeforeId = 0
                        room.lastCommentCreatedAt = 0
                        room.lastCommentSenderEmail = ""
                        room.lastCommentSenderName = ""
                        room.lastCommentStatusRaw = QCommentStatus.sending.rawValue
                        room.lastCommentTypeRaw = QCommentType.text.name()
                        room.lastCommentData = ""
                        room.lastCommentRawExtras = ""
                    }
                    let rts = ThreadSafeReference(to:room)
                    DispatchQueue.main.async {
                        let mainRealm = try! Realm(configuration: Qiscus.dbConfiguration)
                        mainRealm.refresh()
                        if Qiscus.chatRooms[id] == nil {
                            if let r = mainRealm.resolve(rts) {
                                Qiscus.chatRooms[id] = r
                            }
                        }
                        if let cache = QRoom.room(withId: id){
                            QiscusNotification.publish(roomChange: cache, onProperty: .lastComment)
                        }
                    }
                }
            }
        }
    }
    internal func recalculateLastComment(){
        let roomId = self.id
        let lastCommentId = 0
        let predicate = NSPredicate(format: "statusRaw != %d AND id > %d", QCommentStatus.deleted.rawValue,0)
        let allComment = self.rawComments.sorted(byKeyPath: "createdAt", ascending: true).filter(predicate)
        
        if let last = allComment.last {
            let realm = try! Realm(configuration: Qiscus.dbConfiguration)
            realm.refresh()
            try! realm.write {
                self.lastCommentId = last.id
                self.lastCommentText = last.text
                self.lastCommentUniqueId = last.uniqueId
                self.lastCommentBeforeId = last.beforeId
                self.lastCommentCreatedAt = last.createdAt
                self.lastCommentSenderEmail = last.senderEmail
                self.lastCommentSenderName = last.senderName
                self.lastCommentStatusRaw = last.statusRaw
                self.lastCommentTypeRaw = last.typeRaw
                self.lastCommentData = last.data
                self.lastCommentRawExtras = last.rawExtra
            }
            let rts = ThreadSafeReference(to:self)
            DispatchQueue.main.async {
                let mainRealm = try! Realm(configuration: Qiscus.dbConfiguration)
                mainRealm.refresh()
                if Qiscus.chatRooms[roomId] == nil {
                    if let r = mainRealm.resolve(rts) {
                        Qiscus.chatRooms[roomId] = r
                    }
                }
                if let cache = QRoom.room(withId: roomId){
                    if let c = cache.lastComment {
                        QiscusNotification.publish(roomChange: cache, onProperty: .lastComment)
                    }
                    
                }
            }
        }
    }
    internal func updateLastComentInfo(comment:QComment, triggerNotification:Bool = true ){
        let id = self.id
        let cId = comment.id
        let cText = comment.text
        let cUniqueId = comment.uniqueId
        let cBeforeId = comment.beforeId
        let cCreatedAt = comment.createdAt
        let cSenderEmail = comment.senderEmail
        let cSenderName = comment.senderName
        let cStatusRaw = comment.statusRaw
        let cTypeRaw = comment.typeRaw
        let cData = comment.data
        let cRawExtras = comment.rawExtra
        QiscusDBThread.async {
            if let room = QRoom.threadSaveRoom(withId: id){
                if !room.isInvalidated {
                    if cCreatedAt > room.lastCommentCreatedAt || cId > room.lastCommentId || cId == 0 {
                        let realm = try! Realm(configuration: Qiscus.dbConfiguration)
                        realm.refresh()
                        try! realm.write {
                            room.lastCommentId = cId
                            room.lastCommentText = cText
                            room.lastCommentUniqueId = cUniqueId
                            room.lastCommentBeforeId = cBeforeId
                            room.lastCommentCreatedAt = cCreatedAt
                            room.lastCommentSenderEmail = cSenderEmail
                            room.lastCommentSenderName = cSenderName
                            room.lastCommentStatusRaw = cStatusRaw
                            room.lastCommentTypeRaw = cTypeRaw
                            room.lastCommentData = cData
                            room.lastCommentRawExtras = cRawExtras
                        }
                        let rts = ThreadSafeReference(to:room)
                        DispatchQueue.main.async {
                            let mainRealm = try! Realm(configuration: Qiscus.dbConfiguration)
                            mainRealm.refresh()
                            if Qiscus.chatRooms[id] == nil {
                                if let r = mainRealm.resolve(rts) {
                                    Qiscus.chatRooms[id] = r
                                }
                            }
                            if let cache = QRoom.room(withId: id){
                                if let c = cache.lastComment {
                                    if cache.comments.count == 0 {
                                        QiscusNotification.publish(gotNewComment: c, room: cache)
                                    }
                                    QiscusNotification.publish(roomChange: cache, onProperty: .lastComment)
                                }
                                
                            }
                        }
                    }
                }
            }
        }
    }
    // MARK: - Public Object method
    internal func syncRoomData(withJSON json:JSON, onSuccess: @escaping ((QRoom)->Void) = {_ in }){
        let id = self.id
        QiscusDBThread.async {
            if let room = QRoom.threadSaveRoom(withId: id) {
                let realm = try! Realm(configuration: Qiscus.dbConfiguration)
                realm.refresh()
                if let option = json["options"].string {
                    if option != "" && option != "<null>" && option != room.data{
                        try! realm.write {
                            room.data = option
                        }
                        let rts = ThreadSafeReference(to:room)
                        DispatchQueue.main.async {
                            let mainRealm = try! Realm(configuration: Qiscus.dbConfiguration)
                            mainRealm.refresh()
                            if Qiscus.chatRooms[id] == nil {
                                if let r = mainRealm.resolve(rts) {
                                    Qiscus.chatRooms[id] = r
                                }
                            }
                            if let cache = QRoom.room(withId: id) {
                                QiscusNotification.publish(roomChange: cache, onProperty: .data)
                            }
                        }
                    }
                }
                if let unread = json["unread_count"].int {
                    if unread != room.unreadCount {
                        try! realm.write {
                            room.unreadCount = unread
                        }
                        let rts = ThreadSafeReference(to: room)
                        DispatchQueue.main.async {
                            let mainRealm = try! Realm(configuration: Qiscus.dbConfiguration)
                            mainRealm.refresh()
                            if Qiscus.chatRooms[id] == nil {
                                if let r = mainRealm.resolve(rts) {
                                    Qiscus.chatRooms[id] = r
                                }
                            }
                            if let cache = QRoom.getRoom(withId: id) {
                                QiscusNotification.publish(roomChange: cache, onProperty: .unreadCount)
                                cache.delegate?.room?(didChangeUnread: cache)
                            }
                        }
                    }
                }
                if let roomName = json["room_name"].string {
                    if roomName != room.storedName {
                        try! realm.write {
                            room.storedName = roomName
                        }
                        if room.definedname == "" {
                            let rts = ThreadSafeReference(to: room)
                            DispatchQueue.main.async {
                                let mainRealm = try! Realm(configuration: Qiscus.dbConfiguration)
                                mainRealm.refresh()
                                if Qiscus.chatRooms[id] == nil {
                                    if let r = mainRealm.resolve(rts) {
                                        Qiscus.chatRooms[id] = r
                                    }
                                }
                                if let cache = QRoom.room(withId: id) {
                                    QiscusNotification.publish(roomChange: cache, onProperty: .name)
                                }
                            }
                        }
                    }
                }
                if let roomAvatar = json["avatar_url"].string {
                    room.update(avatarURL: roomAvatar)
                }
                if json["last_comment"] != JSON.null {
                    let commentData = json["last_comment"]
                    let comment = QComment.tempComment(fromJSON: commentData)
                    if comment.id > room.lastCommentId {
                        try! realm.write {
                            room.lastCommentId = comment.id
                            room.lastCommentText = comment.text
                            room.lastCommentUniqueId = comment.uniqueId
                            room.lastCommentBeforeId = comment.beforeId
                            room.lastCommentCreatedAt = comment.createdAt
                            room.lastCommentSenderEmail = comment.senderEmail
                            room.lastCommentSenderName = comment.senderName
                            room.lastCommentStatusRaw = comment.statusRaw
                            room.lastCommentTypeRaw = comment.typeRaw
                            room.lastCommentData = comment.data
                        }
                        let rts = ThreadSafeReference(to: room)
                        DispatchQueue.main.async {
                            let mainRealm = try! Realm(configuration: Qiscus.dbConfiguration)
                            mainRealm.refresh()
                            if Qiscus.chatRooms[id] == nil {
                                if let r = mainRealm.resolve(rts) {
                                    Qiscus.chatRooms[id] = r
                                }
                            }
                            if let cache = QRoom.room(withId: id) {
                                QiscusNotification.publish(roomChange: cache, onProperty: .lastComment)
                            }
                        }
                    }
                }
                
                if let participants = json["participants"].array {
                    var participantString = [String]()
                    var participantChanged = false
                    for participantJSON in participants {
                        let participantEmail = participantJSON["email"].stringValue
                        let fullname = participantJSON["username"].stringValue
                        let avatarURL = participantJSON["avatar_url"].stringValue
                        
                        let _ = QUser.saveUser(withEmail: participantEmail, fullname: fullname, avatarURL: avatarURL)
                        
                        let lastReadId = participantJSON["last_comment_read_id"].intValue
                        let lastDeliveredId = participantJSON["last_comment_received_id"].intValue
                        let savedParticipant = room.participants.filter("email == '\(participantEmail)'")
                        if savedParticipant.count > 0{
                            let storedParticipant = savedParticipant.first!
                            storedParticipant.updateLastReadId(commentId: lastReadId)
                            storedParticipant.updateLastDeliveredId(commentId: lastDeliveredId)
                        }else {
                            let newParticipant = QParticipant()
                            newParticipant.localId = "\(room.id)_\(participantEmail)"
                            newParticipant.roomId = room.id
                            newParticipant.email = participantEmail
                            newParticipant.lastReadCommentId = lastReadId
                            newParticipant.lastDeliveredCommentId = lastDeliveredId
                            
                            do {
                                try realm.write {
                                    room.participants.append(newParticipant)
                                }
                            }
                            catch let error as NSError {
                                Qiscus.printLog(text: "WARNING!! - \(error.localizedDescription)")
                            }
                            
                            participantChanged = true
                        }
                        participantString.append(participantEmail)
                    }
                    
                    var index = 0
                    var participantRemoved = false
                    for participant in room.participants{
                        if !participantString.contains(participant.email){
                            try! realm.write {
                                room.participants.remove(at: index)
                                participantRemoved = true
                            }
                            participantChanged = true
                        }
                        index += 1
                    }
                    if participantChanged {
                        let rts = ThreadSafeReference(to: room)
                        DispatchQueue.main.async {
                            let mainRealm = try! Realm(configuration: Qiscus.dbConfiguration)
                            mainRealm.refresh()
                            if Qiscus.chatRooms[id] == nil {
                                if let r = mainRealm.resolve(rts) {
                                    Qiscus.chatRooms[id] = r
                                }
                            }
                            if let cache = QRoom.room(withId: id) {
                                cache.delegate?.room?(didChangeParticipant: cache)
                                QiscusNotification.publish(roomChange: cache, onProperty: .participant)
                            }
                        }
                    }
                    if participantRemoved {
                        room.checkCommentStatus()
                    }
                }
                onSuccess(room)
            }
        }
    }
    internal func createComment(withJSON json:JSON)->QComment{
        let realm = try! Realm(configuration: Qiscus.dbConfiguration)
        let commentId = json["id"].intValue
        let commentUniqueId = json["unique_temp_id"].stringValue
        var commentText = json["message"].stringValue
        let commentSenderName = json["username"].stringValue
        let commentSenderAvatarURL = json["user_avatar_url"].stringValue
        let commentCreatedAt = json["unix_timestamp"].doubleValue
        let commentBeforeId = json["comment_before_id"].intValue
        let senderEmail = json["email"].stringValue
        let commentType = json["type"].stringValue
        
        let commentExtras = "\(json["extras"])"
        let isDeleted = json["is_deleted"].boolValue
        let statusData = json["status"].stringValue
        var commentStatus = QCommentStatus.sent
        
        if isDeleted {
            commentStatus = .deleted
        }else{
            switch statusData {
            case "read" :
                commentStatus = .read
                break
            case "delivered":
                commentStatus = .delivered
                break
            default: break
            }
        }        
        if commentType == "reply" || commentType == "buttons" {
            commentText = json["payload"]["text"].stringValue
        }
        let avatarURL = json["user_avatar_url"].stringValue
        
        let _ = QUser.saveUser(withEmail: senderEmail, fullname: commentSenderName, avatarURL: avatarURL)
        
        let newComment = QComment()
        newComment.uniqueId = commentUniqueId
        newComment.id = commentId
        newComment.roomId = self.id
        newComment.text = commentText
        newComment.senderName = commentSenderName
        newComment.createdAt = commentCreatedAt
        newComment.beforeId = commentBeforeId
        newComment.senderEmail = senderEmail
        newComment.cellPosRaw = QCellPosition.single.rawValue
        newComment.roomAvatar = self.avatarURL
        newComment.roomName = self.name
        newComment.roomTypeRaw = self.typeRaw
        newComment.rawExtra = commentExtras
        newComment.senderAvatarURL = commentSenderAvatarURL
        
        
        if newComment.id > self.lastParticipantsReadId && newComment.id > 0 && commentStatus == .read{
            try! realm.write {
                self.lastParticipantsReadId = newComment.id
                self.lastParticipantsDeliveredId = newComment.id
            }
        }else if newComment.id > self.lastParticipantsDeliveredId  && newComment.id > 0 && commentStatus == .delivered{
            try! realm.write {
                self.lastParticipantsDeliveredId = newComment.id
            }
        }
        newComment.statusRaw = commentStatus.rawValue
        
        switch commentType {
        case "buttons":
            newComment.data = "\(json["payload"]["buttons"])"
            newComment.typeRaw = QCommentType.postback.name()
            break
        case "account_linking":
            newComment.data = "\(json["payload"])"
            newComment.typeRaw = QCommentType.account.name()
            break
        case "reply":
            newComment.data = "\(json["payload"])"
            newComment.typeRaw = QCommentType.reply.name()
            break
        case "system_event":
            newComment.data = "\(json["payload"])"
            newComment.typeRaw = QCommentType.system.name()
            break
        case "carousel":
            newComment.data = "\(json["payload"])"
            newComment.typeRaw = QCommentType.carousel.name()
            break
        case "card":
            newComment.data = "\(json["payload"])"
            newComment.typeRaw = QCommentType.card.name()
            break
        case "contact_person":
            newComment.data = "\(json["payload"])"
            newComment.typeRaw = QCommentType.contact.name()
            break
        case "location":
            newComment.data = "\(json["payload"])"
            newComment.typeRaw = QCommentType.location.name()
            break
        case "button_postback_response" :
            newComment.data = "\(json["payload"])"
            newComment.typeRaw = QCommentType.text.name()
            break
        case "custom":
            newComment.data = "\(json["payload"])"
            newComment.typeRaw = json["payload"]["type"].stringValue
            break
        case "file_attachment":
            newComment.data = "\(json["payload"])"
            let fileURL = json["payload"]["url"].stringValue
            var filename = newComment.fileName(text: fileURL)
            var fileSize = Double(0)
            var filePages = 0
            if let pages = json["payload"]["pages"].int {
                if pages > 0 {
                    filePages = pages
                }
            }
            if let size = json["payload"]["size"].double {
                if size > 0 {
                    fileSize = size 
                }
            }
            
            if let name = json["payload"]["file_name"].string {
                if name != "" {
                    filename = name
                }
            }else if filename.contains("-"){
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
            
            var type = QiscusFileType.file
            if newComment.file == nil {
                let file = QFile()
                file.id = newComment.uniqueId
                file.url = fileURL
                file.senderEmail = newComment.senderEmail
                file.filename = filename
                file.pages = filePages
                file.size = Double(fileSize)
                
                try! realm.write {
                    realm.add(file, update:true)
                }
                type = file.type
            }else{
                try! realm.write {
                    newComment.file!.url = fileURL
                }
                type = newComment.file!.type
            }
            switch type {
            case .image:
                newComment.typeRaw = QCommentType.image.name()
                break
            case .video:
                newComment.typeRaw = QCommentType.video.name()
                break
            case .audio:
                newComment.typeRaw = QCommentType.audio.name()
                break
            case .document:
                newComment.typeRaw = QCommentType.document.name()
                break
            default:
                newComment.typeRaw = QCommentType.file.name()
                break
            }
            break
        case "text":
            if newComment.text.hasPrefix("[file]"){
                var type = QiscusFileType.file
                let fileURL = QFile.getURL(fromString: newComment.text)
                var filename = newComment.fileName(text: fileURL)
                
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
                if newComment.file == nil {
                    let file = QFile()
                    file.id = newComment.uniqueId
                    file.url = fileURL
                    file.filename = filename
                    file.senderEmail = newComment.senderEmail
                    try! realm.write {
                        realm.add(file, update:true)
                    }
                    type = file.type
                }else{
                    try! realm.write {
                        newComment.file!.url = QFile.getURL(fromString: newComment.text)
                    }
                    type = newComment.file!.type
                }
                switch type {
                case .image:
                    newComment.typeRaw = QCommentType.image.name()
                    break
                case .video:
                    newComment.typeRaw = QCommentType.video.name()
                    break
                case .audio:
                    newComment.typeRaw = QCommentType.audio.name()
                    break
                case .document:
                    newComment.typeRaw = QCommentType.document.name()
                    break
                default:
                    newComment.typeRaw = QCommentType.file.name()
                    break
                }
            }else{
                newComment.typeRaw = QCommentType.text.name()
            }
            break
        default:
            newComment.data = "\(json["payload"])"
            newComment.typeRaw = json["payload"]["type"].stringValue
            break
        }
        return newComment
    }
    internal func saveNewComment(fromJSON json:JSON){
        let roomId = self.id
        
        QiscusDBThread.async {
            if let room = QRoom.threadSaveRoom(withId:  roomId){
                let realm = try! Realm(configuration: Qiscus.dbConfiguration)
                realm.refresh()
                let newComment = room.createComment(withJSON: json)
                let commentUniqueId = newComment.uniqueId
                
                if let oldComment = QComment.threadSaveComment(withUniqueId: commentUniqueId) {
                    try! realm.write {
                        oldComment.id = newComment.id
                        oldComment.text = newComment.text
                        oldComment.senderName = newComment.senderName
                        oldComment.createdAt = newComment.createdAt
                        oldComment.beforeId = newComment.beforeId
                        oldComment.roomName = room.name
                    }
                    var status = QCommentStatus.sent
                    if oldComment.id < room.lastParticipantsReadId {
                        status = .read
                    }else if oldComment.id < room.lastParticipantsDeliveredId{
                        status = .delivered
                    }
                    oldComment.updateStatus(status: status)
                }
                else{
                    room.addComment(newComment: newComment)
                }
            }
        }
    }
    
    internal func saveOldComment(fromJSON json:JSON){
        let roomId = self.id
        
        QiscusDBThread.sync {
            autoreleasepool {
                let realm = try! Realm(configuration: Qiscus.dbConfiguration)
                realm.refresh()
                guard let room = QRoom.threadSaveRoom(withId: roomId) else { return }
                let commentUniqueId = json["unique_temp_id"].stringValue
                let newComment = room.createComment(withJSON: json)
                
                if let oldComment = QComment.threadSaveComment(withUniqueId: commentUniqueId) {
                    try! realm.write {
                        oldComment.id = newComment.id
                        oldComment.text = newComment.text
                        oldComment.senderName = newComment.senderName
                        oldComment.senderEmail = newComment.senderEmail
                        oldComment.createdAt = newComment.createdAt
                        oldComment.beforeId = newComment.beforeId
                        oldComment.roomName = room.name
                        oldComment.roomId = room.id
                        oldComment.rawExtra = newComment.rawExtra
                    }
                    if oldComment.statusRaw < QCommentStatus.sent.rawValue {
                        var status = QCommentStatus.sent
                        if oldComment.id < self.lastParticipantsReadId {
                            status = .read
                        }else if oldComment.id < self.lastParticipantsDeliveredId{
                            status = .delivered
                        }
                        oldComment.updateStatus(status: status)
                    }
                }
                else{
                    self.addComment(newComment: newComment, onTop: false)
                }
            }
        }
    }
    internal func syncRoom(){
        let service = QRoomService()
        service.sync(onRoom: self)
    }
    internal func loadMoreComment(){
        let service = QRoomService()
        service.loadMore(onRoom: self)
    }
    
    internal func updateStatus(inComment comment:QComment, status:QCommentStatus){
        comment.updateStatus(status: status)
    }
    
    internal func publishStatus(withStatus status:QCommentStatus){
        let service = QRoomService()
        if !self.isPublicChannel {
            service.publisComentStatus(onRoom: self, status: status)
        }
    }
    internal func getParticipant(withEmail email:String)->QParticipant?{
        let data = self.participants.filter("email == '\(email)'")
        return data.first
    }
    
    internal func getGrouppedCommentsUID(filter:NSPredicate? = nil)->[[String]]{
        let realm = try! Realm(configuration: Qiscus.dbConfiguration)
        var retVal = [[String]]()
        var uidList = [String]()
        var s = 0
        let date = Double(Date().timeIntervalSince1970)
        var prevComment:QComment?
        var group = [String]()
        var count = 0
        func checkPosition(ids:[String]) {
            var n = 0
            for id in ids {
                var position = QCellPosition.middle
                if ids.count > 1 {
                    switch n {
                    case 0 :
                        position = .first
                        break
                    case ids.count - 1 :
                        position = .last
                        break
                    default:
                        position = .middle
                        break
                    }
                }else{
                    position = .single
                }
                n += 1
                if let c = QComment.threadSaveComment(withUniqueId: id){
                    c.updateCellPos(cellPos: position)
                }
            }
        }
        let filteredComments = self.comments(withFilter: filter)
        for comment in filteredComments{
            
            if !comment.isInvalidated {
                if !uidList.contains(comment.uniqueId) {
                    if let prev = prevComment{
                        if prev.date == comment.date && prev.senderEmail == comment.senderEmail && comment.type != .system  {
                            uidList.append(comment.uniqueId)
                            group.append(comment.uniqueId)
                        }else{
                            retVal.append(group)
                            checkPosition(ids: group)
                            if !comment.isInvalidated {
                                group = [String]()
                                group.append(comment.uniqueId)
                                uidList.append(comment.uniqueId)
                            }
                        }
                    }else{
                        group.append(comment.uniqueId)
                        uidList.append(comment.uniqueId)
                    }
                    if count == filteredComments.count - 1  {
                        retVal.append(group)
                        checkPosition(ids: group)
                    }else{
                        prevComment = comment
                    }
                }
            }
            count += 1
        }
        
        return retVal
    }
}

