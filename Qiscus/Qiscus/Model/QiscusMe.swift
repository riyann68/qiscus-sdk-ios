//
//  QiscusMe.swift
//  QiscusSDK
//
//  Created by Ahmad Athaullah on 9/8/16.
//  Copyright © 2016 Ahmad Athaullah. All rights reserved.
//

import UIKit
import SwiftyJSON

open class QiscusMe: NSObject {
    
    public static var inBackgroundSync:Bool{
        set{
            let userData = UserDefaults.standard
            userData.set(inBackgroundSync, forKey: "qiscus_in_backgroundSync")
        }
        get{
            let userData = UserDefaults.standard
            if let inBackgroundSync = userData.value(forKey: "qiscus_in_backgroundSync") as? Bool {
                return inBackgroundSync
            }
            return false
        }
    }
    public static var needBackgroundSync:Bool{
        set{
            let userData = UserDefaults.standard
            userData.set(needBackgroundSync, forKey: "qiscus_needBackgroundSync")
        }
        get{
            let userData = UserDefaults.standard
            if let needBackgroundSync = userData.value(forKey: "qiscus_needBackgroundSync") as? Bool {
                return needBackgroundSync
            }
            return false
        }
    }
    
    open static let shared = QiscusMe()
    
    let userData = UserDefaults.standard
    
    open class var isLoggedIn:Bool {
        get{
            return (QiscusMe.shared.token != "")
        }
    }
    open class var canReconnect:Bool{
        get{
            return (QiscusMe.shared.userKey != "" && QiscusMe.shared.email != "")
        }
    }
    public var id = 0
    public var email = ""
    public var userName = ""
    public var avatarUrl = ""
    public var rtKey = ""
    public var token = ""
    public var userKey = ""
    public var appId = ""
    public var baseUrl = ""
    
    public var realtimeServer:String = "mqtt.qiscus.com"
    public var realtimePort:Int = 1883
    public var realtimeSSL:Bool = false
    
    public var lastCommentId = Int(0)
    public var lastKnownCommentId = Int(0)
    
    public var paramEmail = ""
    public var paramPass = ""
    public var paramUsername = ""
    public var paramAvatar = ""
    
    open var deviceToken:String = ""{
        didSet{
            let userData = UserDefaults.standard
            userData.set(deviceToken, forKey: "qiscus_device_token")
        }
    }
    
    fileprivate override init(){
        
        if let userId = userData.value(forKey: "qiscus_id") as? Int {
            self.id = userId
        }
        if let userEmail = userData.value(forKey: "qiscus_email") as? String {
            self.email = userEmail
        }
        if let appId = userData.value(forKey: "qiscus_appId") as? String {
            self.appId = appId
        }
        if let realtimeServer = userData.value(forKey: "qiscus_realtimeServer") as? String{
            self.realtimeServer = realtimeServer
        }
        if let realtimePort = userData.value(forKey: "qiscus_realtimePort") as? Int{
            self.realtimePort = realtimePort
        }
        if let realtimeSSL = userData.value(forKey: "qiscus_realtimeSSL") as? Bool{
            self.realtimeSSL = realtimeSSL
        }
        if let name = userData.value(forKey: "qiscus_username") as? String {
            self.userName = name
        }
        if let avatar = userData.value(forKey: "qiscus_avatar_url") as? String {
            self.avatarUrl = avatar
        }
        if let key = userData.value(forKey: "qiscus_rt_key") as? String {
            self.rtKey = key
        }
        if let userToken = userData.value(forKey: "qiscus_token") as? String {
            self.token = userToken
        }
        if let key = userData.value(forKey: "qiscus_user_key") as? String{
            self.userKey = key
        }
        if let url = userData.value(forKey: "qiscus_base_url") as? String{
            self.baseUrl = url
        }
        if let lastComment = userData.value(forKey: "qiscus_lastComment_id") as? Int{
            self.lastCommentId = lastComment
        }
        if let lastComment = userData.value(forKey: "qiscus_lastKnownComment_id") as? Int{
            self.lastKnownCommentId = lastComment
        }
        if let dToken = userData.value(forKey: "qiscus_device_token") as? String{
            self.deviceToken = dToken
        }
        if let paramEmail = userData.value(forKey: "qiscus_param_email") as? String{
            self.paramEmail = paramEmail
        }
        if let paramPass = userData.value(forKey: "qiscus_param_pass") as? String{
            self.paramPass = paramPass
        }
        if let paramUsername = userData.value(forKey: "qiscus_param_username") as? String{
            self.paramUsername = paramUsername
        }
        if let paramAvatar = userData.value(forKey: "qiscus_param_avatar") as? String{
            self.paramAvatar = paramAvatar
        }
    }
    
    open class func saveData(fromJson json:JSON, reconnect:Bool = false)->QiscusMe{
        Qiscus.printLog(text: "jsonFron saveData: \(json)")
        QiscusMe.shared.id = json["id"].intValue
        QiscusMe.shared.email = json["email"].stringValue
        QiscusMe.shared.userName = json["username"].stringValue
        QiscusMe.shared.avatarUrl = json["avatar"].stringValue
        QiscusMe.shared.rtKey = json["rtKey"].stringValue
        QiscusMe.shared.token = json["token"].stringValue
        
        QiscusMe.shared.userData.set(json["id"].intValue, forKey: "qiscus_id")
        QiscusMe.shared.userData.set(json["email"].stringValue, forKey: "qiscus_email")
        QiscusMe.shared.userData.set(json["username"].stringValue, forKey: "qiscus_username")
        QiscusMe.shared.userData.set(json["avatar"].stringValue, forKey: "qiscus_avatar_url")
        QiscusMe.shared.userData.set(json["rtKey"].stringValue, forKey: "qiscus_rt_key")
        QiscusMe.shared.userData.set(json["token"].stringValue, forKey: "qiscus_token")
        
        if !reconnect {
            QiscusMe.shared.userData.set(json["last_comment_id"].intValue, forKey: "qiscus_lastComment_id")
            QiscusMe.shared.userData.set(json["last_comment_id"].intValue, forKey: "qiscus_lastKnownComment_id")
        }else{
            if json["last_comment_id"].intValue > QiscusMe.shared.lastCommentId {
                Qiscus.sync()
            }
        }
        if let lastComment = QiscusMe.shared.userData.value(forKey: "qiscus_lastComment_id") as? Int{
            QiscusMe.shared.lastCommentId = lastComment
            if lastComment == 0 {
                QiscusMe.shared.lastCommentId = json["last_comment_id"].intValue
                QiscusMe.shared.userData.set(json["last_comment_id"].intValue, forKey: "qiscus_lastComment_id")
                QiscusMe.shared.userData.set(json["last_comment_id"].intValue, forKey: "qiscus_lastKnownComment_id")
            }
        }else{
            QiscusMe.shared.lastCommentId = json["last_comment_id"].intValue
            QiscusMe.shared.userData.set(json["last_comment_id"].intValue, forKey: "qiscus_lastComment_id")
            QiscusMe.shared.userData.set(json["last_comment_id"].intValue, forKey: "qiscus_lastKnownComment_id")
        }
        if let lastComment = QiscusMe.shared.userData.value(forKey: "qiscus_lastKnownComment_id") as? Int{
            QiscusMe.shared.lastKnownCommentId = lastComment
        }
        return QiscusMe.shared
    }
    public class func updateLastCommentId(commentId:Int){
        if QiscusMe.shared.lastCommentId < commentId {
            QiscusMe.shared.lastCommentId = commentId
            QiscusMe.shared.userData.set(commentId, forKey: "qiscus_lastComment_id")
        }
        if QiscusMe.shared.lastKnownCommentId < commentId {
            QiscusMe.shared.lastKnownCommentId = commentId
            QiscusMe.shared.userData.set(commentId, forKey: "qiscus_lastKnownComment_id")
        }
        
    }
    public class func updateLastKnownCommentId(commentId:Int){
        if QiscusMe.shared.lastKnownCommentId < commentId {
            QiscusMe.shared.lastKnownCommentId = commentId
            QiscusMe.shared.userData.set(commentId, forKey: "qiscus_lastKnownComment_id")
        }
    }
    open class func clear(){
        QiscusMe.shared.id = 0
        QiscusMe.shared.email = ""
        QiscusMe.shared.userName = ""
        QiscusMe.shared.avatarUrl = ""
        QiscusMe.shared.rtKey = ""
        QiscusMe.shared.token = ""
        QiscusMe.shared.lastCommentId = 0
        
        QiscusMe.shared.userData.removeObject(forKey: "qiscus_id")
        QiscusMe.shared.userData.removeObject(forKey: "qiscus_email")
        QiscusMe.shared.userData.removeObject(forKey: "qiscus_username")
        QiscusMe.shared.userData.removeObject(forKey: "qiscus_avatar_url")
        QiscusMe.shared.userData.removeObject(forKey: "qiscus_rt_key")
        QiscusMe.shared.userData.removeObject(forKey: "qiscus_token")
        QiscusMe.shared.userData.removeObject(forKey: "qiscus_lastComment_id")
        QiscusMe.shared.userData.removeObject(forKey: "qiscus_lastKnownComment_id")
    }
}

