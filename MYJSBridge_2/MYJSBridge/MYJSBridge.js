!function() {
    // 检查window.MYJSBridge对象是否存在, 如果已存在,代表注入已成功,直接使用
    if (window.MYJSBridge) {
        return;
    }

    // Define window.MYJSBridge
    window.MYJSBridge = {
        // Scheme标识
        customProtocolScheme : "https",

        // queue message 标识
        // https://__jb_bridge_loaded__[即kJBBridgeLoaded]
        // https://__jb_queue_message__[kJBQueueHasMessage]
        queueHasMessage : "__jb_queue_message__",

        // Messaging iframe
        messagingIframe : false,

        // JS发送给native的消息的队列，数组类型
        sendMessageQueue : [],

        // 消息处理，Map类型
        messageHandlers : {},

        // 响应回调，Map类型，用于保存Native回调JS的方法
        responseCallbacks : {},

        // 惟一标识, 从1开始
        uniqueId : 1,

        // Dispatch message with timeout safety
        dispatchMessagesWithTimeoutSafety : true,

        // 注册handler
        registerHandler: function (handlerName, handler) {
            this.messageHandlers[handlerName] = handler;
        },

        // Call
        call: function(handlerName, data, responseCallback) {
            // alert('hello'); // TODO://弹不出来
            if (arguments.length == 2 && typeof data == 'function') {
                responseCallback = data;
                data = null;
            }
            this.doSend({ handlerName:handlerName, data:data }, responseCallback);
        },

        // Call handler
        callHandler: function(handlerName, data, responseCallback) {
            this.call(handlerName, data, responseCallback);
        },
  
        // Disable javascript alert box safety timeout
        disableJavscriptAlertBoxSafetyTimeout: function () {
            this.dispatchMessagesWithTimeoutSafety = false;
        },

        // 获取消息队列
        // 每次获取后就会清空
        fetchQueue: function () {
            var messageQueueString = JSON.stringify(this.sendMessageQueue);
            this.sendMessageQueue = [];
            return messageQueueString;
        },

        // 处理native发过来的消息
        handleMessageFromObjC: function(messageJSON) {
            if (this.dispatchMessagesWithTimeoutSafety) {
                var _this = this;
                setTimeout(function() { _this.dispatchMessageFromObjC(messageJSON); });
            } else {
                this.dispatchMessageFromObjC(messageJSON);
            }
        },

        // Dispatch message from Objective C
        dispatchMessageFromObjC : function(messageJSON) {
            if (this.dispatchMessagesWithTimeoutSafety) {
                var _this = this;
                setTimeout(function() { _this.doDispatchMessageFromObjC(messageJSON);});
            } else {
                this.doDispatchMessageFromObjC(messageJSON);
            }
        },

        // 处理native过来的消息
        doDispatchMessageFromObjC : function(messageJSON) {
            var message = JSON.parse(messageJSON);
            var messageHandler;
            var responseCallback;
            if (message.responseId) {
                responseCallback = this.responseCallbacks[message.responseId];
                if (!responseCallback) {
                    return;
                }
                responseCallback(message.responseData);
                delete this.responseCallbacks[message.responseId];
            } else {
                var _this = this;
                if (message.callbackId) {
                    alert("Native过来的消息" + messageJSON)
                    var callbackResponseId = message.callbackId;
                    responseCallback = function(responseData) {
                        _this.doSend({ handlerName:message.handlerName,
                                     responseId:callbackResponseId,
                                     responseData:responseData });
                    };
                }

                var handler = this.messageHandlers[message.handlerName];
                alert(message.handlerName);
                alert(message);
                if (!handler) {
                    console.log("MYJSBridge: WARNING: no handler for message from ObjC:", message);
                } else {
                    handler(message.data, responseCallback);
                }
            }
        },

        // 发送消息给Native
        // message是一个对象, 比如：
        // {handlerName: 'doIt', data: {key: 'value'}, callbackId: callbackId}
        doSend: function (message, responseCallback) {
            alert("doSend: !!!" + message); // 执行了
            // 如果存在Native回调JS的方法，把此callback方法保存起来，并关联一个惟一的id
            if (responseCallback) {
                var callbackId = 'cb_' + (this.uniqueId++) + '_' + new Date().getTime();
                this.responseCallbacks[callbackId] = responseCallback;
                message['callbackId'] = callbackId;
            }
            // 发送消息，只是把message对象加入sendMessageQueue队列中
            // 到了webview的代理方法时，再通过`MYJSBridge.fetchQueue()`获取这个消息列表
            this.sendMessageQueue.push(message);
  
            // 检测是否消息iframe被添加到了DOM上
            // queueHasMessage: __jb_queue_message__
            // iframe
            // key: __jb_queue_message__
            // value:
            if (!document.getElementById(this.queueHasMessage)) {
                document.documentElement.appendChild(this.messagingIframe);
            }
            // https://__jb_queue_message__
            // 这会走到WKNavigationDelegate代理方法中:
            // webView:decidePolicyForNavigationAction:decisionHandler:
            this.messagingIframe.src = this.customProtocolScheme + '://' + this.queueHasMessage;
        },

        // 初始化方法
        // 此JS文件一旦被注入，此方法就会得到调用
        initialize: function() {
            // Create iframe
            this.messagingIframe = document.createElement('iframe');
            this.messagingIframe.style.display = 'none';
            this.messagingIframe.id = this.queueHasMessage;
            this.messagingIframe.src = this.customProtocolScheme + '://' + this.queueHasMessage;
            document.documentElement.appendChild(this.messagingIframe);

            // Register handler
            this.registerHandler("_disableJavascriptAlertBoxSafetyTimeout",
                                 this.disableJavscriptAlertBoxSafetyTimeout);

            // Detech callbacks
            setTimeout(function() {
                var callbacks = window.BMJsCallbacks;
                delete window.BMJsCallbacks;
                if (callbacks) {
                    for (var i = 0; i < callbacks.length; ++i) {
                        callbacks[i](MYJSBridge);
                    }
                }
            }, 0);
        }
    };
//
//    // Compitable for WindVane
//    if (!window.WindVane) {
//        window.WindVane = {};
//        for (var p in window.MYJSBridge) {
//            window.WindVane[p] = window.MYJSBridge[p];
//        }
//        window.WindVane.call = function(bridge,
//                                        handlerName,
//                                        data,
//                                        responseCallback,
//                                        errorCallback) {
//            window.MYJSBridge.call(handlerName, data, responseCallback);
//        }
//    }

    // Initialization
    MYJSBridge.initialize();
}();
