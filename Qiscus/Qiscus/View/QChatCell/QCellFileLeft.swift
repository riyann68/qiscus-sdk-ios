//
//  QCellFileLeft.swift
//  QiscusSDK
//
//  Created by Ahmad Athaullah on 1/6/17.
//  Copyright © 2017 Ahmad Athaullah. All rights reserved.
//

import UIKit

class QCellFileLeft: QChatCell {

    @IBOutlet weak var userNameLabel: UILabel!
    @IBOutlet weak var balloonView: UIImageView!
    @IBOutlet weak var fileContainer: UIView!
    @IBOutlet weak var fileIcon: UIImageView!
    @IBOutlet weak var fileNameLabel: UILabel!
    @IBOutlet weak var fileTypeLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    
    @IBOutlet weak var balloonWidth: NSLayoutConstraint!
    @IBOutlet weak var topMargin: NSLayoutConstraint!
    @IBOutlet weak var cellHeight: NSLayoutConstraint!
    @IBOutlet weak var balloonLeftMargin: NSLayoutConstraint!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        fileContainer.layer.cornerRadius = 10
        fileIcon.image = Qiscus.image(named: "ic_file")?.withRenderingMode(.alwaysTemplate)
        fileIcon.contentMode = .scaleAspectFit
    }
    public override func commentChanged() {
        if hideAvatar {
            self.balloonLeftMargin.constant = 0
        }else{
            self.balloonLeftMargin.constant = 27
        }
        if let color = self.userNameColor {
            self.userNameLabel.textColor = color
        }
        userNameLabel.isHidden = true
        topMargin.constant = 0
        cellHeight.constant = 0
        balloonView.image = getBallon()
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(QChatCell.showFile))
        fileContainer.addGestureRecognizer(tapRecognizer)
        
        if self.showUserName{
            if let sender = self.comment?.sender {
                self.userNameLabel.text = sender.fullname
            }else{
                self.userNameLabel.text = self.comment?.senderName
            }
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
        
        balloonView.tintColor = QiscusColorConfiguration.sharedInstance.leftBaloonColor
        dateLabel.textColor = QiscusColorConfiguration.sharedInstance.leftBaloonTextColor
        fileIcon.tintColor = QiscusColorConfiguration.sharedInstance.leftBaloonColor
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
