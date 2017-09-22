//
//  Qiscus.swift
//
//  Created by Ahmad Athaullah on 7/17/16.
//  Copyright © 2016 qiscus. All rights reserved.
//


import UIKit
import RealmSwift
import Foundation
import SwiftyJSON
import PushKit
import UserNotifications
import CocoaMQTT

var QiscusFileThread = DispatchQueue(label: "com.qiscus.file", attributes: .concurrent)
var QiscusRequestThread = DispatchQueue(label: "com.qiscus.request", attributes: .concurrent)
var QiscusUploadThread = DispatchQueue(label: "com.qiscus.upload", attributes: .concurrent)
var QiscusBackgroundThread = DispatchQueue(label: "com.qiscus.background", attributes: .concurrent)
var QiscusDBThread = DispatchQueue(label: "com.qiscus.db", attributes: .concurrent)

@objc public class Qiscus: NSObject, PKPushRegistryDelegate, UNUserNotificationCenterDelegate {
    
    static let sharedInstance = Qiscus()
    
    static let qiscusVersionNumber:String = "2.5.3"
    
    static let showDebugPrint = true
    
    // MARK: - Thread
    static let uiThread = DispatchQueue.main
    
    static var qiscusDeviceToken: String = ""
    static var dbConfiguration = Realm.Configuration.defaultConfiguration
    static var chatRooms = [Int : QRoom]()
    static var qiscusDownload:[String] = [String]()
    
    var backgroundTask: UIBackgroundTaskIdentifier = UIBackgroundTaskInvalid
    
    public static var chatDelegate:QiscusChatDelegate?
    
    static var realtimeConnected:Bool{
        get{
            return Qiscus.shared.mqtt?.connState == .connected
        }
    }
    internal static var publishStatustimer:Timer?
    internal static var realtimeChannel = [String]()
    
    var config = QiscusConfig.sharedInstance
    var commentService = QiscusCommentClient.sharedInstance
    
    public var iCloudUpload = false
    public var cameraUpload = true
    public var galeryUpload = true
    public var contactShare = true
    public var locationShare = true
    
    var isPushed:Bool = false
    var reachability:QReachability?
    internal var mqtt:CocoaMQTT?
    var notificationAction:((QiscusChatVC)->Void)? = nil
    var syncing = false
    var syncTimer: Timer?
    var delegate:QiscusConfigDelegate?
    
    @objc public var styleConfiguration = QiscusUIConfiguration.sharedInstance
    @objc public var connected:Bool = false
    @objc public var httpRealTime:Bool = false
    @objc public var toastMessageAct:((_ roomId:Int, _ comment:QComment)->Void)?
    
    let application = UIApplication.shared
    let appDelegate = UIApplication.shared.delegate
    
    public var chatViews = [Int:QiscusChatVC]()
    
    @objc public class var versionNumber:String{
        get{
            return Qiscus.qiscusVersionNumber
        }
    }
    @objc public class var shared:Qiscus{
        get{
            return Qiscus.sharedInstance
        }
    }
    @objc public class var isLoggedIn:Bool{
        get{
            return QiscusMe.isLoggedIn
        }
    }
    @objc public class var deviceToken:String{
        get{
            return Qiscus.qiscusDeviceToken
        }
    }
    @objc public class var style:QiscusUIConfiguration{
        get{
            return Qiscus.sharedInstance.styleConfiguration
        }
    }
    
    class var commentService:QiscusCommentClient{
        get{
            return QiscusCommentClient.sharedInstance
        }
    }
    
    fileprivate override init(){
        
    }
    
    class var bundle:Bundle{
        get{
            let podBundle = Bundle(for: Qiscus.self)
            
            if let bundleURL = podBundle.url(forResource: "Qiscus", withExtension: "bundle") {
                return Bundle(url: bundleURL)!
            }else{
                return podBundle
            }
        }
    }
    
    /**
     Class function to disable notification when **In App**
     */
    @objc public class func disableInAppNotif(){
        Qiscus.sharedInstance.config.showToasterMessage = false
    }
    /**
     Class function to enable notification when **In App**
     */
    @objc public class func enableInAppNotif(){
        Qiscus.sharedInstance.config.showToasterMessage = true
    }
    
    class func disconnectRealtime(){
        Qiscus.uiThread.async { autoreleasepool{
            Qiscus.sharedInstance.mqtt?.disconnect()
        }}
    }
    
    @objc public class func clear(){
        Qiscus.clearData()
        Qiscus.publishUserStatus(offline: true)
        Qiscus.shared.mqtt?.disconnect()
        Qiscus.unRegisterPN()
        QiscusMe.clear()
    }
    @objc public class func clearData(){
        Qiscus.chatRooms = [Int : QRoom]()
        QParticipant.cache = [String : QParticipant]()
        QCommentGroup.cache = [String : QCommentGroup]()
        QComment.cache = [String : QComment]()
        QUser.cache = [String: QUser]()
        Qiscus.shared.chatViews = [Int:QiscusChatVC]()
        
        Qiscus.dbConfiguration.deleteRealmIfMigrationNeeded = true
        Qiscus.dbConfiguration.schemaVersion = Qiscus.shared.config.dbSchemaVersion
        let realm = try! Realm(configuration: Qiscus.dbConfiguration)
        try! realm.write {
            realm.deleteAll()
        }
        Qiscus.deleteAllFiles()
    }
    @objc public class func unRegisterPN(){
        if Qiscus.isLoggedIn {
            QiscusCommentClient.sharedInstance.unRegisterDevice()
        }
    }
    // need Documentation
    func backgroundCheck(){
        if Qiscus.isLoggedIn{
            QiscusBackgroundThread.async { autoreleasepool{
                if Qiscus.shared.mqtt?.connState != CocoaMQTTConnState.connected {
                    Qiscus.mqttConnect()
                }else{
                    QChatService.sync()
                }
            }}
        }
    }
    func checkChat(){
        if Qiscus.isLoggedIn{
            Qiscus.mqttConnect(chatOnly: true)
        }
    }
    func RealtimeConnect(){
        NotificationCenter.default.removeObserver(self, name: .UIApplicationDidBecomeActive, object: nil)
        NotificationCenter.default.removeObserver(self, name: .UIApplicationDidEnterBackground, object: nil)
        
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(Qiscus.applicationDidBecomeActife), name: .UIApplicationDidBecomeActive, object: nil)
        center.addObserver(self, selector: #selector(Qiscus.goToBackgroundMode), name: .UIApplicationDidEnterBackground, object: nil)
        if Qiscus.isLoggedIn {
            Qiscus.mqttConnect()
        }
    }
    public class func connect(delegate:QiscusConfigDelegate? = nil){
        Qiscus.shared.RealtimeConnect()
        if delegate != nil {
            Qiscus.shared.delegate = delegate
        }
    }
    public class func updateProfile(username:String? = nil, avatarURL:String? = nil, onSuccess:@escaping (()->Void), onFailed:@escaping ((String)->Void)) {
        QChatService.updateProfil(userName: username, userAvatarURL: avatarURL, onSuccess: onSuccess, onError: onFailed)
    }
    @objc public class func setup(withAppId appId:String, userEmail:String, userKey:String, username:String, avatarURL:String? = nil, delegate:QiscusConfigDelegate? = nil, secureURl:Bool = true){
        Qiscus.checkDatabaseMigration()
        var requestProtocol = "https"
        if !secureURl {
            requestProtocol = "http"
        }
        let email = userEmail.lowercased()
        let baseUrl = "\(requestProtocol)://\(appId).qiscus.com/api/v2/mobile"
        
        QiscusMe.sharedInstance.baseUrl = baseUrl
        QiscusMe.sharedInstance.userData.set(baseUrl, forKey: "qiscus_base_url")
        QiscusMe.sharedInstance.userData.set(email, forKey: "qiscus_param_email")
        QiscusMe.sharedInstance.userData.set(userKey, forKey: "qiscus_param_pass")
        QiscusMe.sharedInstance.userData.set(username, forKey: "qiscus_param_username")
        
        if avatarURL != nil{
            QiscusMe.sharedInstance.userData.set(avatarURL, forKey: "qiscus_param_avatar")
        }
        if delegate != nil {
            Qiscus.shared.delegate = delegate
        }
        var needLogin = false
        
        if QiscusMe.isLoggedIn {
            if email != QiscusMe.sharedInstance.email{
                needLogin = true
            }
        }else{
            needLogin = true
        }
        Qiscus.setupReachability()
        if needLogin {
            Qiscus.clear()
            QiscusCommentClient.sharedInstance.loginOrRegister(userEmail, password: userKey, username: username, avatarURL: avatarURL)
        }else{
            if let delegate = Qiscus.shared.delegate {
                Qiscus.uiThread.async { autoreleasepool{
                    delegate.qiscusConnected?()
                    delegate.qiscus?(didConnect: true, error: nil)
                }}
            }
        }
        Qiscus.sharedInstance.RealtimeConnect()
    }
    @objc public class func setup(withURL baseUrl:String, userEmail:String, id:Int, username:String, userKey:String, delegate:QiscusConfigDelegate? = nil, secureURl:Bool = true, realTimeKey:String){
//        Qiscus.checkDatabaseMigration()
        let email = userEmail.lowercased()
        
        QiscusMe.sharedInstance.baseUrl = "\(baseUrl)/api/v2/mobile"
        QiscusMe.sharedInstance.id = id
        QiscusMe.sharedInstance.email = email
        QiscusMe.sharedInstance.userName = username
        QiscusMe.sharedInstance.token = userKey
        QiscusMe.sharedInstance.rtKey = realTimeKey
        
        QiscusMe.sharedInstance.userData.set(realTimeKey, forKey: "qiscus_rt_key")
        QiscusMe.sharedInstance.userData.set(id, forKey: "qiscus_id")
        QiscusMe.sharedInstance.userData.set(baseUrl, forKey: "qiscus_base_url")
        QiscusMe.sharedInstance.userData.set(email, forKey: "qiscus_email")
        QiscusMe.sharedInstance.userData.set(username, forKey: "qiscus_username")
        QiscusMe.sharedInstance.userData.set(userKey, forKey: "qiscus_token")
        Qiscus.setupReachability()
        
        Qiscus.sharedInstance.RealtimeConnect()
        
        if delegate != nil {
            Qiscus.shared.delegate = delegate
        }
        Qiscus.uiThread.async {autoreleasepool{
            Qiscus.shared.delegate?.qiscusConnected?()
            Qiscus.shared.delegate?.qiscus?(didConnect: true, error: nil)
        }}
    }
    
    
    /**
     Class function to configure chat with user
     - parameter users: **String** users.
     - parameter readOnly: **Bool** to set read only or not (Optional), Default value : false.
     - parameter title: **String** text to show as chat title (Optional), Default value : "".
     - parameter subtitle: **String** text to show as chat subtitle (Optional), Default value : "" (empty string).
     */
//    @objc public class func chatVC(withUsers users:[String], readOnly:Bool = false, title:String = "", subtitle:String = "", distinctId:String? = nil, optionalData:String?=nil, withMessage:String? = nil)->QiscusChatVC{
//        Qiscus.checkDatabaseMigration()
//        if !Qiscus.sharedInstance.connected {
//            Qiscus.setupReachability()
//        }
//        
//        Qiscus.sharedInstance.isPushed = true
//        QiscusUIConfiguration.sharedInstance.copyright.chatSubtitle = subtitle
//        QiscusUIConfiguration.sharedInstance.copyright.chatTitle = title
//        
//        var chatVC = QiscusChatVC()
//        for (_,chatRoom) in Qiscus.sharedInstance.chatViews {
//            if let room = chatRoom.room {
//                if !room.isGroup {
//                    if let user = chatRoom.users?.first {
//                        if user == users.first! {
//                            chatVC = chatRoom
//                            break
//                        }
//                    }
//                }
//            }
//        }
//        if distinctId != nil{
//            chatVC.distincId = distinctId!
//        }else{
//            chatVC.distincId = ""
//        }
//        chatVC.optionalData = optionalData
//        chatVC.message = withMessage
//        chatVC.users = users
//        chatVC.optionalData = optionalData
//        chatVC.archived = readOnly
//        
//        if chatVC.isPresence {
//            chatVC.goBack()
//        }
//        chatVC.backAction = nil
//        
//        
//        return chatVC
//    }
    
    /**
     No Documentation
     */
    
    @objc public class func chat(withRoomId roomId:Int, target:UIViewController, readOnly:Bool = false, title:String = "", subtitle:String = "", distinctId:String? = nil, withMessage:String? = nil, optionalData:String?=nil){
//        Qiscus.checkDatabaseMigration()
        if !Qiscus.sharedInstance.connected {
            Qiscus.setupReachability()
        }
        
        Qiscus.sharedInstance.isPushed = false
        QiscusUIConfiguration.sharedInstance.copyright.chatSubtitle = subtitle
        QiscusUIConfiguration.sharedInstance.copyright.chatTitle = title
        
        let chatVC = QiscusChatVC()
        if distinctId != nil{
            chatVC.distincId = distinctId!
        }else{
            chatVC.distincId = ""
        }
        chatVC.roomId = roomId
        chatVC.optionalData = optionalData
        chatVC.message = withMessage
        chatVC.newRoom = false
        chatVC.archived = readOnly
        
        if chatVC.isPresence {
            chatVC.goBack()
        }
        
        chatVC.backAction = nil
        
        let navController = UINavigationController()
        navController.viewControllers = [chatVC]
        
        UIApplication.shared.keyWindow?.rootViewController?.present(navController, animated: true, completion: nil)
    }
    @objc public class func chat(withUsers users:[String], target:UIViewController, readOnly:Bool = false, title:String = "", subtitle:String = "", distinctId:String? = nil, withMessage:String? = nil, optionalData:String?=nil){
//        Qiscus.checkDatabaseMigration()
        if !Qiscus.sharedInstance.connected {
            Qiscus.setupReachability()
        }
        
        Qiscus.sharedInstance.isPushed = false
        QiscusUIConfiguration.sharedInstance.copyright.chatSubtitle = subtitle
        QiscusUIConfiguration.sharedInstance.copyright.chatTitle = title
        
        
        let chatVC = QiscusChatVC()
        //chatVC.reset()
        if distinctId != nil{
            chatVC.distincId = distinctId!
        }else{
            chatVC.distincId = ""
        }
        chatVC.optionalData = optionalData
        chatVC.message = withMessage
        chatVC.users = users
        chatVC.archived = readOnly
        
        if chatVC.isPresence {
            chatVC.goBack()
        }
        chatVC.backAction = nil
        
        let navController = UINavigationController()
        navController.viewControllers = [chatVC]
        
        UIApplication.shared.keyWindow?.rootViewController?.present(navController, animated: true, completion: nil)
    }
    /**
     No Documentation
     */
    @objc public class func chatView(withUsers users:[String], readOnly:Bool = false, title:String = "", subtitle:String = "", distinctId:String = "", withMessage:String? = nil)->QiscusChatVC{
        
        if let room = QRoom.room(withUser: users.first!) {
            return Qiscus.chatView(withRoomId: room.id, readOnly: readOnly, title: title, subtitle: subtitle, withMessage: withMessage)
        }else{
//            Qiscus.checkDatabaseMigration()
            if !Qiscus.sharedInstance.connected {
                Qiscus.setupReachability()
            }
            Qiscus.sharedInstance.isPushed = true
            
            let chatVC = QiscusChatVC()
            
            chatVC.chatUser = users.first!
            chatVC.chatTitle = title
            chatVC.chatSubtitle = subtitle
            chatVC.archived = readOnly
            chatVC.chatMessage = withMessage
            chatVC.backAction = nil
            if chatVC.isPresence {
                chatVC.goBack()
            }
            return chatVC
        }
    }
    /**
     No Documentation
     */
    @objc public class func chatView(withRoomUniqueId uniqueId:String, readOnly:Bool = false, title:String = "", avatarUrl:String = "", subtitle:String = "", withMessage:String? = nil)->QiscusChatVC{
        if let room = QRoom.room(withUniqueId: uniqueId){
            return Qiscus.chatView(withRoomId: room.id, readOnly: readOnly, title: title, subtitle: subtitle, withMessage: withMessage)
        }else{
//            Qiscus.checkDatabaseMigration()
            if !Qiscus.sharedInstance.connected {
                Qiscus.setupReachability()
            }
            Qiscus.sharedInstance.isPushed = true
            
            let chatVC = QiscusChatVC()
            
            chatVC.chatMessage = withMessage
            chatVC.chatRoomUniqueId = uniqueId
            chatVC.chatAvatarURL = avatarUrl
            chatVC.chatTitle = title
            
            if chatVC.isPresence {
                chatVC.goBack()
            }
            chatVC.backAction = nil
            chatVC.archived = readOnly
            return chatVC
        }
    }
    @objc public class func chatView(withRoomId roomId:Int, readOnly:Bool = false, title:String = "", subtitle:String = "", withMessage:String? = nil)->QiscusChatVC{
//        Qiscus.checkDatabaseMigration()
        if !Qiscus.sharedInstance.connected {
            Qiscus.setupReachability()
        }
        
        var chatVC = QiscusChatVC()
        
        if let chatView = Qiscus.shared.chatViews[roomId] {
            chatVC = chatView
        }else{
            chatVC.chatRoomId = roomId
        }
        chatVC.chatTitle = title
        chatVC.chatSubtitle = subtitle
        chatVC.archived = readOnly
        chatVC.chatMessage = withMessage
        chatVC.backAction = nil
        
        return chatVC
    }
    @objc public class func image(named name:String)->UIImage?{
        return UIImage(named: name, in: Qiscus.bundle, compatibleWith: nil)?.localizedImage()
    }
    /**
     Class function to unlock action chat
     - parameter action: **()->Void** as unlock action for your chat
     */
    @objc public class func unlockAction(_ action:@escaping (()->Void)){
        print("[Qiscus] - methode deprecated")
    }
    /**
     Class function to show alert in chat with UIAlertController
     - parameter alert: The **UIAlertController** to show alert message in chat
     */
    @objc public class func showChatAlert(alertController alert:UIAlertController){
        print("[Qiscus] - methode deprecated")
    }
    /**
     Class function to unlock chat
     */
    @objc public class func unlockChat(){
        print("[Qiscus] - methode deprecated")
    }
    /**
     Class function to lock chat
     */
    @objc public class func lockChat(){
        print("[Qiscus] - methode deprecated")
    }
    
    /**
     Class function to set color chat navigation with gradient
     - parameter topColor: The **UIColor** as your top gradient navigation color.
     - parameter bottomColor: The **UIColor** as your bottom gradient navigation color.
     - parameter tintColor: The **UIColor** as your tint gradient navigation color.
     */
    @objc public class func setGradientChatNavigation(_ topColor:UIColor, bottomColor:UIColor, tintColor:UIColor){
        Qiscus.shared.styleConfiguration.color.topColor = topColor
        Qiscus.shared.styleConfiguration.color.bottomColor = bottomColor
        Qiscus.shared.styleConfiguration.color.tintColor = tintColor
        
        for (_,chatView) in Qiscus.shared.chatViews {
            chatView.topColor = topColor
            chatView.bottomColor = bottomColor
            chatView.tintColor = tintColor
        }
    }
    /**
     Class function to set color chat navigation without gradient
     - parameter color: The **UIColor** as your navigation color.
     - parameter tintColor: The **UIColor** as your tint navigation color.
     */
    @objc public class func setNavigationColor(_ color:UIColor, tintColor: UIColor){
        Qiscus.shared.styleConfiguration.color.topColor = color
        Qiscus.shared.styleConfiguration.color.bottomColor = color
        Qiscus.shared.styleConfiguration.color.tintColor = tintColor
        for (_,chatView) in Qiscus.shared.chatViews {
            chatView.topColor = color
            chatView.bottomColor = color
            chatView.tintColor = tintColor
        }
    }
    
    /**
     Class function to set upload from iCloud active or not
     - parameter active: **Bool** to set active or not.
     */
    @objc public class func iCloudUploadActive(_ active:Bool){
        Qiscus.sharedInstance.iCloudUpload = active
    }
    
    class func setupReachability(){
        QiscusBackgroundThread.async {autoreleasepool{
            Qiscus.sharedInstance.reachability = QReachability()
            
            if let reachable = Qiscus.sharedInstance.reachability {
                if reachable.isReachable {
                    Qiscus.sharedInstance.connected = true
                    if Qiscus.isLoggedIn {
                        Qiscus.sharedInstance.RealtimeConnect()
                        DispatchQueue.main.async { autoreleasepool{
                            QComment.resendPendingMessage()
                        }}
                    }
                }
            }
            
            Qiscus.sharedInstance.reachability?.whenReachable = { reachability in
                if reachability.isReachableViaWiFi {
                    Qiscus.printLog(text: "connected via wifi")
                } else {
                    Qiscus.printLog(text: "connected via cellular data")
                }
                Qiscus.sharedInstance.connected = true
                if Qiscus.isLoggedIn {
                    Qiscus.sharedInstance.RealtimeConnect()
                    DispatchQueue.main.async { autoreleasepool{
                        QComment.resendPendingMessage()
                    }}
                }
            }
            Qiscus.sharedInstance.reachability?.whenUnreachable = { reachability in
                Qiscus.printLog(text: "disconnected")
                Qiscus.sharedInstance.connected = false
            }
            do {
                try  Qiscus.sharedInstance.reachability?.startNotifier()
            } catch {
                Qiscus.printLog(text: "Unable to start network notifier")
            }
        }}
    }
    
    
    
    func applicationDidBecomeActife(){
        Qiscus.checkDatabaseMigration()
        Qiscus.setupReachability()
        if Qiscus.isLoggedIn{
            Qiscus.sharedInstance.RealtimeConnect()
        }
        if !Qiscus.sharedInstance.styleConfiguration.rewriteChatFont {
            Qiscus.sharedInstance.styleConfiguration.chatFont = UIFont.preferredFont(forTextStyle: UIFontTextStyle.body)
        }
        if let chatView = self.topViewController() as? QiscusChatVC {
            chatView.isPresence = true

        }
        Qiscus.sync()
    }
    class func printLog(text:String){
        if Qiscus.showDebugPrint{
            DispatchQueue.global().async{
                print("[Qiscus]: \(text)")
            }
        }
    }
    class func deleteAllFiles(){
        let fileManager = FileManager.default
        let dirPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let qiscusDirPath = "\(dirPath)/Qiscus"
        
        do {
            let filePaths = try fileManager.contentsOfDirectory(atPath: qiscusDirPath)
            for filePath in filePaths {
                try fileManager.removeItem(atPath: NSTemporaryDirectory() + filePath)
            }
        } catch let error as NSError {
            Qiscus.printLog(text: "Could not clear temp folder: \(error.debugDescription)")
        }
    }
    
    // MARK: - local DB
    class func checkDatabaseMigration(){
        if Qiscus.dbConfiguration.fileURL?.lastPathComponent != "Qiscus.realm" {
            Qiscus.dbConfiguration = Realm.Configuration.defaultConfiguration
            var realmURL = Qiscus.dbConfiguration.fileURL!
            realmURL.deleteLastPathComponent()
            realmURL.appendPathComponent("Qiscus.realm")
            Qiscus.dbConfiguration.fileURL = realmURL
            Qiscus.dbConfiguration.deleteRealmIfMigrationNeeded = true
        }
        Qiscus.dbConfiguration.schemaVersion = Qiscus.shared.config.dbSchemaVersion
        
        let _ = try! Realm(configuration: Qiscus.dbConfiguration)
        //Qiscus.printLog(text:"realmURL \(Qiscus.dbConfiguration.fileURL!)")
    }
    
    // MARK: - Create NEW Chat
    @objc public class func createChatView(withUsers users:[String], readOnly:Bool = false, title:String, subtitle:String = "", distinctId:String? = nil, optionalData:String?=nil, withMessage:String? = nil)->QiscusChatVC{
//        Qiscus.checkDatabaseMigration()
        if !Qiscus.sharedInstance.connected {
            Qiscus.setupReachability()
        }
        
        Qiscus.sharedInstance.isPushed = true
        
        let chatVC = QiscusChatVC()
        //chatVC.reset()
        if distinctId != nil{
            chatVC.distincId = distinctId!
        }else{
            chatVC.distincId = ""
        }
        chatVC.optionalData = optionalData
        chatVC.chatMessage = withMessage
        chatVC.archived = readOnly
        chatVC.chatNewRoomUsers = users
        chatVC.chatTitle = title
        chatVC.chatSubtitle = subtitle
        return chatVC
    }
    @objc public class func createChat(withUsers users:[String], target:UIViewController, readOnly:Bool = false, title:String, subtitle:String = "", distinctId:String? = nil, optionalData:String?=nil, withMessage:String? = nil){
//        Qiscus.checkDatabaseMigration()
        if !Qiscus.sharedInstance.connected {
            Qiscus.setupReachability()
        }
        
        Qiscus.sharedInstance.isPushed = false
        QiscusUIConfiguration.sharedInstance.copyright.chatSubtitle = subtitle
        QiscusUIConfiguration.sharedInstance.copyright.chatTitle = title
        
        let chatVC = QiscusChatVC()
        //chatVC.reset()
        if distinctId != nil{
            chatVC.distincId = distinctId!
        }else{
            chatVC.distincId = ""
        }
        chatVC.optionalData = optionalData
        chatVC.message = withMessage
        chatVC.newRoom = true
        chatVC.users = users
        chatVC.archived = readOnly
        
        let navController = UINavigationController()
        navController.viewControllers = [chatVC]
        
        UIApplication.shared.keyWindow?.rootViewController?.present(navController, animated: true, completion: nil)
    }
    
    // MARK: - Update Room Methode
//    @objc public class func updateRoom(withRoomId roomId:Int, roomName:String? = nil, roomAvatarURL:String? = nil, roomAvatar:UIImage? = nil, roomOptions:String? = nil){
////        Qiscus.commentService.updateRoom(withRoomId: roomId, roomName: roomName, roomAvatarURL: roomAvatarURL, roomOptions: roomOptions)
//        if let room = QRoom.room(withId: roomId) {
//            room.update(name: roomName, avatarURL: roomAvatarURL, data: roomOptions)
//        }
//    }
    
    // MARK: - Push Notification Setup
    public func pushRegistry(_ registry: PKPushRegistry, didUpdate credentials: PKPushCredentials, forType type: PKPushType) {
        if Qiscus.isLoggedIn{
            var token: String = ""
            let deviceToken = credentials.token
            for i in 0..<credentials.token.count {
                token += String(format: "%02.2hhx", deviceToken[i] as CVarArg)
            }
            Qiscus.qiscusDeviceToken = token
            QiscusMe.sharedInstance.deviceToken = token
            Qiscus.printLog(text: "Device token: \(token)")
            QiscusCommentClient.sharedInstance.registerDevice(withToken: token)
        }
    }
    public func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, forType type: PKPushType) {
        if Qiscus.isLoggedIn{
            let payloadData = JSON(payload.dictionaryPayload)
            if let _ = payloadData["qiscus_sdk"].string {
                Qiscus.sharedInstance.checkChat()
            }
        }
    }
    public func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenForType type: PKPushType) {
        Qiscus.registerNotification()
    }
    @objc public class func registerNotification(){
        let notificationSettings = UIUserNotificationSettings(types: [.badge, .sound, .alert], categories: nil)
        Qiscus.sharedInstance.application.registerUserNotificationSettings(notificationSettings)
        Qiscus.sharedInstance.application.registerForRemoteNotifications()
    }
    @objc public class func didRegisterUserNotification(withToken token: Data){
        if Qiscus.isLoggedIn{
            var tokenString: String = ""
            for i in 0..<token.count {
                tokenString += String(format: "%02.2hhx", token[i] as CVarArg)
            }
            Qiscus.qiscusDeviceToken = tokenString
            QiscusMe.sharedInstance.deviceToken = tokenString
            Qiscus.printLog(text: "Device token: \(tokenString)")
            QChatService.registerDevice(withToken: tokenString)
        }
    }
    
    
    @objc public class func didReceive(RemoteNotification userInfo:[AnyHashable : Any], completionHandler: @escaping (UIBackgroundFetchResult) -> Void = {_ in}){
        completionHandler(.newData)
        
        if Qiscus.isLoggedIn{
            if userInfo["qiscus_sdk"] != nil {
                let state = Qiscus.shared.application.applicationState
                if state != .active {
                    QChatService.sync()
                    if let payloadData = userInfo["payload"]{
                        let jsonPayload = JSON(arrayLiteral: payloadData)[0]
                        let tempComment = QComment.tempComment(fromJSON: jsonPayload)
                        Qiscus.shared.delegate?.qiscus?(gotSilentNotification: tempComment)
                    }
                }
            }
        }
    }
    @objc public class func notificationAction(roomId: Int){
        if let window = UIApplication.shared.keyWindow{
            if Qiscus.sharedInstance.notificationAction != nil{
                let chatVC = Qiscus.chatView(withRoomId: roomId, title: "")
                Qiscus.sharedInstance.notificationAction!(chatVC)
            }else{
                if let currenRootView = window.rootViewController as? UINavigationController{
                    
                    let viewController = currenRootView.viewControllers[currenRootView.viewControllers.count - 1]
                    if Qiscus.sharedInstance.isPushed{
                        let chatVC = Qiscus.chatView(withRoomId: roomId, title: "")
                        currenRootView.pushViewController(chatVC, animated: true)
                    }else{
                        Qiscus.chat(withRoomId: roomId, target: viewController)
                    }
                }
                else if let currentRootView = window.rootViewController as? UITabBarController{
                    if let navigation = currentRootView.selectedViewController as? UINavigationController{
                        let viewController = navigation.viewControllers[navigation.viewControllers.count - 1]
                        if Qiscus.sharedInstance.isPushed{
                            let chatVC = Qiscus.chatView(withRoomId: roomId, title: "")
                            navigation.pushViewController(chatVC, animated: true)
                        }else{
                            Qiscus.chat(withRoomId: roomId, target: viewController)
                        }
                    }
                }
            }
        }
    }
    
    class func mqttConnect(chatOnly:Bool = false){
        let appName = Bundle.main.infoDictionary![kCFBundleNameKey as String] as! String
        var deviceID = "000"
        if let vendorIdentifier = UIDevice.current.identifierForVendor {
            deviceID = vendorIdentifier.uuidString
        }
        
        QChatService.sync()
        
        let clientID = "iosMQTT-\(appName)-\(deviceID)-\(QiscusMe.sharedInstance.id)"
        let mqtt = CocoaMQTT(clientID: clientID, host: "mqtt.qiscus.com", port: 1883)
        mqtt.username = ""
        mqtt.password = ""
        mqtt.cleanSession = true
        mqtt.willMessage = CocoaMQTTWill(topic: "u/\(QiscusMe.sharedInstance.email)/s", message: "0")
        mqtt.keepAlive = 60
        mqtt.delegate = Qiscus.shared
        let state = UIApplication.shared.applicationState
        if state == .active {
            mqtt.connect()
        }
    }
    public class func createLocalNotification(forComment comment:QComment, alertTitle:String? = nil, alertBody:String? = nil, userInfo:[AnyHashable : Any]? = nil){
        DispatchQueue.main.async {autoreleasepool{
            let localNotification = UILocalNotification()
            if let title = alertTitle {
                localNotification.alertTitle = title
            }else{
                localNotification.alertTitle = comment.senderName
            }
            if let body = alertBody {
                localNotification.alertBody = body
            }else{
                localNotification.alertBody = comment.text
            }
            var userData = [AnyHashable : Any]()
            
            if userInfo != nil {
                for (key,value) in userInfo! {
                    userData[key] = value
                }
            }
            
            let commentInfo = comment.encodeDictionary()
            for (key,value) in commentInfo {
                userData[key] = value
            }
            localNotification.userInfo = userData
            localNotification.fireDate = Date().addingTimeInterval(0.4)
            Qiscus.shared.application.scheduleLocalNotification(localNotification)
        }}
    }
    public class func didReceiveNotification(notification:UILocalNotification){
        if notification.userInfo != nil {
            if let comment = QComment.decodeDictionary(data: notification.userInfo!) {
                var userData:[AnyHashable : Any]? = [AnyHashable : Any]()
                let qiscusKey:[AnyHashable] = ["qiscus_commentdata","qiscus_uniqueId","qiscus_id","qiscus_roomId","qiscus_beforeId","qiscus_text","qiscus_createdAt","qiscus_senderEmail","qiscus_senderName","qiscus_statusRaw","qiscus_typeRaw","qiscus_data"]
                for (key,value) in notification.userInfo! {
                    if !qiscusKey.contains(key) {
                        userData![key] = value
                    }
                }
                if userData!.count == 0 {
                    userData = nil
                }
                Qiscus.shared.delegate?.qiscus?(didTapLocalNotification: comment, userInfo: userData)
            }
        }
    }
    class func publishUserStatus(offline:Bool = false){
        if Qiscus.isLoggedIn{
            QiscusBackgroundThread.async {autoreleasepool{
                var message: String = "1";
                
                let channel = "u/\(QiscusMe.sharedInstance.email)/s"
                if offline {
                    message = "0"
                    DispatchQueue.main.async {autoreleasepool{
                        Qiscus.shared.mqtt?.publish(channel, withString: message, qos: .qos1, retained: true)
                    }}
                }else{
                    if Qiscus.sharedInstance.application.applicationState == UIApplicationState.active {
                        DispatchQueue.main.async { autoreleasepool{
                            Qiscus.shared.mqtt?.publish(channel, withString: message, qos: .qos1, retained: true)
                        }}
                        
                        let when = DispatchTime.now() + 40
                        QiscusBackgroundThread.asyncAfter(deadline: when) {
                            Qiscus.publishUserStatus()
                        }
                    }
                }
            }}
        }
    }
    func goToBackgroundMode(){
        for (_,chatView) in self.chatViews {
            if chatView.isPresence {
                chatView.goBack()
                if let room = chatView.chatRoom {
                    room.delegate = nil
                }
            }
        }
        
        Qiscus.publishUserStatus(offline: true)
    }
    @objc public class func setNotificationAction(onClick action:@escaping ((QiscusChatVC)->Void)){
        Qiscus.sharedInstance.notificationAction = action
    }
    
    // MARK: - register PushNotification
    @objc class func registerDevice(withToken deviceToken: String){
        QiscusCommentClient.sharedInstance.registerDevice(withToken: deviceToken)
    }
}
extension Qiscus:CocoaMQTTDelegate{
    public func mqtt(_ mqtt: CocoaMQTT, didConnect host: String, port: Int){
        let state = UIApplication.shared.applicationState
        
        if state == .active {
            let commentChannel = "\(QiscusMe.sharedInstance.token)/c"
            mqtt.subscribe(commentChannel, qos: .qos2)
            Qiscus.publishUserStatus()
            for channel in Qiscus.realtimeChannel{
                mqtt.subscribe(channel)
            }
            Qiscus.shared.mqtt = mqtt
        }
        if self.syncTimer != nil {
            self.syncTimer?.invalidate()
            self.syncTimer = nil
        }
    }
    public func mqtt(_ mqtt: CocoaMQTT, didConnectAck ack: CocoaMQTTConnAck){
        QiscusBackgroundThread.async {
            let state = UIApplication.shared.applicationState
            
            if state == .active {
                let commentChannel = "\(QiscusMe.sharedInstance.token)/c"
                mqtt.subscribe(commentChannel, qos: .qos2)
                Qiscus.publishUserStatus()
                for channel in Qiscus.realtimeChannel{
                    mqtt.subscribe(channel)
                }
                Qiscus.shared.mqtt = mqtt
            }
            if self.syncTimer != nil {
                self.syncTimer?.invalidate()
                self.syncTimer = nil
            }
        }
    }
    public func mqtt(_ mqtt: CocoaMQTT, didPublishMessage message: CocoaMQTTMessage, id: UInt16){
        
    }
    public func mqtt(_ mqtt: CocoaMQTT, didPublishAck id: UInt16){
        
    }
    public func mqtt(_ mqtt: CocoaMQTT, didReceiveMessage message: CocoaMQTTMessage, id: UInt16 ){
        QiscusBackgroundThread.async {autoreleasepool{
            if let messageData = message.string {
                let channelArr = message.topic.characters.split(separator: "/")
                let lastChannelPart = String(channelArr.last!)
                switch lastChannelPart {
                case "c":
                    let json = JSON.parse(messageData)
                    let roomId = json["room_id"].intValue
                    let commentId = json["id"].intValue
                    print("mqtt data: \(json)")
                    if commentId > QiscusMe.sharedInstance.lastCommentId {
                        QChatService.sync()
                        let commentType = json["type"].stringValue
                        if commentType == "system_event" {
                            let payload = json["payload"]
                            let type = payload["type"].stringValue
                            if type == "remove_member" {
                                if payload["object_email"].stringValue == QiscusMe.sharedInstance.email {
                                    DispatchQueue.main.async {autoreleasepool{
                                        let comment = QComment.tempComment(fromJSON: json)
                                        if let roomDelegate = QiscusCommentClient.shared.roomDelegate {
                                            roomDelegate.gotNewComment(comment)
                                        }
                                        Qiscus.chatDelegate?.qiscusChat?(gotNewComment: comment)
                                        if let chatView = Qiscus.shared.chatViews[roomId] {
                                            if chatView.isPresence {
                                                chatView.goBack()
                                            }
                                            Qiscus.shared.chatViews[roomId] = nil
                                        }
                                        Qiscus.chatRooms[roomId] = nil
                                        if let room = QRoom.room(withId: roomId){
                                            if !room.isInvalidated {
                                                QRoom.deleteRoom(room: room)
                                            }
                                        }
                                        //QiscusNotification.publish(gotNewComment: comment)
                                    }}
                                }
                            }
                        }
                    }else{
                        let uniqueId = json["unique_temp_id"].stringValue
                        DispatchQueue.main.async {autoreleasepool{
                            if let room = QRoom.room(withId: roomId) {
                                if let comment = QComment.comment(withUniqueId: uniqueId){
                                    if comment.status != .delivered && comment.status != .read {
                                        room.updateCommentStatus(inComment: comment, status: .delivered)
                                    }
                                }
                            }
                        }}
                    }
                    if #available(iOS 10.0, *) {
                        if Qiscus.publishStatustimer != nil {
                            Qiscus.publishStatustimer?.invalidate()
                        }
                        Qiscus.publishStatustimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false, block: { (_) in
                            QRoom.publishStatus(roomId: roomId, commentId: commentId, status: .delivered)
                        })
                    } else {
                        QRoom.publishStatus(roomId: roomId, commentId: commentId, status: .delivered)
                    }
                    
                    break
                case "t":
                    let roomId:Int = Int(String(channelArr[2]))!
                    let userEmail:String = String(channelArr[3])
                    let data = (messageData == "0") ? "" : userEmail
                    if userEmail != QiscusMe.sharedInstance.email {
                        DispatchQueue.main.async {autoreleasepool{
                            if let room = QRoom.room(withId: roomId) {
                                if let user = QUser.user(withEmail: userEmail){
                                    let typing = (messageData == "0") ? false : true
                                    QiscusNotification.publish(userTyping: user, room: room, typing: typing)
                                }
                                room.updateUserTyping(userEmail: data)
                            }
                            QUser.user(withEmail: userEmail)?.updateLastSeen(lastSeen: Double(Date().timeIntervalSince1970))
                        }}
                    }
                    break
                case "d":
                    let roomId = Int(String(channelArr[2]))!
                    let messageArr = messageData.characters.split(separator: ":")
                    let commentId = Int(String(messageArr[0]))!
                    let userEmail = String(channelArr[3])
                    if userEmail != QiscusMe.sharedInstance.email {
                        DispatchQueue.main.async { autoreleasepool{
                            QParticipant.participant(inRoomWithId: roomId, andEmail: userEmail)?.updateLastDeliveredId(commentId: commentId)
                        }}
                    }
                    break
                case "r":
                    let roomId:Int = Int(String(channelArr[2]))!
                    let messageArr = messageData.characters.split(separator: ":")
                    let commentId = Int(String(messageArr[0]))!
                    let userEmail = String(channelArr[3])
                    if userEmail != QiscusMe.sharedInstance.email {
                        DispatchQueue.main.async { autoreleasepool{
                            QParticipant.participant(inRoomWithId: roomId, andEmail: userEmail)?.updateLastReadId(commentId: commentId)
                        }}
                    }else{
                        Qiscus.roomInfo(withId: roomId, onSuccess: { (room) in
                            QiscusNotification.publish(roomChange: room)
                        }, onError: { (error) in
                            Qiscus.printLog(text: "fail to update room: \(error)")
                        })
                    }
                    break
                case "s":
                    let messageArr = messageData.characters.split(separator: ":")
                    let userEmail = String(channelArr[1])
                    if userEmail != QiscusMe.sharedInstance.email{
                        if let timeToken = Double(String(messageArr[1])){
                            DispatchQueue.main.async { autoreleasepool{
                                QUser.user(withEmail: userEmail)?.updateLastSeen(lastSeen: Double(timeToken)/1000)
                            }}
                        }
                    }
                    break
                default:
                    Qiscus.printLog(text: "Realtime socket receive message in unknown topic: \(message.topic)")
                    break
                }
            }
        }}
        
    }
    public func mqtt(_ mqtt: CocoaMQTT, didSubscribeTopic topic: String){
        Qiscus.printLog(text: "topic : \(topic) subscribed")
        if !Qiscus.realtimeChannel.contains(topic) {
            Qiscus.realtimeChannel.append(topic)
        }
    }
    public func mqtt(_ mqtt: CocoaMQTT, didUnsubscribeTopic topic: String){
        if Qiscus.realtimeChannel.contains(topic){
            var i = 0
            for channel in Qiscus.realtimeChannel {
                if channel == topic {
                    Qiscus.realtimeChannel.remove(at: i)
                    break
                }
                i+=1
            }
        }
    }
    public func mqttDidPing(_ mqtt: CocoaMQTT){
    }
    public func mqttDidReceivePong(_ mqtt: CocoaMQTT){
        
    }
    public func mqttDidDisconnect(_ mqtt: CocoaMQTT, withError err: Error?){
        if Qiscus.isLoggedIn {
            if self.syncTimer == nil {
                self.syncTimer = Timer.scheduledTimer(timeInterval: 5.0, target: self, selector: #selector(self.sync), userInfo: nil, repeats: true)
            }
        }
    }
    
    @objc public func sync(){
        self.backgroundCheck()
    }
    public class func sync(){
        Qiscus.sharedInstance.backgroundCheck()
    }
    
    func topViewController(controller: UIViewController? = UIApplication.shared.keyWindow?.rootViewController) -> UIViewController? {
        if let navigationController = controller as? UINavigationController {
            return topViewController(controller: navigationController.visibleViewController)
        }
        if let tabController = controller as? UITabBarController {
            if let selected = tabController.selectedViewController {
                return topViewController(controller: selected)
            }
        }
        if let presented = controller?.presentedViewController {
            return topViewController(controller: presented)
        }
        return controller
    }
    public class func cacheData(){
        Qiscus.checkDatabaseMigration()
        QRoom.cacheAll()
        QCommentGroup.cacheAll()
        QComment.cacheAll()
        QUser.cacheAll()
        QParticipant.cacheAll()
    }
    @objc public class func getNonce(withAppId appId:String, onSuccess:@escaping ((String)->Void), onFailed:@escaping ((String)->Void), secureURL:Bool = true){
        QChatService.getNonce(withAppId: appId, onSuccess: onSuccess, onFailed: onFailed)
    }
    @objc public class func setup(withUserIdentityToken uidToken:String, delegate: QiscusConfigDelegate? = nil){
        if delegate != nil {
            Qiscus.shared.delegate = delegate
        }
        QChatService.setup(withuserIdentityToken: uidToken)
        Qiscus.setupReachability()
        Qiscus.sharedInstance.RealtimeConnect()
    }
    public class func subscribeAllRoomNotification(){
        let rooms = QRoom.all()
        for room in rooms {
            room.subscribeRealtimeStatus()
        }
    }
}

extension Qiscus { // Public class API to get room
    
    public class func room(withId roomId:Int, onSuccess:@escaping ((QRoom)->Void),onError:@escaping ((String)->Void)){
        let service = QChatService()
        var needToLoad = true
        var room:QRoom?
        if QRoom.room(withId: roomId) != nil{
            room = QRoom.room(withId: roomId)
            if room!.comments.count > 0 {
                needToLoad = false
            }
        }
        if !needToLoad {
            onSuccess(room!)
        }else{
            service.room(withId: roomId, onSuccess: { (room) in
                onSuccess(room)
            }) { (error) in
                onError(error)
            }
        }
    }
    
    public class func room(withChannel channelName:String, onSuccess:@escaping ((QRoom)->Void),onError:@escaping ((String)->Void)){
        let service = QChatService()
        var needToLoad = true
        var room:QRoom?
        if QRoom.room(withUniqueId: channelName) != nil{
            room = QRoom.room(withUniqueId: channelName)
            if room!.comments.count > 0 {
                needToLoad = false
            }
        }
        if !needToLoad {
            onSuccess(room!)
        }else{
            service.room(withUniqueId: channelName, onSuccess: { (room) in
                onSuccess(room)
            }) { (error) in
                onError(error)
            }
        }
        
    }
    
    public class func room(withUserId userId:String, onSuccess:@escaping ((QRoom)->Void),onError:@escaping ((String)->Void)){
        let service = QChatService()
        var needToLoad = true
        var room:QRoom?
        
        if QRoom.room(withUser: userId) != nil{
            room = QRoom.room(withUser: userId)
            if room!.comments.count > 0 {
                needToLoad = false
            }
        }
        if !needToLoad {
            onSuccess(room!)
        }else{
            service.room(withUser: userId, onSuccess: { (room) in
                onSuccess(room)
            }, onError: { (error) in
                onError(error)
            })
        }
    }
    
    // MARK: - Room List
    public class func roomList(withLimit limit:Int, page:Int, onSuccess:@escaping (([QRoom], Int, Int, Int)->Void),onError:@escaping ((String)->Void)){
        QChatService.roomList(onSuccess: { (rooms, totalRoom, currentPage, limit) in
            onSuccess(rooms, totalRoom, currentPage, limit)
        }) { (error) in
            onError(error)
        }
    }
    
    public class func roomInfo(withId id:Int, onSuccess:@escaping ((QRoom)->Void), onError: @escaping ((String)->Void)){
        QChatService.roomInfo(withId: id, onSuccess: { (room) in
            onSuccess(room)
        }) { (error) in
            onError(error)
        }
    }
    
    public class func roomsInfo(withIds ids:[Int], onSuccess:@escaping (([QRoom])->Void), onError: @escaping ((String)->Void)){
        QChatService.roomsInfo(withIds: ids, onSuccess: { (rooms) in
            onSuccess(rooms)
        }) { (error) in
            onError(error)
        }
    }
    public class func channelInfo(withName name:String, onSuccess:@escaping ((QRoom)->Void), onError: @escaping ((String)->Void)){
        QChatService.roomInfo(withUniqueId: name, onSuccess: { (room) in
            onSuccess(room)
        }) { (error) in
            onError(error)
        }
    }
    
    public class func channelsInfo(withNames names:[String], onSuccess:@escaping (([QRoom])->Void), onError: @escaping ((String)->Void)){
        QChatService.roomsInfo(withUniqueIds: names, onSuccess: { (rooms) in
            onSuccess(rooms)
        }) { (error) in
            onError(error)
        }
    }
}

