//
//  QCellContactLeft.swift
//  Example
//
//  Created by Ahmad Athaullah on 8/23/17.
//  Copyright © 2017 Ahmad Athaullah. All rights reserved.
//

import UIKit
import SwiftyJSON

class QCellContactLeft: QChatCell {

    @IBOutlet weak var userNameLabel: UILabel!
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var contactIcon: UIImageView!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var contactNameLabel: UILabel!
    @IBOutlet weak var separator: UIView!
    @IBOutlet weak var balloonView: UIImageView!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var balloonLeftMargin: NSLayoutConstraint!
    
    @IBOutlet weak var topMargin: NSLayoutConstraint!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.containerView.layer.cornerRadius = 10.0
        self.separator.backgroundColor = QiscusColorConfiguration.sharedInstance.leftBaloonColor
        self.balloonView.tintColor = QiscusColorConfiguration.sharedInstance.leftBaloonColor
    }
    override func commentChanged() {
        if hideAvatar {
            self.balloonLeftMargin.constant = 0
        }else{
            self.balloonLeftMargin.constant = 27
        }
        if let color = self.userNameColor {
            self.userNameLabel.textColor = color
        }
        let data = self.comment!.data
        let payloadJSON = JSON(parseJSON: data)
        
        self.contactNameLabel.text = payloadJSON["name"].stringValue
        
        self.descriptionLabel.text = payloadJSON["value"].stringValue
        
        self.balloonView.image = self.getBallon()
        
        if self.showUserName{
            if let sender = self.comment?.sender {
                self.userNameLabel.text = sender.fullname
            }else{
                self.userNameLabel.text = self.comment?.senderName
            }
            self.userNameLabel.isHidden = false
            self.topMargin.constant = 20
        }else{
            self.userNameLabel.text = ""
            self.userNameLabel.isHidden = true
            self.topMargin.constant = 0
        }
        self.dateLabel.textColor = QiscusColorConfiguration.sharedInstance.leftBaloonTextColor
        self.dateLabel.text = self.comment!.time.lowercased()
    }
    
    @IBAction func saveContact(_ sender: Any) {
        self.delegate?.didTapSaveContact(onComment: self.comment!)
    }
    public override func comment(didChangePosition comment:QComment, position: QCellPosition) {
        if comment.uniqueId == self.comment?.uniqueId {
            self.balloonView.image = self.getBallon()
        }
    }
    public override func updateUserName() {
        if let sender = self.comment?.sender {
            self.userNameLabel.text = sender.fullname
        }else{
            self.userNameLabel.text = self.comment?.senderName
        }
    }
}
