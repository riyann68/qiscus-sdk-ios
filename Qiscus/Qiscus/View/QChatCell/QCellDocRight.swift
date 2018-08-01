//
//  QCellDocRight.swift
//  Qiscus
//
//  Created by Ahmad Athaullah on 14/12/17.
//  Copyright © 2017 Ahmad Athaullah. All rights reserved.
//

import UIKit

class QCellDocRight: QChatCell {
    @IBOutlet weak var userNameLabel: UILabel!
    @IBOutlet weak var balloonView: UIImageView!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var downloadButton: ChatFileButton!
    @IBOutlet weak var fileNameLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var fileIconView: UIImageView!
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var docPreview: UIImageView!
    @IBOutlet weak var progressContainer: UIView!
    @IBOutlet weak var progressView: UIView!
    @IBOutlet weak var statusImage: UIImageView!
    
    @IBOutlet weak var progresHeight: NSLayoutConstraint!
    @IBOutlet weak var topMargin: NSLayoutConstraint!
    @IBOutlet weak var containerWidth: NSLayoutConstraint!
    @IBOutlet weak var cellHeight: NSLayoutConstraint!
    
    let defaultDateLeftMargin:CGFloat = -10
    let maxProgressHeight:CGFloat = 20.0
    
    override func awakeFromNib() {
        super.awakeFromNib()
        userNameLabel.textAlignment = .right
        progressContainer.layer.cornerRadius = 10
        progressContainer.clipsToBounds = true
        progressContainer.layer.borderColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.65).cgColor
        progressContainer.layer.borderWidth = 2
        downloadButton.setImage(Qiscus.image(named: "ic_download_chat")!.withRenderingMode(.alwaysOriginal), for: UIControlState())
        
        self.docPreview.contentMode = .scaleAspectFill
        self.docPreview.clipsToBounds = true
        self.docPreview.backgroundColor = UIColor.black
        self.docPreview.isUserInteractionEnabled = true
        //imageDisplay.layer.cornerRadius = 10
        containerView.layer.cornerRadius = 10
        containerView.clipsToBounds = true
        containerWidth.constant = QiscusUIConfiguration.chatTextMaxWidth + 6.0
        let tapRecognizer = UITapGestureRecognizer(target:self,action:#selector(QCellDocRight.didTapImage))
        docPreview.addGestureRecognizer(tapRecognizer)
    }
    public override func commentChanged() {
        if let color = self.userNameColor {
            self.userNameLabel.textColor = color
        }
        balloonView.tintColor = QiscusColorConfiguration.sharedInstance.rightBaloonColor
        self.balloonView.image = self.getBallon()
        progressContainer.isHidden = true
        progresHeight.constant = 0
        dateLabel.text = self.comment!.time.lowercased()
        dateLabel.textColor = QiscusColorConfiguration.sharedInstance.leftBaloonTextColor
        descriptionLabel.text = ""
        
        if let file = self.comment!.file {
            self.fileNameLabel.text = file.filename
            var description = "\(file.ext.uppercased()) File"
            if file.pages > 0 {
                description = "\(description), \(file.pages) page"
            }
            if file.sizeString != "" {
                description = "\(description), \(file.sizeString)"
            }
            self.descriptionLabel.text = description
            if let image = self.comment!.displayImage {
                self.docPreview.image = image
            }
            else if QFileManager.isFileExist(inLocalPath: file.localThumbPath){
                docPreview.loadAsync(fromLocalPath: file.localThumbPath, onLoaded: { (image, _) in
                    self.docPreview.image = image
                    self.comment!.displayImage = image
                })
            }else if QFileManager.isFileExist(inLocalPath: file.localMiniThumbPath){
                docPreview.loadAsync(fromLocalPath: file.localMiniThumbPath, onLoaded: { (image, _) in
                    self.docPreview.image = image
                    self.comment!.displayImage = image
                })
            }else{
                docPreview.loadAsync(file.thumbURL, onLoaded: { (image, _) in
                    self.docPreview.image = image
                    self.comment!.displayImage = image
                    file.saveMiniThumbImage(withImage: image)
                })
            }
            if self.showUserName{
                self.userNameLabel.text = "YOU".getLocalize()
                self.userNameLabel.isHidden = false
                self.topMargin.constant = 20
                self.cellHeight.constant = 20
            }else{
                self.userNameLabel.text = ""
                self.userNameLabel.isHidden = true
                self.topMargin.constant = 0
                self.cellHeight.constant = 0
            }
            
            dateLabel.text = self.comment!.time.lowercased()
            dateLabel.textColor = QiscusColorConfiguration.sharedInstance.rightBaloonTextColor
            
            if !QFileManager.isFileExist(inLocalPath: file.localPath){
                file.updateLocalPath(path: "")
                if self.comment!.isDownloading {
                    self.downloadButton.isHidden = true
                    self.progressContainer.isHidden = false
                    let newHeight = self.comment!.progress * maxProgressHeight
                    self.progresHeight.constant = newHeight
                    self.progressView.layoutIfNeeded()
                }else{
                    self.downloadButton.comment = self.comment!
                    self.downloadButton.isHidden = false
                }
            }else{
                self.downloadButton.isHidden = true
                if self.comment!.isUploading{
                    self.progressContainer.isHidden = false
                    let newHeight = self.comment!.progress * maxProgressHeight
                    self.progresHeight.constant = newHeight
                    self.progressView.layoutIfNeeded()
                }
            }
            updateStatus(toStatus: self.comment!.status)
        }
    }
    open override func setupCell(){
        
    }
    
    public override func updateStatus(toStatus status:QCommentStatus){
        super.updateStatus(toStatus: status)
        dateLabel.text = self.comment!.time.lowercased()
        dateLabel.textColor = QiscusColorConfiguration.sharedInstance.rightBaloonTextColor
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
            if self.comment!.isUploading{
                dateLabel.text = QiscusTextConfiguration.sharedInstance.uploadingText
            }else{
                dateLabel.text = QiscusTextConfiguration.sharedInstance.sendingText
                if status == .pending {
                    dateLabel.text = self.comment!.time.lowercased()
                }
            }
            statusImage.image = Qiscus.image(named: "ic_info_time")?.withRenderingMode(.alwaysTemplate)
            break
        case .sent:
            statusImage.image = Qiscus.image(named: "ic_sending")?.withRenderingMode(.alwaysTemplate)
            uploadFinished()
            break
        case .delivered:
            statusImage.image = Qiscus.image(named: "ic_read")?.withRenderingMode(.alwaysTemplate)
            break
        case .read:
            statusImage.tintColor = Qiscus.style.color.readMessageColor
            statusImage.image = Qiscus.image(named: "ic_read")?.withRenderingMode(.alwaysTemplate)
            break
        case .failed:
            self.progressContainer.isHidden = true
            dateLabel.text = QiscusTextConfiguration.sharedInstance.failedText
            dateLabel.textColor = QiscusColorConfiguration.sharedInstance.failToSendColor
            statusImage.image = Qiscus.image(named: "ic_warning")?.withRenderingMode(.alwaysTemplate)
            statusImage.tintColor = QiscusColorConfiguration.sharedInstance.failToSendColor
            break
        default: break
        }
    }
    
    public override func downloadingMedia() {
        self.downloadButton.isHidden = true
        self.progressContainer.isHidden = false
        
        let newHeight = self.comment!.progress * maxProgressHeight
        self.progresHeight.constant = newHeight
        UIView.animate(withDuration: 0.65, animations: {
            self.progressView.layoutIfNeeded()
        })
    }
    public override func downloadFinished() {
        if let file = self.comment!.file {
            var description = "\(file.ext.uppercased()) File"
            if file.pages > 0 {
                description = "\(description), \(file.pages) page"
            }
            if file.sizeString != "" {
                description = "\(description), \(file.sizeString)"
            }
            self.descriptionLabel.text = description
            if QFileManager.isFileExist(inLocalPath: file.localThumbPath){
                docPreview.loadAsync(fromLocalPath: file.localThumbPath, onLoaded: { (image, _) in
                    DispatchQueue.main.async {
                        self.docPreview.image = image
                        self.comment!.displayImage = image
                    }
                })
            }else if QFileManager.isFileExist(inLocalPath: file.localMiniThumbPath){
                docPreview.loadAsync(fromLocalPath: file.localMiniThumbPath, onLoaded: { (image, _) in
                    self.docPreview.image = image
                    self.comment!.displayImage = image
                })
            }else{
                self.downloadButton.comment = self.comment!
                self.downloadButton.isHidden = false
            }
            self.progressContainer.isHidden = true
        }
    }
    @objc func didTapImage(){
        if let file = self.comment!.file{
            if QFileManager.isFileExist(inLocalPath: file.localPath){
                self.delegate?.didTapFile(comment: self.comment!)
            }else{
                download()
            }
        }
    }
    public override func uploadingMedia() {
        self.downloadButton.isHidden = true
        self.progressContainer.isHidden = false
        
        let newHeight = self.comment!.progress * maxProgressHeight
        let percentage = Int(self.comment!.progress * 100.0)
        self.progresHeight.constant = newHeight
        self.descriptionLabel.text = "Uploading \(percentage) %"
        UIView.animate(withDuration: 0.65, animations: {
            self.progressView.layoutIfNeeded()
        })
    }
    public override func uploadFinished(){
        self.progressContainer.isHidden = true
        if let file = self.comment?.file{
            var description = "\(file.ext.uppercased()) File"
            if file.pages > 0 {
                description = "\(description), \(file.pages) page"
            }
            if file.sizeString != "" {
                description = "\(description), \(file.sizeString)"
            }
            self.descriptionLabel.text = description
        }
    }
    func setupImageView(){
        
    }
    public override func updateUserName() {
        if let sender = self.comment?.sender {
            self.userNameLabel.text = sender.fullname
        }else{
            self.userNameLabel.text = self.comment?.senderName
        }
    }
    public override func comment(didChangePosition comment:QComment, position: QCellPosition) {
        if self.comment?.uniqueId == comment.uniqueId {
            self.balloonView.image = self.getBallon()
        }
    }
    public override func comment(didDownload comment:QComment, downloading:Bool){
        if self.comment?.uniqueId == comment.uniqueId {
            if !downloading {
                self.downloadFinished()
            }else{
                self.downloadingMedia()
            }
        }
    }
    public override func comment(didUpload comment:QComment, uploading:Bool){
        if self.comment?.uniqueId == comment.uniqueId {
            self.uploadFinished()
        }
    }
    public override func comment(didChangeProgress comment:QComment, progress:CGFloat){
        if self.comment?.uniqueId == comment.uniqueId {
            self.downloadButton.isHidden = true
            self.progressContainer.isHidden = false
            
            if self.comment!.isUploading {
                let percentage = Int(self.comment!.progress * 100.0)
                self.descriptionLabel.text = "Uploading \(percentage) %"
            }
            
            let newHeight = progress * maxProgressHeight
            self.progresHeight.constant = newHeight
            UIView.animate(withDuration: 0.65, animations: {
                self.progressView.layoutIfNeeded()
            })
        }
    }
    func download(){
        self.downloadButton.isHidden = true
        if let room = QRoom.room(withId: comment!.roomId){
            room.downloadMedia(onComment: self.comment!)
        }
    }
    @IBAction func onDownload(_ sender: Any) {
        download()
    }
    
}
