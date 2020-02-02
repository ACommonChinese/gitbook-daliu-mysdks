//
//  MYJSBridgeCallback.swift
//  MYJSBridge
//
//  Created by liuweizhen on 2020/1/11.
//  Copyright © 2020 liuxing8807@126.com. All rights reserved.
//

import Foundation

public typealias JBResponseCallback = (AnyObject?) -> Void
public typealias JBHandler = (AnyObject?, JBResponseCallback?) -> Void
