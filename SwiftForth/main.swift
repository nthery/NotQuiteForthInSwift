//
// Forth read-eval-print loop
//

import Foundation
import SwiftForthKit

class ErrorPrinter : ForthErrorHandler {
    func HandleError(msg: String) {
        println("ERROR: \(msg)")
    }
}

class StdinLineReader {
    var stdin = NSFileHandle.fileHandleWithStandardInput()
    
    func read() -> String {
        // TODO: broken: read whole file when input is not console
        return NSString(data: stdin.availableData, encoding: NSUTF8StringEncoding)
    }
}

func repl() {
    var reader = StdinLineReader()
    var evaluator = ForthEvaluator()
    evaluator.setErrorHandler(ErrorPrinter())
    
    while true {
        println("[ \(evaluator.argStack) ]")
        print("==> ")
        let input = reader.read()
        if input.isEmpty {
            break
        }
        evaluator.eval(input)
        print(evaluator.getAndResetOutput())
    }
}

repl()