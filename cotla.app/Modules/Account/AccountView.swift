//
//  AccountView.swift
//  cotla.app
//

import Supabase
import SwiftUI

/// Conta logada: sair ou excluir. A App Store exige que quem cria conta no app consiga excluí-la por ele.
struct AccountView: View {
    let email: String?
    let onClose: () -> Void

    @State private var confirmDelete = false
    @State private var isWorking     = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Conta") {
                    LabeledContent("E-mail", value: email ?? "—")
                }

                Section {
                    Button("Sair") {
                        Task { await run { try await SupabaseService.client.auth.signOut() } }
                    }
                }

                Section {
                    Button("Excluir conta", role: .destructive) { confirmDelete = true }
                } footer: {
                    Text("Apaga sua conta e a carteira guardada na nuvem. A carteira salva neste aparelho continua aqui.")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Conta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK", action: onClose)
                }
            }
            .confirmationDialog("Excluir sua conta?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Excluir conta", role: .destructive) {
                    Task {
                        // `delete_user` é uma função no banco (supabase/migrations) que apaga só o usuário logado.
                        await run {
                            try await SupabaseService.client.rpc("delete_user").execute()
                            PortfolioSync.forgetAccount()
                            try await SupabaseService.client.auth.signOut()
                        }
                    }
                }
            } message: {
                Text("Isso não pode ser desfeito.")
            }
            .disabled(isWorking)
        }
    }

    private func run(_ operation: () async throws -> Void) async {
        isWorking    = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            try await operation()
            onClose()
        } catch {
            errorMessage = "Não deu certo. Confira a conexão e tente de novo."
        }
    }
}
