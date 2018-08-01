//
//  QRoomList.swift
//  Example
//
//  Created by Ahmad Athaullah on 9/15/17.
//  Copyright © 2017 Ahmad Athaullah. All rights reserved.
//

import UIKit
@objc public protocol QRoomListDelegate {
    /**
     Click Cell and redirect to chat view
     */
    @objc optional func didSelect(room: QRoom)
    @objc optional func didDeselect(room:QRoom)
    @objc optional func didSelect(comment: QComment)
    @objc optional func didDeselect(comment:QComment)
    @objc optional func willLoad(rooms: [QRoom]) -> [QRoom]?
    /**
     Return your custom table view cell as QRoomListCell
    */
    @objc optional func tableviewCell(for room: QRoom) -> QRoomListCell?
}

open class QRoomList: UITableView{
    public var listDelegate: QRoomListDelegate?
    
    public var rooms = [QRoom]()
    private var clearingData:Bool = false
    
    public var filteredRooms: [QRoom] {
        get{
            let text = searchText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            if text == "" {
                return self.rooms
            }else{
                return self.rooms.filter({ (room) in
                    return room.name.lowercased().contains(text)
                })
            }
        }
    }
    
    public var comments = [QComment](){
        didSet{
            let indexSet = IndexSet(integer: 1)
            self.reloadSections(indexSet, with: UITableViewRowAnimation.fade)
        }
    }
    
    public var searchText:String = "" {
        didSet{
            let indexSet = IndexSet(integer: 0)
            self.reloadSections(indexSet, with: .none)
        }
    }
    
    override open func draw(_ rect: CGRect) {
        // Drawing code
        self.delegate = self
        self.dataSource = self
        self.estimatedRowHeight = 60
        self.rowHeight = UITableViewAutomaticDimension
        self.tableFooterView = UIView()
        NotificationCenter.default.addObserver(self, selector: #selector(QRoomList.roomListChange(_:)), name: QiscusNotification.ROOM_ORDER_MAY_CHANGE, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(QRoomList.roomListChange(_:)), name: QiscusNotification.ROOM_DELETED, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(QRoomList.dataCleared(_:)), name: QiscusNotification.FINISHED_CLEAR_MESSAGES, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(QRoomList.newRoom(_:)), name: QiscusNotification.GOT_NEW_ROOM, object: nil)
        registerCell()
    }
 
    open func registerCell(){
        self.register(UINib(nibName: "QRoomListDefaultCell", bundle: Qiscus.bundle), forCellReuseIdentifier: "roomDefaultCell")
        self.register(UINib(nibName: "QSearchListDefaultCell", bundle: Qiscus.bundle), forCellReuseIdentifier: "searchDefaultCell")
    }
    internal func didSelectRoom(room: QRoom){
        self.listDelegate?.didSelect?(room: room)
    }
    internal func didSelectComment(comment: QComment){
        self.listDelegate?.didSelect?(comment: comment)
    }
    
    open func roomCell(at row: Int) -> QRoomListCell {
        let indexPath = IndexPath(row: row, section: 0)
        let cell = self.dequeueReusableCell(withIdentifier: "roomDefaultCell", for: indexPath) as! QRoomListDefaultCell
        return cell
    }
    
    open func commentCell(at row: Int) -> QSearchListCell{
        let indexPath = IndexPath(row: row, section: 1)
        let cell = self.dequeueReusableCell(withIdentifier: "searchDefaultCell", for: indexPath) as! QSearchListDefaultCell
        return cell
    }
    public func reload(){
        if !self.clearingData {
            let roomsData = QRoom.all()
            if let extRooms = self.listDelegate?.willLoad?(rooms: roomsData) {
                self.rooms = extRooms
            } else {
                self.rooms = roomsData
            }
            
            let indexSet = IndexSet(integer: 0)
            self.reloadSections(indexSet, with: .none)
        }
    }

    public func search(text:String, searchLocal: Bool = false){
        self.searchText = text
        
        if !searchLocal {
            QChatService.searchComment(withQuery: text, onSuccess: { (comments) in
                if text == self.searchText {
                    self.comments = comments
                }
            }) { (error) in
                Qiscus.printLog(text: "test")
            }
        } else {
            self.comments = Qiscus.searchComment(searchQuery: text)
        }
        
    }
    @objc private func dataCleared(_ notification: Notification){
        dataCleared()
        self.clearingData = true
    }
    @objc private func newRoom(_ notification: Notification){
        if let userInfo = notification.userInfo {
            if let room = userInfo["room"] as? QRoom {
                if room.isInvalidated {
                    self.reload()
                }else{
                    self.gotNewRoom(room: room)
                }
            }
        }
        
    }
    @objc private func roomListChange(_ notification: Notification){
        self.reload()
    }
    open func dataCleared(){
        self.reload()
    }
    open func gotNewRoom(room:QRoom){
        self.reload()
    }
    open func roomListChange(){
        self.rooms = QRoom.all()
        let indexSet = IndexSet(integer: 0)
        self.reloadSections(indexSet, with: .none)
    }
    open func roomSectionHeight()->CGFloat{
        if self.searchText != ""{
            return 25.0
        } else {
            return 0
        }
    }
    
    open func commentSectionHeight()->CGFloat{
        if self.searchText != ""{
            return 25.0
        } else {
            return 0
        }
    }
    
    open func roomHeader()->UIView? {
        if self.searchText != "" {
            let screenWidth: CGFloat    = QiscusHelper.screenWidth()
            
            let container           = UIView(frame: CGRect(x: 0, y: 0, width: screenWidth, height: 25))
            let title               = UILabel(frame: CGRect(x: 8, y: 0, width: screenWidth - 16, height: 25))
            title.textAlignment     = NSTextAlignment.left
            title.textColor         = UIColor.black
            title.font              = UIFont.boldSystemFont(ofSize: 12)
            
            title.text = "Conversations"
            
            container.backgroundColor = UIColor.lightGray
            container.addSubview(title)
            return container
        } else {
            return nil
        }
    }
    
    open func commentHeader()->UIView?{
        if self.searchText != "" {
            let screenWidth: CGFloat    = QiscusHelper.screenWidth()
            let container           = UIView(frame: CGRect(x: 0, y: 0, width: screenWidth, height: 25))
            let title               = UILabel(frame: CGRect(x: 8, y: 0, width: screenWidth - 16, height: 25))
            title.textAlignment     = NSTextAlignment.left
            title.textColor         = UIColor.black
            title.font              = UIFont.boldSystemFont(ofSize: 12)
            
            title.text = "Messages"
            container.backgroundColor = UIColor.lightGray
            container.addSubview(title)
            return container
        } else {
            return nil
        }
    }
}

extension QRoomList: UITableViewDelegate,UITableViewDataSource {
    
    open func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return self.filteredRooms.count
        case 1:
            return self.comments.count
        default:
            return 0
        }
    }
    
    open func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    open func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // When filter or search active, top section is room result then comment result
        if indexPath.section == 0 {
            let room = self.filteredRooms[indexPath.row]
            // New approach Custom Cell
            if var cell = self.listDelegate?.tableviewCell?(for: room) {
                cell = self.dequeueReusableCell(withIdentifier: cell.reuseIdentifier!, for: indexPath) as! QRoomListCell
                cell.room = room
                cell.searchText = searchText
                return cell
            }
            let cell = self.roomCell(at: indexPath.row)
            cell.room = room
            cell.searchText = searchText
            return cell
        }else{
            let cell = self.commentCell(at: indexPath.row)
            cell.comment = self.comments[indexPath.row]
            cell.searchText = self.searchText
            return cell
        }
    }
    
    open func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 0 {
            didSelectRoom(room: self.filteredRooms[indexPath.row])
        }else{
            didSelectComment(comment: self.comments[indexPath.row])
        }
    }

    open func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        if indexPath.section == 0 {
            self.listDelegate?.didDeselect?(room: self.filteredRooms[indexPath.row])
        }else{
            self.listDelegate?.didDeselect?(comment: self.comments[indexPath.row])
        }
    }
    
    open func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == 0 {
            return self.roomSectionHeight()
        }else{
            return self.commentSectionHeight()
        }
    }
    
    open func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if section == 0 {
            return roomHeader()
        }else{
            return commentHeader()
        }
    }
}
