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
    case decodingFailed = "Não foi possível interpretar os dados recebidos"
    case noConnection = "Sem conexão com a internet"
    case unknown = "Ocorreu um erro inesperado"
}
