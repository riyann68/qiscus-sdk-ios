//
//  QCellCarousel.swift
//  Qiscus
//
//  Created by Ahmad Athaullah on 08/01/18.
//  Copyright © 2018 Ahmad Athaullah. All rights reserved.
//

import UIKit
import SwiftyJSON


public protocol QCellCarouselDelegate {
    func cellCarousel(carouselCell:QCellCarousel, didTapCard card:QCard)
    func cellCarousel(carouselCell:QCellCarousel, didTapAction action:QCardAction)
}

public class QCellCarousel: QChatCell{

    @IBOutlet weak var carouselView: UICollectionView!
    @IBOutlet weak var userNameLabel: UILabel!
    @IBOutlet weak var carouselTrailing: NSLayoutConstraint!
    @IBOutlet weak var carouselLeading: NSLayoutConstraint!
    @IBOutlet weak var topMargin: NSLayoutConstraint!
    @IBOutlet weak var carouselHeight: NSLayoutConstraint!
    
    public var cards = [QCard](){
        didSet{
            self.carouselView.reloadData()
            if let c = self.comment {
                if c.senderEmail == Qiscus.client.email {
                    if cards.count > 0 {
                        if cards.count == 1 {
                            self.carouselLeading.constant = QiscusHelper.screenWidth() - (QiscusHelper.screenWidth() * 0.6 + 32)
                        }else{
                            self.carouselLeading.constant = 0
                        }
                        let lastIndex = IndexPath(item: cards.count - 1, section: 0)
                        self.carouselView.scrollToItem(at: lastIndex, at: .left, animated: false)
                    }
                }else{
                    self.carouselLeading.constant = 0
                }
            }
        }
    }
    
    public var cellCarouselDelegate:QCellCarouselDelegate?
    
    override public func awakeFromNib() {
        super.awakeFromNib()
        self.carouselView.register(UINib(nibName: "QCarouselCardCell",bundle: Qiscus.bundle), forCellWithReuseIdentifier: "cellCardCarousel")
        carouselView.delegate = self
        carouselView.dataSource = self
        carouselView.clipsToBounds = true
        
        self.layer.zPosition = 99
    }
    
    override public func commentChanged() {
        cards = [QCard]()
        
        if let c = self.comment {
            var leftSpace = CGFloat(0)
            var rightSpace = CGFloat(0)
            
            if c.senderEmail == Qiscus.client.email {
                self.userNameLabel.textAlignment = .right
                rightSpace = 15
            }else{
                self.userNameLabel.textAlignment = .left
                leftSpace = 42
                if self.hideAvatar {
                    leftSpace = 27
                }
            }
            
            let layout:UICollectionViewFlowLayout =  UICollectionViewFlowLayout()
            layout.sectionInset = UIEdgeInsets(top: 20, left: leftSpace, bottom: 0, right: rightSpace)
            layout.scrollDirection = .horizontal
            
            self.carouselView.collectionViewLayout = layout
            
            if self.showUserName{
                if c.senderEmail == Qiscus.client.email {
                    self.userNameLabel.text = "YOU".getLocalize()
                } else if let sender = c.sender {
                    self.userNameLabel.text = sender.fullname
                }else{
                    self.userNameLabel.text = c.senderName
                }
                self.userNameLabel.isHidden = false
                self.topMargin.constant = 20
            }else{
                self.userNameLabel.text = ""
                self.userNameLabel.isHidden = true
                self.topMargin.constant = 0
            }
            self.carouselHeight.constant = c.textSize.height + 10
            self.carouselView.layoutIfNeeded()
        }
    }
    
    override public func willDisplayCell() {
        if let c = self.comment {
            let payload = JSON(parseJSON: c.data)
            
            let cards = payload["cards"].arrayValue
            var allCards = [QCard]()
            for cardData in cards {
                let card = QCard(json: cardData)
                allCards.append(card)
            }
            self.cards = allCards
        }
    }
}
extension QCellCarousel: UICollectionViewDelegateFlowLayout {
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if let c = self.comment {
            var size = c.textSize
            size.width = QiscusHelper.screenWidth() * 0.70
            size.height += 30
            return size
        }
        return CGSize.zero
    }
}

extension QCellCarousel: UICollectionViewDelegate{
    
}

extension QCellCarousel: UICollectionViewDataSource{
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return cards.count
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cellCardCarousel", for: indexPath) as! QCarouselCardCell
        let height = self.comment!.textSize.height + 30.0
        
        cell.setupWithCard(card: self.cards[indexPath.item], height: height)
        cell.cardDelegate = self
        return cell
    }
}
extension QCellCarousel: QCarouselCardDelegate {
    public func carouselCard(cardCell: QCarouselCardCell, didTapAction card: QCardAction) {
        self.cellCarouselDelegate?.cellCarousel(carouselCell: self, didTapAction: card)
    }
}
