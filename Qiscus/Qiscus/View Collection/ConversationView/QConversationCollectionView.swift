//
//  QConversationCollectionView.swift
//  Qiscus
//
//  Created by Ahmad Athaullah on 06/12/17.
//  Copyright © 2017 Ahmad Athaullah. All rights reserved.
//

import UIKit
import MobileCoreServices
import AVFoundation

public class QConversationCollectionView: UICollectionView {
    public var room:QRoom? {
        didSet{
            if let oldRoom = oldValue {
                oldRoom.delegate = nil
            }
            if let r = room {
                let rid = r.id
                Qiscus.chatRooms[r.id] = r
                r.delegate = self
                r.subscribeRealtimeStatus()
                self.registerCell()
                self.unsubscribeEvent()
                self.subscribeEvent()
                self.delegate = self
                self.dataSource = self

                QiscusBackgroundThread.async {
                    if let rts = QRoom.threadSaveRoom(withId: rid){
                        var messages = rts.grouppedCommentsUID
                        messages = self.checkHiddenMessage(messages: messages)
                        
                        DispatchQueue.main.async {
                            self.messagesId = messages
                            self.reloadData()
                        }
                    }
                }
            }else{
                self.messagesId = [[String]]()
                self.unsubscribeEvent()
                self.delegate = self
                self.dataSource = self
                self.reloadData()
            }
        }
    }
    public var typingUsers = [String:QUser]()
    
    public var viewDelegate:QConversationViewDelegate?
    public var roomDelegate:QConversationViewRoomDelegate?
    public var cellDelegate:QConversationViewCellDelegate?
    public var configDelegate:QConversationViewConfigurationDelegate?
    
    public var typingUserTimer = [String:Timer]()
    
    public var processingTyping = false
    public var previewedTypingUsers = [String]()
    public var isPresence = false
        
    public var messagesId = [[String]](){
        didSet{
            DispatchQueue.main.async {
                if oldValue.count == 0 {
                    self.layoutIfNeeded()
                    self.scrollToBottom()
                }
                self.viewDelegate?.viewDelegate?(view: self, didLoadData: self.messagesId)
            }
        }
    }
    internal var loadingMore = false
    internal var targetIndexPath:IndexPath?
    
    var isLastRowVisible: Bool = false
    
    // MARK: Audio Variable
    var audioPlayer: AVAudioPlayer?
    var audioTimer: Timer?
    var activeAudioCell: QCellAudio?
    
    // Overrided method
    @objc public var registerCustomCell:(()->Void)? = nil
    
    var loadMoreControl = UIRefreshControl()
    public var targetComment:QComment?
    
    override public func draw(_ rect: CGRect) {
        self.scrollsToTop = false
        if self.viewWithTag(1721) == nil {
            self.loadMoreControl.addTarget(self, action: #selector(self.loadMore), for: UIControlEvents.valueChanged)
            self.loadMoreControl.tag = 1721
            self.addSubview(self.loadMoreControl)
        }
        let layout = self.collectionViewLayout as? UICollectionViewFlowLayout
        layout?.sectionHeadersPinToVisibleBounds = true
        layout?.sectionFootersPinToVisibleBounds = true
        self.decelerationRate = UIScrollViewDecelerationRateNormal
        
        
    }
    
    open func registerCell(){
        self.register(UINib(nibName: "QCellTypingLeft",bundle: Qiscus.bundle), forCellWithReuseIdentifier: "cellTypingLeft")
        self.register(UINib(nibName: "QChatEmptyFooter",bundle: Qiscus.bundle), forSupplementaryViewOfKind: UICollectionElementKindSectionFooter, withReuseIdentifier: "emptyFooter")
        self.register(UINib(nibName: "QChatEmptyHeaderCell",bundle: Qiscus.bundle), forSupplementaryViewOfKind: UICollectionElementKindSectionHeader, withReuseIdentifier: "emptyHeader")
        self.register(UINib(nibName: "QChatHeaderCell",bundle: Qiscus.bundle), forSupplementaryViewOfKind: UICollectionElementKindSectionHeader, withReuseIdentifier: "cellHeader")
        self.register(UINib(nibName: "QChatFooterLeft",bundle: Qiscus.bundle), forSupplementaryViewOfKind: UICollectionElementKindSectionFooter, withReuseIdentifier: "cellFooterLeft")
        self.register(UINib(nibName: "QChatFooterRight",bundle: Qiscus.bundle), forSupplementaryViewOfKind: UICollectionElementKindSectionFooter, withReuseIdentifier: "cellFooterRight")
        self.register(UINib(nibName: "QCellSystem",bundle: Qiscus.bundle), forCellWithReuseIdentifier: "cellSystem")
        self.register(UINib(nibName: "QCellDocLeft",bundle: Qiscus.bundle), forCellWithReuseIdentifier: "cellDocLeft")
        self.register(UINib(nibName: "QCellDocRight",bundle: Qiscus.bundle), forCellWithReuseIdentifier: "cellDocRight")
        self.register(UINib(nibName: "QCellCardLeft",bundle: Qiscus.bundle), forCellWithReuseIdentifier: "cellCardLeft")
        self.register(UINib(nibName: "QCellCardRight",bundle: Qiscus.bundle), forCellWithReuseIdentifier: "cellCardRight")
        self.register(UINib(nibName: "QCellTextLeft",bundle: Qiscus.bundle), forCellWithReuseIdentifier: "cellTextLeft")
        self.register(UINib(nibName: "QCellPostbackLeft",bundle: Qiscus.bundle), forCellWithReuseIdentifier: "cellPostbackLeft")
        self.register(UINib(nibName: "QCellTextRight",bundle: Qiscus.bundle), forCellWithReuseIdentifier: "cellTextRight")
        self.register(UINib(nibName: "QCellMediaLeft",bundle: Qiscus.bundle), forCellWithReuseIdentifier: "cellMediaLeft")
        self.register(UINib(nibName: "QCellMediaRight",bundle: Qiscus.bundle), forCellWithReuseIdentifier: "cellMediaRight")
        self.register(UINib(nibName: "QCellAudioLeft",bundle: Qiscus.bundle), forCellWithReuseIdentifier: "cellAudioLeft")
        self.register(UINib(nibName: "QCellAudioRight",bundle: Qiscus.bundle), forCellWithReuseIdentifier: "cellAudioRight")
        self.register(UINib(nibName: "QCellFileLeft",bundle: Qiscus.bundle), forCellWithReuseIdentifier: "cellFileLeft")
        self.register(UINib(nibName: "QCellFileRight",bundle: Qiscus.bundle), forCellWithReuseIdentifier: "cellFileRight")
        self.register(UINib(nibName: "QCellContactRight",bundle: Qiscus.bundle), forCellWithReuseIdentifier: "cellContactRight")
        self.register(UINib(nibName: "QCellContactLeft",bundle: Qiscus.bundle), forCellWithReuseIdentifier: "cellContactLeft")
        self.register(UINib(nibName: "QCellLocationRight",bundle: Qiscus.bundle), forCellWithReuseIdentifier: "cellLocationRight")
        self.register(UINib(nibName: "QCellLocationLeft",bundle: Qiscus.bundle), forCellWithReuseIdentifier: "cellLocationLeft")
        self.registerCustomCell?()
    }
    public func subscribeEvent(){
        let center: NotificationCenter = NotificationCenter.default

        center.addObserver(self, selector: #selector(QConversationCollectionView.commentDeleted(_:)), name: QiscusNotification.COMMENT_DELETE, object: nil)
        center.addObserver(self, selector: #selector(QConversationCollectionView.userTyping(_:)), name: QiscusNotification.USER_TYPING, object: nil)
        center.addObserver(self, selector: #selector(QConversationCollectionView.newCommentNotif(_:)), name: QiscusNotification.GOT_NEW_COMMENT, object: nil)
    }
    public func unsubscribeEvent(){
        let center: NotificationCenter = NotificationCenter.default
        center.removeObserver(self, name: QiscusNotification.COMMENT_DELETE, object: nil)
        center.removeObserver(self, name: QiscusNotification.USER_TYPING, object: nil)
        center.removeObserver(self, name: QiscusNotification.GOT_NEW_COMMENT, object: nil)
    }
    // MARK: - Event handler
    open func onDeleteComment(){
        self.reloadData()
    }
    open func gotNewComment(comment: QComment, room:QRoom) {
        let rid = room.id
        QiscusBackgroundThread.async {
            if let rts = QRoom.threadSaveRoom(withId: rid){
                var messages = rts.grouppedCommentsUID
                messages = self.checkHiddenMessage(messages: messages)
                
                DispatchQueue.main.async {
                    self.messagesId = messages
                    self.reloadData()
                    if comment.senderEmail == QiscusMe.shared.email || self.isLastRowVisible {
                        self.layoutIfNeeded()
                        self.scrollToBottom(true)
                    }
                }
            }
        }
    }
    open func userTypingChanged(user: QUser, typing:Bool){
        self.processingTyping = true
        if user.isInvalidated {return}
        if !typing {
            if self.typingUsers[user.email] != nil {
                self.typingUsers[user.email] = nil
                self.reloadData()
                if self.isLastRowVisible{
                    scrollToBottom()
                }
            }
            if let timer = self.typingUserTimer[user.email] {
                timer.invalidate()
            }
        }else{
            if self.typingUsers[user.email] == nil {
                self.typingUsers[user.email] = user
                if let timer = self.typingUserTimer[user.email] {
                    timer.invalidate()
                }
                self.typingUserTimer[user.email] = Timer.scheduledTimer(timeInterval: 3.0, target: self, selector: #selector(QConversationCollectionView.publishStopTyping(timer:)), userInfo: user, repeats: false)
                self.reloadData()
                if self.isLastRowVisible{
                    scrollToBottom()
                }
            }else{
                if let timer = self.typingUserTimer[user.email] {
                    timer.invalidate()
                }
                self.typingUserTimer[user.email] = Timer.scheduledTimer(timeInterval: 3.0, target: self, selector: #selector(QConversationCollectionView.publishStopTyping(timer:)), userInfo: user, repeats: false)
            }
        }
        self.processingTyping = false
    }
    
    
    // MARK: - Notification Listener
    @objc private func userTyping(_ notification: Notification){
        if let userInfo = notification.userInfo {
            let user = userInfo["user"] as! QUser
            let typing = userInfo["typing"] as! Bool
            let room = userInfo["room"] as! QRoom
            if room.isInvalidated || user.isInvalidated {
                return
            }
            if let currentRoom = self.room {
                if currentRoom.isInvalidated { return }
                if currentRoom.id == room.id {
                    if !processingTyping{
                        self.userTypingChanged(user: user, typing: typing)
                    }
                }
            }
        }
    }
    @objc private func newCommentNotif(_ notification: Notification){
        if let userInfo = notification.userInfo {
            let comment = userInfo["comment"] as! QComment
            let room = userInfo["room"] as! QRoom
            if room.isInvalidated { return }
            if let currentRoom = self.room {
                if !currentRoom.isInvalidated {
                    if currentRoom.id == comment.roomId {
                        self.gotNewComment(comment: comment, room: room)
                    }
                }
            }
        }
    }
    
    @objc private func commentDeleted(_ notification: Notification) {
        if let userInfo = notification.userInfo {
            let room = userInfo["room"] as! QRoom
            
            if let currentRoom = self.room {
                if !currentRoom.isInvalidated && !room.isInvalidated{
                    if currentRoom.id == room.id {
                        self.onDeleteComment()
                    }
                }
            }
        }
    }
    
    // MARK: - Internal Method
    @objc private func publishStopTyping(timer:Timer){
        if let user = timer.userInfo as? QUser {
            if let room = self.room {
                QiscusNotification.publish(userTyping: user, room: room, typing: false )
            }
        }
    }
    
    // MARK: public Method
    func scrollToBottom(_ animated:Bool = false){
        if self.room != nil {
            if self.messagesId.count > 0 {
                let lastSection = self.numberOfSections - 1
                let lastItem = self.numberOfItems(inSection: lastSection) - 1
                
                if lastSection >= 0 && lastItem >= 0 {
                    let indexPath = IndexPath(item: lastItem, section: lastSection)
                    self.layoutIfNeeded()
                    self.scrollToItem(at: indexPath, at: .bottom, animated: animated)
                }
            }
        }
    }
    
    open func cellHeightForComment (comment:QComment, defaultHeight height:CGFloat, firstInSection first:Bool)->CGFloat{
        var retHeight = height
        
        switch comment.type {
        case .card, .contact    : break
        case .video, .image     :
            if retHeight > 0 {
                retHeight += 151 ;
            }else{
                retHeight = 140
            }
            break
        case .audio             : retHeight = 83 ; break
        case .file              : retHeight = 67  ; break
        case .reply             : retHeight += 88 ; break
        case .system            : retHeight += 46 ; break
        case .text              : retHeight += 15 ; break
        case .document          : retHeight += 7; break
        default                 : retHeight += 20 ; break
        }
        
        if (comment.type != .system && first) {
            var showUserName = true
            if let user = comment.sender {
                if let hidden = self.configDelegate?.configDelegate?(hideUserNameLabel: self, forUser: user){
                    showUserName = !hidden
                }
            }
            
            if showUserName {
                retHeight += 20
            }
        }
        return retHeight
    }
    
    func loadMore(){
        if let room = self.room {
            let id = room.id
            self.loadMoreComment(roomId: id)
        }
    }
    func loadMoreComment(roomId:String){
        QiscusBackgroundThread.async {
            if self.loadingMore { return }
            self.loadingMore = true
            if let r = QRoom.threadSaveRoom(withId: roomId){
                if r.canLoadMore{
                    r.loadMore()
                }else{
                    self.loadingMore = false
                    DispatchQueue.main.async {
                        self.loadMoreControl.endRefreshing()
                        self.loadMoreControl.removeFromSuperview()
                    }
                }
            }else{
                self.loadingMore = false
                DispatchQueue.main.async {
                    self.loadMoreControl.endRefreshing()
                }
            }
        }
    }
    func scrollToComment(comment:QComment){
        if let room = self.room {
            let roomId = room.id
            let uniqueId = comment.uniqueId
            QiscusBackgroundThread.async {
                if let rts = QRoom.threadSaveRoom(withId: roomId){
                    var section = 0
                    var found = false
                    for group in rts.grouppedCommentsUID{
                        var item = 0
                        if group.contains("\(uniqueId)"){
                            for id in group {
                                if id == uniqueId {
                                    found = true
                                    break
                                }else{
                                    item += 1
                                }
                            }
                        }
                        if found {
                            break
                        }else{
                            section += 1
                        }
                        self.targetIndexPath = IndexPath(item: item, section: section)
                        DispatchQueue.main.async {
                            self.layoutIfNeeded()
                            self.scrollToItem(at: self.targetIndexPath!, at: .top, animated: true)
                        }
                    }
                }
            }
        }
    }
    public func refreshData(){
        if let room = self.room {
            let rid = room.id
            QiscusBackgroundThread.async {
                if let rts = QRoom.threadSaveRoom(withId: rid){
                    var messages = rts.grouppedCommentsUID
                    messages = self.checkHiddenMessage(messages: messages)
                    DispatchQueue.main.async {
                        self.messagesId = messages
                        self.reloadData()
                    }
                }
            }
        }
    }
    internal func checkMessagePos(inGroup group:[String]){
        var item = 0
        for i in group {
            var position = QCellPosition.middle
            if group.count == 1 {
                position = .single
            }else{
                if item == 0 {
                    position = .first
                }else if item == group.count - 1 {
                    position = .last
                }
            }
            if let comment = QComment.threadSaveComment(withUniqueId: i){
                comment.updateCellPos(cellPos: position)
            }
            item += 1
        }
    }
    internal func checkHiddenMessage(messages:[[String]])->[[String]]{
        var retVal = messages
        if let delegate = self.viewDelegate {
            var hiddenIndexPaths = [IndexPath]()
            var groupCheck = [Int]()
            var section = 0
            
            for s in retVal {
                var item = 0
                for i in s {
                    if let comment = QComment.threadSaveComment(withUniqueId: i){
                        if let val = delegate.viewDelegate?(view: self, hideCellWith: comment){
                            if val {
                                hiddenIndexPaths.append(IndexPath(item: item, section: section))
                                comment.read(check: false)
                                if !groupCheck.contains(section) {
                                    groupCheck.append(section)
                                }
                            }
                        }
                    }
                    item += 1
                }
                section += 1
            }
            
            for indexPath in hiddenIndexPaths.reversed(){
                retVal[indexPath.section].remove(at: indexPath.item)
            }
            
            for group in groupCheck.reversed(){
                if retVal[group].count == 0 {
                    retVal.remove(at: group)
                }
            }
            var newGroup = [[String]]()
            var prev:QComment?
            var s = 0
            for group in retVal {
                let first = QComment.threadSaveComment(withUniqueId: group.first!)!
                if prev == nil {
                    newGroup.append(group)
                    prev = first
                }else{
                    if prev!.date == first.date && prev!.senderEmail == first.senderEmail && first.type != .system {
                        for uid in group {
                            newGroup[s].append(uid)
                        }
                    }else{
                        s += 1
                        newGroup.append(group)
                        prev = first
                    }
                }
            }
            for group in newGroup {
                self.checkMessagePos(inGroup: group)
            }
            return newGroup
        }else{
            return retVal
        }
    }
    func loadData(){
        if let r = self.room {
            let rid = r.id
            QiscusBackgroundThread.async {
                if let rts = QRoom.threadSaveRoom(withId: rid){
                    rts.loadData(onSuccess: { (result) in
                        var messages = result.grouppedCommentsUID
                        messages = self.checkHiddenMessage(messages: messages)
                        DispatchQueue.main.async {
                            self.messagesId = messages
                            self.reloadData()
                        }
                    }, onError: { (error) in
                        Qiscus.printLog(text: "fail to load data on room")
                    })
                }
            }
        }
    }
}
