//
//  ProgressVC.swift
//  Example
//
//  Created by Ahmad Athaullah on 9/25/17.
//  Copyright © 2017 Ahmad Athaullah. All rights reserved.
//

import UIKit
import Qiscus

class ProgressVC: UIViewController {

    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let logoutButton = UIBarButtonItem(image: UIImage(named: "ic_exit_to_app"), style: .plain, target: self, action: #selector(logOut))
        self.navigationItem.leftBarButtonItems = [logoutButton]
        // Do any additional setup after loading the view.
    }
    @objc func logOut(){
        Qiscus.clear()
        self.appDelegate.goToLoginView()
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        //self.progressView.setProgress(0.57, animated: true)
        
        Qiscus.fetchAllRoom(loadLimit: 50, onSuccess: { (rooms) in
            self.appDelegate.goToRoomList(rooms: rooms)
        }, onError: { (error) in
            print("error")
        }) { (progress, loadedRoom, totalRoom) in
            print("progress: \(progress) [\(loadedRoom)/\(totalRoom)]")
            let percentage = Int(100.0 * progress)
            self.descriptionLabel.text = "Load room : \(percentage) %   [\(loadedRoom)/\(totalRoom)]"
            self.progressView.setProgress(Float(progress), animated: true)
        }
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
//        for i in 1...9999 {
//            let pembagi = 10000 - i
////            if pembagi % 10 == 0 {
//            let progress = Float(Float(1)/Float(pembagi))
//                setProgress(withText: "progres: \(progress)", progress: progress)
////            }
//        }
    }
    func setProgress(withText text:String, progress:Float){
        DispatchQueue.main.async {
            self.descriptionLabel.text = text
            self.progressView.setProgress(progress, animated: true)
        }
    }
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
