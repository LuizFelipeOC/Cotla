//
//  LoginView.swift
//  cotla.app
//

import Supabase
import SwiftUI

/// Entrar ou criar conta com e-mail e senha pelo Supabase Auth.
/// "Agora não" segue sem conta: a carteira continua neste aparelho.
struct LoginView: View {
    let onFinish: () -> Void

    @State private var email        = ""
    @State private var password     = ""
    @State private var isSignUp     = false
    @State private var isLoading    = false
    @State private var errorMessage: String?
    @State private var infoMessage: String?

    private let brand = Color("BrandGreen")
    private let ink   = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? .label : UIColor(red: 0.059, green: 0.102, blue: 0.078, alpha: 1) })
    private let background = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? .systemBackground : UIColor(red: 0.949, green: 0.965, blue: 0.953, alpha: 1) })

    /// O Supabase exige no mínimo 6 caracteres por padrão.
    private var canSubmit: Bool {
        email.contains("@") && password.count >= 6
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Spacer()

            Text(isSignUp ? "Crie sua conta" : "Entre na sua conta")
                .font(.system(size: 34, weight: .bold))
                .kerning(-0.8)
                .foregroundStyle(ink)

            Text(isSignUp ? "Use seu e-mail e uma senha de pelo menos 6 caracteres." : "Use seu e-mail e senha para entrar no Cotla.")
                .font(.system(size: 17))
                .foregroundStyle(.secondary)
                .padding(.bottom, 12)

            TextField("E-mail", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .modifier(FieldStyle())

            SecureField("Senha", text: $password)
                .textContentType(isSignUp ? .newPassword : .password)
                .modifier(FieldStyle())

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            if let infoMessage {
                Text(infoMessage)
                    .font(.footnote)
                    .foregroundStyle(brand)
            }

            Spacer()

            Button {
                Task { await submit() }
            } label: {
                Text(isSignUp ? "Criar conta" : "Entrar")
                    .font(.system(size: 17, weight: .bold))
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .foregroundStyle(ink)
                    .background(brand.opacity(canSubmit ? 1 : 0.4), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .disabled(!canSubmit)

            Button(isSignUp ? "Já tem conta? Entrar" : "Não tem conta? Criar conta") {
                isSignUp.toggle()
                errorMessage = nil
                infoMessage  = nil
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(brand)
            .frame(maxWidth: .infinity, minHeight: 44)

            Button("Agora não", action: onFinish)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .padding(20)
        .background(background.ignoresSafeArea())
        .disabled(isLoading)
        .overlay { if isLoading { ProgressView().tint(brand) } }
    }

    private func submit() async {
        isLoading    = true
        errorMessage = nil
        infoMessage  = nil
        defer { isLoading = false }

        let email = email.trimmingCharacters(in: .whitespaces)

        do {
            if isSignUp {
                // Com "Confirm email" ligado no Supabase (o padrão), a conta só abre sessão depois do link no e-mail.
                let response = try await SupabaseService.client.auth.signUp(email: email, password: password)
                guard response.session != nil else {
                    isSignUp    = false
                    infoMessage = "Enviamos um link para \(email). Confirme o e-mail e depois entre com sua senha."
                    return
                }
            } else {
                try await SupabaseService.client.auth.signIn(email: email, password: password)
            }
            onFinish()
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    private static func message(for error: Error) -> String {
        switch (error as? AuthError)?.errorCode.rawValue {
        case "invalid_credentials": return "E-mail ou senha incorretos."
        case "email_not_confirmed": return "Confirme seu e-mail pelo link que enviamos antes de entrar."
        case "user_already_exists": return "Já existe uma conta com este e-mail. Entre com sua senha."
        case "weak_password":       return "Senha fraca. Use pelo menos 6 caracteres."
        case "over_email_send_rate_limit":
            return "Muitos e-mails enviados em pouco tempo. Espere alguns minutos e tente de novo."
        default:
            // Mostra o motivo real (rede ou mensagem do Supabase) para não esconder erros que não mapeamos.
            return "Não foi possível continuar: \(error.localizedDescription)"
        }
    }
}

private struct FieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 17))
            .padding(.horizontal, 14)
            .frame(minHeight: 52)
            .background(Color(uiColor: .tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color(uiColor: .separator)))
    }
}
