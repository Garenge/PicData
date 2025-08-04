//
//  PPSocketActions.swift
//  GCDSocketDemo
//
//  Created by Garenge on 2024/12/4.
//

import Foundation

/// 长度小于18的字符串, 在前面补0, 补齐18
enum PPSocketActions: String {
    
    /// 请求下载文件
    case requestToDownloadFile
    /// 响应下载文件
    case responseToDownloadFile
    
    /// 取消任务
    case requestToCancelTask
    /// 响应取消任务
    case responseToCancelTask
    
    /// 数据直传
    case directionData
    
    /// 获取动作字符串, 长度不足18的在前面补0
    func getActionString() -> String {
        let actionString = self.rawValue
        let actionLength = actionString.count
        if actionLength < 18 {
            let zeroString = String(repeating: "0", count: 18 - actionLength)
            return zeroString + actionString
        }
        return actionString
    }
}

/// 专门构造一个模型, 专门整理直连数据的格式
struct PPSocketDirectionMsg: PPSocketConvertable {
    
    enum MsgType: String {
        /// 其他类型的消息
        case common
        
        /// 发送设备名称
        case deviceName
        
        /// 移除client, 发指令让client自己离开
        case removeClient
        
        /// 请求文件列表
        case requestFileList
        
        /// 响应文件列表
        case responseFileList
    }
    
    var timestamp: TimeInterval = Date().timeIntervalSince1970
    var type: String
    var content: String?
    
    init(type: String = MsgType.common.rawValue, content: String? = nil) {
        self.type = type
        self.content = content
    }
    
    init(type: MsgType = .common, content: String? = nil) {
        self.type = type.rawValue
        self.content = content
    }
    
    func toString() -> String {
        return self.pp_convertToString() ?? ""
    }
    
    init?(data: Data?) {
        guard let data = data else {
            return nil
        }
        do {
            let decoder = JSONDecoder()
            let msg = try decoder.decode(PPSocketDirectionMsg.self, from: data)
            self.timestamp = msg.timestamp
            self.type = msg.type
            self.content = msg.content
        } catch {
            print(error)
            return nil
        }
    }
    
}
