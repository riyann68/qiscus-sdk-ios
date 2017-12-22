//
//  QiscusLinkData.swift
//  QiscusSDK
//
//  Created by Ahmad Athaullah on 1/17/17.
//  Copyright © 2017 Ahmad Athaullah. All rights reserved.
//

import UIKit
import RealmSwift
import SwiftyJSON

open class QiscusLinkData: Object {
    open dynamic var localId:Int = 0
    open dynamic var linkURL:String = ""{
        didSet{
            if localId > 0 {
                let id = self.localId
                let value = linkURL
                
                let realm = Qiscus.realm()
                let searchQuery = NSPredicate(format: "localId == \(id)")
                
                let linkData = realm.objects(QiscusLinkData.self).filter(searchQuery)
                
                if linkData.count > 0{
                    let firstLink = linkData.first!
                    if firstLink.linkURL != value{
                        try! realm.write {
                            firstLink.linkURL = value
                        }
                    }
                }
                
            }
        }
    }
    open dynamic var linkTitle:String = ""{
        didSet{
            if localId > 0 {
                let id = self.localId
                let value = linkTitle
                
                let realm = Qiscus.realm()
                let searchQuery = NSPredicate(format: "localId == \(id)")
                
                let linkData = realm.objects(QiscusLinkData.self).filter(searchQuery)
                
                if linkData.count > 0{
                    let firstLink = linkData.first!
                    if firstLink.linkTitle != value{
                        try! realm.write {
                            firstLink.linkTitle = value
                        }
                    }
                }
            }
        }
    }
    open dynamic var linkDescription: String = ""{
        didSet{
            if localId > 0 {
                let id = self.localId
                let value = linkDescription
                
                let realm = Qiscus.realm()
                let searchQuery = NSPredicate(format: "localId == \(id)")
                
                let linkData = realm.objects(QiscusLinkData.self).filter(searchQuery)
                
                if linkData.count > 0{
                    let firstLink = linkData.first!
                    if firstLink.linkDescription != value{
                        try! realm.write {
                            firstLink.linkDescription = value
                        }
                    }
                }
            }
        }
    }
    open dynamic var linkImageURL: String = ""{
        didSet{
            if localId > 0 {
                let id = self.localId
                let value = linkImageURL
                
                let realm = Qiscus.realm()
                let searchQuery = NSPredicate(format: "localId == \(id)")
                
                let linkData = realm.objects(QiscusLinkData.self).filter(searchQuery)
                
                if linkData.count > 0{
                    let firstLink = linkData.first!
                    if firstLink.linkImageURL != value{
                        try! realm.write {
                            firstLink.linkImageURL = value
                        }
                    }
                }
                
            }
        }
    }
    open dynamic var linkImageThumbURL: String = ""{
        didSet{
            if localId > 0 {
                let id = self.localId
                let value = linkImageThumbURL
                
                let realm = Qiscus.realm()
                let searchQuery = NSPredicate(format: "localId == \(id)")
                
                let linkData = realm.objects(QiscusLinkData.self).filter(searchQuery)
                
                if linkData.count > 0{
                    let firstLink = linkData.first!
                    if firstLink.linkImageThumbURL != value{
                        try! realm.write {
                            firstLink.linkImageThumbURL = value
                        }
                    }
                }
                
            }
        }
    }
    
    class func copyLink(link:QiscusLinkData)->QiscusLinkData{
        let newLink = QiscusLinkData()
        newLink.localId = link.localId
        newLink.linkURL = link.linkURL
        newLink.linkTitle = link.linkTitle
        newLink.linkDescription = link.linkDescription
        newLink.linkImageURL = link.linkImageURL
        newLink.linkImageThumbURL = link.linkImageThumbURL
        return newLink
    }
    open var isLocalThumbExist:Bool{
        get{
            var check:Bool = false
            if QFileManager.isFileExist(inLocalPath: self.linkImageThumbURL){
                check = true
            }
            return check
        }
    }
    open var thumbImage:UIImage?{
        get{
            if isLocalThumbExist{
                if let image = UIImage.init(contentsOfFile: self.linkImageThumbURL){
                    return image
                }else{
                    return remoteLinkImage
                }
            }else{
                return remoteLinkImage
            }
        }
    }
    open var remoteLinkImage:UIImage?{
        get{
            if linkImageURL != "" {
                if let imageURL = URL(string: linkImageURL){
                    if let imageData = NSData(contentsOf: imageURL){
                        if let image = UIImage(data: imageData as Data){
                            return image
                        }
                    }
                }
            }
            return nil
        }
    }
    // MARK: - Set Primary Key
    override open class func primaryKey() -> String {
        return "localId"
    }
    open class var LastId:Int{
        get{
            let realm = Qiscus.realm()
            let RetNext = realm.objects(QiscusLinkData.self).sorted(byKeyPath: "localId")
            
            if RetNext.count > 0 {
                let last = RetNext.last!
                return last.localId
            } else {
                return 0
            }
        }
    }
    open class func getLinkData(fromURL url: String)->QiscusLinkData?{
        let realm = Qiscus.realm()
        let searchQuery:NSPredicate = NSPredicate(format: "linkURL == '\(url)'")
        let RetNext = realm.objects(QiscusLinkData.self).filter(searchQuery)
        
        if RetNext.count > 0 {
            let data = QiscusLinkData.copyLink(link: RetNext.first!)
            return data
        }else{
            return nil
        }
    }
    open func saveLink(){ //  
        
        let realm = Qiscus.realm()
        let searchQuery = NSPredicate(format: "linkURL == '\(self.linkURL)'")
        
        let linkData = realm.objects(QiscusLinkData.self).filter(searchQuery)
        
        if linkData.count == 0{
            try! realm.write {
                self.localId = QiscusLinkData.LastId + 1
                realm.add(self)
            }
            if self.linkImageThumbURL == "" {
                //self.downloadThumbImage()
            }
        }
        
    }
    open func updateThumbURL(url:String){
        let localId = self.localId
        
        let realm = Qiscus.realm()
        let searchQuery = NSPredicate(format: "localId == '\(localId)'")
        
        let linkData = realm.objects(QiscusLinkData.self).filter(searchQuery)

        if linkData.count > 0{
            let firstLink = linkData.first!
            try! realm.write {
                firstLink.linkImageThumbURL = url
            }
        }
        
    }
    open func updateLinkImageURL(url:String){
        let localId = self.localId
        
        let realm = Qiscus.realm()
        let searchQuery = NSPredicate(format: "localId == '\(localId)'")
        
        let linkData = realm.objects(QiscusLinkData.self).filter(searchQuery)
        
        if linkData.count > 0{
            let firstLink = linkData.first!
            try! realm.write {
                firstLink.linkImageURL = url
            }
        }
        
    }
    fileprivate func createThumbLink(_ image:UIImage)->UIImage{
        var smallPart:CGFloat = image.size.height
        
        if(image.size.width > image.size.height){
            smallPart = image.size.width
        }
        let ratio:CGFloat = CGFloat(100.0/smallPart)
        let newSize = CGSize(width: (image.size.width * ratio),height: (image.size.height * ratio))
        
        UIGraphicsBeginImageContext(newSize)
        image.draw(in: CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage!
    }
    
}
