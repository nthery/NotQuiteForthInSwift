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
        switch insn {
        case .Add:
            if argStack.count >= 2 {
                let rhs = argStack.pop()
                let lhs = argStack.pop()
                argStack.push(lhs + rhs)
            } else {
                error("add: not enough arguments")
                return nil
            }
        case .Call(let phrase):
            if !execPhrase(phrase) {
                return nil
            }
        case .PushConstant(let k):
            argStack.push(k)
        case .Dot:
            output += "\(argStack.pop()) "
        case .Nop:
            break
        case let .Branch(condition, target):
            if conditionIsTrue(condition) {
                return target!
            }
        case .Emit:
            output += String(fromAsciiCode: argStack.pop())
        }
        
        return pc + 1
    }
    
    func conditionIsTrue(condition: BranchCondition) -> Bool {
        switch condition {
        case .Always:
            return true
        case .IfZero:
            return argStack.pop() == 0
        }
    }
}

