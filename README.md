# Qiscus SDK iOS

<p align="center"><br/><img src="https://res.cloudinary.com/qiscus/image/upload/zKB8jtyLZJ/ssios1.png" width="45%" /><br/></p>

# Quick Start

### Create a new app

Register on [https://www.qiscus.com/dashboard](https://www.qiscus.com/dashboard) using your email and password and then create new application

You should create one application per service, regardless of the platform. For example, an app released in both Android and iOS would require only one application to be created in the Dashboard.

All users within the same Qiscus application are able to communicate with each other, across all platforms. This means users using iOS, Android, web clients, etc. can all chat with one another. However, users in different Qiscus applications cannot talk to each other.

Done! Now you can use the APP_ID into your apps and get chat functionality by implementing Qiscus into your app.


### integrating SDK with an existing app

[CocoaPods](http://cocoapods.org/) is a dependency manager for Cocoa projects. You can install it with the following command:


```
$ gem install cocoapods
```

> CocoaPods 1.1.0+ is required.

Podfile :

```
target 'Sample' do

  .....
  use_frameworks!

  .....
  pod 'Qiscus'
  .....

end

```

Install Qiscus through CocoaPods

```
$ pod install
```

# Authentication

### Init with App ID

To initiate Qiscus SDK, you need to import Qiscus and then add this in your code everywhere you want

**Swift 3.0:**

```
import Qiscus


Qiscus.setup( withAppId: YOUR_APP_ID, 
              userEmail: CURRENT_USER_EMAIL, 
              userKey: CURRENT_USER_PASSWORD, 
              username: CURRENT_USER_USERNAME, 
              avatarURL: CURRENT_USER_AVATAR_URL, 
              delegate: self
)
```

**Using the  SDK in Objective-C**


```
import Qiscus

[Qiscus setupWithAppId:<YOUR_APP_ID> 
        userEmail:<USER_EMAIL> 
        userKey:<USER_KEY> 
        username:<USER_NAME> 
        avatarURL:<USER_AVATAR_URL> 
        delegate:self 
        secureURl:<true|false>];
```


**Example on AppDelegate.swift**


```
func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        let viewController = ViewController()
        let navigationController = UINavigationController(rootViewController: viewController)
        
        Qiscus.setup( withAppId: "DragonGo",
                      userEmail: "abcde@qiscus.coom",
                      userKey: "abcd1234",
                      username: "Steve Kusuma",
                      avatarURL: "",
                      delegate: nil
        )
        
        self.window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = navigationController
        window?.makeKeyAndVisible()

        return true
}
```

### Updating a User Profile and Avatar

Updating user profile and details is simply by re-init the user using new details :


```
        Qiscus.setup( withAppId: "DragonGo",
                      userEmail: "abcde@qiscus.coom",
                      userKey: "abcd1234",
                      username: "Steve Kusuma New Name",
                      avatarURL: "https://myimage.com/myNewImage.png",
                      delegate: nil
        )
```

# Chat Rooms 

### Creating 1-to-1 chat

Start chat with target is very easy, all you need is just call

Swift 3.0 :

```
      let email = targetField.text!
      let view = Qiscus.chatView(withUsers: [email])
      self.navigationController?.pushViewController(view, animated: true)
```



in your code

For example in your ViewController :

Swift 3.0:

```
import UIKit
import Qiscus

class ViewController: UIViewController {

.....

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        let button = UIButton(frame: CGRect(x: 100, y:100, width:100, height:30))
        button.backgroundColor = UIColor.green
        button.setTitle("Start Chat", for: .normal)
        button.addTarget(self, action: #selector(ViewController.startChat), for: .touchUpInside)
        self.view.addSubview(button)
        
    }
    
    func startChat(){
        let email = targetField.text!
        let view = Qiscus.chatView(withUsers: [email])
        self.navigationController?.pushViewController(view, animated: true)
    }

.....
}
```



### Creating a Group Room

Qiscus also support group chat. To create new group chat, all you need is just call

Swift 3.0:

`Qiscus.createChatView(withUsers: ["TARGET_EMAIL_1, TARGET_EMAIL_2"], title: "CHAT_GROUP_TITLE")`

For example in your ViewController :

Swift 3.0

```
import UIKit
import Qiscus

class ViewController: UIViewController {

    .....
    func goToChat(){
        let chatTargets = ["081111111111@qiscuswa.com, 081234567890@qiscuswa.com"]
        let view = Qiscus.createChatView(withUsers: chatTargets, title: "New Group Chat")
        self.navigationController?.pushViewController(view, animated: true)
    }
    .....
}
```


for accesing room that created by this call, you need to call it with its roomId. This methode is always creating new chat room.


### Get a room by id


When you already know your chat room id, you can easily go to that room. Just call

Swift 3.0:

`Qiscus.chatView(withRoomId: roomId)`


For example in your ViewController :

Swift 3.0

```
import UIKit
import Qiscus

class ViewController: UIViewController {

.....

  func goToChat(){
          let roomId = Int(targetField.text!)
          let view = Qiscus.chatView(withRoomId: roomId)
          self.navigationController?.pushViewController(view, animated: true)
  }

.....
}
```

### Create or join room by defined id

You probably want to set defined id for the room you are creating so that the id can be reference for users to get into.

Usual usage for this is when user create common room or channel which expecting other users can join to the same channel by knowing the channel name or id, you can use the channel name or id as qiscus room defined id.

Additional note: 
If room with predefined unique id is not exist then it will create a new one with requester as the only one participant. Otherwise, if room with predefined unique id is already exist, it will return that room and add requester as a participant.

When first call (room is not exist), if requester did not send avatar_url and/or room name it will use default value. But, after the second call (room is exist) and user (requester) send avatar_url and/or room name, it will be updated to that value. Object changed will be true in first call and when avatar_url or room name is updated.


Swift 3.0:

`Qiscus.chatView(withRoomUniqueId: uniqueId)`


For example in your ViewController :

Swift 3.0

```
import UIKit
import Qiscus

class ViewController: UIViewController {

.....

  func goToChat(){
          let roomId = Int(targetField.text!)
          let view = Qiscus.chatView(withRoomUniqueId: uniqueId)
          self.navigationController?.pushViewController(view, animated: true)
  }

.....
}
```

### Inviting users to an existing Room

Currently we recommend to invite user into existing room through our **REST API** for simplicity and security reason

### Leaving a Group Room

Currently we recommend to kick user out of specific room through our **REST API** for simplicity and security reason

### Get Rooms List

We can get room list for the user by executing this function, however no `view` being returned. The function will only return data of the rooms

```
QChatService.roomList(withLimit: 100, page: page, onSuccess: { (rooms, totalRoom, currentPage, limit) in
            print("room list: \(rooms)")
        }) { (error) in
            print("\(error)")
        }
```


# Event Handler

**QiscusConfigDelegate**

```
class MainView: UIViewController, QiscusConfigDelegate {

    // MARK: - QiscusConfigDelegate
    func qiscusFailToConnect(_ withMessage:String){
        print(withMessage)
        ...
    }
    func qiscusConnected(){
        appDelegate.goToChatNavigationView()
        ...
    }
}
```


**QiscusRoomDelegate**

```
class SampleAppRealtime: QiscusRoomDelegate {
    
    // MARK: - Member of QiscusRoomDelegate
    internal func gotNewComment(_ comments: QiscusComment) {
        print("getting new messages")
    }
    
    internal func didFinishLoadRoom(onRoom room: QiscusRoom) {
        print("did finish load roomId: \(localRoom.roomId), roomName: \(localRoom.roomName)")
    }
    
    internal func didFailLoadRoom(withError error: String) {
        print("did fail load room error: \(error)")
    }

    func didFinishUpdateRoom(onRoom room: QiscusRoom) {
        print("did finish update room roomId: \(localRoom.roomId), roomName: \(localRoom.roomName)")
    }
    
    func didFailUpdateRoom(withError error:String) {
        print("did fail update room: \(error)")
    }
    
}
```

# UI Customization

### Theme Customization

Lots of our items inside Chat Room can be modified based on our needs, here is the example of the customisation that can be done easily

```
 
  let qiscusColor = Qiscus.style.color
  qiscusColor.welcomeIconColor = colorConfig.chatWelcomeIconColor
  qiscusColor.leftBaloonColor = colorConfig.chatLeftBaloonColor
  qiscusColor.leftBaloonTextColor = colorConfig.chatLeftTextColor
  qiscusColor.leftBaloonLinkColor = colorConfig.chatLeftBaloonLinkColor
  qiscusColor.rightBaloonColor = colorConfig.chatRightBaloonColor
  qiscusColor.rightBaloonTextColor = colorConfig.chatRightTextColor
        
  Qiscus.setNavigationColor(colorConfig.baseNavigateColor, tintColor: colorConfig.baseNavigateTextColor)

  let fontSize: CGFloat = CGFloat(17).flexibleIphoneFont()
  Qiscus.style.chatFont = UIFont.systemFont(ofSize: fontSize)
  
```

### UI Source code

If you want full customisations, you can modify everything on the view by extend our `QiscusChatVC` based on your needs.

here is sample of modification by extending our `QiscusChatVC` :

```
class QChatView: QiscusChatVC {
    var actions : [ChatAction]? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        // self.collectionViewTopMargin.constant = 100
        self.backgroundView.isHidden    = true

        let iconCall        = UIImage(named: "ic_phone_call", in: QChat.bundle, compatibleWith: nil)
        let iconCallVideo   = UIImage(named: "ic_video_call", in: QChat.bundle, compatibleWith: nil)
        let iconEnd         = UIImage(named: "ic_end_consultation", in: QChat.bundle, compatibleWith: nil)
        
        let endButton = UIButton(frame: CGRect(x: 0, y: 0, width: 40, height: 20))
        endButton.setBackgroundImage(iconEnd, for: .normal)
        endButton.imageView?.contentMode = UIViewContentMode.scaleAspectFit
        endButton.addTarget(self, action: #selector(endConsultation), for: .touchUpInside)
        let barButtonEnd    = UIBarButtonItem(customView: endButton)

        let callButton = UIButton(frame: CGRect(x: 0, y: 0, width: 20, height: 20))
        callButton.setBackgroundImage(iconCall, for: .normal)
        callButton.imageView?.contentMode = UIViewContentMode.scaleAspectFit
        callButton.addTarget(self, action: #selector(addTapped), for: .touchUpInside)
        let barButtonCall    = UIBarButtonItem(customView: callButton)
        
        let callVideoButton = UIButton(frame: CGRect(x: 0, y: 0, width: 30, height: 20))
        callVideoButton.setBackgroundImage(iconCallVideo, for: .normal)
        callVideoButton.imageView?.contentMode = UIViewContentMode.scaleAspectFit
        callVideoButton.addTarget(self, action: #selector(addTapped), for: .touchUpInside)
        let barButtonCallVideo    = UIBarButtonItem(customView: callVideoButton)
        
        navigationItem.rightBarButtonItems = [barButtonEnd, barButtonCallVideo, barButtonCall]
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.tabBarController?.tabBar.isHidden = true
    }
    
    func addTapped() {
        print("something")
    }
    
    func endConsultation() {
        postComment(type: "endConsultation", payload: "Semoga Lekas sembuh")
    }
    
    func postComment(type: String, payload: String) {
        let newComment = self.chatRoom?.newCustomComment(type: type, payload: payload, text: "Pesan Doktor")
        self.chatRoom?.post(comment: newComment!)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        return super.collectionView(collectionView, cellForItemAt: indexPath)
    }
}
```


# Push Notifications 

Currently we recommend to use our Webhook-API to push notification from your own server to client app for simplicity and flexibility handling

# Offline Messages

## Post Messages

During post message, if you dont have any internet connection, message will be store locally and will be automatically being send once your internet connection is back. 

## Get Messages

Messages are stored locally so you can still access the messages when you dont have internet conenction. However any new messages will not being received after you have your internet connection back.



# Notes

Don't forget to add usage description for camera, photo library and microphone to your **info.plist **to use our attachment functionality in chat SDK

```
<key>NSCameraUsageDescription</key>
<string>Need camera access for uploading Images</string>
<key>NSContactsUsageDescription</key>
<string>Need access for sync contact</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>$(PRODUCT_NAME) location use</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>$(PRODUCT_NAME) location use</string>
<key>NSMicrophoneUsageDescription</key>
<string>$(PRODUCT_NAME) microphone use</string>
<key>NSPhotoLibraryAddUsageDescription</key>
<string>NeedLibrary access for uploading and Images</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>NeedLibrary access for uploading and Images</string>
```


