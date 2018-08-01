//
//  QiscusUploaderVC.swift
//  Example
//
//  Created by Ahmad Athaullah on 9/12/17.
//  Copyright © 2017 Ahmad Athaullah. All rights reserved.
//

import UIKit
import Photos
import MobileCoreServices
enum QUploaderType {
    case image
    case video
}

class QiscusUploaderVC: UIViewController, UIScrollViewDelegate {

    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var sendButton: UIButton!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var deleteButton: UIButton!
    @IBOutlet weak var imageCollection: UICollectionView!
    @IBOutlet weak var inputBottom: NSLayoutConstraint!
    @IBOutlet weak var mediaCaption: ChatInputText!
    @IBOutlet weak var minInputHeight: NSLayoutConstraint!
    @IBOutlet weak var mediaBottomMargin: NSLayoutConstraint!
    
    var chatView:QiscusChatVC?
    var type = QUploaderType.image
    var data   : Data?
    var fileName :String?
    var room    : QRoom?
    var imageData: [QComment] = []
    var selectedImageIndex: Int = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.qiscusAutoHideKeyboard()
        self.scrollView.delegate = self
        self.scrollView.minimumZoomScale = 1.0
        self.scrollView.maximumZoomScale = 4.0
        let sendImage = Qiscus.image(named: "send")?.withRenderingMode(.alwaysTemplate)
        self.sendButton.setImage(sendImage, for: .normal)
        self.sendButton.tintColor = Qiscus.shared.styleConfiguration.color.topColor
        self.cancelButton.setTitle("CANCEL".getLocalize(), for: .normal)
        self.mediaCaption.chatInputDelegate = self
        self.mediaCaption.font = Qiscus.style.chatFont
        self.mediaCaption.placeholder = QiscusTextConfiguration.sharedInstance.captionPlaceholder
        
        imageCollection.dataSource = self
        imageCollection.delegate = self
        imageCollection.register(UINib(nibName: "MultipleImageCell", bundle: Qiscus.bundle), forCellWithReuseIdentifier: "MultipleImageCell")
        imageCollection.backgroundColor = UIColor.clear
        imageCollection.isHidden = true
        imageCollection.allowsSelection = true
        self.deleteButton.isHidden = true
        
        if self.fileName != nil && self.data != nil && self.imageData.count == 0 {
            self.imageData.append(self.generateComment(fileName: self.fileName!, data: self.data!, mediaCaption: self.mediaCaption.value))
        }
        
        for gesture in self.view.gestureRecognizers! {
            self.view.removeGestureRecognizer(gesture)
        }
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
    
    func generateComment(fileName: String, data: Data, mediaCaption: String) -> QComment {
        let newComment = self.room!.prepareImageComment(filename: fileName, data: data)
        return newComment
    }
    
    @IBAction func deleteImage(_ sender: UIButton) {
        sender.isHidden = self.imageData.count == 2
        self.imageData.remove(at: self.selectedImageIndex)
        self.selectedImageIndex = self.selectedImageIndex != 0 ? self.selectedImageIndex - 1 : 0
        self.imageCollection.reloadData()
        self.imageCollection.selectItem(at: IndexPath(row: self.selectedImageIndex, section: 0), animated: true, scrollPosition: .bottom)
        self.imageView.loadAsync(fromLocalPath: (self.imageData[self.selectedImageIndex].file?.localThumbPath)!, onLoaded: { (image, _) in
            self.imageView.image = image
        })
    }
    @IBAction func addMoreImage(_ sender: UIButton) {
        self.goToGaleryPicker()
    }
    
    @IBAction func sendMedia(_ sender: Any) {
        if room != nil {
            if type == .image {
                let firstComment = self.room!.prepareImageComment(filename: self.fileName!, caption: self.mediaCaption.value, data: self.data!)
                self.imageData.removeFirst()
                self.imageData.insert(firstComment, at: 0)
                for comment in imageData {
                    self.room!.add(newComment: comment)
                    self.room!.upload(comment: comment, onSuccess: { (roomResult, commentResult) in
                        if let chatView = self.chatView {
                            chatView.postComment(comment: commentResult)
                        }
                    }, onError: { (roomResult, commentResult, error) in
                        Qiscus.printLog(text: "Error: \(error)")
                    })
                }
                
                self.room!.delegate?.room!(didFinishSync: self.room!)
                
                let _ = self.navigationController?.popViewController(animated: true)
            }
        }
    }
    
    // MARK: - Keyboard Methode
    @objc func keyboardWillHide(_ notification: Notification){
        let info: NSDictionary = (notification as NSNotification).userInfo! as NSDictionary
        
        let animateDuration = info[UIKeyboardAnimationDurationUserInfoKey] as! Double
        self.inputBottom.constant = self.imageData.count > 1 ? self.imageCollection.frame.height : 0
        self.mediaBottomMargin.constant = 8
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
        self.mediaBottomMargin.constant = -(self.mediaCaption.frame.height + 8)
        UIView.animate(withDuration: animateDuration, delay: 0, options: UIViewAnimationOptions(), animations: {
            self.view.layoutIfNeeded()
        }, completion: nil)
    }

    @IBAction func cancel(_ sender: Any) {
        let _ = self.navigationController?.popViewController(animated: true)
    }
    
    func goToGaleryPicker(){
        DispatchQueue.main.async(execute: {
            let picker = UIImagePickerController()
            picker.delegate = self
            picker.allowsEditing = false
            picker.sourceType = UIImagePickerControllerSourceType.photoLibrary
            picker.mediaTypes = [kUTTypeImage as String]
            self.present(picker, animated: true, completion: nil)
        })
    }
}

extension QiscusUploaderVC: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func showFileTooBigAlert(){
        let alertController = UIAlertController(title: "Fail to upload", message: "File too big", preferredStyle: .alert)
        let galeryActionButton = UIAlertAction(title: "Cancel", style: .cancel) { _ -> Void in }
        alertController.addAction(galeryActionButton)
        self.present(alertController, animated: true, completion: nil)
    }
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]){
            let time = Double(Date().timeIntervalSince1970)
            let fileType:String = info[UIImagePickerControllerMediaType] as! String
            //picker.dismiss(animated: true, completion: nil)
            
            if fileType == "public.image"{
                var imageName:String = ""
                let image = info[UIImagePickerControllerOriginalImage] as! UIImage
                var data = UIImagePNGRepresentation(image)
                if let imageURL = info[UIImagePickerControllerReferenceURL] as? URL{
                    imageName = imageURL.lastPathComponent
                    
                    let imageNameArr = imageName.split(separator: ".")
                    let imageExt:String = String(imageNameArr.last!).lowercased()
                    
                    let gif:Bool = (imageExt == "gif" || imageExt == "gif_")
                    let png:Bool = (imageExt == "png" || imageExt == "png_")
                    
                    if png{
                        data = UIImagePNGRepresentation(image)!
                    }else if gif{
                        let asset = PHAsset.fetchAssets(withALAssetURLs: [imageURL], options: nil)
                        if let phAsset = asset.firstObject {
                            let option = PHImageRequestOptions()
                            option.isSynchronous = true
                            option.isNetworkAccessAllowed = true
                            PHImageManager.default().requestImageData(for: phAsset, options: option) {
                                (gifData, dataURI, orientation, info) -> Void in
                                data = gifData
                            }
                        }
                    }else{
                        let result = PHAsset.fetchAssets(withALAssetURLs: [imageURL], options: nil)
                        let asset = result.firstObject
                        imageName = "\((asset?.value(forKey: "filename"))!)"
                        let imageSize = image.size
                        var bigPart = CGFloat(0)
                        if(imageSize.width > imageSize.height){
                            bigPart = imageSize.width
                        }else{
                            bigPart = imageSize.height
                        }
                        
                        var compressVal = CGFloat(1)
                        if(bigPart > 2000){
                            compressVal = 2000 / bigPart
                        }
                        
                        data = UIImageJPEGRepresentation(image, compressVal)!
                    }
                }
                
                if data != nil {
                    let mediaSize = Double(data!.count) / 1024.0
                    if mediaSize > Qiscus.maxUploadSizeInKB {
                        picker.dismiss(animated: true, completion: {
                            self.showFileTooBigAlert()
                        })
                        return
                    }
                    
                    imageData.append(self.generateComment(fileName: imageName, data: data!, mediaCaption: ""))
                    self.inputBottom.constant = self.imageCollection.frame.height
                    UIView.animate(withDuration: 1, delay: 0, options: UIViewAnimationOptions(), animations: {
                        self.view.layoutIfNeeded()
                        
                    }, completion: nil)
                    picker.dismiss(animated: true, completion: nil)
                    self.imageCollection.reloadData()
                    imageCollection.isHidden = false
                    self.deleteButton.isHidden = false
                }
            }
    }
    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
}

extension QiscusUploaderVC: UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.imageData.count
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let imagePath = self.imageData[indexPath.row].file?.localThumbPath
        self.imageView.loadAsync(fromLocalPath: imagePath!, onLoaded: { (image, _) in
            self.imageView.image = image
        })
        self.selectedImageIndex = indexPath.row
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let comment = self.imageData[indexPath.row]
        let imagePath = comment.file?.localThumbPath
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "MultipleImageCell", for: indexPath) as! MultipleImageCell
        cell.ivMedia.loadAsync(fromLocalPath: imagePath!, onLoaded: { (image, _) in
            cell.ivMedia.image = image
        })
        
        return cell
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
