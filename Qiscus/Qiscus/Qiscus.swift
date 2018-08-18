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

    
    static let qiscusVersionNumber:String = "2.8.25"
    
    
    /// shared instance of QiscusClient
    public static var client : QiscusClient {
        get { return QiscusClient.shared }
    }

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
    
    /**
     Qiscus Chat delegate to get new event from Qiscus. Exp: new message, new room, and user typing.
     
     ```
     func qiscusChat(gotNewComment comment:QComment)
     func qiscusChat(userDidTyping users:QUser)
     func qiscusChat(gotNewRoom room:QRoom)
     ```
     */
    public static var chatDelegate:QiscusChatDelegate?
    
    
    /// Disable language localization
    public static var disableLocalization: Bool = false
    
    /**
     Setup maximum size when you send attachment inside chat view, example send video/image from galery. By default maximum size is unlimited.
    */
    public static var maxUploadSizeInKB:Double = Double(100) * Double(1024)
    
    
    /// is realtime (mqtt) connected
    static var realtimeConnected:Bool = false
    internal static var publishStatustimer:Timer?
    internal static var realtimeChannel = [String]()
    
    var config = QiscusConfig.sharedInstance
    var commentService = QiscusCommentClient.sharedInstance
    
    /**
     iCloud Config, by default is disable/false. You need to setup icloud capabilities then create container in your developer account.
     */
    public var iCloudUpload = false
    /**
     Set camera upload to upload photo/video inside chat View, by default is enable/true.
     And you need to setup camera permition in info.plist
     
     ```
     <key>NSCameraUsageDescription</key>
     <string>Need camera access for uploading Images</string>
     <key>NSMicrophoneUsageDescription</key>
     <string>$(PRODUCT_NAME) microphone use</string>
     ```
     */
    public var cameraUpload = true
    /**
    Set attach image/Video from galery, by default is enable/true. But you need to set permition in info.plist
     
     ```
     <key>NSPhotoLibraryUsageDescription</key>
     <string>NeedLibrary access for uploading Images</string>
     ```
     */
    public var galeryUpload = true
    /**
     Share contact phone inside chat view, by default is enable/true. But you need to set permition in info.plist
     
     ```
     <key>NSContactsUsageDescription</key>
     <string>Need access for sync contact</string>
     ```
     */
    public var contactShare = true
    /**
     Location share inside chat view, by default is enable/true. But you need to set permition in info.plist
     ```
     <key>NSLocationAlwaysUsageDescription</key>
     <string>$(PRODUCT_NAME) location use</string>
     <key>NSLocationWhenInUseUsageDescription</key>
     <string>$(PRODUCT_NAME) location use</string>
     ```
     */
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
    
    /**
     Active Qiscus Print log, by default is disable/false
     */
    public static var showDebugPrint = false
    
    /**
     Save qiscus log.
     */
    // TODO : when active save log, make sure file size under 1/3Mb.
    @available(*, deprecated, message: "no longer available for public ...")
    public static var saveLog:Bool = false
    
    /**
     Receive all Qiscus Log, then handle logs\s by client.
     
     ```
     func qiscusDiagnostic(sendLog log:String)
     ```
    */
    public var diagnosticDelegate:QiscusDiagnosticDelegate?
    
    
    /// Setup Qiscus Custom Configuration, default value is QiscusUIConfiguration.sharedInstance
    @available(*, deprecated, message: "no longer available for public ...")
    var styleConfiguration = QiscusUIConfiguration.sharedInstance
    @available(*, deprecated, message: "no longer available for public ...")
    var connected:Bool = false
    /// check qiscus is connected with server or not.
    @objc public var isConnected: Bool {
        get {
            return Qiscus.sharedInstance.connected
        }
    }
    // never used
    // @objc public var httpRealTime:Bool = false
    @objc public var toastMessageAct:((_ roomId:Int, _ comment:QComment)->Void)?
    
    let application = UIApplication.shared
    let appDelegate = UIApplication.shared.delegate
    
    
    /// cached qiscusChatVC : viewController that already opened will be chached here
    public var chatViews = [String:QiscusChatVC]()
    
    
    /// qiscus sdk version number
    @objc public class var versionNumber:String{
        get{
            return Qiscus.qiscusVersionNumber
        }
    }
    
    
    /// shared instance of Qiscus.swift
    @objc public class var shared:Qiscus{
        get{
            return Qiscus.sharedInstance
        }
    }
    
    
    /// check qiscus user login status
    @objc public class var isLoggedIn:Bool{
        get{
            return QiscusClient.isLoggedIn
        }
    }
    
    
    /// device token for notification
    @objc public class var deviceToken:String{
        get{
            return Qiscus.qiscusDeviceToken
        }
    }
    
    
    /// QiscusUIConfiguration class
    @objc public class var style:QiscusUIConfiguration{
        get{
            return Qiscus.sharedInstance.styleConfiguration
        }
    }
    
    
    /// qiscus comment rest service
    class var commentService:QiscusCommentClient{
        get{
            return QiscusCommentClient.sharedInstance
        }
    }
    
    fileprivate override init(){
        
    }
    
    
    /// Qiscus bundle
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
     Class function to disable notification when **In App**, by default is true
     */
    @objc public class func disableInAppNotif(){
        Qiscus.sharedInstance.config.showToasterMessage = false
    }
    /**
     Class function to enable notification when **In App**, by default is true
     */
    @objc public class func enableInAppNotif(){
        Qiscus.sharedInstance.config.showToasterMessage = true
    }
    
    // MARK: - Deprecated
    @available(*, deprecated, message: "no longer available ...")
    class func disconnectRealtime(){
        Qiscus.uiThread.async { autoreleasepool{
            Qiscus.sharedInstance.mqtt?.disconnect()
            }}
    }
    
    /**
     Logout Qiscus and clear all data with this function
     @func clearData()
     */
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
        QiscusClient.hasRegisteredDeviceToken = false
    }
    
    /**
     Remove all database, cache, file in local document, and stop all API request.
     
     User no need to re-Login
     */
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
    
    /**
     Remove your device token from backend, Then you not receiving any Push Notification (Apns nor Pushkit)
    */
    @objc public class func unRegisterPN(){
        if Qiscus.isLoggedIn {
            QiscusCommentClient.sharedInstance.unRegisterDevice()
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
    
    
    /// connect to mqtt and setup reachability
    ///
    /// - Parameter delegate: QiscusConfigDelegate
    public class func connect(delegate:QiscusConfigDelegate? = nil){
        Qiscus.shared.RealtimeConnect()
        if delegate != nil {
            Qiscus.shared.delegate = delegate
        }
        Qiscus.setupReachability()
        QChatService.syncProcess()
    }
    
    // MARK: - Configuration
    
    /**
     to setup Qiscus URL Server, this method called when you are using dedicated server.
     
     - parameter url: Your custom/dedicated server, with Qiscus Enggine
     
     */
    @objc public class func setBaseURL(withURL url:String) {
        Qiscus.client.baseUrl = url
        Qiscus.client.userData.set(url, forKey: "qiscus_base_url")
    }
    
    /**
     Set App ID, when you are using nonce auth you need to setup App ID before get nounce
     
     - parameter appId: Qiscus App ID, please register or login in http://qiscus.com to find your App ID
    */
    @objc public class func setAppId(appId:String){
        Qiscus.client.appId = appId
        Qiscus.client.userData.set(appId, forKey: "qiscus_appId")
    }
    
    
    /// setup custom mqtt server
    ///
    /// - Parameters:
    ///   - server: server domain, example: 'qiscus.mqtt.com'
    ///   - port: server port
    ///   - enableSSL: true => enable SSL, false => disable SSL
    @objc public class func setRealtimeServer(withServer server:String, port:Int = 1883, enableSSL:Bool = false){
        Qiscus.client.realtimeServer = server
        Qiscus.client.realtimePort = port
        Qiscus.client.realtimeSSL = enableSSL
        Qiscus.client.userData.set(server, forKey: "qiscus_realtimeServer")
        Qiscus.client.userData.set(port, forKey: "qiscus_realtimePort")
        Qiscus.client.userData.set(enableSSL, forKey: "qiscus_realtimeSSL")
    }
    
    
    /// update qiscus user profile
    ///
    /// - Parameters:
    ///   - username: String username
    ///   - avatarURL: String avatar url
    ///   - extras: valid jsonString
    ///   - onSuccess: @escaping on success update user profile
    ///   - onFailed: @escaping on error update user profile with error message
    public class func updateProfile(username:String? = nil, avatarURL:String? = nil, extras: String? = nil, onSuccess:@escaping (()->Void), onFailed:@escaping ((String)->Void)) {
        QChatService.updateProfil(userName: username, userAvatarURL: avatarURL, extras: extras, onSuccess: onSuccess, onError: onFailed)
    }
    
    
    /// setup qiscus
    ///
    /// - Parameters:
    ///   - appId: qiscus app id
    ///   - userEmail: client (username, userEmail, id)
    ///   - userKey: client (key)
    ///   - username: client username
    ///   - avatarURL: client avatar url
    ///   - delegate: QiscusConfigDelegate
    ///   - secureURl: true => https, false => http
    ///   - extras:  client extras (jsonString)
    @objc public class func setup(withAppId appId:String, userEmail:String, userKey:String, username:String, avatarURL:String? = nil, extras:String? = nil, delegate:QiscusConfigDelegate? = nil, secureURl:Bool = true){
        var requestProtocol = "https"
        if !secureURl {
            requestProtocol = "http"
        }
        let email = userEmail.lowercased()
        let baseUrl = "\(requestProtocol)://api.qiscus.com"
        
        if delegate != nil {
            
            Qiscus.shared.delegate = delegate
        }
        var needLogin = false
        
        if QiscusClient.isLoggedIn {
            if email != Qiscus.client.email || appId != Qiscus.client.appId{
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
            Qiscus.client.userData.set(extras, forKey: "qiscus_param_extras")
            
            if Qiscus.client.baseUrl == "" {
                Qiscus.client.baseUrl = baseUrl
                Qiscus.client.userData.set(baseUrl, forKey: "qiscus_base_url")
            }
            
            if avatarURL != nil{
                Qiscus.client.userData.set(avatarURL, forKey: "qiscus_param_avatar")
            }
            
            QiscusCommentClient.sharedInstance.loginOrRegister(userEmail, password: userKey, username: username, avatarURL: avatarURL, extras: extras)
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

    // local DB
    private class func getConfiguration()->Realm.Configuration{
        let documentDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).last! as NSString
        let fileURL = documentDirectory.appendingPathComponent("Qiscus.realm")
        let objectTypes = [
            QRoom.self,
            QComment.self,
            QFile.self,
            QUser.self,
            QParticipant.self,
            QiscusLinkData.self
        ]
        var conf = Realm.Configuration(fileURL: NSURL(string: fileURL) as URL?, objectTypes: objectTypes)
        conf.deleteRealmIfMigrationNeeded = true
        conf.schemaVersion = Qiscus.shared.config.dbSchemaVersion
        return conf
    }
    
    /// get image assets on qiscus bundle
    ///
    /// - Parameter name: assets name
    /// - Returns: UIImage
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
    
    
    /// setup reachability for network connection detection
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
        if let chatView = QiscusHelper.topViewController() as? QiscusChatVC {
            chatView.isPresence = true
            
        }
        Qiscus.connect()
        Qiscus.sync(cloud: true)
    }
    
    
    /// debug print
    ///
    /// - Parameter text: log message
    public class func printLog(text:String){
        if Qiscus.showDebugPrint{
            let logText = "[Qiscus]: \(text)"
            print(logText)
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
    
    
    
    // MARK: - Create NEW Chat
    
    /// get QiscusChatVC with array of username
    ///
    /// - Parameters:
    ///   - users: with array of client (username used on Qiscus.setup)
    ///   - readOnly: true => unable to access input view , false => able to access input view
    ///   - title: chat title
    ///   - subtitle: chat subtitle
    ///   - distinctId: -
    ///   - withMessage: predefined text message
    /// - Returns: QiscusChatVC to be presented or pushed
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
    
    
    /// get QiscusChatVC with room uniqueId
    ///
    /// - Parameters:
    ///   - uniqueId: room uniqueId
    ///   - readOnly: true => unable to access input view , false => able to access input view
    ///   - title: chat title
    ///   - subtitle: chat subtitle
    ///   - distinctId: -
    ///   - withMessage: predefined text message
    /// - Returns: QiscusChatVC to be presented or pushed
    @objc public class func chatView(withRoomUniqueId uniqueId:String, readOnly:Bool = false, title:String = "", avatarUrl:String = "", subtitle:String = "", withMessage:String? = nil)->QiscusChatVC{
        if let room = QRoom.room(withUniqueId: uniqueId){
            let chatVC = Qiscus.chatView(withRoomId: room.id, readOnly: readOnly, title: title, subtitle: subtitle, withMessage: withMessage)
            chatVC.chatRoomUniqueId = uniqueId
            chatVC.isPublicChannel = true
            return chatVC
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
            chatVC.isPublicChannel = true
            
            if chatVC.isPresence {
                chatVC.goBack()
            }
            chatVC.archived = readOnly
            return chatVC
        }
    }
    
    /// get QiscusChatVC with room id
    ///
    /// - Parameters:
    ///   - roomId: room id
    ///   - readOnly: true => unable to access input view , false => able to access input view
    ///   - title: chat title
    ///   - subtitle: chat subtitle
    ///   - distinctId: -
    ///   - withMessage: predefined text message
    /// - Returns: QiscusChatVC to be presented or pushed
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
    
    
    /// get QiscusChatVC with room id
    ///
    /// - Parameters:
    ///   - users: array of user id
    ///   - readOnly: true => unable to access input view , false => able to access input view
    ///   - title: chat title
    ///   - subtitle: chat subtitle
    ///   - distinctId: -
    ///   - withMessage: predefined text message
    /// - Returns: QiscusChatVC to be presented or pushed
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
    
    // MARK: - Push Notification Setup
    
    /**
     Device will be generate an device token, then register to qiscus
     */
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
    
    /**
     Forward you Push Notification payload to Qiscus SDK, then Qiscus will be filter the content.
     - parameter payload: your pushkit payload or The push payload sent by a developer via APNS server API.
     - parameter type: This is a PKPushType constant, which is present in [registry desiredPushTypes].
     */
    public func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType) {
        if Qiscus.isLoggedIn{
            let payloadData = JSON(payload.dictionaryPayload)
            if let _ = payloadData["qiscus_sdk"].string {
                Qiscus.mqttConnect(chatOnly: true)
            }
        }
    }
    
    /**
     Phone no longer receive push notif, then qiscus will be register notification to the client
     */
    public func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        Qiscus.registerNotification()
    }
    
    
    /// trigger register notif delegate on appDelegate
    @objc public class func registerNotification(){
        let notificationSettings = UIUserNotificationSettings(types: [.badge, .sound, .alert], categories: nil)
        Qiscus.sharedInstance.application.registerUserNotificationSettings(notificationSettings)
        Qiscus.sharedInstance.application.registerForRemoteNotifications()
    }
    
    
    /// register device token to sdk server
    ///
    /// - Parameter token: device token Data
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
    
    
    /// notif banner action to open chatView
    ///
    /// - Parameter roomId: chat room id
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
        QiscusBackgroundThread.async {
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
            self.mqtt!.connect()
        }
    }
    
    
    /// connect mqtt
    ///
    /// - Parameter chatOnly: -
    class func mqttConnect(chatOnly:Bool = false){
        QiscusBackgroundThread.asyncAfter(deadline: .now() + 1.0) {
            Qiscus.shared.mqttConnect()
        }
    }
    
    
    /// create banner natification
    ///
    /// - Parameters:
    ///   - comment: QComment
    ///   - alertTitle: banner title
    ///   - alertBody: banner body
    ///   - userInfo: userInfo
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
            
            localNotification.soundName = "default"
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
    
    
    /// didREceive localnotification
    ///
    /// - Parameter notification: UILocalNotification
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
    
    
    /// handle tap usernotification
    ///
    /// - Parameter userInfo: userInfo
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
    
    
    /// publish online or offline status
    ///
    /// - Parameter offline: false = offline, true = online
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
    
    
    /// set banner click action
    ///
    /// - Parameter action: do something on @escaping when banner notif did tap
    @objc public class func setNotificationAction(onClick action:@escaping ((QiscusChatVC)->Void)){
        Qiscus.shared.notificationAction = action
    }
    
    // MARK: - register PushNotification
    
    
    /// register device token to sdk service
    ///
    /// - Parameter deviceToken: device token in string
    @objc public class func registerDevice(withToken deviceToken: String){
        Qiscus.qiscusDeviceToken = deviceToken
        Qiscus.client.deviceToken = deviceToken
        QiscusCommentClient.sharedInstance.registerDevice(withToken: deviceToken)
    }
    
    
    /// unregister device token from sdk service
    @objc public class func unRegisterDevice(){
        Qiscus.qiscusDeviceToken = ""
        Qiscus.client.deviceToken = ""
        QiscusCommentClient.sharedInstance.unRegisterDevice()
    }
    
    
    /// do message synchronize
    ///
    /// - Parameter cloud: -
    public class func sync(cloud:Bool = false){
        if Qiscus.isLoggedIn{
            QChatService.syncProcess(cloud: cloud)
        }
    }
    
    
    /// clear qiscus cached data
    public class func cacheData(){
        QRoom.cacheAll()
        QComment.cacheAll()
        QUser.cacheAll()
        QParticipant.cacheAll()
    }
    
    
    /// get nonce from sdk server
    ///
    /// - Parameters:
    ///   - appId: sdk app id
    ///   - baseURL: custom base url sdk server (optional)
    ///   - onSuccess: on success get nonce with string nonce
    ///   - onFailed: on failed get nonce with string error message
    ///   - secureURL: true = https, false = http (default value = true)
    @objc public class func getNonce(withAppId appId:String, baseURL:String? = nil, onSuccess:@escaping ((String)->Void), onFailed:@escaping ((String)->Void), secureURL:Bool = true){
        QChatService.getNonce(withAppId: appId, baseURL: baseURL, onSuccess: onSuccess, onFailed: onFailed, secureURL: secureURL)
    }
    
    /**
     Qiscus Setup with `identity token`, 2nd call method after you call getNounce. Response from you backend then putback in to Qiscus Server
     
     - parameter uidToken: token where you get from get nonce
     - parameter delegate: QiscusConfigDelegate
     
     */
    @objc public class func setup(withUserIdentityToken uidToken:String, delegate: QiscusConfigDelegate? = nil){
        if delegate != nil {
            Qiscus.shared.delegate = delegate
        }
        QChatService.setup(withuserIdentityToken: uidToken)
        Qiscus.setupReachability()
        Qiscus.sharedInstance.RealtimeConnect()
    }
    
    
    /// subscribe room notification
    public class func subscribeAllRoomNotification(){
        QiscusBackgroundThread.async { autoreleasepool {
            let rooms = QRoom.all()
            for room in rooms {
                room.subscribeRealtimeStatus()
            }
        }}
    }
    
    
    /// search local message comment
    ///
    /// - Parameter searchQuery: query to search
    /// - Returns: array of QComment obj
    public class func searchComment(searchQuery: String) -> [QComment] {
        return QComment.comments(searchQuery: searchQuery)
    }
    
    
    /// get all unread count
    ///
    /// - Parameters:
    ///   - onSuccess: success completion with unread count value
    ///   - onError: error completion with error message
    public class func getAllUnreadCount(onSuccess: @escaping ((_ unread: Int) -> Void), onError: @escaping ((_ error: String) -> Void)) {
        QChatService.defaultService.getAllUnreadCount(onSuccess: { (unread) in
            onSuccess(unread)
        }) { (error) in
            onError(error)
        }
    }
    
    
    /// add participants to room
    ///
    /// - Parameters:
    ///   - id: room id
    ///   - userIds: array of participant user id registered in qiscus sdk
    ///   - onSuccess: completion when successfully add participant
    ///   - onError: completion when failed add participant
    public class func addParticipant(onRoomId id: String, userIds: [String], onSuccess:@escaping (QRoom)->Void, onError: @escaping ([String],Int?)->Void) {
        QRoomService.addParticipant(onRoom: id, userIds: userIds, onSuccess: onSuccess, onError: onError)
        
    }
    
    
    /// remove participants from room
    ///
    /// - Parameters:
    ///   - id: room id
    ///   - userIds: array of participant user id registered in qiscus sdk
    ///   - onSuccess: completion when failed delete participant
    ///   - onError: completion when failed delete participant
    public class func removeParticipant(onRoom id: String, userIds: [String], onSuccess:@escaping (QRoom)->Void, onError: @escaping ([String],Int?)->Void) {
        QRoomService.removeParticipant(onRoom: id, userIds: userIds, onSuccess: onSuccess, onError: onError)
    }
    
    /// block user
    /// - Parameters:
    ///   - user_email
    public class func blockUser(user_email: String, onSuccess:@escaping()->Void, onError: @escaping (String)->Void) {
        QRoomService.blockUser(sdk_email: user_email, onSuccess: onSuccess, onError: onError)
    }
    
    /// unblock user
    /// - Parameters:
    ///   - user_email
    public class func unBlockUser(user_email: String, onSuccess:@escaping()->Void, onError: @escaping (String)->Void) {
        QRoomService.unBlockUser(sdk_email: user_email, onSuccess: onSuccess, onError: onError)
    }
    
    /// list of block user
    /// - Parameters:
    ///   - token
    public class func getListBlockUser(onSuccess:@escaping([String])->Void, onError: @escaping (String)->Void){
        QRoomService.getListBlockUser(onSuccess: onSuccess, onError: onError)
    }
}
