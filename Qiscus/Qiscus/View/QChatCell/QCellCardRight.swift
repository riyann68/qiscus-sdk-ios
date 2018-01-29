//
//  QCellCardRight.swift
//  Example
//
//  Created by Ahmad Athaullah on 8/1/17.
//  Copyright © 2017 Ahmad Athaullah. All rights reserved.
//

import UIKit
import SwiftyJSON

class QCellCardRight: QChatCell {

    @IBOutlet weak var buttonArea: UIStackView!
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var displayView: UIImageView!
    @IBOutlet weak var cardTitle: UILabel!
    @IBOutlet weak var cardDescription: UITextView!
    @IBOutlet weak var userNameLabel: UILabel!
    
    @IBOutlet weak var cardHeight: NSLayoutConstraint!
    @IBOutlet weak var buttonAreaHeight: NSLayoutConstraint!
    @IBOutlet weak var topMargin: NSLayoutConstraint!
    var buttons = [UIButton]()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.containerView.layer.cornerRadius = 10.0
        self.containerView.layer.borderWidth = 0.5
        self.containerView.layer.borderColor = UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1).cgColor
        self.containerView.clipsToBounds = true
        self.displayView.contentMode = .scaleAspectFill
        self.displayView.clipsToBounds = true
    }
    override func commentChanged() {
        if let color = self.userNameColor {
            self.userNameLabel.textColor = color
        }
        let data = self.comment!.data
        let payload = JSON(parseJSON: data)
        
        let title = payload["title"].stringValue
        let description = payload["description"].stringValue
        let imageURL = payload["image"].stringValue
        
        self.cardTitle.text = title
        self.displayView.loadAsync(imageURL, onLoaded: {(image, _) in
            self.displayView.image = image
        })
        self.cardDescription.text = description
        
        if self.showUserName{
            userNameLabel.isHidden = false
            topMargin.constant = 20
        }else{
            userNameLabel.isHidden = true
            topMargin.constant = 0
        }
        
        let buttonsData = payload["buttons"].arrayValue
        let buttonWidth = self.buttonArea.frame.size.width
        
        for currentButton in self.buttons {
            self.buttonArea.removeArrangedSubview(currentButton)
            currentButton.removeFromSuperview()
        }
        self.buttons = [UIButton]()
        var yPos = CGFloat(0)
        let titleColor = UIColor(red: 101/255, green: 119/255, blue: 183/255, alpha: 1)
        var i = 0
        for buttonData in buttonsData{
            let buttonFrame = CGRect(x: 0, y: yPos, width: buttonWidth, height: 45)
            let button = UIButton(frame: buttonFrame)
            button.setTitle(buttonData["label"].stringValue, for: .normal)
            button.tag = i
            
            let borderFrame = CGRect(x: 0, y: 0, width: buttonWidth, height: 0.5)
            let buttonBorder = UIView(frame: borderFrame)
            buttonBorder.backgroundColor = UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1)
            button.setTitleColor(titleColor, for: .normal)
            button.addSubview(buttonBorder)
            self.buttons.append(button)
            self.buttonArea.addArrangedSubview(button)
            button.addTarget(self, action: #selector(cardButtonTapped(_:)), for: .touchUpInside)
            
            yPos += 45
            i += 1
        }
        self.buttonAreaHeight.constant = yPos
        self.cardHeight.constant = 90 + yPos
        self.containerView.layoutIfNeeded()
    }
    @objc func cardButtonTapped(_ sender: UIButton) {
        let data = self.comment!.data
        let payload = JSON(parseJSON: data)
        let buttonsData = payload["buttons"].arrayValue
        if buttonsData.count > sender.tag {
            self.delegate?.didTapCardButton(onComment: self.comment!, index: sender.tag)
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
