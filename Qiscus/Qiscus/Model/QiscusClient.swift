//
//  QiscusMe.swift
//  QiscusSDK
//
//  Created by Ahmad Athaullah on 9/8/16.
//  Copyright © 2016 Ahmad Athaullah. All rights reserved.
//

import UIKit
import SwiftyJSON


/// contain sdk user information
open class QiscusClient: NSObject {
    
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

    public static var hasRegisteredDeviceToken: Bool {
        set {
            let userData = UserDefaults.standard
            userData.set(hasRegisteredDeviceToken, forKey: "has_register_device_token")
        }
        
        get {
            let userData = UserDefaults.standard
            if let hasRegisteredDeviceToken = userData.value(forKey: "has_register_device_token") as? Bool {
                return hasRegisteredDeviceToken
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
    
    open static let shared = QiscusClient()
    
    let userData = UserDefaults.standard
    
    open class var isLoggedIn:Bool {
        get{
            return (Qiscus.client.token != "")
        }
    }
    open class var canReconnect:Bool{
        get{
            return (Qiscus.client.userKey != "" && Qiscus.client.email != "")
        }
    }
    public var id = 0
    public var email = ""
    public var userName = ""
    public var avatarUrl = ""
    public var rtKey = ""
    public var token = ""
    public var extras = ""
    public var userKey = ""
    public var appId = ""
    public var baseUrl = ""
    
    public var realtimeServer:String = "mqtt.qiscus.com"
    public var realtimePort:Int = 1883
    public var realtimeSSL:Bool = false
    
    public var lastCommentId = Int(0)
    public var lastEventId = ""
    public var lastKnownCommentId = Int(0)
    
    public var paramEmail = ""
    public var paramPass = ""
    public var paramUsername = ""
    public var paramAvatar = ""
    public var paramExtras = ""
    
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
        if let extras = userData.value(forKey: "qiscus_extras") as? String{
            self.extras = extras
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
        if let lastEvent = userData.value(forKey: "qiscus_lastEvent_id") as? String{
            self.lastEventId = lastEvent
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
        if let paramExtras = userData.value(forKey: "qiscus_param_extras") as? String{
            self.paramExtras = paramExtras
        }
    }
    
    open class func saveData(fromJson json:JSON, reconnect:Bool = false)->QiscusClient{
        Qiscus.printLog(text: "jsonFron saveData: \(json)")
        Qiscus.client.id = json["id"].intValue
        Qiscus.client.email = json["email"].stringValue
        Qiscus.client.userName = json["username"].stringValue
        Qiscus.client.avatarUrl = json["avatar"].stringValue
        Qiscus.client.rtKey = json["rtKey"].stringValue
        Qiscus.client.token = json["token"].stringValue
        var extrasData = json["extras"]
        var extras = ""
        if !(extrasData.isEmpty){
            extras = "\(extrasData)"
        }
        Qiscus.client.extras = extras
        Qiscus.client.userData.set(json["id"].intValue, forKey: "qiscus_id")
        Qiscus.client.userData.set(json["email"].stringValue, forKey: "qiscus_email")
        Qiscus.client.userData.set(json["username"].stringValue, forKey: "qiscus_username")
        Qiscus.client.userData.set(json["avatar"].stringValue, forKey: "qiscus_avatar_url")
        Qiscus.client.userData.set(json["rtKey"].stringValue, forKey: "qiscus_rt_key")
        Qiscus.client.userData.set(json["token"].stringValue, forKey: "qiscus_token")
        Qiscus.client.userData.set(extras, forKey: "extras")
        
        if !reconnect {
            Qiscus.client.userData.set(json["last_comment_id"].intValue, forKey: "qiscus_lastComment_id")
            Qiscus.client.userData.set(json["last_comment_id"].intValue, forKey: "qiscus_lastKnownComment_id")
        }else{
            if json["last_comment_id"].intValue > Qiscus.client.lastCommentId {
                Qiscus.sync()
            }
        }
        if let lastComment = Qiscus.client.userData.value(forKey: "qiscus_lastComment_id") as? Int{
            Qiscus.client.lastCommentId = lastComment
            if lastComment == 0 {
                Qiscus.client.lastCommentId = json["last_comment_id"].intValue
                Qiscus.client.userData.set(json["last_comment_id"].intValue, forKey: "qiscus_lastComment_id")
                Qiscus.client.userData.set(json["last_comment_id"].intValue, forKey: "qiscus_lastKnownComment_id")
            }
        }else{
            Qiscus.client.lastCommentId = json["last_comment_id"].intValue
            Qiscus.client.userData.set(json["last_comment_id"].intValue, forKey: "qiscus_lastComment_id")
            Qiscus.client.userData.set(json["last_comment_id"].intValue, forKey: "qiscus_lastKnownComment_id")
        }
        if let lastComment = Qiscus.client.userData.value(forKey: "qiscus_lastKnownComment_id") as? Int{
            Qiscus.client.lastKnownCommentId = lastComment
        }
        return Qiscus.client
    }
    public class func updateLastCommentId(commentId:Int){
        if Qiscus.client.lastCommentId < commentId {
            Qiscus.client.lastCommentId = commentId
            Qiscus.client.userData.set(commentId, forKey: "qiscus_lastComment_id")
        }
        if Qiscus.client.lastKnownCommentId < commentId {
            Qiscus.client.lastKnownCommentId = commentId
            Qiscus.client.userData.set(commentId, forKey: "qiscus_lastKnownComment_id")
        }
        
    }
    public class func updateLastKnownCommentId(commentId:Int){
        if Qiscus.client.lastKnownCommentId < commentId {
            Qiscus.client.lastKnownCommentId = commentId
            Qiscus.client.userData.set(commentId, forKey: "qiscus_lastKnownComment_id")
        }
    }
    public class func clear(){
        Qiscus.client.id = 0
        Qiscus.client.email = ""
        Qiscus.client.userName = ""
        Qiscus.client.avatarUrl = ""
        Qiscus.client.rtKey = ""
        Qiscus.client.token = ""
        Qiscus.client.lastCommentId = 0
        Qiscus.client.lastEventId = ""
        Qiscus.client.extras = ""
        
        Qiscus.client.userData.removeObject(forKey: "qiscus_id")
        Qiscus.client.userData.removeObject(forKey: "qiscus_email")
        Qiscus.client.userData.removeObject(forKey: "qiscus_username")
        Qiscus.client.userData.removeObject(forKey: "qiscus_avatar_url")
        Qiscus.client.userData.removeObject(forKey: "qiscus_rt_key")
        Qiscus.client.userData.removeObject(forKey: "qiscus_token")
        Qiscus.client.userData.removeObject(forKey: "qiscus_lastComment_id")
        Qiscus.client.userData.removeObject(forKey: "qiscus_lastKnownComment_id")
        Qiscus.client.userData.removeObject(forKey: "qiscus_lastEvent_id")
        Qiscus.client.userData.removeObject(forKey: "qiscus_extras")
    }
    
    public class func update(lastEventId eventId: String){
        guard let newId = Int64(eventId) else {return}
        if Qiscus.client.lastEventId == "" {
            Qiscus.client.lastEventId = eventId
            Qiscus.client.userData.set(eventId, forKey: "qiscus_lastEvent_id")
        }else{
            if let currentId = Int64(Qiscus.client.lastEventId) {
                if currentId < newId {
                    Qiscus.client.lastEventId = eventId
                    Qiscus.client.userData.set(eventId, forKey: "qiscus_lastEvent_id")
                }
            } else { 
                Qiscus.client.lastEventId = eventId
                Qiscus.client.userData.set(eventId, forKey: "qiscus_lastEvent_id")
            }
            
        }
    }
}

