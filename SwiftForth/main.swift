//
// Forth read-eval-print loop
//

import Foundation

class ErrorPrinter : ErrorHandler {
    func HandleError(msg: String) {
        println("ERROR: \(msg)")
    }
}

func repl() {
    var reader = StdinLineReader()
    var evaluator = Evaluator()
    evaluator.setErrorHandler(ErrorPrinter())
    
    while true {
        println("[ \(evaluator.argStack.asString) ]")
        print("==> ")
        let input = reader.read()
        if input.isEmpty {
            break
        }
        evaluator.eval(input)
        print(evaluator.readAndResetOutput())
    }
}

repl()