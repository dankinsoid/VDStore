import Foundation

struct CustomError: LocalizedError {
    
    var errorDescription: String?
    
    init(_ errorDescription: String) {
        self.errorDescription = errorDescription
    }
}
