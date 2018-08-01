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
        let realm = try! Realm(configuration: Qiscus.dbConfiguration)
        realm.refresh()
        let data = realm.objects(QRoom.self).sorted(byKeyPath: "lastCommentCreatedAt", ascending: false)
        
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
            if let cache = Qiscus.chatRooms[id] {
                if !cache.isInvalidated {
                    return cache
                }else{
                    Qiscus.chatRooms[id] = nil
                }
            }
            let realm = try! Realm(configuration: Qiscus.dbConfiguration)
            realm.refresh()
            let rooms = realm.objects(QRoom.self).filter("id == '\(id)'")
            if let room = rooms.first {
                if !room.isInvalidated {
                    let room = rooms.first!
                    Qiscus.chatRooms[room.id] = room
                    return room
                }
            }
        }
        return nil
    }
    internal class func getRoom(withUniqueId uniqueId:String) -> QRoom? {
        let realm = try! Realm(configuration: Qiscus.dbConfiguration)
        realm.refresh()
        let data =  realm.objects(QRoom.self).filter("uniqueId == '\(uniqueId)'")
        
        if data.count > 0{
            let room = data.first!
            if let cachedRoom = Qiscus.chatRooms[room.id] {
                return cachedRoom
            }else{
                Qiscus.chatRooms[room.id] = room
                Qiscus.sharedInstance.RealtimeConnect()
                return room
            }
        }
        return nil
    }
    internal class func getSingleRoom(withUser user:String) -> QRoom? {
        if Thread.isMainThread {
            let realm = try! Realm(configuration: Qiscus.dbConfiguration)
            realm.refresh()
            let data =  realm.objects(QRoom.self).filter("singleUser == '\(user)'")
            
            if data.count > 0{
                let room = data.first!
                if let cachedRoom = Qiscus.chatRooms[room.id] {
                    return cachedRoom
                }else{
                    Qiscus.chatRooms[room.id] = room
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
            let realm = try! Realm(configuration: Qiscus.dbConfiguration)
            realm.refresh()
            
            let roomId = "\(json["id"])"
            let option = json["options"].stringValue
            let roomUniqueId = json["unique_id"].stringValue
            let distinctId = json["distinct_id"].stringValue
            let chatTypeRaw = json["chat_type"].stringValue
            let roomName = json["room_name"].stringValue
            let roomTotalParticipant = json["room_total_participants"].intValue
            let roomAvatar = json["avatar_url"].stringValue
            let unread = json["unread_count"].intValue
            let isPublicChannel = json["is_public_channel"].boolValue
            
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
                            if savedUser.email != Qiscus.client.email {
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
                    var index = room.participants.count - 1
                    var participantRemoved = false
                    for participant in room.participants.reversed(){
                        if !participantString.contains(participant.email){
                            try! realm.write {
                                room.participants.remove(at: index)
                            }
                            participantRemoved = true
                        }
                        index -= 1
                    }
                    if participantRemoved {
                        let rId = room.id
                        room.checkCommentStatus()
                        let rts = ThreadSafeReference(to:room)
                        DispatchQueue.main.async {
                            let mainRealm = try! Realm(configuration: Qiscus.dbConfiguration)
                            mainRealm.refresh()
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
                savedRoom.updateTotalParticipant(count: roomTotalParticipant)
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
                room.roomTotalParticipant = roomTotalParticipant
                room.isPublicChannel = isPublicChannel
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
                let realm = try! Realm(configuration: Qiscus.dbConfiguration)
                realm.refresh()
                r.unsubscribeRoomChannel()
                for comment in r.comments{
                    QComment.cache[comment.uniqueId] = nil
                    try! realm.write {
                        realm.delete(comment)
                    }
                }
                try! realm.write {
                    r.rawComments.removeAll()
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
        let realm = try! Realm(configuration: Qiscus.dbConfiguration)
        realm.refresh()
        let rooms = realm.objects(QRoom.self).filter("id == '\(id)'")
        if rooms.count > 0 {
            return rooms.first!
        }
        return nil
    }
}

