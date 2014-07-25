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
    case Sub
    case Mul
    case Div
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
        case Sub:
            return "sub"
        case Mul:
            return "mul"
        case Div:
            return "div"
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
    
    var expectedArgumentCount : Int {
    switch self {
    case Nop, .PushConstant, Call:
        return 0
    case Dot, Emit:
        return 1
    case Add, Sub, Mul, Div:
        return 2
    case PushConstant:
        return 0
    case let Branch(condition, _):
        return condition == .Always ? 0 : 1
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
    var argStack = ForthStack<Int>()
    var output = ""
    
    override func resetAfterError() {
        argStack = ForthStack<Int>()
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
        if argStack.count < insn.expectedArgumentCount {
            error("\(insn.asString): expected \(insn.expectedArgumentCount) argument(s) but got \(argStack.count)")
            return nil
        }
        
        switch insn {
        case .Add:
            let rhs = self.argStack.pop()
            let lhs = self.argStack.pop()
            self.argStack.push(lhs + rhs)
        case .Sub:
            let rhs = self.argStack.pop()
            let lhs = self.argStack.pop()
            self.argStack.push(lhs - rhs)
        case .Mul:
            let rhs = self.argStack.pop()
            let lhs = self.argStack.pop()
            self.argStack.push(lhs * rhs)
        case .Div:
            let rhs = self.argStack.pop()
            let lhs = self.argStack.pop()
            if rhs != 0 {
                self.argStack.push(lhs / rhs)
            } else {
                error("division by zero")
                return nil
            }
        case .Call(let phrase):
            if !execPhrase(phrase) {
                return nil
            }
        case .PushConstant(let k):
            argStack.push(k)
        case .Dot:
            self.output += "\(self.argStack.pop()) "
        case .Nop:
            break
        case let .Branch(condition, target):
            if conditionIsTrue(condition) {
                return target!
            }
        case .Emit:
            self.output += String(fromAsciiCode: self.argStack.pop())
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

