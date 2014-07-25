//
// Error handling.
//

import Foundation

// Clients must implement this protocol to be notified on error.
public protocol ForthErrorHandler {
    func HandleError(msg: String)
}

// An error handler that discards all errors.
class NullErrorHandler : ForthErrorHandler {
    func HandleError(msg: String) {
        // nop
    }
}

// Abstract base class for classes that raise errors.
class ErrorRaiser {
    var errorHandler : ForthErrorHandler = NullErrorHandler()
    
    // Report an error and rollback to consistent state for error recovery.
    func error(msg: String) {
        errorHandler.HandleError(msg)
        resetAfterError()
    }
    
    // To be implemented by subclasses.
    func resetAfterError() {
    }
}
