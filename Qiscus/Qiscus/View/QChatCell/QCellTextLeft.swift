//
//  QCellTextLeft.swift
//  QiscusSDK
//
//  Created by Ahmad Athaullah on 1/3/17.
//  Copyright © 2017 Ahmad Athaullah. All rights reserved.
//

import UIKit
import SwiftyJSON

class QCellTextLeft: QChatCell, UITextViewDelegate {
    let maxWidth:CGFloat = QiscusUIConfiguration.chatTextMaxWidth
    let minWidth:CGFloat = 80
    
    @IBOutlet weak var userNameLabel: UILabel!
    @IBOutlet weak var balloonView: UIImageView!
    @IBOutlet weak var view: UIView!
    @IBOutlet weak var textView: QTextView!
    @IBOutlet weak var dateLabel: UILabel!
    
    @IBOutlet weak var balloonTopMargin: NSLayoutConstraint!
    @IBOutlet weak var leftMargin: NSLayoutConstraint!
    @IBOutlet weak var cellHeight: NSLayoutConstraint!
    @IBOutlet weak var textLeading: NSLayoutConstraint!
    @IBOutlet weak var textViewWidth: NSLayoutConstraint!
    @IBOutlet weak var textViewHeight: NSLayoutConstraint!
    @IBOutlet weak var balloonWidth: NSLayoutConstraint!
    @IBOutlet weak var linkContainerWidth: NSLayoutConstraint!
    
    @IBOutlet weak var LinkContainer: UIView!
    @IBOutlet weak var linkDescription: UITextView!
    @IBOutlet weak var linkTitle: UILabel!
    @IBOutlet weak var linkImage: UIImageView!
    @IBOutlet weak var linkImageWidth: NSLayoutConstraint!
    
    @IBOutlet weak var linkHeight: NSLayoutConstraint!
    @IBOutlet weak var textTopMargin: NSLayoutConstraint!
    @IBOutlet weak var ballonHeight: NSLayoutConstraint!
    @IBOutlet weak var cellWidth: NSLayoutConstraint!
    @IBOutlet weak var balloonLeftMargin: NSLayoutConstraint!
    
    
    override func awakeFromNib() {
        super.awakeFromNib()
        textView.contentInset = UIEdgeInsets.zero
        textView.delegate = self
        
        LinkContainer.isHidden = true
        LinkContainer.layer.cornerRadius = 4
        LinkContainer.clipsToBounds = true
        linkContainerWidth.constant = self.maxWidth + 2
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(QCellTextLeft.openLink))
        LinkContainer.addGestureRecognizer(tapRecognizer)
        linkImage.clipsToBounds = true
    }
    
    open override func setupCell(){
        
    }
    override func clearContext() {
        textView.layoutIfNeeded()
        LinkContainer.isHidden = true
    }
    @objc func openLink(){
        self.delegate?.didTouchLink(onComment: self.comment!)
    }
    
    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange) -> Bool {
        return true
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
        self.textView.comment = self.comment
        
        self.balloonView.image = self.getBallon()
        
        let textSize = self.comment!.textSize
        var textWidth = self.comment!.textSize.width
        
        if textWidth > self.minWidth {
            textWidth = textSize.width
        }else{
            textWidth = self.minWidth
        }
        
        if self.comment!.type == .reply{
            let replyData = JSON(parseJSON: self.comment!.data)
            var text = replyData["replied_comment_message"].stringValue
            var replyType = self.comment!.replyType(message: text)
            
            if replyType == .text  {
                switch replyData["replied_comment_type"].stringValue {
                case "location":
                    replyType = .location
                    break
                case "contact_person":
                    replyType = .contact
                    break
                default:
                    break
                }
            }
            var username = replyData["replied_comment_sender_username"].stringValue
            let repliedEmail = replyData["replied_comment_sender_email"].stringValue
            if repliedEmail == Qiscus.client.email {
                username = "YOU".getLocalize()
            }else{
                if let user = QUser.user(withEmail: repliedEmail){
                    username = user.fullname
                }
            }
            switch replyType {
            case .text:
                self.linkImageWidth.constant = 0
                self.linkImage.isHidden = true
                break
            case .image, .video:
                self.linkImage.contentMode = .scaleAspectFill
                self.linkImage.image = Qiscus.image(named: "link")
                let filename = self.comment!.fileName(text: text)
                let url = self.comment!.getAttachmentURL(message: text)
                
                self.linkImageWidth.constant = 55
                self.linkImage.isHidden = false
                
                if let file = QFile.file(withURL: url){
                    if QFileManager.isFileExist(inLocalPath: file.localThumbPath){
                        self.linkImage.loadAsync(fromLocalPath: file.localThumbPath, onLoaded: { (image, _) in
                            self.linkImage.image = image
                        })
                    }else if QFileManager.isFileExist(inLocalPath: file.localMiniThumbPath){
                        self.linkImage.loadAsync(fromLocalPath: file.localMiniThumbPath, onLoaded: { (image, _) in
                            self.linkImage.image = image
                        })
                    }else{
                        self.linkImage.loadAsync(file.thumbURL, onLoaded: { (image, _) in
                            self.linkImage.image = image
                        })
                    }
                }else{
                    var thumbURL = url.replacingOccurrences(of: "/upload/", with: "/upload/w_30,c_scale/")
                    let thumbUrlArr = thumbURL.split(separator: ".")
                    
                    var newThumbURL = ""
                    var i = 0
                    for thumbComponent in thumbUrlArr{
                        if i == 0{
                            newThumbURL += String(thumbComponent)
                        }else if i < (thumbUrlArr.count - 1){
                            newThumbURL += ".\(String(thumbComponent))"
                        }else{
                            newThumbURL += ".png"
                        }
                        i += 1
                    }
                    thumbURL = newThumbURL
                    self.linkImage.loadAsync(thumbURL, onLoaded: { (image, _) in
                        self.linkImage.image = image
                    })
                }
                text = filename
                
                break
            case .document :
                self.linkImage.contentMode = .scaleAspectFill
                self.linkImage.image = nil
                let filename = self.comment!.fileName(text: text)
                let url = self.comment!.getAttachmentURL(message: text)
                
                self.linkImageWidth.constant = 55
                self.linkImage.isHidden = false
                text = filename
                if let file = QFile.file(withURL: url){
                    if QFileManager.isFileExist(inLocalPath: file.localThumbPath){
                        self.linkImage.loadAsync(fromLocalPath: file.localThumbPath, onLoaded: { (image, _) in
                            self.linkImage.image = image
                        })
                    }else if QFileManager.isFileExist(inLocalPath: file.localMiniThumbPath){
                        self.linkImage.loadAsync(fromLocalPath: file.localMiniThumbPath, onLoaded: { (image, _) in
                            self.linkImage.image = image
                        })
                    }else{
                        self.linkImage.loadAsync(file.thumbURL, onLoaded: { (image, _) in
                            self.linkImage.image = image
                        })
                    }
                    var description = "\(file.filename)\nPDF File"
                    if file.pages > 0 {
                        description = "\(description), \(file.pages) page"
                    }
                    if file.sizeString != "" {
                        description = "\(description), \(file.sizeString)"
                    }
                    text = description
                }
                break
            case .location :
                self.linkImage.contentMode = .scaleAspectFill
                self.linkImage.image = Qiscus.image(named: "map_ico")
                self.linkImageWidth.constant = 55
                self.linkImage.isHidden = false
                
                let payload = JSON(parseJSON: "\(replyData["replied_comment_payload"])")
                text = "\(payload["name"].stringValue) - \(payload["address"].stringValue)"
                break
            case .contact:
                self.linkImage.contentMode = .top
                self.linkImage.image = Qiscus.image(named: "contact")
                self.linkImageWidth.constant = 55
                self.linkImage.isHidden = false
                
                let payload = JSON(parseJSON: "\(replyData["replied_comment_payload"])")
                text = "\(payload["name"].stringValue) - \(payload["value"].stringValue)"
                break
            default:
                let filename = self.comment!.fileName(text: text)
                text = filename
                self.linkImageWidth.constant = 0
                self.linkImage.isHidden = true
                break
            }
            
            
            self.linkTitle.text = username
            self.linkDescription.text = text
            
            self.LinkContainer.isHidden = false
            self.ballonHeight.constant = 83
            self.textTopMargin.constant = 73
            self.linkHeight.constant = 65
            textWidth = self.maxWidth
        }else{
            self.linkTitle.text = ""
            self.linkDescription.text = ""
            self.linkImage.image = Qiscus.image(named: "link")
            self.LinkContainer.isHidden = true
            self.ballonHeight.constant = 10
            self.textTopMargin.constant = 0
        }
        
        
        var size = self.textView.sizeThatFits(CGSize(width: maxWidth, height: CGFloat.greatestFiniteMagnitude))
        if self.comment?.type == .postback && self.comment?.data != ""{
            let payload = JSON(parseJSON: self.comment!.data)
            
            if let buttonsPayload = payload.array {
                let heightAdd = CGFloat(35 * buttonsPayload.count)
                size.height += heightAdd
            }else{
                size.height += 35
            }
        }
        self.textViewWidth.constant = textWidth
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
