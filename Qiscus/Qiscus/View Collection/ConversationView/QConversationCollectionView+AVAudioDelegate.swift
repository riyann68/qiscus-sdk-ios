//
//  QConversationCollectionView+AVAudioPlayerDelegate.swift
//  Qiscus
//
//  Created by Ahmad Athaullah on 16/12/17.
//  Copyright © 2017 Ahmad Athaullah. All rights reserved.
//
import AVFoundation

extension QConversationCollectionView:AVAudioPlayerDelegate{
    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        do {
            try AVAudioSession.sharedInstance().setActive(false)
            if let activeCell = activeAudioCell {
                activeCell.comment!.updatePlaying(playing: false)
            }
            stopAudioTimer()
            updateAudioDisplay()
        } catch _ as NSError {}
    }
    
    public func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        if let activeCell = activeAudioCell as? QCellAudioLeft{
            activeCell.comment!.updatePlaying(playing: false)
        }
        stopAudioTimer()
        updateAudioDisplay()
    }
    
    // MARK: - Audio Methods
    @objc func audioTimerFired(_ timer: Timer) {
        self.updateAudioDisplay()
    }
    
    func stopAudioTimer() {
        audioTimer?.invalidate()
        audioTimer = nil
    }
    
    func updateAudioDisplay() {
        if let cell = activeAudioCell{
            if let currentTime = audioPlayer?.currentTime {
                cell.updateAudioDisplay(withTimeInterval: currentTime)
            }
        }
    }
}
