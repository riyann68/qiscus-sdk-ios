//
//  QRoom+InternalClassMethod.swift
//  Qiscus
//
//  Created by Ahmad Athaullah on 21/11/17.
//  Copyright © 2017 Ahmad Athaullah. All rights reserved.
//

import RealmSwift
import SwiftyJSON

internal extension QRoom {
    internal class func allRoom()->[QRoom]{
        guard let realm = Qiscus.realm() else{ return [QRoom]() }
        let data = realm.objects(QRoom.self).sorted(byKeyPath: "pinned", ascending: false).sorted(byKeyPath: "lastCommentCreatedAt", ascending: false)
        
        if data.count > 0 {
            return Array(data)
        }else{
            return [QRoom]()
        }
    }
    internal class func unpinAllRoom(){
        let data = QRoom.allRoom()
        for room in data {
            room.unpin()
        }
    }
    internal class func getRoom(withId id:String) -> QRoom?{
        if Thread.isMainThread {
            guard let realm = Qiscus.realm() else{ return nil }
            if let cache = Qiscus.chatRooms[id] {
                if !cache.isInvalidated {
                    cache.subscribeRoomChannel()
                    return cache
                }else{
                    Qiscus.chatRooms[id] = nil
                }
            }
            
            let rooms = realm.objects(QRoom.self).filter("id == '\(id)'")
            if rooms.count > 0 {
                let room = rooms.first!
                room.resetRoomComment()
                Qiscus.chatRooms[room.id] = room
                if Qiscus.shared.chatViews[room.id] ==  nil{
                    let chatView = QiscusChatVC()
                    chatView.chatRoom = Qiscus.chatRooms[room.id]
                    Qiscus.shared.chatViews[room.id] = chatView
                }
                room.subscribeRoomChannel()
                return room
            }
        }
        return nil
    }
    internal class func getRoom(withUniqueId uniqueId:String) -> QRoom? {
        guard let realm = Qiscus.realm() else{ return nil }
        let data =  realm.objects(QRoom.self).filter("uniqueId == '\(uniqueId)'")
        
        if data.count > 0{
            let room = data.first!
            if let cachedRoom = Qiscus.chatRooms[room.id] {
                return cachedRoom
            }else{
                room.resetRoomComment()
                Qiscus.chatRooms[room.id] = room
                if Qiscus.shared.chatViews[room.id] ==  nil{
                    let chatView = QiscusChatVC()
                    chatView.chatRoom = Qiscus.chatRooms[room.id]
                    Qiscus.shared.chatViews[room.id] = chatView
                }
                Qiscus.sharedInstance.RealtimeConnect()
                return room
            }
        }
        return nil
    }
    internal class func getSingleRoom(withUser user:String) -> QRoom? {
        if Thread.isMainThread {
            guard let realm = Qiscus.realm() else{ return nil }
            let data =  realm.objects(QRoom.self).filter("singleUser == '\(user)'")
            
            if data.count > 0{
                let room = data.first!
                if let cachedRoom = Qiscus.chatRooms[room.id] {
                    return cachedRoom
                }else{
                    room.resetRoomComment()
                    Qiscus.chatRooms[room.id] = room
                    if Qiscus.shared.chatViews[room.id] ==  nil{
                        let chatView = QiscusChatVC()
                        chatView.chatRoom = Qiscus.chatRooms[room.id]
                        Qiscus.shared.chatViews[room.id] = chatView
                    }
                    Qiscus.sharedInstance.RealtimeConnect()
                    return room
                }
            }
        }
        return nil
    }
    internal class func addNewRoom(json:JSON)->QRoom{
        let room = QRoom()
        
        if json["id"] != JSON.null {
            guard let realm = Qiscus.realm() else{ return QRoom() }
            
            let roomId = "\(json["id"])"
            let option = json["options"].stringValue
            let roomUniqueId = json["unique_id"].stringValue
            let distinctId = json["distinct_id"].stringValue
            let chatTypeRaw = json["chat_type"].stringValue
            let roomName = json["room_name"].stringValue
            let roomAvatar = json["avatar_url"].stringValue
            let unread = json["unread_count"].intValue
            
            var chatType = QRoomType.single
            if chatTypeRaw != "single" {
                chatType = .group
            }
            var lastComment:QComment?
            
            if json["last_comment"] != JSON.null {
                let commentData = json["last_comment"]
                lastComment = QComment.tempComment(fromJSON: commentData)
            }
            
            func cache(room:QRoom){
                DispatchQueue.main.async {
                    if let r = QRoom.getRoom(withId: roomId){
                        if let roomDelegate = QiscusCommentClient.shared.roomDelegate {
                            if !r.isInvalidated {
                                roomDelegate.didFinishLoadRoom(onRoom: r)
                            }
                        }
                    }
                }
            }
            
            func checkParticipants(room:QRoom){
                if let participants = json["participants"].array{
                    var participantString = [String]()
                    for participantJSON in participants {
                        let participantEmail = participantJSON["email"].stringValue
                        let fullname = participantJSON["username"].stringValue
                        let avatarURL = participantJSON["avatar_url"].stringValue
                        let lastReadId = participantJSON["last_comment_read_id"].intValue
                        let lastDeliveredId = participantJSON["last_comment_received_id"].intValue
                        
                        
                        let savedUser = QUser.saveUser(withEmail: participantEmail, fullname: fullname, avatarURL: avatarURL)
                        
                        if room.type == .single {
                            if savedUser.email != QiscusMe.shared.email {
                                try! realm.write {
                                    room.singleUser = participantEmail
                                }
                            }
                        }
                        let roomPariticipant = room.participants.filter("email == '\(participantEmail)'")
                        
                        if roomPariticipant.count == 0{
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
                            
                        }else{
                            let selectedParticipant = roomPariticipant.first!
                            try! realm.write {
                                selectedParticipant.email = participantEmail
                                selectedParticipant.lastReadCommentId = lastReadId
                                selectedParticipant.lastDeliveredCommentId = lastDeliveredId
                            }
                        }
                        participantString.append(participantEmail)
                    }
                    room.updateCommentStatus()
                    var index = 0
                    var participantRemoved = false
                    for participant in room.participants{
                        if !participantString.contains(participant.email){
                            room.participants.remove(at: index)
                            participantRemoved = true
                        }
                        index += 1
                    }
                    if participantRemoved {
                        let rId = room.id
                        room.checkCommentStatus()
                        let rts = ThreadSafeReference(to:room)
                        DispatchQueue.main.async {
                            guard let mainRealm = Qiscus.realm() else{ return }
                            if Qiscus.chatRooms[rId] == nil {
                                if let r = mainRealm.resolve(rts) {
                                    Qiscus.chatRooms[rId] = r
                                }
                            }
                            if let r = QRoom.room(withId: rId){
                                QiscusNotification.publish(roomChange: r, onProperty: .participant)
                            }
                        }
                    }
                }
            }
            
            if let savedRoom = QRoom.threadSaveRoom(withId: roomId){
                if let c = lastComment {
                    savedRoom.updateLastComentInfo(comment: c)
                }
                savedRoom.update(avatarURL: roomAvatar)
                savedRoom.update(name: roomName)
                savedRoom.updateUnreadCommentCount(count: unread)
                if option != "" && option != "<null>" && savedRoom.data != option{
                    try! realm.write {
                        savedRoom.data = option
                    }
                }
                if distinctId != savedRoom.distinctId {
                    try! realm.write {
                        savedRoom.distinctId = distinctId
                    }
                }
                checkParticipants(room: savedRoom)
                cache(room: savedRoom)
                
                return savedRoom
            }else{
                room.id = roomId
                if option != "" && option != "<null>" {
                    room.data = option
                }
                room.uniqueId = roomUniqueId
                room.typeRaw = chatType.rawValue
                room.distinctId = distinctId
                room.storedName = roomName
                room.storedAvatarURL = roomAvatar
                if let c = lastComment {
                    room.lastCommentId = c.id
                    room.lastCommentText = c.text
                    room.lastCommentUniqueId = c.uniqueId
                    room.lastCommentBeforeId = c.beforeId
                    room.lastCommentCreatedAt = c.createdAt
                    room.lastCommentSenderEmail = c.senderEmail
                    room.lastCommentSenderName = c.senderName
                    room.lastCommentStatusRaw = c.statusRaw
                    room.lastCommentTypeRaw = c.typeRaw
                    room.lastCommentData = c.data
                }
                
                try! realm.write {
                    realm.add(room, update: true)
                }
                checkParticipants(room: room)
                cache(room: room)
                
                return room
            }
        }
        
        return room
    }
    internal class func removeRoom(room:QRoom){
        let roomId = room.id
        QiscusDBThread.sync {autoreleasepool{
            if let r = QRoom.threadSaveRoom(withId: roomId){
                guard let realm = Qiscus.realm() else{ return }
                r.unsubscribeRoomChannel()
                for comment in r.comments{
                    QComment.cache[comment.uniqueId] = nil
                    try! realm.write {
                        realm.delete(comment)
                    }
                }
                try! realm.write {
                    r.comments.removeAll()
                }
                for participant in r.participants {
                    if !participant.isInvalidated {
                        QParticipant.cache[participant.localId] = nil
                        try! realm.write {
                            realm.delete(participant)
                        }
                    }
                }
                try! realm.write {
                    realm.delete(r)
                }
            }
        }}
    }
    
    internal class func cacheAll(){
        let rooms = QRoom.all()
        for room in rooms{
            room.cache()
        }
    }
    internal class func threadSaveRoom(withId id:String) -> QRoom? {
        guard let realm = Qiscus.realm() else{ return nil }
        let rooms = realm.objects(QRoom.self).filter("id == '\(id)'")
        if rooms.count > 0 {
            return rooms.first!
        }
        return nil
    }
}

