//
//  PortfolioMerge.swift
//  cotla.app
//

import Foundation

/// Qual carteira fica ao juntar a do aparelho com a da conta. Separado do envio para ser testável sem rede.
nonisolated enum PortfolioMerge: Equatable {
    case upload, download, clearLocal, nothing
    /// Criada sem conta neste aparelho, e a conta já tem outra: só o usuário sabe qual vale.
    case ask

    /// - local.owner: conta com que a carteira do aparelho foi sincronizada (nil = criada sem conta).
    /// - remote: nil quando a conta ainda não tem carteira na nuvem.
    static func decide(local: (isEmpty: Bool, modified: Date?, owner: String?),
                       remote: (isEmpty: Bool, modified: Date)?,
                       userId: String) -> PortfolioMerge {
        // A carteira do aparelho é de outra conta: nunca sobe para esta.
        if let owner = local.owner, owner != userId {
            guard let remote, !remote.isEmpty else { return .clearLocal }
            return .download
        }

        // Já sincronizada com esta conta: vale a edição mais recente (folga de 1 ms para o arredondamento do banco).
        if local.owner == userId {
            guard let remote else { return .upload }
            let localModified = local.modified ?? .distantPast
            if abs(localModified.timeIntervalSince(remote.modified)) < 0.001 { return .nothing }
            return localModified > remote.modified ? .upload : .download
        }

        // Criada sem conta (ex.: antes do login existir): sobe se a conta estiver vazia.
        guard let remote, !remote.isEmpty else { return local.isEmpty ? .nothing : .upload }
        return local.isEmpty ? .download : .ask
    }
}
