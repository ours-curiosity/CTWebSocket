//
//  ViewController.swift
//  CTWebSocket
//
//  Created by ghostlordstar on 12/01/2020.
//  Copyright (c) 2020 ghostlordstar. All rights reserved.
//

import UIKit
import CTWebSocket
class ViewController: UIViewController {

    var ctws: CTWebSocket?
    
    @IBOutlet weak var wsAddressField: UITextField!
    @IBOutlet weak var sendMessageField: UITextField!
    @IBOutlet weak var logTextView: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    
    @IBAction func clearBtnAction(_ sender: UIButton) {
        
        self.logTextView.text = "----------log-------->>>\n"
    }
    @IBAction func sendBtnAction(_ sender: UIButton) {
        
        if let text = self.sendMessageField.text {
            self.ctws?.ws_sendMsg(text)
        }
    }
    
    @IBAction func connectBtnAction(_ sender: UIButton) {
        
        if let url = wsAddressField.text {
            let req = URLRequest.init(url: URL.init(string: url) ?? URL.init(string: "ws://123.207.136.134:9010/ajaxchattest")!)
            self.ctws = CTWebSocket.init(request: req)
            self.ctws?.delegate = self
//            self.ctws?.parseDelegate = self
            self.addLog(newLog: "开启websoket:\(req.url?.absoluteString ?? "")")
        }
    }
    
    @IBAction func disConnectBtnAction(_ sender: UIButton) {
        self.ctws?.ws_disconnect(isForce: true)
        self.addLog(newLog: "断开websocket:\(self.ctws?.wsRequest?.url?.absoluteString ?? "")")
    }
    
    private func addLog(newLog: String) {
 
        DispatchQueue.main.async {
            var log = self.logTextView.text
            log = ">>>" + newLog + "\n" + (log ?? "")
            self.logTextView.text = log
        }
    }
    
    private func clearLog() {
        self.logTextView.text = ""
    }
}

extension ViewController: CTWebSocketProtocol, CTWebSocketReceivedParse {
    func ws_didConnect(req: URLRequest?, ws: CTWebSocket) {
        self.addLog(newLog: "ws_didConnect")
    }
    
    func ws_didDisConnect(req: URLRequest?, ws: CTWebSocket) {
        self.addLog(newLog: "ws_didDisConnect")
    }
    
    func ws_connectError(errorType: CTWebSocketErrorType, error: Error?) {
        self.addLog(newLog: "ws_connectError:\(String(describing: errorType)), \(String(describing: error))")
    }

    func ws_sendMsg(isSuc: Bool, error: CTWebSocketErrorType, msg: Any?, ws: CTWebSocket) {
        self.addLog(newLog: "ws_sendMsg：\(String(describing: msg)), error: \(String(describing: error))")
    }
    
    func ws_didReceivedStringMsg(msg: String?) {
        self.addLog(newLog: "ws_didReceivedStringMsg：\(String(describing: msg))")
    }
    
    func ws_didReceivedDataMsg(data: Data?) {
        
    }
    
    func ws_didReceivedJsonObject(object: [String : Any]?) {
        self.addLog(newLog: "ws_didReceivedJsonObject：\(object)")
    }
    
    func ws_viabilityChanged() {
        self.addLog(newLog: "ws_viabilityChanged")
    }
}
