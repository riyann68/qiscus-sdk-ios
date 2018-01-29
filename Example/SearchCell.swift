//
//  SearchCell.swift
//  Example
//
//  Created by Ahmad Athaullah on 9/5/17.
//  Copyright © 2017 Ahmad Athaullah. All rights reserved.
//

import UIKit
import Qiscus

class SearchCell: UITableViewCell {

    @IBOutlet weak var roomLabel: UILabel!
    @IBOutlet weak var messageLabel: UITextView!
    
    var comment:QComment?{
        didSet{
            if comment != nil {
                self.roomLabel.text = comment!.roomName
                let attributedString = NSMutableAttributedString(string: comment!.text, attributes: [NSAttributedStringKey.font:UIFont.systemFont(ofSize: 14.0)])
                let boldFontAttribute = [NSAttributedStringKey.font: UIFont.boldSystemFont(ofSize: 14.0), NSAttributedStringKey.foregroundColor: UIColor.red]
                attributedString.addAttributes(boldFontAttribute, range: (comment!.text as NSString).range(of: searchString))
                attributedString.addAttributes(boldFontAttribute, range: (comment!.text as NSString).range(of: searchString.capitalized))
                attributedString.addAttributes(boldFontAttribute, range: (comment!.text as NSString).range(of: searchString.uppercased()))
                attributedString.addAttributes(boldFontAttribute, range: (comment!.text as NSString).range(of: searchString.lowercased()))
                self.messageLabel.attributedText = attributedString
                self.messageLabel.sizeToFit()
                
            }
        }
    }
    var searchString = ""
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
}
