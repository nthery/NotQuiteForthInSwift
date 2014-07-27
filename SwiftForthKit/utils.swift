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

public class ForthStack<T> : Printable {
    var items = [T]()
    
    public var isEmpty : Bool {
        return items.isEmpty
    }
    
    public var count : Int {
        return items.count
    }
    
    public func push(value: T) {
        items.append(value)
    }
    
    public func pop() -> T {
        return items.removeLast()
    }
    
    // Return most recently pushed item by default or item at specified
    // offset from stack top.
    public func top(offsetFromTop: Int = 0) -> T {
        return items[items.count - 1 - offsetFromTop]
    }
    
    public var description : String {
        var acc = ""
        for i in items {
            acc += "\(i) "
        }
        return acc
    }
}

extension String {
    init(fromAsciiCode asciiCode: Int) {
        self = NSString(format: "%c", asciiCode)
    }
}