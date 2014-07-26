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
    var dictionary = Dictionary()
    var phraseBeingCompiled = PhraseBuilder()
    var ifCompilerHelper : IfCompilerHelper!
    var loopCompilerHelper : LoopCompilerHelper!

    init() {
        super.init()

        ifCompilerHelper = IfCompilerHelper(compiler: self)
        loopCompilerHelper = LoopCompilerHelper(compiler: self)

        dictionary.appendPhrase("+", phrase: [.Add])
        dictionary.appendPhrase("-", phrase: [.Sub])
        dictionary.appendPhrase("*", phrase: [.Mul])
        dictionary.appendPhrase("/", phrase: [.Div])
        dictionary.appendPhrase(".", phrase: [.Dot])
        dictionary.appendPhrase("EMIT", phrase: [.Emit])
        dictionary.appendPhrase("I", phrase: [.PushControlStackTop])
        
        dictionary.appendSpecialForm(":")
        dictionary.appendSpecialForm(";")
        dictionary.appendSpecialForm("IF")
        dictionary.appendSpecialForm("THEN")
        dictionary.appendSpecialForm("ELSE")
        dictionary.appendSpecialForm("DO")
        dictionary.appendSpecialForm("LOOP")
    }
    
    override func resetAfterError() {
        definitionState = DefinitionState.None
        ifCompilerHelper = IfCompilerHelper(compiler: self)
        loopCompilerHelper = LoopCompilerHelper(compiler: self)
        phraseBeingCompiled = PhraseBuilder()
    }
    
    var isCompiling : Bool {
        return ifCompilerHelper.isCompiling || loopCompilerHelper.isCompiling ||
            definitionState.isDefining
    }

    // Transform source string into compiled phrase.  Return phrase on success
    // or nil on error.
    func compile(input: String) -> CompiledPhrase? {
        let tokens = splitInBlankSeparatedWords(input)
        
        for token in tokens {
            debug("Processing token: \(token) definitionState: \(definitionState)")
            switch definitionState {
            case .WaitingName:
                if token.toForthInt() || dictionary.isSpecialForm(token) {
                    error("word expected after ':' (parsed \(token))")
                    return nil
                }
                definitionState = .CompilingBody(token)
            default:
                if !compileToken(token) {
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
        var success = true

        switch (name) {
        case ":":
            definitionState = .WaitingName
        case ";":
            if let name = definitionState.name {
                if ifCompilerHelper.isCompiling {
                    error("unterminated IF in definition")
                    success = false
                } else if loopCompilerHelper.isCompiling {
                     // TODO: Change message or logic if LoopCompilerHelper extended for other kinds of loops.
                    error("unterminated DO in definition")
                    success = false
                } else {
                    dictionary.append(Definition(name: name, body: .Regular(phrase: phraseBeingCompiled.getAndReset())))
                    definitionState = .None
                }
            } else {
                error("unexpected ;")
                success = false
            }
        case "IF":
            success = ifCompilerHelper.onIf()
        case "THEN":
            success = ifCompilerHelper.onThen()
        case "ELSE":
            success = ifCompilerHelper.onElse()
        case "DO":
            success = loopCompilerHelper.onDo()
        case "LOOP":
            success = loopCompilerHelper.onLoop()
        default:
            assert(false, "bad special form")
        }
        
        return success
    }
}

// Abstract base class for helper classes Compiler delegate to.
class AbstractCompilerHelper {
    init(compiler: Compiler) {
        self.compiler = compiler
    }

    let isCompiling = false

    unowned let compiler: Compiler
}

// Handle compilation of IF [ELSE] THEN special forms.
class IfCompilerHelper : AbstractCompilerHelper {
    override var isCompiling : Bool {
        return !stack.isEmpty
    }

    func onIf() -> Bool {
        stack.push(compiler.phraseBeingCompiled.appendForwardBranch(.IfZero))
        return true
    }

    func onElse() -> Bool {
        if stack.isEmpty {
            compiler.error("ELSE without IF")
            return false
        }
        let ifAddress = stack.pop()
        let elseAddress = compiler.phraseBeingCompiled.appendForwardBranch(.Always)
        compiler.phraseBeingCompiled.patchBranchAt(ifAddress, withTarget: compiler.phraseBeingCompiled.nextAddress)
        stack.push(elseAddress)
        return true
    }

    func onThen() -> Bool {
        if stack.isEmpty {
            compiler.error("THEN without IF")
            return false
        }
        let target = compiler.phraseBeingCompiled.appendInstruction(.Nop) // ensure there is an insn at jump target
        let ifAddress = stack.pop()
        compiler.phraseBeingCompiled.patchBranchAt(ifAddress, withTarget: target)
        return true
    }

    let stack = ForthStack<CompiledPhrase.Address>()
}

// Handle compilation of DO LOOP.
class LoopCompilerHelper : AbstractCompilerHelper {
    override var isCompiling : Bool {
        return !stack.isEmpty
    }

    func onDo() -> Bool {
        compiler.phraseBeingCompiled.appendInstruction(.Do)
        stack.push(compiler.phraseBeingCompiled.nextAddress)
        return true
    }

    func onLoop() -> Bool {
        if stack.isEmpty {
            compiler.error("LOOP without DO")
            return false
        }
        let doAddress = stack.pop()
        compiler.phraseBeingCompiled.appendInstruction(.Loop(doAddress))
        return true
    }

    let stack = ForthStack<CompiledPhrase.Address>()
}