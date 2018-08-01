//
//  QConversationCollectionView+QRoomDelegate.swift
//  Extension for conversation view for roomDelegate
//  Qiscus
//
//  Created by Ahmad Athaullah on 16/12/17.
//  Copyright © 2017 Ahmad Athaullah. All rights reserved.
//

import UIKit

extension QConversationCollectionView: QRoomDelegate {
    public func room(didChangeName room: QRoom) {
        if let r = self.room {
            if r.id == room.id {
                let name = room.name
                self.roomDelegate?.roomDelegate?(didChangeName: room, name: name)
            }
        }
    }
    public func room(didFinishSync room: QRoom) {
        if let r = self.room {
            if r.id == room.id {
                let rid = r.id
                var hardDelete = false
                if let softDelete = self.viewDelegate?.viewDelegate?(usingSoftDeleteOnView: self){
                    hardDelete = !softDelete
                }
                var predicate:NSPredicate?
                if hardDelete {
                    predicate = NSPredicate(format: "statusRaw != %d AND statusRaw != %d", QCommentStatus.deleted.rawValue, QCommentStatus.deleting.rawValue)
                }
                QiscusBackgroundThread.async {
                    if let rts = QRoom.threadSaveRoom(withId: rid){
                        var messages = rts.grouppedCommentsUID(filter: predicate)                        
                        messages = self.checkHiddenMessage(messages: messages)
                        DispatchQueue.main.async {
                            self.messagesId = messages
                            self.reloadData()
                            self.roomDelegate?.roomDelegate?(didFinishSync: r)
                        }
                    }
                }
            }
        }
    }
    public func room(didChangeAvatar room: QRoom) {
        if let r = self.room {
            if r.id == room.id {
                let roomId = r.id
                let roomName = r.name
                QiscusBackgroundThread.async {
                    if let rts = QRoom.threadSaveRoom(withId: roomId){
                        rts.loadAvatar(onSuccess: { (avatar) in
                            DispatchQueue.main.async {
                                self.roomDelegate?.roomDelegate?(didChangeAvatar: r, avatar: avatar)
                            }
                        }, onError: { (error) in
                            Qiscus.printLog(text: "fail to load room avatar on room \(roomName)")
                        })
                    }
                }
            }
        }
    }
    
    public func room(didChangeUser room: QRoom, user: QUser) {
        if let r = self.room {
            if r.id == room.id {
                self.roomDelegate?.roomDelegate?(didChangeUser: r, user: user)
            }
        }
    }
    public func room(didChangeParticipant room: QRoom) {
        if let r = self.room {
            if r.id == room.id {
                self.roomDelegate?.roomDelegate?(didChangeParticipant: r)
            }
        }
    }
    
    public func room(gotNewComment comment: QComment) {
        Qiscus.printLog(text: "gotNewComment::")
    }
    
    public func room(didDeleteComment room:QRoom) {
        if let r = self.room {
            if r.id == room.id {
                let rid = r.id
                var hardDelete = false
                if let softDelete = self.viewDelegate?.viewDelegate?(usingSoftDeleteOnView: self){
                    hardDelete = !softDelete
                }
                var predicate:NSPredicate?
                if hardDelete {
                    predicate = NSPredicate(format: "statusRaw != %d AND statusRaw != %d", QCommentStatus.deleted.rawValue, QCommentStatus.deleting.rawValue)
                }
                QiscusBackgroundThread.async {
                    if let rts = QRoom.threadSaveRoom(withId: rid){
                        var messages = rts.grouppedCommentsUID(filter: predicate)                        
                        messages = self.checkHiddenMessage(messages: messages)
                        DispatchQueue.main.async {
                            self.messagesId = messages
                            self.reloadData()
                        }
                    }
                }
            }
        }
    }
    
    public func room(didFinishLoadMore inRoom: QRoom, success: Bool, gotNewComment: Bool) {
        if let r = self.room {
            if r.id == inRoom.id {
                self.loadMoreControl.endRefreshing()
                if success && gotNewComment {
                    let rid = r.id
                    let contentHeight = self.contentSize.height
                    let offsetY = self.contentOffset.y
                    let bottomOffset = contentHeight - offsetY
                    self.refreshData(withCompletion: {
                        DispatchQueue.main.async {
                            CATransaction.begin()
                            CATransaction.setDisableActions(true)
                            self.reloadData()
                            self.layoutIfNeeded()
                            self.contentOffset = CGPoint(x: 0, y: self.contentSize.height - bottomOffset)
                            CATransaction.commit()
                            self.loadMoreControl.endRefreshing()
                            
                            if !r.canLoadMore {
                                self.loadMoreControl.removeFromSuperview()
                            }
                        }
                        self.loadingMore = false
                    })
                }else{
                    self.loadMoreControl.endRefreshing()
                     self.loadingMore = false
                }
            }else{
                self.loadMoreControl.endRefreshing()
                 self.loadingMore = false
            }
        }else{
            self.loadMoreControl.endRefreshing()
            self.loadingMore = false
        }
    }
    public func room(didChangeUnread inRoom:QRoom) {
        if let r = self.room {
            if r.id == inRoom.id {
                self.roomDelegate?.roomDelegate?(didChangeUnread: r, unreadCount: r.unreadCount)
            }
        }
    }
}
