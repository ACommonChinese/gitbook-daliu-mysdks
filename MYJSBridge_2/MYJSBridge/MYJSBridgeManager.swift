//
//  MYJSBridgeManager.swift
//  MYJSBridge
//
//  Created by liuweizhen on 2020/1/11.
//  Copyright © 2020 liuxing8807@126.com. All rights reserved.
//

import UIKit

protocol MYJSBridgeManagerDelegate: class {
    // public typealias AnyClass = AnyObject.Type
    func evaluateJavascript(_ command: String?) -> Any?;
}

class MYJSBridgeManager: NSObject {
    
    /// 弱引用的代理
    weak var delegate: MYJSBridgeManagerDelegate?
    
    /// 自定义 scheme
    static let kJBCustomScheme = "https"
    
    /// 消息队列前缀标识
    static let kJBQueueHasMessage = "__jb_queue_message__"
    
    /// 用以加载MYJSBridge.js文件的标识
    static let kJBBridgeLoaded = "__jb_bridge_loaded__"
    
    /// 获取message queue
    let fetchQueueCommand: String = "MYJSBridge.fetchQueue();"
    
    /// 检测JSBridge是否存在
    let checkCommand = "typeof JSBridge == \'object\';"
    
    /// 唯一标识
    var uniqueId: Int = 0
    
    /// 消息处理 Map
    public var messageHandlers: Dictionary<String, JBHandler> = Dictionary<String, JBHandler>();
    
    // 回调js的方法
    var responseCallbacks: Dictionary<String, Any> = [:]
    
    /// 是否允许打印
    private static var kEnableLogging = false;
    
    /// 允许打印
    public class func enableLogging() {
        kEnableLogging = true;
    }
    
    /// 向JS发送数据
    /*
     self.jsBridge?.callHandler(handlerName: "jsMethod", data: "hello js" as AnyObject, responseCallback: { (result) in
         print(result)
     })
    */
    public func sendData(handlerName: String?, data: AnyObject?, responseCallback: JBResponseCallback?) {
        var message: Dictionary<String, AnyObject> = [:]
        if let handlerName_ = handlerName {
            message["handlerName"] = handlerName_ as AnyObject
        }
        if let data_ = data {
            message["data"] = data_
        }
        if let callback = responseCallback {
            self.uniqueId += 1
            let callbackId = String(format: "objc_cb_%d", self.uniqueId)
            message["callbackId"] = callbackId as AnyObject
            self.responseCallbacks[callbackId] = callback
        }
        self.queueMessage(message: message)
    }
    
    /// 向JS发送消息
    func dispatchMessage(message: Dictionary<String, Any>) {
        
    }
    
    func isJSBridgeURL(url: URL) -> Bool {
        print("isJSBridgeURL执行了!!!!")
        if !isSchemaMatch(url: url) {
            return false
        }
        // https://__jb_bridge_loaded__[即kJBBridgeLoaded]
        // https://__jb_queue_message__[kJBQueueHasMessage]
        return isBridgeLoadedURL(url: url) || isQueueMessageURL(url: url)
    }
    
    func logUnkownMessage(_ url: URL) {
        print("JSBridge: WARNING: Received unknown BMJSBridge command \(url.absoluteString)")
    }
    
    func isSchemaMatch(url: URL) -> Bool {
        guard let schema = url.scheme?.lowercased() else {
            return false
        }
        return schema.elementsEqual(MYJSBridgeManager.kJBCustomScheme)
    }
    
    func isBridgeLoadedURL(url: URL) -> Bool {
        guard let host = url.host?.lowercased() else {
            return false
        }
        return isSchemaMatch(url: url) && host.elementsEqual(MYJSBridgeManager.kJBBridgeLoaded)
    }
    
    func isQueueMessageURL(url: URL) -> Bool {
        // https://__jb_queue_message__/
        guard let host = url.host?.lowercased() else {
            return false
        }
        return isSchemaMatch(url: url) && host.elementsEqual(MYJSBridgeManager.kJBQueueHasMessage)
    }
    
    func injectJavascriptFile() {
        // 注入本地JSBridge.js代码
        
        let path: String? = Bundle.init(for: MYJSBridgeManager.self).path(forResource: "MYJSBridge", ofType: "js")
        print(path ?? "!!")
        
        
        guard let filePath: String = Bundle(for: MYJSBridgeManager.self).path(forResource: "MYJSBridge", ofType: "js") else {
            return
        }
        do {
            let js: String = try String(contentsOfFile: filePath)
            evaluateJavascript(js)
        }
        catch {
            
        }
    }
    
    @discardableResult
    func evaluateJavascript(_ command: String) -> Any? {
        return self.delegate?.evaluateJavascript(command)
    }
    
    // 发送消息给js
    private func queueMessage(message: Dictionary<String, Any>) {
        //TODO://if self.startupMessageQueue
        self.dispatchMessage(message)
    }
    
    // 发送消息给js
    func dispatchMessage(_ message: Dictionary<String, Any>) {
        guard let messageJSON: String = self.serializeMessage(message, pretty: false) else {
            return
        }
        let command: String = String(format: "MYJSBridge.handleMessageFromObjC('%@')", messageJSON)
        if Thread.current.isMainThread {
            self.evaluateJavascript(command)
        }
        else {
            DispatchQueue.main.async {
                self.evaluateJavascript(command)
            }
        }
    }
    
    func flushMessageQueue(_ messageQueueString: String?) {
        guard let messageQueue: String = messageQueueString, !messageQueue.isEmpty else {
            print("""
                JSBridge: WARNING:
                Swift got nil while fetching the message queue JSON from webview.
                This can happen if the JSBridge JS is not currently present in the webview,
                e.g if the webview just loaded a new page.
                """)
            return
        }
        
        guard let messageArray: Array<Any> = self.deserializeMessage(messageQueue) else {
            return
        }
        
        for message in messageArray {
            /**
             {
                 "handlerName": "doIt",
                 "data": {
                     "key": "value"
                 },
                 "callbackId": "cb_1_1578808663568"
             }
             */
            if let dict: Dictionary = (message as? Dictionary<String, Any>) {
                // 如果存在responseId
                // 代表这是Native调js, js回调过来的
                if let responseId: String = dict["responseId"] as? String {
                    if let responseCallback: JBResponseCallback = self.responseCallbacks[responseId] as? JBResponseCallback {
                        responseCallback(dict["responseId"] as AnyObject?);
                        self.responseCallbacks.removeValue(forKey: responseId)
                    }
                }
                else {
                    // callback
                    var responseCallback: JBResponseCallback? = nil
                    // public typealias JBResponseCallback = (AnyObject?) -> Void
                    // callback id
                    // 存在callbackId, 即js需要native回调
                    if let callbackId: String = dict["callbackId"] as? String {
                        print("不存在responseId, 存在callback id")
                        responseCallback = { [weak self] (responseData: Any?) in
                            var message: Dictionary<String, Any> = [:]
                            message["responseId"] = callbackId as AnyObject
                            if let resp = responseData {
                                message["responseData"] = resp
                            }
                            self?.queueMessage(message: message)
                        }
                    }
                    else {
                        responseCallback = { obj in
                            // Do nothing
                        }
                    }
                    
                    let handlerName: String? = dict["handlerName"] as? String
                    if let name = handlerName {
                        let handler: JBHandler? = self.messageHandlers[name]
                        if handler == nil {
                            print("JBNoHandlerException, No handler for message from js: \(dict)")
                            continue
                        }
                        
                        // 调用handler
                        print("调用handler: \(name)")
                        handler?(dict["data"] as AnyObject, responseCallback)
                    }
                    else {
                        print("未找到handlerName: \(handlerName!)")
                        continue
                    }
                }
            }
            else {
                print("接收到了非Dictionary json: \(message)")
                continue
            }
        }
    }
    
    /// 反序列化，JSON字符串 -> List对象
    func deserializeMessage(_ messageJSON: String) -> Array<Any>? {
        // JSONSerialization.jsonObject(with: messageJSON.data(using: .utf8), options: .allowFragments)
        guard let data = messageJSON.data(using: .utf8) else {
            return nil
        }
        
        var arr: Array<Any>? = nil
        do {
            try arr = JSONSerialization.jsonObject(with: data, options: .allowFragments) as? Array<Any>
        } catch {
            return nil
        }
        return arr
    }
    
    // 序列化, 对象 -> JSON
    func serializeMessage(_ message: Any, pretty: Bool) -> String? {
        let option = pretty ? JSONSerialization.WritingOptions .prettyPrinted : JSONSerialization.WritingOptions.fragmentsAllowed
        do {
            let data: Data = try JSONSerialization.data(withJSONObject: message, options: option)
            return String(data: data, encoding: .utf8)
        }
        catch {
            print("serializeMessage error: \(message)")
        }
        return nil
    }
}
