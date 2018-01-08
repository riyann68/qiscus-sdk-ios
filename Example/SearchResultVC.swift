//
//  SearchResultVC.swift
//  Example
//
//  Created by Ahmad Athaullah on 9/5/17.
//  Copyright © 2017 Ahmad Athaullah. All rights reserved.
//

import UIKit
import Qiscus

class SearchResultVC: UITableViewController {
    var comments = [QComment](){
        didSet{
        
        }
    }
    var searchText:String = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Search Result"
        self.tableView.dataSource = self
        self.tableView.register(UINib(nibName: "SearchCell", bundle: nil), forCellReuseIdentifier: "searchCell")
        self.tableView.estimatedRowHeight = 300
        self.tableView.rowHeight = UITableViewAutomaticDimension
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.comments.count
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "searchCell", for: indexPath)
        if let targetCell = cell as? SearchCell {
            targetCell.searchString = self.searchText
            targetCell.comment = self.comments[indexPath.row]
        }

        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let comment = self.comments[indexPath.row]
        let view = Qiscus.chatView(withRoomId: comment.roomId)
        view.chatTarget = comment
        self.navigationController?.pushViewController(view, animated: true)
//        view.titleAction = {
//            print("title clicked")
//        }
//        view.forwardAction = {(comment) in
//            view.navigationController?.popViewController(animated: true)
//            comment.forward(toRoomWithId: "13006")
//            let newView = Qiscus.chatView(withRoomId: "13006")
//            self.navigationController?.pushViewController(newView, animated: true)
//        }
//        view.infoAction = {(comment) in
//            let statusInfo = comment.statusInfo!
//            print("commentInfo: \(statusInfo)")
//            print("delivered to: \(statusInfo.deliveredUser)")
//            print("read by: \(statusInfo.readUser)")
//        }
    }
        
}
