//
// Top-level class coordinating compiler and virtual machine.
//

import Foundation

class Evaluator {
    let compiler = Compiler()
    let vm = VM()
    
    init() {
        // Compile builtins implemented in Forth.
        evalOrDie(": CR 13 EMIT ;")
    }
    
    func setErrorHandler(handler: ErrorHandler) {
        compiler.errorHandler = handler
        vm.errorHandler = handler
    }
    
    func readAndResetOutput() -> String {
        let o = vm.output
        vm.output = ""
        return o
    }
    
    var argStack : Stack<Int> {
        return vm.argStack
    }
    
    // Main entry point for clients.
    func eval(input: String) -> Result {
        if let phrase = compiler.compile(input) {
            return vm.execPhrase(phrase) ? .OK : .KO
        } else {
            return .KO
        }
    }

    func evalOrDie(input: String) {
        let result = eval(input)
        if result != .OK {
            println("failed to evaluate '\(input)'")
            exit(1)
        }
    }
    

}