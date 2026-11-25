//
//  SupabaseService.swift
//  cotla.app
//

import Foundation
import Supabase

/// Cliente único do Supabase. A sessão fica no Keychain e é renovada pelo próprio SDK.
enum SupabaseService {
    static let client = SupabaseClient(
        supabaseURL: URL(string: "https://\(AppConfig.supabaseHost)")!,
        supabaseKey: AppConfig.supabaseAnonKey
    )
}
