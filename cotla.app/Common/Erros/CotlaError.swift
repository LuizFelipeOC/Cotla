//
//  CotlaErrors.swift
//  cotla.app
//
//  Created by Luiz Felipe on 08/09/26.
//

import Foundation

enum CotlaError: String, Error {
    case invalidURL = "URL inválida"
    case invalidData = "Dados inválidos"
    case invalidResponse = "Resposta inválida do servidor"
    case unauthorized = "Token de acesso ausente ou inválido"
    case paidFeatureRequired = "Recurso disponível apenas em planos pagos"
    case tooManyRequests = "Muitas requisições agora, tente novamente em instantes"
    case decodingFailed = "Não foi possível interpretar os dados recebidos"
    case noConnection = "Sem conexão com a internet"
    case unknown = "Ocorreu um erro inesperado"
}
