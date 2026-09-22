import Foundation

enum AppConfig {
    static let brapiToken: String = {
        guard let token = ProcessInfo.processInfo.environment["BRAPI_TOKEN"] else {
            fatalError("BRAPI_TOKEN environment variable is not set.")
        }
        
        return token
    }()
}