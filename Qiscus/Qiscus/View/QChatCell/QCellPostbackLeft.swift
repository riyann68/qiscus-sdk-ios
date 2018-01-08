//
//  QCellPostbackLeft.swift
//  Example
//
//  Created by Ahmad Athaullah on 5/18/17.
//  Copyright © 2017 Ahmad Athaullah. All rights reserved.
//

import UIKit
import SwiftyJSON

class QCellPostbackLeft: QChatCell {
    let maxWidth:CGFloat = QiscusUIConfiguration.chatTextMaxWidth
    let minWidth:CGFloat = QiscusUIConfiguration.chatTextMaxWidth
    let buttonWidth:CGFloat = QiscusUIConfiguration.chatTextMaxWidth + 10
    
    
    @IBOutlet weak var userNameLabel: UILabel!
    @IBOutlet weak var balloonView: UIImageView!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var buttonsView: UIStackView!
    
    @IBOutlet weak var textViewHeight: NSLayoutConstraint!
    @IBOutlet weak var textViewWidth: NSLayoutConstraint!
    @IBOutlet weak var balloonTopMargin: NSLayoutConstraint!
    @IBOutlet weak var balloonWidth: NSLayoutConstraint!
    @IBOutlet weak var cellHeight: NSLayoutConstraint!
    @IBOutlet weak var balloonHeight: NSLayoutConstraint!
    @IBOutlet weak var textLeading: NSLayoutConstraint!
    @IBOutlet weak var textTopMargin: NSLayoutConstraint!
    @IBOutlet weak var buttonsViewHeight: NSLayoutConstraint!
    @IBOutlet weak var balloonLeftMargin: NSLayoutConstraint!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        textView.contentInset = UIEdgeInsets.zero
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
        self.textView.attributedText = self.comment?.attributedText
        self.textView.linkTextAttributes = self.linkTextAttributes
        balloonView.image = getBallon()
        let textSize = self.comment!.textSize
        var textWidth = textSize.width
        
        if textWidth > minWidth {
            textWidth = textSize.width
        }else{
            textWidth = minWidth
        }
        
        for view in buttonsView.subviews{
            view.removeFromSuperview()
        }
        
        textViewWidth.constant = textWidth
        textViewHeight.constant = textSize.height
        
        userNameLabel.textAlignment = .left
        
        dateLabel.text = self.comment!.time.lowercased()
        balloonView.tintColor = QiscusColorConfiguration.sharedInstance.leftBaloonColor
        dateLabel.textColor = QiscusColorConfiguration.sharedInstance.leftBaloonTextColor
        
        if self.showUserName{
            if let sender = self.comment?.sender {
                self.userNameLabel.text = sender.fullname
            }else{
                self.userNameLabel.text = self.comment?.senderName
            }
            userNameLabel.isHidden = false
            balloonTopMargin.constant = 20
            cellHeight.constant = 20
        }else{
            userNameLabel.text = ""
            userNameLabel.isHidden = true
            balloonTopMargin.constant = 0
            cellHeight.constant = 0
        }
        if self.comment!.type == .postback {
            var i = 0
            let buttonsPayload = JSON(parseJSON: self.comment!.data).arrayValue
            self.buttonsViewHeight.constant = CGFloat(buttonsPayload.count * 35)
            self.layoutIfNeeded()
            for buttonsData in buttonsPayload{
                let button = UIButton(frame: CGRect(x: 0, y: 0, width: self.buttonWidth, height: 32))
                button.backgroundColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.7)
                button.setTitle(buttonsData["label"].stringValue, for: .normal)
                button.setTitleColor(.black, for: .normal)
                button.tag = i
                button.addTarget(self, action:#selector(self.postback(sender:)), for: .touchUpInside)
                self.buttonsView.addArrangedSubview(button)
                i += 1
            }
        }else{
            let dataPayload = JSON(parseJSON: self.comment!.data)
            let paramData = dataPayload["params"]
            
            self.buttonsViewHeight.constant = CGFloat(35)
            self.layoutIfNeeded()
            
            let button = UIButton(frame: CGRect(x: 0, y: 0, width: self.buttonWidth, height: 32))
            button.backgroundColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.7)
            button.setTitle(paramData["button_text"].stringValue, for: .normal)
            button.setTitleColor(.black, for: .normal)
            button.tag = 2222
            button.addTarget(self, action:#selector(self.accountLinking(sender:)), for: .touchUpInside)
            
            self.buttonsView.addArrangedSubview(button)
        }
    }
    open override func setupCell() {
       
    }
    
    @objc func postback(sender:UIButton){
        let allData = JSON(parseJSON: self.comment!.data).arrayValue
        if allData.count > sender.tag {
            self.delegate?.didTapPostbackButton(onComment: self.comment!, index: sender.tag)
        }
    }
    
    @objc func accountLinking(sender:UIButton){
        self.delegate?.didTapAccountLinking(onComment: self.comment!)
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
