//
//  Server.swift
//  GCDSocketDemo
//
//  Created by Garenge on 2023/5/17.
//

import Foundation
import CocoaAsyncSocket
import PPCustomAsyncOperation

public class PPServerSocketManager: PPSocketBaseManager {
    
    public lazy var socket: GCDAsyncSocket = {
        let socket = GCDAsyncSocket(delegate: self, delegateQueue: DispatchQueue.main)
        return socket
    }()
    
    public func accept(port: UInt16 = 12123) {
        do {
            try socket.accept(onPort: port)
            print("Server 监听端口 \(port) 成功")
            self.doServerAcceptPortClosure?(self, port, nil)
        } catch {
            print("Server 监听端口 \(port) 失败: \(error)")
            self.doServerAcceptPortClosure?(self, port, error as NSError)
        }
    }
    
//    public var clientSocket: GCDAsyncSocket?
    public var clientSocketDic: [String: GCDAsyncSocket] = [:]
    
    public var doServerAcceptPortClosure: ((_ manager: PPServerSocketManager, _ port: UInt16, _ err: NSError?) -> Void)?
    
    public func sendDirectionMessage(sock: GCDAsyncSocket, message: String, messageKey: String) {
        let messageFormat = PPSocketMessageFormat.format(action: .directionData, content: PPSocketDirectionMsg(type: .common, content: message), messageKey: messageKey)
        self.sendDirectionData(socket: sock, data: messageFormat.pp_convertToJsonData(), messageKey: messageKey, receiveBlock: nil)
    }
    public var doServerAcceptNewSocketClosure: ((_ manager: PPServerSocketManager, _ clientSocket: GCDAsyncSocket) -> Void)?
    public var doServerLossClientSocketClosure: ((_ manager: PPServerSocketManager, _ clientSocket: GCDAsyncSocket, _ err: Error?) -> Void)?
    
    public var rootPath = "/Users/garenge/Downloads"
    
    /// tcp是数据流, 所以不代表每次拿到数据就是完整的, 需要自己处理数据的完整性
    /// 为了兼容多socket, 该值改为字典, key是对应发送消息的socket的地址, value是该socket对应发送的数据
    var receiveBufferDic: [String: Data] = [:]
    
    override func receiveRequestToDownloadFile(_ messageFormat: PPSocketMessageFormat, sock: GCDAsyncSocket) {
        print("Server 收到下载文件请求")
        print(messageFormat)
        guard let content = messageFormat.content else {
            self.sendDirectionData(socket: sock, data: nil, messageKey: messageFormat.messageKey, receiveBlock: nil)
            return
        }
        self.sendFile(sock: sock, filePath: content, messageKey: messageFormat.messageKey)
    }
    
    override func receiveRequestToCancelTask(_ messageFormat: PPSocketMessageFormat, sock: GCDAsyncSocket) {
        print("Server 收到取消任务请求")
        print(messageFormat)
        self.cancelSendingTask(socket: sock, content: messageFormat.content, messageKey: messageFormat.messageKey, receiveBlock: nil)
    }
    
    public var didReceiveDirectionDataBlock: ((_ message: String?, _ messageKey: String, _ clientSocket: GCDAsyncSocket) -> Void)?
    public var didReceivedClientSocketDeviceName: ((_ deviceName: String?, _ clientSocket: GCDAsyncSocket) -> Void)?
    override func receiveDirectionData(_ messageFormat: PPSocketMessageFormat, sock: GCDAsyncSocket) {
        
        // 解析content {"content":"iPhone 16 Pro","type":"deviceName","timestamp":1742704364.828758}
        // 转成PPSocketDirectionMsg模型
        guard let content = messageFormat.content, let directionMsg = PPSocketDirectionMsg(data: content.data(using: .utf8)) else {
            return
        }
        print("Server 收到直连数据: \(content)")
        
        guard let type = PPSocketDirectionMsg.MsgType(rawValue: directionMsg.type) else {
            return
        }
        
        switch type {
        case .common:
            do {
                print("Server 收到普通直连数据: \(directionMsg.content ?? "")")
            }
        case .deviceName:
            do {
                print("Server 收到设备名称直连数据: \(directionMsg.content ?? "")")
                sock.name = directionMsg.content
                self.didReceivedClientSocketDeviceName?(directionMsg.content, sock)
            }
        case .requestFileList:
            do {
                print("Server 收到文件列表请求, 文件夹路径: \(directionMsg.content ?? "")")
                
                self.sendFolderList(sock: sock, folderPath: directionMsg.content, messageKey: messageFormat.messageKey)
            }
        default: break
        }
        
        self.didReceiveDirectionDataBlock?(content, messageFormat.messageKey, sock)
    }
    
}

extension PPServerSocketManager {
    
    /// 发送消息
    public func sendTestMessage() {
        // 模拟多任务队列
//        do {
//            // 构造一个json
//            let json = ["name": "Server", "age": 18] as [String : Any]
//            if let data = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) {
//                self.sendDirectionData(socket: self.clientSocket, data: data)
//            }
//        }
//        do {
//            guard let filePath = Bundle.main.path(forResource: "okzxVsJNxXc.jpg", ofType: nil) else {
//                print("文件不存在")
//                return
//            }
//            if let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) {
//                self.sendDirectionData(socket: self.clientSocket, data: data)
//            }
//        }
    }
    
    /// 发送文件夹下的文件列表 folderPath: 空表示根目录
    func sendFolderList(sock: GCDAsyncSocket, folderPath: String?, messageKey: String?) {
        
        var messageFormat = PPSocketMessageFormat.format(action: .directionData, content: PPSocketDirectionMsg(type: .responseFileList), messageKey: messageKey)
        
        let filePath = (rootPath as NSString).appendingPathComponent(folderPath ?? "")
        var models: [PPFileModel] = []
        do {
            let fileList = try FileManager.default.contentsOfDirectory(atPath: filePath)
            models = fileList.map({ fileName in
                var fileModel = PPFileModel()
                fileModel.filePath = (filePath as NSString).appendingPathComponent(fileName)
                
                return fileModel
            })
            models.sort { (model1, model2) -> Bool in
                // 文件夹在前面, 文件大小按顺序
                let inte1 = model1.isFolder ? 1 : 0
                let inte2 = model2.isFolder ? 1 : 0
                if inte1 == inte2 {
                    if (inte1 == 1) {
                        return (model1.fileName ?? "") < (model2.fileName ?? "")
                    } else {
                        return model1.fileSize > model2.fileSize
                    }
                } else {
                    return inte1 > inte2
                }
            }
        } catch {
            print("Server 获取文件列表失败: \(error)")
            messageFormat.errorCode = "Server 获取文件列表失败"
        }
        var responseStr: String?
        if let jsonData = models.pp_convertToJsonData() {
            responseStr = String(data: jsonData, encoding: .utf8)
        }
        messageFormat.content = responseStr
        
        self.sendDirectionData(socket: sock, data: messageFormat.pp_convertToJsonData(), messageKey: messageKey, receiveBlock: nil)
    }
    
    /// 发送文件信息
    public func sendFileInfo(sock: GCDAsyncSocket, filePath: String) {
        var fileModel = PPFileModel()
        fileModel.filePath = filePath
        
        guard let jsonDic = fileModel.pp_convertToDict(), let jsonData = try? JSONSerialization.data(withJSONObject: jsonDic, options: .prettyPrinted) else {
            return
        }
        self.sendDirectionData(socket: sock, data: jsonData, receiveBlock: nil)
    }
    
    /// 发送文件流
    func sendFile(sock: GCDAsyncSocket, filePath: String, messageKey: String?) {
        self.sendFileData(socket: sock, filePath: filePath, messageKey: messageKey)
    }
    
    /// 移除客户端
    public func sendRemoveClient(toRemoveSock: GCDAsyncSocket) {
        let format = PPSocketMessageFormat.format(action: .directionData, content: PPSocketDirectionMsg(type: .removeClient))
        self.sendDirectionData(socket: toRemoveSock, data: format.pp_convertToJsonData(), messageKey: nil, receiveBlock: nil)
    }
    
}

extension PPServerSocketManager: GCDAsyncSocketDelegate {
    
    public func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
        print("Server 已连接 \(host):\(port)")
    }
    
    // 这里的sock就是self.socket, newSocket是self.clientSocket
    public func socket(_ sock: GCDAsyncSocket, didAcceptNewSocket newSocket: GCDAsyncSocket) {
        print("Server accept new socket")
        let key = String(format: "%p", newSocket)
        self.clientSocketDic[key] = newSocket
        // 重置
        
        receiveBufferDic[key] = Data()
        newSocket.readData(withTimeout: -1, tag: 10086)
        self.doServerAcceptNewSocketClosure?(self, newSocket)
    }
    
    // 这里的sock就是self.clientSocket
    public func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
        print("Server 已断开: \(String(describing: err))")
        self.cancelAllSendOperation()
        self.cancelALLReceiveTask()
        
        let key = String(format: "%p", sock)
        self.clientSocketDic[key] = nil
        // 重置
        
        receiveBufferDic[key] = Data()
        self.doServerLossClientSocketClosure?(self, sock, err)
    }
    
    // 这里的sock就是self.clientSocket
    public func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
        
        let key = String(format: "%p", sock)
        // 一个server会有多个client
        var receiveBuffer = receiveBufferDic[key] ?? Data()
        
        // 将新收到的数据追加到缓冲区
        receiveBuffer.append(data)
        
        while receiveBuffer.count >= prefixLength {
            // 读取包头，解析包体长度
            let lengthData = receiveBuffer.subdata(in: (20 + 8 + 8)..<(20 + 8 + 8 + 8))
            let length = Int(String(data: lengthData, encoding: .utf8) ?? "0") ?? 0
            if length == 0 {
                // 有异常数据混入, 这个包丢弃
                receiveBuffer.removeAll()
                break
            }
            
            if receiveBuffer.count >= length {
                // 获取完整包
                let completePacket = receiveBuffer.subdata(in: 0..<length)
                
                // 处理完整包数据
                self.socketDidReceiveData(sock, data: completePacket)
                
                // 移除已处理的包
                receiveBuffer.removeSubrange(0..<length)
            } else {
                // 数据不完整，等待更多数据
                break
            }
        }
        
        sock.readData(withTimeout: -1, tag: 10086)
    }
    
    // 这里的sock就是self.clientSocket
    public func socket(_ sock: GCDAsyncSocket, didWriteDataWithTag tag: Int) {
        print("Server 已发送消息, tag:\(tag)")
        self.sendBodyMessage(socket: sock)
    }
}
