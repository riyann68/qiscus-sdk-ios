//
//  QVCCollectionView.swift
//  Example
//
//  Created by Ahmad Athaullah on 5/16/17.
//  Copyright © 2017 Ahmad Athaullah. All rights reserved.
//

import UIKit

// MARK: - CollectionView dataSource, delegate, and delegateFlowLayout
extension QiscusChatVC: QConversationViewConfigurationDelegate {
    public func configDelegate(userNameLabelColor collectionView:QConversationCollectionView, forUser user:QUser)->UIColor?{
        if let config = self.configDelegate{
            if let color = config.chatVCConfigDelegate?(userNameLabelColor: self, forUser: user){
                return color
            }
        }
        return nil
    }
    public func configDelegate(hideLeftAvatarOn collectionView:QConversationCollectionView)->Bool{
        if let config = self.configDelegate{
            if let hidden = config.chatVCConfigDelegate?(hideLeftAvatarOn: self){
                return hidden
            }
        }
        return false
    }
    public func configDelegate(hideUserNameLabel collectionView:QConversationCollectionView, forUser user:QUser)->Bool{
        if let config = self.configDelegate{
            if let hideLabel = config.chatVCConfigDelegate?(hideUserNameLabel: self, forUser: user){
                return hideLabel
            }
        }
        return false
    }
}
extension QiscusChatVC: QConversationViewDelegate {
    public func viewDelegate(enableInfoAction view: QConversationCollectionView) -> Bool {
        if let delegate = self.delegate {
            return delegate.chatVC(enableInfoAction: self)
        }else{
            return false
        }
    }
    public func viewDelegate(enableForwardAction view: QConversationCollectionView) -> Bool {
        if let delegate = self.delegate{
            return delegate.chatVC(enableForwardAction: self)
        }
        return false
    }
    public func viewDelegate(view:QConversationCollectionView, cellForComment comment:QComment)->QChatCell?{
        if let delegate = self.delegate {
            if let cell = delegate.chatVC?(viewController: self, cellForComment: comment){
                return cell
            }
        }
        return nil
    }
    public func viewDelegate(view:QConversationCollectionView, heightForComment comment:QComment)->QChatCellHeight?{
        if let delegate = self.delegate {
            if let height = delegate.chatVC?(viewController: self, heightForComment: comment){
                return height
            }
        }
        return nil
    }
    public func viewDelegate(view:QConversationCollectionView, willDisplayCellForComment comment:QComment, cell:QChatCell, indexPath: IndexPath){
 
    }
    public func viewDelegate(view:QConversationCollectionView, didEndDisplayingCellForComment comment:QComment, cell:QChatCell, indexPath: IndexPath){
        
    }
    public func viewDelegate(didEndDisplayingLastMessage view:QConversationCollectionView, comment:QComment){
        self.bottomButton.isHidden = false
        
        if self.chatRoom?.unreadCount == 0 {
            self.unreadIndicator.isHidden = true
        }else{
            self.unreadIndicator.isHidden = true
            var unreadText = ""
            if self.chatRoom!.unreadCount > 0 {
                if self.chatRoom!.unreadCount > 99 {
                    unreadText = "99+"
                }else{
                    unreadText = "\(self.chatRoom!.unreadCount)"
                }
            }
            self.unreadIndicator.text = unreadText
            self.unreadIndicator.isHidden = self.bottomButton.isHidden
        }
    }
    open func viewDelegate(willDisplayLastMessage view:QConversationCollectionView, comment:QComment){
        self.bottomButton.isHidden = true
        if self.isPresence && !self.prefetch {
            if let room = self.chatRoom {
                let rid = room.id
                QiscusBackgroundThread.async {
                    if let rts = QRoom.threadSaveRoom(withId: rid){
                        rts.readAll()
                    }
                }
            }
        }
    }
    public func viewDelegate(view:QConversationCollectionView, hideCellWith comment:QComment)->Bool{
        if let delegate = self.delegate {
            if let hide = delegate.chatVC?(viewController: self, hideCellWith: comment) {
                return hide
            }
        }
        return false
    }
    public func viewDelegate(view: QConversationCollectionView, didLoadData messages: [[String]]) {
        if messages.count > 0 {
            let delay = 0.8 * Double(NSEC_PER_SEC)
            let time = DispatchTime.now() + delay / Double(NSEC_PER_SEC)
            DispatchQueue.main.asyncAfter(deadline: time, execute: {
                self.welcomeView.isHidden = true
                self.collectionView.isHidden = false
                self.dismissLoading()
                if self.firstLoad {
                    self.collectionView.scrollToBottom()
                    self.firstLoad = false
                }
                if !self.prefetch && self.isPresence{
                    if let room = self.chatRoom {
                        let rid = room.id
                        QiscusBackgroundThread.async {
                            if let rts = QRoom.threadSaveRoom(withId: rid){
                                rts.readAll()
                            }
                        }
                    }
                }
            })
        }else{
            self.welcomeView.isHidden = false
            self.collectionView.isHidden = true
            self.dismissLoading()
        }
    }
}

