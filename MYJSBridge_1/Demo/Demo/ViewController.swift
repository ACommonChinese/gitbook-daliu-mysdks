//
//  ViewController.swift
//  Demo
//
//  Created by liuweizhen on 2020/1/11.
//  Copyright © 2020 liuxing8807@126.com. All rights reserved.
//

import UIKit
import WebKit
import MYJSBridge

class ViewController: UIViewController, WKUIDelegate {

    @IBOutlet weak var webView: WKWebView!
    
    private var jsBridge: MYJSBridge?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.configUI()
    }
    
    func configUI() {
        self.view.backgroundColor = UIColor.red
        let url = URL(fileURLWithPath: Bundle.main.path(forResource: "index", ofType: "html")!)
        let request = URLRequest(url: url)
        self.webView.load(request)
        self.webView.uiDelegate = self
        do {
            try self.jsBridge = MYJSBridge.bridge(webView: self.webView)
            // try self.jsBridge = MYWKWebViewJSBridge.bridge(webView: webView)
            //print(self.webView.navigationDelegate!)
        }
        catch {
            print("error error error")
        }
        
        // public typealias JBResponseCallback = (AnyObject?) -> Void
        // public typealias JBHandler = (AnyObject?, JBResponseCallback?) -> Void
        // native注册方法doIt给js调用
        self.jsBridge?.registerHandler(handlerName: "doIt", handler: { (result: AnyObject?, callback: JBResponseCallback?) in
            // [weak self] (result: AnyObject?, ...)
            if let res = result {
                print("JS调用native成功: \(res)")
                // self?.showAlert("JS调用native成功: \(res)")
                if let call = callback {
                    call("大刘测试: Native回调js" as AnyObject)
                }
            }
        })
    }
    
    // Native调用js的方法
    @IBAction func callJsMethod(_ sender: Any) {
        self.jsBridge?.callHandler(handlerName: "jsMethod", data: "hello js" as AnyObject, responseCallback: { (result) in
            if let str = result as? String {
                self.showAlert("JS回调Native成功: \(str)")
            }
        })
    }
    
    func showAlert(_ message: String) {
        let alert: UIAlertController = UIAlertController(title: "JS 消息", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: { (action) in
        }))
        self.present(alert, animated: true, completion: nil)
    }
        
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert: UIAlertController = UIAlertController(title: "JS 消息", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: { (action) in
            completionHandler()
        }))
        self.present(alert, animated: true, completion: nil)
    }
    
    @IBAction func test(_ sender: Any) {
        self.webView.evaluateJavaScript("typeof window.MYJSBridge == 'object'") { (result, error) in
            guard let res = result else {
                return
            }
            if res is String {
                let resStr: String = res as! String
                print(resStr)
                if "true".elementsEqual(resStr) { // 即如果window.MYJSBridge对象不存在
                    self.showAlert("注入成功")
                }
            }
            else if res is Int {
                let ret: Int = res as! Int
                if ret == 0 {
                    self.showAlert("注入失败: \(ret)")
                }
                else {
                    self.showAlert("注入成功: \(ret)")
                }
            }
        }
    }
}

