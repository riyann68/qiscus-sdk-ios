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
    
    static let qiscusVersionNumber:String = "2.8.0"
    public static let client = QiscusClient.shared
    
    public static var showDebugPrint = false
    public static var saveLog:Bool = false
    
    // MARK: - Thread
    static let uiThread = DispatchQueue.main
    
    static var qiscusDeviceToken: String = ""
    private static var dbConfigurationRaw:Realm.Configuration? = nil
    static var dbConfiguration:Realm.Configuration{
        get{
            if let conf = Qiscus.dbConfigurationRaw {
                return conf
            }else{
                let conf = Qiscus.getConfiguration()
                Qiscus.dbConfigurationRaw = conf
                return conf
            }
        }
    }
    
    static var chatRooms = [String : QRoom]()
    static var qiscusDownload:[String] = [String]()
    
    var backgroundTask: UIBackgroundTaskIdentifier = UIBackgroundTaskInvalid
    
    public static var chatDelegate:QiscusChatDelegate?
    public static var maxUploadSizeInKB:Double = Double(100) * Double(1024)
    
    static var realtimeConnected:Bool = false
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
    internal var connectingMQTT = false
    
    var notificationAction:((QiscusChatVC)->Void)? = nil
    var syncing = false
    var syncTimer: Timer?
    var userStatusTimer: Timer?
    var delegate:QiscusConfigDelegate?
    public var diagnosticDelegate:QiscusDiagnosticDelegate?
    
    @objc public var styleConfiguration = QiscusUIConfiguration.sharedInstance
    @objc public var connected:Bool = false
    @objc public var httpRealTime:Bool = false
    @objc public var toastMessageAct:((_ roomId:Int, _ comment:QComment)->Void)?
    
    let application = UIApplication.shared
    let appDelegate = UIApplication.shared.delegate
    
    public var chatViews = [String:QiscusChatVC]()
    
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
            return QiscusClient.isLoggedIn
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
        Qiscus.shared.stopPublishOnlineStatus()
        for channel in Qiscus.realtimeChannel {
            Qiscus.shared.mqtt?.unsubscribe(channel)
        }
        Qiscus.shared.mqtt?.disconnect()
        Qiscus.unRegisterPN()
        QiscusClient.clear()
        Qiscus.removeLogFile()
    }
    @objc public class func clearData(){
        Qiscus.cancellAllRequest()
        Qiscus.removeAllFile()
        
        Qiscus.removeDB()
        Qiscus.dbConfigurationRaw = nil
        Qiscus.chatRooms = [String : QRoom]()
        QParticipant.cache = [String : QParticipant]()
        QComment.cache = [String : QComment]()
        QUser.cache = [String: QUser]()
        Qiscus.shared.chatViews = [String:QiscusChatVC]()
        Qiscus.realtimeChannel = [String]()
    }
    @objc public class func unRegisterPN(){
        if Qiscus.isLoggedIn {
            QiscusCommentClient.sharedInstance.unRegisterDevice()
        }
    }
    // need Documentation
    func backgroundCheck(cloud:Bool = false){
        if Qiscus.isLoggedIn{
            QChatService.syncProcess(cloud: cloud)
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
        Qiscus.setupReachability()
        QChatService.syncProcess()
    }
    @objc public class func setBaseURL(withURL url:String){
        Qiscus.client.baseUrl = url
        Qiscus.client.userData.set(url, forKey: "qiscus_base_url")
    }
    @objc public class func setAppId(appId:String){
        Qiscus.client.appId = appId
        Qiscus.client.userData.set(appId, forKey: "qiscus_appId")
    }
    @objc public class func setRealtimeServer(withServer server:String, port:Int = 1883, enableSSL:Bool = false){
        Qiscus.client.realtimeServer = server
        Qiscus.client.realtimePort = port
        Qiscus.client.realtimeSSL = enableSSL
        Qiscus.client.userData.set(server, forKey: "qiscus_realtimeServer")
        Qiscus.client.userData.set(port, forKey: "qiscus_realtimePort")
        Qiscus.client.userData.set(enableSSL, forKey: "qiscus_realtimeSSL")
    }
    public class func updateProfile(username:String? = nil, avatarURL:String? = nil, onSuccess:@escaping (()->Void), onFailed:@escaping ((String)->Void)) {
        QChatService.updateProfil(userName: username, userAvatarURL: avatarURL, onSuccess: onSuccess, onError: onFailed)
    }
    @objc public class func setup(withAppId appId:String, userEmail:String, userKey:String, username:String, avatarURL:String? = nil, delegate:QiscusConfigDelegate? = nil, secureURl:Bool = true){
        var requestProtocol = "https"
        if !secureURl {
            requestProtocol = "http"
        }
        let email = userEmail.lowercased()
        let baseUrl = "\(requestProtocol)://\(appId).qiscus.com"
        
        if delegate != nil {
            Qiscus.shared.delegate = delegate
        }
        var needLogin = false
        
        if QiscusClient.isLoggedIn {
            if email != Qiscus.client.email{
                needLogin = true
            }
        }else{
            needLogin = true
        }
        Qiscus.setupReachability()
        if needLogin {
            Qiscus.clear()
            Qiscus.client.appId = appId
            Qiscus.client.userData.set(appId, forKey: "qiscus_appId")
            
            Qiscus.client.userData.set(email, forKey: "qiscus_param_email")
            Qiscus.client.userData.set(userKey, forKey: "qiscus_param_pass")
            Qiscus.client.userData.set(username, forKey: "qiscus_param_username")
            
            if Qiscus.client.baseUrl == "" {
                Qiscus.client.baseUrl = baseUrl
                Qiscus.client.userData.set(baseUrl, forKey: "qiscus_base_url")
            }
            
            if avatarURL != nil{
                Qiscus.client.userData.set(avatarURL, forKey: "qiscus_param_avatar")
            }
            
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
    
    
    /**
     Class function to configure chat with user
     - parameter users: **String** users.
     - parameter readOnly: **Bool** to set read only or not (Optional), Default value : false.
     - parameter title: **String** text to show as chat title (Optional), Default value : "".
     - parameter subtitle: **String** text to show as chat subtitle (Optional), Default value : "" (empty string).
     */
    //    @objc public class func chatVC(withUsers users:[String], readOnly:Bool = false, title:String = "", subtitle:String = "", distinctId:String? = nil, optionalData:String?=nil, withMessage:String? = nil)->QiscusChatVC{
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
    
    
    
    /**
     No Documentation
     */
    @objc public class func chatView(withUsers users:[String], readOnly:Bool = false, title:String = "", subtitle:String = "", distinctId:String = "", withMessage:String? = nil)->QiscusChatVC{
        
        if let room = QRoom.room(withUser: users.first!) {
            return Qiscus.chatView(withRoomId: room.id, readOnly: readOnly, title: title, subtitle: subtitle, withMessage: withMessage)
        }else{
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
            chatVC.archived = readOnly
            return chatVC
        }
    }
    @objc public class func chatView(withRoomId roomId:String, readOnly:Bool = false, title:String = "", subtitle:String = "", withMessage:String? = nil)->QiscusChatVC{
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
        Qiscus.printLog(text: "methode unlockAction deprecated")
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
    
    @objc func applicationDidBecomeActife(){
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
        Qiscus.connect()
        Qiscus.sync(cloud: true)
    }
    public class func printLog(text:String){
        print(text)
        if Qiscus.showDebugPrint{
            let logText = "[Qiscus]: \(text)"
            DispatchQueue.global().sync{
                if Qiscus.saveLog {
                    let date = Date()
                    let df = DateFormatter()
                    df.dateFormat = "y-MM-dd H:m:ss"
                    let dateTime = df.string(from: date)
                    
                    let logFileText = "[Qiscus - \(dateTime)] : \(text)"
                    let logFilePath = Qiscus.logFile()
                    var dump = ""
                    if FileManager.default.fileExists(atPath: logFilePath) {
                        dump =  try! String(contentsOfFile: logFilePath, encoding: String.Encoding.utf8)
                    }
                    do {
                        // Write to the file
                        try  "\(dump)\n\(logFileText)".write(toFile: logFilePath, atomically: true, encoding: String.Encoding.utf8)
                    } catch let error as NSError {
                        Qiscus.printLog(text: "Failed writing to log file: \(logFilePath), Error: " + error.localizedDescription)
                    }
                }
            }
            Qiscus.shared.diagnosticDelegate?.qiscusDiagnostic(sendLog: logText)
        }
    }
    
    // MARK: - local DB
    private class func getConfiguration()->Realm.Configuration{
        var conf = Realm.Configuration.defaultConfiguration
        
        var realmURL = conf.fileURL!
        realmURL.deleteLastPathComponent()
        realmURL.appendPathComponent("Qiscus.realm")
        
        conf.fileURL = realmURL
        conf.deleteRealmIfMigrationNeeded = true
        conf.schemaVersion = Qiscus.shared.config.dbSchemaVersion
        
        return conf
    }
    
    // MARK: - Create NEW Chat
    @objc public class func createChatView(withUsers users:[String], readOnly:Bool = false, title:String, subtitle:String = "", distinctId:String? = nil, optionalData:String?=nil, withMessage:String? = nil)->QiscusChatVC{
        if !Qiscus.sharedInstance.connected {
            Qiscus.setupReachability()
        }
        
        Qiscus.sharedInstance.isPushed = true
        
        let chatVC = QiscusChatVC()
        //chatVC.reset()
        if distinctId != nil{
            chatVC.chatDistinctId = distinctId!
        }else{
            chatVC.chatDistinctId = ""
        }
        chatVC.chatData = optionalData
        chatVC.chatMessage = withMessage
        chatVC.archived = readOnly
        chatVC.chatNewRoomUsers = users
        chatVC.chatTitle = title
        chatVC.chatSubtitle = subtitle
        return chatVC
    }
    
    
    // MARK: - Update Room Methode
    //    @objc public class func updateRoom(withRoomId roomId:Int, roomName:String? = nil, roomAvatarURL:String? = nil, roomAvatar:UIImage? = nil, roomOptions:String? = nil){
    ////        Qiscus.commentService.updateRoom(withRoomId: roomId, roomName: roomName, roomAvatarURL: roomAvatarURL, roomOptions: roomOptions)
    //        if let room = QRoom.room(withId: roomId) {
    //            room.update(name: roomName, avatarURL: roomAvatarURL, data: roomOptions)
    //        }
    //    }
    
    // MARK: - Push Notification Setup
    public func pushRegistry(_ registry: PKPushRegistry, didUpdate credentials: PKPushCredentials, for type: PKPushType) {
        if Qiscus.isLoggedIn{
            var token: String = ""
            let deviceToken = credentials.token
            for i in 0..<credentials.token.count {
                token += String(format: "%02.2hhx", deviceToken[i] as CVarArg)
            }
            Qiscus.qiscusDeviceToken = token
            Qiscus.client.deviceToken = token
            Qiscus.printLog(text: "Device token: \(token)")
            QiscusCommentClient.sharedInstance.registerDevice(withToken: token)
        }
    }
    public func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType) {
        if Qiscus.isLoggedIn{
            let payloadData = JSON(payload.dictionaryPayload)
            if let _ = payloadData["qiscus_sdk"].string {
                Qiscus.sharedInstance.checkChat()
            }
        }
    }
    public func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
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
            Qiscus.client.deviceToken = tokenString
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
                    QChatService.syncProcess()
                    if let payloadData = userInfo["payload"]{
                        let jsonPayload = JSON(arrayLiteral: payloadData)[0]
                        let tempComment = QComment.tempComment(fromJSON: jsonPayload)
                        Qiscus.shared.delegate?.qiscus?(gotSilentNotification: tempComment, userInfo: userInfo)
                    }
                }
            }
        }
    }
    @objc public class func notificationAction(roomId: String){
        if let window = UIApplication.shared.keyWindow{
            if Qiscus.sharedInstance.notificationAction != nil{
                let chatVC = Qiscus.chatView(withRoomId: roomId, title: "")
                Qiscus.sharedInstance.notificationAction!(chatVC)
            }else{
                if let currenRootView = window.rootViewController as? UINavigationController{
                    
                    let chatVC = Qiscus.chatView(withRoomId: roomId, title: "")
                    currenRootView.pushViewController(chatVC, animated: true)
                }
                else if let currentRootView = window.rootViewController as? UITabBarController{
                    if let navigation = currentRootView.selectedViewController as? UINavigationController{
                        
                        let chatVC = Qiscus.chatView(withRoomId: roomId, title: "")
                        navigation.pushViewController(chatVC, animated: true)
                    }
                }
            }
        }
    }
    internal func mqttConnect(){
        if Qiscus.shared.connectingMQTT { return }
        Qiscus.shared.connectingMQTT = true
//        QiscusBackgroundThread.async {
            if self.mqtt == nil {
                let appName = Bundle.main.infoDictionary![kCFBundleNameKey as String] as! String
                var deviceID = "000"
                if let vendorIdentifier = UIDevice.current.identifierForVendor {
                    deviceID = vendorIdentifier.uuidString
                }
                
                let clientID = "iosMQTT-\(appName)-\(deviceID)-\(Qiscus.client.id)"
                self.mqtt = CocoaMQTT(clientID: clientID, host: Qiscus.client.realtimeServer, port: UInt16(Qiscus.client.realtimePort))
                self.mqtt!.username = ""
                self.mqtt!.password = ""
                self.mqtt!.cleanSession = true
                self.mqtt!.willMessage = CocoaMQTTWill(topic: "u/\(Qiscus.client.email)/s", message: "0")
                self.mqtt!.keepAlive = 60
                self.mqtt!.delegate = Qiscus.shared
                self.mqtt!.enableSSL = Qiscus.client.realtimeSSL
                
                if Qiscus.client.realtimeSSL {
                    self.mqtt!.allowUntrustCACertificate = true
                }
            }
        print("mqtt host: \(self.mqtt!.host)")
        print("mqtt port: \(self.mqtt!.port)")
        print("mqtt clientId: \(self.mqtt!.clientID)")
        print("mqtt state: \(self.mqtt!.connState)")
        print("mqtt delegate: \(self.mqtt!.delegate != nil)")
        print("mqtt ssl: \(self.mqtt!.enableSSL)")
        
            self.mqtt!.connect()
//        }
    }
    class func mqttConnect(chatOnly:Bool = false){
        QiscusBackgroundThread.asyncAfter(deadline: .now() + 1.0) {
            Qiscus.shared.mqttConnect()
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
    public class func didReceiveUNUserNotification(withUserInfo userInfo:[AnyHashable:Any]){
        if let comment = QComment.decodeDictionary(data: userInfo) {
            var userData:[AnyHashable : Any]? = [AnyHashable : Any]()
            let qiscusKey:[AnyHashable] = ["qiscus_commentdata","qiscus_uniqueId","qiscus_id","qiscus_roomId","qiscus_beforeId","qiscus_text","qiscus_createdAt","qiscus_senderEmail","qiscus_senderName","qiscus_statusRaw","qiscus_typeRaw","qiscus_data"]
            for (key,value) in userInfo {
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
    class func publishUserStatus(offline:Bool = false){
        if Qiscus.isLoggedIn{
            DispatchQueue.main.async {
                let isActive = (Qiscus.sharedInstance.application.applicationState == UIApplicationState.active)
                QiscusBackgroundThread.async {autoreleasepool{
                    var message: String = "1";
                    
                    let channel = "u/\(Qiscus.client.email)/s"
                    if offline {
                        message = "0"
                        
                        DispatchQueue.main.async {autoreleasepool{
                            Qiscus.shared.stopPublishOnlineStatus()
                            Qiscus.shared.mqtt?.publish(channel, withString: message, qos: .qos1, retained: true)
                            }}
                    }else{
                        if isActive {
                            Qiscus.shared.startPublishOnlineStatus()
                        }
                    }
                    }}
            }
        }
    }
    func startPublishOnlineStatus(){
        if Thread.isMainThread{
            self.userStatusTimer?.invalidate()
            self.userStatusTimer = Timer.scheduledTimer(timeInterval: 3.0, target: self, selector: #selector(Qiscus.publishOnlineStatus), userInfo: nil, repeats: true)
        }else{
            DispatchQueue.main.sync {
                self.userStatusTimer?.invalidate()
                self.userStatusTimer = Timer.scheduledTimer(timeInterval: 3.0, target: self, selector: #selector(Qiscus.publishOnlineStatus), userInfo: nil, repeats: true)
            }
        }
    }
    @objc func publishOnlineStatus(){
        let channel = "u/\(Qiscus.client.email)/s"
        let isActive = (Qiscus.sharedInstance.application.applicationState == UIApplicationState.active)
        if isActive {
            self.mqtt?.publish(channel, withString: "1", qos: .qos1, retained: true)
        }
    }
    func stopPublishOnlineStatus(){
        let channel = "u/\(Qiscus.client.email)/s"
        self.userStatusTimer?.invalidate()
        self.mqtt?.publish(channel, withString: "0", qos: .qos1, retained: true)
    }
    @objc func goToBackgroundMode(){
        for (_,chatView) in self.chatViews {
            if chatView.isPresence {
                chatView.goBack()
                if let room = chatView.chatRoom {
                    room.delegate = nil
                }
            }
        }
        Qiscus.shared.stopPublishOnlineStatus()
    }
    @objc public class func setNotificationAction(onClick action:@escaping ((QiscusChatVC)->Void)){
        Qiscus.shared.notificationAction = action
    }
    
    // MARK: - register PushNotification
    @objc public class func registerDevice(withToken deviceToken: String){
        Qiscus.qiscusDeviceToken = deviceToken
        Qiscus.client.deviceToken = deviceToken
        QiscusCommentClient.sharedInstance.registerDevice(withToken: deviceToken)
    }
    @objc public class func unRegisterDevice(){
        Qiscus.qiscusDeviceToken = ""
        Qiscus.client.deviceToken = ""
        QiscusCommentClient.sharedInstance.unRegisterDevice()
    }
    public class func sync(cloud:Bool = false){
        if Qiscus.isLoggedIn{
            QChatService.syncProcess(cloud: cloud)
        }
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
        QRoom.cacheAll()
        QComment.cacheAll()
        QUser.cacheAll()
        QParticipant.cacheAll()
    }
    @objc public class func getNonce(withAppId appId:String, baseURL:String? = nil, onSuccess:@escaping ((String)->Void), onFailed:@escaping ((String)->Void), secureURL:Bool = true){
        QChatService.getNonce(withAppId: appId, baseURL: baseURL, onSuccess: onSuccess, onFailed: onFailed, secureURL: secureURL)
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
        QiscusBackgroundThread.async { autoreleasepool {
            let rooms = QRoom.all()
            for room in rooms {
                room.subscribeRealtimeStatus()
            }
        }}
    }
}
extension Qiscus:CocoaMQTTDelegate{
    public func mqtt(_ mqtt: CocoaMQTT, didConnectAck ack: CocoaMQTTConnAck){
        Qiscus.printLog(text: "[Qiscus-MQTT] didConnectAck")
        let state = UIApplication.shared.applicationState
        let activeState = (state == .active)
        Qiscus.shared.connectingMQTT = false
        QiscusBackgroundThread.async {
            let commentChannel = "\(Qiscus.client.token)/c"
            mqtt.subscribe(commentChannel, qos: .qos2)
            
            for channel in Qiscus.realtimeChannel{
                mqtt.subscribe(channel)
            }
            Qiscus.realtimeConnected = true
            Qiscus.shared.mqtt = mqtt
            
            if activeState {
                Qiscus.shared.startPublishOnlineStatus()
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
                let channelArr = message.topic.split(separator: "/")
                let lastChannelPart = String(channelArr.last!)
                switch lastChannelPart {
                case "c":
                    let json = JSON(parseJSON:messageData)
                    let roomId = "\(json["room_id"])"
                    let commentId = json["id"].intValue
                    if commentId > Qiscus.client.lastCommentId {
                        if Qiscus.client.lastCommentId == 0 || Qiscus.client.lastKnownCommentId == 0 {
                            QiscusClient.updateLastCommentId(commentId: commentId - 1)
                        }
                        func syncData(){
                            QChatService.syncProcess()
                        }
                        let commentType = json["type"].stringValue
                        if commentType == "system_event" {
                            let payload = json["payload"]
                            let type = payload["type"].stringValue
                            if type == "remove_member" || type == "left_room"{
                                if payload["object_email"].stringValue == Qiscus.client.email {
                                    DispatchQueue.main.async {autoreleasepool{
                                        let comment = QComment.tempComment(fromJSON: json)
                                        
                                        if let roomDelegate = QiscusCommentClient.shared.roomDelegate {
                                            roomDelegate.gotNewComment(comment)
                                        }
                                        Qiscus.chatDelegate?.qiscusChat?(gotNewComment: comment)
                                        
                                        if let chatView = Qiscus.shared.chatViews[roomId] {
                                            chatView.chatRoom = nil
                                            if chatView.isPresence {
                                                chatView.goBack()
                                            }
                                            Qiscus.shared.chatViews[roomId] = nil
                                        }
                                        Qiscus.chatRooms[roomId] = nil
                                        
                                        if let room = QRoom.threadSaveRoom(withId: roomId){
                                            if !room.isInvalidated {
                                                room.unsubscribeRealtimeStatus()
                                                QRoom.deleteRoom(room: room)
                                            }
                                        }
                                        QiscusNotification.publish(roomDeleted: roomId)
                                    }}
                                }
                                else{
                                    syncData()
                                }
                            }else{
                                syncData()
                            }
                        }else{
                            syncData()
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
                    let roomId = String(channelArr[2])
                    let userEmail:String = String(channelArr[3])
                    let data = (messageData == "0") ? "" : userEmail
                    if userEmail != Qiscus.client.email {
                        DispatchQueue.main.async {autoreleasepool{
                            if let room = QRoom.room(withId: roomId) {
                                if room.isInvalidated{ return }
                                if let user = QUser.user(withEmail: userEmail){
                                    if user.isInvalidated { return }
                                    let typing = (messageData == "0") ? false : true
                                    QiscusNotification.publish(userTyping: user, room: room, typing: typing)
                                }
                                room.updateUserTyping(userEmail: data)
                            }
                            }}
                    }
                    break
                case "d":
                    QiscusBackgroundThread.async {
                        let roomId = String(channelArr[2])
                        let messageArr = messageData.split(separator: ":")
                        let commentId = Int(String(messageArr[0]))!
                        let userEmail = String(channelArr[3])
                        if userEmail != Qiscus.client.email {
                            if let room = QRoom.threadSaveRoom(withId: roomId){
                                if let participant = room.participant(withEmail: userEmail) {
                                    participant.updateLastDeliveredId(commentId: commentId)
                                }
                            }
                        }
                    }
                    
                    break
                case "r":
                    let roomId = String(channelArr[2])
                    let messageArr = messageData.split(separator: ":")
                    let commentId = Int(String(messageArr[0]))!
                    
                    let userEmail = String(channelArr[3])
                    if userEmail != Qiscus.client.email {
                        DispatchQueue.main.async { autoreleasepool{
                            if let room = QRoom.room(withId: roomId){
                                let savedParticipant = room.participants.filter("email == '\(userEmail)'")
                                if savedParticipant.count > 0 {
                                    let participant = savedParticipant.first!
                                    participant.updateLastReadId(commentId: commentId)
                                }
                            }
                            }}
                    }else{
                        QiscusBackgroundThread.async { autoreleasepool{
                            if let substring = messageArr.last {
                                let uniqueId = String(substring)
                                if let c = QComment.threadSaveComment(withUniqueId: uniqueId){
                                    c.read()
                                }
                            }
                            }}
                    }
                    break
                case "s":
                    QiscusBackgroundThread.async {
                        let messageArr = messageData.split(separator: ":")
                        let userEmail = String(channelArr[1])
                        let presenceString = String(messageArr[0])
                        if let rawPresence = Int(presenceString){
                            if userEmail != Qiscus.client.email{
                                if let timeToken = Double(String(messageArr[1])){
                                    if let user = QUser.getUser(email: userEmail){
                                        user.updateLastSeen(lastSeen: Double(timeToken)/1000)
                                        let presence = QUserPresence(rawValue: rawPresence)!
                                        user.updatePresence(presence: presence)
                                    }
                                }
                            }
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
        if !Qiscus.realtimeChannel.contains(topic) {
            Qiscus.printLog(text: "new realtime channel : \(topic) subscribed")
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
        Qiscus.printLog(text: "[Qiscus-MQTT] mqttDidDisconnect")
        Qiscus.shared.connectingMQTT = false
        if Qiscus.isLoggedIn {
            Qiscus.shared.stopPublishOnlineStatus()
            Qiscus.realtimeConnected = false
            Qiscus.sync()
        }
    }
    public func mqtt(_ mqtt: CocoaMQTT, didStateChangeTo state: CocoaMQTTConnState) {
        Qiscus.printLog(text: "[Qiscus-MQTT] didStateChangeTo state: \(state)")
    }
    public func mqtt(_ mqtt: CocoaMQTT, didPublishComplete id: UInt16) {
        Qiscus.printLog(text: "[Qiscus-MQTT] didPublishComplete")
    }
    public func mqtt(_ mqtt: CocoaMQTT, didReceive trust: SecTrust, completionHandler: @escaping (Bool) -> Void) {
        Qiscus.printLog(text: "[Qiscus-MQTT] didReceive trust")
        completionHandler(true)
    }
    
    
}

extension Qiscus { // Public class API to get room
    public class func clearMessages(inChannels channels:[String], onSuccess:@escaping ([QRoom],[String])->Void, onError:@escaping (Int)->Void){
        QRoomService.clearMessages(inRoomsChannel: channels, onSuccess: { (rooms, channels) in
            onSuccess(rooms,channels)
        }) { (statusCode) in
            onError(statusCode)
        }
    }
    public class func prepareView(witCompletion completion: @escaping (([QiscusChatVC])->Void)){
        if Thread.isMainThread {
            let allRoom = QRoom.all()
            var allView = [QiscusChatVC]()
            for room in allRoom {
                room.subscribeRoomChannel()
                if Qiscus.chatRooms[room.id] == nil {
                    Qiscus.chatRooms[room.id] = room
                }
                if Qiscus.shared.chatViews[room.id] == nil {
                    let chatView = QiscusChatVC()
                    chatView.chatRoom = room
                    chatView.prefetch = true
                    chatView.viewDidLoad()
                    chatView.viewWillAppear(false)
                    chatView.viewDidAppear(false)
                    chatView.view.layoutSubviews()
                    chatView.inputBar.layoutSubviews()
                    chatView.inputText.commonInit()
                    
                    Qiscus.shared.chatViews[room.id] = chatView
                    allView.append(chatView)
                }
            }
            completion(allView)
        }else{
            completion([QiscusChatVC]())
        }
    }
    public class func prepareView(){
        if Thread.isMainThread {
            let allRoom = QRoom.all()
            for room in allRoom {
                room.subscribeRoomChannel()
                if Qiscus.chatRooms[room.id] == nil {
                    Qiscus.chatRooms[room.id] = room
                }
                if Qiscus.shared.chatViews[room.id] == nil {
                    let chatView = QiscusChatVC()
                    chatView.chatRoom = room
                    chatView.prefetch = true
                    chatView.viewDidLoad()
                    chatView.viewWillAppear(false)
                    chatView.viewDidAppear(false)
                    chatView.view.layoutSubviews()
                    chatView.inputBar.layoutSubviews()
                    chatView.inputText.commonInit()
                    
                    
                    Qiscus.shared.chatViews[room.id] = chatView
                }
            }
        }
    }
    public class func room(withId roomId:String, onSuccess:@escaping ((QRoom)->Void),onError:@escaping ((String)->Void)){
        let service = QChatService()
        var needToLoad = true
        func loadRoom(){
            service.room(withId: roomId, onSuccess: { (room) in
                if !room.isInvalidated {
                    onSuccess(room)
                }else{
                    Qiscus.printLog(text: "localRoom has been deleted")
                    onError("localRoom has been deleted")
                }
            }) { (error) in
                onError(error)
            }
        }
        if let room = QRoom.room(withId: roomId){
            if room.comments.count > 0 {
                onSuccess(room)
            }else{
                loadRoom()
            }
        }else{
            loadRoom()
        }
    }
    
    public class func room(withChannel channelName:String, title:String = "", avatarURL:String, onSuccess:@escaping ((QRoom)->Void),onError:@escaping ((String)->Void)){
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
            service.room(withUniqueId: channelName, title: title, avatarURL: avatarURL, onSuccess: { (room) in
                onSuccess(room)
            }, onError: { (error) in
                onError(error)
            })
        }
        
    }
    public class func newRoom(withUsers usersId:[String], roomName: String, avatarURL:String = "", onSuccess:@escaping ((QRoom)->Void),onError:@escaping ((String)->Void)){
        let service = QChatService()
        if roomName.trimmingCharacters(in: .whitespacesAndNewlines) != "" {
            service.createRoom(withUsers: usersId, roomName: roomName, avatarURL: avatarURL, onSuccess: onSuccess, onError: onError)
        }else{
            onError("room name can not be empty string")
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
        }, onFailed: {(error) in
            onError(error)
        })
    }
    public class func fetchAllRoom(loadLimit:Int = 0, onSuccess:@escaping (([QRoom])->Void),onError:@escaping ((String)->Void), onProgress: ((Double,Int,Int)->Void)? = nil){
        var page = 1
        var limit = 100
        if loadLimit > 0 {
            limit = loadLimit
        }
        func load(onPage:Int) {
            QChatService.roomList(withLimit: limit, page: page, showParticipant: true, onSuccess: { (rooms, totalRoom, currentPage, limit) in
                if totalRoom > (limit * (currentPage - 1)) + rooms.count{
                    page += 1
                    load(onPage: page)
                }else{
                    let rooms = QRoom.all()
                    onSuccess(rooms)
                }
            }, onFailed: { (error) in
                onError(error)
            }) { (progress, loadedRoomm, totalRoom) in
                onProgress?(progress,loadedRoomm,totalRoom)
            }
        }
        load(onPage: 1)
    }
    public class func roomInfo(withId id:String, lastCommentUpdate:Bool = true, onSuccess:@escaping ((QRoom)->Void), onError: @escaping ((String)->Void)){
        QChatService.roomInfo(withId: id, lastCommentUpdate: lastCommentUpdate, onSuccess: { (room) in
            onSuccess(room)
        }) { (error) in
            onError(error)
        }
    }
    
    public class func roomsInfo(withIds ids:[String], onSuccess:@escaping (([QRoom])->Void), onError: @escaping ((String)->Void)){
        QChatService.roomsInfo(withIds: ids, onSuccess: { (rooms) in
            onSuccess(rooms)
        }) { (error) in
            onError(error)
        }
    }
    public class func channelInfo(withName name:String, onSuccess:@escaping ((QRoom)->Void), onError: @escaping ((String)->Void)){
        QChatService.roomInfo(withUniqueId: name, onSuccess: { (room) in
            if !room.isInvalidated {
                onSuccess(room)
            }else{
                Qiscus.channelInfo(withName: name, onSuccess: onSuccess, onError: onError)
            }
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
    
    public class func removeAllFile(){
        let filemanager = FileManager.default
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory,.userDomainMask,true)[0] as NSString
        let destinationPath = documentsPath.appendingPathComponent("Qiscus")
        
        do {
            try filemanager.removeItem(atPath: destinationPath)
        } catch {
            Qiscus.printLog(text: "Could not clear Qiscus folder: \(error.localizedDescription)")
        }
        
    }
    public class func cancellAllRequest(){
        let sessionManager = QiscusService.session
        sessionManager.session.getAllTasks { (allTask) in
            allTask.forEach({ (task) in
                task.cancel()
            })
        }
    }
    public class func removeDB(){
        let realm = try! Realm(configuration: Qiscus.dbConfiguration)
        realm.refresh()
        try! realm.write {
            realm.deleteAll()
        }
        let filemanager = FileManager.default
        do {
            try filemanager.removeItem(at: Qiscus.dbConfiguration.fileURL!)
        } catch {
            Qiscus.printLog(text: "Could not clear Qiscus folder: \(error.localizedDescription)")
        }
    }
    
    internal class func logFile()->String{
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory,.userDomainMask,true)[0] as NSString
        let logPath = documentsPath.appendingPathComponent("Qiscus.log")
        return logPath
    }
    
    public class func removeLogFile(){
        let filemanager = FileManager.default
        let logFilePath = Qiscus.logFile()
        do {
            try filemanager.removeItem(atPath: logFilePath)
        } catch {
            Qiscus.printLog(text: "Could not clear Qiscus folder: \(error.localizedDescription)")
        }
    }
    
    public class func backgroundSync(){
        QChatService.backgroundSync()
    }
}
