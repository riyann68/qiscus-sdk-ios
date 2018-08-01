//
//  QConversationCollectionView+CollectionView.swift
//  Qiscus
//
//  Created by Ahmad Athaullah on 16/12/17.
//  Copyright © 2017 Ahmad Athaullah. All rights reserved.
//

import UIKit

extension QConversationCollectionView: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    // MARK: SCrolling
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.onScrolling = true
    }
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        self.onScrolling = false
        if self.needToReload {
            self.refreshData()
        }
    }
    // MARK: CollectionView Data source
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if self.room == nil {return 0}
        if section < self.messagesId.count {
            return self.messagesId[section].count
        }else{
            return 1
        }
    }
    public func numberOfSections(in collectionView: UICollectionView) -> Int {
        var sectionNumber = 0
        var usingTypingCell = false
        if let config = self.configDelegate?.configDelegate?(usingTpingCellIndicator: self){
            usingTypingCell = config
        }
        if self.room != nil {
            sectionNumber = self.messagesId.count
            if usingTypingCell && self.typingUsers.count > 0 {
                sectionNumber += 1
            }
        }
        return sectionNumber
    }
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.section < self.messagesId.count && indexPath.row < self.messagesId[indexPath.section].count {
            let uid = self.messagesId[indexPath.section][indexPath.row]
            var comment = QComment()
            if let c = QComment.comment(withUniqueId: uid){
                if !c.isInvalidated {
                    comment = c
                }
            }
            
            if let cell = self.viewDelegate?.viewDelegate?(view: self, cellForComment: comment, indexPath: indexPath){
                return cell
            }else{
                var cell = collectionView.dequeueReusableCell(withReuseIdentifier: comment.cellIdentifier, for: indexPath) as! QChatCell
                
                var showName = false
                var color:UIColor?
                if indexPath.row == 0 {
                    var showUserName = true
                    if let user = comment.sender {
                        if let hidden = self.configDelegate?.configDelegate?(hideUserNameLabel: self, forUser: user){
                            showUserName = !hidden
                        }
                        color = self.configDelegate?.configDelegate?(userNameLabelColor: self, forUser: user)
                    }
                    showName = showUserName
                }
                
                cell.clipsToBounds = true
                var showAvatar = true
                if let hideAvatar = self.configDelegate?.configDelegate?(hideLeftAvatarOn: self){
                    showAvatar = !hideAvatar
                }
                
                cell.setData(onIndexPath: indexPath, comment: comment, showUserName: showName, userNameColor: color, hideAvatar: !showAvatar, delegate: self)
                
                if let audioCell = cell as? QCellAudio{
                    audioCell.audioCellDelegate = self
                    cell = audioCell
                }else if let carouselCell = cell as? QCellCarousel {
                    carouselCell.cellCarouselDelegate = self
                    cell = carouselCell
                }
                return cell
            }
        }else{
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cellTypingLeft", for: indexPath) as! QCellTypingLeft
            var showAvatar = true
            if let hideAvatar = self.configDelegate?.configDelegate?(hideLeftAvatarOn: self){
                showAvatar = !hideAvatar
            }
            cell.hideAvatar = !showAvatar
            cell.users = typingUsers
            return cell
        }
        
    }
    open func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if indexPath.section < self.messagesId.count {
            let commentGroup = self.messagesId[indexPath.section]
            let uid = commentGroup.first!
            if let firsMessage = QComment.comment(withUniqueId: uid) {
                if kind == UICollectionElementKindSectionFooter{
                    if firsMessage.senderEmail == Qiscus.client.email{
                        let footerCell = self.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "cellFooterRight", for: indexPath) as! QChatFooterRight
                        return footerCell
                    }else{
                        let footerCell = self.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "cellFooterLeft", for: indexPath) as! QChatFooterLeft
                        footerCell.user = firsMessage.sender
                        return footerCell
                    }
                }else{
                    let headerCell = self.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "cellHeader", for: indexPath) as! QChatHeaderCell
                    
                    headerCell.dateString = firsMessage.date
                    return headerCell
                }
            } else {
                let footerCell = self.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "emptyHeader", for: indexPath)
                return footerCell
            }
        }else{
            if kind == UICollectionElementKindSectionFooter{
                let footerCell = self.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "emptyFooter", for: indexPath) as! QChatEmptyFooter
                return footerCell
            }else{
                let headerCell = self.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "emptyHeader", for: indexPath) as! QChatEmptyHeaderCell
                
                return headerCell
            }
        }
    }
    
    // MARK: CollectionView delegate
    open func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        QiscusBackgroundThread.async {
            if self.messagesId.count > indexPath.section {
                let group = self.messagesId[indexPath.section]
                if group.count > indexPath.item {
                    let uid = group[indexPath.item]
                    if let chatCell = cell as? QChatCell {
                        var isLastItem = false
                        let lastSection = self.messagesId.count - 1
                        if indexPath.section == lastSection {
                            let lastItem = self.messagesId[lastSection].count - 1
                            if indexPath.item == lastItem {
                                isLastItem = true
                            }
                        }
                        if let target = self.targetIndexPath {
                            if indexPath.section == target.section && indexPath.item == target.item {
                                DispatchQueue.main.async {
                                    cell.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.15)
                                    self.targetIndexPath = nil
                                }
                            }
                        }
                        DispatchQueue.main.async {
                            chatCell.willDisplayCell()
                            if let message = QComment.comment(withUniqueId: uid) {
                                self.viewDelegate?.viewDelegate?(view: self, willDisplayCellForComment: message, cell: chatCell, indexPath: indexPath)
                                if isLastItem {
                                    self.viewDelegate?.viewDelegate?(willDisplayLastMessage: self, comment: message)
                                    self.isLastRowVisible = true
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    open func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        QiscusBackgroundThread.async {
            if self.messagesId.count > indexPath.section {
                let group = self.messagesId[indexPath.section]
                if group.count > indexPath.item {
                    let uid = group[indexPath.item]
                    var isLastRow = false
                    if let chatCell = cell as? QChatCell {
                        let lastSection = self.messagesId.count - 1
                        if indexPath.section == lastSection {
                            let lastItem = self.messagesId[lastSection].count - 1
                            if indexPath.item == lastItem {
                                isLastRow = true
                            }
                        }
                        DispatchQueue.main.async {
                            chatCell.backgroundColor = UIColor.clear
                            chatCell.endDisplayingCell()
                            
                            if let message = QComment.comment(withUniqueId: uid){
                                self.viewDelegate?.viewDelegate?(view: self, didEndDisplayingCellForComment: message, cell: chatCell, indexPath: indexPath)
                                if isLastRow {
                                    self.isLastRowVisible = false
                                    self.viewDelegate?.viewDelegate?(didEndDisplayingLastMessage: self, comment: message)
                                }
                            }
                        }
                    }
                }
            }
        }
        
    }
    open func collectionView(_ collectionView: UICollectionView, shouldShowMenuForItemAt indexPath: IndexPath) -> Bool {
        if indexPath.section < self.messagesId.count {
            return true
        }
        return false
    }
    open func collectionView(_ collectionView: UICollectionView, canPerformAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) -> Bool {
        if indexPath.section < self.messagesId.count {
            let uid = self.messagesId[indexPath.section][indexPath.item]
            let comment = QComment.comment(withUniqueId: uid)!
            switch action.description {
            case "copy:":
                if comment.type == .text{ return true }
                return false
            case "resend":
                if !Qiscus.sharedInstance.connected || comment.status != .failed {
                    return false
                }else{
                    switch comment.type {
                    case .text, .contact:
                        return true
                    case .video,.image,.audio,.file,.document:
                        if let file = comment.file {
                            if QFileManager.isFileExist(inLocalPath: file.localPath){
                                return true
                            }else if file.url.contains("http"){
                                return true
                            }
                        }
                        return false
                    default:
                        return false
                    }
                }
            case "deleteComment":
                if comment.senderEmail == Qiscus.client.email && comment.status != .deleting && comment.status != .deleted {
                    return true
                }
                return false
            case "deleteForMe":
                if comment.status != .deleting && comment.status != .deleted {
                    return true
                }
                return false
            case "reply":
                if Qiscus.sharedInstance.connected{
                    switch comment.status {
                    case .failed, .sending, .pending, .deleted, .deleting, .deletePending :
                        return false
                    default:
                        switch comment.type {
                        case .postback,.account,.system,.card,.carousel:
                            return false
                        default:
                            return true
                        }
                    }
                }
                return false
            case "forward":
                if let viewDelegate = self.viewDelegate{
                    if !Qiscus.sharedInstance.connected || !viewDelegate.viewDelegate(enableForwardAction: self){
                        return false
                    }else {
                        switch comment.status {
                        case .failed, .sending, .pending: return false
                        default:
                            switch comment.type {
                            case .postback, .account,.system,.carousel:
                                return false
                            default:
                                return true
                            }
                        }
                    }
                }
                return false
            case "info":
                if let viewDelegate = self.viewDelegate {
                    if  !Qiscus.sharedInstance.connected ||
                        !viewDelegate.viewDelegate(enableInfoAction: self) ||
                        self.room!.type == .single || comment.senderEmail != Qiscus.client.email{
                        return false
                    }else {
                        switch comment.status {
                        case .failed, .sending, .pending: return false
                        default:
                            switch comment.type {
                            case .postback, .account,.system,.carousel:
                                return false
                            default:
                                return true
                            }
                        }
                    }
                }
                return false
            case "share":
                if Qiscus.sharedInstance.connected && ( comment.type == .image || comment.type == .video || comment.type == .audio || comment.type == .text || comment.type == .file || comment.type == .document) {
                    if let file = comment.file {
                        switch comment.type {
                        case .file:
                            if NSURL(string: file.url) != nil{
                                return true
                            }
                            break
                        case .text:
                            return true
                        default:
                            if QFileManager.isFileExist(inLocalPath: file.localPath){
                                return true
                            }
                            break
                        }
                    }
                }
                return false
            default:
                return false
            }
        }else{
            return false
        }
    }
    open func collectionView(_ collectionView: UICollectionView, performAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) {
        if action == #selector(UIResponderStandardEditActions.copy(_:)) {
            if self.messagesId.count > indexPath.section {
                let group = self.messagesId[indexPath.section]
                if group.count > indexPath.item {
                    let uid = group[indexPath.item]
                    let message = QComment.comment(withUniqueId: uid)!
                    if message.type == .text {
                        UIPasteboard.general.string = message.text
                    }
                }
            }
        }
    }
    // MARK: CollectionView delegateFlowLayout
    open func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        var height = CGFloat(0)
        if self.messagesId.count > section {
            if section == 0 {
                height = 35
            }else{
                if let uid = self.messagesId[section].first, let uidBefore = self.messagesId[section - 1].first, let group = QComment.comment(withUniqueId: uid), let groupBefore = QComment.comment(withUniqueId: uidBefore) {
                    if group.date != groupBefore.date {
                        height = 35
                    }
                }
            }
        }
        return CGSize(width: collectionView.bounds.size.width, height: height)
    }
    open func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
        var height = CGFloat(0)
        var width = CGFloat(0)
        if self.messagesId.count > section {
            var showAvatar = true
            if let uid = self.messagesId[section].first {
                if let firstMessage = QComment.comment(withUniqueId: uid) {
                    if let hideAvatar = self.configDelegate?.configDelegate?(hideLeftAvatarOn: self){
                        showAvatar = !hideAvatar
                    }
                    if showAvatar && firstMessage.senderEmail != Qiscus.client.email && firstMessage.type != .system {
                        height = 44
                        width = 44
                    }
                }
            }
        }
        return CGSize(width: width, height: height)
    }
    open func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        if self.messagesId.count > section {
            let uid = self.messagesId[section].first!
            if let firstMessage = QComment.comment(withUniqueId: uid) {
                var showAvatar = true
                if let hideAvatar = self.configDelegate?.configDelegate?(hideLeftAvatarOn: self){
                    showAvatar = !hideAvatar
                }
                if showAvatar && firstMessage.senderEmail != Qiscus.client.email && firstMessage.type != .system {
                    return UIEdgeInsets(top: 0, left: 6, bottom: -44, right: 0)
                }
            }
        }
        return UIEdgeInsets.zero
    }
    open func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if self.messagesId.count > indexPath.section {
            let group = self.messagesId[indexPath.section]
            if group.count > indexPath.item {
                let uid = group[indexPath.item]
                if let cachedSize = self.cacheCellSize[uid] {
                    return cachedSize
                } else {
                    if let message = QComment.comment(withUniqueId: uid) {
                        if let h = self.viewDelegate?.viewDelegate?(view: self, heightForComment: message) {
                            let size = CGSize(width: QiscusHelper.screenWidth() - 16, height: h.height)
                            self.cacheCellSize[uid] = size
                            return size
                        }else{
                            var size = message.textSize
                            size.width = QiscusHelper.screenWidth() - 16
                            size.height = self.cellHeightForComment(comment: message, defaultHeight: size.height, firstInSection: indexPath.item == 0)
                            self.cacheCellSize[uid] = size
                            return size
                        }
                    }
                }
            }
            return CGSize.zero
        }else{
            return CGSize(width: QiscusHelper.screenWidth() - 16, height: CGFloat(54))
        }
    }
}
