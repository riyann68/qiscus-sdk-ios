//
//  QFileManager.swift
//  Example
//
//  Created by Ahmad Athaullah on 7/30/17.
//  Copyright © 2017 Ahmad Athaullah. All rights reserved.
//

import Foundation
@objc public enum QDirectoryType:Int{
    case comment
    case user
    case room
}
public class QFileManager:NSObject{
    internal class func directoryPath(forDirectory directory:QDirectoryType)->String{
        var dir = ""
        switch directory {
        case .comment:
            dir = "comment"
            break
        case .room:
            dir = "room"
            break
        case .user:
            dir = "user"
            break
        }
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as String
        let qiscusPath = "\(documentsPath)/Qiscus"
        if !FileManager.default.fileExists(atPath: qiscusPath){
            do {
                try FileManager.default.createDirectory(atPath: qiscusPath, withIntermediateDirectories: false, attributes: nil)
            } catch let error as NSError {
                Qiscus.printLog(text: error.localizedDescription);
            }
        }
        let directoryPath = "\(qiscusPath)/\(dir)"
        if !FileManager.default.fileExists(atPath: directoryPath){
            do {
                try FileManager.default.createDirectory(atPath: directoryPath, withIntermediateDirectories: false, attributes: nil)
            } catch let error as NSError {
                Qiscus.printLog(text: error.localizedDescription);
            }
        }
        return directoryPath
    }
    internal class func saveFile(withData fileData: Data, fileName: String, type:QDirectoryType)->String{
        let directoryPath = QFileManager.directoryPath(forDirectory: type)
        let path = "\(directoryPath)/\(fileName.replacingOccurrences(of: " ", with: "_").replacingOccurrences(of: "’", with: "%E2%80%99"))"
        try? fileData.write(to: URL(fileURLWithPath: path), options: [.atomic])
        return path
    }
    public class func isFileExist(inLocalPath path:String)->Bool{
        var check:Bool = false
        
        let checkValidation = FileManager.default
        
        if (path != "" && checkValidation.fileExists(atPath:path))
        {
            check = true
        }
        return check
    }
    internal class func clearTempDirectory(){
        FileManager.default.clearTmpDirectory()
    }
    
}

extension FileManager {
    func clearTmpDirectory() {
        do {
            let tmpDirectory = try contentsOfDirectory(atPath: NSTemporaryDirectory())
            try tmpDirectory.forEach {[unowned self] file in
                let path = String.init(format: "%@%@", NSTemporaryDirectory(), file)
                try self.removeItem(atPath: path)
            }
        } catch {
            Qiscus.printLog(text: error.localizedDescription)
        }
    }
}
