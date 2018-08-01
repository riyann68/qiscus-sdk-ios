//
//  QCellTextRight.swift
//  QiscusSDK
//
//  Created by Ahmad Athaullah on 1/3/17.
//  Copyright © 2017 Ahmad Athaullah. All rights reserved.
//

import UIKit
import SwiftyJSON

class QCellTextRight: QChatCell {
    let maxWidth:CGFloat = QiscusUIConfiguration.chatTextMaxWidth
    let minWidth:CGFloat = 80
    
    @IBOutlet weak var userNameLabel: UILabel!
    @IBOutlet weak var balloonView: UIImageView!
    @IBOutlet weak var textView: QTextView!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var statusImage: UIImageView!
    
    //@IBOutlet weak var balloonWidth: NSLayoutConstraint!
    @IBOutlet weak var linkContainerWidth: NSLayoutConstraint!
    @IBOutlet weak var cellHeight: NSLayoutConstraint!
    //@IBOutlet weak var rightMargin: NSLayoutConstraint!
    @IBOutlet weak var balloonTopMargin: NSLayoutConstraint!
    //@IBOutlet weak var textTrailing: NSLayoutConstraint!
    //@IBOutlet weak var statusTrailing: NSLayoutConstraint!
    @IBOutlet weak var textViewHeight: NSLayoutConstraint!
    @IBOutlet weak var textViewWidth: NSLayoutConstraint!
    @IBOutlet weak var linkImageWidth: NSLayoutConstraint!

    @IBOutlet weak var LinkContainer: UIView!
    @IBOutlet weak var linkDescription: UITextView!
    @IBOutlet weak var linkTitle: UILabel!
    @IBOutlet weak var linkImage: UIImageView!
    
    @IBOutlet weak var linkHeight: NSLayoutConstraint!
    @IBOutlet weak var textTopMargin: NSLayoutConstraint!
    @IBOutlet weak var balloonHeight: NSLayoutConstraint!
    
    
    override func awakeFromNib() {
        super.awakeFromNib()
        textView.contentInset = UIEdgeInsets.zero
        LinkContainer.isHidden = true
        LinkContainer.layer.cornerRadius = 4
        LinkContainer.clipsToBounds = true
        linkContainerWidth.constant = self.maxWidth + 2
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(QCellTextRight.openLink))
        LinkContainer.addGestureRecognizer(tapRecognizer)
        linkImage.clipsToBounds = true
        
    }
    public override func commentChanged() {
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
        
        if !self.comment!.isInvalidated {
            if self.comment?.type == .reply{
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
                
                //self.linkImage.image = self.data.linkImage
                self.LinkContainer.isHidden = false
                self.balloonHeight.constant = 83
                self.textTopMargin.constant = 73
                self.linkHeight.constant = 65
                textWidth = self.maxWidth
            }else{
                self.linkTitle.text = ""
                self.linkDescription.text = ""
                self.linkImage.image = Qiscus.image(named: "link")
                self.LinkContainer.isHidden = true
                self.balloonHeight.constant = 10
                self.textTopMargin.constant = 0
            }
        }
        
        
        var size = self.textView.sizeThatFits(CGSize(width: maxWidth, height: CGFloat.greatestFiniteMagnitude))
        
        if !self.comment!.isInvalidated {
            if self.comment?.type == .postback && self.comment?.data != ""{
                let payload = JSON(parseJSON: self.comment!.data)
                
                if let buttonsPayload = payload.array {
                    let heightAdd = CGFloat(35 * buttonsPayload.count)
                    size.height += heightAdd
                }else{
                    size.height += 35
                }
            }
        }
        
        self.textViewHeight.constant = size.height
        self.textViewWidth.constant = textWidth
        self.userNameLabel.textAlignment = .right
        
        self.balloonView.tintColor = QiscusColorConfiguration.sharedInstance.rightBaloonColor
        
        if !self.comment!.isInvalidated {
            self.dateLabel.text = self.comment!.time.lowercased()
        }
        
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
        
        // comment status render
        if !self.comment!.isInvalidated {
            self.updateStatus(toStatus: self.comment!.status)
        }
        
        self.textView.layoutIfNeeded()
    }
    
    public override func updateStatus(toStatus status:QCommentStatus){
        super.updateStatus(toStatus: status)
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
            dateLabel.textColor = QiscusColorConfiguration.sharedInstance.rightBaloonTextColor
            statusImage.tintColor = QiscusColorConfiguration.sharedInstance.rightBaloonTextColor
            dateLabel.text = QiscusTextConfiguration.sharedInstance.sendingText
            if status == .pending {
                dateLabel.text = self.comment!.time.lowercased()
            }
            statusImage.image = Qiscus.image(named: "ic_info_time")?.withRenderingMode(.alwaysTemplate)
            break
        case .sent:
            dateLabel.text = self.comment!.time.lowercased()
            dateLabel.textColor = QiscusColorConfiguration.sharedInstance.rightBaloonTextColor
            statusImage.tintColor = QiscusColorConfiguration.sharedInstance.rightBaloonTextColor
            statusImage.image = Qiscus.image(named: "ic_sending")?.withRenderingMode(.alwaysTemplate)
            break
        case .delivered:
            dateLabel.text = self.comment!.time.lowercased()
            dateLabel.textColor = QiscusColorConfiguration.sharedInstance.rightBaloonTextColor
            statusImage.tintColor = QiscusColorConfiguration.sharedInstance.rightBaloonTextColor
            statusImage.image = Qiscus.image(named: "ic_read")?.withRenderingMode(.alwaysTemplate)
            break
        case .read:
            dateLabel.text = self.comment!.time.lowercased()
            dateLabel.textColor = QiscusColorConfiguration.sharedInstance.rightBaloonTextColor
            statusImage.tintColor = Qiscus.style.color.readMessageColor
            statusImage.image = Qiscus.image(named: "ic_read")?.withRenderingMode(.alwaysTemplate)
            break
        case . failed:
            dateLabel.textColor = QiscusColorConfiguration.sharedInstance.failToSendColor
            dateLabel.text = QiscusTextConfiguration.sharedInstance.failedText
            statusImage.image = Qiscus.image(named: "ic_warning")?.withRenderingMode(.alwaysTemplate)
            statusImage.tintColor = QiscusColorConfiguration.sharedInstance.failToSendColor
            break
        }
    }
    override func clearContext() {
        LinkContainer.isHidden = true
        textView.text = ""
        textView.font = UIFont.systemFont(ofSize: 14)
    }
    @objc func openLink(){
        self.delegate?.didTouchLink(onComment: self.comment!)
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
