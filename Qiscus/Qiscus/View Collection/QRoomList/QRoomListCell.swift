//
//  QRoomListCell.swift
//  Example
//
//  Created by Ahmad Athaullah on 9/15/17.
//  Copyright © 2017 Ahmad Athaullah. All rights reserved.
//

import UIKit

open class QRoomListCell: UITableViewCell {
    
    public var searchText = ""{
        didSet{
            self.searchTextChanged()
        }
    }
    
    public var room:QRoom? {
        didSet{
            setupUI()
        }
    }

    override open func awakeFromNib() {
        super.awakeFromNib()
        let center: NotificationCenter = NotificationCenter.default
        center.addObserver(self, selector: #selector(QRoomListCell.userTyping(_:)), name: QiscusNotification.USER_TYPING, object: nil)
        center.addObserver(self, selector: #selector(QRoomListCell.newCommentNotif(_:)), name: QiscusNotification.GOT_NEW_COMMENT, object: nil)
        center.addObserver(self, selector: #selector(QRoomListCell.roomChangeNotif(_:)), name: QiscusNotification.ROOM_CHANGE, object: nil)
    }

    override open func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    open func setupUI(){}
    
    
    open func onUserTyping(user:QUser, typing:Bool){}
    
    open func onRoomChange(room: QRoom){
        self.room = room
    }
    
    open func gotNewComment(comment:QComment){
//        self.room = comment.room!
    }
    
    
    open func searchTextChanged(){}
    
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
            }
            if self.room?.id == room.id {
                self.onUserTyping(user: user, typing: typing)
            }
        }
    }
    @objc private func newCommentNotif(_ notification: Notification){
        if let userInfo = notification.userInfo {
            if let currentRoom = self.room {
                if currentRoom.isInvalidated { return }
                
                if let comment = userInfo["comment"] as? QComment{
                    if comment.isInvalidated { return }
                    if currentRoom.id == comment.roomId {
                        self.gotNewComment(comment: comment)
                    }
                }
            }
        }
    }
    
    @objc private func roomChangeNotif(_ notification: Notification){
        if let userInfo = notification.userInfo {
            if let room = userInfo["room"] as? QRoom {
                if let currentRoom = self.room {
                    if currentRoom.isInvalidated { return}
                }
                if !room.isInvalidated {
                    if let property = userInfo["property"] as? QRoomProperty {
                        switch property {
                        case .name:
                            self.roomDataChange()
                            break
                        case .avatar:
                            self.roomAvatarChange()
                            break
                        case .participant:
                            self.roomParticipantChange()
                            break
                        case .lastComment:
                            self.roomLastCommentChange()
                            break
                        case .unreadCount:
                            self.roomUnreadCountChange()
                            break
                        case .data:
                            self.roomDataChange()
                            break
                        }
                    }
                    if room.id == self.room?.id {
                        self.onRoomChange(room: room)
                    }
                }
            }
        }
    }
    open func roomNameChange(){}
    open func roomAvatarChange(){}
    open func roomParticipantChange(){}
    open func roomLastCommentChange(){}
    open func roomUnreadCountChange(){}
    open func roomDataChange(){}
}
