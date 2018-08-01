//
//  QiscusRealtime.swift
//  Qiscus
//
//  Created by Qiscus.
//  Copyright © 2018 Qiscus Pte Ltd. All rights reserved.
//

import CocoaMQTT
import SwiftyJSON

extension Qiscus:CocoaMQTTDelegate{
    public func mqtt(_ mqtt: CocoaMQTT, didConnectAck ack: CocoaMQTTConnAck){
        Qiscus.printLog(text: "[Qiscus-MQTT] didConnectAck")
        let state = UIApplication.shared.applicationState
        let activeState = (state == .active)
        Qiscus.shared.connectingMQTT = false
        QiscusBackgroundThread.async {
            let commentChannel = "\(Qiscus.client.token)/c"
            mqtt.subscribe(commentChannel, qos: .qos2)
            
            let eventChannel = "\(Qiscus.client.token)/n"
            mqtt.subscribe(eventChannel, qos: .qos2)
            
            for room in QRoom.all() {
                if !room.isPublicChannel {
                    mqtt.subscribe("r/\(room.id)/\(room.id)/+/t")
                } else {
                    mqtt.subscribe("\(Qiscus.client.appId)/\(room.uniqueId)/c")
                }
            }
            Qiscus.realtimeConnected = true
            Qiscus.shared.mqtt = mqtt
            
            if activeState {
                Qiscus.shared.startPublishOnlineStatus()
            }
        }
    }
    public func mqtt(_ mqtt: CocoaMQTT, didPublishMessage message: CocoaMQTTMessage, id: UInt16){
    }
    public func mqtt(_ mqtt: CocoaMQTT, didPublishAck id: UInt16){
    }
    public func mqtt(_ mqtt: CocoaMQTT, didReceiveMessage message: CocoaMQTTMessage, id: UInt16 ){
        QiscusBackgroundThread.async {autoreleasepool{
            if let messageData = message.string {
                let channelArr = message.topic.split(separator: "/")
                let lastChannelPart = String(channelArr.last!)
                switch lastChannelPart {
                case "n":
                    QiscusBackgroundThread.async {
                        let json = JSON(parseJSON:messageData)
                        let eventId = "\(json["id"])"
                        let lastEventId = Int64(Qiscus.client.lastEventId)
                        if Qiscus.client.lastEventId == "" || lastEventId == nil{
                            QiscusClient.update(lastEventId: eventId)
                        }
                        Qiscus.syncEvent()
                    }
                    break
                case "c":
                    let json = JSON(parseJSON:messageData)
                    let roomId = "\(json["room_id"])"
                    let commentId = json["id"].intValue
                    if commentId > Qiscus.client.lastCommentId {
                        if Qiscus.client.lastCommentId == 0 || Qiscus.client.lastKnownCommentId == 0 {
                            QiscusClient.updateLastCommentId(commentId: commentId - 1)
                        }
                        func syncData(){
                            QChatService.syncProcess()
                        }
                        let commentType = json["type"].stringValue
                        if commentType == "system_event" {
                            let payload = json["payload"]
                            let type = payload["type"].stringValue
                            if type == "remove_member" || type == "left_room"{
                                if payload["object_email"].stringValue == Qiscus.client.email {
                                    DispatchQueue.main.async {autoreleasepool{
                                        let comment = QComment.tempComment(fromJSON: json)
                                        
                                        if let roomDelegate = QiscusCommentClient.shared.roomDelegate {
                                            if !comment.isInvalidated{
                                                 roomDelegate.gotNewComment(comment)
                                            }
                                           
                                        }
                                        Qiscus.chatDelegate?.qiscusChat?(gotNewComment: comment)
                                        
                                        if let chatView = Qiscus.shared.chatViews[roomId] {
                                            chatView.chatRoom = nil
                                            if chatView.isPresence {
                                                chatView.goBack()
                                            }
                                            Qiscus.shared.chatViews[roomId] = nil
                                        }
                                        Qiscus.chatRooms[roomId] = nil
                                        
                                        if let room = QRoom.threadSaveRoom(withId: roomId){
                                            if !room.isInvalidated {
                                                room.unsubscribeRealtimeStatus()
                                                QRoom.deleteRoom(room: room)
                                            }
                                        }
                                        QiscusNotification.publish(roomDeleted: roomId)
                                        }}
                                }
                                else{
                                    syncData()
                                }
                            }else{
                                syncData()
                            }
                        }else{
                            syncData()
                        }
                    }else{
                        let uniqueId = json["unique_temp_id"].stringValue
                        DispatchQueue.main.async {autoreleasepool{
                            if let room = QRoom.room(withId: roomId) {
                                if let comment = QComment.comment(withUniqueId: uniqueId){
                                    if comment.status != .delivered && comment.status != .read {
                                        room.updateCommentStatus(inComment: comment, status: .delivered)
                                    }
                                }
                            }
                            }}
                    }
                    
                    let statusObj = ["room_id" : roomId,
                                     "comment_id": commentId,
                                     "status": QCommentStatus.delivered
                        ] as [String : Any]
                    
                    if Qiscus.publishStatustimer != nil {
                        Qiscus.publishStatustimer?.invalidate()
                    }
                    
                    if UIApplication.shared.applicationState == .active {
                        DispatchQueue.main.async {
                            Qiscus.publishStatustimer = Timer.scheduledTimer(timeInterval: 1.5, target: self, selector: #selector(self.publishStatus(sender:)), userInfo: statusObj, repeats: false)
                        }
                    } else {
                        QRoom.publishStatus(roomId: roomId, commentId: commentId, status: .delivered)
                    }
                    
                    break
                case "t":
                    QiscusBackgroundThread.async {
                        let roomId = String(channelArr[2])
                        let userEmail:String = String(channelArr[3])
                        let data = (messageData == "0") ? "" : userEmail
                        
                        
                        func startTypingNotification(){
                            DispatchQueue.main.async {
                                if let room = QRoom.room(withId: roomId) {
                                    if room.isInvalidated{ return }
                                    if let user = QUser.user(withEmail: userEmail){
                                        if user.isInvalidated { return }
                                        let typing = (messageData == "0") ? false : true
                                        QiscusNotification.publish(userTyping: user, room: room, typing: typing)
                                    }
                                    room.updateUserTyping(userEmail: data)
                                }
                            }
                        }
                        
                        if userEmail != Qiscus.client.email {
                            if let r = QRoom.threadSaveRoom(withId: roomId){
                                if r.isInvalidated { return }
                                if QUser.getUser(email: userEmail) != nil {
                                    startTypingNotification()
                                }
                            }
                        }
                    }
                    break
                case "d":
                    QiscusBackgroundThread.async {
                        let roomId = String(channelArr[2])
                        let messageArr = messageData.split(separator: ":")
                        let commentId = Int(String(messageArr[0]))!
                        let userEmail = String(channelArr[3])
                        if userEmail != Qiscus.client.email {
                            if let room = QRoom.threadSaveRoom(withId: roomId){
                                if let participant = room.participant(withEmail: userEmail) {
                                    participant.updateLastDeliveredId(commentId: commentId)
                                }
                            }
                        }
                    }
                    
                    break
                case "r":
                    QiscusBackgroundThread.async {
                        let roomId = String(channelArr[2])
                        let messageArr = messageData.split(separator: ":")
                        let commentUid = String(messageArr.last!)
                        let commentId = Int(String(messageArr[0]))!
                        let userEmail = String(channelArr[3])
                        
                        if QRoom.threadSaveRoom(withId: roomId) == nil { return }
                        guard let c = QComment.threadSaveComment(withUniqueId: commentUid) else {return}
                        if userEmail == Qiscus.client.email {
                            c.read()
                        }else{
                            DispatchQueue.main.async {
                                if let room = QRoom.room(withId: roomId){
                                    if let participant = room.participants.filter("email == '\(userEmail)'").first {
                                        participant.updateLastReadId(commentId: commentId)
                                    }
                                }
                            }
                        }
                    }
                    
                    break
                case "s":
                    QiscusBackgroundThread.async {
                        let messageArr = messageData.split(separator: ":")
                        if messageArr.count > 1 {
                            let userEmail = String(channelArr[1])
                            let presenceString = String(messageArr[0])
                            if let rawPresence = Int(presenceString){
                                if userEmail != Qiscus.client.email{
                                    if let timeToken = Double(String(messageArr[1])){
                                        if let user = QUser.getUser(email: userEmail){
                                            user.updateLastSeen(lastSeen: Double(timeToken)/1000)
                                            let presence = QUserPresence(rawValue: rawPresence)!
                                            user.updatePresence(presence: presence)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    break
                default:
                    Qiscus.printLog(text: "Realtime socket receive message in unknown topic: \(message.topic)")
                    break
                }
            }
            }}
    }
    
    @objc func publishStatus(sender: Timer) {
        let userInfo = sender.userInfo! as! [String: Any]
        let roomId = userInfo["room_id"] as! String
        let commentId = userInfo["comment_id"] as! Int
        let status = userInfo["status"] as! QCommentStatus

        DispatchQueue.global(qos: .background).async {
            QRoom.publishStatus(roomId: roomId, commentId: commentId, status: status)
        }
    }
    
    public func mqtt(_ mqtt: CocoaMQTT, didSubscribeTopic topic: String){
        if !Qiscus.realtimeChannel.contains(topic) {
            Qiscus.printLog(text: "new realtime channel : \(topic) subscribed")
            Qiscus.realtimeChannel.append(topic)
        }
    }
    public func mqtt(_ mqtt: CocoaMQTT, didUnsubscribeTopic topic: String){
        if Qiscus.realtimeChannel.contains(topic){
            var i = 0
            for channel in Qiscus.realtimeChannel {
                if channel == topic {
                    Qiscus.realtimeChannel.remove(at: i)
                    break
                }
                i+=1
            }
        }
    }
    public func mqttDidPing(_ mqtt: CocoaMQTT){
    }
    public func mqttDidReceivePong(_ mqtt: CocoaMQTT){
        
    }
    public func mqttDidDisconnect(_ mqtt: CocoaMQTT, withError err: Error?){
        Qiscus.printLog(text: "[Qiscus-MQTT] mqttDidDisconnect")
        Qiscus.shared.connectingMQTT = false
        if Qiscus.isLoggedIn {
            Qiscus.shared.stopPublishOnlineStatus()
            Qiscus.realtimeConnected = false
            Qiscus.sync()
        }
    }
    public func mqtt(_ mqtt: CocoaMQTT, didStateChangeTo state: CocoaMQTTConnState) {
        Qiscus.printLog(text: "[Qiscus-MQTT] didStateChangeTo state: \(state)")
    }
    public func mqtt(_ mqtt: CocoaMQTT, didPublishComplete id: UInt16) {
        Qiscus.printLog(text: "[Qiscus-MQTT] didPublishComplete")
    }
    public func mqtt(_ mqtt: CocoaMQTT, didReceive trust: SecTrust, completionHandler: @escaping (Bool) -> Void) {
        Qiscus.printLog(text: "[Qiscus-MQTT] didReceive trust")
        completionHandler(true)
    }
}
