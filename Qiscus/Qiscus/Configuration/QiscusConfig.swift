//
//  QiscusConfig.swift
//  LinkDokter
//
//  Created by Qiscus on 3/2/16.
//  Copyright © 2016 qiscus. All rights reserved.
//

import UIKit

open class QiscusConfig: NSObject {
    
    static let sharedInstance = QiscusConfig()
    
    open var commentPerLoad:Int = 10
    open var dbSchemaVersion:UInt64 = 68
    
    open var UPLOAD_URL = ""
    
    open var showToasterMessage:Bool = true
    open var showToasterMessageInsideChat:Bool = true
    internal var API_VERSION = "2"
    
    open var BASE_URL:String{
        get{
            return QiscusMe.shared.baseUrl
        }
    }
    open var USER_EMAIL:String{
        get{
            return QiscusMe.shared.email
        }
    }
    open var USER_TOKEN:String{
        get{
            return QiscusMe.shared.token
        }
    }
    open var PUSHER_KEY:String{
        get{
            return QiscusMe.shared.rtKey
        }
    }

    internal var BASE_API_URL:String{
        get{
            if QiscusMe.shared.baseUrl != "" {
                return "\(QiscusMe.shared.baseUrl)/api/v\(self.API_VERSION)/mobile"
            }else{
                return "\(QiscusMe.shared.appId).qiscus.com/api/v\(self.API_VERSION)/mobile"
            }
        }
    }
    internal var requestHeader:[String:String]{
        get{
            var headers:[String:String] = [
                "User-Agent" : "QiscusSDKIos/v\(Qiscus.versionNumber)",
                "QISCUS_SDK_APP_ID" : QiscusMe.shared.appId,
            ]
            if QiscusMe.shared.token != "" {
                headers["QISCUS_SDK_TOKEN"] = QiscusMe.shared.token
            }
            if QiscusMe.shared.email != "" {
                headers["QISCUS_SDK_USER_ID"] = QiscusMe.shared.email
            }
            return headers
        }
    }
    
    fileprivate override init() {}
    
    internal class var postCommentURL:String{
        get{
            let config = QiscusConfig.sharedInstance
            return "\(config.BASE_API_URL)/post_comment"
        }
    }
    
    // MARK: -URL
    internal class var SYNC_URL:String{
        get{
            return "\(QiscusConfig.sharedInstance.BASE_API_URL)/sync"
    
        }
    }
    internal class var SEARCH_URL:String{
        get{
            return "\(QiscusConfig.sharedInstance.BASE_API_URL)/search_messages"
        }
    }
    internal class var ROOMLIST_URL:String{
        get{
            return "\(QiscusConfig.sharedInstance.BASE_API_URL)/user_rooms"
            
        }
    }
    internal class var ROOMINFO_URL:String{
        get{
            return "\(QiscusConfig.sharedInstance.BASE_API_URL)/rooms_info"
            
        }
    }
    internal class var SET_DEVICE_TOKEN_URL:String{
        return "\(QiscusConfig.sharedInstance.BASE_API_URL)/set_user_device_token"
    }
    internal class var REMOVE_DEVICE_TOKEN_URL:String{
        return "\(QiscusConfig.sharedInstance.BASE_API_URL)/remove_user_device_token"
    }
    internal class var UPLOAD_URL:String{
        return "\(QiscusConfig.sharedInstance.BASE_API_URL)/upload"
    }
    internal class var UPDATE_ROOM_URL:String{
        return "\(QiscusConfig.sharedInstance.BASE_API_URL)/update_room"
    }
    internal class var UPDATE_COMMENT_STATUS_URL:String{
        return "\(QiscusConfig.sharedInstance.BASE_API_URL)/update_comment_status"
    }
    internal class var LOGIN_REGISTER:String{
        return "\(QiscusConfig.sharedInstance.BASE_API_URL)/login_or_register"
    }
    internal class var CREATE_NEW_ROOM:String{
        return "\(QiscusConfig.sharedInstance.BASE_API_URL)/create_room"
    }
    internal class var ROOM_REQUEST_URL:String{
        return "\(QiscusConfig.sharedInstance.BASE_API_URL)/get_or_create_room_with_target"
    }
    internal class var ROOM_UNIQUEID_URL:String{
        return "\(QiscusConfig.sharedInstance.BASE_API_URL)/get_or_create_room_with_unique_id"
    }
    open class var LINK_METADATA_URL:String{
        let config = QiscusConfig.sharedInstance
        return "\(config.BASE_API_URL)/get_url_metadata"
    }
    internal class var LOAD_URL:String{
        let config = QiscusConfig.sharedInstance
        return "\(config.BASE_API_URL)/load_comments/"
    }
    open class func LOAD_URL_(withTopicId topicId:Int, commentId:Int)->String{
        let config = QiscusConfig.sharedInstance
        return "\(config.BASE_API_URL)/topic/\(topicId)/comment/\(commentId)/token/\(config.USER_TOKEN)"
    }
    open class var ROOM_REQUEST_ID_URL:String{
        let config = QiscusConfig.sharedInstance
        return "\(config.BASE_API_URL)/get_room_by_id"
    }
    open func setUserConfig(withEmail email:String, userKey:String, rtKey:String){
        QiscusMe.shared.email = email
        QiscusMe.shared.userData.set(email, forKey: "qiscus_email")
        
        QiscusMe.shared.token = userKey
        QiscusMe.shared.userData.set(userKey, forKey: "qiscus_token")
        
        QiscusMe.shared.rtKey = rtKey
        QiscusMe.shared.userData.set(rtKey, forKey: "qiscus_rt_key")
    }
}
