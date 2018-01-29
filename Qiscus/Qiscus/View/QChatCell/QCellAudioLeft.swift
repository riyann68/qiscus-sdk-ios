//
//  QCellAudioLeft.swift
//  QiscusSDK
//
//  Created by Ahmad Athaullah on 1/5/17.
//  Copyright © 2017 Ahmad Athaullah. All rights reserved.
//

import UIKit
import AVFoundation

class QCellAudioLeft: QCellAudio {

    @IBOutlet weak var userNameLabel: UILabel!
    @IBOutlet weak var balloonView: UIImageView!
    @IBOutlet weak var fileContainer: UIView!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var currentTimeSlider: UISlider!
    @IBOutlet weak var progressContainer: UIView!
    @IBOutlet weak var seekTimeLabel: UILabel!
    @IBOutlet weak var durationLabel: UILabel!
    @IBOutlet weak var progressView: UIView!
    @IBOutlet weak var progressImageView: UIImageView!
    
    @IBOutlet weak var cellHeight: NSLayoutConstraint!
    @IBOutlet weak var balloonTopMargin: NSLayoutConstraint!
    @IBOutlet weak var progressHeight: NSLayoutConstraint!
    @IBOutlet weak var balloonLeftMargin: NSLayoutConstraint!
    
    let defaultDateLeftMargin:CGFloat = -10
    var tapRecognizer: ChatTapRecognizer?
    
    var isDownloading = false{
        didSet {
            self.playButton.removeTarget(nil, action: nil, for: .allEvents)
            if isDownloading {
                self.progressImageView.image = Qiscus.image(named: "audio_download")
                self.progressContainer.isHidden = false
            }
        }
    }
    var filePath = "" {
        didSet {
            self.playButton.removeTarget(nil, action: nil, for: .allEvents)
            if filePath == "" {
                self.progressContainer.isHidden = true
                self.playButton.setImage(Qiscus.image(named: "audio_download"), for: UIControlState())
                self.playButton.addTarget(self, action: #selector(downloadButtonTapped(_:)), for: .touchUpInside)
            }else{
                self.progressContainer.isHidden = true
                self.playButton.setImage(Qiscus.image(named: "play_audio"), for: UIControlState())
                self.playButton.addTarget(self, action: #selector(playButtonTapped(_:)), for: .touchUpInside)
            }
        }
    }
    var isPlaying = false {
        didSet {
            self.playButton.removeTarget(nil, action: nil, for: .allEvents)
            if isPlaying {
                self.playButton.setImage(Qiscus.image(named: "audio_pause"), for: UIControlState())
                self.playButton.addTarget(self, action: #selector(pauseButtonTapped(_:)), for: .touchUpInside)
            } else {
                self.playButton.setImage(Qiscus.image(named: "play_audio"), for: UIControlState())
                self.playButton.addTarget(self, action: #selector(playButtonTapped(_:)), for: .touchUpInside)
            }
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        progressContainer.layer.cornerRadius = 15
        progressContainer.clipsToBounds = true
        fileContainer.layer.cornerRadius = 10
    }
    public override func commentChanged() {
        if self.hideAvatar {
            self.balloonLeftMargin.constant = 0
        }else{
            self.balloonLeftMargin.constant = 27
        }
        if let color = self.userNameColor {
            self.userNameLabel.textColor = color
        }
        self.progressHeight.constant = 0
        self.progressContainer.isHidden = true
        self.currentTimeSlider.setValue(self.comment!.currentTimeSlider, animated: true)
        self.durationLabel.text = self.comment!.durationLabel
        
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
        self.seekTimeLabel.text = self.comment!.seekTimeLabel
        if self.tapRecognizer != nil{
            self.fileContainer.removeGestureRecognizer(self.tapRecognizer!)
            self.tapRecognizer = nil
        }
        balloonView.tintColor = QiscusColorConfiguration.sharedInstance.leftBaloonColor
        dateLabel.textColor = QiscusColorConfiguration.sharedInstance.leftBaloonTextColor
        self.balloonView.image = getBallon()
        self.dateLabel.text = self.comment!.time.lowercased()
        self.isPlaying = self.comment!.audioIsPlaying
        self.filePath = ""
        if let file = self.comment!.file{
            if file.localPath != "" {
                if QFileManager.isFileExist(inLocalPath: file.localPath){
                    self.filePath = file.localPath
                    self.isPlaying = self.comment!.audioIsPlaying
                    let audioURL = URL(fileURLWithPath: file.localPath)
                    let audioAsset = AVURLAsset(url: audioURL)
                    audioAsset.loadValuesAsynchronously(forKeys: ["duration"], completionHandler: {
                        var error: NSError? = nil
                        let status = audioAsset.statusOfValue(forKey: "duration", error: &error)
                        switch status {
                        case .loaded:
                            let duration = Double(CMTimeGetSeconds(audioAsset.duration))
                            DispatchQueue.main.async {
                                autoreleasepool{
                                    self.currentTimeSlider.maximumValue = Float(duration)
                                    if let durationString = self.timeFormatter?.string(from: duration) {
                                    
                                        self.comment!.updateDurationLabel(label: durationString)
                                        self.durationLabel.text = durationString
                                    }
                                }
                            }
                            break
                        default:
                            break
                        }
                    })
                }else{
                    file.updateLocalPath(path: "")
                }
            }
        }
        if self.comment!.isUploading || self.comment!.isDownloading{
            let uploadProgres = Int(self.comment!.progress * 100)
            let uploading = QiscusTextConfiguration.sharedInstance.uploadingText
            let downloading = QiscusTextConfiguration.sharedInstance.downloadingText
            
            self.progressContainer.isHidden = false
            self.progressHeight.constant = self.comment!.progress * 30
            
            if self.comment!.isDownloading{
                self.progressImageView.image = Qiscus.image(named: "audio_download")
                dateLabel.text = "\(downloading) \(QChatCellHelper.getFormattedStringFromInt(uploadProgres)) %"
            }else{
                self.progressImageView.image = Qiscus.image(named: "audio_upload")
                dateLabel.text = "\(uploading) \(QChatCellHelper.getFormattedStringFromInt(uploadProgres)) %"
            }
        }
    }
    open override func setupCell(){
    
    }
    @IBAction func playButtonTapped(_ sender: UIButton) {
        self.isPlaying = true
        DispatchQueue.main.async {
            autoreleasepool{
                self.comment?.updatePlaying(playing: true)
                self.audioCellDelegate?.didTapPlayButton(sender, onCell: self)
            }
        }
    }
    
    @IBAction func pauseButtonTapped(_ sender: UIButton) {
        self.isPlaying = false
        DispatchQueue.main.async {
            autoreleasepool{
                self.comment?.updatePlaying(playing: false)
                self.audioCellDelegate?.didTapPauseButton(sender, onCell: self)
            }
        }
    }
    
    @IBAction func downloadButtonTapped(_ sender: UIButton) {
        self.audioCellDelegate?.didTapDownloadButton(sender, onCell: self)
    }
    
    @IBAction func sliderValueChanged(_ sender: UISlider) {
        DispatchQueue.main.async {
            autoreleasepool{
                if let seekTimeString = self.timeFormatter?.string(from: Double(sender.value)){
                    self.comment?.updateTimeSlider(value: self.currentTimeSlider.value)
                    self.comment?.updateSeekLabel(label: seekTimeString)
                    
                    self.seekTimeLabel.text = seekTimeString
                }
                self.audioCellDelegate?.didStartSeekTimeSlider(sender, onCell: self)
            }
        }
    }
    @IBAction func sliderTouchUpInside(_ sender: UISlider) {
        DispatchQueue.main.async {
            autoreleasepool{
                self.comment!.updateTimeSlider(value: self.currentTimeSlider.value)
                self.audioCellDelegate?.didEndSeekTimeSlider(sender, onCell: self)
            }
        }
        
    }
    public override func downloadingMedia() {
        self.progressContainer.isHidden = false
        self.progressHeight.constant = self.comment!.progress * 30
        let percentage = Int(self.comment!.progress * 100)
        self.dateLabel.text = "Downloading \(QChatCellHelper.getFormattedStringFromInt(percentage)) %"
        UIView.animate(withDuration: 0.65, animations: {
            self.progressView.layoutIfNeeded()
        })
    }
    open override func displayAudioDownloading() {
        self.isDownloading = true
        DispatchQueue.main.async {
            autoreleasepool{
                self.comment?.updateDownloading(downloading: true)
                self.playButton.removeTarget(nil, action: nil, for: .allEvents)
            }
        }
    }
    open override func updateAudioDisplay(withTimeInterval timeInterval:TimeInterval) {
        self.isPlaying = self.comment!.audioIsPlaying
        DispatchQueue.main.async {
            autoreleasepool{
                self.comment?.updateTimeSlider(value: Float(timeInterval))
                self.currentTimeSlider.setValue(Float(timeInterval), animated: true)
                
                self.seekTimeLabel.text = self.timeFormatter?.string(from: timeInterval)
                
                if Float(timeInterval) == Float(0) {
                    self.comment?.updatePlaying(playing: false)
                    self.isPlaying = false
                }
            }
        }
    }
    public override func downloadFinished() {
        if let file = self.comment!.file{
            if file.localPath != "" {
                if QFileManager.isFileExist(inLocalPath: file.localPath){
                    self.filePath = file.localPath
                    self.isPlaying = self.comment!.audioIsPlaying
                    let audioURL = URL(fileURLWithPath: file.localPath)
                    let audioAsset = AVURLAsset(url: audioURL)
                    audioAsset.loadValuesAsynchronously(forKeys: ["duration"], completionHandler: {
                        var error: NSError? = nil
                        let status = audioAsset.statusOfValue(forKey: "duration", error: &error)
                        switch status {
                        case .loaded:
                            let duration = Double(CMTimeGetSeconds(audioAsset.duration))
                            DispatchQueue.main.async {
                                autoreleasepool{
                                    self.currentTimeSlider.maximumValue = Float(duration)
                                    if let durationString = self.timeFormatter?.string(from: duration) {
                                        self.comment!.updateDurationLabel(label: durationString)
                                        self.durationLabel.text = durationString
                                    }
                                }
                            }
                            break
                        default:
                            break
                        }
                    })
                }else{
                    file.updateLocalPath(path: "")
                }
            }
            self.dateLabel.text = self.comment!.time.lowercased()
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
    public override func comment(didDownload comment:QComment, downloading:Bool){
        if comment.uniqueId == self.comment?.uniqueId {
            if downloading {
                self.downloadingMedia()
            }else{
                self.downloadFinished()
            }
        }
    }

    public override func comment(didChangeProgress comment:QComment, progress:CGFloat){
        if comment.uniqueId == self.comment?.uniqueId {
            self.progressContainer.isHidden = false
            self.progressHeight.constant = progress * 30
            let percentage = Int(progress * 100)
            self.dateLabel.text = "Downloading \(QChatCellHelper.getFormattedStringFromInt(percentage)) %"
            UIView.animate(withDuration: 0.65, animations: {
                self.progressView.layoutIfNeeded()
            })
        }
    }
}
