//
//  QCellTypingLeft.swift
//  Qiscus
//
//  Created by Ahmad Athaullah on 24/11/17.
//  Copyright © 2017 Ahmad Athaullah. All rights reserved.
//

import UIKit

class QCellTypingLeft: UICollectionViewCell {
    
    var users = [String:QUser](){
        didSet{
            setup()
        }
    }
    var hideAvatar = false
    var avatarViews = [UIImageView]()
    var onSetup:Bool = false
    
    @IBOutlet weak var typingAnimation: UIImageView!
    @IBOutlet weak var typingAddition: UILabel!
    @IBOutlet weak var avatarArea: UIView!
    @IBOutlet weak var balloonView: UIImageView!
    
    @IBOutlet weak var avatarAreaWidth: NSLayoutConstraint!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        let edgeInset = UIEdgeInsetsMake(13, 28, 13, 13)
        let balloonImage = Qiscus.style.assets.leftBallonLast?.resizableImage(withCapInsets: edgeInset, resizingMode: .stretch).withRenderingMode(.alwaysTemplate)
        
        self.balloonView.image = balloonImage
        self.balloonView.tintColor = QiscusColorConfiguration.sharedInstance.leftBaloonColor
        self.avatarArea.clipsToBounds = true
        NotificationCenter.default.addObserver(self, selector: #selector(QCellTypingLeft.userAvatarChanged(_:)), name: QiscusNotification.USER_AVATAR_CHANGE, object: nil)
        
        self.typingAddition.layer.cornerRadius = 19.0
        self.typingAddition.clipsToBounds = true
        self.typingAddition.isHidden = true
        
        
    }
    func setup(){
        if !onSetup {
            onSetup = true
            if self.hideAvatar {
                self.avatarAreaWidth.constant = 10
            }else{
                var count = self.avatarViews.count - 1
                
                var previewedUser = [QUser]()
                
                for imageView in self.avatarViews.reversed() {
                    imageView.removeFromSuperview()
                    self.avatarViews.remove(at: count)
                    count -= 1
                }
                var i = 0
                var maxPreview = 3
                if self.users.count > 3 {
                    maxPreview = 2
                }
                for (_,user) in self.users {
                    if i < maxPreview {
                        previewedUser.append(user)
                    }else{
                        break
                    }
                    i += 1
                }
                var areaWidth = (CGFloat(previewedUser.count) * 38.0) + (CGFloat(previewedUser.count - 1) * 2.0)
                i = 0
                for user in previewedUser {
                    var x = CGFloat(i) * 38.0
                    if i > 0 {
                        x += 2.0
                    }
                    let frame = CGRect(x: x, y: 0, width: 38, height: 38)
                    let avatarView = UIImageView(frame: frame)
                    avatarView.layer.cornerRadius = 19.0
                    avatarView.clipsToBounds = true
                    avatarView.image = Qiscus.image(named: "avatar")
                    avatarView.tag = i
                    self.avatarArea.addSubview(avatarView)
                    self.avatarViews.append(avatarView)
                    i += 1
                    
                    if let avatar = user.avatar {
                        avatarView.image = avatar
                    }else{
                        user.downloadAvatar()
                    }
                }
                if self.users.count > 3 {
                    let additionUserCount = self.users.count - 2
                    var additionText = "+\(additionUserCount)"
                    if additionUserCount > 9 {
                        additionText = "9+"
                    }
                    
                    areaWidth += 40.0
                    self.typingAddition.isHidden = false
                    self.typingAddition.text = additionText
                }else{
                    self.typingAddition.isHidden = true
                }
                self.avatarAreaWidth.constant = areaWidth
            }
            
            self.layoutIfNeeded()
            self.typingAnimation.loadQiscusGif(name: "typing")
            onSetup = false
        }
    }
    
    // MARK: - userAvatarChange Handler
    @objc private func userAvatarChanged(_ notification: Notification) {
        if users.count > 0 {
            if let userInfo = notification.userInfo {
                let userData = userInfo["user"] as! QUser
                
                if self.users[userData.email] != nil {
                    setup()
                }
            }
        }
    }
}
