//
//  PortfolioSync.swift
//  cotla.app
//

import Supabase
import UIKit

/// Leva a carteira deste aparelho para a conta no Supabase e traz de volta.
/// As telas seguem lendo do aparelho; cada edição sobe em seguida, e ao abrir o app, voltar a ele ou entrar
/// na conta as duas versões são juntadas por `PortfolioMerge`.
/// ponytail: a carteira inteira é um documento só e vale a edição mais recente; edições offline em dois
/// aparelhos ao mesmo tempo perdem uma delas. Passar para tabelas por posição se isso começar a acontecer.
enum PortfolioSync {

    nonisolated struct Row: Codable {
        let userId: UUID
        let data: [PositionEntity]
        let updatedAt: Date

        enum CodingKeys: String, CodingKey {
            case userId    = "user_id"
            case data
            case updatedAt = "updated_at"
        }
    }

    /// Conta com que a carteira do aparelho foi sincronizada. nil = criada sem conta (ou conta excluída).
    private static let ownerKey = "portfolioOwner"

    /// Só envia depois de juntar com a nuvem nesta sessão: antes disso, o aparelho pode estar desatualizado.
    private static var isReady   = false
    private static var isSyncing = false
    private static var isPushing = false
    private static var needsPush = false

    // MARK: - Juntar

    /// `presenter` mostra a pergunta quando o aparelho e a conta têm carteiras diferentes.
    static func sync(from presenter: UIViewController?) async {
        guard !isSyncing else { return }
        isSyncing = true
        isReady   = false
        defer { isSyncing = false }

        guard let user = SupabaseService.client.auth.currentUser else { return }

        let remote: Row?
        do {
            let rows: [Row] = try await SupabaseService.client.from("portfolios")
                .select()
                .eq("user_id", value: user.id.uuidString)
                .limit(1)
                .execute()
                .value
            remote = rows.first
        } catch {
            return // Sem rede: segue com o aparelho; a próxima sincronização junta.
        }

        let local    = PortfolioStore.all()
        var decision = PortfolioMerge.decide(
            local: (isEmpty: local.isEmpty, modified: PortfolioStore.modifiedAt, owner: UserDefaults.standard.string(forKey: ownerKey)),
            remote: remote.map { (isEmpty: $0.data.isEmpty, modified: $0.updatedAt) },
            userId: user.id.uuidString
        )

        if decision == .ask {
            guard let keepAccount = await askWhichToKeep(from: presenter) else { return }
            decision = keepAccount ? .download : .upload
        }

        switch decision {
        case .upload:
            guard await upload(local, userId: user.id) else { return }
        case .download:
            PortfolioStore.replace(with: remote?.data ?? [], modifiedAt: remote?.updatedAt)
        case .clearLocal:
            PortfolioStore.replace(with: [], modifiedAt: nil)
        case .nothing, .ask:
            break
        }

        UserDefaults.standard.set(user.id.uuidString, forKey: ownerKey)
        isReady = true
    }

    /// A conta foi excluída: a carteira fica no aparelho como se tivesse sido criada sem conta.
    static func forgetAccount() {
        UserDefaults.standard.removeObject(forKey: ownerKey)
        isReady = false
    }

    /// Antes de sair: junta com a nuvem para nada ficar só no aparelho. false se não deu (sem rede, por exemplo).
    static func syncBeforeSignOut() async -> Bool {
        await sync(from: nil)
        return isReady
    }

    /// Saiu da conta: a carteira sai do aparelho (está na nuvem e volta ao entrar de novo).
    static func clearAfterSignOut() {
        UserDefaults.standard.removeObject(forKey: ownerKey)
        isReady = false
        PortfolioStore.replace(with: [], modifiedAt: nil)
    }

    // MARK: - Enviar

    /// Uma edição local: sobe a carteira inteira. Um envio por vez, para um mais antigo não chegar depois.
    static func push() {
        guard isReady, let user = SupabaseService.client.auth.currentUser else { return }
        guard !isPushing else {
            needsPush = true
            return
        }

        isPushing = true
        Task {
            await upload(PortfolioStore.all(), userId: user.id)
            isPushing = false

            if needsPush {
                needsPush = false
                push()
            }
        }
    }

    /// Falha de rede não perde nada: o aparelho fica mais novo que a nuvem e sobe na próxima sincronização.
    @discardableResult
    private static func upload(_ positions: [PositionEntity], userId: UUID) async -> Bool {
        let row = Row(userId: userId, data: positions, updatedAt: PortfolioStore.modifiedAt ?? Date())

        do {
            try await SupabaseService.client.from("portfolios").upsert(row).execute()
            return true
        } catch {
            return false
        }
    }

    // MARK: - Pergunta

    /// true = manter a da conta. nil se não há tela livre para perguntar (tenta de novo na próxima sincronização).
    private static func askWhichToKeep(from presenter: UIViewController?) async -> Bool? {
        var top = presenter
        while let presented = top?.presentedViewController { top = presented }
        guard let top, top.view.window != nil, !top.isBeingDismissed else { return nil }

        return await withCheckedContinuation { continuation in
            let alert = UIAlertController(
                title: "Sua conta já tem uma carteira",
                message: "Este aparelho também tem uma carteira, criada sem conta. Qual você quer manter? A outra será substituída.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Manter a da conta", style: .default) { _ in
                continuation.resume(returning: true)
            })
            alert.addAction(UIAlertAction(title: "Manter a deste aparelho", style: .default) { _ in
                continuation.resume(returning: false)
            })
            top.present(alert, animated: true)
        }
    }
}
