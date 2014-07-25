//
// Code turning Forth source into compiled program for VM.
//

import Foundation

// We do not want to treat "+" and "-" as Int as they are valid Forth words.
extension String {
    func toForthInt() -> Int? {
        if self == "+" || self == "-" {
            return nil
        }
        return self.toInt()
    }
}

// An entry in the Forth dictionary.
// Either a special form, evaluated at compile time, or a regular word, evaluated at runtime.
struct Definition {
    enum Body {
        case SpecialForm
        case Regular(phrase: CompiledPhrase)
    }
    
    let name: String
    let body: Body
}

// The Forth dictionary.  We use a growing array rather than a Swift dictionary to mimic Forth
// classical implementation and ease implementation of the MARKER word.
class Dictionary {
    var content = [Definition]()
    
    func append(def: Definition) {
        content.append(def)
    }
    
    func appendPhrase(name: String, phrase: [Instruction]) {
        content.append(Definition(name: name, body: .Regular(phrase: CompiledPhrase(instructions: phrase))))
    }
    
    func appendSpecialForm(name: String) {
        content.append(Definition(name: name, body: .SpecialForm))
    }
    
    subscript(name: String) -> Definition? {
        for var i = content.count - 1; i >= 0; i-- {
            if content[i].name == name {
                return content[i]
            }
        }
        return nil
    }
    
    func isSpecialForm(name: String) -> Bool {
        if let def = self[name] {
            switch def.body {
            case .SpecialForm:
                return true
            default:
                return false
            }
        }
        return false
    }
}

// Helper class for incrementally compiling a phrase.
class PhraseBuilder {
    var phrase = [Instruction]()
    var forwardBranchCount = 0
    
    var nextAddress : CompiledPhrase.Address {
        return phrase.count
    }
    
    func appendInstruction(insn: Instruction) -> CompiledPhrase.Address {
        phrase += insn
        return phrase.count - 1
    }
    
    func appendForwardBranch(condition: Instruction.BranchCondition) -> CompiledPhrase.Address {
        ++forwardBranchCount
        phrase += .Branch(condition, nil)
        return phrase.count - 1
    }
    
    func patchBranchAt(address: CompiledPhrase.Address, withTarget target: CompiledPhrase.Address) {
        assert(forwardBranchCount > 0, "unexpected patching")
        --forwardBranchCount
        
        switch phrase[address] {
        case let .Branch(condition, nil):
            phrase[address] = .Branch(condition, target)
        default:
            assert(false, "patching non-branch instruction")
        }
    }
    
    func getAndReset() -> CompiledPhrase {
        assert(forwardBranchCount == 0, "phrase has unpatched instructions")
        let result = phrase
        phrase = [Instruction]()
        return CompiledPhrase(instructions: result)
    }
}

// The compiler entry point and heart.
class Compiler : ErrorRaiser {
    enum DefinitionState : Printable {
        case None
        case WaitingName
        case CompilingBody(String)
        
        var isDefining : Bool {
            switch self {
            case .None:
                return false
            default:
                return true
            }
        }
        
        var isWaitingName : Bool {
            switch self {
            case .WaitingName:
                return true
            default:
                return false
            }
        }
        
        var name : String? {
            switch self {
            case .CompilingBody(let name):
                return name
            default:
                return nil
                }
        }
        
        var description : String {
            switch self {
            case .None:
                return ".None"
            case .CompilingBody(let name):
                return ".CompilingBody(\(name))"
            case .WaitingName:
                return ".WaitingName"
            }
        }
    }

    var definitionState = DefinitionState.None
    var ifStack = ForthStack<CompiledPhrase.Address>()
    var dictionary = Dictionary()
    var phraseBeingCompiled = PhraseBuilder()

    init() {
        dictionary.appendPhrase("+", phrase: [.Add])
        dictionary.appendPhrase("-", phrase: [.Sub])
        dictionary.appendPhrase("*", phrase: [.Mul])
        dictionary.appendPhrase("/", phrase: [.Div])
        dictionary.appendPhrase(".", phrase: [.Dot])
        dictionary.appendPhrase("EMIT", phrase: [.Emit])
        
        dictionary.appendSpecialForm(":")
        dictionary.appendSpecialForm(";")
        dictionary.appendSpecialForm("IF")
        dictionary.appendSpecialForm("THEN")
        dictionary.appendSpecialForm("ELSE")
    }
    
    override func resetAfterError() {
        definitionState = DefinitionState.None
        ifStack = ForthStack<CompiledPhrase.Address>()
        phraseBeingCompiled = PhraseBuilder()
    }
    
    var isCompiling : Bool {
        get {
            return !ifStack.isEmpty || definitionState.isDefining
        }
    }

    // Transform source string into compiled phrase.  Return phrase on success
    // or nil on error.
    func compile(input: String) -> CompiledPhrase? {
        let tokens = splitInBlankSeparatedWords(input)
        
        for token in tokens {
            debug("Processing token: \(token) definitionState: \(definitionState)")
            if definitionState.isWaitingName {
                if token.toForthInt() || dictionary.isSpecialForm(token) {
                    error("word expected after ':' (parsed \(token))")
                    return nil
                }
                definitionState = .CompilingBody(token)
            } else {
                let success = compileToken(token)
                if !success {
                    resetAfterError()
                    return nil
                }
            }
        }
        
        return isCompiling ? CompiledPhrase() : phraseBeingCompiled.getAndReset()
    }
 
    // Compile single token into phraseBeingCompiled.  Return true on success.
    func compileToken(token: String) -> Bool {
        if let n = token.toForthInt() {
            phraseBeingCompiled.appendInstruction(.PushConstant(n))
        } else if let def = dictionary[token] {
            switch def.body {
            case .SpecialForm:
                let success = compileSpecialForm(token)
                if !success {
                    return false
                }
            case .Regular(let phrase):
                phraseBeingCompiled.appendInstruction(.Call(name: token, phrase))
            }
        } else {
            error("unknown word \(token)")
            return false
        }
        
        return true
    }
    
    // Deal with words evaluated at compile-time.  Return true on
    // success.
    // TODO: The initial idea was to associate Body.SpecialForm with a closure.
    // However, this triggers lots of weird behavior from the Swift compiler so
    // use the special form name for the time being.
    func compileSpecialForm(name: String) -> Bool {
        switch (name) {
        case ":":
            definitionState = .WaitingName
        case ";":
            if let name = definitionState.name {
                if !ifStack.isEmpty {
                    error("unterminated IF in definition")
                    return false
                }
                dictionary.append(Definition(name: name, body: .Regular(phrase: phraseBeingCompiled.getAndReset())))
                definitionState = .None
            } else {
                error("unexpected ;")
                return false
            }
        case "IF":
            ifStack.push(phraseBeingCompiled.appendForwardBranch(.IfZero))
        case "THEN":
            if ifStack.isEmpty {
                error("THEN without IF")
                return false
            }
            let target = phraseBeingCompiled.appendInstruction(.Nop) // ensure there is an insn at jump target
            let ifAddress = ifStack.pop()
            phraseBeingCompiled.patchBranchAt(ifAddress, withTarget: target)
        case "ELSE":
            if ifStack.isEmpty {
                error("ELSE without IF")
                return false
            }
            let ifAddress = ifStack.pop()
            let elseAddress = phraseBeingCompiled.appendForwardBranch(.Always)
            phraseBeingCompiled.patchBranchAt(ifAddress, withTarget: phraseBeingCompiled.nextAddress)
            ifStack.push(elseAddress)
        default:
            assert(false, "bad special form")
        }
        
        return true
    }
}
