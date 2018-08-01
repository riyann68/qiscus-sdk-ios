# Advance Section

## Server Authentication

Another option is to authenticate using Json Web Token [(JWT)](https://jwt.io/). Json Web Token contains your app account details which typically consists of a single string which contains information of two parts, Jose header and JWT claims set. 

The steps to authenticate with JWT goes like this:

1. The Client App request a nonce from Qiscus SDK server
2. Qiscus SDK Server will send Nonce to client app
3. Client App send user credentials and Nonce that is obtained from Qiscus SDK Server to Client app backend
4. The Client App backend will send the token to client app
5. The Client App send that token to Qiscus Chat SDK
6. Qiscus Chat SDK send Qiscus Account to Client app

<p align="center"><br/><img src="https://raw.githubusercontent.com/qiscus/qiscus-sdk-android/develop/screenshot/jwt.png" width="80%" /><br/></p>

You need to request Nonce from Qiscus Chat SDK Server. Nonce (Number Used Once) is a unique, randomly generated string used to identify a single request. Please be noted that a Nonce will expire in 10 minutes. So you need to implement your code to request JWT from your backend right after you got the returned Nonce. Here is how to authenticate to Qiscus Chat SDK using JWT :

Client side will call Qiscus.getNonce() to request Nonce from Qiscus SDK Server.

```swift
import Qiscus

Qiscus.getNonce(withAppId: "APP_ID", onSuccess: { (nonce) in
    print("get nonce here : \(nonce)")
}, onFailed: { (error) in
    print("error : \(error)")
})
```
The code above is a sample of method you can implement in your app. By calling Qiscus.getNonce(), you will request Nonce from Qiscus SDK server and a Nonce will be returned. If it is success, you can request JWT from your backend by sending Nonce you got from Qiscus SDK Server. 
When you got the JWT Token, you can pass that JWT to Qiscus.setup(withUserIdentityToken: "IDENTITY_TOKEN") method to allow Qiscus to authenticate your user and return user account, as shown in the code below :

```swift
import Qiscus

Qiscus.setup(withUserIdentityToken: "IDENTITY_TOKEN")
```

If you are wondering the full implementation of JWT authentication, here is the full code sample:

```swift
import Qiscus

Qiscus.getNonce(withAppId: YOUR_APP_ID, onSuccess: { (nonce) in
    print("get nonce here : \(nonce)")    
    
    // this is your own service that call your own server
    // you pass your user credential together with nonce from Qiscus server that just being received
    MyHTTPService.callAuth(params: {user: userDetails, nonce: nonce}, onSuccess: { (data) in
    
        // success authenticate to your own server
        // now time to verify the identity token from your server to Qiscus Server
        Qiscus.setup( 
              withUserIdentityToken: data.identity_token,
              delegate: self
        )
    }, onError: { (error) in 
        // your auth error callback
    })
}, onError: { (error) in
    print("error : \(error)")
})
```
##Setting JOSE header and JWT Claim Set in your backend

When your backend returns a JWT after receiving Nonce from your client app, the JWT will be caught by client app and will be forwarded to Qiscus Chat SDK Server. In this phase, Qiscus Chat SDK Server will verify the JWT before returning Qiscus Account for your user. To allow Qiscus Chat SDK Server successfully recognize the JWT, you need to setup Jose Header and JWT claim set in your backend as follow :

**Jose Header :**
```
{
  "alg": "HS256",  // must be HMAC algorithm
  "typ": "JWT", // must be JWT
  "ver": "v2" // must be v2
}
```
**JWT Claim Set :**
```
{
  "iss": "QISCUS SDK APP ID", // your qiscus app id, can obtained from dashboard
  "iat": 1502985644, // current timestamp in unix
  "exp": 1502985704, // An arbitrary time in the future when this token should expire. In epoch/unix time. We encourage you to limit 2 minutes
  "nbf": 1502985644, // current timestamp in unix
  "nce": "nonce", // nonce string as mentioned above
  "prn": "YOUR APP USER ID", // your user identity such as email or id, should be unique and stable
  "name": "displayname", // optional, string for user display name
  "avatar_url": "" // optional, string url of user avatar
}
```


## UI Customization

### Basic Customization
Qiscus Chat SDK enable you to customize Chat UI as you like. You can modify colors, change bubble chat design, modify Chat Header, and many more. All customization method are inside `Qiscus.style()`. By calling it, you can simply look at the autocomplete suggestion in your IDE to see lots of methods to modify your Chat Interface.

```swift
  // example of modifying colors
  let qiscusColor = Qiscus.style.color
  qiscusColor.welcomeIconColor = colorConfig.chatWelcomeIconColor
  qiscusColor.leftBaloonColor = colorConfig.chatLeftBaloonColor
  qiscusColor.leftBaloonTextColor = colorConfig.chatLeftTextColor
  qiscusColor.leftBaloonLinkColor = colorConfig.chatLeftBaloonLinkColor
  qiscusColor.rightBaloonColor = colorConfig.chatRightBaloonColor
  qiscusColor.rightBaloonTextColor = colorConfig.chatRightTextColor    

  // example of modiying font
  let fontSize: CGFloat = CGFloat(17).flexibleIphoneFont()
  Qiscus.style.chatFont = UIFont.systemFont(ofSize: fontSize)

```

### Advance Customization

For advance customization, you can only use our Core SDK API for the data flow and use your own full UI. By using this approach you will have full control over the UI. We have sample on how you can do it and there are documentation on list of core api that we provide in the SDK. check it here [https://bitbucket.org/qiscus/qiscus-sdk-core-ios-sample](https://bitbucket.org/qiscus/qiscus-sdk-core-ios-sample)


## Event Handler

An Event Handler is a callback routine that operates asynchronously and handles inputs received into a program. Event Handlers are important in Qiscus because it allows a client to react to any events happening in Qiscus Chat SDK. For example, if a client wants to know any important events from server, such as success login event, client's app can be notified by calling a specific Event Handler. Client, then, can do things with data returned by the event.

There are 3 type of Event Handler that are provided by Qiscus Chat SDK: **QiscusConfigDelegate,** **QiscusNotification** and **QiscusChatVCDelegate**. 
**QiscusConfigDelegate** provides event handler that are related to Qiscus Chat SDK initialization such as events for push notification and event synchronize, while **QiscusNotification** provides event handlers that are related to room and messaging. **QiscusChatVCDelegate** provide event handlers to modify functionalities inside your chat room.

### Qiscus Config Delegate
Here the list of Event Handler provided in QiscusConfigDelegate:

* qiscusFailToConnect(_ withMessage: String)
* qiscusConnected()
* qiscus(gotSilentNotification comment: QComment)
* qiscus(didConnect succes: Bool, error: String?)
* qiscus(didRegisterPushNotification success: Bool, deviceToken: String, error: String?)
* qiscus(didUnregisterPushNotification success: Bool, error: String?)
* qiscus(didTapLocalNotification comment: QComment, userInfo: [AnyHashable : Any]?)
* qiscusStartSyncing()
* qiscus(finishSync success: Bool, error: String?)

To use event handler inside your app, you will need to extend  QiscusConfigDelegate or QiscusNotification, so that you can see all event handlers that are provided by the class, then you can do whatever you need to do inside the event handlers.

**Fail to Connect**

`qiscusFailToConnect()` is an event handler that is called when you fail to connect to Qiscus Chat SDK Service. 

```swift
func qiscusFailToConnect(_ withMessage: String) {
   // do anything if failed to connect to Qiscus Chat SDK 
}
```
**User Connected**

`qiscusConnected()` is an event handler that is called after you successfully connected to Chat SDK service.

```swift
func qiscusConnected() {
   // do anything after successfully connected to Qiscus Chat SDK
}
```
**Got Silent Notification**

This event handler is called when your user turned off the notification on his/her phone.
```swift
func qiscus(gotSilentNotification comment: QComment) {
   //do anything if got new message in silent mode
}
```

**Connect to Push Notification**

This event handler is called when you successfully connected to Qiscus Push Notification.
```swift
func qiscus(didConnect succes: Bool, error: String?) {
   //do anything after successfully connected to Qiscus Push Notification
}
```

**Registered Push Notification**

This event handler is called when you want to listen your status of push notification that you registered.
```swift
func qiscus(didRegisterPushNotification success: Bool, deviceToken: String, error: String?) {
   // got status of registering qiscus sdk
   // do anything after
}
```

**Unregistered Push Notification**

This event handler is called when you want to listen to your push notification status, whether your push notification is registered or not.
```swift
func qiscus(didUnregisterPushNotification success: Bool, error: String?) {
   // got status of un-registering qiscus sdk
}
```

**Tap Local Notification**

This event handler is called after push notification alert is clicked.
```swift
func qiscus(didTapLocalNotification comment: QComment, userInfo: [AnyHashable : Any]?) {
   // do anything after push notification alert is clicked
}
```

**Start Syncronizing**

This event handler is called when you start synchronizing messages.
```swift
func qiscusStartSyncing() {    
   // do anything when Qiscus Chat SDK start to synchronize messages
}
```

**Finish Syncronizing**

This event handler is called after your app finished synchronizing messages.
```swift
func qiscus(finishSync success: Bool, error: String?) {
   // do anything after synchronizing finished
```

### Notification Center

Qiscus Chat SDK provide Event Handler as notification center **QiscusNotification**, this event handler is a trigger while you're getting something changes, e.g: while got a new comment, there are avatars change, etc.

Here how to do that:

```swift
import Qiscus

override func viewDidLoad() {
    ...
    NotificationCenter.default.addObserver(self,
                                           selector: #selector(roomListChange(_:)),
                                           name: QiscusNotification.GOT_NEW_ROOM,
                                           object: nil)
}

@objc func roomListChange(_ sender: Notification) {
    DispatchQueue.main.asyncAfter(deadline: .now()+0.5) {
        // fetch data again
        self.viewModel.loadData()
    }
}
```

The following list are Event Handlers that are available in **QiscusNotification**. Just register an event you want to call using **QiscusNotification.NAME_OF_EVENT** on `viewDidLoad` section, then call your method like sample above.

* COMMENT_DELETE: When any comment is deleted
* MESSAGE_STATUS: when status of  message is changed. e.g: sending, pending, sent, delivered, read, failed
* USER_PRESENCE: provide response user presence (online/offline)
* USER_TYPING: provide response when user is typing  
* USER_AVATAR_CHANGE: provide response when user updated avatar
* GOT_NEW_ROOM: provide response when new room is created
* GOT_NEW_COMMENT: provide response when there is incoming message
* ROOM_CHANGE: provide response when any room is changed
* ROOM_DELETED: provide response when any room is deleted
* ROOM_ORDER_MAY_CHANGE: provide response for updating list of room
* USER_NAME_CHANGE : provide respon when any user changed his/her username

### Custom Chat Component

You can also customize your chat room components and functionalities by using Event handlers that are provided by **QiscusChatVCDelegate**.

Here is how to do that: 

```swift
import Qiscus

public class ChatManager: NSObject {
    static var shared = ChatManager()
    override private init() {}
    
    public class func chatWithRoomId(_ roomId: String, contact: Contact? = nil) -> Void {
        let chatView = Qiscus.chatView(withRoomId: roomId)
        chatView.delegate = ChatManager.shared
        chatView.data = contact
        
        chatView.hidesBottomBarWhenPushed = true
        openViewController(chatView)
    }
    ...
}

extension ChatManager: QiscusChatVCDelegate {
    func chatVC(enableForwardAction viewController:QiscusChatVC)->Bool {
        return true // true to enable forward feature
    }

    func chatVC(enableInfoAction viewController:QiscusChatVC)->Bool {
        return true // true to show message info
    }
    
    func chatVC(overrideBackAction viewController:QiscusChatVC)->Bool {
        return true // true to custom back action
    }
        
    func chatVC(backAction viewController:QiscusChatVC, room:QRoom?, data:Any?) {
        // custom back button action
    }
    
    func chatVC(titleAction viewController:QiscusChatVC, room:QRoom?, data:Any?) {
        // custom title action
    }
    
    func chatVC(viewController:QiscusChatVC, onForwardComment comment:QComment, data:Any?) {
        // custom forward message action
    }
    
    func chatVC(viewController:QiscusChatVC, infoActionComment comment:QComment,data:Any?) {
        // custom info message action
    }
        
    func chatVC(onViewDidLoad viewController:QiscusChatVC) {
        // call your method while view is loaded
    }
    
    func chatVC(viewController:QiscusChatVC, willAppear animated:Bool) {
        // call your method while view is appearing
    }
    
    func chatVC(viewController:QiscusChatVC, willDisappear animated:Bool) {
        // call your method while view will be disappeared
    }
        
    func chatVC(viewController:QiscusChatVC, willPostComment comment:QComment, room:QRoom?, data:Any?)->QComment? {
        // call your method while SDK is posting any comment
    }
        
    func chatVC(viewController:QiscusChatVC, cellForComment comment:QComment)->QChatCell? {
        // to change SDK cell with your own cell
    }
    
    func chatVC(viewController:QiscusChatVC, heightForComment comment:QComment)->QChatCellHeight? {
        // change the height of cell, if you use your own cell
        // PS: Don't change the height of default cell, this will broke the view
    }
}
```
