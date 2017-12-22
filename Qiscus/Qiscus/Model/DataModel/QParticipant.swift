//
//  QParticipant.swift
//  Example
//
//  Created by Ahmad Athaullah on 7/5/17.
//  Copyright © 2017 Ahmad Athaullah. All rights reserved.
//

import Foundation
import RealmSwift
@objc public protocol QParticipantDelegate {
    func participant(didChange participant:QParticipant)
}
public class QParticipant:Object {
    static var cache = [String : QParticipant]()
    public dynamic var localId:String = ""
    public dynamic var roomId:String = ""
    public dynamic var email:String = ""
    public dynamic var lastReadCommentId:Int = 0
    public dynamic var lastDeliveredCommentId:Int = 0
    
    public var delegate:QParticipantDelegate? = nil
    
    override public static func ignoredProperties() -> [String] {
        return ["delegate"]
    }
    
    // MARK: - Getter variable
    public var user:QUser? {
        get{
            return QUser.user(withEmail: self.email)
        }
    }

    internal func updateLastDeliveredId(commentId:Int){
        if !self.isInvalidated {
            let roomId = self.roomId
            let email = self.email
            QiscusDBThread.async {
                if let room = QRoom.threadSaveRoom(withId: roomId){
                    if room.lastDeliveredCommentId >= commentId {return}
                    
                    if let participant = room.participant(withEmail: email){
                        let realm = Qiscus.realm()
                        if room.isInvalidated {return}
                        if participant.lastDeliveredCommentId < commentId {
                            try! realm.write {
                                participant.lastDeliveredCommentId = commentId
                            }
                        }
                        var lastDeliveredId = 0
                        for p in room.participants {
                            if p.email != QiscusMe.shared.email {
                                if lastDeliveredId == 0 {
                                    lastDeliveredId = p.lastDeliveredCommentId
                                }
                                else if p.lastDeliveredCommentId < lastDeliveredId {
                                    lastDeliveredId = p.lastDeliveredCommentId
                                }
                            }
                        }
                        if room.lastDeliveredCommentId >= lastDeliveredId {return}
                        try! realm.write {
                            room.lastDeliveredCommentId = lastDeliveredId
                        }
                        
                        let data = room.comments.filter("id != 0 AND id <= \(lastDeliveredId) AND statusRaw < \(QCommentStatus.delivered.rawValue) AND statusRaw != \(QCommentStatus.sending.rawValue) AND statusRaw != \(QCommentStatus.pending.rawValue)")
                        for c in data {
                            c.updateStatus(status: .delivered)
                            if c.id == room.lastCommentId {
                                try! realm.write {
                                    room.lastCommentStatusRaw = QCommentStatus.delivered.rawValue
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    public func updateLastReadId(commentId:Int){
        if !self.isInvalidated {
            let roomId = self.roomId
            let email = self.email
            QiscusDBThread.async {
                if let room = QRoom.threadSaveRoom(withId: roomId){
                    if room.lastReadCommentId >= commentId {return}
                    
                    if let participant = room.participant(withEmail: email){
                        let realm = Qiscus.realm()
                        if participant.lastReadCommentId < commentId {
                            try! realm.write {
                                participant.lastReadCommentId = commentId
                            }
                        }
                        if participant.lastDeliveredCommentId < commentId {
                            try! realm.write {
                                participant.lastDeliveredCommentId = commentId
                            }
                        }
                        var lastDelivered = 0
                        var lastRead = 0
                        for p in room.participants {
                            if p.email != QiscusMe.shared.email {
                                if lastDelivered == 0 {
                                    lastDelivered = p.lastDeliveredCommentId
                                }else if p.lastDeliveredCommentId < lastDelivered {
                                    lastDelivered = p.lastDeliveredCommentId
                                }
                                if lastRead == 0 {
                                    lastRead = p.lastReadCommentId
                                }else if p.lastReadCommentId < lastRead {
                                    lastRead = p.lastReadCommentId
                                }
                            }
                        }
                        if room.lastDeliveredCommentId < lastDelivered {
                            try! realm.write {
                                room.lastDeliveredCommentId = lastDelivered
                            }
                            let data = room.comments.filter("id != 0 AND id <= \(lastDelivered) AND statusRaw < \(QCommentStatus.delivered.rawValue) AND statusRaw != \(QCommentStatus.sending.rawValue) AND statusRaw != \(QCommentStatus.pending.rawValue)")
                            for c in data {
                                c.updateStatus(status: .delivered)
                                if c.id == room.lastCommentId {
                                    if room.lastCommentStatusRaw != QCommentStatus.delivered.rawValue{
                                        try! realm.write {
                                            room.lastCommentStatusRaw = QCommentStatus.delivered.rawValue
                                        }
                                        let rId = room.id
                                        DispatchQueue.main.async {
                                            if let r = QRoom.room(withId: rId){
                                                QiscusNotification.publish(roomChange: r, onProperty: .lastComment)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        if room.lastReadCommentId < lastRead {
                            try! realm.write {
                                room.lastReadCommentId = lastRead
                            }
                            let data = room.comments.filter("id != 0 AND id <= \(lastRead) AND statusRaw < \(QCommentStatus.read.rawValue) AND statusRaw != \(QCommentStatus.sending.rawValue) AND statusRaw != \(QCommentStatus.pending.rawValue)")
                            for c in data {
                                c.updateStatus(status: .read)
                                if c.id == room.lastCommentId {
                                    if room.lastCommentStatusRaw != QCommentStatus.read.rawValue {
                                        try! realm.write {
                                            room.lastCommentStatusRaw = QCommentStatus.read.rawValue
                                        }
                                        let rId = room.id
                                        DispatchQueue.main.async {
                                            if let r = QRoom.room(withId: rId){
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
        }
    }
    public class func all(withEmail email:String)->[QParticipant]{
        var participants = [QParticipant]()
        let realm = Qiscus.realm()
        let data =  realm.objects(QParticipant.self).filter("email == '\(email)'")
        for participant in data {
            participants.append(participant)
        }
        return participants
    }
    public class func updateLastDeliveredId(forUser email:String, commentId:Int){
        let realm = Qiscus.realm()
        let data =  realm.objects(QParticipant.self).filter("email == '\(email)'")
        
        for participant in data {
            participant.updateLastDeliveredId(commentId: commentId)
        }
    }
    public class func all() -> [QParticipant]{
        let realm = Qiscus.realm()
        let data = realm.objects(QParticipant.self)
        
        if data.count > 0 {
            return Array(data)
        }else{
            return [QParticipant]()
        }
    }
    internal class func cacheAll(){
        let participants = QParticipant.all()
        for participant in participants{
            if QParticipant.cache[participant.localId] == nil {
                QParticipant.cache[participant.localId] = participant
            }
        }
    }
}
