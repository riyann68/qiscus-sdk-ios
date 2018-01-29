//
//  RoomListVC.swift
//  Example
//
//  Created by Ahmad Athaullah on 9/8/17.
//  Copyright © 2017 Ahmad Athaullah. All rights reserved.
//

import UIKit
import Qiscus

class RoomListVC: UITableViewController {
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    var rooms = [QRoom]() {
        didSet{
            self.tableView.reloadData()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Chat List"
        self.tableView.register(UINib(nibName: "RoomListCell", bundle: nil), forCellReuseIdentifier: "roomCell")
        self.tableView.rowHeight = 63.0
        self.tableView.tableFooterView = UIView()
        
        let logoutButton = UIBarButtonItem(image: UIImage(named: "ic_exit_to_app"), style: .plain, target: self, action: #selector(logOut))
        self.navigationItem.leftBarButtonItems = [logoutButton]
        let addButton = UIBarButtonItem(title: "+", style: .plain, target: self, action: #selector(addChat))
        let rightBarButtons = [ addButton]
        self.navigationItem.rightBarButtonItems = rightBarButtons
        
        Qiscus.chatDelegate = self
        
//        let center: NotificationCenter = NotificationCenter.default
//        center.addObserver(self, selector: #selector(RoomListVC.userTyping(_:)), name: QiscusNotification.USER_TYPING, object: nil)
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.showQiscusLoading()
        self.rooms = QRoom.all()
        
        if self.rooms.count == 0 {
            self.loadRoomList()
        }else{
            Qiscus.subscribeAllRoomNotification()
            self.dismissQiscusLoading()
        }
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return self.rooms.count
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "roomCell", for: indexPath) as! RoomListCell
        cell.room = self.rooms[indexPath.row]

        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let room = self.rooms[indexPath.row]
        let chatView = Qiscus.chatView(withRoomId: room.id)
        self.navigationController?.pushViewController(chatView, animated: true)
    }
    
    func loadRoomList(){
        Qiscus.fetchAllRoom(onSuccess: { (rooms) in
            self.rooms = rooms
            self.tableView.reloadData()
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

extension RoomListVC: QiscusChatDelegate {
    func qiscusChat(gotNewComment comment: QComment) {  self.rooms = QRoom.all() }
    func qiscusChat(gotNewRoom room: QRoom) { self.rooms = QRoom.all() }
}
