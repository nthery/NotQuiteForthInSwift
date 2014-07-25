//
// Top-level class coordinating compiler and virtual machine.
//

import Foundation

public class ForthEvaluator {
    let compiler = Compiler()
    let vm = VM()
    
    public init() {
        // Compile builtins implemented in Forth.
        evalOrDie(": CR 13 EMIT ;")
    }
    
    public func setErrorHandler(handler: ForthErrorHandler) {
        compiler.errorHandler = handler
        vm.errorHandler = handler
    }
    
    public func readAndResetOutput() -> String {
        let o = vm.output
        vm.output = ""
        return o
    }
    
    public var argStack : ForthStack<Int> {
        return vm.argStack
    }
    
    // Evaluate Forth source statements.
    // Return true on success.
    // Report an error through ForthErrorHandler and return false on failure.
    public func eval(input: String) -> Bool {
        if let phrase = compiler.compile(input) {
            return vm.execPhrase(phrase)
        } else {
            return false
        }
    }

    func evalOrDie(input: String) {
        if !eval(input) {
            println("failed to evaluate '\(input)'")
            exit(1)
        }
    }
}