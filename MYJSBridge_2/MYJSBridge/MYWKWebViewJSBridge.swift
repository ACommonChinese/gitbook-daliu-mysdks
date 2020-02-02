//
//  MYWKWebViewJSBridge.swift
//  MYJSBridge
//
//  Created by liuweizhen on 2020/1/11.
//  Copyright © 2020 liuxing8807@126.com. All rights reserved.
//

import Foundation
import UIKit
import WebKit

public class MYWKWebViewJSBridge: MYJSBridge, WKNavigationDelegate {
    private var webView: WKWebView

    required public init(webView: WKWebView) {
        self.webView = webView
        super.init(webView: webView)
        self.webView.navigationDelegate = self
    }
    
    public override class func bridge(webView: WKWebView) throws -> Self {
        return self.init(webView: webView)
    }
    
    /// 注入JS代码
    func injectJavascriptFile() {
        let result: Any? = evaluateJavascript("typeof window.MYJSBridge == 'object'")
        guard let res = result else {
            return
        }
        if res is String {
            let resStr: String = res as! String
            if !"true".elementsEqual(resStr) { // 即如果window.MYJSBridge对象不存在
                print("window.MYJSBridge不存在, 准备注入JS")
                self.bridgeManager.injectJavascriptFile()
            }
        }
    }
    
    /// 执行JS代码 javascriptCommand
    override
    public func evaluateJavascript(_ command: String?) -> Any? {
        guard let cmd = command else { return nil }
        
        print("要注入的js内容:")
        print("========================")
        print(cmd)
        print("========================")
        
        var finished = false
        var retValue: Any?
        
        self.webView.evaluateJavaScript(cmd) { (data, error) in
            // The completion handler always runs on the main thread.
            
            retValue = data
            
            if error == nil && data != nil {
                if data is String {
                    retValue = data as! String
                }
                else {
                    if let success: NSNumber = data as? NSNumber, true == success.boolValue {
                        retValue = "true"
                    }
                    else {
                        retValue = "false"
                    }
                }
            }

            finished = true
        }
        while !finished {
            RunLoop.current.run(mode: .default, before: Date.distantFuture)
        }
        return retValue
    }
    
    // MARK: - WKNavigationDelegate
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if webView != self.webView {
            return
        }

        // 注入JS代码
        injectJavascriptFile()
        
        // 转发原始的webView的navigationDelegate
        self.navigationDelegate?.webView?(webView, didFinish: navigation)
    }
    
    public func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if webView != self.webView {
            return
        }
        
        /// 转发原始的webView的navigationDelegate
        /// 注：此处必须有 as 判断，否则由于方法重名，引起
        /// Ambiguous use of 'webView(_:decidePolicyFor:decisionHandler:)'
        /// https://stackoverflow.com/questions/39658358/swift-3-wkwebview-delegate-wknavigationdelegate-ambiguous-method
        typealias WKNavigationResponseMethodType = (WKWebView, WKNavigationResponse, @escaping (WKNavigationResponsePolicy) -> Void) -> Void
        if let navigationDelegate = self.navigationDelegate, navigationDelegate.responds(to: #selector(webView(_:decidePolicyFor:decisionHandler:) as WKNavigationResponseMethodType)) {
           navigationDelegate.webView?(webView, decidePolicyFor: navigationResponse, decisionHandler: decisionHandler)
        }
        else {
            decisionHandler(.allow)
        }
    }
    
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if webView != self.webView {
            return
        }
        
        if handleJSBridgeAction(navigationAction) {
            decisionHandler(.cancel)
            return
        }
        
        /// https://stackoverflow.com/questions/39658358/swift-3-wkwebview-delegate-wknavigationdelegate-ambiguous-method
        typealias WKNavigationActionMethodType = (WKWebView, WKNavigationAction, @escaping (WKNavigationActionPolicy) -> Void) -> Void
        if let navigationDelegate = webView.navigationDelegate, navigationDelegate.responds(to: #selector(webView(_:decidePolicyFor:decisionHandler:) as WKNavigationActionMethodType)) {
            navigationDelegate.webView?(webView, decidePolicyFor: navigationAction, decisionHandler: decisionHandler)
        } else {
            decisionHandler(.allow)
        }
    }
    
    /// 加载JSBridge文件: https://__jb_bridge_loaded__/
    /// JS发送过来消息: https://__jb_queue_message__
    func handleJSBridgeAction(_ navigation: WKNavigationAction) -> Bool {
        guard let url = navigation.request.url else {
            return false
        }
        if self.bridgeManager.isJSBridgeURL(url: url) {
            //isJSBridgeURL不会得到执行???
            if self.bridgeManager.isBridgeLoadedURL(url: url) {
                self.injectJavascriptFile()
            }
            else if self.bridgeManager.isQueueMessageURL(url: url) {
                self.flushMessageQueue()
            }
            else {
                self.bridgeManager.logUnkownMessage(url)
            }
            return true
        }
        return false
    }
    
    @available(iOS 13.0, *)
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, preferences: WKWebpagePreferences, decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void) {
        if webView != self.webView {
            return
        }
        if self.handleJSBridgeAction(navigationAction) {
            decisionHandler(.cancel, preferences)
            return
        }
        // 转发原始的webView的navigationDelegate
        if let navigationDelegate = self.navigationDelegate, navigationDelegate.responds(to: #selector(webView(_:decidePolicyFor:preferences:decisionHandler:))) {
             navigationDelegate.webView?(webView, decidePolicyFor: navigationAction, preferences: preferences, decisionHandler: decisionHandler)
        }
        else {
            decisionHandler(.allow, preferences)
        }
    }
    
    public func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if webView != self.webView {
            return
        }
        
        self.navigationDelegate?.webView?(webView, didReceive: challenge, completionHandler: completionHandler)
    }
    
    func flushMessageQueue() {
           /**
            * 得到JS中维护的 sendMessageQueue 列表
            [
               message字符串1: {handlerName: 'doIt1', data: {key: 'value'}, callbackId: callbackId}
               message字符串2: {handlerName: 'doIt2', data: {key: 'value'}, callbackId: callbackId}
               message字符串3: {handlerName: 'doIt3', data: {key: 'value'}, callbackId: callbackId}
               message字符串4: {handlerName: 'doIt4', data: {key: 'value'}, callbackId: callbackId}
               ...
            ]
            */
           self.webView.evaluateJavaScript(self.bridgeManager.fetchQueueCommand) { (result, error) in
            /**
             [
                 {
                     "handlerName": "doIt",
                     "data": {
                         "key": "value"
                     },
                     "callbackId": "cb_1_1578808663568"
                 }
             ]
             */
               guard let resultStr = result else {
                   print("something wrong, js return null")
                   return
               }
               if let err = error {
                   print("""
                       WKWebViewJavascriptBridge: "
                       WARNING: Error when trying to fetch data from WKWebView: \(err)
                       """)
                   return
               }
               if false == (resultStr is String) {
                   print("something wrong, js return not string")
               }
               else {
                   self.bridgeManager.flushMessageQueue(resultStr as? String)
               }
           }
       }
}
