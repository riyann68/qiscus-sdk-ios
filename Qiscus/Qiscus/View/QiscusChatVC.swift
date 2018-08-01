//
//  QiscusChatVC.swift
//  QiscusSDK
//
//  Created by Ahmad Athaullah on 8/18/16.
//  Copyright © 2016 Ahmad Athaullah. All rights reserved.
//

import UIKit
import MobileCoreServices
import Photos
import ImageViewer
import SwiftyJSON
import UserNotifications
import ContactsUI
import CoreLocation
import RealmSwift

@objc public protocol QiscusChatVCCellDelegate{
    @objc optional func chatVC(viewController:QiscusChatVC, didTapLinkButtonWithURL url:URL )
    @objc optional func chatVC(viewController:QiscusChatVC, cellForComment comment:QComment, indexPath:IndexPath)->QChatCell?
    @objc optional func chatVC(viewController:QiscusChatVC, heightForComment comment:QComment)->QChatCellHeight?
    @objc optional func chatVC(viewController:QiscusChatVC, hideCellWith comment:QComment)->Bool
}

@objc public protocol QiscusChatVCConfigDelegate{
    @objc optional func chatVCConfigDelegate(userNameLabelColor viewController:QiscusChatVC, forUser user:QUser)->UIColor?
    @objc optional func chatVCConfigDelegate(hideLeftAvatarOn viewController:QiscusChatVC)->Bool
    @objc optional func chatVCConfigDelegate(hideUserNameLabel viewController:QiscusChatVC, forUser user:QUser)->Bool
    @objc optional func chatVCConfigDelegate(usingSoftDeleteOn viewController:QiscusChatVC)->Bool
    @objc optional func chatVCConfigDelegate(deletedMessageTextFor viewController:QiscusChatVC, selfMessage isSelf:Bool)->String
    @objc optional func chatVCConfigDelegate(enableReplyMenuItem viewController:QiscusChatVC, forComment comment: QComment)->Bool
    @objc optional func chatVCConfigDelegate(enableForwardMenuItem viewController:QiscusChatVC, forComment comment: QComment)->Bool
    @objc optional func chatVCConfigDelegate(enableResendMenuItem viewController:QiscusChatVC, forComment comment: QComment)->Bool
    @objc optional func chatVCConfigDelegate(enableDeleteMenuItem viewController:QiscusChatVC, forComment comment: QComment)->Bool
    @objc optional func chatVCConfigDelegate(enableDeleteForMeMenuItem viewController:QiscusChatVC, forComment comment: QComment)->Bool
    @objc optional func chatVCConfigDelegate(enableShareMenuItem viewController:QiscusChatVC, forComment comment: QComment)->Bool
    @objc optional func chatVCConfigDelegate(enableInfoMenuItem viewController:QiscusChatVC, forComment comment: QComment)->Bool
    
    @objc optional func chatVCConfigDelegate(usingNavigationSubtitleTyping viewController:QiscusChatVC)->Bool
    @objc optional func chatVCConfigDelegate(usingTypingCell viewController:QiscusChatVC)->Bool
    
}

@objc public protocol QiscusChatVCDelegate{
    // MARK : Review this
    func chatVC(enableForwardAction viewController:QiscusChatVC)->Bool
    func chatVC(enableInfoAction viewController:QiscusChatVC)->Bool
    func chatVC(overrideBackAction viewController:QiscusChatVC)->Bool
    //
    @objc optional func chatVC(backAction viewController:QiscusChatVC, room:QRoom?, data:Any?)
    @objc optional func chatVC(titleAction viewController:QiscusChatVC, room:QRoom?, data:Any?)
    @objc optional func chatVC(viewController:QiscusChatVC, onForwardComment comment:QComment, data:Any?)
    @objc optional func chatVC(viewController:QiscusChatVC, infoActionComment comment:QComment,data:Any?)
    
    @objc optional func chatVC(onViewDidLoad viewController:QiscusChatVC)
    @objc optional func chatVC(viewController:QiscusChatVC, willAppear animated:Bool)
    @objc optional func chatVC(viewController:QiscusChatVC, willDisappear animated:Bool)
    @objc optional func chatVC(didTapAttachment actionSheet: UIAlertController, viewController: QiscusChatVC, onRoom: QRoom?)
    
    @objc optional func chatVC(viewController:QiscusChatVC, willPostComment comment:QComment, room:QRoom?, data:Any?)->QComment?
    
    @objc optional func chatVC(viewController:QiscusChatVC, didFailLoadRoom error:String)
}

public class QiscusChatVC: UIViewController{
    
    @IBOutlet weak var inputBarHeight: NSLayoutConstraint!
    // MARK: - IBOutlet Properties
    @IBOutlet weak var inputBar: UIView!
    @IBOutlet public weak var backgroundView: UIImageView!
    @IBOutlet public weak var inputText: ChatInputText!
    @IBOutlet weak var welcomeView: UIView!
    @IBOutlet weak var welcomeText: UILabel!
    @IBOutlet weak var welcomeSubtitle: UILabel!
    @IBOutlet public weak var sendButton: UIButton!
    @IBOutlet weak var attachButton: UIButton!
    @IBOutlet weak var archievedNotifView: UIView!
    @IBOutlet weak var archievedNotifLabel: UILabel!
    @IBOutlet weak var unlockButton: UIButton!
    @IBOutlet weak var emptyChatImage: UIImageView!
    @IBOutlet public weak var collectionView: QConversationCollectionView!
    @IBOutlet weak var bottomButton: UIButton!
    @IBOutlet weak var unreadIndicator: UILabel!
    @IBOutlet weak var linkPreviewContainer: UIView!
    @IBOutlet weak var linkDescription: UITextView!
    @IBOutlet weak var linkImage: UIImageView!
    @IBOutlet weak var linkTitle: UILabel!
    @IBOutlet weak var linkCancelButton: UIButton!
    @IBOutlet weak var recordBackground: UIView!
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var cancelRecordButton: UIButton!
    
    // MARK: - Constrain
    @IBOutlet public weak var minInputHeight: NSLayoutConstraint!
    @IBOutlet weak var archievedNotifTop: NSLayoutConstraint!
    @IBOutlet weak var inputBarBottomMargin: NSLayoutConstraint!
    @IBOutlet weak var collectionViewBottomConstrain: NSLayoutConstraint!
    @IBOutlet weak var linkPreviewTopMargin: NSLayoutConstraint!
    @IBOutlet weak var recordViewLeading: NSLayoutConstraint!
    @IBOutlet weak var linkImageWidth: NSLayoutConstraint!
    @IBOutlet public weak var collectionViewTopMargin: NSLayoutConstraint!
    
    public var delegate:QiscusChatVCDelegate?
    public var configDelegate:QiscusChatVCConfigDelegate?
    public var cellDelegate:QiscusChatVCCellDelegate?

    public var data:Any?
    
    var isPresence:Bool = false
    public var titleLabel = UILabel()
    public var subtitleLabel = UILabel()
    internal var subtitleText:String = ""
    var roomAvatarImage:UIImage?
    public var roomAvatar = UIImageView()
    public var titleView = UIView()
    
    var isBeforeTranslucent = false
    // MARK: - shared Properties
    var commentClient = QiscusCommentClient.sharedInstance
    var archived:Bool = QiscusUIConfiguration.sharedInstance.readOnly
    
    var selectedCellIndex:IndexPath? = nil
    let locationManager = CLLocationManager()
    var didFindLocation = true
    var prefetch:Bool = false
    var presentingLoading = false
    var flagPresence = true
    internal let currentNavbarTint = UINavigationBar.appearance().tintColor
    static let currentNavbarTint = UINavigationBar.appearance().tintColor
    
    var replyData:QComment? = nil {
        didSet{
            self.reply(toComment: replyData)
        }
    }
    
    public var defaultBack:Bool = true
    
    // MARK: - Data Properties
    var loadMoreControl = UIRefreshControl()
    var processingFile = false
    var processingAudio = false
    var loadingMore = false
    
    // MARK: -  Data load configuration
    public var chatRoom:QRoom?{
        didSet{
            if let room = self.chatRoom {
                if !prefetch && isPresence {
                    room.subscribeRealtimeStatus()
                }
                self.collectionView.room = self.chatRoom
            }
            if oldValue == nil && self.chatRoom != nil {
                let _ = self.view
                self.view.layoutSubviews()
                self.view.layoutIfNeeded()
                let delay = 0.5 * Double(NSEC_PER_SEC)
                let time = DispatchTime.now() + delay / Double(NSEC_PER_SEC)
                DispatchQueue.main.asyncAfter(deadline: time, execute: {
                    self.dismissLoading()
                    self.dataLoaded = true
                })
            }
            
            if let roomId = self.chatRoom?.id {
                let center: NotificationCenter = NotificationCenter.default
                center.addObserver(self, selector: #selector(QiscusChatVC.userTyping(_:)), name: QiscusNotification.USER_TYPING(onRoom: roomId), object: nil)
            }

        }
    }
    public var chatMessage:String?
    public var chatRoomId:String?
    public var isPublicChannel:Bool = false
    public var chatUser:String?
    public var chatTitle:String?{
        didSet{
            self.loadTitle()
        }
    }
    public var chatSubtitle:String?
    public var chatNewRoomUsers:[String] = [String]()
    var chatDistinctId:String?
    var chatData:String?
    public var chatRoomUniqueId:String?
    public var chatTarget:QComment?
    
    var chatAvatarURL = ""
    var chatService = QChatService()
    var collectionWidth:CGFloat = 0
    
    var topColor = Qiscus.shared.styleConfiguration.color.topColor
    var bottomColor = Qiscus.shared.styleConfiguration.color.bottomColor
    var tintColor = Qiscus.shared.styleConfiguration.color.tintColor
    
    // MARK: Galery variable
    var galleryItems:[QiscusGalleryItem] = [QiscusGalleryItem]()
    
    var imagePreview:GalleryViewController?
    var loadWithUser:Bool = false // will be removed
    
    //MARK: - external action
    @objc public var unlockAction:(()->Void) = {}
    
    var audioPlayer: AVAudioPlayer?
    var audioTimer: Timer?
    var activeAudioCell: QCellAudio?
    var loadingView = QLoadingViewController.sharedInstance
    var firstLoad = true
    
    // MARK: - Audio recording variable
    var isRecording = false
    var recordingURL:URL?
    var recorder:AVAudioRecorder?
    var recordingSession = AVAudioSession.sharedInstance()
    var recordTimer:Timer?
    var recordDuration:Int = 0
    
    //data flag
    var checkingData:Bool = false
    var roomSynced = false
    var remoteTypingTimer:Timer?
    var typingTimer:Timer?
    var publishStatusTimer:Timer? = nil
    var defaultBackButtonVisibility = true
    var defaultNavBarVisibility = true
    var defaultLeftButton:[UIBarButtonItem]? = nil
    
    // navigation
    public var navTitle:String = ""
    public var navSubtitle:String = ""
    var dataLoaded = false
    
    var bundle:Bundle {
        get{
            return Qiscus.bundle
        }
    }
    
    var lastVisibleRow:IndexPath?{
        get{
            let indexPaths = collectionView.indexPathsForVisibleItems
            if indexPaths.count > 0 {
                var lastIndexpath = indexPaths.first!
                var i = 0
                for indexPath in indexPaths {
                    if indexPath.section > lastIndexpath.section {
                        lastIndexpath.section = indexPath.section
                        lastIndexpath.row = indexPath.row
                    }else if indexPath.section == lastIndexpath.section {
                        if indexPath.row > lastIndexpath.row {
                            lastIndexpath.row = indexPath.row
                        }
                    }
                    i += 1
                }
                return lastIndexpath
            }else{
                return nil
            }
        }
    }
    var UTIs:[String]{
        get{
            return ["public.jpeg", "public.png","com.compuserve.gif","public.text", "public.archive", "com.microsoft.word.doc", "com.microsoft.excel.xls", "com.microsoft.powerpoint.​ppt", "com.adobe.pdf","public.mpeg-4"]
        }
    }
    var contactVC = CNContactPickerViewController()
    var typingUsers = [String:QUser]()
    var typingUserTimer = [String:Timer]()
    
    var processingTyping = false
    
    
    var previewedTypingUsers = [String]()
    
    public init() {
        super.init(nibName: "QiscusChatVC", bundle: Qiscus.bundle)
        let _ = self.view
        
        let lightColor = self.topColor.withAlphaComponent(0.4)
        recordBackground.backgroundColor = lightColor
        recordBackground.layer.cornerRadius = 16
        bottomButton.setImage(Qiscus.image(named: "bottom")?.withRenderingMode(.alwaysTemplate), for: .normal)
        bottomButton.layer.cornerRadius = 17.5
        bottomButton.clipsToBounds = true
        unreadIndicator.isHidden = true
        unreadIndicator.layer.cornerRadius = 11.5
        unreadIndicator.clipsToBounds = true
        backgroundView.image = Qiscus.image(named: "chat_bg")
        
        linkPreviewContainer.layer.shadowColor = UIColor.black.cgColor
        linkPreviewContainer.layer.shadowOpacity = 0.6
        linkPreviewContainer.layer.shadowOffset = CGSize(width: -5, height: 0)
        linkCancelButton.tintColor = QiscusColorConfiguration.sharedInstance.rightBaloonColor
        linkCancelButton.setImage(Qiscus.image(named: "ar_cancel")?.withRenderingMode(.alwaysTemplate), for: .normal)
        roomAvatar.contentMode = .scaleAspectFill
        inputText.font = Qiscus.style.chatFont
        
        self.emptyChatImage.tintColor = self.topColor
        
        self.emptyChatImage.image = QiscusAssetsConfiguration.shared.emptyChat
        self.emptyChatImage.tintColor = self.bottomColor
        
        let sendImage = Qiscus.image(named: "send")?.withRenderingMode(.alwaysTemplate)
        let attachmentImage = Qiscus.image(named: "share_attachment")?.withRenderingMode(.alwaysTemplate)
        let recordImage = Qiscus.image(named: "ar_record")?.withRenderingMode(.alwaysTemplate)
        let cancelRecordImage = Qiscus.image(named: "ar_cancel")?.withRenderingMode(.alwaysTemplate)
        
        self.sendButton.setImage(sendImage, for: .normal)
        self.attachButton.setImage(attachmentImage, for: .normal)
        self.recordButton.setImage(recordImage, for: .normal)
        self.cancelRecordButton.setImage(cancelRecordImage, for: .normal)
        
        self.cancelRecordButton.isHidden = true
        
        self.sendButton.tintColor = Qiscus.shared.styleConfiguration.color.topColor
        self.attachButton.tintColor = Qiscus.shared.styleConfiguration.color.topColor
        self.recordButton.tintColor = Qiscus.shared.styleConfiguration.color.topColor
        self.cancelRecordButton.tintColor = Qiscus.shared.styleConfiguration.color.topColor
        self.bottomButton.tintColor = Qiscus.shared.styleConfiguration.color.topColor
        self.bottomButton.isHidden = true
        
        sendButton.addTarget(self, action: #selector(QiscusChatVC.sendMessage), for: .touchUpInside)
        recordButton.addTarget(self, action: #selector(QiscusChatVC.recordVoice), for: .touchUpInside)
        cancelRecordButton.addTarget(self, action: #selector(QiscusChatVC.cancelRecordVoice), for: .touchUpInside)
        
        
        self.unlockButton.addTarget(self, action: #selector(QiscusChatVC.confirmUnlockChat), for: .touchUpInside)
        
        self.welcomeText.text = QiscusTextConfiguration.sharedInstance.emptyTitle
        self.welcomeSubtitle.text = QiscusTextConfiguration.sharedInstance.emptyMessage
        self.emptyChatImage.image = Qiscus.style.assets.emptyChat
        self.inputText.placeholder = QiscusTextConfiguration.sharedInstance.textPlaceholder
        self.inputText.chatInputDelegate = self
        
        // Keyboard stuff.
        self.qiscusAutoHideKeyboard()
        
        bottomButton.isHidden = true
        
        self.inputBarBottomMargin.constant = 0
        
        self.archievedNotifView.backgroundColor = QiscusColorConfiguration.sharedInstance.lockViewBgColor
        self.archievedNotifLabel.textColor = QiscusColorConfiguration.sharedInstance.lockViewTintColor
        let unlockImage = Qiscus.image(named: "ic_open_archived")?.withRenderingMode(.alwaysTemplate)
        self.unlockButton.setBackgroundImage(unlockImage, for: UIControlState())
        self.unlockButton.tintColor = QiscusColorConfiguration.sharedInstance.lockViewTintColor
        
        self.view.layoutIfNeeded()
        
        let titleWidth = QiscusHelper.screenWidth()
        
        titleLabel = UILabel(frame:CGRect(x: 40, y: 7, width: titleWidth, height: 17))
        titleLabel.backgroundColor = UIColor.clear
        titleLabel.textColor = QiscusChatVC.currentNavbarTint
        titleLabel.font = UIFont.boldSystemFont(ofSize: UIFont.systemFontSize)
        titleLabel.text = self.chatTitle
        titleLabel.textAlignment = .left
        
        subtitleLabel = UILabel(frame:CGRect(x: 40, y: 25, width: titleWidth, height: 13))
        subtitleLabel.backgroundColor = UIColor.clear
        subtitleLabel.textColor = QiscusChatVC.currentNavbarTint
        subtitleLabel.font = UIFont.systemFont(ofSize: 11)
        subtitleLabel.text = self.chatSubtitle
        subtitleLabel.textAlignment = .left
        
        self.roomAvatar = UIImageView()
        self.roomAvatar.contentMode = .scaleAspectFill
        self.roomAvatar.backgroundColor = UIColor.white
        
        let bgColor = QiscusColorConfiguration.sharedInstance.avatarBackgroundColor
        
        self.roomAvatar.frame = CGRect(x: 0,y: 6,width: 32,height: 32)
        self.roomAvatar.layer.cornerRadius = 16
        self.roomAvatar.clipsToBounds = true
        self.roomAvatar.backgroundColor = bgColor[0]
        
        self.titleView = UIView(frame: CGRect(x: 0, y: 0, width: titleWidth + 40, height: 44))
        self.titleView.addSubview(self.titleLabel)
        self.titleView.addSubview(self.subtitleLabel)
        self.titleView.addSubview(self.roomAvatar)
        
        let center: NotificationCenter = NotificationCenter.default
        center.addObserver(self, selector: #selector(QiscusChatVC.appDidEnterBackground), name: NSNotification.Name.UIApplicationDidEnterBackground, object: nil)
       
        self.welcomeView.isHidden = true
        self.collectionView.isHidden = true
    }
    
    @objc func appPresence(){
         self.loadSubtitle()
    }
    
    func checkSingleRoom()->Bool{
        if let room = self.chatRoom {
            if room.type == .single && flagPresence{
                flagPresence = false
                return true
            }else{
                return false
            }
        }else {
            return false
        }
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - UI Lifecycle
    override public func viewDidLoad() {
        super.viewDidLoad()
        self.chatService.delegate = self
        if #available(iOS 9, *) {
            self.collectionView.dataSource = self.collectionView
        }
        if let delegate = self.delegate{
            delegate.chatVC?(onViewDidLoad: self)
        }
        
    }

    
    override public func viewWillDisappear(_ animated: Bool) {
        if let room = self.chatRoom {
            room.readAll()
            room.unsubscribeRoomChannel()
            room.clearRemain30()
        }
        self.isPresence = false
        self.dataLoaded = false
        super.viewWillDisappear(animated)
        view.endEditing(true)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        NotificationCenter.default.removeObserver(self, name: .UIKeyboardWillChangeFrame, object: nil)
        NotificationCenter.default.removeObserver(self, name: .UIApplicationDidBecomeActive, object: nil)
        if checkSingleRoom(){
            NotificationCenter.default.removeObserver(self, name: QiscusNotification.USER_PRESENCE, object:nil)
        }
        
        if let roomId = self.chatRoom?.id {
            NotificationCenter.default.removeObserver(self, name: QiscusNotification.USER_TYPING(onRoom: roomId), object: nil)
        }
    
        view.endEditing(true)
        
        self.dismissLoading()
        if let delegate = self.delegate {
            delegate.chatVC?(viewController: self, willDisappear: animated)
        }
    }
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if #available(iOS 11.0, *) {
            self.navigationController?.navigationBar.prefersLargeTitles = false
            self.navigationController?.navigationItem.largeTitleDisplayMode = .never
        }
        
        if !self.prefetch {
            self.isPresence = true
            if let room = self.chatRoom {
                let rid = room.id
                QiscusBackgroundThread.async {
                    if let rts = QRoom.threadSaveRoom(withId: rid){
                        rts.readAll()
                        rts.subscribeRoomChannel()
                    }
                }
            }
        }
        titleLabel.textColor = QiscusChatVC.currentNavbarTint
        subtitleLabel.textColor = QiscusChatVC.currentNavbarTint
        
        self.collectionView.viewDelegate = self
        self.collectionView.roomDelegate = self
        self.collectionView.cellDelegate = self
        self.collectionView.configDelegate = self
        self.collectionView.reloadData()
        
        UINavigationBar.appearance().tintColor = self.currentNavbarTint
        
        if let _ = self.navigationController {
            self.navigationController?.navigationBar.isTranslucent = false
            self.defaultNavBarVisibility = self.navigationController!.isNavigationBarHidden
        }
        
        setupNavigationTitle()
        setupPage()
        
        if !self.prefetch {
            let center: NotificationCenter = NotificationCenter.default
            center.addObserver(self, selector: #selector(QiscusChatVC.keyboardWillHide(_:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
            center.addObserver(self, selector: #selector(QiscusChatVC.keyboardChange(_:)), name: NSNotification.Name.UIKeyboardWillChangeFrame, object: nil)
            center.addObserver(self, selector: #selector(QiscusChatVC.applicationDidBecomeActive), name: .UIApplicationDidBecomeActive, object: nil)
            
            if let roomId = self.chatRoom?.id {
                center.addObserver(self, selector: #selector(QiscusChatVC.userTyping(_:)), name: QiscusNotification.USER_TYPING(onRoom: roomId), object: nil)
            }

        }
        if self.loadMoreControl.isRefreshing {
            self.loadMoreControl.endRefreshing()
        }
        if self.defaultBack {
            self.defaultBackButtonVisibility = self.navigationItem.hidesBackButton
        }
        if self.navigationItem.leftBarButtonItems != nil {
            self.defaultLeftButton = self.navigationItem.leftBarButtonItems
        }else{
            self.defaultLeftButton = nil
        }
        
        if let navController = self.navigationController {
            self.isBeforeTranslucent = navController.navigationBar.isTranslucent
            self.navigationController?.navigationBar.isTranslucent = false
            self.defaultNavBarVisibility = self.navigationController!.isNavigationBarHidden
        }
        self.navigationController?.setNavigationBarHidden(false , animated: false)
        
        if self.defaultBack {
            let backButton = QiscusChatVC.backButton(self, action: #selector(QiscusChatVC.goBack))
            self.navigationItem.setHidesBackButton(true, animated: false)
            self.navigationItem.leftBarButtonItems = [backButton]
        }
        
        self.clearAllNotification()
        view.endEditing(true)
        
        
        if inputText.value == "" {
            sendButton.isEnabled = false
            sendButton.isHidden = true
            recordButton.isHidden = false
        }else{
            sendButton.isEnabled = true
        }
        
        if let room = self.chatRoom {
            if self.collectionView.room == nil {
                self.collectionView.room = room
            }
            self.loadTitle()
            self.loadSubtitle()
            self.unreadIndicator.isHidden = true
            if let r = self.collectionView.room {
                if r.comments.count == 0 {
                    if self.isPresence && !self.prefetch && self.chatRoom == nil {
                        self.showLoading("Load data ...")
                    }
                    self.collectionView.loadData()
                }
            }
            if self.chatMessage != nil && self.chatMessage != "" {
                let newMessage = self.chatRoom!.newComment(text: self.chatMessage!)
                self.postComment(comment: newMessage)
                self.chatMessage = nil
            }
            room.resendPendingMessage()
            room.redeletePendingDeletedMessage()
            setupNavigationTitle()
            setupPage()
        }
        
        self.loadData()
        
        if let delegate = self.delegate {
            delegate.chatVC?(viewController: self, willAppear: animated)
        }
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if firstLoad {
            if self.isPresence && !self.prefetch && self.chatRoom == nil {
                self.showLoading("Load data ...")
            }
            self.collectionView.room = self.chatRoom
        }
        if let room = self.chatRoom {
            Qiscus.shared.chatViews[room.id] = self
        }else{
            if self.isPresence && !self.prefetch && self.chatRoom == nil {
                self.showLoading("Load data ...")
            }
        }
        if let target = self.chatTarget {
            if let commentTarget = QComment.comment(withUniqueId: target.uniqueId){
                self.collectionView.scrollToComment(comment: commentTarget)
            }else{
                QToasterSwift.toast(target: self, text: "Can't find message", backgroundColor: UIColor(red: 0.9, green: 0,blue: 0,alpha: 0.8), textColor: UIColor.white)
            }
            self.chatTarget = nil
        }
        self.prefetch = false
    }
    
    // MARK: - Memory Warning
    override public func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    // MARK: - Clear Notification Method
    public func clearAllNotification(){
        if #available(iOS 10.0, *) {
            let center = UNUserNotificationCenter.current()
            center.removeAllDeliveredNotifications() // To remove all delivered notifications
            center.removeAllPendingNotificationRequests()
        }else{
            UIApplication.shared.cancelAllLocalNotifications()
        }
    }
    
    // MARK: - Setup UI
    func setupNavigationTitle(){
        var totalButton = 1
        if let leftButtons = self.navigationItem.leftBarButtonItems {
            totalButton += leftButtons.count
        }
        if let rightButtons = self.navigationItem.rightBarButtonItems {
            totalButton += rightButtons.count
        }
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(QiscusChatVC.goToTitleAction))
        self.titleView.addGestureRecognizer(tapRecognizer)
        
        let containerWidth = QiscusHelper.screenWidth() - 49
        let titleWidth = QiscusHelper.screenWidth() - CGFloat(49 * totalButton) - 40
        
        self.titleLabel.frame = CGRect(x: 40, y: 7, width: titleWidth, height: 17)
        self.subtitleLabel.frame = CGRect(x: 40, y: 25, width: titleWidth, height: 13)
        self.roomAvatar.frame = CGRect(x: 0,y: 6,width: 32,height: 32)
        self.titleView.frame = CGRect(x: 0, y: 0, width: containerWidth, height: 44)
        if self.chatTitle != nil {
            self.titleLabel.text = self.chatTitle
        }
        self.navigationItem.titleView = titleView
    }
    func setupPage(){
        archievedNotifView.isHidden = !archived
        self.archievedNotifTop.constant = 0
        if archived {
            self.archievedNotifLabel.text = QiscusTextConfiguration.sharedInstance.readOnlyText
        }else{
            self.archievedNotifTop.constant = 65
        }
    }
    
    // MARK: - Keyboard Methode
    @objc func keyboardWillHide(_ notification: Notification){
        let info: NSDictionary = (notification as NSNotification).userInfo! as NSDictionary
        
        let animateDuration = info[UIKeyboardAnimationDurationUserInfoKey] as! Double
        let goToRow = self.lastVisibleRow
        self.inputBarBottomMargin.constant = 0
        UIView.animate(withDuration: animateDuration, delay: 0, options: UIViewAnimationOptions(), animations: {
            self.view.layoutIfNeeded()
            if goToRow != nil {
                self.collectionView.scrollToItem(at: goToRow!, at: .bottom, animated: false)
            }
        }, completion: nil)
    }
    
    @objc func keyboardChange(_ notification: Notification){
        let info:NSDictionary = (notification as NSNotification).userInfo! as NSDictionary
        let keyboardSize = (info[UIKeyboardFrameEndUserInfoKey] as! NSValue).cgRectValue
        
        let keyboardHeight: CGFloat = keyboardSize.height
        let animateDuration = info[UIKeyboardAnimationDurationUserInfoKey] as! Double
        
        self.inputBarBottomMargin.constant = 0 - keyboardHeight
        let goToRow = self.lastVisibleRow
        UIView.animate(withDuration: animateDuration, delay: 0, options: UIViewAnimationOptions(), animations: {
            self.view.layoutIfNeeded()
            if goToRow != nil {
                self.collectionView.scrollToItem(at: goToRow!, at: .bottom, animated: true)
            }
        }, completion: nil)
    }
    
    // MARK: - Navigation Action
    func rightLeftButtonAction(_ sender: AnyObject) {
    }
    func righRightButtonAction(_ sender: AnyObject) {
    }
    @objc func goBack() {
        self.isPresence = false
        view.endEditing(true)
        if let delegate = self.delegate{
            if delegate.chatVC(overrideBackAction: self){
                delegate.chatVC?(backAction: self, room: self.chatRoom, data:data)
            }else{
                let _ = self.navigationController?.popViewController(animated: true)
            }
        }else{
            let _ = self.navigationController?.popViewController(animated: true)
        }
    }
    func unsubscribeNotificationCenter(){
        let center: NotificationCenter = NotificationCenter.default
        center.removeObserver(self)
    }
    // MARK: - Button Action
    @objc func appDidEnterBackground(){
        self.isPresence = false
        view.endEditing(true)
        self.dismissLoading()
    }
    public func resendMessage(){
        
    }
    
    @IBAction func goToBottomTapped(_ sender: UIButton) {
        self.collectionView.scrollToBottom()
    }
    
    @IBAction func hideLinkPreview(_ sender: UIButton) {
        if replyData != nil {
            replyData = nil
        }
    }
    
    @IBAction func showAttcahMenu(_ sender: UIButton) {
        self.showAttachmentMenu()
    }
    
    @IBAction func doNothing(_ sender: Any) {}
    
    public func postComment(comment : QComment) {
        var postedComment = comment
        if let delegate = self.delegate {
            if let temp = delegate.chatVC?(viewController: self, willPostComment: postedComment, room: self.chatRoom, data: self.data){
                postedComment = temp
            }
        }
        chatRoom?.post(comment: postedComment)
    }
    public func register(_ nib: UINib?, forChatCellWithReuseIdentifier identifier: String) {
        self.collectionView.register(nib, forCellWithReuseIdentifier: identifier)
    }
    public func register(_ chatCellClass: AnyClass?, forCellWithReuseIdentifier identifier: String) {
        self.collectionView.register(chatCellClass, forCellWithReuseIdentifier: identifier)
    }
    @objc internal func applicationDidBecomeActive(){
        if let room = self.collectionView.room{
            room.syncRoom()
        }
    }
    
    public func postReceivedFile(fileUrl: URL) {
        self.showLoading("Processing File")
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(readingItemAt: fileUrl, options: NSFileCoordinator.ReadingOptions.forUploading, error: nil) { (dataURL) in
            do{
                var data:Data = try Data(contentsOf: dataURL, options: NSData.ReadingOptions.mappedIfSafe)
                let mediaSize = Double(data.count) / 1024.0
                
                if mediaSize > Qiscus.maxUploadSizeInKB {
                    self.processingFile = false
                    self.dismissLoading()
                    self.showFileTooBigAlert()
                    return
                }
                
                var fileName = dataURL.lastPathComponent.replacingOccurrences(of: "%20", with: "_")
                fileName = fileName.replacingOccurrences(of: " ", with: "_")
                
                var popupText = QiscusTextConfiguration.sharedInstance.confirmationImageUploadText
                var fileType = QiscusFileType.image
                var thumb:UIImage? = nil
                let fileNameArr = (fileName as String).split(separator: ".")
                let ext = String(fileNameArr.last!).lowercased()
                
                let gif = (ext == "gif" || ext == "gif_")
                let video = (ext == "mp4" || ext == "mp4_" || ext == "mov" || ext == "mov_")
                let isImage = (ext == "jpg" || ext == "jpg_" || ext == "tif" || ext == "heic" || ext == "png" || ext == "png_")
                let isPDF = (ext == "pdf" || ext == "pdf_")
                var usePopup = false
                
                if isImage{
                    var i = 0
                    for n in fileNameArr{
                        if i == 0 {
                            fileName = String(n)
                        }else if i == fileNameArr.count - 1 {
                            fileName = "\(fileName).jpg"
                        }else{
                            fileName = "\(fileName).\(String(n))"
                        }
                        i += 1
                    }
                    let image = UIImage(data: data)!
                    let imageSize = image.size
                    var bigPart = CGFloat(0)
                    if(imageSize.width > imageSize.height){
                        bigPart = imageSize.width
                    }else{
                        bigPart = imageSize.height
                    }
                    
                    var compressVal = CGFloat(1)
                    if(bigPart > 2000){
                        compressVal = 2000 / bigPart
                    }
                    data = UIImageJPEGRepresentation(image, compressVal)!
                    thumb = UIImage(data: data)
                }else if isPDF{
                    usePopup = true
                    popupText = "Are you sure to send this document?"
                    fileType = QiscusFileType.document
                    if let provider = CGDataProvider(data: data as NSData) {
                        if let pdfDoc = CGPDFDocument(provider) {
                            if let pdfPage:CGPDFPage = pdfDoc.page(at: 1) {
                                var pageRect:CGRect = pdfPage.getBoxRect(.mediaBox)
                                pageRect.size = CGSize(width:pageRect.size.width, height:pageRect.size.height)
                                UIGraphicsBeginImageContext(pageRect.size)
                                if let context:CGContext = UIGraphicsGetCurrentContext(){
                                    context.saveGState()
                                    context.translateBy(x: 0.0, y: pageRect.size.height)
                                    context.scaleBy(x: 1.0, y: -1.0)
                                    context.concatenate(pdfPage.getDrawingTransform(.mediaBox, rect: pageRect, rotate: 0, preserveAspectRatio: true))
                                    context.drawPDFPage(pdfPage)
                                    context.restoreGState()
                                    if let pdfImage:UIImage = UIGraphicsGetImageFromCurrentImageContext() {
                                        thumb = pdfImage
                                    }
                                }
                                UIGraphicsEndImageContext()
                            }
                        }
                    }
                }
                else if gif{
                    let image = UIImage(data: data)!
                    thumb = image
                    let asset = PHAsset.fetchAssets(withALAssetURLs: [dataURL], options: nil)
                    if let phAsset = asset.firstObject {
                        let option = PHImageRequestOptions()
                        option.isSynchronous = true
                        option.isNetworkAccessAllowed = true
                        PHImageManager.default().requestImageData(for: phAsset, options: option) {
                            (gifData, dataURI, orientation, info) -> Void in
                            data = gifData!
                        }
                    }
                    popupText = "Are you sure to send this image?"
                    usePopup = true
                }else if video {
                    fileType = .video
                    
                    let assetMedia = AVURLAsset(url: dataURL)
                    let thumbGenerator = AVAssetImageGenerator(asset: assetMedia)
                    thumbGenerator.appliesPreferredTrackTransform = true
                    
                    let thumbTime = CMTimeMakeWithSeconds(0, 30)
                    let maxSize = CGSize(width: QiscusHelper.screenWidth(), height: QiscusHelper.screenWidth())
                    thumbGenerator.maximumSize = maxSize
                    
                    do{
                        let thumbRef = try thumbGenerator.copyCGImage(at: thumbTime, actualTime: nil)
                        thumb = UIImage(cgImage: thumbRef)
                        popupText = "Are you sure to send this video?"
                    }catch{
                        Qiscus.printLog(text: "error creating thumb image")
                    }
                    usePopup = true
                }else{
                    usePopup = true
                    let textFirst = QiscusTextConfiguration.sharedInstance.confirmationFileUploadText
                    let textMiddle = "\(fileName as String)"
                    let textLast = QiscusTextConfiguration.sharedInstance.questionMark
                    popupText = "\(textFirst) \(textMiddle) \(textLast)"
                    fileType = QiscusFileType.file
                }
                self.dismissLoading()
                //                UINavigationBar.appearance().tintColor = self.currentNavbarTint
                if usePopup {
                    QPopUpView.showAlert(withTarget: self, image: thumb, message:popupText, isVideoImage: video,
                                         doneAction: {
                                            self.postFile(filename: fileName, data: data, type: fileType, thumbImage: thumb)
                    },
                                         cancelAction: {
                                            Qiscus.printLog(text: "cancel upload")
                                            QFileManager.clearTempDirectory()
                    }
                    )
                }else{
                    let uploader = QiscusUploaderVC(nibName: "QiscusUploaderVC", bundle: Qiscus.bundle)
                    uploader.chatView = self
                    uploader.data = data
                    uploader.fileName = fileName
                    uploader.room = self.chatRoom
                    self.navigationController?.pushViewController(uploader, animated: true)
                }
            }catch _{
                self.dismissLoading()
            }
        }
    }
}

extension QiscusChatVC:QChatServiceDelegate{
    public func chatService(didFinishLoadRoom inRoom: QRoom, withMessage message: String?) {
        self.chatRoomId = inRoom.id
        self.chatRoom = inRoom
        self.chatRoomUniqueId = inRoom.uniqueId
        self.isPublicChannel = inRoom.isPublicChannel
        self.loadTitle()
        self.loadSubtitle()
        self.unreadIndicator.isHidden = true
        
        if inRoom.isPublicChannel {
            Qiscus.shared.mqtt?.subscribe("\(Qiscus.client.appId)/\(inRoom.uniqueId)/c")
        }
        
        if self.chatMessage != nil && self.chatMessage != "" {
            let newMessage = self.chatRoom!.newComment(text: self.chatMessage!)
            self.postComment(comment: newMessage)
            self.chatMessage = nil
        }
        Qiscus.shared.chatViews[inRoom.id] = self
        if inRoom.comments.count > 0 {
            self.collectionView.refreshData()
            if let target = self.chatTarget {
                self.collectionView.scrollToComment(comment: target)
                self.chatTarget = nil
            }else{
                self.collectionView.scrollToBottom()
            }
        }
        if checkSingleRoom(){
            let presence: NotificationCenter = NotificationCenter.default
            presence.addObserver(self, selector: #selector(QiscusChatVC.appPresence), name: QiscusNotification.USER_PRESENCE, object: nil)
        }
        self.dismissLoading()
        
    }
    public func chatService(didFailLoadRoom error: String) {
        let delay = 1.5 * Double(NSEC_PER_SEC)
        let time = DispatchTime.now() + delay / Double(NSEC_PER_SEC)
        DispatchQueue.main.asyncAfter(deadline: time, execute: {
            self.dismissLoading()
        })
        if chatRoom?.storedName == nil {
            if !Qiscus.sharedInstance.connected {
                QToasterSwift.toast(target: self, text: "No Internet Connection", backgroundColor: UIColor(red: 0.9, green: 0,blue: 0,alpha: 0.8), textColor: UIColor.white)
            }else {
                QToasterSwift.toast(target: self, text: "Can't load chat room\n\(error)", backgroundColor: UIColor(red: 0.9, green: 0,blue: 0,alpha: 0.8), textColor: UIColor.white)
                self.hideInputBar()
            }
        }
        self.dataLoaded = false
        self.delegate?.chatVC?(viewController: self, didFailLoadRoom: error)
    }
    
}
extension QiscusChatVC:QConversationViewRoomDelegate{
    public func roomDelegate(didChangeName room: QRoom, name:String){
        if name != self.titleLabel.text{
            self.titleLabel.text = name
        }
    }
    public func roomDelegate(didFinishSync room: QRoom){
        self.dismissLoading()
        if self.chatRoom!.comments.count > 0 {
            self.collectionView.refreshData()
            if let target = self.chatTarget {
                self.collectionView.layoutIfNeeded()
                self.collectionView.scrollToComment(comment: target)
            }else{
                self.collectionView.scrollToBottom()
            }
        }
    }
    public func roomDelegate(didChangeAvatar room: QRoom, avatar:UIImage){
        self.roomAvatar.image = avatar
    }
    public func roomDelegate(didFailUpdate error: String){}
    public func roomDelegate(didChangeUser room: QRoom, user: QUser){
        if self.chatRoom!.type == .single {
            if user.email != Qiscus.client.email && self.chatRoom!.typingUser == ""{
                self.loadSubtitle()
            }
        }
    }
    public func roomDelegate(didChangeParticipant room: QRoom){
        if self.chatRoom?.type == .group && (self.chatSubtitle == "" || self.chatSubtitle == nil){
            self.loadSubtitle()
        }
    }
    public func roomDelegate(didChangeUnread room:QRoom, unreadCount:Int){
        if unreadCount == 0 {
            self.unreadIndicator.text = ""
            self.unreadIndicator.isHidden = true
        }else{
            if unreadCount > 99 {
                self.unreadIndicator.text = "99+"
            }else{
                self.unreadIndicator.text = "\(unreadCount)"
            }
            self.unreadIndicator.isHidden = self.bottomButton.isHidden
        }
    }
    public func roomDelegate(gotFirstComment room: QRoom) {
        self.welcomeView.isHidden = true
        self.collectionView.isHidden = false
    }
}

extension QiscusChatVC: CLLocationManagerDelegate {
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        QiscusBackgroundThread.async {autoreleasepool{
            manager.stopUpdatingLocation()
            if !self.didFindLocation {
                if let currentLocation = manager.location {
                    let geoCoder = CLGeocoder()
                    let latitude = currentLocation.coordinate.latitude
                    let longitude = currentLocation.coordinate.longitude
                    var address:String?
                    var title:String?
                    
                    geoCoder.reverseGeocodeLocation(currentLocation, completionHandler: { (placemarks, error) in
                        if error == nil {
                            let placeArray = placemarks
                            var placeMark: CLPlacemark!
                            placeMark = placeArray?[0]
                            
                            if let addressDictionary = placeMark.addressDictionary{
                                if let addressArray = addressDictionary["FormattedAddressLines"] as? [String] {
                                    address = addressArray.joined(separator: ", ")
                                }
                                title = addressDictionary["Name"] as? String
                                DispatchQueue.main.async { autoreleasepool{
                                    let comment = self.chatRoom!.newLocationComment(latitude: latitude, longitude: longitude, title: title, address: address)
                                    self.postComment(comment: comment)
                                    self.addCommentToCollectionView(comment: comment)
                                }}
                            }
                        }
                    })
                    
                }
                self.didFindLocation = true
                self.dismissLoading()
            }
        }}
    }
}
