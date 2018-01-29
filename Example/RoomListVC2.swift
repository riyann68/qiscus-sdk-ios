//
//  RoomListVC2.swift
//  Example
//
//  Created by Ahmad Athaullah on 9/15/17.
//  Copyright © 2017 Ahmad Athaullah. All rights reserved.
//

import UIKit
import Qiscus

class RoomListVC2: UIViewController {

    @IBOutlet weak var roomListView: QRoomList!
    @IBOutlet weak var loadingView: UIView!
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    var rooms = [QRoom]()
    
    override func viewDidLoad() {
        NotificationCenter.default.addObserver(self, selector: #selector(RoomListVC2.qiscusStartCloudSync(_:)), name: QiscusNotification.START_CLOUD_SYNC, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(RoomListVC2.qiscusFinishedCloudSync(_:)), name: QiscusNotification.FINISHED_CLOUD_SYNC, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(RoomListVC2.qiscusErrorCloudSync(_:)), name: QiscusNotification.ERROR_CLOUD_SYNC, object: nil)
        
        super.viewDidLoad()

        self.title = "Chat List"
        
        self.roomListView.listDelegate = self
        
        let logoutButton = UIBarButtonItem(image: UIImage(named: "ic_exit_to_app"), style: .plain, target: self, action: #selector(logOut))
        self.navigationItem.leftBarButtonItems = [logoutButton]
        let addButton = UIBarButtonItem(title: "+", style: .plain, target: self, action: #selector(addChat))
        let searchButton = UIBarButtonItem(title: "s", style: .plain, target: self, action: #selector(searchText))

        let rightBarButtons = [ addButton, searchButton]
        self.navigationItem.rightBarButtonItems = rightBarButtons
        
    }
    @objc private func qiscusStartCloudSync(_ notification: Notification){
        DispatchQueue.main.async {
            self.loadingView.isHidden = false
        }
    }
    @objc private func qiscusFinishedCloudSync(_ notification: Notification){
        DispatchQueue.main.async {
            self.loadingView.isHidden = true
        }
        
    }
    @objc private func qiscusErrorCloudSync(_ notification: Notification){
        if let userInfo = notification.userInfo {
            if let error = userInfo["error"] as? String {
                print("error cloud sync: \(error)")
                self.loadingView.isHidden = true
            }
        }
        
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        //self.showQiscusLoading()
        //self.rooms = QRoom.all()
        
        if self.rooms.count > 0 {
            //self.roomListView.rooms = self.rooms
            self.roomListView.reload()
            Qiscus.subscribeAllRoomNotification()
            if let user = QUser.user(withEmail: "userid_117_6285727170251@kiwari-prod.com") {
                user.setName(name: "Ashari J")
            }
            if let room = QRoom.room(withId: "13006") {
                room.setName(name: "Test User")
            }
            //self.dismissQiscusLoading()
        }else{
            self.showQiscusLoading()
            self.loadRoomList()
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @objc func searchText(){
        self.roomListView.search(text: "kiwari")
    }
    func loadRoomList(){
        
        Qiscus.fetchAllRoom(onSuccess: { (rooms) in
            self.rooms = rooms
            self.roomListView.rooms = rooms
            self.roomListView.reloadData()
            Qiscus.subscribeAllRoomNotification()
            
            self.dismissQiscusLoading()
        }, onError: { (error) in
            print("error")
        }) { (progress, loadedRoom, totalRoom) in
            print("progress: \(progress) [\(loadedRoom)/\(totalRoom)]")
        }
    }
    
    @objc func logOut(){
        Qiscus.clear()
        self.appDelegate.goToLoginView()
    }
    @objc func addChat(){
        let actionSheetController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        let cancelActionButton = UIAlertAction(title: "Cancel", style: .cancel) { action -> Void in
            print("Cancel")
        }
        actionSheetController.addAction(cancelActionButton)
        
        let singleChat = UIAlertAction(title: "Add Single Chat", style: .default) { action -> Void in
            self.createChat(type: .single)
        }
        actionSheetController.addAction(singleChat)
        
        let groupChat = UIAlertAction(title: "Add Group Chat", style: .default) { action -> Void in
            self.createChat(type: .group)
        }
        actionSheetController.addAction(groupChat)
        
        let channelChat = UIAlertAction(title: "Add Channel", style: .default) { action -> Void in
            self.createChat(type: .channel)
        }
        actionSheetController.addAction(channelChat)
        
        self.present(actionSheetController, animated: true, completion: nil)
    }
    func createChat(type:AddChatType){
        let view = goToChatVC()
        view.type = type
        self.navigationController?.pushViewController(view, animated: true)
    }
    
}
extension RoomListVC2: QRoomListDelegate {
    func didSelect(room: QRoom) {
        let chatView = Qiscus.chatView(withRoomId: room.id)
        self.navigationController?.pushViewController(chatView, animated: true)
    }
    func didSelect(comment: QComment) {
        
    }
}
extension QRoomList {
    func commentCell(at indexPath: IndexPath) -> UITableViewCell{
    return UITableViewCell()
    }
    
}

