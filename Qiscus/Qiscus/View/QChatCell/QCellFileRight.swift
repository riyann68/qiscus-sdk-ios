//
//  QCellFileRight.swift
//  QiscusSDK
//
//  Created by Ahmad Athaullah on 1/6/17.
//  Copyright © 2017 Ahmad Athaullah. All rights reserved.
//

import UIKit

class QCellFileRight: QChatCell {
    @IBOutlet weak var userNameLabel: UILabel!
    @IBOutlet weak var balloonView: UIImageView!
    @IBOutlet weak var fileContainer: UIView!
    @IBOutlet weak var fileTypeLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var statusImage: UIImageView!
    @IBOutlet weak var fileIcon: UIImageView!
    @IBOutlet weak var fileNameLabel: UILabel!

    @IBOutlet weak var balloonWidth: NSLayoutConstraint!
    @IBOutlet weak var cellHeight: NSLayoutConstraint!
    @IBOutlet weak var rightMargin: NSLayoutConstraint!
    @IBOutlet weak var topMargin: NSLayoutConstraint!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        fileContainer.layer.cornerRadius = 10
        fileIcon.image = Qiscus.image(named: "ic_file")?.withRenderingMode(.alwaysTemplate)
        fileIcon.contentMode = .scaleAspectFit
    }
    public override func commentChanged() {
        if let color = self.userNameColor {
            self.userNameLabel.textColor = color
        }
        userNameLabel.text = "YOU".getLocalize()
        userNameLabel.isHidden = true
        topMargin.constant = 0
        cellHeight.constant = 0
        balloonView.image = getBallon()
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(QChatCell.showFile))
        fileContainer.addGestureRecognizer(tapRecognizer)
        
        if self.showUserName{
            userNameLabel.isHidden = false
            topMargin.constant = 20
            cellHeight.constant = 20
        }
        
        if let file = self.comment!.file {
            fileNameLabel.text = file.filename
            if file.ext == "doc" || file.ext == "docx" || file.ext == "ppt" || file.ext == "pptx" || file.ext == "xls" || file.ext == "xlsx" || file.ext == "txt" {
                fileTypeLabel.text = "\(file.ext.uppercased()) File"
            }else{
                fileTypeLabel.text = "Unknown File"
            }
        }
        
        dateLabel.text = self.comment!.time.lowercased()
        
        balloonView.tintColor = QiscusColorConfiguration.sharedInstance.rightBaloonColor
        dateLabel.textColor = QiscusColorConfiguration.sharedInstance.rightBaloonTextColor
        fileIcon.tintColor = QiscusColorConfiguration.sharedInstance.rightBaloonColor
        updateStatus(toStatus: self.comment!.status)
        if self.comment!.isUploading {
            let uploadProgres = Int(self.comment!.progress * 100)
            let uploading = QiscusTextConfiguration.sharedInstance.uploadingText
            
            dateLabel.text = "\(uploading) \(QChatCellHelper.getFormattedStringFromInt(uploadProgres)) %"
        }
        self.updateStatus(toStatus: self.comment!.status)
    }
    public override func uploadingMedia() {
        if self.comment!.isUploading {
            let uploadProgres = Int(self.comment!.progress * 100)
            let uploading = QiscusTextConfiguration.sharedInstance.uploadingText
            
            dateLabel.text = "\(uploading) \(QChatCellHelper.getFormattedStringFromInt(uploadProgres)) %"
        }
    }
    public override func uploadFinished() {
        updateStatus(toStatus: self.comment!.status)
    }
    
    public override func updateStatus(toStatus status:QCommentStatus){
        super.updateStatus(toStatus: status)
        dateLabel.text = self.comment!.time.lowercased()
        dateLabel.textColor = QiscusColorConfiguration.sharedInstance.rightBaloonTextColor
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
    public override func updateUserName() {
        if let sender = self.comment?.sender {
            self.userNameLabel.text = sender.fullname
        }else{
            self.userNameLabel.text = self.comment?.senderName
        }
    }
    public override func comment(didChangePosition comment:QComment, position: QCellPosition) {
        if comment.uniqueId == self.comment?.uniqueId {
            self.balloonView.image = self.getBallon()
        }
    }
}
