import Foundation

enum AppConfig {
    static var brapiToken: String {
        Bundle.main.object(forInfoDictionaryKey: "BRAPI_TOKEN") as? String ?? ""
    }
}
