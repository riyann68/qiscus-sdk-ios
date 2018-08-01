//
//  QTextView.swift
//  Example
//
//  Created by Ahmad Athaullah on 8/3/17.
//  Copyright © 2017 Ahmad Athaullah. All rights reserved.
//

import UIKit
enum QTextViewType {
    case caption
    case text
}
class QTextView: UITextView {
    var type = QTextViewType.text
    var commentLinkTextAttributes:[String: Any]{
        get{
            var foregroundColorAttributeName = QiscusColorConfiguration.sharedInstance.leftBaloonLinkColor
            var underlineColorAttributeName = QiscusColorConfiguration.sharedInstance.leftBaloonLinkColor
            if self.comment?.senderEmail == Qiscus.client.email{
                foregroundColorAttributeName = QiscusColorConfiguration.sharedInstance.rightBaloonLinkColor
                underlineColorAttributeName = QiscusColorConfiguration.sharedInstance.rightBaloonLinkColor
            }
            return [
                NSAttributedStringKey.foregroundColor.rawValue: foregroundColorAttributeName,
                NSAttributedStringKey.underlineColor.rawValue: underlineColorAttributeName,
                NSAttributedStringKey.underlineStyle.rawValue: NSUnderlineStyle.styleSingle.rawValue,
                NSAttributedStringKey.font.rawValue: Qiscus.style.chatFont
            ]
        }
    }
    var comment:QComment?{
        didSet{
            if let currentValue = comment {
                if !currentValue.isInvalidated {
                    self.tintColor = .clear
                    self.attributedText = currentValue.attributedText
                    self.linkTextAttributes = self.commentLinkTextAttributes
                }
            }
        }
    }
    
    override func copy(_ sender: Any?) {
        UIPasteboard.general.string = comment?.text
        if !NSEqualRanges(self.selectedRange, NSRange(location: 0, length: 0)){
            self.selectedRange = NSRange(location: 0, length: 0)
        }
    }
    override func selectionRects(for range: UITextRange) -> [Any] {
        return []
    }
    
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        switch action.description {
        case "cut:","select:","selectAll:","paste:","_lookup:","_define:","_addShortcut:","_share:":
            return false
        case "copy:":
            if self.type == .text {
                return super.canPerformAction(action, withSender: sender)
            }else{
                return false
            }
        default:
            return super.canPerformAction(action, withSender: sender)
        }
    }
}
