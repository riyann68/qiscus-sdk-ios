//
//  QCellContactRight.swift
//  Example
//
//  Created by Ahmad Athaullah on 8/10/17.
//  Copyright © 2017 Ahmad Athaullah. All rights reserved.
//

import UIKit
import SwiftyJSON

class QCellContactRight: QChatCell {
    @IBOutlet weak var topMargin: NSLayoutConstraint!

    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var contactNameLabel: UILabel!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var balloonView: UIImageView!
    @IBOutlet weak var contactIcon: UIImageView!
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var separator: UIView!
    @IBOutlet weak var userNameLabel: UILabel!
    @IBOutlet weak var statusImage: UIImageView!
    @IBOutlet weak var dateLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.containerView.layer.cornerRadius = 10.0
        self.separator.backgroundColor = QiscusColorConfiguration.sharedInstance.rightBaloonColor
        self.balloonView.tintColor = QiscusColorConfiguration.sharedInstance.rightBaloonColor
    }
    override func commentChanged() {
        if let color = self.userNameColor {
            self.userNameLabel.textColor = color
        }
        let data = self.comment!.data
        let payloadJSON = JSON(parseJSON: data)
        
        self.contactNameLabel.text = payloadJSON["name"].stringValue
        
        self.descriptionLabel.text = payloadJSON["value"].stringValue
        
        self.balloonView.image = self.getBallon()
        
        if self.showUserName{
            self.userNameLabel.text = "YOU".getLocalize()
            self.userNameLabel.isHidden = false
            self.topMargin.constant = 20
        }else{
            self.userNameLabel.text = ""
            self.userNameLabel.isHidden = true
            self.topMargin.constant = 0
        }
        self.updateStatus(toStatus: self.comment!.status)
    }
    @IBAction func saveContact(_ sender: Any) {
        self.delegate?.didTapSaveContact(onComment: self.comment!)
    }
    public override func updateStatus(toStatus status:QCommentStatus){
        super.updateStatus(toStatus: status)
        dateLabel.textColor = QiscusColorConfiguration.sharedInstance.rightBaloonTextColor
        dateLabel.text = self.comment!.time.lowercased()
        statusImage.isHidden = false
        statusImage.tintColor = QiscusColorConfiguration.sharedInstance.rightBaloonTextColor
        statusImage.isHidden = false
        statusImage.tintColor = QiscusColorConfiguration.sharedInstance.rightBaloonTextColor
        
        switch status {
        case .deleted:
            dateLabel.text = self.comment!.time.lowercased()
            statusImage.image = Qiscus.image(named: "ic_deleted")?.withRenderingMode(.alwaysTemplate)
            break
        case .deleting, .deletePending:
            dateLabel.text = QiscusTextConfiguration.sharedInstance.deletingText
            if status == .deletePending {
                dateLabel.text = self.comment!.time.lowercased()
            }
            statusImage.image = Qiscus.image(named: "ic_deleting")?.withRenderingMode(.alwaysTemplate)
            break;
        case .sending, .pending:
            dateLabel.text = QiscusTextConfiguration.sharedInstance.sendingText
            if status == .pending {
                dateLabel.text = self.comment!.time.lowercased()
            }
            statusImage.image = Qiscus.image(named: "ic_info_time")?.withRenderingMode(.alwaysTemplate)
            break
        case .sent:
            statusImage.image = Qiscus.image(named: "ic_sending")?.withRenderingMode(.alwaysTemplate)
            break
        case .delivered:
            statusImage.image = Qiscus.image(named: "ic_read")?.withRenderingMode(.alwaysTemplate)
            break
        case .read:
            statusImage.tintColor = Qiscus.style.color.readMessageColor
            statusImage.image = Qiscus.image(named: "ic_read")?.withRenderingMode(.alwaysTemplate)
            break
        case .failed:
            dateLabel.text = QiscusTextConfiguration.sharedInstance.failedText
            dateLabel.textColor = QiscusColorConfiguration.sharedInstance.failToSendColor
            statusImage.image = Qiscus.image(named: "ic_warning")?.withRenderingMode(.alwaysTemplate)
            statusImage.tintColor = QiscusColorConfiguration.sharedInstance.failToSendColor
            break
        default: break
        }
    }
    public override func comment(didChangePosition comment:QComment, position: QCellPosition) {
        if self.comment?.uniqueId == comment.uniqueId {
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
