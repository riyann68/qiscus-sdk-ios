//
//  QChatFooterLeft.swift
//  QiscusSDK
//
//  Created by Ahmad Athaullah on 1/9/17.
//  Copyright © 2017 Ahmad Athaullah. All rights reserved.
//

import UIKit

class QChatFooterLeft: UICollectionReusableView {

    @IBOutlet weak var avatarImage: UIImageView!
    
    public var user:QUser?{
        didSet{
            if oldValue != nil {
                oldValue?.delegate = nil
            }
            if let sender = self.user{
                QUser.cache[sender.email] = sender
                sender.delegate = self
                let email = sender.email
                if let avatar = sender.cachedAvatar{
                    self.avatarImage.image = avatar
                }
                else {
                    QiscusBackgroundThread.async {
                        if let userData = QUser.getUser(email: email) {
                            if let avatar = userData.avatar {
                                let emailData = userData.email
                                DispatchQueue.main.async {
                                    if emailData == self.user?.email {
                                        self.avatarImage.image = avatar
                                        self.user?.cachedAvatar = avatar
                                    }
                                }
                            }else{
                                DispatchQueue.main.async {
                                    self.avatarImage.image = Qiscus.image(named: "avatar")
                                }
                                userData.downloadAvatar()
                            }
                        }else{
                            DispatchQueue.main.async {
                                self.avatarImage.image = Qiscus.image(named: "avatar")
                            }
                        }
                    }
                }
                
            }else{
                avatarImage.image = nil
            }
        }
    }
    
    
    override func awakeFromNib() {
        super.awakeFromNib()
        avatarImage.layer.cornerRadius = 19
        avatarImage.clipsToBounds = true
        avatarImage.contentMode = .scaleAspectFill
        self.isUserInteractionEnabled = false
        NotificationCenter.default.addObserver(self, selector: #selector(QChatFooterLeft.userAvatarChanged(_:)), name: QiscusNotification.USER_AVATAR_CHANGE, object: nil)
        self.layer.zPosition = 0
    }
    // MARK: - userAvatarChange Handler
    @objc private func userAvatarChanged(_ notification: Notification) {
        if let userInfo = notification.userInfo {
            if let currentUser = self.user {
                let userData = userInfo["user"] as! QUser
                if currentUser.isInvalidated || userData.isInvalidated {
                    return
                }
                if currentUser.email == userData.email {
                    let email = currentUser.email
                    QiscusBackgroundThread.async {
                        if let thisUser = QUser.getUser(email: email){
                            if let avatar = thisUser.avatar {
                                DispatchQueue.main.async {
                                    self.avatarImage.image = avatar
                                }
                            }else{
                                thisUser.downloadAvatar()
                            }
                        }
                    }
                }
            }
        }
    }
}

extension QChatFooterLeft:QUserDelegate{
    func user(didChangeAvatarURL avatarURL: String) {
        if let sender = self.user {
            sender.downloadAvatar()
        }
    }
}
