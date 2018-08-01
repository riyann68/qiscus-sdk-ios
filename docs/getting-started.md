# Getting Started

## Requirement

To install Qiscus Chat SDK you need to have CocoaPods installed. You can skip this part if you already installed CocoaPods.

[CocoaPods](http://cocoapods.org/) is a dependency manager for Cocoa projects and it is available for Swift or Objective-C. Here is how to install CocoaPods :

```cmd
 gem install cocoapods
```

To install Qiscus Chat SDK, you need to initiate pod to generate Podfile. You can do that by going to your app project and type the commend below:

```cmd
 pod init
```

After Podfile is initialized, open it and type 'Qiscus' in the pod section, pod 'Qiscus' is supporting Swift 4

```swift
  target 'Sample' do

  .....
  use_frameworks!

  .....
  pod 'Qiscus'
  .....

end
```

Install Qiscus through CocoaPods

```cmd
 pod install
```

Install Qiscus SDK for Swift 3 simply replace pod 'Qiscus' section with this following code in Podfile : 

```swift
pod 'Qiscus', '~> 2.7.5'
```

### Setting Permission

Before to start, you need to enable some permission by implementing few line of codes inside Info.plist file, to allow your app accessing phone camera for sending images, enable sharing location on your device, and many other functionalities. You can do that by right clicking on your Info.plist file → Open As → Source Code, then add the following codes:

```swift
<key>NSCameraUsageDescription</key>
<string>Need camera access for uploading Images</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Need library access for uploading Images</string>
<key>NSContactsUsageDescription</key>
<string>Need access for share contact</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>$(PRODUCT_NAME) location use</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>$(PRODUCT_NAME) location use</string>
```

There are several features of your phone that you can enable your app to access them : 

* **Camera**: to allow user upload image using his camera.
* **Gallery**: to allow user upload image from gallery/ file manager.
* **iCloud**: to allow user share his file from iCloud.
* **Contact**: to allow user share his contact.
* **Location**: to allow user share his location currently live.

To enable the features listed above, you need to add some code below, and set it to True :

```swift
Qiscus.shared.cameraUpload = true
Qiscus.shared.galeryUpload = true
Qiscus.shared.iCloudUpload = true
Qiscus.shared.contactShare = true
Qiscus.shared.locationShare = true
```

### Enable iCloud Feature
Specially for iCloud feature, you need to do some steps before you can share files from iCloud to your app :


* Make sure you already have IOS Certificate with iCloud ON. You can check it at your [Account Apple Developer](https://developer.apple.com/account) and going to **Certificates, Identifiers & Profiles** menu, select **App IDs**, find your target application, and click the **Edit** Button and make sure **Service iCloud** have you set as Enable
![apple app ids](https://raw.githubusercontent.com/qiscus/qiscus-sdk-ios/develop/screenshots/apple-app-ids.png)

* Open **Project** → **Capabilities** → **iCloud**. Set iCloud to be ON
* On Service menu, make sure **Key-value storage** & **iCloud Documents** is checked
![apple app ids](https://raw.githubusercontent.com/qiscus/qiscus-sdk-ios/develop/screenshots/apple-icloud-enable.png)

* Add the following code on your project :
```swift
Qiscus.shared.iCloudUpload = true
```

## Get Your App Id

To start building app using Qiscus Web Chat SDK you need a key called APP ID. This APP ID acts as identifier of your Application so that Qiscus can connect user to other users on the sample APP ID. You can get your APP ID [here](https://www.qiscus.com/dashboard/register).
You can find your APP ID on your Qiscus app dashboard. Here you can see the picture as a reference.

![App ID Location](https://cdn.rawgit.com/qiscus/qiscus-sdk-web/feature/docs/docs/images/app-id.png "Your APP ID location")

> *All users within the same APP ID are able to communicate with each other, across all platforms. This means users using iOS, Android, Web clients, etc. can all chat with one another. However, users in different Qiscus applications cannot talk to each other.*

## Authentication

To authenticate to SDK server, app needs to have user credential locally stored for further requests. The credential consists of a token that will identify a user in SDK server.
When you want to disconnect from SDK server,  terminating authentication will be done by clearing the stored credential. You can learn more about disconnecting from Qiscus Chat SDK in the next section.
Qiscus SDK authentication can be done separately with your main app authentication, especially if your main app has functionality before the messaging features.

There are 2 type of authentication that you can opt to use: Client Authentication and Server Authentication.
Here some comparison to help you decide between the two options:

* Client Authentication can be done simply by providing userID and userKey through your client app. On the other hand, Server Authentication, the credential information is provided by your Server App. In this case, you need o prepare your own Backend. 
* The Client Authentication is easier to implement but Server Authentication is more secure.

### Client Authentication

Before authentication, you need to first initiate Qiscus SDK. In Qiscus IOS Chat SDK, the initiation is conducted along with setup user account. You need to import Qiscus, then call `Qiscus.setup()` method to define your App Id, along with your user credentials such as userEmail, userKey, username and avatarURL. Here is how you can do :

```swift
  import Qiscus

  Qiscus.setup( withAppId: YOUR_APP_ID,
                userEmail: CURRENT_USER_EMAIL, 
                userKey: CURRENT_USER_PASSWORD, 
                username: CURRENT_USER_USERNAME, 
                avatarURL: CURRENT_USER_AVATAR_URL, 
                delegate: self
              )
```

Here are the explanation for the parameters on user setup:

* **userEmail** (string, unique): A User identifier that will be used to identify a user and used whenever another user need to chat with this user. It can be anything, wheter is is user's email, your user database index, etc. As long as it is unique and a string.
* **userKey** (string): userKey is used as for authentication purpose, so even if a stranger knows your userId, he cannot access the user data.
* **username** (string): Username is used as a display name inside chat room.
* **avatarURL** (string, optional): used to display user's avatar, fallback to default avatar if not provided.

You can learn from the figure below to understand what really happened when calling `Qiscus.setup()` function:
![set user](https://raw.githubusercontent.com/qiscus/qiscus-sdk-ios/develop/screenshots/set-user.png)


### Updating a User Profile and Avatar

After your user account is created, sometimes you may need to update a user information, such as 
ging user avatar. You can use method `Qiscus.updateProfile()` to make changes to your account.

```swift
Qiscus.updateProfile(username: "Your Name", avatarURL: "https://myimage.com/myNewIma...", onSuccess: {
  //  if success, do anything here
}) { (error) in
  // if error, do anything here
}
```

### Clear User Data and disconnect

As mentioned in previous section, when you did `Qiscus.setup()` user, user's data will be stored locally. When user need to disconnect from Qiscus Chat SDK service, you need to clear the user data that is related to Qiscus Chat SDK, such as token, profile, messages,rooms, etc, from local device. You can do this by calling `Qiscus.clear()` method :

```swift
Qiscus.clear()
```

## Create Chat Room

**Chat Room** is a place where 2 or more users can chat each other. There are 2 type of Chat Room that can be created using Qiscus Chat SDK: 1-on-1 Chat Room and Group Chat Room. For some cases, a room can be identified by room unique id or room name. All activities under Qiscus Chat SDK is inside this Chat Room. You can do whatever you need with the available chat features.

## 1-on-1 Chat Room

We assume that you already know a targeted user you want to chat with. Make sure that your targeted user has been registered in Qiscus Chat SDK through setup() method, as explained in the previous section. To start a conversation with your targeted user, it can be done with  `Qiscus.chatView(withUsers: [email])` method. Qiscus Chat SDK, then, will serve you a new Chat Room, asynchronously. When the room is succesfully created.

Here is the example to start a conversation:

```swift
let email = targetField.text!
let view = Qiscus.chatView(withUsers: [email])
self.navigationController?.pushViewController(view, animated: true)
```

## Group Chat Room

When you want your many users to chat together in a single room, you need to create Group Room. Basically Group Room has the same concept as 1-on-1 Chat Room, but the different is that Group Room will target array of users in a single method. You can create Group Room by calling `Qiscus.createChatView()` method. Here how you can create Group Room :

```swift
import UIKit
import Qiscus

class ViewController: UIViewController {

    .....
    func goToChat(){
        let chatTargets = ['user1', 'user2']
        let view = Qiscus.createChatView(withUsers: chatTargets, title: "New Group Chat")
        self.navigationController?.pushViewController(view, animated: true)
    }
    .....
}

```

## Channels 

Channel is a room that behave similar like a group chat, in channel anyone can join using the room uniqueId, there are several limitation on channel like : no typing indicator, no read/deliver status, no comment info, and “delete for me” is not available. Here how you can create or join a Channel Room:

**How to create channel :**
```
import Qiscus

let viewController = Qiscus.chatView(withRoomUniqueId: "thisIsChannel", readOnly: false, title: "This is channel", avatarUrl: "http://your.avatar.url", subtitle: "channel subtitle", withMessage: "this is initial message (optional)" )
navigationController.pushViewController(chatView, animated: true)

```


## More About Room

After successfully created your room, you may need to do advance development for your chat app. This may include invite more participant to your room, enter to a specific room without invitation, and so forth. Hence, in this section you will learn about the following things :

1. **Get Room List**, to get data of your user list, so that you can use that data to load specific room or many more.
2. **Enter to Existing Room**, to enable you to open a room that you already created by passing room ID that is obtained by Get Room List.
3. **Participant Management**, to educate you about adding more participant to your room or managing your user in your room.

### Get Rooms List

When a user is having conversation with many other users, either in 1-1 Chat Room or in Group Room, a user may have involved into many rooms and he may want to leave the room and enter it again later. In this case, you need to display list of room the user involved in your app. Please Keep in mind that Qiscus does not provide the UI of list rooms. However, we provide the information the get the list of room. Using `QChatService.roomList()` method, you can obtain list of room information where your user entered to. This method will return some data that you can benefit to make further modification in your app, for example displaying user rooms.

```swift
QChatService.roomList(withLimit: 100, page: page, onSuccess: { (rooms, totalRoom, currentPage, limit) in
   print("room list: \(rooms)")
}) { (error) in
   print("\(error)")
}

```

After executing the code above, here is what you will get in return :

```json
id = 42313;
storedName = Group test;
avatarURL = https://favim.com/orig/201106/15/animal-beautiful-cat-cute-djur-Favim.com-76976.jpg;
typingUser = ;
unreadCount = 0;
pinned = 0;
lastCommentText = [file]https://d1edrlpyc25xu0.cloudfront.net/kopihitam-o6xn13fos3n/image/upload/IUyF4inZgx/1509078048-ios-15090780469543.jpg [/file];
comments = []
participants = []
```

The returned data above provide you several information such as room id, room name,  how many participant in a room and many more.

### Enter to Existing Room

After successfully getting your room list, you may want to enter an existing room. Remember that there are 2 type of rooms, 1-on-1 Chat Room and Group Room. To enter to a specific room, you need to pass the roomID to` chatView()` method. Here is how you can do: 

```swift

import UIKit
import Qiscus

class ViewController: UIViewController {

  .....

  func goToChat(){
          let roomId = targetField.text!
          let view = Qiscus.chatView(withRoomId: roomId)
          self.navigationController?.pushViewController(view, animated: true)
  }

  .....
}

```

### Participant Management

In some cases, you may need to add additional participants into your room chat or even removing any participant. Currently, Qiscus Chat SDK only allow you to manage your users server to server. You cannot do it on your client app side. Hence, we recommend to invite and remove user out of specific room through our SERVER API for simplicity and security reason. You can learn how to use [Server API](https://www.qiscus.com/docs/restapi). 


## Enable Push Notification

Typically, you might want users to receive message when user not opening you app. With Qiscus Chat SDK, to enable Push Notification, you need to activate Apple Push Notification service by following the steps below :

1. Create a Certificate Signing Request(CSR).
2. Create a Push Notification SSL certificate in Apple Developer site.
3. Export a p12 file and upload it to Qiscus SDK Dashboard.
4. Add some line codes in your project

If you already have certificate with APNs, you can skip this tutorial.

#### 1. Create a Certificate Signing Request (CSR) 

Open **Keychain Access** on your Mac (Applications -> Utilities -> Keychain Access). Select **Request a Certificate From a Certificate Authority**.

![create csr](https://raw.githubusercontent.com/qiscus/qiscus-sdk-ios/develop/screenshots/apple-create-csr.png)

In the **Certificate Information** window, do the following:

1. In the **User Email Address** field, enter your email address.
2. In the **Common Name** field, create a name for your private key (e.g., Muhammad).
3. The **CA Email Address** field should be left empty.
4. In the **Request is** group, select the **Saved to disk** option.

![create csr](https://raw.githubusercontent.com/qiscus/qiscus-sdk-ios/develop/screenshots/apple-certificate-assist.png)


#### 2. Create a Push Notification SSL Certificate

Login to your [Account Apple Developer](https://developer.apple.com/account) and going to **Certificates, Identifiers & Profiles** menu, select **App IDs**, find your target application, and click the **Edit** Button

![app ids](https://raw.githubusercontent.com/qiscus/qiscus-sdk-ios/develop/screenshots/apple-app-ids.png)

**Enable Push Notifications** and create a development or production certificate to fit your purpose.

![apns](https://raw.githubusercontent.com/qiscus/qiscus-sdk-ios/develop/screenshots/apple-apns.png)

You should upload the **CSR file** that you created in step (1) in order to complete this process.
After doing so, you should be able to download a **SSL certificate**.

Double-click the file and register it to your **login keychain**.

![apple download](https://raw.githubusercontent.com/qiscus/qiscus-sdk-ios/develop/screenshots/apple-download.png)


#### 3. Export a p12 file and Upload it to Qiscus SDK Dashboard

Under **Keychain Access**, click the **Certificates** category from the left menu.
Find the Push SSL certificate you just registered and right-click it without expanding the certificate. Then select **Export** to save the file to your disk.

![apple export](https://raw.githubusercontent.com/qiscus/qiscus-sdk-ios/develop/screenshots/apple-export.png)

Keychain will ask you for a password, you can protect your Certificate with password or just leave it empty.

Then, login to your **Qiscus SDK Dashboard** account  and go to the **Settings**
and then upload your P12 file at **Push Notification** section.

![qiscus-dashboard](https://raw.githubusercontent.com/qiscus/qiscus-sdk-ios/develop/screenshots/qiscus-dashboard.png)

#### 4. Add some code to your project

Final step to enable push notification, you should add the following code to your app, for example you can add it to file **AppDelegate.swift**

```swift
// AppDelegate.swift

import Qiscus
...

func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    Qiscus.didRegisterUserNotification(withToken: deviceToken)
}

func application(_ application: UIApplication, didReceive notification: UILocalNotification) {
    Qiscus.didReceiveNotification(notification: notification)
}

func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any]) {
    Qiscus.didReceive(RemoteNotification: userInfo)
}
```

Once your app is up and running, you will receive push notification of your chat app. 
