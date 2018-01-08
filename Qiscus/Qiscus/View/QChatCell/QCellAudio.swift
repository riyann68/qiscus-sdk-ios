//
//  QCellAudio.swift
//  QiscusSDK
//
//  Created by Ahmad Athaullah on 1/6/17.
//  Copyright © 2017 Ahmad Athaullah. All rights reserved.
//

import UIKit
protocol ChatCellAudioDelegate {
    func didTapPlayButton(_ button: UIButton, onCell cell: QCellAudio)
    func didTapPauseButton(_ button: UIButton, onCell cell: QCellAudio)
    func didTapDownloadButton(_ button: UIButton, onCell cell: QCellAudio)
    func didStartSeekTimeSlider(_ slider: UISlider, onCell cell: QCellAudio)
    func didEndSeekTimeSlider(_ slider: UISlider, onCell cell: QCellAudio)
}
class QCellAudio: QChatCell {

    var audioCellDelegate: ChatCellAudioDelegate?
    var _timeFormatter: DateComponentsFormatter?
    var currentTime = TimeInterval()
    var timeFormatter: DateComponentsFormatter? {
        get {
            if _timeFormatter == nil {
                _timeFormatter = DateComponentsFormatter()
                _timeFormatter?.zeroFormattingBehavior = .pad;
                _timeFormatter?.allowedUnits = [.minute, .second]
                _timeFormatter?.unitsStyle = .positional;
            }
            
            return _timeFormatter
        }
        
        set {
            _timeFormatter = newValue
        }
    }
    
    open func displayAudioDownloading(){
        
    }
    open func updateAudioDisplay(withTimeInterval timeInterval:TimeInterval){
    
    }
}
