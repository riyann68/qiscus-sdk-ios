//
//  QConversationCollectionView+protocol.swift
//  Qiscus
//
//  Created by Ahmad Athaullah on 16/12/17.
//  Copyright © 2017 Ahmad Athaullah. All rights reserved.
//
import Foundation
import UIKit

@objc public class QChatCellHeight:NSObject{
    var height = CGFloat(0)
    
    public init(height:CGFloat) {
        super.init()
        self.height = height
    }
}
@objc public protocol QConversationViewDelegate{
    func viewDelegate(enableForwardAction view:QConversationCollectionView)->Bool
    func viewDelegate(enableInfoAction view:QConversationCollectionView)->Bool
    
    @objc optional func viewDelegate(view:QConversationCollectionView, cellForComment comment:QComment, indexPath:IndexPath)->QChatCell?
    @objc optional func viewDelegate(view:QConversationCollectionView, heightForComment comment:QComment)->QChatCellHeight?
    @objc optional func viewDelegate(view:QConversationCollectionView, willDisplayCellForComment comment:QComment, cell:QChatCell, indexPath:IndexPath)
    @objc optional func viewDelegate(view:QConversationCollectionView, didEndDisplayingCellForComment comment:QComment, cell:QChatCell, indexPath:IndexPath)
    @objc optional func viewDelegate(didEndDisplayingLastMessage view:QConversationCollectionView, comment:QComment)
    @objc optional func viewDelegate(willDisplayLastMessage view:QConversationCollectionView, comment:QComment)
    @objc optional func viewDelegate(view:QConversationCollectionView, hideCellWith comment:QComment)->Bool
    @objc optional func viewDelegate(view:QConversationCollectionView, didLoadData messages:[[String]])
    
    @objc optional func viewDelegate(usingSoftDeleteOnView view:QConversationCollectionView)->Bool
}
@objc public protocol QConversationViewRoomDelegate{
    @objc optional func roomDelegate(didChangeName room: QRoom, name:String)
    @objc optional func roomDelegate(didFinishSync room: QRoom)
    @objc optional func roomDelegate(didChangeAvatar room: QRoom, avatar:UIImage)
    @objc optional func roomDelegate(didFailUpdate error: String)
    @objc optional func roomDelegate(didChangeUser room: QRoom, user: QUser)
    @objc optional func roomDelegate(didChangeParticipant room: QRoom)
    @objc optional func roomDelegate(didChangeUnread room:QRoom, unreadCount:Int)
    @objc optional func roomDelegate(gotFirstComment room:QRoom)
}

@objc public protocol QConversationViewCellDelegate{
    @objc optional func cellDelegate(didTapInfoOnComment comment:QComment)
    @objc optional func cellDelegate(didTapForwardOnComment comment:QComment)
    @objc optional func cellDelegate(didTapReplyOnComment comment:QComment)
    @objc optional func cellDelegate(didTapShareOnComment comment:QComment)
    
    @objc optional func cellDelegate(didTapMediaCell comment:QComment)
    @objc optional func cellDelegate(didTapAccountLinking comment:QComment)
    @objc optional func cellDelegate(didTapCardButton comment:QComment, buttonIndex index:Int)
    @objc optional func cellDelegate(didTapPostbackButton comment:QComment, buttonIndex index:Int)
    @objc optional func cellDelegate(didTapCommentLink comment:QComment)
    @objc optional func cellDelegate(didTapSaveContact comment:QComment)
    @objc optional func cellDelegate(didTapDocumentFile comment:QComment, room:QRoom)
    @objc optional func cellDelegate(didTapKnownFile comment:QComment, room:QRoom)
    @objc optional func cellDelegate(didTapUnknownFile comment:QComment, room:QRoom)
    
    @objc optional func cellDelegate(didTapCardAction action:QCardAction)
    @objc optional func cellDelegate(didTapCard card:QCard)
}

@objc public protocol QConversationViewConfigurationDelegate{
    @objc optional func configDelegate(userNameLabelColor collectionView:QConversationCollectionView, forUser user:QUser)->UIColor?
    @objc optional func configDelegate(hideLeftAvatarOn collectionView:QConversationCollectionView)->Bool
    @objc optional func configDelegate(hideUserNameLabel collectionView:QConversationCollectionView, forUser user:QUser)->Bool
    @objc optional func configDelegate(deletedMessageText collectionView:QConversationCollectionView, selfMessage isSelf:Bool)->String
    @objc optional func configDelegate(enableReplyMenuItem collectionView:QConversationCollectionView, forComment comment: QComment)->Bool
    @objc optional func configDelegate(enableResendMenuItem collectionView:QConversationCollectionView, forComment comment: QComment)->Bool
    @objc optional func configDelegate(enableDeleteMenuItem collectionView:QConversationCollectionView, forComment comment: QComment)->Bool
    @objc optional func configDelegate(enableDeleteForMeMenuItem collectionView:QConversationCollectionView, forComment comment: QComment)->Bool
    @objc optional func configDelegate(enableShareMenuItem collectionView:QConversationCollectionView, forComment comment: QComment)->Bool
    @objc optional func configDelegate(enableForwardMenuItem collectionView:QConversationCollectionView, forComment comment: QComment)->Bool
    @objc optional func configDelegate(enableInfoMenuItem collectionView:QConversationCollectionView, forComment comment: QComment)->Bool
    @objc optional func configDelegate(usingTpingCellIndicator collectionView:QConversationCollectionView)->Bool
}
