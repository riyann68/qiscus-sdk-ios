//
//  QConversationCollectionView+chatCellDelegate.swift
//  Qiscus
//
//  Created by Ahmad Athaullah on 16/12/17.
//  Copyright © 2017 Ahmad Athaullah. All rights reserved.
//

import UIKit
import AVFoundation
import SwiftyJSON

extension QConversationCollectionView: QCellCarouselDelegate{
    public func cellCarousel(carouselCell: QCellCarousel, didTapCard card: QCard) {
        self.cellDelegate?.cellDelegate?(didTapCard: card)
    }
    public func cellCarousel(carouselCell: QCellCarousel, didTapAction action: QCardAction) {
        self.cellDelegate?.cellDelegate?(didTapCardAction: action)
    }
}
extension QConversationCollectionView: ChatCellDelegate, ChatCellAudioDelegate {
    func getInfo(comment: QComment) {
        self.cellDelegate?.cellDelegate?(didTapInfoOnComment: comment)
    }
    func didForward(comment: QComment) {
        self.cellDelegate?.cellDelegate?(didTapForwardOnComment: comment)
    }
    func didReply(comment: QComment) {
        self.cellDelegate?.cellDelegate?(didTapReplyOnComment: comment)
    }
    func didShare(comment: QComment) {
        self.cellDelegate?.cellDelegate?(didTapShareOnComment: comment)
    }
    
    func didTapAccountLinking(onComment comment: QComment) {
        self.cellDelegate?.cellDelegate?(didTapAccountLinking: comment)
    }
    func didTapCardButton(onComment comment: QComment, index: Int) {
        self.cellDelegate?.cellDelegate?(didTapCardButton: comment, buttonIndex: index)
    }
    func didTapPostbackButton(onComment comment: QComment, index: Int) {
        self.cellDelegate?.cellDelegate?(didTapPostbackButton: comment, buttonIndex: index)
    }
    func didTouchLink(onComment comment: QComment) {
        if comment.type == .reply{
            let replyData = JSON(parseJSON: comment.data)
            let commentId = replyData["replied_comment_id"].intValue
            if let targetComment = QComment.comment(withId: commentId){
                self.scrollToComment(comment: targetComment)
            }
            self.cellDelegate?.cellDelegate?(didTapCommentLink: comment)
        }
    }
    func didTapCell(onComment comment: QComment){
        self.cellDelegate?.cellDelegate?(didTapMediaCell: comment)
    }
    func didTapSaveContact(onComment comment: QComment) {
        self.cellDelegate?.cellDelegate?(didTapSaveContact: comment)
    }
    func didTapFile(comment: QComment) {
        if let file = comment.file {
            if file.ext == "doc" || file.ext == "docx" || file.ext == "ppt" || file.ext == "pptx" || file.ext == "xls" || file.ext == "xlsx" || file.ext == "txt" {
                self.cellDelegate?.cellDelegate?(didTapKnownFile: comment, room: self.room!)
            }
            else if file.ext == "pdf" || file.ext == "pdf_" {
                if QFileManager.isFileExist(inLocalPath: file.localPath){
                    self.cellDelegate?.cellDelegate?(didTapDocumentFile: comment, room: self.room!)
                }
            }
            else{
                self.cellDelegate?.cellDelegate?(didTapUnknownFile: comment, room: self.room!)
            }
        }
    }
    
    // MARK: ChatCellAudioDelegate
    func didTapPlayButton(_ button: UIButton, onCell cell: QCellAudio) {
        if let file = cell.comment?.file {
            if let url = URL(string: file.localPath) {
                if audioPlayer != nil {
                    if audioPlayer!.isPlaying {
                        if let activeCell = activeAudioCell{
                            DispatchQueue.main.async { autoreleasepool{
                                if let targetCell = activeCell as? QCellAudioRight{
                                    targetCell.isPlaying = false
                                }
                                if let targetCell = activeCell as? QCellAudioLeft{
                                    targetCell.isPlaying = false
                                }
                                activeCell.comment?.updatePlaying(playing: false)
                                }}
                        }
                        audioPlayer?.stop()
                        stopAudioTimer()
                        updateAudioDisplay()
                    }
                }
                activeAudioCell = cell
                do {
                    audioPlayer = try AVAudioPlayer(contentsOf: url)
                }
                catch let error as NSError {
                    Qiscus.printLog(text: error.localizedDescription)
                }
                
                audioPlayer?.delegate = self
                audioPlayer?.currentTime = Double(cell.comment!.currentTimeSlider)
                
                do {
                    try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
                    //Qiscus.printLog(text: "AVAudioSession Category Playback OK")
                    do {
                        try AVAudioSession.sharedInstance().setActive(true)
                        //Qiscus.printLog(text: "AVAudioSession is Active")
                        audioPlayer?.prepareToPlay()
                        audioPlayer?.play()
                        
                        audioTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(audioTimerFired(_:)), userInfo: nil, repeats: true)
                        
                    } catch _ as NSError {
                        Qiscus.printLog(text: "Audio player error")
                    }
                } catch _ as NSError {
                    Qiscus.printLog(text: "Audio player error")
                }
            }
        }
    }
    func didTapPauseButton(_ button: UIButton, onCell cell: QCellAudio){
        audioPlayer?.pause()
        stopAudioTimer()
        updateAudioDisplay()
    }
    func didTapDownloadButton(_ button: UIButton, onCell cell: QCellAudio){
        cell.displayAudioDownloading()
        self.room!.downloadMedia(onComment: cell.comment!, isAudioFile: true)
    }
    func didStartSeekTimeSlider(_ slider: UISlider, onCell cell: QCellAudio){
        if audioTimer != nil {
            stopAudioTimer()
        }
    }
    func didEndSeekTimeSlider(_ slider: UISlider, onCell cell: QCellAudio){
        audioPlayer?.stop()
        
        let currentTime = cell.comment!.currentTimeSlider
        audioPlayer?.currentTime = Double(currentTime)
        
        if let targetCell = cell as? QCellAudioLeft{
            targetCell.isPlaying = false
        }
        if let targetCell = cell as? QCellAudioRight{
            targetCell.isPlaying = false
        }
    }
    
}
