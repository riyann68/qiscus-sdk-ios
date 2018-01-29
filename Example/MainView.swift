//
//  MainView.swift
//  SampleSDK
//
//  Created by Ahmad Athaullah on 1/11/17.
//  Copyright © 2017 Evan Purnama. All rights reserved.
//

import UIKit
import Qiscus

class MainView: UIViewController {

    @IBOutlet weak var appIdField: UITextField!
    @IBOutlet weak var emailField: UITextField!
    @IBOutlet weak var userKeyField: UITextField!
    @IBOutlet weak var userNameField: UITextField!
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //self.navigationController?.isNavigationBarHidden = true
        let dismissRecognizer = UITapGestureRecognizer(target: self, action: #selector(MainView.hideKeyboard))
        self.view.addGestureRecognizer(dismissRecognizer)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func login(_ sender: UIButton) {
        self.showQiscusLoading()
        appDelegate.qiscusLogin(withAppId: appIdField.text!, userEmail: emailField.text!, userKey: userKeyField.text!, username: userNameField.text!)
    }
    @objc func hideKeyboard(){
        self.view.endEditing(true)
    }
    
    
}
