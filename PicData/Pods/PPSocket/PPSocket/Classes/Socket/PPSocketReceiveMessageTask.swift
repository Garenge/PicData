//
//  ReceiveMessageTask.swift
//  GCDSocketDemo
//
//  Created by Garenge on 2024/12/1.
//

import UIKit

/// 将ReceiveMessageTask直接回调给client还是有点不合适的, 暴露的信息过多, 最好是整理一个新的数据模型, 然后回调给client
public typealias PPReceiveMessageTaskBlock = (_ messageTask: PPSocketReceiveMessageTask?) -> ()

/// 收消息的模型
public class PPSocketReceiveMessageTask: NSObject {
    
    deinit {
        print("======== ReceiveMessageTask \(self) deinit ========")
    }
    /// 每个任务有独一无二的key
    var taskId: String? {
        didSet {
            guard let messageKey = taskId else {
                return
            }
            DispatchQueue.main.async {
                self.initialReceiveSpeedTimer()
            }
            receiveMessageTimeoutInterver = 5
        }
    }
    /// 数据分包的总包数
    var bodyCount: Int = 1
    /// 数据分包的当前包数
    var bodyIndex: Int = 0
    /// 此次传输, 总的数据长度
    var totalLength: UInt64 = 0
    /// 已接收数据的长度
    var receivedOffset: UInt64 = 0 {
        didSet {
            if (receivedOffset == totalLength) {
                self.finishReceiveTask()
            }
        }
    }
    
    /// 大数据传输时的进度
    public var progress: Double {
        if totalLength == 0 {
            return 0
        } else {
            return Double(receivedOffset) / Double(totalLength)
        }
    }
    
    /// 数据类型
    var messageType: PPSocketTransMessageType = .directionData
    
    /// 文件才有, 文件路径
    public var filePath: String?
    /// 文件才有, 文件句柄
    var fileHandle: FileHandle?
    
    /// 如果是数据流, 直接拼接
    var directionData: Data?
    
    /// 收到数据结束回调
    public var didReceiveDataCompleteBlock: PPReceiveMessageTaskBlock?
    /// 收到数据过程回调
    public var didReceiveDataProgressBlock: PPReceiveMessageTaskBlock?
    
    /// 默认超时时间, 部分指令从发出就开始等待接收, 设置等待超时时间, 如果超时, 就取消接收任务
    public var receiveMessageTimeoutInterver: TimeInterval = 5 {
        didSet {
            currentReceiveMessageTimeoutInterverCount = 0
            guard receiveMessageTimeoutInterver > 0 else {
                return
            }
            DispatchQueue.main.async { [weak self] in
                guard let self = self else {
                    return
                }
                self.initialReceiveMessageTimeoutTimer()
            }
        }
    }
    /// 超时倒计时的计数器
    private var currentReceiveMessageTimeoutInterverCount: TimeInterval = 0
    private var receiveMessageTimeoutTimer: Timer?
    private func initialReceiveMessageTimeoutTimer() {
        receiveMessageTimeoutTimer?.invalidate()
        receiveMessageTimeoutTimer = Timer.init(timeInterval: 1, repeats: true, block: { [weak self] timer in
            guard let self = self else {
                return
            }
            self.currentReceiveMessageTimeoutInterverCount += 1
            if currentReceiveMessageTimeoutInterverCount >= receiveMessageTimeoutInterver {
                self.currentReceiveMessageTimeoutInterverCount = 0
                self.finishReceiveTask()
                print("当前: \(self) 接收数据超时")
                self.receiveMessageTimeoutBlock?()
            }
        })
        RunLoop.current.add(receiveMessageTimeoutTimer!, forMode: .default)
    }
    /// 超时的回调, 会自动取消任务
    public var receiveMessageTimeoutBlock: (() -> ())?
    
    /// 网速回调
    public var toReceiveTransSpeedChangedBlock: ((_ speed: UInt64) -> ())?
    /// 网速
    public var toReceiveTransSpeed: UInt64 = 0 {
        didSet {
            print("当前: \(self) 接收数据网速: \(toReceiveTransSpeed)B/s")
            toReceiveTransSpeedChangedBlock?(toReceiveTransSpeed)
        }
    }
    /// 计算网速
    private var toReceiveSpeedTimer: Timer?
    /// 一秒钟计算一次增值就好了
    private var toReceiveLastSpeedValue: UInt64 = 0
    private func initialReceiveSpeedTimer() {
        toReceiveSpeedTimer?.invalidate()
        
        // 放到主线程
        toReceiveSpeedTimer = Timer(timeInterval: 1, repeats: true, block: {[weak self] _ in
            guard let self = self else {
                return
            }
            self.calculateReceiveSpeed()
        })
        RunLoop.current.add(toReceiveSpeedTimer!, forMode: .default)
    }
    
    private func calculateReceiveSpeed() {
        self.toReceiveTransSpeed = self.receivedOffset - self.toReceiveLastSpeedValue
        self.toReceiveLastSpeedValue = self.receivedOffset
    }
    
    public func finishReceiveTask() {
        // 结束网速计算
        self.calculateReceiveSpeed()
        toReceiveSpeedTimer?.invalidate()
        toReceiveSpeedTimer = nil
        self.calculateReceiveSpeed()
        
        // 结束倒计时定时器
        receiveMessageTimeoutTimer?.invalidate()
        receiveMessageTimeoutTimer = nil
    }
}
