//
//  QiscusCore.swift
//  Qiscus
//
//  Created by Qiscus on 07/03/18.
//  Copyright © 2018 Qiscus Pte Ltd. All rights reserved.
//

import Foundation
// MARK: TODO Remove realm here
import RealmSwift

extension Qiscus { // Public class API to get room
    public class func clearMessages(inChannels channels:[String], onSuccess:@escaping ([QRoom],[String])->Void, onError:@escaping (Int)->Void){
        QRoomService.clearMessages(inRoomsChannel: channels, onSuccess: { (rooms, channels) in
            onSuccess(rooms,channels)
        }) { (statusCode) in
            onError(statusCode)
        }
    }
    public class func prepareView(witCompletion completion: @escaping (([QiscusChatVC])->Void)){
        if Thread.isMainThread {
            let allRoom = QRoom.all()
            var allView = [QiscusChatVC]()
            for room in allRoom {
                if Qiscus.chatRooms[room.id] == nil {
                    Qiscus.chatRooms[room.id] = room
                }
                if Qiscus.shared.chatViews[room.id] == nil {
                    let chatView = QiscusChatVC()
                    chatView.chatRoom = room
                    chatView.prefetch = true
                    chatView.viewDidLoad()
                    chatView.viewWillAppear(false)
                    chatView.viewDidAppear(false)
                    chatView.view.layoutSubviews()
                    chatView.inputBar.layoutSubviews()
                    chatView.inputText.commonInit()
                    
                    Qiscus.shared.chatViews[room.id] = chatView
                    allView.append(chatView)
                }
            }
            completion(allView)
        }else{
            completion([QiscusChatVC]())
        }
    }
    public class func prepareView(){
        if Thread.isMainThread {
            let allRoom = QRoom.all()
            for room in allRoom {
                if Qiscus.chatRooms[room.id] == nil {
                    Qiscus.chatRooms[room.id] = room
                }
                if Qiscus.shared.chatViews[room.id] == nil {
                    let chatView = QiscusChatVC()
                    chatView.chatRoom = room
                    chatView.prefetch = true
                    chatView.viewDidLoad()
                    chatView.viewWillAppear(false)
                    chatView.viewDidAppear(false)
                    chatView.view.layoutSubviews()
                    chatView.inputBar.layoutSubviews()
                    chatView.inputText.commonInit()
                    
                    
                    Qiscus.shared.chatViews[room.id] = chatView
                }
            }
        }
    }
    public class func room(withId roomId:String, onSuccess:@escaping ((QRoom)->Void),onError:@escaping ((String)->Void)){
        let service = QChatService()
        var needToLoad = true
        func loadRoom(){
            service.room(withId: roomId, onSuccess: { (room) in
                if !room.isInvalidated {
                    onSuccess(room)
                }else{
                    Qiscus.printLog(text: "localRoom has been deleted")
                    onError("localRoom has been deleted")
                }
            }) { (error) in
                onError(error)
            }
        }
        if let room = QRoom.room(withId: roomId){
            if room.comments.count > 0 {
                onSuccess(room)
            }else{
                loadRoom()
            }
        }else{
            loadRoom()
        }
    }
    
    public class func room(withChannel channelName:String, title:String = "", avatarURL:String, onSuccess:@escaping ((QRoom)->Void),onError:@escaping ((String)->Void)){
        let service = QChatService()
        var needToLoad = true
        var room:QRoom?
        if QRoom.room(withUniqueId: channelName) != nil{
            room = QRoom.room(withUniqueId: channelName)
            if room!.comments.count > 0 {
                needToLoad = false
            }
        }
        if !needToLoad {
            onSuccess(room!)
        }else{
            service.room(withUniqueId: channelName, title: title, avatarURL: avatarURL, onSuccess: { (room) in
                onSuccess(room)
            }, onError: { (error) in
                onError(error)
            })
        }
        
    }
    public class func newRoom(withUsers usersId:[String], roomName: String, avatarURL:String = "", onSuccess:@escaping ((QRoom)->Void),onError:@escaping ((String)->Void)){
        let service = QChatService()
        if roomName.trimmingCharacters(in: .whitespacesAndNewlines) != "" {
            service.createRoom(withUsers: usersId, roomName: roomName, avatarURL: avatarURL, onSuccess: onSuccess, onError: onError)
        }else{
            onError("room name can not be empty string")
        }
    }
    public class func room(withUserId userId:String, onSuccess:@escaping ((QRoom)->Void),onError:@escaping ((String)->Void)){
        let service = QChatService()
        var needToLoad = true
        var room:QRoom?
        
        if QRoom.room(withUser: userId) != nil{
            room = QRoom.room(withUser: userId)
            if room!.comments.count > 0 {
                needToLoad = false
            }
        }
        if !needToLoad {
            onSuccess(room!)
        }else{
            service.room(withUser: userId, onSuccess: { (room) in
                onSuccess(room)
            }, onError: { (error) in
                onError(error)
            })
        }
    }
    
    // MARK: - Room List
    public class func roomList(withLimit limit:Int, page:Int, onSuccess:@escaping (([QRoom], Int, Int, Int)->Void),onError:@escaping ((String)->Void)){
        
        QChatService.roomList(onSuccess: { (rooms, totalRoom, currentPage, limit) in
            onSuccess(rooms, totalRoom, currentPage, limit)
        }, onFailed: {(error) in
            onError(error)
        })
    }
    public class func fetchAllRoom(loadLimit:Int = 0, onSuccess:@escaping (([QRoom])->Void),onError:@escaping ((String)->Void), onProgress: ((Double,Int,Int)->Void)? = nil){
        var page = 1
        var limit = 100
        if loadLimit > 0 {
            limit = loadLimit
        }
        func load(onPage:Int) {
            QChatService.roomList(withLimit: limit, page: page, showParticipant: true, onSuccess: { (rooms, totalRoom, currentPage, limit) in
                if totalRoom > (limit * (currentPage - 1)) + rooms.count{
                    page += 1
                    load(onPage: page)
                }else{
                    let rooms = QRoom.all()
                    onSuccess(rooms)
                }
            }, onFailed: { (error) in
                onError(error)
            }) { (progress, loadedRoomm, totalRoom) in
                onProgress?(progress,loadedRoomm,totalRoom)
            }
        }
        load(onPage: 1)
    }
    public class func roomInfo(withId id:String, lastCommentUpdate:Bool = true, onSuccess:@escaping ((QRoom)->Void), onError: @escaping ((String)->Void)){
        QChatService.roomInfo(withId: id, lastCommentUpdate: lastCommentUpdate, onSuccess: { (room) in
            onSuccess(room)
        }) { (error) in
            onError(error)
        }
    }
    
    public class func roomsInfo(withIds ids:[String], onSuccess:@escaping (([QRoom])->Void), onError: @escaping ((String)->Void)){
        QChatService.roomsInfo(withIds: ids, onSuccess: { (rooms) in
            onSuccess(rooms)
        }) { (error) in
            onError(error)
        }
    }
    public class func channelInfo(withName name:String, onSuccess:@escaping ((QRoom)->Void), onError: @escaping ((String)->Void)){
        QChatService.roomInfo(withUniqueId: name, onSuccess: { (room) in
            if !room.isInvalidated {
                onSuccess(room)
            }else{
                Qiscus.channelInfo(withName: name, onSuccess: onSuccess, onError: onError)
            }
        }) { (error) in
            onError(error)
        }
    }
    
    public class func channelsInfo(withNames names:[String], onSuccess:@escaping (([QRoom])->Void), onError: @escaping ((String)->Void)){
        QChatService.roomsInfo(withUniqueIds: names, onSuccess: { (rooms) in
            onSuccess(rooms)
        }) { (error) in
            onError(error)
        }
    }
    
    public class func removeAllFile(){
        let filemanager = FileManager.default
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory,.userDomainMask,true)[0] as NSString
        let destinationPath = documentsPath.appendingPathComponent("Qiscus")
        
        do {
            try filemanager.removeItem(atPath: destinationPath)
        } catch {
            Qiscus.printLog(text: "Could not clear Qiscus folder: \(error.localizedDescription)")
        }
        
    }
    public class func cancellAllRequest(){
        let sessionManager = QiscusService.session
        sessionManager.session.getAllTasks { (allTask) in
            allTask.forEach({ (task) in
                task.cancel()
            })
        }
    }
    public class func removeDB(){
        let realm = try! Realm(configuration: Qiscus.dbConfiguration)
        realm.refresh()
        try! realm.write {
            realm.deleteAll()
        }
        let filemanager = FileManager.default
        do {
            try filemanager.removeItem(at: Qiscus.dbConfiguration.fileURL!)
        } catch {
            Qiscus.printLog(text: "Could not clear Qiscus folder: \(error.localizedDescription)")
        }
    }
    
    internal class func logFile()->String{
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory,.userDomainMask,true)[0] as NSString
        let logPath = documentsPath.appendingPathComponent("Qiscus.log")
        return logPath
    }
    
    public class func removeLogFile(){
        let filemanager = FileManager.default
        let logFilePath = Qiscus.logFile()
        do {
            try filemanager.removeItem(atPath: logFilePath)
        } catch {
            Qiscus.printLog(text: "Could not clear Qiscus folder: \(error.localizedDescription)")
        }
    }
    
    public class func backgroundSync(){
        QChatService.backgroundSync()
    }
    public class func syncEvent(){
        QChatService.syncEvent()
    }
}
