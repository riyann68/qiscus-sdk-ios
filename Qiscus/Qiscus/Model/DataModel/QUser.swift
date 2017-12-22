//
//  QUser.swift
//  Example
//
//  Created by Ahmad Athaullah on 7/5/17.
//  Copyright © 2017 Ahmad Athaullah. All rights reserved.
//

import Foundation
import RealmSwift

@objc public protocol QUserDelegate {
    @objc optional func user(didChangeName fullname:String)
    @objc optional func user(didChangeAvatarURL avatarURL:String)
    @objc optional func user(didChangeAvatar avatar:UIImage)
    @objc optional func user(didChangeLastSeen lastSeen:Double)
}
@objc public enum QUserPresence:Int {
    case offline,online
}
public class QUser:Object {
    static var cache = [String: QUser]()
    
    public dynamic var email:String = ""
    public dynamic var id:Int = 0
    public dynamic var avatarURL:String = ""
    public dynamic var storedName:String = ""
    public dynamic var definedName:String = ""
    public dynamic var lastSeen:Double = 0
    internal dynamic var rawPresence:Int = 0
    internal dynamic var avatarData:Data?
    
    public var cachedAvatar:UIImage?
    
    override public static func primaryKey() -> String? {
        return "email"
    }
    
    
    public var fullname:String{
        if self.definedName != "" {
            return self.definedName
        }else{
            return self.storedName
        }
    }
    public var presence:QUserPresence {
        get{
            return QUserPresence(rawValue: self.rawPresence)!
        }
    }
    public var avatar:UIImage?{
        get{
            if let data = self.avatarData {
                if let image = UIImage(data: data) {
                    return image
                }
            }
            return nil
        }
    }
    public var delegate:QUserDelegate?
    
    public var lastSeenString:String{
        get{
            if self.lastSeen == 0 {
                return ""
            }else{
                var result = ""
                let date = Date(timeIntervalSince1970: self.lastSeen)
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "d MMMM yyyy"
                let dateString = dateFormatter.string(from: date)
                
                let timeFormatter = DateFormatter()
                timeFormatter.dateFormat = "h:mm a"
                let timeString = timeFormatter.string(from: date)
                
                let now = Date()

                let secondDiff = now.offsetFromInSecond(date: date)
                let minuteDiff = Int(secondDiff/60)
                let hourDiff = Int(minuteDiff/60)
                
                if secondDiff < 60 {
                    result = "few seconds ago"
                }
                else if minuteDiff == 1 {
                    result = "a minute ago"
                }
                else if minuteDiff < 60 {
                    result = "\(Int(secondDiff/60)) minute ago"
                }else if hourDiff == 1{
                    result = "an hour ago"
                }else if hourDiff < 6 {
                    result = "\(hourDiff) hours ago"
                }
                else if date.isToday{
                    result = "today at \(timeString)"
                }
                else if date.isYesterday{
                    result = "yesterday at \(timeString)"
                }
                else{
                    result = "\(dateString) at \(timeString)"
                }
                
                return result
            }
        }
    }
    
    // MARK: - Unstored properties
    override public static func ignoredProperties() -> [String] {
        return ["cachedAvatar","delegate"]
    }
    public class func saveUser(withEmail email:String, id:Int? = nil ,fullname:String? = nil, avatarURL:String? = nil, lastSeen:Double? = nil)->QUser{
        guard let realm = Qiscus.realm() else{ return QUser() }
        var user = QUser()
        if let savedUser = QUser.getUser(email: email){
            user = savedUser
            if fullname != nil  && fullname! != user.storedName {
                try! realm.write {
                    user.storedName = fullname!
                }
                if user.definedName != "" {
                    DispatchQueue.main.async {
                        if let u = QUser.user(withEmail: email){
                            u.delegate?.user?(didChangeName: fullname!)
                        }
                    }
                }
            }
            if id != nil {
                try! realm.write {
                    user.id = id!
                }
            }
            if avatarURL != nil && avatarURL! != user.avatarURL{
                try! realm.write {
                    user.avatarURL = avatarURL!
                }
                user.downloadAvatar()
                
                DispatchQueue.main.async {
                    if let u = QUser.user(withEmail: email){
                        u.cachedAvatar = nil
                        u.delegate?.user?(didChangeAvatarURL: avatarURL!)
                        QiscusNotification.publish(userAvatarChange: u)
                    }
                }
            }
            if lastSeen != nil && lastSeen! > user.lastSeen{
                try! realm.write {
                    user.lastSeen = lastSeen!
                }
                DispatchQueue.main.async {
                    if let u = QUser.user(withEmail: email){
                        u.delegate?.user?(didChangeLastSeen: lastSeen!)
                    }
                }
            }
        }else{
            user.email = email
            if fullname != nil {
                user.storedName = fullname!
            }
            if avatarURL != nil {
                user.avatarURL = avatarURL!
            }
            if lastSeen != nil {
                user.lastSeen = lastSeen!
            }
            if id != nil {
                user.id = id!
            }
            try! realm.write {
                realm.add(user, update:true)
            }
            user.downloadAvatar()
        }
        
        return user
    }
    internal class func getUser(email:String) -> QUser? {
        guard let realm = Qiscus.realm() else{ return nil }
        let data = realm.objects(QUser.self).filter("email == '\(email)'")
        if data.count > 0 {
            let user = data.first!
            return user
        }
        return nil
    }
    public class func user(withEmail email:String) -> QUser? {
        guard let realm = Qiscus.realm() else{ return nil }
        if let cachedUser = QUser.cache[email] {
            if !cachedUser.isInvalidated {
                return cachedUser
            }
        }
        let data = realm.objects(QUser.self).filter("email == '\(email)'")
        if data.count > 0 {
            let user = data.first!
            user.cacheObject()
            user.subscribeRealtimeStatus()
            return user
        }
        return nil
    }
    public func subscribeRealtimeStatus(){
        let channel = "u/\(self.email)/s"
        Qiscus.shared.mqtt?.subscribe(channel)
    }
    public func updatePresence(presence:QUserPresence){
        let email = self.email
        QiscusDBThread.async {
            if let user = QUser.getUser(email: email){
                if user.isInvalidated { return }
                guard let realm = Qiscus.realm() else{ return }
                try! realm.write {
                    user.rawPresence = presence.rawValue
                }
                DispatchQueue.main.sync {
                    if let updatedUser = QUser.user(withEmail: email){
                        QiscusNotification.publish(userPresence: updatedUser)
                    }
                }
            }
        }
    }
    public func updateLastSeen(lastSeen:Double){
        let email = self.email
        QiscusDBThread.async {
            if let user = QUser.getUser(email: email){
                guard let realm = Qiscus.realm() else{ return }
                if lastSeen > user.lastSeen {
                    try! realm.write {
                        user.lastSeen = lastSeen
                    }
                    DispatchQueue.main.async {
                        if let room = QRoom.room(withUser: email) {
                            if let mainUser = QUser.user(withEmail: email){
                                room.delegate?.room?(didChangeUser: room, user: mainUser)
                            }
                        }
                    }
                }
            }
        }
    }
    public func setName(name:String){
        guard let realm = Qiscus.realm() else{ return }
        if name != self.definedName {
            try! realm.write {
                self.definedName = name
            }
            self.delegate?.user?(didChangeName: name)
        }
    }
    public class func all() -> [QUser]{
        guard let realm = Qiscus.realm() else{ return [QUser]() }
        let data = realm.objects(QUser.self)
        
        if data.count > 0 {
            return Array(data)
        }else{
            return [QUser]()
        }
    }
    internal class func cacheAll(){
        let users = QUser.all()
        for user in users{
            if QUser.cache[user.email] == nil {
                QUser.cache[user.email] = user
            }
        }
    }
    public func clearAvatar(){
        guard let realm = Qiscus.realm() else{ return }
        try! realm.write {
            self.avatarData = nil
        }
    }
    internal func cacheObject(){
        if Thread.isMainThread {
            if QUser.cache[self.email] == nil {
                QUser.cache[self.email] = self
            }
        }
    }
    public func downloadAvatar(){
        let email = self.email
        let url = self.avatarURL.replacingOccurrences(of: "/upload/", with: "/upload/c_thumb,g_center,h_100,w_100/")
        if !QChatService.downloadTasks.contains(url){
            QChatService.downloadImage(url: url, onSuccess: { (data) in
                QiscusDBThread.async {
                    if let user = QUser.getUser(email: email){
                        guard let realm = Qiscus.realm() else{ return }
                        try! realm.write {
                            user.avatarData = data
                        }
                        DispatchQueue.main.sync {
                            if let mainUser = QUser.user(withEmail: email){
                                QiscusNotification.publish(userAvatarChange: mainUser)
                            }
                        }
                    }
                }
            }, onFailed: { (error) in
                Qiscus.printLog(text: error)
            })
        }
    }
}
