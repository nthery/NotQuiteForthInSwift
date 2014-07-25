//
// Forth virtual machine
//

import Foundation

// Index in CompiledPhrase
typealias Address = Int

enum BranchCondition {
    case Always, IfZero
    
    var asString : String {
        switch self {
        case Always:
            return "always"
        case IfZero:
            return "ifZero"
        }
    }
}

// The instructions the virtual machine supports.
enum Instruction {
    case Nop
    case Add
    case Mul
    case Dot
    case PushConstant(Int)
    case Call(CompiledPhrase)
    case Emit
    case Branch(BranchCondition, Address?)
    
    var asString : String {
        switch self {
        case Nop:
            return "nop"
        case Add:
            return "add"
        case Mul:
            return "mul"
        case Dot:
            return "dot"
        case let PushConstant(k):
            return "pushConstant(\(k))"
        // TODO: add name in CompiledPhrease for disassembly
        case let Call(_):
            return "call"
        case Emit:
            return "emit"
        case let Branch(condition, address):
            return "branch(\(condition.asString), address)"
        }
    }
}

// TODO: turn into class or struct
typealias CompiledPhrase = [Instruction]

func compiledPhraseAsAString(phrase: CompiledPhrase) -> String {
    var acc = ""
    for insn in phrase {
        acc += insn.asString
        acc += "\n"
    }
    return acc
}

// Forth virtual machine
// TODO: Use Stack.tryTop() and .tryPop() returning optionals for dealing with errors?
class VM : ErrorRaiser {
    var argStack = Stack<Int>()
    var output = ""
    
    override func resetAfterError() {
        argStack = Stack<Int>()
    }
    
    // Execute phrase and return true on success or false if a runtime error occurred.
    func execPhrase(phrase: CompiledPhrase) -> Bool {
        var pc = 0
        while pc < phrase.count {
            if let newPc = execInstruction(pc, insn: phrase[pc]) {
                pc = newPc
            } else {
                return false
            }
        }
        return true
    }
    
    // Execute single instruction and return new PC on success or nil if a runtime
    // error occurred.
    func execInstruction(pc: Int, insn: Instruction) -> Int? {
        var ok = true
        switch insn {
        case .Add:
            ok = execOrFail(minStackDepth: 2, operation: "add") {
                let rhs = self.argStack.pop()
                let lhs = self.argStack.pop()
                self.argStack.push(lhs + rhs)
            }
        case .Mul:
            ok = execOrFail(minStackDepth: 2, operation: "mul") {
                let rhs = self.argStack.pop()
                let lhs = self.argStack.pop()
                self.argStack.push(lhs * rhs)
            }
        case .Call(let phrase):
            if !execPhrase(phrase) {
                ok = false
            }
        case .PushConstant(let k):
            argStack.push(k)
        case .Dot:
            ok = execOrFail(minStackDepth: 1, operation: "dot") {
                self.output += "\(self.argStack.pop()) "
            }
        case .Nop:
            break
        case let .Branch(condition, target):
            if conditionIsTrue(condition) {
                return target!
            }
        case .Emit:
            ok = execOrFail(minStackDepth: 1, operation: "EMIT") {
                self.output += String(fromAsciiCode: self.argStack.pop())
            }
        }
        
        return ok ? pc + 1 : nil
    }
    
    func conditionIsTrue(condition: BranchCondition) -> Bool {
        switch condition {
        case .Always:
            return true
        case .IfZero:
            return argStack.pop() == 0
        }
    }

    // Execute specified closure if the argument stack is deep enough.  Report an error
    // and return false otherwise.
    // Executing a closure in the interpreter inner loop is probably not good performance
    // wise but this is an opportunity to play with trailing closures.
    func execOrFail(minStackDepth depth: Int, operation: String, code: () -> ()) -> Bool {
        if argStack.count >= depth {
            code()
            return true
        } else {
            error("\(operation): not enough arguments")
            return false
        }
    }
}

