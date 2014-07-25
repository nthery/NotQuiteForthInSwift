//
//  utils_test.swift
//  SwiftForth
//
//  Created by Nicolas Thery on 21/07/14.
//  Copyright (c) 2014 Nicolas Thery. All rights reserved.
//

import Foundation
import XCTest

class ScannerTest : XCTestCase {
    func testEmpty() {
        // TODO: test assert for comparing arrays?
        XCTAssert(splitInBlankSeparatedWords("") == [String]())
    }
    
    func testSingleToken() {
        XCTAssert(splitInBlankSeparatedWords("10") == ["10"])
    }
    
    func testTwoTokena() {
        XCTAssert(splitInBlankSeparatedWords("10 11") == ["10", "11"])
    }
}
