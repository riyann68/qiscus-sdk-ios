//
//  QCellDeletedLeft.swift
//  Qiscus
//
//  Created by Ahmad Athaullah on 13/02/18.
//  Copyright © 2018 Ahmad Athaullah. All rights reserved.
//

import UIKit

class QCellDeletedLeft: QChatCell  {
    let maxWidth:CGFloat = QiscusUIConfiguration.chatTextMaxWidth
    let minWidth:CGFloat = 80
    
    @IBOutlet weak var userNameLabel: UILabel!
    @IBOutlet weak var balloonView: UIImageView!
    @IBOutlet weak var view: UIView!
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var dateLabel: UILabel!
    
    @IBOutlet weak var balloonTopMargin: NSLayoutConstraint!
    @IBOutlet weak var cellHeight: NSLayoutConstraint!
    @IBOutlet weak var textViewWidth: NSLayoutConstraint!
    @IBOutlet weak var textViewHeight: NSLayoutConstraint!
    @IBOutlet weak var balloonWidth: NSLayoutConstraint!
    
    @IBOutlet weak var textTopMargin: NSLayoutConstraint!
    @IBOutlet weak var ballonHeight: NSLayoutConstraint!
    @IBOutlet weak var balloonLeftMargin: NSLayoutConstraint!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        textView.contentInset = UIEdgeInsets.zero
    }
    
    override func clearContext() {
        textView.layoutIfNeeded()
    }
    
    @objc func openLink(){
        self.delegate?.didTouchLink(onComment: self.comment!)
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
        
        var deletedText = QChatCell.defaultDeletedText()
        if let prefferedText = self.delegate?.deletedMessageText?(selfMessage: false){
            deletedText = prefferedText
        }
        
        let attributedText = NSMutableAttributedString(string: deletedText)
        
        let foregroundColorAttributeName = QiscusColorConfiguration.sharedInstance.leftBaloonTextColor
        
        let textAttribute:[NSAttributedStringKey: Any] = [
            NSAttributedStringKey.foregroundColor: foregroundColorAttributeName,
            NSAttributedStringKey.font: Qiscus.style.chatFont.italic()
        ]
        
        let allRange = (deletedText as NSString).range(of: deletedText)
        attributedText.addAttributes(textAttribute, range: allRange)
        
        self.balloonView.image = self.getBallon()
        
        self.ballonHeight.constant = 10
        self.textTopMargin.constant = 0
        self.textView.attributedText = attributedText
        
        let size = self.textView.sizeThatFits(CGSize(width: maxWidth, height: CGFloat.greatestFiniteMagnitude))

        self.textViewWidth.constant = size.width
        self.textViewHeight.constant = size.height
        
        self.userNameLabel.textAlignment = .left
        
        self.dateLabel.text = self.comment!.time.lowercased()
        self.balloonView.tintColor = QiscusColorConfiguration.sharedInstance.leftBaloonColor
        self.dateLabel.textColor = QiscusColorConfiguration.sharedInstance.leftBaloonTextColor
        
        if self.showUserName{
            if let sender = self.comment?.sender {
                self.userNameLabel.text = sender.fullname
            }else{
                self.userNameLabel.text = self.comment?.senderName
            }
            self.userNameLabel.isHidden = false
            self.balloonTopMargin.constant = 20
            self.cellHeight.constant = 20
        }else{
            self.userNameLabel.text = ""
            self.userNameLabel.isHidden = true
            self.balloonTopMargin.constant = 0
            self.cellHeight.constant = 0
        }
        
        self.textView.layoutIfNeeded()
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
