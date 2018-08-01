# IOS SDK API Reference

## Init

### Using App ID

Client side call this function.

```
import Qiscus

Qiscus.setup( withAppId: "app_id",
                          userEmail: "youremail.com",
                          userKey: "yourpassword",
                          username: "yourname",
                          avatarURL: "",
                          delegate: nil
            )
```

Listen callback from delegate.

```
extension LoginVC : QiscusConfigDelegate{
    func qiscusConnected() {
        print("connect") // your connected callback
    }
    
    func qiscusFailToConnect(_ withMessage: String) {
        print(withMessage) //your error auth callback
    }
}
```

### Using custom server

```
import Qiscus

Qiscus.setBaseURL("Your Constom URL")
Qiscus.setRealtimeServer(server : "Your URL", port : "Your port",enableSSL : true/false)
```

## Authentication

### Using `UserID` and `UserKey`

```
import Qiscus

Qiscus.setup( withAppId: "app_id",
                          userEmail: "youremail.com",
                          userKey: "yourpassword",
                          username: "yourname",
                          avatarURL: "",
                          delegate: nil
            )
```

### Using JWT

Client side call this function.

```
import Qiscus

Qiscus.getNonce(withAppId: "APP_ID", onSuccess: { (nonce) in
    print("get nonce here : \(nonce)")
}, onFailed: { (error) in
    print("error : \(error)")
})
```

Verify the Identity Token and call this setup function.

```
import Qiscus

Qiscus.setup(withUserIdentityToken: "IDENTITY_TOKEN")
```

Sample usage.

```
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

## User

### Update User Profile And Profile Image

```
Qiscus.updateProfile(username: username, avatarURL: avatar, onSuccess: { 
            print("success profile")
        }) { (error) in
            print("error update profile: \(error)")
        }
```

### Login Status

```
Qiscus.isLoggedIn // return true or false
```

### Logout

```
Qiscus.clear()
```

## Message

### Send Text Message

```
 let comment = room.newComment(text: value) // create new text message on room
 room.post(comment: comment) // post message on room
```

### Send File Attachment

```
let comment = room.newFileComment(type: .image, filename: fileName, data: data)
// data contains fileData with type Data
// type: can be .image, .video, .audio, .file

room.upload(comment: comment, onSuccess: { (roomResult, commentResult) in
            roomResult.post(comment: commentResult)
        }, onError: { (roomResult, commentResult, error) in
            
        }) { (progress) in
            // progress value will be from 0.00 to 1.00
        }
```

Example.

```
let image = UIImage(named: "abc") // assuming you have file abc locally
let data = UIImagePNGRepresentation(image!)
let comment = room.newFileComment(type: .image, filename: "abc.png", data: data)

room.upload(comment: comment, onSuccess: { (roomResult, commentResult) in
    print("COMMENT", commentResult)
    roomResult.post(comment: commentResult)
}, onError: { (roomResult, commentResult, error) in
    print("ERROR", error)
}) { (progress) in
    print("PROGRESS", progress)
    // progress value will be from 0.00 to 1.00
}
```

### Send Custom Message

```
let comment = room.newCustomComment(text: value, type: .custom, payload:payload) //create new custom message on room
room.post(comment: comment) //post message on room
```

Example.

```
let comment = room.newCustomComment(type: "custom", payload: "{ \"key\": \"value\"}", text: "THIS IS CUSTOM MESSAGE")
room.post(comment: comment)
```

### Load Messages

```
// offset can be taken from comment.messageId
// this method will give the messages after the offset given
room.loadComments(limit: 20, offset: "12345", onSuccess: { (comments) in
            // comments contain array of QComment objects
        }) { (error) in
            print(error)
        }
```

### Load More

```
// offset can be taken from comment.messageId
// this method will give the messages before the offset given
room.loadMore(limit: 20, offset: "12345", onSuccess: { (comments, hasMoreMessages) in
        // comments contain array of QComment objects
        // hasMoreMessages signifies that there is still another message before the first message, this is Boolean (true/false) 
}) { (error) in
   print(error)
}
```

### Download Media

```
room.downloadMedia(onComment: comment, onSuccess: { (commentResult) in
            <#code#>
            print(commentResult.file.localPath)
        }, onError: { (error) in
            <#code#>
        }) { (progress) in
            <#code#>
        }
```

### Search Message

```
QChatService.searchComment(withQuery: (self.searchViewController?.searchBar.text)!, onSuccess: { (comments) in
            self.filteredComments = comments
            self.tableView.reloadData()
            print("success search comment with result:\n\(comments)")
        }, onFailed: { (error) in
            print("fail to get search result")
        })
```

### Delete Message

To delete one message, we have to provide data QComment.

```
let deletecomment = self.room!.comments[index.row]
```

Delete with this function.

```
deletecomment.delete(forMeOnly: false, hardDelete: true, onSuccess: {
                print("success")
            }, onError: { (statusCode) in
                print("delete error: status code \(statusCode)")
            })
```

### Delete All Messages

```
var room:QRoom?
self.room?.clearMessages(onSuccess: {
                print("success")
            }, onError: { (error) in
                print(error)
            })
```

## Room

### Create Group Room

```
Qiscus.newRoom(withUsers: ["user_id1", "user_id2"], roomName: "My RoomName", onSuccess: { (room) in
            // room data in QRoom object
        }) { (error) in
            // resulting error in String
        } 
```

### Get Chat Room By ID

```
Qiscus.room(withId: roomId, onSuccess: { (room) in
            // room data in QRoom object
            // for accessing comments inside room
            let comments = room.listComment // ressulting array of QComment
        }) { (error) in
            // resulting error in String
        }
```

### Get Chat Room By Channel

```
Qiscus.room(withChannel: channelName, onSuccess: { (room) in
            // room data in QRoom object
            // for accessing comments inside room
            let comments = room.listComment // ressulting array of QComment
        }) { (error) in
            // resulting error in String
        }
```

### Get Chat Room Opponent By User ID

```
Qiscus.room(withUserId: userId, onSuccess: { (room) in
            // room data in QRoom object
            // for accessing comments inside room
            let comments = room.listComment // ressulting array of QComment
        }) { (error) in
            // resulting error in String
        }
```

### Get Room Info With ID

```
Qiscus.roomInfo(withId: "13456", onSuccess: { (room) in
            // room data in QRoom object
        }) { (error) in
            // resulting error in string
        }
```

### Get Multiple Room Info

```
Qiscus.roomsInfo(withIds: ["12345", "13456"], onSuccess: { (rooms) in
            // rooms data in array of QRoom object
        }) { (error) in
            // resulting error in string
        }
```

### Get Channel Info

```
Qiscus.channelInfo(withName: "myChannel", onSuccess: { (room) in
            // room data in QRoom object
        }) { (error) in
            // resulting error in string
        }
```

### Get Multiple Channel Info

```
Qiscus.channelsInfo(withNames: ["myChannel1","myChannel2"], onSuccess: { (rooms) in
            // rooms data in array of QRoom object
        }) { (error) in
            // resulting error in string
        }
```

### Get Room List

```
Qiscus.roomList(withLimit: 100, page: 1, onSuccess: { (rooms, totalRoom, currentPage, limit) in
            // rooms contains array of room
            // totalRoom = total room in server
            // currentPage = current page requested
            // limit = limit requested
        }) { (error) in
            // resulting error in string
        }
```

### Get Room List in LocalDB

```
let rooms = QRoom.all()
```

### Update Room

```
var room:QRoom?
room.update(roomName: roomName, roomAvatarURL: avatar, onSuccess: { (qRoom) in
                //success update
            }, onError: { (error) in
                //error
            })
```

### Get List Of Participant in a Room

```
Qiscus.room(withId: roomId!, onSuccess: { (room) in
            // getroom list participant
          let allparticipant = room.participants
        }) { (error) in
            print("error")
        }
```

## Statuses

### Publish Start Typing

```
room.publishStartTyping()
```

### Publish Stop Typing

```
room.publishStopTyping()
```

### Update Message Read Status

```
QRoom.publishStatus(roomId: roomId, commentId: commentId, status: .read)
```

### View Who Has Received And Read Message

To get information who has received and read a message, We can get all data member in QComment. In QComment class have a variable readUser and deliveredUser.

```
var comment : QComment?

comment?.statusInfo?.readUser //list data users have been read comment
comment?.statusInfo?.readUser.count //count of data users have been read comment
comment?.statusInfo?.deliveredUser //list data users have been delivered comment
comment?.statusInfo?.deliveredUser.count //count of data users have been delivered comment
```

We can get a update users status delivered and received message with `QParticipantDelegate`

```
extension YourViewController: QParticipantDelegate{
    //in function show your tableview
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var participantGroup = data?.statusInfo?.readUser
        if indexPath.section > 0 {
            participantGroup = data?.statusInfo?.deliveredUser
        }
        let participant = participantGroup?[indexPath.row]
        participant?.delegate = self // init QParticipantdelegate
        //init your cell
        return cell
    }
    func participant(didChange participant: QParticipant) {
       //you can update here
    }
}
```

## Event Handler

### New Messages

Listen to notification.

```
NotificationCenter.default.addObserver(self, selector: #selector(YOUR_CLASS.userTyping(_:)), name: QiscusNotification.USER_TYPING(onRoom: "Your room id"), object: nil)
```

Get data on your selector.

```
func newCommentNotif(_ notification: Notification){
        if let userInfo = notification.userInfo {
            let comment = userInfo["comment"] as! QComment
            
            // if you want to get the room where the comment is
            let room = comment.room
            // *note: it can be nil
        }
    }
```

### Typing

Subscribe to notification channel.

```
room.subscribeRealtimeStatus()
```

Listen to notification.

```
NotificationCenter.default.addObserver(self, selector: #selector(YOUR_CLASS.userTyping(_:)), name: QiscusNotification.USER_TYPING(onRoom: "Your room id"), object: nil)
```

Get data on your selector.

```
func userTyping(_ notification: Notification){
        if let userInfo = notification.userInfo {
            let user = userInfo["user"] as! QUser
            let typing = userInfo["typing"] as! Bool
            let room = userInfo["room"] as! QRoom
            
            // typing can be true or false
        }
}
```

### Message Status Change

Message status is object type QCommentStatus. The value can be .sending , .pending , .sent , .delivered, and .read

Listen to notification.

```
NotificationCenter.default.addObserver(self, selector: #selector(YOUR_CLASS.messageStatusChange(_:)), name: QiscusNotification.MESSAGE_STATUS, object: nil)
```

Get data on your selector.

```
func messageStatusChange(_ notification: Notification){
        if let userData = notification.userInfo {
            let comment = userData["comment"] as? QComment
            let newStatus = userData["status"] as? QCommentStatus
        }
    }
```

### Message Status Change Using Delegate

Message status is object type QCommentStatus. the value can be .sending , .pending , .sent , .delivered, and .read

Declared object QComment in Cell Class.

```
var comment:QComment?{
        didSet{
            if oldValue != nil {
                oldValue!.delegate = nil
            }
            if comment != nil {
                self.comment?.delegate = self
                textChat.text = commentRaw?.text
                textChat.sizeToFit()
                textChat.layoutIfNeeded()
                
               //update your status in here 
               // the value can be .sending , .pending , .sent , .delivered, .read
        }
    }
```

Extend QCommentDelegate & Implement callback update.

```
class (YourClassCell) : UITableViewCell , QCommentDelegate{

    override func viewDidLoad() {
        super.viewDidLoad()
         }

    func comment(didChangeStatus comment: QComment, status: QCommentStatus) {
        if self.commentRaw?.uniqueId == comment.uniqueId {
             // update your status in here
             //  the value can be .sending , .pending , .sent , .delivered, .read
        }
    }
}
```

## Notification

### Push Notification

Register device token. Will Receive Push Notification in AppDelegate on didReceiveRemoteNotification 

```
Qiscus.didRegisterUserNotification(withToken: token)
```


