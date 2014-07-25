//
//  SwiftForthTests.swift
//  SwiftForthTests
//
//  Created by Nicolas Thery on 17/07/14.
//  Copyright (c) 2014 Nicolas Thery. All rights reserved.
//

import Foundation
import XCTest

class ErrorCounter : ForthErrorHandler {
    var errors = 0
    
    func HandleError(msg: String) {
        ++errors
    }
}

class FailOnError : ForthErrorHandler {
    func HandleError(msg: String) {
        XCTFail("unexpected evaluator error")
    }
}

class EvaluatorTest : XCTestCase {
    var evaluator = ForthEvaluator()
    var errors = 0
    
    override func setUp() {
        evaluator.setErrorHandler(FailOnError())
    }
    
    func checkEvalSuccess(input: String, expectedOutput: String) {
        XCTAssert(evaluator.eval(input))
        let actualOutput = evaluator.getAndResetOutput()
        XCTAssertEqual(expectedOutput, actualOutput)
    }
    
    func checkEvalFailure(input: String) {
        let counter = ErrorCounter()
        evaluator.setErrorHandler(counter)
        XCTAssert(!evaluator.eval(input))
        XCTAssert(counter.errors > 0)
        
        // Check compiler reset to correct state.
        checkEvalSuccess(": foo 42 ; foo .", expectedOutput: "42 ")
    }
    
    func testDotOnEmptyStack() {
        checkEvalFailure(".")
    }
    
    func testConstant() {
        checkEvalSuccess(": k 42 ;", expectedOutput: "")
        checkEvalSuccess("k 1 + .", expectedOutput: "43 ")
    }
    
    func testUnknownWord() {
        checkEvalFailure("foo")
    }
    
    func testLeaf() {
        checkEvalSuccess(": leaf 1 2 + ;", expectedOutput: "")
        checkEvalSuccess("leaf 1 + .", expectedOutput: "4 ")
    }
    
    func testNonLeaf() {
        checkEvalSuccess(": leaf 1 2 + ;", expectedOutput: "")
        checkEvalSuccess(": nonleaf 1 leaf + ;", expectedOutput: "")
        checkEvalSuccess("nonleaf 1 + .", expectedOutput: "5 ")
    }
    
    func testNumberAfterColon() {
        checkEvalFailure(": 1 2 ;")
    }
    
    func testSemicolonAfterColon() {
        checkEvalFailure(": ;")
    }
    
    func testSemicolonWithoutColon() {
        checkEvalFailure(";")
    }
    
    func testIfNotTaken() {
        checkEvalSuccess("10 0 IF 20 THEN .", expectedOutput: "10 ")
    }
    
    func testIfTaken() {
        checkEvalSuccess("10 1 IF 20 THEN .", expectedOutput: "20 ")
    }
    
    func testNestedIfNotTaken() {
        checkEvalSuccess("10 1 IF 0 IF 20 THEN THEN .", expectedOutput: "10 ")
    }
    
    func testNestedIfTaken() {
        checkEvalSuccess("10 1 IF 1 IF 20 THEN THEN .", expectedOutput: "20 ")
    }
    
    func testElseTaken() {
        checkEvalSuccess("10 0 IF 20 ELSE 30 THEN .", expectedOutput: "30 ")
    }
    
    func testElseNotTaken() {
        checkEvalSuccess("10 1 IF 20 ELSE 30 THEN .", expectedOutput: "20 ")
    }
    
    func testUnterminatedIfInDefinition() {
        checkEvalFailure(": foo 1 IF 20 ELSE 30 ;")
    }
    
    func testElseWithoutIf() {
        checkEvalFailure("ELSE")
    }
    
    func testThenWithoutIf() {
        checkEvalFailure("THEN")
    }
    
    func testEmit() {
        checkEvalSuccess("65 EMIT", expectedOutput: "A")
    }
    
    func testEmitEmptyStack() {
        checkEvalFailure("EMIT")
    }
    
    func testCR() {
        checkEvalSuccess("CR", expectedOutput: "\r")
    }
}

class AddTest : EvaluatorTest {
    func testBinary() {
        checkEvalSuccess("1 2 + .", expectedOutput: "3 ")
    }
    
    func testTernary() {
        checkEvalSuccess("1 2 + 3 + .", expectedOutput: "6 ")
        checkEvalSuccess("1 2 3 + + .", expectedOutput: "6 ")
    }
    
    func testWithoutOperand() {
        checkEvalFailure("+")
    }
    
    func testWithSingleOperand() {
        checkEvalFailure("1 +")
    }
}

class SubTest : EvaluatorTest {
    func testNegativeConstant() {
        checkEvalSuccess("-1 .", expectedOutput: "-1 ")
    }
    
    func testBinary() {
        checkEvalSuccess("3 2 - .", expectedOutput: "1 ")
        checkEvalSuccess("2 3 - .", expectedOutput: "-1 ")
    }
    
    func testWithoutOperand() {
        checkEvalFailure("-")
    }
    
    func testWithSingleOperand() {
        checkEvalFailure("1 -")
    }
}

class MulTest : EvaluatorTest {
    func testBinary() {
        checkEvalSuccess("2 3 * .", expectedOutput: "6 ")
    }
    
    func testTernary() {
        checkEvalSuccess("2 3 * 4 * .", expectedOutput: "24 ")
        checkEvalSuccess("2 3 4 * * .", expectedOutput: "24 ")
    }
    
    func testWithoutOperand() {
        checkEvalFailure("*")
    }
    
    func testWithSingleOperand() {
        checkEvalFailure("1 *")
    }
}

class DivTest : EvaluatorTest {
    func testBinaryWithoutTruncation() {
        checkEvalSuccess("6 2 / .", expectedOutput: "3 ")
    }
    
    func testBinaryWithTruncation() {
        checkEvalSuccess("6 4 / .", expectedOutput: "1 ")
    }
    
    func testByZero() {
        checkEvalFailure("6 0 / .")
    }
    
    func testWithoutOperand() {
        checkEvalFailure("/")
    }
    
    func testWithSingleOperand() {
        checkEvalFailure("1 /")
    }
}

class DictionaryTest : XCTestCase {
    var dict = Dictionary()
    
    func testEmpty() {
        XCTAssert(!dict["foo"])
    }
    
    func testAddAndLookup() {
        dict.appendPhrase("a", phrase: [.Nop])
        let def = dict["a"]
        XCTAssert(def && def!.name == "a")
    }
}
