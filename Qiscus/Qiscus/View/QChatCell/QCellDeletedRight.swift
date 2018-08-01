//
//  QCellDeletedRight.swift
//  Qiscus
//
//  Created by Ahmad Athaullah on 15/02/18.
//  Copyright © 2018 Ahmad Athaullah. All rights reserved.
//

import UIKit

class QCellDeletedRight: QChatCell {

    let maxWidth:CGFloat = QiscusUIConfiguration.chatTextMaxWidth
    let minWidth:CGFloat = 80
    
    @IBOutlet weak var userNameLabel: UILabel!
    @IBOutlet weak var balloonView: UIImageView!
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var statusImage: UIImageView!
    
    @IBOutlet weak var cellHeight: NSLayoutConstraint!
    @IBOutlet weak var balloonTopMargin: NSLayoutConstraint!
    @IBOutlet weak var textViewHeight: NSLayoutConstraint!
    @IBOutlet weak var textViewWidth: NSLayoutConstraint!
    @IBOutlet weak var textTopMargin: NSLayoutConstraint!
    @IBOutlet weak var balloonHeight: NSLayoutConstraint!
    
    
    override func awakeFromNib() {
        super.awakeFromNib()
        textView.contentInset = UIEdgeInsets.zero
    }
    public override func commentChanged() {
        if let color = self.userNameColor {
            self.userNameLabel.textColor = color
        }
        //self.textView.comment = self.comment
        
        self.balloonView.image = self.getBallon()
        
        let textSize = self.comment!.textSize
        var textWidth = self.comment!.textSize.width
        
        if textWidth > self.minWidth {
            textWidth = textSize.width
        }else{
            textWidth = self.minWidth
        }

        self.balloonHeight.constant = 10
        self.textTopMargin.constant = 0
        
        var deletedText = QChatCell.defaultDeletedText(selfMessage: true)
        
        if let prefferedText = self.delegate?.deletedMessageText?(selfMessage: true){
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
        
        self.textView.attributedText = attributedText
        
        let size = self.textView.sizeThatFits(CGSize(width: maxWidth, height: CGFloat.greatestFiniteMagnitude))
        
        self.textViewWidth.constant = size.width
        self.textViewHeight.constant = size.height
        
        self.userNameLabel.textAlignment = .right
        
        self.balloonView.tintColor = QiscusColorConfiguration.sharedInstance.rightBaloonColor
        self.dateLabel.text = self.comment!.time.lowercased()
        self.dateLabel.textColor = QiscusColorConfiguration.sharedInstance.rightBaloonTextColor
        
        
        // first cell
        if self.showUserName{
            self.userNameLabel.text = "YOU".getLocalize()
            self.userNameLabel.isHidden = false
            self.balloonTopMargin.constant = 20
            self.cellHeight.constant = 20
        }else{
            self.userNameLabel.text = ""
            self.userNameLabel.isHidden = true
            self.balloonTopMargin.constant = 0
            self.cellHeight.constant = 0
        }
        
        dateLabel.text = self.comment!.time.lowercased()
        statusImage.image = Qiscus.image(named: "ic_deleted")?.withRenderingMode(.alwaysTemplate)
        
        self.textView.layoutIfNeeded()
    }
    
    override func clearContext() {
        textView.text = ""
        textView.font = UIFont.systemFont(ofSize: 14)
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
