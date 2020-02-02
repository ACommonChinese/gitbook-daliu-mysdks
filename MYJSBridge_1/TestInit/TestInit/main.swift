//
//  main.swift
//  TestInit
//
//  Created by liuweizhen on 2020/1/11.
//  Copyright © 2020 liuxing8807@126.com. All rights reserved.
//

import Foundation

protocol ComputerProtocol: class {
    func computerName() -> String
}

class Computer {
    weak var delegate: ComputerProtocol?
}

class Person: ComputerProtocol {
    public var computer: Computer!
    
    private var name: String?
    init(name: String) {
        print("\(self)")
        self.name = name
        
        self.computer = Computer()
        self.computer.delegate = self
        if nil == self.computer.delegate {
            print("Wrong!!")
        }
    }
    public func log() -> Void {
        print("\(self.name)")
    }
    
    func computerName() -> String {
        return "MAC BOOK PRO"
    }
}

let p: Person = Person(name: "daliu")

p.log()
