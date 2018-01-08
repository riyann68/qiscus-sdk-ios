# Introduction

With Qiscus chat SDK (Software Development Kit), You can embed chat feature inside your application quickly and easily without dealing with complexity of real-time comunication infrastucture. We provide Chat UI that has been designed and optimized for easy customization. So, you can modify the UI to show off your branding identity, favorite color, or customize event.

## A Brief About Chat

Talking about chat app, you may figure out such messager app like Whatsapp. You might have familiar with the flow, how to start conversation, and do things, like sharing image, inside chat room.  If you want to create chat app, for customer service, for instance, Qiscus Chat SDK enable you to establish chat UI and  functionalities easily. But before dive into it, there are essential basic knowledges you need to know about chat app.

### Basic Flow of Chat App

In a chat app, to start a conversation, we usually choose person we want to chat with, from a contact list. Then, we start conversation inside a chat room. In a chat room, we can do things such as sharing images, sending emoji, sharing contact, location, and many more. We can even know when a person is typing or when our message has been read. If chatting is done, we can go back to the conversation list which display our conversations in the app.
To make a chat app with the described flow, we noticed that the most complex part is creating chat room, which posses many features inside it. Hence, Qiscus Chat SDK provide an easy way to create chat app without dealing with  complexity of real-time comunication infrastucture that resides inside a chat room.

## Qiscus Chat SDK and UI Components

<p align="center"><br/><img alt="sdk-in-iphone" src="https://raw.githubusercontent.com/qiscus/qiscus-sdk-ios/develop/screenshots/sdk-in-iphone.png" width="37%" /><br/></p>

In spite of real-time chat, Qiscus Chat SDK provides UI that can be customized according to your needs. But please keep in mind that, by default, Qiscus provides UI for chat room only. If you need to create contact list and conversation list UI, for example, you need to create it your own. However, we provide essential data that you can get and utilize for your app.


## Qiscus Chat SDK Features

When you try our chat SDK, you will find the default built-in features such as:

* Private & group chat
* Typing indicator
* Delivery indicator 
* Image and file attachment
* Online presence 
* Read receipt 
* Reply message 
* Pending Messages
* Emoji support

You also can access more advance and customizable features such as :

* Server side integration with Server API and Webhook
* Customize your user interface 
* Embed bot engine in your app
* Enable Push notification
* Export and import messages from you app

## Try Sample App

To meet your expectations, we suggest you try out our sample app. The sample app is built with full functionalities so that you can figure out the flow and main activities of common chat apps.  We provide you with two options to start with the sample app: 
1) Try Sample App only or
2) Try Sample App with Sample Dashboard

### Try Sample App Only

If you simply want to try the IOS sample app, you can direct to our [github repository](https://github.com/qiscus/qiscus-sdk-web-sample) to clone our sample app. You can explore features of Qiscus Chat SDK.

If you are willing to change your own App ID, you can change it in **Helper.swift** file. Here is how it will look like:
```swift
...

class Helper: NSObject {
    static var APP_ID: String {
        get {
            return "YOUR_APP_ID"
        }
    }
    
    ...
```

### Try Sample App With Sample Dashboard
If you have your own chat app, you may be wondering how you can manage your users. In this case, we provide a sample dashboard for user management. This sample dashboard can help you to figure out how to work with Qiscus Server Api for more advanced functionalities. You can go to https://www.qiscus.com/documentation/rest/list-api to know more about Server API.

> Note: We assume that you already downloaded the sample app. The sample app will be needed to work together with the sample dashboard.

You can explore the sample dashboard http://dashboard-sample.herokuapp.com/ to try it online, or you also can download the source code to deploy it locally or to your own server.

To start trying the sample dashboard on your end, you should carry out the following steps:
Clone sample dashboard in our github (https://github.com/qiscus/dashboard-sample), or just copy the following code.

```cmd
git clone https://github.com/qiscus/dashboard-sample.git
cd dashboard-sample
```

Before running the sample app on your local, first, you need to install composer. 

```cmd
composer install
php -S localhost:8000
```

>The sample dashboard provided Client API to enable your sample app get list of users. This API is based on PHP and used Composer as its dependency manager. Thus, you need to have PHP and composer installed to use the API.

Now you would have successfully run the sample dashboard. However, do note that the sample app is running using our App ID. If you want the sample dashboard to be connected to your app with your own App ID, you need to change it inside *.env file*. You can find your own App ID and Secret Key in your own [Qiscus SDK dashboard](https://www.qiscus.com/dashboard).

If you are wondering how our sample app with dashboard worked, here some ilustration :
<p align="center"><br/><img src="https://raw.githubusercontent.com/qiscus/qiscus-sdk-android/develop/screenshot/how_sample_work.png" width="80%" /><br/></p>

There are 2 Server API that are used inside Qiscus Sample Dashboard:

1. ```.qiscus.com/api/v2.1/rest/get_user_list``` to get list of users from Qiscus SDK database, and
2. ```.qiscus.com/api/v2/rest/login_or_register``` to enable user login or register via Sample Dashboard.

The Sample Dashboard called these APIs inside main.js file. To use these APIs, you need to pass your APP ID and  set method and request parameter.

To pass the APP ID, If you login to Sample Dashboard with your own APP ID and Secret Key, the APP ID and Secret Key has been saved, so that you need nothing to setup APP ID inside main.js.  

To set method and request parameter, you can refer to [Get User List](https://www.qiscus.com/documentation/rest/list-api#get-user-list) and [Login and Register](https://www.qiscus.com/documentation/rest/list-api#login-or-register) on Qiscus Server API Documentation.

The Sample Dashboard also provided API for client app to get list of users from the Sample Dasboard. 
To enable your client app to get list of users, you need to set your APP ID and Secret Key inside .env file. Then, you need to pass your domain name when calling the API.

```
//your-domain.com/api/contacts
Example: //dashboard-sample.herokuapp.com/api/contacts
```
You will get the response as follow:
```JSON
{
   "results":{
      "meta":{
         "total_data":123,
         "total_page":6
      },
      "users":[
         {
            "avatar_url":"https:\/\/d1edrlpyc25xu0.cloudfront.net\/kiwari-prod\/image\/upload\/75r6s_jOHa\/1507541871-avatar-mine.png",
            "created_at":"2017-12-05T08:07:58.405896Z",
            "email":"sample@email.com",
            "id":452773,
            "name":"sample",
            "updated_at":"2017-12-05T08:07:58.405896Z",
            "username":"sample"
         }
      ]
   },
   "status":200
}
```
# Getting Started

## Requirement

To install qiscus chat sdk you need to have CocoaPods installed. You can skip this part if you already installed CocoaPods.

CocoaPods (http://cocoapods.org/) is a dependency manager for Cocoa projects and it is available for Swift or Objective-C. Here is how to install CocoaPods :

```cmd
$ gem install cocoapods.
```

To install Qiscus Chat SDK, you need to initiate pod to generate Podfile. You can do that by going to your app project and type the commend below:
```cmd 
$ pod init
```

After Podfile is initialized, open it and type 'Qiscus' in the pod section

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
$ pod install
```
 >Please be noted that by default, Qiscus Chat SDK uses Swift 3. If your Xcode version is 9 or latest, you need to adjust your Xcode to Swift 3.

###Setting Permission
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

> All users within the same APP ID are able to communicate with each other, across all platforms. This means users using iOS, Android, Web clients, etc. can all chat with one another. However, users in different Qiscus applications cannot talk to each other.

## Authentication

To authenticate to SDK server, app needs to have user credential locally stored for further requests. The credential consists of a token that will identify a user in SDK server.
When you want to disconnect from SDK server,  terminating authentication will be done by clearing the stored credential. You can learn more about disconnecting from Qiscus Chat SDK in the next section.
Qiscus SDK authentication can be done separately with your main app authentication, especially if your main app has functionality before the messaging features.
To initiate Qiscus SDK, you need to import Qiscus, then call `Qiscus.setup()` method to define your App Id, along with your user credentials such as userEmail, userKey, username and avatarURL. Here is how you can do :

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

**Using the SDK in Objective-C**

```objective-c
import Qiscus

[Qiscus setupWithAppId:<YOUR_APP_ID> 
        userEmail:<USER_EMAIL> 
        userKey:<USER_KEY> 
        username:<USER_NAME> 
        avatarURL:<USER_AVATAR_URL> 
        delegate:self 
        secureURl:<true|false>];
```
Here are the explanation for the parameters on user setup:

* **userEmail** (string, unique): A User identifier that will be used to identify a user and used whenever another user need to chat with this user. It can be anything, wheter is is user's email, your user database index, etc. As long as it is unique and a string.
* **userKey** (string): userKey is used as for authentication purpose, so even if a stranger knows your userId, he cannot access the user data.
* **username** (string): Username is used as a display name inside chat room.
* **avatarURL** (string, optional): used to display user's avatar, fallback to default avatar if not provided.

You can learn from the figure below to understand what really happened when calling `Qiscus.setup()` function:
![set user](https://raw.githubusercontent.com/qiscus/qiscus-sdk-ios/develop/screenshots/set-user.png)


## Updating a User Profile and Avatar

After your user account is created, sometimes you may need to update a user information, such as changing user avatar. You can use method `Qiscus.updateProfile()` to make changes to your account.

```swift
Qiscus.updateProfile(username: "Your Name", avatarURL: "https://myimage.com/myNewIma...", onSuccess: {
  //  if success, do anything here
}) { (error) in
  // if error, do anything here
}
```

## Clear User Data and disconnect

As mentioned in previous section, when you did `Qiscus.setup()` user, user's data will be stored locally. When user need to disconnect from Qiscus Chat SDK service, you need to clear the user data that is related to Qiscus Chat SDK, such as token, profile, messages,rooms, etc, from local device. You can do this by calling `Qiscus.clear()` method :

```swift
Qiscus.clear()
```


## Create Chat Room

**Chat Room** is a place where 2 or more users can chat each other. There are 2 type of Chat Room that can be created using Qiscus Chat SDK: 1-on-1 Chat Room and Group Chat Room. For some cases, a room can be identified by room unique id or room name. All activities under Qiscus Chat SDK is inside this Chat Room. You can do whatever you need with the available chat features.

## Creating 1-on-1 Chat Room

We assume that you already know a targeted user you want to chat with. Make sure that your targeted user has been registered in Qiscus Chat SDK through setup() method, as explained in the previous section. To start a conversation with your targeted user, it can be done with  `Qiscus.chatView(withUsers: [email])` method. Qiscus Chat SDK, then, will serve you a new Chat Room, asynchronously. When the room is succesfully created.

Here is the example to start a conversation:

```swift
let email = targetField.text!
let view = Qiscus.chatView(withUsers: [email])
self.navigationController?.pushViewController(view, animated: true)
```

## Creating Group Chat Room

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

## More About Room

After successfully created your room, you may need to do advance development for your chat app. This may include invite more participant to your room, enter to a specific room without invitation, and so forth. Hence, in this section you will learn about the following things :

1. **Get Room List**, to get data of your user list, so that you can use that data to load specific room or many more.
2. **Get Room ID**, to enable you to open a room that you already created by passing room ID that is obtained by Get Room List.
3. **Room Participant**, to educate you about adding more participant to your room or managing your user in your room.

## Get Rooms List

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

## Get a room by id

As explained in the previous section, we know how to obtain a roomID by calling `roomList()` method. To enter to a specific room, you need to pass the roomID to` chatView()` method. Here is how you can do: 
When you already know your chat room id, you can easily go to that room. Just call

Swift 3.0

```swift

import UIKit
import Qiscus

class ViewController: UIViewController {

  .....

  func goToChat(){
          let roomId = String(targetField.text!)
          let view = Qiscus.chatView(withRoomId: roomId)
          self.navigationController?.pushViewController(view, animated: true)
  }

  .....
}

```


## Room Participant Management

In some cases, you may need to add additional participants into your room chat or even removing any participant. Currently, Qiscus Chat SDK only allow you to manage your users server to server. You cannot do it on your client app side. Hence, we recommend to invite and remove user out of specific room through our SERVER API for simplicity and security reason. You can learn how to use Server API [here](https://www.qiscus.com/docs/restapi). 


## Enable Push Notifications

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
# Advance Section

## UI Costomization

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

## Event Handler

An Event Handler is a callback routine that operates asynchronously and handles inputs received into a program. Event Handlers are important in Qiscus because it allows a client to react to any events happening in Qiscus Chat SDK. For example, if a client wants to know any important events from server, such as success login event, client's app can be notified by calling a specific Event Handler. Client, then, can do things with data returned by the event.

There are 2 type of Event Handler provided by Qiscus Chat SDK: **QiscusConfigDelegate** and **QiscusRoomDelegate**. 
**QiscusConfigDelegate** provides event handler that are related to Qiscus Chat SDK initialization.such as events for push notification and event synchronize, while **QiscusRoomDelegate** provides event handlers that are related to room and messaging.

To use event handler inside your app, you will need to extend QiscusConfigDelegate or QiscusRoomDelegate, so that you can see all event handlers that are provided by the class, then you can do whatever you need to do inside the event handlers.
 
There are several event handlers that are provided inside **QiscusConfigDelegate** as listed below :

```swift
func qiscusFailToConnect(_ withMessage: String) {
   // do anything if failed to connect to Qiscus Chat SDK 
}

func qiscusConnected() {
   // do anything after successfully connected to Qiscus Chat SDK
}
    
func qiscus(gotSilentNotification comment: QComment) {
   //do anything if got new message in silent mode
}

func qiscus(didConnect succes: Bool, error: String?) {
   //do anything after successfully connected to Qiscus Push Notification
}

func qiscus(didRegisterPushNotification success: Bool, deviceToken: String, error: String?) {
   // got status of registering qiscus sdk
   //do anything after 
}

func qiscus(didUnregisterPushNotification success: Bool, error: String?) {
   // got status of un-registering qiscus sdk
}

func qiscus(didTapLocalNotification comment: QComment, userInfo: [AnyHashable : Any]?) {
   // do anything after push notification alert is clicked
}
    
func qiscusStartSyncing() {    
   // do anything when Qiscus Chat SDK start to synchronize messages
}

func qiscus(finishSync success: Bool, error: String?) {
   // do anything after synchronizing finished
}
```

There are some event handlers that are provided by **QiscusRoomDelegate** as listed below :
```swift
func gotNewComment(_ comments: QComment) {
   // do anything after receiving new comment
}

func didFinishLoadRoom(onRoom room: QRoom) {
   // do anything after chat room is successfully loaded
}

func didFailLoadRoom(withError error: String) {
   // do anything after chat room is failed to load
}

func didFinishUpdateRoom(onRoom room: QRoom) {
   // do anything after chat room is successfully updated
}

func didFailUpdateRoom(withError error: String) {
   // do anything after chat room is failed to update
}
```

