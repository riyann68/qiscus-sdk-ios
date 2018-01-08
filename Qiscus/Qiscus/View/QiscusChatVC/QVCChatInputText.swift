//
//  QiscusChatVC:InputTextDelegate
//  QiscusSDK
//
//  Created by Ahmad Athaullah on 2/15/17.
//  Copyright © 2017 Ahmad Athaullah. All rights reserved.
//

import UIKit

extension QiscusChatVC: ChatInputTextDelegate {
    // MARK: - ChatInputTextDelegate Delegate
    open func chatInputTextDidChange(chatInput input: ChatInputText, height: CGFloat) {
        if input.value.count > 0 {
            self.chatRoom?.publishStartTyping()
        }
        QiscusBackgroundThread.sync {
            let currentHeight = self.minInputHeight.constant
            if currentHeight != height {
                DispatchQueue.main.async { autoreleasepool{
                    self.minInputHeight.constant = height
                    input.layoutIfNeeded()
                }}
            }
        }
    }
    open func valueChanged(value:String){

    }
    open func chatInputDidEndEditing(chatInput input: ChatInputText) {
        self.sendStopTyping()
    }
    public func sendStopTyping(){
        if let room = self.chatRoom {
            room.publishStopTyping()
        }
    }
}
