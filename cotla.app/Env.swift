import Foundation

enum AppConfig {
    static var brapiToken: String {
        Bundle.main.object(forInfoDictionaryKey: "BRAPI_TOKEN") as? String ?? ""
    }

    /// Ex.: "abcdefgh.supabase.co".
    static var supabaseHost: String {
        Bundle.main.object(forInfoDictionaryKey: "SUPABASE_HOST") as? String ?? ""
    }

    /// Chave anon: pública por desenho; quem protege os dados é o RLS no banco.
    static var supabaseAnonKey: String {
        Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String ?? ""
    }
}
