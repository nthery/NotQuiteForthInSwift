//
//  debug.swift
//  SwiftForth
//
//  Created by Nicolas Thery on 27/07/14.
//  Copyright (c) 2014 Nicolas Thery. All rights reserved.
//

import Foundation

// Debug trace masks.
// TODO: Tried to use an enum initially but could not trick compiler
// into compiling "(condition.toRaw() & debugMask) == 0".
let debugMaskCompiler = 1
let debugMaskVm = 2
let debugMaskEvaluator = 4

var debugMask = 0

func debug(condition: Int, msg: @auto_closure () -> String) {
    if (condition & debugMask)  != 0 {
        println("[DBG] \(msg())")
    }
}