//
// Forth-agnostic utilities
//

import Foundation

func splitInBlankSeparatedWords(input: String) -> [String] {
    var scanner = NSScanner(string: input)
    scanner.charactersToBeSkipped = NSCharacterSet.whitespaceAndNewlineCharacterSet()
    
    var output = [String]()
    
    while true {
        var token : NSString? = ""
        let scanned = scanner.scanUpToCharactersFromSet(scanner.charactersToBeSkipped, intoString: &token)
        
        if !scanned {
            break
        }
        
        output += token!
    }
    
    return output
}

class Stack<T> {
    var items = [T]()
    
    var isEmpty : Bool {
        return items.isEmpty
    }
    
    var count : Int {
        return items.count
    }
    
    func push(value: T) {
        items.append(value)
    }
    
    func pop() -> T {
        return items.removeLast()
    }
    
    func top() -> T {
        return items[items.count-1]
    }
    
    var asString : String {
        var acc = ""
        for i in items {
            acc += "\(i) "
        }
        return acc
    }
}

class StdinLineReader {
    var stdin = NSFileHandle.fileHandleWithStandardInput()
    
    func read() -> String {
        // TODO: broken: read whole file when input is not console
        return NSString(data: stdin.availableData, encoding: NSUTF8StringEncoding)
    }
}

extension String {
    init(fromAsciiCode asciiCode: Int) {
        self = NSString(format: "%c", asciiCode)
    }
}

var debuglevel = 0

func debug(msg: @auto_closure () -> String) {
    if debuglevel > 0 {
        println("[DBG] \(msg())")
    }
}