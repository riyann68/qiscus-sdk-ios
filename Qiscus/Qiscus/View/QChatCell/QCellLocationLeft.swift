//
//  QCellLocationLeft.swift
//  Example
//
//  Created by Ahmad Athaullah on 8/24/17.
//  Copyright © 2017 Ahmad Athaullah. All rights reserved.
//

import UIKit
import MapKit
import SwiftyJSON

class QCellLocationLeft: QChatCell {
    
    @IBOutlet weak var balloonView: UIImageView!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var addressView: UITextView!
    @IBOutlet weak var locationLabel: UILabel!
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var userNameLabel: UILabel!
    
    @IBOutlet weak var topMargin: NSLayoutConstraint!
    @IBOutlet weak var addressHeight: NSLayoutConstraint!
    @IBOutlet weak var balloonLeftMargin: NSLayoutConstraint!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.containerView.layer.cornerRadius = 12.0
        self.balloonView.tintColor = QiscusColorConfiguration.sharedInstance.leftBaloonColor
        self.locationLabel.textColor = Qiscus.style.color.leftBaloonTextColor
        self.dateLabel.textColor = QiscusColorConfiguration.sharedInstance.leftBaloonTextColor
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(QCellLocationLeft.openMap))
        self.mapView.addGestureRecognizer(tapRecognizer)
        // Initialization code
    }
    override func endDisplayingCell() {
        self.mapView.removeAnnotations(self.mapView.annotations)
    }
    override func willDisplayCell() {
        
        let payload = JSON(parseJSON: self.comment!.data)
        
        let lat = CLLocationDegrees(payload["latitude"].doubleValue)
        let long = CLLocationDegrees(payload["longitude"].doubleValue)
        
        let center = CLLocationCoordinate2DMake(lat, long)
        
        let region = MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
        let newPin = MKPointAnnotation()
        newPin.coordinate = center
        self.mapView.setRegion(region, animated: false)
        self.mapView.addAnnotation(newPin)
    }
    override func commentChanged() {
        if hideAvatar {
            self.balloonLeftMargin.constant = 0
        }else{
            self.balloonLeftMargin.constant = 27
        }
        if let color = self.userNameColor {
            self.userNameLabel.textColor = color
        }
        let payload = JSON(parseJSON: self.comment!.data)
        
        //set region on the map
        self.addressHeight.constant = self.comment!.textSize.height - 168.0
        self.addressView.attributedText = self.comment?.attributedText
        self.locationLabel.text = payload["name"].stringValue
        
        if self.showUserName{
            if let sender = self.comment?.sender {
                self.userNameLabel.text = sender.fullname
            }else{
                self.userNameLabel.text = self.comment?.senderName
            }
            self.userNameLabel.isHidden = false
            self.topMargin.constant = 20
        }else{
            self.userNameLabel.text = ""
            self.userNameLabel.isHidden = true
            self.topMargin.constant = 0
        }
        
        self.balloonView.image = self.getBallon()
        
        dateLabel.text = self.comment!.time.lowercased()
        
    }
    @objc func openMap(){
        let payload = JSON(parseJSON: self.comment!.data)
        
        let latitude: CLLocationDegrees = payload["latitude"].doubleValue
        let longitude: CLLocationDegrees = payload["longitude"].doubleValue
        
        let regionDistance:CLLocationDistance = 10000
        let coordinates = CLLocationCoordinate2DMake(latitude, longitude)
        let regionSpan = MKCoordinateRegionMakeWithDistance(coordinates, regionDistance, regionDistance)
        let options = [
            MKLaunchOptionsMapCenterKey: NSValue(mkCoordinate: regionSpan.center),
            MKLaunchOptionsMapSpanKey: NSValue(mkCoordinateSpan: regionSpan.span)
        ]
        let placemark = MKPlacemark(coordinate: coordinates, addressDictionary: nil)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = payload["name"].stringValue
        mapItem.openInMaps(launchOptions: options)
    }
    public override func comment(didChangePosition comment:QComment, position: QCellPosition) {
        if comment.uniqueId == self.comment?.uniqueId {
            self.balloonView.image = self.getBallon()
        }
    }
    public override func updateUserName() {
        if let sender = self.comment?.sender {
            self.userNameLabel.text = sender.fullname
        }else{
            self.userNameLabel.text = self.comment?.senderName
        }
    }
}
