//
//  CTWebSocket.swift
//  CTWebSocket
//
//  Created by apple on 2020/12/1.
//

import UIKit
import Starscream

/// ws的状态
@objc public enum CTWebSocketState: Int {
    case disconnected       // 已经断开
    case connected          // 已经连接
    case connecting         // 正在连接
    case disconnecting      // 正在断开
}

/// ws操作错误类型
@objc public enum CTWebSocketErrorType: Int {
    case none               // 无错误
    case requestError       // 请求体错误
    case websocketNil       // websocket实例为空
    case disconnected       // websocket断开状态
    case massageNil         // 消息体为空
    case didCancel          // 被取消
}

@objc public protocol CTWebSocketProtocol: class {
    /// ws已经连接成功
    /// - Parameters:
    ///   - req: ws的请求
    ///   - ws: ws实例
    @objc optional func ws_didConnect(req: URLRequest?, ws: CTWebSocket)
    
    /// ws已经断开连接
    /// - Parameters:
    ///   - req: ws的请求
    ///   - ws: ws管理器实例
    @objc optional func ws_didDisConnect(req: URLRequest?, ws: CTWebSocket)
    
    /// 连接失败
    /// - Parameter errorType: 失败类型
    /// - Parameter error: 失败原因
    @objc optional func ws_connectError(errorType: CTWebSocketErrorType, error: Error?)
    
    /// ws 发送ping超时
    /// - Parameters:
    ///   - req: ws的请求
    ///   - ws: ws管理器实例
    @objc optional func ws_didPingTimeOut(req: URLRequest?, ws: CTWebSocket)
    
    /// ws发送消息
    /// - Parameters:
    ///   - isSuc: 是否成功
    ///   - error: 失败原因
    ///   - msg: 消息体
    ///   - ws: socket实例
    @objc optional func ws_sendMsg(isSuc: Bool, error: CTWebSocketErrorType, msg: Any?, ws: CTWebSocket)
    
    /// 接到消息
    /// - Parameter msg: 消息内容
    @objc optional func ws_didReceivedStringMsg(msg: String?)
    
    /// 接到消息
    /// - Parameter data: 二进制消息内容
    @objc optional func ws_didReceivedDataMsg(data: Data?)
    
    /// 网络状态发生变化
    @objc optional func ws_viabilityChanged()
}

/// 解析相关协议
@objc public protocol CTWebSocketReceivedParse: class {
    /// 接到的解析后的数据
    /// - Parameter messageDict: 接到的消息对象
    func ws_didReceivedJsonObject(object: [String: Any]?)
}

public class CTWebSocket: NSObject {
    
    /// ws实例
    public private(set) var socket: WebSocket?
    /// ws状态
    public private(set) var wsState: CTWebSocketState = .disconnected
    /// ws的连接
    public private(set) var wsRequest: URLRequest?
    /// 上次发送ping的时间戳
    public private(set) var lastPingStmp: TimeInterval = 0
    /// 心跳间隔
    public var heartTimeInterval: TimeInterval? = 5
    /// 心跳计时器
    private weak var heartTimer: Timer?
    /// ping超时时间
    public var pingTimeOut: TimeInterval = 60
    /// 代理
    public weak var delegate: CTWebSocketProtocol?
    public weak var parseDelegate: CTWebSocketReceivedParse?
    
    // MARK: - public -
    /// 链接ws
    /// - Parameter roomId: roomid
    /// - parameter isForce: 强制连接，如果为YES，无论url是否一致都断开重新连接
    public func ws_connect(request: URLRequest? = nil, isForce: Bool? = false) {
        
        if request == nil {
            self.delegate?.ws_connectError?(errorType: CTWebSocketErrorType.requestError, error: nil)
            return
        }
        
        if isForce != true && self.wsRequest?.url?.absoluteString == request!.url?.absoluteString {
            self.socket?.delegate = self
            self.wsState = .connecting
            self.socket?.connect()
        }else {
            self.ws_disconnect(isForce: true)
            self.socket = WebSocket.init(request: request!)
            debugPrint("WebSocket -- create ")
            self.socket?.delegate = self
            self.wsState = .connecting
            self.socket?.connect()
        }
        
        self.wsRequest = request!
    }
    
    /// 断开连接
    /// - Parameter isForce: 是否强制
    public func ws_disconnect(isForce: Bool? = false) {
        self.wsState = .disconnecting
        if isForce == true {
            self.socket?.forceDisconnect()
        }else {
            self.socket?.disconnect()
        }
        self.socket = nil
        self.wsState = .disconnected
    }
    
    /// 发送消息
    /// - Parameter msg: 消息体
    public func ws_sendMsg(_ msg: String?) {
        if self.socket == nil {
            self.delegate?.ws_sendMsg?(isSuc: false, error: .websocketNil, msg: msg, ws: self)
            return
        }
        
        if msg?.isEmpty ?? true {
            self.delegate?.ws_sendMsg?(isSuc: false, error: .massageNil, msg: msg, ws: self)
            return
        }
        
        self.socket?.write(string: msg!, completion: {
            self.delegate?.ws_sendMsg?(isSuc: true, error: .none , msg: msg, ws: self)
        })
    }
    
    /// 发送消息
    /// - Parameter msgData: 二进制消息体
    public func ws_sendMsg(_ msgData: Data?) {
        if self.socket == nil {
            self.delegate?.ws_sendMsg?(isSuc: false, error: .websocketNil, msg: msgData, ws: self)
            return
        }
        
        if msgData == nil {
            self.delegate?.ws_sendMsg?(isSuc: false, error: .massageNil, msg: msgData, ws: self)
            return
        }
        
        self.socket?.write(data: msgData!, completion: {
            self.delegate?.ws_sendMsg?(isSuc: true, error: .none, msg: msgData, ws: self)
        })
    }
    
    // MARK: - private -
    
    /// 发送心跳
    /// - Parameter timeInterval: 心跳间隔
    private func beginSendHeart(timeInterval: TimeInterval?) {
        if (timeInterval != nil && timeInterval != self.heartTimeInterval) || self.heartTimeInterval == nil {
            self.heartTimeInterval = timeInterval ?? 5.0
        }
        if self.socket != nil && self.wsState == .connected {
            let timer = Timer.init(timeInterval: self.heartTimeInterval!, repeats: true, block: { [weak self] (timer) in
                guard let `self` = self else {return}
                self.sendPing()
            })
            RunLoop.current.add(timer, forMode: RunLoop.Mode.common)
            self.stopHeart()
            self.heartTimer = timer
            self.lastPingStmp = 0
            self.heartTimer?.fire()
        }
    }
    
    /// 发送心跳
    private func sendPing() {
        if socket != nil && self.wsState == .connected {
            self.socket?.write(ping: Data())
        }
        let nowStmp = Date().timeIntervalSince1970
        if self.lastPingStmp == 0 {
            self.lastPingStmp = nowStmp
        }else if nowStmp - self.lastPingStmp > self.pingTimeOut { // ping超时
            self.delegate?.ws_didPingTimeOut?(req: self.wsRequest, ws: self)
        }
        
        debugPrint("websocket-- send ping, last stmp:\(self.lastPingStmp)")
    }
    
    /// 停发心跳
    private func stopHeart() {
        if self.heartTimer != nil {
            self.heartTimer?.invalidate()
            self.heartTimer = nil
        }
    }
    
    /// 处理接到的webSocket消息
    /// - Parameter msg: msg
    private func processReceiveMessage(msg: String) {
        if let data = msg.data(using: .utf8) {
            self.processReceiveData(data: data)
        }
    }
    
    /// 解析数据
    /// - Parameter data: 二进制数据
    private func processReceiveData(data: Data) {
        if self.parseDelegate != nil {
            do {
                if let dict = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] {
                    self.parseDelegate?.ws_didReceivedJsonObject(object: dict)
                }
            }catch {
                print("p_processReceiveData error: \(error)")
            }
        }
    }
    
    /// 检测请求体是否可用
    /// - Parameter request: 请求体
    /// - Returns: 是否可用
    private func checkRequestIsAvailable(request: URLRequest?) -> Bool {
        return (request != nil && (request!.url?.absoluteString.count ?? 0) > 0)
    }
}

extension CTWebSocket {
    
    /// 初始化并连接传入的socket地址
    /// - Parameter request: 请求的URLRequest
    public convenience init(request: URLRequest?) {
        self.init()
        if request != nil {
            self.ws_connect(request: request, isForce: true)
        }
    }
}

/// 代理
extension CTWebSocket: WebSocketDelegate {
    public func didReceive(event: WebSocketEvent, client: WebSocket) {
        switch event {
        case .text(let msg):
            self.delegate?.ws_didReceivedStringMsg?(msg: msg)
            self.processReceiveMessage(msg: msg)
            debugPrint("websocket--text:\(msg)")

        case .binary(let msgData):
            self.delegate?.ws_didReceivedDataMsg?(data: msgData)
            self.processReceiveData(data: msgData)
            debugPrint("websocket--binary:\(msgData.count)")

        case .connected(let headers):
            self.wsState = .connected
            self.beginSendHeart(timeInterval: nil)
            self.delegate?.ws_didConnect?(req: self.wsRequest, ws: self)
            debugPrint("websocket--connected: \(headers)")
            
        case .disconnected(let reason, let code):
            self.stopHeart()
            self.wsState = .disconnected
            self.delegate?.ws_didDisConnect?(req: self.wsRequest, ws: self)
            debugPrint("websocket--reason:\(reason), code: \(code)")
            
        case .ping(_):
            debugPrint("websocket-- rec ping last stmp:\(self.lastPingStmp)")
        case .pong(_):
            self.lastPingStmp = 0
            debugPrint("websocket--rec pong")
            
        case .viabilityChanged(let isAvailable):
            if isAvailable == false{
                self.stopHeart()
                self.wsState = .disconnected
                self.delegate?.ws_viabilityChanged?()
            }
            debugPrint("websocket--viabilityChanged:\(isAvailable)")

        case .reconnectSuggested(let isAvailable):
            self.beginSendHeart(timeInterval: nil)
            debugPrint("websocket--reconnectSuggested:\(isAvailable)")

        case .error(let error):
            self.stopHeart()
            self.wsState = .disconnected
            self.delegate?.ws_connectError?(errorType: .disconnected, error: error)
            debugPrint("websocket--error:\(String(describing: error))")

        case .cancelled:
            self.stopHeart()
            self.wsState = .disconnected
            self.delegate?.ws_connectError?(errorType: .didCancel, error: nil)
            debugPrint("websocket--cancelled")
        }
    }
}
