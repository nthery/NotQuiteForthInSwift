//
// Error handling.
//

import Foundation

enum Result {
    case OK, KO

    var description : String {
        switch self {
        case .OK:
            return "OK"
        case .KO:
            return "KO"
        }
    }
}

// Clients must implement this protocol to be notified on error.
protocol ErrorHandler {
    func HandleError(msg: String)
}

// An error handler that discards all errors.
class NullErrorHandler : ErrorHandler {
    func HandleError(msg: String) {
        // nop
    }
}

// Abstract base class for classes that raise errors.
class ErrorRaiser {
    var errorHandler : ErrorHandler = NullErrorHandler()
    
    // Report an error and rollback to consistent state for error recovery.
    func error(msg: String) {
        errorHandler.HandleError(msg)
        resetAfterError()
    }
    
    // To be implemented by subclasses.
    func resetAfterError() {
    }
}
