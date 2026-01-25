import Foundation
 
extension String {
    var cleanedCopyright: String {
        guard self != "n/a" && !self.isEmpty else { return self }
        
        let clean = self
            .replacingOccurrences(of: #"(?i)(\([cp]\)|©|℗)"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: .punctuationCharacters)
            .trimmingCharacters(in: .whitespaces)
            
        return "© \(clean)"
    }
}
