//
//  debug.swift
//  SwiftForth
//
//  Created by Nicolas Thery on 27/07/14.
//  Copyright (c) 2014 Nicolas Thery. All rights reserved.
//

import Foundation

enum TraceFlag : UInt {
    case Evaluator = 0b0001
    case Compiler = 0b00010
    case Vm = 0b00100
}

var traceMask : UInt = 0

func debug(condition: TraceFlag, msg: @autoclosure () -> String) {
    if (condition.rawValue & traceMask)  != 0 {
        println("[DBG] \(msg())")
    }
}