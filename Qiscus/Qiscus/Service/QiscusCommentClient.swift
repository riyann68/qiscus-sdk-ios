//
//  QiscusCommentClient.swift
//  QiscusSDK
//
//  Created by ahmad athaullah on 7/17/16.
//  Copyright © 2016 qiscus. All rights reserved.
//

import Foundation
import UIKit
import Alamofire
import AlamofireImage
import SwiftyJSON
import AVFoundation
import Photos
import UserNotifications
import CocoaMQTT

fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l > r
  default:
    return rhs < lhs
  }
}

let qiscus = Qiscus.sharedInstance

open class QiscusCommentClient: NSObject {
    open static let sharedInstance = QiscusCommentClient()
    
    class var shared:QiscusCommentClient{
        get{
            return QiscusCommentClient.sharedInstance
        }
    }
    
    open var commentDelegate: QCommentDelegate?
    open var roomDelegate: QiscusRoomDelegate?
    open var linkRequest: Alamofire.Request?
    
    
    // MARK: - Login or register
    open func loginOrRegister(_ email:String = "", password:String = "", username:String? = nil, avatarURL:String? = nil, reconnect:Bool = false, onSuccess:(()->Void)? = nil){
        
        var parameters:[String: AnyObject] = [String: AnyObject]()
        
        parameters = [
            "email"  : email as AnyObject,
            "password" : password as AnyObject,
        ]
        
        if let name = username{
            parameters["username"] = name as AnyObject?
        }
        if let avatar =  avatarURL{
            parameters["avatar_url"] = avatar as AnyObject?
        }
        
        DispatchQueue.global().async(execute: {
            Qiscus.printLog(text: "login url: \(QiscusConfig.LOGIN_REGISTER)")
            Qiscus.printLog(text: "post parameters: \(parameters)")
            Qiscus.printLog(text: "post headers: \(QiscusConfig.sharedInstance.requestHeader)")
            QiscusService.session.request(QiscusConfig.LOGIN_REGISTER, method: .post, parameters: parameters, encoding: URLEncoding.default, headers: QiscusConfig.sharedInstance.requestHeader).responseJSON(completionHandler: { response in
                Qiscus.printLog(text: "login register result: \(response)")
                Qiscus.printLog(text: "login url: \(QiscusConfig.LOGIN_REGISTER)")
                Qiscus.printLog(text: "post parameters: \(parameters)")
                Qiscus.printLog(text: "post headers: \(QiscusConfig.sharedInstance.requestHeader)")
                switch response.result {
                    case .success:
                        if let result = response.result.value{
                            let json = JSON(result)
                            let success:Bool = (json["status"].intValue == 200)
                            if success {
                                let userData = json["results"]["user"]
                                let _ = QiscusClient.saveData(fromJson: userData, reconnect: reconnect)
                                Qiscus.setupReachability()
                                if let delegate = Qiscus.shared.delegate {
                                    Qiscus.uiThread.async { autoreleasepool{
                                        delegate.qiscus?(didConnect: true, error: nil)
                                        delegate.qiscusConnected?()
                                    }}
                                }
                                Qiscus.registerNotification()
                                if let successAction = onSuccess {
                                    Qiscus.uiThread.async { autoreleasepool{
                                        successAction()
                                    }}
                                }
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
        })
    }
    // MARK: - Register deviceToken
    func registerDevice(withToken deviceToken: String){
        func register(){
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
                switch response.result {
                case .success:
                    DispatchQueue.main.async(execute: {
                        if let result = response.result.value{
                            let json = JSON(result)
                            let success:Bool = (json["status"].intValue == 200)
                            
                            if success {
                                let pnData = json["results"]
                                let configured = pnData["pn_ios_configured"].boolValue
                                if configured {
                                    if let delegate = Qiscus.shared.delegate {
                                        delegate.qiscus?(didRegisterPushNotification: true, deviceToken: deviceToken, error: nil)
                                    }
                                }else{
                                    if let delegate = Qiscus.shared.delegate {
                                        delegate.qiscus?(didRegisterPushNotification: false, deviceToken: deviceToken, error: "unsuccessful register deviceToken : pushNotification not configured")
                                    }
                                }
                            }else{
                                if let delegate = Qiscus.shared.delegate {
                                    delegate.qiscus?(didRegisterPushNotification: false, deviceToken: deviceToken, error: "unsuccessful register deviceToken")
                                }
                            }
                        }else{
                            if let delegate = Qiscus.shared.delegate {
                                delegate.qiscus?(didRegisterPushNotification: false, deviceToken: deviceToken, error: "unsuccessful register deviceToken")
                            }
                        }
                    })
                    break
                case .failure(let error):
                    if let delegate = Qiscus.shared.delegate{
                        delegate.qiscus?(didRegisterPushNotification: false, deviceToken: deviceToken, error: "unsuccessful register deviceToken: \(error)")
                    }
                    break
                }
            })
        }
        if Qiscus.isLoggedIn {
            register()
        }else{
            reconnect {
                register()
            }
        }
        
    }
    private func reconnect(onSuccess:@escaping (()->Void)){
        let email = Qiscus.client.userData.value(forKey: "qiscus_param_email") as? String
        let userKey = Qiscus.client.userData.value(forKey: "qiscus_param_pass") as? String
        let userName = Qiscus.client.userData.value(forKey: "qiscus_param_username") as? String
        let avatarURL = Qiscus.client.userData.value(forKey: "qiscus_param_avatar") as? String
        if email != nil && userKey != nil && userName != nil {
            QiscusCommentClient.sharedInstance.loginOrRegister(email!, password: userKey!, username: userName!, avatarURL: avatarURL, reconnect: true, onSuccess: onSuccess)
        }
        
    }
    // MARK: - Remove deviceToken
    public func unRegisterDevice(){
        if Qiscus.client.deviceToken != "" {
            let parameters:[String: AnyObject] = [
                "token"  : qiscus.config.USER_TOKEN as AnyObject,
                "device_token" : Qiscus.client.deviceToken as AnyObject,
                "device_platform" : "ios" as AnyObject
            ]
            
            QiscusService.session.request(QiscusConfig.REMOVE_DEVICE_TOKEN_URL, method: .post, parameters: parameters, encoding: URLEncoding.default, headers: QiscusConfig.sharedInstance.requestHeader).responseJSON(completionHandler: { response in
                switch response.result {
                case .success:
                    DispatchQueue.main.async(execute: {
                        if let result = response.result.value{
                            let json = JSON(result)
                            let success:Bool = (json["status"].intValue == 200)
                            
                            if success {
                                let pnData = json["results"]
                                let success = pnData["success"].boolValue
                                if success {
                                    if let delegate = Qiscus.shared.delegate{
                                        delegate.qiscus?(didUnregisterPushNotification: true, error: nil)
                                        Qiscus.client.deviceToken = ""
                                    }
                                }else{
                                    if let delegate = Qiscus.shared.delegate{
                                        delegate.qiscus?(didUnregisterPushNotification: false, error: "cannot unregister device")
                                    }
                                    DispatchQueue.global().async { autoreleasepool{
                                        self.unRegisterDevice()
                                    }}
                                }
                            }else{
                                if let delegate = Qiscus.shared.delegate {
                                    delegate.qiscus?(didUnregisterPushNotification: false, error: "cannot unregister device")
                                }
                            }
                        }else{
                            if let delegate = Qiscus.shared.delegate {
                                delegate.qiscus?(didUnregisterPushNotification: false, error: "cannot unregister device")
                            }
                        }
                    })
                    break
                case .failure( _):
                    if let delegate = Qiscus.shared.delegate {
                        delegate.qiscus?(didUnregisterPushNotification: false, error: "cannot unregister device")
                    }
                    break
                }
            })
        }
    }

}
