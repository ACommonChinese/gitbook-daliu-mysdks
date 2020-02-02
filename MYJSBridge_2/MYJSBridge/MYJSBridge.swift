//
//  MYJSBridge.swift
//  MYJSBridge
//
//  Created by liuweizhen on 2020/1/11.
//  Copyright © 2020 liuxing8807@126.com. All rights reserved.
//

import Foundation
import WebKit

enum MYJSBridgeError: Error {
    case WebViewType(String)
}

public class MYJSBridge: NSObject, MYJSBridgeManagerDelegate {
    
    weak open var navigationDelegate: WKNavigationDelegate?
    
    var bridgeManager: MYJSBridgeManager = MYJSBridgeManager()
    
    public required init(webView: WKWebView) {
        super.init()
        self.bridgeManager.delegate = self
    }
    
    public class func bridge(webView: WKWebView) throws -> MYJSBridge {
        /// AnyClass
        /// public typealias AnyClass = AnyObject.Type
        if !webView.isKind(of: WKWebView.self) {
            throw MYJSBridgeError.WebViewType("webview type error")
        }
        
        /// return WKWebViewJSBridge.bridge(webView: webView)
        /// Cannot convert return expression of type 'WKWebViewJSBridge' to return type 'Self'
        /// Your method is declared to return Self, whereas you are returning WKWebViewJSBridge
        /// in subclasses, Self will be that subclass type, and WKWebViewJSBridge is not a subtype of that type.
        /// return WKWebViewJSBridge(webView: webView)
        /// return self.init(webView: webView)
        
        return MYWKWebViewJSBridge(webView: webView)
    }
    
    // MARK: - JSBridgeManagerDelegate
    public func evaluateJavascript(_ command: String?) -> Any? {
        // AnyClass
        // public typealias AnyClass = AnyObject.Type
        fatalError("子类实现")
    }
    
    /// 注册Handler
    public func registerHandler(handlerName: String, handler: JBHandler?) {
        self.bridgeManager.messageHandlers[handlerName] = handler
    }
    
    /// 移除Handler
    public func removeHandler(handlerName: String) {
        self.bridgeManager.messageHandlers.removeValue(forKey: handlerName)
    }
    
    /// Native调用JS
    /// - Parameter handlerName: 处理标识
    public func callHandler(handlerName: String?) {
        self.callHandler(handlerName: handlerName, data: nil)
    }
    
    /// Native调用JS
    /// - Parameter handlerName: 处理标识
    /// - Parameter data: 数据
    public func callHandler(handlerName: String?, data: AnyObject?) {
        self.callHandler(handlerName: handlerName, data: data, responseCallback: nil)
    }
    
    /// Native调用JS
    /// - Parameter handlerName: 处理标识
    /// - Parameter data: 数据
    /// - Parameter responseCallback: 回调
    public func callHandler(handlerName: String?, data: AnyObject?, responseCallback: JBResponseCallback?) {
        self.bridgeManager.sendData(handlerName: handlerName, data: data, responseCallback: responseCallback)
    }
    
    /// 允许日志打印
    public func enableLogging() {
        MYJSBridgeManager.enableLogging()
    }
}
