//
//  QCellDocLeft.swift
//  Qiscus
//
//  Created by Ahmad Athaullah on 14/12/17.
//  Copyright © 2017 Ahmad Athaullah. All rights reserved.
//

import UIKit

class QCellDocLeft: QChatCell {

    @IBOutlet weak var userNameLabel: UILabel!
    @IBOutlet weak var balloonView: UIImageView!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var downloadButton: ChatFileButton!
    @IBOutlet weak var fileNameLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var fileIconView: UIImageView!
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var docPreview: UIImageView!
    @IBOutlet weak var progressView: UIView!
    @IBOutlet weak var progressContainer: UIView!
    
    @IBOutlet weak var progresHeight: NSLayoutConstraint!
    @IBOutlet weak var topMargin: NSLayoutConstraint!
    @IBOutlet weak var cellHeight: NSLayoutConstraint!
    @IBOutlet weak var containerWidth: NSLayoutConstraint!
    @IBOutlet weak var balloonLeftMargin: NSLayoutConstraint!
    
    
    let maxProgressHeight:CGFloat = 20
    
    override func awakeFromNib() {
        super.awakeFromNib()
        progressContainer.layer.cornerRadius = 10
        progressContainer.clipsToBounds = true
        progressContainer.layer.borderColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.65).cgColor
        progressContainer.layer.borderWidth = 2
        self.docPreview.contentMode = .scaleAspectFill
        self.docPreview.clipsToBounds = true
        self.docPreview.backgroundColor = UIColor.black
        self.docPreview.isUserInteractionEnabled = true
        downloadButton.setImage(Qiscus.image(named: "ic_download_chat")!.withRenderingMode(.alwaysOriginal), for: UIControlState())
        containerView.layer.cornerRadius = 10
        containerView.clipsToBounds = true
        containerWidth.constant = QiscusUIConfiguration.chatTextMaxWidth + 6.0
        let tapRecognizer = UITapGestureRecognizer(target:self,action:#selector(QCellDocLeft.didTapImage))
        docPreview.addGestureRecognizer(tapRecognizer)
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
        balloonView.tintColor = QiscusColorConfiguration.sharedInstance.leftBaloonColor
        self.balloonView.image = self.getBallon()
        progressContainer.isHidden = true
        progresHeight.constant = 0
        dateLabel.text = self.comment!.time.lowercased()
        dateLabel.textColor = QiscusColorConfiguration.sharedInstance.leftBaloonTextColor
        descriptionLabel.text = ""
        if self.showUserName{
            if let sender = self.comment?.sender {
                self.userNameLabel.text = sender.fullname.capitalized
            }else{
                self.userNameLabel.text = self.comment?.senderName.capitalized
            }
            self.userNameLabel.isHidden = false
            self.topMargin.constant = 20
            self.cellHeight.constant = 20
        }else{
            self.userNameLabel.text = ""
            self.userNameLabel.isHidden = true
            self.topMargin.constant = 0
            self.cellHeight.constant = 0
        }
        if let file = self.comment?.file {
            self.fileNameLabel.text = file.filename
            var description = "\(file.ext.uppercased()) File"
            if file.pages > 0 {
                description = "\(description), \(file.pages) page"
            }
            if file.sizeString != "" {
                description = "\(description), \(file.sizeString)"
            }
            self.descriptionLabel.text = description
            if let image = self.comment?.displayImage{
                self.docPreview.image = image
            }else if QFileManager.isFileExist(inLocalPath: file.localThumbPath){
                self.docPreview.loadAsync(fromLocalPath: file.localThumbPath, onLoaded: { (image, _) in
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
//            if self.tapRecognizer != nil{
//                docPreview.removeGestureRecognizer(self.tapRecognizer!)
//                tapRecognizer = nil
//            }
            
            if !QFileManager.isFileExist(inLocalPath: file.localPath){
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
                    self.progressView.isHidden = false
                    let newHeight = self.comment!.progress * maxProgressHeight
                    self.progresHeight.constant = newHeight
                    self.progressView.layoutIfNeeded()
                }
            }
            self.balloonView.layoutIfNeeded()
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
                    self.docPreview.image = image
                    self.comment!.displayImage = image
                })
            }else if QFileManager.isFileExist(inLocalPath: file.localMiniThumbPath){
                docPreview.loadAsync(fromLocalPath: file.localMiniThumbPath, onLoaded: { (image, _) in
                    self.docPreview.image = image
                    self.comment!.displayImage = image
                })
            }
            self.progressContainer.isHidden = true
        }
    }
    @objc func didTapImage(){
        if let file = self.comment?.file{
            if QFileManager.isFileExist(inLocalPath: file.localPath){
                self.delegate?.didTapFile(comment: self.comment!)
            }else{
                download()
            }
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
        if comment.uniqueId == self.comment?.uniqueId{
            self.balloonView.image = self.getBallon()
        }
    }
    public override func comment(didDownload comment:QComment, downloading:Bool){
        if comment.uniqueId == self.comment?.uniqueId {
            self.downloadFinished()
        }
    }
    public override func comment(didUpload comment:QComment, uploading:Bool){
        if comment.uniqueId == self.comment?.uniqueId {
            self.uploadFinished()
        }
    }
    public override func comment(didChangeProgress comment:QComment, progress:CGFloat){
        if comment.uniqueId == self.comment?.uniqueId {
            self.downloadButton.isHidden = true
            self.progressContainer.isHidden = false
            
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
    @IBAction func onDownload(_ sender: ChatFileButton) {
        download()
    }
}
