//
//  QService.swift
//  Example
//
//  Created by Ahmad Athaullah on 7/6/17.
//  Copyright © 2017 Ahmad Athaullah. All rights reserved.
//

import Foundation
import Alamofire
import SwiftyJSON

@objc public protocol QChatServiceDelegate {
    func chatService(didFinishLoadRoom inRoom:QRoom, withMessage message:String?)
    func chatService(didFailLoadRoom error:String)
}
public class QChatService:NSObject {
    public static var defaultService = QChatService()
    public var delegate:QChatServiceDelegate?
    static var syncTimer:Timer? = nil
    static var inSyncProcess:Bool = false
    static var inSyncEvent:Bool = false
    static var hasPendingSync:Bool = false
    static var syncRetryTime:Double = 3.0
    static var downloadTasks = [String]()
    
    // MARK: - reconnect
    private func reconnect(onSuccess:@escaping (()->Void)){
        let email = Qiscus.client.userData.value(forKey: "qiscus_param_email") as? String
        let userKey = Qiscus.client.userData.value(forKey: "qiscus_param_pass") as? String
        let userName = Qiscus.client.userData.value(forKey: "qiscus_param_username") as? String
        let avatarURL = Qiscus.client.userData.value(forKey: "qiscus_param_avatar") as? String
        if email != nil && userKey != nil && userName != nil {
            if Qiscus.client.appId.isEmpty {
                #if DEBUG
                    fatalError("app id cant be empty")
                #endif
                Qiscus.printLog(text: "app id is empty")
                return
            }
            QiscusCommentClient.sharedInstance.loginOrRegister(email!, password: userKey!, username: userName!, avatarURL: avatarURL, reconnect: true, onSuccess: onSuccess)
        }
    }
    
    internal class func updateProfil(userName: String? = nil, userAvatarURL: String? = nil, onSuccess: @escaping (()->Void),onError:@escaping ((String)->Void)){
        if Qiscus.isLoggedIn {
            var parameters:[String: AnyObject] = [String: AnyObject]()
            parameters["token"] = qiscus.config.USER_TOKEN as AnyObject
            
            if let name = userName{
                parameters["name"] = name as AnyObject?
            }
            if let avatar =  userAvatarURL{
                parameters["avatar_url"] = avatar as AnyObject?
            }
            
            
            DispatchQueue.global().async(execute: {
                QiscusService.session.request(QiscusConfig.UPDATE_PROFILE, method: .patch, parameters: parameters, encoding: URLEncoding.default, headers: QiscusConfig.sharedInstance.requestHeader).responseJSON(completionHandler: { response in
                    switch response.result {
                    case .success:
                        if let result = response.result.value{
                            let json = JSON(result)
                            let success:Bool = (json["status"].intValue == 200)
                            
                            if success {
                                let userData = json["results"]["user"]
                                let _ = QiscusClient.saveData(fromJson: userData, reconnect: true)
                                Qiscus.setupReachability()
                                if let delegate = Qiscus.shared.delegate {
                                    Qiscus.uiThread.async { autoreleasepool{
                                        delegate.qiscus?(didConnect: true, error: nil)
                                        delegate.qiscusConnected?()
                                        }}
                                }
                                Qiscus.registerNotification()
                                Qiscus.uiThread.async { autoreleasepool{
                                    onSuccess()
                                    }}
                            }else{
                                Qiscus.uiThread.async { autoreleasepool{
                                    onError(json["message"].stringValue)
                                    }}
                            }
                        }else{
                            Qiscus.uiThread.async { autoreleasepool{
                                let error = "Cant get data from qiscus server"
                                onError(error)
                                }}
                        }
                        break
                    case .failure(let error):
                        Qiscus.uiThread.async {autoreleasepool{
                            onError("\(error)")
                            }}
                        break
                    }
                })
            })
        }else{
            onError("Not logged in to Qiscus")
        }
    }
    // MARK : - room getter method
    public func room(withUser user:String, distincId:String? = nil, optionalData:String? = nil, withMessage:String? = nil){ //
        if user.isEmpty {
            #if DEBUG
                fatalError("user cant be empty")
            #endif
            return
        }
        if Qiscus.isLoggedIn{
            if let room = QRoom.room(withUser: user){
                self.delegate?.chatService(didFinishLoadRoom: room, withMessage: withMessage)
                if let roomDelegate = QiscusCommentClient.shared.roomDelegate {
                    if !room.isInvalidated {
                        roomDelegate.didFinishLoadRoom(onRoom: room)
                    }
                }
            }
            else{
                QiscusRequestThread.async {
                    autoreleasepool{
                        let loadURL = QiscusConfig.ROOM_REQUEST_URL
                        
                        var parameters:[String : AnyObject] =  [
                            "emails" : [user] as AnyObject,
                            "token"  : qiscus.config.USER_TOKEN as AnyObject
                        ]
                        if distincId != nil{
                            if distincId != "" {
                                parameters["distinct_id"] = distincId! as AnyObject
                            }
                        }
                        if optionalData != nil{
                            parameters["options"] = optionalData! as AnyObject
                        }
                        Qiscus.printLog(text: "get or create room parameters: \(parameters)")
                        Alamofire.request(loadURL, method: .post, parameters: parameters, encoding: URLEncoding.default, headers: QiscusConfig.sharedInstance.requestHeader).responseJSON(completionHandler: {responseData in
                            if let response = responseData.result.value {
                                Qiscus.printLog(text: "get or create room api response:\n\(response)")
                                let json = JSON(response)
                                let results = json["results"]
                                let error = json["error"]
                                if results != JSON.null{
                                    Qiscus.printLog(text: "getListComment with id response: \(responseData)")
                                    let roomData = results["room"]
                                    let commentPayload = results["comments"].arrayValue
                                    
                                    func execute(){
                                        let room = QRoom.room(fromJSON: roomData)
                                        for json in commentPayload {
                                            let commentId = json["id"].intValue
                                            if commentId <= Qiscus.client.lastCommentId {
                                                room.saveOldComment(fromJSON: json)
                                            }else{
                                                QChatService.syncProcess()
                                            }
                                        }
                                        self.delegate?.chatService(didFinishLoadRoom: room, withMessage: withMessage)
                                        
                                        if let roomDelegate = QiscusCommentClient.shared.roomDelegate {
                                            if room.isInvalidated {
                                                roomDelegate.didFinishLoadRoom(onRoom: room)
                                            }
                                        }
                                    }
                                    if Thread.isMainThread {
                                        execute()
                                    }else{
                                        DispatchQueue.main.sync {
                                            autoreleasepool{
                                                execute()
                                            }
                                        }
                                    }
                                }else if error != JSON.null{
                                    var message = "Failed to load room data"
                                    let errorMessages = error["detailed_messages"].arrayValue
                                    if let e = errorMessages.first?.string {
                                        message = e
                                    }
                                    self.delegate?.chatService(didFailLoadRoom: "\(message)")
                                    DispatchQueue.main.async {
                                        autoreleasepool{
                                            if let roomDelegate = QiscusCommentClient.shared.roomDelegate{
                                                roomDelegate.didFailLoadRoom(withError: "\(message)")
                                            }
                                        }
                                    }
                                }else{
                                    let error = "Failed to load room data"
                                    self.delegate?.chatService(didFailLoadRoom: "\(error)")
                                    DispatchQueue.main.async {
                                        autoreleasepool{
                                            if let roomDelegate = QiscusCommentClient.shared.roomDelegate{
                                                roomDelegate.didFailLoadRoom(withError: "\(error)")
                                            }
                                        }
                                    }
                                    Qiscus.printLog(text: error)
                                }
                            }else{
                                let error = "Failed to load room data"
                                self.delegate?.chatService(didFailLoadRoom: "\(error)")
                                DispatchQueue.main.async {
                                    autoreleasepool{
                                        if let roomDelegate = QiscusCommentClient.shared.roomDelegate{
                                            roomDelegate.didFailLoadRoom(withError: "\(error)")
                                        }
                                    }
                                }
                                Qiscus.printLog(text: error)
                            }
                        })
                    }
                }
            }
        }else{
            reconnect {
                self.room(withUser: user, distincId: distincId, optionalData: optionalData, withMessage: withMessage)
            }
        }
    }
    public func room(withUser user:String, distincId:String? = nil, optionalData:String? = nil, withMessage:String? = nil, onSuccess:@escaping ((_ room: QRoom)->Void),onError:@escaping ((_ error: String)->Void)){
        if user.isEmpty {
            Qiscus.printLog(text: "user parameter cant be empty")
            onError("user parameter cant be empty")
            return
        }
        if Qiscus.isLoggedIn{
            if let room = QRoom.room(withUser: user){
                onSuccess(room)
            }
            else{
                QiscusRequestThread.async {
                    autoreleasepool{
                        let loadURL = QiscusConfig.ROOM_REQUEST_URL
                        
                        var parameters:[String : AnyObject] =  [
                            "emails" : [user] as AnyObject,
                            "token"  : qiscus.config.USER_TOKEN as AnyObject
                        ]
                        if distincId != nil{
                            if distincId != "" {
                                parameters["distinct_id"] = distincId! as AnyObject
                            }
                        }
                        if optionalData != nil{
                            parameters["options"] = optionalData! as AnyObject
                        }
                        Qiscus.printLog(text: "get or create room parameters: \(parameters)")
                        QiscusService.session.request(loadURL, method: .post, parameters: parameters, encoding: URLEncoding.default, headers: QiscusConfig.sharedInstance.requestHeader).responseJSON(completionHandler: {responseData in
                            if let response = responseData.result.value {
                                Qiscus.printLog(text: "get or create room api response:\n\(response)")
                                let json = JSON(response)
                                let results = json["results"]
                                let error = json["error"]
                                
                                if results != JSON.null{
                                    Qiscus.printLog(text: "getListComment with id response: \(responseData)")
                                    let roomData = results["room"]
                                    let commentPayload = results["comments"].arrayValue
                                    
                                    func execute(){
                                        let room = QRoom.room(fromJSON: roomData)
                                        
                                        for json in commentPayload {
                                            let commentId = json["id"].intValue
                                            if commentId <= Qiscus.client.lastCommentId {
                                                room.saveOldComment(fromJSON: json)
                                            }else{
                                                QChatService.syncProcess()
                                            }
                                        }
                                        onSuccess(room)
                                    }
                                    if Thread.isMainThread {
                                        execute()
                                    }else{
                                        DispatchQueue.main.sync {
                                            autoreleasepool{
                                                execute()
                                            }
                                        }
                                    }
                                }else if error != JSON.null{
                                    var message = "Failed to load room data"
                                    let errorMessages = error["detailed_messages"].arrayValue
                                    if let e = errorMessages.first?.string {
                                        message = e
                                    }
                                    onError("\(message)")
                                    DispatchQueue.main.async { autoreleasepool{
                                        if let roomDelegate = QiscusCommentClient.shared.roomDelegate{
                                            roomDelegate.didFailLoadRoom(withError: "\(message)")
                                        }
                                        }}
                                }else{
                                    let error = "Failed to load room data"
                                    onError("\(error)")
                                    DispatchQueue.main.async { autoreleasepool{
                                        if let roomDelegate = QiscusCommentClient.shared.roomDelegate{
                                            roomDelegate.didFailLoadRoom(withError: "\(error)")
                                        }
                                        }}
                                    Qiscus.printLog(text: error)
                                }
                            }else{
                                let error = "Failed to load room data"
                                onError("\(error)")
                                DispatchQueue.main.async { autoreleasepool{
                                    if let roomDelegate = QiscusCommentClient.shared.roomDelegate{
                                        roomDelegate.didFailLoadRoom(withError: "\(error)")
                                    }
                                    }}
                                Qiscus.printLog(text: error)
                            }
                        })
                    }
                }
            }
        }else{
            reconnect {
                self.room(withUser: user, distincId: distincId, optionalData: optionalData, withMessage: withMessage)
            }
        }
    }
    //
    public func room(withUniqueId uniqueId:String, title:String = "", avatarURL:String = "", onSuccess:@escaping ((_ room: QRoom)->Void),onError:@escaping ((_ error: String)->Void)){
        if uniqueId.isEmpty {
            Qiscus.printLog(text: "uniqueId parameter cant be empty")
            onError("uniqueId parameter cant be empty")
            return
        }
        if Qiscus.isLoggedIn{
            if let room = QRoom.room(withUniqueId: uniqueId){
                onSuccess(room)
            }else{
                QiscusRequestThread.async { autoreleasepool{
                    let loadURL = QiscusConfig.ROOM_UNIQUEID_URL
                    
                    var parameters:[String : AnyObject] =  [
                        "token"  : qiscus.config.USER_TOKEN as AnyObject,
                        "unique_id" : uniqueId as AnyObject
                    ]
                    if title != ""{
                        parameters["name"] = title as AnyObject
                    }
                    if avatarURL != ""{
                        parameters["avatar_url"] = avatarURL as AnyObject
                    }
                    Qiscus.printLog(text: "get or create room with uniqueId parameters: \(parameters)")
                    QiscusService.session.request(loadURL, method: .post, parameters: parameters, encoding: URLEncoding.default, headers: QiscusConfig.sharedInstance.requestHeader).responseJSON(completionHandler: {responseData in
                        if let response = responseData.result.value {
                            Qiscus.printLog(text: "get or create room with uniqueId response:\n\(response)")
                            let json = JSON(response)
                            let results = json["results"]
                            let error = json["error"]
                            
                            if results != JSON.null{
                                Qiscus.printLog(text: "getListComment with id response: \(responseData)")
                                let roomData = results["room"]
                                let commentPayload = results["comments"].arrayValue
                                
                                func execute(){
                                    let room = QRoom.room(fromJSON: roomData)
                                    for json in commentPayload {
                                        let commentId = json["id"].intValue
                                        if commentId <= Qiscus.client.lastCommentId {
                                            room.saveOldComment(fromJSON: json)
                                        }else{
                                            QChatService.syncProcess()
                                        }
                                    }
                                    onSuccess(room)
                                    
                                    if let roomDelegate = QiscusCommentClient.shared.roomDelegate{
                                        if !room.isInvalidated {
                                            roomDelegate.didFinishLoadRoom(onRoom: room)
                                        }
                                    }
                                }
                                if Thread.isMainThread {
                                    execute()
                                }else{
                                    DispatchQueue.main.sync {
                                        autoreleasepool{
                                            execute()
                                        }
                                    }
                                }
                            }else if error != JSON.null{
                                var message = "Failed to load room data"
                                let errorMessages = error["detailed_messages"].arrayValue
                                if let e = errorMessages.first?.string {
                                    message = e
                                }
                                onError("\(message)")
                                Qiscus.printLog(text: "\(message)")
                                DispatchQueue.main.async { autoreleasepool{
                                    if let roomDelegate = QiscusCommentClient.shared.roomDelegate{
                                        roomDelegate.didFailLoadRoom(withError: "\(error)")
                                    }
                                    }}
                            }else{
                                let error = "Failed to load room data"
                                onError(error)
                                Qiscus.printLog(text: error)
                                DispatchQueue.main.async { autoreleasepool{
                                    if let roomDelegate = QiscusCommentClient.shared.roomDelegate{
                                        roomDelegate.didFailLoadRoom(withError: "\(error)")
                                    }
                                    }}
                            }
                            
                        }else{
                            let error = "Failed to load room data"
                            onError(error)
                            Qiscus.printLog(text: error)
                            DispatchQueue.main.async { autoreleasepool{
                                if let roomDelegate = QiscusCommentClient.shared.roomDelegate{
                                    roomDelegate.didFailLoadRoom(withError: "\(error)")
                                }
                                }}
                        }
                    })
                    }}
            }
        }else{
            reconnect {
                self.room(withUniqueId: uniqueId, title: title, avatarURL: avatarURL, onSuccess: onSuccess, onError: onError)
            }
        }
    }
    public func room(withUniqueId uniqueId:String, title:String = "", avatarURL:String = "", withMessage:String? = nil){
        if uniqueId.isEmpty {
            #if DEBUG
                fatalError("uniqueId parameters cant be empty")
            #endif
            
            return
        }
        if Qiscus.isLoggedIn{
            if let room = QRoom.room(withUniqueId: uniqueId){
                self.delegate?.chatService(didFinishLoadRoom: room, withMessage: withMessage)
                if let roomDelegate = QiscusCommentClient.shared.roomDelegate {
                    if !room.isInvalidated {
                        roomDelegate.didFinishLoadRoom(onRoom: room)
                    }
                }
            }
            QiscusRequestThread.async { autoreleasepool{
                let loadURL = QiscusConfig.ROOM_UNIQUEID_URL
                
                var parameters:[String : AnyObject] =  [
                    "token"  : qiscus.config.USER_TOKEN as AnyObject,
                    "unique_id" : uniqueId as AnyObject
                ]
                if title != ""{
                    parameters["name"] = title as AnyObject
                }
                if avatarURL != ""{
                    parameters["avatar_url"] = avatarURL as AnyObject
                }
                Qiscus.printLog(text: "get or create room with uniqueId parameters: \(parameters)")
                QiscusService.session.request(loadURL, method: .post, parameters: parameters, encoding: URLEncoding.default, headers: QiscusConfig.sharedInstance.requestHeader).responseJSON(completionHandler: {responseData in
                    if let response = responseData.result.value {
                        Qiscus.printLog(text: "get or create room with uniqueId response:\n\(response)")
                        let json = JSON(response)
                        let results = json["results"]
                        let error = json["error"]
                        
                        if results != JSON.null{
                            Qiscus.printLog(text: "getListComment with id response: \(responseData)")
                            let roomData = results["room"]
                            let commentPayload = results["comments"].arrayValue
                            
                            func execute(){
                                let room = QRoom.room(fromJSON: roomData)
                                for json in commentPayload {
                                    let commentId = json["id"].intValue
                                    if commentId <= Qiscus.client.lastCommentId {
                                        room.saveOldComment(fromJSON: json)
                                    }else{
                                        QChatService.syncProcess()
                                    }
                                }
                                
                                self.delegate?.chatService(didFinishLoadRoom: room, withMessage: withMessage)
                                
                                if let roomDelegate = QiscusCommentClient.shared.roomDelegate {
                                    if !room.isInvalidated {
                                        roomDelegate.didFinishLoadRoom(onRoom: room)
                                    }
                                }
                            }
                            if Thread.isMainThread {
                                execute()
                            }else{
                                DispatchQueue.main.sync {
                                    autoreleasepool{
                                        execute()
                                    }
                                }
                            }
                        }else if error != JSON.null{
                            var message = "Failed to load room data"
                            let errorMessages = error["detailed_messages"].arrayValue
                            if let e = errorMessages.first?.string {
                                message = e
                            }
                            self.delegate?.chatService(didFailLoadRoom: "\(message)")
                            Qiscus.printLog(text: "\(message)")
                            DispatchQueue.main.async { autoreleasepool{
                                if let roomDelegate = QiscusCommentClient.shared.roomDelegate{
                                    roomDelegate.didFailLoadRoom(withError: "\(message)")
                                }
                                }}
                        }else{
                            let error = "Failed to load room data"
                            self.delegate?.chatService(didFailLoadRoom: "\(error)")
                            Qiscus.printLog(text: error)
                            DispatchQueue.main.async { autoreleasepool{
                                if let roomDelegate = QiscusCommentClient.shared.roomDelegate{
                                    roomDelegate.didFailLoadRoom(withError: "\(error)")
                                }
                                }}
                        }
                        
                    }else{
                        let error = "Failed to load room data"
                        self.delegate?.chatService(didFailLoadRoom: "\(error)")
                        Qiscus.printLog(text: error)
                        DispatchQueue.main.async { autoreleasepool{
                            if let roomDelegate = QiscusCommentClient.shared.roomDelegate{
                                roomDelegate.didFailLoadRoom(withError: "\(error)")
                            }
                            }}
                    }
                })
                }}
            
        }else{
            reconnect {
                self.room(withUniqueId: uniqueId, title: title, avatarURL: avatarURL, withMessage: withMessage)
            }
        }
    }
    public func room(withId roomId:String, withMessage:String? = nil){
        if roomId.isEmpty {
            #if DEBUG
                fatalError("roomId parameters cant be empty")
            #endif
            return
        }
        if Qiscus.isLoggedIn {
            var needToLoad = true
            if let room = QRoom.room(withId: roomId){
                if !room.isInvalidated {
                    if room.comments.count > 0 {
                        needToLoad = false
                    }
                }
            }
            if !needToLoad {
                func execute(){
                    let room = QRoom.room(withId: roomId)!
                    self.delegate?.chatService(didFinishLoadRoom: room, withMessage: withMessage)
                    if let roomDelegate = QiscusCommentClient.shared.roomDelegate {
                        if !room.isInvalidated {
                            roomDelegate.didFinishLoadRoom(onRoom: room)
                        }
                    }
                }
                if Thread.isMainThread {
                    execute()
                }else{
                    DispatchQueue.main.sync {
                        autoreleasepool{
                            execute()
                        }
                    }
                }
            }
            QiscusRequestThread.async { autoreleasepool{
                let loadURL = QiscusConfig.ROOM_REQUEST_ID_URL
                let parameters:[String : AnyObject] =  [
                    "id" : roomId as AnyObject,
                    "token"  : qiscus.config.USER_TOKEN as AnyObject
                ]
                QiscusService.session.request(loadURL, method: .get, parameters: parameters, encoding: URLEncoding.default, headers: QiscusConfig.sharedInstance.requestHeader).responseJSON(completionHandler: {responseData in
                    if let response = responseData.result.value {
                        let json = JSON(response)
                        let results = json["results"]
                        let error = json["error"]
                        
                        if results != JSON.null{
                            Qiscus.printLog(text: "getListComment with id response: \(responseData)")
                            let roomData = results["room"]
                            let commentPayload = results["comments"].arrayValue
                            
                            func execute(){
                                let room = QRoom.room(fromJSON: roomData)
                                for json in commentPayload {
                                    let commentId = json["id"].intValue
                                    
                                    if commentId <= Qiscus.client.lastCommentId {
                                        room.saveOldComment(fromJSON: json)
                                    }else{
                                        QChatService.syncProcess()
                                    }
                                }
                                self.delegate?.chatService(didFinishLoadRoom: room, withMessage: withMessage)
                                
                                if let roomDelegate = QiscusCommentClient.shared.roomDelegate {
                                    if !room.isInvalidated {
                                        roomDelegate.didFinishLoadRoom(onRoom: room)
                                    }
                                }
                            }
                            if Thread.isMainThread {
                                execute()
                            }else{
                                DispatchQueue.main.sync {
                                    autoreleasepool{
                                        execute()
                                    }
                                }
                            }
                        }else if error != JSON.null{
                            var message = "Failed to load room data"
                            let errorMessages = error["detailed_messages"].arrayValue
                            if let e = errorMessages.first?.string {
                                message = e
                            }
                            self.delegate?.chatService(didFailLoadRoom: "\(message)")
                            Qiscus.printLog(text: "\(message)")
                            DispatchQueue.main.async { autoreleasepool{
                                if let roomDelegate = QiscusCommentClient.shared.roomDelegate{
                                    roomDelegate.didFailLoadRoom(withError: "\(message)")
                                }
                                }}
                        }else{
                            let error = "Failed to load room data"
                            self.delegate?.chatService(didFailLoadRoom: "\(error)")
                            Qiscus.printLog(text: "\(error)")
                            DispatchQueue.main.async { autoreleasepool{
                                if let roomDelegate = QiscusCommentClient.shared.roomDelegate{
                                    roomDelegate.didFailLoadRoom(withError: "\(error)")
                                }
                                }}
                        }
                    }else{
                        let error = "Failed to load room data"
                        self.delegate?.chatService(didFailLoadRoom: "\(error)")
                        Qiscus.printLog(text: error)
                        DispatchQueue.main.async { autoreleasepool{
                            if let roomDelegate = QiscusCommentClient.shared.roomDelegate{
                                roomDelegate.didFailLoadRoom(withError: "\(error)")
                            }
                            }}
                    }
                })
                }}
        }else{
            self.reconnect {
                self.room(withId: roomId, withMessage: withMessage)
            }
        }
    }
    public func room(withId roomId:String, onSuccess:@escaping ((_ room: QRoom)->Void),onError:@escaping ((_ error: String)->Void)){
        if roomId.isEmpty {
            Qiscus.printLog(text: "roomId cant be empty")
            onError("roomId cant be empty")
            return
        }
        if Qiscus.isLoggedIn {
            var needToLoad = true
            if let room = QRoom.room(withId: roomId){
                if room.comments.count > 0 {
                    needToLoad = false
                }
            }
            if !needToLoad {
                onSuccess(QRoom.room(withId: roomId)!)
            }
            else{
                QiscusRequestThread.async { autoreleasepool{
                    let loadURL = QiscusConfig.ROOM_REQUEST_ID_URL
                    let parameters:[String : AnyObject] =  [
                        "id" : roomId as AnyObject,
                        "token"  : qiscus.config.USER_TOKEN as AnyObject
                    ]
                    QiscusService.session.request(loadURL, method: .get, parameters: parameters, encoding: URLEncoding.default, headers: QiscusConfig.sharedInstance.requestHeader).responseJSON(completionHandler: {responseData in
                        if let response = responseData.result.value {
                            let json = JSON(response)
                            let results = json["results"]
                            let error = json["error"]
                            
                            if results != JSON.null{
                                Qiscus.printLog(text: "getListComment with id response: \(responseData)")
                                let roomData = results["room"]
                                let commentPayload = results["comments"].arrayValue
                                func saveRoom(){
                                    let room = QRoom.room(fromJSON: roomData)
                                    for json in commentPayload {
                                        let commentId = json["id"].intValue
                                        
                                        if commentId <= Qiscus.client.lastCommentId {
                                            room.saveOldComment(fromJSON: json)
                                        }else{
                                            QChatService.syncProcess()
                                        }
                                    }
                                    onSuccess(room)
                                }
                                if Thread.isMainThread {
                                    saveRoom()
                                }else{
                                    DispatchQueue.main.sync {
                                        saveRoom()
                                    }
                                }
                            }else if error != JSON.null{
                                var message = "Failed to load room data"
                                let errorMessages = error["detailed_messages"].arrayValue
                                if let e = errorMessages.first?.string {
                                    message = e
                                }
                                DispatchQueue.main.async { autoreleasepool{
                                    onError("\(message)")
                                    }}
                                Qiscus.printLog(text: "\(message)")
                            }else{
                                let error = "Failed to load room data"
                                DispatchQueue.main.async { autoreleasepool{
                                    onError(error)
                                    }}
                                Qiscus.printLog(text: "\(error)")
                            }
                        }else{
                            let error = "Failed to load room data"
                            DispatchQueue.main.async { autoreleasepool{
                                onError(error)
                                }}
                        }
                    })
                    }}
            }
        }else{
            self.reconnect {
                self.room(withId: roomId, onSuccess: onSuccess, onError: onError)
            }
        }
    }
    internal class func syncRoomList(){
        var page = 1
        func load(onPage:Int) {
            QChatService.roomList(withLimit: 50, page: page, showParticipant: true, onSuccess: { (rooms, totalRoom, currentPage, limit) in
                if rooms.count < limit {
                    QiscusNotification.publish(finishedSyncRoomList: true)
                }else{
                    page += 1
                    load(onPage: page)
                }
            }, onFailed: { (error) in
                load(onPage: page)
            }) { (progress, loadedRoom, totalRoom) in
                let percentage = Int(progress * 100.0)
                Qiscus.printLog(text: "sync room List: \(percentage)% [\(loadedRoom)/\(totalRoom)]")
            }
        }
        load(onPage: 1)
    }
    @objc internal class func backgroundSync(){
        if !Qiscus.realtimeConnected {
            Qiscus.mqttConnect()
        }
    }
    
    @objc internal class func syncProcess(first:Bool = true, cloud:Bool = false){
        if Qiscus.client.lastCommentId == 0 {
            return
        }
        if QChatService.inSyncProcess {
            QChatService.hasPendingSync = true
            return
        }
        DispatchQueue.main.async {
            if UIApplication.shared.applicationState != .active {
                Qiscus.printLog(text: "sync qiscus on background")
            }
        }
        func getTime()->String{
            let date = Date()
            let df = DateFormatter()
            df.dateFormat = "y-MM-dd H:m:ss"
            return df.string(from: date)
        }
        QiscusRequestThread.sync {
            Qiscus.printLog(text: "Start syncing on  \(getTime())")
            QChatService.inSyncProcess = true
            let loadURL = QiscusConfig.SYNC_URL
            let limit = 60
            
            let parameters:[String: AnyObject] =  [
                "last_received_comment_id"  : Qiscus.client.lastCommentId as AnyObject,
                "token" : qiscus.config.USER_TOKEN as AnyObject,
                "order" : "asc" as AnyObject,
                "limit" : limit as AnyObject
            ]
            
            QiscusService.session.request(loadURL, method: .get, parameters: parameters, encoding: URLEncoding.default, headers: QiscusConfig.sharedInstance.requestHeader).responseJSON(completionHandler: {responseData in
                if let statusCode = responseData.response?.statusCode {
                    Qiscus.printLog(text: "sync on [\(getTime()) statusCode: \(statusCode)]")
                    if statusCode == 502 || statusCode == 503 {
                        if QChatService.syncRetryTime < 200 {
                            QChatService.syncRetryTime += 3.0
                        }
                    }
                }
                if let response = responseData.result.value {
                    let json = JSON(response)
                    let results = json["results"]
                    let error = json["error"]
                    if results != JSON.null{
                        let meta = json["results"]["meta"]
                        let lastReceivedCommentId = meta["last_received_comment_id"].intValue
                        let needClear = meta["need_clear"].boolValue
                        let comments = json["results"]["comments"].arrayValue
                        if needClear && comments.count > 1 {
                            QiscusBackgroundThread.async {
                                QRoom.removeAllMessage()
                                QiscusClient.updateLastCommentId(commentId: lastReceivedCommentId)
                            }
                        }else{
                            var data = [String:[JSON]]()
                            var roomsName = [String:String]()
                            var needSyncRoom = [String]()
                            if comments.count > 0 {
                                QiscusBackgroundThread.async {
                                    for newComment in comments.reversed() {
                                        let roomId = "\(newComment["room_id"])"
                                        let roomName = "\(newComment["room_name"])"
                                        let id = newComment["id"].intValue
                                        let type = newComment["type"].string
                                        
                                        if id > Qiscus.client.lastCommentId {
                                            if data[roomId] == nil {
                                                data[roomId] = [JSON]()
                                            }
                                            if roomsName[roomId] == nil {
                                                roomsName[roomId] = roomName
                                            }
                                            data[roomId]?.append(newComment)
                                            if type == "system_event" {
                                                if !needSyncRoom.contains(roomId) {
                                                    needSyncRoom.append(roomId)
                                                }
                                            }
                                        }
                                        
                                    }
                                    for (roomId,roomComments) in data {
                                        if roomComments.count > 0 {
                                            if let room = QRoom.threadSaveRoom(withId: roomId){
                                                if let newName = roomsName[roomId] {
                                                    room.update(name: newName)
                                                }
                                                var unread = room.unreadCount
                                                for commentData in roomComments {
                                                    let email = commentData["email"].stringValue
                                                    let beforeId = commentData["comment_before_id"].intValue
                                                    
                                                    if room.comments.count > 0 || beforeId == 0 {
                                                        let temp = room.createComment(withJSON: commentData)
                                                        room.addComment(newComment: temp)
                                                    }else{
                                                        DispatchQueue.main.async {
                                                            if let r = QRoom.room(withId: roomId) {
                                                                let c =  QComment.tempComment(fromJSON: commentData)
                                                                QiscusNotification.publish(gotNewComment: c, room: r)
                                                            }
                                                        }
                                                    }
                                                    if email == Qiscus.client.email {
                                                        unread = 0
                                                    }else{
                                                        unread += 1
                                                    }
                                                }
                                                room.updateUnreadCommentCount(count: unread)
                                                let lastComment = QComment.tempComment(fromJSON: roomComments.last!)
                                                room.updateLastComentInfo(comment: lastComment)
                                            }else{
                                                QChatService.getRoom(withId: roomId)
                                            }
                                        }
                                    }
                                    QiscusClient.updateLastCommentId(commentId: lastReceivedCommentId)
                                }
                            }
                            
                            if comments.count == limit {
                                QChatService.syncProcess(first: false, cloud: cloud)
                            }else{
                                
                                if cloud {
                                    QiscusNotification.publish(finishedCloudSync: true)
                                }
                                if !Qiscus.realtimeConnected {
                                    let delay = QChatService.syncRetryTime * Double(NSEC_PER_SEC)
                                    let time = DispatchTime.now() + delay / Double(NSEC_PER_SEC)
                                    DispatchQueue.main.asyncAfter(deadline: time, execute: {
                                        Qiscus.mqttConnect()
                                    })
                                }else{
                                    if QChatService.hasPendingSync {
                                        let delay = 1.0 * Double(NSEC_PER_SEC)
                                        let time = DispatchTime.now() + delay / Double(NSEC_PER_SEC)
                                        QiscusBackgroundThread.asyncAfter(deadline: time, execute: {
                                            QChatService.hasPendingSync = false
                                            QChatService.syncProcess()
                                        })
                                    }
                                }
                                Qiscus.shared.delegate?.qiscus?(finishSync: true, error: nil)
                                Qiscus.printLog(text: "finish syncing process on [\(getTime())].")
                            }
                            
                            QiscusBackgroundThread.async {
                                Qiscus.syncEvent()
                            }
                        }
                    }else if error != JSON.null{
                        Qiscus.printLog(text: "error sync message: \(error) on [\(getTime())]")
                        
                        let delay = QChatService.syncRetryTime * Double(NSEC_PER_SEC)
                        let time = DispatchTime.now() + delay / Double(NSEC_PER_SEC)
                        QiscusBackgroundThread.asyncAfter(deadline: time, execute: {
                            QChatService.inSyncProcess = false
                            QChatService.hasPendingSync = false
                            QChatService.syncProcess()
                        })
                        Qiscus.shared.delegate?.qiscus?(finishSync: false, error: "\(error)")
                        if cloud {
                            QiscusNotification.publish(errorCloudSync: "\(error)")
                        }
                    }
                    QChatService.syncRetryTime = 3.0
                }
                else{
                    let delay = QChatService.syncRetryTime * Double(NSEC_PER_SEC)
                    let time = DispatchTime.now() + delay / Double(NSEC_PER_SEC)
                    DispatchQueue.main.asyncAfter(deadline: time, execute: {
                        QChatService.hasPendingSync = false
                        QChatService.syncProcess()
                    })
                    Qiscus.shared.delegate?.qiscus?(finishSync: false, error: "error sync message")
                    Qiscus.printLog(text: "error sync message on [\(getTime())]")
                    if cloud {
                        QiscusNotification.publish(errorCloudSync: "error sync message")
                    }
                }
                QChatService.inSyncProcess = false
            })
        }
    }
    // MARK syncMethod
    
    public class func sync(cloud:Bool = false){
        if Qiscus.isLoggedIn{
            QChatService.syncProcess(cloud: cloud)
        }
    }
    public func createRoom(withUsers users:[String], roomName:String, optionalData:String? = nil, withMessage:String? = nil){ //
        if users.isEmpty || roomName.isEmpty {
            #if DEBUG
                fatalError("roomName | users cant be empty")
            #endif
            return
        }
        if Qiscus.isLoggedIn{
            QiscusRequestThread.async {autoreleasepool{
                let loadURL = QiscusConfig.CREATE_NEW_ROOM
                
                var parameters:[String : AnyObject] =  [
                    "name" : roomName as AnyObject,
                    "participants" : users as AnyObject,
                    "token"  : qiscus.config.USER_TOKEN as AnyObject
                ]
                
                if optionalData != nil{
                    parameters["options"] = optionalData! as AnyObject
                }
                Qiscus.printLog(text: "create new room parameters: \(parameters)")
                QiscusService.session.request(loadURL, method: .post, parameters: parameters, encoding: URLEncoding.default, headers: QiscusConfig.sharedInstance.requestHeader).responseJSON(completionHandler: {responseData in
                    if let response = responseData.result.value {
                        Qiscus.printLog(text: "create group room api response:\n\(response)")
                        let json = JSON(response)
                        let results = json["results"]
                        let error = json["error"]
                        
                        if results != JSON.null{
                            Qiscus.printLog(text: "getListComment with id response: \(responseData)")
                            let roomData = results["room"]
                            let commentPayload = results["comments"].arrayValue
                            
                            func execute(){
                                let room = QRoom.room(fromJSON: roomData)
                                for json in commentPayload {
                                    let commentId = json["id"].intValue
                                    
                                    if commentId <= Qiscus.client.lastCommentId {
                                        room.saveOldComment(fromJSON: json)
                                    }
                                }
                                self.delegate?.chatService(didFinishLoadRoom: room, withMessage: withMessage)
                                
                                if let roomDelegate = QiscusCommentClient.shared.roomDelegate {
                                    if !room.isInvalidated {
                                        roomDelegate.didFinishLoadRoom(onRoom: room)
                                    }
                                }
                            }
                            if Thread.isMainThread {
                                execute()
                            }else{
                                DispatchQueue.main.sync {
                                    autoreleasepool{
                                        execute()
                                    }
                                }
                            }
                        }else if error != JSON.null{
                            var message = "Failed to load room data"
                            let errorMessages = error["detailed_messages"].arrayValue
                            if let e = errorMessages.first?.string {
                                message = e
                            }
                            self.delegate?.chatService(didFailLoadRoom: "\(message)")
                            Qiscus.printLog(text: "\(message)")
                            DispatchQueue.main.async { autoreleasepool{
                                if let roomDelegate = QiscusCommentClient.shared.roomDelegate{
                                    roomDelegate.didFailLoadRoom(withError: "\(message)")
                                }
                                }}
                        }else{
                            let error = "Failed to load room data"
                            self.delegate?.chatService(didFailLoadRoom: "\(error)")
                            Qiscus.printLog(text: "\(error)")
                            DispatchQueue.main.async { autoreleasepool{
                                if let roomDelegate = QiscusCommentClient.shared.roomDelegate{
                                    roomDelegate.didFailLoadRoom(withError: "\(error)")
                                }
                                }}
                        }
                    }else{
                        let error = "Failed to load room data"
                        self.delegate?.chatService(didFailLoadRoom: "\(error)")
                        Qiscus.printLog(text: "\(error)")
                        DispatchQueue.main.async { autoreleasepool{
                            if let roomDelegate = QiscusCommentClient.shared.roomDelegate{
                                roomDelegate.didFailLoadRoom(withError: "\(error)")
                            }
                        }}
                    }
                })
                }}
        }
        else{
            reconnect {
                self.createRoom(withUsers: users, roomName: roomName, optionalData: optionalData, withMessage: withMessage)
            }
        }
    }
    public func createRoom(withUsers users:[String], roomName:String , avatarURL:String = "", onSuccess:@escaping ((_ room: QRoom)->Void),onError:@escaping ((_ error: String)->Void)){ //
        if users.isEmpty || roomName.isEmpty {
            Qiscus.printLog(text: "users | roomName cant be empty")
            onError("users | roomName cant be empty")
        }
        if Qiscus.isLoggedIn{
            QiscusRequestThread.async {autoreleasepool{
                let loadURL = QiscusConfig.CREATE_NEW_ROOM
                
                var parameters:[String : AnyObject] =  [
                    "name" : roomName as AnyObject,
                    "participants" : users as AnyObject,
                    "token"  : qiscus.config.USER_TOKEN as AnyObject
                ]
                
                if avatarURL.trimmingCharacters(in: .whitespacesAndNewlines) != "" {
                    parameters["avatar_url"] = avatarURL as AnyObject
                }
                
                QiscusService.session.request(loadURL, method: .post, parameters: parameters, encoding: URLEncoding.default, headers: QiscusConfig.sharedInstance.requestHeader).responseJSON(completionHandler: {responseData in
                    if let response = responseData.result.value {
                        Qiscus.printLog(text: "create group room api response:\n\(response)")
                        let json = JSON(response)
                        let results = json["results"]
                        let error = json["error"]
                        
                        if results != JSON.null{
                            Qiscus.printLog(text: "getListComment with id response: \(responseData)")
                            let roomData = results["room"]
                            let commentPayload = results["comments"].arrayValue
                            
                            func execute(){
                                let room = QRoom.room(fromJSON: roomData)
                                for json in commentPayload {
                                    let commentId = json["id"].intValue
                                    
                                    if commentId <= Qiscus.client.lastCommentId {
                                        room.saveOldComment(fromJSON: json)
                                    }
                                }
                                onSuccess(room)
                            }
                            if Thread.isMainThread {
                                execute()
                            }else{
                                DispatchQueue.main.sync {
                                    autoreleasepool {
                                        execute()
                                    }
                                }
                            }
                        }else if error != JSON.null{
                            var message = "Failed to load room data"
                            let errorMessages = error["detailed_messages"].arrayValue
                            if let e = errorMessages.first?.string {
                                message = e
                            }
                            DispatchQueue.main.async { autoreleasepool{
                                onError("\(message)")
                                }}
                        }else{
                            let error = "Failed to load room data"
                            DispatchQueue.main.async { autoreleasepool{
                                onError(error)
                                }}
                        }
                    }else{
                        let error = "Failed to load room data"
                        DispatchQueue.main.async { autoreleasepool{
                            onError("\(error)")
                            }}
                    }
                })
                }}
        }
        else{
            reconnect {
                self.createRoom(withUsers: users, roomName: roomName, onSuccess: onSuccess, onError: onError)
            }
        }
    }
    
    public func getAllUnreadCount(onSuccess: @escaping ((_ unread: Int)->Void), onError: @escaping ((_ error: String)->Void)) {
        if Qiscus.isLoggedIn{
            QiscusRequestThread.async {autoreleasepool{
                let loadURL = QiscusConfig.ALL_UNREAD_COUNT
                
                var parameters:[String : AnyObject] =  [
                    "token"  : qiscus.config.USER_TOKEN as AnyObject
                ]
                
                QiscusService.session.request(loadURL, method: .get, parameters: parameters, encoding: URLEncoding.default, headers: QiscusConfig.sharedInstance.requestHeader).responseJSON(completionHandler: {responseData in
                    if let response = responseData.result.value {
                        let json = JSON(response)
                        let results = json["results"]
                        let error = json["error"]
                        
                        if results != JSON.null {
                            let unreadCount = results["total_unread_count"].intValue
                            onSuccess(unreadCount)
                        } else if error != JSON.null {
                            var message = "Failed to get unread count"
                            let errorMessages = error["detailed_messages"].arrayValue
                            if let e = errorMessages.first?.string {
                                message = e
                            }
                            DispatchQueue.main.async { autoreleasepool{
                                onError("\(message)")
                                }}
                        }
                    }else{
                        let error = "Failed to load room data"
                        DispatchQueue.main.async { autoreleasepool{
                            onError("\(error)")
                            }}
                    }
                })
                }}
        }
        else{
            reconnect {
                self.getAllUnreadCount(onSuccess: onSuccess, onError: onError)
            }
        }
    }
    
    internal class func registerDevice(withToken deviceToken: String){
        func register(){
            QiscusCommentClient.isRegisteringDeviceToken = true
            let parameters:[String: AnyObject] = [
                "token"  : qiscus.config.USER_TOKEN as AnyObject,
                "device_token" : deviceToken as AnyObject,
                "device_platform" : "ios" as AnyObject
            ]
            
            Qiscus.printLog(text: "registerDevice url: \(QiscusConfig.SET_DEVICE_TOKEN_URL)")
            Qiscus.printLog(text: "post parameters: \(parameters)")
            
            QiscusService.session.request(QiscusConfig.SET_DEVICE_TOKEN_URL, method: .post, parameters: parameters, encoding: URLEncoding.default, headers: QiscusConfig.sharedInstance.requestHeader).responseJSON(completionHandler: { response in
                Qiscus.printLog(text: "registerDevice result: \(response)")
                Qiscus.printLog(text: "registerDevice url: \(QiscusConfig.LOGIN_REGISTER)")
                Qiscus.printLog(text: "registerDevice parameters: \(parameters)")
                Qiscus.printLog(text: "registerDevice headers: \(QiscusConfig.sharedInstance.requestHeader)")
                QiscusCommentClient.isRegisteringDeviceToken = false
                switch response.result {
                case .success:
                    if let result = response.result.value{
                        let json = JSON(result)
                        let success:Bool = (json["status"].intValue == 200)
                        
                        if success {
                            QiscusClient.hasRegisteredDeviceToken = true
                            let pnData = json["results"]
                            let configured = pnData["pn_ios_configured"].boolValue
                            if configured {
                                if let delegate = Qiscus.shared.delegate {
                                    DispatchQueue.main.async {
                                        delegate.qiscus?(didRegisterPushNotification: true, deviceToken: deviceToken, error: nil)
                                    }
                                }
                            }else{
                                if let delegate = Qiscus.shared.delegate  {
                                    DispatchQueue.main.async {
                                        delegate.qiscus?(didRegisterPushNotification: false, deviceToken: deviceToken, error: "failed to register deviceToken : pushNotification not configured")
                                    }
                                }
                            }
                        }else{
                            if let delegate = Qiscus.shared.delegate {
                                DispatchQueue.main.async {
                                    delegate.qiscus?(didRegisterPushNotification: false, deviceToken: deviceToken, error: "unsuccessful register deviceToken")
                                }
                            }
                        }
                    }else{
                        if let delegate = Qiscus.shared.delegate {
                            DispatchQueue.main.async {
                                delegate.qiscus?(didRegisterPushNotification: false, deviceToken: deviceToken, error: "unsuccessful register deviceToken")
                            }
                        }
                    }
                    break
                case .failure(let error):
                    QiscusClient.hasRegisteredDeviceToken = false
                    if let delegate = Qiscus.shared.delegate {
                        DispatchQueue.main.async {
                            delegate.qiscus?(didRegisterPushNotification: false, deviceToken: deviceToken, error: "unsuccessful register deviceToken: \(error)")
                        }
                    }
                    break
                }
            })
        }
        if Qiscus.isLoggedIn && !QiscusClient.hasRegisteredDeviceToken && !QiscusCommentClient.isRegisteringDeviceToken {
            register()
        }else{
            QChatService.defaultService.reconnect {
                if !QiscusClient.hasRegisteredDeviceToken && !QiscusCommentClient.isRegisteringDeviceToken {
                    register()
                }
            }
        }
        
    }
    internal class func getNonce(withAppId appId:String, baseURL:String? = nil,onSuccess:@escaping ((String)->Void), onFailed:@escaping ((String)->Void), secureURL:Bool = true){
        if appId.isEmpty {
            #if DEBUG
                fatalError("appId cant be empty")
            #endif
            return
        }
        QiscusRequestThread.async { autoreleasepool{
            var baseUrl = ""
            if let url = baseURL {
                baseUrl = url
            }else{
                var requestProtocol = "https"
                if !secureURL {
                    requestProtocol = "http"
                }
                baseUrl = "\(requestProtocol)://api.qiscus.com"
            }
            
            Qiscus.client.appId = appId
            Qiscus.client.userData.set(appId, forKey: "qiscus_appId")
            
            Qiscus.client.baseUrl = baseUrl
            Qiscus.client.userData.set(baseUrl, forKey: "qiscus_base_url")
            
            let authURL = "\(QiscusConfig.sharedInstance.BASE_API_URL)/auth/nonce"
            
            QiscusService.session.request(authURL, method: .post, parameters: nil, encoding: URLEncoding.default, headers: QiscusConfig.sharedInstance.requestHeader).responseJSON(completionHandler: { response in
                
                switch response.result {
                case .success:
                    if let result = response.result.value{
                        let json = JSON(result)
                        let success:Bool = (json["status"].intValue == 200)
                        
                        if success {
                            let resultData = json["results"]
                            let nonce = resultData["nonce"].stringValue
                            DispatchQueue.main.async {
                                onSuccess(nonce)
                            }
                        }else{
                            DispatchQueue.main.async {
                                onSuccess("Cant get nonce from server")
                            }
                        }
                    }else{
                        DispatchQueue.main.async {
                            onSuccess("Cant get nonce from server")
                        }
                    }
                    break
                case .failure(let error):
                    DispatchQueue.main.async {
                        onSuccess("\(error)")
                    }
                    break
                }
            })
            }}
    }
    internal class func setup(withuserIdentityToken uidToken:String){
        if uidToken.isEmpty || uidToken == nil {
            #if DEBUG
            fatalError("user indetitiy token is empty or nil")
            #endif
        } else {
            QiscusRequestThread.async { autoreleasepool{
                
                let authURL = "\(QiscusConfig.sharedInstance.BASE_API_URL)/auth/verify_identity_token"
                let parameters:[String: AnyObject] = [
                    "identity_token"  : uidToken as AnyObject
                ]
                
                QiscusService.session.request(authURL, method: .post, parameters: parameters, encoding: URLEncoding.default, headers: QiscusConfig.sharedInstance.requestHeader).responseJSON(completionHandler: { response in
                    
                    switch response.result {
                    case .success:
                        if let result = response.result.value{
                            let json = JSON(result)
                            let success:Bool = (json["status"].intValue == 200)
                            
                            if success {
                                let userData = json["results"]["user"]
                                let _ = QiscusClient.saveData(fromJson: userData)
                                Qiscus.setupReachability()
                                if let delegate = Qiscus.shared.delegate {
                                    Qiscus.uiThread.async { autoreleasepool{
                                        delegate.qiscus?(didConnect: true, error: nil)
                                        delegate.qiscusConnected?()
                                        }}
                                }
                                Qiscus.registerNotification()
                                
                            }else{
                                if let delegate = Qiscus.shared.delegate {
                                    Qiscus.uiThread.async { autoreleasepool{
                                        delegate.qiscusFailToConnect?("\(json["error"]["message"].stringValue)")
                                        delegate.qiscus?(didConnect: false, error: "\(json["error"]["message"].stringValue)")
                                        }}
                                }
                            }
                        }else{
                            if let delegate = Qiscus.shared.delegate {
                                Qiscus.uiThread.async { autoreleasepool{
                                    let error = "Cant get data from qiscus server"
                                    delegate.qiscusFailToConnect?(error)
                                    delegate.qiscus?(didConnect: false, error: error)
                                    }}
                            }
                        }
                        break
                    case .failure(let error):
                        if let delegate = Qiscus.shared.delegate {
                            Qiscus.uiThread.async {autoreleasepool{
                                delegate.qiscusFailToConnect?("\(error)")
                                delegate.qiscus?(didConnect: false, error: "\(error)")
                                }}
                        }
                        break
                    }
                })
                }}
        }
    }
    
    public class func roomList(withLimit limit:Int = 100, page:Int? = nil, showParticipant:Bool = true, onSuccess:@escaping (([QRoom],Int,Int,Int)->Void), onFailed: @escaping ((String)->Void), onProgress: ((Double,Int, Int)->Void)? = nil){
        if Qiscus.isLoggedIn {
            QiscusRequestThread.async {
                autoreleasepool{
                    var parameters:[String: AnyObject] = [
                        "token"             : qiscus.config.USER_TOKEN as AnyObject,
                        "show_participants" : showParticipant as AnyObject,
                        "limit"             : limit as AnyObject
                    ]
                    if page != nil {
                        parameters["page"] = page as AnyObject
                    }
                    Qiscus.printLog(text: "room list url: \(QiscusConfig.SEARCH_URL)")
                    Qiscus.printLog(text: "room list parameters: \(parameters)")
                    QiscusService.session.request(QiscusConfig.ROOMLIST_URL, method: .get, parameters: parameters, encoding: URLEncoding.default, headers: QiscusConfig.sharedInstance.requestHeader).responseJSON(completionHandler: { response in
                        //Qiscus.printLog(text: "room list result: \(response)")
                        switch response.result {
                        case .success:
                            if let result = response.result.value{
                                let json = JSON(result)
                                let success:Bool = (json["status"].intValue == 200)
                                var recordedRoom = 0
                                if page != nil{
                                    if page! > 0 {
                                        recordedRoom = (page! - 1) * limit
                                    }
                                }
                                if success {
                                    let resultData = json["results"]
                                    let currentPage = resultData["meta"]["current_page"].intValue
                                    let totalRoom = resultData["meta"]["total_room"].intValue
                                    let rooms = resultData["rooms_info"].arrayValue
                                    
                                    func proceed() {
                                        var roomResult = [QRoom]()
                                        var i = 0
                                        for roomData in rooms {
                                            let roomId = "\(roomData["id"])"
                                            let unread = roomData["unread_count"].intValue
                                            if let room = QRoom.room(withId: roomId){
                                                let lastCommentData = roomData["last_comment"]
                                                let lastComment = QComment.tempComment(fromJSON: lastCommentData)
                                                room.updateLastComentInfo(comment: lastComment)
                                                roomResult.append(room)
                                            }else{
                                                let room = QRoom.room(fromJSON: roomData)
                                                room.updateUnreadCommentCount(count: unread)
                                                roomResult.append(room)
                                            }
                                            let progress = Double(Double(recordedRoom + i)/(Double(totalRoom)))
                                            let loadedRoom = recordedRoom + i
                                            
                                            onProgress?(progress, loadedRoom, totalRoom)
                                            i += 1
                                        }
                                        onSuccess(roomResult,totalRoom,currentPage,limit)
                                    }
                                    
                                    if Thread.isMainThread{
                                        proceed()
                                    }else{
                                        DispatchQueue.main.sync {
                                            proceed()
                                        }
                                    }
                                }else{
                                    onFailed("can't load room list")
                                }
                            }else{
                                onFailed("can't load room list")
                            }
                            break
                        case .failure(let error):
                            onFailed("\(error.localizedDescription)")
                            break
                        }
                    })
                }
            }
        } else {
            onFailed("unauthorized")
        }
    }
    internal class func getRoom(withId id:String){
        if Qiscus.isLoggedIn {
            QiscusRequestThread.async {
                let parameters:[String: AnyObject] = [
                    "token"  : qiscus.config.USER_TOKEN as AnyObject,
                    "room_id" : [id] as AnyObject,
                    "show_participants": true as AnyObject
                ]
                QiscusService.session.request(QiscusConfig.ROOMINFO_URL, method: .post, parameters: parameters, encoding: URLEncoding.default, headers: QiscusConfig.sharedInstance.requestHeader).responseJSON(completionHandler: { response in
                    
                    switch response.result {
                    case .success:
                        if let result = response.result.value{
                            let json = JSON(result)
                            let success:Bool = (json["status"].intValue == 200)
                            if success {
                                let resultData = json["results"]
                                let roomsData = resultData["rooms_info"].arrayValue
                                if roomsData.count > 0 {
                                    let roomData = roomsData[0]
                                    let roomId = "\(roomData["id"])"
                                    let unread = roomData["unread_count"].intValue
                                    if let room = QRoom.room(withId: roomId){
                                        let lastCommentData = roomData["last_comment"]
                                        let lastComment = QComment.tempComment(fromJSON: lastCommentData)
                                        if !room.isInvalidated {
                                            room.updateLastComentInfo(comment: lastComment)
                                            room.updateUnreadCommentCount(count: unread)
                                            DispatchQueue.main.async {
                                                if let r = QRoom.room(withId: roomId){
                                                    if let c = r.lastComment {
                                                        QiscusNotification.publish(gotNewComment: c, room: r)
                                                    }
                                                }
                                            }
                                        }
                                    }else{
                                        let lastCommentData = roomData["last_comment"]
                                        let lastComment = QComment.tempComment(fromJSON: lastCommentData)
                                        let room = QRoom.room(fromJSON: roomData)
                                        if !room.isInvalidated {
                                            room.updateUnreadCommentCount(count: unread)
                                            room.updateLastComentInfo(comment: lastComment)
                                            DispatchQueue.main.async {
                                                if let r = QRoom.room(withId: roomId){
                                                    if let c = r.lastComment {
                                                        QiscusNotification.publish(gotNewComment: c, room: r)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        break
                    case .failure(let error):
                        Qiscus.printLog(text: "error getting room: \(error.localizedDescription)")
                        break
                    }
                })
            }
        } else {
            #if DEBUG
                preconditionFailure("please call Qiscus.setup first")
            #endif
            Qiscus.printLog(text: "unauthorized")
        }
    }
    public class func roomInfo(withId id:String, lastCommentUpdate:Bool = true, onSuccess:@escaping ((QRoom)->Void), onFailed: @escaping ((String)->Void)){
        if id.isEmpty {
            onFailed("id cant be empty")
            Qiscus.printLog(text: "id cant be empty")
            return
        }
        QiscusRequestThread.async {
            let parameters:[String: AnyObject] = [
                "token"  : qiscus.config.USER_TOKEN as AnyObject,
                "room_id" : [id] as AnyObject,
                "show_participants": true as AnyObject
            ]
            QiscusService.session.request(QiscusConfig.ROOMINFO_URL, method: .post, parameters: parameters, encoding: URLEncoding.default, headers: QiscusConfig.sharedInstance.requestHeader).responseJSON(completionHandler: { response in
                
                switch response.result {
                case .success:
                    if let result = response.result.value{
                        let json = JSON(result)
                        let success:Bool = (json["status"].intValue == 200)
                        if success {
                            let resultData = json["results"]
                            let roomsData = resultData["rooms_info"].arrayValue
                            if roomsData.count > 0 {
                                let roomData = roomsData[0]
                                func execute(){
                                    let roomId = "\(roomData["id"])"
                                    let unread = roomData["unread_count"].intValue
                                    if let room = QRoom.room(withId: roomId){
                                        let lastCommentData = roomData["last_comment"]
                                        let lastComment = QComment.tempComment(fromJSON: lastCommentData)
                                        if !room.isInvalidated {
                                            if lastCommentUpdate {
                                                room.updateLastComentInfo(comment: lastComment)
                                            }
                                            room.updateUnreadCommentCount(count: unread)
                                            onSuccess(room)
                                        }else{
                                            onFailed("room has been deleted")
                                        }
                                    }else{
                                        let room = QRoom.room(fromJSON: roomData)
                                        if !room.isInvalidated {
                                            room.updateUnreadCommentCount(count: unread)
                                            onSuccess(room)
                                        }else{
                                            onFailed("room has been deleted")
                                        }
                                    }
                                }
                                
                                if Thread.isMainThread {
                                    execute()
                                }else{
                                    DispatchQueue.main.sync {
                                        autoreleasepool {
                                            execute()
                                        }
                                    }
                                }
                            }else{
                                func execute(){
                                    if let chatView = Qiscus.shared.chatViews[id] {
                                        if chatView.isPresence {
                                            chatView.goBack()
                                        }
                                        Qiscus.shared.chatViews[id] = nil
                                    }
                                    Qiscus.chatRooms[id] = nil
                                    
                                    if let room = QRoom.room(withId: id){
                                        if !room.isInvalidated {
                                            room.unsubscribeRealtimeStatus()
                                            QRoom.deleteRoom(room: room)
                                        }
                                    }
                                    QiscusNotification.publish(roomDeleted: id)
                                }
                                if Thread.isMainThread {
                                    execute()
                                }else{
                                    DispatchQueue.main.sync {
                                        autoreleasepool{
                                            execute()
                                        }
                                    }
                                }
                                onFailed("noAccess to room")
                            }
                        }else{
                            onFailed("can't get search result")
                        }
                    }else{
                        onFailed("can't get search result")
                    }
                    break
                case .failure(let error):
                    onFailed("\(error.localizedDescription)")
                    break
                }
            })
        }
    }
    
    public class func roomsInfo(withIds ids:[String], onSuccess:@escaping (([QRoom])->Void), onFailed: @escaping ((String)->Void)){
        if ids.isEmpty || (ids.count == 1 && ids[0].isEmpty) {
            onFailed("id cant be empty or empty value")
            Qiscus.printLog(text: "id cant be empty or empty value")
        }
        QiscusRequestThread.async {
            let parameters:[String: AnyObject] = [
                "token"  : qiscus.config.USER_TOKEN as AnyObject,
                "room_id" : ids as AnyObject,
                "show_participants": true as AnyObject
            ]
            Qiscus.printLog(text: "rooms info url: \(QiscusConfig.SEARCH_URL)")
            Qiscus.printLog(text: "rooms info parameters: \(parameters)")
            QiscusService.session.request(QiscusConfig.ROOMINFO_URL, method: .post, parameters: parameters, encoding: URLEncoding.default, headers: QiscusConfig.sharedInstance.requestHeader).responseJSON(completionHandler: { response in
                Qiscus.printLog(text: "rooms info result: \(response)")
                switch response.result {
                case .success:
                    if let result = response.result.value{
                        let json = JSON(result)
                        let success:Bool = (json["status"].intValue == 200)
                        
                        if success {
                            let resultData = json["results"]
                            let roomsData = resultData["rooms_info"].arrayValue
                            
                            if roomsData.count > 0 {
                                func execute(){
                                    var rooms = [QRoom]()
                                    for roomData in roomsData {
                                        let roomId = "\(roomData["id"])"
                                        let unread = roomData["unread_count"].intValue
                                        if let room = QRoom.room(withId: roomId){
                                            let lastCommentData = roomData["last_comment"]
                                            let lastComment = QComment.tempComment(fromJSON: lastCommentData)
                                            room.updateLastComentInfo(comment: lastComment)
                                            rooms.append(room)
                                        }else{
                                            let room = QRoom.room(fromJSON: roomData)
                                            room.updateUnreadCommentCount(count: unread)
                                            rooms.append(room)
                                        }
                                    }
                                    onSuccess(rooms)
                                }
                                if Thread.isMainThread {
                                    execute()
                                }else{
                                    DispatchQueue.main.sync {
                                        autoreleasepool{
                                            execute()
                                        }
                                    }
                                }
                            }else{
                                onFailed("all requested room not found")
                            }
                        }else{
                            onFailed("can't get rooms info")
                        }
                    }else{
                        onFailed("can't get rooms info")
                    }
                    break
                case .failure(let error):
                    onFailed("\(error.localizedDescription)")
                    break
                }
            })
        }
    }
    public class func roomInfo(withUniqueId uniqueId:String, onSuccess:@escaping ((QRoom)->Void), onFailed: @escaping ((String)->Void)){
        if uniqueId.isEmpty {
            onFailed("uniqueId cant be empty")
            Qiscus.printLog(text: "uniqueId cant be empty")
        }
        QiscusRequestThread.async {
            let parameters:[String: AnyObject] = [
                "token"  : qiscus.config.USER_TOKEN as AnyObject,
                "room_unique_id" : [uniqueId] as AnyObject,
                "show_participants": false as AnyObject
            ]
            Qiscus.printLog(text: "room info url: \(QiscusConfig.ROOMINFO_URL)")
            Qiscus.printLog(text: "room info parameters: \(parameters)")
            QiscusService.session.request(QiscusConfig.ROOMINFO_URL, method: .post, parameters: parameters, encoding: URLEncoding.default, headers: QiscusConfig.sharedInstance.requestHeader).responseJSON(completionHandler: { response in
                switch response.result {
                case .success:
                    if let result = response.result.value{
                        let json = JSON(result)
                        let success:Bool = (json["status"].intValue == 200)
                        
                        if success {
                            let resultData = json["results"]
                            let roomsData = resultData["rooms_info"].arrayValue
                            
                            if roomsData.count > 0 {
                                let roomData = roomsData[0]
                                func execute(){
                                    let roomId = "\(roomData["id"])"
                                    let unread = roomData["unread_count"].intValue
                                    if let room = QRoom.room(withId: roomId){
                                        if !room.isInvalidated {
                                            let lastCommentData = roomData["last_comment"]
                                            let lastComment = QComment.tempComment(fromJSON: lastCommentData)
                                            room.updateUnreadCommentCount(count: unread)
                                            room.updateLastComentInfo(comment: lastComment)
                                            onSuccess(room)
                                        }else{
                                            let room = QRoom.room(fromJSON: roomData)
                                            room.updateUnreadCommentCount(count: unread)
                                            onSuccess(room)
                                        }
                                    }else{
                                        let room = QRoom.room(fromJSON: roomData)
                                        room.updateUnreadCommentCount(count: unread)
                                        onSuccess(room)
                                    }
                                }
                                if Thread.isMainThread {
                                    execute()
                                }else{
                                    DispatchQueue.main.sync {
                                        autoreleasepool{
                                            execute()
                                        }
                                    }
                                }
                            }else{
                                onFailed("room notfound")
                            }
                        }else{
                            onFailed("can't get search result")
                        }
                    }else{
                        onFailed("can't get search result")
                    }
                    break
                case .failure(let error):
                    onFailed("\(error.localizedDescription)")
                    break
                }
            })
        }
    }
    
    public class func roomsInfo(withUniqueIds uniqueIds:[String], onSuccess:@escaping (([QRoom])->Void), onFailed: @escaping ((String)->Void)){
        if uniqueIds.isEmpty || (uniqueIds.count == 1 && uniqueIds[0].isEmpty) {
            onFailed("uniqueIds cant be empty or empty value")
            Qiscus.printLog(text: "uniqueIds cant be empty or empty value")
        }
        QiscusRequestThread.async {
            let parameters:[String: AnyObject] = [
                "token"  : qiscus.config.USER_TOKEN as AnyObject,
                "room_unique_id" : uniqueIds as AnyObject,
                "show_participants": false as AnyObject
            ]
            Qiscus.printLog(text: "rooms info url: \(QiscusConfig.SEARCH_URL)")
            Qiscus.printLog(text: "rooms info parameters: \(parameters)")
            QiscusService.session.request(QiscusConfig.ROOMINFO_URL, method: .post, parameters: parameters, encoding: URLEncoding.default, headers: QiscusConfig.sharedInstance.requestHeader).responseJSON(completionHandler: { response in
                Qiscus.printLog(text: "rooms info result: \(response)")
                switch response.result {
                case .success:
                    if let result = response.result.value{
                        let json = JSON(result)
                        let success:Bool = (json["status"].intValue == 200)
                        
                        if success {
                            let resultData = json["results"]
                            let roomsData = resultData["rooms_info"].arrayValue
                            
                            if roomsData.count > 0 {
                                func execute(){
                                    var rooms = [QRoom]()
                                    for roomData in roomsData {
                                        let roomId = "\(roomData["id"])"
                                        let unread = roomData["unread_count"].intValue
                                        if let room = QRoom.room(withId: roomId){
                                            let lastCommentData = roomData["last_comment"]
                                            let lastComment = QComment.tempComment(fromJSON: lastCommentData)
                                            room.updateLastComentInfo(comment: lastComment)
                                            rooms.append(room)
                                        }else{
                                            let room = QRoom.room(fromJSON: roomData)
                                            room.updateUnreadCommentCount(count: unread)
                                            rooms.append(room)
                                        }
                                    }
                                    onSuccess(rooms)
                                }
                                if Thread.isMainThread {
                                    execute()
                                }else{
                                    DispatchQueue.main.sync {
                                        execute()
                                    }
                                }
                            }else{
                                onFailed("all requested room not found")
                            }
                        }else{
                            onFailed("can't get rooms info")
                        }
                    }else{
                        onFailed("can't get rooms info")
                    }
                    break
                case .failure(let error):
                    onFailed("\(error.localizedDescription)")
                    break
                }
            })
        }
    }
    public class func searchComment(withQuery text:String, room:QRoom? = nil, fromComment:QComment? = nil, onSuccess:@escaping (([QComment])->Void), onFailed: @escaping ((String)->Void)){
        let roomId:String? = room?.id
        let commentId:Int? = fromComment?.id
        if text.trimmingCharacters(in: .whitespacesAndNewlines) == "" {
            onFailed("cant search empty string")
            return
        }
        
        if Qiscus.isLoggedIn {
            QiscusRequestThread.async {
                var parameters:[String: AnyObject] = [
                    "token"  : qiscus.config.USER_TOKEN as AnyObject,
                    "query" : text as AnyObject,
                    ]
                if roomId != nil {
                    parameters["room_id"] = roomId as AnyObject
                }
                if commentId != nil {
                    parameters["last_comment_id"] = commentId as AnyObject
                }
                Qiscus.printLog(text: "search url: \(QiscusConfig.SEARCH_URL)")
                Qiscus.printLog(text: "search parameters: \(parameters)")
                QiscusService.session.request(QiscusConfig.SEARCH_URL, method: .post, parameters: parameters, encoding: URLEncoding.default, headers: QiscusConfig.sharedInstance.requestHeader).responseJSON(completionHandler: { response in
                    Qiscus.printLog(text: "search result: \(response)")
                    switch response.result {
                    case .success:
                        if let result = response.result.value{
                            let json = JSON(result)
                            let success:Bool = (json["status"].intValue == 200)
                            
                            if success {
                                let resultData = json["results"]
                                let comments = resultData["comments"].arrayValue
                                
                                func execute(){
                                    var commentResult = [QComment]()
                                    for commentData in comments {
                                        let uniqueId = commentData["unique_temp_id"].stringValue
                                        if let comment = QComment.comment(withUniqueId: uniqueId){
                                            commentResult.append(comment)
                                        }else{
                                            let comment = QComment.tempComment(fromJSON: commentData)
                                            commentResult.append(comment)
                                        }
                                    }
                                    onSuccess(commentResult)
                                }
                                if Thread.isMainThread {
                                    execute()
                                }else{
                                    DispatchQueue.main.sync {
                                        execute()
                                    }
                                }
                            }else{
                                onFailed("can't get search result")
                            }
                        }else{
                            onFailed("can't get search result")
                        }
                        break
                    case .failure(let error):
                        onFailed("\(error.localizedDescription)")
                        break
                    }
                })
            }
        } else {
            #if DEBUG
                preconditionFailure("please call Qiscus.setup first")
            #endif
            Qiscus.printLog(text: "unauthorized")
        }
    }
    
    internal class func downloadImage(url:String, onSuccess:@escaping ((Data)->Void), onFailed: @escaping ((String)->Void)){
        QiscusRequestThread.async {
            QiscusService.session.request(url, method: .get, parameters: nil, encoding: URLEncoding.default, headers: nil).responseData(completionHandler: { response in
                switch response.result {
                case .success:
                    if let imageData = response.data {
                        if let _ = UIImage(data: imageData) {
                            DispatchQueue.main.async {
                                onSuccess(imageData)
                            }
                        }
                    }
                    break
                case .failure:
                    DispatchQueue.main.async {
                        onFailed("fail to download image: \(url)")
                    }
                    break
                }
            })
        }
    }
    
    internal class func syncEvent(){
        if QChatService.inSyncEvent { return }
        if Qiscus.client.lastEventId == "" { return }
        
        guard let lastEventId = Int64(Qiscus.client.lastEventId) else { return }
        
        DispatchQueue.main.async {
            if UIApplication.shared.applicationState != .active {
                Qiscus.printLog(text: "sync qiscus event on background")
            }
        }
        func getTime()->String{
            let date = Date()
            let df = DateFormatter()
            df.dateFormat = "y-MM-dd H:m:ss"
            return df.string(from: date)
        }
        QiscusRequestThread.sync {
            Qiscus.printLog(text: "Start event syncing on  \(getTime())")
            QChatService.inSyncEvent = true
            
            let loadURL = QiscusConfig.SYNC_EVENT_URL
            
            let parameters:[String: AnyObject] =  [
                "token" : qiscus.config.USER_TOKEN as AnyObject,
                "start_event_id" : lastEventId as AnyObject,
            ]
            QiscusService.session.request(loadURL, method: .get, parameters: parameters, encoding: URLEncoding.default, headers: QiscusConfig.sharedInstance.requestHeader).responseJSON(completionHandler: {responseData in
                if let response = responseData.result.value {
                    let json = JSON(response)
                    let eventsData = json["events"].arrayValue
                    
                    for eventJSON in eventsData.reversed() {
                        let action = eventJSON["action_topic"].stringValue
                        let payload = eventJSON["payload"]
                        let eventId = "\(eventJSON["id"])"
                        
                        switch action {
                        case "delete_message":
                            let data = payload["data"]
                            let hardDelete = data["is_hard_delete"].boolValue
                            let rooms = data["deleted_messages"].arrayValue
                            
                            for roomJSON in rooms {
                                let roomId = roomJSON["room_id"].stringValue
                                if let room = QRoom.threadSaveRoom(withId: roomId){
                                    let comments = roomJSON["message_unique_ids"].arrayValue
                                    for commentJSON in comments {
                                        let uid = commentJSON.stringValue
                                        if let c = QComment.threadSaveComment(withUniqueId: uid){
                                            if hardDelete {
//                                                c.updateStatus(status: .deleted)
                                                room.deleteComment(comment: c)
                                            }else{
                                                c.updateStatus(status: .deleted)
                                            }
                                        }
                                    }
                                }
                            }
                            
                            break
                        default:break
                        }
                        QiscusClient.update(lastEventId: eventId)
                    }
                }
                QChatService.inSyncEvent = false
            })
        }
    }
}
