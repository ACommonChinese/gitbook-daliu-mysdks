```
========================================================================
                   JS Call OC
========================================================================
```

```
[self.jsBridge registerHandler:@"doIt" handler:^(id _Nullable data, BMJBResponseCallback responseCallback) {
    if (responseCallback) {
        responseCallback(@"hello");
    }
}];
```

当JS调用OC方法时
```
bridge.call(‘doIt’, {key:’value’}, function(data)) {
 
}
```
JS传过来的消息对象是：
```
{
 handlerName: “doIt”, 
 data: {key: 'value'}, 
 callbackId: “cb_uniqueId_date”
}
```
OC会通过flushMessageQueue给handler的responseCallback赋值并调用handler
```
responseCallback = ^(id responseData) {
    if (responseData == nil) {
        responseData = [NSNull null];
    }
    
    [self queueMessage:@{ @"responseId":callbackId,
                          @"responseData":responseData }];
};
```

这会调到JS的方法：
```
BMJSBridge.handleMessageFromObjC(
 {
  responseId: OC回调给JS的id
  responseData: 数据
 }
)
```

```
========================================================================
                 OC Call JS
========================================================================
```

```

// 注册js方法给OC调
// OC调用JS方法jsMethod
// 带给JS数据data
// 然后如果希望JS回调OC, 可以使用responseCallback这个闭包
bridge.registerHandler("jsMethod", function(data, responseCallback) {
    alert(data);
    if (responseCallback) {
        responseCallback("hello");
    }
});

当OC调用JS方法时

[self.jsBridge callHandler:@"jsMethod" data:@"HelloChina!" responseCallback:^(id  _Nullable responseData) {
    NSLog(@"######### data : %@", responseData);
}];


OC传给JS的消息对象是：

message: {
 handlerName: "jsMethod", 
 data: {key: "value"}, 
 callbackId: "objc_cb_++uniqueid"
}

BMJSBridge.handleMessageFromObjC(message)

```

这会让JS给responseCallback这个闭包赋值，并执行handler

给responseCallback赋值：

```
responseCallback = function(responseData) {
    _this.doSend({ handlerName:message.handlerName,
                 responseId:callbackResponseId,
                 responseData:responseData });
};
```
JS把消息放入它的messageQueue中：
```
{
 handlerName: "jsMethod",
 responseId: "objc_cb_++uniqueid",
 responseData: '数据'
}
```

```
========================================================================
                  数据交换字段
========================================================================
```

| JS Call OC            | OC Call back              |
| :-------------------|:-----------------|
| handlerName: "doIt"          | responseId: cb_uniqueId_date |
| data : xxx              | responseData: yyy            |
| callbackId: "cb_uniqueId_date" | null                    |


| OC Call JS            | JS Call back             |
| :------------ |:---------------|
| handlerName: "jsMethod"     | handlerName: "jsMethod"      |
| data : xxx                   | responseData: yyy            |
| callbackId: "objc_cb_uniqueId" | responseId: objc_cb_uniqueId |
