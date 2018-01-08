//
//  QiscusUploaderVC.swift
//  Example
//
//  Created by Ahmad Athaullah on 9/12/17.
//  Copyright © 2017 Ahmad Athaullah. All rights reserved.
//

import UIKit
enum QUploaderType {
    case image
    case video
}

class QiscusUploaderVC: UIViewController, UIScrollViewDelegate {

    @IBOutlet weak var sendButton: UIButton!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var imageView: UIImageView!
    
    @IBOutlet weak var inputBottom: NSLayoutConstraint!
    @IBOutlet weak var mediaCaption: ChatInputText!
    @IBOutlet weak var minInputHeight: NSLayoutConstraint!
    
    var chatView:QiscusChatVC?
    var type = QUploaderType.image
    var data   : Data?
    var fileName :String?
    var room    : QRoom?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.qiscusAutoHideKeyboard()
        self.scrollView.delegate = self
        self.scrollView.minimumZoomScale = 1.0
        self.scrollView.maximumZoomScale = 4.0
        let sendImage = Qiscus.image(named: "send")?.withRenderingMode(.alwaysTemplate)
        self.sendButton.setImage(sendImage, for: .normal)
        self.sendButton.tintColor = Qiscus.shared.styleConfiguration.color.topColor
        self.mediaCaption.chatInputDelegate = self
        self.mediaCaption.font = Qiscus.style.chatFont
        self.mediaCaption.placeholder = QiscusTextConfiguration.sharedInstance.captionPlaceholder
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if self.data != nil {
            if type == .image {
                self.imageView.image = UIImage(data: self.data!)
            }
        }
        let center: NotificationCenter = NotificationCenter.default
        center.addObserver(self, selector: #selector(QiscusUploaderVC.keyboardWillHide(_:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        center.addObserver(self, selector: #selector(QiscusUploaderVC.keyboardChange(_:)), name: NSNotification.Name.UIKeyboardWillChangeFrame, object: nil)
        self.navigationController?.isNavigationBarHidden = true
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
    }
    override func viewWillDisappear(_ animated: Bool) {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIKeyboardWillChangeFrame, object: nil)
        self.navigationController?.isNavigationBarHidden = false
    }
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return self.imageView
    }
    
    @IBAction func sendMedia(_ sender: Any) {
        if room != nil {
            if type == .image {
                let newComment = self.room!.newFileComment(type: .image, filename: self.fileName!, caption: self.mediaCaption.value, data: self.data!)
                self.room!.upload(comment: newComment, onSuccess: { (roomResult, commentResult) in
                    if let chatView = self.chatView {
                        chatView.postComment(comment: commentResult)
                    }
                }, onError: { (roomResult, commentResult, error) in
                    Qiscus.printLog(text:"Error: \(error)")
                })
                let _ = self.navigationController?.popViewController(animated: true)
            }
        }
    }
    // MARK: - Keyboard Methode
    @objc func keyboardWillHide(_ notification: Notification){
        let info: NSDictionary = (notification as NSNotification).userInfo! as NSDictionary
        
        let animateDuration = info[UIKeyboardAnimationDurationUserInfoKey] as! Double
        self.inputBottom.constant = 0
        UIView.animate(withDuration: animateDuration, delay: 0, options: UIViewAnimationOptions(), animations: {
            self.view.layoutIfNeeded()
            
        }, completion: nil)
    }
    @objc func keyboardChange(_ notification: Notification){
        let info:NSDictionary = (notification as NSNotification).userInfo! as NSDictionary
        let keyboardSize = (info[UIKeyboardFrameEndUserInfoKey] as! NSValue).cgRectValue
        
        let keyboardHeight: CGFloat = keyboardSize.height
        let animateDuration = info[UIKeyboardAnimationDurationUserInfoKey] as! Double
        
        self.inputBottom.constant = keyboardHeight
        UIView.animate(withDuration: animateDuration, delay: 0, options: UIViewAnimationOptions(), animations: {
            self.view.layoutIfNeeded()
        }, completion: nil)
    }

    @IBAction func cancel(_ sender: Any) {
        let _ = self.navigationController?.popViewController(animated: true)
    }
}

extension QiscusUploaderVC: ChatInputTextDelegate {
    // MARK: - ChatInputTextDelegate Delegate
    open func chatInputTextDidChange(chatInput input: ChatInputText, height: CGFloat) {
        QiscusBackgroundThread.async { autoreleasepool{
            let currentHeight = self.minInputHeight.constant
            if currentHeight != height {
                DispatchQueue.main.async { autoreleasepool{
                    self.minInputHeight.constant = height
                    input.layoutIfNeeded()
                }}
            }
            }}
    }
    open func valueChanged(value:String){
        
    }
    open func chatInputDidEndEditing(chatInput input: ChatInputText) {
        //self.sendStopTyping()
    }
    
}
