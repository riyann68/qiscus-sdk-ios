//
//  QCellLocationRight.swift
//  Example
//
//  Created by Ahmad Athaullah on 8/24/17.
//  Copyright © 2017 Ahmad Athaullah. All rights reserved.
//

import UIKit
import MapKit
import SwiftyJSON

class QCellLocationRight: QChatCell {

    @IBOutlet weak var balloonView: UIImageView!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var statusImage: UIImageView!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var addressView: UITextView!
    @IBOutlet weak var locationLabel: UILabel!
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var userNameLabel: UILabel!
    
    @IBOutlet weak var topMargin: NSLayoutConstraint!
    @IBOutlet weak var addressHeight: NSLayoutConstraint!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.containerView.layer.cornerRadius = 12.0
        self.balloonView.tintColor = QiscusColorConfiguration.sharedInstance.rightBaloonColor
        self.locationLabel.textColor = Qiscus.style.color.rightBaloonTextColor
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(QCellLocationRight.openMap))
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
        if let color = self.userNameColor {
            self.userNameLabel.textColor = color
        }
        let payload = JSON(parseJSON: self.comment!.data)
        self.addressHeight.constant = self.comment!.textSize.height - 168.0
        self.addressView.attributedText = self.comment?.attributedText
        self.locationLabel.text = payload["name"].stringValue
        
        if self.showUserName{
            self.userNameLabel.text = "YOU".getLocalize()
            self.userNameLabel.isHidden = false
            self.topMargin.constant = 20
        }else{
            self.userNameLabel.text = ""
            self.userNameLabel.isHidden = true
            self.topMargin.constant = 0
        }
        
        self.balloonView.image = self.getBallon()
        self.updateStatus(toStatus: self.comment!.status)
    }
    public override func updateStatus(toStatus status:QCommentStatus){
        super.updateStatus(toStatus: status)
        dateLabel.textColor = QiscusColorConfiguration.sharedInstance.rightBaloonTextColor
        dateLabel.text = self.comment!.time.lowercased()
        statusImage.isHidden = false
        statusImage.tintColor = QiscusColorConfiguration.sharedInstance.rightBaloonTextColor
        statusImage.isHidden = false
        statusImage.tintColor = QiscusColorConfiguration.sharedInstance.rightBaloonTextColor
        
        switch status {
        case .deleted:
            dateLabel.text = self.comment!.time.lowercased()
            statusImage.image = Qiscus.image(named: "ic_deleted")?.withRenderingMode(.alwaysTemplate)
            break
        case .deleting, .deletePending:
            dateLabel.text = QiscusTextConfiguration.sharedInstance.deletingText
            if status == .deletePending {
                dateLabel.text = self.comment!.time.lowercased()
            }
            statusImage.image = Qiscus.image(named: "ic_deleting")?.withRenderingMode(.alwaysTemplate)
            break;
        case .sending, .pending:
            dateLabel.text = QiscusTextConfiguration.sharedInstance.sendingText
            if status == .pending {
                dateLabel.text = self.comment!.time.lowercased()
            }
            statusImage.image = Qiscus.image(named: "ic_info_time")?.withRenderingMode(.alwaysTemplate)
            break
        case .sent:
            statusImage.image = Qiscus.image(named: "ic_sending")?.withRenderingMode(.alwaysTemplate)
            break
        case .delivered:
            statusImage.image = Qiscus.image(named: "ic_read")?.withRenderingMode(.alwaysTemplate)
            break
        case .read:
            statusImage.tintColor = Qiscus.style.color.readMessageColor
            statusImage.image = Qiscus.image(named: "ic_read")?.withRenderingMode(.alwaysTemplate)
            break
        case .failed:
            dateLabel.text = QiscusTextConfiguration.sharedInstance.failedText
            dateLabel.textColor = QiscusColorConfiguration.sharedInstance.failToSendColor
            statusImage.image = Qiscus.image(named: "ic_warning")?.withRenderingMode(.alwaysTemplate)
            statusImage.tintColor = QiscusColorConfiguration.sharedInstance.failToSendColor
            break
        default: break
        }
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
        if self.comment?.uniqueId == comment.uniqueId{
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
