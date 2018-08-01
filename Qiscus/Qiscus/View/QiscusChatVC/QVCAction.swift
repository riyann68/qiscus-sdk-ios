//
//  QVCAction.swift
//  Example
//
//  Created by Ahmad Athaullah on 5/16/17.
//  Copyright © 2017 Ahmad Athaullah. All rights reserved.
//

import UIKit
import Photos
import MobileCoreServices
import SwiftyJSON
import ContactsUI

extension QiscusChatVC:CNContactPickerDelegate{
    //func shareContact
    public func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
        func share(name:String, value:String){
            let newComment = self.chatRoom!.newContactComment(name: name, value: value)
            self.postComment(comment: newComment)
            self.chatRoom!.post(comment: newComment)
            self.addCommentToCollectionView(comment: newComment)
        }
        let contactName = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespacesAndNewlines)
        let contactSheetController = UIAlertController(title: contactName, message: "select contact you want to share", preferredStyle: .actionSheet)
        
        let cancelActionButton = UIAlertAction(title: "Cancel", style: .cancel) { action -> Void in
            
        }
        contactSheetController.addAction(cancelActionButton)
        
        for phoneNumber in contact.phoneNumbers {
            let value = phoneNumber.value.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            var title = "\(value)"
            if let label = phoneNumber.label {
                let labelString = CNLabeledValue<CNPhoneNumber>.localizedString(forLabel: label)
                title = "\(labelString): \(value)"
            }
            let phoneButton = UIAlertAction(title: title, style: .default) { action -> Void in
                share(name: contactName, value: value)
            }
            contactSheetController.addAction(phoneButton)
        }
        for email in contact.emailAddresses {
            let value = email.value as String
            var title = "\(value)"
            if let label = email.label {
                let labelString = CNLabeledValue<NSString>.localizedString(forLabel: label)
                title = "\(labelString): \(value)"
            }
            let emailButton = UIAlertAction(title: title, style: .default) { action -> Void in
                share(name: contactName, value: value)
            }
            contactSheetController.addAction(emailButton)
        }
        picker.dismiss(animated: true, completion: nil)
        self.present(contactSheetController, animated: true, completion: nil)
    }
}
extension QiscusChatVC {
    @objc public func showLoading(_ text:String = "Loading"){
        if !self.presentingLoading {
            self.presentingLoading = true
            self.showQiscusLoading(withText: text, isBlocking: true)
        }
    }
    @objc public func dismissLoading(){
        self.presentingLoading = false
        self.dismissQiscusLoading()
    }
    @objc public func unlockChat(){
        self.archievedNotifTop.constant = 65
        UIView.animate(withDuration: 0.6, animations: {
            self.view.layoutIfNeeded()
        }, completion: { _ in
            self.archievedNotifView.isHidden = true
        })
    }
    @objc public func lockChat(){
        self.archived = true
        self.archievedNotifView.isHidden = false
        self.archievedNotifTop.constant = 0
        UIView.animate(withDuration: 0.6, animations: {
            self.view.layoutIfNeeded()
        }
        )
    }
    @objc func confirmUnlockChat(){
        self.unlockAction()
    }
    func showAlert(alert:UIAlertController){
        self.present(alert, animated: true, completion: nil)
    }
    func shareContact(){
        self.contactVC.delegate = self
        self.present(self.contactVC, animated: true, completion: nil)
    }
    func showAttachmentMenu(){
        let actionSheetController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        let cancelActionButton = UIAlertAction(title: "CANCEL".getLocalize(), style: .cancel) { action -> Void in
            Qiscus.printLog(text: "Cancel attach file")
        }
        actionSheetController.addAction(cancelActionButton)
        
        if Qiscus.shared.cameraUpload {
            let cameraActionButton = UIAlertAction(title: "CAMERA".getLocalize(), style: .default) { action -> Void in
                self.uploadFromCamera()
            }
            actionSheetController.addAction(cameraActionButton)
        }
        
        if Qiscus.shared.galeryUpload {
            let galeryActionButton = UIAlertAction(title: "GALLERY".getLocalize(), style: .default) { action -> Void in
                self.uploadImage()
            }
            actionSheetController.addAction(galeryActionButton)
        }
        
        if Qiscus.sharedInstance.iCloudUpload {
            let iCloudActionButton = UIAlertAction(title: "DOCUMENT".getLocalize(), style: .default) { action -> Void in
                self.iCloudOpen()
            }
            actionSheetController.addAction(iCloudActionButton)
        }
        
        if Qiscus.shared.contactShare {
            let contactActionButton = UIAlertAction(title: "CONTACT".getLocalize(), style: .default) { action -> Void in
                self.shareContact()
            }
            actionSheetController.addAction(contactActionButton)
        }
        if Qiscus.shared.locationShare {
            let contactActionButton = UIAlertAction(title: "CURRENT_LOCATION".getLocalize(), style: .default) { action -> Void in
                self.shareCurrentLocation()
            }
            actionSheetController.addAction(contactActionButton)
        }
        
        if let delegate = self.delegate{
            delegate.chatVC?(didTapAttachment: actionSheetController, viewController: self, onRoom: self.chatRoom)
        }
        
        self.present(actionSheetController, animated: true, completion: nil)
    }
    func shareCurrentLocation(){
        
        self.locationManager.requestWhenInUseAuthorization()
        
        if CLLocationManager.locationServicesEnabled() {
            switch CLLocationManager.authorizationStatus() {
            case .authorizedAlways, .authorizedWhenInUse:
                self.showLoading("LOADING_LOCATION".getLocalize())
                
                locationManager.delegate = self
                locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
                self.didFindLocation = false
                self.locationManager.startUpdatingLocation()
                break
            case .denied:
                self.showLocationAccessAlert()
                break
            case .restricted:
                self.showLocationAccessAlert()
                break
            case .notDetermined:
                self.showLocationAccessAlert()
                break
            }
        }else{
            self.showLocationAccessAlert()
        }
    }
    func getLinkPreview(url:String){
        
    }
    func hideLinkContainer(){
        Qiscus.uiThread.async { autoreleasepool{
            self.linkPreviewTopMargin.constant = 0
            UIView.animate(withDuration: 0.65, animations: {
                self.view.layoutIfNeeded()
            }, completion: nil)
            }}
    }
    
    func showNoConnectionToast(){
        QToasterSwift.toast(target: self, text: QiscusTextConfiguration.sharedInstance.noConnectionText, backgroundColor: UIColor(red: 0.9, green: 0,blue: 0,alpha: 0.8), textColor: UIColor.white)
    }
    // MARK: - Overriding back action
    
    func setTitle(title:String = "", withSubtitle:String? = nil){
        QiscusUIConfiguration.sharedInstance.copyright.chatTitle = title
        if withSubtitle != nil {
            QiscusUIConfiguration.sharedInstance.copyright.chatSubtitle = withSubtitle!
        }
        self.loadTitle()
    }
    
    
    func subscribeRealtime(){
        //        if let room = self.chatRoom {
        //            let delay = 3 * Double(NSEC_PER_SEC)
        //            let time = DispatchTime.now() + delay / Double(NSEC_PER_SEC)
        //
        //            DispatchQueue.main.asyncAfter(deadline: time, execute: {
        //                let typingChannel:String = "r/\(room.id)/\(room.id)/+/t"
        //                let readChannel:String = "r/\(room.id)/\(room.id)/+/r"
        //                let deliveryChannel:String = "r/\(room.id)/\(room.id)/+/d"
        //                Qiscus.shared.mqtt?.subscribe(typingChannel, qos: .qos1)
        //                Qiscus.shared.mqtt?.subscribe(readChannel, qos: .qos1)
        //                Qiscus.shared.mqtt?.subscribe(deliveryChannel, qos: .qos1)
        //                for participant in room.participants {
        //                    let userChannel = "u/\(participant.email)/s"
        //                    Qiscus.shared.mqtt?.subscribe(userChannel, qos: .qos1)
        //                }
        //            })
        //        }
    }
    func unsubscribeTypingRealtime(onRoom room:QRoom?){
        //        if room != nil {
        //            let channel = "r/\(room!.id)/\(room!.id)/+/t"
        //            Qiscus.shared.mqtt?.unsubscribe(channel)
        //        }
    }
    func iCloudOpen(){        
        if Qiscus.sharedInstance.connected{
            UINavigationBar.appearance().tintColor = UIColor.blue
            let documentPicker = UIDocumentPickerViewController(documentTypes: self.UTIs, in: UIDocumentPickerMode.import)
            documentPicker.delegate = self
            documentPicker.modalPresentationStyle = UIModalPresentationStyle.fullScreen
            self.present(documentPicker, animated: true, completion: nil)
        }else{
            self.showNoConnectionToast()
        }
    }
    
    func goToIPhoneSetting(){
        UIApplication.shared.openURL(URL(string: UIApplicationOpenSettingsURLString)!)
        let _ = self.navigationController?.popViewController(animated: true)
    }
    
    func loadTitle(){
        DispatchQueue.main.async {autoreleasepool{
            if self.chatTitle == nil || self.chatTitle == "" {
                if let room = self.chatRoom {
                    self.titleLabel.text = room.name
                    if self.roomAvatarImage == nil {
                        self.roomAvatar.image = Qiscus.image(named: "avatar")
                        room.loadAvatar(onSuccess: { (avatar) in
                            self.roomAvatar.image = avatar
                        }, onError: { (_) in
                            room.downloadRoomAvatar()
                        })
                    }
                }
            }
            else{
                self.titleLabel.text = self.chatTitle
                
                if let room = self.chatRoom {
                    self.roomAvatar.image = Qiscus.image(named: "avatar")
                    room.loadAvatar(onSuccess: { (avatar) in
                        self.roomAvatar.image = avatar
                    }, onError: { (_) in
                        room.downloadRoomAvatar()
                    })
                }
            }
            }}
    }
    func loadSubtitle(){
        
        if self.chatRoom != nil{
            if self.chatRoom!.isInvalidated {return}
            DispatchQueue.main.async {autoreleasepool{
                var prevSubtitle = ""
                if let currentSubtitle = self.subtitleLabel.text {
                    prevSubtitle = currentSubtitle
                }
                if self.chatSubtitle == nil || self.chatSubtitle == "" {
                    if let room = self.chatRoom {
                        if room.isInvalidated { return }
                        var subtitleString = ""
                        if room.type == .group{
                            if room.isPublicChannel {
                                subtitleString = "\(room.roomTotalParticipant) people"
                            } else {
                                subtitleString = "YOU".getLocalize()
                                for participant in room.participants {
                                    if participant.email != Qiscus.client.email {
                                        if let user = participant.user {
                                            subtitleString += ", \(user.fullname)"
                                        }
                                    }
                                }
                            }
                        }else{
                            if room.participants.count > 0 {
                                for participant in room.participants {
                                    if participant.email != Qiscus.client.email {
                                        if let user = participant.user {
                                            if user.presence == .offline{
                                                let lastSeenString = user.lastSeenString
                                                if lastSeenString != "" {
                                                    subtitleString = "LAST_SEEN".getLocalize(value: "\(user.lastSeenString)")
                                                }
                                            }else{
                                                subtitleString = "online"
                                            }
                                        }
                                        break
                                    }
                                }
                            }else{
                                subtitleString = ""
                            }
                        }
                        var frame = self.titleLabel.frame
                        
                        if subtitleString == "" && prevSubtitle == "" && frame.size.height == 17 && room.type == .single{
                            self.subtitleLabel.text = ""
                            frame.size.height = 30
                            UIView.animate(withDuration: 0.5, animations: {
                                self.titleLabel.frame = frame
                            })
                        }
                        else if subtitleString == "" && prevSubtitle != "" && room.type == .single{
                            // increase title height
                            self.subtitleLabel.text = ""
                            frame.size.height = 30
                            UIView.animate(withDuration: 0.5, animations: {
                                self.titleLabel.frame = frame
                            })
                        }else if subtitleString != "" && prevSubtitle == "" && room.type == .single{
                            // reduce titleHeight
                            frame.size.height = 17
                            UIView.animate(withDuration: 0.5, animations: {
                                self.titleLabel.frame = frame
                            }, completion: { (_) in
                                self.subtitleLabel.text = subtitleString
                                self.subtitleText = subtitleString
                            })
                        }else{
                            self.subtitleLabel.text = subtitleString
                            self.subtitleText = subtitleString
                        }
                        if subtitleString.contains("minute") || subtitleString.contains("hours") || subtitleString.contains("seconds"){
                            var delay = 60.0 * Double(NSEC_PER_SEC)
                            if subtitleString.contains("hours"){
                                delay = 3600.0 * Double(NSEC_PER_SEC)
                            }
                            let time = DispatchTime.now() + delay / Double(NSEC_PER_SEC)
                            DispatchQueue.main.asyncAfter(deadline: time, execute: {
                                self.loadSubtitle()
                            })
                        }
                    }
                }else{
                    self.subtitleLabel.text = self.chatSubtitle!
                    self.subtitleText = self.chatSubtitle!
                }
                }}
        }
    }
    func showLocationAccessAlert(){
        DispatchQueue.main.async{autoreleasepool{
            let text = QiscusTextConfiguration.sharedInstance.locationAccessAlertText
            let cancelTxt = QiscusTextConfiguration.sharedInstance.alertCancelText
            let settingTxt = QiscusTextConfiguration.sharedInstance.alertSettingText
            QPopUpView.showAlert(withTarget: self, message: text, firstActionTitle: settingTxt, secondActionTitle: cancelTxt,
                                 doneAction: {
                                    self.goToIPhoneSetting()
            },
                                 cancelAction: {}
            )
            }}
    }
    func showPhotoAccessAlert(){
        DispatchQueue.main.async(execute: {
            let text = QiscusTextConfiguration.sharedInstance.galeryAccessAlertText
            let cancelTxt = QiscusTextConfiguration.sharedInstance.alertCancelText
            let settingTxt = QiscusTextConfiguration.sharedInstance.alertSettingText
            QPopUpView.showAlert(withTarget: self, message: text, firstActionTitle: settingTxt, secondActionTitle: cancelTxt,
                                 doneAction: {
                                    self.goToIPhoneSetting()
            },
                                 cancelAction: {}
            )
        })
    }
    func showCameraAccessAlert(){
        DispatchQueue.main.async(execute: {
            let text = QiscusTextConfiguration.sharedInstance.cameraAccessAlertText
            let cancelTxt = QiscusTextConfiguration.sharedInstance.alertCancelText
            let settingTxt = QiscusTextConfiguration.sharedInstance.alertSettingText
            QPopUpView.showAlert(withTarget: self, message: text, firstActionTitle: settingTxt, secondActionTitle: cancelTxt,
                                 doneAction: {
                                    self.goToIPhoneSetting()
            },
                                 cancelAction: {}
            )
        })
    }
    func showMicrophoneAccessAlert(){
        DispatchQueue.main.async(execute: {
            let text = QiscusTextConfiguration.sharedInstance.microphoneAccessAlertText
            let cancelTxt = QiscusTextConfiguration.sharedInstance.alertCancelText
            let settingTxt = QiscusTextConfiguration.sharedInstance.alertSettingText
            QPopUpView.showAlert(withTarget: self, message: text, firstActionTitle: settingTxt, secondActionTitle: cancelTxt,
                                 doneAction: {
                                    self.goToIPhoneSetting()
            },
                                 cancelAction: {}
            )
        })
    }
    func goToGaleryPicker(){
        DispatchQueue.main.async(execute: {
            let picker = UIImagePickerController()
            picker.delegate = self
            picker.allowsEditing = false
            picker.sourceType = UIImagePickerControllerSourceType.photoLibrary
            picker.mediaTypes = [kUTTypeMovie as String, kUTTypeImage as String]
            self.present(picker, animated: true, completion: nil)
        })
    }
    @objc func goToTitleAction(){
        self.inputBarBottomMargin.constant = 0
        self.view.layoutIfNeeded()
        if let delegate = self.delegate {
            delegate.chatVC?(titleAction: self, room: self.chatRoom, data:self.data)
        }
    }
    //    func scrollToBottom(_ animated:Bool = false){
    //        self.collectionView.scrollToBottom()
    ////        if self.chatRoom != nil {
    ////            if self.collectionView.numberOfSections > 0 {
    ////                let section = self.collectionView.numberOfSections - 1
    ////                if self.collectionView.numberOfItems(inSection: section) > 0 {
    ////                    let item = self.collectionView.numberOfItems(inSection: section) - 1
    ////                    let lastIndexPath = IndexPath(row: item, section: section)
    ////                    self.collectionView.scrollToItem(at: lastIndexPath, at: .bottom, animated: animated)
    ////                    if self.isPresence {
    ////                        self.chatRoom!.readAll()
    ////                    }
    ////                }
    ////            }
    ////        }
    //    }
    
    func setNavigationColor(_ color:UIColor, tintColor:UIColor){
        self.topColor = color
        self.bottomColor = color
        self.tintColor = tintColor
        self.navigationController?.navigationBar.verticalGradientColor(topColor, bottomColor: bottomColor)
        self.navigationController?.navigationBar.tintColor = tintColor
        let _ = self.view
        self.sendButton.tintColor = self.topColor
        if self.inputText.value == "" {
            self.sendButton.isEnabled = false
        }
        self.attachButton.tintColor = self.topColor
        self.bottomButton.tintColor = self.topColor
        self.recordButton.tintColor = self.topColor
        self.cancelRecordButton.tintColor = self.topColor
        self.emptyChatImage.tintColor = self.bottomColor
    }
    
    @objc func sendMessage(){
        //if Qiscus.shared.connected{
        if !self.isRecording {
            let value = self.inputText.value.trimmingCharacters(in: .whitespacesAndNewlines)
            if value != "" {
                var type:QCommentType = .text
                var payload:JSON? = nil
                if let reply = self.replyData {
                    var senderName = reply.senderName
                    if let user = reply.sender{
                        senderName = user.fullname
                    }
                    var payloadArray: [(String,Any)] = [
                        ("replied_comment_sender_email",reply.senderEmail),
                        ("replied_comment_id", reply.id),
                        ("text", value),
                        ("replied_comment_message", reply.text),
                        ("replied_comment_sender_username", senderName),
                        ("replied_comment_payload", reply.data)
                    ]
                    if reply.type == .location || reply.type == .contact {
                        payloadArray.append(("replied_comment_type",reply.typeRaw))
                    }
                    payload = JSON(dictionaryLiteral: payloadArray)
                    type = .reply
                    self.replyData = nil
                }
                self.inputText.clearValue()
                
                DispatchQueue.main.async { autoreleasepool{
                    self.inputText.text = ""
                    self.minInputHeight.constant = 32
                    self.sendButton.isEnabled = false
                    self.inputText.layoutIfNeeded()
                    }
                }
                
                guard let chatRoomObj = chatRoom else {return}
                let comment = chatRoomObj.newComment(text: value, payload: payload, type: type)
                self.postComment(comment: comment)
                
                self.addCommentToCollectionView(comment: comment)
            }
        }else{
            if !self.processingAudio {
                self.processingAudio = true
                self.finishRecording()
            }
        }
        //        }else{
        //            self.showNoConnectionToast()
        //            if self.isRecording {
        //                self.cancelRecordVoice()
        //            }
        //        }
    }
    
    func addCommentToCollectionView(comment: QComment) {
        var section = 0
        var item = 0
        if comment.sender?.email == Qiscus.client.email {
            if let lastUid = self.collectionView.messagesId.last?.last {
                if let lastComment = QComment.comment(withUniqueId: lastUid) {
                    section = self.collectionView.messagesId.count - 1
                    item = (self.collectionView.messagesId.last?.count)! - 1
                    
                    if lastComment.date == comment.date && lastComment.sender?.email == comment.sender?.email {
                        var lastGroup = self.collectionView.messagesId.last
                        lastGroup?.append(comment.uniqueId)
                        
                        self.collectionView.messagesId.removeLast()
                        self.collectionView.messagesId.append(lastGroup!)
                        
                        let newIndexPath = IndexPath(row: item + 1, section: section)
                        
                        self.collectionView.performBatchUpdates({
                            self.collectionView.insertItems(at: [newIndexPath])
                        }, completion: { (success) in
                            self.collectionView.layoutIfNeeded()
                            self.collectionView.scrollToBottom(true)
                            
                            if lastComment.cellPos == .single {
                                lastComment.updateCellPos(cellPos: .first)
                            }else if lastComment.cellPos == .last {
                                lastComment.updateCellPos(cellPos: .middle)
                            }
                            let lastIndexPath = IndexPath(row: item, section: section)
                            self.collectionView.reloadItems(at: [lastIndexPath])
                            
                        })
                        
                    } else {
                        self.collectionView.messagesId.append([comment.uniqueId])
                        let newIndexPath = IndexPath(row: 0, section: section + 1)
                        comment.updateCellPos(cellPos: .single)
                        self.collectionView.performBatchUpdates({
                            self.collectionView.insertSections(IndexSet(integer: section + 1))
                            self.collectionView.insertItems(at: [newIndexPath])
                        }, completion: { (success) in
                            self.collectionView.layoutIfNeeded()
                            self.collectionView.scrollToBottom(true)
                        })
                    }
                }
                
                
            } else {
                self.collectionView.messagesId.append([comment.uniqueId])
                let newIndexPath = IndexPath(row: 0, section: 0)
                comment.updateCellPos(cellPos: .single)
                self.collectionView.reloadData()
            }
        }
    }
    
    func uploadImage(){
        view.endEditing(true)
        if Qiscus.sharedInstance.connected{
            let photoPermissions = PHPhotoLibrary.authorizationStatus()
            
            if(photoPermissions == PHAuthorizationStatus.authorized){
                self.goToGaleryPicker()
            }else if(photoPermissions == PHAuthorizationStatus.notDetermined){
                PHPhotoLibrary.requestAuthorization({(status:PHAuthorizationStatus) in
                    switch status{
                    case .authorized:
                        self.goToGaleryPicker()
                        break
                    case .denied:
                        self.showPhotoAccessAlert()
                        break
                    default:
                        self.showPhotoAccessAlert()
                        break
                    }
                })
            }else{
                self.showPhotoAccessAlert()
            }
        }else{
            self.showNoConnectionToast()
        }
    }
    func uploadFromCamera(){
        view.endEditing(true)
        if Qiscus.sharedInstance.connected{
            if AVCaptureDevice.authorizationStatus(for: AVMediaType.video) ==  AVAuthorizationStatus.authorized
            {
                DispatchQueue.main.async(execute: {
                    let picker = UIImagePickerController()
                    picker.delegate = self
                    picker.allowsEditing = false
                    picker.mediaTypes = [(kUTTypeImage as String),(kUTTypeMovie as String)]
                    
                    picker.sourceType = UIImagePickerControllerSourceType.camera
                    self.present(picker, animated: true, completion: nil)
                })
            }else{
                AVCaptureDevice.requestAccess(for: AVMediaType.video, completionHandler: { (granted :Bool) -> Void in
                    if granted {
                        PHPhotoLibrary.requestAuthorization({(status:PHAuthorizationStatus) in
                            switch status{
                            case .authorized:
                                let picker = UIImagePickerController()
                                picker.delegate = self
                                picker.allowsEditing = false
                                picker.mediaTypes = [(kUTTypeImage as String),(kUTTypeMovie as String)]
                                
                                picker.sourceType = UIImagePickerControllerSourceType.camera
                                self.present(picker, animated: true, completion: nil)
                                break
                            case .denied:
                                self.showPhotoAccessAlert()
                                break
                            default:
                                self.showPhotoAccessAlert()
                                break
                            }
                        })
                    }else{
                        DispatchQueue.main.async(execute: {
                            self.showCameraAccessAlert()
                        })
                    }
                })
            }
        }else{
            self.showNoConnectionToast()
        }
    }
    @objc func recordVoice(){
        self.prepareRecording()
    }
    func startRecording(){
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let time = Double(Date().timeIntervalSince1970)
        let timeToken = UInt64(time * 10000)
        let fileName = "audio-\(timeToken).m4a"
        let audioURL = documentsPath.appendingPathComponent(fileName)
        print ("audioURL: \(audioURL)")
        self.recordingURL = audioURL
        let settings:[String : Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: Float(44100),
            AVNumberOfChannelsKey: Int(2),
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        Qiscus.uiThread.async {autoreleasepool{
            self.recordButton.isHidden = true
            self.sendButton.isHidden = false
            self.recordBackground.clipsToBounds = true
            let inputWidth = self.inputText.frame.width
            let recorderWidth = inputWidth + 17
            self.recordViewLeading.constant = 0 - recorderWidth
            
            UIView.animate(withDuration: 0.5, animations: {
                self.inputText.isHidden = true
                self.cancelRecordButton.isHidden = false
                self.view.layoutIfNeeded()
            }, completion: { success in
                
                var timerLabel = self.recordBackground.viewWithTag(543) as? UILabel
                if timerLabel == nil {
                    timerLabel = UILabel(frame: CGRect(x: 34, y: 5, width: 40, height: 20))
                    timerLabel!.backgroundColor = UIColor.clear
                    timerLabel!.textColor = UIColor.white
                    timerLabel!.tag = 543
                    timerLabel!.font = UIFont.systemFont(ofSize: 12)
                    self.recordBackground.addSubview(timerLabel!)
                }
                timerLabel!.text = "00:00"
                
                var waveView = self.recordBackground.viewWithTag(544) as? QSiriWaveView
                if waveView == nil {
                    let backgroundFrame = self.recordBackground.bounds
                    waveView = QSiriWaveView(frame: CGRect(x: 76, y: 2, width: backgroundFrame.width - 110, height: 28))
                    waveView!.waveColor = UIColor.white
                    waveView!.numberOfWaves = 6
                    waveView!.primaryWaveWidth = 1.0
                    waveView!.secondaryWaveWidth = 0.75
                    waveView!.tag = 544
                    waveView!.layer.cornerRadius = 14.0
                    waveView!.clipsToBounds = true
                    waveView!.backgroundColor = UIColor.clear
                    self.recordBackground.addSubview(waveView!)
                }
                do {
                    self.recorder = nil
                    if self.recorder == nil {
                        self.recorder = try AVAudioRecorder(url: audioURL, settings: settings)
                    }
                    self.recorder?.prepareToRecord()
                    self.recorder?.isMeteringEnabled = true
                    self.recorder?.record()
                    self.sendButton.isEnabled = true
                    self.recordDuration = 0
                    if self.recordTimer != nil {
                        self.recordTimer?.invalidate()
                        self.recordTimer = nil
                    }
                    self.recordTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(QiscusChatVC.updateTimer), userInfo: nil, repeats: true)
                    self.isRecording = true
                    let displayLink = CADisplayLink(target: self, selector: #selector(QiscusChatVC.updateAudioMeter))
                    displayLink.add(to: RunLoop.current, forMode: RunLoopMode.commonModes)
                } catch {
                    Qiscus.printLog(text: "error recording")
                }
            })
            }}
    }
    func prepareRecording(){
        do {
            try recordingSession.setCategory(AVAudioSessionCategoryPlayAndRecord)
            try recordingSession.setActive(true)
            recordingSession.requestRecordPermission() { [unowned self] allowed in
                if allowed {
                    self.startRecording()
                } else {
                    Qiscus.uiThread.async { autoreleasepool{
                        self.showMicrophoneAccessAlert()
                        }}
                }
            }
        } catch {
            Qiscus.uiThread.async { autoreleasepool{
                self.showMicrophoneAccessAlert()
                }}
        }
    }
    @objc func updateTimer(){
        if let timerLabel = self.recordBackground.viewWithTag(543) as? UILabel {
            self.recordDuration += 1
            let minutes = Int(self.recordDuration / 60)
            let seconds = self.recordDuration % 60
            var minutesString = "\(minutes)"
            if minutes < 10 {
                minutesString = "0\(minutes)"
            }
            var secondsString = "\(seconds)"
            if seconds < 10 {
                secondsString = "0\(seconds)"
            }
            timerLabel.text = "\(minutesString):\(secondsString)"
        }
    }
    @objc func updateAudioMeter(){
        if let audioRecorder = self.recorder{
            audioRecorder.updateMeters()
            let normalizedValue:CGFloat = pow(10.0, CGFloat(audioRecorder.averagePower(forChannel: 0)) / 20)
            Qiscus.uiThread.async {autoreleasepool{
                if let waveView = self.recordBackground.viewWithTag(544) as? QSiriWaveView {
                    waveView.update(withLevel: normalizedValue)
                }
                }}
        }
    }
    func finishRecording(){
        self.recorder?.stop()
        self.recorder = nil
        self.recordViewLeading.constant = 8
        Qiscus.uiThread.async {autoreleasepool{
            UIView.animate(withDuration: 0.5, animations: {
                self.inputText.isHidden = false
                self.cancelRecordButton.isHidden = true
                self.view.layoutIfNeeded()
            }) { (_) in
                self.recordButton.isHidden = false
                self.sendButton.isHidden = true
                if self.recordTimer != nil {
                    self.recordTimer?.invalidate()
                    self.recordTimer = nil
                    self.recordDuration = 0
                }
                self.isRecording = false
                self.processingAudio = false
            }
            }}
        if let audioURL = self.recordingURL {
            var fileContent: Data?
            fileContent = try! Data(contentsOf: audioURL)
            let mediaSize = Double(fileContent!.count) / 1024.0
            if mediaSize > Qiscus.maxUploadSizeInKB {
                self.showFileTooBigAlert()
                return
            }
            let fileName = audioURL.lastPathComponent
            
            let newComment = self.chatRoom!.newFileComment(type: .audio, filename: fileName, data: fileContent!)
            
            self.addCommentToCollectionView(comment: newComment)
            self.chatRoom!.upload(comment: newComment, onSuccess: { (roomResult, commentResult) in
                self.postComment(comment: commentResult)
            }, onError: { (roomResult, commentResult, error) in
                Qiscus.printLog(text: "Error: \(error)")
            })
        }
    }
    @objc func cancelRecordVoice(){
        self.recordViewLeading.constant = 8
        Qiscus.uiThread.async { autoreleasepool{
            UIView.animate(withDuration: 0.5, animations: {
                self.inputText.isHidden = false
                self.cancelRecordButton.isHidden = true
                self.view.layoutIfNeeded()
            }) { (_) in
                self.recordButton.isHidden = false
                self.sendButton.isHidden = true
                if self.recordTimer != nil {
                    self.recordTimer?.invalidate()
                    self.recordTimer = nil
                    self.recordDuration = 0
                }
                self.isRecording = false
            }
            }}
    }
    
    func postFile(filename:String, data:Data? = nil, type:QiscusFileType, thumbImage:UIImage? = nil){
        if Qiscus.sharedInstance.connected {
            let newComment = self.chatRoom!.newFileComment(type: type, filename: filename, data: data, thumbImage: thumbImage)
            self.addCommentToCollectionView(comment: newComment)
            self.chatRoom!.upload(comment: newComment, onSuccess: { (roomResult, commentResult) in
                self.postComment(comment: commentResult)
            }, onError: { (roomResult, commentResult, error) in
                Qiscus.printLog(text: "Error: \(error)")
            })
        }else{
            self.showNoConnectionToast()
        }
    }
    
    // MARK: - Back Button
    class func backButton(_ target: UIViewController, action: Selector) -> UIBarButtonItem{
        let backIcon = UIImageView()
        backIcon.contentMode = .scaleAspectFit
        
        let image = Qiscus.image(named: "ic_back")?.withRenderingMode(UIImageRenderingMode.alwaysTemplate)
        backIcon.image = image
        backIcon.tintColor = QiscusChatVC.currentNavbarTint
        
        if UIApplication.shared.userInterfaceLayoutDirection == .leftToRight {
            backIcon.frame = CGRect(x: 0,y: 11,width: 13,height: 22)
        }else{
            backIcon.frame = CGRect(x: 22,y: 11,width: 13,height: 22)
        }
        
        let backButton = UIButton(frame:CGRect(x: 0,y: 0,width: 23,height: 44))
        backButton.addSubview(backIcon)
        backButton.addTarget(target, action: action, for: UIControlEvents.touchUpInside)
        return UIBarButtonItem(customView: backButton)
    }
    
    func setGradientChatNavigation(withTopColor topColor:UIColor, bottomColor:UIColor, tintColor:UIColor){
        self.topColor = topColor
        self.bottomColor = bottomColor
        self.tintColor = tintColor
        self.navigationController?.navigationBar.verticalGradientColor(self.topColor, bottomColor: self.bottomColor)
        self.navigationController?.navigationBar.tintColor = self.tintColor
        let _ = self.view
        self.sendButton.tintColor = self.topColor
        if self.inputText.value == "" {
            self.sendButton.isEnabled = false
        }
        self.attachButton.tintColor = self.topColor
        self.bottomButton.tintColor = self.topColor
        self.recordButton.tintColor = self.topColor
        self.cancelRecordButton.tintColor = self.topColor
        self.emptyChatImage.tintColor = self.bottomColor
        
    }
    // MARK: - Load DataSource on firstTime
    func loadData(){
        if self.chatRoomId != nil && !self.isPublicChannel {
            self.chatService.room(withId: self.chatRoomId!, withMessage: self.chatMessage)
        }else if self.chatUser != nil {
            self.chatService.room(withUser: self.chatUser!, distincId: self.chatDistinctId, optionalData: self.chatData, withMessage: self.chatMessage)
        }else if self.chatNewRoomUsers.count > 0 {
            self.chatService.createRoom(withUsers: self.chatNewRoomUsers, roomName: self.chatTitle!, optionalData: self.chatData, withMessage: self.chatMessage)
        }else if self.chatRoomUniqueId != nil && self.isPublicChannel {
            self.chatService.room(withUniqueId: self.chatRoomUniqueId!, title: self.chatTitle!, avatarURL: self.chatAvatarURL, withMessage: self.chatMessage)
        }else {
            self.dismissLoading()
        }
    }
    func forward(comment:QComment){
        if let delegate = self.delegate {
            delegate.chatVC?(viewController: self, onForwardComment: comment, data: self.data)
        }
    }
    func info(comment:QComment){
        if let delegate = self.delegate {
            delegate.chatVC?(viewController: self, infoActionComment: comment, data: self.data)
        }
    }
    public func hideInputBar(){
        self.inputBarHeight.constant = 0
        self.minInputHeight.constant = 0
    }
    open func reply(toComment comment:QComment?){
        if comment == nil {
            Qiscus.uiThread.async { autoreleasepool{
                self.linkPreviewTopMargin.constant = 0
                UIView.animate(withDuration: 0.65, animations: {
                    self.view.layoutIfNeeded()
                }, completion: {(_) in
                    if self.inputText.value == "" {
                        self.sendButton.isEnabled = false
                        self.sendButton.isHidden = true
                        self.recordButton.isHidden = false
                        self.linkImage.image = nil
                    }
                })
                }}
        }
        else{
            Qiscus.uiThread.async {autoreleasepool{
                switch comment!.type {
                case .text:
                    self.linkDescription.text = comment!.text
                    self.linkImageWidth.constant = 0
                    break
                case .document:
                    self.linkImage.contentMode = .scaleAspectFill
                    if let file = comment!.file {
                        if QFileManager.isFileExist(inLocalPath: file.localThumbPath){
                            self.linkImage.loadAsync(fromLocalPath: file.localThumbPath, onLoaded: { (image, _) in
                                self.linkImage.image = image
                            })
                        }
                        else if QFileManager.isFileExist(inLocalPath: file.localMiniThumbPath){
                            self.linkImage.loadAsync(fromLocalPath: file.localMiniThumbPath, onLoaded: { (image, _) in
                                self.linkImage.image = image
                            })
                        }
                        else{
                            self.linkImage.loadAsync(file.thumbURL, onLoaded: { (image, _) in
                                self.linkImage.image = image
                            })
                        }
                        self.linkImageWidth.constant = 55
                        var description = "\(file.filename)\nPDF File"
                        if file.pages > 0 {
                            description = "\(description), \(file.pages) page"
                        }
                        if file.sizeString != "" {
                            description = "\(description), \(file.sizeString)"
                        }
                        self.linkDescription.text = description
                    }
                    break
                case .video, .image:
                    self.linkImage.contentMode = .scaleAspectFill
                    if let file = comment!.file {
                        if comment!.type == .video || comment!.type == .image {
                            if QFileManager.isFileExist(inLocalPath: file.localThumbPath){
                                self.linkImage.loadAsync(fromLocalPath: file.localThumbPath, onLoaded: { (image, _) in
                                    self.linkImage.image = image
                                })
                            }
                            else if QFileManager.isFileExist(inLocalPath: file.localMiniThumbPath){
                                self.linkImage.loadAsync(fromLocalPath: file.localMiniThumbPath, onLoaded: { (image, _) in
                                    self.linkImage.image = image
                                })
                            }
                            else{
                                self.linkImage.loadAsync(file.thumbURL, onLoaded: { (image, _) in
                                    self.linkImage.image = image
                                })
                            }
                            self.linkImageWidth.constant = 55
                        }
                        var description = "\(file.filename)\n"
                        if file.sizeString != "" {
                            description = "\(description), \(file.sizeString)"
                        }
                        self.linkDescription.text = file.filename
                    }
                    break
                case .audio:
                    self.linkImageWidth.constant = 0
                    if let file = comment!.file {
                        var description = "\(file.filename)\nAUDIO FILE"
                        
                        if file.sizeString != "" {
                            description = "\(description), \(file.sizeString)"
                        }
                        self.linkDescription.text = description
                    }
                    break
                case .file:
                    self.linkImageWidth.constant = 0
                    if let file = comment!.file {
                        var description = "\(file.filename)\n\(file.ext.uppercased()) FILE"
                        
                        if file.sizeString != "" {
                            description = "\(description), \(file.sizeString)"
                        }
                        self.linkDescription.text = description
                    }
                    break
                case .location:
                    let payload = JSON(parseJSON: comment!.data)
                    self.linkImage.contentMode = .scaleAspectFill
                    self.linkImage.image = Qiscus.image(named: "map_ico")
                    self.linkImageWidth.constant = 55
                    self.linkDescription.text = "\(payload["name"].stringValue) - \(payload["address"].stringValue)"
                    break
                case .contact:
                    let payload = JSON(parseJSON: comment!.data)
                    self.linkImage.contentMode = .top
                    self.linkImage.image = Qiscus.image(named: "contact")
                    self.linkImageWidth.constant = 55
                    self.linkDescription.text = "\(payload["name"].stringValue) - \(payload["value"].stringValue)"
                    break
                case .reply:
                    self.linkDescription.text = comment!.text
                    self.linkImageWidth.constant = 0
                    break
                default:
                    break
                }
                
                if let user = self.replyData!.sender {
                    self.linkTitle.text = user.fullname
                }else{
                    self.linkTitle.text = comment!.senderName
                }
                self.linkPreviewTopMargin.constant = -65
                
                UIView.animate(withDuration: 0.35, animations: {
                    self.view.layoutIfNeeded()
                    if self.lastVisibleRow != nil {
                        self.collectionView.scrollToItem(at: self.lastVisibleRow!, at: .bottom, animated: true)
                    }
                }, completion: { (_) in
                    if self.inputText.value == "" {
                        self.sendButton.isEnabled = false
                    }else{
                        self.sendButton.isEnabled = true
                    }
                    self.sendButton.isHidden = false
                    self.recordButton.isHidden = true
                })
                }}
        }
    }
    func didTapActionButton(withData data:JSON){
        if Qiscus.sharedInstance.connected{
            let postbackType = data["type"]
            let payload = data["payload"]
            switch postbackType {
            case "link":
                let urlString = payload["url"].stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                let urlArray = urlString.components(separatedBy: "/")
                func openInBrowser(){
                    if let url = URL(string: urlString) {
                        UIApplication.shared.openURL(url)
                    }
                }
                
                if urlArray.count > 2 {
                    if urlArray[2].lowercased().contains("instagram.com") {
                        var instagram = "instagram://app"
                        if urlArray.count == 4 || (urlArray.count == 5 && urlArray[4] == ""){
                            let usernameIG = urlArray[3]
                            instagram = "instagram://user?username=\(usernameIG)"
                        }
                        if let instagramURL =  URL(string: instagram) {
                            if UIApplication.shared.canOpenURL(instagramURL) {
                                UIApplication.shared.openURL(instagramURL)
                            }else{
                                openInBrowser()
                            }
                        }
                    }else{
                        openInBrowser()
                    }
                }else{
                    openInBrowser()
                }
                
                
                break
            default:
                let text = data["label"].stringValue
                let type = "button_postback_response"
                
                if let room = self.chatRoom {
                    let newComment = room.newComment(text: text)
                    room.post(comment: newComment, type: type, payload: payload)
                }
                break
            }
            
        }else{
            Qiscus.uiThread.async { autoreleasepool{
                self.showNoConnectionToast()
                }}
        }
    }
    
    @objc internal func userTyping(_ notification: Notification){
        if let userInfo = notification.userInfo {
            let user = userInfo["user"] as! QUser
            let typing = userInfo["typing"] as! Bool
            let room = userInfo["room"] as! QRoom
            if room.isInvalidated || user.isInvalidated {
                return
            }
            if let currentRoom = self.chatRoom {
                if currentRoom.isInvalidated { return }
                if currentRoom.id == room.id {
                    if !processingTyping{
                        self.userTypingChanged(user: user, typing: typing)
                    }
                }
            }
        }
    }
    
    open func userTypingChanged(user: QUser, typing:Bool){
        if user.isInvalidated {return}
        if !typing {
            self.subtitleLabel.text = self.subtitleText
        }else{
            guard let room = self.chatRoom else {return}
            if room.type == .single {
                self.subtitleLabel.text = "is typing ..."
            }else{
                self.subtitleLabel.text = "\(user.fullname) is typing ..."
            }
        }
    }
}
